-- Abandon Advisor: the window (rated quest list, right-click menu, confirm popup)
--
-- Each quest row copies the quest log's own quest row (QuestLogTitleTemplate and
-- QuestLogQuests_AddQuestButton in Blizzard_UIPanels_Game/Mainline/QuestMapFrame.xml/.lua):
-- the title in its difficulty colour at 31,-8, a tag on the right in the same colour, an
-- objective-style line under it, the quest log's yellow glow under the mouse, and a
-- right-click menu (Abandon Quest) instead of buttons on the row.
local _, ns = ...
local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 540, 440
local POPUP = "ABANDONADVISOR_CONFIRM"
local NAME = "Abandon Advisor"
local ICON = "Interface\\Icons\\INV_Misc_Book_08"
local ATTIC = 88            -- the window's strip beside the portrait, for the summary (FrameTemplate_SetAtticHeight)

-- QuestLogTitleTemplate and QuestLogQuests_AddQuestButton.
local TEXT_LEFT, TEXT_TOP = 31, 8          -- Text: TOPLEFT x=31 y=-8
local TEXT_RIGHT = 18                      -- Text/TagText right edge: Checkbox (14) + 4 from the row's right
local ROW_LEFT = 4                         -- QuestMapFrameOverrides.titleFrameLeftPadding (Camelot)
local OBJECTIVE_GAP, ROW_EXTRA = 3, 6      -- objective 3 below the text; 6 more "because of POI icon"
local FALLBACK_LINE = 12                   -- a line's height when the client can't measure it

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function Color(name, r, g, b) return ns.GameColor(name, r, g, b) end
local function Gold() return Color("NORMAL_FONT_COLOR", 1, 0.82, 0) end
local function White() return Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1) end
local function Gray() return Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5) end
local function Red() return Color("RED_FONT_COLOR", 1, 0.125, 0.125) end
local function Green() return Color("GREEN_FONT_COLOR", 0.1, 1, 0.1) end

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

local function LevelColor(row)
    if row.level and not row.scaling and GetQuestDifficultyColor then
        local color = ns.Call(GetQuestDifficultyColor, row.level)
        if type(color) == "table" and color.r then return color.r, color.g, color.b end
    end
    return Gold()
end

-- The quest log's title colours: normal and under the mouse (GetDifficultyColor).
local function TitleColors(row)
    if GetDifficultyColor and C_PlayerInfo and C_PlayerInfo.GetContentDifficultyQuestForPlayer then
        local difficulty = ns.Call(C_PlayerInfo.GetContentDifficultyQuestForPlayer, row.id)
        if difficulty ~= nil then
            local color, highlight = ns.Call(GetDifficultyColor, difficulty)
            if type(color) == "table" and type(color.r) == "number" then
                if not (type(highlight) == "table" and type(highlight.r) == "number") then highlight = color end
                return color, highlight
            end
        end
    end
    local r, g, b = LevelColor(row)
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

local function OpenInQuestLog(row)
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("The quest log can't be opened from here in combat.")
        return
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then pcall(C_QuestLog.SetSelectedQuest, row.id) end
    if QuestMapFrame_OpenToQuestDetails then
        pcall(QuestMapFrame_OpenToQuestDetails, row.id)
    elseif QuestLogFrame and ShowUIPanel then
        pcall(ShowUIPanel, QuestLogFrame)
        if QuestLog_SetSelection then pcall(QuestLog_SetSelection, row.index) end
        if QuestLog_Update then pcall(QuestLog_Update) end
    end
end

local function CanAbandon(row)
    return row.verdict ~= "turnin" and row.canAbandon ~= false
end

local function TogglePin(row)
    if row.verdict == "turnin" then return end
    local pinned = ns.ToggleKeep(row.id)
    ns.Print((pinned and "Pinned as keep: %s" or "Unpinned: %s"):format(row.title))
    UI.UpdateAll(ns.Compute())
end

