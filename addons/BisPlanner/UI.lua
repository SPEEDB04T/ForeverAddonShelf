-- BiS Planner: the window (/bisplan, left-click on the minimap button).
--
-- It copies the game's Macro window (Blizzard_MacroUI.xml, Gethe/wow-ui-source branch
-- forever) the way Slutmog Shop's window does: the portrait window (ButtonFrameTemplate,
-- 440 x 540 against the macro window's 338 x 424, for 17 item rows), top tabs
-- (PanelTopTabButtonTemplate at 51, -28, the second hanging off the first) and 80 x 22 panel
-- buttons in the button bar (BOTTOMLEFT 4, 4 / BOTTOMRIGHT -5, 4).
--   Above both tabs: the set of weights in use (WowStyle1DropdownTemplate), New and Delete,
--                    and the level planned for (InputBoxTemplate).
--   Plan tab:        one row per slot: the bag slot (ItemButton, 37 px, with its quality
--                    border), the name in the item's quality colour, where it comes from
--                    under it, the quest log's row highlight.
--   Weights tab:     one row per stat with two InputBoxTemplate boxes: weight, and "at least".
local _, ns = ...
local UI = {}
ns.UI = UI

local W, H = 440, 540
local HEADER_H = 34
local ROW_H = 41
local STAT_H = 24
local ROW_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local NEW_POPUP, DELETE_POPUP = "BISPLANNER_NEW_PROFILE", "BISPLANNER_DELETE_PROFILE"
local SPEC_POPUP = "BISPLANNER_SPEC_WEIGHTS"

local frame
local planRows, statBoxes = {}, {}

local function Has(t, k)
    return type(t) == "table" and type(t[k]) == "table"
end

local function FromTemplate(kind, parent, template, name)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
end

local function Text(parent, font, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK", font)
    if fs.SetFontObject and _G[font] then pcall(fs.SetFontObject, fs, _G[font]) end
    return fs
end

local function Color(c, r, g, b)
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return r, g, b
end

local function Sound(kit)
    if kit and type(PlaySound) == "function" then pcall(PlaySound, kit) end
end

local function Button(parent, label, w, h)
    local b = FromTemplate("Button", parent, "UIPanelButtonTemplate") or CreateFrame("Button", nil, parent)
    b:SetSize(w or 80, h or 22)
    b:SetText(label)
    return b
end

local function Tip(owner, title, ...)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then GameTooltip:AddLine(line, 1, 0.82, 0, true) end
    end
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

local function OnHover(widget, title, ...)
    local lines = { ... }
    widget:SetScript("OnEnter", function(self) Tip(self, title, unpack(lines)) end)
    widget:SetScript("OnLeave", HideTip)
end

local function Focused(box)
    return type(box) == "table" and type(box.HasFocus) == "function" and box:HasFocus() and true or false
end

local function QualityColor(quality)
    local c = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[quality]
    return Color(c, 1, 1, 1)
end

local function InputBox(parent, w)
    local box = FromTemplate("EditBox", parent, "InputBoxTemplate") or CreateFrame("EditBox", nil, parent)
    box:SetSize(w, 20)
    box:SetAutoFocus(false)
    if box.SetMaxLetters then box:SetMaxLetters(8) end
    if box.SetFontObject and ChatFontNormal then pcall(box.SetFontObject, box, ChatFontNormal) end
    return box
end

local function Scroll(page, top)
    local list = FromTemplate("ScrollFrame", page, "ScrollFrameTemplate")
        or FromTemplate("ScrollFrame", page, "UIPanelScrollFrameTemplate")
        or CreateFrame("ScrollFrame", nil, page)
    list:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -top)
    list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -26, 4)
    local content = CreateFrame("Frame", nil, list)
    content:SetSize(W - 10 - 6 - 26, 10)
    if list.SetScrollChild then list:SetScrollChild(content) end
    if Has(list, "ScrollBar") and list.ScrollBar.SetHideIfUnscrollable then
        pcall(list.ScrollBar.SetHideIfUnscrollable, list.ScrollBar, true)
    end
    return list, content
