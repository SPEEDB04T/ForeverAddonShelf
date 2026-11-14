-- Slutmog Scout: window (Market, Farm guide and Measured tabs) and the auction house button
local ADDON, ns = ...

local QUALITY_HEX = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }
local ARMOR_ORDER = { "all", "cloth", "leather", "mail", "plate" }
local ARMOR_LABEL = { all = "All", cloth = "Cloth", leather = "Leather", mail = "Mail", plate = "Plate", other = "Other" }
local SLOT_LABEL = { chest = "chest", legs = "legs", shoulder = "shoulders", waist = "belt", hands = "gloves", feet = "boots", head = "head", wrist = "bracers", back = "cloak", other = "" }

local ROW_H = 20
local FARM_ROW_H = 38
local LIST_TOP = -34          -- farm and measured lists start below a two-line header
local COLS = {
  { key = "name", label = "Item", width = 206, align = "LEFT" },
  { key = "type", label = "Type", width = 92, align = "LEFT" },
  { key = "look", label = "Look", width = 198, align = "LEFT",
    tip = "Measured from the item's texture: how much of the torso or legs it leaves bare." },
  { key = "low", label = "Lowest", width = 84, align = "RIGHT", numeric = true,
    tip = "Lowest price on the auction house in your last scan." },
  { key = "qty", label = "Qty", width = 36, align = "RIGHT", numeric = true,
    tip = "How many are on the auction house in your last scan." },
  { key = "value", label = "Typical low", width = 84, align = "RIGHT", numeric = true,
    tip = "Typical lowest price: the middle value of the lowest prices in your last 10 scans that had the piece. Grey when it is not listed right now. Before your first scan it comes from Auctionator or TradeSkillMaster if you have one." },
  { key = "seen", label = "Seen %", width = 52, align = "RIGHT", numeric = true,
    tip = "Share of your scans in which the piece was listed at all." },
  { key = "mob", label = "Mob lvl", width = 58, align = "RIGHT", numeric = true,
    tip = "Level of the mobs it is expected to drop from. A rule of thumb (required level to required level + 5), widened by drops you measured yourself." },
}
local COL_GAP = 8
local ICON_W = 20

local state = { tab = "market", armor = "all", listedOnly = false, sortKey = "value", sortAsc = false, farmItem = nil }
local win, marketView, farmView, measuredView, statusText, scanButton, farmHeader, farmClear, listedCheck, listedText
local tabButtons, armorButtons, headerText = {}, {}, {}

local function ItemName(id, it)
  it = it or ns.ITEMS[id] or (ns.db.custom[id]) or {}
  return ("|c%s%s|r"):format(QUALITY_HEX[it.q or 2] or QUALITY_HEX[2], it.name or ("Item " .. id))
end

local function ItemIcon(id)
  local _, _, _, _, icon = C_Item.GetItemInfoInstant(id)
  return icon or 134400
end

local function Ago(t)
  if not t or t == 0 then
    return "never"
  end
  local d = time() - t
  if d < 90 then
    return "just now"
  elseif d < 5400 then
    return ("%d min ago"):format(math.floor(d / 60))
  elseif d < 172800 then
    return ("%d h ago"):format(math.floor(d / 3600))
  end
  return ("%d days ago"):format(math.floor(d / 86400))
end

local function Dur(secs)
  secs = math.floor(secs or 0)
  if secs < 60 then
    return "under a minute"
  end
  local m = math.floor(secs / 60)
  if m < 60 then
    return m .. " min"
  end
  return ("%d h %d min"):format(math.floor(m / 60), m % 60)
end

local function Pct(x)
  return math.floor(x * 100 + 0.5)
end

local function TypeLabel(it)
  local slot = SLOT_LABEL[it.slot] or it.slot or ""
  return (ARMOR_LABEL[it.armor] or "") .. (slot ~= "" and (" " .. slot) or "")
end

local function ArmorFilter(it)
  return state.armor == "all" or it.armor == state.armor
end

