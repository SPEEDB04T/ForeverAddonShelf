-- Abandon Advisor: the window (rated quest list, abandon buttons, confirm popup)
local _, ns = ...
local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 540, 440
local ROW_H = 36           -- the window's rows: verdict and button side by side
local COMPACT_ROW_H = 40   -- the quest log's narrow rows: button under the verdict
local POPUP = "ABANDONADVISOR_CONFIRM"
local NAME = "Abandon Advisor"
local ICON = "Interface\\Icons\\INV_Misc_Book_08"
local ATTIC = 88            -- the window's strip under the title bar, beside the portrait (summary)
local BUTTON_BAR = 26       -- the window's bottom strip (hint, free-slot target)

-- Each verdict's colour is one of the game's text colours (numbers only for a client without it)
-- and its icon is the game's own: ready check marks, and the quest giver's turn-in mark.
local VERDICT = {
    turnin  = { label = "Hand in", color = { "LIGHTBLUE_FONT_COLOR", 0.53, 0.67, 1 },
                icon = "Interface\\GossipFrame\\ActiveQuestIcon" },
    abandon = { label = "Abandon", color = { "RED_FONT_COLOR", 1, 0.125, 0.125 },
                icon = "Interface\\RaidFrame\\ReadyCheck-NotReady" },
    maybe   = { label = "Maybe",   color = { "YELLOW_FONT_COLOR", 1, 1, 0 },
                icon = "Interface\\RaidFrame\\ReadyCheck-Waiting" },
    keep    = { label = "Keep",    color = { "GREEN_FONT_COLOR", 0.1, 1, 0.1 },
                icon = "Interface\\RaidFrame\\ReadyCheck-Ready" },
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function Color(name, r, g, b) return ns.GameColor(name, r, g, b) end
local function Gold() return Color("NORMAL_FONT_COLOR", 1, 0.82, 0) end
local function White() return Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1) end
local function Gray() return Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5) end
local function Red() return Color("RED_FONT_COLOR", 1, 0.125, 0.125) end
local function Green() return Color("GREEN_FONT_COLOR", 0.1, 1, 0.1) end
local function VerdictColor(v) return Color(v.color[1], v.color[2], v.color[3], v.color[4]) end

