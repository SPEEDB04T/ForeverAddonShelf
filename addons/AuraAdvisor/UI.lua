-- Aura Advisor: the on-screen frame. One click-to-cast button per aura you know, drawn like
-- the game's own stance-bar buttons: the aura that is on looks pressed in (checked), the one
-- to switch to gets the game's spell-alert glow, and the line under the buttons says why.
--
-- The buttons are secure (they cast), so in a fight nothing here may be shown, hidden, moved
-- or re-aimed. That is why there is a button for every aura and the advice is only paint:
-- textures, a glow and text can change in a fight, the buttons themselves can not.
local _, ns = ...
local Data = ns.Data
local UI = {}
ns.UI = UI

local BTN, GAP, PAD = 36, 6, 10
local TEXT_H = 26
local MIN_W = 206

----------------------------------------------------------------------
-- The game's colours and art
----------------------------------------------------------------------
local FALLBACK = {
    NORMAL_FONT_COLOR = { 1.0, 0.82, 0.0 },
    HIGHLIGHT_FONT_COLOR = { 1.0, 1.0, 1.0 },
    GREEN_FONT_COLOR = { 0.1, 1.0, 0.1 },
    GRAY_FONT_COLOR = { 0.5, 0.5, 0.5 },
    RED_FONT_COLOR = { 1.0, 0.1, 0.1 },
    TOOLTIP_DEFAULT_BACKGROUND_COLOR = { 0.09, 0.09, 0.19 },
    TOOLTIP_DEFAULT_COLOR = { 1.0, 1.0, 1.0 },
}

local function RGB(name)
    local c = _G[name]
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    local f = FALLBACK[name]
    return f[1], f[2], f[3]
end

local function Paint(name, text)
    local r, g, b = RGB(name)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5), text)
end
UI.Paint = Paint

-- This client draws action buttons from the UI-HUD-ActionBar atlases (Blizzard_ActionBar,
-- ActionButtonTemplate.xml); the older button files are the fallback if they are missing.
local ATLAS = {
    slot = "UI-HUD-ActionBar-IconFrame-Background",
    mask = "UI-HUD-ActionBar-IconFrame-Mask",
    frame = "UI-HUD-ActionBar-IconFrame",
    down = "UI-HUD-ActionBar-IconFrame-Down",
    hover = "UI-HUD-ActionBar-IconFrame-Mouseover",
}

local function HasAtlas(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return false end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

local function UseKeyDown()
    local ok, v
    if C_CVar and C_CVar.GetCVarBool then
        ok, v = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
    elseif GetCVarBool then
        ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    end
    return ok and v
end

-- [noform:N] keeps a click on the aura that is already on from doing anything.
local function CastMacro(info)
    if info.form then return ("/cast [noform:%d] %s"):format(info.form, info.name) end
    return "/cast " .. info.name
end
UI.CastMacro = CastMacro

----------------------------------------------------------------------
-- Tooltip: the game's own spell tooltip, with the advice under it
----------------------------------------------------------------------
local function OnEnter(self)
    local info = self.info
    if not info then return end
    local res = ns.result
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = info.spellID and GameTooltip.SetSpellByID and pcall(GameTooltip.SetSpellByID, GameTooltip, info.spellID)
    if not ok then
        GameTooltip:AddLine(info.name, RGB("HIGHLIGHT_FONT_COLOR"))
        local r, g, b = RGB("NORMAL_FONT_COLOR")
        GameTooltip:AddLine(Data.AURAS[self.key].does, r, g, b, true)
    end
    GameTooltip:AddLine(" ")
    if res then
        local taken = ns.OtherAuras()[self.key]
        if self.key == res.shown then
            local r, g, b = RGB("GREEN_FONT_COLOR")
            GameTooltip:AddLine("Switch to this: " .. tostring(res.reason), r, g, b, true)
        elseif self.key == res.current then
            GameTooltip:AddLine("On now", RGB("GREEN_FONT_COLOR"))
        end
        if res.why[self.key] and self.key ~= res.shown then
            local r, g, b = RGB(taken and "RED_FONT_COLOR" or "HIGHLIGHT_FONT_COLOR")
            GameTooltip:AddLine(res.why[self.key], r, g, b, true)
        end
        local lr, lg, lb = RGB("NORMAL_FONT_COLOR")
        local vr, vg, vb = RGB("HIGHLIGHT_FONT_COLOR")
        GameTooltip:AddDoubleLine("Points right now", ("%.1f"):format(res.scores[self.key] or 0), lr, lg, lb, vr, vg, vb)
    end
    local r, g, b = RGB("GRAY_FONT_COLOR")
    GameTooltip:AddLine("Left-click: switch to it. Right-click: the numbers in chat.", r, g, b, true)
    GameTooltip:Show()
end

local function OnLeave() GameTooltip:Hide() end

local function PostClick(_, button, down)
    if button == "RightButton" and not down then ns.PrintWhy() end
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
function UI.SavePosition()
    local point, _, relPoint, x, y = UI.frame:GetPoint()
    if type(point) == "string" and type(x) == "number" and type(y) == "number" then
        ns.db.point = { point, relPoint or point, x, y }
    end
end

function UI.RestorePosition()
    local f, p = UI.frame, ns.db.point
    if not f or InCombatLockdown() then return end
    f:ClearAllPoints()
    if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 0, -150) end
