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
    /pinata flow        -> the mana you get flies into your mana bar, on / off
    /pinata number      -> "+N Mana" by your mana bar when a hit gives you mana, on / off
    /pinata sound       -> the coin sound when a hit gives you mana, on / off (off to start with)
    /pinata preview     -> a stand-in nameplate in mid-screen takes a few blows
    /pinata stills      -> the same, holding still at four moments for LookShots
    /pinata on|off, /pinata reset, /pinata debug
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cff59c8ffMana Piñata|r: "
local ART    = "Interface\\AddOns\\ManaPinata\\Art\\Pinata"
local FLASH_ART  = "Interface\\AddOns\\ManaPinata\\Art\\PinataFlash"     -- the piñata's shape in white
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
-- Each payout's own debuff rank, whose spell text also says the mana.
local PAYOUT_RANK = { [20268] = 20186, [20352] = 20354, [20353] = 20355 }

local DEFAULTS = {
    enabled  = true,
    size     = 44,
    xOffset  = 0,
    yOffset  = 0,
    swing    = true,
    colorBar = true,    -- the enemy's health bar turns blue while the debuff is on it
    juice    = true,    -- a hit knocks the piñata about and sparkles
    manaFlow = true,    -- the mana you get flies from the piñata into your mana bar
    manaNumber = true,  -- the mana you got, as a number, when the game lets it be read
    sound    = false,   -- the coin sound when a hit gives you mana (off unless chosen: it rings a lot)
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
-- push: how far the piñata is knocked (pixels, for a 44 piñata), lift: how
-- far it rises at the end of its swing, squash: how much it squashes and
-- wobbles (1 = the SQUASH table as it is), flash: how white it flashes,
-- burst: the sparkle's scale from, scale to, seconds.
local BLOWS = {
    miss   = { push = 5,  lift = 0, squash = 0.15 },
    glance = { push = 8,  lift = 2, squash = 0.50, flash = 0.45 },
    normal = { push = 13, lift = 4, squash = 0.85, flash = 0.75, burst = { 0.55, 1.15, 0.28 } },
    crit   = { push = 19, lift = 6, squash = 1.15, flash = 1.00, burst = { 0.60, 1.55, 0.34 } },
    payout = { push = 17, lift = 7, squash = 1.25, flash = 1.00, burst = { 0.50, 1.60, 0.46 } },
}
ns.BLOWS = BLOWS

-- The knock, step by step: where the piñata is after each step as a share of
-- the push (it rises a little at both ends of the swing), and how long each
-- step takes. The first step is the impact: the piñata stays put for a
-- moment and only squashes, which is what gives the blow its weight. Then it
-- snaps away, swings back once past the middle and settles. No long wobble.
local KNOCK         = { 0, 1, -0.30, 0.08, 0 }
local KNOCK_SECONDS = { 0.035, 0.065, 0.17, 0.14, 0.12 }
local KNOCK_EASE    = { "OUT", "OUT", "IN_OUT", "IN_OUT", "IN_OUT" }
-- The squash over the same steps (width, height), about the top of the
-- piñata where the rope holds it: flattened by the blow, springing back tall
-- as it flies, then back into shape. Squashed from below, it never sinks
-- towards the name under it.
local SQUASH = { { 1.20, 0.82 }, { 0.93, 1.07 }, { 1.02, 0.98 }, { 1.0, 1.0 }, { 1, 1 } }
local SQUASH_MAX = 1.6

-- The sparkle: the game's cooldown-finished bling star (CooldownFrame's
-- default bling texture) in the colour the game gives mana numbers
-- (CombatFeedback.lua, ENERGIZE). Drawn in a 100 x 100 box that is scaled
-- with the piñata, so its shape never depends on the size setting.
local STAR = "Interface\\Cooldown\\star4"
local ENERGIZE_COLOR = { 0.41, 0.80, 0.94 }
local BURST_BOX = 100
local SPARKS, SPARK_RADIUS, SPARK_SIZE = 8, 36, 14
-- The sparks fan round the top only, a little below level at each side: the
-- bottom of a full ring would land on the nameplate's name and health bar.
local SPARK_FROM, SPARK_TO = -0.25, math.pi + 0.25

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
    local stars = { Star(34, 0, 0), Star(16, 0, 0, true) }
    -- Not a ring: each spark a little nearer or further, bigger or smaller.
    local SPREAD = { { 1.00, 1.00, 0 }, { 0.80, 0.75, 0.10 }, { 1.12, 1.15, -0.06 }, { 0.88, 0.85, 0.08 },
                     { 1.08, 1.10, -0.10 }, { 0.82, 0.80, 0.05 }, { 1.15, 1.20, -0.04 }, { 0.92, 0.90, 0 } }
    for i = 1, SPARKS do
        local s = SPREAD[(i - 1) % #SPREAD + 1]
        local angle = SPARK_FROM + (i - 1) * (SPARK_TO - SPARK_FROM) / (SPARKS - 1) + s[3]
        local radius = SPARK_RADIUS * s[1]
        stars[#stars + 1] = Star(SPARK_SIZE * s[2], radius * math.cos(angle), radius * math.sin(angle), i % 2 == 0)
    end
    return stars
end

-- The knock and the squash, step by step. Each step moves and scales on from
-- where the last one left off, and together they add up to nothing. Played
-- on the addon's own frame that holds the piñata, so it can run in a fight,
-- and it shows only where the game shows a piñata.
local function WhackGroup(frame)
    local group = frame:CreateAnimationGroup()
    group.moves, group.squash = {}, {}
    for i, seconds in ipairs(KNOCK_SECONDS) do
        local smoothing = KNOCK_EASE[i]
        local move = group:CreateAnimation("Translation")
        move:SetOrder(i)
        move:SetDuration(seconds)
        if move.SetSmoothing then move:SetSmoothing(smoothing) end
        local squash = group:CreateAnimation("Scale")
        squash:SetOrder(i)
        squash:SetDuration(seconds)
        squash:SetOrigin("TOP", 0, 0)
        if squash.SetSmoothing then squash:SetSmoothing(smoothing) end
        group.moves[i], group.squash[i] = move, squash
    end
    return group
end

-- size: the piñata's size.
local function Whack(group, blow, dir, size)
    group:Stop()
    local scale = (size or 44) / 44
    local push, lift = blow.push * scale, blow.lift * scale
    local amount = min(blow.squash, SQUASH_MAX)
    local x0, y0, w0, h0 = 0, 0, 1, 1
    for i, at in ipairs(KNOCK) do
        local x, y = dir * push * at, lift * math.abs(at)
        local w = 1 + amount * (SQUASH[i][1] - 1)
        local h = 1 + amount * (SQUASH[i][2] - 1)
        group.moves[i]:SetOffset(x - x0, y - y0)
        group.squash[i]:SetScaleFrom(1, 1)
        group.squash[i]:SetScaleTo(w / w0, h / h0)
        x0, y0, w0, h0 = x, y, w, h
    end
    group:Play()
end

-- The white flash: the piñata's own shape in white, over it, on a frame of
-- ours that rests invisible and flares for a moment on a blow.
local FLASH_IN, FLASH_HOLD, FLASH_FADE = 0.02, 0.045, 0.13
local function FlashGroup(frame)
    local group = frame:CreateAnimationGroup()
    if group.SetToFinalAlpha then group:SetToFinalAlpha(true) end
    local on = group:CreateAnimation("Alpha")
    on:SetOrder(1)
    on:SetDuration(FLASH_IN)
    on:SetFromAlpha(0)
    local off = group:CreateAnimation("Alpha")
    off:SetOrder(1)
    off:SetStartDelay(FLASH_HOLD)
    off:SetDuration(FLASH_FADE)
    off:SetToAlpha(0)
    if off.SetSmoothing then off:SetSmoothing("OUT") end
    group.on, group.off = on, off
    return group
end

local function Flash(group, strength)
    group:Stop()
    group.on:SetToAlpha(strength)
    group.off:SetFromAlpha(strength)
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

-- One blow on anything built by BuildRig (a piñata, the preview). Blows come
-- from alternate sides, like a stick swung back and forth.
local function Strike(target, kind)
    local blow = BLOWS[kind]
    if not blow then return end
    target.dir = -(target.dir or -1)
    Whack(target.whack, blow, target.dir, db and db.size)
    if blow.flash then Flash(target.flash, blow.flash) end
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

-- The things the game draws for us, each on an aura slot of its own: the
-- piñata above the nameplate, the blue over the health bar, and for hits the
-- sparkle and the white flash. One failing does not take another down. `field` is where a piñata keeps that
-- container; `error` is set while the game refuses.
local NATIVE = {
    icon = { slot = "ManaPinata", field = "container", tries = 0,
             warn = "the game would not let the piñata onto the nameplates, so none will show." },
    bar  = { slot = "ManaPinataBar", field = "barContainer", tries = 0,
             warn = "the game would not let the health bar be coloured, so it keeps its own colour." },
    burst = { slot = "ManaPinataBurst", field = "burstContainer", tries = 0, name = "sparkle",
             warn = "the game would not let the hit sparkle onto the nameplates, so a hit only knocks the piñata about." },
    flash = { slot = "ManaPinataFlash", field = "flashContainer", tries = 0, name = "white flash",
             warn = "the game would not let the white hit flash onto the nameplates; the rest of a hit still shows." },
}
-- The hit slots, in the order they are made.
local HIT_SLOTS = { "burst", "flash" }

-- The piñata and its flash swing and drop as one: each picture
-- gets the same swing and drop, which the client starts on all of them when
-- the debuff shows. Kept per picture so the swing setting can reach them all.
local function Dress(p, key, button, tex)
    local swing = SwingGroup(tex)
    local entry = { button = button, swing = swing, on = false }
    if db.swing then
        button:AddAuraShownAnimation(swing)     -- the client plays it while the debuff is up
        entry.on = true
    end
    -- An extra: if this client can't do it, the piñata simply appears.
    pcall(function()
        local drop = DropGroup(tex)
        button:AddAuraAssignedAnimation(drop)
        entry.drop = drop
    end)
    p.swingers = p.swingers or {}
    p.swingers[key] = entry
    return entry
end

-- Everything on the button has to happen in here. The client calls this from
-- inside AddAuraSlot, and in a fight it locks the button and all its children
-- the moment AddAuraSlot returns: nothing on them can be touched afterwards.
local function SetupButton(p, container, button)
    button:EnableMouse(false)          -- never in the way of a click on the nameplate
    button:ClearAllPoints()
    button:SetAllPoints(container)
    button:SetFrameLevel((container:GetFrameLevel() or 0) + 1)
    local tex = Art(button)
    local entry = Dress(p, "icon", button, tex)
    p.button, p.tex, p.swing, p.drop, p.swinging = button, tex, entry.swing, entry.drop, entry.on
end

-- A picture laid over the piñata (the flash), the same size and swinging with it.
local function OverlaySetup(key, art)
    return function(p, container, button)
        button:EnableMouse(false)
        button:ClearAllPoints()
        button:SetAllPoints(container)
        button:SetFrameLevel((container:GetFrameLevel() or 0) + 1)
        local tex = button:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(art)
        tex:SetAllPoints(button)
        Dress(p, key, button, tex)
    end
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

-- Which of the piñata's own frames each slot goes in, and how its button is dressed.
local SLOT_PARENT = { icon = "holder", bar = "barHolder", burst = "burstHolder", flash = "flashHolder" }
local SLOT_SETUP = { icon = SetupButton, bar = SetupBar, burst = SetupBurst,
    flash = OverlaySetup("flash", FLASH_ART) }

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

local warnedSlots = {}
local function TryNative(p, kind)
    local state = NATIVE[kind]
    if p[state.field] or state.error then return end
    local parent = p[SLOT_PARENT[kind]]
    local level = kind ~= "icon" and parent:GetFrameLevel() or nil
    local ok, result = pcall(BuildNative, p, state.slot, parent, SLOT_SETUP[kind], level)
    if ok then
        p[state.field] = result
        return
    end
    if p.spare then
        pcall(function() p.spare:SetEnabled(false); p.spare:Hide() end)
        p.spare = nil
    end
    if p.swingers then p.swingers[kind] = nil end
    if kind == "icon" then
        p.button, p.tex, p.swing, p.drop, p.swinging = nil, nil, nil, nil, nil
    elseif kind == "bar" then
        p.barButton, p.barTex = nil, nil
    elseif kind == "burst" then
        p.burstButton = nil
    end
    state.error = (issecret and issecret(result)) and "hidden by the game" or tostring(result)
    state.tries = state.tries + 1
    -- One line for all the hit slots: if one is refused, the others likely are too.
    local key = state.name and "hits" or kind
    if not warnedSlots[key] then
        warnedSlots[key] = true
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

-- The addon's own frames a piñata is drawn in, on a nameplate or on the
-- preview. The holder carries the piñata; over it, a frame for the white
-- flash, which moves with it. The sparkle sits beside it, on `parent`, so it
-- stays where the blow landed while the piñata is knocked away. On a nameplate the game's aura slots go
-- into these frames; the test piñata and the preview draw the same art
-- straight onto them (the `...Test` pictures), which needs no debuff.
local function BuildRig(parent)
    local r = {}
    local holder = CreateFrame("Frame", nil, parent)
    holder:Hide()
    r.holder = holder
    r.test = Art(holder)
    r.test:Hide()
    local function Overlay(art)
        local frame = CreateFrame("Frame", nil, holder)
        frame:SetAllPoints(holder)
        frame:SetAlpha(0)
        local tex = frame:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(art)
        tex:SetAllPoints(frame)
        tex:Hide()
        return frame, tex
    end
    r.flashHolder, r.flashTest = Overlay(FLASH_ART)
    r.testSwings = { SwingGroup(r.test), SwingGroup(r.flashTest) }
    local burst = CreateFrame("Frame", nil, parent)
    burst:SetSize(BURST_BOX, BURST_BOX)
    burst:SetAlpha(0)
    burst:Hide()
    local test = CreateFrame("Frame", nil, burst)
    test:SetAllPoints(burst)
    BurstArt(test)
    test:Hide()
    r.burstHolder, r.burstTest = burst, test
    r.whack = WhackGroup(holder)
    r.flash = FlashGroup(r.flashHolder)
    r.burst = BurstGroup(r.burstHolder)
    return r
end

-- Frame levels from the piñata's own up: the flash, then the sparkle on top.
local function RigLevels(r, base)
    r.holder:SetFrameLevel(base)
    r.flashHolder:SetFrameLevel(base + 3)
    r.burstHolder:SetFrameLevel(base + 5)
end

-- The sparkle's 100 x 100 box is scaled so a 44 piñata gets an 88 box.
local function BurstScale() return db.size / 50 end

-- Size and place a rig's piñata `x`, `y` from the point it hangs from.
local function RigLayout(r, anchor, x, y)
    r.holder:SetSize(db.size, db.size)
    r.holder:ClearAllPoints()
    r.holder:SetPoint("BOTTOM", anchor, "TOP", x, y)
    r.burstHolder:SetScale(BurstScale())
    r.burstHolder:ClearAllPoints()
    r.burstHolder:SetPoint("CENTER", r.holder, "CENTER", 0, 0)
end

-- The test pictures on or off, swinging if swing is on.
local function ShowTestArt(r, on)
    for _, region in ipairs({ r.test, r.flashTest, r.burstTest }) do
        if on then region:Show() else region:Hide() end
    end
    for _, group in ipairs(r.testSwings) do
        if on and db.swing then
            if not group:IsPlaying() then group:Play() end
        else
            group:Stop()
        end
    end
end

local function Build(plate)
    local p = BuildRig(plate)
    p.plate = plate
    RigLevels(p, (plate:GetFrameLevel() or 0) + LEVEL)
    pinatas[plate] = p
    return p
end

local function Layout(p)
    RigLayout(p, p.plate, db.xOffset, db.yOffset)
end

-- Ends any blow still playing, so a nameplate handed to another enemy starts still.
local function StillJuice(target)
    for _, key in ipairs({ "whack", "flash", "burst" }) do
        if target[key] then target[key]:Stop() end
    end
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
        for _, kind in ipairs(HIT_SLOTS) do Switch(p[NATIVE[kind].field], nil) end
        ApplyBar(p, nil, false)
        StillJuice(p)
        ShowTestArt(p, false)
        p.holder:Hide()
        p.burstHolder:Hide()
        return
    end

    Layout(p)
    RigLevels(p, (p.plate:GetFrameLevel() or 0) + LEVEL)
    local live = db.enabled and not testing
    if live then TryNative(p, "icon") end
    local errors = { Switch(p.container, live and unit or nil), ApplyBar(p, unit, live) }
    local sparkle = live and db.juice
    for _, kind in ipairs(HIT_SLOTS) do
        if sparkle then TryNative(p, kind) end
        errors[#errors + 1] = Switch(p[NATIVE[kind].field], sparkle and unit or nil)
    end
    local err
    for i = 1, 2 + #HIT_SLOTS do err = err or errors[i] end
    p.bindError = err
    ShowTestArt(p, testing)
    if not db.juice then
        p.burstTest:Hide()
        p.flashTest:Hide()
        StillJuice(p)
    end
    if db.juice then p.burstHolder:Show() else p.burstHolder:Hide() end
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
    local want = db.swing
    for _, p in pairs(pinatas) do
        for key, entry in pairs(p.swingers or {}) do
            if entry.on ~= want then
                local ok = pcall(function()
                    if want then
                        entry.button:AddAuraShownAnimation(entry.swing)
                    else
                        entry.button:RemoveAuraShownAnimation(entry.swing)
                    end
                end)
                if ok then
                    entry.on = want
                    if key == "icon" then p.swinging = want end
                    -- Start or stop it now if the piñata is up; refused in a fight, which is fine:
                    -- the game starts it the next time the debuff lands.
                    pcall(function()
                        if not want then
                            entry.swing:Stop()
                        elseif entry.button:IsShown() then
                            entry.swing:Play()
                        end
                    end)
                else
                    swingPending = true
                end
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

---------------------------------------------------------------------------
-- The mana going to you: blue sparks arc from the piñata into your mana bar
-- on the player frame, the bar surges, and the mana you got rises from it.
---------------------------------------------------------------------------
-- A small number generator with a fixed start, so every payout throws the
-- same well-spread pattern (and the offline test can check it).
local function Dice(seed)
    return function(a, b)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return a + (b - a) * seed / 2147483648
    end
end

-- How the sparks travel without knowing where anything is (a nameplate's
-- place on screen is hidden from addons): each spark is drawn at the
-- piñata, in a frame of ours whose centre sits on the end of your mana bar.
-- That frame then shrinks to nothing around its centre, which pulls the
-- spark from the piñata into the bar. The game works out both places.
-- The arc: the whole rig slides up and back on the way, so the sparks pour
-- over in one curved stream, each a little higher or lower than the last.
-- Keeping its size: shrinking the frame would shrink the spark too, to a dot
-- long before the bar. So the pull runs in ORB_STEPS steps, each halving the
-- frame, while the picture grows by as much in the same steps: the spark
-- keeps its size (within an eighth) the whole way. The steps get shorter, so
-- the spark speeds up as it is drawn in.
local ORB_COUNT, ORB_SECONDS, ORB_STAGGER = 10, 0.56, 0.035
local ORB_THROW = ORB_SECONDS * 0.45        -- the bend is widest a little before halfway
local ORB_SIZES = { 26, 16, 21, 14 }
local ORB_STEPS, ORB_STEP = 6, 0.5            -- ends 1.6% of the way out: on the bar
local ORB_FADE = 0.05                         -- fades as it lands, not before
-- When each step ends, as a share of the flight: the distance left after
-- step k is ORB_STEP^k, and an even pull-in covers it by sqrt(1 - left).
local ORB_STEP_ENDS = {}
for k = 1, ORB_STEPS do ORB_STEP_ENDS[k] = math.sqrt(1 - ORB_STEP ^ k) end
ORB_STEP_ENDS[ORB_STEPS] = 1
local SURGE_IN, SURGE_OUT, SURGE_SWEEP = 0.06, 0.55, 0.30
local flow                 -- built on the first payout
ns.Flow = function() return flow end

-- The player frame's mana bar and its fill, or nothing (another unit frame addon).
local function ManaBar()
    local bar
    if type(PlayerFrame_GetManaBar) == "function" then
        local ok, found = pcall(PlayerFrame_GetManaBar)
        if ok then bar = found end
    end
    if type(bar) ~= "table" then bar = rawget(_G, "PlayerFrameManaBar") end
    if type(bar) ~= "table" or Forbidden(bar) or type(bar.GetStatusBarTexture) ~= "function" then return end
    local ok, fill = pcall(bar.GetStatusBarTexture, bar)
    if not ok or type(fill) ~= "table" then return end
    return bar, fill
end

-- A bright copy of the bar's own fill, added on top of it: the bar flares up.
local function GlowArt(tex, fill)
    CopyFill(tex, fill)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(ENERGIZE_COLOR[1], ENERGIZE_COLOR[2], ENERGIZE_COLOR[3], 1)
end

local function Glint(owner, width, height, white)
    local t = owner:CreateTexture(nil, "OVERLAY")
    t:SetTexture(STAR)
    t:SetBlendMode("ADD")
    t:SetSize(width, height)
    if white then t:SetVertexColor(1, 1, 1, 1)
    else t:SetVertexColor(ENERGIZE_COLOR[1], ENERGIZE_COLOR[2], ENERGIZE_COLOR[3], 1) end
    return t
end

local function BuildFlow(bar, fill)
    local okS, strata = pcall(bar.GetFrameStrata, bar)
    strata = (okS and type(strata) == "string") and strata or "MEDIUM"
    local level = (bar.GetFrameLevel and bar:GetFrameLevel() or 0) + 5
    local okH, height = pcall(bar.GetHeight, bar)
    height = (okH and PlainNumber(height) and height > 0) and height or 10
    local fx = { bar = bar, fill = fill, orbs = {} }

    -- The surge: the bar flares up and swells for a moment.
    local flash = CreateFrame("Frame", nil, UIParent)
    flash:SetFrameStrata(strata)
    flash:SetFrameLevel(level)
    flash:SetAllPoints(bar)
    flash:SetAlpha(0)
    flash:EnableMouse(false)
    local glow = flash:CreateTexture(nil, "OVERLAY")
    GlowArt(glow, fill)
    glow:SetAllPoints(fill)
    local group = flash:CreateAnimationGroup()
    local function Step(g, kind, seconds, smoothing)
        local a = g:CreateAnimation(kind)
        a:SetOrder(1)
        a:SetDuration(seconds)
        if kind == "Scale" then a:SetOrigin("CENTER", 0, 0) end
        if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
        return a
    end
    local flashIn = Step(group, "Alpha", SURGE_IN)
    flashIn:SetFromAlpha(0)
    flashIn:SetToAlpha(1)
    local flashOut = Step(group, "Alpha", SURGE_OUT, "IN")
    flashOut:SetFromAlpha(1)
    flashOut:SetToAlpha(0)
    local swell = Step(group, "Scale", 0.08, "OUT")
    swell:SetScaleFrom(1, 1)
    swell:SetScaleTo(1, 1.6)
    local ebb = Step(group, "Scale", 0.30, "IN_OUT")
    ebb:SetScaleFrom(1, 1)
    ebb:SetScaleTo(1, 1 / 1.6)
    fx.flash, fx.glow, fx.group = flash, glow, group
    -- For LookShots: the bar and the room beside it where the number rises.
    local capture = CreateFrame("Frame", nil, UIParent)
    capture:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 30)
    capture:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 150, 0)
    capture:EnableMouse(false)
    fx.capture = capture
    fx.flashIn, fx.flashOut, fx.swell, fx.ebb = flashIn, flashOut, swell, ebb

    -- A glint that runs along the bar from its start to the end of the fill:
    -- the picture sits on the fill's end, in a frame whose centre is the bar's
    -- start, grown from nothing (the same trick as the sparks, the other way).
    local sweep = CreateFrame("Frame", nil, UIParent)
    sweep:SetFrameStrata(strata)
    sweep:SetFrameLevel(level + 2)
    sweep:SetSize(1, 1)
    sweep:SetPoint("CENTER", bar, "LEFT", 0, 0)
    sweep:SetAlpha(0)
    sweep:EnableMouse(false)
    local glintWide = Glint(sweep, 44, height * 2.2)
    glintWide:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    local glint = Glint(sweep, 16, height * 3, true)
    glint:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    local sweepGroup = sweep:CreateAnimationGroup()
    if sweepGroup.SetToFinalAlpha then sweepGroup:SetToFinalAlpha(true) end
    local sweepIn = Step(sweepGroup, "Alpha", 0.04)
    sweepIn:SetFromAlpha(0)
    sweepIn:SetToAlpha(1)
    local run = Step(sweepGroup, "Scale", SURGE_SWEEP, "OUT")
    run:SetScaleFrom(0.05, 0.05)
    run:SetScaleTo(1, 1)
    local sweepOut = Step(sweepGroup, "Alpha", 0.16, "IN")
    sweepOut:SetFromAlpha(1)
    sweepOut:SetToAlpha(0)
    fx.sweep, fx.sweepGroup, fx.sweepIn, fx.run, fx.sweepOut = sweep, sweepGroup, sweepIn, run, sweepOut

    -- A burst where the glint ends.
    local spark = CreateFrame("Frame", nil, UIParent)
    spark:SetFrameStrata(strata)
    spark:SetFrameLevel(level + 3)
    spark:SetSize(BURST_BOX, BURST_BOX)
    spark:SetScale(0.5)
    spark:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    spark:SetAlpha(0)
    spark:EnableMouse(false)
    BurstArt(spark)
    local sparkGroup = spark:CreateAnimationGroup()
    if sparkGroup.SetToFinalAlpha then sparkGroup:SetToFinalAlpha(true) end
    local sparkIn = Step(sparkGroup, "Alpha", 0.03)
    sparkIn:SetFromAlpha(0)
    sparkIn:SetToAlpha(1)
    local sparkGrow = Step(sparkGroup, "Scale", 0.4, "OUT")
    sparkGrow:SetScaleFrom(0.4, 0.4)
    sparkGrow:SetScaleTo(1.5, 1.5)
    local sparkOut = Step(sparkGroup, "Alpha", 0.3, "IN")
    sparkOut:SetFromAlpha(1)
    sparkOut:SetToAlpha(0)
    fx.spark, fx.sparkGroup, fx.sparkIn, fx.sparkGrow, fx.sparkOut = spark, sparkGroup, sparkIn, sparkGrow, sparkOut

    local roll = Dice(3)
    for i = 1, ORB_COUNT do
        -- The bend: a frame of ours on the bar's end that slides out to one
        -- side and back while the spark flies. It carries the shrinking frame
        -- inside it, so the bend is in plain screen pixels and the spark
        -- swings round in a curve instead of running straight.
        local path = CreateFrame("Frame", nil, UIParent)
        path:SetFrameStrata(strata)
        path:SetFrameLevel(level + 1)
        path:SetSize(1, 1)
        path:SetPoint("CENTER", fill, "RIGHT", 0, 0)
        path:EnableMouse(false)
        local orb = CreateFrame("Frame", nil, path)
        orb:SetFrameStrata(strata)
        orb:SetFrameLevel(level + 1)
        orb:SetSize(1, 1)
        orb:SetPoint("CENTER", path, "CENTER", 0, 0)
        orb:SetAlpha(0)
        orb:EnableMouse(false)
        local size = ORB_SIZES[(i - 1) % #ORB_SIZES + 1]
        local tex = Glint(orb, size, size, i % 3 == 2)
        local g = orb:CreateAnimationGroup()
        if g.SetToFinalAlpha then g:SetToFinalAlpha(true) end
        local fadeIn = Step(g, "Alpha", 0.05)
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)
        local fadeOut = Step(g, "Alpha", ORB_FADE)
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)
        local arc = path:CreateAnimationGroup()
        local out = Step(arc, "Translation", ORB_THROW, "OUT")
        local back = Step(arc, "Translation", ORB_SECONDS - ORB_THROW, "IN")
        -- Close paths and an even spread over them, so the sparks read as one
        -- stream, not a scatter that clumps.
        local bx, by = roll(-10, 10), 64 + ((i * 3) % ORB_COUNT) * 3
        out:SetOffset(bx, by)
        back:SetOffset(-bx, -by)
        -- The picture's growth that undoes the pull's shrinking.
        local keep = tex:CreateAnimationGroup()
        local pulls, grows = {}, {}
        for k = 1, ORB_STEPS do
            local seconds = ORB_SECONDS * (ORB_STEP_ENDS[k] - (ORB_STEP_ENDS[k - 1] or 0))
            local pull = Step(g, "Scale", seconds)
            pull:SetScaleFrom(1, 1)
            pull:SetScaleTo(ORB_STEP, ORB_STEP)
            local grow = Step(keep, "Scale", seconds)
            grow:SetScaleFrom(1, 1)
            grow:SetScaleTo(1 / ORB_STEP, 1 / ORB_STEP)
            pulls[k], grows[k] = pull, grow
        end
        fx.orbs[i] = { path = path, frame = orb, tex = tex, group = g, fadeIn = fadeIn, pulls = pulls,
            keep = keep, grows = grows, fadeOut = fadeOut, arc = arc, out = out, back = back,
            dx = roll(-8, 8), dy = roll(-6, 8) }
    end
    return fx
