-- Turn-in Route: the window (numbered legs, their quests, the lists under the route)
--
-- A leg is a quest log header (ListHeaderVisualTemplate, Blizzard_SharedXML/ListTemplates.xml, the
-- visual half of QuestLogHeaderTemplate) without its collapse button; its quests are the quest
-- log's own quest row (QuestLogTitleTemplate and QuestLogQuests_AddQuestButton in
-- Blizzard_UIPanels_Game/Mainline/QuestMapFrame.xml/.lua): the title in its difficulty colour at
-- 31,-8, a tag on the right, an objective-style line under it, the quest log's yellow glow under
-- the mouse, and the quest log's right-click menu (Super Track / Stop Super Tracking).
local _, ns = ...
local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 460, 480
local NAME = "Turn-in Route"
local ATTIC = 88            -- the window's strip beside the portrait, for the summary (FrameTemplate_SetAtticHeight)
local BUTTON_BAR = 26       -- PANEL_INSET_BOTTOM_OFFSET with a button bar

-- QuestLogTitleTemplate and QuestLogQuests_AddQuestButton.
local TEXT_LEFT, TEXT_TOP = 31, 8
local TEXT_RIGHT = 18
local ROW_LEFT = 4
local OBJECTIVE_GAP, ROW_EXTRA = 3, 6
local FALLBACK_LINE = 12
-- QuestLogHeaderTemplate: 22 high, its text 8 in from the left.
local HEADER_HEIGHT, HEADER_GAP = 22, 4

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function Color(name, r, g, b) return ns.GameColor(name, r, g, b) end
local function Gold() return Color("NORMAL_FONT_COLOR", 1, 0.82, 0) end
local function White() return Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1) end
local function Green() return Color("GREEN_FONT_COLOR", 0.1, 1, 0.1) end
local function Red() return Color("RED_FONT_COLOR", 1, 0.125, 0.125) end

local function Text(name, fallback)
    local value = _G[name]
    if type(value) == "string" and value ~= "" then return value end
    return fallback
end

local function HasAtlas(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    return type((ns.Call(C_Texture.GetAtlasInfo, atlas))) == "table"
end
UI.HasAtlas = HasAtlas

local function TitleColors(data)
    if GetDifficultyColor and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer then
        local difficulty = ns.Call(C_PlayerInfo.GetContentDifficultyQuestForPlayer, data.id)
        if difficulty ~= nil then
            local color, highlight = ns.Call(GetDifficultyColor, difficulty)
            if type(color) == "table" and type(color.r) == "number" then
                if not (type(highlight) == "table" and type(highlight.r) == "number") then highlight = color end
                return color, highlight
            end
        end
    end
    if data.level and not data.scaling and GetQuestDifficultyColor then
        local color = ns.Call(GetQuestDifficultyColor, data.level)
        if type(color) == "table" and color.r then return color, color end
    end
    local r, g, b = Gold()
    local color = { r = r, g = g, b = b }
    return color, color
end

local function ObjectiveColor(highlighted)
    if highlighted then return Color("QUEST_OBJECTIVE_HIGHLIGHT_FONT_COLOR", 1, 1, 1) end
    return Color("QUEST_OBJECTIVE_FONT_COLOR", 0.8, 0.8, 0.8)
end

local function MoneyText(copper)
    if GetCoinTextureString then
        local text = ns.Str(ns.Call(GetCoinTextureString, copper))
        if text then return text end
    end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function OpenInQuestLog(data)
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("The quest log can't be opened from here in combat.")
        return
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then pcall(C_QuestLog.SetSelectedQuest, data.id) end
    if QuestMapFrame_OpenToQuestDetails then
        pcall(QuestMapFrame_OpenToQuestDetails, data.id)
    elseif QuestLogFrame and ShowUIPanel then
        pcall(ShowUIPanel, QuestLogFrame)
        if QuestLog_SetSelection and data.index then pcall(QuestLog_SetSelection, data.index) end
        if QuestLog_Update then pcall(QuestLog_Update) end
    end
end

----------------------------------------------------------------------
-- Right-click menu: the quest log's own pair (SUPER_TRACK_QUEST / STOP_SUPER_TRACK_QUEST).
-- Tracking a quest on the route also follows the route from there.
----------------------------------------------------------------------
local function OpenMenu(owner, data)
    if not ns.CanTrack() then return end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ns.Track(not ns.IsTracked(data.id) and data.id or nil)
        return
    end
    pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
        if ns.IsTracked(data.id) then
            root:CreateButton(Text("STOP_SUPER_TRACK_QUEST", "Stop Super Tracking"), function() ns.Track(nil) end)
        else
            root:CreateButton(Text("SUPER_TRACK_QUEST", "Super Track"), function() ns.Track(data.id) end)
        end
    end)
