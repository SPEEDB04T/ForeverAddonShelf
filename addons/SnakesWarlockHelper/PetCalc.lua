-- Snakes Warlock Helper: how much damage each demon is worth right now.
--
-- For every demon the warlock can summon:
--   demon dps  = its melee (measured while it is out) + its damaging ability (from the tooltip)
--   your gain  = what having it out adds to your own spells (Soul Link, Master Demonologist,
--                Demonic Knowledge), turned into dps with an estimate of your own dps
-- WoW Forever blocks the combat log for addons, so nothing here is a damage meter: melee comes
-- from the demon's character-sheet numbers and is remembered per demon, with the time it was taken.
local _, ns = ...
local D = ns.Data
local S = ns.State
local P = {}
ns.PetCalc = P

local Call, CallN = ns.Call, ns.CallN
local T = D.TALENT

-- Same-level target: melee 5% miss and 5% crit for double damage; spells 4% miss, 5% crit for +50%.
local MELEE_FACTOR = 0.95 * 1.05
local SPELL_FACTOR = 0.96 * 1.025

local function num(s) return tonumber((s:gsub(",", ""))) end

-- Average damage in a spell tooltip: "85 to 95 Fire damage" or "99 Shadow damage".
function P.ParseDamage(desc)
    if type(desc) ~= "string" then return nil end
    desc = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local a, b = desc:match("(%d[%d,]*) to (%d[%d,]*)")
    if not a then a, b = desc:match("(%d[%d,]*)%s*%-%s*(%d[%d,]*)") end
    if a and b then return (num(a) + num(b)) / 2 end
    a = desc:match("(%d[%d,]*)%s+%a+ damage")
    if a then return num(a) end
    return nil
end

local function IsOrc()
    local _, race = CallN(UnitRace, "player")
    return race == "Orc"
end

local function Talents()
    local dk = S.Talent("demonic knowledge")
    return {
        unholy = S.Talent("unholy power"),
        md = S.Talent("master demonologist"),
        dk = dk,
        dkShare = T.demonicKnowledge[dk] or 0,
        soulLink = S.soulLinkKnown,
        sacrifice = S.Talent("demonic sacrifice") > 0 or S.Resolve(D.SACRIFICE) ~= nil,
        pact = S.Talent("demonic pact") > 0,
        orc = IsOrc(),
        abilityRank = {
            firebolt = S.Talent("improved imp"),
            lash = math.max(S.Talent("improved sayaad"), S.Talent("improved succubus")),
        },
    }
end

-- What changes the demon's melee numbers between a measurement and now.
local function MeleeContext()
    return { unholy = S.Talent("unholy power"), soulLink = S.soulLinkUp and true or false }
end
local function MeleeMult(unholy, soulLink)
    return (1 + T.unholyPower * (unholy or 0)) * (soulLink and (1 + T.soulLink) or 1)
end

----------------------------------------------------------------------
-- Measure the demon that is out (only when its numbers can be read, so not in combat)
----------------------------------------------------------------------
function P.Measure()
    local pet = S.pet
    if S.inCombat or not (pet.exists and pet.alive and pet.key) then return nil end
    local def = D.PETS[pet.key]
    local snap = {
        t = time(), level = S.level, rank = pet.rank, ctx = MeleeContext(),
        sp = Call(GetPetSpellBonusDamage),
    }
    if def.melee then
        local lo, hi = CallN(UnitDamage, "pet")
        local speed = Call(UnitAttackSpeed, "pet")
        if type(lo) ~= "number" or type(hi) ~= "number" or type(speed) ~= "number" or speed <= 0 or hi <= 0 then
            return nil
        end
        snap.lo, snap.hi, snap.speed = lo, hi, speed
    end
    ns.cdb.pets[pet.key] = snap
    return snap
end

----------------------------------------------------------------------
-- Your own dps (for turning "+10% Shadow" into a number)
----------------------------------------------------------------------
-- Returns { dps, source = "manual" | "estimate", spell, perSpellPower } or nil.
function P.SelfDps(school, talents, demonOut)
    local idx = D.SCHOOL[school]
    local sp = Call(GetSpellBonusDamage, idx) or 0
    local crit = Call(GetSpellCritChance, idx) or 5
    local dkSP = talents.dkShare * S.level
    -- Spell damage shown on the character sheet already includes Demonic Knowledge while a demon is out.
    if demonOut then sp = math.max(0, sp - dkSP) end
    local hitCrit = 0.96 * (1 + crit / 100 * 0.5)

    local best
    for _, filler in ipairs(D.FILLERS[school]) do
        local spell = S.Resolve(filler)
        if spell then
            local avg = P.ParseDamage(S.SpellDesc(spell.id))
            local cast = math.max(1.5, S.SpellCastTime(spell.id) or filler.cast)
            if avg then
                local dps = (avg + filler.coeff * sp) / cast * hitCrit
                if not best or dps > best.dps then
                    best = { dps = dps, source = "estimate", spell = spell.name,
                        perSpellPower = filler.coeff / cast * hitCrit }
                end
            end
        end
    end
    if ns.cdb.selfDps then
        return { dps = ns.cdb.selfDps, source = "manual", spell = best and best.spell,
            perSpellPower = best and best.perSpellPower or 0 }
    end
    return best
