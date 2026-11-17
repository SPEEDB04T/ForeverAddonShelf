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
    /pinata juice       -> a hit knocks the piñata about and sparkles, on / off
    /pinata sound       -> the coin sound when a hit gives you mana, on / off
    /pinata preview     -> a stand-in nameplate in mid-screen takes a few blows
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

-- The mana a hit brings back: the spell that gives the attacker mana when
-- Judgement of Wisdom pays out (ranks 1 to 3). Not debuffs; see IsPayout.
local PAYOUT_SPELLS = { [20268] = true, [20352] = true, [20353] = true }

local DEFAULTS = {
    enabled  = true,
    size     = 44,
    xOffset  = 0,
    yOffset  = 0,
    swing    = true,
    colorBar = true,    -- the enemy's health bar turns blue while the debuff is on it
    juice    = true,    -- a hit knocks the piñata about and sparkles
    sound    = true,    -- the coin sound when a hit gives you mana
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
-- Juice: what a blow does to a piñata
---------------------------------------------------------------------------
-- How hard a blow lands follows the game's own hit feedback on unit frames
-- (Blizzard_FrameXML/Mainline/CombatFeedback.lua): a critical or crushing
-- blow 1.5 times a normal one, a glancing or partly stopped one 0.75. A miss
-- only makes it sway. A payout is the hit that gave you mana.
-- push/up: how far the piñata is knocked (pixels), pop: how much it swells,
-- burst: the sparkle's scale from, scale to, seconds.
local BLOWS = {
    miss   = { push = 3, up = 0, pop = 1.00 },
    glance = { push = 4, up = 1, pop = 1.06 },
    normal = { push = 6, up = 2, pop = 1.12, burst = { 0.55, 1.15, 0.30 } },
    crit   = { push = 9, up = 3, pop = 1.18, burst = { 0.60, 1.55, 0.36 } },
    payout = { push = 8, up = 4, pop = 1.28, burst = { 0.50, 2.00, 0.55 } },
}
ns.BLOWS = BLOWS

-- The sparkle: the game's cooldown-finished bling star (CooldownFrame's
-- default bling texture) in the colour the game gives mana numbers
-- (CombatFeedback.lua, ENERGIZE). Drawn in a 100 x 100 box that is scaled
-- with the piñata, so its shape never depends on the size setting.
local STAR = "Interface\\Cooldown\\star4"
local ENERGIZE_COLOR = { 0.41, 0.80, 0.94 }
local BURST_BOX = 100
local SPARKS, SPARK_RADIUS, SPARK_SIZE = 8, 36, 14