end

----------------------------------------------------------------------
-- Tooltips, laid out like the quest log's (QuestMapLogTitleButton_OnEnter)
----------------------------------------------------------------------
local function PlaceTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local right, screen = ns.Num(owner:GetRight()), UIParent and ns.Num(UIParent:GetRight())
    if right and screen and right + 34 + 251 > screen then
        GameTooltip:SetPoint("TOPRIGHT", owner, "TOPLEFT", -5, 0)
    else
        GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 34, 0)
    end
end

local function SourceText(source)
    if source == "Questie" then return "Questie" end
    return "the game's quest marker"
end

local function ShowRowTooltip(self)
    local data = self.data
    if not data or not GameTooltip then return end
    local quest = data.quest
    PlaceTooltip(self)
    GameTooltip:SetText(data.title)
    local wr, wg, wb = White()
    local gr, gg, gb = Gold()
    GameTooltip:AddLine(Text("QUEST_WATCH_QUEST_READY", "Ready for turn-in"), wr, wg, wb, true)
    if data.leg then
        GameTooltip:AddLine(("Leg %d: %s."):format(data.leg.number, data.leg.text), wr, wg, wb, true)
        if ns.following and ns.following == data.id then
            GameTooltip:AddLine("Super tracked: handing it in moves the arrow to the next stop.", wr, wg, wb, true)
        end
    elseif data.section == "inside" then
        GameTooltip:AddLine(("Not on the route: it is handed in inside %s, where the route cannot lead."):format(
            quest.turnIn.instance), wr, wg, wb, true)
    else
        GameTooltip:AddLine("Not on the route: neither the game nor Questie says where it is handed in.", wr, wg, wb, true)
    end
    GameTooltip:AddLine(" ")
    local function Fact(label, value) GameTooltip:AddDoubleLine(label, value, gr, gg, gb, wr, wg, wb) end
    local turnIn = quest.turnIn
    if turnIn and turnIn.npc then Fact("Hand in to", turnIn.npc) end
    if turnIn and turnIn.instance then
        Fact("Hand in inside", turnIn.instance)
    elseif turnIn and turnIn.zone then
        Fact("Hand in at", turnIn.zone)
    elseif quest.zone then
        Fact("Zone", quest.zone)
    end
    if turnIn then Fact("Place from", SourceText(turnIn.source)) end
    if quest.level then Fact("Level", tostring(quest.level)) end
    if quest.tagName then Fact("Type", quest.tagName) end
    if quest.xp and quest.xp > 0 then Fact("XP", tostring(quest.xp)) end
    if quest.money and quest.money > 0 then Fact("Money", MoneyText(quest.money)) end
    GameTooltip:AddLine(" ")
    local hr, hg, hb = Green()
    GameTooltip:AddLine("<Click to show it in the quest log>", hr, hg, hb)
    if ns.CanTrack() then GameTooltip:AddLine("<Right-click to super track it>", hr, hg, hb) end
    GameTooltip:Show()
end

