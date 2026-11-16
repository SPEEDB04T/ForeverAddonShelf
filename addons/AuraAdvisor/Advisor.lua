-- Aura Advisor: which aura fits what is happening right now.
--
-- Every aura gets points from the fight (Signals.Summary); the aura with the most points is
-- the advisor's pick. A switch is only suggested when the pick is clearly ahead of the aura
-- you have on, because a switch costs a global cooldown and nobody wants a new suggestion
-- with every hit.
--
--   Devotion        physical hits on you and the party; worth more after crits or crushing blows
--   Retribution     physical hits that landed (each one hits back); worth more with many enemies
--   Concentration   casts that were pushed back
--   Resistance      hits of that school, and enemies seen casting a spell of that school
--
-- Only what was seen counts: hits that landed or were dodged, casts that were pushed back, an
-- enemy spell being cast. Nothing is guessed from what an enemy is (class, elite, boss) or
-- what it might cast, and in a fight no switch is suggested that can't say what caused it.
--
-- This file reads nothing from the game: it works on plain tables, so the tests can run it.
local _, ns = ...
local Data = ns.Data
local A = {}
ns.Advisor = A

A.T = {
    -- how far ahead the pick must be: the current aura's points plus the larger of
    -- gain and margin x those points
    sensitivity = {
        low    = { margin = 1.00, gain = 4 },
        normal = { margin = 0.50, gain = 2 },
        high   = { margin = 0.25, gain = 1.5 },
    },
    baseline = 2,           -- points your default aura gets for free
    cast = 2,               -- an enemy casting a spell of a known school
    pushMine = 4, pushParty = 2.5,
    danger = 1.8,           -- Devotion after crits and crushing blows
    crowd = 3,              -- this many enemies make Retribution worth more to a tank
    style = {
        damage = { devotion = 0.6, retribution = 1.0 },
        tank   = { devotion = 0.9, retribution = 0.8, crowdRetribution = 1.2 },
        healer = { devotion = 1.0, retribution = 0.4 },
    },
}

local function Plural(n, one, many)
    return n == 1 and one or many
end

-- The aura to wear when nothing is going on.
function A.IdleAura(ctx)
    local known = ctx.known or {}
    local taken = ctx.others or {}
    local want = ctx.idle
    if want and want ~= "auto" and known[want] and not taken[want] then return want end
    local order
    if ctx.style == "damage" then
        order = { "retribution", "devotion", "concentration" }
    else
        order = { "devotion", "retribution", "concentration" }
    end
    for _, key in ipairs(order) do
        if known[key] and not taken[key] then return key end
    end
    for _, key in ipairs(Data.ORDER) do
        if known[key] and not taken[key] then return key end
    end
    for _, key in ipairs(Data.ORDER) do
        if known[key] then return key end
    end
end