local function BurstArt(owner)
    local r, g, b = ENERGIZE_COLOR[1], ENERGIZE_COLOR[2], ENERGIZE_COLOR[3]
    local function Star(size, x, y, white)
        local t = owner:CreateTexture(nil, "OVERLAY")
        t:SetTexture(STAR)
        t:SetBlendMode("ADD")
        t:SetSize(size, size)
        t:SetPoint("CENTER", owner, "CENTER", x, y)
        if white then t:SetVertexColor(1, 1, 1, 1) else t:SetVertexColor(r, g, b, 1) end
        return t
    end
    local stars = { Star(56, 0, 0), Star(28, 0, 0, true) }
    for i = 1, SPARKS do
        local angle = (i - 1) * 2 * math.pi / SPARKS
        stars[#stars + 1] = Star(SPARK_SIZE, SPARK_RADIUS * math.cos(angle), SPARK_RADIUS * math.sin(angle), i % 2 == 0)
    end
    return stars
end

-- Knocked aside and up, back past the middle, settled: three moves that add
-- up to nothing, with a swell and its undoing. Played on the addon's own
-- frame that holds the piñata, so it can run in a fight, and it shows only
-- where the game shows a piñata.
local function WhackGroup(frame)
    local group = frame:CreateAnimationGroup()
    local function Step(kind, order, seconds, smoothing)
        local a = group:CreateAnimation(kind)
        a:SetOrder(order)
        a:SetDuration(seconds)
        if kind == "Scale" then a:SetOrigin("CENTER", 0, 0) end
        if a.SetSmoothing then a:SetSmoothing(smoothing) end
        return a
    end
    group.hit    = Step("Translation", 1, 0.05, "OUT")
    group.recoil = Step("Translation", 2, 0.13, "IN_OUT")
    group.settle = Step("Translation", 3, 0.20, "IN_OUT")
    group.grow   = Step("Scale", 1, 0.05, "OUT")
    group.shrink = Step("Scale", 2, 0.16, "IN_OUT")
    return group
end

local function Whack(group, blow, dir)
    group:Stop()
    group.hit:SetOffset(dir * blow.push, blow.up)
    group.recoil:SetOffset(-dir * blow.push * 1.4, -blow.up)
    group.settle:SetOffset(dir * blow.push * 0.4, 0)
    group.grow:SetScaleFrom(1, 1)
    group.grow:SetScaleTo(blow.pop, blow.pop)
    group.shrink:SetScaleFrom(1, 1)
    group.shrink:SetScaleTo(1 / blow.pop, 1 / blow.pop)
    group:Play()
end

-- The sparkle flashes in, grows and fades; its frame rests at alpha 0.
local function BurstGroup(frame)
    local group = frame:CreateAnimationGroup()
    if group.SetToFinalAlpha then group:SetToFinalAlpha(true) end
    local flash = group:CreateAnimation("Alpha")
    flash:SetOrder(1)
    flash:SetDuration(0.04)
    flash:SetFromAlpha(0)
    flash:SetToAlpha(1)
    local fade = group:CreateAnimation("Alpha")
    fade:SetOrder(1)
    fade:SetStartDelay(0.06)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    if fade.SetSmoothing then fade:SetSmoothing("IN") end
    local grow = group:CreateAnimation("Scale")
    grow:SetOrder(1)
    grow:SetOrigin("CENTER", 0, 0)
    if grow.SetSmoothing then grow:SetSmoothing("OUT") end
    group.fade, group.grow = fade, grow
    return group
end

local function Burst(group, burst)
    group:Stop()
    group.grow:SetScaleFrom(burst[1], burst[1])
    group.grow:SetScaleTo(burst[2], burst[2])
    group.grow:SetDuration(burst[3])
    group.fade:SetDuration(burst[3] - 0.06)
    group:Play()
end

-- One blow on anything with a whack and a burst group (a piñata, the preview).
-- Blows come from alternate sides, like a stick swung back and forth.
local function Strike(target, kind)
    local blow = BLOWS[kind]
    if not blow then return end
    target.dir = -(target.dir or -1)
    Whack(target.whack, blow, target.dir)
    if blow.burst then Burst(target.burst, blow.burst) end
    target.lastBlow = kind
end

local function CoinSound()
    if not (db and db.sound) or type(PlaySound) ~= "function" then return end
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND) or 120, "SFX")
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
    burst = { slot = "ManaPinataBurst", field = "burstContainer", tries = 0,
             warn = "the game would not let the hit sparkle onto the nameplates, so a hit only knocks the piñata about." },
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

-- And for the sparkle: drawn once, fully lit. The addon's own frame around it
-- rests invisible and lights up for a moment on each hit, so it only ever
-- shows on an enemy the game is showing it on.
local function SetupBurst(p, container, button)
    button:EnableMouse(false)
    button:ClearAllPoints()
    button:SetAllPoints(container)
    button:SetFrameLevel((container:GetFrameLevel() or 0) + 1)
    BurstArt(button)
    p.burstButton = button
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
    elseif kind == "bar" then
        ok, result = pcall(BuildNative, p, state.slot, p.barHolder, SetupBar, p.barHolder:GetFrameLevel())
    else
        ok, result = pcall(BuildNative, p, state.slot, p.burstHolder, SetupBurst, p.burstHolder:GetFrameLevel())
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
    elseif kind == "bar" then
        p.barButton, p.barTex = nil, nil
    else
        p.burstButton = nil
    end
    state.error = (issecret and issecret(result)) and "hidden by the game" or tostring(result)
    state.tries = state.tries + 1
    if not state.warned then
        state.warned = true
        print(PREFIX .. state.warn .. " /pinata debug prints what went wrong.")
    end
end

-- The game draws its own marks on the health bar in the bar's frame: the
-- darkening on every enemy that is not the target, the target border, the
-- mouse-over highlight, the aggro flash, heal absorbs and the health text
-- (Blizzard_NamePlates.xml; the unit frame moves selectionHighlight and
-- aggroFlash onto the bar). The blue lies one frame level up, so it would
-- cover them and an enemy that is not the target would look like the target.
-- They move to a frame of ours one level above the blue. Their layers,
-- anchors and showing and hiding stay the game's; one another addon has
-- already moved is left where it is.
local BAR_MARKS = { "deselectedOverlay", "selectedBorder", "myHealAbsorb", "myHealAbsorbLeftShadow",
    "myHealAbsorbRightShadow", "overAbsorbGlow", "overHealAbsorbGlow", "Text", "LeftText", "RightText" }
