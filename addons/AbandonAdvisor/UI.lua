-- Abandon Advisor: the window (rated quest list, abandon buttons, confirm popup)
local _, ns = ...
local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 540, 440
local ROW_H = 36
local POPUP = "ABANDONADVISOR_CONFIRM"

local VERDICT = {
    turnin  = { label = "Hand in", r = 0.35, g = 0.70, b = 1.00 },
    abandon = { label = "Abandon", r = 1.00, g = 0.30, b = 0.30 },
    maybe   = { label = "Maybe",   r = 1.00, g = 0.82, b = 0.10 },
    keep    = { label = "Keep",    r = 0.30, g = 0.90, b = 0.30 },
}

local rows = {}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
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
    local r, g, b = LevelColor(row)
    GameTooltip:AddLine(row.title, r, g, b)
    local v = VERDICT[row.verdict]
    local right = row.verdict == "turnin" and "" or ("score %d"):format(row.score)
    GameTooltip:AddDoubleLine(v.label, right, v.r, v.g, v.b, 0.7, 0.7, 0.7)
    if row.pick then GameTooltip:AddLine("Marked: one of the first to drop to reach your free-slot target.", 1, 0.5, 0.5, true) end
    GameTooltip:AddLine(" ")
    for _, reason in ipairs(row.reasons) do
        if reason.pts > 0 then
            GameTooltip:AddDoubleLine(reason.text, ("+%d"):format(reason.pts), 1, 0.6, 0.6, 1, 0.6, 0.6)
        elseif reason.pts < 0 then
            GameTooltip:AddDoubleLine(reason.text, tostring(reason.pts), 0.6, 1, 0.6, 0.6, 1, 0.6)
        else
            GameTooltip:AddLine(reason.text, 0.9, 0.9, 0.9, true)
        end
    end
    GameTooltip:AddLine(" ")
    if row.zone then GameTooltip:AddDoubleLine("Zone", row.zone, 0.7, 0.7, 0.7, 1, 1, 1) end
    if row.level then GameTooltip:AddDoubleLine("Level", tostring(row.level), 0.7, 0.7, 0.7, 1, 1, 1) end
    if row.tagName then GameTooltip:AddDoubleLine("Type", row.tagName, 0.7, 0.7, 0.7, 1, 1, 1) end
    if row.xp and row.xp > 0 then
        local text = tostring(row.xp)
        if row.xpPct then text = ("%s (%.1f%% of a level)"):format(text, row.xpPct) end
        GameTooltip:AddDoubleLine("XP", text, 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if row.money and row.money > 0 then
        GameTooltip:AddDoubleLine("Money", MoneyText(row.money), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    if row.distance then
        GameTooltip:AddDoubleLine("Distance", ("%d yd"):format(row.distance), 0.7, 0.7, 0.7, 1, 1, 1)
    end
    for _, objective in ipairs(row.objectives or {}) do
        if objective.text then
            local c = objective.done and 0.5 or 0.85
            GameTooltip:AddLine("- " .. objective.text, c, c, c, true)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: show in quest log   Right-click: pin as keep / unpin", 0.5, 0.8, 1)
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
        UI.Update(ns.Compute())
    else
        OpenInQuestLog(row)
    end
end

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------
local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints(row)
    row.hl:SetColorTexture(1, 1, 1, 0.08)

    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.stripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 2)
    row.stripe:SetWidth(4)

    row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.button:SetSize(74, 20)
    row.button:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.button:SetText("Abandon")
    row.button:SetScript("OnClick", function(self)
        local data = self:GetParent().data
        if data then ConfirmAbandon(data) end
    end)

    row.verdict = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.verdict:SetPoint("RIGHT", row.button, "LEFT", -8, 0)
    row.verdict:SetWidth(74)
    row.verdict:SetJustifyH("RIGHT")

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -4)
    row.title:SetPoint("RIGHT", row.verdict, "LEFT", -6, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)

    row.why = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.why:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.why:SetPoint("RIGHT", row.verdict, "LEFT", -6, 0)
    row.why:SetJustifyH("LEFT")
    row.why:SetWordWrap(false)
    row.why:SetTextColor(0.72, 0.72, 0.72)

    row:SetScript("OnEnter", RowEnter)
    row:SetScript("OnLeave", RowLeave)
    row:SetScript("OnClick", RowClick)
    return row
end

local function FillRow(row, data)
    row.data = data
    local v = VERDICT[data.verdict]
    row.stripe:SetColorTexture(v.r, v.g, v.b, 1)

    local r, g, b = LevelColor(data)
    local title = ("[%s] %s"):format(data.level and tostring(data.level) or "?", data.title)
    if data.tagName then title = title .. " (" .. data.tagName .. ")" end
    if data.pick then title = "|cffff5555»|r " .. title end
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
    row.verdict:SetTextColor(v.r, v.g, v.b)

    if data.verdict == "turnin" or data.canAbandon == false then
        row.button:Hide()
    else
        row.button:Show()
    end
    row:Show()
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
    UI.Update(ns.Compute())
end

function UI.Create()
    if UI.frame then return end
    local f = CreateFrame("Frame", "AbandonAdvisorFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    UI.frame = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SavePosition()
    end)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 32, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0, 0, 0, 0.92)
    end

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.title:SetText("Abandon Advisor")

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.summary:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
    f.summary:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.summary:SetJustifyH("LEFT")
    f.summary:SetJustifyV("TOP")
    f.summary:SetHeight(44)

    -- Free-slot target: [-] Aim for N free [+]
    f.more = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.more:SetSize(22, 20)
    f.more:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
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
    f.hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 15)
    f.hint:SetText("Hover a quest for the reasons. Right-click to pin it as keep.")

    f.scroll = CreateFrame("ScrollFrame", "AbandonAdvisorScroll", f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -84)
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 38)

    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetSize(WIDTH - 42, ROW_H)
    f.scroll:SetScrollChild(f.content)

    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.empty:SetPoint("CENTER", f.scroll, "CENTER", 0, 0)
    f.empty:SetText("Your quest log is empty.")
    f.empty:Hide()

    f:SetScript("OnShow", function() UI.Update(ns.Compute()) end)
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

    local list = res.rows or {}
    for i, data in ipairs(list) do
        rows[i] = rows[i] or CreateRow(f.content, i)
        FillRow(rows[i], data)
    end
    for i = #list + 1, #rows do
        rows[i].data = nil
        rows[i]:Hide()
    end
    f.content:SetHeight(math.max(ROW_H, #list * ROW_H))
    if #list == 0 and not res.error then f.empty:Show() else f.empty:Hide() end
end

function UI.IsShown()
    return UI.frame ~= nil and UI.frame:IsShown()
end

function UI.Show()
    if not UI.frame then UI.Create() end
    UI.frame:Show()
end

function UI.Toggle()
    if not UI.frame then UI.Create() end
    if UI.frame:IsShown() then UI.frame:Hide() else UI.frame:Show() end
end