end

----------------------------------------------------------------------
-- One demon
----------------------------------------------------------------------
local function AbilityDamage(ability, rank)
    local id = ability.ids[rank]
    return (id and P.ParseDamage(S.SpellDesc(id))) or ability.damage[rank]
end

local function RankForLevel(ability, level)
    local rank = 1
    for i, lv in ipairs(ability.levels) do
        if level >= lv then rank = i end
    end
    return rank
end

local function PetRow(key, school, talents, me)
    local def = D.PETS[key]
    local live = S.pet.exists and S.pet.alive and S.pet.key == key
    local snap = (live and P.Measure()) or ns.cdb.pets[key]
    local row = {
        key = key, name = def.name, icon = def.icon, live = live and true or false,
        parts = {}, notes = {},
    }
    if live and S.pet.family then row.name = S.pet.family end
    for _, s in ipairs(def.summons) do
        local spell = S.Resolve(s)
        if spell then
            row.icon = spell.icon or row.icon
            if not live and s ~= def.summons[1] and not S.Resolve(def.summons[1]) then row.name = def.altName end
            break
        end
    end

    row.source = live and snap and "live" or (snap and "seen") or (def.melee and "unmeasured" or "estimate")
    row.age = snap and not live and (time() - snap.t) or nil
    row.seenLevel = snap and snap.level or nil

    local petDps = 0
    -- Soul Link is counted as up whenever the talent is known: keeping it up is what the reminder is for.
    local soulLink = talents.soulLink

    if def.melee then
        if snap and snap.lo then
            local dps = (snap.lo + snap.hi) / 2 / snap.speed
            dps = dps * MeleeMult(talents.unholy, soulLink) / MeleeMult(snap.ctx.unholy, snap.ctx.soulLink)
            dps = dps * MELEE_FACTOR
            row.parts[#row.parts + 1] = { label = "Melee", dps = dps,
                detail = ("%d-%d every %.1f s"):format(snap.lo, snap.hi, snap.speed) }
            petDps = petDps + dps
        else
            row.unmeasured = true
        end
    end

    if def.ability then
        local ability = D.ABILITIES[def.ability]
        local rank = (snap and snap.rank) or RankForLevel(ability, S.level)
        local base = AbilityDamage(ability, rank)
        -- The demon's spell damage: measured, or just Demonic Knowledge when it was never out.
        local petSP = (snap and snap.sp) or (talents.dkShare * S.level)
        local mult = (1 + T.unholyPower * talents.unholy)
            * (1 + ability.talentPerRank * (talents.abilityRank[def.ability] or 0))
            * (soulLink and (1 + T.soulLink) or 1)
            * (talents.orc and (1 + T.orcCommand) or 1)
        if def.mdSchool == ability.school then mult = mult * (1 + T.masterDemonologist * talents.md) end
        local hit = (base + ability.coeff * petSP) * mult
        local period = ability.cooldown or math.max(1.5, (ability.ids[rank] and S.SpellCastTime(ability.ids[rank]))
            or ability.cast)
        local dps = hit / period * SPELL_FACTOR
        row.parts[#row.parts + 1] = { label = ability.name, dps = dps,
            detail = ("%d a hit, every %.1f s"):format(hit, period) }
        petDps = petDps + dps
    end

    row.petDps = (not row.unmeasured) and petDps or nil

    -- What it adds to your own spells while it is out.
    local pct = 1
    if soulLink then
        pct = pct * (1 + T.soulLink)
        row.notes[#row.notes + 1] = "Soul Link +3%"
    end
    if talents.md > 0 then
        if def.mdSchool == school then
            pct = pct * (1 + T.masterDemonologist * talents.md)
            row.notes[#row.notes + 1] = ("Master Demonologist +%d%% %s"):format(talents.md * 2, D.SCHOOL_NAME[school])
        elseif def.mdSchool then
            row.notes[#row.notes + 1] = ("Master Demonologist boosts %s, not %s"):format(
                D.SCHOOL_NAME[def.mdSchool], D.SCHOOL_NAME[school])
        elseif def.mdNote then
            row.notes[#row.notes + 1] = "Master Demonologist: you " .. def.mdNote:gsub("^takes", "take")
        end
    end
    row.youPct = pct - 1
    if me then
        local dk = talents.dkShare * S.level * me.perSpellPower
        if dk > 0 then row.notes[#row.notes + 1] = ("Demonic Knowledge +%d spell damage"):format(talents.dkShare * S.level) end
        row.youDps = me.dps * row.youPct + dk
    end

    row.total = row.petDps and (row.petDps + (row.youDps or 0)) or nil
    return row
end

----------------------------------------------------------------------
-- Everything the window shows
----------------------------------------------------------------------
function P.Evaluate()
    local school = ns.cdb.school == "fire" and "fire" or "shadow"
    local talents = Talents()
    local demonOut = S.pet.exists and S.pet.alive
    local me = P.SelfDps(school, talents, demonOut)
    local res = { school = school, me = me, talents = talents, rows = {} }

    for _, key in ipairs(D.PET_ORDER) do
        local def = D.PETS[key]
        local known = false
        for _, s in ipairs(def.summons) do known = known or S.Resolve(s) ~= nil end
        if known or (S.pet.exists and S.pet.key == key) then
            res.rows[#res.rows + 1] = PetRow(key, school, talents, me)
        end
    end
    table.sort(res.rows, function(a, b)
        if (a.total ~= nil) ~= (b.total ~= nil) then return a.total ~= nil end
        if a.total and b.total and a.total ~= b.total then return a.total > b.total end
        return a.name < b.name
    end)

    -- Demonic Sacrifice: the demon whose sacrifice boosts the chosen school.
    if talents.sacrifice then
        for _, key in ipairs(D.PET_ORDER) do
            local def = D.PETS[key]
            if def.sacSchool == school then
                local known = false
                for _, s in ipairs(def.summons) do known = known or S.Resolve(s) ~= nil end
                if known then
                    res.sacrifice = {
                        key = key, name = def.name, icon = def.icon, pct = T.sacrifice,
                        youDps = me and me.dps * T.sacrifice or nil, pact = talents.pact,
                    }
                end
            end
        end
    end

    -- The line under the list.
    local sac = res.sacrifice
    local function bestRow(exclude)
        for _, row in ipairs(res.rows) do
            if row.total and row.key ~= exclude then return row end
        end
    end
    local top = bestRow()
    if sac and sac.youDps and sac.pact then
        local keep = bestRow(sac.key)
        if keep then
            res.best = ("Best: sacrifice your %s, then keep your %s out"):format(sac.name, keep.name)
            res.bestKey = keep.key
        else
            res.best = ("Best: sacrifice your %s"):format(sac.name)
        end
    elseif sac and sac.youDps and (not top or sac.youDps > top.total) then
        res.best = ("Best: sacrifice your %s (+%d dps) instead of keeping a demon out"):format(sac.name, sac.youDps)
    elseif top then
        res.best = ("Best: keep your %s out"):format(top.name)
        res.bestKey = top.key
    end
    return res
end

-- Sample numbers for /swh demo.
function P.DemoResult()
    local function row(key, name, source, age, melee, ability, abilityName, youPct, youDps, note)
        local def = D.PETS[key]
        local parts = {}
        if melee then parts[#parts + 1] = { label = "Melee", dps = melee, detail = "152-181 every 2.0 s" } end
        if ability then parts[#parts + 1] = { label = abilityName, dps = ability, detail = "sample" } end
        local petDps = (melee or 0) + (ability or 0)
        return { key = key, name = name, icon = def.icon, live = source == "live", source = source, age = age,
            parts = parts, notes = { "Soul Link +3%", note }, petDps = petDps, youPct = youPct, youDps = youDps,
            total = petDps + youDps }
    end
    return {
        school = "shadow", demo = true,
        me = { dps = 520, source = "estimate", spell = "Shadow Bolt" },
        talents = { soulLink = true, sacrifice = true, pact = true },
        rows = {
            row("sayaad", "Succubus", "live", nil, 84, 11, "Lash of Pain", 0.133, 69, "Master Demonologist +10% Shadow"),
            row("felhunter", "Felhunter", "seen", 172800, 71, nil, nil, 0.03, 16, "Master Demonologist: you take less magic damage"),
            row("imp", "Imp", "seen", 5400, nil, 61, "Firebolt", 0.03, 16, "Master Demonologist boosts Fire, not Shadow"),
            { key = "voidwalker", name = "Voidwalker", icon = D.PETS.voidwalker.icon, source = "unmeasured",
              unmeasured = true, parts = {}, notes = { "Soul Link +3%" }, youPct = 0.03, youDps = 16 },
        },
        sacrifice = { key = "imp", name = "Imp", icon = D.PETS.imp.icon, pct = 0.15, youDps = 78, pact = true },
        best = "Best: sacrifice your Imp, then keep your Succubus out",
        bestKey = "sayaad",
    }
end