end

local function StartMove()
    local f = UI.frame
    if not ns.db.locked and not InCombatLockdown() then f:StartMoving(); f.moving = true end
end

local function StopMove()
    local f = UI.frame
    if f.moving then
        f:StopMovingOrSizing()
        f.moving = nil
        UI.SavePosition()
    end
end

-- The game's tooltip look: tooltip border and background files in the tooltip's own colours.
local function Backdrop(frame)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })
    local r, g, b = RGB("TOOLTIP_DEFAULT_BACKGROUND_COLOR")
    frame:SetBackdropColor(r, g, b, 0.9)
    frame:SetBackdropBorderColor(RGB("TOOLTIP_DEFAULT_COLOR"))
end

-- A state texture (normal, pushed, highlight) sized like ActionButtonTemplate's: 46 x 45 on a
-- 45 button, pinned top left.
local function FitState(tex)
    if not tex then return end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT")
    tex:SetSize(BTN * 46 / 45, BTN)
end

local function NewButton(key, index, parent, modern)
    local b = CreateFrame("Button", "AuraAdvisorButton" .. index, parent, "SecureActionButtonTemplate")
    b.key = key
    b:SetSize(BTN, BTN)
    if UseKeyDown() then b:RegisterForClicks("AnyDown", "AnyUp") else b:RegisterForClicks("AnyUp") end

    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    b.icon:SetTexture(Data.AURAS[key].icon)

    b.checked = b:CreateTexture(nil, "OVERLAY")
    b.checked:SetBlendMode("ADD")
    b.checked:Hide()

    if modern then
        b.slot = b:CreateTexture(nil, "BACKGROUND", nil, -1)
        b.slot:SetAllPoints()
        b.slot:SetAtlas(ATLAS.slot)
        if b.CreateMaskTexture then
            b.mask = b:CreateMaskTexture()
            b.mask:SetAtlas(ATLAS.mask)
            b.mask:SetAllPoints(b.icon)
            b.icon:AddMaskTexture(b.mask)
        else
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
        b:SetNormalAtlas(ATLAS.frame)
        FitState(b:GetNormalTexture())
        b:SetPushedAtlas(ATLAS.down)
        FitState(b:GetPushedTexture())
        b:SetHighlightAtlas(ATLAS.hover)
        FitState(b:GetHighlightTexture())
        b.checked:SetAtlas(ATLAS.hover)
        FitState(b.checked)
    else
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
        local n = b:GetNormalTexture()
        if n then
            n:ClearAllPoints()
            n:SetPoint("CENTER", 0, -1)
            n:SetSize(BTN * 66 / 36, BTN * 66 / 36)
        end
        b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b.checked:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        b.checked:SetAllPoints()
    end

    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)
    b:SetScript("PostClick", PostClick)
    b:Hide()
    return b
end

-- The game's spell-alert glow (the one procs use), built the way ActionButtonSpellAlerts.lua
-- builds it: 1.4 x the button, centred. Made out of a fight, when the buttons are made, and
-- run by hand rather than through ActionButtonSpellAlertManager, so that none of the game's
-- own tables ever holds one of our buttons.
local function NewGameAlert(b)
    local ok, a = pcall(CreateFrame, "Frame", nil, b, "ActionButtonSpellAlertTemplate")
    if not ok or type(a) ~= "table" or type(a.ProcStartAnim) ~= "table" or type(a.ProcLoop) ~= "table" then
        return nil
    end
    a:SetSize(BTN * 1.4, BTN * 1.4)
    a:SetPoint("CENTER", b, "CENTER", 0, 0)
    a:Hide()
    return a
end