----------------------------------------------------------------------
-- Confirm popup
----------------------------------------------------------------------
local function EnsurePopup()
    if not StaticPopupDialogs or StaticPopupDialogs[POPUP] then return end
    StaticPopupDialogs[POPUP] = {
        text = "%s",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function(self, data)
            data = data or (self and self.data)
            if data then ns.Abandon(data.id, data.title) end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function ConfirmAbandon(row)
    local text = ("Abandon \"%s\"?"):format(row.title)
    if row.progress and row.progress > 0 then
        text = text .. ("\n\nIt is %d%% done. Progress and its quest items are lost."):format(
            math.floor(row.progress * 100 + 0.5))
    end
    if row.itemStarted then text = text .. "\n\nIt was started by an item you may not get again." end
    EnsurePopup()
    if StaticPopup_Show and StaticPopupDialogs and StaticPopupDialogs[POPUP] then
        StaticPopup_Show(POPUP, text, nil, { id = row.id, title = row.title })
    else
        ns.Print("No confirm popup on this client; nothing was abandoned.")
    end
end

----------------------------------------------------------------------
-- Right-click menu: the game's context menu, as the quest log's own rows
-- have (QuestMapLogTitleButton_CreateContextMenu: ... "Abandon Quest").
----------------------------------------------------------------------
local function OpenMenu(owner, row)
    local pinText = row.pinned and "Unpin" or "Pin as Keep"
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        -- A client without the menu: right-click pins (or super tracks a finished quest),
        -- shift + right-click abandons (after asking).
        if row.verdict == "turnin" then
            if ns.CanTrack() then ns.Track(not ns.IsTracked(row.id) and row.id or nil) end
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            if CanAbandon(row) then ConfirmAbandon(row) end
        else
            TogglePin(row)
        end
        return
    end
    if row.verdict == "turnin" then
        -- The quest log's own pair (SUPER_TRACK_QUEST / STOP_SUPER_TRACK_QUEST); here tracking
        -- a stop also follows the route: the next stop is tracked once this one is handed in.
        if not ns.CanTrack() then return end
        pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
            if ns.IsTracked(row.id) then
                root:CreateButton(Text("STOP_SUPER_TRACK_QUEST", "Stop Super Tracking"), function() ns.Track(nil) end)
            else
                root:CreateButton(Text("SUPER_TRACK_QUEST", "Super Track"), function() ns.Track(row.id) end)
            end
        end)
        return
    end
    pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
        root:CreateButton(pinText, function() TogglePin(row) end)
        if CanAbandon(row) then
            root:CreateButton(Text("ABANDON_QUEST", "Abandon Quest"), function() ConfirmAbandon(row) end)
        end
    end)
end

----------------------------------------------------------------------
-- Row tooltip: laid out like the quest log's (QuestMapLogTitleButton_OnEnter):
-- title, the quest's state, white objectives (grey when done), green click hints.
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

local VERDICT_LABEL = { turnin = "Hand in", abandon = "Abandon", maybe = "Maybe", keep = "Keep" }

local function ShowTooltip(self)
    local row = self.data
    if not row or not GameTooltip then return end
    PlaceTooltip(self)
    GameTooltip:SetText(row.title)
    local wr, wg, wb = White()
    local gr, gg, gb = Gold()
    if row.verdict == "turnin" then
        GameTooltip:AddLine(Text("QUEST_WATCH_QUEST_READY", "Ready for turn-in"), wr, wg, wb, true)
        if row.stop and row.stops > 1 then
            GameTooltip:AddLine(("Stop %d of %d on the shortest route through your finished quests."):format(
                row.stop, row.stops), wr, wg, wb, true)
        end
        if ns.following and ns.following == row.id then
            GameTooltip:AddLine("Super tracked: handing it in tracks the next stop.", wr, wg, wb, true)
        end
    else
        local label = row.pinned and "Pinned as keep" or VERDICT_LABEL[row.verdict]
        GameTooltip:AddDoubleLine(label, ("score %d"):format(row.score), gr, gg, gb, wr, wg, wb)
        if row.pick then
            GameTooltip:AddLine("One of the first to drop to reach your free-slot target.", wr, wg, wb, true)
        end
    end
    if #row.reasons > 0 then GameTooltip:AddLine(" ") end
    for _, reason in ipairs(row.reasons) do
        if reason.pts > 0 then
            local cr, cg, cb = Red()
            GameTooltip:AddDoubleLine(reason.text, ("+%d"):format(reason.pts), wr, wg, wb, cr, cg, cb)
        elseif reason.pts < 0 then
            local cr, cg, cb = Green()
            GameTooltip:AddDoubleLine(reason.text, tostring(reason.pts), wr, wg, wb, cr, cg, cb)
        else
            GameTooltip:AddLine(reason.text, wr, wg, wb, true)
        end
    end
    GameTooltip:AddLine(" ")
    local function Fact(label, value) GameTooltip:AddDoubleLine(label, value, gr, gg, gb, wr, wg, wb) end
    if row.zone then Fact("Zone", row.zone) end
    if row.level then Fact("Level", tostring(row.level)) end
    if row.tagName then Fact("Type", row.tagName) end
    if row.xp and row.xp > 0 then
        local text = tostring(row.xp)
        if row.xpPct then text = ("%s (%.1f%% of a level)"):format(text, row.xpPct) end
        Fact("XP", text)
    end
    if row.money and row.money > 0 then Fact("Money", MoneyText(row.money)) end
    if row.turnIn and row.turnIn.zone then Fact("Hand in", row.turnIn.zone) end
    if row.stop then
        if row.leg then Fact(row.stop == 1 and "From you" or "From the stop before", ns.Score.Yards(row.leg)) end
    elseif row.distance then
        Fact("Distance", ns.Score.Yards(row.distance))
    end
    if row.drop then Fact("Drops", ns.Score.DropText(row.drop)) end
    local objectives = false
    local sr, sg, sb = Gray()
    for _, objective in ipairs(row.objectives or {}) do
        if objective.text then
            if not objectives then GameTooltip:AddLine(" "); objectives = true end
            local dash = Text("QUEST_DASH", "- ")
            if objective.done then
                GameTooltip:AddLine(dash .. objective.text, sr, sg, sb, true)
            else
                GameTooltip:AddLine(dash .. objective.text, wr, wg, wb, true)
            end
        end
    end
    GameTooltip:AddLine(" ")
    local hr, hg, hb = Green()
    GameTooltip:AddLine("<Click to show it in the quest log>", hr, hg, hb)
    if row.verdict ~= "turnin" then
        GameTooltip:AddLine("<Right-click to abandon or pin it>", hr, hg, hb)
    elseif ns.CanTrack() then
        GameTooltip:AddLine("<Right-click to super track it>", hr, hg, hb)
    end
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- Rows. A list is one column of rated quests; the window has one and the
-- quest log panel has another. Both use the quest log's row.
----------------------------------------------------------------------
function UI.NewList(content)
    return { content = content, rows = {} }
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
    ShowTooltip(self)
