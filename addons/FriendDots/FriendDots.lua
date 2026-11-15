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
    /fdots group      -> highlight your own party (bigger dot, drawn on top) on / off
    /fdots npcs       -> also turn friendly NPCs and pets into small green dots
    /fdots click [on|off] -> friendly nameplates click-through
    /fdots combat     -> friendly player nameplates (and so the dots) only in combat
    /fdots y <n>      -> move the dot up / down
    /fdots plates     -> turn friendly player nameplates on / off (the game setting)
    /fdots on|off, /fdots reset, /fdots debug
    /fdots preview    -> one dot of each kind in the middle of the screen, for a minute
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cff7fd4ffFriend Dots|r: "
local WHITE  = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\Masks\\CircleMaskScalable"
local PLATES_CVAR = "nameplateShowFriendlyPlayers"

-- The look copies this client's own nameplate (Blizzard_NamePlates on the
-- "forever" branch): its health bar art, its 1 px border at 80% black, its
-- white border on your target, its name font. Party members are told apart
-- the way the world map does it (GroupMembersDataProvider): by size only.
local BAR_ATLAS    = "UI-HUD-CoolDownManager-Bar"               -- the nameplate's health bar
local BAR_TEXTURE  = "Interface\\TargetingFrame\\UI-StatusBar"  -- fallback if the atlas is missing
local NAME_FONT    = "SystemFont_NamePlate_Outlined"            -- the nameplate's name font
local BORDER_ALPHA = 0.8      -- NamePlateFriendlyFrameOptions.defaultBorderColor (black, 0.8)
local NAME_GAP     = 4        -- the 2 px target border + the game's 2 px name spacing
local MARKER_SIZE  = 22       -- the game's RaidTargetFrame size
local MARKER_GAP   = 10       -- the game's gap between a name and the raid marker above it

-- Colours come from the game's own constants where it has one, so the dots
-- read like the rest of the UI; the numbers are only fallbacks.
local function GameColor(c, r, g, b)
    if type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { r, g, b }
end

local DEAD_ALPHA    = 0.35                 -- dead or offline
local NPC_COLOR     = GameColor(FACTION_BAR_COLORS and FACTION_BAR_COLORS[5], 0.00, 0.60, 0.10) -- "friendly"
local UNKNOWN_COLOR = GameColor(GRAY_FONT_COLOR, 0.50, 0.50, 0.50)  -- class not known (yet)
local TARGET_COLOR  = GameColor(NamePlateConstants and NamePlateConstants.TARGET_BORDER_COLOR, 1.00, 1.00, 1.00)
local GROUP_SCALE   = 11 / 8.25            -- world map: party pins 11, raid pins 8.25
local LEVEL_NORMAL, LEVEL_GROUP, LEVEL_TARGET = 5, 10, 15   -- frame level above the plate

