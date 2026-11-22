-- Aura Advisor: what is happening in the fight, as far as the game lets an addon see it.
--
-- WoW Forever hides a lot from addons in a fight (no combat log, damage amounts and most
-- enemy spell names are "secret values"). What is left, and what this file collects:
--   * UNIT_COMBAT on you and your party: every hit, with its damage school (the amount is
--     hidden, the school is not), and whether it was a crit or a crushing blow;
--   * UNIT_SPELLCAST_DELAYED on you and your party: a cast that a hit pushed back;
--   * UNIT_SPELLCAST_START on enemies (target, focus, nameplates): an enemy is casting, and
--     when the game shows the spell's name, which school it is;
--   * how many enemies are in the fight.
-- Every value read from the game is checked for being hidden before it is used.
local _, ns = ...
local Data = ns.Data
local S = {}
ns.Signals = S

local HALF_LIFE = { hit = 5, magic = 12, push = 8, cast = 6 }  -- seconds
local KEEP = 60             -- seconds an event is remembered at all
local RECENT = 10           -- seconds counted for "5 Fire hits in 10 s"
local SCAN_EVERY = 1        -- seconds between looks at the enemies
S.RECENT = RECENT

local MINE = { player = true, party1 = false, party2 = false, party3 = false, party4 = false }
local AVOIDED = { DODGE = true, PARRY = true, MISS = true, EVADE = true, DEFLECT = true }
local SOAKED = { RESIST = true, IMMUNE = true, REFLECT = true, ABSORB = true }
S.log = {}
S.enemies = { engaged = 0 }
S.selfHarm = {}             -- unit -> { school, untilT }: that unit is hurting itself (Hellfire, Life Tap)
S.stats = { combat = 0, hits = 0, hiddenSchool = 0, hiddenEvent = 0, pushes = 0,
            enemyCasts = 0, namedCasts = 0, schoolCasts = 0, selfHarm = 0, far = 0 }
local SelfInflicted         -- below

-- A hidden value may not even be compared, so ask before anything else.
local function Secret(v)
    return issecretvalue and issecretvalue(v) and true or false
end
S.Secret = Secret

local function Plain(v)
    if Secret(v) then return nil end
    return v
end
S.Plain = Plain

local function Now()
    return GetTime and GetTime() or 0
end

