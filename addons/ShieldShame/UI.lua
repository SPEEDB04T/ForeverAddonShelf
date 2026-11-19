-- Shield Shame: the reminder. One greyed-out buff icon of the shield you should be wearing,
-- built as the game's own buff icon (AuraButtonArtTemplate). What going without cost you in
-- this fight (or the last one) sits under it where a buff's time left goes; the rest is in its
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

-- What goes under the icon: this fight's loss (or the last fight's) in the shield's own
-- currency, or nil.
local function LossUnder(kind)
    local what = kind == "water" and "mana" or "damage"
    local f = ns.fight or ns.lastFight
    local n = f and f[what] or 0
    if n < 1 then return nil end
    return ns.Short(n)
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
        local this = ns.fight and "this fight" or "last fight"
        GameTooltip:AddDoubleLine("Lost " .. this, ns.LostText(f), C(NORMAL), C(WHITE))
        local up = ns.Uptime(f)
        if up then GameTooltip:AddDoubleLine("Shield up", ns.Pct(up) .. " of it", C(NORMAL), C(WHITE)) end
        local spring = ns.SpringUptime(f)
        if spring then GameTooltip:AddDoubleLine("Mana Spring on you", ns.Pct(spring) .. " of it", C(NORMAL), C(WHITE)) end
        local i = ns.fight and ns.fightInfo or f
        local low = {}
        if i and i.lowMana then low[#low + 1] = ns.Pct(i.lowMana) .. " mana" end
        if i and i.lowHealth then low[#low + 1] = ns.Pct(i.lowHealth) .. " health" end
        if #low > 0 then GameTooltip:AddDoubleLine("Lowest", table.concat(low, ", "), C(NORMAL), C(WHITE)) end
    else
        GameTooltip:AddLine("No fight yet since you logged in.", C(WHITE))
    end
    local n, damage, mana, of, spring = ns.RecentHurt()
    if n > 0 then
        GameTooltip:AddLine(("%d of your last %d fights took you below %d%% with %s: %s."):format(
            n, of, ns.db.hurtPct, ns.MissingText(), ns.LostText({ damage = damage, mana = mana, spring = spring })), C(GRAY), true)
    end
    local totem = ns.SpringSummary()
    if totem then GameTooltip:AddLine(totem, C(GRAY), true) end
    GameTooltip:AddLine(" ")
    if LossUnder(kind) then GameTooltip:AddLine(("The number under the icon: lost %s."):format(ns.fight and "this fight" or "last fight"), C(GRAY)) end
    GameTooltip:AddLine("Left-click: the last fight, in chat", C(GRAY))
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
            if HasKit() then ns.Kit.Open() else ns.Print("the options window appears after a /reload.") end
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
    local under = LossUnder(kind)
    if under then
        button.Duration:SetText("-" .. under)
        button.Duration:Show()
    else
        button.Duration:Hide()
    end
    button:Show()
    holder:Show()
end