end

local function RowLeave(self)
    if self.data then SetRowColors(self, false) end
    self.hl:Hide()
    if GameTooltip then GameTooltip:Hide() end
end

local function RowClick(self, button)
    local row = self.data
    if not row then return end
    if button == "RightButton" then
        OpenMenu(self, row)
    else
        OpenInQuestLog(row)
    end
end

local function CreateRow(list)
    local row = CreateFrame("Button", nil, list.content)
    row.isAbandonAdvisorRow = true        -- so LookShots can tell our row tooltip from others
    row:SetHeight(TEXT_TOP + 2 * FALLBACK_LINE + OBJECTIVE_GAP + ROW_EXTRA)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
    row.title:SetJustifyH("LEFT")
    row.tag = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
    row.tag:SetPoint("TOPRIGHT", row, "TOPRIGHT", -TEXT_RIGHT, -TEXT_TOP)
    row.why = row:CreateFontString(nil, "ARTWORK", _G.ObjectiveFont and "ObjectiveFont" or "GameFontHighlightSmall")
    row.why:SetJustifyH("LEFT")

    -- The quest log's glow behind the title under the mouse (HighlightTexture, BORDER layer).
    row.hl = row:CreateTexture(nil, "BORDER")
    if HasAtlas("questlog-quest-glow-yellow") then
        row.hl:SetAtlas("questlog-quest-glow-yellow", true)
        row.hl:SetPoint("TOP", row.title, "TOP", 0, 4)
        row.hl:SetPoint("BOTTOM", row.title, "BOTTOM", 0, -4)
    else
        -- A client without that atlas: its own quest log's title highlight.
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

-- What the row's right-hand tag says: only the advice that asks something of you.
local function TagFor(data)
    if data.pinned then return "Pinned" end
    if data.pick or data.verdict == "abandon" then return "Abandon" end
end