local function AtlasInfo(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    local info = ns.Call(C_Texture.GetAtlasInfo, atlas)
    if type(info) == "table" then return info end
end

-- The quest log's own parchment over the whole box, cropped rather than squashed.
-- False when the client has no such atlas.
function UI.CoverWithAtlas(texture, atlas, width, height)
    local info = AtlasInfo(atlas)
    local iw, ih = info and ns.Num(info.width), info and ns.Num(info.height)
    local left, right = info and ns.Num(info.leftTexCoord), info and ns.Num(info.rightTexCoord)
    local top, bottom = info and ns.Num(info.topTexCoord), info and ns.Num(info.bottomTexCoord)
    if not (iw and ih and left and right and top and bottom) or iw <= 0 or ih <= 0 then return false end
    texture:SetAtlas(atlas)
    if not (width and height) or width <= 0 or height <= 0 then return true end
    local box, native = width / height, iw / ih
    if native > box then
        local cut = (right - left) * (1 - box / native) / 2
        left, right = left + cut, right - cut
    else
        local cut = (bottom - top) * (1 - native / box) / 2
        top, bottom = top + cut, bottom - cut
    end
    texture:SetTexCoord(left, right, top, bottom)
    return true
end

-- A list background: the quest log's parchment, else the game's marble panel art.
function UI.LayParchment(texture, width, height)
    if UI.CoverWithAtlas(texture, "QuestLog-main-background", width, height) then return end
    texture:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
    if texture.SetHorizTile then texture:SetHorizTile(true) end
    if texture.SetVertTile then texture:SetVertTile(true) end
    texture:SetTexCoord(0, 1, 0, 1)
end
local function LevelColor(row)
    if row.level and not row.scaling and GetQuestDifficultyColor then
        local color = ns.Call(GetQuestDifficultyColor, row.level)
        if type(color) == "table" and color.r then return color.r, color.g, color.b end
    end
    return 1, 0.82, 0
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
-- Row tooltip
----------------------------------------------------------------------
local function RowEnter(self)
    local row = self.data
    if not row or not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    -- Laid out like the game's own tooltips: the quest's name in its difficulty colour, gold labels,
    -- white values, red for what counts against the quest, green for what counts for it, grey hints.
    local r, g, b = LevelColor(row)
    GameTooltip:AddLine(row.title, r, g, b)
    local v = VERDICT[row.verdict]
    local right = row.verdict == "turnin" and "" or ("score %d"):format(row.score)
    local vr, vg, vb = VerdictColor(v)
    local wr, wg, wb = White()
    GameTooltip:AddDoubleLine(v.label, right, vr, vg, vb, wr, wg, wb)
    if row.pick then
        local rr, rg, rb = Red()
        GameTooltip:AddLine("Marked: one of the first to drop to reach your free-slot target.", rr, rg, rb, true)
    end
    GameTooltip:AddLine(" ")
    for _, reason in ipairs(row.reasons) do
        if reason.pts > 0 then
            local cr, cg, cb = Red()
            GameTooltip:AddDoubleLine(reason.text, ("+%d"):format(reason.pts), cr, cg, cb, cr, cg, cb)
        elseif reason.pts < 0 then
            local cr, cg, cb = Green()
            GameTooltip:AddDoubleLine(reason.text, tostring(reason.pts), cr, cg, cb, cr, cg, cb)
        else
            GameTooltip:AddLine(reason.text, wr, wg, wb, true)
        end
    end
    GameTooltip:AddLine(" ")
    local gr, gg, gb = Gold()
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
    if row.distance then Fact("Distance", ("%d yd"):format(row.distance)) end
    if row.drop then Fact("Drops", ns.Score.DropText(row.drop)) end
    local sr, sg, sb = Gray()
    for _, objective in ipairs(row.objectives or {}) do
        if objective.text then
            if objective.done then
                GameTooltip:AddLine("- " .. objective.text, sr, sg, sb, true)
            else
                GameTooltip:AddLine("- " .. objective.text, wr, wg, wb, true)
            end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: show in quest log   Right-click: pin as keep / unpin", sr, sg, sb)
    GameTooltip:Show()
end

local function RowLeave()
    if GameTooltip then GameTooltip:Hide() end
end

local function RowClick(self, button)
    local row = self.data
    if not row then return end
    if button == "RightButton" then
        if row.verdict == "turnin" then return end
        local pinned = ns.ToggleKeep(row.id)
        ns.Print((pinned and "Pinned as keep: %s" or "Unpinned: %s"):format(row.title))
        UI.UpdateAll(ns.Compute())
    else
        OpenInQuestLog(row)
    end
end

----------------------------------------------------------------------
-- Rows. A list is one column of rated quests; the window has one and
-- the quest log panel has another (narrower, so its rows are compact).
----------------------------------------------------------------------
function UI.NewList(content, compact)
    return { content = content, rows = {}, compact = compact or false,
        rowHeight = compact and COMPACT_ROW_H or ROW_H }
end

local function CreateRow(list, index)
    local parent, compact = list.content, list.compact
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(list.rowHeight)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- The quest log's own title highlight under the mouse.
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints(row)
    row.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.hl:SetBlendMode("ADD")
    row.hl:SetAlpha(0.6)

    -- The verdict's game icon at the row's left (see VERDICT).
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)

    row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.button:SetText("Abandon")
    row.button:SetScript("OnClick", function(self)
        local data = self:GetParent().data
        if data then ConfirmAbandon(data) end
    end)

    row.verdict = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.verdict:SetJustifyH("RIGHT")
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.why = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    -- Each text is pinned by its two top corners. A top corner plus a side's
    -- middle would make the game work the height out from the anchors.
    local titleInset, whyInset
    if compact then
        row.verdict:SetWidth(84)
        row.verdict:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
        row.button:SetSize(66, 18)
        row.button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 3)
        titleInset, whyInset = 6 + 84 + 4, 4 + 66 + 4
    else
        row.button:SetSize(74, 20)
        row.button:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.verdict:SetWidth(74)
        row.verdict:SetPoint("RIGHT", row.button, "LEFT", -8, 0)
        titleInset = 4 + 74 + 8 + 74 + 6
        whyInset = titleInset
    end
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 24, -5)
    row.title:SetPoint("TOPRIGHT", row, "TOPRIGHT", -titleInset, -5)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)

    row.why:SetPoint("TOPLEFT", row, "TOPLEFT", 24, -21)
    row.why:SetPoint("TOPRIGHT", row, "TOPRIGHT", -whyInset, -21)
    row.why:SetJustifyH("LEFT")
    row.why:SetWordWrap(false)

    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    return row
end