local function ShowHeaderTooltip(self)
    local data = self.data
    if not data or not GameTooltip then return end
    PlaceTooltip(self)
    local wr, wg, wb = White()
    local gr, gg, gb = Gold()
    local leg = data.leg
    if not leg then
        GameTooltip:SetText(data.title)
        GameTooltip:AddLine(data.tip, wr, wg, wb, true)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetText(("%d. %s"):format(leg.number, leg.text))
    local function Fact(label, value) GameTooltip:AddDoubleLine(label, value, gr, gg, gb, wr, wg, wb) end
    Fact("Where", leg.zone and leg.label ~= leg.zone and (leg.label .. ", " .. leg.zone) or leg.label)
    Fact("Turn-ins", tostring(#leg.quests))
    if leg.how == "start" then
        Fact("Getting there", "unknown (your position is hidden here)")
    else
        Fact("Getting there", ns.Duration(leg.travel))
    end
    Fact("Between the stops", ns.Duration(leg.inside))
    if leg.noWay then
        local rr, rg, rb = Red()
        GameTooltip:AddLine("No known way there yet: open the flight master's map at the flight paths you pass, "
            .. "or turn the boats back on.", rr, rg, rb, true)
    end
    GameTooltip:AddLine(" ")
    local hr, hg, hb = Green()
    if ns.CanTrack() then
        GameTooltip:AddLine("<Click to super track this leg and follow the route from here>", hr, hg, hb, true)
    end
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- Lists. A list is one column of legs and quests; the window has one and the
-- quest log panel has another.
----------------------------------------------------------------------
function UI.NewList(content)
    return { content = content, rows = {}, headers = {} }
end

local function SetRowColors(row, highlighted)
    local color, highlight = TitleColors(row.data)
    local c = highlighted and highlight or color
    row.title:SetTextColor(c.r, c.g, c.b)
    row.tag:SetTextColor(c.r, c.g, c.b)
    row.why:SetTextColor(ObjectiveColor(highlighted))
end

local function RowEnter(self)
    if not self.data then return end
    SetRowColors(self, true)
    self.hl:Show()
    ShowRowTooltip(self)
end

local function RowLeave(self)
    if self.data then SetRowColors(self, false) end
    self.hl:Hide()
    if GameTooltip then GameTooltip:Hide() end
end

local function RowClick(self, button)
    local data = self.data
    if not data then return end
    if button == "RightButton" then OpenMenu(self, data) else OpenInQuestLog(data) end
end

local function CreateRow(list)
    local row = CreateFrame("Button", nil, list.content)
    row.isTurnInRouteRow = true           -- so LookShots can tell our row tooltip from others
    row:SetHeight(TEXT_TOP + 2 * FALLBACK_LINE + OBJECTIVE_GAP + ROW_EXTRA)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
    row.title:SetJustifyH("LEFT")
    row.tag = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
    row.tag:SetPoint("TOPRIGHT", row, "TOPRIGHT", -TEXT_RIGHT, -TEXT_TOP)
    row.why = row:CreateFontString(nil, "ARTWORK", _G.ObjectiveFont and "ObjectiveFont" or "GameFontHighlightSmall")
    row.why:SetJustifyH("LEFT")
    row.hl = row:CreateTexture(nil, "BORDER")
    if HasAtlas("questlog-quest-glow-yellow") then
        row.hl:SetAtlas("questlog-quest-glow-yellow", true)
        row.hl:SetPoint("TOP", row.title, "TOP", 0, 4)
        row.hl:SetPoint("BOTTOM", row.title, "BOTTOM", 0, -4)
    else
        row.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.hl:SetBlendMode("ADD")
        row.hl:SetAllPoints(row)
    end
    row.hl:Hide()
    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    return row
end

local function LineHeight(fontString)
    local height = ns.Num(fontString:GetStringHeight())
    if not height or height < 6 then return FALLBACK_LINE end
    return height
end

local function LineFor(data)
    local quest = data.quest
    if data.section == "inside" then
        local npc = quest.turnIn.npc
        return npc and (quest.turnIn.instance .. ": " .. npc) or quest.turnIn.instance
    elseif data.section == "unknown" then
        return quest.zone and (quest.zone .. ": turn-in place unknown") or "Turn-in place unknown"
    end
    local turnIn = quest.turnIn
    if turnIn and turnIn.npc then return turnIn.npc end
    return (turnIn and turnIn.zone) or Text("QUEST_WATCH_QUEST_READY", "Ready for turn-in")
end

local function FillRow(row, data)
    row.data = data
    -- The right-hand tag: "Tracked" while the arrow points at it, else the quest's kind
    -- ("Dungeon", "Group", "Elite"), the way the quest log tags its rows.
    local tag = ns.IsTracked(data.id) and "Tracked" or data.quest.tagName
    row.tag:SetText(tag or "")
    row.tag:SetShown(tag ~= nil)
    row.title:ClearAllPoints()
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_LEFT, -TEXT_TOP)
    if tag then
        row.title:SetPoint("TOPRIGHT", row.tag, "TOPLEFT", -4, 0)
    else
        row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -TEXT_RIGHT, -TEXT_TOP)
    end
    row.title:SetText(data.title)
    local titleHeight = LineHeight(row.title)
    local y = TEXT_TOP + titleHeight + OBJECTIVE_GAP
    row.why:ClearAllPoints()
    row.why:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_LEFT, -y)
    row.why:SetPoint("TOPRIGHT", row, "TOPRIGHT", -TEXT_RIGHT, -y)
    local line = LineFor(data)
    row.why:SetText(line)
    local height = TEXT_TOP + titleHeight + ROW_EXTRA
    if line ~= "" then height = height + OBJECTIVE_GAP + LineHeight(row.why) end
    SetRowColors(row, false)
    row.hl:Hide()
    row:SetHeight(height)
    row:Show()
    return height