end

-- Sends the mana from `from` (the piñata's frame; nil: none on screen, the
-- bar only surges) into your mana bar. Does nothing without a visible bar.
local function Flow(from)
    if not (db.enabled and db.manaFlow) then return end
    local bar, fill = ManaBar()
    if not bar then return end
    local ok, visible = pcall(bar.IsVisible, bar)
    if not ok or not Plain(visible) or visible ~= true then return end
    if not flow or flow.fill ~= fill then
        local built, fx = pcall(BuildFlow, bar, fill)
        if not built then return end
        flow = fx
    else
        pcall(GlowArt, flow.glow, fill)              -- keep up with a restyled bar
    end
    local land, last = 0, 0
    if from then
        for i, orb in ipairs(flow.orbs) do
            local delay = (i - 1) * ORB_STAGGER
            orb.group:Stop()
            orb.arc:Stop()
            orb.keep:Stop()
            orb.tex:ClearAllPoints()
            orb.tex:SetPoint("CENTER", from, "CENTER", orb.dx, orb.dy)
            orb.fadeIn:SetStartDelay(delay)
            for k = 1, ORB_STEPS do
                local at = delay + ORB_SECONDS * (ORB_STEP_ENDS[k - 1] or 0)
                orb.pulls[k]:SetStartDelay(at)
                orb.grows[k]:SetStartDelay(at)
            end
            orb.fadeOut:SetStartDelay(delay + ORB_SECONDS - 0.01)
            orb.out:SetStartDelay(delay)
            orb.back:SetStartDelay(delay + ORB_THROW)
            orb.group:Play()
            orb.arc:Play()
            orb.keep:Play()
        end
        land = ORB_SECONDS * 0.9                       -- the bar surges as the first sparks arrive
        last = (ORB_COUNT - 1) * ORB_STAGGER           -- and stays lit while the rest pour in
    end
    flow.group:Stop()
    flow.sweepGroup:Stop()
    flow.sparkGroup:Stop()
    flow.flashIn:SetStartDelay(land)
    flow.flashOut:SetStartDelay(land + SURGE_IN + last)
    flow.swell:SetStartDelay(land)
    flow.ebb:SetStartDelay(land + 0.08)
    flow.sweepIn:SetStartDelay(land)
    flow.run:SetStartDelay(land)
    flow.sweepOut:SetStartDelay(land + SURGE_SWEEP - 0.08)
    local burstAt = land + SURGE_SWEEP - 0.1
    flow.sparkIn:SetStartDelay(burstAt)
    flow.sparkGrow:SetStartDelay(burstAt)
    flow.sparkOut:SetStartDelay(burstAt + 0.1)
    flow.group:Play()
    flow.sweepGroup:Play()
    flow.sparkGroup:Play()
    flow.from = from
    -- When the number should pop: halfway through the stream's arrival, so it
    -- lands with the bulk of the sparks rather than the first one.
    return land + last * 0.5