local FRAME_MARKS = { "selectionHighlight", "aggroFlash" }

local function LiftMarks(p)
    local bar, top = p.bar, p.barTop
    local function Lift(region)
        if type(region) ~= "table" or type(region.SetParent) ~= "function" then return end
        pcall(function()
            if region:GetParent() == bar then region:SetParent(top) end
        end)
    end
    for _, key in ipairs(BAR_MARKS) do Lift(rawget(bar, key)) end
    local uf = p.plate.UnitFrame
    if type(uf) == "table" then
        for _, key in ipairs(FRAME_MARKS) do Lift(rawget(uf, key)) end
    end
end

-- The addon's own frame on the health bar: it carries the test colour and
-- the bar's aura container, and shows, fades and hides with the bar itself.
-- Above it, the frame that keeps the game's marks on top of the blue.
-- False while the nameplate has no health bar the addon can use.
local function EnsureBar(p)
    if p.barHolder then return true end
    if p.barFailed then return false end
    local bar = HealthBar(p.plate)
    if not bar then return false end
    local ok = pcall(function()
        local fill = bar:GetStatusBarTexture()
        if not fill then error("the health bar has no fill") end
        local level = bar:GetFrameLevel() or 0
        local holder = CreateFrame("Frame", nil, bar)
        holder:SetAllPoints(bar)
        holder:SetFrameLevel(level + 1)
        holder:Hide()
        local top = CreateFrame("Frame", nil, bar)
        top:SetAllPoints(bar)
        top:SetFrameLevel(level + 2)
        local test = BarArt(holder, fill)
        test:Hide()
        p.bar, p.fill, p.barTest, p.barHolder, p.barTop = bar, fill, test, holder, top
    end)
    if not ok then p.barFailed = true; return false end
    LiftMarks(p)
    return true
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
    p.whack = WhackGroup(holder)
    -- The sparkle sits on the nameplate, not in the piñata's frame, so it stays
    -- where the blow landed while the piñata is knocked away from it.
    local burstHolder = CreateFrame("Frame", nil, plate)
    burstHolder:SetSize(BURST_BOX, BURST_BOX)
    burstHolder:SetFrameLevel((plate:GetFrameLevel() or 0) + LEVEL + 1)
    burstHolder:SetAlpha(0)
    burstHolder:Hide()
    p.burstHolder = burstHolder
    local burstTest = CreateFrame("Frame", nil, burstHolder)
    burstTest:SetAllPoints(burstHolder)
    BurstArt(burstTest)
    burstTest:Hide()
    p.burstTest = burstTest
    p.burst = BurstGroup(burstHolder)
    pinatas[plate] = p
    return p
end

-- The sparkle's 100 x 100 box is scaled so a 44 piñata gets an 88 box.
local function BurstScale() return db.size / 50 end

local function Layout(p)
    p.holder:SetSize(db.size, db.size)
    p.holder:ClearAllPoints()
    p.holder:SetPoint("BOTTOM", p.plate, "TOP", db.xOffset, db.yOffset)
    p.burstHolder:SetScale(BurstScale())
    p.burstHolder:ClearAllPoints()
    p.burstHolder:SetPoint("CENTER", p.holder, "CENTER", 0, 0)
end

-- Ends any blow still playing, so a nameplate handed to another enemy starts still.
local function StillJuice(target)
    if target.whack then target.whack:Stop() end
    if target.burst then target.burst:Stop() end
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
        LiftMarks(p)                       -- in case the game put one back on the bar
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
        Switch(p.burstContainer, nil)
        ApplyBar(p, nil, false)
        StillJuice(p)
        p.testSwing:Stop()
        p.test:Hide()
        p.holder:Hide()
        p.burstHolder:Hide()
        return
    end

    Layout(p)
    local level = (p.plate:GetFrameLevel() or 0) + LEVEL
    p.holder:SetFrameLevel(level)
    p.burstHolder:SetFrameLevel(level + 1)
    local live = db.enabled and not testing
    if live then TryNative(p, "icon") end
    local iconErr = Switch(p.container, live and unit or nil)
    local barErr = ApplyBar(p, unit, live)
    local sparkle = live and db.juice
    if sparkle then TryNative(p, "burst") end
    local burstErr = Switch(p.burstContainer, sparkle and unit or nil)
    p.bindError = iconErr or barErr or burstErr
    if testing and db.juice then p.burstTest:Show() else p.burstTest:Hide() end
    if db.juice then p.burstHolder:Show() else StillJuice(p); p.burstHolder:Hide() end

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
-- Hits
---------------------------------------------------------------------------
-- UNIT_COMBAT is the event the game's own unit frames use for their hit
-- numbers. The amount is hidden from addons; what kind of blow it was is
-- not, and that is all a piñata needs. It comes for any enemy with a
-- nameplate, whoever hit it, so a piñata bounces for the whole group. The
-- addon can't tell which enemies have the debuff in a fight; it doesn't
-- need to: it moves its own frames on every nameplate that is hit, and only
-- where the game is showing a piñata is there anything to see move.
local MISSES = { MISS = true, DODGE = true, PARRY = true, BLOCK = true, RESIST = true, EVADE = true,
    IMMUNE = true, DEFLECT = true, ABSORB = true, REFLECT = true }
