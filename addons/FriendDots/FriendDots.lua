--[[
    Friend Dots
    Replaces the nameplates of friendly players with a small class-coloured
    dot (or a round class icon) and a hairline health indicator. Enemy
    nameplates are never touched. Made for busy fights: battlegrounds,
    arenas, world PvP.

    Blizzard's own plate is only made invisible (alpha 0) while a dot is shown
    and gets its alpha back as soon as the unit leaves or stops being friendly,
    so nothing is destroyed and other nameplate addons keep working.

    /fdots            -> current settings and the command list
    /fdots style dot|icon
    /fdots size <n>
    /fdots hp bar|fill|off
    /fdots hpfull     -> keep the health line visible at full health
    /fdots names off|target|all
    /fdots where all|pvp -> everywhere, or only in battlegrounds and arenas
    /fdots group      -> highlight your own party (bigger dot, gold ring) on / off
    /fdots npcs       -> also turn friendly NPCs and pets into small green dots
    /fdots click [on|off] -> friendly nameplates click-through
    /fdots y <n>      -> move the dot up / down
    /fdots plates     -> turn friendly player nameplates on / off (the game setting)
    /fdots on|off, /fdots reset, /fdots debug
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cff7fd4ffFriend Dots|r: "
local WHITE  = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\Masks\\CircleMaskScalable"
local PLATES_CVAR = "nameplateShowFriendlyPlayers"

local LOW_HEALTH    = 0.35                 -- health line turns red below this
local DEAD_ALPHA    = 0.35                 -- dead or offline
local NPC_COLOR     = { 0.35, 0.85, 0.40 }
local UNKNOWN_COLOR = { 0.80, 0.80, 0.80 } -- class not known (yet)
local HP_GREEN      = { 0.25, 0.90, 0.35 }
local HP_RED        = { 1.00, 0.20, 0.15 }
local GROUP_COLOR   = { 1.00, 0.82, 0.20 } -- ring on members of your own party
local GROUP_SCALE   = 1.25                 -- their dot is this much bigger
local LEVEL_NORMAL, LEVEL_GROUP, LEVEL_TARGET = 5, 10, 15   -- frame level above the plate

local DEFAULTS = {
    enabled      = true,
    style        = "dot",   -- "dot" | "icon"
    dotSize      = 12,
    iconSize     = 22,
    hp           = "bar",   -- "bar" (line under the dot) | "fill" (the dot drains) | "off"
    hpAlways     = false,   -- false: the line only shows when health is missing
    names        = "off",   -- "off" | "target" | "all"
    where        = "all",   -- "all" | "pvp" (battlegrounds and arenas only)
    groupRing    = true,
    npcs         = false,
    clickThrough = true,
    yOffset      = 0,
}
local CHOICES = {
    style = { dot = true, icon = true },
    hp    = { bar = true, fill = true, off = true },
    names = { off = true, target = true, all = true },
    where = { all = true, pvp = true },
}

local db
local floor, max, min = math.floor, math.max, math.min

---------------------------------------------------------------------------
-- Secret values: in combat this client hides some unit data from addons.
-- Testing or comparing a secret throws, so anything we branch on goes
-- through Known() (secret -> nil = "unknown"). Widgets may DISPLAY secrets,
-- so health goes straight from the API into status bars and alphas.
---------------------------------------------------------------------------
local issecret = issecretvalue
local function Known(v)
    if issecret and issecret(v) then return nil end
    return v
end

local function PlainNumber(v)
    if issecret and issecret(v) then return false end
    return type(v) == "number"
end

-- Alpha from a boolean that may be secret.
local function AlphaFromBool(region, value, onAlpha, offAlpha)
    if issecret and issecret(value) then
        if region.SetAlphaFromBoolean then
            region:SetAlphaFromBoolean(value, onAlpha, offAlpha)
        else
            region:SetAlpha(offAlpha)
        end
    else
        region:SetAlpha(value and onAlpha or offAlpha)
    end
end

---------------------------------------------------------------------------
-- Health curves (health percent -> alpha), evaluated by the client so the
-- addon never reads the health itself.
---------------------------------------------------------------------------
local notFullCurve, lowCurve   -- nil = not built yet, false = unavailable
local function Curves()
    if notFullCurve ~= nil then return notFullCurve, lowCurve end
    notFullCurve, lowCurve = false, false
    if UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType then
        local ok, a, b = pcall(function()
            local notFull = C_CurveUtil.CreateCurve()
            notFull:SetType(Enum.LuaCurveType.Step)
            notFull:AddPoint(0.0, 1)
            notFull:AddPoint(1.0, 0)
            -- Linear with a very short ramp: the same shape BetterBlizzPlates
            -- uses for its execute indicator on this client.
            local low = C_CurveUtil.CreateCurve()
            low:SetType(Enum.LuaCurveType.Linear)
            low:AddPoint(0.0, 1)
            low:AddPoint(LOW_HEALTH, 1)
            low:AddPoint(LOW_HEALTH + 0.001, 0)
            low:AddPoint(1.0, 0)
            return notFull, low
        end)
        if ok and a and b then notFullCurve, lowCurve = a, b end
    end
    return notFullCurve, lowCurve
end

---------------------------------------------------------------------------
-- Which nameplates get a dot
---------------------------------------------------------------------------
-- "where pvp": only inside battlegrounds and arenas.
local function InScope()
    if db.where ~= "pvp" or not IsInInstance then return true end
    local inInstance, kind = IsInInstance()
    return (inInstance and (kind == "pvp" or kind == "arena")) and true or false
end

-- "player" / "npc"  -> gets a dot
-- false             -> known not to be ours: Blizzard's plate
-- nil               -> the client hides what we need to know: keep the plate
--                      as it is now and look again later
-- A dot needs positive proof of a friend. "Can't be attacked" alone is not
-- proof (an unflagged player of the other faction can't be attacked either).
local function Classify(unit)
    local isSelf = Known(UnitIsUnit(unit, "player"))
    if isSelf then return false end                            -- personal resource plate
    local attackable = Known(UnitCanAttack("player", unit))
    if attackable then return false end                        -- enemies, duel partners
    local friend = Known(UnitIsFriend("player", unit))
    if friend == false then return false end
    if friend == nil or isSelf == nil then return nil end
    local isPlayer = Known(UnitIsPlayer(unit))
    if isPlayer == nil then return nil end
    if isPlayer then return "player" end
    return db.npcs and "npc" or false
end

local function ClassOf(unit)
    local _, classFile = UnitClass(unit)
    classFile = Known(classFile)
    if type(classFile) == "string" then return classFile end
end

local function ClassColor(classFile)
    local c = classFile and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
                          or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]))
    if c then return c.r, c.g, c.b end
    return UNKNOWN_COLOR[1], UNKNOWN_COLOR[2], UNKNOWN_COLOR[3]