-- Points per aura, and one line per aura saying where they come from.
function A.Score(sum, ctx)
    local T = A.T
    local known, taken = ctx.known or {}, ctx.others or {}
    local style = T.style[ctx.style] or T.style.damage
    local e = sum.enemies or {}
    local scores, why = {}, {}
    local n = sum.count

    local phys = sum.physMine + sum.physParty
    local danger = sum.heavy > 0.3

    -- Devotion: every physical attack, landed or not
    local dev = (phys + sum.swings * 0.5) * style.devotion
    if danger then dev = dev * T.danger end
    scores.devotion = dev
    -- the causes are short: they show in the aura's tooltip, "8 Fire hits", "3 pushbacks"
    if n.physical > 0 then
        why.devotion = ("%d %s"):format(n.physical, danger and Plural(n.physical, "hard hit", "hard hits")
            or Plural(n.physical, "melee hit", "melee hits"))
    end

    -- Retribution: only what landed
    local retFactor = style.retribution
    if style.crowdRetribution and (e.engaged or 0) >= T.crowd then retFactor = style.crowdRetribution end
    scores.retribution = phys * retFactor
    if n.physical > 0 then
        why.retribution = ("%d %s"):format(n.physical, Plural(n.physical, "melee hit", "melee hits"))
    end

    -- Concentration: casts a hit actually pushed back
    scores.concentration = sum.pushMine * T.pushMine + sum.pushParty * T.pushParty
    if n.pushMine > 0 then
        why.concentration = ("%d %s"):format(n.pushMine, Plural(n.pushMine, "pushback", "pushbacks"))
    elseif n.pushParty > 0 then
        why.concentration = ("%d party %s"):format(n.pushParty, Plural(n.pushParty, "pushback", "pushbacks"))
    end

    -- Resistance auras: hits of that school, and enemy spells of that school being cast
    for _, school in ipairs({ "shadow", "frost", "fire" }) do
        local pts = sum.magic[school] + sum.casts[school] * T.cast
        scores[school] = pts
        local name = Data.SCHOOL_NAME[school]
        if n[school] > 0 then
            if sum.casts[school] > 0.3 and sum.castName[school] then
                why[school] = ("%s, %d %s"):format(sum.castName[school], n[school], Plural(n[school], "hit", "hits"))
            else
                why[school] = ("%d %s %s"):format(n[school], name, Plural(n[school], "hit", "hits"))
            end
        elseif sum.casts[school] > 0.3 and sum.castName[school] then
            why[school] = sum.castName[school]          -- "Shadow Bolt": the spell being cast
        end
    end

    -- Your default gets a head start, so that a single stray hit changes nothing.
    local idle = A.IdleAura(ctx)
    if idle then scores[idle] = (scores[idle] or 0) + T.baseline end

    for key in pairs(scores) do
        if not known[key] then
            scores[key] = nil
            why[key] = nil
        elseif taken[key] then
            -- Two paladins with the same aura give the party nothing extra.
            scores[key] = 0
            local who = type(taken[key]) == "string" and taken[key] or "another paladin"
            why[key] = who .. " has it"
        end
    end
    return scores, why, idle
end

-- ctx: known = { key = true }, current = key or nil, others = { key = name or true },
--      style = "damage" | "tank" | "healer", idle = "auto" | key, sensitivity = "low" | "normal" | "high",
--      sticky = the aura suggested last time (it stays suggested until it stops being better),
--      betweenFights = suggest the default aura when nothing is going on
-- Returns { best, suggest, reason, scores, why, current, idle, quiet }.
function A.Advise(sum, ctx)
    local scores, why, idle = A.Score(sum, ctx)
    local current = ctx.current
    if current and not (ctx.known or {})[current] then current = nil end
    local res = { scores = scores, why = why, current = current, idle = idle, quiet = sum.pressure == 0 }

    local best, bestScore
    for _, key in ipairs(Data.ORDER) do
        local s = scores[key]
        if s and (not bestScore or s > bestScore or (s == bestScore and key == current)) then
            best, bestScore = key, s
        end
    end
    if not best then return res end
    if res.quiet and idle then best, bestScore = idle, scores[idle] or 0 end
    res.best = best

    local taken = ctx.others or {}
    if not current then
        res.suggest = best
        res.reason = "No aura"
        return res
    end
    if best == current then return res end

    if taken[current] then
        res.suggest = best
        res.reason = why[current] or "another paladin has it"
        if not res.quiet and why[best] then res.reason = why[best] end
        return res
    end

    if res.quiet then
        if ctx.betweenFights ~= false then
            res.suggest = best
            res.reason = "Fight over"
        end
        return res
    end

    local sens = A.T.sensitivity[ctx.sensitivity] or A.T.sensitivity.normal
    local have = scores[current] or 0
    local need = have + math.max(sens.gain, have * sens.margin)
    if ctx.sticky == best then need = have + 0.01 end
    -- In a fight, a switch has to name what caused it: no hits or casts seen, no suggestion.
    if bestScore >= need and why[best] then
        res.suggest = best
        res.reason = why[best]
    end
    return res
end
