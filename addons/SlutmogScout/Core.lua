-- Slutmog Scout: core (saved data, prices, auction scan, farm ranking, list self-check)
local ADDON, ns = ...

local PREFIX = "|cffff66aaSlutmog Scout|r: "
local BROWSE_BATCH = 500      -- size of one browse page on the modern auction house
local PAGE_CAP = 200          -- a scan that needs more pages than this is stopped
local HISTORY_MAX = 30        -- price points kept per item
local SCAN_TIMEOUT = 25       -- seconds without any auction house answer before a scan gives up
local CHECK_TIMEOUT = 20      -- seconds the list self-check waits for item data
local AH_CUT = 0.05
ns.AH_CUT = AH_CUT

local db
local listeners = {}

function ns.Print(msg)
  print(PREFIX .. tostring(msg))
end

function ns.On(fn)
  listeners[#listeners + 1] = fn
end

function ns.Fire(what)
  for _, fn in ipairs(listeners) do
    fn(what)
  end
end

local function IsSecret(v)
  return issecretvalue ~= nil and issecretvalue(v)
end
ns.IsSecret = IsSecret

-- A plain number, or nil for anything else (including the game's secret values).
local function Num(v)
  if IsSecret(v) then
    return nil
  end
  if type(v) == "number" then
    return v
  end
  return nil
end
ns.Num = Num

-------------------------------------------------------------------------------
-- Money
-------------------------------------------------------------------------------
-- dim = true gives the same text in grey (used for prices that are not current).
function ns.Money(copper, dim)
  if not copper then
    return "|cff777777-|r"
  end
  copper = math.floor(copper + 0.5)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local text
  if g >= 100 then
    text = ("|cffffd100%s|rg"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g)
  elseif g > 0 then
    text = ("|cffffd100%d|rg |cffc7c7cf%d|rs"):format(g, s)
  elseif s > 0 then
    text = ("|cffc7c7cf%d|rs |cffeda55f%d|rc"):format(s, c)
  else
    text = ("|cffeda55f%d|rc"):format(c)
  end
  if dim then
    text = "|cff999999" .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") .. "|r"
  end
  return text
end

-------------------------------------------------------------------------------
-- Item set: built-in list + the player's own additions
-------------------------------------------------------------------------------
local ARMOR_SUBCLASS = { cloth = 1, leather = 2, mail = 3, plate = 4 }
local SUBCLASS_ARMOR = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate" }
-- Enum.InventoryType values used as auction house slot filters
local SLOT_INVTYPES = {
  head = { 1 }, shoulder = { 3 }, chest = { 5, 20 }, waist = { 6 }, legs = { 7 },
  feet = { 8 }, wrist = { 9 }, hands = { 10 }, back = { 16 },
}
local EQUIPLOC_SLOT = {
  INVTYPE_HEAD = "head", INVTYPE_SHOULDER = "shoulder", INVTYPE_CHEST = "chest",
  INVTYPE_ROBE = "chest", INVTYPE_WAIST = "waist", INVTYPE_LEGS = "legs",
  INVTYPE_FEET = "feet", INVTYPE_WRIST = "wrist", INVTYPE_HAND = "hands",
  INVTYPE_CLOAK = "back",
}
local ItemBind = Enum and Enum.ItemBind or {}
local BIND_ON_ACQUIRE = ItemBind.OnAcquire or 1
local BIND_QUEST = ItemBind.Quest or 4

local items = {}

local function GameBuild()
  if not GetBuildInfo then
    return "?"
  end
  local version, build = GetBuildInfo()
  return tostring(version) .. "." .. tostring(build)
end

local function Locale()
  local locale = GetLocale and GetLocale() or "?"
  return type(locale) == "string" and locale or "?"
end

-- Identifies the built-in list by its contents, so a stored check result is
-- never applied to a list with other pieces in it.
local listKeyCache, listKeyFor
local function ListKey()
  if listKeyFor ~= ns.ITEMS then
    local list = ns.LIST or {}
    local sum, n = 0, 0
    for id in pairs(ns.ITEMS) do
      if type(id) == "number" then
        sum = (sum + id * 31) % 1000003
        n = n + 1
      end
    end
    listKeyCache = tostring(list.build) .. "/" .. tostring(list.count) .. "/" .. n .. "/" .. sum
    listKeyFor = ns.ITEMS
  end
  return listKeyCache
end

-- The stored result of the last list self-check, or nil when it was made for
-- another version of the built-in list.
local function CheckResult()
  local chk = db and db.check
  if type(chk) == "table" and chk.list == ListKey() and type(chk.bad) == "table" then
    return chk
  end
  return nil
end

function ns.RebuildItems()
  wipe(items)
  local chk = CheckResult()
  local bad = chk and chk.bad
  -- Names stored by the check are in the language it ran in: after a language
  -- switch the list's own names are used until the check has run again.
  local names = chk and chk.locale == Locale() and type(chk.names) == "table" and chk.names or nil
  for id, it in pairs(ns.ITEMS) do
    it.id = id
    it.listName = it.listName or it.name
    it.name = names and names[id] or it.listName
    if not (db and db.hidden[id]) and not (bad and bad[id]) then
      items[id] = it
    end
  end
  if db then
    for id, it in pairs(db.custom) do
      if type(it) == "table" then
        it.custom = true
        it.id = id
        items[id] = it
      end
    end
  end
end

function ns.Items()
  return items
end

-- Mob levels an item is expected to drop from. The third return is true when
-- the band was widened by levels of mobs it really dropped from for the player.
function ns.MobRange(it)
  local lo, hi
  if it.mob then
    lo, hi = it.mob[1], it.mob[2]
  else
    local req = it.req or 1
    lo, hi = req, math.min(req + 5, 63)
  end
  local seen = db and db.dropLvl and it.id and db.dropLvl[it.id]
  if type(seen) == "table" and seen.lo and seen.hi then
    return math.min(lo, seen.lo), math.max(hi, seen.hi), true
  end
  return lo, hi, false
end

local function ItemIDFromLink(text)
  if type(text) ~= "string" then
    return nil
  end
  local id = text:match("|Hitem:(%d+)") or text:match("^%s*(%d+)%s*$") or text:match("item:(%d+)")
  if not id or #id > 7 then
    return nil
  end
  id = tonumber(id)
  return id and id >= 1 and id or nil
end
ns.ItemIDFromLink = ItemIDFromLink

-- "/smog add" input: an item link or a bare item ID, then an optional note.
local function ParseAdd(text)
  if type(text) ~= "string" then
    return nil
  end
  local id = text:match("|Hitem:(%d+)")
  local note
  if id then
    note = text:gsub("|c.-|h|r", ""):gsub("|H.-|h.-|h", "")
  else
    id, note = text:match("^%s*(%d+)%s+(.*)$")
    if not id then
      id, note = text:match("^%s*(%d+)%s*$"), ""
    end
  end
  if not id or #id > 7 then
    return nil
  end
  id = tonumber(id)
  if not id or id < 1 then
    return nil
  end
  note = (note or ""):gsub("^%s+", ""):gsub("%s+$", "")
  return id, note
end

function ns.AddCustom(text)
  local id, note = ParseAdd(text)
  if not id then
    ns.Print("Shift-click an item into the chat box after |cffffff00/smog add|r, or give an item ID.")
    return
  end
  local builtin = ns.ITEMS[id]
  if builtin then
    local chk = CheckResult()
    local reason = chk and chk.bad[id]
    if reason then
      ns.Print(("%s stays hidden: it %s."):format(builtin.name, reason))
      return
    end
    db.hidden[id] = nil
    db.custom[id] = nil
    ns.RebuildItems()
    ns.Print(("%s is a built-in piece and is on the list."):format(builtin.name))
    ns.Fire("ITEMS")
    return
  end
  local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  classID, subClassID = Num(classID), Num(subClassID)
  if not classID then
    ns.Print("The game does not know item " .. id .. ".")
    return
  end
  if type(equipLoc) ~= "string" or IsSecret(equipLoc) then
    equipLoc = nil
  end
  local function save()
    local name, _, quality, ilvl, req, _, _, _, _, _, _, _, _, bind = C_Item.GetItemInfo(id)
    if name == nil then
      ns.Print("The game sent no data for item " .. id .. ". Try again in a moment.")
      return
    end
    if type(name) ~= "string" or IsSecret(name) then
      ns.Print("The game sent no usable data for item " .. id .. ".")
      return
    end
    bind = Num(bind)
    quality, ilvl, req = Num(quality), Num(ilvl), Num(req)
    if bind == BIND_ON_ACQUIRE or bind == BIND_QUEST then
      ns.Print(("%s binds when picked up, so it can never be on the auction house. Not added."):format(name))
      return
    end
    db.hidden[id] = nil
    db.custom[id] = {
      name = name,
      armor = classID == 4 and subClassID and SUBCLASS_ARMOR[subClassID] or "other",
      slot = equipLoc and EQUIPLOC_SLOT[equipLoc] or "other",
      q = quality or 2,
      req = req and req > 0 and req or nil,
      ilvl = ilvl,
      look = note ~= "" and note or "added by you",
      src = "world",
      classID = classID,
      subClassID = subClassID,
    }
    ns.RebuildItems()
    ns.Print(("Added %s. It is included from the next scan."):format(name))
    ns.Fire("ITEMS")
  end
  if C_Item.GetItemInfo(id) then
    save()
  elseif Item and Item.CreateFromItemID then
    ns.Print("Loading item " .. id .. "...")
    local item = Item:CreateFromItemID(id)
    item:ContinueOnItemLoad(save)
  else
    ns.Print("The game sent no data for item " .. id .. ". Try again in a moment.")
  end
end

function ns.RemoveItem(text)
  local id = ItemIDFromLink(text)
  if not id or not items[id] then
    ns.Print("That item is not on the list.")
    return
  end
  local name = items[id].name
  if db.custom[id] then
    db.custom[id] = nil
  else
    db.hidden[id] = true
  end
  ns.RebuildItems()
  ns.Print(("Removed %s. |cffffff00/smog restore|r brings back removed built-in pieces."):format(name))
  ns.Fire("ITEMS")
end

-------------------------------------------------------------------------------
-- Prices
-------------------------------------------------------------------------------
local function Median(list)
  local n = #list
  if n == 0 then
    return nil
  end
  table.sort(list)
  if n % 2 == 1 then
    return list[(n + 1) / 2]
  end
  return (list[n / 2] + list[n / 2 + 1]) / 2
end

local function ExternalPrice(id)
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, v = pcall(api.GetAuctionPriceByItemID, ADDON, id)
    if ok and type(v) == "number" and v > 0 then
      return v, "Auctionator"
    end
  end
  if TSM_API and TSM_API.GetCustomPriceValue then
    local ok, v = pcall(TSM_API.GetCustomPriceValue, "dbminbuyout", "i:" .. id)
    if ok and type(v) == "number" and v > 0 then
      return v, "TSM"
    end
  end
end

-- Returns a table describing what is known about an item's price.
--   low      lowest price in the last scan (nil when none were listed)
--   qty      items listed in the last scan (nil before any scan)
--   typical  median of the lowest prices seen over the last 10 scans that had it
--   value    best single estimate of what one sells for (typical > low > other addon)
--   source   where value came from
--   seenPct  share of scans in which the item was listed at all
function ns.Price(id)
  local p = db.prices[id]
  local info = {}
  if p then
    info.qty = p.qty
    info.low = (p.qty or 0) > 0 and p.min or nil
    info.lastSeen = p.lastSeen
    info.lastMin = p.lastMin
    if p.hist and #p.hist > 0 then
      local mins = {}
      for i = math.max(1, #p.hist - 9), #p.hist do
        mins[#mins + 1] = p.hist[i][2]
      end
      info.typical = Median(mins)
    end
    if (p.scans or 0) > 0 then
      info.seenPct = (p.seen or 0) / p.scans
    end
  end
  if info.typical then
    info.value, info.source = info.typical, "your scans"
  elseif info.low then
    info.value, info.source = info.low, "last scan"
  else
    info.value, info.source = ExternalPrice(id)
  end
  return info
end

function ns.NetValue(id)
  local v = ns.Price(id).value
  return v and v * (1 - AH_CUT) or nil
end

-------------------------------------------------------------------------------
-- Auction house scan (browse query limited to the armor types/slots on the list)
-------------------------------------------------------------------------------
local scan = { active = false, rows = 0, pages = 0 }
ns.scan = scan

local function BuildClassFilters()
  local seen, filters, classes = {}, {}, {}
  local function add(classID, subClassID, invType)
    local key = classID .. ":" .. tostring(subClassID) .. ":" .. tostring(invType)
    if not seen[key] then
      seen[key] = true
      classes[classID] = true
      filters[#filters + 1] = { classID = classID, subClassID = subClassID, inventoryType = invType }
    end
  end
  for _, it in pairs(items) do
    local classID = it.classID or 4
    local subClassID = it.subClassID or ARMOR_SUBCLASS[it.armor]
    local invTypes = classID == 4 and SLOT_INVTYPES[it.slot]
    if invTypes then
      for _, invType in ipairs(invTypes) do
        add(classID, subClassID, invType)
      end
    else
      add(classID, subClassID, nil)
    end
  end
  return filters, classes
end

local function ScanApiPresent()
  local ah = C_AuctionHouse
  return ah and ah.SendBrowseQuery and ah.GetBrowseResults and ah.HasFullBrowseResults
    and ah.RequestMoreBrowseResults and ah.IsThrottledMessageSystemReady
    and Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price ~= nil
end

local function Ready()
  return C_AuctionHouse.IsThrottledMessageSystemReady()
end

local function RunPending()
  if scan.active and scan.pending and Ready() then
    local fn = scan.pending
    scan.pending = nil
    fn()
  end
end

local function Queue(fn)
  scan.pending = fn
  RunPending()
end

local function StopTicker()
  if scan.ticker then
    scan.ticker:Cancel()
    scan.ticker = nil
  end
end

local function Abort(reason)
  if not scan.active then
    return
  end
  scan.active = false
  scan.pending = nil
  StopTicker()
  ns.Print("Scan stopped: " .. reason)
  ns.Fire("SCAN")
end

local function Finish()
  -- An empty answer is far more likely a failed search than an empty auction
  -- house, and saving it would mark every piece as "not listed".
  if scan.rows == 0 then
    Abort("the auction house returned no results. Nothing was saved, try again.")
    return
  end
  local now = time()
  local listed, total, skipped = 0, 0, 0
  -- Only the pieces that were on the list when the scan started were searched for.
  for id in pairs(scan.ids) do
    if items[id] then
      total = total + 1
      local f = scan.found[id]
      if not (f and f.min) and scan.unreadable[id] then
        -- It is listed, but its price or quantity could not be read. Saying
        -- "not listed" would be wrong: its earlier record is left as it was.
        skipped = skipped + 1
      else
        local p = db.prices[id]
        if not p then
          p = { hist = {} }
          db.prices[id] = p
        end
        p.hist = p.hist or {}
        p.scans = (p.scans or 0) + 1
        p.t = now
        if f and f.min then
          listed = listed + 1
          p.min, p.qty, p.variants = f.min, f.qty, f.variants
          p.lastMin, p.lastSeen = f.min, now
          p.seen = (p.seen or 0) + 1
          p.hist[#p.hist + 1] = { now, f.min, f.qty }
          while #p.hist > HISTORY_MAX do
            table.remove(p.hist, 1)
          end
        else
          p.min, p.qty, p.variants = nil, 0, 0
        end
      end
    end
  end
  db.lastScan = now
  scan.active = false
  scan.pending = nil
  StopTicker()
  ns.Print(("Scan done: %d of %d tracked pieces are listed right now (%d search results read).%s"):format(listed, total, scan.rows,
    skipped > 0 and (" %d could not be read and kept their earlier data."):format(skipped) or ""))
  ns.Fire("SCAN")
end

-- Adds one page of browse results. Every field is checked: the game may hand
-- out values an addon is not allowed to read.
local function Absorb(results)
  local n = 0
  for _, r in ipairs(results) do
    if type(r) == "table" then
      n = n + 1
      local key = r.itemKey
      local id = type(key) == "table" and Num(key.itemID) or nil
      if id and scan.ids[id] then
        local qty = Num(r.totalQuantity)
        local price = Num(r.minPrice)
        if qty == nil or (qty > 0 and not (price and price > 0)) then
          scan.unreadable[id] = true -- listed, but not in a form this addon can read
        end
        if qty and qty > 0 then
          local f = scan.found[id]
          if not f then
            f = { qty = 0, variants = 0 }
            scan.found[id] = f
          end
          f.qty = f.qty + qty
          f.variants = f.variants + 1
          if price and price > 0 and (not f.min or price < f.min) then
            f.min = price
          end
        end
      end
    end
  end
  scan.rows = scan.rows + n
  scan.pages = scan.pages + 1
  if n > 0 then
    scan.lastActivity = GetTime()
  end
end

-- Samples a result page: false when it holds items of a class the scan never
-- asked for, which means another search (the player's or another addon's)
-- answered instead of ours.
local function LooksLikeOurs(results)
  local n = #results
  if n == 0 then
    return true
  end
  local step = math.max(1, math.floor(n / 25))
  for i = 1, n, step do
    local r = results[i]
    local id = type(r) == "table" and type(r.itemKey) == "table" and Num(r.itemKey.itemID) or nil
    if id then
      local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, id)
      classID = ok and Num(classID) or nil
      if classID and not scan.classes[classID] then
        return false
      end
    end
  end
  return true
end

local function NextStep()
  local ok, full = pcall(C_AuctionHouse.HasFullBrowseResults)
  if not ok then
    Abort("the auction house refused the search. Wait a few seconds and scan again.")
  elseif full then
    Finish()
  elseif scan.pages >= PAGE_CAP then
    Abort("too many result pages, stopping.")
  else
    Queue(function()
      scan.lastActivity = GetTime()
      scan.requested = true
      if not pcall(C_AuctionHouse.RequestMoreBrowseResults) then
        Abort("the auction house refused the search. Wait a few seconds and scan again.")
      end
    end)
    ns.Fire("SCAN")
  end
end

local function OnBrowseUpdated()
  if not (scan.active and scan.sent) then
    return
  end
  local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
  if not ok or type(results) ~= "table" then
    return
  end
  local n = #results
  if scan.pages == 0 then
    -- Waiting for our first page. Anything else is left alone; the timeout
    -- ends the scan if ours never comes.
    local accept = n > 0
    if n == 0 then
      -- An empty list only counts when the game says it is the whole answer.
      local okf, full = pcall(C_AuctionHouse.HasFullBrowseResults)
      accept = okf and not IsSecret(full) and full == true
    end
    if accept and n <= BROWSE_BATCH and LooksLikeOurs(results) then
      Absorb(results)
      NextStep()
    end
  elseif n > BROWSE_BATCH then
    return -- a refresh of pages that are already counted
  elseif scan.pages == 1 and LooksLikeOurs(results) then
    -- The first page again (the game re-sends it when item data arrives).
    wipe(scan.found)
    wipe(scan.unreadable)
    scan.rows, scan.pages = 0, 0
    Absorb(results)
    if not scan.pending and not scan.requested then
      NextStep()
    end
  else
    Abort("another search replaced the scan. Nothing was saved, scan again.")
  end
end

local function OnBrowseAdded(results)
  if scan.active and scan.sent and scan.pages > 0 and type(results) == "table" then
    scan.requested = false
    Absorb(results)
    NextStep()
  end
end

function ns.AuctionHouseOpen()
  return AuctionHouseFrame ~= nil and AuctionHouseFrame:IsShown()
end

function ns.StartScan()
  if scan.active then
    ns.Print("A scan is already running.")
    return
  end
  if not ScanApiPresent() then
    ns.Print("This game version lacks the auction house search this addon uses. |cffffff00/smog selftest|r shows what is missing.")
    return
  end
  if not ns.AuctionHouseOpen() then
    ns.Print("Open the auction house first, then scan.")
    return
  end
  local filters, classes = BuildClassFilters()
  if #filters == 0 then
    ns.Print("Nothing to scan: every piece is removed. Use |cffffff00/smog restore|r.")
    return
  end
  scan.active = true
  scan.sent = false
  scan.requested = false
  scan.found = {}
  scan.unreadable = {}
  scan.classes = classes
  scan.ids = {}
  for id in pairs(items) do
    scan.ids[id] = true
  end
  scan.rows = 0
  scan.pages = 0
  scan.lastActivity = GetTime()
  local query = {
    searchString = "",
    sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } },
    filters = {},
    itemClassFilters = filters,
  }
  StopTicker()
  scan.ticker = C_Timer.NewTicker(1, function()
    if not scan.active then
      StopTicker()
    elseif GetTime() - scan.lastActivity > SCAN_TIMEOUT then
      Abort("the auction house did not answer. Try again in a moment.")
    else
      RunPending()
    end
  end)
  Queue(function()
    scan.sent = true
    scan.lastActivity = GetTime()
    if not pcall(C_AuctionHouse.SendBrowseQuery, query) then
      Abort("the auction house refused the search. Wait a few seconds and scan again.")
    end
  end)
  ns.Fire("SCAN")
end

-------------------------------------------------------------------------------
-- Farm ranking
-------------------------------------------------------------------------------
-- How strongly an item belongs to a spot: 0..1 (share of the item's mob-level
-- band the spot covers). Dungeon-only drops match only their own instance.
-- Pieces that are not mob drops (fishing) match no spot.
local function SpotMatch(spot, it)
  if it.src == "fishing" then
    return 0
  end
  if it.inst then
    return spot.inst == it.inst and 1 or 0
  end
  local lo, hi = ns.MobRange(it)
  local olo, ohi = math.max(lo, spot.lo), math.min(hi, spot.hi)
  if ohi < olo then
    return 0
  end
  return (ohi - olo + 1) / (hi - lo + 1)
end

-- Returns spots sorted by the summed value of the pieces whose level band
-- overlaps them. This is a pool estimate, not gold per hour.
-- filter(it) optionally limits which items count.
function ns.RankSpots(filter)
  local out = {}
  for _, spot in ipairs(ns.SPOTS) do
    local entry = { spot = spot, total = 0, priced = 0, pieces = {} }
    for id, it in pairs(items) do
      if not filter or filter(it) then
        local m = SpotMatch(spot, it)
        if m > 0 then
          local v = ns.NetValue(id)
          entry.pieces[#entry.pieces + 1] = { id = id, value = v, match = m }
          if v then
            entry.total = entry.total + v * m
            entry.priced = entry.priced + 1
          end
        end
      end
    end
    if #entry.pieces > 0 then
      table.sort(entry.pieces, function(a, b)
        local av, bv = (a.value or 0) * a.match, (b.value or 0) * b.match
        if av ~= bv then
          return av > bv
        end
        return a.id < b.id
      end)
      out[#out + 1] = entry
    end
  end
  table.sort(out, function(a, b)
    if a.total ~= b.total then
      return a.total > b.total
    end
    return #a.pieces > #b.pieces
  end)
  return out
end

function ns.SpotsForItem(id, limit)
  local it = items[id]
  local out = {}
  if not it then
    return out
  end
  for _, spot in ipairs(ns.SPOTS) do
    local m = SpotMatch(spot, it)
    if m > 0 then
      out[#out + 1] = { spot = spot, match = m }
    end
  end
  table.sort(out, function(a, b)
    if a.match ~= b.match then
      return a.match > b.match
    end
    return (a.spot.dungeon and 1 or 0) < (b.spot.dungeon and 1 or 0)
  end)
  while limit and #out > limit do
    out[#out] = nil
  end
  return out
end

function ns.SpotLabel(spot)
  if spot.area and spot.area ~= "" then
    if spot.dungeon then
      return spot.zone .. " (" .. spot.area .. ")"
    end
    return spot.zone .. ": " .. spot.area
  end
  return spot.zone
end

-------------------------------------------------------------------------------
-- List self-check: compares every built-in piece with the running game.
-- A piece is hidden only on positive proof that it no longer fits (not armor,
-- another slot or armor type, binds when picked up). Missing data hides nothing.
-------------------------------------------------------------------------------
local check = { running = false }

local function Judge(id, it)
  local _, _, _, equipLoc, _, classID, subClassID = C_Item.GetItemInfoInstant(id)
  classID = Num(classID)
  if not classID then
    return nil, true
  end
  if classID ~= 4 then
    return "is not armor in this game"
  end
  if type(equipLoc) ~= "string" or IsSecret(equipLoc) then
    return nil, true
  end
  if EQUIPLOC_SLOT[equipLoc] ~= it.slot then
    return ("is not a %s piece in this game"):format(tostring(it.slot))
  end
  local want = ARMOR_SUBCLASS[it.armor]
  if want and Num(subClassID) ~= want then
    return ("is %s in this game, the list says %s"):format(SUBCLASS_ARMOR[Num(subClassID) or 0] or "another armor type", it.armor)
  end
  local bind = Num((select(14, C_Item.GetItemInfo(id))))
  if bind == BIND_ON_ACQUIRE or bind == BIND_QUEST then
    return "binds when picked up in this game, so it cannot be auctioned"
  end
  return nil
end

local function English()
  local locale = GetLocale and GetLocale() or "enUS"
  return type(locale) == "string" and locale:sub(1, 2) == "en"
end

local function CappedList(list, cap)
  table.sort(list)
  local shown = {}
  for i = 1, math.min(cap, #list) do
    shown[i] = list[i]
  end
  local text = table.concat(shown, "; ")
  if #list > cap then
    text = text .. ("; and %d more"):format(#list - cap)
  end
  return text
end

local function ReportCheck(res, verbose)
  local badList, renamedList = {}, {}
  for id, reason in pairs(res.bad) do
    local base = ns.ITEMS[id]
    if base then
      badList[#badList + 1] = ("%s (%d) %s"):format(tostring(base.listName or base.name), id, tostring(reason))
    end
  end
  for id, name in pairs(res.names) do
    local base = ns.ITEMS[id]
    if base then
      renamedList[#renamedList + 1] = ("%d \"%s\" is \"%s\" here"):format(id, tostring(base.listName or "?"), tostring(name))
    end
  end
  if not verbose then
    if #badList > 0 then
      ns.Print(("%d built-in piece(s) no longer fit this game build and were hidden. |cffffff00/smog verify|r shows which."):format(#badList))
    end
    if #renamedList > 0 and English() then
      ns.Print(("%d built-in piece(s) have another name in this game build. |cffffff00/smog verify|r shows which."):format(#renamedList))
    end
    return
  end
  ns.Print(("Checked %d built-in pieces against game build %s."):format(res.checked, res.build))
  print(("  %d passed: nothing found that contradicts the list (armor, slot, armor type, not bind-on-pickup)."):format(res.ok))
  if res.unknown > 0 then
    print(("  %d the game has no data for (kept; they may not exist in this build)."):format(res.unknown))
  end
  if res.unanswered > 0 then
    print(("  %d not answered within %d seconds (kept; checked again at next login)."):format(res.unanswered, CHECK_TIMEOUT))
  end
  if #renamedList > 0 then
    if English() then
      print(("  %d have another name here: %s"):format(#renamedList, CappedList(renamedList, 10)))
    else
      print(("  %d use this game's own names (normal on a non-English client)."):format(#renamedList))
    end
  end
  if #badList > 0 then
    print(("  %d hidden as wrong: %s"):format(#badList, CappedList(badList, 10)))
  end
  local seenOnAH = 0
  for id in pairs(ns.ITEMS) do
    local p = db.prices[id]
    if p and (p.seen or 0) > 0 then
      seenOnAH = seenOnAH + 1
    end
  end
  print(("  %d have been seen on the auction house in your scans."):format(seenOnAH))
  if ns.LIST and ns.LIST.build ~= res.build then
    print(("  The list was generated from game build %s. Regenerating it (tools/SlutmogScout/build_items.py) picks up new and changed items."):format(tostring(ns.LIST.build)))
  end
end

function ns.SelfCheck(verbose)
  if check.running then
    if verbose then
      ns.Print("A check is already running.")
    end
    return
  end
  if not (C_Item and C_Item.DoesItemExistByID and C_Item.GetItemInfoInstant and C_Item.GetItemInfo and Item and Item.CreateFromItemID) then
    if verbose then
      ns.Print("This game version lacks the item functions the check needs. |cffffff00/smog selftest|r shows what is missing.")
    end
    return
  end
  check.running = true
  local res = { bad = {}, names = {}, ok = 0, unknown = 0, unanswered = 0, checked = 0, build = GameBuild() }
  local pending, waiting, queued, done = {}, 0, false, false

  local function finish()
    if done then
      return
    end
    done = true
    check.running = false
    -- A piece that did not answer this time keeps its earlier verdict (same
    -- list only): a slow moment must not un-hide a piece already proven wrong.
    -- A piece that did answer always wins.
    local prev = CheckResult()
    local prevNames = prev and prev.locale == Locale() and type(prev.names) == "table" and prev.names or nil
    for id in pairs(pending) do
      res.unanswered = res.unanswered + 1
      if prev and prev.bad[id] and not res.bad[id] then
        res.bad[id] = prev.bad[id]
      end
      if prevNames and prevNames[id] and not res.names[id] then
        res.names[id] = prevNames[id]
      end
    end
    db.check = {
      build = res.build, list = ListKey(), locale = Locale(), t = time(), complete = res.unanswered == 0,
      bad = res.bad, names = res.names, ok = res.ok, unknown = res.unknown + res.unanswered,
    }
    ns.RebuildItems()
    ns.Fire("ITEMS")
    ReportCheck(res, verbose)
  end

  -- Asks the game to load one piece and judges it when the data arrives.
  local function register(id, it)
    pending[id] = true
    waiting = waiting + 1
    local item = Item:CreateFromItemID(id)
    item:ContinueOnItemLoad(function()
      if done or not pending[id] then
        return
      end
      pending[id] = nil
      waiting = waiting - 1
      -- An error while judging counts the piece as "no data": it must not
      -- drop out of the totals or stop the check from finishing.
      local okJ, reason, noData = pcall(Judge, id, it)
      if not okJ then
        reason, noData = nil, true
      end
      if reason then
        res.bad[id] = reason
      elseif noData then
        res.unknown = res.unknown + 1
      else
        res.ok = res.ok + 1
        local okN, name = pcall(item.GetItemName, item)
        if okN and type(name) == "string" and not IsSecret(name) and name ~= "" and name ~= (it.listName or it.name) then
          res.names[id] = name
        end
      end
      if queued and waiting == 0 then
        finish()
      end
    end)
  end

  for id, it in pairs(ns.ITEMS) do
    res.checked = res.checked + 1
    local okE, exists = pcall(C_Item.DoesItemExistByID, id)
    if not okE or IsSecret(exists) or not exists then
      res.unknown = res.unknown + 1
    elseif not pcall(register, id, it) and pending[id] then
      -- The game refused to load this piece: count it as "no data".
      pending[id] = nil
      waiting = waiting - 1
      res.unknown = res.unknown + 1
    end
  end
  queued = true
  if waiting == 0 then
    finish()
  else
    C_Timer.After(CHECK_TIMEOUT, finish)
  end
end

-- Runs the check by itself when the game build or the built-in list changed.
local function AutoCheck()
  local chk = db.check
  if type(chk) == "table" and chk.build == GameBuild() and chk.list == ListKey()
    and chk.locale == Locale() and chk.complete then
    return
  end
  ns.SelfCheck(false)
end

-- Number of built-in pieces the self-check is hiding right now.
function ns.CheckHidden()
  local chk = CheckResult()
  local n = 0
  if chk then
    for _ in pairs(chk.bad) do
      n = n + 1
    end
  end
  return n
end

-------------------------------------------------------------------------------
-- Self-test: does this game have the functions the addon is built on?
-------------------------------------------------------------------------------
function ns.SelfTest()
  local found, missing = 0, {}
  local function need(present, name, breaks)
    if present then
      found = found + 1
    else
      missing[#missing + 1] = ("%s (%s)"):format(name, breaks)
    end
  end
  local ah, ci, et = C_AuctionHouse or {}, C_Item or {}, Enum or {}
  need(ah.SendBrowseQuery, "C_AuctionHouse.SendBrowseQuery", "scanning")
  need(ah.GetBrowseResults, "C_AuctionHouse.GetBrowseResults", "scanning")
  need(ah.HasFullBrowseResults, "C_AuctionHouse.HasFullBrowseResults", "scanning")
  need(ah.RequestMoreBrowseResults, "C_AuctionHouse.RequestMoreBrowseResults", "scanning")
  need(ah.IsThrottledMessageSystemReady, "C_AuctionHouse.IsThrottledMessageSystemReady", "scanning")
  need(et.AuctionHouseSortOrder and et.AuctionHouseSortOrder.Price ~= nil, "Enum.AuctionHouseSortOrder.Price", "scanning")
  need(ci.GetItemInfoInstant, "C_Item.GetItemInfoInstant", "icons, adding pieces, the list check")
  need(ci.GetItemInfo, "C_Item.GetItemInfo", "links, adding pieces, the list check")
  need(ci.DoesItemExistByID, "C_Item.DoesItemExistByID", "the list check")
  need(Item and Item.CreateFromItemID, "Item:CreateFromItemID", "the list check")
  need(GetBuildInfo, "GetBuildInfo", "noticing game updates")
  need(C_Timer and C_Timer.After and C_Timer.NewTicker, "C_Timer", "scanning, the list check")
  need(GetNumLootItems and GetLootSlotLink, "GetNumLootItems / GetLootSlotLink", "measured farm data")
  need(GetLootSourceInfo, "GetLootSourceInfo", "measured farm data")
  need(UnitGUID and UnitLevel, "UnitGUID / UnitLevel", "mob levels in measured farm data")
  need(GetRealZoneText and GetSubZoneText, "GetRealZoneText / GetSubZoneText", "measured farm data")
  need(TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and et.TooltipDataType, "TooltipDataProcessor", "item tooltip lines")
  need(GameTooltip and GameTooltip.SetItemByID, "GameTooltip:SetItemByID", "tooltips in the window")
  ns.Print(("Self-test: %d of %d game functions found."):format(found, found + #missing))
  for _, line in ipairs(missing) do
    print("  |cffff5555missing|r " .. line)
  end

  local total, orphans, noDungeon = 0, {}, {}
  for id, it in pairs(ns.ITEMS) do
    total = total + 1
    if it.src ~= "fishing" then
      local any = false
      for _, spot in ipairs(ns.SPOTS) do
        if SpotMatch(spot, it) > 0 then
          any = true
          break
        end
      end
      if not any then
        local target = it.inst and noDungeon or orphans
        target[#target + 1] = ("%s (%d)"):format(it.listName or it.name, id)
      end
    end
  end
  local listCount = ns.LIST and ns.LIST.count
  print(("  Built-in list: %d pieces%s, %d farm spots (%d dungeons)."):format(total,
    listCount == total and "" or (" |cffff5555but its header says %s|r"):format(tostring(listCount)),
    #ns.SPOTS, #(ns.DUNGEON_SPOTS or {})))
  if #orphans > 0 then
    print("  |cffff5555No farm spot covers:|r " .. CappedList(orphans, 10))
  end
  if #noDungeon > 0 then
    print("  |cffff5555Dungeon not in the dungeon list:|r " .. CappedList(noDungeon, 10))
  end
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  print(("  Optional price sources: Auctionator %s, TradeSkillMaster %s."):format(
    api and api.GetAuctionPriceByItemID and "found" or "not loaded",
    TSM_API and TSM_API.GetCustomPriceValue and "found" or "not loaded"))
  print(("  Game build %s. List generated from %s."):format(GameBuild(), tostring(ns.LIST and ns.LIST.build)))
  return #missing, #orphans + #noDungeon
end

-------------------------------------------------------------------------------
-- Item tooltips
-------------------------------------------------------------------------------
-- True when the tooltip belongs to a row of this addon's own window, which
-- writes its own, longer lines.
local function OwnRow(tooltip)
  if not tooltip.GetOwner then
    return false
  end
  local ok, own = pcall(function()
    local owner = tooltip:GetOwner()
    return owner and owner.smogOwnTooltip
  end)
  return ok and own == true
end

local function OnTooltipItem(tooltip, data)
  if not db or type(data) ~= "table" then
    return
  end
  local id = Num(data.id)
  local it = id and items[id]
  if not it or not tooltip.AddLine then
    return
  end
  if OwnRow(tooltip) then
    if ns.FillItemTooltip then
      ns.tipFilled = true
      ns.FillItemTooltip(tooltip, id)
    end
    return
  end
  if not db.opts.tooltip then
    return
  end
  tooltip:AddLine(" ")
  tooltip:AddLine("|cffff66aaSlutmog|r: " .. (it.look or "revealing"), 1, 1, 1, true)
  local info = ns.Price(id)
  if info.low then
    tooltip:AddDoubleLine("Lowest in your last scan", ns.Money(info.low) .. (" |cff999999(%d listed in all)|r"):format(info.qty or 0))
  elseif info.value then
    if info.qty ~= nil then
      tooltip:AddDoubleLine("Not listed in your last scan. Typical lowest price", ns.Money(info.value))
    else
      -- never been through a scan: the price comes from another addon
      tooltip:AddDoubleLine("Typical lowest price (" .. (info.source or "?") .. ")", ns.Money(info.value))
    end
  end
  if it.src == "fishing" then
    tooltip:AddLine(it.srcNote or "Fished up, not a mob drop.", 0.7, 0.9, 0.7, true)
  elseif it.inst then
    tooltip:AddLine("Drops in " .. it.inst .. " (dungeon).", 0.7, 0.9, 0.7, true)
  else
    local spots = ns.SpotsForItem(id, 2)
    if #spots > 0 then
      local lo, hi = ns.MobRange(it)
      local names = {}
      for _, s in ipairs(spots) do
        names[#names + 1] = ns.SpotLabel(s.spot)
      end
      tooltip:AddLine(("Farm (rule of thumb): level %d-%d mobs, e.g. %s"):format(lo, hi, table.concat(names, "; ")), 0.7, 0.9, 0.7, true)
    end
  end
end

-------------------------------------------------------------------------------
-- Events and slash commands
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("AUCTION_HOUSE_SHOW")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
frame:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
frame:RegisterEvent("AUCTION_HOUSE_BROWSE_FAILURE")
frame:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")

frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then
      return
    end
    SlutmogScoutDB = SlutmogScoutDB or {}
    db = SlutmogScoutDB
    db.prices = db.prices or {}
    db.custom = db.custom or {}
    db.hidden = db.hidden or {}
    db.areas = db.areas or {}
    db.dropLvl = db.dropLvl or {}
    db.opts = db.opts or {}
    if db.opts.tooltip == nil then
      db.opts.tooltip = true
    end
    ns.db = db
    ns.RebuildItems()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipItem)
    end
    -- Item data is not ready during loading, so the list check waits a little.
    if C_Timer and C_Timer.After then
      C_Timer.After(8, AutoCheck)
    end
    ns.Fire("LOADED")
    if ns.Kit and ns.Options then            -- options window and minimap button
      local ok, err = pcall(ns.Options.Init)
      if not ok then
        ns.Print("options error: " .. tostring(err))
      end
    end
  elseif not db then
    return
  elseif event == "AUCTION_HOUSE_SHOW" then
    ns.Fire("AH_SHOW")
    -- The auction window can be created after this event, so look again.
    C_Timer.After(1.5, function()
      if not ns.AuctionHouseOpen() then
        return
      end
      ns.Fire("AH_SHOW")
      if db.opts.autoScan and not scan.active and time() - (db.lastScan or 0) > 30 * 60 then
        ns.StartScan()
      end
    end)
  elseif event == "AUCTION_HOUSE_CLOSED" then
    Abort("the auction house was closed.")
    ns.Fire("AH_CLOSED")
  elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
    -- A result the addon cannot read must end the scan at once with nothing
    -- saved, not leave it half-updated until the timeout.
    local ok, err
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
      ok, err = pcall(OnBrowseUpdated)
    else
      ok, err = pcall(OnBrowseAdded, arg1)
    end
    if not ok then
      if scan.active then
        Abort("the auction house sent results this addon could not read. Nothing was saved.")
      else
        error(err, 0) -- the scan itself was over: do not hide the error
      end
    end
  elseif event == "AUCTION_HOUSE_BROWSE_FAILURE" then
    Abort("the auction house refused the search. Wait a few seconds and scan again.")
  elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
    RunPending()
  end
end)

-- Shared by the slash commands and the options window.
function ns.RestoreHidden()
  wipe(db.hidden)
  ns.RebuildItems()
  ns.Print("Removed built-in pieces are back on the list.")
  ns.Fire("ITEMS")
end

function ns.WipePrices()
  wipe(db.prices)
  db.lastScan = nil
  ns.Print("Saved prices cleared.")
  ns.Fire("SCAN")
end

-- Kit.lua and Options.lua are new in 1.2.0. The game only finds new files after a full restart,
-- so right after an update a /reload runs this file without them: say so instead of erroring.
local function HasKit()
  if ns.Kit and ns.Options then return true end
  ns.Print("The options window and the minimap button appear after you restart the game once (this update added new files, and /reload does not load those).")
  return false
end

SLASH_SLUTMOGSCOUT1 = "/smog"
SLASH_SLUTMOGSCOUT2 = "/slutmog"
SlashCmdList.SLUTMOGSCOUT = function(input)
  if not db then
    return
  end
  input = input or ""
  local cmd, rest = input:match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "" or cmd == "show" then
    ns.Toggle()
  elseif cmd == "scan" then
    ns.StartScan()
  elseif cmd == "farm" then
    ns.Toggle("farm", true)
  elseif cmd == "measured" then
    ns.Toggle("measured", true)
  elseif cmd == "add" then
    ns.AddCustom(rest)
  elseif cmd == "remove" then
    ns.RemoveItem(rest)
  elseif cmd == "restore" then
    ns.RestoreHidden()
  elseif cmd == "config" or cmd == "options" or cmd == "opt" then
    if HasKit() then
      ns.Kit.Open()
    end
  elseif cmd == "minimap" then
    if HasKit() then
      ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
      ns.Print("Minimap button: " .. (ns.Kit.MinimapShown() and "on" or "off"))
    end
  elseif cmd == "verify" then
    ns.SelfCheck(true)
  elseif cmd == "selftest" then
    ns.SelfTest()
  elseif cmd == "auto" then
    db.opts.autoScan = not db.opts.autoScan
    ns.Print("Scan when the auction house opens (at most every 30 min): " .. (db.opts.autoScan and "on" or "off"))
  elseif cmd == "tooltip" then
    db.opts.tooltip = not db.opts.tooltip
    ns.Print("Tooltip lines: " .. (db.opts.tooltip and "on" or "off"))
  elseif cmd == "wipe" then
    ns.WipePrices()
  elseif cmd == "clearfarm" then
    if rest:lower() == "yes" then
      ns.ClearMeasured()
    else
      ns.Print("This deletes all measured farm data. Type |cffffff00/smog clearfarm yes|r to do it.")
    end
  else
    ns.Print("Commands:")
    print("  |cffffff00/smog|r  open the window")
    print("  |cffffff00/smog config|r  open the options window")
    print("  |cffffff00/smog minimap|r  show or hide the minimap button")
    print("  |cffffff00/smog scan|r  scan the auction house (it must be open)")
    print("  |cffffff00/smog farm|r  open the farm guide")
    print("  |cffffff00/smog measured|r  open your measured farm results")
    print("  |cffffff00/smog add <item link or id> [note]|r  add your own piece")
    print("  |cffffff00/smog remove <item link or id>|r  take a piece off the list")
    print("  |cffffff00/smog restore|r  bring back removed built-in pieces")
    print("  |cffffff00/smog verify|r  check the built-in list against this game build")
    print("  |cffffff00/smog selftest|r  check that this game has what the addon needs")
    print("  |cffffff00/smog auto|r  toggle scanning when the auction house opens")
    print("  |cffffff00/smog tooltip|r  toggle item tooltip lines")
    print("  |cffffff00/smog wipe|r  clear saved prices")
    print("  |cffffff00/smog clearfarm yes|r  clear measured farm data")
  end
  if ns.Kit then      -- an open options window follows what was typed
    ns.Kit.Sync()
  end
end

-- The addon's line in the list of addons next to the minimap: left-click the window,
-- right-click the options.
function SlutmogScout_OnAddonCompartmentClick(_, mouseButton)
  if not db then
    return
  end
  if mouseButton == "RightButton" and ns.Kit then
    ns.Kit.Open()
  else
    ns.Toggle()
  end
end