local function SortedCounts(map)
  local list = {}
  for name, n in pairs(map) do
    list[#list + 1] = { name = name, n = n }
  end
  table.sort(list, function(a, b)
    if a.n ~= b.n then
      return a.n > b.n
    end
    return tostring(a.name) < tostring(b.name)
  end)
  return list
end

-------------------------------------------------------------------------------
-- Tooltips and clicks
-------------------------------------------------------------------------------
-- The addon's own lines for an item, written into the tooltip of a window row.
-- Called from the tooltip hook in Core.lua (so the lines survive the game
-- redrawing the tooltip) and directly when that hook did not run.
function ns.FillItemTooltip(tip, id)
  local it = ns.Items()[id]
  if not it then
    return
  end
  local info = ns.Price(id)
  tip:AddLine(" ")
  tip:AddLine("|cffff66aaSlutmog|r: " .. (it.look or "revealing"), 1, 1, 1, true)
  if info.low then
    tip:AddDoubleLine("Lowest in your last scan", ns.Money(info.low) .. (" |cff999999(%d listed in all)|r"):format(info.qty or 0), 1, 0.82, 0, 1, 1, 1)
  end
  if info.value then
    tip:AddDoubleLine("Typical lowest price (" .. (info.source or "?") .. ")", ns.Money(info.value, not info.low), 1, 0.82, 0, 1, 1, 1)
  else
    tip:AddLine("No price yet. Scan at the auction house.", 0.6, 0.6, 0.6)
  end
  if info.seenPct then
    tip:AddDoubleLine("Listed in", ("%d%% of your scans"):format(Pct(info.seenPct)), 1, 0.82, 0, 1, 1, 1)
  end
  if not info.low and info.lastSeen then
    tip:AddDoubleLine("Last seen", Ago(info.lastSeen) .. " at " .. ns.Money(info.lastMin), 1, 0.82, 0, 1, 1, 1)
  end
  tip:AddLine(" ")
  if it.src == "fishing" then
    tip:AddLine(it.srcNote or "Fished up, not a mob drop.", 0.7, 0.9, 0.7, true)
  else
    local spots = ns.SpotsForItem(id, 5)
    local lo, hi, measured = ns.MobRange(it)
    if it.inst then
      tip:AddLine("Drops in " .. it.inst .. " (dungeon).", 0.7, 0.9, 0.7, true)
    elseif measured then
      tip:AddLine(("Level %d-%d mobs (rule of thumb, widened by your own drops). Best level matches:"):format(lo, hi), 0.7, 0.9, 0.7, true)
    else
      tip:AddLine(("Probably a world drop from about level %d-%d mobs (rule of thumb). Best level matches:"):format(lo, hi), 0.7, 0.9, 0.7, true)
    end
    for _, s in ipairs(spots) do
      tip:AddDoubleLine("  " .. ns.SpotLabel(s.spot), ("%d-%d"):format(s.spot.lo, s.spot.hi), 1, 1, 1, 0.7, 0.7, 0.7)
    end
  end
  local drops = ns.Drops(id)
  if drops then
    tip:AddLine(" ")
    tip:AddLine("Dropped for you in:", 1, 0.4, 0.67)
    for _, d in ipairs(SortedCounts(drops)) do
      tip:AddDoubleLine("  " .. d.name, "x" .. d.n, 1, 1, 1, 1, 1, 1)
    end
    local seen = ns.db.dropLvl[id]
    if type(seen) == "table" and seen.lo then
      tip:AddLine(("  from level %d-%d mobs"):format(seen.lo, seen.hi), 0.7, 0.7, 0.7)
    end
  end
  tip:AddLine(" ")
  tip:AddLine("Click: where to farm it. Ctrl-click: try it on.", 0.5, 0.5, 0.5)
  tip:AddLine("Shift-click: link in chat. Right-click: search the auction house.", 0.5, 0.5, 0.5)
end

local function ShowItemTooltip(owner, id)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  ns.tipFilled = false
  GameTooltip:SetItemByID(id)
  if not ns.tipFilled then
    ns.FillItemTooltip(GameTooltip, id)
  end
  GameTooltip:Show()
end

local function SearchAuctionHouse(name)
  if ns.scan and ns.scan.active then
    -- A search now would replace the results the scan is still reading.
    ns.Print("A scan is running. Search again when it is done.")
    return
  end
  if not ns.AuctionHouseOpen() then
    ns.Print("Open the auction house to search for it.")
    return
  end
  local ok = pcall(function()
    local ah = AuctionHouseFrame
    if ah.SetDisplayMode and AuctionHouseFrameDisplayMode then
      ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
    end
    ah.SearchBar.SearchBox:SetText(name)
    ah.SearchBar:StartSearch()
  end)
  if not ok then
    ns.Print("Could not fill in the auction house search box. Search for \"" .. name .. "\" by hand.")
  end
end

local Refresh

local function OnItemClick(id, button)
  local it = ns.Items()[id]
  if not it then
    return
  end
  local _, link = C_Item.GetItemInfo(id)
  if button == "RightButton" then
    SearchAuctionHouse(it.name)
  elseif IsModifiedClick("DRESSUP") then
    DressUpItemLink(link or ("item:" .. id))
  elseif IsModifiedClick("CHATLINK") then
    if link then
      ChatEdit_InsertLink(link)
    end
  else
    state.farmItem = id
    state.tab = "farm"
    Refresh()
  end
end

-------------------------------------------------------------------------------
-- Scroll list helper
-------------------------------------------------------------------------------
local function CreateList(parent, rowHeight, buildRow)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(10, 10)
  scroll:SetScrollChild(content)
  scroll:SetScript("OnSizeChanged", function(_, w)
    content:SetWidth(w)
  end)
  local list = { scroll = scroll, content = content, rows = {} }
  function list:SetCount(n)
    for i = 1, n do
      local row = self.rows[i]
      if not row then
        row = buildRow(content)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * rowHeight)
        row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        self.rows[i] = row
      end
      row:Show()
    end
    for i = n + 1, #self.rows do
      self.rows[i]:Hide()
    end
    content:SetHeight(math.max(1, n * rowHeight))
  end
  return list
