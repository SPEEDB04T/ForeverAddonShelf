-- Snakes Warlock Helper: the reminder strip. A row of small icons that exists only while
-- something is missing. Out of combat an icon can be clicked to cast the missing buff;
-- in combat the icons are display-only, because the game doesn't let addons show or move
-- clickable cast buttons during a fight.
local _, ns = ...
local UI = ns.UI
local C = UI.color
local Strip = {}
ns.Strip = Strip

local GAP = 6
local icons, buttons = {}, {}
local current = {}

local function UseKeyDown()
    local ok, v
    if C_CVar and C_CVar.GetCVarBool then
        ok, v = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
    elseif GetCVarBool then
        ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    end
    return ok and v
end

----------------------------------------------------------------------
-- Tooltip and right-click
----------------------------------------------------------------------
local function ShowTip(icon)
    local e = icon and icon.entry
    if not e then return end
    local gold, white, gray, green = C.gold, C.white, C.gray, C.green
    GameTooltip:SetOwner(icon, "ANCHOR_BOTTOM", 0, -6)
    GameTooltip:AddLine(e.title, gold[1], gold[2], gold[3])
    GameTooltip:AddLine(e.text, white[1], white[2], white[3], true)
    if not ns.demo then
        if InCombatLockdown() then
            GameTooltip:AddLine("Can't be clicked during a fight.", gray[1], gray[2], gray[3])
        elseif e.spell or e.macro then
            GameTooltip:AddLine(e.macro and "Click to use it" or "Click to cast it", green[1], green[2], green[3])
        end
    end
    GameTooltip:AddLine("Right-click: quiet for 10 minutes", gray[1], gray[2], gray[3])
    GameTooltip:AddLine("Shift + right-click: turn this reminder off", gray[1], gray[2], gray[3])
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

local function RightClick(e)
    if not e or ns.demo then return end
    if IsShiftKeyDown() then ns.Reminders.Disable(e.key) else ns.Reminders.Snooze(e.key) end
    GameTooltip:Hide()
end

----------------------------------------------------------------------
-- Frames
----------------------------------------------------------------------
local function NewIcon(i)
    local ic = CreateFrame("Frame", nil, Strip.frame)
    -- Built like an action bar button: slot, masked icon, icon frame, then the bar's coloured
    -- border (purple: missing, orange: running out) and its spell-highlight glow.
    UI.IconFrame(ic, (ns.db and ns.db.iconSize) or 32)
    ic.border = UI.IconOverlay(ic, "UI-HUD-ActionBar-IconFrame-Border", 2)
    ic.glow = UI.IconOverlay(ic, "UI-HUD-ActionBar-IconFrame-Mouseover", 3, true)
    ic.hl = UI.IconOverlay(ic, "UI-HUD-ActionBar-IconFrame-Mouseover", 4, true)
    ic.hl:Hide()
    ic.timer = ic:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    ic.timer:SetPoint("BOTTOM", 0, 3)

    -- Breathing glow. Animation support differs between clients, so it is optional.
    pcall(function()
        local group = ic.glow:CreateAnimationGroup()
        group:SetLooping("BOUNCE")
        local a = group:CreateAnimation("Alpha")
        a:SetFromAlpha(0.9)
        a:SetToAlpha(0.1)
        a:SetDuration(1.2)
        a:SetSmoothing("IN_OUT")
        ic.pulse = group
    end)

    -- Hovered without a cast button on top (during a fight, in the demo): the bar's highlight.
    ic:EnableMouse(true)
    ic:SetScript("OnEnter", function(self) self.hl:Show(); ShowTip(self) end)
    ic:SetScript("OnLeave", function(self) self.hl:Hide(); HideTip() end)
    ic:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then RightClick(self.entry) end
    end)
    ic:Hide()
    icons[i] = ic
    return ic
end

local function NewButton(i)
    local b = CreateFrame("Button", "SnakesWarlockHelperCast" .. i, UIParent, "SecureActionButtonTemplate")
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Strip.frame:GetFrameLevel() + 10)
    if UseKeyDown() then b:RegisterForClicks("AnyDown", "AnyUp") else b:RegisterForClicks("AnyUp") end
    -- the action bar's own hover and pressed art
    if b.SetHighlightAtlas then b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", "ADD") end
    if b.SetPushedAtlas then b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down") end
    b:SetScript("OnEnter", function(self) ShowTip(self.icon) end)
    b:SetScript("OnLeave", HideTip)
    b:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down then RightClick(self.entry) end
    end)
    b:Hide()
    buttons[i] = b
    return b
end