local DEFAULTS = {
    enabled      = true,
    style        = "dot",   -- "dot" | "icon"
    dotSize      = 12,
    iconSize     = 22,
    hp           = "bar",   -- "bar" (line under the dot) | "fill" (the dot drains) | "off"
    hpAlways     = false,   -- false: the line only shows when health is missing
    names        = "all",   -- "off" | "target" | "all"
    where        = "all",   -- "all" | "pvp" (battlegrounds and arenas only)
    groupRing    = true,
    combatPlates = false,   -- friendly player nameplates only while you are in combat
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
local notFullCurve   -- nil = not built yet, false = unavailable
local function Curves()
    if notFullCurve ~= nil then return notFullCurve end
    notFullCurve = false
    if UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType then
        local ok, a = pcall(function()
            local notFull = C_CurveUtil.CreateCurve()
            notFull:SetType(Enum.LuaCurveType.Step)
            notFull:AddPoint(0.0, 1)
            notFull:AddPoint(1.0, 0)
            return notFull
        end)
        if ok and a then notFullCurve = a end
    end
    return notFullCurve
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
local function AtlasExists(atlas)
    local ok = atlasChecked[atlas]
    if ok == nil then
        ok = true
        if C_Texture and C_Texture.GetAtlasInfo then
            ok = C_Texture.GetAtlasInfo(atlas) ~= nil
        end
        atlasChecked[atlas] = ok
    end
    return ok
end

local function ClassAtlas(classFile)
    if not classFile then return end
    local atlas = "classicon-" .. classFile:lower()   -- the game's GetClassAtlas()
    if AtlasExists(atlas) then return atlas end
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
        icon:SetSize(MARKER_SIZE, MARKER_SIZE)
        -- Where the game puts it on a plate that shows only a name: above
        -- the name; above the dot when names are off.
        if db.names == "off" then
            icon:SetPoint("BOTTOM", w, "TOP", 0, NAME_GAP)
        else
            icon:SetPoint("BOTTOM", w.name, "TOP", 0, MARKER_GAP)
        end
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

local function CreateWidget(plate, sample)   -- sample: a preview dot, not tied to a nameplate
    local w = CreateFrame("Frame", nil, plate)
    w.plate = plate
    w:SetFrameLevel((plate:GetFrameLevel() or 0) + LEVEL_NORMAL)

    -- One border, as on the game's nameplate: 1 px black at 80%, and on your
    -- target a 2 px white one drawn over it (the plate's selected border).
    w.ring = Circle(w, "BACKGROUND", 1)
    w.ring:SetVertexColor(0, 0, 0, BORDER_ALPHA)
    w.targetRing = Circle(w, "BACKGROUND", 2)
    w.targetRing:SetVertexColor(TARGET_COLOR[1], TARGET_COLOR[2], TARGET_COLOR[3], 1)
    w.targetRing:SetAlpha(0)

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

    -- Health line: the nameplate's own health bar, 2 px high, in the same
    -- colour as the dot (friendly plates colour health by class), inside the
    -- plate's 1 px border at 80% black.
    local hp = CreateFrame("Frame", nil, w)
    hp:SetPoint("TOP", w, "BOTTOM", 0, -2)
    local hpBg = hp:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints(hp)
    hpBg:SetColorTexture(0, 0, 0, BORDER_ALPHA)
    local bar = CreateFrame("StatusBar", nil, hp)
    bar:SetPoint("TOPLEFT", hp, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", hp, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(BAR_TEXTURE)
    local barTex = bar:GetStatusBarTexture()
    if barTex and barTex.SetAtlas and AtlasExists(BAR_ATLAS) then barTex:SetAtlas(BAR_ATLAS) end
    bar:SetFrameLevel((hp:GetFrameLevel() or 0) + 1)
    w.hp, w.hpBar = hp, bar

    -- The nameplate's own name font (outlined), falling back to a game font.
    local name = w:CreateFontString(nil, "OVERLAY")
    if not pcall(name.SetFontObject, name, NAME_FONT) or not name:GetFont() then
        name:SetFontObject("GameFontHighlightSmall")
        local font, fontSize = name:GetFont()
        if font and fontSize then name:SetFont(font, fontSize, "OUTLINE") end
    end
    name:SetPoint("BOTTOM", w, "TOP", 0, NAME_GAP)
    name:Hide()
    w.name = name

    w:Hide()
    if not sample then widgets[plate] = w end
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
    local notFull = Curves()
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
    if db.names == "target" then AlphaFromBool(w.name, isTarget, 1, 0) end
end

-- Is this dot a member of your own party? A hidden answer counts as no:
-- size and layer can't follow a hidden value.
local function InParty(w)
    if not (db.groupRing and w.kind == "player" and UnitInParty) then return false end
    return Known(UnitInParty(w.unit)) == true
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
-- Colour, size, icon and health mode for a dot from plain facts (shared by
-- the nameplate dots and the preview).
local function Look(kind, classFile, inParty, style)
    local r, g, b
    if kind == "npc" then
        r, g, b = NPC_COLOR[1], NPC_COLOR[2], NPC_COLOR[3]
    else
        r, g, b = ClassColor(classFile)
    end

    -- Icons need a known class; otherwise (and for NPCs) fall back to a dot.
    local atlas = (style == "icon" and kind == "player") and ClassAtlas(classFile) or nil
    local size = atlas and db.iconSize or db.dotSize
    if kind == "npc" then size = max(4, floor(size * 0.7 + 0.5)) end
    -- Your own party stands out the way the world map shows it: a bigger
    -- dot (party pins 11 against raid pins 8.25).
    if inParty then size = floor(size * GROUP_SCALE + 0.5) end

    local mode = db.hp
    if mode == "fill" and atlas then mode = "bar" end   -- an icon can't drain
    if hpBroken then mode = "off" end
    return r, g, b, size, atlas, mode
end

-- Draws a dot from that look. The unit's own values (name text, health,
-- target) are set afterwards by the caller.
local function Paint(w, r, g, b, size, atlas, mode, showName)
    w:SetSize(size, size)
    SetPad(w.ring, w, 1)
    SetPad(w.targetRing, w, 2)
    if atlas then
        w.icon:SetAtlas(atlas)
        w.icon:Show()
    else
        w.icon:Hide()
    end
    -- The drained part in fill mode: dark, but never as dark as the outline.
    w.bg:SetVertexColor(r * 0.3 + 0.08, g * 0.3 + 0.08, b * 0.3 + 0.08, 1)
    w.fill:SetStatusBarColor(r, g, b)

    w.hpMode = mode
    if mode ~= "fill" then
        w.fill:SetMinMaxValues(0, 1)
        w.fill:SetValue(1)
    end
    if mode == "bar" then
        w.hp:SetSize(max(size, 12) + 2, 4)
        w.hpBar:SetStatusBarColor(r, g, b)
        w.hp:Show()
    else
        w.hp:Hide()
    end

    if showName then
        w.name:ClearAllPoints()
        w.name:SetPoint("BOTTOM", w, "TOP", 0, NAME_GAP)
        w.name:SetTextColor(r, g, b)
        w.name:SetAlpha(1)
        w.name:Show()
    else
        w.name:Hide()
    end
end

local function Style(w)
    local unit = w.unit
    -- The class is remembered per dot: if the client hides it mid-fight, a
    -- dot that already had its colour keeps it.
    local classFile = (w.kind == "player") and (ClassOf(unit) or w.classFile) or nil
    w.classFile = classFile
    w.inParty = InParty(w)
    local r, g, b, size, atlas, mode = Look(w.kind, classFile, w.inParty, db.style)

    -- Party members are drawn above the others, your target above everything.
    if raised ~= w then w:SetFrameLevel(BaseLevel(w)) end
    w:ClearAllPoints()
    w:SetPoint("CENTER", w.plate, "CENTER", 0, db.yOffset)

    Paint(w, r, g, b, size, atlas, mode, db.names ~= "off")
    if db.names ~= "off" then
        w.name:SetText(UnitName(unit))            -- may be secret: fine for a widget
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
    if ns.RepaintPreview then ns.RepaintPreview() end   -- an open preview follows the settings
end

---------------------------------------------------------------------------
-- Preview: one dot of each kind side by side on a plain frame, drawn by the
-- same code as the nameplate dots. It exists for screenshots: this client
-- hides the position of anything anchored to a nameplate from addons
-- (GetRect and friends are "secret when anchoring is secret"), so a
-- screenshot helper can't find the real dots, but it can find this frame.
-- /fdots preview shows it for a minute; with the author's LookShots helper
-- loaded it also shows by itself until LookShots has shot this version.
---------------------------------------------------------------------------
local PREVIEW_LABEL   = "preview"
local PREVIEW_SECONDS = 60
local PREVIEW_STEP    = 48          -- centre-to-centre distance of the samples
local SAMPLES = {
    { class = "MAGE",    hp = 0.6 },                    -- a friendly player
    { class = "PRIEST",  hp = 0.4, party = true },      -- your own party
    { class = "WARRIOR", hp = 0.8, target = true },     -- your target
    { class = "DRUID",   hp = 0.5, style = "icon" },    -- a class icon
    { kind = "npc",      hp = 1.0, name = "Guard" },    -- a friendly NPC
}
local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
local preview, previewAuto, previewLeft, previewTick

local function LookShotsLoaded()
    return (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("LookShots")) and true or false
end

local function PreviewShot()                  -- LookShots has a shot of this version's preview
    local done = type(LookShotsDB) == "table" and LookShotsDB.done
    local byAddon = type(done) == "table" and done[ADDON_NAME]
    local byVersion = type(byAddon) == "table" and byAddon[version or "?"]
    return type(byVersion) == "table" and byVersion[PREVIEW_LABEL] ~= nil
end

-- The nameplate dots are drawn at the plates' scale; the preview matches it
-- when a dot is up and that scale can be read, else it uses the UI's.
local function PlateScale()
    local ui = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
    if not (PlainNumber(ui) and ui > 0) then return 1 end
    for _, w in pairs(active) do
        local ok, es = pcall(w.GetEffectiveScale, w)
        if ok and PlainNumber(es) and es > 0 then return es / ui end
    end
    return 1
end

local function PaintPreview()
    local biggest = 0
    for i, s in ipairs(preview.samples) do
        local spec = SAMPLES[i]
        local kind = spec.kind or "player"
        local r, g, b, size, atlas, mode = Look(kind, spec.class, spec.party, spec.style or db.style)
        local showName = db.names ~= "off"
        Paint(s, r, g, b, size, atlas, mode, showName)
        if showName then
            local classNames = LOCALIZED_CLASS_NAMES_MALE
            s.name:SetText(spec.name or (classNames and classNames[spec.class]) or spec.class)
            if db.names == "target" and not spec.target then s.name:SetAlpha(0) end
        end
        if mode == "fill" then
            s.fill:SetMinMaxValues(0, 1)
            s.fill:SetValue(spec.hp)
        elseif mode == "bar" then
            s.hpBar:SetMinMaxValues(0, 1)
            s.hpBar:SetValue(spec.hp)
            s.hp:SetAlpha((db.hpAlways or spec.hp < 1) and 1 or 0)
        end
        s.targetRing:SetAlpha(spec.target and 1 or 0)
        s:SetAlpha(1)
        s:SetFrameLevel((preview:GetFrameLevel() or 0) + (spec.target and LEVEL_TARGET or spec.party and LEVEL_GROUP or LEVEL_NORMAL))
        s:ClearAllPoints()
        s:SetPoint("CENTER", preview, "CENTER", (i - (#SAMPLES + 1) / 2) * PREVIEW_STEP, 0)
        s:Show()
        if size > biggest then biggest = size end
    end
    -- Room for the name above and the health line below each sample.
    preview:SetSize(#SAMPLES * PREVIEW_STEP, biggest + 2 * 24)
    preview:SetScale(PlateScale())
end

local function HidePreview()
    if preview then preview:Hide() end
    previewAuto = false
end

local function ShowPreview(auto)
    if not db then return end
    if not preview then
        preview = CreateFrame("Frame", "FriendDotsPreview", UIParent)
        preview:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
        preview:SetFrameStrata("MEDIUM")
        preview.samples = {}
        for i = 1, #SAMPLES do preview.samples[i] = CreateWidget(preview, true) end
        preview:SetScript("OnUpdate", function(_, elapsed)
            previewLeft = previewLeft - (elapsed or 0)
            previewTick = previewTick - (elapsed or 0)
            if previewTick <= 0 then
                previewTick = 1
                if previewAuto and PreviewShot() then HidePreview() return end
            end
            if previewLeft <= 0 then HidePreview() end
        end)
        ns.preview = preview
    end
    previewAuto = auto and true or false
    previewLeft, previewTick = PREVIEW_SECONDS, 1
    PaintPreview()
    preview:Show()
end

function ns.RepaintPreview()
    if preview and preview:IsShown() then PaintPreview() end
end

-- At login, only for the author's screenshot helper, only once per version.
local function AutoPreview()
    if LookShotsLoaded() and not PreviewShot() and not InCombatLockdown() then ShowPreview(true) end
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets[ADDON_NAME] = {
    version = version or "?",
    frames = {
        { label = PREVIEW_LABEL, pad = 24, frame = function()
            return (preview and preview:IsShown()) and preview or nil
        end },
    },
}

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
-- Friendly nameplates only in combat: the game's own "friendly player
-- nameplates" setting is switched on as a fight starts and off when it ends.
-- It has to be switched in the moment combat starts (PLAYER_REGEN_DISABLED,
-- before the game locks protected changes), the way Leatrix Plus does it for
-- enemy plates on this client. BetterBlizzPlates saves this setting per zone
-- type and puts its own value back after zone changes and after combat, so
-- ours is written again a moment after those.
---------------------------------------------------------------------------
local platesError, platesWarned, platesRestore = nil, false, nil

local function SyncWindow()
    if ns.Kit and ns.Kit.Sync then pcall(ns.Kit.Sync) end
end

local function WritePlates(value)
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return false end
    if C_CVar.GetCVar(PLATES_CVAR) == value then return true end
    local ok, err = pcall(C_CVar.SetCVar, PLATES_CVAR, value)
    if ok and C_CVar.GetCVar(PLATES_CVAR) == value then
        SyncWindow()
        return true
    end
    platesError = ok and "the game did not take the change" or tostring(err)
    return false
end

local function CombatPlatesActive()
    return db.combatPlates and db.enabled
end

-- Out of combat the plates are off while the option is active.
local function SyncCombatPlates()
    if not db or not CombatPlatesActive() or InCombatLockdown() then return end
    WritePlates("0")
end

local function LaterSync(seconds)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, SyncCombatPlates) end
end

local function RestorePlates()
    local before = db.platesBefore or "1"
    if InCombatLockdown() then
        platesRestore = before
    else
        platesRestore = nil
        WritePlates(before)
    end
end

-- The option itself: remembers the setting it found, and puts it back when
-- the option is turned off.
local function SetCombatPlates(on)
    on = on and true or false
    if on == db.combatPlates then return end
    db.combatPlates = on
    if on then
        db.platesBefore = (C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(PLATES_CVAR)) or "1"
        platesRestore, platesWarned = nil, false
        SyncCombatPlates()
    else
        RestorePlates()
        db.platesBefore = nil
    end
end

-- The addon was switched on or off: off gives the nameplates back.
local function CombatPlatesEnabledChanged()
    if not db.combatPlates then return end
    if db.enabled then SyncCombatPlates() else RestorePlates() end
end

local function OnCombatStart()
    if not CombatPlatesActive() then return end
    if not WritePlates("1") and not platesWarned then
        platesWarned = true
        print(PREFIX .. "the game did not let Friend Dots turn friendly nameplates on as the fight started. "
            .. "/fdots debug shows why, /fdots combat turns this option off.")
    end
end

local function OnCombatEnd()
    if platesRestore then
        WritePlates(platesRestore)
        platesRestore = nil
    end
    SyncCombatPlates()
    LaterSync(0)          -- after other addons' own end-of-combat changes
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
    -- 1.4.4: names are on by default. Names were off by default before, so
    -- an earlier "off" is turned on once; switching them off later sticks.
    if not db.namesOnce then
        db.namesOnce = true
        if db.names == "off" then db.names = DEFAULTS.names end
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
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ZONE_CHANGED")
f:RegisterEvent("ZONE_CHANGED_INDOORS")
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

    elseif event == "PLAYER_REGEN_DISABLED" then
        OnCombatStart()
        HidePreview()

    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        if CombatPlatesActive() then LaterSync(2) end

    elseif event == "PLAYER_REGEN_ENABLED" then
        if clickPending then ApplyClick() end
        OnCombatEnd()
        -- Plates that came up while the client was hiding who they belong to
        -- (and dots that stayed grey) get another look now.
        RefreshAll()

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- A moment later, so this lands after other nameplate addons' setup.
        C_Timer.After(1, function()
            ApplyClick()
            SyncCombatPlates()
            RefreshAll()
            AutoPreview()
        end)
        if CombatPlatesActive() then LaterSync(2) end   -- after BetterBlizzPlates' own check
        local platesOff = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(PLATES_CVAR) == "0"
        if platesOff and not db.hinted and not db.combatPlates then
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
        .. "  |  nameplates only in combat " .. OnOff(db.combatPlates)
        .. "  |  npcs " .. OnOff(db.npcs)
        .. "  |  click-through " .. OnOff(db.clickThrough) .. (clickPending and " (changes after combat)" or "")
        .. "  |  y " .. db.yOffset)
end

local function PrintHelp()
    print(PREFIX .. "commands:")
    print("  /fdots style dot|icon   -  /fdots size <4-64>   -  /fdots y <-100..100>")
    print("  /fdots hp bar|fill|off   -  /fdots hpfull (show the health line at full health)")
    print("  /fdots names off|target|all   -  /fdots where all|pvp (pvp = only battlegrounds and arenas)")
    print("  /fdots group (your own party: bigger dot, drawn on top)   -  /fdots npcs   -  /fdots click [on|off]")
    print("  /fdots plates (friendly player nameplates on/off)   -  /fdots combat (friendly nameplates only in combat)")
    print("  /fdots on|off   -  /fdots reset   -  /fdots debug   -  /fdots preview (one dot of each kind, for a minute)")
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
    if key == "combatPlates" then
        SetCombatPlates(value)
        RefreshAll()
        return
    end
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
        if key == "enabled" then CombatPlatesEnabledChanged() end
    end
    RefreshAll()
end

function ns.Reset()
    SetCombatPlates(false)                    -- gives the nameplate setting back first
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
    if CombatPlatesActive() then
        print(PREFIX .. "\"only in combat\" is on, so they switch on and off again with your next fight. /fdots combat turns that off.")
    end
end

-- Kit.lua and Options.lua are new in 1.2.0. If the game is still running the files it loaded
-- before an update, they are missing: say so instead of erroring (on WoW Forever /reload loads them).
local function HasKit()
    if ns.Kit and ns.Options then return true end
    print(PREFIX .. "the options window and the minimap button appear after a /reload "
        .. "(this update added new files).")
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

    elseif cmd == "preview" then
        if preview and preview:IsShown() then HidePreview() else ShowPreview(false) end
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
        CombatPlatesEnabledChanged()

    elseif cmd == "combat" then
        SetCombatPlates(not db.combatPlates)
        if db.combatPlates then
            print(PREFIX .. "friendly player nameplates now turn on when a fight starts and off when it ends.")
        else
            print(PREFIX .. "friendly player nameplates are no longer switched with combat"
                .. (platesRestore and "; your setting comes back when this fight ends." or "."))
        end

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
        if platesError then print(PREFIX .. "last nameplate switch error: " .. platesError) end
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