end

-- noHover: rows that cannot be clicked get no hover highlight.
local function AddStripe(row, noHover)
  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 0.04)
  row.stripe = bg
  if not noHover then
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.4, 0.67, 0.15)
  end
end

-------------------------------------------------------------------------------
-- Market tab
-------------------------------------------------------------------------------
local function BuildMarketRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row.smogOwnTooltip = true
  row.smogRow = true
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  AddStripe(row)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", 2, 0)
  row.cells = {}
  local x = ICON_W + 2
  for _, col in ipairs(COLS) do
    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", x, 0)
    fs:SetWidth(col.width)
    fs:SetJustifyH(col.align)
    fs:SetWordWrap(false)
    row.cells[col.key] = fs
    x = x + col.width + COL_GAP
  end
  row:SetScript("OnEnter", function(self)
    if self.id then
      ShowItemTooltip(self, self.id)
    end
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnClick", function(self, button)
    if self.id then
      OnItemClick(self.id, button)
    end
  end)
  return row
end

local NUMERIC = {}
for _, col in ipairs(COLS) do
  NUMERIC[col.key] = col.numeric
end

-- Rows for the market list. Numeric columns use -1 for "no value"; those rows
-- always sort to the bottom, whichever way the column is sorted.
local function MarketData()
  local rows = {}
  for id, it in pairs(ns.Items()) do
    if ArmorFilter(it) then
      local info = ns.Price(id)
      if not state.listedOnly or info.low then
        local lo, hi = ns.MobRange(it)
        rows[#rows + 1] = {
          id = id, it = it, info = info, lo = lo, hi = hi,
          name = it.name or "", type = TypeLabel(it), look = it.look or "",
          low = info.low or -1, qty = (info.qty and info.qty > 0) and info.qty or -1, value = info.value or -1,
          seen = info.seenPct or -1, mob = (it.src == "fishing" or it.inst) and -1 or lo,
        }
      end
    end
  end
  local key, asc, numeric = state.sortKey, state.sortAsc, NUMERIC[state.sortKey]
  table.sort(rows, function(a, b)
    local av, bv = a[key], b[key]
    if numeric then
      local amiss, bmiss = av < 0, bv < 0
      if amiss ~= bmiss then
        return bmiss
      end
    end
    if av == bv then
      return a.id < b.id
    end
    if asc then
      return av < bv
    end
    return av > bv
  end)
  return rows
end

