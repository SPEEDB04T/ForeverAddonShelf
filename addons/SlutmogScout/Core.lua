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
-- Written the way the game writes money: white amounts with the gold, silver
-- and copper coin icons (letters in colourblind mode), shortened to gold only
-- from 100 gold up. dim = true gives the amounts in grey (used for prices
-- that are not current).
ns.COIN = {
  g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t",
  s = "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t",
  c = "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
}
local function CoinLetters()
  local ok, on = pcall(function()
    return GetCVarBool and GetCVarBool("colorblindMode")
  end)
  return ok and on == true
end
local function GreyHex()
  return ns.GREY_HEX or "ff808080"
end
function ns.Money(copper, dim)
  if not copper then
    return "|c" .. GreyHex() .. "-|r"
  end
  copper = math.floor(copper + 0.5)
  local g = math.floor(copper / 10000)
  local s = math.floor((copper % 10000) / 100)
  local c = copper % 100
  local letters = CoinLetters()
  local function coin(n, unit)
    return tostring(n) .. (letters and unit or ns.COIN[unit])
  end
  local text
  if g >= 100 then
    text = coin(BreakUpLargeNumbers and BreakUpLargeNumbers(g) or g, "g")
  elseif g > 0 then
    text = coin(g, "g") .. " " .. coin(s, "s")
  elseif s > 0 then
    text = coin(s, "s") .. " " .. coin(c, "c")
  else
    text = coin(c, "c")
  end
  if dim then
    text = "|c" .. GreyHex() .. text .. "|r"
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
local byDisplay = {}          -- display id -> ids on the list with that look

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

local GRADES = { bikini = true, skimpy = true, cropped = true }
ns.GRADES = GRADES

-- " (skimpy)" or " (skimpy, set by you)" for the tooltip line, "" without a grade
function ns.GradeLabel(it)
  return it and it.grade and (" (" .. it.grade .. (it.gradeMine and ", set by you" or "") .. ")") or ""
end

function ns.RebuildItems()
  wipe(items)
  local chk = CheckResult()
  local bad = chk and chk.bad
  -- Names stored by the check are in the language it ran in: after a language
  -- switch the list's own names are used until the check has run again.
  local names = chk and chk.locale == Locale() and type(chk.names) == "table" and chk.names or nil
  local mine = db and type(db.grades) == "table" and db.grades or {}
  for id, it in pairs(ns.ITEMS) do
    it.id = id
    -- a grade the player set with /smog grade wins over the generator's
    if it.genGrade == nil then
      it.genGrade = it.grade or false
    end
    local g = GRADES[mine[id]] and mine[id] or nil
    it.grade, it.gradeMine = g or it.genGrade or nil, g and true or nil
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
        local g = GRADES[mine[id]] and mine[id] or nil
        it.grade, it.gradeMine = g, g and true or nil
        items[id] = it
      end
    end
  end
  -- look-alikes for fair values and the "unique look" rarity reason
  wipe(byDisplay)
  for id, it in pairs(items) do
    if it.display then
      byDisplay[it.display] = byDisplay[it.display] or {}
      table.insert(byDisplay[it.display], id)
    end
  end
  if ns.PricesChanged then
    ns.PricesChanged()
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
    if builtin.grade == "cropped" and not ns.ShowCropped() and not ns.Demanded(id) then
      ns.Print(("%s is a built-in piece with a cropped look, hidden for now: |cffffff00/smog cropped|r or Filter > Show cropped pieces shows it."):format(builtin.name))
      ns.Fire("ITEMS")
      return
    end
    local common = not ns.ShowCommon() and ns.Common(builtin)
    if common then
      ns.Print(("%s is a built-in piece hidden as easy, common gear (%s): |cffffff00/smog common|r or Filter > Show easy, common pieces shows it."):format(builtin.name, common))
      ns.Fire("ITEMS")
      return
    end
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