end

local atlasChecked = {}
local function ClassAtlas(classFile)
    if not classFile then return end
    local atlas = "classicon-" .. classFile:lower()
    local ok = atlasChecked[atlas]
    if ok == nil then
        ok = true
        if C_Texture and C_Texture.GetAtlasInfo then
            ok = C_Texture.GetAtlasInfo(atlas) ~= nil
        end
        atlasChecked[atlas] = ok
    end
    if ok then return atlas end
end

---------------------------------------------------------------------------
-- Hiding / restoring Blizzard's plate
---------------------------------------------------------------------------
local hiddenUF  = setmetatable({}, { __mode = "k" })
local hookedUF  = setmetatable({}, { __mode = "k" })
local lastAlpha = setmetatable({}, { __mode = "k" }) -- alpha to give back
local markerOf  = setmetatable({}, { __mode = "k" }) -- saved raid marker layout
local enforcing = false

local function Forbidden(frame)
    return not frame or (frame.IsForbidden and frame:IsForbidden())
end

-- Raid target markers (skull, star...) matter in PvP: Blizzard's own marker
-- stays visible and sits above the dot while the rest of the plate is hidden.
local function MarkerParts(uf)
    local holder = uf.RaidTargetFrame
    if type(holder) ~= "table" or Forbidden(holder) then return end
    local icon = holder.RaidTargetIcon
    if type(icon) ~= "table" then return end
    return holder, icon
end

local function MoveMarker(uf, w)
    local holder, icon = MarkerParts(uf)
    if not icon then return end
    pcall(function()
        if not markerOf[uf] then
            local saved = { points = {} }
            if holder.IsIgnoringParentAlpha then
                saved.ignore = holder:IsIgnoringParentAlpha() and true or false
            end
            for i = 1, (icon:GetNumPoints() or 0) do
                local point, rel, relPoint, x, y = icon:GetPoint(i)
                saved.points[i] = { point, rel, relPoint, x, y }
            end
            markerOf[uf] = saved
        end
        holder:SetIgnoreParentAlpha(true)
        icon:ClearAllPoints()
        icon:SetPoint("BOTTOM", w, "TOP", 0, (db.names == "off" and 3 or 16) + (w.inParty and 4 or 0))
    end)
end

