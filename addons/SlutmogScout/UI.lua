-- Slutmog Scout: window (Market, Farm guide and Measured tabs) and the auction house button
local ADDON, ns = ...

-- Fallback only: the game's own item quality colours, used when the game's
-- table cannot be read.
local QUALITY_HEX = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee", [5] = "ffff8000" }

-------------------------------------------------------------------------------
-- Game look: colours and art the game itself uses (its auction house list).
-------------------------------------------------------------------------------
local function ColorRGB(c, r, g, b)
  if type(c) == "table" and type(c.r) == "number" then
    return c.r, c.g, c.b
  end
  return r, g, b
end
local GOLD = { ColorRGB(NORMAL_FONT_COLOR, 1, 0.82, 0) }
local WHITE = { ColorRGB(HIGHLIGHT_FONT_COLOR, 1, 1, 1) }
local GREY = { ColorRGB(GRAY_FONT_COLOR, 0.5, 0.5, 0.5) }
local GREY_HEX = ("ff%02x%02x%02x"):format(GREY[1] * 255, GREY[2] * 255, GREY[3] * 255)
ns.GREY_HEX = GREY_HEX

local function Grey(text)
  return "|c" .. GREY_HEX .. tostring(text) .. "|r"
end

local function QualityHex(q)
  if C_Item and C_Item.GetItemQualityColor then
    local ok, _, _, _, hex = pcall(C_Item.GetItemQualityColor, q)
    if ok and type(hex) == "string" and #hex == 8 then
      return hex
    end
  end
  return QUALITY_HEX[q] or QUALITY_HEX[2]
end

local atlasKnown = {}
local function HasAtlas(name)
  if atlasKnown[name] == nil then
    local ok, info = pcall(function()
      return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)
    end)
    atlasKnown[name] = ok and info ~= nil and info ~= false
  end
  return atlasKnown[name]
end

-- Puts game art on a texture: the atlas when this client has it, else the
-- file. Returns false (and hides the texture) when neither is available, so
-- a missing piece of art never turns into a flat colour.
local function SetArt(tex, atlas, file)
  if atlas and HasAtlas(atlas) then
    tex:SetAtlas(atlas)
    return true
  end
  if file then
    tex:SetTexture(file)
    return true
  end
  tex:Hide()
  return false
end

local function TryCreate(kind, name, parent, template)
  local ok, f = pcall(CreateFrame, kind, name, parent, template)
  if ok and f then
    return f
  end
  return nil
end
local ARMOR_ORDER = { "all", "cloth", "leather", "mail", "plate" }
local ARMOR_LABEL = { all = "All", cloth = "Cloth", leather = "Leather", mail = "Mail", plate = "Plate", other = "Other" }
local SLOT_LABEL = { chest = "chest", legs = "legs", shoulder = "shoulders", waist = "belt", hands = "gloves", feet = "boots", head = "head", wrist = "bracers", back = "cloak", other = "" }

-- Sizes copied from the auction house (Blizzard_AuctionHouseUI, branch
-- forever): 20 px list lines (AuctionHouseItemListLineTemplate), 19 px column
-- headers, cells padded 10 px (STANDARD_PADDING in the table builder), the
-- price column first with 14 px on its right, as in the browse list.
local ROW_H = 20
local FARM_ROW_H = 38
local WIN_W, WIN_H = 940, 560
-- the list area runs from x 4 to -5 in the window; its headers from 4 to -26
local HEADER_W = WIN_W - 4 - 5 - 4 - 26
local COLS = {
  { key = "low", label = "Lowest", width = 96, padL = 0, padR = 14, align = "RIGHT", numeric = true,
    tip = "Lowest price on the auction house in your last scan." },
  { key = "name", label = "Item", fill = true, padL = 10, align = "LEFT" },
  { key = "type", label = "Type", width = 102, padL = 10, align = "LEFT" },
  { key = "look", label = "Look", width = 190, padL = 10, align = "LEFT",
    tip = "Measured from the item's texture: how much of the torso or legs it leaves bare." },
  { key = "value", label = "Fair value", width = 94, padL = 10, align = "RIGHT", numeric = true,
    tip = "What the piece normally sells for, never taken from the listing it is judged against: the middle of its lowest prices in your earlier scans, else its other listings now, else pieces that look the same, else Auctionator or TradeSkillMaster. Grey when it is not listed right now." },
  { key = "seen", label = "Seen %", width = 62, padL = 10, align = "RIGHT", numeric = true,
    tip = "Share of your scans in which the piece was listed at all." },
  { key = "mob", label = "Mob lvl", width = 66, padL = 10, align = "RIGHT", numeric = true,
    tip = "Level of the mobs it is expected to drop from. A rule of thumb (required level to required level + 5), widened by drops you measured yourself." },
  { key = "qty", label = "Available", width = 80, padL = 10, padR = 10, align = "RIGHT", numeric = true,
    tip = "How many are on the auction house in your last scan." },
}
do
  local fixed = 0
  for _, col in ipairs(COLS) do
    fixed = fixed + (col.width or 0)
  end
  local x = 0
  for _, col in ipairs(COLS) do
    if col.fill then
      col.width = HEADER_W - fixed
    end
    col.x = x
    x = x + col.width
  end
end
local HEADER_OVERLAP = 2 -- SetColumnHeaderOverlap(2) in the auction house table builder
local CELL_FONT = "Number14FontWhite"

