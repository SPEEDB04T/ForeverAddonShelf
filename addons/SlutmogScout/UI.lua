-- Slutmog Scout: window (Market, Farm guide, Measured and Review tabs) and the auction house button
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
    tip = "Lowest price in your last scan." },
  { key = "name", label = "Item", fill = true, padL = 10, align = "LEFT" },
  { key = "type", label = "Type", width = 96, padL = 10, align = "LEFT" },
  { key = "rating", label = "Rating", width = 58, padL = 10, align = "RIGHT", numeric = true,
    tip = "Look, 1-10: your rating in colour, the list's estimate in grey. Rate pieces in the Review tab." },
  { key = "value", label = "Worth", width = 90, padL = 10, align = "RIGHT", numeric = true,
    tip = "Estimated slutmog price: vendor price times look, quality and rarity. Grey: not listed now." },
  { key = "vendor", label = "x Vendor", width = 66, padL = 10, align = "RIGHT", numeric = true,
    tip = "Lowest price as a multiple of the vendor price." },
  { key = "qty", label = "Stock", width = 90, padL = 10, padR = 10, align = "RIGHT", numeric = true,
    tip = "Listed now, with your usual count in grey." },
  { key = "seen", label = "Seen %", width = 54, padL = 10, align = "RIGHT", numeric = true,
    tip = "Share of your scans it was listed in." },
  { key = "farm", label = "Farm", width = 74, padL = 10, align = "RIGHT", numeric = true,
    tip = "Time to farm one copy alone. Grey: only the mob level is known." },
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

local TAB_DEFS = { { "market", "Market", 80 }, { "farm", "Farm guide", 90 }, { "measured", "Measured", 90 }, { "review", "Review", 80 },
  { "sell", "Sell", 70 } }
local TAB_INDEX = {}
for i, def in ipairs(TAB_DEFS) do
  TAB_INDEX[def[1]] = i
end

-- listedOnly starts on: the Market list shows what can be bought now
local state = { tab = "market", armor = "all", listedOnly = true, freshOnly = false, sortKey = "value", sortAsc = false, farmItem = nil,
  reviewShow = "todo", reviewSel = nil, reviewIndex = 1, reviewPage = 1, female = true, wholeBody = false }