local function FillRow(row, data)
    row.data = data
    local v = VERDICT[data.verdict]
    row.icon:SetTexture(v.icon)

    local r, g, b = LevelColor(data)
    local title = ("[%s] %s"):format(data.level and tostring(data.level) or "?", data.title)
    if data.tagName then title = title .. " (" .. data.tagName .. ")" end
    if data.pick then title = ns.ColorCode("RED_FONT_COLOR", 1, 0.125, 0.125) .. "»|r " .. title end
    row.title:SetText(title)
    row.title:SetTextColor(r, g, b)

    local why = {}
    for i = 1, math.min(3, #data.reasons) do why[#why + 1] = data.reasons[i].short end
    local line = table.concat(why, ", ")
    if data.zone and not data.sameZone then line = data.zone .. ": " .. line end
    row.why:SetText(line)

    if data.verdict == "turnin" then
        row.verdict:SetText(v.label)
    else
        row.verdict:SetText(("%s %d"):format(data.pinned and "Pinned" or v.label, data.score))
    end
    row.verdict:SetTextColor(VerdictColor(v))

    if data.verdict == "turnin" or data.canAbandon == false then
        row.button:Hide()
    else
        row.button:Show()
    end
    row:Show()
end

-- Lays the rated quests out in `list`, the first row `top` below the content's
-- top edge. Returns how tall the rows are together.
function UI.FillList(list, quests, top)
    top = top or 0
    local parent, height = list.content, list.rowHeight
    for i, data in ipairs(quests) do
        local row = list.rows[i]
        if not row then
            row = CreateRow(list, i)
            list.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(top + (i - 1) * height))
        row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(top + (i - 1) * height))
        FillRow(row, data)
    end
    for i = #quests + 1, #list.rows do
        list.rows[i].data = nil
        list.rows[i]:Hide()
    end
    return #quests * height
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

local function SetTarget(delta)
    ns.db.target = math.max(1, math.min(25, (ns.db.target or 3) + delta))
    UI.UpdateAll(ns.Compute())
end
UI.SetTarget = SetTarget

-- The game's framed window with a portrait (the one the character, spellbook and friends
-- windows use). A client without it gets the plainer framed window, then the game's dialog box.
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
    local summaryLeft, summaryTop, listTop, listBottom, side = 14, -30, -88, 34, 8
    local titleText = Child(f, "TitleContainer") and Child(f.TitleContainer, "TitleText") or Child(f, "TitleText")
    if template == "ButtonFrameTemplate" then
        if type(f.SetTitle) == "function" then pcall(f.SetTitle, f, NAME) end
        if titleText then titleText:SetText(NAME) end
        if type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, ICON) end
        summaryLeft, summaryTop, listTop, listBottom = 66, -28, -ATTIC, BUTTON_BAR
    elseif titleText then
        titleText:SetText(NAME)
    else
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.title:SetPoint("TOP", f, "TOP", 0, -18)
        f.title:SetText(NAME)
        summaryLeft, summaryTop, listTop, listBottom, side = 20, -40, -96, 40, 14
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

    -- The list sits in the template's inset (moved down to make room for the summary),
    -- on the quest log's own parchment.
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
    f.parchment = body:CreateTexture(nil, "BACKGROUND", nil, 1)
    f.parchment:SetPoint("TOPLEFT", body, "TOPLEFT", 3, -3)
    f.parchment:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -3, 3)
    UI.LayParchment(f.parchment, ns.Num(body:GetWidth()), ns.Num(body:GetHeight()))
    body:SetScript("OnSizeChanged", function(_, width, height)
        UI.LayParchment(f.parchment, ns.Num(width), ns.Num(height))
    end)

    -- Bottom strip: hint on the left, free-slot target [-] Aim for N free [+] on the right.
    local barY = math.floor((listBottom - 20) / 2 + 0.5)
    f.more = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.more:SetSize(22, 20)
    f.more:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, math.max(3, barY))
    f.more:SetText("+")
    f.more:SetScript("OnClick", function() SetTarget(1) end)

    f.targetText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.targetText:SetPoint("RIGHT", f.more, "LEFT", -6, 0)

    f.less = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.less:SetSize(22, 20)
    f.less:SetPoint("RIGHT", f.targetText, "LEFT", -6, 0)
    f.less:SetText("-")
    f.less:SetScript("OnClick", function() SetTarget(-1) end)

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.hint:SetPoint("LEFT", f, "BOTTOMLEFT", side + 4, listBottom / 2 + 1)
    f.hint:SetText("Hover a quest for the reasons. Right-click to pin it as keep.")

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
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
        bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
    end

    f.content = CreateFrame("Frame", nil, scroll)
    f.content:SetSize(WIDTH - 44, ROW_H)
    scroll:SetScrollChild(f.content)
    scroll:SetScript("OnSizeChanged", function(_, width)
        width = ns.Num(width)
        if width and width > 100 then f.content:SetWidth(width) end
    end)
    f.list = UI.NewList(f.content, false)

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("CENTER", body, "CENTER", 0, 0)
    f.empty:SetText("Your quest log is empty.")
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
    f.targetText:SetText(("Aim for %d free"):format(res.target or ns.db.target))

    local quests = res.rows or {}
    f.content:SetHeight(math.max(ROW_H, UI.FillList(f.list, quests, 0)))
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