local TAB_DEFS = { { "market", "Market", 80 }, { "farm", "Farm guide", 90 }, { "measured", "Measured", 90 } }
local TAB_INDEX = {}
for i, def in ipairs(TAB_DEFS) do
  TAB_INDEX[def[1]] = i
end

local state = { tab = "market", armor = "all", listedOnly = false, buyOnly = false, sortKey = "value", sortAsc = false, farmItem = nil }
local win, marketView, farmView, measuredView, statusText, scanButton, farmHeader, farmClear, listedCheck, listedText
local filterButton, dealsCheck, dealsText, croppedCheck, croppedText, commonCheck, commonText
local tabButtons, armorButtons, headerText = {}, {}, {}

local function ItemName(id, it)
  it = it or ns.ITEMS[id] or (ns.db.custom[id]) or {}
  return ("|c%s%s|r"):format(QualityHex(it.q or 2), it.name or ("Item " .. id))
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
  local g1, g2, g3 = GOLD[1], GOLD[2], GOLD[3]
  local w1, w2, w3 = WHITE[1], WHITE[2], WHITE[3]
  local e1, e2, e3 = GREY[1], GREY[2], GREY[3]
  tip:AddLine(" ")
  tip:AddLine("|cffff66aaSlutmog|r" .. ns.GradeLabel(it) .. ": " .. (it.look or "revealing"),
    w1, w2, w3, true)
  if info.low then
    tip:AddDoubleLine("Lowest in your last scan", ns.Money(info.low) .. " " .. Grey(("(%d listed in all)"):format(info.qty or 0)), g1, g2, g3, w1, w2, w3)
  end
  if info.fair then
    tip:AddDoubleLine("Fair value", ns.Money(info.fair, not info.low), g1, g2, g3, w1, w2, w3)
    tip:AddLine(("From %s (%d %s), %s confidence."):format(info.fairBasis or "?", info.fairN or 1,
      (info.fairN or 1) == 1 and "price" or "prices", info.sure or "low"), e1, e2, e3, true)
  elseif info.value then
    tip:AddDoubleLine("Lowest price", ns.Money(info.value, not info.low), g1, g2, g3, w1, w2, w3)
  else
    tip:AddLine("No price yet. Scan at the auction house.", e1, e2, e3)
  end
  local b = info.low and ns.Buy(id, info) or nil
  if b then
    tip:AddLine(" ")
    if b.buy then
      tip:AddDoubleLine("Worth buying up to", ns.Money(b.upTo), g1, g2, g3, w1, w2, w3)
      tip:AddLine(("Resale about %s; one earns about %s after the 5%% cut and the deposit. Risk: %s.%s"):format(
        ns.Money(b.resale), ns.Money(math.floor(b.gain)), b.risk,
        b.count > 1 and (" %d are listed at or under that price, %s in all."):format(b.count, ns.Money(b.cost)) or ""),
        w1, w2, w3, true)
    else
      tip:AddLine("Not worth buying: " .. b.stop .. ".", w1, w2, w3, true)
    end
    if b.cheaper and ns.Items()[b.cheaper.id] then
      tip:AddDoubleLine("Same look, cheaper: " .. ns.Items()[b.cheaper.id].name, ns.Money(b.cheaper.low), g1, g2, g3, w1, w2, w3)
    end
    if #b.pros > 0 then
      tip:AddLine("For: " .. table.concat(b.pros, "; ") .. ".", e1, e2, e3, true)
    end
    if #b.cons > 0 then
      tip:AddLine("Against: " .. table.concat(b.cons, "; ") .. ".", e1, e2, e3, true)
    end
  end
  if info.seenPct then
    tip:AddDoubleLine("Listed in", ("%d%% of your scans"):format(Pct(info.seenPct)), g1, g2, g3, w1, w2, w3)
  end
  if not info.low and info.lastSeen then
    tip:AddDoubleLine("Last seen", Ago(info.lastSeen) .. " at " .. ns.Money(info.lastMin), g1, g2, g3, w1, w2, w3)
  end
  tip:AddLine(" ")
  if it.src == "fishing" then
    tip:AddLine(it.srcNote or "Fished up, not a mob drop.", w1, w2, w3, true)
  else
    local spots = ns.SpotsForItem(id, 5)
    local lo, hi, measured = ns.MobRange(it)
    if it.inst then
      tip:AddLine("Drops in " .. it.inst .. " (dungeon).", w1, w2, w3, true)
    elseif measured then
      tip:AddLine(("Level %d-%d mobs (rule of thumb, widened by your own drops). Best level matches:"):format(lo, hi), w1, w2, w3, true)
    else
      tip:AddLine(("Probably a world drop from about level %d-%d mobs (rule of thumb). Best level matches:"):format(lo, hi), w1, w2, w3, true)
    end
    for _, s in ipairs(spots) do
      tip:AddDoubleLine("  " .. ns.SpotLabel(s.spot), ("%d-%d"):format(s.spot.lo, s.spot.hi), w1, w2, w3, e1, e2, e3)
    end
  end
  local drops = ns.Drops(id)
  if drops then
    tip:AddLine(" ")
    tip:AddLine("Dropped for you in:", g1, g2, g3)
    for _, d in ipairs(SortedCounts(drops)) do
      tip:AddDoubleLine("  " .. d.name, "x" .. d.n, w1, w2, w3, w1, w2, w3)
    end
    local seen = ns.db.dropLvl[id]
    if type(seen) == "table" and seen.lo then
      tip:AddLine(("  from level %d-%d mobs"):format(seen.lo, seen.hi), e1, e2, e3)
    end
  end
  tip:AddLine(" ")
  tip:AddLine("Click: where to farm it. Ctrl-click: try it on.", e1, e2, e3)
  tip:AddLine("Shift-click: link in chat. Right-click: search the auction house.", e1, e2, e3)
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
    state.backTab = state.tab
    state.farmItem = id
    state.tab = "farm"
    Refresh()
  end