local function RestoreMarker(uf)
    local saved = markerOf[uf]
    if not saved then return end
    markerOf[uf] = nil
    local holder, icon = MarkerParts(uf)
    if not icon then return end
    pcall(function()
        holder:SetIgnoreParentAlpha(saved.ignore or false)
        if #saved.points > 0 then
            icon:ClearAllPoints()
            for _, p in ipairs(saved.points) do
                icon:SetPoint(p[1], p[2], p[3], p[4], p[5])
            end
        end
    end)
end

local function HideBlizzard(uf)
    if Forbidden(uf) then return end
    if not hiddenUF[uf] then
        local alpha = uf.GetAlpha and uf:GetAlpha()
        lastAlpha[uf] = PlainNumber(alpha) and alpha or nil
    end
    hiddenUF[uf] = true
    if not hookedUF[uf] then
        hookedUF[uf] = true
        -- Blizzard (or another addon) may set the alpha again: keep it at 0
        -- for as long as our dot stands in for this plate, and remember what
        -- was asked for so it can be given back afterwards.
        hooksecurefunc(uf, "SetAlpha", function(self, alpha)
            if hiddenUF[self] and not enforcing then
                if PlainNumber(alpha) then lastAlpha[self] = alpha end
                enforcing = true
                self:SetAlpha(0)
                enforcing = false
            end
        end)
    end
    enforcing = true
    uf:SetAlpha(0)
    enforcing = false
end

local function ShowBlizzard(uf)
    if not uf or not hiddenUF[uf] then return end
    hiddenUF[uf] = nil
    local alpha = lastAlpha[uf]
    lastAlpha[uf] = nil
    if Forbidden(uf) then return end
    uf:SetAlpha(alpha or 1)
    RestoreMarker(uf)
end

---------------------------------------------------------------------------
-- The dot
---------------------------------------------------------------------------
local widgets = setmetatable({}, { __mode = "k" }) -- nameplate -> our frame
local active  = {}                                 -- unit token -> our frame
ns.widgets, ns.active = widgets, active

local function Circle(owner, layer, sublevel)
    local tex = owner:CreateTexture(nil, layer, nil, sublevel or 0)
    tex:SetTexture(WHITE)
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return tex
end

local function SetPad(tex, anchor, pad)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
    tex:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
end