local function Create()
    if Strip.frame then return end
    local f = CreateFrame("Frame", "SnakesWarlockHelperStrip", UIParent)
    Strip.frame = f
    f:SetSize(32, 32)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:Hide()

    -- Shown only while unlocked: a box to drag the strip by.
    -- A dialog-style box, like the game's own move handles.
    local m = CreateFrame("Frame", nil, f, "BackdropTemplate")
    Strip.mover = m
    m:SetFrameLevel(f:GetFrameLevel() + 20)
    m:SetPoint("CENTER", f, "CENTER", 0, 7)
    if m.SetBackdrop then
        m:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = UI.TOOLTIP_BORDER, edgeSize = 12, tile = true, tileSize = 32,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        m:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
        m:SetBackdropColor(1, 1, 1, 0.6)
    end
    m.label = UI.Text(m, "GameFontNormalSmall", nil, "CENTER")
    m.label:SetPoint("TOP", 0, -6)
    m.label:SetText("Warlock reminders: drag me")
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", function()
        if not InCombatLockdown() then f:StartMoving(); f.moving = true end
    end)
    m:SetScript("OnDragStop", function()
        if f.moving then f:StopMovingOrSizing(); f.moving = nil; UI.SavePoint(f, "stripPoint") end
    end)
    m:Hide()

    Strip.RestorePosition()
end

function Strip.RestorePosition()
    if Strip.frame then UI.RestorePoint(Strip.frame, "stripPoint", "CENTER", 0, -170) end
end

----------------------------------------------------------------------
-- Showing a list of reminders
----------------------------------------------------------------------
function Strip.Show(list)
    Create()
    current = list or {}
    local n, size = #current, ns.db.iconSize or 32
    local now = GetTime()

    for i = 1, math.max(n, #icons) do
        local e, ic = current[i], icons[i]
        if e then
            ic = ic or NewIcon(i)
            e.expiresAt = e.remaining and (now + e.remaining) or nil
            ic.entry = e
            UI.SizeIconFrame(ic, size)
            ic:ClearAllPoints()
            ic:SetPoint("LEFT", Strip.frame, "LEFT", (i - 1) * (size + GAP), 0)
            ic.tex:SetTexture(e.icon)
            local c = (e.state == "expiring") and C.orange or C.warlock
            ic.border:SetVertexColor(c[1], c[2], c[3], 1)
            ic.glow:SetVertexColor(c[1], c[2], c[3], 1)
            if e.state == "expiring" or not ns.db.pulse then ic.glow:Hide() else ic.glow:Show() end
            ic.timer:SetTextColor(C.white[1], C.white[2], C.white[3])
            ic:Show()
            if ic.pulse then
                if ns.db.pulse and e.state ~= "expiring" then
                    if not ic.pulse:IsPlaying() then ic.pulse:Play() end
                else
                    ic.pulse:Stop()
                end
            end
        elseif ic then
            ic.entry = nil
            if ic.pulse then ic.pulse:Stop() end
            ic:Hide()
        end
    end

    -- The strip is anchored by its centre, so it grows evenly to both sides.
    Strip.frame:SetSize(math.max(1, n) * size + math.max(0, n - 1) * GAP, size)
    Strip.mover:SetSize(math.max(Strip.frame:GetWidth() + 24, 190), size + 38)
    if n > 0 or not ns.db.locked then Strip.frame:Show() else Strip.frame:Hide() end
    Strip.UpdateTimers()
    Strip.ApplySecure()
end

function Strip.UpdateTimers()
    if not Strip.frame or not Strip.frame:IsShown() then return end
    local now = GetTime()
    for i = 1, #current do
        local e, ic = current[i], icons[i]
        if ic and e then
            if e.expiresAt and e.expiresAt > now then
                ic.timer:SetText(UI.FormatTimer(e.expiresAt - now))
            else
                ic.timer:SetText("")
            end
        end
    end
end

-- Click-to-cast overlays. Only touched out of combat; dropped when a fight starts.
function Strip.ApplySecure()
    if not Strip.frame or InCombatLockdown() then return end
    for i = 1, math.max(#current, #buttons) do
        local e, b = current[i], buttons[i]
        if e and (e.spell or e.macro) and not ns.demo then
            b = b or NewButton(i)
            b.entry, b.icon = e, icons[i]
            b:SetAttribute("type1", e.macro and "macro" or "spell")
            b:SetAttribute("spell", e.spell)
            b:SetAttribute("macrotext", e.macro)
            b:ClearAllPoints()
            b:SetAllPoints(icons[i])
            b:Show()
        elseif b then
            b.entry = nil
            b:SetAttribute("type1", nil)
            b:Hide()
            b:ClearAllPoints()
        end
    end
end

local function OnCombatStart()
    -- Fires just before the lockdown: last chance to detach the cast buttons, so the
    -- icons stay free to appear, move and disappear during the fight.
    for _, b in ipairs(buttons) do
        b:Hide()
        b:ClearAllPoints()
    end
    if Strip.frame and Strip.frame.moving then
        Strip.frame:StopMovingOrSizing()
        Strip.frame.moving = nil
        UI.SavePoint(Strip.frame, "stripPoint")
    end
end

function Strip.ApplyLock()
    Create()
    if ns.db.locked then Strip.mover:Hide() else Strip.mover:Show() end
    Strip.Show(current)
end

function Strip.Enable()
    Create()
    ns.On("PLAYER_REGEN_DISABLED", OnCombatStart)
    ns.On("PLAYER_REGEN_ENABLED", function() Strip.ApplySecure() end)
    Strip.ApplyLock()
end
