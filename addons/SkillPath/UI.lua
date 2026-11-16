-- SkillPath has no window of its own. It adds a page to two of the game's windows:
--   Professions: a side tab under the profession tabs (ForeverCore's shared column when that addon
--   is installed). Left: the path as numbered steps. Right: the step you picked.
--   Auction house: a bottom tab after Buy / Sell / Auctions (through LibAHTab when another addon
--   brought it, so every addon's tabs line up). What to buy, the price scan, what to sell later.
local _, ns = ...
local UI = {}
ns.UI = UI

local Num = ns.Num

-- A card is the crafting output log's 46-pixel item element (item card art, item button, two
-- lines of text). Lines, headers and notes are the other rows.
local CARD, LINE, HEAD, GAP, PAD = 46, 20, 26, 2, 4
local TRADE_KEY, AH_TAB = "skillpath", "SkillPathAuctionTab"

local ICON_BUY = "Interface\\Icons\\INV_Misc_Bag_08"
local ICON_SELL = "Interface\\Icons\\INV_Misc_Coin_02"
local ICON_TRAIN = "Interface\\Icons\\INV_Misc_Book_11"
local ICON_GAP = "Interface\\Icons\\INV_Misc_QuestionMark"

local function HasAtlas(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil
    end
    return true
end

local function Art(texture, atlas, file)
    if texture.SetAtlas and HasAtlas(atlas) and pcall(texture.SetAtlas, texture, atlas) then return true end
    if file then texture:SetTexture(file) end
    return false
end

local function Color(name, r, g, b) return ns.GameColor(name, r, g, b) end
local function White() return Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1) end
local function Gold() return Color("NORMAL_FONT_COLOR", 1, 0.82, 0) end
local function Grey() return Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5) end
local function Red() return Color("RED_FONT_COLOR", 1, 0.1, 0.1) end
local function Green() return Color("GREEN_FONT_COLOR", 0.1, 1, 0.1) end

-- The professions window's own recipe colours.
local DIFF = {
    [0] = { "DIFFICULT_DIFFICULTY_COLOR", 1, 0.5, 0.25 },
    [1] = { "FAIR_DIFFICULTY_COLOR", 1, 1, 0 },
    [2] = { "EASY_DIFFICULTY_COLOR", 0.25, 0.75, 0.25 },
    [3] = { "TRIVIAL_DIFFICULTY_COLOR", 0.5, 0.5, 0.5 },
}
function UI.DifficultyColor(r, s, offset)
    local key
    if r.y then
        local eff = s + (offset or 0)
        if eff >= r.g then
            key = 3
        elseif eff < r.y then
            key = 0
        else
            key = eff < math.floor((r.y + r.g) / 2) and 1 or 2
        end
    else
        key = r.colour or 0
    end
    local d = DIFF[key] or DIFF[0]
    return Color(d[1], d[2], d[3], d[4])
end

----------------------------------------------------------------------
-- Words
----------------------------------------------------------------------
local function Plural(n, one, many) return n == 1 and one or many end
local function Items(n) return ("%d %s"):format(n, Plural(n, "item", "items")) end

local function CostText(cost, priced)
    if not priced then return "no price" end
    if cost < 0.5 then return "free" end
    return ns.Money(cost)
end

-- Crafts to plan for: an expected 34.9 is 35.
function UI.CraftCount(step)
    return math.max(1, math.ceil(step.crafts - 0.05))
end

-- Every point of the step comes from an orange craft, so the count is exact.
local function Exact(step)
    for _, p in ipairs(step.points) do
        if not p.orange then return false end
    end
    return true
end

