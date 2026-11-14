-- Slutmog Scout: measured farm data.
-- Counts what really happens when the player loots: corpses opened per area,
-- list pieces found on them, the level of the mobs they came from, and the time
-- spent (gaps between loots). Everything is read from the loot window, never
-- from chat, so vendor, quest and mail items are not counted.
local ADDON, ns = ...

local GAP = 300            -- a pause longer than this between loots is not farming time
local MIN_SECS = 900       -- measured time needed before gold per hour is shown
local LEVEL_CACHE_MAX = 3000
ns.MIN_MEASURE_SECS = MIN_SECS

local IsSecret, Num = ns.IsSecret, ns.Num

local levels, levelCount = {}, 0   -- creature GUID -> level, this session
local corpses = {}                 -- creature GUID -> true once counted, this session
local counted = {}                 -- "GUID:itemID" -> true once counted, this session
local lastLoot, lastKey            -- time and area of the previous counted loot

local function Str(v)
  if IsSecret(v) then
    return nil
  end
  if type(v) == "string" then
    return v
  end
  return nil
end

local function IsCreature(guid)
  return guid:find("^Creature%-") ~= nil or guid:find("^Vehicle%-") ~= nil
end

local function RememberLevel(unit)
  local ok, guid = pcall(UnitGUID, unit)
  guid = ok and Str(guid) or nil
  if not guid or not IsCreature(guid) then
    return
  end
  local ok2, level = pcall(UnitLevel, unit)
  level = ok2 and Num(level) or nil
  if not level or level <= 0 then
    return -- skull-level mobs report -1
  end
  if not levels[guid] then
    if levelCount >= LEVEL_CACHE_MAX then
      wipe(levels)
      levelCount = 0
    end
    levelCount = levelCount + 1
  end
  levels[guid] = level
end

local function CurrentArea()
  local zone = Str(GetRealZoneText()) or ""
  if zone == "" then
    zone = "Unknown"
  end
  local sub = Str(GetSubZoneText()) or ""
  local inside = false
  if IsInInstance then
    local ok, v = pcall(IsInInstance)
    inside = ok and not IsSecret(v) and v == true
  end
  local key = zone
  if not inside and sub ~= "" and sub ~= zone then
    key = zone .. ": " .. sub
  end
  local db = ns.db
  local a = db.areas[key]
  if type(a) ~= "table" then
    a = { zone = zone, looted = 0, secs = 0, items = {} }
    db.areas[key] = a
  end
  a.items = a.items or {}
  return a, key
end

local function ItemIDOfSlot(slot)
  local ok, link = pcall(GetLootSlotLink, slot)
  link = ok and Str(link) or nil
  local id = link and link:match("|Hitem:(%d+)")
  return id and tonumber(id) or nil
end