end
ns.FlowTo = Flow

---------------------------------------------------------------------------
-- The mana you got, as a number
---------------------------------------------------------------------------
-- Read, never guessed: with no real amount there is no number. First the
-- rank: each Judgement of Wisdom rank gives a set amount, and the game's own
-- text for that rank says how much ("... restore 59 mana ..."), so the
-- payout's spell ID is enough and nothing has to be read mid-fight. Without
-- it (a client whose payout carries no spell ID, or text that names no
-- mana), the amount on the game's own ENERGIZE hit message when the client
-- lets addons see it, else the step up in your own mana at the moment of the
-- payout. Of the steps close to the payout, the closest in time counts.
local GAIN_WINDOW = 0.2                 -- seconds either side of the payout
local manaSeen                          -- your mana at the last update
local rises = {}                        -- recent steps up: { at = time, gain = mana }
local energized                         -- the last readable ENERGIZE amount: { at, amount }

local function ReadMana()
    if type(UnitPower) ~= "function" then return end
    local ok, v = pcall(UnitPower, "player", 0)
    if ok and PlainNumber(v) then return v end
end

-- UNIT_POWER_FREQUENT for your mana.
local function OnMana()
    local v, now = ReadMana(), Now()
    if v and manaSeen and v > manaSeen then
        rises[#rises + 1] = { at = now, gain = v - manaSeen }
    end
    manaSeen = v
    while rises[1] and now - rises[1].at > 2 do table.remove(rises, 1) end
end
ns.OnMana = OnMana

-- The UNIT_COMBAT amount of an ENERGIZE on you, if the client shows it.
local function NoteEnergize(amount)
    if PlainNumber(amount) and amount > 0 then energized = { at = Now(), amount = amount } end
end

-- The mana a spell's text says it restores, or nil.
local function SpellText(id)
    for _, get in ipairs({ C_Spell and C_Spell.GetSpellDescription, GetSpellDescription }) do
        if type(get) == "function" then
            local ok, text = pcall(get, id)
            if ok and Plain(text) and type(text) == "string" and text ~= "" then return text end
        end
    end
end

local function ManaInText(text)
    local n = text and text:lower():match("(%d[%d,]*) mana")
    n = n and tonumber((n:gsub(",", "")))
    if n and n >= 1 then return n end
end

-- The mana the Judgement of Wisdom rank behind payout `spellID` gives, from
-- the payout's text or else its debuff's. Kept once read.
local rankMana = {}
local function RankMana(spellID)
    if not PlainNumber(spellID) then return end
    if rankMana[spellID] then return rankMana[spellID] end
    local n = ManaInText(SpellText(spellID))
    if not n and PAYOUT_RANK[spellID] then n = ManaInText(SpellText(PAYOUT_RANK[spellID])) end
    rankMana[spellID] = n
    return n
end
ns.RankMana = RankMana

-- For /pinata debug: "33, 46, 59", "?" for a rank whose text names no mana.
local function RankList()
    local out = {}
    for i, id in ipairs({ 20268, 20352, 20353 }) do out[i] = tostring(RankMana(id) or "?") end
    return table.concat(out, ", ")
end

-- Asks the game to load the ranks' text, so it is there by the first payout.
local function LoadRankText()
    if not (C_Spell and C_Spell.RequestLoadSpellData) then return end
    for payout, debuff in pairs(PAYOUT_RANK) do
        pcall(C_Spell.RequestLoadSpellData, payout)
        pcall(C_Spell.RequestLoadSpellData, debuff)
    end
end

-- The mana a payout at `at` gave you, or nil.
local function GainAt(at)
    if energized and math.abs(energized.at - at) <= GAIN_WINDOW then return floor(energized.amount + 0.5) end
    local best
    for _, rise in ipairs(rises) do
        local off = math.abs(rise.at - at)
        if off <= GAIN_WINDOW and (not best or off < best.off or (off == best.off and rise.gain > best.gain)) then
            best = { off = off, gain = rise.gain }
        end
    end
    if best and best.gain >= 1 then return floor(best.gain + 0.5) end
end
ns.GainAt = GainAt

-- The number: the font the game's unit frames show hit numbers in
-- (CombatFeedback), in its ENERGIZE colour, written the way the game's
-- floating combat text writes a mana gain. It pops in a little big, snaps
-- to size, rises and fades. Beside the end of your mana bar, where the
-- sparks land, so it covers nothing on the player frame; above the piñata
-- when your mana bar isn't the game's own.
local GAIN_POP, GAIN_RISE, GAIN_SECONDS, GAIN_HOLD = 1.8, 26, 1.15, 0.55
local gain
ns.Gain = function() return gain end

local function BuildGain()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetSize(1, 1)
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    local font = rawget(_G, "NumberFontNormalHuge") and "NumberFontNormalHuge" or "GameFontNormalHuge"
    local text = frame:CreateFontString(nil, "OVERLAY", font)
    text:SetTextColor(ENERGIZE_COLOR[1], ENERGIZE_COLOR[2], ENERGIZE_COLOR[3])
    local group = frame:CreateAnimationGroup()
    if group.SetToFinalAlpha then group:SetToFinalAlpha(true) end
    local function Step(kind, delay, seconds, smoothing)
        local a = group:CreateAnimation(kind)
        a:SetOrder(1)
        a:SetStartDelay(delay)
        a:SetDuration(seconds)
        if kind == "Scale" then a:SetOrigin("CENTER", 0, 0) end
        if smoothing and a.SetSmoothing then a:SetSmoothing(smoothing) end
        return a
    end
    local fx = { frame = frame, text = text, group = group }
    fx.show = Step("Alpha", 0, 0.01)                 -- at full strength from the pop's first frame
    fx.show:SetFromAlpha(0)
    fx.show:SetToAlpha(1)
    fx.pop = Step("Scale", 0, 0.12, "OUT")
    fx.pop:SetScaleFrom(GAIN_POP, GAIN_POP)
    fx.pop:SetScaleTo(1, 1)
    fx.rise = Step("Translation", 0.12, GAIN_SECONDS - 0.12, "OUT")
    fx.rise:SetOffset(0, GAIN_RISE)
    fx.hide = Step("Alpha", GAIN_HOLD, GAIN_SECONDS - GAIN_HOLD, "IN")
    fx.hide:SetFromAlpha(1)
    fx.hide:SetToAlpha(0)
    return fx
end

-- Shows "+amount Mana" after `delay` seconds: by the bar when `bar` is given,
-- else above `from` (a piñata's frame).
local function ShowGain(amount, delay, bar, from)
    if not (db.enabled and db.manaNumber) or not PlainNumber(amount) or amount < 1 then return end
    if not (bar or from) then return end
    if not gain then
        local built, fx = pcall(BuildGain)
        if not built then return end
        gain = fx
    end
    local fx = gain
    fx.group:Stop()
    fx.frame:ClearAllPoints()
    fx.text:ClearAllPoints()
    if bar then
        fx.frame:SetPoint("CENTER", bar, "RIGHT", 8, 0)
        fx.text:SetPoint("LEFT", fx.frame, "CENTER", 0, 0)
    else
        fx.frame:SetPoint("CENTER", from, "TOP", 0, 4)
        fx.text:SetPoint("BOTTOM", fx.frame, "CENTER", 0, 0)
    end
    fx.text:SetText("+" .. floor(amount) .. " " .. ((type(MANA) == "string" and MANA) or "Mana"))
    delay = max(0, delay or 0)
    for _, a in ipairs({ fx.show, fx.pop }) do a:SetStartDelay(delay) end
    fx.rise:SetStartDelay(delay + 0.12)
    fx.hide:SetStartDelay(delay + GAIN_HOLD)
    fx.group:Play()
    fx.amount, fx.bar, fx.from = amount, bar, from
end
ns.ShowGain = ShowGain

-- After a payout at `at`, the number as the sparks land (`land` seconds
-- after the payout) or straight away if none fly: the rank's amount when the
-- payout's spell ID gives one, else once the mana can be read.
local function GainLater(at, land, from, spellID)
    if not db.manaNumber then return end
    local bar = land and flow and flow.bar or nil
    local ranked = RankMana(spellID)
    if ranked then return ShowGain(ranked, land or 0, bar, from) end
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(GAIN_WINDOW, function()
        local amount = GainAt(at)
        if amount then ShowGain(amount, (land or 0) - GAIN_WINDOW, bar, from) end
    end)
end

-- The blow that gave you mana: a big burst on your target, the mana flying
-- into your bar, the number, and the coin sound if that is on.
local lastPayout
local function Payout(spellID)
    if not db.enabled then return end
    local now = Now()
    if lastPayout and now - lastPayout < PAYOUT_GAP then return end
    lastPayout = now
    CoinSound()
    local p = PinataFor("target")
    if p then Hit(p, "payout") end
    local land = Flow(p and p.holder)
    GainLater(now, land, p and p.holder, spellID)
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

local function OnCombat(unit, action, flag, amount)
    if not Plain(unit) or type(unit) ~= "string" then return end
    if unit == "player" then
        -- Mana given to you right as your target was hit: the same payout,
        -- for clients where the mana does not arrive as a spell cast.
        if Plain(action) and action == "ENERGIZE" and ManaUser() then
            NoteEnergize(amount)
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
    if unit == "player" and IsPayout(spellID) then Payout(spellID) end
end

---------------------------------------------------------------------------
-- The hit preview: a stand-in nameplate in the middle of the screen that
-- takes a string of blows, so the effects can be seen without a paladin.
---------------------------------------------------------------------------
-- Plain blows, a crit, a glancing blow, a miss and two payouts.
local PREVIEW_BLOWS = { "normal", "normal", "crit", "normal", "payout", "glance", "normal", "miss", "crit", "payout" }
-- The preview's payouts give no mana, so its number is a sample.
local PREVIEW_GAIN = 85
local PREVIEW_GAP, PREVIEW_PAYOUT_GAP, PREVIEW_START, PREVIEW_END = 0.55, 1.3, 0.4, 1.4
local PREVIEW_BAR_W, PREVIEW_BAR_H = 120, 13          -- the size of a small nameplate health bar
-- /pinata stills plays the same blows, but stops everything for a moment at
-- these points (seconds after the blow) so LookShots can take a picture of
-- each: long enough for it to see the frame settle, and far enough apart
-- for its five seconds between pictures.
local PREVIEW_STILLS = {
    [1]  = { label = "still: hit", at = 0.03 },             -- the impact: white and squashed, before it moves
    [3]  = { label = "still: crit", at = 0.12 },
    [5]  = { label = "still: payout", at = 0.14 },
    [10] = { label = "still: mana surge", at = 0.82, bar = true },   -- your mana bar and the number
}
local STILL_HOLD, STILL_SPACING = 2.0, 6.0
ns.PREVIEW_BLOWS, ns.PREVIEW_STILLS = PREVIEW_BLOWS, PREVIEW_STILLS
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

    local pv = BuildRig(frame)
    RigLevels(pv, (frame:GetFrameLevel() or 0) + LEVEL)
    pv.holder:Show()
    pv.burstHolder:Show()
    -- The area the blows reach, for LookShots: the bar, the piñata and its sparkle.
    local capture = CreateFrame("Frame", nil, frame)
    capture:SetSize(300, 170)
    capture:SetPoint("BOTTOM", frame, "BOTTOM", 0, -12)
    pv.frame, pv.bar, pv.capture, pv.run = frame, bar, capture, 0
    return pv
end

-- Every animation the preview can have running, its own and the payout's.
local function PreviewGroups(pv)
    local list = { pv.whack, pv.flash, pv.burst }
    for _, group in ipairs(pv.testSwings) do list[#list + 1] = group end
    if gain then list[#list + 1] = gain.group end
    if flow then
        list[#list + 1] = flow.group
        list[#list + 1] = flow.sweepGroup
        list[#list + 1] = flow.sparkGroup
        for _, orb in ipairs(flow.orbs) do
            list[#list + 1] = orb.group
            list[#list + 1] = orb.arc
            list[#list + 1] = orb.keep
        end
    end
    return list
end

local function Hold(pv, label)
    pv.paused = {}
    for _, group in ipairs(PreviewGroups(pv)) do
        if group.Pause and group:IsPlaying() then
            group:Pause()
            pv.paused[#pv.paused + 1] = group
        end
    end
    pv.still = label
end

local function Resume(pv)
    pv.still = nil
    for _, group in ipairs(pv.paused or {}) do group:Play() end
    pv.paused = nil
end

local function StopPreview()
    if not preview then return end
    local pv = preview
    pv.run = pv.run + 1
    for _, group in ipairs(pv.paused or {}) do group:Stop() end
    pv.paused, pv.still = nil, nil
    StillJuice(pv)
    if gain then gain.group:Stop() end
    ShowTestArt(pv, false)
    pv.frame:Hide()
end

local function PreviewShowing()
    return preview ~= nil and preview.frame:IsShown() == true
end
ns.PreviewShowing = PreviewShowing

local function PreviewBlow(pv, kind)
    Strike(pv, kind)
    if kind == "payout" then
        CoinSound()
        local land = Flow(pv.holder)
        ShowGain(PREVIEW_GAIN, land or 0, land and flow and flow.bar or nil, pv.holder)
    end
end

-- Plays the blows one after another and hides itself after the last.
-- Asked again while it runs, it stops. `stills`: hold at PREVIEW_STILLS.
local function RunPreview(stills)
    if PreviewShowing() then StopPreview(); return false end
    preview = preview or BuildPreview()
    local pv = preview
    RigLayout(pv, pv.frame, db.xOffset, db.yOffset)
    pv.frame:Show()
    ShowTestArt(pv, true)
    pv.run = pv.run + 1
    pv.dir, pv.step, pv.still, pv.lastHold = nil, 0, nil, nil
    pv.stills = stills and true or false
    local run = pv.run
    local function Next()
        if pv.run ~= run then return end
        local kind = PREVIEW_BLOWS[pv.step + 1]
        if not kind then
            C_Timer.After(PREVIEW_END, function() if pv.run == run then StopPreview() end end)
            return
        end
        local still = pv.stills and PREVIEW_STILLS[pv.step + 1]
        if still and pv.lastHold then
            local wait = pv.lastHold + STILL_SPACING - (Now() + still.at)
            if wait > 0 then
                C_Timer.After(wait, Next)
                return
            end
        end
        pv.step = pv.step + 1
        PreviewBlow(pv, kind)
        local gap = kind == "payout" and PREVIEW_PAYOUT_GAP or PREVIEW_GAP
        if not still then
            C_Timer.After(gap, Next)
            return
        end
        C_Timer.After(still.at, function()
            if pv.run ~= run then return end
            Hold(pv, still.label)
            pv.lastHold = Now()
            C_Timer.After(STILL_HOLD, function()
                if pv.run ~= run then return end
                Resume(pv)
                C_Timer.After(max(0.05, gap - still.at), Next)
            end)
        end)
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
    local version = type(db.settingsVersion) == "number" and db.settingsVersion or 0
    if version < 2 and db.size == 36 then db.size = DEFAULTS.size end   -- the first build's smaller default
    if version < 3 then db.sound = false end    -- 1.1.0 had the coin on for everyone; off once, then it's the player's choice
    db.settingsVersion = 3
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
    if PreviewShowing() and not preview.stills then return preview.capture end
end

-- /pinata stills: each held moment is its own picture.
-- The mana surge is a picture of your mana bar (the frame the surge lies on).
local function StillFrame(still)
    return function()
        if not (PreviewShowing() and preview.still == still.label) then return end
        if still.bar then return flow and flow.capture or nil end
        return preview.capture
    end
end

local LOOKS = { { label = "hit preview", frame = PreviewFrame } }
for i = 1, #PREVIEW_BLOWS do
    local still = PREVIEW_STILLS[i]
    if still then LOOKS[#LOOKS + 1] = { label = still.label, frame = StillFrame(still) } end
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
    frames = LOOKS,
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
if not (f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, "UNIT_POWER_FREQUENT", "player")) then
    pcall(f.RegisterEvent, f, "UNIT_POWER_FREQUENT")
end
if not (f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")) then
    pcall(f.RegisterEvent, f, "UNIT_SPELLCAST_SUCCEEDED")
end

f:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
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
        OnCombat(arg1, arg2, arg3, arg4)

    elseif event == "UNIT_POWER_FREQUENT" then
        if arg1 == "player" and arg2 == "MANA" then OnMana() end

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
        OnMana()                                  -- where your mana stands, to see it rise
        LoadRankText()                            -- each rank's mana, for the number
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

local function AnySlotError()
    for _, state in pairs(NATIVE) do
        if state.error then return true end
    end
    return false
end

local function PrintStatus()
    print(PREFIX .. (db.enabled and "on" or "OFF")
        .. "  |  size " .. db.size
        .. "  |  x " .. db.xOffset .. ", y " .. db.yOffset
        .. "  |  swing " .. OnOff(db.swing) .. (swingPending and " (changes after the fight)" or "")
        .. "  |  blue health bar " .. OnOff(db.colorBar)
        .. "  |  bounce on hits " .. OnOff(db.juice)
        .. "  |  mana to your bar " .. OnOff(db.manaFlow)
        .. "  |  mana number " .. OnOff(db.manaNumber)
        .. "  |  coin sound " .. OnOff(db.sound)
        .. (testing and "  |  TEST piñatas showing" or "")
        .. (AnySlotError() and "  |  not fully working, see /pinata debug" or ""))
end

local function PrintHelp()
    print(PREFIX .. "commands:")
    print("  /pinata test (a piñata on every nameplate, to size and place it)   -  /pinata config (options window)")
    print("  /pinata size <16-96>   -  /pinata x <-100..100>   -  /pinata y <-100..100>   -  /pinata swing")
    print("  /pinata bar (the enemy's health bar turns blue too, on/off)")
    print("  /pinata juice (bounce and sparkle on hits, on/off)   -  /pinata flow (mana flies into your mana bar, on/off)")
    print("  /pinata number (\"+N Mana\" by your mana bar, on/off)")
    print("  /pinata sound (coin sound on mana, on/off)   -  /pinata preview   -  /pinata stills (the preview, paused at each moment)")
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

    elseif cmd == "flow" or cmd == "mana" then
        ns.Set("manaFlow", not db.manaFlow)

    elseif cmd == "number" or cmd == "numbers" then
        ns.Set("manaNumber", not db.manaNumber)

    elseif cmd == "preview" then
        if RunPreview() then print(PREFIX .. "hit preview in the middle of the screen. /pinata preview again stops it.") end
        return

    elseif cmd == "stills" then
        if RunPreview(true) then
            print(PREFIX .. "hit preview with pauses, so each moment can be looked at (about half a minute). "
                .. "/pinata stills again stops it.")
        end
        return

    elseif cmd == "test" then
        ns.SetTesting(not testing)
        TestNote()
        SyncOptions()
        return

    elseif cmd == "reset" then
        ns.Reset()

    elseif cmd == "debug" then
        local ids, live, bars, total = {}, 0, 0, 0
        local hitSlots = {}
        for id in pairs(spells) do ids[#ids + 1] = id end
        table.sort(ids)
        for _, p in pairs(pinatas) do
            total = total + 1
            if p.container then live = live + 1 end
            if p.barContainer then bars = bars + 1 end
            for _, kind in ipairs(HIT_SLOTS) do
                if p[NATIVE[kind].field] then hitSlots[kind] = (hitSlots[kind] or 0) + 1 end
            end
        end
        local icon, bar = NATIVE.icon, NATIVE.bar
        local hitText = {}
        for _, kind in ipairs(HIT_SLOTS) do
            local state = NATIVE[kind]
            hitText[#hitText + 1] = state.name .. " " .. (hitSlots[kind] or 0)
                .. (state.error and (" FAILED " .. state.tries .. "x") or "")
        end
        print(PREFIX .. "build " .. tostring((select(4, GetBuildInfo())))
            .. ", nameplates now: " .. PlateCount()
            .. ", piñatas made: " .. total .. " (" .. live .. " with a working aura slot, " .. bars .. " with a health bar slot)"
            .. ", auras hidden right now: " .. tostring(AurasSecret())
            .. ", aura slots: " .. (icon.error and ("FAILED " .. icon.tries .. "x") or "ok")
            .. ", health bar slots: " .. (bar.error and ("FAILED " .. bar.tries .. "x") or "ok")
            .. ", hit slots: " .. table.concat(hitText, ", "))
        if icon.error then print(PREFIX .. "aura slot error: " .. icon.error) end
        if bar.error then print(PREFIX .. "health bar slot error: " .. bar.error) end
        for _, kind in ipairs(HIT_SLOTS) do
            local state = NATIVE[kind]
            if state.error then print(PREFIX .. state.name .. " slot error: " .. state.error) end
        end
        local blows = 0
        for _, p in pairs(pinatas) do if p.lastBlowAt then blows = blows + 1 end end
        print(PREFIX .. "nameplates hit so far: " .. blows
            .. (lastPayout and (", last mana payout " .. floor(Now() - lastPayout) .. " s ago") or ", no mana payout seen yet")
            .. ", mana per Judgement of Wisdom rank: " .. RankList()
            .. ", your mana " .. (ReadMana() and "readable" or "hidden right now")
            .. (gain and gain.amount and (", last number +" .. gain.amount) or ""))
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