end

local function HeaderClick(self)
    local data = self.data
    if not (data and data.leg) then return end
    local quest = data.leg.quests[1]
    if quest and ns.CanTrack() then
        ns.Track(quest.id)
        ns.Print(("Following the route from leg %d: %s."):format(data.leg.number, data.leg.text))
    end
end

local function SetScriptOrHook(frame, script, fn)
    if frame:GetScript(script) then frame:HookScript(script, fn) else frame:SetScript(script, fn) end
end

-- ListHeaderVisualTemplate; a client without it gets a plain button in the same font.
local function CreateHeader(list)
    local ok, header = pcall(CreateFrame, "Button", nil, list.content, "ListHeaderVisualTemplate")
    if ok and type(header) == "table" then
        header.template = "ListHeaderVisualTemplate"
        local collapse = header.CollapseButton
        if type(collapse) == "table" and collapse.Hide then collapse:Hide() end
        header.text = header.ButtonText
    else
        header = CreateFrame("Button", nil, list.content)
        local hl = header:CreateTexture(nil, "HIGHLIGHT")
        hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        hl:SetBlendMode("ADD")
        hl:SetAllPoints(header)
    end
    if type(header.text) ~= "table" then
        header.text = header:CreateFontString(nil, "ARTWORK", _G.Game15Font_Shadow and "Game15Font_Shadow" or "GameFontNormal")
    end
    header.text:ClearAllPoints()
    header.text:SetPoint("LEFT", header, "LEFT", 8, 0)
    header.text:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    header.text:SetJustifyH("LEFT")
    if header.text.SetWordWrap then header.text:SetWordWrap(false) end
    header.isTurnInRouteHeader = true
    header:SetHeight(HEADER_HEIGHT)
    header:RegisterForClicks("LeftButtonUp")
    header:SetScript("OnClick", HeaderClick)
    SetScriptOrHook(header, "OnEnter", ShowHeaderTooltip)
    SetScriptOrHook(header, "OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    return header
end

-- The header line of a leg: "1. Hearth to Goldshire (3), 4 min"
function UI.LegTitle(leg)
    return ("%d. %s (%d), %s"):format(leg.number, leg.text, #leg.quests, ns.Duration(leg.seconds))
end

local INSIDE_TIP = "These are handed in inside a dungeon or raid, where the route cannot lead. Dungeon and group "
    .. "quests handed in outside are on the route like any other."
local UNKNOWN_TIP = "Neither the game nor Questie says where these are handed in. Questie, when installed, knows most of them."

-- What a list shows for a plan: { { header = {...} }, { row = {...} }, ... }
function UI.Items(plan)
    local items = {}
    local function Row(quest, leg, section)
        items[#items + 1] = { row = { id = quest.id, index = quest.index, title = quest.title, level = quest.level,
            scaling = quest.scaling, quest = quest, leg = leg, section = section } }
    end
    for _, leg in ipairs(plan.legs or {}) do
        items[#items + 1] = { header = { leg = leg, title = UI.LegTitle(leg) } }
        for _, quest in ipairs(leg.quests) do Row(quest, leg, "leg") end
    end
    if #(plan.inside or {}) > 0 then
        items[#items + 1] = { header = { title = "Hand in inside a dungeon", tip = INSIDE_TIP } }
        for _, quest in ipairs(plan.inside) do Row(quest, nil, "inside") end
    end
    if #(plan.unknown or {}) > 0 then
        items[#items + 1] = { header = { title = "Turn-in place unknown", tip = UNKNOWN_TIP } }
        for _, quest in ipairs(plan.unknown) do Row(quest, nil, "unknown") end
    end
    return items
end

-- Lays the plan out in `list`, `top` below the content's top. Returns the height used.
function UI.FillList(list, plan, top)
    top = top or 0
    local parent, y = list.content, top
    local nRows, nHeaders = 0, 0
    for _, item in ipairs(UI.Items(plan)) do
        if item.header then
            nHeaders = nHeaders + 1
            local header = list.headers[nHeaders]
            if not header then
                header = CreateHeader(list)
                list.headers[nHeaders] = header
            end
            if nHeaders > 1 then y = y + HEADER_GAP end
            header.data = item.header
            header.text:SetText(item.header.title)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_LEFT, -y)
            header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -y)
            header:Show()
            y = y + HEADER_HEIGHT
        else
            nRows = nRows + 1
            local row = list.rows[nRows]
            if not row then
                row = CreateRow(list)
                list.rows[nRows] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_LEFT, -y)
            row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
            y = y + FillRow(row, item.row)
        end
    end
    for i = nRows + 1, #list.rows do list.rows[i].data = nil; list.rows[i]:Hide() end
    for i = nHeaders + 1, #list.headers do list.headers[i].data = nil; list.headers[i]:Hide() end
    return y - top
end

function UI.IsEmpty(plan)
    return #(plan.legs or {}) + #(plan.inside or {}) + #(plan.unknown or {}) == 0
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
function UI.SavePosition()
    local point, _, relPoint, x, y = UI.frame:GetPoint()
    ns.db.point = { point, relPoint, x, y }
end

function UI.RestorePosition()
    local f, p = UI.frame, ns.db.point
    if not f then return end
    f:ClearAllPoints()
    if type(p) == "table" and p[1] then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
end

function UI.ApplyScale()
    if UI.frame then UI.frame:SetScale(ns.db.scale or 1) end
end

-- The game's framed window with a portrait (ButtonFrameTemplate, SharedUIPanelTemplates.xml).
local function NewWindow()
    for _, template in ipairs({ "ButtonFrameTemplate", "BasicFrameTemplateWithInset" }) do
        local ok, f = pcall(CreateFrame, "Frame", "TurnInRouteFrame", UIParent, template)
        if ok and type(f) == "table" then return f, template end
    end
    local f = CreateFrame("Frame", "TurnInRouteFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end
    return f, nil
end

local function Child(f, key)
    local child = f[key]
    if type(child) == "table" then return child end
end

function UI.UpdateButton()
    local f = UI.frame
    if not (f and f.follow) then return end
    f.follow:SetText(ns.following and "Stop following" or "Follow route")
    local plan = ns.result
    local can = ns.CanTrack() and (ns.following ~= nil or (plan ~= nil and #plan.legs > 0))
    if can then f.follow:Enable() else f.follow:Disable() end
end

function UI.Create()
    if UI.frame then return end
    local f, template = NewWindow()
    UI.frame = f
    f.template = template
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SavePosition()
    end)

    local summaryLeft, summaryTop, listTop, listBottom, side = 14, -30, -88, 8 + BUTTON_BAR, 8
    local titleText = Child(f, "TitleContainer") and Child(f.TitleContainer, "TitleText") or Child(f, "TitleText")
    if template == "ButtonFrameTemplate" then
        if type(f.SetTitle) == "function" then pcall(f.SetTitle, f, NAME) end
        if titleText then titleText:SetText(NAME) end
        if type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, ns.ICON) end
        summaryLeft, summaryTop, listTop, listBottom = 66, -28, -ATTIC, BUTTON_BAR
    elseif titleText then
        titleText:SetText(NAME)
    else
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOP", f, "TOP", 0, -18)
        f.title:SetText(NAME)
        summaryLeft, summaryTop, listTop, listBottom, side = 20, -40, -96, 14 + BUTTON_BAR, 14
    end
    if not Child(f, "CloseButton") then
        f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    end

    f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", summaryLeft, summaryTop)
    f.summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, summaryTop)
    f.summary:SetJustifyH("LEFT")
    f.summary:SetJustifyV("TOP")
    f.summary:SetHeight(summaryTop - listTop - 4)

    local body = Child(f, "Inset")
    if body then
        body:ClearAllPoints()
        body:SetPoint("TOPLEFT", f, "TOPLEFT", 4, listTop)
        body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, listBottom)
    else
        body = CreateFrame("Frame", nil, f)
        body:SetPoint("TOPLEFT", f, "TOPLEFT", side, listTop)
        body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -side, listBottom)
    end
    f.body = body

    local ok, scroll = pcall(CreateFrame, "ScrollFrame", "TurnInRouteScroll", body, "ScrollFrameTemplate")
    if not (ok and type(scroll) == "table") then
        scroll = CreateFrame("ScrollFrame", "TurnInRouteScroll", body, "UIPanelScrollFrameTemplate")
    end
    f.scroll = scroll
    scroll:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -24, 4)
    local bar = Child(scroll, "ScrollBar")
    if bar and bar.ClearAllPoints then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 2)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, -4)
    end

    f.content = CreateFrame("Frame", nil, scroll)
    f.content:SetSize(WIDTH - 44, 40)
    scroll:SetScrollChild(f.content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        width = ns.Num(width)
        if width and width > 100 then f.content:SetWidth(width) end
    end)
    f.list = UI.NewList(f.content)

    f.empty = f:CreateFontString(nil, "OVERLAY", _G.Game16Font and "Game16Font" or "GameFontNormalLarge")
    f.empty:SetPoint("CENTER", body, "CENTER", 0, 0)
    f.empty:SetText("No finished quests to hand in.")
    f.empty:Hide()

    -- The button bar's button (UIPanelButtonTemplate), as the game's own panels place theirs.
    f.follow = CreateFrame("Button", "TurnInRouteFollowButton", f, "UIPanelButtonTemplate")
    f.follow:SetSize(120, 22)
    f.follow:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 4)
    f.follow:SetText("Follow route")
    f.follow:SetScript("OnClick", function()
        if ns.following then
            ns.Track(nil)
            ns.Print("Stopped following the route.")
        else
            ns.NextStop()
        end
        UI.UpdateButton()
    end)

    local function OnShow() UI.Update(ns.Compute()) end
    if f:GetScript("OnShow") then f:HookScript("OnShow", OnShow) else f:SetScript("OnShow", OnShow) end
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "TurnInRouteFrame") end

    UI.ApplyScale()
    UI.RestorePosition()
    f:Hide()
end

function UI.Update(plan)
    local f = UI.frame
    if not f or not plan then return end
    f.summary:SetText(plan.error or ns.Plan.Summary(plan))
    f.content:SetHeight(math.max(40, UI.FillList(f.list, plan, 0)))
    f.empty:SetShown(UI.IsEmpty(plan) and not plan.error)
    UI.UpdateButton()
end

function UI.IsShown()
    return UI.frame ~= nil and UI.frame:IsShown()
end

function UI.AnyShown()
    return UI.IsShown() or (ns.QuestLog ~= nil and ns.QuestLog.IsShown())
end

function UI.UpdateAll(plan)
    if UI.IsShown() then UI.Update(plan) end
    if ns.QuestLog and ns.QuestLog.IsShown() then ns.QuestLog.Update(plan) end
end

function UI.Show()
    if not UI.frame then UI.Create() end
    UI.frame:Show()
end

function UI.Toggle()
    if not UI.frame then UI.Create() end
    if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
end