-- Creature GUIDs a loot slot came from (area loot can merge several corpses).
local function CollectSources(out, ok, ...)
  if not ok then
    return out
  end
  -- returns come in pairs: guid, quantity, guid, quantity, ...
  for i = 1, select("#", ...), 2 do
    local guid = Str((select(i, ...)))
    if guid and IsCreature(guid) then
      out[#out + 1] = guid
    end
  end
  return out
end

local function SourcesOfSlot(slot)
  return CollectSources({}, pcall(GetLootSourceInfo, slot))
end

-- True for a slot the player cannot take (yet): a group-loot roll or master
-- loot. Such a piece is not the player's drop. The slot is looked at again on
-- the next loot event, so a piece that unlocks is still counted.
local function SlotLocked(slot)
  if not GetLootSlotInfo then
    return false
  end
  local ok, _, _, _, _, _, locked = pcall(GetLootSlotInfo, slot)
  return ok and not IsSecret(locked) and locked == true
end

local function OnLoot()
  local db = ns.db
  if not db or not (GetNumLootItems and GetLootSlotLink and GetLootSourceInfo) then
    return
  end
  local ok, n = pcall(GetNumLootItems)
  n = ok and Num(n) or 0
  if n <= 0 then
    return
  end
  local items = ns.Items()
  local newCorpses, drops = {}, {}
  for slot = 1, n do
    local sources = SourcesOfSlot(slot)
    for _, guid in ipairs(sources) do
      if not corpses[guid] then
        corpses[guid] = true
        newCorpses[#newCorpses + 1] = guid
      end
    end
    local id = ItemIDOfSlot(slot)
    local guid = sources[1]
    if id and guid and items[id] and not counted[guid .. ":" .. id] and not SlotLocked(slot) then
      counted[guid .. ":" .. id] = true
      drops[#drops + 1] = { id = id, guid = guid }
    end
  end
  if #newCorpses == 0 and #drops == 0 then
    return
  end

  local a, key = CurrentArea()
  local now = time()
  if #newCorpses > 0 then
    a.looted = (a.looted or 0) + #newCorpses
    if lastLoot and lastKey == key and now >= lastLoot and now - lastLoot <= GAP then
      a.secs = (a.secs or 0) + (now - lastLoot)
    end
    lastLoot, lastKey = now, key
    a.last = now
    for _, guid in ipairs(newCorpses) do
      local level = levels[guid]
      if level then
        a.lmin = math.min(a.lmin or level, level)
        a.lmax = math.max(a.lmax or level, level)
      end
    end
  end
  for _, d in ipairs(drops) do
    a.items[d.id] = (a.items[d.id] or 0) + 1
    local level = levels[d.guid]
    if level then
      local seen = db.dropLvl[d.id]
      if type(seen) ~= "table" then
        seen = { lo = level, hi = level, n = 0 }
        db.dropLvl[d.id] = seen
      end
      seen.lo, seen.hi, seen.n = math.min(seen.lo, level), math.max(seen.hi, level), (seen.n or 0) + 1
    end
    -- The count is saved; a failing chat line must not stop the loop.
    pcall(function()
      local it = items[d.id]
      local name = it and it.name
      if type(name) ~= "string" then
        name = "Item " .. d.id
      end
      local v = ns.NetValue(d.id)
      ns.Print(("%s dropped in %s. Logged.%s"):format(name, key,
        v and (" It sells for about " .. ns.Money(v) .. " after the auction house cut.") or ""))
    end)
  end
  ns.Fire("DROPS")
end

-------------------------------------------------------------------------------
-- What the window reads
-------------------------------------------------------------------------------
local function Summarise(key, a)
  local value, pieces, unpriced = 0, 0, 0
  for id, n in pairs(a.items or {}) do
    pieces = pieces + n
    local v = ns.NetValue(id)
    if v then
      value = value + v * n
    else
      unpriced = unpriced + n
    end
  end
  local secs = a.secs or 0
  return {
    key = key, area = a, pieces = pieces, value = value, unpriced = unpriced,
    perHour = secs >= MIN_SECS and value / (secs / 3600) or nil,
  }
end

-- Every area the player has looted in, best measured gold per hour first.
function ns.Measured()
  local out = {}
  for key, a in pairs(ns.db.areas) do
    if type(a) == "table" then
      out[#out + 1] = Summarise(key, a)
    end
  end
  table.sort(out, function(x, y)
    local xh, yh = x.perHour or -1, y.perHour or -1
    if xh ~= yh then
      return xh > yh
    end
    if x.value ~= y.value then
      return x.value > y.value
    end
    local xl, yl = x.area.looted or 0, y.area.looted or 0
    if xl ~= yl then
      return xl > yl
    end
    return x.key < y.key
  end)
  return out
end

function ns.MeasuredForZone(zone)
  local out = {}
  for _, m in ipairs(ns.Measured()) do
    if m.area.zone == zone then
      out[#out + 1] = m
    end
  end
  return out
end

-- Where a piece was found for the player: { [area] = count }, or nil.
function ns.Drops(id)
  local out
  for key, a in pairs(ns.db.areas) do
    local n = type(a) == "table" and a.items and a.items[id]
    if n then
      out = out or {}
      out[key] = n
    end
  end
  return out
end

function ns.ClearMeasured()
  wipe(ns.db.areas)
  wipe(ns.db.dropLvl)
  lastLoot, lastKey = nil, nil
  ns.Print("Measured farm data cleared.")
  ns.Fire("DROPS")
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
for _, event in ipairs({ "LOOT_READY", "LOOT_OPENED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED" }) do
  -- An event name this game does not know must not stop the others.
  pcall(frame.RegisterEvent, frame, event)
end

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "LOOT_READY" or event == "LOOT_OPENED" then
    -- Tracking is an extra: an error here must never break looting.
    local ok, err = pcall(OnLoot)
    if not ok and not frame.warned then
      frame.warned = true
      ns.Print("Measured farm data is off for this session (" .. tostring(err) .. ").")
      frame:UnregisterEvent("LOOT_READY")
      frame:UnregisterEvent("LOOT_OPENED")
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    RememberLevel("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    RememberLevel("mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    if not IsSecret(arg1) and type(arg1) == "string" then
      RememberLevel(arg1)
    end
  end
end)