local SOFT = { GLANCING = true, ABSORB = true, BLOCK = true, RESIST = true, BLOCK_REDUCED = true }
local RANK = { miss = 1, glance = 2, normal = 3, crit = 4, payout = 5 }
local MIN_GAP = 0.1          -- seconds; a weaker blow this soon after another doesn't restart it
local PAYOUT_GAP = 0.25
local PAIR_WINDOW = 0.15     -- a mana gain this soon after the target was hit came from the hit

local function Plain(v) return not (issecret and issecret(v)) end
local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end

-- "crit", "normal", "glance", "miss", or nil for things that aren't blows
-- (heals, mana). Hidden values count as a normal blow.
local function HitKind(action, flag)
    if not Plain(action) then return "normal" end
    if type(action) ~= "string" then return nil end
    if action ~= "WOUND" then return MISSES[action] and "miss" or nil end
    if not Plain(flag) or type(flag) ~= "string" then return "normal" end
    if flag == "CRITICAL" or flag == "CRUSHING" then return "crit" end
    if SOFT[flag] then return "glance" end
    return "normal"
end
ns.HitKind = HitKind

local function PinataFor(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or type(plate) ~= "table" or Forbidden(plate) then return end
    local p = pinatas[plate]
    if p and p.unit then return p end
end

local function Hit(p, kind)
    if not (db.enabled and db.juice) or not RANK[kind] then return end
    local now = Now()
    if p.lastBlowAt and now - p.lastBlowAt < MIN_GAP and RANK[kind] <= (RANK[p.lastBlow] or 0) then return end
    p.lastBlowAt = now
    Strike(p, kind)
end

local function ManaUser()
    if type(UnitPowerType) ~= "function" then return true end
    local ok, power = pcall(UnitPowerType, "player")
    if not ok or not Plain(power) then return true end
    return power == 0
end

-- The blow that gave you mana: a big burst on your target and the coin sound.
local lastPayout
local function Payout()
    if not db.enabled then return end
    local now = Now()
    if lastPayout and now - lastPayout < PAYOUT_GAP then return end
    lastPayout = now
    CoinSound()
    local p = PinataFor("target")
    if p then Hit(p, "payout") end
end
ns.Payout = Payout

-- The mana from Judgement of Wisdom, by spell ID or (an ID this list lacks)
-- by name. The debuff's own IDs never count: a paladin putting the debuff up
-- is not a payout.
local function IsPayout(spellID)
    if not PlainNumber(spellID) then return false end
    if PAYOUT_SPELLS[spellID] then return true end
    if spells[spellID] then return false end
    if not (C_Spell and C_Spell.GetSpellName) then return false end
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    return ok and Plain(name) and name == WisdomName()
end

local function OnCombat(unit, action, flag)
    if not Plain(unit) or type(unit) ~= "string" then return end
    if unit == "player" then
        -- Mana given to you right as your target was hit: the same payout,
        -- for clients where the mana does not arrive as a spell cast.
        if Plain(action) and action == "ENERGIZE" and ManaUser() then
            local p = PinataFor("target")
            if p and p.woundAt and Now() - p.woundAt <= PAIR_WINDOW then Payout() end
        end
        return
    end
    if not (IsPlateUnit(unit) or unit == "target" or unit == "focus") then return end
    local kind = HitKind(action, flag)
    if not kind then return end
    local p = PinataFor(unit)
    if not p then return end
    if kind ~= "miss" then p.woundAt = Now() end
    Hit(p, kind)
end
ns.OnCombat = OnCombat

local function OnCast(unit, spellID)
    if unit == "player" and IsPayout(spellID) then Payout() end
end

---------------------------------------------------------------------------
-- The hit preview: a stand-in nameplate in the middle of the screen that
-- takes a few blows, so the effects can be seen without a paladin.
---------------------------------------------------------------------------
local PREVIEW_BLOWS = { "normal", "normal", "crit", "normal", "payout", "glance", "normal", "miss", "crit", "payout" }
local PREVIEW_GAP, PREVIEW_START, PREVIEW_END = 0.7, 0.4, 1.2
local PREVIEW_BAR_W, PREVIEW_BAR_H = 120, 13          -- the size of a small nameplate health bar
local preview

local function SafeAtlas(tex, atlas, fallback)
    if not pcall(tex.SetAtlas, tex, atlas) then tex:SetTexture(fallback) end
end

local function BuildPreview()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(PREVIEW_BAR_W, 30)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(false)
    frame:Hide()
    -- The health bar, in the nameplate's own bar art, three quarters full and blue.
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetSize(PREVIEW_BAR_W, PREVIEW_BAR_H)
    bar:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    SafeAtlas(bg, "UI-HUD-CoolDownManager-Bar-BG", BAR_TEXTURE)
    bg:SetAllPoints(bar)
    local fill = bar:CreateTexture(nil, "ARTWORK")
    SafeAtlas(fill, "UI-HUD-CoolDownManager-Bar", BAR_TEXTURE)
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    fill:SetWidth(PREVIEW_BAR_W * 0.75)
    fill:SetVertexColor(ManaColor())
    local name = frame:CreateFontString(nil, "OVERLAY", _G.SystemFont_NamePlate and "SystemFont_NamePlate" or "GameFontNormalSmall")
    name:SetPoint("BOTTOM", bar, "TOP", 0, 2)
    name:SetText("Hit preview")
    name:SetTextColor(1, 1, 1)

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameLevel((frame:GetFrameLevel() or 0) + LEVEL)
    local art = Art(holder)
    local burstHolder = CreateFrame("Frame", nil, frame)
    burstHolder:SetSize(BURST_BOX, BURST_BOX)
    burstHolder:SetFrameLevel((frame:GetFrameLevel() or 0) + LEVEL + 1)
    burstHolder:SetAlpha(0)
    BurstArt(burstHolder)
    return {
        frame = frame, holder = holder, burstHolder = burstHolder, art = art,
        swing = SwingGroup(art), whack = WhackGroup(holder), burst = BurstGroup(burstHolder),
        run = 0,
    }
end

local function StopPreview()
    if not preview then return end
    preview.run = preview.run + 1
    StillJuice(preview)
    preview.swing:Stop()
    preview.frame:Hide()
end

local function PreviewShowing()
    return preview ~= nil and preview.frame:IsShown() == true
end
ns.PreviewShowing = PreviewShowing

-- Plays the blows one after another and hides itself after the last.
-- Asked again while it runs, it stops.
local function RunPreview()
    if PreviewShowing() then StopPreview(); return false end
    preview = preview or BuildPreview()
    local pv = preview
    pv.holder:SetSize(db.size, db.size)
    pv.holder:ClearAllPoints()
    pv.holder:SetPoint("BOTTOM", pv.frame, "TOP", db.xOffset, db.yOffset)
    pv.burstHolder:SetScale(BurstScale())
    pv.burstHolder:ClearAllPoints()
    pv.burstHolder:SetPoint("CENTER", pv.holder, "CENTER", 0, 0)
    pv.frame:Show()
    if db.swing then pv.swing:Play() else pv.swing:Stop() end
    pv.run = pv.run + 1
    pv.dir, pv.step = nil, 0
    local run = pv.run
    local function Next()
        if pv.run ~= run then return end
        pv.step = pv.step + 1
        local kind = PREVIEW_BLOWS[pv.step]
        if not kind then
            C_Timer.After(PREVIEW_END, function() if pv.run == run then StopPreview() end end)
            return
        end
        Strike(pv, kind)
        if kind == "payout" then CoinSound() end
        C_Timer.After(PREVIEW_GAP, Next)
    end
    C_Timer.After(PREVIEW_START, Next)
    return true
end
ns.RunPreview = RunPreview
ns.StopPreview = StopPreview
function ns.Preview() return preview end

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
-- LookShots: a helper on SuccuDev's machine that takes one game screenshot
-- of each frame listed here the first time it shows. Harmless without it.
-- Frames on a nameplate can't be listed: the client hides where they are
-- from addons. The hit preview is drawn by the same code and art on the
-- screen itself, so that is what is listed.
---------------------------------------------------------------------------
local function PreviewFrame()
    if PreviewShowing() then return preview.frame end
end

local function AddonVersion()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not get then return "?" end
    local ok, version = pcall(get, ADDON_NAME, "Version")
    return (ok and type(version) == "string") and version or "?"
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets[ADDON_NAME] = {
    version = AddonVersion(),
    frames = {
        { label = "hit preview", frame = PreviewFrame },
    },
}

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
pcall(f.RegisterEvent, f, "UNIT_COMBAT")
if not (f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")) then
    pcall(f.RegisterEvent, f, "UNIT_SPELLCAST_SUCCEEDED")
end

f:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
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

    if event == "UNIT_COMBAT" then
        OnCombat(arg1, arg2, arg3)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        OnCast(arg1, arg3)

    elseif event == "NAME_PLATE_UNIT_ADDED" then
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
        .. "  |  bounce on hits " .. OnOff(db.juice)
        .. "  |  coin sound " .. OnOff(db.sound)
        .. (testing and "  |  TEST piñatas showing" or "")
        .. ((NATIVE.icon.error or NATIVE.bar.error or NATIVE.burst.error) and "  |  not fully working, see /pinata debug" or ""))
end

local function PrintHelp()
    print(PREFIX .. "commands:")
    print("  /pinata test (a piñata on every nameplate, to size and place it)   -  /pinata config (options window)")
    print("  /pinata size <16-96>   -  /pinata x <-100..100>   -  /pinata y <-100..100>   -  /pinata swing")
    print("  /pinata bar (the enemy's health bar turns blue too, on/off)")
    print("  /pinata juice (bounce and sparkle on hits, on/off)   -  /pinata sound (coin sound on mana, on/off)   -  /pinata preview")
    print("  /pinata on|off   -  /pinata minimap (minimap button on/off)   -  /pinata reset   -  /pinata debug")
end

-- Kit.lua and Options.lua sit next to this file. If this file ran without them
-- (on Forever, files added by an update load on the next /reload), say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    print(PREFIX .. "the options window and the minimap button appear after a /reload.")
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

    elseif cmd == "juice" or cmd == "hits" then
        ns.Set("juice", not db.juice)

    elseif cmd == "sound" then
        ns.Set("sound", not db.sound)

    elseif cmd == "preview" then
        if RunPreview() then print(PREFIX .. "hit preview in the middle of the screen. /pinata preview again stops it.") end
        return

    elseif cmd == "test" then
        ns.SetTesting(not testing)
        TestNote()
        SyncOptions()
        return

    elseif cmd == "reset" then
        ns.Reset()

    elseif cmd == "debug" then
        local ids, live, bars, bursts, total = {}, 0, 0, 0, 0
        for id in pairs(spells) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, p in pairs(pinatas) do
            total = total + 1
            if p.container then live = live + 1 end
            if p.barContainer then bars = bars + 1 end
            if p.burstContainer then bursts = bursts + 1 end
        end
        local icon, bar, burst = NATIVE.icon, NATIVE.bar, NATIVE.burst
        print(PREFIX .. "build " .. tostring((select(4, GetBuildInfo())))
            .. ", nameplates now: " .. PlateCount()
            .. ", piñatas made: " .. total .. " (" .. live .. " with a working aura slot, " .. bars .. " with a health bar slot, "
            .. bursts .. " with a sparkle slot)"
            .. ", auras hidden right now: " .. tostring(AurasSecret())
            .. ", aura slots: " .. (icon.error and ("FAILED " .. icon.tries .. "x") or "ok")
            .. ", health bar slots: " .. (bar.error and ("FAILED " .. bar.tries .. "x") or "ok")
            .. ", sparkle slots: " .. (burst.error and ("FAILED " .. burst.tries .. "x") or "ok"))
        if icon.error then print(PREFIX .. "aura slot error: " .. icon.error) end
        if bar.error then print(PREFIX .. "health bar slot error: " .. bar.error) end
        if burst.error then print(PREFIX .. "sparkle slot error: " .. burst.error) end
        local blows = 0
        for _, p in pairs(pinatas) do if p.lastBlowAt then blows = blows + 1 end end
        print(PREFIX .. "nameplates hit so far: " .. blows
            .. (lastPayout and (", last mana payout " .. floor(Now() - lastPayout) .. " s ago") or ", no mana payout seen yet"))
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