end

-------------------------------------------------------------------------------
-- Scroll list helper
-------------------------------------------------------------------------------
-- The scroll bar is the game's thin one (ScrollFrameTemplate: MinimalScrollBar),
-- placed as the auction house places it: 9 px right of the list.
local function CreateList(parent, rowHeight, buildRow)
  local scroll = TryCreate("ScrollFrame", nil, parent, "ScrollFrameTemplate")
  if scroll and type(scroll.ScrollBar) == "table" and scroll.ScrollBar.ClearAllPoints then
    local bar = scroll.ScrollBar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 9, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 9, 4)
  elseif not scroll then
    scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  end
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

-- Row background and hover highlight of the auction house's list lines
-- (AuctionHouseItemListLineTemplate): alternating stripes and its row
-- highlight, added on hover.
local function AddStripe(row)
  local bg = row:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  row.stripe = bg
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  if SetArt(hl, "auctionhouse-ui-row-highlight", "Interface\\QuestFrame\\UI-QuestTitleHighlight") then
    hl:SetBlendMode("ADD")
  end
end

local function CellFont()
  return _G[CELL_FONT] and CELL_FONT or "GameFontHighlightSmall"
end

local function SetStripe(row, i)
  if HasAtlas("auctionhouse-rowstripe-1") then
    row.stripe:SetAtlas(i % 2 == 1 and "auctionhouse-rowstripe-1" or "auctionhouse-rowstripe-2")
    row.stripe:Show()
  else
    row.stripe:Hide()
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
  row.cells = {}
  local font = CellFont()
  for _, col in ipairs(COLS) do
    local padL, padR = col.padL or 0, col.padR or 0
    local fs = row:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH(col.align)
    fs:SetWordWrap(false)
    if col.key == "name" then
      -- the auction house's item cell (AuctionHouseTableCellItemDisplayTemplate):
      -- 14 px icon in its 16 px border, name 4 px right of the icon, 1 px down
      row.icon = row:CreateTexture(nil, "BACKGROUND", nil, 1)
      row.icon:SetSize(14, 14)
      row.icon:SetPoint("LEFT", col.x + padL, 0)
      local border = row:CreateTexture(nil, "BACKGROUND", nil, 2)
      border:SetSize(16, 16)
      border:SetPoint("CENTER", row.icon, "CENTER")
      if HasAtlas("auctionhouse-itemicon-small-border") then
        border:SetAtlas("auctionhouse-itemicon-small-border")
      else
        border:Hide()
      end
      fs:SetPoint("LEFT", row.icon, "RIGHT", 4, -1)
      fs:SetWidth(col.width - padL - 14 - 4 - padR)
    else
      fs:SetPoint("LEFT", col.x + padL, 0)
      fs:SetWidth(col.width - padL - padR)
    end
    row.cells[col.key] = fs
    if col.key == "qty" then
      -- Buy, left in the Available cell: the cheapest copy listed now, once the
      -- game's own confirm popup has shown its price
      local buy = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      buy:SetSize(40, 18)
      buy:SetPoint("LEFT", col.x + padL - 4, 0)
      buy:SetText("Buy")
      buy:SetScript("OnClick", function(self)
        local id = self:GetParent().id
        if id then
          ns.StartPurchase(id)
        end
      end)
      buy:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Buy")
        GameTooltip:AddLine("Finds the cheapest copy listed now. The game shows its price and asks you to confirm before anything is bought.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      buy:SetScript("OnLeave", GameTooltip_Hide)
      buy:Hide()
      row.buyButton = buy
    end
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

-- The short note after a piece's name: what to pay for a buy, or that farming
-- it yourself is the cheaper way.
local function BuyNote(b)
  if not b then
    return ""
  end
  if b.buy then
    return "  " .. Grey("buy up to") .. " " .. ns.Money(b.upTo)
      .. Grey((b.count > 1 and (" x%d"):format(b.count) or "") .. (", %s risk"):format(b.risk))
  end
  if b.noDemand then
    return "  " .. Grey("sells like ordinary gear: no demand for the look")
  end
  if b.easyFarm then
    return "  " .. Grey(("cheaper to farm: level %d-%d mobs"):format(b.easyFarm.lo, b.easyFarm.hi))
  end
  return ""
end

-- Rows for the market list. Numeric columns use -1 for "no value"; those rows
-- always sort to the bottom, whichever way the column is sorted.
local function MarketData()
  local rows = {}
  for id, it in pairs(ns.Items()) do
    local info = ArmorFilter(it) and ns.Price(id)
    if info and ns.Shown(it, info) then
      local buy = info.low and ns.Buy(id, info) or nil
      if (not state.listedOnly or info.low) and (not state.buyOnly or (buy and buy.buy)) then
        local lo, hi = ns.MobRange(it)
        rows[#rows + 1] = {
          id = id, it = it, info = info, lo = lo, hi = hi, buy = buy,
          name = it.name or "", type = TypeLabel(it), look = (it.grade and (it.grade .. ": ") or "") .. (it.look or ""),
          low = info.low or -1, qty = (info.qty and info.qty > 0) and info.qty or -1, value = info.value or -1,
          seen = info.seenPct or -1, mob = (it.src == "fishing" or it.inst) and -1 or lo,
        }
      end
    end
  end
  local key, asc, numeric = state.sortKey, state.sortAsc, NUMERIC[state.sortKey]
  table.sort(rows, function(a, b)
    if state.buyOnly and a.buy.score ~= b.buy.score then
      return a.buy.score > b.buy.score -- the best buy first
    end
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
    -- sort arrow as in the auction house: its arrow art, flipped for the
    -- other direction; a text arrow only where the art is missing
    local h = headerText[col.key]
    local arrow = h.arrow
    local sorted = state.sortKey == col.key
    h.arrowState = sorted and (state.sortAsc and "asc" or "desc") or nil
    if arrow then
      h:SetText(col.label)
      arrow:SetShown(sorted)
      if sorted then
        if state.sortAsc then
          arrow:SetTexCoord(0, 1, 1, 0)
        else
          arrow:SetTexCoord(0, 1, 0, 1)
        end
      end
    else
      h:SetText(col.label .. (sorted and (state.sortAsc and " ^" or " v") or ""))
    end
  end
  local data = MarketData()
  local ahOpen = ns.AuctionHouseOpen() and ns.PurchaseApiPresent()
  marketView.list:SetCount(#data)
  for i, d in ipairs(data) do
    local row = marketView.list.rows[i]
    row.id = d.id
    SetStripe(row, i)
    row.icon:SetTexture(ItemIcon(d.id))
    local c = row.cells
    c.name:SetText(ItemName(d.id, d.it) .. (d.it.custom and (" " .. Grey("*")) or "")
      .. BuyNote(d.buy))
    c.type:SetText(d.type)
    c.look:SetText(d.look)
    if d.info.low then
      c.low:SetText(ns.Money(d.info.low))
    elseif d.info.qty then
      c.low:SetText(Grey("none"))
    else
      c.low:SetText(Grey("?"))
    end
    c.qty:SetText(d.info.qty and d.info.qty > 0 and d.info.qty or "")
    row.buyButton:SetShown(d.info.low ~= nil and ahOpen)
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
  AddStripe(row)
  -- two lines laid out like the group finder's result rows
  -- (LFGListSearchEntryTemplate): name 10 px in and 6 px down, the second
  -- line right under it; the value sits on the name line at the right.
  row.pool = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.pool:SetPoint("TOPRIGHT", -10, -6)
  row.pool:SetHeight(14)
  row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.title:SetPoint("TOPLEFT", 10, -6)
  row.title:SetPoint("RIGHT", row.pool, "LEFT", -10, 0)
  row.title:SetHeight(14)
  row.title:SetJustifyH("LEFT")
  row.title:SetWordWrap(false)
  row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, 0)
  row.detail:SetPoint("RIGHT", -10, 0)
  row.detail:SetHeight(15)
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
  GameTooltip:AddLine(ns.SpotLabel(spot), GOLD[1], GOLD[2], GOLD[3])
  GameTooltip:AddLine(("%s, level %d-%d%s"):format(spot.mobs or "Mobs", spot.lo, spot.hi, spot.dungeon and " (dungeon)" or ""), WHITE[1], WHITE[2], WHITE[3], true)
  if spot.note then
    GameTooltip:AddLine(spot.note, WHITE[1], WHITE[2], WHITE[3], true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Pieces whose level band overlaps this spot:", GOLD[1], GOLD[2], GOLD[3])
  for i, p in ipairs(e.pieces) do
    if i > 22 then
      GameTooltip:AddLine(("  ...and %d more"):format(#e.pieces - 22), GREY[1], GREY[2], GREY[3])
      break
    end
    local it = ns.Items()[p.id]
    local right = p.value and ns.Money(p.value, not ns.Price(p.id).low) or Grey("no price")
    if p.match < 0.999 then
      right = right .. " " .. Grey(("(%d%% of its band)"):format(Pct(p.match)))
    end
    GameTooltip:AddDoubleLine("  " .. ItemName(p.id, it), right)
  end
  GameTooltip:AddLine("Prices shown after the 5% auction house cut. Grey: not listed right now.", GREY[1], GREY[2], GREY[3], true)
  if not state.farmItem then
    GameTooltip:AddLine("The value is an estimate: the summed price of every piece whose level band overlaps the spot. Not gold per hour: drop chances are unknown.", GREY[1], GREY[2], GREY[3], true)
  end
  local measured = ns.MeasuredForZone(spot.zone)
  if #measured > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Your measured results in " .. spot.zone .. ":", GOLD[1], GOLD[2], GOLD[3])
    for i, m in ipairs(measured) do
      if i > 4 then
        break
      end
      GameTooltip:AddDoubleLine("  " .. m.key, MeasuredLine(m), WHITE[1], WHITE[2], WHITE[3], WHITE[1], WHITE[2], WHITE[3])
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
      farmHeader:SetText(ItemName(itemFilter, it) .. "  " .. Grey("fished up, not a mob drop"))
      farmView.empty:SetText("No farm spot: this piece is fished up, not dropped by mobs. " .. (it.srcNote or ""))
    elseif it.inst then
      farmHeader:SetText(ItemName(itemFilter, it) .. "  " .. Grey("drops in " .. it.inst))
    else
      local lo, hi = ns.MobRange(it)
      farmHeader:SetText(ItemName(itemFilter, it) .. "  " .. Grey(("level %d-%d mobs (rule of thumb)"):format(lo, hi)))
    end
    table.sort(ranked, function(a, b)
      if a.pieces[1].match ~= b.pieces[1].match then
        return a.pieces[1].match > b.pieces[1].match
      end
      return (a.spot.dungeon and 1 or 0) < (b.spot.dungeon and 1 or 0)
    end)
  else
    ranked = ns.RankSpots(ArmorFilter)
  end
  -- one piece's spots: the auction house's item page, a Back button above the list
  farmClear:SetShown(itemFilter ~= nil)
  farmHeader:SetShown(itemFilter ~= nil)
  farmView.PlaceList(itemFilter and -37 or 0)
  farmView.list:SetCount(#ranked)
  for i, e in ipairs(ranked) do
    local row = farmView.list.rows[i]
    row.entry = e
    SetStripe(row, i)
    local spot = e.spot
    row.title:SetText(("%s  %s"):format(ns.SpotLabel(spot), Grey(("%s %d-%d%s"):format(spot.mobs or "mobs", spot.lo, spot.hi, spot.dungeon and ", dungeon" or ""))))
    if itemFilter then
      row.pool:SetText(it.inst and "drops in this dungeon" or ("covers %d%% of its level band"):format(Pct(e.pieces[1].match)))
      row.detail:SetText(spot.note or "")
    else
      row.pool:SetText(e.priced > 0 and (ns.Money(e.total) .. " " .. Grey("pool")) or Grey("scan to price"))
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
  GameTooltip:AddLine(m.key, GOLD[1], GOLD[2], GOLD[3])
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
      GameTooltip:AddDoubleLine(("  %s x%d"):format(ItemName(d.name, ns.Items()[d.name]), d.n), v and ns.Money(v * d.n) or Grey("no price"))
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Gold per hour counts only the list pieces found, at their typical price today after the 5% auction house cut. Other loot is not counted. Time is only the stretches between loots (pauses over 5 minutes are left out), so a short or sparse session reads higher than a full hour of farming would.", GREY[1], GREY[2], GREY[3], true)
  GameTooltip:Show()
end

local function RefreshMeasured()
  local data = ns.Measured()
  measuredView.list:SetCount(#data)
  for i, m in ipairs(data) do
    local row = measuredView.list.rows[i]
    local a = m.area
    row.entry = m
    SetStripe(row, i)
    row.title:SetText(m.key .. (a.lmin and ("  " .. Grey(("mobs level %d-%d"):format(a.lmin, a.lmax))) or ""))
    if m.perHour then
      row.pool:SetText(ns.Money(m.perHour) .. " " .. Grey("per hour"))
    else
      row.pool:SetText(Grey("too little data yet"))
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
  elseif ns.ladder and ns.ladder.active then
    statusText:SetText(("Checking the other listings of possible buys... %d left"):format(#ns.ladder.queue + (ns.ladder.current and 1 or 0)))
    scanButton:SetText("Scan")
    scanButton:SetEnabled(ns.AuctionHouseOpen())
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
  if win.smogPanelTabs then
    PanelTemplates_SetTab(win, TAB_INDEX[state.tab] or 1)
  else
    for key, b in pairs(tabButtons) do
      b:SetEnabled(key ~= state.tab)
    end
  end
  -- The armor filter does nothing on the Measured tab or while the Farm
  -- guide shows the spots of one piece, so it is not offered there.
  local filterUseful = state.tab == "market" or (state.tab == "farm" and not (state.farmItem and ns.Items()[state.farmItem]))
  if filterButton then
    filterButton:SetShown(filterUseful)
    if filterButton.smogValidate then
      pcall(filterButton.ValidateResetState, filterButton)
    end
  else
    for key, b in pairs(armorButtons) do
      b:SetEnabled(key ~= state.armor)
      b:SetShown(filterUseful)
    end
    listedCheck:SetShown(state.tab == "market")
    listedText:SetShown(state.tab == "market")
    dealsCheck:SetShown(state.tab == "market")
    dealsText:SetShown(state.tab == "market")
    croppedCheck:SetShown(filterUseful)
    croppedText:SetShown(filterUseful)
    croppedCheck:SetChecked(ns.ShowCropped())
    commonCheck:SetShown(filterUseful)
    commonText:SetShown(filterUseful)
    commonCheck:SetChecked(ns.ShowCommon())
  end
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

-- The list area of a view: the game's inset (InsetFrameTemplate, as under the
-- auction house's browse list) with the scroll list inside it.
local function MakeInset(view)
  local inset = TryCreate("Frame", nil, view, "InsetFrameTemplate")
  if not inset then
    inset = CreateFrame("Frame", nil, view)
  end
  return inset
end

-- Text shown when a list is empty, where and how the auction house shows
-- "No results" (ResultsText in AuctionHouseItemListTemplate).
local function MakeEmptyText(view, scroll)
  local fs = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOP", scroll, "TOP", 0, -45)
  fs:SetPoint("LEFT", view, "LEFT", 45, 0)
  fs:SetPoint("RIGHT", view, "RIGHT", -67, 0)
  fs:SetJustifyH("CENTER")
  fs:SetWordWrap(true)
  return fs
end

-- the views fill the window below the search-bar row, like the auction
-- house's browse area: 4 px from the left edge, 5 from the right
local VIEW_TOP, VIEW_BOTTOM = -73, 26

local function MakeView()
  local view = CreateFrame("Frame", nil, win)
  view:SetPoint("TOPLEFT", 4, VIEW_TOP)
  view:SetPoint("BOTTOMRIGHT", -5, VIEW_BOTTOM)
  return view
end

-- A view without column headers (Farm guide, Measured): the inset from its
-- top (or below a Back button), the list 3 px inside it, the scroll bar in
-- the auction house's place.
local function MakePlainList(view, rowHeight, buildRow)
  view.inset = MakeInset(view)
  view.list = CreateList(view, rowHeight, buildRow)
  function view.PlaceList(top)
    view.inset:ClearAllPoints()
    view.inset:SetPoint("TOPLEFT", 0, top)
    view.inset:SetPoint("BOTTOMRIGHT", 0, 0)
    local scroll = view.list.scroll
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", 4, top - 3)
    scroll:SetPoint("BOTTOMRIGHT", -26, 3)
  end
  view.PlaceList(0)
  view.empty = MakeEmptyText(view, view.list.scroll)
end

local function SelectTab(key)
  state.tab = key
  if key == "farm" then
    state.farmItem = nil
  end
  Refresh()
end

local function FilterIsDefault()
  return state.armor == "all" and not state.listedOnly and not state.buyOnly and not ns.ShowCropped() and not ns.ShowCommon()
end

-- The filter: the game's filter dropdown, as the auction house's search bar
-- has it (WowStyle1FilterDropdownTemplate, 93 wide, 10 px left of the
-- search button, a menu of titled groups). Its reset button shows while a
-- filter is set, which is how the game says a filter is on.
local function CreateFilterDropdown()
  local dd = TryCreate("DropdownButton", nil, win, "WowStyle1FilterDropdownTemplate")
  if not dd or type(dd.SetupMenu) ~= "function" then
    if dd then
      dd:Hide()
    end
    return nil
  end
  dd:SetWidth(93)
  dd:SetPoint("RIGHT", scanButton, "LEFT", -10, 0)
  local ok = pcall(dd.SetupMenu, dd, function(_, root)
    pcall(root.SetTag, root, "MENU_SLUTMOGSCOUT_FILTER")
    root:CreateTitle("Armor type")
    for _, key in ipairs(ARMOR_ORDER) do
      root:CreateRadio(ARMOR_LABEL[key], function()
        return state.armor == key
      end, function()
        state.armor = key
        Refresh()
      end, key)
    end
    if state.tab == "market" then
      root:QueueSpacer()
      root:CreateTitle("Auction house")
      root:CreateCheckbox("Listed now only", function()
        return state.listedOnly
      end, function()
        state.listedOnly = not state.listedOnly
        Refresh()
      end)
      root:CreateCheckbox("Worth buying", function()
        return state.buyOnly
      end, function()
        state.buyOnly = not state.buyOnly
        Refresh()
      end)
    end
    -- cropped looks: a top that covers the bust, shorts that cover most of the thigh
    root:QueueSpacer()
    root:CreateTitle("Look")
    root:CreateCheckbox("Show cropped pieces", ns.ShowCropped, function()
      ns.SetShowCropped(not ns.ShowCropped())
    end)
    -- easy, common gear: low-level greens and cheap pieces listed in every scan
    root:CreateCheckbox("Show easy, common pieces", ns.ShowCommon, function()
      ns.SetShowCommon(not ns.ShowCommon())
    end)
  end)
  if not ok then
    dd:Hide()
    return nil
  end
  if pcall(dd.SetIsDefaultCallback, dd, FilterIsDefault) and pcall(dd.SetDefaultCallback, dd, function()
    state.armor, state.listedOnly, state.buyOnly = "all", false, false
    if ns.ShowCropped() then
      ns.SetShowCropped(false)
    end
    if ns.ShowCommon() then
      ns.SetShowCommon(false)
    end
    Refresh()
  end) then
    dd.smogValidate = true
  end
  return dd
end

-- Fallback when this client has no filter dropdown: the game's buttons and
-- check box in the same row.
local function CreateFilterButtons(startX)
  local x = startX > 0 and startX + 16 or 12
  for _, key in ipairs(ARMOR_ORDER) do
    local b = MakeButton(win, ARMOR_LABEL[key], 60, function()
      state.armor = key
      Refresh()
    end)
    b:SetPoint("LEFT", win, "TOPLEFT", x, -49)
    armorButtons[key] = b
    x = x + 64
  end
  listedCheck = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
  listedCheck:SetSize(24, 24)
  listedCheck:SetPoint("LEFT", win, "TOPLEFT", x + 6, -49)
  listedCheck:SetHitRectInsets(0, -100, 0, 0) -- the label is clickable too
  listedText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  listedText:SetPoint("LEFT", listedCheck, "RIGHT", 2, 0)
  listedText:SetText("Listed now only")
  listedCheck:SetScript("OnClick", function(self)
    state.listedOnly = self:GetChecked() and true or false
    Refresh()
  end)
  dealsCheck = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
  dealsCheck:SetSize(24, 24)
  dealsCheck:SetPoint("LEFT", listedCheck, "RIGHT", 110, 0)
  dealsCheck:SetHitRectInsets(0, -100, 0, 0)
  dealsText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dealsText:SetPoint("LEFT", dealsCheck, "RIGHT", 2, 0)
  dealsText:SetText("Worth buying")
  dealsCheck:SetScript("OnClick", function(self)
    state.buyOnly = self:GetChecked() and true or false
    Refresh()
  end)
  croppedCheck = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
  croppedCheck:SetSize(24, 24)
  croppedCheck:SetPoint("LEFT", dealsCheck, "RIGHT", 100, 0)
  croppedCheck:SetHitRectInsets(0, -100, 0, 0)
  croppedText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  croppedText:SetPoint("LEFT", croppedCheck, "RIGHT", 2, 0)
  croppedText:SetText("Show cropped")
  croppedCheck:SetScript("OnClick", function(self)
    ns.SetShowCropped(self:GetChecked() and true or false)
  end)
  commonCheck = CreateFrame("CheckButton", nil, win, "UICheckButtonTemplate")
  commonCheck:SetSize(24, 24)
  commonCheck:SetPoint("LEFT", croppedCheck, "RIGHT", 100, 0)
  commonCheck:SetHitRectInsets(0, -100, 0, 0)
  commonText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  commonText:SetPoint("LEFT", commonCheck, "RIGHT", 2, 0)
  commonText:SetText("Show common")
  commonCheck:SetScript("OnClick", function(self)
    ns.SetShowCommon(self:GetChecked() and true or false)
  end)
end

local function CreateTabs()
  -- the game's tabs under the bottom edge, placed as the auction house
  -- places its Buy tab (20 px in, 28 px down; the rest 3 px apart)
  local useTabs = type(PanelTemplates_SetNumTabs) == "function" and type(PanelTemplates_SetTab) == "function"
  local made = {}
  if useTabs then
    for i in ipairs(TAB_DEFS) do
      local b = TryCreate("Button", "SlutmogScoutFrameTab" .. i, win, "PanelTabButtonTemplate")
      if not b then
        useTabs = false
        break
      end
      made[i] = b
    end
  end
  if useTabs then
    win.Tabs = made
    for i, def in ipairs(TAB_DEFS) do
      local b = made[i]
      b:SetID(i)
      b:SetText(def[2])
      if i == 1 then
        b:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 20, -28)
      else
        b:SetPoint("TOPLEFT", made[i - 1], "TOPRIGHT", 3, 0)
      end
      b:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
          PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end
        SelectTab(def[1])
      end)
      tabButtons[def[1]] = b
    end
    PanelTemplates_SetNumTabs(win, #TAB_DEFS)
    win.smogPanelTabs = true
    return 0
  end
  for _, b in ipairs(made) do
    b:Hide()
  end
  -- no tab template: plain buttons at the top left of the filter row
  local x = 12
  for _, def in ipairs(TAB_DEFS) do
    local key = def[1]
    local b = MakeButton(win, def[2], def[3], function()
      SelectTab(key)
    end)
    b:SetPoint("LEFT", win, "TOPLEFT", x, -49)
    tabButtons[key] = b
    x = x + def[3] + 4
  end
  return x
end

local function CreateMarketHeaders()
  local container = CreateFrame("Frame", nil, marketView)
  container:SetPoint("TOPLEFT", 4, -1)
  container:SetPoint("TOPRIGHT", -26, -1)
  container:SetHeight(19)
  for ci, col in ipairs(COLS) do
    -- the auction house's column header tab, each one 2 px over the next
    local h = TryCreate("Button", nil, container, "ColumnDisplayButtonShortTemplate")
    if not h then
      h = CreateFrame("Button", nil, container)
      local hl = h:CreateTexture(nil, "HIGHLIGHT")
      hl:SetAllPoints()
      if SetArt(hl, nil, "Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight") then
        hl:SetBlendMode("ADD")
      end
    end
    h:SetSize(col.width + (ci < #COLS and HEADER_OVERLAP or 0), 19)
    h:SetPoint("TOPLEFT", col.x, 0)
    -- text 8 px in and the sort arrow 3 px after it, as in
    -- AuctionHouseTableHeaderStringTemplate
    local fs = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(col.label)
    if HasAtlas("auctionhouse-ui-sortarrow") then
      local arrow = h:CreateTexture(nil, "OVERLAY")
      arrow:SetAtlas("auctionhouse-ui-sortarrow", true)
      arrow:SetPoint("LEFT", fs, "RIGHT", 3, 0)
      arrow:Hide()
      fs.arrow = arrow
    end
    headerText[col.key] = fs
    h:SetScript("OnClick", function()
      if state.sortKey == col.key then
        state.sortAsc = not state.sortAsc
      else
        state.sortKey = col.key
        state.sortAsc = not col.numeric
      end
      if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
      end
      Refresh()
    end)
    h:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(col.label, GOLD[1], GOLD[2], GOLD[3])
      if col.tip then
        GameTooltip:AddLine(col.tip, WHITE[1], WHITE[2], WHITE[3], true)
      end
      GameTooltip:AddLine("Click to sort.", GREY[1], GREY[2], GREY[3])
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", GameTooltip_Hide)
  end
  return container
end

local function CreateWindow()
  -- the auction house's window: the game's portrait frame
  win = TryCreate("Frame", "SlutmogScoutFrame", UIParent, "PortraitFrameTemplate")
  if not win then
    win = CreateFrame("Frame", "SlutmogScoutFrame", UIParent, "BasicFrameTemplateWithInset")
  end
  win:SetSize(WIN_W, WIN_H)
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

  if not pcall(win.SetTitle, win, "Slutmog Scout") then
    local title = win.TitleText or (win.TitleContainer and win.TitleContainer.TitleText)
    if not title then
      title = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      title:SetPoint("TOP", 0, -5)
    end
    title:SetText("Slutmog Scout")
  end
  pcall(win.SetPortraitToAsset, win, "Interface\\Icons\\INV_Misc_Coin_01")

  local tabsX = CreateTabs()

  -- the search-bar row: Scan where the auction house has Search
  -- (AuctionHouseSearchButtonTemplate: 132 x 22 at the right of a 40 px bar
  -- 12 px in and 29 px down), the filter dropdown left of it
  scanButton = MakeButton(win, "Scan", 132, function()
    if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
    ns.StartScan()
  end)
  scanButton:SetPoint("RIGHT", win, "TOPRIGHT", -12, -49)
  filterButton = CreateFilterDropdown()
  if not filterButton then
    CreateFilterButtons(tabsX)
  end

  -- the totals line at the bottom, as under the Who list
  statusText = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("BOTTOMLEFT", 12, 8)
  statusText:SetPoint("RIGHT", -12, 0)
  statusText:SetJustifyH("LEFT")
  statusText:SetWordWrap(false)

  -- market view: the auction house's browse list. Headers sit above the
  -- inset (backgroundYOffset -19); the list starts 6 px under them.
  marketView = MakeView()
  marketView.inset = MakeInset(marketView)
  marketView.inset:SetPoint("TOPLEFT", 0, -19)
  marketView.inset:SetPoint("BOTTOMRIGHT", 0, 0)
  local headers = CreateMarketHeaders()
  marketView.list = CreateList(marketView, ROW_H, BuildMarketRow)
  marketView.list.scroll:SetPoint("TOPLEFT", headers, "BOTTOMLEFT", 0, -6)
  marketView.list.scroll:SetPoint("RIGHT", headers, "RIGHT", 0, 0)
  marketView.list.scroll:SetPoint("BOTTOM", marketView, "BOTTOM", 0, 3)
  marketView.empty = MakeEmptyText(marketView, marketView.list.scroll)
  marketView.empty:SetText("No pieces match this filter.")

  -- farm view; one piece's spots get the auction house item page's Back
  -- button (UIPanelButtonTemplate 110 x 22) and the piece's name beside it
  farmView = MakeView()
  MakePlainList(farmView, FARM_ROW_H, function(parent)
    return BuildWideRow(parent, FarmRowTooltip)
  end)
  farmClear = MakeButton(farmView, "Back", 110, function()
    local back = state.backTab
    state.farmItem = nil
    state.backTab = nil
    if back and back ~= "farm" then
      state.tab = back
    end
    Refresh()
  end)
  farmClear:SetPoint("TOPLEFT", 0, -5)
  local nameFont = _G.SystemFont_Shadow_Large2 and "SystemFont_Shadow_Large2" or "GameFontHighlightLarge"
  farmHeader = farmView:CreateFontString(nil, "OVERLAY", nameFont)
  farmHeader:SetPoint("LEFT", farmClear, "RIGHT", 12, 0)
  farmHeader:SetPoint("RIGHT", farmView, "RIGHT", -12, 0)
  farmHeader:SetJustifyH("LEFT")
  farmHeader:SetWordWrap(false)

  -- measured view
  measuredView = MakeView()
  MakePlainList(measuredView, FARM_ROW_H, function(parent)
    return BuildWideRow(parent, MeasuredRowTooltip)
  end)
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
    Refresh() -- the Buy buttons show while the auction house is open
  elseif what == "AH_CLOSED" then
    UpdateStatus()
    Refresh()
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

-------------------------------------------------------------------------------
-- LookShots (a local helper that screenshots listed frames; harmless without it)
-------------------------------------------------------------------------------
local function WindowOn(tab, filtered)
  return function()
    if not win or not win:IsShown() or state.tab ~= tab then
      return nil
    end
    if tab == "farm" and (state.farmItem ~= nil) ~= filtered then
      return nil
    end
    return win
  end
end

local function AddonVersion()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ok, v = pcall(get, ADDON, "Version")
  return ok and type(v) == "string" and v or "unknown"
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["SlutmogScout"] = {
  version = AddonVersion(),
  frames = {
    { label = "window: Market", frame = WindowOn("market") },
    { label = "window: Farm guide", frame = WindowOn("farm", false) },
    { label = "window: one piece's farm spots", frame = WindowOn("farm", true) },
    { label = "window: Measured", frame = WindowOn("measured") },
    { label = "auction house button", frame = function() return ahButton end, pad = 60 },
  },
}