-- In a battleground or an arena? (IsInInstance's second return: "pvp" or "arena")
function S.InPvP()
    if not IsInInstance then return false end
    local ok, _, kind = pcall(IsInInstance)
    kind = ok and Plain(kind) or nil
    return kind == "pvp" or kind == "arena"
end

-- Is a party member near enough for your aura to reach them? An aura reaches the party within
-- 30 yards; the game tells an addon only "within about 40 yards" (UnitInRange), which is close
-- enough. In a battleground your party is spread over the map: hits on someone at the other
-- base say nothing about which aura you should wear. When the game won't say, they count.
function S.Near(unit)
    if unit == "player" then return true end
    if UnitIsVisible then
        local ok, v = pcall(UnitIsVisible, unit)
        if ok and Plain(v) == false then return false end
    end
    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        if ok then
            inRange, checked = Plain(inRange), Plain(checked)
            if inRange == false and checked ~= false then return false end
        end
    end
    return true
end
local Near = S.Near

function S.Reset()
    S.log = {}
    S.enemies = { engaged = 0 }
    S.selfHarm = {}
    S.castBy = {}
    S.lastScan = nil
end

----------------------------------------------------------------------
-- Recording
----------------------------------------------------------------------
-- school: "physical", "fire", "frost", "shadow", "other", or "unknown" (the game hid it)
-- unit: who was hit ("player", "party1"...), or nil (a pretend hit)
function S.Hit(now, mine, school, landed, heavy, unit)
    S.log[#S.log + 1] = { t = now, kind = "hit", mine = mine and true or false, school = school,
                          landed = landed and true or false, heavy = heavy and true or false, unit = unit }
    S.stats.hits = S.stats.hits + 1
end

function S.Push(now, mine)
    S.log[#S.log + 1] = { t = now, kind = "push", mine = mine and true or false }
    S.stats.pushes = S.stats.pushes + 1
end

S.castBy = {}               -- enemy unit -> its cast being counted, until it lands or fails

function S.EnemyCast(now, school, name, unit)
    local ev = { t = now, kind = "cast", school = school, name = name }
    S.log[#S.log + 1] = ev
    if unit then S.castBy[unit] = ev end
    S.stats.enemyCasts = S.stats.enemyCasts + 1
    if name then S.stats.namedCasts = S.stats.namedCasts + 1 end
    if school then S.stats.schoolCasts = S.stats.schoolCasts + 1 end
end

-- UNIT_SPELLCAST_INTERRUPTED / FAILED: an interrupted cast hits nobody, so it stops counting.
function S.OnCastFailed(unit)
    unit = Plain(unit)
    if type(unit) ~= "string" then return end
    local ev = S.castBy[unit]
    if ev then
        ev.dropped = true
        S.castBy[unit] = nil
    end
end

----------------------------------------------------------------------
-- Game events
----------------------------------------------------------------------
-- UNIT_COMBAT: unit, action, flag, amount, schoolMask
function S.OnUnitCombat(unit, action, flag, amount, mask)
    unit = Plain(unit)
    if type(unit) ~= "string" or MINE[unit] == nil then return end
    S.stats.combat = S.stats.combat + 1
    if not Near(unit) then
        S.stats.far = S.stats.far + 1
        return
    end
    action = Plain(action)
    if type(action) ~= "string" then
        S.stats.hiddenEvent = S.stats.hiddenEvent + 1
        return
    end
    flag = Plain(flag)
    local school
    if Plain(mask) ~= nil then school = Data.SchoolOfMask(mask) end
    local mine, now = MINE[unit], Now()
    -- a hit from the unit's own spell (a party warlock's Hellfire) is no enemy's
    if action ~= "BLOCK" and not AVOIDED[action] and SelfInflicted(unit, school or "unknown", now) then
        S.stats.selfHarm = S.stats.selfHarm + 1
        return
    end

    if action == "WOUND" then
        if not school then
            S.stats.hiddenSchool = S.stats.hiddenSchool + 1
            school = "unknown"
        end
        -- An amount of 0 with no reason given is a plain miss. A hidden amount counts as a hit.
        local landed = true
        if Plain(amount) == 0 and flag ~= "ABSORB" and flag ~= "BLOCK" and flag ~= "RESIST" then landed = false end
        S.Hit(now, mine, school, landed, flag == "CRITICAL" or flag == "CRUSHING", unit)
    elseif action == "BLOCK" then
        S.Hit(now, mine, "physical", true, false, unit)
    elseif AVOIDED[action] then
        S.Hit(now, mine, "physical", false, false, unit)
    elseif action == "IMMUNE" then
        -- nothing got through (Divine Shield, say): no aura would have helped
        S.Hit(now, mine, "unknown", false, false, unit)
    elseif SOAKED[action] then
        if not school or school == "physical" then school = (action == "ABSORB") and "unknown" or "other" end
        S.Hit(now, mine, school, true, false, unit)
    end
end

-- UNIT_SPELLCAST_DELAYED: a hit pushed a cast back
function S.OnCastDelayed(unit)
    unit = Plain(unit)
    if type(unit) ~= "string" or MINE[unit] == nil then return end
    if not Near(unit) then
        S.stats.far = S.stats.far + 1
        return
    end
    S.Push(Now(), MINE[unit])
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok then return Plain(name) end
    elseif GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok then return Plain(name) end
    end
end

----------------------------------------------------------------------
-- Hits a unit deals itself. Told apart by what it is casting, because the game doesn't say
-- who dealt a hit: by the cast events, and by asking the game what it is channelling right
-- now (that also works after a /reload in the middle of a Hellfire).
----------------------------------------------------------------------
local harmNames
local function HarmByName(name)
    if not harmNames then
        harmNames = {}
        for _, s in ipairs(Data.SELF_HARM) do
            harmNames[s.english:lower()] = s
            local localName = SpellName(s.ids[1])
            if type(localName) == "string" then harmNames[localName:lower()] = s end
        end
    end
    return harmNames[name:lower()]
end

local function SelfHarmOf(spellID, name)
    spellID = Plain(spellID)
    if type(spellID) == "number" then
        if Data.SELF_HARM_BY_ID[spellID] then return Data.SELF_HARM_BY_ID[spellID] end
        if type(name) ~= "string" then name = SpellName(spellID) end
    end
    if type(name) == "string" then return HarmByName(name) end
end

local function IsWarlock(unit)
    if not UnitClass then return false end
    local ok, _, class = pcall(UnitClass, unit)
    return ok and Plain(class) == "WARLOCK"
end

-- What the unit is channelling: a SELF_HARM entry, "hidden" when the game won't say, or nil.
local function Channel(unit)
    if not UnitChannelInfo then return nil end
    local ok, name, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, unit)
    if not ok then return nil end
    if Secret(name) or Secret(spellID) then return "hidden" end
    if name == nil and spellID == nil then return nil end
    return SelfHarmOf(spellID, name)
end

local function Covers(school, hitSchool)
    return hitSchool == school or hitSchool == "unknown"
end

SelfInflicted = function(unit, school, now)
    local rec = S.selfHarm[unit]
    if rec and now <= rec.untilT and Covers(rec.school, school) then return true end
    local live = Channel(unit)
    if type(live) == "table" then return Covers(live.school, school) end
    -- the game hides what a warlock is channelling: their own Fire hits are most likely Hellfire
    if live == "hidden" and IsWarlock(unit) then return school == "fire" end
    return false
end

-- A hit can come in just before the cast that caused it (Life Tap): take back the ones of that
-- school on that unit from the moment before.
local function TakeBack(unit, school, now)
    local log = S.log
    for i = #log, 1, -1 do
        local ev = log[i]
        if now - ev.t > 0.5 then break end
        if ev.kind == "hit" and ev.unit == unit and Covers(school, ev.school) then
            table.remove(log, i)
            S.stats.hits = S.stats.hits - 1
            S.stats.selfHarm = S.stats.selfHarm + 1
        end
    end
end

-- UNIT_SPELLCAST_CHANNEL_START / UNIT_SPELLCAST_SUCCEEDED from you or your party
function S.OnFriendlyCast(unit, spellID, channel)
    unit = Plain(unit)
    if type(unit) ~= "string" or MINE[unit] == nil then return end
    local harm = SelfHarmOf(spellID)
    if not harm and channel and Plain(spellID) == nil and IsWarlock(unit) then
        harm = Data.SELF_HARM[1]        -- a warlock channelling something hidden: maybe Hellfire
    end
    if not harm then return end
    -- a channel lasts until it stops (Hellfire: 15 s at most); an instant hurts once, now
    local now = Now()
    S.selfHarm[unit] = { school = harm.school, untilT = now + ((channel and harm.channel) and 20 or 0.6) }
    if not (channel and harm.channel) then TakeBack(unit, harm.school, now) end
end

-- UNIT_SPELLCAST_CHANNEL_STOP: the last tick can land a moment after the channel ends
function S.OnChannelStop(unit)
    unit = Plain(unit)
    local rec = type(unit) == "string" and S.selfHarm[unit]
    if rec then rec.untilT = math.min(rec.untilT, Now() + 1.5) end
end

local function HasPlate(unit)
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return false end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    return ok and plate ~= nil
end

local function Hostile(unit)
    if not UnitCanAttack then return false end
    local ok, can = pcall(UnitCanAttack, "player", unit)
    return ok and Plain(can) == true
end

local function Fighting(unit)
    if not UnitAffectingCombat then return false end
    local ok, v = pcall(UnitAffectingCombat, unit)
    return ok and Plain(v) == true
end

-- Is the enemy's target you or someone in your party? Only when the game says so.
local GROUP = { "player", "party1", "party2", "party3", "party4" }
local function AimedAtUs(unit)
    if not UnitIsUnit then return false end
    local target = unit .. "target"
    for _, u in ipairs(GROUP) do
        local ok, same = pcall(UnitIsUnit, target, u)
        if ok and Plain(same) == true then return Near(u) end
    end
    return false
end

-- UNIT_SPELLCAST_START / UNIT_SPELLCAST_CHANNEL_START
function S.OnCastStart(unit, spellID)
    unit = Plain(unit)
    if type(unit) ~= "string" then return end
    local plate = unit:find("^nameplate%d+$") ~= nil
    if not plate and unit ~= "target" and unit ~= "focus" then return end
    if not Fighting("player") or not Hostile(unit) then return end
    if not plate and HasPlate(unit) then return end     -- its nameplate reports the same cast
    if not AimedAtUs(unit) then return end              -- at someone else: no aura of yours helps

    local name
    spellID = Plain(spellID)
    if type(spellID) == "number" then name = SpellName(spellID) end
    if not name then
        for _, f in ipairs({ UnitCastingInfo or false, UnitChannelInfo or false }) do
            if f and not name then
                local ok, n = pcall(f, unit)
                if ok and type(Plain(n)) == "string" then name = n end
            end
        end
    end
    if type(name) ~= "string" then name = nil end
    S.EnemyCast(Now(), name and Data.SchoolOfSpellName(name) or nil, name, unit)
end

----------------------------------------------------------------------
-- The enemies in the fight (from the nameplates, or the target without them)
----------------------------------------------------------------------
-- Only how many: what an enemy is (class, elite, boss) says nothing about what is hitting you.
local function LookAt(unit, e)
    if Hostile(unit) and Fighting(unit) then e.engaged = e.engaged + 1 end
end

function S.ScanEnemies(now, force)
    if not force and S.lastScan and now - S.lastScan < SCAN_EVERY then return end
    S.lastScan = now
    local e = { engaged = 0 }
    local targetSeen = false
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local okUnit, unit = pcall(function()
                    if plate.IsForbidden and plate:IsForbidden() then return nil end
                    return plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                end)
                unit = okUnit and Plain(unit) or nil
                if type(unit) == "string" then pcall(LookAt, unit, e, false) end
            end
        end
        targetSeen = HasPlate("target")
    end
    if not targetSeen and UnitExists then
        local ok, exists = pcall(UnitExists, "target")
        if ok and Plain(exists) then pcall(LookAt, "target", e, true) end
    end
    S.enemies = e
end

----------------------------------------------------------------------
-- The numbers the advisor works from. Every event fades: after one half-life it counts
-- half, so the picture follows the fight without jumping at every single hit.
----------------------------------------------------------------------
local function Weight(age, half)
    return 0.5 ^ (age / half)
end

function S.Summary(now)
    local sum = {
        physMine = 0, physParty = 0,        -- physical hits that landed (crits and crushing blows count 1.5)
        swings = 0,                         -- physical attacks that were dodged, parried or missed
        heavy = 0,                          -- crits and crushing blows
        magic = { fire = 0, frost = 0, shadow = 0, other = 0 },
        pushMine = 0, pushParty = 0,        -- casts pushed back
        casts = { fire = 0, frost = 0, shadow = 0, unknown = 0 },   -- enemy spells being cast (unknown: only "a fight is on")
        castName = {},                      -- school -> the latest spell name seen
        count = { physical = 0, fire = 0, frost = 0, shadow = 0, other = 0, unknown = 0,
                  pushMine = 0, pushParty = 0, casts = 0 },          -- plain counts, last 10 s
        spread = { fire = 0, frost = 0, shadow = 0 },  -- how many of you that school hit, last 10 s
        enemies = S.enemies,
        pressure = 0,                       -- everything together: 0 means nothing is going on
    }
    local hitBy = { fire = {}, frost = {}, shadow = {} }
    local log, keep = S.log, {}
    for i = 1, #log do
        local ev = log[i]
        local age = now - ev.t
        if age < 0 then age = 0 end
        if age <= KEEP and not ev.dropped then
            if ev.kind == "hit" and age <= RECENT and hitBy[ev.school] then
                local who = ev.unit or ("pretend" .. i)
                if not hitBy[ev.school][who] then
                    hitBy[ev.school][who] = true
                    sum.spread[ev.school] = sum.spread[ev.school] + 1
                end
            end
            keep[#keep + 1] = ev
            local recent = age <= RECENT
            if ev.kind == "hit" then
                local magic = sum.magic[ev.school] ~= nil
                local w = Weight(age, magic and HALF_LIFE.magic or HALF_LIFE.hit)
                if ev.school == "physical" then
                    if ev.landed then
                        local pts = w * (ev.heavy and 1.5 or 1)
                        if ev.mine then sum.physMine = sum.physMine + pts else sum.physParty = sum.physParty + pts end
                        if ev.heavy then sum.heavy = sum.heavy + w end
                    else
                        sum.swings = sum.swings + w
                    end
                elseif magic then
                    sum.magic[ev.school] = sum.magic[ev.school] + w * (ev.mine and 2 or 1.5)
                end
                sum.pressure = sum.pressure + w
                if recent then sum.count[ev.school] = (sum.count[ev.school] or 0) + 1 end
            elseif ev.kind == "push" then
                local w = Weight(age, HALF_LIFE.push)
                if ev.mine then sum.pushMine = sum.pushMine + w else sum.pushParty = sum.pushParty + w end
                sum.pressure = sum.pressure + w
                if recent then
                    local k = ev.mine and "pushMine" or "pushParty"
                    sum.count[k] = sum.count[k] + 1
                end
            elseif ev.kind == "cast" then
                local w = Weight(age, HALF_LIFE.cast)
                local k = ev.school or "unknown"
                sum.casts[k] = sum.casts[k] + w
                if ev.school and ev.name then sum.castName[ev.school] = ev.name end
                sum.pressure = sum.pressure + w
                if recent then sum.count.casts = sum.count.casts + 1 end
            end
        end
    end
    S.log = keep
    if sum.pressure < 0.05 then sum.pressure = 0 end
    return sum
end
