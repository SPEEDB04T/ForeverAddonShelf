-- SkillPath: the guide panel. A sibling of the professions window's own crafting output log
-- (Blizzard_ProfessionsCraftingOutputLog on the forever branch): the same ScrollingFlatPanelTemplate,
-- step cards built like its 46-pixel item elements (looting item card art, item button, name),
-- and per-point lines built like its extra rows (the Professions-Results-Bracket and small white
-- text). It sits to the right of the professions window, past its side tabs, and beside the
-- output log when that is open; with the professions window closed it floats and can be moved.
local _, ns = ...
local UI = {}
ns.UI = UI

local Num = ns.Num

-- Output log: element 46 high, extra rows 20 (ElementBonusRowHeight), spacing 2, pad 6.
local CARD, POINT, HEADER, GAP, PAD = 46, 20, 24, 2, 6
-- The output log is 220 wide and at most 290 high; a guide needs room for a cost on each line
-- and a whole profession's steps.
local PANEL_WIDTH, PANEL_MAX_HEIGHT = 300, 560
local ROW_WIDTH = PANEL_WIDTH - PAD - PAD * 2
local NOTE_CHARS = 52          -- GameFontHighlightSmall at this width: about this many characters a line
local FRAME_NAME = "SkillPathFrame"
local SIDE_TABS = 44           -- the professions window's side tabs stick out this far on its right

local frame, mode
local classicRows = {}

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
-- Words for the rows and tooltips
----------------------------------------------------------------------
local function CostText(cost, priced)
    if not priced then return "no price" end
    if cost < 0.5 then return "free" end
    return ns.Money(cost)
end

local function Plural(n, one, many) return n == 1 and one or many end