-- What the line under the title says: for a finished quest its place on the hand-in route
-- (or the quest log's "Ready for turn-in"), otherwise the reasons.
local function LineFor(data)
    if data.verdict == "turnin" then
        if not (data.stop and data.stops > 1) then return Text("QUEST_WATCH_QUEST_READY", "Ready for turn-in") end
        local line = ("Stop %d of %d"):format(data.stop, data.stops)
        local zone = data.turnIn and data.turnIn.zone
        if zone then line = line .. ": " .. zone end
        if data.leg then line = line .. ", " .. ns.Score.Yards(data.leg) end
        return line
    end
    local why = {}
    for i = 1, math.min(3, #data.reasons) do why[#why + 1] = data.reasons[i].short end
    local line = table.concat(why, ", ")
    if data.zone and not data.sameZone then line = data.zone .. ": " .. line end
    return line
end

-- Fills the row and returns its height (QuestLogQuests_AddQuestButton's sum).
local function FillRow(row, data)
    row.data = data
    local tag = TagFor(data)
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

-- Lays the rated quests out in `list`, the first row `top` below the content's
-- top edge. Returns how tall the rows are together.
function UI.FillList(list, quests, top)
    top = top or 0
    local parent, y = list.content, top
    for i, data in ipairs(quests) do
        local row = list.rows[i]
        if not row then
            row = CreateRow(list)
            list.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", ROW_LEFT, -y)
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
        y = y + FillRow(row, data)
    end
    for i = #quests + 1, #list.rows do
        list.rows[i].data = nil
        list.rows[i]:Hide()
    end
    return y - top
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
-- A client without it gets the plainer framed window, then the game's dialog box.
local function NewWindow()
    for _, template in ipairs({ "ButtonFrameTemplate", "BasicFrameTemplateWithInset" }) do
        local ok, f = pcall(CreateFrame, "Frame", "AbandonAdvisorFrame", UIParent, template)
        if ok and type(f) == "table" then return f, template end
    end
    local f = CreateFrame("Frame", "AbandonAdvisorFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
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

    -- Title and close button: the template's own where it has them.
    -- side: the list's distance from the window's edges where there is no template inset.
    local summaryLeft, summaryTop, listTop, listBottom, side = 14, -30, -88, 8, 8
    local titleText = Child(f, "TitleContainer") and Child(f.TitleContainer, "TitleText") or Child(f, "TitleText")
    if template == "ButtonFrameTemplate" then
        if type(f.SetTitle) == "function" then pcall(f.SetTitle, f, NAME) end
        if titleText then titleText:SetText(NAME) end
        if type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, ICON) end
        -- PANEL_INSET_BOTTOM_OFFSET: the inset reaches down to 4 when there is no button bar.
        summaryLeft, summaryTop, listTop, listBottom = 66, -28, -ATTIC, 4
    elseif titleText then
        titleText:SetText(NAME)
    else
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOP", f, "TOP", 0, -18)
        f.title:SetText(NAME)
        summaryLeft, summaryTop, listTop, listBottom, side = 20, -40, -96, 14, 14
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

    -- The list sits in the template's inset, on the inset's own background.
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

    -- The game's current scroll frame and bar (as in the quest log), else the older one.
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", "AbandonAdvisorScroll", body, "ScrollFrameTemplate")
    if not (ok and type(scroll) == "table") then
        scroll = CreateFrame("ScrollFrame", "AbandonAdvisorScroll", body, "UIPanelScrollFrameTemplate")
    end
    f.scroll = scroll
    scroll:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -24, 4)
    local bar = Child(scroll, "ScrollBar")
    if bar and bar.ClearAllPoints then
        -- The quest log's own placement (scrollBarX 8, scrollBarTopY 2, scrollBarBottomY -4).
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

    -- The quest log's empty text (EmptyText: Game16Font, centred).
    f.empty = f:CreateFontString(nil, "OVERLAY", _G.Game16Font and "Game16Font" or "GameFontNormalLarge")
    f.empty:SetPoint("CENTER", body, "CENTER", 0, 0)
    f.empty:SetText(Text("QUEST_LOG_NO_QUESTS", "Your quest log is empty."))
    f.empty:Hide()

    local function OnShow() UI.Update(ns.Compute()) end
    if f:GetScript("OnShow") then f:HookScript("OnShow", OnShow) else f:SetScript("OnShow", OnShow) end
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "AbandonAdvisorFrame") end

    UI.ApplyScale()
    UI.RestorePosition()
    f:Hide()
end

function UI.Update(res)
    local f = UI.frame
    if not f or not res then return end
    f.summary:SetText(ns.Score.Summary(res))

    local quests = res.rows or {}
    f.content:SetHeight(math.max(40, UI.FillList(f.list, quests, 0)))
    if #quests == 0 and not res.error then f.empty:Show() else f.empty:Hide() end
end

function UI.IsShown()
    return UI.frame ~= nil and UI.frame:IsShown()
end

-- The window and the quest log panel show the same advice; these cover both.
function UI.AnyShown()
    return UI.IsShown() or (ns.QuestLog ~= nil and ns.QuestLog.IsShown())
end

function UI.UpdateAll(res)
    if UI.IsShown() then UI.Update(res) end
    if ns.QuestLog and ns.QuestLog.IsShown() then ns.QuestLog.Update(res) end
end

function UI.Show()
    if not UI.frame then UI.Create() end
    UI.frame:Show()
end

function UI.Toggle()
    if not UI.frame then UI.Create() end
    if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
end
