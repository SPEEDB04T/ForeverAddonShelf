-- Aura Advisor: the on-screen bar. A copy of the game's stance bar (Blizzard_ActionBar:
-- StanceBar.xml / StanceBar.lua): one SmallActionButtonTemplate button per aura you know, 30 px,
-- 2 px apart, no panel and no text. The aura that is on is checked, the way the stance bar
-- shows the active stance; the aura to switch to gets the game's spell-alert glow, the way a
-- proc shows on an action button. Why it is suggested is in the tooltip, the line in the middle
-- of the screen and /aura.
--
-- The buttons are secure (they cast), so in a fight nothing here may be shown, hidden, moved
-- or re-aimed. That is why there is a button for every aura and the advice is only paint:
-- checked state, glow and icon colour can change in a fight, the buttons themselves can not.
local _, ns = ...
local Data = ns.Data
local UI = {}
ns.UI = UI

-- StanceBar's buttons: SmallActionButtonTemplate is 30 x 30; the stance bar's default Edit Mode
-- IconPadding is 2 (EditModePresetLayouts.lua).
local GAME_SIZE, GAME_GAP = 30, 2
-- Only if this client lacked SmallActionButtonTemplate: the old ActionButtonTemplate, 36 px.
local OLD_SIZE, OLD_GAP = 36, 6

