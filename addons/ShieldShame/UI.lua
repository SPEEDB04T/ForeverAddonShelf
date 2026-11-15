-- Shield Shame: the reminder. One greyed-out buff icon of the shield you should be wearing,
-- built as the game's own buff icon (AuraButtonArtTemplate); what it cost you is in its
-- tooltip. It is a plain frame (nothing secure), so showing and hiding it in a fight is allowed.
local _, ns = ...
local UI = {}
ns.UI = UI

-- The game's buff icon: 30 wide, 40 high with the line under it. A bigger or smaller icon
-- comes from SetScale on the holder, never from the art.
local ICON, HEIGHT = 30, 40
local holder, button
local testing = false
local shownKind

local NORMAL = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
local WHITE = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
local GRAY = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
local function C(c) return c.r, c.g, c.b end

local function Icon(kind)
    local e = ns.values[kind]
    local id = e and e.id or ns.SHIELDS[kind].ids[1]
    if C_Spell and C_Spell.GetSpellTexture then
        local v = ns.Call(C_Spell.GetSpellTexture, id)
        if v then return v end
    end
    local v = ns.Call(GetSpellTexture, id)
    return v or ns.SHIELDS[kind].iconPath
end

local function HasKit()
    return ns.Kit and ns.Options and ns.Options.Ready and ns.Options.Ready()
end

----------------------------------------------------------------------
-- Tooltip, laid out like a buff's (gold title, white body, grey hints)
----------------------------------------------------------------------
local function ShowTooltip(self)
    local kind = shownKind or ns.Measured() or "lightning"
    local e = ns.values[kind]
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")     -- as AuraButtonMixin:OnEnter
    GameTooltip:AddLine(e and e.name or ns.SHIELDS[kind].english, C(NORMAL))
    GameTooltip:AddLine(ns.Tease(kind), C(WHITE))
    local value, what = ns.OrbValue(kind)
    if (value or 0) > 0 then
        GameTooltip:AddLine(("Every hit you take without it is %s %s you don't get."):format(ns.Commas(value), what), C(GRAY), true)
    end
    GameTooltip:AddLine(" ")
    local f = ns.fight or ns.lastFight
    if f then
        GameTooltip:AddDoubleLine(ns.fight and "Lost this fight" or "Lost last fight",
            ("%s damage, %s mana"):format(ns.Commas(f.damage), ns.Commas(f.mana)), C(NORMAL), C(WHITE))
    end
    local s, t = ns.session, ns.char.total
    GameTooltip:AddDoubleLine("Lost this session", ("%s damage, %s mana"):format(ns.Commas(s.damage), ns.Commas(s.mana)), C(NORMAL), C(WHITE))
    GameTooltip:AddDoubleLine("Lost all time", ("%s damage, %s mana"):format(ns.Commas(t.damage), ns.Commas(t.mana)), C(NORMAL), C(WHITE))
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: what you lost, in chat", C(GRAY))
    GameTooltip:AddLine("Right-click: options", C(GRAY))
    if not ns.db.locked then GameTooltip:AddLine("Drag: move", C(GRAY)) end
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- Building: the game's buff icon, AuraButtonArtTemplate
-- (Blizzard_BuffFrame/BuffFrameTemplates.xml): a 30x40 button, the 30x30 icon at its top,
-- Duration (GameFontNormalSmall) under the icon, Count (NumberFontNormal) at the icon's
-- bottom right. No border, highlight or pushed art: the buff icon has none.
----------------------------------------------------------------------
local function BuildArt(b)
    -- the same layers by hand, for a client where the template is missing
    b:SetSize(ICON, HEIGHT)
    b.Icon = b:CreateTexture(nil, "BACKGROUND")
    b.Icon:SetSize(ICON, ICON)
    b.Icon:SetPoint("TOP", b, "TOP", 0, 0)
    b.Duration = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
    b.Duration:SetPoint("TOP", b.Icon, "BOTTOM", 0, 0)
    b.Duration:Hide()
    b.Count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.Count:SetPoint("BOTTOMRIGHT", b.Icon, "BOTTOMRIGHT", -2, 2)
end

local function MakeButton()
    local ok, b = pcall(CreateFrame, "Button", nil, holder, "AuraButtonArtTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, holder) end
    if type(b.Icon) ~= "table" or type(b.Count) ~= "table" or type(b.Duration) ~= "table" then BuildArt(b) end
    b:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.Icon:SetDesaturated(true)          -- missing: the game's look for "not there"
    b.Count:Hide()
    if type(b.DebuffBorder) == "table" then b.DebuffBorder:Hide() end
    if type(b.TempEnchantBorder) == "table" then b.TempEnchantBorder:Hide() end
    if type(b.Symbol) == "table" then b.Symbol:Hide() end

    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if HasKit() then ns.Kit.Open() else ns.Print("the options window appears after you restart the game once.") end
        else
            ns.PrintSummary()
        end
    end)
    b:SetScript("OnDragStart", function()
        if not ns.db.locked then holder:StartMoving() end
    end)
    b:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        local point, _, relPoint, x, y = holder:GetPoint(1)
        if point then ns.db.point = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) } end
    end)
    return b
end

function UI.Place()
    if not holder then return end
    local p = ns.db.point
    holder:ClearAllPoints()
    holder:SetPoint(p[1] or "TOP", UIParent, p[2] or "TOP", p[3] or 0, p[4] or -190)
    holder:SetScale(ns.db.scale or 1)
end

-- LookShots (a helper only on the author's machine) shoots each listed frame the first time it
-- shows. Harmless without it. Keep in step with the TOC's version.
LookShotsTargets = type(LookShotsTargets) == "table" and LookShotsTargets or {}
LookShotsTargets["ShieldShame"] = {
    version = ns.VERSION,
    frames = {
        { label = "missing-shield icon", frame = function() return holder end },
    },
}

function UI.Init()
    if holder then return end
    holder = CreateFrame("Frame", "ShieldShameReminder", UIParent)
    holder:SetSize(ICON, HEIGHT)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:SetFrameStrata("LOW")             -- BuffFrame's strata
    button = MakeButton()
    UI.Place()
    holder:Hide()
    UI.holder, UI.button = holder, button
    UI.Update()
end

----------------------------------------------------------------------
-- Showing
----------------------------------------------------------------------
function UI.Testing() return testing end
function UI.SetTesting(on)
    testing = on and true or false
    UI.Update()
end

-- The shield to remind you of now, or nil.
function UI.Wanted()
    local db = ns.db
    if not db or ns.disabled then return nil end
    local kind = ns.Measured()
    if testing then return kind or "lightning" end
    if not db.enabled or not db.remind or not kind then return nil end
    if ns.shield then return nil end
    if ns.Call(UnitIsDeadOrGhost, "player") == true then return nil end
    if ns.Call(UnitOnTaxi, "player") == true then return nil end
    local fighting = ns.inCombat or ns.Call(UnitAffectingCombat, "player") == true
    if fighting then return db.remindCombat and kind or nil end
    if db.hideMounted and ns.Call(IsMounted) == true then return nil end
    if db.hideResting and ns.Call(IsResting) == true then return nil end
    return kind
end

function UI.Update()
    if not holder or not ns.db then return end
    local ok, kind = pcall(UI.Wanted)
    if not ok then kind = nil end
    if not kind then
        shownKind = nil
        holder:Hide()
        return
    end
    if kind ~= shownKind then
        button.Icon:SetTexture(Icon(kind))
        shownKind = kind
    end
    button:Show()
    holder:Show()
end