-- One reagent's sources, in a line.
function UI.SourceText(item)
    local sup = ns.Prices.Supply(item)
    local parts = {}
    if sup.have > 0 then parts[#parts + 1] = ("you have %d"):format(sup.have) end
    if sup.listed > 0 then
        local cheapest
        for _, u in ipairs(sup.units) do cheapest = cheapest and math.min(cheapest, u.u) or u.u end
        for _, l in ipairs(sup.lots) do cheapest = cheapest and math.min(cheapest, l.u) or l.u end
        parts[#parts + 1] = ("auction house from %s each (%d listed, %s)"):format(ns.Money(cheapest), sup.listed,
            ns.Age(sup.age))
    end
    if sup.vendor then
        parts[#parts + 1] = ("vendor %s each%s"):format(ns.Money(sup.vendor),
            sup.vendorFrom == "vendor" and "" or " (the item's vendor price)")
    end
    if not sup.priced then parts[#parts + 1] = ns.Prices.Missing(sup) end
    return table.concat(parts, "; ")
end

local function AddReagents(tooltip, r)
    local wr, wg, wb = Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
    local gr, gg, gb = Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
    if r.currency then tooltip:AddLine("Also costs a currency (not counted).", gr, gg, gb, true) end
    for _, slot in ipairs(r.slots or {}) do
        for i, item in ipairs(slot.items) do
            local name = ns.Prices.ItemName(item)
            tooltip:AddLine(("%s%d x %s"):format(i > 1 and "  or " or "", slot.qty, name), wr, wg, wb)
            tooltip:AddLine("    " .. UI.SourceText(item), gr, gg, gb, true)
        end
    end
end

----------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------
local function OwnsTooltip(row)
    return GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row)
end

local function StepTooltip(row, step)
    local r = step.r
    local plan = ns.Plan()
    local offset = plan.ctx and plan.ctx.offset or 0
    GameTooltip:SetText(r.name, UI.DifficultyColor(r, step.from, offset))
    local wr, wg, wb = Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
    local nr, ng, nb = Color("NORMAL_FONT_COLOR", 1, 0.82, 0)
    local gr, gg, gb = Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
    local rr, rg, rb = Color("RED_FONT_COLOR", 1, 0.1, 0.1)
    GameTooltip:AddLine(("Skill %d to %d: %s %s, %s"):format(step.from, step.to, ns.Crafts(step.crafts),
        Plural(step.crafts, "craft", "crafts"), step.priced and ("about " .. CostText(step.cost, true)) or "no price"),
        wr, wg, wb)
    if r.trust then
        GameTooltip:AddLine(("Orange below %d, grey from %d%s (the client's recipe table; the game confirms it)."):format(
            r.y - offset, r.g - offset, offset ~= 0 and ", with your skill bonus" or ""), gr, gg, gb, true)
    else
        GameTooltip:AddLine("Its levels aren't confirmed, so it is only used while the game shows it orange.",
            gr, gg, gb, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Each point", nr, ng, nb)
    local shown = 0
    for _, p in ipairs(step.points) do
        shown = shown + 1
        if shown > 20 then
            GameTooltip:AddLine(("  and %d more"):format(#step.points - 20), gr, gg, gb)
            break
        end
        GameTooltip:AddDoubleLine(UI.PointText(p), CostText(p.cost or 0, p.priced), wr, wg, wb, wr, wg, wb)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Reagents for one craft", nr, ng, nb)
    AddReagents(GameTooltip, r)
    for _, p in ipairs(step.points) do
        if p.missing then
            for _, m in ipairs(p.missing) do
                local what = m.item and (ns.Prices.ItemName(m.item) .. ": ") or ""
                GameTooltip:AddLine("No price: " .. what .. m.why, rr, rg, rb, true)
            end
            break
        end
    end
    local alts = {}
    for _, c in pairs(step.alts or {}) do alts[#alts + 1] = c end
    table.sort(alts, function(a, b) return a.r.id < b.r.id end)
    for _, c in ipairs(alts) do
        local why = c.missing and c.missing[1]
        local item = why and why.item and ns.Prices.ItemName(why.item)
        GameTooltip:AddLine(("Might be cheaper: %s (no price for %s)"):format(c.r.name, item or "a reagent"), rr, rg, rb, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: show it in the professions window. Shift-click: link it.", gr, gg, gb, true)
end

local function ShopTooltip(row, e)
    if not pcall(GameTooltip.SetItemByID, GameTooltip, e.item) then GameTooltip:SetText(ns.Prices.ItemName(e.item)) end
    local wr, wg, wb = Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
    local gr, gg, gb = Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(("The guide uses about %s; you have %d%s."):format(ns.Crafts(e.need), e.have,
        e.made > 0.05 and (", and its earlier steps make about " .. ns.Crafts(e.made)) or ""), wr, wg, wb, true)
    GameTooltip:AddLine(UI.SourceText(e.item), gr, gg, gb, true)
end

local function OptionTooltip(row, o)
    local r = o.r
    GameTooltip:SetText(r.name, Color("NORMAL_FONT_COLOR", 1, 0.82, 0))
    local wr, wg, wb = Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
    local gr, gg, gb = Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
    GameTooltip:AddLine("You don't know this recipe yet.", wr, wg, wb)
    if o.covers > 0 then
        GameTooltip:AddLine(("It gives skill on %d %s past where your recipes stop."):format(o.covers,
            Plural(o.covers, "point", "points")), wr, wg, wb, true)
    end
    if o.saving >= 1 then
        GameTooltip:AddLine(("It could save about %s between %d and %d (not counting what the recipe costs)."):format(
            ns.Money(o.saving), o.from, o.to), wr, wg, wb, true)
    end
    GameTooltip:AddLine(("Orange below %d, grey from %d."):format(r.y, r.g), gr, gg, gb)
    if o.learnAt then
        GameTooltip:AddLine(("Its recipe item asks for skill %d."):format(o.learnAt), gr, gg, gb)
    else
        GameTooltip:AddLine("The game doesn't say at what skill it is taught.", gr, gg, gb, true)
    end
    if o.source then GameTooltip:AddLine(o.source, gr, gg, gb, true) end
    GameTooltip:AddLine(" ")
    AddReagents(GameTooltip, r)
end

function UI.ShowTooltip(row)
    local e = row.element
    if not (e and GameTooltip) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if e.kind == "step" then
        StepTooltip(row, e.step)
    elseif e.kind == "shop" then
        ShopTooltip(row, e.entry)
    elseif e.kind == "option" then
        OptionTooltip(row, e.option)
    elseif e.kind == "point" then
        local p = e.point
        GameTooltip:SetText(p.r.name)
        local wr, wg, wb = Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
        if p.orange then
            GameTooltip:AddLine(("Orange: every craft gives %d %s."):format(p.gain, Plural(p.gain, "point", "points")),
                wr, wg, wb, true)
        else
            GameTooltip:AddLine(("%d%% chance a craft gives a point at %d, so about %s crafts."):format(
                math.floor(p.chance * 100 + 0.5), p.s, ns.Crafts(p.crafts)), wr, wg, wb, true)
        end
    else
        GameTooltip:Hide()
        return
    end
    GameTooltip:Show()
    UI.tooltipRow = row
end

----------------------------------------------------------------------
-- Clicks
----------------------------------------------------------------------
local function RecipeLink(id)
    local T = C_TradeSkillUI
    return T and ns.Str(ns.Call(T.GetRecipeLink, id))
end

function UI.Click(row, button)
    local e = row.element
    if not e then return end
    local r = (e.kind == "step" and e.step.r) or (e.kind == "option" and e.option.r) or (e.kind == "point" and e.point.r)
    if IsModifiedClick and IsModifiedClick() then
        local link
        if r then
            link = RecipeLink(r.id)
        elseif e.kind == "shop" then
            link = select(2, ns.Call(C_Item and C_Item.GetItemInfo, e.entry.item))
        end
        if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
        return
    end
    if r and C_TradeSkillUI and C_TradeSkillUI.OpenRecipe then
        pcall(C_TradeSkillUI.OpenRecipe, r.id)
    end
end

----------------------------------------------------------------------
-- A row: the output log's element (card) or extra row (bracket line), built in Lua
----------------------------------------------------------------------
local function NewItemButton(row)
    local ok, item = pcall(CreateFrame, "ItemButton", nil, row)
    if not ok or not item then item = CreateFrame("Button", nil, row, "ItemButtonTemplate") end
    return item
end

local function BuildRow(row)
    row.built = true
    row:EnableMouse(true)

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetAllPoints()
    Art(row.Background, "looting_itemcard_bg", "Interface\\QuestFrame\\UI-QuestItemNameFrame")
    row.Border = row:CreateTexture(nil, "BORDER")
    row.Border:SetAllPoints()
    if not Art(row.Border, "looting_itemcard_stroke_normal") then row.Border:Hide() end
    row.Highlight = row:CreateTexture(nil, "OVERLAY")
    row.Highlight:SetAllPoints()
    Art(row.Highlight, "looting_itemcard_stroke_clickstate", "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Highlight:SetBlendMode("ADD")
    row.Highlight:SetAlpha(0.7)
    row.Highlight:Hide()

    local item = NewItemButton(row)
    row.Item = item
    item:SetSize(37, 37)
    item:SetPoint("TOPLEFT", 5, -4)
    item:EnableMouse(false)          -- the row takes the mouse, as one button

    row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Text:SetPoint("TOPLEFT", item, "TOPRIGHT", 8, -3)
    row.Text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)
    row.Sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -3)
    row.Sub:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetWordWrap(false)

    -- The extra row: bracket and one line of small text.
    row.Bracket = row:CreateTexture(nil, "ARTWORK")
    row.Bracket:SetSize(10, 19)
    row.Bracket:SetPoint("TOPLEFT", 13, -1)
    if not Art(row.Bracket, "Professions-Results-Bracket") then row.Bracket:SetTexture(nil) end
    row.Line = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Line:SetPoint("LEFT", row.Bracket, "RIGHT", 4, 0)
    row.Line:SetPoint("RIGHT", row, "RIGHT", -64, 0)
    row.Line:SetJustifyH("LEFT")
    row.Line:SetWordWrap(false)
    row.Right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Right:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.Right:SetPoint("TOP", row.Line, "TOP", 0, 0)
    row.Right:SetJustifyH("RIGHT")

    -- Headers and notes.
    row.Title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Title:SetPoint("TOPLEFT", 8, -6)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Title:SetJustifyH("LEFT")
    row.Note = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Note:SetPoint("TOPLEFT", 8, -3)
    row.Note:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Note:SetJustifyH("LEFT")
    row.Note:SetJustifyV("TOP")
    row.Note:SetWordWrap(true)

    -- The head: what the guide is for, its cost, and the scan.
    row.Big = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    row.Big:SetPoint("TOPLEFT", 8, -6)
    row.Big:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Big:SetJustifyH("LEFT")
    row.Cost = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.Cost:SetPoint("TOPLEFT", row.Big, "BOTTOMLEFT", 0, -4)
    row.Cost:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Cost:SetJustifyH("LEFT")
    row.Status = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Status:SetPoint("TOPLEFT", row.Cost, "BOTTOMLEFT", 0, -4)
    row.Status:SetPoint("RIGHT", row, "RIGHT", -96, 0)
    row.Status:SetJustifyH("LEFT")
    row.Status:SetWordWrap(true)
    row.Scan = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.Scan:SetSize(84, 22)
    row.Scan:SetPoint("BOTTOMRIGHT", -6, 6)
    row.Scan:SetText("Scan prices")
    row.Scan:SetScript("OnClick", function() ns.Prices.StartScan(true) end)

    row:SetScript("OnEnter", function(self)
        local kind = self.element and self.element.kind
        if kind == "step" or kind == "shop" or kind == "option" then self.Highlight:Show() end
        UI.ShowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        if OwnsTooltip(self) then GameTooltip:Hide() end
        self.Highlight:Hide()
    end)
    row:SetScript("OnMouseUp", function(self, button) UI.Click(self, button) end)
end

local CARD_KINDS = { step = true, shop = true, option = true, train = true, gap = true }

local function ShowParts(row, kind)
    local card = CARD_KINDS[kind] or false
    row.Background:SetShown(card or kind == "head")
    row.Border:SetShown(card and HasAtlas("looting_itemcard_stroke_normal"))
    row.Highlight:Hide()
    row.Item:SetShown(card)
    row.Text:SetShown(card)
    row.Sub:SetShown(card)
    row.Bracket:SetShown(kind == "point")
    row.Line:SetShown(kind == "point")
    row.Right:SetShown(kind == "point")
    row.Title:SetShown(kind == "header")
    row.Note:SetShown(kind == "note")
    row.Big:SetShown(kind == "head")
    row.Cost:SetShown(kind == "head")
    row.Status:SetShown(kind == "head")
    row.Scan:SetShown(kind == "head" and ns.Prices.IsOpen() and not ns.Prices.IsScanning())
end

local function SetIcon(row, icon, desaturate)
    local item = row.Item
    if SetItemButtonTexture then SetItemButtonTexture(item, icon) elseif item.icon then item.icon:SetTexture(icon) end
    if SetItemButtonCount then SetItemButtonCount(item, 0) elseif item.Count then item.Count:SetText("") end
    if SetItemButtonDesaturated then pcall(SetItemButtonDesaturated, item, desaturate and true or false) end
end

-- "45 > 46  60%, 1.7 crafts"
function UI.PointText(p)
    local range = p.gain > 1 and ("%d-%d"):format(p.s, p.to) or tostring(p.s)
    if p.orange then
        return ("%s  orange, 1 craft%s"):format(range, p.gain > 1 and (" for " .. p.gain .. " points") or "")
    end
    return ("%s  %d%%, %s crafts"):format(range, math.floor(p.chance * 100 + 0.5), ns.Crafts(p.crafts))
end

local function InitRow(row, e)
    row.element = e
    ShowParts(row, e.kind)
    local wr, wg, wb = Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
    local rr, rg, rb = Color("RED_FONT_COLOR", 1, 0.1, 0.1)
    if e.kind == "head" then
        row.Big:SetText(e.title)
        row.Cost:SetText(e.cost)
        row.Status:SetText(e.status)
        row.Background:SetVertexColor(1, 1, 1)
    elseif e.kind == "step" then
        local step = e.step
        local plan = ns.Plan()
        SetIcon(row, step.r.icon, false)
        row.Text:SetText(step.name)
        row.Text:SetTextColor(UI.DifficultyColor(step.r, step.from, plan.ctx and plan.ctx.offset or 0))
        local sub = ("%d-%d  %s %s  %s"):format(step.from, step.to, ns.Crafts(step.crafts),
            Plural(step.crafts, "craft", "crafts"), CostText(step.cost, step.priced))
        if step.stale then sub = sub .. "  (old price)" end
        row.Sub:SetText(sub)
        if step.priced then row.Sub:SetTextColor(wr, wg, wb) else row.Sub:SetTextColor(rr, rg, rb) end
        row.Background:SetVertexColor(1, 1, 1)
    elseif e.kind == "point" then
        row.Line:SetText(UI.PointText(e.point))
        row.Right:SetText(CostText(e.point.cost or 0, e.point.priced))
    elseif e.kind == "train" then
        SetIcon(row, "Interface\\Icons\\INV_Misc_Book_11", false)
        row.Text:SetText("Train the next rank")
        row.Text:SetTextColor(Color("NORMAL_FONT_COLOR", 1, 0.82, 0))
        row.Sub:SetText(("At %d: your trainer teaches the next rank."):format(e.at))
        row.Sub:SetTextColor(wr, wg, wb)
        row.Background:SetVertexColor(1, 1, 1)
    elseif e.kind == "gap" then
        SetIcon(row, "Interface\\Icons\\INV_Misc_QuestionMark", true)
        row.Text:SetText(("No recipe for %d-%d"):format(e.step.from, e.step.to))
        row.Text:SetTextColor(rr, rg, rb)
        row.Sub:SetText("Learn a new recipe to go on.")
        row.Sub:SetTextColor(wr, wg, wb)
        row.Background:SetVertexColor(1, 1, 1)
    elseif e.kind == "shop" then
        local s = e.entry
        SetIcon(row, ns.Prices.ItemIcon(s.item), false)
        if SetItemButtonCount then SetItemButtonCount(row.Item, s.buy) elseif row.Item.Count then
            row.Item.Count:SetText(s.buy > 1 and tostring(s.buy) or "")
        end
        row.Text:SetText(ns.Prices.ItemName(s.item))
        row.Text:SetTextColor(wr, wg, wb)
        local sub
        if s.buy == 0 then
            sub = ("You have enough (%d)"):format(s.have)
            row.Sub:SetTextColor(wr, wg, wb)
        elseif s.cost then
            sub = ("Buy %d: %s, %s%s"):format(s.buy, ns.Money(s.cost), s.from or "", s.stale and " (old price)" or "")
            row.Sub:SetTextColor(wr, wg, wb)
        else
            sub = ("Buy %d: %s"):format(s.buy, s.missing or "no price")
            row.Sub:SetTextColor(rr, rg, rb)
        end
        row.Sub:SetText(sub)
        row.Background:SetVertexColor(1, 1, 1)
    elseif e.kind == "option" then
        local o = e.option
        SetIcon(row, o.r.icon, true)
        row.Text:SetText(o.r.name)
        row.Text:SetTextColor(Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5))
        local sub
        if o.covers > 0 then
            sub = ("Not known: goes on to %d"):format(o.to)
        else
            sub = ("Not known: saves about %s"):format(ns.Money(o.saving))
        end
        if o.learnAt then sub = sub .. (", learn at %d"):format(o.learnAt) end
        row.Sub:SetText(sub)
        row.Sub:SetTextColor(wr, wg, wb)
        row.Background:SetVertexColor(0.6, 0.6, 0.6)
    elseif e.kind == "header" then
        row.Title:SetText(e.text)
    elseif e.kind == "note" then
        row.Note:SetText(e.text)
    end
    if OwnsTooltip(row) then UI.ShowTooltip(row) end
end
UI.InitRow = InitRow

----------------------------------------------------------------------
-- The list: one element per line of the guide
----------------------------------------------------------------------
local function NoteHeight(text)
    local lines = math.max(1, math.ceil(#text / NOTE_CHARS))
    return lines * 12 + 6
end

function UI.Extent(e)
    if e.kind == "head" then return 70 end
    if e.kind == "point" then return POINT end
    if e.kind == "header" then return HEADER end
    if e.kind == "note" then return NoteHeight(e.text) end
    return CARD
end

local function HeadStatus(plan)
    local P = ns.Prices
    if P.IsScanning() then
        local done, total = P.Progress()
        return ("Reading auction prices: %d of %d."):format(done, total)
    end
    local n, age = P.Summary()
    local where = P.IsOpen() and "" or " Open the auction house to scan."
    if n == 0 then return "No auction prices yet." .. where end
    return ("Auction prices of %d %s, newest %s.%s"):format(n, Plural(n, "item", "items"), ns.Age(age), where)
end

function UI.Elements()
    local plan = ns.Plan()
    local out = {}
    if not plan.ok then
        out[1] = { kind = "head", title = plan.name or ns.NAME, cost = "", status = HeadStatus(plan) }
        out[2] = { kind = "note", text = plan.why }
        return out
    end
    local cost
    if plan.totalComplete then
        cost = ("Expected cost: %s"):format(CostText(plan.total, true))
    else
        cost = ("Expected cost: %s for the priced part"):format(CostText(plan.total, true))
    end
    out[#out + 1] = { kind = "head", title = ("%s %d to %d"):format(plan.name, plan.from, plan.to), cost = cost,
        status = HeadStatus(plan), scan = ns.Prices.IsOpen() }
    for _, note in ipairs(plan.notes) do out[#out + 1] = { kind = "note", text = note } end
    for _, step in ipairs(plan.steps) do
        if step.kind == "craft" then
            out[#out + 1] = { kind = "step", step = step }
            if ns.db.showPoints then
                for _, p in ipairs(step.points) do out[#out + 1] = { kind = "point", point = p, step = step } end
            end
        elseif step.kind == "train" then
            out[#out + 1] = { kind = "train", at = step.at }
        elseif step.kind == "gap" then
            out[#out + 1] = { kind = "gap", step = step }
            out[#out + 1] = { kind = "note", text = step.why }
        end
    end
    if #plan.shopping > 0 then
        out[#out + 1] = { kind = "header", text = "Shopping list" }
        for _, entry in ipairs(plan.shopping) do out[#out + 1] = { kind = "shop", entry = entry } end
    end
    if #plan.options > 0 then
        out[#out + 1] = { kind = "header", text = "Recipes you could learn" }
        for _, o in ipairs(plan.options) do out[#out + 1] = { kind = "option", option = o } end
    end
    return out
end

local function ElementsHeight(list)
    local h = 0
    for i, e in ipairs(list) do h = h + UI.Extent(e) + (i > 1 and GAP or 0) end
    return math.max(h, CARD)
end

----------------------------------------------------------------------
-- The window
----------------------------------------------------------------------
local function CanUsePanel()
    if not (CreateScrollBoxListLinearView and ScrollUtil and CreateDataProvider) then return false end
    if not (ScrollUtil.InitScrollBoxListWithScrollBar or ScrollUtil.InitScrollBoxWithScrollBar) then return false end
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, "ScrollingFlatPanelTemplate")
        if not (ok and info) then return false end
    end
    return true
end

local function CreatePanel()
    local ok, f = pcall(CreateFrame, "Frame", FRAME_NAME, UIParent, "ScrollingFlatPanelTemplate")
    if not (ok and f and f.ScrollBox and f.ScrollBar and f.Resize) then return nil end
    f.panelWidth, f.panelMaxHeight = PANEL_WIDTH, PANEL_MAX_HEIGHT
    f.CalculateElementsHeight = function() return ElementsHeight(UI.current or {}) end
    -- The close animation ends in HideUIPanel; a plain Hide does the same for a window that isn't a UI panel.
    f.OnHideAnimFinished = function(self) self:Hide() end
    local view = CreateScrollBoxListLinearView(PAD, PAD, PAD, PAD, GAP)
    view:SetElementInitializer("Frame", function(row, e)
        if not row.built then BuildRow(row) end
        InitRow(row, e)
    end)
    if view.SetElementExtentCalculator then
        view:SetElementExtentCalculator(function(_, e) return UI.Extent(e) end)
    end
    local init = ScrollUtil.InitScrollBoxListWithScrollBar or ScrollUtil.InitScrollBoxWithScrollBar
    init(f.ScrollBox, f.ScrollBar, view)
    pcall(function()      -- the output log's shadows over the list's top and bottom
        f.ScrollBox:SetShadowsFrameLevel(f.ScrollBox.ScrollTarget:GetFrameLevel() + 15)
        f.ScrollBox:SetShadowsScale(0.2)
        f.ScrollBox:GetUpperShadowTexture():SetTexCoord(0, 1, 1, 0)
        f.ScrollBox:GetUpperShadowTexture():SetPoint("TOPLEFT", 30, 0)
        f.ScrollBox:GetUpperShadowTexture():SetPoint("TOPRIGHT", -30, 0)
        f.ScrollBox:GetLowerShadowTexture():SetPoint("BOTTOMLEFT", 30, 0)
        f.ScrollBox:GetLowerShadowTexture():SetPoint("BOTTOMRIGHT", -30, 0)
    end)
    if f.SetTitle then f:SetTitle(ns.NAME) end
    return f
end

-- A client without the panel template: the game's basic window with a scroll frame.
local function CreateClassic()
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(PANEL_WIDTH + 24, 300)
    if f.TitleText then f.TitleText:SetText(ns.NAME) end
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(ROW_WIDTH, CARD)
    scroll:SetScrollChild(child)
    f.Scroll, f.Child = scroll, child
    return f
end

local function ClassicRow(i)
    local row = classicRows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, frame.Child)
    BuildRow(row)
    classicRows[i] = row
    return row
end

function UI.Create()
    if frame then return frame end
    if CanUsePanel() then frame = CreatePanel() end
    if frame then
        mode = "scrollbox"
    else
        mode = "classic"
        frame = CreateClassic()
    end
    _G[FRAME_NAME] = frame
    frame:Hide()
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        if not self.anchored then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not self.anchored then UI.SavePosition() end
    end)
    frame:SetScript("OnHide", function()
        frame.autoOpened = false
        if UI.tooltipRow and OwnsTooltip(UI.tooltipRow) then GameTooltip:Hide() end
    end)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, FRAME_NAME) end   -- Escape closes it
    UI.ApplyScale()
    UI.Place()
    return frame
end

function UI.Mode() return mode end
function UI.Frame() return frame end

function UI.ApplyScale()
    if frame and ns.db then frame:SetScale(Num(ns.db.scale) or 1) end
end

function UI.SavePosition()
    if not (frame and ns.db) then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    local parentTop = UIParent and UIParent.GetTop and UIParent:GetTop()
    if not (left and top and parentTop) then return end
    local scale = frame:GetScale() or 1
    ns.db.point = { "TOPLEFT", left, top - parentTop / scale }
end

local hooked = false
local function HookProfessions()
    if hooked or not ProfessionsFrame then return end
    hooked = true
    local log = ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.CraftingOutputLog
    if log and log.HookScript then
        log:HookScript("OnShow", function() UI.Place() end)
        log:HookScript("OnHide", function() UI.Place() end)
    end
end

local function ProfessionsVisible()
    return ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown() and true or false
end

-- Beside the professions window when it is open (and beside its output log), else where it was left.
function UI.Place()
    if not frame then return end
    frame:ClearAllPoints()
    if ProfessionsVisible() then
        HookProfessions()
        frame.anchored = true
        local log = ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.CraftingOutputLog
        if log and log.IsShown and log:IsShown() then
            frame:SetPoint("TOPLEFT", log, "TOPRIGHT", 8, 0)
        else
            frame:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", SIDE_TABS, 0)
        end
        return
    end
    frame.anchored = false
    local p = ns.db and ns.db.point
    if type(p) == "table" and type(p[2]) == "number" and type(p[3]) == "number" then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", p[2], p[3])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

function UI.Update()
    if not (frame and ns.db) then return end
    local list = UI.Elements()
    UI.current = list
    if mode == "scrollbox" then
        local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
        frame.ScrollBox:SetDataProvider(CreateDataProvider(list), retain)
        frame:Resize()
    else
        local y = -PAD
        for i, e in ipairs(list) do
            local row = ClassicRow(i)
            local h = UI.Extent(e)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.Child, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", frame.Child, "TOPRIGHT", 0, y)
            row:SetHeight(h)
            InitRow(row, e)
            row:Show()
            y = y - h - GAP
        end
        for i = #list + 1, #classicRows do
            classicRows[i].element = nil
            classicRows[i]:Hide()
        end
        local height = -y + PAD
        frame.Child:SetHeight(height)
        frame:SetHeight(math.min(height + 36, PANEL_MAX_HEIGHT))
    end
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end

function UI.Show()
    UI.Create()
    UI.Place()
    UI.Update()
    if mode == "scrollbox" and frame.Open then frame:Open() else frame:Show() end
end

function UI.Hide()
    if not frame then return end
    if mode == "scrollbox" and frame.Close and frame:IsShown() then frame:Close() else frame:Hide() end
end

function UI.Toggle()
    if UI.IsShown() then UI.Hide() else UI.Show() end
end

-- The professions window opened (and its recipes were read).
function UI.ProfessionsShown()
    if not frame then return end
    if UI.IsShown() then
        UI.Place()
        UI.Update()
    elseif ns.db.autoShow then
        UI.Show()
        frame.autoOpened = true
    end
end

function UI.ProfessionsHidden()
    if not frame then return end
    if frame.autoOpened and UI.IsShown() then
        frame:Hide()
    else
        UI.Place()
    end
end

-- The rows on screen (tests and LookShots).
function UI.Rows()
    local out = {}
    if not frame then return out end
    if mode == "scrollbox" then
        if frame.ScrollBox.ForEachFrame then frame.ScrollBox:ForEachFrame(function(row) out[#out + 1] = row end) end
    else
        for _, row in ipairs(classicRows) do
            if row:IsShown() then out[#out + 1] = row end
        end
    end
    return out
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["SkillPath"] = {
    version = ns.VERSION,
    frames = {
        { label = "guide panel", frame = function() return frame and frame:IsShown() and frame or nil end },
        { label = "row tooltip", frame = function()
            local row = UI.tooltipRow
            if row and GameTooltip and GameTooltip:IsShown() and OwnsTooltip(row) then return GameTooltip end
        end },
    },
}