----------------------------------------------------------------------
-- The game's colours
----------------------------------------------------------------------
local FALLBACK = {
    NORMAL_FONT_COLOR = { 1.0, 0.82, 0.0 },
    HIGHLIGHT_FONT_COLOR = { 1.0, 1.0, 1.0 },
    GREEN_FONT_COLOR = { 0.1, 1.0, 0.1 },
    GRAY_FONT_COLOR = { 0.5, 0.5, 0.5 },
    RED_FONT_COLOR = { 1.0, 0.1, 0.1 },
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

local function UseKeyDown()
    local ok, v
    if C_CVar and C_CVar.GetCVarBool then
        ok, v = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
    elseif GetCVarBool then
        ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    end
    return ok and v
end

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- [noform:N] keeps a click on the aura that is already on from doing anything.
local function CastMacro(info)
    if info.form then return ("/cast [noform:%d] %s"):format(info.form, info.name) end
    return "/cast " .. info.name
end
UI.CastMacro = CastMacro

----------------------------------------------------------------------
-- Tooltip: StanceButtonMixin_OnEnter's, with the advice added under it
----------------------------------------------------------------------
local function OnEnter(self)
    local info = self.info
    if not info then return end
    local uber = GetCVarBool and select(2, pcall(GetCVarBool, "UberTooltips"))
    if uber == true and GameTooltip_SetDefaultAnchor then
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
    else
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    end
    local ok = false
    if info.form and GameTooltip.SetShapeshift then
        ok = pcall(GameTooltip.SetShapeshift, GameTooltip, info.form)
    end
    if not ok and info.spellID and GameTooltip.SetSpellByID then
        ok = pcall(GameTooltip.SetSpellByID, GameTooltip, info.spellID)
    end
    if not ok then
        GameTooltip:AddLine(info.name, RGB("HIGHLIGHT_FONT_COLOR"))
        local r, g, b = RGB("NORMAL_FONT_COLOR")
        GameTooltip:AddLine(Data.AURAS[self.key].does, r, g, b, true)
    end
    local res = ns.result
    if res then
        local taken = ns.OtherAuras()[self.key]
        GameTooltip:AddLine(" ")
        if self.key == res.shown then
            local r, g, b = RGB("GREEN_FONT_COLOR")
            GameTooltip:AddLine("Switch to this: " .. tostring(res.reason), r, g, b, true)
        elseif res.why[self.key] then
            local r, g, b = RGB(taken and "RED_FONT_COLOR" or "HIGHLIGHT_FONT_COLOR")
            GameTooltip:AddLine(res.why[self.key], r, g, b, true)
        end
        local r, g, b = RGB("GRAY_FONT_COLOR")
        GameTooltip:AddLine("Right-click: every aura's points in chat", r, g, b, true)
    end
    GameTooltip:Show()
end

local function OnLeave()
    if GameTooltip_Hide then GameTooltip_Hide() else GameTooltip:Hide() end
end

----------------------------------------------------------------------
-- Moving: drag any button while the bar is unlocked, outside a fight
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

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------
-- A CheckButton flips its own checked state when clicked (StanceButtonMixin_OnClick does the
-- same); put it back until the game says the aura really changed.
local function PostClick(self, button, down)
    self:SetChecked(self.on and true or false)
    if button == "RightButton" and not down then ns.PrintWhy() end
end

-- The game's button: SmallActionButtonTemplate with SecureActionButtonTemplate, the "barebones
-- combo" ActionButton.lua's UpdateFlyout names. Its own OnLoad lays out the art.
local function GameButton(index, parent)
    local ok, b = pcall(CreateFrame, "CheckButton", "AuraAdvisorButton" .. index, parent,
        "SecureActionButtonTemplate, SmallActionButtonTemplate")
    if ok and type(b) == "table" and type(b.icon) == "table" and type(b.cooldown) == "table" then
        b.cooldown:SetSwipeColor(0, 0, 0)    -- as StanceButtonMixin_OnLoad
        return b
    end
end

-- Only if this client lacked that template: the old ActionButtonTemplate's build.
local function OldButton(index, parent)
    local b = CreateFrame("CheckButton", "AuraAdvisorOldButton" .. index, parent, "SecureActionButtonTemplate")
    b:SetSize(OLD_SIZE, OLD_SIZE)
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    local n = b:GetNormalTexture()
    if n then
        n:ClearAllPoints()
        n:SetPoint("CENTER", 0, -1)
        n:SetSize(66, 66)
    end
    b:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
    local c = b:GetCheckedTexture()
    if c and c.SetBlendMode then c:SetBlendMode("ADD") end
    return b
end

-- The game's spell-alert glow, built the way ActionButtonSpellAlerts.lua's GetAlertFrame builds
-- it: 1.4 x the button, centred. Made when the buttons are made (out of a fight) and run by
-- hand rather than through ActionButtonSpellAlertManager, so that none of the game's own tables
-- ever holds one of our buttons.
local function NewGameAlert(b)
    local ok, a = pcall(CreateFrame, "Frame", nil, b, "ActionButtonSpellAlertTemplate")
    if not ok or type(a) ~= "table" or type(a.ProcStartAnim) ~= "table" or type(a.ProcLoop) ~= "table" then
        return nil
    end
    local w, h = b:GetSize()
    a:SetSize(w * 1.4, h * 1.4)
    a:SetPoint("CENTER", b, "CENTER", 0, 0)
    a:Hide()
    return a
end

local function NewButton(key, index, parent)
    local b = GameButton(index, parent)
    UI.game = b and true or false
    b = b or OldButton(index, parent)
    b.key = key
    b.icon:SetTexture(Data.AURAS[key].icon)
    if UseKeyDown() then b:RegisterForClicks("AnyDown", "AnyUp") else b:RegisterForClicks("AnyUp") end
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)
    b:SetScript("OnDragStart", StartMove)
    b:SetScript("OnDragStop", StopMove)
    b:SetScript("PostClick", PostClick)
    b.alert = NewGameAlert(b)
    b:Hide()
    return b
end

-- The suggestion: the game's spell-alert glow on one button. Without the template, the
-- action button's own spell highlight (SpellHighlightAnim), which the game also uses.
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
    elseif type(b.SpellHighlightTexture) == "table" and type(b.SpellHighlightAnim) == "table" then
        b.SpellHighlightTexture:SetShown(on)
        if on then b.SpellHighlightAnim:Play() else b.SpellHighlightAnim:Stop() end
    end