-- An item on the list from a link, an item ID or its exact name (any case).
function ns.FindListItem(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end
  local id = ItemIDFromLink(text)
  if id then
    return items[id] and id or nil
  end
  local want = text:lower()
  for i, it in pairs(items) do
    if (it.name or ""):lower() == want or (it.listName or ""):lower() == want then
      return i
    end
  end
  return nil
end

-- "/smog grade <item link, ID or name> <bikini|skimpy|cropped|auto>": the
-- player's grade wins over the generator's; auto goes back to it.
function ns.SetGrade(text)
  text = type(text) == "string" and text or ""
  local body, word = text:match("^(.-)%s*(%a+)%s*$")
  word = word and word:lower()
  if not (word and (GRADES[word] or word == "auto")) or (body or "") == "" then
    ns.Print("Usage: |cffffff00/smog grade|r <item link, ID or name> <bikini, skimpy, cropped or auto>")
    return
  end
  local id = ns.FindListItem(body)
  local it = id and items[id]
  if not it then
    ns.Print("That item is not on the list.")
    return
  end
  if type(db.grades) ~= "table" then
    db.grades = {}
  end
  db.grades[id] = word ~= "auto" and word or nil
  ns.RebuildItems()
  ns.PricesChanged()
  if word == "auto" then
    ns.Print(("%s: back to the list's own grade (%s)."):format(it.name, it.grade or "none"))
  else
    ns.Print(("%s is now graded %s by you (the list says %s). |cffffff00/smog grade %d auto|r undoes it."):format(
      it.name, word, it.genGrade or "nothing", id))
  end
  ns.Fire("ITEMS")
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

-------------------------------------------------------------------------------
-- Fair value: what a piece normally sells for, never taken from the very
-- listing it is judged against. Evidence, best first:
--   1. its own lowest prices in earlier scans (the current scan left out)
--   2. the other listings of it right now (a price ladder read after a scan)
--   3. pieces with the same look and armor type, then similar pieces
--      (same armor, slot and quality, level within 5, bare share within 15)
--   4. Auctionator or TradeSkillMaster
-------------------------------------------------------------------------------
local DEAL_RATIO = 0.5        -- underpriced: the lowest price is at most half the fair value
local DEAL_MIN_GAIN = 10000   -- and reselling at fair value earns at least 1 gold after the cut
local RARE_SEEN = 0.3         -- listed in at most 30% of your scans (3 or more) counts as rare
local LADDER_MAX = 8          -- price-ladder searches after one scan
local LADDER_TIMEOUT = 10     -- seconds one price-ladder search may take
ns.DEAL_RATIO = DEAL_RATIO

local peerCache = {}

local function PricesChanged()
  wipe(peerCache)
end
ns.PricesChanged = PricesChanged

-- Recorded lowest prices, newest first. earlierOnly leaves out the current
-- scan's own price, so a piece is never judged against itself.
local function Lows(p, earlierOnly, max)
  local out = {}
  local hist = type(p) == "table" and p.hist
  if type(hist) ~= "table" then
    return out
  end
  local last = #hist
  if earlierOnly and (p.qty or 0) > 0 and last > 0 and type(hist[last]) == "table" and hist[last][1] == p.lastSeen then
    last = last - 1
  end
  for i = last, math.max(1, last - (max or 10) + 1), -1 do
    local v = type(hist[i]) == "table" and Num(hist[i][2]) or nil
    if v and v > 0 then
      out[#out + 1] = v
    end
  end
  return out
end

-- The other listings right now: the middle of the 2nd to 5th cheapest. Only
-- valid for the scan it was read after.
local function LadderValue(p)
  local l = type(p) == "table" and p.ladder
  if type(l) ~= "table" or type(l.prices) ~= "table" or (p.qty or 0) == 0 or l.scan ~= p.lastSeen then
    return nil
  end
  local rest = {}
  for i = 2, math.min(5, #l.prices) do
    local v = Num(l.prices[i])
    if v and v > 0 then
      rest[#rest + 1] = v
    end
  end
  if #rest == 0 then
    return nil
  end
  return Median(rest), #rest
end

local function PeerValue(id, it)
  local hit = peerCache[id]
  if hit then
    return hit.value, hit.basis, hit.n
  end
  local vals, basis = {}, nil
  if it.display then
    for _, pid in ipairs(byDisplay[it.display] or {}) do
      local o = items[pid]
      if pid ~= id and o and o.armor == it.armor then
        local v = Median(Lows(db.prices[pid]))
        if v then
          vals[#vals + 1] = v
        end
      end
    end
    basis = "pieces with the same look"
  end
  if #vals == 0 then
    for pid, o in pairs(items) do
      if pid ~= id and o.armor == it.armor and o.slot == it.slot and (o.q or 2) == (it.q or 2)
          and math.abs((o.req or 0) - (it.req or 0)) <= 5 and math.abs((o.skin or 0) - (it.skin or 0)) <= 15 then
        local v = Median(Lows(db.prices[pid]))
        if v then
          vals[#vals + 1] = v
        end
      end
    end
    basis = "similar pieces"
    if #vals < 3 then
      vals = {}  -- one or two loose look-alikes say too little
    end
  end
  hit = { n = #vals }
  if #vals > 0 then
    hit.value, hit.basis = Median(vals), basis
  end
  peerCache[id] = hit
  return hit.value, hit.basis, hit.n
end

-- Returns a table describing what is known about an item's price.
--   low       lowest price in the last scan (nil when none were listed)
--   qty       items listed in the last scan (nil before any scan)
--   fair      fair value (see above); fairBasis says where it came from,
--             fairN how many prices it rests on, sure "high", "medium" or "low"
--   value     best single estimate of what one sells for: the fair value when it
--             rests on this piece's own prices, else the lowest price now, else
--             the fair value from look-alikes or another addon
--   source    where value came from
--   seenPct   share of scans in which the item was listed at all; scans: how many
function ns.Price(id)
  local p = db.prices[id]
  local info = {}
  if p then
    info.qty = p.qty
    info.low = (p.qty or 0) > 0 and Num(p.min) or nil
    info.lastSeen = p.lastSeen
    info.lastMin = p.lastMin
    info.scans = p.scans
    if (p.scans or 0) > 0 then
      info.seenPct = (p.seen or 0) / p.scans
    end
  end
  local lows = Lows(p, true)
  local fair, basis, n, sure, own
  if #lows > 0 then
    fair, basis, n, own = Median(lows), "your earlier scans", #lows, true
    sure = n >= 3 and "high" or n == 2 and "medium" or "low"
  end
  if not fair or sure == "low" then
    local lv, ln = LadderValue(p)
    if lv then
      fair, basis, n, own = lv, "the other listings now", ln, true
      sure = ln >= 3 and "medium" or "low"
    end
  end
  if not fair and items[id] then
    local pv, pb, pn = PeerValue(id, items[id])
    if pv then
      fair, basis, n = pv, pb, pn
      sure = (pb == "pieces with the same look" and pn >= 2) and "medium" or "low"
    end
  end
  if not fair then
    local ev, src = ExternalPrice(id)
    if ev then
      fair, basis, n, sure = ev, src, 1, "low"
    end
  end
  info.fair, info.fairBasis, info.fairN, info.sure = fair, basis, n, sure
  if own or (fair and not info.low) then
    info.value, info.source = fair, basis
  elseif info.low then
    info.value, info.source = info.low, "last scan"
  end
  return info
end

-- Why a piece is hard to come by. The second return is true when at least one
-- reason is strong; "only N listed now" alone is not, most pieces are scarce.
function ns.Rarity(id, info)
  local it = items[id]
  local why, strong = {}, false
  if not it then
    return why, false
  end
  info = info or ns.Price(id)
  local function add(text, isStrong)
    why[#why + 1] = text
    strong = strong or isStrong
  end
  if (it.q or 2) >= 4 then
    add("epic quality", true)
  elseif (it.q or 2) == 3 then
    add("blue (rare) quality", true)
  end
  if it.inst then
    add("drops only in " .. it.inst, true)
  end
  if info.seenPct and (info.scans or 0) >= 3 and info.seenPct <= RARE_SEEN then
    add(("listed in only %d%% of your scans"):format(math.floor(info.seenPct * 100 + 0.5)), true)
  end
  if it.shared == 1 then
    -- a common green below level 21 is easy to farm: a look of its own is not
    -- enough to call it rare
    add("no other item in the game has its look", (it.q or 2) >= 3 or (it.req or 0) > 20)
  end
  if info.low and info.qty and info.qty <= 2 then
    add(info.qty == 1 and "only one listed now" or "only two listed now", false)
  end
  return why, strong
end

-- A deal: listed now, rare, and its lowest price at most half the fair value.
function ns.Deal(id, info)
  info = info or ns.Price(id)
  local low, fair = info.low, info.fair
  if not ns.Shown(items[id], info) or ns.NoDemand(id, info) then
    return nil
  end
  if not (low and fair) or low > fair * DEAL_RATIO or fair * (1 - AH_CUT) - low < DEAL_MIN_GAIN then
    return nil
  end
  local why, strong = ns.Rarity(id, info)
  if not strong then
    return nil
  end
  return { id = id, under = 1 - low / fair, low = low, fair = fair, sure = info.sure, basis = info.fairBasis, why = why }
end

function ns.Deals()
  local out = {}
  for id in pairs(items) do
    local d = ns.Deal(id)
    if d then
      out[#out + 1] = d
    end
  end
  table.sort(out, function(a, b)
    if a.under ~= b.under then
      return a.under > b.under
    end
    return a.id < b.id
  end)
  return out
end

function ns.NetValue(id)
  local v = ns.Price(id).value
  return v and v * (1 - AH_CUT) or nil
end

-------------------------------------------------------------------------------
-- Look grade and demand. Each built-in piece has a grade: bikini, skimpy or
-- cropped (a top that covers the bust, shorts that cover most of the thigh).
-- Cropped pieces stay out of the Market list, the buys and the farm values
-- unless the player asks for them. Pieces added by the player have no grade.
--
-- Demand: the same browse scan returns every chest and leg piece of these
-- armor types, so the addon keeps the median lowest price of the pieces not on
-- the list, per quality and 5-level band (the "baseline"). A piece whose fair
-- value is barely above that baseline sells like ordinary gear: nobody pays
-- for its look. Off-list pieces listed far above it may be transmog pieces the
-- list misses.
-------------------------------------------------------------------------------
local BASE_KEEP = 5        -- the baseline is the median of the last 5 scans' band medians
local BASE_MIN_ROWS = 5    -- a band needs 5 ordinary pieces in a scan to count
local NO_DEMAND = 1.3      -- a fair value under 1.3 times the baseline: no demand for the look
local NO_DEMAND_SEEN = 3   -- once at least 3 of your scans listed the piece
local OFF_RATIO = 3        -- an off-list piece listed at 3 times its baseline or more
local OFF_KEEP = 30
local OFF_SLOTS = { INVTYPE_CHEST = true, INVTYPE_ROBE = true, INVTYPE_LEGS = true }
ns.NO_DEMAND, ns.NO_DEMAND_SEEN, ns.OFF_RATIO = NO_DEMAND, NO_DEMAND_SEEN, OFF_RATIO

function ns.ShowCropped()
  return db and db.opts and db.opts.showCropped == true or false
end

-- Easy, common pieces: gear players get by the dozen, never worth flipping.
--   a green world drop up to level 30 (every leveler loots them), unless its
--   own prices say it sells for 2 gold or more;
--   any piece your scans list nearly every time for under 2 gold.
-- Blue and epic pieces, dungeon drops and fished pieces are never common by level.
local COMMON_MAX_REQ = 30
local COMMON_FLOOR = 20000
local COMMON_STEADY = 0.8
local COMMON_STEADY_SCANS = 5
ns.COMMON_MAX_REQ, ns.COMMON_FLOOR = COMMON_MAX_REQ, COMMON_FLOOR
local OWN_BASIS = { ["your earlier scans"] = true, ["the other listings now"] = true }

function ns.ShowCommon()
  return db and db.opts and db.opts.showCommon == true or false
end

-- Why the piece counts as easy, common gear, or nil when it does not.
-- info is ns.Price(id); it is looked up when left out.
function ns.Common(it, info)
  if not it or it.custom then
    return nil
  end
  info = info or (it.id and ns.Price(it.id)) or {}
  local own = OWN_BASIS[info.fairBasis] and info.fair or nil
  if own and (own >= COMMON_FLOOR or (it.id and ns.Demanded(it.id, info))) then
    return nil
  end
  if (it.q or 2) <= 2 and not it.inst and it.src ~= "fishing" and (it.req or 0) <= COMMON_MAX_REQ then
    return ("a green world drop of level %d: players levelling there loot them by the dozen"):format(it.req or 0)
  end
  if own and info.seenPct and (info.scans or 0) >= COMMON_STEADY_SCANS and info.seenPct >= COMMON_STEADY then
    return ("listed in %d%% of your scans for under %s"):format(math.floor(info.seenPct * 100 + 0.5), ns.Money(COMMON_FLOOR))
  end
  return nil
end

-- false for a cropped piece while cropped pieces are hidden (unless its prices
-- show demand, see ns.Demanded), and for an easy, common piece while those are
-- hidden. info as in ns.Common.
local DEMAND_SHOW = 2     -- own prices at 2 times ordinary gear or more: demand evidence
local GRADE_CROPPED = 0.85 -- a shown cropped piece without demand evidence scores lower
ns.DEMAND_SHOW, ns.GRADE_CROPPED = DEMAND_SHOW, GRADE_CROPPED
function ns.Shown(it, info)
  if it == nil then
    return false
  end
  if it.grade == "cropped" and not ns.ShowCropped() and not (it.id and ns.Demanded(it.id, info)) then
    return false
  end
  return ns.ShowCommon() or not ns.Common(it, info)
end

local function BandKey(q, req)
  return (q or 2) .. ":" .. math.floor(math.max(1, req or 1) / 5) * 5
end
ns.BandKey = BandKey

local function BandBaseline(key)
  local hist = db and type(db.baseline) == "table" and db.baseline[key]
  if type(hist) ~= "table" then
    return nil
  end
  local vals = {}
  for _, v in ipairs(hist) do
    v = Num(v)
    if v and v > 0 then
      vals[#vals + 1] = v
    end
  end
  return Median(vals)
end

-- What ordinary gear of this quality and level sells for, or nil when the
-- scans have not seen enough of it.
function ns.Baseline(q, req)
  return BandBaseline(BandKey(q, req))
end

-- Fair value divided by the baseline of its band (nil when either is unknown),
-- then the baseline.
function ns.Premium(id, info)
  local it = items[id]
  info = info or ns.Price(id)
  local base = it and it.q and info.fair and ns.Baseline(it.q, it.req)
  if not base then
    return nil
  end
  return info.fair / base, base
end

-- True when the piece has been listed in a few scans and its fair value is
-- barely above ordinary gear of its level.
function ns.NoDemand(id, info)
  local prem = ns.Premium(id, info)
  local p = db and db.prices[id]
  return prem ~= nil and prem < NO_DEMAND and type(p) == "table" and (Num(p.seen) or 0) >= NO_DEMAND_SEEN
end

-- Demand evidence: the piece's own prices put it at DEMAND_SHOW times ordinary
-- gear of its level or more. Returns that ratio, or nil. Such a piece is never
-- hidden or ruled out for its grade: what players pay beats what the textures say.
function ns.Demanded(id, info)
  info = info or ns.Price(id)
  if not OWN_BASIS[info.fairBasis] then
    return nil
  end
  local prem = ns.Premium(id, info)
  return prem and prem >= DEMAND_SHOW and prem or nil
end

local craftedSet
local function Crafted(id)
  if not craftedSet then
    craftedSet = {}
    for _, i in ipairs(ns.CRAFTED or {}) do
      craftedSet[i] = true
    end
  end
  return craftedSet[id] == true
end
ns.Crafted = Crafted

-- name, quality, required level and equip slot from the item cache. Asks the
-- game to load items it does not have yet, so the next scan can use them.
local function CachedFacts(id)
  local ok, name, _, q, _, req, _, _, _, equip = pcall(C_Item.GetItemInfo, id)
  if not ok or type(name) ~= "string" or IsSecret(name) then
    if C_Item.RequestLoadItemDataByID then
      pcall(C_Item.RequestLoadItemDataByID, id)
    end
    return nil
  end
  if type(equip) ~= "string" or IsSecret(equip) then
    equip = nil
  end
  return name, Num(q), Num(req), equip
end

-- Off-list rows of a scan (id -> lowest price) feed the baseline and the
-- off-list hints. Everything listed on the auction house can be traded, so the
-- bind type does not need checking.
local function UpdateBaseline(other, now)
  local bands, rows = {}, {}
  for id, price in pairs(other) do
    if not (ns.ITEMS[id] or db.custom[id]) then
      local name, q, req, equip = CachedFacts(id)
      if name and q and q >= 2 and q <= 4 and equip and OFF_SLOTS[equip] then
        local key = BandKey(q, req)
        bands[key] = bands[key] or {}
        table.insert(bands[key], price)
        rows[#rows + 1] = { id = id, name = name, q = q, req = req, price = price, key = key }
      end
    end
  end
  db.baseline = type(db.baseline) == "table" and db.baseline or {}
  for key, prices in pairs(bands) do
    if #prices >= BASE_MIN_ROWS then
      local hist = type(db.baseline[key]) == "table" and db.baseline[key] or {}
      hist[#hist + 1] = Median(prices)
      while #hist > BASE_KEEP do
        table.remove(hist, 1)
      end
      db.baseline[key] = hist
    end
  end
  local hints = {}
  for _, r in ipairs(rows) do
    local base = BandBaseline(r.key)
    if base and r.price >= base * OFF_RATIO and not Crafted(r.id) then
      r.ratio = r.price / base
      hints[#hints + 1] = r
    end
  end
  table.sort(hints, function(a, b)
    if a.ratio ~= b.ratio then
      return a.ratio > b.ratio
    end
    return a.id < b.id
  end)
  while #hints > OFF_KEEP do
    hints[#hints] = nil
  end
  for _, r in ipairs(hints) do
    r.key = nil
  end
  db.offList = { t = now, list = hints }
  return hints
end
ns.UpdateBaseline = UpdateBaseline

-- Off-list pieces from the last scan that are listed like transmog pieces.
function ns.OffList()
  local list = db and type(db.offList) == "table" and type(db.offList.list) == "table" and db.offList.list or {}
  local out = {}
  for _, r in ipairs(list) do
    if type(r) == "table" and Num(r.id) and not (ns.ITEMS[r.id] or db.custom[r.id]) then
      out[#out + 1] = r
    end
  end
  return out
end

local function ReportOffList(hints, max)
  if #hints == 0 then
    return
  end
  local parts = {}
  for i = 1, math.min(max, #hints) do
    local r = hints[i]
    parts[#parts + 1] = ("%s (%s, %.1f times ordinary gear of its level) |cffffff00/smog add %d|r"):format(r.name,
      ns.Money(r.price), r.ratio, r.id)
  end
  ns.Print(("Not on the list, but priced like %s: %s%s."):format(#hints == 1 and "a transmog piece" or "transmog pieces",
    table.concat(parts, ", "), #hints > max and (" |cffffff00/smog hints|r lists %d more"):format(#hints - max) or ""))
end
ns.ReportOffList = ReportOffList

-------------------------------------------------------------------------------
-- What to buy. One score per listed piece: what reselling it earns after the
-- cut and the deposit, times factors that are each at most 1. More supply,
-- easier farming or more items with the same look only ever lower a factor.
-- Every factor is kept as a plain reason for or against.
-------------------------------------------------------------------------------
local BUY_MIN_GAIN = 10000   -- a buy earns at least 1 gold, also after its risks
local BUY_MARGIN = 1.3       -- buy up to the resale money / 1.3: 30% kept for risk
local DEPOSIT_SHARE = 0.3    -- assumed: a 24-hour listing costs about 30% of the vendor price
local WALL_SHARE = 0.6       -- other listings under 60% of the fair value make a cheap wall
local SURE_MULT = { high = 1, medium = 0.8, low = 0.55 }
ns.BUY_MIN_GAIN, ns.BUY_MARGIN = BUY_MIN_GAIN, BUY_MARGIN

local function Clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function Deposit(id)
  local ok, sell = pcall(function() return (select(11, C_Item.GetItemInfo(id))) end)
  sell = ok and Num(sell) or nil
  return sell and sell > 0 and math.floor(sell * DEPOSIT_SHARE) or 0
end

-- The cheapest listed piece with the same look and armor type, and how many
-- copies with that look are listed besides this piece.
local function SameLookListed(id, it)
  local best, bestLow, count = nil, nil, 0
  for _, pid in ipairs(it.display and byDisplay[it.display] or {}) do
    local o = items[pid]
    if pid ~= id and o and o.armor == it.armor then
      local pinfo = ns.Price(pid)
      if pinfo.low then
        count = count + math.max(1, pinfo.qty or 1)
        if not bestLow or pinfo.low < bestLow then
          best, bestLow = pid, pinfo.low
        end
      end
    end
  end
  return best, bestLow, count
end

local function LadderPrices(p)
  local l = type(p) == "table" and p.ladder
  if type(l) ~= "table" or type(l.prices) ~= "table" or (p.qty or 0) == 0 or l.scan ~= p.lastSeen then
    return nil
  end
  return l.prices
end

-- Average count listed in up to three earlier scans that listed it.
local function EarlierQty(p)
  local hist = type(p) == "table" and p.hist
  if type(hist) ~= "table" then
    return nil
  end
  local last = #hist
  if last > 0 and type(hist[last]) == "table" and hist[last][1] == p.lastSeen then
    last = last - 1
  end
  local sum, n = 0, 0
  for i = last, math.max(1, last - 2), -1 do
    local q = type(hist[i]) == "table" and Num(hist[i][3]) or nil
    if q then
      sum, n = sum + q, n + 1
    end
  end
  return n > 0 and sum / n or nil
end

-- How slowly the piece comes back onto the market, 0 (anyone farms it in
-- minutes) to 1. Higher mob level, blue or better, dungeon-only and a big pool
-- of other drops at its level make it slower; more farm spots and drops you
-- have seen yourself make it faster.
local function FarmHardness(id, it)
  if it.src == "fishing" then
    return 0.6, 0, 0
  end
  local lvl = Clamp(((it.req or 1) - 5) / 50, 0, 1)
  local h = 0.35 * lvl + ((it.q or 2) >= 3 and 0.2 or 0) + 0.25 * Clamp((it.pool or 200) / 400, 0, 1)
    + (it.inst and 0.2 or 0)
  local spots = #ns.SpotsForItem(id)
  h = h - 0.04 * math.max(0, math.min(spots, 6) - 2)
  local seen = db and db.dropLvl and db.dropLvl[id]
  local drops = type(seen) == "table" and Num(seen.n) or 0
  if drops >= 3 then
    h = h * 0.8
  elseif drops >= 1 then
    h = h * 0.9
  end
  return Clamp(h, 0, 1), spots, drops
end

-- Returns nil for pieces not listed now. Otherwise a table:
--   buy       true when it is worth buying; stop says why not (the first hard stop)
--   score     gain times all factors (copper); mult the factors alone
--   upTo      the most to pay for one; count, cost: copies listed at or under it
--   resale    the expected sale price; gain what one earns after the cut and deposit
--   risk      "low", "medium" or "high"; pros, cons: reasons for and against
--   cheaper   { id, low } when a same-look piece is listed under the fair value
--   easyFarm  { lo, hi, spot } when farming it yourself is quick
function ns.Buy(id, info)
  local it = items[id]
  info = info or ns.Price(id)
  if not (it and info.low) then
    return nil
  end
  local p = db.prices[id]
  local b = { id = id, low = info.low, fair = info.fair, sure = info.sure, basis = info.fairBasis,
    pros = {}, cons = {}, score = 0, mult = 0, buy = false, risk = "high" }
  local function pro(text) b.pros[#b.pros + 1] = text end
  local function con(text) b.cons[#b.cons + 1] = text end
  local function stop(text) b.stop = b.stop or text end
  local alt = type(it.alt) == "table" and it.alt or {}
  local common = not ns.ShowCommon() and ns.Common(it, info)
  local demanded = ns.Demanded(id, info)
  if it.grade == "cropped" and not ns.ShowCropped() and not demanded then
    stop("a cropped look (it covers the bust or most of the thigh), which few buy for slutmog")
  elseif common then
    b.common = common
    stop("easy, common gear (" .. common .. "), not worth flipping")
  elseif (Num(alt.made) or 0) > 0 then
    stop(("a crafted item has the same look (%s), so anyone can have it made"):format(it.altName or "made by a profession"))
  elseif (Num(alt.plain) or 0) > 0 then
    stop(("a white or grey item has the same look (%s), often sold by a vendor"):format(it.altName or "a plain item"))
  end
  if not info.fair then
    stop("no fair value yet: scan a few more times")
    return b
  end
  local prem, base = ns.Premium(id, info)
  b.premium, b.baseline = prem, base
  if prem and prem < NO_DEMAND and (Num(p and p.seen) or 0) >= NO_DEMAND_SEEN then
    b.noDemand = true
    stop(("it sells like ordinary gear of its level (about %s), so nobody pays extra for its look"):format(ns.Money(base)))
  end

  -- resale: the fair value, capped by the cheapest listed piece with the same look
  local cheap, cheapLow, sameN = SameLookListed(id, it)
  local resale = info.fair
  if cheapLow and cheapLow < resale then
    resale = cheapLow
    b.cheaper = { id = cheap, low = cheapLow }
  end
  b.resale, b.deposit = resale, Deposit(id)
  local net = resale * (1 - AH_CUT) - b.deposit
  b.gain = net - info.low
  b.upTo = math.floor(net / BUY_MARGIN)
  if b.gain < BUY_MIN_GAIN then
    local o = b.cheaper and items[b.cheaper.id]
    stop(o and ("%s has the same look and is listed for %s, so this would not sell for more"):format(o.name, ns.Money(b.cheaper.low))
      or "reselling it would earn under 1 gold after the cut and the deposit")
  elseif info.low > b.upTo then
    stop("its price leaves less than 30% of the resale for risk")
  end
  local under = 1 - info.low / info.fair
  if under >= 0.25 then
    pro(("listed %d%% under its fair value"):format(math.floor(under * 100 + 0.5)))
  end
  b.deal = ns.Deal(id, info) ~= nil

  -- confidence of the fair value
  local c = SURE_MULT[info.sure] or SURE_MULT.low
  if info.sure == "high" then
    pro(("its fair value rests on %d of your scans"):format(info.fairN or 3))
  else
    con(("its fair value is a %s guess, from %s"):format(info.sure == "medium" and "fair" or "rough", info.fairBasis or "little data"))
  end

  -- supply: this piece and its look
  local qty = math.max(1, info.qty or 1)
  local s = qty == 1 and 1 or qty == 2 and 0.9 or qty <= 4 and 0.75 or 0.6
  if qty == 1 then
    pro("it is the only one listed")
  elseif qty >= 3 then
    con(("%d are listed: you compete with the others"):format(qty))
  end
  local prices = LadderPrices(p)
  if prices then
    local wall = 0
    for i = 2, #prices do
      local v = Num(prices[i])
      if v and v <= info.fair * WALL_SHARE then
        wall = wall + 1
      end
    end
    if wall > 0 then
      s = s * math.max(0.5, 0.85 ^ wall)
      con(("%d more %s listed under %d%% of its fair value: the price may be falling"):format(wall,
        wall == 1 and "is" or "are", WALL_SHARE * 100))
    end
  end
  local before = EarlierQty(p)
  if before and qty >= before * 1.5 and qty >= before + 2 then
    s = s * 0.85
    con(("more are listed than in your earlier scans (%d, about %d before)"):format(qty, math.floor(before + 0.5)))
  elseif before and qty < before then
    pro(("fewer are listed than in your earlier scans (%d, about %d before): some may have sold"):format(qty, math.floor(before + 0.5)))
  end
  if sameN > 0 then
    s = s * math.max(0.5, 1 / (1 + 0.25 * sameN))
    con(("%d more with the same look %s listed"):format(sameN, sameN == 1 and "is" or "are"))
  end
  if info.seenPct and (info.scans or 0) >= 5 and info.seenPct >= 0.8 then
    s = s * 0.85
    con(("listed in %d%% of your scans: a steady supply"):format(math.floor(info.seenPct * 100 + 0.5)))
  elseif info.seenPct and (info.scans or 0) >= 3 and info.seenPct <= RARE_SEEN then
    pro(("listed in only %d%% of your scans"):format(math.floor(info.seenPct * 100 + 0.5)))
  end

  -- how quickly farmers bring more
  local h, spots, drops = FarmHardness(id, it)
  local f = 0.55 + 0.45 * h
  local lo, hi = ns.MobRange(it)
  if it.src == "fishing" then
    pro("it is fished up, not dropped by mobs")
  elseif h >= 0.65 then
    pro(it.inst and ("slow to farm: it drops only in %s"):format(it.inst)
      or ("slow to farm: level %d-%d mobs, one of about %d drops at that level"):format(lo, hi, it.pool or 200))
  elseif h < 0.35 then
    local spot = ns.SpotsForItem(id, 1)[1]
    b.easyFarm = { lo = lo, hi = hi, spot = spot and ns.SpotLabel(spot.spot) }
    con(("easy to farm: level %d-%d mobs%s"):format(lo, hi, b.easyFarm.spot and (", e.g. " .. b.easyFarm.spot) or ""))
  end
  if drops > 0 then
    con(("it has dropped %d %s for you"):format(drops, drops == 1 and "time" or "times"))
  end

  -- other items with the same look
  local bop, boe = Num(alt.bop) or 0, Num(alt.boe) or 0
  local o = math.max(0.6, 0.9 ^ boe) * math.max(0.7, 0.9 ^ bop)
  if it.shared == 1 then
    pro("no other item in the game has its look")
  end
  if boe > 0 then
    con(("%d other BoE %s the same look"):format(boe, boe == 1 and "item has" or "items have"))
  end
  if bop > 0 then
    con(("%d bind-on-pickup %s the same look, so some players get it themselves"):format(bop, bop == 1 and "item has" or "items have"))
  end

  -- demand for the look: what it sells for next to ordinary gear of its level
  local d = 1
  if prem then
    d = Clamp(0.4 + 0.2 * prem, 0.6, 1)
    if prem >= 2 then
      pro(("it sells for %.1f times ordinary gear of its level"):format(prem))
    else
      con(("it sells for only %.1f times ordinary gear of its level (%s)"):format(prem, ns.Money(base)))
    end
  end

  -- the grade only lowers the score, and only without demand evidence
  local g = 1
  if it.grade == "cropped" then
    if demanded then
      pro(("a cropped look, but it sells for %.1f times ordinary gear of its level"):format(demanded))
    else
      g = GRADE_CROPPED
      con("a cropped look: fewer players buy it for slutmog")
    end
  end

  b.factors = { sure = c, supply = s, farm = f, look = o, demand = d, grade = g }
  b.mult = c * s * f * o * d * g
  b.score = math.max(0, b.gain) * b.mult
  b.risk = b.mult >= 0.5 and "low" or b.mult >= 0.3 and "medium" or "high"
  if not b.stop and b.score < BUY_MIN_GAIN then
    stop(("the gain is too small for its risks (about %s once they are counted)"):format(ns.Money(math.floor(b.score))))
  end
  b.count, b.cost = 1, info.low
  if prices then
    local n, cost = 0, 0
    for _, v in ipairs(prices) do
      v = Num(v)
      if v and v <= b.upTo then
        n, cost = n + 1, cost + v
      end
    end
    if n > 0 then
      b.count, b.cost = n, cost
    end
  end
  b.buy = not b.stop
  return b
end

-- Pieces worth buying now, best score first.
function ns.BuyList()
  local out = {}
  for id in pairs(items) do
    local b = ns.Buy(id)
    if b and b.buy then
      out[#out + 1] = b
    end
  end
  table.sort(out, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.id < b.id
  end)
  return out
end

-------------------------------------------------------------------------------
-- Auction house scan (browse query limited to the armor types/slots on the list)
-------------------------------------------------------------------------------
local scan = { active = false, rows = 0, pages = 0 }
ns.scan = scan
local StartLadder, StopLadder -- the price ladder read after a scan, below
local ladder = {}

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
  wipe(ladder.keys)
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
          ladder.keys[id] = f.key
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
  local hints = UpdateBaseline(scan.other or {}, now)
  ns.Print(("Scan done: %d of %d tracked pieces are listed right now (%d search results read).%s"):format(listed, total, scan.rows,
    skipped > 0 and (" %d could not be read and kept their earlier data."):format(skipped) or ""))
  ReportOffList(hints, 3)
  PricesChanged()
  ns.Fire("SCAN")
  StartLadder()
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
            -- the cheapest variant's key: a random-suffix piece ("of the Monkey")
            -- is only found again with its suffix
            f.key = { itemID = id, itemLevel = Num(key.itemLevel) or 0, itemSuffix = Num(key.itemSuffix) or 0,
              battlePetSpeciesID = 0 }
          end
        end
      elseif id and scan.other then
        -- not on the list: kept for the baseline of ordinary gear
        local price, qty = Num(r.minPrice), Num(r.totalQuantity)
        if price and price > 0 and qty and qty > 0 and (not scan.other[id] or price < scan.other[id]) then
          scan.other[id] = price
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
  StopLadder(false)
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
  scan.other = {}
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
-- Price ladder: after a scan, the auction house's per-item search reads the
-- other listings of a few pieces that may be deals, so their fair value does
-- not rest on look-alikes alone. One search at a time, throttled, at most
-- LADDER_MAX per scan, each field read through Num().
-------------------------------------------------------------------------------
ladder.queue, ladder.keys, ladder.active = {}, {}, false
ns.ladder = ladder

local function LadderApiPresent()
  local ah = C_AuctionHouse
  return (ah and ah.SendSearchQuery and ah.MakeItemKey and ah.GetNumItemSearchResults
    and ah.GetItemSearchResultInfo and ah.IsThrottledMessageSystemReady) and true or false
end
ns.LadderApiPresent = LadderApiPresent

-- First cut: listed now with another copy beside it, no fair value from its
-- own earlier prices that is sure enough already, and no crafted or plain item
-- with the same look (those are never worth buying, whatever the price).
local function LadderCandidates()
  local list = {}
  for id, it in pairs(items) do
    local info = ns.Price(id)
    local alt = type(it.alt) == "table" and it.alt or {}
    if info.low and (info.qty or 0) >= 2 and not (info.fairBasis == "your earlier scans" and info.sure ~= "low")
        and (Num(alt.made) or 0) == 0 and (Num(alt.plain) or 0) == 0 and ns.Shown(it, info) and not ns.NoDemand(id, info) then
      list[#list + 1] = { id = id, r = info.fair and info.low / info.fair or 1 }
    end
  end
  table.sort(list, function(a, b)
    if a.r ~= b.r then
      return a.r < b.r
    end
    return a.id < b.id
  end)
  local out = {}
  for i = 1, math.min(LADDER_MAX, #list) do
    out[i] = list[i].id
  end
  return out
end

local function ReportDeals()
  local buys = ns.BuyList()
  if #buys == 0 then
    return
  end
  local parts = {}
  for i = 1, math.min(3, #buys) do
    local b = buys[i]
    local it = items[b.id]
    parts[#parts + 1] = ("%s up to %s (resale %s, %s risk)"):format(it and it.name or ("item " .. b.id), ns.Money(b.upTo),
      ns.Money(b.resale), b.risk)
  end
  ns.Print(("%d %s worth buying: %s%s. The Market list's Filter > Worth buying lists %s, best first."):format(#buys,
    #buys == 1 and "piece looks" or "pieces look", table.concat(parts, ", "),
    #buys > 3 and (" and %d more"):format(#buys - 3) or "", #buys == 1 and "it" or "them"))
end

StopLadder = function(report)
  if ladder.ticker then
    ladder.ticker:Cancel()
    ladder.ticker = nil
  end
  local was = ladder.active
  ladder.active, ladder.current, ladder.key = false, nil, nil
  wipe(ladder.queue)
  if was then
    PricesChanged()
    ns.Fire("SCAN")
  end
  if report and was then
    ReportDeals()
  end
end

local function LadderStep()
  if not ladder.active then
    return
  end
  if ladder.current then
    if GetTime() - ladder.sentAt <= LADDER_TIMEOUT then
      return
    end
    ladder.current = nil -- no answer for this piece: go on with the next
  end
  if #ladder.queue == 0 then
    StopLadder(true)
    return
  end
  local okReady, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
  if not okReady or IsSecret(ready) or not ready then
    return
  end
  local id = table.remove(ladder.queue, 1)
  local okKey, key = true, ladder.keys[id]
  if not key then
    okKey, key = pcall(C_AuctionHouse.MakeItemKey, id)
  end
  if not okKey or type(key) ~= "table" then
    StopLadder(true)
    return
  end
  ladder.current, ladder.key, ladder.sentAt = id, key, GetTime()
  local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
  if not pcall(C_AuctionHouse.SendSearchQuery, key, sorts, false) then
    StopLadder(true)
  end
end
ns.LadderStep = LadderStep

local function Field(t, k)
  local ok, v = pcall(function() return t[k] end)
  return ok and Num(v) or nil
end

local function OnLadderResults(itemKey)
  if not (ladder.active and ladder.current) then
    return
  end
  if (type(itemKey) == "table" and Field(itemKey, "itemID")) ~= ladder.current then
    return -- the player's own search, not ours
  end
  local id, key = ladder.current, ladder.key
  local okN, n = pcall(C_AuctionHouse.GetNumItemSearchResults, key)
  n = okN and Num(n) or 0
  local prices = {}
  for i = 1, math.min(n, 10) do
    local ok, r = pcall(C_AuctionHouse.GetItemSearchResultInfo, key, i)
    if ok and type(r) == "table" then
      local buy, qty = Field(r, "buyoutAmount"), Field(r, "quantity")
      if buy and buy > 0 and (qty == nil or qty == 1) then
        prices[#prices + 1] = buy
      end
    end
  end
  table.sort(prices)
  local p = db.prices[id]
  if p and #prices > 0 then
    p.ladder = { scan = p.lastSeen, t = time(), prices = prices }
  end
  ladder.current = nil
  PricesChanged()
  LadderStep()
end

StartLadder = function()
  StopLadder(false)
  if not (LadderApiPresent() and ns.AuctionHouseOpen() and C_Timer and C_Timer.NewTicker) then
    ReportDeals()
    return
  end
  for _, id in ipairs(LadderCandidates()) do
    ladder.queue[#ladder.queue + 1] = id
  end
  if #ladder.queue == 0 then
    ReportDeals()
    return
  end
  ladder.active = true
  ladder.ticker = C_Timer.NewTicker(0.5, LadderStep)
  ns.Fire("SCAN")
  LadderStep()
end

-------------------------------------------------------------------------------
-- Buying from the list. The Buy button searches the piece's listings; the
-- game's own confirm popup then names the cheapest copy, its price and what
-- the piece is worth paying, and its Buy button places the buyout. Nothing is
-- bought without that click.
-------------------------------------------------------------------------------
local PURCHASE_TIMEOUT = 10   -- seconds the listing search may take
local PURCHASE_MAX = 50       -- listings read to find the cheapest
local purchase = {}           -- id, key, sentAt: a search is out; offer: the popup is up; placed: bought, not confirmed
ns.purchase = purchase

local function PurchaseApiPresent()
  return LadderApiPresent() and C_AuctionHouse.PlaceBid ~= nil
end
ns.PurchaseApiPresent = PurchaseApiPresent

local function Flag(t, k)
  local ok, v = pcall(function() return t[k] end)
  return ok and v == true
end

-- Starts buying one piece: false (with a chat line) when it cannot start now.
function ns.StartPurchase(id)
  local it = items[id]
  if not it then
    ns.Print("That item is not on the list.")
    return false
  end
  if not ns.AuctionHouseOpen() then
    ns.Print(("Open the auction house to buy %s."):format(it.name))
    return false
  end
  if not PurchaseApiPresent() then
    ns.Print("This game client does not let addons buy. Right-click the piece in the list to search for it in the auction house.")
    return false
  end
  if ns.scan and ns.scan.active then
    ns.Print("A scan is running. Buy again when it is done.")
    return false
  end
  if ladder.active then
    ns.Print("Still reading listings after the scan. Buy again in a few seconds.")
    return false
  end
  local okReady, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
  if not okReady or IsSecret(ready) or not ready then
    ns.Print("The auction house is busy. Click Buy again in a moment.")
    return false
  end
  local key = ladder.keys[id] -- the listed variant's key, with its suffix
  if not key then
    local ok, k = pcall(C_AuctionHouse.MakeItemKey, id)
    key = ok and type(k) == "table" and k or nil
  end
  if not key then
    ns.Print(("Could not search for %s."):format(it.name))
    return false
  end
  if StaticPopup_Hide then
    pcall(StaticPopup_Hide, "SLUTMOGSCOUT_BUY")
  end
  purchase.id, purchase.key, purchase.sentAt, purchase.offer = id, key, GetTime(), nil
  local sorts = { { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false } }
  if not pcall(C_AuctionHouse.SendSearchQuery, key, sorts, false) then
    purchase.id = nil
    ns.Print(("The auction house refused the search for %s. Try again in a moment."):format(it.name))
    return false
  end
  return true
end

-- What the confirm popup says about the price, from the buy score.
local function PurchaseNote(id, price)
  local info = ns.Price(id)
  local b = info.low and ns.Buy(id, info)
  if not b then
    return nil
  end
  if b.buy then
    if price <= b.upTo then
      return ("Worth buying: pay at most %s (resale about %s)."):format(ns.Money(b.upTo), ns.Money(b.resale))
    end
    return ("|cffff2020More than the %s it is worth paying.|r"):format(ns.Money(b.upTo))
  end
  return b.stop and ("|cffff2020Not worth buying:|r %s."):format(b.stop) or nil
end

local function ShowPurchasePopup(text)
  if not (StaticPopupDialogs and StaticPopup_Show) then
    return false
  end
  if not StaticPopupDialogs.SLUTMOGSCOUT_BUY then
    StaticPopupDialogs.SLUTMOGSCOUT_BUY = {
      text = "%s",
      button1 = BUY or "Buy",
      button2 = CANCEL or "Cancel",
      OnAccept = function() ns.ConfirmPurchase() end,
      OnCancel = function() purchase.offer = nil end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
      preferredIndex = 3,
    }
  end
  return StaticPopup_Show("SLUTMOGSCOUT_BUY", text) ~= nil
end

-- true when the results were this addon's purchase search
local function OnPurchaseResults(itemKey)
  if not purchase.id or (type(itemKey) == "table" and Field(itemKey, "itemID")) ~= purchase.id then
    return false
  end
  local id, key = purchase.id, purchase.key
  purchase.id = nil
  if GetTime() - (purchase.sentAt or 0) > PURCHASE_TIMEOUT then
    return true -- an answer that came too late: the player has moved on
  end
  local it = items[id]
  local okN, n = pcall(C_AuctionHouse.GetNumItemSearchResults, key)
  n = okN and not IsSecret(n) and Num(n) or 0
  local offers = {}
  for i = 1, math.min(n, PURCHASE_MAX) do
    local ok, r = pcall(C_AuctionHouse.GetItemSearchResultInfo, key, i)
    if ok and type(r) == "table" then
      local buy, qty, auction = Field(r, "buyoutAmount"), Field(r, "quantity"), Field(r, "auctionID")
      if buy and buy > 0 and auction and (qty == nil or qty == 1)
          and not Flag(r, "containsOwnerItem") and not Flag(r, "containsAccountItem") then
        offers[#offers + 1] = { auction = auction, price = buy }
      end
    end
  end
  table.sort(offers, function(a, b) return a.price < b.price end)
  local name = it and it.name or ("item " .. id)
  if #offers == 0 then
    ns.Print(("No copy of %s can be bought out right now: none is listed with a buyout, or only yours are."):format(name))
    return true
  end
  local best = offers[1]
  local okLink, _, link = pcall(C_Item.GetItemInfo, id)
  if not okLink or type(link) ~= "string" or IsSecret(link) then
    link = name
  end
  purchase.offer = { id = id, auction = best.auction, price = best.price, nextPrice = offers[2] and offers[2].price, count = #offers }
  local note = PurchaseNote(id, best.price)
  local text = ("Buy %s for %s?\n%s"):format(link, ns.Money(best.price),
    #offers == 1 and "The only copy you can buy." or ("The cheapest of %d you can buy; the next costs %s."):format(#offers, ns.Money(offers[2].price)))
  if note then
    text = text .. "\n\n" .. note
  end
  if not ShowPurchasePopup(text) then
    purchase.offer = nil
    ns.Print(("Cheapest %s: %s. The confirm window could not open, so nothing was bought."):format(name, ns.Money(best.price)))
  end
  return true
end

-- The popup's Buy button: places the buyout for the offered copy.
function ns.ConfirmPurchase()
  local o = purchase.offer
  purchase.offer = nil
  if not o then
    return false
  end
  local it = items[o.id]
  local name = it and it.name or ("item " .. o.id)
  if not ns.AuctionHouseOpen() then
    ns.Print("The auction house is closed: nothing was bought.")
    return false
  end
  if not pcall(C_AuctionHouse.PlaceBid, o.auction, o.price) then
    ns.Print(("The game refused to buy %s. Nothing was bought."):format(name))
    return false
  end
  purchase.placed = o
  ns.Print(("Buying %s for %s..."):format(name, ns.Money(o.price)))
  return true
end

-- The game confirmed a purchase: one copy fewer is listed, the next is the cheapest.
local function OnPurchaseCompleted(auctionID)
  local o = purchase.placed
  if not o or (auctionID ~= nil and Num(auctionID) ~= o.auction) then
    return
  end
  purchase.placed = nil
  local p = db.prices[o.id]
  if type(p) == "table" and (Num(p.qty) or 0) > 0 then
    p.qty = p.qty - 1
    if p.qty > 0 and o.nextPrice then
      p.min = o.nextPrice
    end
  end
  local it = items[o.id]
  ns.Print(("Bought %s for %s."):format(it and it.name or ("item " .. o.id), ns.Money(o.price)))
  PricesChanged()
  ns.Fire("SCAN")
end
ns.OnPurchaseCompleted = OnPurchaseCompleted

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
  -- cropped and easy, common pieces (while hidden) and pieces nobody pays
  -- extra for do not count; each piece is priced once, not once per spot
  local counted = {}
  for id, it in pairs(items) do
    if not filter or filter(it) then
      local info = ns.Price(id)
      if ns.Shown(it, info) and not ns.NoDemand(id, info) then
        counted[#counted + 1] = { id = id, it = it, value = info.value and info.value * (1 - AH_CUT) or nil }
      end
    end
  end
  for _, spot in ipairs(ns.SPOTS) do
    local entry = { spot = spot, total = 0, priced = 0, pieces = {} }
    for _, c in ipairs(counted) do
      local id, it = c.id, c.it
      do
        local m = SpotMatch(spot, it)
        if m > 0 then
          local v = c.value
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
  need(ah.SendSearchQuery and ah.MakeItemKey, "C_AuctionHouse.SendSearchQuery / MakeItemKey",
    "reading a piece's other listings for its fair value")
  need(ah.GetNumItemSearchResults and ah.GetItemSearchResultInfo, "C_AuctionHouse.GetNumItemSearchResults / GetItemSearchResultInfo",
    "reading a piece's other listings for its fair value")
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
  tooltip:AddLine("|cffff66aaSlutmog|r" .. ns.GradeLabel(it) .. ": " .. (it.look or "revealing"),
    1, 1, 1, true)
  local info = ns.Price(id)
  if info.low then
    tooltip:AddDoubleLine("Lowest in your last scan", ns.Money(info.low) .. (" |c%s(%d listed in all)|r"):format(GreyHex(), info.qty or 0))
    local b = ns.Buy(id, info)
    if b and b.buy then
      tooltip:AddDoubleLine(("Worth buying up to %s (%s risk)"):format(ns.Money(b.upTo), b.risk), "resale " .. ns.Money(b.resale))
    elseif b and b.stop then
      local g = GRAY_FONT_COLOR
      tooltip:AddLine("Not worth buying: " .. b.stop .. ".", g and g.r or 0.5, g and g.g or 0.5, g and g.b or 0.5, true)
    end
    if b and b.cheaper and items[b.cheaper.id] then
      tooltip:AddDoubleLine("Same look, cheaper: " .. items[b.cheaper.id].name, ns.Money(b.cheaper.low))
    end
  elseif info.value then
    if info.qty ~= nil then
      tooltip:AddDoubleLine("Not listed in your last scan. Fair value", ns.Money(info.value))
    else
      -- never been through a scan: the price comes from another addon
      tooltip:AddDoubleLine("Fair value (" .. (info.source or "?") .. ")", ns.Money(info.value))
    end
  end
  if it.src == "fishing" then
    tooltip:AddLine(it.srcNote or "Fished up, not a mob drop.", 1, 1, 1, true)
  elseif it.inst then
    tooltip:AddLine("Drops in " .. it.inst .. " (dungeon).", 1, 1, 1, true)
  else
    local spots = ns.SpotsForItem(id, 2)
    if #spots > 0 then
      local lo, hi = ns.MobRange(it)
      local names = {}
      for _, s in ipairs(spots) do
        names[#names + 1] = ns.SpotLabel(s.spot)
      end
      tooltip:AddLine(("Farm (rule of thumb): level %d-%d mobs, e.g. %s"):format(lo, hi, table.concat(names, "; ")), 1, 1, 1, true)
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
frame:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
pcall(frame.RegisterEvent, frame, "AUCTION_HOUSE_PURCHASE_COMPLETED") -- not in every client
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
    StopLadder(true)
    purchase.id, purchase.offer = nil, nil
    if StaticPopup_Hide then
      pcall(StaticPopup_Hide, "SLUTMOGSCOUT_BUY")
    end
    ns.Fire("AH_CLOSED")
  elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
    pcall(OnPurchaseCompleted, arg1)
  elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
    local okP, mine = pcall(OnPurchaseResults, arg1)
    if not okP then
      purchase.id, purchase.offer = nil, nil
      ns.Print("Could not read the listings, so nothing was bought.")
    elseif mine then
      return
    end
    if ladder.active and not pcall(OnLadderResults, arg1) then
      StopLadder(true) -- results this addon cannot read: keep what was read so far
    end
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
    LadderStep()
  end
end)

-- Shared by the slash commands and the options window.
function ns.RestoreHidden()
  wipe(db.hidden)
  ns.RebuildItems()
  ns.Print("Removed built-in pieces are back on the list.")
  ns.Fire("ITEMS")
end

function ns.SetShowCropped(on)
  db.opts.showCropped = on and true or nil
  PricesChanged()
  ns.Fire("ITEMS")
end

function ns.SetShowCommon(on)
  db.opts.showCommon = on and true or nil
  PricesChanged()
  ns.Fire("ITEMS")
end

function ns.WipePrices()
  wipe(db.prices)
  db.lastScan = nil
  PricesChanged()
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
  elseif cmd == "hints" then
    local hints = ns.OffList()
    if #hints == 0 then
      ns.Print("Your last scan found no piece off the list that is priced like a transmog piece.")
    else
      ReportOffList(hints, 10)
    end
  elseif cmd == "cropped" then
    ns.SetShowCropped(not ns.ShowCropped())
    ns.Print("Cropped pieces (tops that cover the bust, shorts that cover most of the thigh): "
      .. (ns.ShowCropped() and "shown" or "hidden"))
  elseif cmd == "grade" then
    ns.SetGrade(rest)
  elseif cmd == "buy" then
    local id = ns.FindListItem(rest)
    if id then
      ns.StartPurchase(id)
    else
      ns.Print("Usage: |cffffff00/smog buy|r <item link, ID or name of a piece on the list>")
    end
  elseif cmd == "common" then
    ns.SetShowCommon(not ns.ShowCommon())
    ns.Print(("Easy, common pieces (green world drops up to level %d, pieces always listed for under %s): %s"):format(
      COMMON_MAX_REQ, ns.Money(COMMON_FLOOR), ns.ShowCommon() and "shown" or "hidden"))
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
    print("  |cffffff00/smog cropped|r  show or hide cropped pieces")
    print("  |cffffff00/smog buy|r <item>  find the cheapest copy listed and ask to buy it")
    print("  |cffffff00/smog grade|r <item> <bikini, skimpy, cropped or auto>  set a piece's grade yourself")
    print("  |cffffff00/smog common|r  show or hide easy, common pieces (low-level greens, cheap pieces always listed)")
    print("  |cffffff00/smog hints|r  pieces off the list that are priced like transmog pieces")
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