local win, marketView, farmView, measuredView, reviewView, statusText, scanButton, farmHeader, farmClear, listedCheck, listedText
local sellView, sellMoney
local levelBox
local ReviewSelected, ReviewMoveView -- the review grid's view helpers, defined further down
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
  local function pair(left, right)
    tip:AddDoubleLine(left, right, g1, g2, g3, w1, w2, w3)
  end
  local function note(text)
    tip:AddLine(text, e1, e2, e3, true)
  end
  tip:AddLine(" ")
  tip:AddLine("|cffff66aaSlutmog|r" .. ns.GradeLabel(it) .. ": " .. (it.look or "revealing"), w1, w2, w3, true)
  local look, lookFrom = ns.LookScore(id, it)
  if lookFrom == "rating" then
    pair("Look", ("%d/10 (rated)"):format(look))
  elseif lookFrom == "estimate" then
    pair("Look", ("~%d/10 (estimate)"):format(look))
    if it.estNote and it.estNote ~= "" then
      note(it.estNote)
    end
  end

  -- the auction house now
  tip:AddLine(" ")
  if info.low then
    local qty, usual = ns.Stock(id)
    pair("Lowest now", ns.Money(info.low))
    pair("Listed now", tostring(qty or info.qty or 0) .. (usual and Grey((" (usually %d)"):format(math.floor(usual + 0.5))) or ""))
    local kind, was = ns.Fresh(id)
    if kind == "new" then
      tip:AddLine("New since the scan before.", 0.25, 1, 0.25)
    elseif kind == "cheaper" then
      tip:AddLine("Cheaper than in the scan before (" .. ns.Money(was) .. ").", 0.25, 1, 0.25)
    end
    local nextL = ns.NextListings(id)
    if nextL and #nextL > 1 then
      local parts = {}
      for i = 2, math.min(4, #nextL) do
        parts[#parts + 1] = ns.Money(nextL[i])
      end
      pair("Next listings", table.concat(parts, ", "))
    end
  elseif info.lastSeen then
    pair("Last seen", Ago(info.lastSeen) .. " at " .. ns.Money(info.lastMin))
  elseif info.qty then
    note("Not listed in your scans.")
  else
    note("Not scanned yet.")
  end
  local lo, hi, n = ns.PriceRange(id)
  if n and n >= 2 and info.scans then
    pair("Your scans", ("%s to %s"):format(ns.Money(lo), ns.Money(hi)) .. Grey((", listed in %d of %d"):format(n, info.scans)))
  elseif info.seenPct then
    pair("Listed in", ("%d%% of your scans"):format(Pct(info.seenPct)))
  end

  -- worth and the floor
  if info.fair then
    pair("Slutmog worth (estimate)", ns.Money(info.fair, not info.low))
    note(("%.1fx vendor: %s"):format(info.times or 0, table.concat(info.worthWhy or {}, ", ")))
  end
  if info.vendor and info.vendor > 0 then
    pair("Vendor price", ns.Money(info.vendor) .. (info.low and Grey((" (lowest is %.1fx)"):format(info.low / info.vendor)) or ""))
  end

  -- other items with its look
  local alt = type(it.alt) == "table" and it.alt or {}
  local b = info.low and ns.Buy(id, info) or nil
  if b and b.cheaper and ns.Items()[b.cheaper.id] then
    pair("Same look, cheaper", ns.Items()[b.cheaper.id].name .. " " .. ns.Money(b.cheaper.low))
  end
  if (tonumber(alt.made) or 0) > 0 then
    note(("A crafted item has this look (%s)."):format(it.altName or "made by a profession"))
  elseif (tonumber(alt.plain) or 0) > 0 then
    note(("A white or grey item has this look (%s)."):format(it.altName or "a plain item"))
  end
  local boe, bop = tonumber(alt.boe) or 0, tonumber(alt.bop) or 0
  local same = {}
  if boe > 0 then
    same[#same + 1] = ("%d other BoE %s"):format(boe, boe == 1 and "item" or "items")
  end
  if bop > 0 then
    same[#same + 1] = ("%d bind-on-pickup %s"):format(bop, bop == 1 and "item" or "items")
  end
  if #same > 0 then
    note("Same look on " .. table.concat(same, " and ") .. ".")
  end

  -- where it comes from
  tip:AddLine(" ")
  if it.src == "fishing" then
    tip:AddLine(it.srcNote or "Fished up, not a mob drop.", w1, w2, w3, true)
  else
    local dropText = ns.DropText(it)
    if dropText then
      tip:AddLine(dropText .. ".", w1, w2, w3, true)
    elseif it.inst then
      tip:AddLine("Drops in " .. it.inst .. " (dungeon).", w1, w2, w3, true)
    else
      local mlo, mhi = ns.MobRange(it)
      local names = {}
      for _, sp in ipairs(ns.SpotsForItem(id, 3)) do
        names[#names + 1] = ns.SpotLabel(sp.spot)
      end
      tip:AddLine(("World drop, mobs level %d-%d%s."):format(mlo, mhi,
        #names > 0 and (", e.g. " .. table.concat(names, "; ")) or ""), w1, w2, w3, true)
    end
  end
  local drops = ns.Drops(id)
  if drops then
    local parts = {}
    for _, d in ipairs(SortedCounts(drops)) do
      parts[#parts + 1] = ("%s x%d"):format(d.name, d.n)
    end
    tip:AddLine("Dropped for you: " .. table.concat(parts, ", ") .. ".", w1, w2, w3, true)
  end
  note("Click: farm guide. Right-click: search the auction house.")
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
        border.smogArt = true
      else
        border:Hide()
      end
      row.iconBorder = border
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
        GameTooltip:AddLine("Finds the cheapest copy. You confirm before anything is bought.", 1, 1, 1, true)
        GameTooltip:Show()
      end)
      buy:SetScript("OnLeave", GameTooltip_Hide)
      buy:Hide()
      row.buyButton = buy
    end
  end
  -- a section line ("New or cheaper since your last scan"): gold text across the row
  local st = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  st:SetPoint("LEFT", 8, 0)
  st:SetJustifyH("LEFT")
  st:Hide()
  row.sectionText = st
  row.isSection = false
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

local FRESH_TEXT = { new = "|cff40ff40new|r", cheaper = "|cff40ff40cheaper|r" }

-- Farm time of one copy, short: "40 min", "2.5 h", "87 h".
local function ShortHours(h)
  if h < 1 then
    return ("%d min"):format(math.max(1, math.floor(h * 60 + 0.5)))
  elseif h < 10 then
    return (("%.1f h"):format(h):gsub("%.0 h", " h"))
  end
  return ("%d h"):format(math.floor(h + 0.5))
end

-- Rows for the market list. Numeric columns use -1 for "no value"; those rows
-- always sort to the bottom, whichever way the column is sorted.
local function MarketData()
  local rows = {}
  for id, it in pairs(ns.Items()) do
    local info = ArmorFilter(it) and ns.Price(id)
    if info and ns.Shown(it, info) then
      local fresh = info.low and ns.Fresh(id) or nil
      if (not state.listedOnly or info.low) and (not state.freshOnly or fresh) then
        local lo, hi = ns.MobRange(it)
        local look, lookFrom = ns.LookScore(id, it)
        local rated = lookFrom == "rating" or lookFrom == "estimate"
        local _, usual = ns.Stock(id)
        local hours = type(it.drop) == "table" and tonumber(it.drop.hours) or nil
        rows[#rows + 1] = {
          rating = rated and look or -1, ratingFrom = lookFrom, fresh = fresh, usual = usual, hours = hours,
          id = id, it = it, info = info, lo = lo, hi = hi,
          name = it.name or "", type = TypeLabel(it),
          low = info.low or -1, qty = (info.qty and info.qty > 0) and info.qty or -1, value = info.value or -1,
          vendor = (info.low and info.vendor and info.vendor > 0) and info.low / info.vendor or -1,
          seen = info.seenPct or -1, farm = hours or -1,
        }
      end
    end
  end
  local key, asc, numeric = state.sortKey, state.sortAsc, NUMERIC[state.sortKey]
  table.sort(rows, function(a, b)
    -- new or cheaper since the scan before: a group of their own at the top
    -- (SuccuDev, 2026-11-15: "new since last scan should be separated more")
    if (a.fresh ~= nil) ~= (b.fresh ~= nil) then
      return a.fresh ~= nil
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
  local nFresh = 0
  for _, d in ipairs(data) do
    if d.fresh then
      nFresh = nFresh + 1
    end
  end
  local lines = data
  if nFresh > 0 and not state.freshOnly then
    lines = { { section = ("New or cheaper since your last scan (%d)"):format(nFresh) } }
    for i, d in ipairs(data) do
      if i == nFresh + 1 then
        lines[#lines + 1] = { section = ("Everything else (%d)"):format(#data - nFresh) }
      end
      lines[#lines + 1] = d
    end
  end
  marketView.list:SetCount(#lines)
  for i, d in ipairs(lines) do
    local row = marketView.list.rows[i]
    SetStripe(row, i)
    local c = row.cells
    row.isSection = d.section ~= nil
    if d.section then
      row.id = nil
      row.sectionText:SetText(d.section)
      row.sectionText:Show()
      row.icon:Hide()
      row.iconBorder:Hide()
      row.buyButton:Hide()
      for _, col in ipairs(COLS) do
        c[col.key]:SetText("")
      end
    else
      row.sectionText:Hide()
      row.icon:Show()
      row.iconBorder:SetShown(row.iconBorder.smogArt == true)
      row.id = d.id
      row.icon:SetTexture(ItemIcon(d.id))
      c.name:SetText(ItemName(d.id, d.it) .. (d.it.custom and (" " .. Grey("*")) or "")
        .. (d.fresh and ("  " .. FRESH_TEXT[d.fresh]) or ""))
      c.type:SetText(d.type)
      if d.rating < 0 then
        c.rating:SetText("")
      elseif d.ratingFrom == "estimate" then
        c.rating:SetText(Grey(("~%d"):format(d.rating)))
      else
        -- as in the Review tab: green 7+, gold on the list, red off it
        c.rating:SetText(("|cff%s%d/10|r"):format(d.rating >= 7 and "40ff40" or d.rating >= ns.RATING_KEEP and "ffd100" or "ff4040", d.rating))
      end
      if d.info.low then
        c.low:SetText(ns.Money(d.info.low))
      elseif d.info.qty then
        c.low:SetText(Grey("none"))
      else
        c.low:SetText(Grey("?"))
      end
      if d.info.qty and d.info.qty > 0 then
        c.qty:SetText(d.info.qty .. (d.usual and (" " .. Grey(("(%s)"):format(math.floor(d.usual + 0.5)))) or ""))
      else
        c.qty:SetText("")
      end
      c.vendor:SetText(d.vendor >= 0 and ("%.1fx"):format(d.vendor) or "")
      row.buyButton:SetShown(d.info.low ~= nil and ahOpen)
      -- grey: a remembered price for a piece that is not listed right now
      c.value:SetText(ns.Money(d.info.value, d.info.value ~= nil and not d.info.low))
      c.seen:SetText(d.info.seenPct and ("%d%%"):format(Pct(d.info.seenPct)) or "")
      if d.hours then
        c.farm:SetText(ShortHours(d.hours))
      elseif d.it.src == "fishing" then
        c.farm:SetText(Grey("fishing"))
      elseif d.it.inst then
        c.farm:SetText(Grey("dungeon"))
      else
        c.farm:SetText(Grey(("lvl %d-%d"):format(d.lo, d.hi)))
      end
    end
  end
  if state.freshOnly then
    marketView.empty:SetText(ns.db.lastScan and "Nothing is new or cheaper than in the scan before. Untick Filter > New or cheaper to see every piece."
      or "No scan yet. Open the auction house and scan.")
  elseif state.listedOnly then
    marketView.empty:SetText(ns.db.lastScan and "None of these pieces was listed in your last scan. Scan again, or untick Filter > Listed now only to see every piece."
      or "No scan yet. Open the auction house and scan, or untick Filter > Listed now only to see every piece.")
  else
    marketView.empty:SetText("No pieces match this filter.")
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
  GameTooltip:AddLine("After the 5% auction house cut. Grey: not listed now.", GREY[1], GREY[2], GREY[3], true)
  if not state.farmItem then
    GameTooltip:AddLine("The sum of the pieces that can drop here, not gold per hour.", GREY[1], GREY[2], GREY[3], true)
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
    elseif it.drop and it.drop.mob then
      local d = it.drop
      farmHeader:SetText(ItemName(itemFilter, it) .. "  " .. Grey(("best: %s%s, about %s a copy"):format(d.mob,
        d.zone and (" in " .. d.zone) or "", ns.Hours(d.hours))))
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
  GameTooltip:AddLine("List pieces only, at today's price after the 5% cut. Pauses over 5 min are left out.", GREY[1], GREY[2], GREY[3], true)
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
-- Review tab: every piece, on the list or left off, in a grid of models like
-- the game's Appearances window, each rated 1 to 10 by the player. A rating
-- of 4 or more puts a piece on the list (and never hides it as cropped), 1 to
-- 3 takes it off; the rating scales the buy score. import_review.py copies
-- the ratings into the item list's generator.
-------------------------------------------------------------------------------
local REVIEW_SHOW = { { "todo", "Not rated yet" }, { "off", "Left off the list" }, { "on", "On the list" }, { "all", "All pieces" } }
local REVIEW_COLS, REVIEW_ROWS = 9, 2
local REVIEW_PER_PAGE = REVIEW_COLS * REVIEW_ROWS

-- Where the piece stands now, in a few words.
local function ListStatus(p)
  local it = ns.Items()[p.id]
  local verdict = ns.ReviewVerdict(p.flag)
  if not it then
    if verdict == false then
      return type(p.flag) == "number" and "off the list (your rating)" or "off the list (your no)"
    elseif p.onList then
      return ns.db.hidden[p.id] and "removed by you" or "hidden by the game-build check"
    end
    return "left off the list"
  end
  if not p.onList and verdict == true then
    return type(p.flag) == "number" and "on the list (your rating)" or "on the list (your yes)"
  end
  if it.grade == "cropped" and not it.reviewYes and not ns.ShowCropped() then
    return "on the list, hidden as cropped"
  end
  if not ns.ShowCommon() and ns.Common(it) then
    return "on the list, hidden as easy, common gear"
  end
  return "on the list"
end

-- "8/10" in green (7+), yellow (4-6) or red (1-3); old answers as Yes or No
local function FlagLabel(flag)
  local n = tonumber(flag)
  if n then
    local hex = n >= 7 and "40ff40" or n >= ns.RATING_KEEP and "ffd100" or "ff4040"
    return ("|cff%s%d/10|r"):format(hex, n)
  elseif flag == true then
    return "|cff40ff40Yes|r"
  elseif flag == false then
    return "|cffff4040No|r"
  end
  return ""
end

local function ReviewDetail(p)
  local s = p.src
  local look = s.look or "not measured"
  if s.grade then
    look = s.grade .. ": " .. look
  end
  if tonumber(s.est) and not (p.why and p.why:find("estimate", 1, true)) then
    look = ("estimated %d/10%s; "):format(s.est, s.estNote and (" (" .. s.estNote .. ")") or "") .. look
  end
  if p.why and not p.onList then
    return p.why .. "; " .. look
  end
  return look
end

local function ReviewData()
  local rows = {}
  local listed = ns.Items()
  for _, p in ipairs(ns.ReviewPieces()) do
    local s = p.src
    local on = listed[p.id] ~= nil
    local want = state.reviewShow
    if ArmorFilter(s) and ns.InLevelRange(s) and (want == "all" or (want == "todo" and p.flag == nil)
        or (want == "on" and on) or (want == "off" and not on)) then
      rows[#rows + 1] = p
    end
  end
  -- the barest first: on the list the most likely to be right, off it the
  -- most likely to be missing
  table.sort(rows, function(a, b)
    local as, bs = a.src.skin or -1, b.src.skin or -1
    if as ~= bs then
      return as > bs
    end
    return a.id < b.id
  end)
  return rows
end

local function ReviewItemName(p)
  return ("|c%s%s|r"):format(QualityHex(p.src.q or 2), p.src.name or ("Item " .. p.id))
end

-- How the grid's models are framed. Up close, a chest piece shows the torso
-- and a leg piece the hips and thighs; "whole body" shows all of it.
--   zoom  how far the body comes toward the camera
--   lift  moves the body up (+) or down (-), so the camera sees lower or higher
-- Both are in yards of a human-sized body, scaled by the race's height. The
-- wheel and a right-drag on the grid change the framing of the piece type
-- under the pointer for every tile, and it is saved.
local REVIEW_CAM = {
  chest = { zoom = 2, lift = -0.4 },
  legs = { zoom = 1.8, lift = 0.25 },
  body = { zoom = 0, lift = 0 },
}
local CAM_ZOOM_MIN, CAM_ZOOM_MAX = -0.5, 3
local CAM_LIFT_MIN, CAM_LIFT_MAX = -1.3, 1.3
-- body height against a human's (assumed; the framing can be moved by hand)
local RACE_SIZE = { Gnome = 0.55, Dwarf = 0.8, Goblin = 0.6, Tauren = 1.2, NightElf = 1.1, Troll = 1.05, Draenei = 1.1 }
ns.REVIEW_CAM = REVIEW_CAM

local function RaceSize()
  local ok, _, raceFile = pcall(UnitRace, "player")
  return ok and RACE_SIZE[raceFile] or 1
end

-- "chest", "legs" or "body": which framing a piece gets
local function CamKind(p)
  if state.wholeBody then
    return "body"
  end
  return p and p.src and p.src.slot == "legs" and "legs" or "chest"
end

-- the framing in use for that kind: the player's own, else the default
local function ReviewCam(kind)
  local saved = ns.db and ns.db.opts and type(ns.db.opts.reviewCam) == "table" and ns.db.opts.reviewCam[kind]
  local def = REVIEW_CAM[kind] or REVIEW_CAM.body
  if type(saved) == "table" and type(saved.zoom) == "number" and type(saved.lift) == "number" then
    return saved
  end
  return { zoom = def.zoom, lift = def.lift }
end

local function SetReviewCam(kind, zoom, lift)
  local opts = ns.db.opts
  opts.reviewCam = type(opts.reviewCam) == "table" and opts.reviewCam or {}
  opts.reviewCam[kind] = {
    zoom = math.floor(math.max(CAM_ZOOM_MIN, math.min(CAM_ZOOM_MAX, zoom)) * 1000 + 0.5) / 1000,
    lift = math.floor(math.max(CAM_LIFT_MIN, math.min(CAM_LIFT_MAX, lift)) * 1000 + 0.5) / 1000,
  }
end
ns.ReviewCam = ReviewCam

local function FrameModel(tile)
  local model = tile and tile.model
  if not (model and tile.entry) then
    return
  end
  local cam, size = ReviewCam(CamKind(tile.entry)), RaceSize()
  tile.camZoom, tile.camLift = cam.zoom * size, cam.lift * size
  pcall(model.SetPosition, model, tile.camZoom, 0, tile.camLift)
end

-- Dresses a grid tile's model in its piece: the player's own body, or a
-- female one of the player's race when the player's character is male (the
-- list measures the female textures).
local function DressModel(tile, id)
  local model = tile and tile.model
  if not model or not id then
    return
  end
  tile.wantId = id
  local function dress()
    if tile.wantId ~= id then
      return -- the tile shows another piece by now
    end
    local sex = UnitSex and UnitSex("player")
    local custom = false
    if state.female and sex ~= 3 and model.SetCustomRace then
      custom = pcall(function()
        local _, _, raceID = UnitRace("player")
        local female = Enum and Enum.UnitSex and Enum.UnitSex.Female or 1
        model:SetCustomRace(raceID or 1, female)
      end)
    end
    if not custom then
      pcall(model.SetUnit, model, "player") -- the player's own body
    end
    pcall(model.Undress, model)
    pcall(model.TryOn, model, "item:" .. id)
    FrameModel(tile)
  end
  if C_Item.GetItemInfo(id) or not (Item and Item.CreateFromItemID) then
    dress()
  else
    local ok, item = pcall(Item.CreateFromItemID, Item, id)
    if ok and item then
      item:ContinueOnItemLoad(dress)
    end
  end
end

-- the pieces the grid shows now, kept for the page buttons and the keys
local reviewData = {}

local function RefreshReview()
  local data = ReviewData()
  reviewData = data
  -- keep the selected piece; when it left the view (just rated), take the
  -- one that moved into its place
  local index
  for i, p in ipairs(data) do
    if p.id == state.reviewSel then
      index = i
    end
  end
  if not index and #data > 0 then
    index = math.min(math.max(1, state.reviewIndex or 1), #data)
  end
  local sel = index and data[index] or nil
  state.reviewSel, state.reviewIndex = sel and sel.id or nil, index or 1
  -- the page that holds the selected piece
  local pages = math.max(1, math.ceil(#data / REVIEW_PER_PAGE))
  local page = index and math.ceil(index / REVIEW_PER_PAGE) or 1
  state.reviewPage = page
  local first = (page - 1) * REVIEW_PER_PAGE
  for i, tile in ipairs(reviewView.tiles) do
    local p = data[first + i]
    tile.entry = p
    tile:SetShown(p ~= nil)
    if p then
      tile.name:SetText(ReviewItemName(p))
      -- the player's own rating, else the estimate the list ships with, in grey
      tile.rating:SetText(p.flag ~= nil and FlagLabel(p.flag)
        or tonumber(p.src.est) and Grey(("~%d/10"):format(p.src.est)) or "")
      tile.info:SetText(Grey(("%s %d%s"):format(TypeLabel(p.src), p.src.req or 1,
        p.src.skin and (", " .. p.src.skin .. "% bare") or "")))
      tile.selected:SetShown(p.id == state.reviewSel)
      tile.onList:SetShown(ns.Items()[p.id] ~= nil)
      if tile.shownId ~= p.id or tile.shownFemale ~= state.female then
        tile.shownId, tile.shownFemale = p.id, state.female
        DressModel(tile, p.id)
      else
        FrameModel(tile)
      end
    else
      tile.shownId = nil
    end
  end
  reviewView.pageText:SetText(("Page %d of %d"):format(page, pages))
  reviewView.prev:SetEnabled(page > 1)
  reviewView.next:SetEnabled(page < pages)
  reviewView.empty:SetShown(#data == 0)
  if state.reviewShow == "todo" then
    reviewView.empty:SetText("Every piece in this filter has your rating. Filter > All pieces shows them again.")
  else
    reviewView.empty:SetText("No pieces match this filter.")
  end
  local bar = reviewView.bar
  bar.female:SetChecked(state.female)
  local rated = sel and tonumber(sel.flag)
  for n, b in ipairs(bar.rates) do
    b:SetEnabled(sel ~= nil)
    if rated == n then
      b:LockHighlight()
    else
      b:UnlockHighlight()
    end
  end
  if not sel then
    bar.name:SetText("")
    bar.info:SetText("")
    bar.clear:Disable()
    return
  end
  bar.name:SetText(ReviewItemName(sel))
  bar.info:SetText(("%s, level %d. %s.%s  %s"):format(TypeLabel(sel.src), sel.src.req or 1, ListStatus(sel),
    sel.flag ~= nil and (" Yours: " .. FlagLabel(sel.flag) .. ".") or "", Grey(ReviewDetail(sel))))
  bar.clear:SetEnabled(sel.flag ~= nil)
end

local function ReviewFlagSelected(flag)
  local id = state.reviewSel
  if id then
    ns.SetReview(id, flag) -- fires ITEMS, which refreshes the window
  end
end

-- Goes to another page of the grid and selects its first piece.
local function ReviewPage(delta)
  local pages = math.max(1, math.ceil(#reviewData / REVIEW_PER_PAGE))
  local page = math.min(pages, math.max(1, (state.reviewPage or 1) + delta))
  local p = reviewData[(page - 1) * REVIEW_PER_PAGE + 1]
  if p then
    state.reviewSel, state.reviewIndex = p.id, (page - 1) * REVIEW_PER_PAGE + 1
    Refresh()
  end
end

-- the selected piece's entry, or nil
function ReviewSelected()
  for _, p in ipairs(reviewData) do
    if p.id == state.reviewSel then
      return p
    end
  end
  return nil
end

-- Zooms (dz) or moves up and down (dy, in tile heights) the framing of p's
-- piece type, for every tile showing that type.
function ReviewMoveView(p, dz, dy)
  local kind = CamKind(p)
  local cam = ReviewCam(kind)
  -- a tile height shows about 2 yards at zoom 0, less up close
  SetReviewCam(kind, cam.zoom + dz, cam.lift + dy * 2 / (1 + math.max(0, cam.zoom) * 0.6))
  for _, tile in ipairs(reviewView and reviewView.tiles or {}) do
    if tile:IsShown() and tile.entry and CamKind(tile.entry) == kind then
      FrameModel(tile)
    end
  end
end

-- Moves the selection by delta pieces (the arrow keys).
local function ReviewStep(delta)
  local i = math.min(#reviewData, math.max(1, (state.reviewIndex or 1) + delta))
  local p = reviewData[i]
  if p then
    state.reviewSel, state.reviewIndex = p.id, i
    Refresh()
  end
end

-- all pieces, the rated ones (old yes or no answers included), the ones a
-- rating or yes keeps on the list and the ones it takes off
local function ReviewCounts()
  local all, kept, off = 0, 0, 0
  for _, p in ipairs(ns.ReviewPieces()) do
    all = all + 1
    local v = ns.ReviewVerdict(p.flag)
    if v == true then
      kept = kept + 1
    elseif v == false then
      off = off + 1
    end
  end
  return all, kept, off
end

-------------------------------------------------------------------------------
-- Sell tab: a sell box for the selected bag piece over a list of the bag
-- pieces (one copy each) and your auctions, as in the auction house's own
-- Sell and Auctions tabs.
-------------------------------------------------------------------------------
local SELL_COLS = {
  { key = "name", label = "Item", fill = true, padL = 10, align = "LEFT" },
  { key = "price", label = "Price", width = 110, padL = 10, align = "RIGHT" },
  { key = "low", label = "Lowest", width = 110, padL = 10, align = "RIGHT" },
  { key = "others", label = "Others", width = 64, padL = 10, align = "RIGHT" },
  { key = "left", label = "Time left", width = 96, padL = 10, align = "RIGHT" },
  { key = "status", label = "Status", width = 84, padL = 10, align = "LEFT" },
  { key = "act", label = "", width = 84, padL = 6, padR = 6, align = "LEFT" },
}
do
  local fixed = 0
  for _, col in ipairs(SELL_COLS) do
    fixed = fixed + (col.width or 0)
  end
  local x = 0
  for _, col in ipairs(SELL_COLS) do
    if col.fill then
      col.width = HEADER_W - fixed
    end
    col.x = x
    x = x + col.width
  end
end
local SELL_STATUS = { undercut = "|cffff4040Undercut|r", lowest = "|cff40ff40Lowest|r" }

local function MoneyGet()
  local m = sellMoney
  if m and type(MoneyInputFrame_GetCopper) == "function" then
    local ok, c = pcall(MoneyInputFrame_GetCopper, m)
    c = ok and tonumber(c) or nil
    if c and c > 0 then
      return c
    end
  end
  return nil
end

local function MoneySet(copper)
  local m = sellMoney
  if m and type(MoneyInputFrame_SetCopper) == "function" then
    pcall(MoneyInputFrame_SetCopper, m, copper)
  end
end

local function MarketText(m)
  if not m then
    return Grey("...")
  elseif m.unknown then
    return Grey("?")
  elseif m.low then
    return ns.Money(m.low)
  end
  return Grey("none")
end

local function OthersText(m)
  if not m or m.unknown then
    return ""
  end
  return m.more and (m.count .. "+") or tostring(m.count)
end

-- the bag piece in the sell box: the one picked, else the first not listed
local function SellSelected(bags)
  local first
  for _, r in ipairs(bags) do
    if not r.listed then
      if r.id == state.sellSel then
        return r
      end
      first = first or r
    end
  end
  return first
end

local function SellSelectedNow()
  return SellSelected((ns.SellRows()))
end

-- Post: the sell box's price for the piece in it, else the piece's own default.
local function SellPostRow(r)
  if not r then
    return
  end
  local price
  if sellView and state.sellBoxId == r.id then
    price = MoneyGet()
  end
  if not price then
    price = ns.DefaultPostPrice(r.id, r.market, r.link)
  end
  ns.SellPost(r.entry, price)
end

local function SellInfoLine(r)
  local parts = {}
  local m = r.market
  if not m then
    parts[#parts + 1] = "Reading listings..."
  elseif m.unknown then
    parts[#parts + 1] = "Listings unknown"
  elseif m.low then
    parts[#parts + 1] = ("Lowest %s, %s %s"):format(ns.Money(m.low), OthersText(m), m.count == 1 and "other" or "others")
  else
    parts[#parts + 1] = "No other listings"
  end
  if r.count > 1 then
    parts[#parts + 1] = ("%d in bags"):format(r.count)
  end
  return table.concat(parts, ", ")
end

local function RefreshSellBox(bags)
  local box = sellView.box
  local r = SellSelected(bags)
  local ahOpen = ns.AuctionHouseOpen()
  if not r then
    state.sellBoxId = nil
    box.icon:SetTexture(nil)
    box.name:SetText(Grey(#bags > 0 and "Every piece in your bags is listed" or "No list piece in your bags"))
    box.info:SetText("")
    box.note:SetText("")
    box.post:SetEnabled(false)
    return
  end
  box.icon:SetTexture(ItemIcon(r.id))
  box.name:SetText(r.link or ItemName(r.id))
  box.info:SetText(Grey(SellInfoLine(r)))
  local price, source = ns.DefaultPostPrice(r.id, r.market, r.link)
  local current = MoneyGet()
  if state.sellBoxId ~= r.id or current == nil or current == state.sellBoxSet then
    MoneySet(price)
    state.sellBoxSet = price
  end
  state.sellBoxId = r.id
  state.sellSel = r.id
  local deposit = ns.PostDeposit(r.entry)
  box.note:SetText(Grey(source .. (deposit and (", deposit " .. ns.Money(deposit)) or "")))
  box.post:SetEnabled(ahOpen and not ns.sell.pending)
end

local function RefreshSell()
  local bags, auctions = ns.SellRows()
  RefreshSellBox(bags)
  local ahOpen = ns.AuctionHouseOpen()
  local busy = ns.sell.pending ~= nil
  local rows = {}
  if #bags > 0 then
    rows[#rows + 1] = { section = ("In your bags (%d)"):format(#bags) }
    for _, r in ipairs(bags) do
      rows[#rows + 1] = r
    end
  end
  if #auctions > 0 then
    rows[#rows + 1] = { section = ("Your auctions (%d)"):format(#auctions) }
    for _, r in ipairs(auctions) do
      rows[#rows + 1] = r
    end
  end
  local list = sellView.list
  list:SetCount(#rows)
  for i, d in ipairs(rows) do
    local row = list.rows[i]
    row.data = d.section == nil and d or false
    row.id = d.id
    SetStripe(row, i)
    local c = row.cells
    row.act:Hide()
    row.selected:SetShown(d.kind == "bag" and d.id == state.sellBoxId)
    if d.section then
      row.sectionText:SetText(d.section)
      row.sectionText:Show()
      row.icon:Hide()
      row.iconBorder:Hide()
      for _, col in ipairs(SELL_COLS) do
        c[col.key]:SetText("")
      end
    else
      row.sectionText:Hide()
      row.icon:Show()
      row.iconBorder:SetShown(row.iconBorder.smogArt == true)
      row.icon:SetTexture(ItemIcon(d.id))
      c.low:SetText(MarketText(d.market))
      c.others:SetText(OthersText(d.market))
      if d.kind == "bag" then
        c.name:SetText((d.link or ItemName(d.id)) .. (d.count > 1 and Grey(" x" .. d.count) or ""))
        local price = ns.DefaultPostPrice(d.id, d.market, d.link)
        c.price:SetText(ns.Money(price, d.listed))
        c.left:SetText("")
        c.status:SetText(d.listed and Grey("Listed") or "")
        if not d.listed and ahOpen then
          row.act:SetText("Post")
          row.act:SetEnabled(not busy)
          row.act:Show()
        end
      else
        c.name:SetText(d.link or ItemName(d.id))
        c.price:SetText(d.price and ns.Money(d.price, d.status == "sold") or "")
        c.left:SetText(d.status == "sold" and "" or (d.left and Dur(d.left) or ""))
        c.status:SetText(d.status == "sold" and Grey("Sold") or SELL_STATUS[d.status] or Grey("..."))
        if d.status ~= "sold" and ahOpen then
          row.act:SetText("Cancel")
          row.act:SetEnabled(not ns.sell.cancelling)
          row.act:Show()
        end
      end
    end
  end
  sellView.empty:SetText(ahOpen and "No list piece in your bags or on the auction house." or "Open the auction house to sell.")
  sellView.empty:SetShown(#rows == 0)
end

-------------------------------------------------------------------------------
-- Window
-------------------------------------------------------------------------------
-- the scan advice's colour: green when fresh, gold when due, red when stale
local SCAN_HEX = { fresh = "ff40c040", due = "ffffd100", stale = "ffff5050", none = "ffffd100" }

local function ScanTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Slutmog scan")
  local level, advice = ns.ScanAdvice()
  local r, g, b = 1, 0.82, 0
  if level == "fresh" then
    r, g, b = 0.25, 0.75, 0.25
  elseif level == "stale" then
    r, g, b = 1, 0.31, 0.31
  end
  GameTooltip:AddLine(advice, r, g, b, true)
  if ns.db.opts.autoScan then
    GameTooltip:AddLine("Scans by itself when prices are over 30 min old.", 1, 1, 1, true)
  end
  GameTooltip:Show()
end
ns.ScanTooltip = ScanTooltip

local function UpdateStatus()
  if not win then
    return
  end
  local scan = ns.scan
  if state.tab == "sell" and not scan.active then
    if not ns.AuctionHouseOpen() then
      statusText:SetText("Open the auction house to sell.")
    else
      local post, listed, under, left = ns.SellCounts()
      local parts = { ("%d to post"):format(post), ("%d listed"):format(listed) }
      if under > 0 then
        parts[#parts + 1] = ("|cffff4040%d undercut|r"):format(under)
      end
      if left > 0 then
        parts[#parts + 1] = Grey(("reading listings, %d left"):format(left))
      end
      statusText:SetText(table.concat(parts, ", "))
    end
    scanButton:SetText("Refresh")
    scanButton:SetEnabled(ns.AuctionHouseOpen())
  elseif scan.active then
    statusText:SetText(("Scanning... %d search results read"):format(scan.rows or 0))
    scanButton:SetText("Scanning")
    scanButton:Disable()
  elseif ns.ladder and ns.ladder.active then
    statusText:SetText(("Reading listings... %d left"):format(#ns.ladder.queue + (ns.ladder.current and 1 or 0)))
    scanButton:SetText("Scan")
    scanButton:SetEnabled(ns.AuctionHouseOpen())
  elseif state.tab == "review" then
    local all, kept, off = ReviewCounts()
    statusText:SetText(("%d of %d rated: %d kept, %d off. 4-10 keeps, 1-3 takes off. Keys 1-9 and 0 rate, arrows move.")
      :format(kept + off, all, kept, off))
    scanButton:SetText("Scan")
    scanButton:SetEnabled(ns.AuctionHouseOpen())
  else
    local n = 0
    for _ in pairs(ns.Items()) do
      n = n + 1
    end
    local hidden = ns.CheckHidden()
    local level, advice = ns.ScanAdvice()
    statusText:SetText(("|c%s%s|r  %d pieces.%s"):format(SCAN_HEX[level] or SCAN_HEX.due, advice, n,
      hidden > 0 and (" %d hidden (/smog verify)."):format(hidden) or ""))
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
  local filterUseful = state.tab == "market" or state.tab == "review" or (state.tab == "farm" and not (state.farmItem and ns.Items()[state.farmItem]))
  if levelBox then
    levelBox:SetShown(filterUseful)
    levelBox.Sync()
  end
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
    listedCheck:SetChecked(state.listedOnly)
    listedText:SetShown(state.tab == "market")
    dealsCheck:SetShown(state.tab == "market")
    dealsText:SetShown(state.tab == "market")
    local lookUseful = filterUseful and state.tab ~= "review"
    croppedCheck:SetShown(lookUseful)
    croppedText:SetShown(lookUseful)
    croppedCheck:SetChecked(ns.ShowCropped())
    commonCheck:SetShown(lookUseful)
    commonText:SetShown(lookUseful)
    commonCheck:SetChecked(ns.ShowCommon())
  end
  marketView:SetShown(state.tab == "market")
  farmView:SetShown(state.tab == "farm")
  measuredView:SetShown(state.tab == "measured")
  reviewView:SetShown(state.tab == "review")
  sellView:SetShown(state.tab == "sell")
  if state.tab == "market" then
    RefreshMarket()
  elseif state.tab == "farm" then
    RefreshFarm()
  elseif state.tab == "review" then
    RefreshReview()
  elseif state.tab == "sell" then
    RefreshSell()
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
  if key == "sell" then
    ns.SellRefresh()
  end
end

local function FilterIsDefault()
  return state.armor == "all" and state.listedOnly and not state.freshOnly and not ns.ShowCropped() and not ns.ShowCommon()
    and state.reviewShow == "todo"
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
      root:CreateCheckbox("New or cheaper", function()
        return state.freshOnly
      end, function()
        state.freshOnly = not state.freshOnly
        Refresh()
      end)
    end
    if state.tab == "review" then
      root:QueueSpacer()
      root:CreateTitle("Show")
      for _, def in ipairs(REVIEW_SHOW) do
        root:CreateRadio(def[2], function()
          return state.reviewShow == def[1]
        end, function()
          state.reviewShow = def[1]
          state.reviewIndex = 1
          Refresh()
        end, def[1])
      end
      root:QueueSpacer()
      root:CreateTitle("View")
      root:CreateRadio("The piece up close", function()
        return not state.wholeBody
      end, function()
        state.wholeBody = false
        Refresh()
      end, "close")
      root:CreateRadio("The whole body", function()
        return state.wholeBody
      end, function()
        state.wholeBody = true
        Refresh()
      end, "body")
      if root.CreateButton then
        root:CreateButton("Reset zoom and position", function()
          ns.db.opts.reviewCam = nil
          Refresh()
        end)
      end
      return
    end
    -- cropped looks: a top that covers the bust, shorts that cover most of the thigh
    root:QueueSpacer()
    root:CreateTitle("Look")
    root:CreateCheckbox("Show cropped pieces", ns.ShowCropped, function()
      ns.SetShowCropped(not ns.ShowCropped())
    end)
    -- easy, common gear: the most common share of the list by drop data (options slider)
    root:CreateCheckbox("Show easy, common pieces", ns.ShowCommon, function()
      ns.SetShowCommon(not ns.ShowCommon())
    end)
  end)
  if not ok then
    dd:Hide()
    return nil
  end
  if pcall(dd.SetIsDefaultCallback, dd, FilterIsDefault) and pcall(dd.SetDefaultCallback, dd, function()
    state.armor, state.listedOnly, state.freshOnly, state.reviewShow = "all", true, false, "todo"
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
  dealsText:SetText("New or cheaper")
  dealsCheck:SetScript("OnClick", function(self)
    state.freshOnly = self:GetChecked() and true or false
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

-- Level range: the classic auction house's two level boxes (InputBoxTemplate,
-- "Level Range" and a dash), left of the filter. Saved; empty means no limit.
local function CreateLevelRange(anchor)
  local box = CreateFrame("Frame", nil, win)
  box:SetSize(150, 22)
  box:SetPoint("RIGHT", anchor, "LEFT", -14, 0)
  local function MakeBox()
    local e = TryCreate("EditBox", nil, box, "InputBoxTemplate") or CreateFrame("EditBox", nil, box)
    e:SetSize(26, 20)
    e:SetAutoFocus(false)
    e:SetNumeric(true)
    e:SetMaxLetters(2)
    e:SetJustifyH("CENTER")
    return e
  end
  local maxBox = MakeBox()
  maxBox:SetPoint("RIGHT", box, "RIGHT", 0, 0)
  local dash = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dash:SetPoint("RIGHT", maxBox, "LEFT", -6, 0)
  dash:SetText("-")
  local minBox = MakeBox()
  minBox:SetPoint("RIGHT", dash, "LEFT", -8, 0)
  local label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  label:SetPoint("RIGHT", minBox, "LEFT", -10, 0)
  label:SetText("Level range")
  box.min, box.max = minBox, maxBox
  function box.Sync()
    local lo, hi = ns.LevelRange()
    if not minBox:HasFocus() then
      minBox:SetText(lo and tostring(lo) or "")
    end
    if not maxBox:HasFocus() then
      maxBox:SetText(hi and tostring(hi) or "")
    end
  end
  local function Apply()
    local lo, hi = ns.LevelRange()
    local newLo, newHi = tonumber(minBox:GetText() or ""), tonumber(maxBox:GetText() or "")
    if newLo ~= lo or newHi ~= hi then
      ns.SetLevelRange(newLo, newHi) -- fires ITEMS, which refreshes the window
    end
    box.Sync()
  end
  box.Apply = Apply
  for _, e in ipairs({ minBox, maxBox }) do
    e:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
    end)
    e:SetScript("OnEditFocusLost", Apply)
    e:SetScript("OnEscapePressed", function(self)
      local lo, hi = ns.LevelRange()
      local v = self == minBox and lo or hi
      self:SetText(v and tostring(v) or "")
      self:ClearFocus()
    end)
    e:SetScript("OnTabPressed", function(self)
      (self == minBox and maxBox or minBox):SetFocus()
    end)
    e:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Level range")
      GameTooltip:AddLine("Shows only pieces of this required level. Leave a box empty for no limit.", 1, 1, 1, true)
      GameTooltip:Show()
    end)
    e:SetScript("OnLeave", GameTooltip_Hide)
  end
  box.Sync()
  return box
end

-- The Review tab: a grid of models, one per piece, like the game's
-- Appearances window, with the selected piece and the 1-10 rating buttons in
-- a bar under it.
local REVIEW_BAR_H = 58
local REVIEW_KEYS = { NUMPAD0 = 10, ["0"] = 10 }
local REVIEW_PAGE_KEYS = { PAGEUP = -1, PAGEDOWN = 1 }
for n = 1, 9 do
  REVIEW_KEYS[tostring(n)], REVIEW_KEYS["NUMPAD" .. n] = n, n
end

-- the game's page arrows (the collections journal and the spellbook use them)
local function PageArrow(parent, dir, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(26, 26)
  local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. dir .. "Page-"
  pcall(b.SetNormalTexture, b, base .. "Up")
  pcall(b.SetPushedTexture, b, base .. "Down")
  pcall(b.SetDisabledTexture, b, base .. "Disabled")
  pcall(b.SetHighlightTexture, b, "Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  b:SetScript("OnClick", onClick)
  return b
end

local function CreateReviewView()
  reviewView = MakeView()
  local view = reviewView
  local grid = MakeInset(view)
  grid:SetPoint("TOPLEFT", 0, 0)
  grid:SetPoint("BOTTOMRIGHT", 0, REVIEW_BAR_H)
  view.grid = grid
  view.empty = MakeEmptyText(view, grid)
  view.empty:ClearAllPoints()
  view.empty:SetPoint("TOP", grid, "TOP", 0, -60)
  view.empty:SetPoint("LEFT", grid, "LEFT", 45, 0)
  view.empty:SetPoint("RIGHT", grid, "RIGHT", -45, 0)

  -- tile size from the view's size (931 x 461 in the 940 x 560 window)
  local GAP, PAD = 4, 6
  local gridW, gridH = WIN_W - 9, WIN_H + VIEW_TOP - VIEW_BOTTOM - REVIEW_BAR_H
  local tileW = math.floor((gridW - 2 * PAD - (REVIEW_COLS - 1) * GAP) / REVIEW_COLS)
  local tileH = math.floor((gridH - 2 * PAD - (REVIEW_ROWS - 1) * GAP) / REVIEW_ROWS)
  view.tiles = {}
  for i = 1, REVIEW_PER_PAGE do
    local col, row = (i - 1) % REVIEW_COLS, math.floor((i - 1) / REVIEW_COLS)
    local tile = CreateFrame("Button", nil, grid)
    tile:SetSize(tileW, tileH)
    tile:SetPoint("TOPLEFT", PAD + col * (tileW + GAP), -(PAD + row * (tileH + GAP)))
    local bg = MakeInset(tile)
    bg:SetAllPoints()
    pcall(tile.RegisterForClicks, tile, "LeftButtonUp", "RightButtonUp")
    pcall(tile.SetHighlightTexture, tile, "Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
    tile.selected = tile:CreateTexture(nil, "OVERLAY")
    tile.selected:SetAllPoints()
    pcall(tile.selected.SetTexture, tile.selected, "Interface\\Buttons\\UI-Listbox-Highlight")
    pcall(tile.selected.SetBlendMode, tile.selected, "ADD")
    pcall(tile.selected.SetVertexColor, tile.selected, 1, 0.82, 0, 0.6)
    tile.selected:Hide()
    local model = TryCreate("DressUpModel", nil, tile)
    if model then
      model:SetPoint("TOPLEFT", 3, -3)
      model:SetPoint("BOTTOMRIGHT", -3, 34)
      pcall(model.EnableMouse, model, false) -- clicks and drags go to the tile
      tile.model = model
      -- A hidden model forgets what it wore. Dress it again each time it
      -- shows: back on the Review tab, the window opened again, or a tile
      -- that was empty on the last page filled again.
      pcall(model.SetScript, model, "OnShow", function()
        local p = tile.entry
        if p then
          tile.shownId, tile.shownFemale = p.id, state.female
          DressModel(tile, p.id)
        end
      end)
      -- The body loads after SetUnit returns, and a piece or framing set
      -- before that can be lost: put both on again once it has loaded.
      pcall(model.SetScript, model, "OnModelLoaded", function()
        local p = tile.entry
        if p and tile.wantId == p.id then
          pcall(model.Undress, model)
          pcall(model.TryOn, model, "item:" .. p.id)
          FrameModel(tile)
        end
      end)
    end
    tile.onList = tile:CreateTexture(nil, "OVERLAY")
    tile.onList:SetSize(14, 14)
    tile.onList:SetPoint("TOPLEFT", 4, -4)
    pcall(tile.onList.SetTexture, tile.onList, "Interface\\RaidFrame\\ReadyCheck-Ready")
    tile.rating = tile:CreateFontString(nil, "OVERLAY", _G.GameFontNormalLarge and "GameFontNormalLarge" or "GameFontNormal")
    tile.rating:SetPoint("TOPRIGHT", -5, -5)
    tile.name = tile:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tile.name:SetPoint("BOTTOMLEFT", 4, 16)
    tile.name:SetPoint("BOTTOMRIGHT", -4, 16)
    tile.name:SetHeight(20)
    tile.name:SetJustifyH("CENTER")
    tile.name:SetJustifyV("BOTTOM")
    tile.name:SetWordWrap(true)
    tile.info = tile:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tile.info:SetPoint("BOTTOMLEFT", 4, 4)
    tile.info:SetPoint("BOTTOMRIGHT", -4, 4)
    tile.info:SetJustifyH("CENTER")
    tile.info:SetWordWrap(false)
    -- as in the dressing room: drag to turn the model, right-drag to move
    -- the view up and down (every tile of that piece type follows)
    tile:SetScript("OnMouseDown", function(self, mouse)
      local x, y = GetCursorPosition()
      if mouse == "RightButton" then
        self.panY = y
      else
        self.dragX = x
      end
    end)
    tile:SetScript("OnMouseUp", function(self)
      self.dragX, self.panY = nil, nil
    end)
    tile:SetScript("OnUpdate", function(self)
      if self.dragX and self.model then
        local x = GetCursorPosition()
        local ok, facing = pcall(self.model.GetFacing, self.model)
        if ok and type(facing) == "number" then
          pcall(self.model.SetFacing, self.model, facing + (x - self.dragX) * 0.02)
        end
        self.dragX = x
      end
      if self.panY and self.entry then
        local _, y = GetCursorPosition()
        if y ~= self.panY then
          ReviewMoveView(self.entry, 0, (y - self.panY) / math.max(1, self:GetHeight() * self:GetEffectiveScale()))
          self.panY = y
        end
      end
    end)
    tile:SetScript("OnClick", function(self, mouse)
      local p = self.entry
      if not p then
        return
      end
      if IsModifiedClick("CHATLINK") then
        local _, link = C_Item.GetItemInfo(p.id)
        if link then
          ChatEdit_InsertLink(link)
        end
        return
      end
      state.reviewSel, state.reviewIndex = p.id, (state.reviewPage - 1) * REVIEW_PER_PAGE + i
      Refresh()
    end)
    tile:SetScript("OnEnter", function(self)
      if self.entry then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetItemByID, GameTooltip, self.entry.id)
        GameTooltip:Show()
      end
    end)
    tile:SetScript("OnLeave", GameTooltip_Hide)
    tile:Hide()
    view.tiles[i] = tile
  end
  -- the wheel zooms the piece type under the pointer; Shift-wheel pages, as
  -- the wheel does in the Appearances window
  pcall(grid.EnableMouseWheel, grid, true)
  grid:SetScript("OnMouseWheel", function(_, delta)
    if IsShiftKeyDown and IsShiftKeyDown() then
      ReviewPage(delta > 0 and -1 or 1)
      return
    end
    local over
    for _, tile in ipairs(view.tiles) do
      if tile:IsShown() and MouseIsOver and MouseIsOver(tile) then
        over = tile.entry
      end
    end
    ReviewMoveView(over or ReviewSelected(), delta * 0.25, 0)
  end)

  -- the bar: the selected piece on the left, the rating on the right
  local bar = CreateFrame("Frame", nil, view)
  bar:SetPoint("BOTTOMLEFT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", 0, 0)
  bar:SetHeight(REVIEW_BAR_H - 4)
  view.bar = bar
  local function Tip(button, title, text)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(title)
      GameTooltip:AddLine(text, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
  end
  bar.clear = MakeButton(bar, "Undo", 56, function()
    ReviewFlagSelected(nil)
  end)
  bar.clear:SetPoint("TOPRIGHT", 0, -2)
  Tip(bar.clear, "Undo", "Forgets your rating: the piece is judged by its measure again.")
  bar.rates = {}
  for n = 10, 1, -1 do
    local b = MakeButton(bar, tostring(n), 26, function()
      ReviewFlagSelected(n)
    end)
    if n == 10 then
      b:SetPoint("RIGHT", bar.clear, "LEFT", -6, 0)
    else
      b:SetPoint("RIGHT", bar.rates[n + 1], "LEFT", -2, 0)
    end
    Tip(b, ("Rate it %d/10"):format(n), n >= ns.RATING_KEEP
      and "Keeps the piece on the list (or puts it on); the higher the rating, the higher its buy score. Then the next piece shows."
      or "Takes the piece off the list. Then the next piece shows.")
    bar.rates[n] = b
  end
  local rateText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  rateText:SetPoint("RIGHT", bar.rates[1], "LEFT", -6, 0)
  rateText:SetText("Rating")
  bar.name = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  bar.name:SetPoint("TOPLEFT", 4, -4)
  bar.name:SetPoint("RIGHT", rateText, "LEFT", -12, 0)
  bar.name:SetJustifyH("LEFT")
  bar.name:SetWordWrap(false)
  bar.info = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bar.info:SetPoint("TOPLEFT", bar.name, "BOTTOMLEFT", 0, -3)
  bar.info:SetPoint("RIGHT", bar, "RIGHT", -345, 0)
  bar.info:SetJustifyH("LEFT")
  bar.info:SetJustifyV("TOP")
  bar.info:SetHeight(26)
  bar.info:SetWordWrap(true)
  -- second line, right: the female body box and the page arrows
  view.next = PageArrow(bar, "Next", function()
    ReviewPage(1)
  end)
  view.next:SetPoint("BOTTOMRIGHT", 0, -2)
  view.pageText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  view.pageText:SetPoint("RIGHT", view.next, "LEFT", -4, 0)
  view.prev = PageArrow(bar, "Prev", function()
    ReviewPage(-1)
  end)
  view.prev:SetPoint("RIGHT", view.pageText, "LEFT", -4, 0)
  bar.female = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
  bar.female:SetSize(24, 24)
  bar.female:SetPoint("RIGHT", view.prev, "LEFT", -96, 0)
  bar.female:SetHitRectInsets(0, -80, 0, 0)
  local femaleText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  femaleText:SetPoint("LEFT", bar.female, "RIGHT", 2, 0)
  femaleText:SetText("Female body")
  bar.female:SetScript("OnClick", function(self)
    state.female = self:GetChecked() and true or false
    Refresh()
  end)
  Tip(bar.female, "Female body", "Shows the pieces on a female body of your race when your character is male. The list measures the female textures.")
  local probe = view.tiles[1].model
  local canFemale = probe and type(probe.SetCustomRace) == "function"
  bar.female:SetShown(canFemale and true or false)
  femaleText:SetShown(canFemale and true or false)

  -- keys while the pointer is over the grid: 1-9 and 0 (10) rate the selected
  -- piece, the arrows move the selection. Other keys go on to the game, and
  -- in combat the grid takes no keys at all.
  local function Propagate(on)
    if not (InCombatLockdown and InCombatLockdown()) then
      pcall(view.SetPropagateKeyboardInput, view, on)
    end
  end
  local tick = 0
  view:SetScript("OnUpdate", function(self, elapsed)
    tick = tick + (elapsed or 0)
    if tick < 0.1 then
      return
    end
    tick = 0
    local want = (MouseIsOver and MouseIsOver(grid) or false) and not (InCombatLockdown and InCombatLockdown())
      and not (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus())
    want = want and true or false
    if want ~= self.keys then
      self.keys = want
      if want then
        Propagate(true)
      end
      pcall(self.EnableKeyboard, self, want)
    end
  end)
  view:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown and InCombatLockdown() then
      return
    end
    local n = REVIEW_KEYS[key]
    local step = key == "LEFT" and -1 or key == "RIGHT" and 1 or key == "UP" and -REVIEW_COLS or key == "DOWN" and REVIEW_COLS or nil
    local page = REVIEW_PAGE_KEYS[key]
    if (n or step or page) and not (IsModifierKeyDown and IsModifierKeyDown()) then
      Propagate(false)
      if n then
        ReviewFlagSelected(n)
      elseif page then
        ReviewPage(page)
      else
        ReviewStep(step)
      end
    else
      Propagate(true)
    end
  end)
  view:SetScript("OnKeyUp", function()
    Propagate(true)
  end)
  view:SetScript("OnHide", function(self)
    self.keys = nil
    pcall(self.EnableKeyboard, self, false)
  end)
end

-- The Sell tab's row: the auction house's list line, with a Post or Cancel
-- button in its last cell.
local function BuildSellRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row.smogRow = true
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  AddStripe(row)
  local sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  sel:SetAllPoints()
  if SetArt(sel, "auctionhouse-ui-row-select", "Interface\\QuestFrame\\UI-QuestTitleHighlight") then
    sel:SetBlendMode("ADD")
  end
  sel:Hide()
  row.selected = sel
  local font = CellFont()
  row.cells = {}
  for _, col in ipairs(SELL_COLS) do
    local padL, padR = col.padL or 0, col.padR or 0
    local fs = row:CreateFontString(nil, "OVERLAY", font)
    fs:SetJustifyH(col.align)
    fs:SetWordWrap(false)
    if col.key == "name" then
      row.icon = row:CreateTexture(nil, "BACKGROUND", nil, 2)
      row.icon:SetSize(14, 14)
      row.icon:SetPoint("LEFT", col.x + padL, 0)
      local border = row:CreateTexture(nil, "BACKGROUND", nil, 3)
      border:SetSize(16, 16)
      border:SetPoint("CENTER", row.icon, "CENTER")
      if HasAtlas("auctionhouse-itemicon-small-border") then
        border:SetAtlas("auctionhouse-itemicon-small-border")
        border.smogArt = true
      end
      row.iconBorder = border
      fs:SetPoint("LEFT", row.icon, "RIGHT", 4, -1)
      fs:SetWidth(col.width - padL - 14 - 4 - padR)
    else
      fs:SetPoint("LEFT", col.x + padL, 0)
      fs:SetWidth(col.width - padL - padR)
    end
    row.cells[col.key] = fs
    if col.key == "act" then
      local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      b:SetSize(col.width - padL - padR, 18)
      b:SetPoint("LEFT", col.x + padL, 0)
      b:SetScript("OnClick", function(self)
        local d = self:GetParent().data
        if not d then
          return
        end
        if d.kind == "bag" then
          SellPostRow(d)
        else
          ns.SellCancel(d.auction)
        end
      end)
      b:SetScript("OnEnter", function(self)
        local d = self:GetParent().data
        if d and d.kind == "auction" then
          GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
          GameTooltip:SetText("Cancel")
          GameTooltip:AddLine("It goes to your mailbox.", 1, 1, 1, true)
          local cost = ns.CancelCost(d.auction)
          if cost and cost > 0 then
            GameTooltip:AddLine("Costs " .. ns.Money(cost), 1, 1, 1, true)
          end
          GameTooltip:Show()
        end
      end)
      b:SetScript("OnLeave", GameTooltip_Hide)
      b:Hide()
      row.act = b
    end
  end
  -- a section line ("In your bags"): gold text across the row
  local st = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  st:SetPoint("LEFT", 8, 0)
  st:SetJustifyH("LEFT")
  st:Hide()
  row.sectionText = st
  row:SetScript("OnEnter", function(self)
    local d = self.data
    if not d then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    ns.tipFilled = false
    if d.link and GameTooltip.SetHyperlink then
      GameTooltip:SetHyperlink(d.link)
    else
      GameTooltip:SetItemByID(d.id)
    end
    if not ns.tipFilled then
      ns.FillItemTooltip(GameTooltip, d.id)
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnClick", function(self)
    local d = self.data
    if not d then
      return
    end
    if IsModifiedClick("CHATLINK") and d.link then
      ChatEdit_InsertLink(d.link)
    elseif IsModifiedClick("DRESSUP") then
      DressUpItemLink(d.link or ("item:" .. d.id))
    elseif d.kind == "bag" and not d.listed then
      state.sellSel = d.id
      Refresh()
    end
  end)
  return row
end

local function PostFromBox()
  SellPostRow(SellSelectedNow())
end

local function CreateSellView()
  sellView = MakeView()
  -- the sell box: item, price box and Post, as in the auction house's Sell tab
  local box = CreateFrame("Frame", nil, sellView)
  box:SetPoint("TOPLEFT", 0, 0)
  box:SetPoint("TOPRIGHT", 0, 0)
  box:SetHeight(46)
  sellView.box = box
  local icon = box:CreateTexture(nil, "ARTWORK")
  icon:SetSize(36, 36)
  icon:SetPoint("LEFT", 8, 0)
  box.icon = icon
  local frame = box:CreateTexture(nil, "OVERLAY")
  frame:SetSize(38, 38)
  frame:SetPoint("CENTER", icon, "CENTER")
  if not SetArt(frame, "auctionhouse-itemicon-border-white", nil) then
    frame:Hide()
  end
  local name = box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
  name:SetPoint("RIGHT", box, "RIGHT", -400, 0)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  box.name = name
  local info = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 2)
  info:SetPoint("RIGHT", box, "RIGHT", -400, 0)
  info:SetJustifyH("LEFT")
  info:SetWordWrap(false)
  box.info = info
  local post = MakeButton(box, "Post", 100, PostFromBox)
  post:SetPoint("RIGHT", box, "RIGHT", -8, 0)
  box.post = post
  sellMoney = TryCreate("Frame", "SlutmogScoutSellPrice", box, "MoneyInputFrameTemplate")
  if sellMoney then
    sellMoney:SetPoint("RIGHT", post, "LEFT", -12, 0)
    -- Enter in the price box posts
    for _, k in ipairs({ "gold", "silver", "copper" }) do
      local eb = sellMoney[k]
      if type(eb) == "table" and eb.SetScript then
        eb:SetScript("OnEnterPressed", function(self)
          pcall(self.ClearFocus, self)
          PostFromBox()
        end)
      end
    end
  end
  local note = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  note:SetPoint("BOTTOMRIGHT", post, "TOPRIGHT", 0, 3)
  note:SetJustifyH("RIGHT")
  box.note = note

  local headers = CreateFrame("Frame", nil, sellView)
  headers:SetPoint("TOPLEFT", 4, -48)
  headers:SetPoint("TOPRIGHT", -26, -48)
  headers:SetHeight(19)
  for ci, col in ipairs(SELL_COLS) do
    local h = TryCreate("Button", nil, headers, "ColumnDisplayButtonShortTemplate") or CreateFrame("Button", nil, headers)
    h:SetSize(col.width + (ci < #SELL_COLS and HEADER_OVERLAP or 0), 19)
    h:SetPoint("TOPLEFT", col.x, 0)
    pcall(h.EnableMouse, h, false)
    local fs = h:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", 8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(col.label)
  end
  sellView.inset = MakeInset(sellView)
  sellView.inset:SetPoint("TOPLEFT", 0, -67)
  sellView.inset:SetPoint("BOTTOMRIGHT", 0, 0)
  sellView.list = CreateList(sellView, ROW_H, BuildSellRow)
  sellView.list.scroll:SetPoint("TOPLEFT", headers, "BOTTOMLEFT", 0, -6)
  sellView.list.scroll:SetPoint("RIGHT", headers, "RIGHT", 0, 0)
  sellView.list.scroll:SetPoint("BOTTOM", sellView, "BOTTOM", 0, 3)
  sellView.empty = MakeEmptyText(sellView, sellView.list.scroll)
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
  pcall(win.SetScale, win, ns.WindowScale())
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

  -- the chat window's size grabber in the bottom-right corner: dragging it
  -- scales the whole window, the top-left corner stays put
  local grip = CreateFrame("Button", nil, win)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -4, 4)
  grip:SetFrameLevel((tonumber(win:GetFrameLevel()) or 1) + 10)
  pcall(grip.SetNormalTexture, grip, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  pcall(grip.SetPushedTexture, grip, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  pcall(grip.SetHighlightTexture, grip, "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight", "ADD")
  grip:SetScript("OnMouseDown", function(self)
    local x = GetCursorPosition()
    local ok, w = pcall(function() return win:GetWidth() * win:GetEffectiveScale() end)
    self.sizing = ok and w and w > 0 and { x = x, w = w, scale = win:GetScale() } or nil
  end)
  grip:SetScript("OnMouseUp", function(self)
    if self.sizing then
      self.sizing = nil
      ns.SetWindowScale(win:GetScale())
    end
  end)
  grip:SetScript("OnUpdate", function(self)
    local s = self.sizing
    if s then
      local x = GetCursorPosition()
      ns.SetWindowScale(s.scale * (s.w + (x - s.x)) / s.w, true)
    end
  end)
  grip:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Window size")
    GameTooltip:AddLine(("Drag to resize (now %d%%)."):format(math.floor(ns.WindowScale() * 100 + 0.5)), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  grip:SetScript("OnLeave", GameTooltip_Hide)
  win.grip = grip

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
    if state.tab == "sell" then
      ns.SellRefresh(true)
    else
      ns.StartScan()
    end
  end)
  scanButton:SetPoint("RIGHT", win, "TOPRIGHT", -12, -49)
  pcall(scanButton.SetMotionScriptsWhileDisabled, scanButton, true) -- the tooltip shows while the auction house is closed
  scanButton:SetScript("OnEnter", function(self)
    if state.tab == "sell" then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine("Refresh")
      GameTooltip:AddLine("Reads your auctions and each piece's listings again.", 1, 1, 1, true)
      GameTooltip:Show()
    else
      ScanTooltip(self)
    end
  end)
  scanButton:SetScript("OnLeave", GameTooltip_Hide)
  filterButton = CreateFilterDropdown()
  if not filterButton then
    CreateFilterButtons(tabsX)
  end
  levelBox = CreateLevelRange(filterButton or scanButton)

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

  CreateReviewView()
  CreateSellView()

  win:SetScript("OnShow", Refresh)
end

-- The window's size as a scale of its normal size, 0.6 to 2.
local SCALE_MIN, SCALE_MAX = 0.6, 2
ns.SCALE_MIN, ns.SCALE_MAX = SCALE_MIN, SCALE_MAX
function ns.WindowScale()
  local s = ns.db and ns.db.opts and tonumber(ns.db.opts.scale)
  return s and math.max(SCALE_MIN, math.min(SCALE_MAX, s)) or 1
end

-- Sets the window's scale; its top-left corner stays where it is on screen.
-- live: while dragging, the position is saved when the drag ends.
function ns.SetWindowScale(s, live)
  s = tonumber(s)
  if not (s and ns.db) then
    return nil
  end
  s = math.floor(math.max(SCALE_MIN, math.min(SCALE_MAX, s)) * 100 + 0.5) / 100
  ns.db.opts.scale = s ~= 1 and s or nil
  if win then
    local ok, left, top = pcall(function()
      local eff = win:GetEffectiveScale()
      return win:GetLeft() * eff, win:GetTop() * eff
    end)
    pcall(win.SetScale, win, s)
    if ok and left and top then
      local eff = win:GetEffectiveScale()
      win:ClearAllPoints()
      win:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / eff, top / eff)
      if not live then
        ns.db.winPos = { p = "TOPLEFT", rp = "BOTTOMLEFT", x = left / eff, y = top / eff }
      end
    end
  end
  return s
end

function ns.ScaleCommand(rest)
  rest = (rest or ""):lower():gsub("%%", ""):match("^%s*(.-)%s*$")
  local n = tonumber(rest)
  if rest == "reset" or rest == "off" then
    n = 100
  end
  if not n then
    ns.Print(("Window size: %d%%. Usage: |cffffff00/smog scale|r 60-200 (percent), or reset."):format(math.floor(ns.WindowScale() * 100 + 0.5)))
    return
  end
  if n <= SCALE_MAX then
    n = n * 100 -- 1.2 means 120%
  end
  local s = ns.SetWindowScale(n / 100)
  ns.Print(("Window size: %d%%."):format(math.floor(s * 100 + 0.5)))
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
  ahButton:SetScript("OnEnter", ScanTooltip)
  ahButton:SetScript("OnLeave", GameTooltip_Hide)
  -- the Sell tab (SuccuDev, 2026-11-15: "proper auctioning addon")
  local sellButton = CreateFrame("Button", "SlutmogScoutSellButton", AuctionHouseFrame, "UIPanelButtonTemplate")
  sellButton:SetSize(120, 22)
  sellButton:SetPoint("RIGHT", ahButton, "LEFT", -4, 0)
  sellButton:SetText("Slutmog sell")
  sellButton:SetScript("OnClick", function()
    ns.Toggle("sell", true)
    ns.SellRefresh()
  end)
  sellButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Slutmog sell")
    GameTooltip:AddLine(("Post your list pieces for %s and watch your auctions."):format(ns.PostDurationText()), 1, 1, 1, true)
    GameTooltip:Show()
  end)
  sellButton:SetScript("OnLeave", GameTooltip_Hide)
end

ns.On(function(what)
  if what == "AH_SHOW" then
    EnsureAuctionHouseButton()
    UpdateStatus()
    Refresh() -- the Buy buttons show while the auction house is open
    if win and win:IsShown() and state.tab == "sell" then
      ns.SellRefresh()
    end
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
  elseif what == "SELL" then
    if win and win:IsShown() and state.tab == "sell" then
      Refresh()
    end
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
    { label = "window: Review", frame = WindowOn("review") },
    { label = "window: Sell", frame = WindowOn("sell") },
    { label = "auction house button", frame = function() return ahButton end, pad = 60 },
  },
}