end

-- "1,5" and "1.5" are both one and a half. Empty is nothing. Anything else is refused (false).
function UI.ParseNumber(text)
    text = tostring(text or ""):gsub("%s", ""):gsub(",", ".")
    if text == "" then return nil end
    local value = tonumber(text)
    if not value or value ~= value or value == math.huge or value == -math.huge then return false end
    return value
end

---------------------------------------------------------------------------
-- Popups: a name for a new set of weights, and "delete this set?"
---------------------------------------------------------------------------
local function PopupBox(popup)
    if type(popup) ~= "table" then return nil end
    if type(popup.GetEditBox) == "function" then
        local ok, box = pcall(popup.GetEditBox, popup)
        if ok and type(box) == "table" then return box end
    end
    return popup.editBox or popup.EditBox
end

local function AcceptNew(popup)
    local box = PopupBox(popup)
    local ok, why = ns.NewProfile(box and box.GetText and box:GetText() or "")
    if not ok then ns.Print(why) end
end

local function EnsurePopups()
    if type(StaticPopupDialogs) ~= "table" or StaticPopupDialogs[NEW_POPUP] then return end
    StaticPopupDialogs[NEW_POPUP] = {
        text = "Name the new set of weights. It starts as a copy of the one in use.",
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        maxLetters = 24,
        OnAccept = AcceptNew,
        EditBoxOnEnterPressed = function(box)
            local popup = box:GetParent()
            AcceptNew(popup)
            if popup and popup.Hide then popup:Hide() end
        end,
        EditBoxOnEscapePressed = function(box)
            local popup = box:GetParent()
            if popup and popup.Hide then popup:Hide() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopupDialogs[DELETE_POPUP] = {
        text = "Delete the set of weights \"%s\"?",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(_, name) ns.DeleteProfile(name) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
    StaticPopupDialogs[SPEC_POPUP] = {
        text = "Replace the weights in \"%s\" with the %s defaults? Your goals stay.",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(_, spec) ns.ApplySpec(spec) end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function UI.AskNew()
    EnsurePopups()
    if type(StaticPopup_Show) == "function" and type(StaticPopupDialogs) == "table" and StaticPopupDialogs[NEW_POPUP] then
        StaticPopup_Show(NEW_POPUP)
    else
        ns.Print("This game version has no name box here.")
    end
end

function UI.AskDelete()
    EnsurePopups()
    local name = ns.char.profile
    if type(StaticPopup_Show) == "function" and type(StaticPopupDialogs) == "table" and StaticPopupDialogs[DELETE_POPUP] then
        StaticPopup_Show(DELETE_POPUP, name, nil, name)
    else
        ns.DeleteProfile(name)
    end
end

---------------------------------------------------------------------------
-- The plan tab
---------------------------------------------------------------------------
local function ItemLink(id)
    local _, link = ns.Call(C_Item and C_Item.GetItemInfo or GetItemInfo, id)
    return type(link) == "string" and link or nil
end

local function ItemIcon(id)
    local icon = ns.Call(C_Item and C_Item.GetItemIconByID or GetItemIcon, id)
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function RowEnter(self)
    local data = self.data
    if not (data and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local shown = false
    if type(GameTooltip.SetItemByID) == "function" then shown = pcall(GameTooltip.SetItemByID, GameTooltip, data.id) end
    if not shown and type(GameTooltip.SetHyperlink) == "function" then
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. data.id)
    end
    local item = ns.Item(data.id)
    if not shown and item then GameTooltip:SetText(item.name, QualityColor(item.quality)) end
    local source = item and ns.SourceText(item)
    if source then
        local gr, gg, gb = Color(NORMAL_FONT_COLOR, 1, 0.82, 0)
        local wr, wg, wb = Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Source", source, gr, gg, gb, wr, wg, wb)
    end
    if item and item.special then
        GameTooltip:AddLine("Its special effect is not counted.", Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
    end
    if data.alts and #data.alts > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Next best", Color(NORMAL_FONT_COLOR, 1, 0.82, 0))
        for _, alt in ipairs(data.alts) do
            local other = ns.Item(alt.id)
            if other then
                local r, g, b = QualityColor(other.quality)
                local wr, wg, wb = Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
                GameTooltip:AddDoubleLine(other.name, ns.Number(math.floor(alt.diff * 10 + 0.5) / 10), r, g, b, wr, wg, wb)
                local from = ns.SourceText(other)
                if from then GameTooltip:AddLine("    " .. from, Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5)) end
            end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Right-click: leave this item out of the plan", Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
    GameTooltip:AddLine("Shift-click: link it in chat", Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
    GameTooltip:Show()
end

local function RowClick(self, button)
    local data = self.data
    if not data then return end
    local item = ns.Item(data.id)
    if button == "RightButton" then
        Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        HideTip()
        ns.Exclude(data.id, true)
        ns.Print(("%s is left out. /bisplan unhide brings every left-out item back."):format(item and item.name or "It"))
    elseif type(IsModifiedClick) == "function" and ns.Call(IsModifiedClick, "CHATLINK") == true then
        local link = ItemLink(data.id)
        if not link then
            ns.Print("The game is still loading that item. Try again in a moment.")
        elseif ChatFrameUtil and type(ChatFrameUtil.InsertLink) == "function" then
            pcall(ChatFrameUtil.InsertLink, link)
        elseif type(ChatEdit_InsertLink) == "function" then
            pcall(ChatEdit_InsertLink, link)
        end
    end
end

local function PlanRow(i)
    local row = planRows[i]
    if row then return row end
    local content = frame.planContent
    row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)
    if row.RegisterForClicks then row:RegisterForClicks("LeftButtonUp", "RightButtonUp") end

    local slot = FromTemplate("ItemButton", row)
    if slot and slot.EnableMouse then
        slot:SetPoint("LEFT", row, "LEFT", 2, 0)
        slot:EnableMouse(false)
        row.slotButton = slot
    else
        if slot then slot:Hide() end
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(37, 37)
        row.icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    end

    row.where = Text(row, "GameFontNormalSmall")
    row.where:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -7)
    row.where:SetJustifyH("RIGHT")
    row.name = Text(row, "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 46, -6)
    row.name:SetPoint("RIGHT", row.where, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end
    row.detail = Text(row, "GameFontHighlightSmall")
    row.detail:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.detail:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.detail:SetJustifyH("LEFT")
    if row.detail.SetWordWrap then row.detail:SetWordWrap(false) end

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(ROW_HIGHLIGHT)
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(row)

    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", HideTip)
    row:SetScript("OnClick", RowClick)
    planRows[i] = row
    return row
end

local function FillPlan(plan, why)
    local shown = 0
    for i, data in ipairs(plan and plan.rows or {}) do
        local item = ns.Item(data.id)
        if item then
            shown = shown + 1
            local row = PlanRow(shown)
            row.data = data
            local icon = ItemIcon(item.id)
            if row.slotButton then
                if type(SetItemButtonTexture) == "function" then pcall(SetItemButtonTexture, row.slotButton, icon) end
                if type(SetItemButtonQuality) == "function" then pcall(SetItemButtonQuality, row.slotButton, item.quality, item.id) end
            else
                row.icon:SetTexture(icon)
            end
            row.name:SetText(item.name)
            row.name:SetTextColor(QualityColor(item.quality))
            row.where:SetText(data.twoHand and "Two-hand" or data.slot)
            local owned = ns.Owned(item.id)
            local source = ns.SourceText(item)
            local level = (item.guess and "Around level %d" or "Level %d"):format(item.level)
            if owned == "equipped" then
                row.detail:SetText("You wear it")
                row.detail:SetTextColor(Color(GREEN_FONT_COLOR, 0.1, 1, 0.1))
            elseif owned then
                row.detail:SetText("You have it")
                row.detail:SetTextColor(Color(GREEN_FONT_COLOR, 0.1, 1, 0.1))
            else
                row.detail:SetText(source and (level .. ". " .. source) or level)
                row.detail:SetTextColor(Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
            end
            row:Show()
        end
    end
    for i = shown + 1, #planRows do planRows[i]:Hide() end
    frame.planContent:SetHeight(math.max(10, shown * ROW_H))
    frame.empty:SetText(why or "")
    frame.empty:SetShown(shown == 0)
end

local function BuildPlan(page)
    frame.planList, frame.planContent = Scroll(page, 4)
    frame.empty = Text(page, "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", page, "TOPLEFT", 40, -70)
    frame.empty:SetPoint("TOPRIGHT", page, "TOPRIGHT", -40, -70)
    frame.empty:SetJustifyH("CENTER")
end

---------------------------------------------------------------------------
-- The weights tab
---------------------------------------------------------------------------
local function Commit(box)
    local value = UI.ParseNumber(box:GetText())
    if value == false then
        ns.Print(("\"%s\" is not a number."):format(tostring(box:GetText())))
        value = ns.Profile()[box.kind][box.key]
    end
    ns.SetStat(box.kind, box.key, value)
    local now = ns.Profile()[box.kind][box.key]
    box:SetText(now and ns.Number(now) or "")
end

local function StatBox(row, kind, key, x)
    local box = InputBox(row, 54)
    box:SetPoint("RIGHT", row, "RIGHT", x, 0)
    box.kind, box.key = kind, key
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self)
        local now = ns.Profile()[self.kind][self.key]
        self:SetText(now and ns.Number(now) or "")
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusLost", Commit)
    box:SetScript("OnTabPressed", function(self)
        local back = type(IsShiftKeyDown) == "function" and ns.Call(IsShiftKeyDown) == true
        local nextBox = statBoxes[self.index + (back and -1 or 1)]
        if nextBox then nextBox:SetFocus() else self:ClearFocus() end
    end)
    statBoxes[#statBoxes + 1] = box
    box.index = #statBoxes
    return box
end

-- The spec defaults menu: your class's specs; one fills the set in use with its weights.
function UI.PickSpec(spec)
    local profile = ns.Profile()
    if not next(profile.weights) then
        ns.ApplySpec(spec)
        return
    end
    EnsurePopups()
    if type(StaticPopup_Show) == "function" and type(StaticPopupDialogs) == "table" and StaticPopupDialogs[SPEC_POPUP] then
        StaticPopup_Show(SPEC_POPUP, ns.char.profile, spec.name, spec)
    else
        ns.ApplySpec(spec)
    end
end

local function SpecTip(tooltip, spec)
    if type(tooltip) ~= "table" or type(tooltip.SetText) ~= "function" then return end
    tooltip:SetText(spec.name, Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
    tooltip:AddLine(spec.cap, 1, 0.82, 0, true)
    tooltip:AddLine("Weights from " .. spec.source .. ".", Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
end

local function BuildSpecs(page)
    local dd = FromTemplate("DropdownButton", page, "WowStyle1DropdownTemplate")
    if dd and type(dd.SetupMenu) == "function" then
        dd:SetWidth(150)
        dd:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -4)
        if type(dd.SetDefaultText) == "function" then dd:SetDefaultText("Spec defaults") end
        dd:SetupMenu(function(_, root)
            if type(root.CreateTitle) == "function" then root:CreateTitle("Fill the weights for") end
            for _, spec in ipairs(ns.Specs()) do
                local button = root:CreateButton(spec.name, function() UI.PickSpec(spec) end)
                if type(button) == "table" and type(button.SetTooltip) == "function" then
                    button:SetTooltip(function(tooltip) SpecTip(tooltip, spec) end)
                end
            end
        end)
    else
        if dd then dd:Hide() end
        dd = Button(page, "Spec defaults", 110)
        dd:SetPoint("TOPLEFT", page, "TOPLEFT", 10, -4)
        dd:SetScript("OnClick", function() ns.ListSpecs() end)
    end
    OnHover(dd, "Spec defaults", "Fills the weights of the set in use with your spec's. Its goals stay.",
        "From sixtysim.com's Forever simulations (17 November 2026); the tanks' are estimates.")
    frame.specs = dd
end

local function BuildWeights(page)
    local weightCap = Text(page, "GameFontNormalSmall")
    weightCap:SetPoint("TOPRIGHT", page, "TOPRIGHT", -102, -8)
    weightCap:SetWidth(60)
    weightCap:SetJustifyH("CENTER")
    weightCap:SetText("Weight")
    local goalCap = Text(page, "GameFontNormalSmall")
    goalCap:SetPoint("TOPRIGHT", page, "TOPRIGHT", -36, -8)
    goalCap:SetWidth(60)
    goalCap:SetJustifyH("CENTER")
    goalCap:SetText("At least")
    BuildSpecs(page)

    local list, content = Scroll(page, 30)
    frame.statList, frame.statContent = list, content
    local hint = Text(content, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -4)
    hint:SetPoint("TOPRIGHT", content, "TOPRIGHT", -6, -4)
    hint:SetJustifyH("LEFT")
    hint:SetText("Weight: points per stat point. At least: the least you want from gear.")
    local y = 12
    for _, group in ipairs(ns.STAT_GROUPS) do
        local head = Text(content, "GameFontNormal")
        head:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -y - 8)
        head:SetText(group[1])
        y = y + STAT_H + 2
        for _, stat in ipairs(group[2]) do
            local row = CreateFrame("Frame", nil, content)
            row:SetHeight(STAT_H)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            local label = Text(row, "GameFontHighlight")
            label:SetPoint("LEFT", row, "LEFT", 16, 0)
            label:SetText(stat[2])
            StatBox(row, "weights", stat[1], -72)
            StatBox(row, "goals", stat[1], -6)
            y = y + STAT_H
        end
    end
    content:SetHeight(y + 8)
end

local function FillWeights()
    local profile = ns.Profile()
    for _, box in ipairs(statBoxes) do
        if not Focused(box) then
            local now = profile[box.kind][box.key]
            box:SetText(now and ns.Number(now) or "")
        end
    end
end

---------------------------------------------------------------------------
-- Above the tabs' pages: the set of weights and the level
---------------------------------------------------------------------------
local function SyncProfile()
    local dd = frame.profile
    if not dd then return end
    if dd.isMenu then
        if type(dd.GenerateMenu) == "function" then pcall(dd.GenerateMenu, dd) end
    else
        dd:SetText(ns.char.profile)
    end
end

local function BuildHeader(host)
    local label = Text(host, "GameFontNormal")
    label:SetPoint("TOPLEFT", host, "TOPLEFT", 12, -11)
    label:SetText("Weights")

    local dd = FromTemplate("DropdownButton", host, "WowStyle1DropdownTemplate")
    if dd and type(dd.SetupMenu) == "function" then
        dd.isMenu = true
        dd:SetWidth(130)
        dd:SetPoint("LEFT", label, "RIGHT", 8, 0)
        dd:SetupMenu(function(_, root)
            for _, name in ipairs(ns.ProfileNames()) do
                root:CreateRadio(name,
                    function() return ns.char.profile == name end,
                    function() ns.SetProfile(name) end,
                    name)
            end
        end)
    else
        if dd then dd:Hide() end
        -- without the game's dropdown: a button that steps through the sets
        dd = Button(host, "", 130)
        dd:SetPoint("LEFT", label, "RIGHT", 8, 0)
        dd:SetScript("OnClick", function()
            local names = ns.ProfileNames()
            for i, name in ipairs(names) do
                if name == ns.char.profile then
                    ns.SetProfile(names[i % #names + 1])
                    break
                end
            end
        end)
    end
    frame.profile = dd

    local new = Button(host, "New", 50)
    new:SetPoint("LEFT", dd, "RIGHT", 6, 0)
    new:SetScript("OnClick", UI.AskNew)
    OnHover(new, "New set of weights", "A copy of the one in use, under a name you give it. "
        .. "Keep one per role: tanking, healing, leveling.")
    local delete = Button(host, "Delete", 56)
    delete:SetPoint("LEFT", new, "RIGHT", 0, 0)
    delete:SetScript("OnClick", UI.AskDelete)
    OnHover(delete, "Delete this set of weights", "The last set is emptied instead.")

    local level = InputBox(host, 34)
    level:SetPoint("TOPRIGHT", host, "TOPRIGHT", -12, -7)
    if level.SetNumeric then level:SetNumeric(true) end
    if level.SetMaxLetters then level:SetMaxLetters(3) end
    level:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    level:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(ns.PlanLevel()))
        self:ClearFocus()
    end)
    level:SetScript("OnEditFocusLost", function(self)
        ns.SetLevel(tonumber(self:GetText()))
        self:SetText(tostring(ns.PlanLevel()))
    end)
    OnHover(level, "Level to plan for", "Only gear you can wear at this level is used.",
        "Empty: your own level, and the plan follows you as you level.")
    frame.level = level
    local levelLabel = Text(host, "GameFontNormal")
    levelLabel:SetPoint("RIGHT", level, "LEFT", -10, 0)
    levelLabel:SetText("Level")
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function SelectTab(i)
    frame.tab = i
    for k, page in ipairs(frame.pages) do
        if k == i then page:Show() else page:Hide() end
    end
    if type(PanelTemplates_SetTab) == "function" and frame.numTabs then pcall(PanelTemplates_SetTab, frame, i) end
end
UI.SelectTab = function(i)
    if frame then
        SelectTab(i)
        UI.Refresh()
    end
end

local function StatusTip(self)
    local plan = frame.shownPlan
    if not plan then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(ns.Summary(plan), Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
    for _, goal in ipairs(plan.goals) do
        local r, g, b = Color(goal.met and GREEN_FONT_COLOR or RED_FONT_COLOR, goal.met and 0.1 or 1, goal.met and 1 or 0.1, 0.1)
        GameTooltip:AddDoubleLine((ns.STAT_NAME[goal.key] or goal.key) .. ", at least " .. ns.Number(goal.want),
            ns.Number(goal.have), 1, 0.82, 0, r, g, b)
    end
    local keys = {}
    for key in pairs(plan.totals) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return (ns.STAT_NAME[a] or a) < (ns.STAT_NAME[b] or b) end)
    if #keys > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("From this gear", 1, 0.82, 0)
        for _, key in ipairs(keys) do
            GameTooltip:AddDoubleLine(ns.STAT_NAME[key] or key, ns.Number(math.floor(plan.totals[key] * 10 + 0.5) / 10),
                1, 1, 1, 1, 1, 1)
        end
    end
    local out = ns.ExcludedCount()
    if out > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("%d %s left out. /bisplan unhide brings them back."):format(out, out == 1 and "item is" or "items are"),
            Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
    end
    GameTooltip:Show()
end

local function Build()
    if frame then return frame end
    local f = FromTemplate("Frame", UIParent, "ButtonFrameTemplate", "BisPlannerFrame")
    local portrait = f ~= nil
    f = f or FromTemplate("Frame", UIParent, "BasicFrameTemplateWithInset", "BisPlannerFrame")
        or CreateFrame("Frame", "BisPlannerFrame", UIParent)
    frame = f
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    if f.SetToplevel then f:SetToplevel(true) end
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if type(f.SetTitle) == "function" then
        pcall(f.SetTitle, f, ns.NAME)
    elseif Has(f, "TitleText") then
        f.TitleText:SetText(ns.NAME)
    end
    if portrait and type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, ns.ICON) end
    if not Has(f, "CloseButton") then
        local close = FromTemplate("Button", f, "UIPanelCloseButton")
        if close then
            close:SetPoint("TOPRIGHT", 0, 0)
            close:SetScript("OnClick", function() f:Hide() end)
        end
    end

    local inset = Has(f, "Inset") and f.Inset or nil
    if not inset then
        inset = CreateFrame("Frame", nil, f)
        inset:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -60)
        inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 26)
    end
    f.host = inset
    BuildHeader(inset)

    f.pages = {}
    for i = 1, 2 do
        local page = CreateFrame("Frame", nil, inset)
        page:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, -HEADER_H)
        page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
        f.pages[i] = page
    end
    BuildPlan(f.pages[1])
    BuildWeights(f.pages[2])

    f.tabs = {}
    for i, label in ipairs({ "Plan", "Weights and goals" }) do
        local t = FromTemplate("Button", f, "PanelTopTabButtonTemplate", "BisPlannerFrameTab" .. i)
            or Button(f, label, 130)
        t:SetID(i)
        t:SetText(label)
        if i == 1 then t:SetPoint("TOPLEFT", f, "TOPLEFT", 51, -28) else t:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", 0, 0) end
        t:SetScript("OnClick", function()
            UI.SelectTab(i)
            Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end)
        f.tabs[i] = t
    end
    if type(PanelTemplates_SetNumTabs) == "function" then pcall(PanelTemplates_SetNumTabs, f, #f.tabs) end

    local options = Button(f, "Options")
    options:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    options:SetScript("OnClick", function()
        if ns.Kit then ns.Kit.Open() end
    end)
    OnHover(options, "Options", "Which gear the plan may use: quality, crafted, PvP and reputation gear, weapon kinds.")

    f.print = Button(f, "To chat")
    f.print:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
    f.print:SetScript("OnClick", function() ns.Report() end)
    OnHover(f.print, "Print the plan", "Lists the plan in your chat window, where only you see it. Same as /bisplan print.")

    f.status = Text(f, "GameFontHighlightSmall")
    f.status:SetPoint("LEFT", options, "RIGHT", 8, 0)
    f.status:SetPoint("RIGHT", f.print, "LEFT", -8, 0)
    f.status:SetJustifyH("CENTER")
    local statusHover = CreateFrame("Frame", nil, f)
    statusHover:SetAllPoints(f.status)
    statusHover:SetScript("OnEnter", StatusTip)
    statusHover:SetScript("OnLeave", HideTip)

    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "BisPlannerFrame") end
    f:Hide()
    -- After the first Hide: OnHide runs on it otherwise.
    f:SetScript("OnShow", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        UI.Refresh()
    end)
    f:SetScript("OnHide", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        HideTip()
    end)
    SelectTab(1)
    return f
end

---------------------------------------------------------------------------
-- Refreshing and opening
---------------------------------------------------------------------------
-- waiting: a setting just changed and the new plan comes in a moment; don't plan here.
function UI.Refresh(waiting)
    if not (frame and ns.db and frame:IsShown()) then return end
    SyncProfile()
    if not Focused(frame.level) then frame.level:SetText(tostring(ns.PlanLevel())) end
    FillWeights()
    if waiting then
        frame.status:SetText("Planning...")
        return
    end
    local plan, why = ns.Plan()
    frame.shownPlan = plan
    FillPlan(plan, why)
    if plan then
        frame.status:SetText(ns.Summary(plan))
        local c = plan.feasible and HIGHLIGHT_FONT_COLOR or RED_FONT_COLOR
        frame.status:SetTextColor(Color(c, 1, 1, 1))
    else
        frame.status:SetText("")
    end
end

function UI.Toggle()
    if not ns.db then return end
    local f = Build()
    if f:IsShown() then
        f:Hide()
    else
        -- nothing set yet: start where the weights are typed
        local profile = ns.Profile()
        if not (next(profile.weights) or next(profile.goals)) then SelectTab(2) end
        f:Show()
    end
end

function UI.Shown()
    return frame ~= nil and frame:IsShown()
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["BisPlanner"] = {
    version = ns.VERSION,
    frames = {
        { label = "planner window", frame = function() return frame and frame:IsShown() and frame or nil end },
    },
}
