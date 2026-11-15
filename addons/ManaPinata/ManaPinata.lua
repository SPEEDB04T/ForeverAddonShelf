--[[
    Mana Piñata
    Hangs a swinging blue piñata over the nameplate of every enemy that has
    Judgement of Wisdom on it (any paladin's) and turns its health bar blue,
    so you can see at a glance which enemy gives mana back when you hit it.

    How it works: in fights this client hides auras from addons, so the addon
    never reads them. Each nameplate gets two of the game's own aura slots
    (AuraContainers), told to look for Judgement of Wisdom only. The game
    itself shows and hides each slot's button; the addon only drew a piñata
    on one and a blue copy of the health bar's fill on the other beforehand.

    /pinata             -> current settings and the command list
    /pinata config      -> the options window
    /pinata test        -> a test piñata on every nameplate, to place and size it
    /pinata size <n>    -> how big
    /pinata x <n>, /pinata y <n> -> move it sideways / up and down
    /pinata swing       -> swinging on / off
    /pinata bar         -> colouring the enemy's health bar blue on / off
    /pinata on|off, /pinata reset, /pinata debug
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cff59c8ffMana Piñata|r: "
local ART    = "Interface\\AddOns\\ManaPinata\\Art\\Pinata"
local LEVEL  = 6                       -- frame level above the nameplate
local SWING_DEGREES, SWING_SECONDS = 9, 1.6
local DROP_SECONDS = 0.22
local MANA_BLUE   = { 0, 0, 1 }                                   -- the game's mana bar, if PowerBarColor is missing
local BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"     -- when the bar's own can't be copied

-- The colour the game paints mana bars with, so the health bar reads as "mana".
local function ManaColor()
    local c = type(PowerBarColor) == "table" and PowerBarColor.MANA
    if type(c) == "table" and type(c.r) == "number" and type(c.g) == "number" and type(c.b) == "number" then
        return c.r, c.g, c.b
    end
    return MANA_BLUE[1], MANA_BLUE[2], MANA_BLUE[3]
end

-- Judgement of Wisdom: the debuff ranks and the IDs other aura addons list
-- under the same name. An ID that is never a debuff costs nothing here. IDs
-- seen on a real enemy out of combat are added to this (see Learn).
local WISDOM = { 20186, 20268, 20352, 20353, 20354, 20355, 25757, 25758, 27164 }
local WISDOM_FALLBACK_NAME = "Judgement of Wisdom"

local DEFAULTS = {
    enabled  = true,
    size     = 44,
    xOffset  = 0,
    yOffset  = 0,
    swing    = true,
    colorBar = true,    -- the enemy's health bar turns blue while the debuff is on it
}
local LIMITS = {
    size    = { 16, 96 },
    xOffset = { -100, 100 },
    yOffset = { -100, 100 },
}

local db
local floor, max, min = math.floor, math.max, math.min
local issecret = issecretvalue

local function PlainNumber(v)
    if issecret and issecret(v) then return false end
    return type(v) == "number"
end

local function Forbidden(frame)
    return not frame or (frame.IsForbidden and frame:IsForbidden())
end

local function IsPlateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate") ~= nil
end

-- True while the client hides auras from addons (fights, PvP).
local function AurasSecret()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok then return true end
        if issecret and issecret(secret) then return true end
        return secret and true or false
    end
    return false
end

---------------------------------------------------------------------------
-- Which spells count
---------------------------------------------------------------------------
local spells = {}
for _, id in ipairs(WISDOM) do spells[id] = true end

-- A fresh table every time: the client keeps what it is given.
local function SpellMap()
    local map = {}
    for id in pairs(spells) do map[id] = true end
    return map
end

local wisdomName
local function WisdomName()
    if wisdomName then return wisdomName end
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, found = pcall(C_Spell.GetSpellName, WISDOM[1])
        if ok then name = found end
    end
    if not name and GetSpellInfo then
        local ok, found = pcall(GetSpellInfo, WISDOM[1])
        if ok then name = found end
    end
    if type(name) == "string" and not (issecret and issecret(name)) and name ~= "" then
        wisdomName = name
        return name
    end
    return WISDOM_FALLBACK_NAME
end

local function HarmfulFilter()
    if AuraUtil and AuraUtil.CreateFilterString and AuraUtil.AuraFilters and AuraUtil.AuraFilters.Harmful then
        local ok, filter = pcall(AuraUtil.CreateFilterString, AuraUtil.AuraFilters.Harmful)
        if ok and type(filter) == "string" and filter ~= "" then return filter end
    end
    return "HARMFUL"
end

---------------------------------------------------------------------------
-- The art and its animations
---------------------------------------------------------------------------
-- A pendulum about the top of the picture, where the rope leaves it. Three
-- turns that add up to nothing, repeated: out, across, back.
local function SwingGroup(tex)
    local group = tex:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local function Turn(degrees, order, seconds, smoothing)
        local a = group:CreateAnimation("Rotation")
        a:SetTarget(tex)
        a:SetOrigin("TOP", 0, 0)
        a:SetDegrees(degrees)
        a:SetOrder(order)
        a:SetDuration(seconds)
        if a.SetSmoothing then a:SetSmoothing(smoothing) end
    end
    Turn(SWING_DEGREES, 1, SWING_SECONDS / 4, "OUT")
    Turn(-2 * SWING_DEGREES, 2, SWING_SECONDS / 2, "IN_OUT")
    Turn(SWING_DEGREES, 3, SWING_SECONDS / 4, "IN")
    return group
end

-- Played once when the debuff lands: the piñata drops down its rope.
local function DropGroup(tex)
    local group = tex:CreateAnimationGroup()
    local a = group:CreateAnimation("Scale")
    a:SetTarget(tex)
    a:SetOrigin("TOP", 0, 0)
    a:SetOrder(1)
    a:SetDuration(DROP_SECONDS)
    a:SetScaleFrom(0.25, 0.25)
    a:SetScaleTo(1, 1)
    if a.SetSmoothing then a:SetSmoothing("OUT") end
    return group
end

local function Art(owner)
    local tex = owner:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(ART)
    tex:SetAllPoints(owner)
    return tex
end

---------------------------------------------------------------------------
-- The health bar
---------------------------------------------------------------------------
local function HealthBar(plate)
    local uf = plate.UnitFrame
    if type(uf) ~= "table" or Forbidden(uf) then return end
    local bar = uf.healthBar
    if not bar and type(uf.HealthBarsContainer) == "table" then bar = uf.HealthBarsContainer.healthBar end
    if type(bar) ~= "table" or Forbidden(bar) or not bar.GetStatusBarTexture then return end
    return bar
end

-- A blue copy of the bar's fill, laid exactly over the fill. Anchored to the
-- fill itself, so it shrinks with the enemy's health without the addon ever
-- knowing the health.
-- Gives `tex` the picture the bar's fill uses right now (another addon may
-- have restyled the bar since the last look).
local function CopyFill(tex, fill)
    local copied = pcall(function()
        local atlas = fill.GetAtlas and fill:GetAtlas()
        if type(atlas) == "string" and atlas ~= "" then
            tex:SetAtlas(atlas)
            return
        end
        local file = fill:GetTexture()
        if file == nil or file == "" then error("the bar has no texture") end
        tex:SetTexture(file)
    end)
    if not copied then tex:SetTexture(BAR_TEXTURE) end
    local r, g, b = ManaColor()
    tex:SetVertexColor(r, g, b, 1)
end

local function BarArt(owner, fill)
    local tex = owner:CreateTexture(nil, "ARTWORK")
    CopyFill(tex, fill)
    tex:SetAllPoints(fill)
    return tex
end

---------------------------------------------------------------------------
-- One piñata per nameplate
---------------------------------------------------------------------------
local pinatas = setmetatable({}, { __mode = "k" })   -- nameplate -> piñata
local active  = {}                                    -- unit token -> piñata
ns.pinatas, ns.active = pinatas, active

local testing = false                  -- test piñatas on every nameplate
local swingPending, swingNoted = false, false

-- The two things the game draws for us, each on an aura slot of its own:
-- the piñata above the nameplate and the blue over the health bar. One
-- failing does not take the other down. `field` is where a piñata keeps
-- that container; `error` is set while the game refuses.
local NATIVE = {
    icon = { slot = "ManaPinata", field = "container", tries = 0,
             warn = "the game would not let the piñata onto the nameplates, so none will show." },
    bar  = { slot = "ManaPinataBar", field = "barContainer", tries = 0,
             warn = "the game would not let the health bar be coloured, so it keeps its own colour." },
}

-- Everything on the button has to happen in here. The client calls this from
-- inside AddAuraSlot, and in a fight it locks the button and all its children
-- the moment AddAuraSlot returns: nothing on them can be touched afterwards.
local function SetupButton(p, container, button)
    button:EnableMouse(false)          -- never in the way of a click on the nameplate
    button:ClearAllPoints()
    button:SetAllPoints(container)
    button:SetFrameLevel((container:GetFrameLevel() or 0) + 1)
    local tex = Art(button)
    p.button, p.tex = button, tex
    p.swing = SwingGroup(tex)
    if db.swing then
        button:AddAuraShownAnimation(p.swing)   -- the client plays it while the debuff is up
        p.swinging = true
    end
    -- An extra: if this client can't do it, the piñata simply appears.
    pcall(function()
        local drop = DropGroup(tex)
        button:AddAuraAssignedAnimation(drop)
        p.drop = drop
    end)
end

-- The same rule for the button that colours the health bar: all of it in here.
local function SetupBar(p, container, button)
    button:EnableMouse(false)
    button:ClearAllPoints()
    button:SetAllPoints(container)
    button:SetFrameLevel(container:GetFrameLevel() or 0)
    p.barButton = button
    p.barTex = BarArt(button, p.fill)
end

-- One aura container filling `parent`, with one slot that only takes
-- Judgement of Wisdom and whose button is dressed by `setup`.
local function BuildNative(p, slot, parent, setup, level)
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    p.spare = container                -- kept even if the rest fails, so it can be switched off
    container:SetEnabled(false)
    if container.SetEditModePreviewEnabled then container:SetEditModePreviewEnabled(false) end
    if container.SetAuraProcessingPolicy and CustomAuraContainerAuraProcessingPolicy then
        container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    end
    container:SetAllPoints(parent)
    if level then container:SetFrameLevel(level) end
    pcall(container.EnableMouse, container, false)

    -- The client runs initializeFrame behind an error boundary of its own, so
    -- what happened in there is written down here instead of raised.
    local called, setupOK, setupErr = false, false, "the game never set the button up"
    container:AddAuraSlot(slot, HarmfulFilter(), {
        candidateFilters = { includeSpellIDs = SpellMap() },
        initializeFrame = function(button)
            called = true
            setupOK, setupErr = pcall(setup, p, container, button)
        end,
    })
    if not called or not setupOK then error(setupErr, 0) end
    p.spare = nil
    return container
end

local function TryNative(p, kind)
    local state = NATIVE[kind]
    if p[state.field] or state.error then return end
    local ok, result
    if kind == "icon" then
        ok, result = pcall(BuildNative, p, state.slot, p.holder, SetupButton)
    else
        ok, result = pcall(BuildNative, p, state.slot, p.barHolder, SetupBar, p.barHolder:GetFrameLevel())
    end
    if ok then
        p[state.field] = result
        return
    end
    if p.spare then
        pcall(function() p.spare:SetEnabled(false); p.spare:Hide() end)
        p.spare = nil
    end
    if kind == "icon" then
        p.button, p.tex, p.swing, p.drop, p.swinging = nil, nil, nil, nil, nil
    else
        p.barButton, p.barTex = nil, nil
    end
    state.error = (issecret and issecret(result)) and "hidden by the game" or tostring(result)
    state.tries = state.tries + 1
    if not state.warned then
        state.warned = true
        print(PREFIX .. state.warn .. " /pinata debug prints what went wrong.")
    end
end

-- The addon's own frame on the health bar: it carries the test colour and
-- the bar's aura container, and shows, fades and hides with the bar itself.
-- False while the nameplate has no health bar the addon can use.
local function EnsureBar(p)
    if p.barHolder then return true end
    if p.barFailed then return false end
    local bar = HealthBar(p.plate)
    if not bar then return false end
    local ok = pcall(function()
        local fill = bar:GetStatusBarTexture()
        if not fill then error("the health bar has no fill") end
        local holder = CreateFrame("Frame", nil, bar)
        holder:SetAllPoints(bar)
        holder:SetFrameLevel((bar:GetFrameLevel() or 0) + 1)
        holder:Hide()
        local test = BarArt(holder, fill)
        test:Hide()
        p.fill, p.barTest, p.barHolder = fill, test, holder
    end)
    if not ok then p.barFailed = true end
    return ok
end

local function Build(plate)
    local p = { plate = plate }
    local holder = CreateFrame("Frame", nil, plate)
    holder:SetFrameLevel((plate:GetFrameLevel() or 0) + LEVEL)
    holder:Hide()
    p.holder = holder
    -- The test piñata is the addon's own picture: it can be shown without any debuff.
    p.test = Art(holder)
    p.test:Hide()
    p.testSwing = SwingGroup(p.test)
    pinatas[plate] = p
    return p
end

local function Layout(p)
    p.holder:SetSize(db.size, db.size)
    p.holder:ClearAllPoints()
    p.holder:SetPoint("BOTTOM", p.plate, "TOP", db.xOffset, db.yOffset)
end

-- Points a container at a unit, or switches it off (unit nil). Returns the
-- error text if the game refused.
local function Switch(container, unit)
    if not container then return end
    local ok, err = pcall(function()
        if unit then
            container:SetUnit(unit)
            container:SetEnabled(true)
            container:UpdateAllAuras()         -- the same token can be a different enemy now
            container:Show()
        else
            container:SetEnabled(false)
            container:Hide()
        end
    end)
    if not ok then return tostring(err) end
end

-- The blue on the health bar, for one nameplate.
local function ApplyBar(p, unit, live)
    local want = unit ~= nil and db.colorBar and (live or testing) and EnsureBar(p)
    if want then
        -- Keep up with a restyled bar. The game's button is locked in a fight:
        -- refused there, done the next time this nameplate comes up outside one.
        CopyFill(p.barTest, p.fill)
        if p.barTex then pcall(CopyFill, p.barTex, p.fill) end
        if live then TryNative(p, "bar") end
    end
    local err = Switch(p.barContainer, (want and live) and unit or nil)
    if p.barHolder then
        if want and testing then p.barTest:Show() else p.barTest:Hide() end
        if want then p.barHolder:Show() else p.barHolder:Hide() end
    end
    return err
end

-- Puts one piñata in the state the settings ask for. Only the addon's own
-- frames and the containers are touched here: those stay writable in a fight.
local function Apply(p)
    local unit = p.unit
    if not unit then
        Switch(p.container, nil)
        ApplyBar(p, nil, false)
        p.testSwing:Stop()
        p.test:Hide()
        p.holder:Hide()
        return
    end

    Layout(p)
    p.holder:SetFrameLevel((p.plate:GetFrameLevel() or 0) + LEVEL)
    local live = db.enabled and not testing
    if live then TryNative(p, "icon") end
    local iconErr = Switch(p.container, live and unit or nil)
    local barErr = ApplyBar(p, unit, live)
    p.bindError = iconErr or barErr

    if testing then
        p.test:Show()
        if db.swing then
            if not p.testSwing:IsPlaying() then p.testSwing:Play() end
        else
            p.testSwing:Stop()
        end
    else
        p.testSwing:Stop()
        p.test:Hide()
    end
    p.holder:Show()
end

---------------------------------------------------------------------------
-- Spell IDs learned from a real enemy
---------------------------------------------------------------------------
-- The list above should cover it. If this realm uses another ID, the first
-- enemy seen with the debuff while auras are readable (out of a fight)
-- teaches it, and it is remembered.
local function ApplyFilters()
    for _, p in pairs(pinatas) do
        for _, state in pairs(NATIVE) do
            local container = p[state.field]
            if container then
                pcall(container.SetAuraSlotCandidateFilters, container, state.slot, { includeSpellIDs = SpellMap() })
            end
        end
    end
end

local function Learn(unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) or AurasSecret() then return end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, WisdomName(), "HARMFUL")
    if not ok or type(aura) ~= "table" or (issecret and issecret(aura)) then return end
    local id = aura.spellId
    if not PlainNumber(id) or spells[id] then return end
    spells[id] = true
    if type(db.learned) ~= "table" then db.learned = {} end
    db.learned[id] = true
    ApplyFilters()
end

---------------------------------------------------------------------------
-- Attach / detach
---------------------------------------------------------------------------
local function Detach(unit)
    local p = active[unit]
    if not p then return end
    active[unit] = nil
    p.unit = nil
    Apply(p)
end

local function Attach(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if Forbidden(plate) then
        Detach(unit)
        return
    end
    local p = pinatas[plate] or Build(plate)
    if p.unit and p.unit ~= unit and active[p.unit] == p then active[p.unit] = nil end
    local old = active[unit]
    if old and old ~= p then                 -- the token moved to another plate
        old.unit = nil
        Apply(old)
    end
    p.unit = unit
    active[unit] = p
    Apply(p)
    Learn(unit)
end

local function RefreshAll()
    if not db then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit and not Forbidden(plate) then Attach(unit) end
    end
end

-- Swinging on or off for the live piñatas. Their buttons are locked in a
-- fight, so a change that is refused is done when the fight ends.
local function ApplySwing()
    swingPending = false
    for _, p in pairs(pinatas) do
        if p.button and p.swing and (p.swinging or false) ~= db.swing then
            local want = db.swing
            local ok = pcall(function()
                if want then
                    p.button:AddAuraShownAnimation(p.swing)
                else
                    p.button:RemoveAuraShownAnimation(p.swing)
                end
            end)
            if ok then
                p.swinging = want
                -- Start or stop it now if the piñata is up; refused in a fight, which is fine:
                -- the game starts it the next time the debuff lands.
                pcall(function()
                    if not want then
                        p.swing:Stop()
                    elseif p.button:IsShown() then
                        p.swing:Play()
                    end
                end)
            else
                swingPending = true
            end
        end
    end
    if swingPending and not swingNoted then
        swingNoted = true
        print(PREFIX .. "piñatas that are already up change their swing when the fight ends.")
    end
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
local function Clamp(key, value)
    local limit = LIMITS[key]
    if not limit then return value end
    return floor(max(limit[1], min(limit[2], value)) + 0.5)
end

local function InitDB()
    if type(ManaPinataDB) ~= "table" then ManaPinataDB = {} end
    db = ManaPinataDB
    for key, value in pairs(DEFAULTS) do
        if type(db[key]) ~= type(value) then db[key] = value end
    end
    for key in pairs(LIMITS) do db[key] = Clamp(key, db[key]) end
    if db.settingsVersion ~= 2 then
        if db.size == 36 then db.size = DEFAULTS.size end   -- the first build's smaller default
        db.settingsVersion = 2
    end
    if type(db.learned) == "table" then
        for id in pairs(db.learned) do
            if type(id) == "number" then spells[id] = true end
        end
    else
        db.learned = nil
    end
    ns.db = db
end

---------------------------------------------------------------------------
-- For Options.lua and the slash commands
---------------------------------------------------------------------------
function ns.Print(msg) print(PREFIX .. tostring(msg)) end

function ns.Set(key, value)
    if not db or DEFAULTS[key] == nil then return end
    if type(value) ~= type(DEFAULTS[key]) then return end
    if LIMITS[key] then value = Clamp(key, value) end
    db[key] = value
    if key == "swing" then ApplySwing() end
    RefreshAll()
end

function ns.Testing() return testing end

function ns.SetTesting(on)
    on = on and true or false
    if on == testing then return end
    testing = on
    RefreshAll()
end

function ns.Reset()
    for key, value in pairs(DEFAULTS) do db[key] = value end
    db.minimap = nil
    testing = false
    ApplySwing()
    if ns.Kit then ns.Kit.RefreshMinimap() end
    RefreshAll()
end

-- nil when the game's aura slots work (or have not been needed yet), else the error text.
function ns.NativeError() return NATIVE.icon.error end
function ns.BarError() return NATIVE.bar.error end

local function PlateCount()
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n
end

local function TestNote()
    if not testing then
        print(PREFIX .. "test piñatas hidden.")
        return
    end
    local n = PlateCount()
    if n == 0 then
        print(PREFIX .. "test is on, but there are no nameplates on screen. Turn enemy nameplates on (V) and "
            .. "stand near something: each nameplate gets a test piñata. /pinata test again hides them.")
    else
        print(PREFIX .. "test piñata on " .. n .. " nameplate" .. (n == 1 and "" or "s")
            .. ". Size and place it in /pinata config. /pinata test again hides them.")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
pcall(f.RegisterEvent, f, "UNIT_AURA")

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
        Detach(arg1)

    elseif event == "UNIT_AURA" then
        -- Only to learn a spell ID; the piñata itself is shown by the game.
        if IsPlateUnit(arg1) and active[arg1] then Learn(arg1) end

    elseif event == "PLAYER_REGEN_DISABLED" then
        if testing then                           -- never hide the real ones during a fight
            testing = false
            RefreshAll()
            print(PREFIX .. "test piñatas hidden: a fight started.")
            if ns.Kit then ns.Kit.Sync() end
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        for _, state in pairs(NATIVE) do
            if state.error and state.tries < 3 then state.error = nil end   -- one more try
        end
        if swingPending then ApplySwing() end
        RefreshAll()

    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshAll()
        if not db.welcomed then
            db.welcomed = true
            print(PREFIX .. "loaded. Enemies with Judgement of Wisdom get a piñata over their nameplate and a blue health bar. "
                .. "/pinata test shows one on every nameplate, /pinata config opens the options.")
        end
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function PrintStatus()
    print(PREFIX .. (db.enabled and "on" or "OFF")
        .. "  |  size " .. db.size
        .. "  |  x " .. db.xOffset .. ", y " .. db.yOffset
        .. "  |  swing " .. OnOff(db.swing) .. (swingPending and " (changes after the fight)" or "")
        .. "  |  blue health bar " .. OnOff(db.colorBar)
        .. (testing and "  |  TEST piñatas showing" or "")
        .. ((NATIVE.icon.error or NATIVE.bar.error) and "  |  not fully working, see /pinata debug" or ""))
end

local function PrintHelp()
    print(PREFIX .. "commands:")
    print("  /pinata test (a piñata on every nameplate, to size and place it)   -  /pinata config (options window)")
    print("  /pinata size <16-96>   -  /pinata x <-100..100>   -  /pinata y <-100..100>   -  /pinata swing")
    print("  /pinata bar (the enemy's health bar turns blue too, on/off)")
    print("  /pinata on|off   -  /pinata minimap (minimap button on/off)   -  /pinata reset   -  /pinata debug")
end

-- Kit.lua and Options.lua sit next to this file. If a /reload ran this file without them
-- (files added by an update only load after a full restart), say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    print(PREFIX .. "the options window and the minimap button appear after you restart the game once.")
    return false
end

local function SyncOptions()                  -- an open options window follows what was typed
    if ns.Kit then ns.Kit.Sync() end
end

local function Describe(v)
    if issecret and issecret(v) then return "HIDDEN (secret)" end
    return tostring(v)
end

local NUMBER_COMMANDS = { size = "size", x = "xOffset", y = "yOffset" }

SLASH_MANAPINATA1 = "/pinata"
SLASH_MANAPINATA2 = "/manapinata"
SlashCmdList.MANAPINATA = function(msg)
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
        ns.Set("enabled", cmd == "on")

    elseif NUMBER_COMMANDS[cmd] then
        local key = NUMBER_COMMANDS[cmd]
        local n = tonumber(arg)
        if not n then
            print(PREFIX .. "/pinata " .. cmd .. " <" .. LIMITS[key][1] .. ".." .. LIMITS[key][2] .. ">")
            return
        end
        ns.Set(key, n)

    elseif cmd == "swing" then
        ns.Set("swing", not db.swing)

    elseif cmd == "bar" then
        ns.Set("colorBar", not db.colorBar)

    elseif cmd == "test" then
        ns.SetTesting(not testing)
        TestNote()
        SyncOptions()
        return

    elseif cmd == "reset" then
        ns.Reset()

    elseif cmd == "debug" then
        local ids, live, bars, total = {}, 0, 0, 0
        for id in pairs(spells) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, p in pairs(pinatas) do
            total = total + 1
            if p.container then live = live + 1 end
            if p.barContainer then bars = bars + 1 end
        end
        local icon, bar = NATIVE.icon, NATIVE.bar
        print(PREFIX .. "build " .. tostring((select(4, GetBuildInfo())))
            .. ", nameplates now: " .. PlateCount()
            .. ", piñatas made: " .. total .. " (" .. live .. " with a working aura slot, " .. bars .. " with a health bar slot)"
            .. ", auras hidden right now: " .. tostring(AurasSecret())
            .. ", aura slots: " .. (icon.error and ("FAILED " .. icon.tries .. "x") or "ok")
            .. ", health bar slots: " .. (bar.error and ("FAILED " .. bar.tries .. "x") or "ok"))
        if icon.error then print(PREFIX .. "aura slot error: " .. icon.error) end
        if bar.error then print(PREFIX .. "health bar slot error: " .. bar.error) end
        for _, p in pairs(active) do
            if p.bindError then
                print(PREFIX .. "nameplate error: " .. p.bindError)
                break
            end
        end
        print(PREFIX .. "looking for \"" .. WisdomName() .. "\", spell IDs " .. table.concat(ids, ", "))
        if UnitExists and UnitExists("target") and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
            if AurasSecret() then
                print(PREFIX .. "target: auras are hidden right now (fight), try again outside one.")
            else
                local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "target", WisdomName(), "HARMFUL")
                if ok and type(aura) == "table" then
                    print(PREFIX .. "target has it, spell ID " .. Describe(aura.spellId) .. ".")
                else
                    print(PREFIX .. "target does not have it.")
                end
            end
        end
        return

    else
        PrintHelp()
        return
    end

    PrintStatus()
    SyncOptions()
end