local function RefreshMarket()
  for _, col in ipairs(COLS) do
    local arrow = ""
    if state.sortKey == col.key then
      arrow = state.sortAsc and " ^" or " v"
    end
    headerText[col.key]:SetText(col.label .. arrow)
  end
  local data = MarketData()
  marketView.list:SetCount(#data)
  for i, d in ipairs(data) do
    local row = marketView.list.rows[i]
    row.id = d.id
    row.stripe:SetShown(i % 2 == 0)
    row.icon:SetTexture(ItemIcon(d.id))
    local c = row.cells
    c.name:SetText(ItemName(d.id, d.it) .. (d.it.custom and " |cff999999*|r" or ""))
    c.type:SetText(d.type)
    c.look:SetText("|cffbbbbbb" .. d.look .. "|r")
    if d.info.low then
      c.low:SetText(ns.Money(d.info.low))
    elseif d.info.qty then
      c.low:SetText("|cff777777none|r")
    else
      c.low:SetText("|cff777777?|r")
    end
    c.qty:SetText(d.info.qty and d.info.qty > 0 and d.info.qty or "")
    -- grey: a remembered price for a piece that is not listed right now
    c.value:SetText(ns.Money(d.info.value, d.info.value ~= nil and not d.info.low))
    c.seen:SetText(d.info.seenPct and ("%d%%"):format(Pct(d.info.seenPct)) or "")
    if d.it.src == "fishing" then
      c.mob:SetText("fishing")
    elseif d.it.inst then
      c.mob:SetText("dungeon")
    else
      c.mob:SetText(("%d-%d"):format(d.lo, d.hi))
    end
  end
  marketView.empty:SetShown(#data == 0)
end

-------------------------------------------------------------------------------
-- Farm tab
-------------------------------------------------------------------------------
local function BuildWideRow(parent, onEnter)
  local row = CreateFrame("Button", nil, parent)
  row.smogRow = true
  AddStripe(row, true)
  row.rank = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  row.rank:SetPoint("LEFT", 4, 0)
  row.rank:SetWidth(30)
  row.pool = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.pool:SetPoint("TOPRIGHT", -8, -4)
  row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.title:SetPoint("TOPLEFT", 40, -4)
  row.title:SetPoint("RIGHT", row.pool, "LEFT", -8, 0)
  row.title:SetJustifyH("LEFT")
  row.title:SetWordWrap(false)
  row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.detail:SetPoint("BOTTOMLEFT", 40, 5)
  row.detail:SetPoint("RIGHT", -8, 0)
  row.detail:SetJustifyH("LEFT")
  row.detail:SetWordWrap(false)
  row:SetScript("OnEnter", onEnter)
  row:SetScript("OnLeave", GameTooltip_Hide)
  return row
end

local function MeasuredLine(m)
  local a = m.area
  return ("%d corpse%s, %d piece%s%s"):format(a.looted or 0, (a.looted or 0) == 1 and "" or "s", m.pieces, m.pieces == 1 and "" or "s",
    m.perHour and (", " .. ns.Money(m.perHour) .. " per hour") or "")
end

local function FarmRowTooltip(self)
  local e = self.entry
  if not e then
    return
  end
  local spot = e.spot
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(ns.SpotLabel(spot), 1, 0.4, 0.67)
  GameTooltip:AddLine(("%s, level %d-%d%s"):format(spot.mobs or "Mobs", spot.lo, spot.hi, spot.dungeon and " (dungeon)" or ""), 1, 1, 1, true)
  if spot.note then
    GameTooltip:AddLine(spot.note, 0.7, 0.9, 0.7, true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Pieces whose level band overlaps this spot:", 1, 0.82, 0)
  for i, p in ipairs(e.pieces) do
    if i > 22 then
      GameTooltip:AddLine(("  ...and %d more"):format(#e.pieces - 22), 0.6, 0.6, 0.6)
      break
    end
    local it = ns.Items()[p.id]
    local right = p.value and ns.Money(p.value, not ns.Price(p.id).low) or "|cff777777no price|r"
    if p.match < 0.999 then
      right = right .. (" |cff777777(%d%% of its band)|r"):format(Pct(p.match))
    end
    GameTooltip:AddDoubleLine("  " .. ItemName(p.id, it), right)
  end
  GameTooltip:AddLine("Prices shown after the 5% auction house cut. Grey: not listed right now.", 0.5, 0.5, 0.5, true)
  local measured = ns.MeasuredForZone(spot.zone)
  if #measured > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Your measured results in " .. spot.zone .. ":", 1, 0.4, 0.67)
    for i, m in ipairs(measured) do
      if i > 4 then
        break
      end
      GameTooltip:AddDoubleLine("  " .. m.key, MeasuredLine(m), 1, 1, 1, 0.8, 0.8, 0.8)
    end
  end
  GameTooltip:Show()
end

local function RefreshFarm()
  local itemFilter = state.farmItem and ns.Items()[state.farmItem] and state.farmItem
  local ranked
  local it = itemFilter and ns.Items()[itemFilter]
  farmView.empty:SetText("No farm spots match this filter.")
  if itemFilter then
    ranked = ns.RankSpots(function(other)
      return other == it
    end)
    if it.src == "fishing" then
      farmHeader:SetText(ItemName(itemFilter, it) .. " is not a mob drop. " .. (it.srcNote or ""))
      farmView.empty:SetText("No farm spot: this piece is fished up, not dropped by mobs.")
    elseif it.inst then
      farmHeader:SetText("Where to farm " .. ItemName(itemFilter, it) .. ": it drops in " .. it.inst .. ".")
    else
      local lo, hi = ns.MobRange(it)
      farmHeader:SetText(("Where to farm %s: camps of level %d-%d mobs, best level match first. The level band is a rule of thumb, not a drop table."):format(ItemName(itemFilter, it), lo, hi))
    end
    table.sort(ranked, function(a, b)
      if a.pieces[1].match ~= b.pieces[1].match then
        return a.pieces[1].match > b.pieces[1].match
      end
      return (a.spot.dungeon and 1 or 0) < (b.spot.dungeon and 1 or 0)
    end)
  else
    ranked = ns.RankSpots(ArmorFilter)
    farmHeader:SetText("Estimate only: summed auction value (after the 5% auction house cut) of every piece whose level band overlaps the spot. Not gold per hour: drop chances are unknown. Scan the auction house to get prices. Hover a spot for its pieces.")
  end
  farmClear:SetShown(itemFilter ~= nil)
  farmView.list:SetCount(#ranked)
  for i, e in ipairs(ranked) do
    local row = farmView.list.rows[i]
    row.entry = e
    row.stripe:SetShown(i % 2 == 0)
    local spot = e.spot
    row.title:SetText(("%s  |cff999999%s %d-%d%s|r"):format(ns.SpotLabel(spot), spot.mobs or "mobs", spot.lo, spot.hi, spot.dungeon and ", dungeon" or ""))
    if itemFilter then
      row.rank:SetText(i)
      row.pool:SetText(it.inst and "drops in this dungeon" or ("covers %d%% of its level band"):format(Pct(e.pieces[1].match)))
      row.detail:SetText("|cffbbbbbb" .. (spot.note or "") .. "|r")
    else
      row.rank:SetText(e.priced > 0 and i or "-")
      row.pool:SetText(e.priced > 0 and (ns.Money(e.total) .. " |cff777777pool|r") or "|cff777777scan to price|r")
      local parts = {}
      for j = 1, math.min(3, #e.pieces) do
        local p = e.pieces[j]
        parts[#parts + 1] = ItemName(p.id, ns.Items()[p.id]) .. (p.value and (" " .. ns.Money(p.value)) or "")
      end
      row.detail:SetText(("%d pieces (%d priced): %s%s"):format(#e.pieces, e.priced, table.concat(parts, ", "), #e.pieces > 3 and ", ..." or ""))
    end
  end
  farmView.empty:SetShown(#ranked == 0)
end

-------------------------------------------------------------------------------
-- Measured tab: what the player's own looting produced
-------------------------------------------------------------------------------
local function MeasuredRowTooltip(self)
  local m = self.entry
  if not m then
    return
  end
  local a = m.area
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(m.key, 1, 0.4, 0.67)
  GameTooltip:AddDoubleLine("Corpses with loot opened", a.looted or 0, 1, 0.82, 0, 1, 1, 1)
  GameTooltip:AddDoubleLine("Time between loots", Dur(a.secs), 1, 0.82, 0, 1, 1, 1)
  if a.lmin then
    GameTooltip:AddDoubleLine("Mob levels seen", ("%d-%d"):format(a.lmin, a.lmax), 1, 0.82, 0, 1, 1, 1)
  end
  if a.last then
    GameTooltip:AddDoubleLine("Last farmed", Ago(a.last), 1, 0.82, 0, 1, 1, 1)
  end
  if m.pieces > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("List pieces found here:", 1, 0.82, 0)
    for _, d in ipairs(SortedCounts(a.items)) do
      local v = ns.NetValue(d.name)
      GameTooltip:AddDoubleLine(("  %s x%d"):format(ItemName(d.name, ns.Items()[d.name]), d.n), v and ns.Money(v * d.n) or "|cff777777no price|r")
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Gold per hour counts only the list pieces found, at their typical price today after the 5% auction house cut. Other loot is not counted. Time is only the stretches between loots (pauses over 5 minutes are left out), so a short or sparse session reads higher than a full hour of farming would.", 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end

local function RefreshMeasured()
  local data = ns.Measured()
  measuredView.list:SetCount(#data)
  for i, m in ipairs(data) do
    local row = measuredView.list.rows[i]
    local a = m.area
    row.entry = m
    row.stripe:SetShown(i % 2 == 0)
    row.rank:SetText(m.perHour and i or "-")
    row.title:SetText(m.key .. (a.lmin and ("  |cff999999mobs level %d-%d|r"):format(a.lmin, a.lmax) or ""))
    if m.perHour then
      row.pool:SetText(ns.Money(m.perHour) .. " |cff777777per hour|r")
    else
      row.pool:SetText("|cff777777too little data yet|r")
    end
    local worth = ""
    if m.pieces > 0 then
      worth = " worth " .. ns.Money(m.value)
      if m.unpriced > 0 then
        worth = worth .. (" (%d without a price)"):format(m.unpriced)
      end
    end
    row.detail:SetText(("%d corpse%s with loot, %d list piece%s%s, %s between loots"):format(a.looted or 0, (a.looted or 0) == 1 and "" or "s",
      m.pieces, m.pieces == 1 and "" or "s", worth, Dur(a.secs)))
  end
  measuredView.empty:SetShown(#data == 0)
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
local function UpdateStatus()
  if not win then
    return
  end
  local scan = ns.scan
  if scan.active then
    statusText:SetText(("Scanning... %d search results read"):format(scan.rows or 0))
    scanButton:SetText("Scanning")
    scanButton:Disable()
  else
    local n = 0
    for _ in pairs(ns.Items()) do
      n = n + 1
    end
    local hidden = ns.CheckHidden()
    statusText:SetText(("%d pieces tracked. Last scan: %s.%s%s"):format(n, Ago(ns.db.lastScan),
      hidden > 0 and (" %d hidden by the game-build check (/smog verify)."):format(hidden) or "",
      ns.AuctionHouseOpen() and "" or " Open the auction house to scan."))
    scanButton:SetText("Scan")
    scanButton:SetEnabled(ns.AuctionHouseOpen())
  end
end

Refresh = function()
  if not win or not win:IsShown() then
    return
  end
  for key, b in pairs(tabButtons) do
    b:SetEnabled(key ~= state.tab)
  end
  for key, b in pairs(armorButtons) do
    b:SetEnabled(key ~= state.armor)
    -- The armor filter does nothing on the Measured tab or while the Farm
    -- guide shows the spots of one piece, so it is not offered there.
    b:SetShown(state.tab == "market" or (state.tab == "farm" and not (state.farmItem and ns.Items()[state.farmItem])))
  end
  listedCheck:SetShown(state.tab == "market")
  listedText:SetShown(state.tab == "market")
  marketView:SetShown(state.tab == "market")
  farmView:SetShown(state.tab == "farm")
  measuredView:SetShown(state.tab == "measured")
  if state.tab == "market" then
    RefreshMarket()
  elseif state.tab == "farm" then
    RefreshFarm()
  else
    RefreshMeasured()
  end
  -- A tooltip left open on one of the window's rows would still describe the
  -- row's old content: show it again for what the row holds now.
  pcall(function()
    if GameTooltip:IsShown() then
      local owner = GameTooltip:GetOwner()
      if owner and owner.smogRow == true then
        local onEnter = owner:IsShown() and owner:GetScript("OnEnter")
        if onEnter then
          onEnter(owner)
        else
          GameTooltip:Hide()
        end
      end
    end
  end)
  UpdateStatus()
end

local function MakeButton(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function MakeHeaderText(view)
  local fs = view:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 4, -2)
  fs:SetPoint("RIGHT", view, "RIGHT", -146, 0)
  fs:SetHeight(28)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  fs:SetWordWrap(true)
  return fs
end

local function CreateWindow()
  win = CreateFrame("Frame", "SlutmogScoutFrame", UIParent, "BasicFrameTemplateWithInset")
  win:SetSize(940, 560)
  win:SetFrameStrata("HIGH")
  win:SetMovable(true)
  win:SetClampedToScreen(true)
  win:EnableMouse(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint(1)
    if type(p) == "string" then
      ns.db.winPos = { p = p, rp = rp, x = x, y = y }
    end
  end)
  -- back to where the player left it
  local pos = ns.db.winPos
  local placed = type(pos) == "table" and pcall(function()
    win:ClearAllPoints()
    win:SetPoint(pos.p, UIParent, pos.rp, pos.x, pos.y)
  end)
  if not placed then
    win:ClearAllPoints()
    win:SetPoint("CENTER")
  end
  win:Hide()
  tinsert(UISpecialFrames, "SlutmogScoutFrame")

  local title = win.TitleText or (win.TitleContainer and win.TitleContainer.TitleText)
  if not title then
    title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
  end
  title:SetText("Slutmog Scout")

  -- top bar
  local x = 14
  for _, def in ipairs({ { "market", "Market", 80 }, { "farm", "Farm guide", 90 }, { "measured", "Measured", 90 } }) do
    local key = def[1]
    local b = MakeButton(win, def[2], def[3], function()
      state.tab = key
      if key == "farm" then
        state.farmItem = nil
      end
      Refresh()
    end)
    b:SetPoint("TOPLEFT", x, -30)
    tabButtons[key] = b
    x = x + def[3] + 4
  end
  x = x + 16
  for _, key in ipairs(ARMOR_ORDER) do
    local b = MakeButton(win, ARMOR_LABEL[key], 60, function()
      state.armor = key
      Refresh()
    end)
    b:SetPoint("TOPLEFT", x, -30)
    armorButtons[key] = b
    x = x + 62
  end

  listedCheck = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
  listedCheck:SetSize(24, 24)
  listedCheck:SetPoint("TOPLEFT", x + 10, -29)
  listedCheck:SetHitRectInsets(0, -100, 0, 0) -- the label is clickable too
  listedText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listedText:SetPoint("LEFT", listedCheck, "RIGHT", 2, 0)
  listedText:SetText("Listed now only")
  listedCheck:SetScript("OnClick", function(self)
    state.listedOnly = self:GetChecked() and true or false
    Refresh()
  end)

  scanButton = MakeButton(win, "Scan", 90, function()
    ns.StartScan()
  end)
  scanButton:SetPoint("TOPRIGHT", -14, -30)

  statusText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("BOTTOMLEFT", 14, 9)
  statusText:SetPoint("RIGHT", -14, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetWordWrap(false)

  -- market view
  marketView = CreateFrame("Frame", nil, win)
  marketView:SetPoint("TOPLEFT", 12, -58)
  marketView:SetPoint("BOTTOMRIGHT", -12, 28)
  local hx = ICON_W + 2
  for _, col in ipairs(COLS) do
    local h = CreateFrame("Button", nil, marketView)
    h:SetSize(col.width, 18)
    h:SetPoint("TOPLEFT", hx, 0)
    local hl = h:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH(col.align)
    fs:SetWordWrap(false)
    fs:SetText(col.label)
    headerText[col.key] = fs
    h:SetScript("OnClick", function()
      if state.sortKey == col.key then
        state.sortAsc = not state.sortAsc
      else
        state.sortKey = col.key
        state.sortAsc = not col.numeric
      end
      Refresh()
    end)
    h:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(col.label, 1, 0.82, 0)
      if col.tip then
        GameTooltip:AddLine(col.tip, 1, 1, 1, true)
      end
      GameTooltip:AddLine("Click to sort.", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", GameTooltip_Hide)
    hx = hx + col.width + COL_GAP
  end
  marketView.list = CreateList(marketView, ROW_H, BuildMarketRow)
  marketView.list.scroll:SetPoint("TOPLEFT", 0, -20)
  marketView.list.scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  marketView.empty = marketView:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  marketView.empty:SetPoint("CENTER")
  marketView.empty:SetText("Nothing to show. Untick \"Listed now only\" or pick another armor type.")

  -- farm view
  farmView = CreateFrame("Frame", nil, win)
  farmView:SetPoint("TOPLEFT", 12, -58)
  farmView:SetPoint("BOTTOMRIGHT", -12, 28)
  farmHeader = MakeHeaderText(farmView)
  farmClear = MakeButton(farmView, "Show all spots", 110, function()
    state.farmItem = nil
    Refresh()
  end)
  farmClear:SetPoint("TOPRIGHT", -26, 0)
  farmView.list = CreateList(farmView, FARM_ROW_H, function(parent)
    return BuildWideRow(parent, FarmRowTooltip)
  end)
  farmView.list.scroll:SetPoint("TOPLEFT", 0, LIST_TOP)
  farmView.list.scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  farmView.empty = farmView:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  farmView.empty:SetPoint("CENTER")
  farmView.empty:SetText("No farm spots match this filter.")

  -- measured view
  measuredView = CreateFrame("Frame", nil, win)
  measuredView:SetPoint("TOPLEFT", 12, -58)
  measuredView:SetPoint("BOTTOMRIGHT", -12, 28)
  local measuredHeader = MakeHeaderText(measuredView)
  measuredHeader:SetText("Measured from your own looting: corpses you opened, list pieces found on them, and the time between loots (pauses over 5 minutes are left out). Gold per hour counts list pieces only and needs 15 minutes of data.")
  measuredView.list = CreateList(measuredView, FARM_ROW_H, function(parent)
    return BuildWideRow(parent, MeasuredRowTooltip)
  end)
  measuredView.list.scroll:SetPoint("TOPLEFT", 0, LIST_TOP)
  measuredView.list.scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  measuredView.empty = measuredView:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  measuredView.empty:SetPoint("CENTER")
  measuredView.empty:SetText("Nothing measured yet. Loot mobs anywhere and this tab fills in by itself.")

  win:SetScript("OnShow", Refresh)
end

function ns.Toggle(tab, forceShow)
  if not ns.db then
    return
  end
  if not win then
    CreateWindow()
  end
  if tab then
    state.tab = tab
    state.farmItem = nil
  end
  if win:IsShown() and not forceShow then
    win:Hide()
  else
    local was = win:IsShown()
    win:Show() -- showing a hidden window refreshes it
    if was then
      Refresh()
    end
  end
end

-------------------------------------------------------------------------------
-- Button above the auction house window
-------------------------------------------------------------------------------
local ahButton
local function EnsureAuctionHouseButton()
  if ahButton or not AuctionHouseFrame then
    return
  end
  ahButton = CreateFrame("Button", "SlutmogScoutAHButton", AuctionHouseFrame, "UIPanelButtonTemplate")
  ahButton:SetSize(120, 22)
  ahButton:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "TOPRIGHT", -2, 2)
  ahButton:SetText("Slutmog scan")
  ahButton:SetScript("OnClick", function()
    ns.Toggle(nil, true)
    ns.StartScan()
  end)
  ahButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Slutmog Scout")
    GameTooltip:AddLine("Scan the auction house for revealing BoE drops and open the list.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  ahButton:SetScript("OnLeave", GameTooltip_Hide)
end

ns.On(function(what)
  if what == "AH_SHOW" then
    EnsureAuctionHouseButton()
    UpdateStatus()
  elseif what == "AH_CLOSED" then
    UpdateStatus()
    if C_Timer and C_Timer.After then
      C_Timer.After(0.3, UpdateStatus) -- the game's own window may hide after this event
    end
  elseif what == "SCAN" then
    if ns.scan.active then
      UpdateStatus()
    else
      Refresh()
    end
  elseif what == "ITEMS" or what == "DROPS" then
    Refresh()
  end
end)