local function CreateWidget(plate)
    local w = CreateFrame("Frame", nil, plate)
    w.plate = plate
    w:SetFrameLevel((plate:GetFrameLevel() or 0) + LEVEL_NORMAL)

    -- From the outside in; the first two only show on your target, the next
    -- two only on members of your own party.
    w.targetEdge = Circle(w, "BACKGROUND", -5)   -- dark edge so the ring reads on snow
    w.targetEdge:SetVertexColor(0, 0, 0, 0.9)
    w.targetEdge:SetAlpha(0)
    w.targetRing = Circle(w, "BACKGROUND", -4)   -- white ring
    w.targetRing:SetVertexColor(1, 1, 1, 1)
    w.targetRing:SetAlpha(0)
    w.groupEdge = Circle(w, "BACKGROUND", -3)    -- dark edge around the gold
    w.groupEdge:SetVertexColor(0, 0, 0, 0.9)
    w.groupEdge:SetAlpha(0)
    w.groupRing = Circle(w, "BACKGROUND", -2)    -- gold: in your own party
    w.groupRing:SetVertexColor(GROUP_COLOR[1], GROUP_COLOR[2], GROUP_COLOR[3], 1)
    w.groupRing:SetAlpha(0)
    w.ring = Circle(w, "BACKGROUND", 1)          -- thin outline

    -- The dot itself is a vertical status bar clipped to a circle: full in
    -- "bar" mode, draining from the top in "fill" mode.
    local fill = CreateFrame("StatusBar", nil, w)
    fill:SetAllPoints(w)
    fill:SetOrientation("VERTICAL")
    fill:SetStatusBarTexture(WHITE)
    fill:SetMinMaxValues(0, 1)
    fill:SetValue(1)
    local mask = fill:CreateMaskTexture()
    mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(fill)
    local bg = fill:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE)
    bg:SetAllPoints(fill)
    bg:AddMaskTexture(mask)
    local fillTex = fill:GetStatusBarTexture()
    if fillTex and fillTex.AddMaskTexture then fillTex:AddMaskTexture(mask) end
    local icon = fill:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(fill)
    icon:AddMaskTexture(mask)
    icon:Hide()
    w.fill, w.bg, w.icon = fill, bg, icon

    -- Health line: 2 px of health inside a 1 px dark edge.
    local hp = CreateFrame("Frame", nil, w)
    hp:SetPoint("TOP", w, "BOTTOM", 0, -2)
    local hpBg = hp:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints(hp)
    hpBg:SetColorTexture(0, 0, 0, 0.85)
    local function Bar(level, color)
        local bar = CreateFrame("StatusBar", nil, hp)
        bar:SetPoint("TOPLEFT", hp, "TOPLEFT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -1, 1)
        bar:SetStatusBarTexture(WHITE)
        bar:SetStatusBarColor(color[1], color[2], color[3])
        bar:SetFrameLevel((hp:GetFrameLevel() or 0) + level)
        return bar
    end
    w.hp = hp
    w.hpBar = Bar(1, HP_GREEN)
    w.hpLow = Bar(2, HP_RED)     -- same value on top, visible only at low health
    w.hpLow:SetAlpha(0)

    local name = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("BOTTOM", w, "TOP", 0, 3)
    local font, fontSize = name:GetFont()
    if font and fontSize then name:SetFont(font, fontSize, "OUTLINE") end
    name:Hide()
    w.name = name

    w:Hide()
    widgets[plate] = w
    return w
end

---------------------------------------------------------------------------
-- Health
---------------------------------------------------------------------------
local hpFailures, hpBroken, lastError = 0, false, nil
local RefreshAll -- forward

local function SetHealth(w)
    local unit = w.unit
    local hp, hpMax = UnitHealth(unit), UnitHealthMax(unit)
    if w.hpMode == "fill" then
        w.fill:SetMinMaxValues(0, hpMax)
        w.fill:SetValue(hp)
        return
    end
    w.hpBar:SetMinMaxValues(0, hpMax)
    w.hpBar:SetValue(hp)
    w.hpLow:SetMinMaxValues(0, hpMax)
    w.hpLow:SetValue(hp)
    local notFull, low = Curves()
    if low then
        w.hpLow:SetAlpha(UnitHealthPercent(unit, true, low))
    else
        w.hpLow:SetAlpha(0)
    end
    if db.hpAlways or not notFull then
        w.hp:SetAlpha(1)
    else
        w.hp:SetAlpha(UnitHealthPercent(unit, true, notFull))
    end
end

local function UpdateHealth(w)
    if w.hpMode ~= "off" and not hpBroken then
        local ok, err = pcall(SetHealth, w)
        if ok then
            hpFailures = 0
        else
            -- Never spam errors from a health event: three failures in a row
            -- switch the health indicator off.
            hpFailures, lastError = hpFailures + 1, tostring(err)
            if hpFailures >= 3 then
                hpBroken = true
                print(PREFIX .. "the health indicator hit an error and is off. /fdots hp bar tries again, /fdots debug shows the error.")
                RefreshAll()
                return
            end
        end
    end
    -- Dead (also when the client hides it) or offline: dimmed.
    AlphaFromBool(w, UnitIsDeadOrGhost(w.unit), DEAD_ALPHA, 1)
    if UnitIsConnected and Known(UnitIsConnected(w.unit)) == false then
        w:SetAlpha(DEAD_ALPHA)
    end
end

local function UpdateTarget(w)
    local isTarget = UnitIsUnit(w.unit, "target")
    AlphaFromBool(w.targetRing, isTarget, 1, 0)
    AlphaFromBool(w.targetEdge, isTarget, 1, 0)
    if db.names == "target" then AlphaFromBool(w.name, isTarget, 1, 0) end
end

-- Is this dot a member of your own party? true / false, or a hidden value
-- that the rings can still display.
local function PartyState(w)
    if not (db.groupRing and w.kind == "player" and UnitInParty) then return false end
    local party = UnitInParty(w.unit)
    if issecret and issecret(party) then return party end
    return party and true or false
end

-- Party members are drawn above other dots, your target above everything.
local function BaseLevel(w)
    return (w.plate:GetFrameLevel() or 0) + (w.inParty and LEVEL_GROUP or LEVEL_NORMAL)
end

-- Asking the client for the target's plate works even when "is this my
-- target" is hidden per unit.
local raised
local function RaiseTarget()
    pcall(function()
        if raised and raised.plate then
            raised:SetFrameLevel(BaseLevel(raised))
        end
        raised = nil
        local plate = C_NamePlate.GetNamePlateForUnit("target")
        if Forbidden(plate) then return end
        local w = widgets[plate]
        if w and w.unit then
            w:SetFrameLevel((plate:GetFrameLevel() or 0) + LEVEL_TARGET)
            raised = w
        end
    end)
end

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------
local function Style(w)
    local unit = w.unit
    -- The class is remembered per dot: if the client hides it mid-fight, a
    -- dot that already had its colour keeps it.
    local classFile = (w.kind == "player") and (ClassOf(unit) or w.classFile) or nil
    w.classFile = classFile
    local r, g, b
    if w.kind == "npc" then
        r, g, b = NPC_COLOR[1], NPC_COLOR[2], NPC_COLOR[3]
    else
        r, g, b = ClassColor(classFile)
    end

    -- Icons need a known class; otherwise (and for NPCs) fall back to a dot.
    local atlas = (db.style == "icon" and w.kind == "player") and ClassAtlas(classFile) or nil
    local size = atlas and db.iconSize or db.dotSize
    if w.kind == "npc" then size = max(4, floor(size * 0.7 + 0.5)) end

    -- Your own party stands out: a bigger dot, drawn above the others, inside
    -- a gold ring with a dark edge. When the game hides who is in your party
    -- only the ring is used, because that is all a hidden value can drive.
    local party = PartyState(w)
    local partyKnown = Known(party)               -- true / false / nil (hidden)
    w.inParty = (partyKnown == true)
    if w.inParty then size = floor(size * GROUP_SCALE + 0.5) end
    if raised ~= w then w:SetFrameLevel(BaseLevel(w)) end

    w:SetSize(size, size)
    w:ClearAllPoints()
    w:SetPoint("CENTER", w.plate, "CENTER", 0, db.yOffset)

    local pad = atlas and 1.5 or 1
    local outer = pad
    SetPad(w.ring, w, pad)
    if partyKnown ~= false then
        SetPad(w.groupRing, w, pad + 2)
        SetPad(w.groupEdge, w, pad + 3)
        outer = pad + 3                           -- the target ring goes around it
    end
    SetPad(w.targetRing, w, outer + 1.5)
    SetPad(w.targetEdge, w, outer + 2.5)
    AlphaFromBool(w.groupRing, party, 1, 0)
    AlphaFromBool(w.groupEdge, party, 1, 0)
    if atlas then
        w.ring:SetVertexColor(r, g, b, 1)         -- class-coloured rim around the icon
        w.icon:SetAtlas(atlas)
        w.icon:Show()
    else
        w.ring:SetVertexColor(0, 0, 0, 0.9)
        w.icon:Hide()
    end
    -- The drained part in fill mode: dark, but never as dark as the outline.
    w.bg:SetVertexColor(r * 0.3 + 0.08, g * 0.3 + 0.08, b * 0.3 + 0.08, 1)
    w.fill:SetStatusBarColor(r, g, b)

    local mode = db.hp
    if mode == "fill" and atlas then mode = "bar" end   -- an icon can't drain
    if hpBroken then mode = "off" end
    w.hpMode = mode
    if mode ~= "fill" then
        w.fill:SetMinMaxValues(0, 1)
        w.fill:SetValue(1)
    end
    if mode == "bar" then
        w.hp:SetSize(max(size, 12) + 2, 4)
        w.hp:Show()
    else
        w.hp:Hide()
    end

    if db.names == "off" then
        w.name:Hide()
    else
        w.name:ClearAllPoints()                   -- clear of the gold ring
        w.name:SetPoint("BOTTOM", w, "TOP", 0, w.inParty and 7 or 3)
        w.name:SetText(UnitName(unit))            -- may be secret: fine for a widget
        w.name:SetTextColor(r, g, b)
        w.name:SetAlpha(1)
        w.name:Show()
    end

    local uf = w.plate.UnitFrame
    if uf and hiddenUF[uf] then MoveMarker(uf, w) end

    UpdateHealth(w)
    UpdateTarget(w)
end

---------------------------------------------------------------------------
-- Attach / detach
---------------------------------------------------------------------------
local function Detach(plate)
    local w = widgets[plate]
    if w then
        if w.unit and active[w.unit] == w then active[w.unit] = nil end
        w.unit, w.kind, w.classFile = nil, nil, nil
        w:Hide()
    end
    ShowBlizzard(plate.UnitFrame)
end

local function Attach(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if Forbidden(plate) then return end
    local kind = false
    if db.enabled and InScope() then kind = Classify(unit) end
    local w = widgets[plate]
    if kind == nil then
        -- Unknown right now (hidden in combat): a dot that is already up for
        -- this unit stays, anything else is left as Blizzard's plate. Combat
        -- ending looks again.
        if w and w.unit == unit and active[unit] == w then
            Style(w)
        elseif w and w.unit then
            Detach(plate)
        end
        return
    end
    if not kind or Forbidden(plate.UnitFrame) then
        Detach(plate)
        return
    end
    w = w or CreateWidget(plate)
    if w.unit and w.unit ~= unit then
        if active[w.unit] == w then active[w.unit] = nil end
        w.classFile = nil
    end
    local old = active[unit]
    if old and old ~= w then Detach(old.plate) end    -- the token moved to another plate
    w.unit, w.kind = unit, kind
    active[unit] = w
    HideBlizzard(plate.UnitFrame)
    Style(w)
    w:Show()
    RaiseTarget()
end

function RefreshAll()
    if not db then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then Attach(unit) end
    end
end

---------------------------------------------------------------------------
-- Click-through: an invisible plate should not eat clicks meant for the
-- world. The hit area is one client-wide setting for all friendly plates and
-- can only be changed out of combat. Other nameplate addons
-- (BetterBlizzPlates) write the same setting, so their writes are watched:
-- ours is put back while click-through is wanted, and theirs is restored
-- when it is not.
---------------------------------------------------------------------------
local clickApplied, clickPending = false, false
local ourWrite, lastOther = false, nil
local fightStart, fightCount, fightLost = 0, 0, false

local function ApplyClick()
    if not (C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets
            and Enum and Enum.NamePlateType and Enum.NamePlateType.Friendly) then
        return false
    end
    local want = db.enabled and db.clickThrough and InScope()
    if not want and not clickApplied then       -- never ours: leave it
        clickPending = false
        return true
    end
    if InCombatLockdown() then
        clickPending = true
        return true
    end
    clickPending = false
    local l, r, t, b = 10000, 10000, 10000, 10000
    if not want then
        if lastOther then
            l, r, t, b = lastOther[1], lastOther[2], lastOther[3], lastOther[4]
        else
            l, r, t, b = 0, 0, 0, 0
        end
    end
    ourWrite = true
    local ok = pcall(C_NamePlateManager.SetNamePlateHitTestInsets, Enum.NamePlateType.Friendly, l, r, t, b)
    ourWrite = false
    if ok then clickApplied = want and true or false end
    return ok
end

local function OnInsetsWritten(kind, l, r, t, b)
    if ourWrite or not db then return end
    if not (Enum and Enum.NamePlateType) or kind ~= Enum.NamePlateType.Friendly then return end
    lastOther = { l, r, t, b }
    if l == 10000 and r == 10000 and t == 10000 and b == 10000 then return end   -- same as ours
    clickApplied = false
    if not (db.enabled and db.clickThrough and InScope()) then return end
    -- Put ours back, but never in an endless tug-of-war with another addon.
    local now = GetTime and GetTime() or 0
    if now - fightStart > 10 then fightStart, fightCount = now, 0 end
    fightCount = fightCount + 1
    if fightCount > 6 then
        if not fightLost then
            fightLost = true
            print(PREFIX .. "another addon keeps changing the friendly nameplate click area, so click-through is left to it. Turn on its own friendly click-through option, or use /fdots click off.")
        end
        return
    end
    if InCombatLockdown() then
        clickPending = true
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0, ApplyClick)
    end
end

if C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets and hooksecurefunc then
    pcall(hooksecurefunc, C_NamePlateManager, "SetNamePlateHitTestInsets", OnInsetsWritten)
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
local function InitDB()
    if type(FriendDotsDB) ~= "table" then FriendDotsDB = {} end
    db = FriendDotsDB
    for key, value in pairs(DEFAULTS) do
        if type(db[key]) ~= type(value) then db[key] = value end
    end
    for key, allowed in pairs(CHOICES) do
        if not allowed[db[key]] then db[key] = DEFAULTS[key] end
    end
    ns.db = db
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("UNIT_MAXHEALTH")
f:RegisterEvent("UNIT_CONNECTION")
f:RegisterEvent("UNIT_FACTION")
f:RegisterEvent("UNIT_NAME_UPDATE")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
-- Arena rounds can swap who is on your team. Registered defensively: an
-- event name this client doesn't know must not stop the addon from loading.
pcall(f.RegisterEvent, f, "PVP_MATCH_STATE_CHANGED")
pcall(f.RegisterEvent, f, "ARENA_OPPONENT_UPDATE")

local function IsPlateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate") ~= nil
end

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDB()
            if ns.Kit and ns.Options then         -- options window and minimap button
                local ok, err = pcall(ns.Options.Init)
                if not ok then print(PREFIX .. "options error: " .. tostring(err)) end
            end
        end
        return
    end
    if not db then return end

    if event == "NAME_PLATE_UNIT_ADDED" then
        Attach(arg1)

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local w = active[arg1]
        if w then Detach(w.plate) end

    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then
        local w = active[arg1]
        if w then UpdateHealth(w) end

    elseif event == "UNIT_FACTION" then
        -- Duels, mind control, PvP flags: friend and foe can swap.
        if arg1 == "player" then
            RefreshAll()
        elseif IsPlateUnit(arg1) then
            Attach(arg1)
        end

    elseif event == "UNIT_NAME_UPDATE" then
        local w = active[arg1]
        if w then
            Style(w)                              -- class arrives with the name
        elseif IsPlateUnit(arg1) then
            Attach(arg1)                          -- may have been unknown until now
        end

    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, w in pairs(active) do UpdateTarget(w) end
        RaiseTarget()

    elseif event == "GROUP_ROSTER_UPDATE" then
        for _, w in pairs(active) do Style(w) end     -- party size, ring and layer

    elseif event == "PVP_MATCH_STATE_CHANGED" or event == "ARENA_OPPONENT_UPDATE" then
        RefreshAll()

    elseif event == "PLAYER_REGEN_ENABLED" then
        if clickPending then ApplyClick() end
        -- Plates that came up while the client was hiding who they belong to
        -- (and dots that stayed grey) get another look now.
        RefreshAll()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- A moment later, so this lands after other nameplate addons' setup.
        C_Timer.After(1, function()
            ApplyClick()
            RefreshAll()
        end)
        local platesOff = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(PLATES_CVAR) == "0"
        if platesOff and not db.hinted then
            db.hinted, db.welcomed = true, true
            print(PREFIX .. "friendly player nameplates are off, so there are no dots yet. Type /fdots plates to turn them on. Type /fdots to see all options.")
        elseif not db.welcomed then
            db.welcomed = true
            print(PREFIX .. "loaded. Dots appear on friendly players near you. Type /fdots to see the options.")
        end
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function PrintStatus()
    print(PREFIX .. (db.enabled and "on" or "OFF") .. "  |  style " .. db.style
        .. " (dot " .. db.dotSize .. ", icon " .. db.iconSize .. ")"
        .. "  |  hp " .. db.hp .. (hpBroken and " (off after errors)" or (db.hpAlways and ", always shown" or ", only when hurt"))
        .. "  |  names " .. db.names
        .. "  |  where " .. db.where
        .. "  |  party highlight " .. OnOff(db.groupRing)
        .. "  |  npcs " .. OnOff(db.npcs)
        .. "  |  click-through " .. OnOff(db.clickThrough) .. (clickPending and " (changes after combat)" or "")
        .. "  |  y " .. db.yOffset)
end

local function PrintHelp()
    print(PREFIX .. "commands:")
    print("  /fdots style dot|icon   -  /fdots size <4-64>   -  /fdots y <-100..100>")
    print("  /fdots hp bar|fill|off   -  /fdots hpfull (show the health line at full health)")
    print("  /fdots names off|target|all   -  /fdots where all|pvp (pvp = only battlegrounds and arenas)")
    print("  /fdots group (your own party: bigger dot, gold ring)   -  /fdots npcs   -  /fdots click [on|off]")
    print("  /fdots plates (friendly player nameplates on/off)   -  /fdots on|off   -  /fdots reset   -  /fdots debug")
    print("  /fdots config (options window)   -  /fdots minimap (minimap button on/off)")
end

local function ClickNote()
    if clickPending then print(PREFIX .. "click-through changes when you leave combat.") end
end

local function Describe(v)
    if issecret and issecret(v) then return "HIDDEN (secret)" end
    return tostring(v)
end

---------------------------------------------------------------------------
-- For Options.lua: the same changes the slash commands make
---------------------------------------------------------------------------
function ns.Print(msg) print(PREFIX .. tostring(msg)) end

-- Stores one setting and redraws every dot.
function ns.Set(key, value)
    if not db or DEFAULTS[key] == nil then return end
    local old = db[key]
    db[key] = value
    if key == "hp" then
        hpBroken, hpFailures = false, 0       -- give a broken indicator another try
    elseif key == "clickThrough" then
        if ApplyClick() == false then
            db[key] = old
            print(PREFIX .. "this client has no way to change the nameplate click area.")
        end
        ClickNote()
    elseif key == "enabled" or key == "where" then
        ApplyClick()
        ClickNote()
    end
    RefreshAll()
end

function ns.Reset()
    for key, value in pairs(DEFAULTS) do db[key] = value end
    db.minimap = nil
    hpBroken, hpFailures = false, 0
    ApplyClick()
    ClickNote()
    if ns.Kit then ns.Kit.RefreshMinimap() end
    RefreshAll()
end

-- The game's own "friendly player nameplates" setting.
function ns.PlatesShown()
    return (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(PLATES_CVAR) == "1") and true or false
end

function ns.SetPlates(turnOn)
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    if InCombatLockdown() then
        print(PREFIX .. "nameplates can't be switched in combat.")
        return
    end
    C_CVar.SetCVar(PLATES_CVAR, turnOn and "1" or "0")
    print(PREFIX .. "friendly player nameplates " .. OnOff(turnOn) .. ".")
end

-- Kit.lua and Options.lua are new in 1.2.0. The game only finds new files after a full restart,
-- so right after an update a /reload runs this file without them: say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    print(PREFIX .. "the options window and the minimap button appear after you restart the game once "
        .. "(this update added new files, and /reload does not load those).")
    return false
end

local function SyncOptions()                  -- an open options window follows what was typed
    if ns.Kit then ns.Kit.Sync() end
end

SLASH_FRIENDDOTS1 = "/fdots"
SLASH_FRIENDDOTS2 = "/frienddots"
SlashCmdList.FRIENDDOTS = function(msg)
    if not db then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")

    if cmd == "" or cmd == "help" or cmd == "status" then
        PrintStatus()
        PrintHelp()
        return

    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if HasKit() then ns.Kit.Open() end
        return

    elseif cmd == "minimap" then
        if not HasKit() then return end
        ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
        print(PREFIX .. "minimap button " .. OnOff(ns.Kit.MinimapShown()) .. ".")
        SyncOptions()
        return

    elseif cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        ApplyClick()
        ClickNote()

    elseif CHOICES[cmd] then
        if not CHOICES[cmd][arg] then
            local list = {}
            for choice in pairs(CHOICES[cmd]) do list[#list + 1] = choice end
            table.sort(list)
            print(PREFIX .. "/fdots " .. cmd .. " " .. table.concat(list, "|"))
            return
        end
        db[cmd] = arg
        if cmd == "hp" then
            hpBroken, hpFailures = false, 0       -- give a broken indicator another try
        elseif cmd == "where" then
            ApplyClick()
            ClickNote()
        end

    elseif cmd == "size" then
        local n = tonumber(arg)
        if not n then print(PREFIX .. "/fdots size <4-64>  (sets the size of the current style)") return end
        n = floor(max(4, min(64, n)) + 0.5)
        if db.style == "icon" then db.iconSize = n else db.dotSize = n end

    elseif cmd == "y" then
        local n = tonumber(arg)
        if not n then print(PREFIX .. "/fdots y <-100..100>") return end
        db.yOffset = floor(max(-100, min(100, n)) + 0.5)

    elseif cmd == "hpfull" then
        db.hpAlways = not db.hpAlways

    elseif cmd == "npcs" then
        db.npcs = not db.npcs

    elseif cmd == "group" then
        db.groupRing = not db.groupRing

    elseif cmd == "click" then
        local old = db.clickThrough
        if arg == "on" then
            db.clickThrough = true
        elseif arg == "off" then
            db.clickThrough = false
        else
            db.clickThrough = not old
        end
        if ApplyClick() == false then
            db.clickThrough = old
            print(PREFIX .. "this client has no way to change the nameplate click area.")
        end
        ClickNote()

    elseif cmd == "plates" then
        ns.SetPlates(not ns.PlatesShown())
        SyncOptions()
        return

    elseif cmd == "reset" then
        ns.Reset()

    elseif cmd == "debug" then
        local shown = 0
        for _ in pairs(active) do shown = shown + 1 end
        local notFull = Curves()
        print(PREFIX .. "build " .. tostring((select(4, GetBuildInfo()))) .. ", dots shown: " .. shown
            .. ", in scope: " .. tostring(InScope())
            .. ", health curves: " .. (notFull and "yes" or "no")
            .. ", click-through applied: " .. tostring(clickApplied)
            .. ", plates cvar: " .. tostring(C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(PLATES_CVAR)))
        if lastError then print(PREFIX .. "last health error: " .. lastError) end
        if UnitExists("target") then
            print(PREFIX .. "target: friend = " .. Describe(UnitIsFriend("player", "target"))
                .. ", attackable = " .. Describe(UnitCanAttack("player", "target"))
                .. ", player = " .. Describe(UnitIsPlayer("target"))
                .. ", class = " .. Describe((select(2, UnitClass("target"))))
                .. ", health = " .. Describe(UnitHealth("target")))
        end
        return

    else
        PrintHelp()
        return
    end

    RefreshAll()
    PrintStatus()
    SyncOptions()
end