-- The suggestion glow: the game's spell-alert glow, or the old action-button glow file,
-- pulsing, if this client lacks the template.
local function Alert(b, on)
    if (b.alerting and true or false) == on then return end
    b.alerting = on
    local a = b.alert
    if a then
        if on then
            a:Show()
            a.ProcStartAnim:Play()
        else
            a.ProcStartAnim:Stop()
            a.ProcLoop:Stop()
            a:Hide()
        end
        return
    end
    if not b.glow then
        b.glow = b:CreateTexture(nil, "OVERLAY", nil, 1)
        b.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        b.glow:SetBlendMode("ADD")
        b.glow:SetPoint("CENTER")
        b.glow:SetSize(BTN * 1.9, BTN * 1.9)
        b.glow:Hide()
        b.pulse = b.glow:CreateAnimationGroup()
        b.pulse:SetLooping("BOUNCE")
        local fade = b.pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.35)
        fade:SetDuration(0.5)
    end
    if on then
        b.glow:Show()
        b.pulse:Play()
    else
        b.pulse:Stop()
        b.glow:Hide()
    end
end

function UI.Create()
    if UI.frame then return end
    local f = CreateFrame("Frame", "AuraAdvisorFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    UI.frame = f
    f:SetSize(MIN_W, PAD * 2 + BTN + 4 + TEXT_H)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", StartMove)
    f:SetScript("OnDragStop", StopMove)
    Backdrop(f)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(PAD + BTN + 5))
    f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD, -(PAD + BTN + 5))
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)

    f.reason = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.reason:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
    f.reason:SetPoint("TOPRIGHT", f.title, "BOTTOMRIGHT", 0, -2)
    f.reason:SetJustifyH("LEFT")
    f.reason:SetWordWrap(false)

    local modern = HasAtlas(ATLAS.frame) and HasAtlas(ATLAS.mask)
    UI.modern = modern
    f.buttons = {}
    for index, key in ipairs(Data.ORDER) do
        local b = NewButton(key, index, f, modern)
        b.alert = NewGameAlert(b)
        f.buttons[key] = b
    end
    UI.RestorePosition()
    UI.ApplySecure()
end

-- Everything the game only allows outside a fight: which buttons there are, what they cast,
-- where they sit, and whether the frame is shown. In a fight it waits for the fight to end.
function UI.ApplySecure()
    local f = UI.frame
    if not f then return end
    if InCombatLockdown() then UI.pending = true; return end
    UI.pending = false
    f:SetScale(ns.db.scale)

    local n = 0
    for _, key in ipairs(Data.ORDER) do
        local b, info = f.buttons[key], ns.known[key]
        b.info = info
        if info then
            b.icon:SetTexture(info.icon)
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", CastMacro(info))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + n * (BTN + GAP), -PAD)
            b:Show()
            n = n + 1
        else
            b:SetAttribute("type1", nil)
            b:SetAttribute("macrotext1", nil)
            b:Hide()
        end
    end
    f:SetSize(math.max(MIN_W, PAD * 2 + n * BTN + math.max(0, n - 1) * GAP), PAD * 2 + BTN + 4 + TEXT_H)

    if f.driven then
        if UnregisterStateDriver then UnregisterStateDriver(f, "visibility") end
        f.driven = nil
    end
    if n == 0 or ns.db.show == "never" then
        f:Hide()
    elseif ns.db.show == "combat" and RegisterStateDriver then
        RegisterStateDriver(f, "visibility", "[combat] show; hide")
        f.driven = true
    else
        f:Show()
    end
    UI.Update(ns.result)
end

local function Fade(f, alpha)
    pcall(f.SetAlpha, f, alpha)
end

-- Paint only: safe in a fight.
function UI.Update(res)
    local f = UI.frame
    if not f then return end
    local taken = res and ns.OtherAuras() or {}
    for _, key in ipairs(Data.ORDER) do
        local b = f.buttons[key]
        if b.info then
            local on = res and key == res.current or false
            b.checked:SetShown(on)
            -- like an action you can't use right now: grey and dimmed
            local greyed = taken[key] and not on and true or false
            b.icon:SetDesaturated(greyed)
            if greyed then b.icon:SetVertexColor(0.6, 0.6, 0.6) else b.icon:SetVertexColor(1, 1, 1) end
            Alert(b, res and key == res.shown or false)
        else
            Alert(b, false)
        end
    end

    if not res or not next(ns.known) then
        f.title:SetText("Aura Advisor")
        f.reason:SetText(next(ns.known) and "" or "no aura learned yet")
        Fade(f, ns.db.idleAlpha)
        return
    end
    if res.shown then
        local info = ns.known[res.shown]
        f.title:SetText("Switch to " .. info.name)
        f.reason:SetText(res.reason or "")
        Fade(f, 1)
    else
        local cur = res.current and ns.known[res.current]
        f.title:SetText(cur and Paint("GREEN_FONT_COLOR", cur.name) or "No aura on")
        if not cur then
            f.reason:SetText("")
        elseif res.quiet then
            f.reason:SetText("nothing is hitting you")
        else
            f.reason:SetText(res.why[res.current] or "fits this fight")
        end
        Fade(f, ns.db.idleAlpha)
    end
end