-- Where one reagent comes from, in a line.
function UI.SourceText(item)
    local sup = ns.Prices.Supply(item)
    local parts = {}
    if sup.have > 0 then parts[#parts + 1] = ("you have %d"):format(sup.have) end
    if sup.listed > 0 then
        local cheapest
        for _, u in ipairs(sup.units) do cheapest = cheapest and math.min(cheapest, u.u) or u.u end
        for _, l in ipairs(sup.lots) do cheapest = cheapest and math.min(cheapest, l.u) or l.u end
        parts[#parts + 1] = ("auction from %s each (%d listed, %s)"):format(ns.Money(cheapest), sup.listed,
            ns.Age(sup.age))
    end
    if sup.vendor then
        parts[#parts + 1] = ("vendor %s each%s"):format(ns.Money(sup.vendor),
            sup.vendorFrom == "vendor" and "" or " (item data)")
    end
    if not sup.priced then parts[#parts + 1] = ns.Prices.Missing(sup) end
    return table.concat(parts, "; ")
end

-- The profession and where the path goes; what it costs.
function UI.Summary(plan)
    if not plan.ok then return plan.name or ns.NAME, plan.why or "" end
    local title = ("%s %d to %d"):format(plan.name, plan.from, plan.to)
    local unpriced = false
    for _, s in ipairs(plan.steps) do
        if s.kind == "craft" and not s.priced then unpriced = true end
    end
    local line
    if unpriced and plan.total < 0.5 then
        line = "No prices yet"
    else
        line = "Cost " .. CostText(plan.total, true)
        if plan.gapAt then line = line .. (" to reach %d"):format(plan.gapAt) end
        if unpriced then line = line .. ", plus what has no price" end
    end
    if (plan.back or 0) >= 0.5 then
        line = line .. (". Leftovers sell for %s. Net %s"):format(ns.Money(plan.back),
            plan.net >= 0 and ns.Money(plan.net) or (ns.Money(-plan.net) .. " profit"))
    end
    return title, line .. "."
end

function UI.PriceStatus()
    local P = ns.Prices
    if P.IsScanning() then
        local done, total = P.Progress()
        return ("Reading prices: %d of %d"):format(done, total)
    end
    local n, age = P.Summary()
    if n == 0 then return "No auction prices yet" end
    return ("Auction prices: %s, newest %s"):format(Items(n), ns.Age(age))
end

----------------------------------------------------------------------
-- The path as numbered steps: buy, craft (and train), sell
----------------------------------------------------------------------
function UI.Steps(plan)
    plan = plan or ns.Plan()
    local steps = {}
    if not plan.ok then return steps end
    local buy, cost, unpriced = {}, 0, 0
    for _, e in ipairs(plan.shopping or {}) do
        if e.buy > 0 then
            buy[#buy + 1] = e
            if e.cost then cost = cost + e.cost else unpriced = unpriced + 1 end
        end
    end
    if #buy > 0 then steps[#steps + 1] = { kind = "buy", entries = buy, cost = cost, unpriced = unpriced } end
    for _, s in ipairs(plan.steps) do
        if s.kind == "craft" then
            steps[#steps + 1] = { kind = "craft", step = s }
        elseif s.kind == "train" then
            steps[#steps + 1] = { kind = "train", at = s.at }
        elseif s.kind == "gap" then
            steps[#steps + 1] = { kind = "gap", step = s }
        end
    end
    local left, back = {}, 0
    for _, e in ipairs(plan.leftovers or {}) do
        if e.left >= 0.5 and (e.value or 0) >= 0.5 then
            left[#left + 1] = e
            back = back + e.value
        end
    end
    if #left > 0 then steps[#steps + 1] = { kind = "sell", entries = left, back = back } end
    for i, s in ipairs(steps) do s.n = i end
    return steps
end

local function StepKey(s)
    if s.kind == "craft" then return ("craft:%s:%s"):format(tostring(s.step.r.id), tostring(s.step.from)) end
    if s.kind == "train" then return "train:" .. tostring(s.at) end
    return s.kind
end
UI.StepKey = StepKey

-- title, second line, icon, the title's colour, and whether the second line is a problem
function UI.StepText(s, plan)
    local r, g, b = Gold()
    if s.kind == "buy" then
        local n = #s.entries
        local sub
        if s.unpriced == 0 then
            sub = ("%s, %s"):format(Items(n), ns.Money(s.cost))
        elseif s.unpriced == n then
            sub = ("%s, no prices yet"):format(Items(n))
        else
            sub = ("%s, %s and %d with no price"):format(Items(n), ns.Money(s.cost), s.unpriced)
        end
        return "Buy reagents", sub, ICON_BUY, r, g, b, s.unpriced > 0
    elseif s.kind == "craft" then
        local step = s.step
        local title = ("%s%d x %s"):format(Exact(step) and "" or "About ", UI.CraftCount(step), step.name)
        local sub = ("Skill %d to %d, %s%s"):format(step.from, step.to, CostText(step.cost, step.priced),
            step.stale and ", old price" or "")
        r, g, b = UI.DifficultyColor(step.r, step.from, plan and plan.ctx and plan.ctx.offset or 0)
        return title, sub, step.r.icon, r, g, b, not step.priced
    elseif s.kind == "train" then
        return "Train the next rank", ("At skill %d, at your trainer"):format(s.at), ICON_TRAIN, r, g, b, false
    elseif s.kind == "gap" then
        return "Learn a new recipe", ("Nothing you know gives skill at %d"):format(s.step.from), ICON_GAP,
            r, g, b, true
    end
    return "Sell what's left", ("%s, about %s"):format(Items(#s.entries), ns.Money(s.back)), ICON_SELL, r, g, b, false
end

----------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------
local function OwnsTooltip(row)
    return GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row)
end

local function ItemTip(tip, item)
    if not pcall(tip.SetItemByID, tip, item) then tip:SetText(ns.Prices.ItemName(item)) end
    tip:AddLine(" ")
end

local function ShopTip(tip, e)
    ItemTip(tip, e.item)
    local wr, wg, wb = White()
    local gr, gg, gb = Grey()
    tip:AddLine(("The path uses %s. You have %d%s."):format(ns.Crafts(e.need), e.have,
        e.made > 0.05 and (", earlier steps make " .. ns.Crafts(e.made)) or ""), wr, wg, wb, true)
    tip:AddLine(UI.SourceText(e.item), gr, gg, gb, true)
end

-- What one leftover is worth, and what that rests on.
function UI.SellLines(e)
    local res = ns.Prices.Resale(e.item)
    local lines = {}
    if res.ah then
        local atAH = math.min(e.left, res.cap)
        lines[#lines + 1] = ("Auction house: %s at %s each after the 5%% cut (cheapest listing %s, %s)."):format(
            ns.Crafts(atAH), ns.Money(res.ah), ns.Money(res.lowest), ns.Age(res.age))
        lines[#lines + 1] = ("%.1f a day left the auction house over %.0f h of scans. %d %s of that counts."):format(
            res.perDay, res.hours, ns.db.sellDays or 3, (ns.db.sellDays or 3) == 1 and "day" or "days")
        lines[#lines + 1] = "Cancelled and expired auctions leave too, so that is the most that sold."
        if res.stale then lines[#lines + 1] = "Old price: scan again." end
    end
    if res.vendor and res.vendor > 0 then
        local rest = res.ah and math.max(0, e.left - res.cap) or e.left
        if rest > 0.05 then
            lines[#lines + 1] = ("Vendor: %s at %s each."):format(ns.Crafts(rest), ns.Money(res.vendor))
        end
    elseif not ns.db.sellVendor then
        lines[#lines + 1] = "Vendor sales are off in the options."
    elseif res.sell == nil then
        lines[#lines + 1] = "Vendor price not loaded yet."
    else
        lines[#lines + 1] = "Vendors don't buy it."
    end
    if not res.ah and res.why then lines[#lines + 1] = "Not counted at the auction house: " .. res.why .. "." end
    return lines
end

local function SellTip(tip, e)
    ItemTip(tip, e.item)
    local wr, wg, wb = White()
    local gr, gg, gb = Grey()
    tip:AddLine(("The path makes %s more than it uses: about %s."):format(ns.Crafts(e.left), ns.Money(e.value)),
        wr, wg, wb, true)
    for _, line in ipairs(UI.SellLines(e)) do tip:AddLine(line, gr, gg, gb, true) end
end

local function OptionTip(tip, o)
    local r = o.r
    tip:SetText(r.name, Gold())
    local wr, wg, wb = White()
    local gr, gg, gb = Grey()
    if o.covers > 0 then
        tip:AddLine(("Gives skill on %d %s past where your recipes stop."):format(o.covers,
            Plural(o.covers, "point", "points")), wr, wg, wb, true)
    end
    if o.saving >= 1 then
        tip:AddLine(("Saves about %s between %d and %d, before what the recipe costs."):format(
            ns.Money(o.saving), o.from, o.to), wr, wg, wb, true)
    end
    tip:AddLine(("Orange below %d, grey from %d."):format(r.y, r.g), gr, gg, gb)
    if o.learnAt then tip:AddLine(("Needs skill %d to learn."):format(o.learnAt), gr, gg, gb) end
    if o.source then tip:AddLine(o.source, gr, gg, gb, true) end
    tip:AddLine(" ")
    for _, slot in ipairs(r.slots or {}) do
        for i, item in ipairs(slot.items) do
            tip:AddLine(("%s%d x %s"):format(i > 1 and "or " or "", slot.qty, ns.Prices.ItemName(item)), wr, wg, wb)
        end
    end
end

local function ReagentTip(tip, item)
    ItemTip(tip, item)
    local gr, gg, gb = Grey()
    tip:AddLine(UI.SourceText(item), gr, gg, gb, true)
end

function UI.ShowTooltip(row)
    local e = row.element
    if not (e and e.tip and GameTooltip) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    e.tip(GameTooltip)
    if e.hint then GameTooltip:AddLine(e.hint, Green()) end
    GameTooltip:Show()
    UI.tooltipRow = row
end

----------------------------------------------------------------------
-- Cards for items and recipes
----------------------------------------------------------------------
local function ItemLink(item)
    return function() return (select(2, ns.Call(C_Item and C_Item.GetItemInfo, item))) end
end

local function RecipeLink(id)
    return function()
        local T = C_TradeSkillUI
        return T and ns.Str(ns.Call(T.GetRecipeLink, id))
    end
end

-- click: what a click on the card does (nil: nothing); hint: the tooltip's last line saying so.
function UI.ShopCard(e, click, hint)
    local sub, bad
    if e.cost then
        sub = ("%s, %s%s"):format(ns.Money(e.cost), e.from or "", e.stale and ", old price" or "")
    else
        sub, bad = "No price: " .. (e.missing or "not scanned yet"), true
    end
    return { kind = "card", icon = ns.Prices.ItemIcon(e.item), count = e.buy, title = ns.Prices.ItemName(e.item),
        sub = sub, bad = bad, link = ItemLink(e.item), tip = function(tip) ShopTip(tip, e) end, click = click,
        hint = hint, entry = e, what = "shop" }
end

function UI.SellCard(e, click, hint)
    local res = ns.Prices.Resale(e.item)
    local where
    if res.ah and e.left > res.cap + 0.05 then
        where = ("%d at auction, the rest to a vendor"):format(res.cap)
    elseif res.ah then
        where = "auction house"
    elseif e.value >= 0.5 then
        where = "vendor"
    end
    return { kind = "card", icon = ns.Prices.ItemIcon(e.item), count = math.floor(e.left + 0.5),
        title = ns.Prices.ItemName(e.item),
        sub = where and ("%s, %s"):format(ns.Money(e.value), where) or "Sells for nothing",
        link = ItemLink(e.item), tip = function(tip) SellTip(tip, e) end, click = click, hint = hint,
        entry = e, what = "sell" }
end

function UI.OptionCard(o)
    local sub
    if o.covers > 0 then
        sub = ("Not known. Takes you to %d"):format(o.to)
    else
        sub = ("Not known. Saves about %s"):format(ns.Money(o.saving))
    end
    if o.learnAt then sub = sub .. (", needs skill %d"):format(o.learnAt) end
    local r, g, b = Grey()
    return { kind = "card", icon = o.r.icon, desaturate = true, dim = true, title = o.r.name, color = { r, g, b },
        sub = sub, link = RecipeLink(o.r.id), tip = function(tip) OptionTip(tip, o) end, option = o, what = "option" }
end

-- One line per point; a run of orange points is one line.
function UI.PointLines(step)
    local out, pts, i = {}, step.points, 1
    while i <= #pts do
        local p = pts[i]
        if p.orange then
            local j, cost, priced = i, p.cost or 0, p.priced
            while pts[j + 1] and pts[j + 1].orange and pts[j + 1].gain == p.gain do
                j = j + 1
                cost, priced = cost + (pts[j].cost or 0), priced and pts[j].priced
            end
            out[#out + 1] = { kind = "line", left = ("%d to %d: orange, %s every craft"):format(p.s, pts[j].to,
                p.gain > 1 and (p.gain .. " points") or "a point"), right = CostText(cost, priced) }
            i = j + 1
        else
            out[#out + 1] = { kind = "line", left = ("%d: %d%% chance, about %s crafts"):format(p.s,
                math.floor(p.chance * 100 + 0.5), ns.Crafts(p.crafts)), right = CostText(p.cost or 0, p.priced) }
            i = i + 1
        end
    end
    return out
end

----------------------------------------------------------------------
-- A scrolling list of cards, lines, headers and notes
----------------------------------------------------------------------
local function NewItemButton(parent)
    local ok, item = pcall(CreateFrame, "ItemButton", nil, parent)
    if not ok or type(item) ~= "table" then item = CreateFrame("Button", nil, parent, "ItemButtonTemplate") end
    item:SetSize(37, 37)
    item:EnableMouse(false)
    return item
end

local function SetIcon(item, icon, count, desaturate)
    if SetItemButtonTexture then SetItemButtonTexture(item, icon) elseif item.icon then item.icon:SetTexture(icon) end
    count = count or 0
    if SetItemButtonCount then
        SetItemButtonCount(item, count)
    elseif item.Count then
        item.Count:SetText(count > 1 and tostring(count) or "")
    end
    if SetItemButtonDesaturated then pcall(SetItemButtonDesaturated, item, desaturate and true or false) end
end

local function BuildRow(row)
    row:EnableMouse(true)

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetAllPoints()
    Art(row.Background, "looting_itemcard_bg", "Interface\\QuestFrame\\UI-QuestItemNameFrame")
    row.Border = row:CreateTexture(nil, "BORDER")
    row.Border:SetAllPoints()
    row.hasBorder = Art(row.Border, "looting_itemcard_stroke_normal")
    row.Selected = row:CreateTexture(nil, "ARTWORK")
    row.Selected:SetAllPoints()
    Art(row.Selected, "looting_itemcard_stroke_clickstate", "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Selected:SetBlendMode("ADD")
    row.Highlight = row:CreateTexture(nil, "OVERLAY")
    row.Highlight:SetAllPoints()
    Art(row.Highlight, "looting_itemcard_stroke_clickstate", "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Highlight:SetBlendMode("ADD")
    row.Highlight:SetAlpha(0.5)
    row.Highlight:Hide()

    -- A card: step number (the step list only), icon, two lines.
    row.Num = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    row.Num:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.Num:SetWidth(24)
    row.Num:SetJustifyH("CENTER")
    row.Item = NewItemButton(row)
    row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Text:SetPoint("TOPLEFT", row.Item, "TOPRIGHT", 8, -3)
    row.Text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)
    row.Sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -3)
    row.Sub:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetWordWrap(false)

    -- A line: text on the left, a cost on the right.
    row.Line = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Line:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.Line:SetPoint("RIGHT", row, "RIGHT", -90, 0)
    row.Line:SetJustifyH("LEFT")
    row.Line:SetWordWrap(false)
    row.Right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Right:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Right:SetJustifyH("RIGHT")

    -- A header, and a note that wraps.
    row.Title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Title:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 5)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)
    row.Note = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Note:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.Note:SetJustifyH("LEFT")
    row.Note:SetJustifyV("TOP")
    row.Note:SetWordWrap(true)

    row:SetScript("OnEnter", function(self)
        local e = self.element
        if e and e.click then self.Highlight:Show() end
        UI.ShowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        if OwnsTooltip(self) then GameTooltip:Hide() end
        self.Highlight:Hide()
    end)
    row:SetScript("OnMouseUp", function(self, button)
        local e = self.element
        if not e then return end
        if IsModifiedClick and IsModifiedClick() then
            local link = e.link and e.link()
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
            return
        end
        if e.click then e.click(button) end
    end)
end

local function InitRow(row, e, width)
    row.element = e
    local card = e.kind == "card"
    row.Background:SetShown(card)
    row.Border:SetShown(card and row.hasBorder)
    row.Selected:SetShown(card and e.selected and true or false)
    row.Highlight:Hide()
    row.Num:SetShown(card and e.n ~= nil)
    row.Item:SetShown(card)
    row.Text:SetShown(card)
    row.Sub:SetShown(card)
    row.Line:SetShown(e.kind == "line")
    row.Right:SetShown(e.kind == "line")
    row.Title:SetShown(e.kind == "head")
    row.Note:SetShown(e.kind == "text")
    if card then
        row.Item:ClearAllPoints()
        row.Item:SetPoint("TOPLEFT", row, "TOPLEFT", e.n and 32 or 5, -4)
        row.Num:SetText(e.n and tostring(e.n) or "")
        SetIcon(row.Item, e.icon, e.count, e.desaturate)
        row.Text:SetText(e.title)
        if e.color then row.Text:SetTextColor(e.color[1], e.color[2], e.color[3]) else row.Text:SetTextColor(White()) end
        row.Sub:SetText(e.sub or "")
        if e.bad then row.Sub:SetTextColor(Red()) else row.Sub:SetTextColor(White()) end
        local shade = e.dim and 0.6 or 1
        row.Background:SetVertexColor(shade, shade, shade)
    elseif e.kind == "line" then
        row.Line:SetText(e.left)
        row.Right:SetText(e.right or "")
    elseif e.kind == "head" then
        row.Title:SetText(e.text)
    elseif e.kind == "text" then
        row.Note:SetWidth(math.max(40, width - 16))
        row.Note:SetText(e.text)
        if e.bad then row.Note:SetTextColor(Red()) else row.Note:SetTextColor(White()) end
    end
    if OwnsTooltip(row) then
        if e.tip then UI.ShowTooltip(row) else GameTooltip:Hide() end
    end
end

local function Extent(row, e)
    if e.kind == "card" then return CARD end
    if e.kind == "line" then return LINE end
    if e.kind == "head" then return HEAD end
    local h = Num(row.Note:GetStringHeight())
    if not h or h < 10 then h = 12 end
    return h + 8
end

-- parent: the frame the list fills. name: the scroll frame's name on a client without ScrollFrameTemplate.
function UI.NewList(parent, name)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, parent, "ScrollFrameTemplate")
    if not (ok and type(scroll) == "table") then
        scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    end
    -- The template hangs its scroll bar outside the scroll frame, on the right.
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, PAD)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(300, CARD)
    scroll:SetScrollChild(child)

    local list = { scroll = scroll, child = child, rows = {}, elements = {} }
    function list:Set(elements)
        self.elements = elements
        local width = Num(scroll:GetWidth())
        if not width or width < 60 then width = 300 end
        self.width = width
        child:SetWidth(width)
        local y = 0
        for i, e in ipairs(elements) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, child)
                BuildRow(row)
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
            InitRow(row, e, width)
            local h = Extent(row, e)
            row:SetHeight(h)
            row:Show()
            y = y + h + GAP
        end
        for i = #elements + 1, #self.rows do
            self.rows[i].element = nil
            self.rows[i]:Hide()
        end
        child:SetHeight(math.max(y, CARD))
    end
    -- The rows on screen.
    function list:Shown()
        local out = {}
        for _, row in ipairs(self.rows) do
            if row:IsShown() then out[#out + 1] = row end
        end
        return out
    end
    -- The professions window is wider with an addon page open than without.
    scroll:HookScript("OnSizeChanged", function(_, width)
        width = Num(width)
        if width and width >= 60 and math.abs(width - (list.width or 0)) > 1 then list:Set(list.elements) end
    end)
    return list
end

local function NewInset(parent)
    local ok, inset = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
    if ok and type(inset) == "table" then return inset end
    return CreateFrame("Frame", nil, parent)
end

local function AddNotes(elements, plan)
    for _, note in ipairs(plan.notes or {}) do elements[#elements + 1] = { kind = "text", text = note } end
end

----------------------------------------------------------------------
-- Professions window: the page
----------------------------------------------------------------------
local trade = { hidden = {} }
UI.trade = trade

local function TradeFrame()
    local book = _G.ProfessionsFrame
    return type(book) == "table" and book or nil
end

-- ForeverCore's shared side-tab column for addon pages in the professions window.
local function CoreTabs()
    local core = _G.ForeverCore
    local tabs = type(core) == "table" and core.ProfessionTabs
    if type(tabs) == "table" and type(tabs.Register) == "function" and type(tabs.Select) == "function"
        and type(tabs.ShowNative) == "function" then
        return tabs
    end
end

local function NativeTabs(book)
    local list = {}
    if type(book.ProfessionsOverviewTab) == "table" then list[1] = book.ProfessionsOverviewTab end
    for _, tab in ipairs(book.rightProfessionTabs or {}) do list[#list + 1] = tab end
    return list
end

-- The game checks its side tab when it shows a page. After our page it needs telling again.
local function CheckNativeTab(book)
    local line
    if type(Professions) == "table" and type(Professions.GetEffectiveSkillLineID) == "function" then
        line = Num(ns.Call(Professions.GetEffectiveSkillLineID))
    end
    local onBook = type(book.BookPage) == "table" and book.BookPage:IsShown() and true or false
    if type(book.ProfessionsOverviewTab) == "table" then book.ProfessionsOverviewTab:SetChecked(onBook) end
    for _, tab in ipairs(book.rightProfessionTabs or {}) do
        tab:SetChecked(not onBook and line ~= nil and line ~= 0 and tab.skillLine == line)
    end
end

-- Above the game's pages (level 100), below the window's portrait, title and border.
local function PageLevel(book)
    local portrait = book.PortraitContainer
    local top = type(portrait) == "table" and portrait.GetFrameLevel and Num(portrait:GetFrameLevel())
    if top and top > 110 then return top - 10 end
    return (Num(book:GetFrameLevel()) or 0) + 200
end

-- The crafting page's rank bar is in the HIGH strata: faded out with its page, it still takes the
-- mouse through ours. A frame over it takes the mouse instead.
local function CoverRankBar(book, page)
    local bar = type(book.CraftingPage) == "table" and book.CraftingPage.RankBar
    if type(bar) ~= "table" or trade.rankCover then return end
    local cover = CreateFrame("Frame", nil, page)
    local box = type(bar.Border) == "table" and bar.Border or bar
    cover:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2)
    cover:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -2)
    cover:SetFrameStrata("HIGH")
    cover:SetFrameLevel((Num(bar:GetFrameLevel()) or 0) + 10)
    cover:EnableMouse(true)
    trade.rankCover = cover
end

local function BuildTradePage(book)
    local page = CreateFrame("Frame", "SkillPathTradePage", book)
    -- The box the game's own pages fill: inside the window's border, under its title bar.
    page:SetPoint("TOPLEFT", book, "TOPLEFT", 3, -24)
    page:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -3, 3)
    page:SetFrameLevel(PageLevel(book))
    pcall(CoverRankBar, book, page)
    page:EnableMouse(true)
    if page.EnableMouseWheel then
        page:EnableMouseWheel(true)
        page:SetScript("OnMouseWheel", function() end)
    end
    page:Hide()

    local bg = page:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Art(bg, "Profession-Background-Overview", "Interface\\FrameGeneral\\UI-Background-Marble")

    -- To the right of the window's portrait.
    page.Title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    page.Title:SetPoint("TOPLEFT", page, "TOPLEFT", 66, -10)
    page.Cost = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.Cost:SetPoint("TOPLEFT", page.Title, "BOTTOMLEFT", 0, -5)
    page.Cost:SetPoint("RIGHT", page, "RIGHT", -12, 0)
    page.Cost:SetJustifyH("LEFT")
    page.Cost:SetWordWrap(false)
    page.Prices = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    page.Prices:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -13)

    local left = NewInset(page)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -54)
    left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 4, 4)
    left:SetWidth(330)
    local right = NewInset(page)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 4)

    -- The picked step: icon, two lines, and for a craft the button that opens its recipe.
    local d = {}
    d.Icon = NewItemButton(right)
    d.Icon:SetPoint("TOPLEFT", right, "TOPLEFT", 12, -12)
    d.Button = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    d.Button:SetSize(110, 22)
    d.Button:SetPoint("TOPRIGHT", right, "TOPRIGHT", -12, -12)
    d.Button:SetText("Show recipe")
    d.Button:SetScript("OnClick", function(self)
        if self.step then UI.ShowRecipe(self.step) end
    end)
    d.Title = right:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    d.Title:SetPoint("TOPLEFT", d.Icon, "TOPRIGHT", 10, -1)
    d.Title:SetPoint("RIGHT", d.Button, "LEFT", -8, 0)
    d.Title:SetJustifyH("LEFT")
    d.Title:SetWordWrap(false)
    d.Sub = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d.Sub:SetPoint("TOPLEFT", d.Title, "BOTTOMLEFT", 0, -4)
    d.Sub:SetPoint("RIGHT", right, "RIGHT", -12, 0)
    d.Sub:SetJustifyH("LEFT")
    d.Sub:SetWordWrap(false)
    local holder = CreateFrame("Frame", nil, right)
    holder:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -58)
    holder:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)

    trade.page, trade.detail = page, d
    trade.list = UI.NewList(left, "SkillPathStepScroll")
    trade.detailList = UI.NewList(holder, "SkillPathDetailScroll")
    page:SetScript("OnShow", function(self)
        self:SetFrameLevel(PageLevel(book))
        UI.Update()
    end)
    page:SetScript("OnHide", function()
        if UI.tooltipRow and OwnsTooltip(UI.tooltipRow) then GameTooltip:Hide() end
    end)
end

-- The rows under a craft step's header.
local function CraftDetail(step)
    local els = {}
    local count = UI.CraftCount(step)
    els[#els + 1] = { kind = "head", text = ("Reagents for %d %s"):format(count, Plural(count, "craft", "crafts")) }
    for _, slot in ipairs(step.r.slots or {}) do
        local names, have = {}, 0
        for _, item in ipairs(slot.items) do
            names[#names + 1] = ns.Prices.ItemName(item)
            have = have + ns.Prices.Supply(item).have
        end
        local first = slot.items[1]
        els[#els + 1] = { kind = "card", icon = ns.Prices.ItemIcon(first), count = slot.qty * count,
            title = table.concat(names, " or "), sub = ("You have %d"):format(have), link = ItemLink(first),
            tip = function(tip) ReagentTip(tip, first) end, what = "reagent" }
    end
    if step.r.currency then els[#els + 1] = { kind = "text", text = "Also costs a currency, which isn't counted." } end
    for _, p in ipairs(step.points) do
        if p.missing then
            for _, m in ipairs(p.missing) do
                local text = m.item and ("No price for %s: %s."):format(ns.Prices.ItemName(m.item), m.why)
                    or ("No price: %s."):format(m.why)
                els[#els + 1] = { kind = "text", text = text, bad = true }
            end
            break
        end
    end
    local alts = {}
    for _, c in pairs(step.alts or {}) do alts[#alts + 1] = c end
    table.sort(alts, function(x, y) return x.r.id < y.r.id end)
    for _, c in ipairs(alts) do
        local why = c.missing and c.missing[1]
        els[#els + 1] = { kind = "text", bad = true, text = ("%s might be cheaper, but %s has no price."):format(
            c.r.name, why and why.item and ns.Prices.ItemName(why.item) or "a reagent") }
    end
    if (step.credit or 0) >= 0.5 then
        els[#els + 1] = { kind = "text", text = ("What it makes sells for about %s."):format(ns.Money(step.credit)) }
    end
    if not step.r.trust then
        els[#els + 1] = { kind = "text",
            text = "Its levels don't match the colours the game shows, so it is used only while orange." }
    end
    if ns.db.showPoints then
        els[#els + 1] = { kind = "head", text = "Each point" }
        for _, line in ipairs(UI.PointLines(step)) do els[#els + 1] = line end
    end
    return els
end

local function Detail(s, plan)
    local d = trade.detail
    d.Button:Hide()
    d.Button.step = nil
    if not s then
        d.Icon:Hide()
        d.Title:SetText("")
        d.Sub:SetText("")
        trade.detailList:Set({})
        return
    end
    local title, sub, icon, r, g, b = UI.StepText(s, plan)
    d.Icon:Show()
    SetIcon(d.Icon, icon, 0, false)
    d.Title:SetText(title)
    d.Title:SetTextColor(r, g, b)
    d.Sub:SetText(sub)
    local els = {}
    if s.kind == "buy" then
        els[#els + 1] = { kind = "text", text = "At the auction house, the SkillPath tab searches for each." }
        for _, e in ipairs(s.entries) do els[#els + 1] = UI.ShopCard(e) end
    elseif s.kind == "craft" then
        d.Button.step = s.step
        d.Button:Show()
        els = CraftDetail(s.step)
    elseif s.kind == "gap" then
        for _, o in ipairs(plan.options or {}) do
            if o.covers > 0 then els[#els + 1] = UI.OptionCard(o) end
        end
    elseif s.kind == "sell" then
        for _, e in ipairs(s.entries) do els[#els + 1] = UI.SellCard(e) end
    end
    trade.detailList:Set(els)
end

local function UpdateTrade()
    local page = trade.page
    if not (page and page:IsVisible() and ns.db) then return end
    local plan = ns.Plan()
    local title, line = UI.Summary(plan)
    page.Title:SetText(title)
    page.Cost:SetText(line)
    page.Prices:SetText(UI.PriceStatus())

    local steps = UI.Steps(plan)
    local sel
    for _, s in ipairs(steps) do
        if StepKey(s) == trade.selected then
            sel = s
            break
        end
    end
    sel = sel or steps[1]
    trade.selected = sel and StepKey(sel) or nil

    local els = {}
    for _, s in ipairs(steps) do
        local t, sub, icon, r, g, b, bad = UI.StepText(s, plan)
        els[#els + 1] = { kind = "card", n = s.n, icon = icon, title = t, color = { r, g, b }, sub = sub, bad = bad,
            selected = s == sel, step = s, what = "step", click = function()
                trade.selected = StepKey(s)
                UI.Update()
            end }
    end
    if plan.ok and #(plan.options or {}) > 0 then
        els[#els + 1] = { kind = "head", text = "Recipes worth learning" }
        for _, o in ipairs(plan.options) do els[#els + 1] = UI.OptionCard(o) end
    end
    AddNotes(els, plan)
    trade.list:Set(els)
    Detail(sel, plan)
end

----------------------------------------------------------------------
-- Professions window: the side tab
----------------------------------------------------------------------
local function SetTabIcon(tab)
    local icon = type(tab) == "table" and tab.Icon
    if type(icon) ~= "table" or not icon.SetTexture then return end
    icon:SetTexture(ns.ICON)
    if type(tab.SetFillToInterior) == "function" then tab:SetFillToInterior(true) end
end

-- Without ForeverCore: our own tab under the game's, and the game's pages faded out under ours
-- (never hidden: hiding them from addon code would run the game's page scripts tainted).
local function OwnSelect(on)
    local book = TradeFrame()
    if not (book and trade.page and trade.tab) then return end
    on = on and true or false
    if on then
        for _, page in ipairs(book.Pages or {}) do
            if page:IsShown() and trade.hidden[page] == nil then
                trade.hidden[page] = Num(page:GetAlpha()) or 1
                page:SetAlpha(0)
            end
        end
        for _, tab in ipairs(NativeTabs(book)) do tab:SetChecked(false) end
    else
        for page, alpha in pairs(trade.hidden) do page:SetAlpha(alpha) end
        trade.hidden = {}
    end
    trade.tab:SetChecked(on)
    trade.page:SetShown(on)
end

local function OwnAnchor(book)
    local above = type(book.ProfessionsOverviewTab) == "table" and book.ProfessionsOverviewTab or nil
    for _, tab in ipairs(book.rightProfessionTabs or {}) do
        if tab:IsShown() then above = tab end
    end
    trade.tab:ClearAllPoints()
    if above then
        trade.tab:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
    else
        trade.tab:SetPoint("TOPLEFT", book, "TOPRIGHT", 0, -60)
    end
end

local function OwnTab(book)
    local tab = CreateFrame("Button", "SkillPathTradeTab", book, "LargeSideTabButtonTemplate")
    tab.tooltipText = ns.NAME
    tab:SetCustomOnMouseUpHandler(function(_, mouseButton, upInside)
        if mouseButton ~= "LeftButton" or not upInside then return end
        local on = not trade.page:IsShown()
        OwnSelect(on)
        if not on then CheckNativeTab(book) end
    end)
    tab:SetChecked(false)
    trade.tab = tab
    OwnAnchor(book)
    local function back() OwnSelect(false) end
    for _, native in ipairs(NativeTabs(book)) do native:HookScript("OnMouseUp", back) end
    for _, page in ipairs(book.Pages or {}) do page:HookScript("OnShow", back) end
    book:HookScript("OnShow", function() OwnAnchor(book) end)
    book:HookScript("OnHide", back)
end

local function AttachTrade()
    if trade.attached then return end
    local book = TradeFrame()
    if not book then return end
    trade.attached = true
    local ok, err = pcall(function()
        BuildTradePage(book)
        local core = CoreTabs()
        if core then
            trade.tab = core.Register(TRADE_KEY, { icon = ns.ICON, tooltip = ns.NAME, page = trade.page })
            trade.mode = "core"
        else
            OwnTab(book)
            trade.mode = "own"
        end
        SetTabIcon(trade.tab)
    end)
    if not ok then
        trade.error, trade.mode = tostring(err), nil
        if trade.page then trade.page:Hide() end
    end
end
UI.AttachTrade = AttachTrade

function UI.TradeShown()
    return trade.page ~= nil and trade.page:IsVisible() and true or false
end

function UI.SelectTrade()
    AttachTrade()
    if trade.mode == "core" then
        local core = CoreTabs()
        if core then pcall(core.Select, TRADE_KEY) end
    elseif trade.mode == "own" then
        OwnSelect(true)
    end
    return UI.TradeShown()
end

-- Back to the game's own page.
function UI.ShowNative()
    if not UI.TradeShown() then return end
    local book = TradeFrame()
    if trade.mode == "core" then
        local core = CoreTabs()
        if core then pcall(core.ShowNative) end
    else
        OwnSelect(false)
    end
    if book then pcall(CheckNativeTab, book) end
end

-- The step's recipe on the game's crafting page, with the number of crafts filled in.
function UI.ShowRecipe(step)
    local T = C_TradeSkillUI
    if not (T and T.OpenRecipe and step and step.r) then return end
    UI.ShowNative()
    pcall(T.OpenRecipe, step.r.id)
    local count = UI.CraftCount(step)
    ns.After(0.3, function()
        local book = TradeFrame()
        local box = book and type(book.CraftingPage) == "table" and book.CraftingPage.CreateMultipleInputBox
        if type(box) == "table" and box.SetValue and box:IsShown() then pcall(box.SetValue, box, count) end
    end)
end

----------------------------------------------------------------------
-- Auction house: the page and its tab
----------------------------------------------------------------------
local auction = {}
UI.auction = auction

local function AuctionFrame()
    local ah = _G.AuctionHouseFrame
    return type(ah) == "table" and ah or nil
end

-- The game's Buy tab, searching for the item.
function UI.SearchAuction(item)
    local ah = AuctionFrame()
    local name = ns.Prices.ItemName(item)
    if not (ah and name and type(AuctionHouseFrameDisplayMode) == "table") then return false end
    return (pcall(function()
        ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
        ah.SearchBar:SetSearchText(name)
        ah.SearchBar:StartSearch()
    end))
end

local function BuildAuctionPage(ah)
    local page = CreateFrame("Frame", "SkillPathAuctionPage", ah)
    -- Under the title bar, above the money bar: the box the game's Auctions page takes.
    page:SetPoint("TOPLEFT", ah, "TOPLEFT", 4, -24)
    page:SetPoint("BOTTOMRIGHT", ah, "BOTTOMRIGHT", -4, 27)
    page:Hide()

    -- To the right of the window's portrait.
    page.Title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    page.Title:SetPoint("TOPLEFT", page, "TOPLEFT", 66, -8)
    page.Cost = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.Cost:SetPoint("TOPLEFT", page.Title, "BOTTOMLEFT", 0, -4)
    page.Cost:SetPoint("RIGHT", page, "RIGHT", -140, 0)
    page.Cost:SetJustifyH("LEFT")
    page.Cost:SetWordWrap(false)
    page.Scan = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    page.Scan:SetSize(120, 22)
    page.Scan:SetPoint("TOPRIGHT", page, "TOPRIGHT", -8, -20)
    page.Scan:SetText("Scan prices")
    page.Scan:SetScript("OnClick", function() ns.Prices.StartScan(true) end)
    page.Prices = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    page.Prices:SetPoint("BOTTOMRIGHT", page.Scan, "TOPRIGHT", 0, 3)

    local left = NewInset(page)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -46)
    left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    left:SetWidth(430)
    local right = NewInset(page)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)

    auction.page = page
    auction.buy = UI.NewList(left, "SkillPathBuyScroll")
    auction.sell = UI.NewList(right, "SkillPathSellScroll")
    page:SetScript("OnShow", function() UI.Update() end)
    page:SetScript("OnHide", function()
        if UI.tooltipRow and OwnsTooltip(UI.tooltipRow) then GameTooltip:Hide() end
    end)
end

local SEARCH_HINT = "Click to search for it."

local function UpdateAuction()
    local page = auction.page
    if not (page and page:IsVisible() and ns.db) then return end
    local plan = ns.Plan()
    local title, line = UI.Summary(plan)
    page.Title:SetText(title)
    page.Cost:SetText(line)
    page.Prices:SetText(UI.PriceStatus())
    page.Scan:SetEnabled(not ns.Prices.IsScanning())

    local buy, sell = {}, {}
    local buyStep, sellStep
    for _, s in ipairs(UI.Steps(plan)) do
        if s.kind == "buy" then buyStep = s elseif s.kind == "sell" then sellStep = s end
    end
    -- The same numbers and names as the steps in the professions window.
    if buyStep then
        buy[#buy + 1] = { kind = "head", text = ("%d. Buy reagents: %s"):format(buyStep.n,
            (select(2, UI.StepText(buyStep, plan)))) }
        for _, e in ipairs(buyStep.entries) do
            buy[#buy + 1] = UI.ShopCard(e, function() UI.SearchAuction(e.item) end, SEARCH_HINT)
        end
    elseif plan.ok then
        buy[#buy + 1] = { kind = "text", text = "Nothing to buy: you hold every reagent the path uses." }
    end
    AddNotes(buy, plan)
    if sellStep then
        sell[#sell + 1] = { kind = "head", text = ("%d. Sell what's left: %s"):format(sellStep.n,
            (select(2, UI.StepText(sellStep, plan)))) }
        for _, e in ipairs(sellStep.entries) do
            sell[#sell + 1] = UI.SellCard(e, function() UI.SearchAuction(e.item) end, SEARCH_HINT)
        end
    elseif plan.ok then
        sell[#sell + 1] = { kind = "text", text = "Nothing left over to sell." }
    end
    auction.buy:Set(buy)
    auction.sell:Set(sell)
end

-- Without LibAHTab: the tab it would make, after the game's last one.
local function OwnAuctionTab(ah)
    local root = CreateFrame("Frame", nil, ah)
    root:SetSize(10, 10)
    root:SetPoint("TOPLEFT", ah.Tabs[#ah.Tabs], "TOPRIGHT")
    local tab = CreateFrame("Button", AH_TAB, root, "AuctionHouseFrameDisplayModeTabTemplate")
    tab:SetText(ns.NAME)
    tab:SetPoint("TOPLEFT", root, "TOPLEFT", 3, 0)
    if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 20, nil, 70) end
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    tab:SetScript("OnClick", function() UI.SelectAuction() end)
    -- The game showing one of its own pages puts ours away.
    hooksecurefunc(ah, "SetDisplayMode", function(_, displayMode)
        if type(displayMode) == "table" and #displayMode > 0 then
            auction.page:Hide()
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
        end
    end)
    auction.tab = tab
end

local function AttachAuction()
    if auction.attached then return end
    local ah = AuctionFrame()
    if not (ah and type(ah.Tabs) == "table" and #ah.Tabs > 0) then return end
    auction.attached = true
    local ok, err = pcall(function()
        BuildAuctionPage(ah)
        local lib = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibAHTab-1-0", true)
        if type(lib) == "table" and lib.CreateTab and lib.SetSelected and lib.GetButton then
            lib:CreateTab(AH_TAB, auction.page, ns.NAME, ns.NAME)
            auction.tab, auction.lib, auction.mode = lib:GetButton(AH_TAB), lib, "lib"
        else
            OwnAuctionTab(ah)
            auction.mode = "own"
        end
    end)
    if not ok then
        auction.error, auction.mode = tostring(err), nil
        if auction.page then auction.page:Hide() end
    end
end
UI.AttachAuction = AttachAuction

function UI.AuctionShown()
    return auction.page ~= nil and auction.page:IsVisible() and true or false
end

function UI.SelectAuction()
    AttachAuction()
    if auction.mode == "lib" then
        pcall(auction.lib.SetSelected, auction.lib, AH_TAB)
    elseif auction.mode == "own" then
        local ah = AuctionFrame()
        pcall(function()
            ah:SetDisplayMode({})       -- hides every page of the game's
            ah.displayMode = nil
            for _, tab in ipairs(ah.Tabs) do PanelTemplates_DeselectTab(tab) end
            PanelTemplates_SelectTab(auction.tab)
            if ah.SetTitle then ah:SetTitle(ns.NAME) end
        end)
        auction.page:Show()
    end
    return UI.AuctionShown()
end

----------------------------------------------------------------------
-- What the rest of the addon calls
----------------------------------------------------------------------
function UI.Init()
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        pcall(EventUtil.ContinueOnAddOnLoaded, "Blizzard_Professions", AttachTrade)
        pcall(EventUtil.ContinueOnAddOnLoaded, "Blizzard_AuctionHouseUI", AttachAuction)
    end
    AttachTrade()
    AttachAuction()
end

function UI.Update()
    UpdateTrade()
    UpdateAuction()
end

function UI.IsShown()
    return UI.TradeShown() or UI.AuctionShown()
end

local function Visible(frame)
    return frame ~= nil and frame.IsVisible ~= nil and frame:IsVisible() and true or false
end

-- /skillpath and the minimap button: the SkillPath tab of whichever window is open.
function UI.Toggle()
    if Visible(TradeFrame()) then
        if UI.TradeShown() then
            UI.ShowNative()
            return
        elseif UI.SelectTrade() then
            return
        end
    end
    if Visible(AuctionFrame()) and UI.SelectAuction() then return end
    ns.Report()
    ns.Print("SkillPath is a tab in the professions window and in the auction house.")
end

-- A profession opened and its recipes were read.
function UI.ProfessionsShown()
    AttachTrade()
    if ns.db.openOnTab then UI.SelectTrade() end
    UI.Update()
end

function UI.ProfessionsHidden() end

function UI.AuctionOpened()
    AttachAuction()
    UI.Update()
end

function UI.Status()
    return ("professions tab: %s%s; auction tab: %s%s"):format(trade.mode or "not attached",
        trade.error and (" (" .. trade.error .. ")") or "", auction.mode or "not attached",
        auction.error and (" (" .. auction.error .. ")") or "")
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["SkillPath"] = {
    version = ns.VERSION,
    frames = {
        { label = "professions page", frame = function() return UI.TradeShown() and trade.page or nil end },
        { label = "professions side tab", frame = function()
            return trade.tab and Visible(TradeFrame()) and trade.tab or nil
        end },
        { label = "auction house page", frame = function() return UI.AuctionShown() and auction.page or nil end },
        { label = "auction house tab", frame = function()
            return auction.tab and Visible(AuctionFrame()) and auction.tab or nil
        end },
        { label = "row tooltip", frame = function()
            local row = UI.tooltipRow
            if row and GameTooltip and GameTooltip:IsShown() and OwnsTooltip(row) then return GameTooltip end
        end },
    },
}
