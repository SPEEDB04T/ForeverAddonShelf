-- Aura Advisor: which aura fits what is happening right now.
--
-- Every aura gets points from the fight (Signals.Summary); the aura with the most points is
-- the advisor's pick. A switch is only suggested when the pick is clearly ahead of the aura
-- you have on, because a switch costs a global cooldown and nobody wants a new suggestion
-- with every hit.
--
--   Devotion        physical hits on you and the party; worth more against elites and bosses
--                   and after crits or crushing blows
--   Retribution     physical hits that landed (each one hits back); worth more with many enemies
--   Concentration   casts that were pushed back, and you casting while being hit
--   Resistance      hits of that school, enemies casting a spell of that school, and enemy
--                   players whose class uses it
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
    unknownCast = 1,        -- an enemy casting something, shared out like the magic hits so far
    classHint = 2,          -- an enemy player of a class, times that class's weight
    pushMine = 4, pushParty = 2.5,
    castingUnderFire = 1.5,
    danger = 1.8,           -- Devotion against elites, bosses, crits and crushing blows
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
    local danger = e.hard or sum.heavy > 0.3

    -- Devotion: every physical attack, landed or not
    local dev = (phys + sum.swings * 0.5) * style.devotion
    if danger then dev = dev * T.danger end
    scores.devotion = dev
    if n.physical > 0 then
        local line = ("%d physical %s in %d s"):format(n.physical, Plural(n.physical, "hit", "hits"), ns.Signals.RECENT)
        if e.hard then
            line = line .. ", an elite or boss in the fight"
        elseif sum.heavy > 0.3 then
            line = line .. ", crits or crushing blows among them"
        end
        why.devotion = line
    end

    -- Retribution: only what landed
    local retFactor = style.retribution
    if style.crowdRetribution and (e.engaged or 0) >= T.crowd then retFactor = style.crowdRetribution end
    scores.retribution = phys * retFactor
    if n.physical > 0 then
        local line = ("%d physical %s in %d s"):format(n.physical, Plural(n.physical, "hit", "hits"), ns.Signals.RECENT)
        if (e.engaged or 0) >= 2 then line = line .. (" from %d enemies"):format(e.engaged) end
        why.retribution = line .. ": each one hits back"
    end

    -- Concentration
    local underFire = math.min(sum.myCasts, sum.hitsMine)
    scores.concentration = sum.pushMine * T.pushMine + sum.pushParty * T.pushParty + underFire * T.castingUnderFire
    if n.pushMine > 0 then
        why.concentration = ("your casts were pushed back %d %s in %d s"):format(n.pushMine,
            Plural(n.pushMine, "time", "times"), ns.Signals.RECENT)
    elseif n.pushParty > 0 then
        why.concentration = ("your party's casts were pushed back %d %s in %d s"):format(n.pushParty,
            Plural(n.pushParty, "time", "times"), ns.Signals.RECENT)
    elseif underFire > 0.5 then
        why.concentration = "you are casting while being hit"
    end

    -- Resistance auras
    local magicTotal = sum.magic.fire + sum.magic.frost + sum.magic.shadow
    for _, school in ipairs({ "shadow", "frost", "fire" }) do
        local pts = sum.magic[school] + sum.casts[school] * T.cast
        if magicTotal > 0 then
            pts = pts + sum.casts.unknown * T.unknownCast * (sum.magic[school] / magicTotal)
        end
        local hint = e.hints and e.hints[school]
        if hint then pts = pts + hint * T.classHint end
        scores[school] = pts
        local name = Data.SCHOOL_NAME[school]
        if n[school] > 0 then
            local line = ("%d %s %s on you and your party in %d s"):format(n[school], name,
                Plural(n[school], "hit", "hits"), ns.Signals.RECENT)
            if sum.casts[school] > 0.3 and sum.castName[school] then
                line = line .. ", and an enemy is casting " .. sum.castName[school]
            end
            why[school] = line
        elseif sum.casts[school] > 0.3 and sum.castName[school] then
            why[school] = ("an enemy is casting %s (%s)"):format(sum.castName[school], name)
        elseif hint and e.hintClass and e.hintClass[school] then
            why[school] = ("an enemy %s is in the fight"):format(e.hintClass[school])
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
            why[key] = who .. " already has it up"
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
        res.reason = "no aura is on"
        if why[best] then res.reason = res.reason .. "; " .. why[best] end
        return res
    end
    if best == current then return res end

    if taken[current] then
        res.suggest = best
        res.reason = why[current] or "another paladin already has it up"
        if not res.quiet and why[best] then res.reason = res.reason .. "; " .. why[best] end
        return res
    end

    if res.quiet then
        if ctx.betweenFights ~= false then
            res.suggest = best
            res.reason = "nothing is hitting you: back to your default"
        end
        return res
    end

    local sens = A.T.sensitivity[ctx.sensitivity] or A.T.sensitivity.normal
    local have = scores[current] or 0
    local need = have + math.max(sens.gain, have * sens.margin)
    if ctx.sticky == best then need = have + 0.01 end
    if bestScore >= need then
        res.suggest = best
        res.reason = why[best] or (best == idle and "your default" or "it fits this fight better")
    end
    return res
end
