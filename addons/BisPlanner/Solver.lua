-- BiS Planner: picks one candidate per slot. No game API in this file.
--
-- A plan is the set with the highest weighted score among the sets that reach every goal.
-- A goal is a minimum for one stat ("hit at least 30"). Goals are reached with a price per
-- missing point (found by bisection, one goal at a time), then single and double swaps
-- polish the result. When the goals cannot all be reached, the set that comes closest wins.
local _, ns = ...
local Solver = {}
ns.Solver = Solver

local EPS = 1e-9

-- slots: { { key = "Head", cands = { { stats = {...}, ... }, ... } }, ... }
-- weights: { stat = number }, goals: { stat = minimum }, base: stats the set starts with (optional)
function Solver.Solve(slots, weights, goals, base)
    local goalKeys = {}
    for key, want in pairs(goals or {}) do
        if type(want) == "number" and want > 0 then goalKeys[#goalKeys + 1] = key end
    end
    table.sort(goalKeys)
    local G = #goalKeys
    local want, start = {}, {}
    for i, key in ipairs(goalKeys) do
        want[i] = goals[key]
        start[i] = base and base[key] or 0
    end

    -- per candidate: its weighted score and what it gives toward each goal
    local S = {}
    for _, slot in ipairs(slots) do
        if #slot.cands > 0 then
            local entry = { slot = slot, n = #slot.cands, score = {}, g = {} }
            for c, cand in ipairs(slot.cands) do
                local score = 0
                for key, value in pairs(cand.stats) do
                    local w = weights[key]
                    if w then score = score + w * value end
                end
                entry.score[c] = score
                local row = {}
                for i, key in ipairs(goalKeys) do row[i] = cand.stats[key] or 0 end
                entry.g[c] = row
            end
            S[#S + 1] = entry
        end
    end
    local N = #S

    local function Totals(pick)
        local score, have = 0, {}
        for i = 1, G do have[i] = start[i] end
        for s = 1, N do
            local e, c = S[s], pick[s]
            score = score + e.score[c]
            local row = e.g[c]
            for i = 1, G do have[i] = have[i] + row[i] end
        end
        return score, have
    end

    local function Penalty(have)
        local p = 0
        for i = 1, G do
            if have[i] < want[i] - EPS then p = p + (want[i] - have[i]) / want[i] end
        end
        return p
    end

    local function PickWith(lambda)
        local pick = {}
        for s = 1, N do
            local e = S[s]
            local best, bestValue, bestScore
            for c = 1, e.n do
                local value = e.score[c]
                local row = e.g[c]
                for i = 1, G do value = value + lambda[i] * row[i] end
                if not best or value > bestValue + EPS
                    or (value > bestValue - EPS and e.score[c] > bestScore) then
                    best, bestValue, bestScore = c, value, e.score[c]
                end
            end
            pick[s] = best
        end
        return pick
    end

    local function Better(p1, s1, p2, s2)
        if p1 < p2 - EPS then return true end
        if p1 > p2 + EPS then return false end
        return s1 > s2 + EPS
    end

    local lambda = {}
    for i = 1, G do lambda[i] = 0 end
    local bestPick = PickWith(lambda)
    local bestScore, bestHave = Totals(bestPick)
    local bestPenalty = Penalty(bestHave)

    local function Consider(pick)
        local score, have = Totals(pick)
        local p = Penalty(have)
        if Better(p, score, bestPenalty, bestScore) then
            bestPick, bestScore, bestHave, bestPenalty = pick, score, have, p
        end
        return have
    end

    if G > 0 and bestPenalty > EPS then
        for _ = 1, 4 do
            for i = 1, G do
                lambda[i] = 0
                local have = Consider(PickWith(lambda))
                if have[i] < want[i] - EPS then
                    local lo, hi = 0, 0.01
                    local reached = false
                    for _ = 1, 60 do
                        lambda[i] = hi
                        have = Consider(PickWith(lambda))
                        if have[i] >= want[i] - EPS then reached = true break end
                        lo, hi = hi, hi * 2
                    end
                    if reached then
                        for _ = 1, 40 do
                            local mid = (lo + hi) / 2
                            lambda[i] = mid
                            have = Consider(PickWith(lambda))
                            if have[i] >= want[i] - EPS then hi = mid else lo = mid end
                        end
                    end
                    lambda[i] = hi
                    Consider(PickWith(lambda))
                end
            end
            if bestPenalty <= EPS then
                local _, have = Totals(PickWith(lambda))
                if Penalty(have) <= EPS then break end
            end
        end
    end

    -- polish: single swaps, then double swaps, until nothing improves
    local pick = {}
    for s = 1, N do pick[s] = bestPick[s] end
    local score, have = Totals(pick)
    local penalty = Penalty(have)

    local function TrySingle()
        local improved = false
        for s = 1, N do
            local e = S[s]
            local old = pick[s]
            for c = 1, e.n do
                if c ~= pick[s] then
                    local cur = pick[s]
                    local ns_ = score - e.score[cur] + e.score[c]
                    local p = 0
                    for i = 1, G do
                        local h = have[i] - e.g[cur][i] + e.g[c][i]
                        if h < want[i] - EPS then p = p + (want[i] - h) / want[i] end
                    end
                    if Better(p, ns_, penalty, score) then
                        for i = 1, G do have[i] = have[i] - e.g[cur][i] + e.g[c][i] end
                        pick[s], score, penalty = c, ns_, p
                        improved = true
                    end
                end
            end
            if pick[s] ~= old then improved = true end
        end
        return improved
    end

    local function TryDouble()
        if G == 0 then return false end
        for a = 1, N - 1 do
            local ea = S[a]
            for b = a + 1, N do
                local eb = S[b]
                local ca0, cb0 = pick[a], pick[b]
                for ca = 1, ea.n do
                    if ca ~= ca0 then
                        local sa = score - ea.score[ca0] + ea.score[ca]
                        for cb = 1, eb.n do
                            if cb ~= cb0 then
                                local ns_ = sa - eb.score[cb0] + eb.score[cb]
                                local p = 0
                                for i = 1, G do
                                    local h = have[i] - ea.g[ca0][i] + ea.g[ca][i] - eb.g[cb0][i] + eb.g[cb][i]
                                    if h < want[i] - EPS then p = p + (want[i] - h) / want[i] end
                                end
                                if Better(p, ns_, penalty, score) then
                                    for i = 1, G do
                                        have[i] = have[i] - ea.g[ca0][i] + ea.g[ca][i] - eb.g[cb0][i] + eb.g[cb][i]
                                    end
                                    pick[a], pick[b], score, penalty = ca, cb, ns_, p
                                    return true
                                end
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    for _ = 1, 200 do
        local moved = TrySingle()
        if not moved then moved = TryDouble() end
        if not moved then break end
    end

    local result = { picks = {}, score = score, goals = {}, feasible = penalty <= EPS, order = {} }
    for s = 1, N do
        local e = S[s]
        result.picks[e.slot.key] = e.slot.cands[pick[s]]
        result.order[#result.order + 1] = e.slot.key
    end
    for i, key in ipairs(goalKeys) do
        result.goals[key] = { have = have[i], want = want[i], met = have[i] >= want[i] - EPS }
    end
    -- the price the plan paid per goal point, so callers can rank alternatives the same way
    result.lambda = {}
    for i, key in ipairs(goalKeys) do result.lambda[key] = lambda[i] end
    return result
end

-- Weighted score of a stat table.
function Solver.Score(stats, weights)
    local score = 0
    for key, value in pairs(stats) do
        local w = weights[key]
        if w then score = score + w * value end
    end
    return score
end

-- Keeps the candidates that can matter: the best few by score and by each goal stat.
-- list: { { stats = {...} }, ... }; returns a new list.
function Solver.Prune(list, weights, goals, keepScore, keepGoal)
    keepScore, keepGoal = keepScore or 8, keepGoal or 5
    if #list <= keepScore then return list end
    local keep, out = {}, {}
    local function Take(order, count)
        local taken = 0
        for _, cand in ipairs(order) do
            if taken >= count then break end
            if not keep[cand] then
                keep[cand] = true
                out[#out + 1] = cand
            end
            taken = taken + 1
        end
    end
    local scored = {}
    for i, cand in ipairs(list) do
        cand._score = Solver.Score(cand.stats, weights)
        cand._i = i
        scored[i] = cand
    end
    table.sort(scored, function(a, b)
        if a._score ~= b._score then return a._score > b._score end
        return a._i < b._i
    end)
    Take(scored, keepScore)
    for key, want in pairs(goals or {}) do
        if type(want) == "number" and want > 0 then
            local by = {}
            for _, cand in ipairs(list) do
                if (cand.stats[key] or 0) > 0 then by[#by + 1] = cand end
            end
            table.sort(by, function(a, b)
                local x, y = a.stats[key], b.stats[key]
                if x ~= y then return x > y end
                if a._score ~= b._score then return a._score > b._score end
                return a._i < b._i
            end)
            Take(by, keepGoal)
            -- and the ones that give the goal stat at the least cost in score
            table.sort(by, function(a, b)
                local x = (scored[1]._score - a._score) / a.stats[key]
                local y = (scored[1]._score - b._score) / b.stats[key]
                if x ~= y then return x < y end
                return a._i < b._i
            end)
            Take(by, keepGoal)
        end
    end
    return out
end