end

function UI.Create()
    if UI.frame then return end
    local f = CreateFrame("Frame", "AuraAdvisorFrame", UIParent)
    UI.frame = f
    f:SetSize(GAME_SIZE, GAME_SIZE)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)

    f.buttons = {}
    for index, key in ipairs(Data.ORDER) do
        f.buttons[key] = NewButton(key, index, f)
    end
    UI.size = UI.game and GAME_SIZE or OLD_SIZE
    UI.gap = UI.game and GAME_GAP or OLD_GAP

    -- the global cooldown after a switch, as StanceBarMixin shows it
    f:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
    f:SetScript("OnEvent", function() UI.UpdateCooldowns() end)

    UI.RestorePosition()
    UI.ApplySecure()
end

-- Everything the game only allows outside a fight: which buttons there are, what they cast,
-- where they sit, and whether the bar is shown. In a fight it waits for the fight to end.
function UI.ApplySecure()
    local f = UI.frame
    if not f then return end
    if InCombatLockdown() then UI.pending = true; return end
    UI.pending = false
    f:SetScale(ns.db.scale)

    local size, gap = UI.size, UI.gap
    local n = 0
    for _, key in ipairs(Data.ORDER) do
        local b, info = f.buttons[key], ns.known[key]
        b.info = info
        if info then
            b.icon:SetTexture(info.icon)
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", CastMacro(info))
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", n * (size + gap), 0)
            b:Show()
            n = n + 1
        else
            b:SetAttribute("type1", nil)
            b:SetAttribute("macrotext1", nil)
            b:Hide()
        end
    end
    f:SetSize(math.max(size, n * size + math.max(0, n - 1) * gap), size)

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
    UI.UpdateCooldowns()
    UI.Update(ns.result)
end

-- StanceBarMixin:UpdateState's cooldown part. In a fight the game may hide cooldowns from
-- addons; then the sweep is simply left out.
function UI.UpdateCooldowns()
    local f = UI.frame
    if not f or not GetShapeshiftFormCooldown or not CooldownFrame_Set then return end
    for _, key in ipairs(Data.ORDER) do
        local b = f.buttons[key]
        local form = b.info and b.info.form
        if form and b.cooldown then
            local ok, start, duration, enable = pcall(GetShapeshiftFormCooldown, form)
            if ok and Plain(start) and Plain(duration) and Plain(enable) ~= nil then
                pcall(CooldownFrame_Set, b.cooldown, start, duration, enable)
            end
        end
    end
end

local function Fade(f, alpha)
    pcall(f.SetAlpha, f, alpha)
end

-- Can the aura be cast right now (StanceBarMixin:UpdateState's isCastable)?
local function Castable(info)
    if not (info.form and GetShapeshiftFormInfo) then return true end
    local ok, _, _, castable = pcall(GetShapeshiftFormInfo, info.form)
    if not ok then return true end
    castable = Plain(castable)
    return castable ~= false
end

-- Paint only: safe in a fight.
function UI.Update(res)
    local f = UI.frame
    if not f then return end
    local taken = res and ns.OtherAuras() or {}
    for _, key in ipairs(Data.ORDER) do
        local b = f.buttons[key]
        local info = b.info
        if info then
            b.on = res and key == res.current or false
            b:SetChecked(b.on)
            -- another paladin has it up: unavailable, so desaturated
            b.icon:SetDesaturated(taken[key] and not b.on and true or false)
            -- can't be cast right now (no mana): the stance bar's 0.4
            if Castable(info) then b.icon:SetVertexColor(1, 1, 1) else b.icon:SetVertexColor(0.4, 0.4, 0.4) end
            Alert(b, res and key == res.shown or false)
        else
            Alert(b, false)
        end
    end
    Fade(f, (res and res.shown) and 1 or ns.db.idleAlpha)
end
