-- SkillPath: the path. For every skill point from the start to the target it picks the recipe with
-- the lowest expected cost for that point, from:
--   * the chance a craft gives a point (orange always; yellow and green by the classic formula
--     from the recipe's yellow and grey levels: (grey - skill) / (grey - yellow));
--   * what its reagents cost at that point of the path: what you hold first, then what earlier
--     steps made, then auction listings cheapest first, a vendor when that is cheaper, or
--     crafting the reagent with another recipe when that beats buying it;
--   * what its result gives back: used by a later step, or sold.
-- Recipes that aren't known are used from the skill they can be learned at (the trainer's list
-- once it was read, a recipe item with a price), and the path says when to learn them.
-- A recipe whose levels the game didn't confirm is only used where the game itself shows it orange.
-- A path for someone else starts with no recipe known and nothing in the bags.
local _, ns = ...
local Pl = {}
ns.Planner = Pl

local EPS = 1e-9
local MAX_DEPTH = 3       -- a reagent made from a reagent made from a reagent
local MAX_TESTS = 24      -- learned recipes tried without, to see whether learning them pays
local RANK_STEP = 75      -- each trainer rank raises the cap by this much
local TOP_RANK = 300      -- the last rank's cap: no trainer raises it further
Pl.TOP = TOP_RANK
local AHEAD_MAX = 64      -- points looked ahead when a reagent is sold in whole lots
local SPARE_Z = 1.28      -- spare reagents for the unlucky run: this many deviations, 9 runs in 10
Pl.RANK_STEP = RANK_STEP

-- The chance that one craft at this skill gives a point.
function Pl.Chance(yellow, grey, skill)
    if skill >= grey then return 0 end
    if skill < yellow or grey <= yellow then return 1 end
    return (grey - skill) / (grey - yellow)
end

----------------------------------------------------------------------
-- What n crafts of a recipe cost, given what earlier steps used
----------------------------------------------------------------------
-- What n left-over units of an item are worth (0 when nothing values them).
local function Value(ctx, item, n)
    if not ctx.value or n <= EPS then return 0 end
    return ctx.value(item, n) or 0
end

-- Where k units of an item come from, after `a` units this craft already set aside: what you
-- hold (H left), what earlier steps made and nothing used yet (M left), and the market.
-- Returns the units from each, and the units this craft already had to buy.
local function Split(ctx, sup, item, a, k)
    local H = math.max(0, sup.have - (ctx.haveUsed[item] or 0))
    local M = math.max(0, (ctx.made[item] or 0) - (ctx.madeUsed[item] or 0))
    local b = a + k
    local fromH = math.max(0, math.min(b, H) - math.min(a, H))
    local fromM = math.max(0, math.min(b, H + M) - math.max(a, H))
    local buy = math.max(0, b - math.max(a, H + M))
    local before = math.max(0, a - (H + M))
    return fromH, fromM, buy, before, H, M
end

-- Whether the plan can craft a recipe at skill s: known, or learnable by then.
local function Usable(ctx, r, s)
    if r.known then return true end
    local learn = ctx.learn[r.id]
    return learn ~= nil and s >= learn.at
end

-- Units an evaluation has already set aside (pend), with a log to take them back.
local function Take(pend, log, item, n)
    pend[item] = (pend[item] or 0) + n
    log[#log + 1] = item
    log[#log + 1] = n
end

local function Undo(pend, log, mark)
    for i = #log - 1, mark + 1, -2 do
        pend[log[i]] = pend[log[i]] - log[i + 1]
        log[i], log[i + 1] = nil, nil
    end
end

-- n units of an item from what is held, what earlier steps made, and what can be bought.
-- Returns the cost (nil: they can't be had), what the made units used would have sold for, the
-- supply, and how many are bought. Units bought earlier in the path stay bought: the next ones
-- cost what the next listings cost.
local function Stock(ctx, pend, item, n)
    local sup = ctx.supply(item)
    local a = pend[item] or 0
    local _, fromM, buy, before, H, M = Split(ctx, sup, item, a, n)
    local c = 0
    if buy > EPS then
        c = ctx.marginal(sup, (ctx.bought[item] or 0) + before + sup.have, buy, 0)
        if not c then return nil, 0, sup, buy end
    end
    local given = 0
    if fromM > EPS then
        local left = M - math.max(0, math.min(a - H, M))
        given = Value(ctx, item, left) - Value(ctx, item, math.max(0, left - fromM))
    end
    return c, given, sup, buy
end

local Make

-- The cheapest way to n units of a reagent at skill s: from stock and the market, or made with
-- another recipe from what is left after the free units. Returns
-- { item, n, cost, given, sup, stock (units not made), buy (units bought), make = { r, crafts, cost, given, parts } }.
local function Source(ctx, pend, log, item, n, s, depth, stack)
    local c, given, sup, buy = Stock(ctx, pend, item, n)
    local best = c and { item = item, n = n, stock = n, buy = buy, cost = c, given = given, sup = sup } or nil
    local makers = depth < MAX_DEPTH and ctx.makers and ctx.makers[item]
    if not makers then return best, sup end
    local fromH, fromM = Split(ctx, sup, item, pend[item] or 0, n)
    local fromStock = fromH + fromM
    local rest = n - fromStock
    if rest <= EPS then return best, sup end
    local g0 = 0
    if fromStock > EPS then
        local _
        _, g0 = Stock(ctx, pend, item, fromStock)
    end
    for _, q in ipairs(makers) do
        if not stack[q.id] and Usable(ctx, q, s) then
            local mark = #log
            if fromStock > EPS then Take(pend, log, item, fromStock) end
            local m = Make(ctx, pend, log, q, rest / q.outQty, s, depth + 1, stack)
            Undo(pend, log, mark)
            -- Making has to beat buying by more than rounding.
            if m and (not best or m.cost + m.given + g0 < best.cost + best.given - 0.5) then
                best = { item = item, n = n, stock = fromStock, buy = 0, cost = m.cost, given = m.given + g0, sup = sup,
                    make = m }
            end
        end
    end
    return best, sup
end

-- Sets aside what a chosen source takes (so the next reagent sees it gone).
local function Apply(pend, log, part)
    if part.stock > EPS then Take(pend, log, part.item, part.stock) end
    if part.make then
        for _, sub in ipairs(part.make.parts) do Apply(pend, log, sub) end
    end
end

-- `crafts` crafts of a recipe used only for what it makes. nil when a reagent can't be had.
Make = function(ctx, pend, log, q, crafts, s, depth, stack)
    if q.currency or q.unreadable or not q.slots then return nil end
    stack[q.id] = true
    local m = { r = q, crafts = crafts, cost = 0, given = 0, parts = {} }
    local mark = #log
    for i, slot in ipairs(q.slots) do
        local need = slot.qty * crafts
        local best
        for _, item in ipairs(slot.items) do
            local o = Source(ctx, pend, log, item, need, s, depth, stack)
            if o and (not best or o.cost + o.given < best.cost + best.given) then best = o end
        end
        if not best then
            Undo(pend, log, mark)
            stack[q.id] = nil
            return nil
        end
        Apply(pend, log, best)
        m.cost = m.cost + best.cost
        m.given = m.given + best.given
        m.parts[i] = best
    end
    stack[q.id] = nil
    return m
end

-- Items of a chosen source that were priced from an old scan.
local function Stale(part, into)
    if part.make then
        for _, sub in ipairs(part.make.parts) do into = Stale(sub, into) end
    end
    if (part.buy or 0) > EPS and part.sup.stale and part.sup.listed > 0 then
        into = into or {}
        into[#into + 1] = part.item
    end
    return into
end

-- Whether a chosen source buys an item that is sold in whole lots.
local function BuysLots(part)
    if (part.buy or 0) > EPS and part.sup.lotBest then return true end
    if part.make then
        for _, sub in ipairs(part.make.parts) do
            if BuysLots(sub) then return true end
        end
    end
    return false
end

-- Returns cost (gold for the priced reagents), whether every reagent is priced, the item chosen
-- for each slot, the missing items (with the reason), the items priced from an old scan, and
-- `extra`: credit (what selling this craft's output would give back), given (what made items it
-- uses would have sold for) and parts[slot] (how each reagent is had).
local function CraftCost(ctx, r, crafts, s)
    local cost, priced = 0, true
    local choice, missing, stale = {}, nil, nil
    local extra = { credit = 0, given = 0, parts = {} }
    if r.currency then
        priced = false
        missing = { { why = "it also costs a currency" } }
    end
    local pend, log, stack = {}, {}, { [r.id] = true }
    s = s or ctx.seenSkill or 0
    for i, slot in ipairs(r.slots or {}) do
        local need = slot.qty * crafts
        local best
        for _, item in ipairs(slot.items) do
            local o = Source(ctx, pend, log, item, need, s, 0, stack)
            if o and (not best or o.cost + o.given < best.cost + best.given) then best = o end
        end
        if best then
            Apply(pend, log, best)
            cost = cost + best.cost
            choice[i] = best.item
            extra.parts[i] = best
            extra.given = extra.given + best.given
            stale = Stale(best, stale)
        else
            priced = false
            choice[i] = slot.items[1]
            missing = missing or {}
            missing[#missing + 1] = { item = slot.items[1], why = ns.Prices.Missing(ctx.supply(slot.items[1])) }
        end
    end
    if r.out and r.outQty and r.outQty > 0 then
        local left = (ctx.made[r.out] or 0) - (ctx.madeUsed[r.out] or 0)
        local n = crafts * r.outQty
        extra.credit = Value(ctx, r.out, left + n) - Value(ctx, r.out, left)
    end
    return cost, priced, choice, missing, stale, extra
end
Pl.CraftCost = CraftCost

-- Takes n units of an item out of the supply: your own first, then what the path made, then bought.
local function Use(ctx, item, n)
    local fromH, fromM, buy = Split(ctx, ctx.supply(item), item, 0, n)
    if fromH > 0 then ctx.haveUsed[item] = (ctx.haveUsed[item] or 0) + fromH end
    if fromM > 0 then ctx.madeUsed[item] = (ctx.madeUsed[item] or 0) + fromM end
    if buy > 0 then ctx.bought[item] = (ctx.bought[item] or 0) + buy end
    ctx.used[item] = (ctx.used[item] or 0) + n
end

-- A craft that isn't sure to give its point may take more crafts than expected: how much the
-- count of each reagent can vary, for the spare units on the shopping list.
local function Spread(ctx, item, units, crafts, chance)
    if chance >= 1 or crafts <= EPS then return end
    local per = units / crafts
    ctx.var[item] = (ctx.var[item] or 0) + per * per * (1 - chance) / (chance * chance)
end

-- Takes a chosen source out of the supply; `subs` collects the recipes crafted for their output.
local function CommitPart(ctx, part, subs, crafts, chance)
    if part.stock > EPS then
        Use(ctx, part.item, part.stock)
        Spread(ctx, part.item, part.stock, crafts, chance)
    end
    local m = part.make
    if m then
        subs[#subs + 1] = { r = m.r, crafts = m.crafts, item = part.item, n = part.n - part.stock }
        for _, sub in ipairs(m.parts) do CommitPart(ctx, sub, subs, crafts, chance) end
    end
end

local function Commit(ctx, r, crafts, choice, extra, chance)
    local subs = {}
    for i, slot in ipairs(r.slots or {}) do
        local part = extra and extra.parts[i]
        if part then
            CommitPart(ctx, part, subs, crafts, chance or 1)
        elseif choice[i] then
            Use(ctx, choice[i], slot.qty * crafts)      -- no price: still on the shopping list
            Spread(ctx, choice[i], slot.qty * crafts, crafts, chance or 1)
        end
    end
    if r.out and r.outQty and r.outQty > 0 then
        ctx.made[r.out] = (ctx.made[r.out] or 0) + crafts * r.outQty
    end
    return subs
end

-- What is left of everything the path made, in whole units, and what selling it gives back.
local function Leftovers(ctx)
    local list, back = {}, 0
    for item, made in pairs(ctx.made) do
        -- Whole units, counted the way the steps count them (an expected 34.9 is 35 made).
        local used = ctx.madeUsed[item] or 0
        local left = math.max(0, math.ceil(made - 0.05) - math.max(0, math.ceil(used - 0.05)))
        if left >= 1 then
            local value = Value(ctx, item, left)
            back = back + value
            list[#list + 1] = { item = item, left = left, value = value, made = made, used = ctx.madeUsed[item] or 0 }
        end
    end
    table.sort(list, function(a, b)
        if math.abs(a.value - b.value) > EPS then return a.value > b.value end
        return a.item < b.item
    end)
    return list, back
end
Pl.Leftovers = Leftovers

-- How a recipe does at one skill: chance, points per craft and expected crafts for those points.
local function AtSkill(ctx, r, s, limit)
    local chance
    if r.trust then
        chance = Pl.Chance(r.y, r.g, s + ctx.offset)
    elseif r.known and s == ctx.seenSkill and r.colour == ns.Recipes.OPTIMAL then
        chance = 1          -- the game shows it orange right now
    else
        chance = 0
    end
    if chance <= 0 then return nil end
    local orange = chance >= 1 and (not r.trust or s + ctx.offset < r.y)
    if orange then
        return 1, math.max(1, math.min(r.ups or 1, limit - s)), 1, true
    end
    return chance, 1, 1 / chance, false
end

-- A reagent sold in whole lots makes the first point dear and the next ones free, so one point
-- alone says little: the recipe is judged by its cost per point over the best run of points.
local function Ahead(ctx, c, s, limit)
    local lots = false
    for _, part in pairs(c.extra.parts) do
        if BuysLots(part) then
            lots = true
            break
        end
    end
    if not lots then return end
    local crafts, gain, t, n, check = c.crafts, c.gain, s + c.gain, 1, 2
    while t < limit and n < AHEAD_MAX do
        local chance, g, k = AtSkill(ctx, c.r, t, limit)
        if not chance then break end
        crafts, gain, t, n = crafts + k, gain + g, t + g, n + 1
        if n == check or t >= limit or n == AHEAD_MAX then
            check = check * 2
            local cost, priced, _, _, _, extra = CraftCost(ctx, c.r, crafts, s)
            if not priced then break end
            local per = (cost + extra.given - extra.credit) / gain
            if per < c.perPoint then c.perPoint, c.ahead = per, gain end
        end
    end
end

-- 0 for a recipe the path already has, 1 for one it would have to learn.
local function Ready(ctx, r) return (r.known or ctx.learned[r.id]) and 0 or 1 end

-- On a tie the recipe of the point before wins (one step instead of two), then one already known.
local function Better(ctx, a, b)
    if not b then return true end
    if math.abs(a.perPoint - b.perPoint) > 0.5 then return a.perPoint < b.perPoint end
    if (a.r == ctx.prev) ~= (b.r == ctx.prev) then return a.r == ctx.prev end
    local ra, rb = Ready(ctx, a.r), Ready(ctx, b.r)
    if ra ~= rb then return ra < rb end
    if math.abs(a.craftsPerPoint - b.craftsPerPoint) > EPS then return a.craftsPerPoint < b.craftsPerPoint end
    return a.r.id < b.r.id
end

local function BetterUnpriced(ctx, a, b)
    if not b then return true end
    if (a.r == ctx.prev) ~= (b.r == ctx.prev) then return a.r == ctx.prev end
    local ra, rb = Ready(ctx, a.r), Ready(ctx, b.r)
    if ra ~= rb then return ra < rb end
    if math.abs(a.craftsPerPoint - b.craftsPerPoint) > EPS then return a.craftsPerPoint < b.craftsPerPoint end
    if math.abs(a.perPoint - b.perPoint) > 0.5 then return a.perPoint < b.perPoint end
    return a.r.id < b.r.id
end

----------------------------------------------------------------------
-- One path, without the recipes in `banned`
----------------------------------------------------------------------
-- Learns a recipe on its first use: a trainer's fee joins the cost, a recipe item the shopping list.
local function Learn(ctx, plan, r, s)
    if r.known or ctx.learned[r.id] then return false end
    local info = ctx.learn[r.id]
    local fee, unknown = info.fee, false
    if info.how == "item" then
        fee = Stock(ctx, {}, info.item, 1) or 0
        Use(ctx, info.item, 1)
    elseif not fee then
        fee, unknown = 0, true
    else
        plan.fees = plan.fees + fee
    end
    plan.nLearned = plan.nLearned + 1
    ctx.learned[r.id] = { r = r, info = info, fee = fee, unknown = unknown, at = s, order = plan.nLearned }
    plan.total = plan.total + fee
    if unknown then plan.feesUnknown = plan.feesUnknown + 1 end
    if info.how == "trainer" and not info.seen then plan.assumed = plan.assumed + 1 end
    return true
end

-- With no trainer's list read, a trainer recipe is taken to be learnable at its yellow skill:
-- that is the latest it can be. Where nothing gives skill, the one that turns yellow soonest may
-- be taught already, but that is not known: the path stops there and names it, with its skill.
local function Unread(ctx, candidates, s, limit)
    local pick
    for _, r in ipairs(candidates) do
        local info = ctx.learn[r.id]
        if info and info.how == "trainer" and not info.seen and info.at > s and not ctx.learned[r.id]
            and AtSkill(ctx, r, s, limit) then
            local now = pick and ctx.learn[pick.id]
            if not now or info.at < now.at or (info.at == now.at and r.id < pick.id) then pick = r end
        end
    end
    if pick then return { r = pick, at = ctx.learn[pick.id].at } end
end

local function Build(args, banned)
    local ctx = {
        offset = args.offset or 0, seenSkill = args.seenSkill or args.skill,
        supply = args.supply, marginal = args.marginal, value = args.value,
        used = {}, made = {}, madeUsed = {}, haveUsed = {}, bought = {}, var = {},
        learn = {}, learned = {}, makers = {},
    }
    local plan = { ok = true, from = args.skill, to = args.target, max = args.max, points = {}, steps = {},
        total = 0, totalComplete = true, missing = {}, stale = {}, notes = {}, untrusted = 0,
        fees = 0, feesUnknown = 0, assumed = 0, nLearned = 0, unpriced = 0, unreadable = 0, left = {} }
    local candidates = {}
    for _, r in ipairs(args.recipes) do
        local can = false
        -- No reagents read is not "no reagents": such a recipe would be a free craft.
        local readable = not r.unreadable and r.slots and #r.slots > 0
        if not readable then
            if r.known then plan.unreadable = plan.unreadable + 1 end
        elseif r.known then
            can = true
            if r.trust or r.colour == ns.Recipes.OPTIMAL then candidates[#candidates + 1] = r end
            if not r.trust then plan.untrusted = plan.untrusted + 1 end
        elseif args.learn and not banned[r.id] then
            local info, why = args.learn(r)
            -- A recipe item has to be in the bags or have a price.
            if info and info.how == "item" and not ctx.marginal(ctx.supply(info.item), 0, 1, 0) then
                info, why = nil, "its recipe item has no price"
            end
            if info then
                ctx.learn[r.id] = info
                can = true
                if r.trust then candidates[#candidates + 1] = r end
            elseif why then
                plan.left[r.id] = why
            end
        end
        if can and r.out and r.outQty and r.outQty > 0 and not r.currency then
            local list = ctx.makers[r.out]
            if not list then
                list = {}
                ctx.makers[r.out] = list
            end
            list[#list + 1] = r
        end
    end

    local s, cap = args.skill, args.max
    while s < args.target do
        if s >= cap then
            while s >= cap do cap = cap + RANK_STEP end
            plan.steps[#plan.steps + 1] = { kind = "train", at = s, rank = cap, learn = {}, fee = 0, unknown = 0 }
        end
        local limit = math.min(cap, args.target)
        local best, bestUnpriced
        local unpriced = {}
        for _, r in ipairs(candidates) do
            if Usable(ctx, r, s) then
                local chance, gain, crafts, orange = AtSkill(ctx, r, s, limit)
                if chance then
                    local cost, priced, choice, missing, stale, extra = CraftCost(ctx, r, crafts, s)
                    local net = cost + extra.given - extra.credit
                    local c = { r = r, chance = chance, gain = gain, crafts = crafts, orange = orange, cost = cost,
                        priced = priced, choice = choice, missing = missing, stale = stale, extra = extra, net = net,
                        perPoint = net / gain, craftsPerPoint = crafts / gain }
                    if priced then
                        Ahead(ctx, c, s, limit)
                        if Better(ctx, c, best) then best = c end
                    else
                        unpriced[#unpriced + 1] = c
                        if BetterUnpriced(ctx, c, bestUnpriced) then bestUnpriced = c end
                    end
                end
            end
        end
        local pick = best or bestUnpriced
        if not pick then
            plan.steps[#plan.steps + 1] = { kind = "gap", from = s, to = args.target,
                why = ("No recipe gives skill at %d."):format(s), wait = Unread(ctx, candidates, s, limit) }
            plan.gapAt = s
            plan.totalComplete = false
            break
        end
        -- Recipes that might be cheaper but have a reagent with no price.
        local alts
        if best then
            for _, c in ipairs(unpriced) do
                if c.perPoint < best.perPoint - 0.5 then
                    alts = alts or {}
                    alts[#alts + 1] = c
                end
            end
        end
        local subs = Commit(ctx, pick.r, pick.crafts, pick.choice, pick.extra, pick.chance)
        local learnedNow = Learn(ctx, plan, pick.r, s)
        for _, sub in ipairs(subs) do
            if Learn(ctx, plan, sub.r, s) then learnedNow = true end
        end
        ctx.prev = pick.r
        local point = { s = s, to = s + pick.gain, r = pick.r, chance = pick.chance, gain = pick.gain,
            crafts = pick.crafts, orange = pick.orange, cost = pick.priced and pick.cost or nil, known = pick.cost,
            priced = pick.priced, missing = pick.missing, stale = pick.stale, alts = alts, subs = subs,
            credit = pick.extra.credit, given = pick.extra.given, net = pick.priced and pick.net or nil }
        plan.points[#plan.points + 1] = point
        plan.total = plan.total + pick.cost
        if not pick.priced then
            plan.totalComplete = false
            plan.unpriced = plan.unpriced + 1
        end
        for _, m in ipairs(pick.missing or {}) do
            if m.item then plan.missing[m.item] = m.why end
        end
        -- A reagent with no price that keeps a maybe-cheaper recipe out is missing too: a scan could change the path.
        for _, c in ipairs(alts or {}) do
            for _, m in ipairs(c.missing or {}) do
                if m.item then plan.missing[m.item] = m.why end
            end
        end
        for _, item in ipairs(pick.stale or {}) do plan.stale[item] = true end

        -- A point that needs something learned starts a new step: the learning goes right before it.
        local last = plan.steps[#plan.steps]
        local step
        if not learnedNow and last and last.kind == "craft" and last.r == pick.r then
            step = last
            step.to = point.to
            step.crafts = step.crafts + pick.crafts
            step.cost = step.cost + pick.cost
            step.credit = step.credit + pick.extra.credit
            step.given = step.given + pick.extra.given
            step.points[#step.points + 1] = point
            if not pick.priced then step.priced = false end
            if pick.stale then step.stale = true end
        else
            step = { kind = "craft", r = pick.r, name = pick.r.name, from = s, to = point.to,
                crafts = pick.crafts, cost = pick.cost, priced = pick.priced, points = { point },
                credit = pick.extra.credit, given = pick.extra.given,
                stale = pick.stale and true or false, alts = {}, subs = {}, uses = {} }
            plan.steps[#plan.steps + 1] = step
        end
        -- What the step takes: per reagent the units, and how many of them are bought.
        for i, slot in ipairs(pick.r.slots or {}) do
            local part = pick.extra.parts[i]
            local item = pick.choice[i]
            if item then
                local u = step.uses[item]
                if not u then
                    u = { item = item, n = 0, buy = 0, made = 0 }
                    step.uses[item] = u
                end
                u.n = u.n + slot.qty * pick.crafts
                if part then
                    u.buy = u.buy + (part.buy or 0)
                    u.made = u.made + (part.n - part.stock)
                else
                    u.noPrice = true
                end
            end
        end
        for _, c in ipairs(alts or {}) do step.alts[c.r.id] = c end
        for _, sub in ipairs(subs) do
            local e = step.subs[sub.r.id]
            if not e then
                e = { r = sub.r, crafts = 0, item = sub.item, n = 0 }
                step.subs[sub.r.id] = e
            end
            e.crafts, e.n = e.crafts + sub.crafts, e.n + sub.n
        end
        for _, l in pairs(ctx.learned) do
            if l.at == s and not l.step then l.step = step end
        end
        s = point.to
    end
    plan.reached = s
    plan.used, plan.made, plan.madeUsed, plan.learned = ctx.used, ctx.made, ctx.madeUsed, ctx.learned
    plan.leftovers, plan.back = Leftovers(ctx)
    plan.net = plan.total - plan.back
    plan.ctx = ctx
    return plan
end

-- Puts the learning into the steps. A visit to the trainer goes right before the first step that
-- needs a trained recipe, or with a new rank; it takes every recipe the path trains later that
-- can be learned by then. A recipe item goes right before the step that needs it.
local function Schedule(plan)
    local list = {}
    for _, l in pairs(plan.learned) do list[#list + 1] = l end
    table.sort(list, function(a, b) return a.order < b.order end)
    local steps, done = {}, {}
    local function Teach(train)
        for _, l in ipairs(list) do
            if not done[l] and l.info.how ~= "item" and l.info.at <= train.at then
                done[l] = true
                train.learn[#train.learn + 1] = l
                train.fee = train.fee + l.fee
                if l.unknown then train.unknown = train.unknown + 1 end
            end
        end
    end
    for _, step in ipairs(plan.steps) do
        if step.kind == "train" then
            local prev = steps[#steps]
            if prev and prev.kind == "train" and prev.at == step.at then
                prev.rank = step.rank
            else
                steps[#steps + 1] = step
                prev = step
            end
            Teach(prev)
        elseif step.kind == "craft" then
            local visit
            local items = {}
            for _, l in ipairs(list) do
                if l.step == step and not done[l] then
                    if l.info.how == "item" then
                        done[l] = true
                        items[#items + 1] = { kind = "learn", r = l.r, item = l.info.item, cost = l.fee, at = step.from }
                    else
                        visit = true
                    end
                end
            end
            if visit then
                local train = steps[#steps]
                if not (train and train.kind == "train" and train.at == step.from) then
                    train = { kind = "train", at = step.from, learn = {}, fee = 0, unknown = 0 }
                    steps[#steps + 1] = train
                end
                Teach(train)
            end
            for _, learn in ipairs(items) do steps[#steps + 1] = learn end
            steps[#steps + 1] = step
        else
            steps[#steps + 1] = step
        end
    end
    plan.steps = steps
end

-- Whether path a is at least as good as path b: further, then fewer points with no price, then cheaper.
local function NotWorse(a, b)
    if a.reached ~= b.reached then return a.reached > b.reached end
    if a.unpriced ~= b.unpriced then return a.unpriced < b.unpriced end
    return a.net <= b.net + 0.5
end

-- args: skill, max, target, offset, seenSkill, recipes, supply(item), marginal(sup, used, k, extra),
-- value(item, n) (what n left-over units sell for; optional), learn(recipe) (how a recipe that
-- isn't known is learned: { how = "trainer" or "item", at = skill, fee, item, seen }; optional)
function Pl.Build(args)
    local banned = {}
    local plan = Build(args, banned)
    -- Each point took the cheapest recipe without what learning it costs. Now drop every recipe
    -- with a fee or a recipe item that the path is no worse without, dearest first.
    local tested, tests = {}, 0
    local again = args.learn ~= nil
    while again and tests < MAX_TESTS do
        again = false
        local list = {}
        for id, l in pairs(plan.learned) do
            if not tested[id] and l.fee > 0.5 then list[#list + 1] = l end
        end
        table.sort(list, function(a, b)
            if a.fee ~= b.fee then return a.fee > b.fee end
            return a.r.id < b.r.id
        end)
        for _, l in ipairs(list) do
            local id = l.r.id
            tested[id] = true
            tests = tests + 1
            banned[id] = true
            local other = Build(args, banned)
            if NotWorse(other, plan) then
                plan = other
                again = true
                break
            end
            banned[id] = nil
            if tests >= MAX_TESTS then break end
        end
    end
    Schedule(plan)
    return plan
end

----------------------------------------------------------------------
-- What to buy, and the recipes worth finding
----------------------------------------------------------------------
-- One entry per reagent the path takes from outside: need (expected units), have, made (by the
-- path), buy (whole units), cost, from, spare (more units that cover an unlucky run) and what
-- they cost, missing (why there is no price), short (units more than are listed).
function Pl.Shopping(plan)
    local list = {}
    local Prices = ns.Prices
    local ctx = plan.ctx
    for item, need in pairs(plan.used) do
        if need > EPS then
            local sup = ctx.supply(item)
            local buy = math.max(0, math.ceil((ctx.bought[item] or 0) - 1e-6))
            local cost = Prices.Cost(sup, buy)
            local e = { item = item, need = need, have = sup.have, made = plan.made[item] or 0, buy = buy, cost = cost,
                stale = sup.stale and sup.listed > 0 and buy > 0 }
            if buy > 0 then
                local fromAH = sup.listed > 0
                if fromAH and sup.vendor then
                    -- A vendor's price is the ceiling: listings above it were left out.
                    local ah = math.min(buy, sup.listed)
                    e.from = ah >= buy and "auction house" or "auction house and vendor"
                elseif fromAH then
                    e.from = "auction house"
                elseif sup.vendor then
                    e.from = sup.vendorFrom == "vendor" and "vendor" or "vendor (item data)"
                end
                if not cost then
                    e.missing = Prices.Missing(sup)
                    if sup.listed > 0 and sup.listed < buy then
                        e.short = buy - sup.listed
                        e.listed = sup.listed
                        e.costListed = Prices.Cost(sup, sup.listed)
                    end
                end
                local spare = math.ceil(SPARE_Z * math.sqrt(ctx.var[item] or 0) - 1e-6)
                if spare > 0 and cost then
                    local more = Prices.Cost(sup, buy + spare)
                    e.spare, e.spareCost = spare, more and (more - cost) or nil
                end
            end
            list[#list + 1] = e
        end
    end
    table.sort(list, function(a, b)
        local ca, cb = a.cost or -1, b.cost or -1
        if ca ~= cb then return ca > cb end
        return a.item < b.item
    end)
    return list
end

-- What the whole path costs to buy: the shopping list in whole units and the trainer's fees.
local function Totals(plan)
    local spend, spare = plan.fees, 0
    for _, e in ipairs(plan.shopping) do
        if e.cost then spend = spend + e.cost elseif e.costListed then spend = spend + e.costListed end
        spare = spare + (e.spareCost or 0)
    end
    plan.spend, plan.spareCost = spend, spare
    plan.complete = plan.totalComplete and plan.feesUnknown == 0
end

-- Recipes the path can't count on (a recipe item with no price, a trainer that doesn't list
-- them) that would make it cheaper, or reach past where it stops.
function Pl.Options(plan, prof, limit)
    local out = {}
    local ctx = { offset = prof.offset or 0, seenSkill = prof.seenSkill, used = {}, made = {}, madeUsed = {},
        haveUsed = {}, bought = {}, var = {}, learn = {}, learned = {}, makers = {},
        supply = plan.ctx.supply, marginal = ns.Prices.Marginal, value = ns.Prices.ValueOf }
    local inPlan = plan.ctx and plan.ctx.learn or {}
    for _, r in ipairs(prof.recipes or {}) do
        local readable = not r.unreadable and r.slots and #r.slots > 0
        if not r.known and r.trust and readable and not inPlan[r.id] then
            local info, why = ns.Recipes.Learn(prof.line, r, plan.forOther)
            if not why then why = plan.left[r.id] end
            local o = { r = r, learnAt = info and info.at or r.rank, item = info and info.item or r.item, why = why,
                source = r.source, covers = 0, saving = 0 }
            local function Try(s, lim)
                if o.learnAt and s < o.learnAt then return nil end
                local chance, gain, crafts = AtSkill(ctx, r, s, lim)
                if not chance then return nil end
                local cost, priced, _, _, _, extra = CraftCost(ctx, r, crafts, s)
                return gain, cost + extra.given - extra.credit, priced
            end
            for _, p in ipairs(plan.points) do
                local gain, cost, priced = Try(p.s, p.to)
                if gain and priced and p.priced then
                    local diff = (p.net / p.gain - cost / gain) * p.gain
                    if diff >= 1 then
                        o.saving = o.saving + diff
                        o.from = o.from or p.s
                        o.to = p.to
                    end
                end
            end
            if plan.gapAt then
                for s = plan.gapAt, plan.to - 1 do
                    if Try(s, plan.to) then
                        o.covers = o.covers + 1
                        o.from = o.from and math.min(o.from, s) or s
                        o.to = math.max(o.to or 0, s + 1)
                    end
                end
            end
            if o.covers > 0 or o.saving >= 1 then out[#out + 1] = o end
        end
    end
    table.sort(out, function(a, b)
        if a.covers ~= b.covers then return a.covers > b.covers end
        if math.abs(a.saving - b.saving) >= 1 then return a.saving > b.saving end
        return a.r.id < b.r.id
    end)
    while #out > (limit or 5) do table.remove(out) end
    return out
end

----------------------------------------------------------------------
-- The path for a saved profession or for someone else, with its notes
----------------------------------------------------------------------
-- The target of a profession: its own (/skillpath target), else the rank's cap.
function Pl.Target(line)
    local targets = ns.db and ns.db.targets
    return type(targets) == "table" and ns.Num(targets[line]) or 0
end

-- Notes every path has: prices, recipes taken on trust.
local function Notes(plan, name)
    local notes = plan.notes
    local nMissing, nStale = 0, 0
    for _ in pairs(plan.missing) do nMissing = nMissing + 1 end
    for _ in pairs(plan.stale) do nStale = nStale + 1 end
    plan.nMissing, plan.nStale = nMissing, nStale
    local scanned = ns.Prices.Summary()
    plan.noScan = scanned == 0
    if plan.noScan then
        notes[#notes + 1] = "No auction prices yet: only vendor prices are known, so the order of recipes is a "
            .. "guess and the cost leaves out what vendors don't sell. Scan at the auction house."
    elseif nMissing > 0 then
        local has = nMissing == 1 and "reagent has" or "reagents have"
        -- A scan only helps with what no scan has read: the rest had none, or too few, for sale.
        local scan = ""
        for _, why in pairs(plan.missing) do
            if why == "not scanned yet" then scan = " Scan at the auction house." end
        end
        if plan.totalComplete then
            notes[#notes + 1] = ("%d %s no price, so a cheaper recipe may be left out.%s"):format(nMissing, has, scan)
        else
            notes[#notes + 1] = ("%d %s no price and %s not in the cost.%s")
                :format(nMissing, has, nMissing == 1 and "is" or "are", scan)
        end
    end
    if nStale > 0 then
        notes[#notes + 1] = ("%d reagent %s over %d h old. Scan again."):format(nStale,
            nStale == 1 and "price is" or "prices are", ns.db.staleHours or 3)
    end
    if plan.assumed > 0 then
        local one = plan.assumed == 1
        -- A list that was read may stop short: a trainer teaches up to their own rank.
        local seen = ns.db and type(ns.db.trainer) == "table" and ns.db.trainer[plan.line]
        local top = type(seen) == "table" and tonumber(seen.top) or 0
        notes[#notes + 1] = ("%s %d %s, learned at %s yellow skill, with no fee in the cost. The real skill is "
            .. "often lower, so this path may cost more than it has to. %s"):format(
            top > 0 and ("The %s trainer's list read so far stops at skill %d."):format(name, top)
                or ("The %s trainer's list is not read yet."):format(name),
            plan.assumed,
            one and "recipe is taken to be a trainer recipe" or "recipes are taken to be trainer recipes",
            one and "its" or "their",
            top > 0 and "Open a trainer of a higher rank to read the real skills and fees."
                or "Open the trainer once to read the real skills and fees.")
    elseif plan.feesUnknown > 0 then
        notes[#notes + 1] = ("The trainer showed no fee for %d %s: not in the cost."):format(plan.feesUnknown,
            plan.feesUnknown == 1 and "recipe" or "recipes")
    end
end

function Pl.ForProfession(prof)
    if not prof then
        return { ok = false, why = "Open a profession to get its path." }
    end
    local R = ns.Recipes
    local ceiling = R.Ceiling(prof.line)
    local skill, max = prof.skill or 0, prof.max or prof.skill or 0
    -- As far as the profession goes: the last rank's cap, or the highest grey of its recipes.
    local top = math.max(max, TOP_RANK)
    if ceiling > 0 and ceiling < top then top = ceiling end
    local own = Pl.Target(prof.line)
    local target = own > 0 and own or max
    -- At the rank's cap with no target of your own: on through the next rank, the trainer first.
    if own == 0 and skill >= max then target = max + RANK_STEP end
    local capped = false
    if target > top then target, capped = top, true end
    local base = { ok = false, name = prof.name, from = skill, to = target, max = max, prof = prof, line = prof.line }
    if skill >= target then
        if skill >= top then
            base.why = ("%s is at %d, as far as it goes."):format(prof.name, skill)
        else
            base.why = ("%s is at %d. The target (%d) is reached."):format(prof.name, skill, target)
        end
        return base
    end
    local plan = Pl.Build({
        skill = skill, max = max, target = target, offset = prof.offset or 0, seenSkill = prof.seenSkill,
        recipes = prof.recipes or {}, supply = ns.Prices.Supply, marginal = ns.Prices.Marginal,
        value = ns.Prices.ValueOf, learn = function(r) return R.Learn(prof.line, r) end,
    })
    plan.name, plan.prof, plan.line = prof.name, prof, prof.line
    plan.shopping = Pl.Shopping(plan)
    Totals(plan)
    plan.options = ns.db.showOptions and Pl.Options(plan, prof, 5) or {}

    local notes = plan.notes
    if capped and own > 0 then
        notes[#notes + 1] = ("%s stops at %d: no rank or recipe goes past it."):format(prof.name, top)
    end
    Notes(plan, prof.name)
    if plan.untrusted > 0 then
        notes[#notes + 1] = ("%d known %s the game's colours and %s used only while orange (/skillpath debug).")
            :format(plan.untrusted, plan.untrusted == 1 and "recipe doesn't match" or "recipes don't match",
                plan.untrusted == 1 and "is" or "are")
    end
    if plan.unreadable > 0 then
        notes[#notes + 1] = ("The game didn't give the reagents of %d known %s: left out."):format(plan.unreadable,
            plan.unreadable == 1 and "recipe" or "recipes")
    end
    -- Data.BUILD is "1.60.1.70938"; the game gives the last part.
    local build = prof.build
    local table = ns.Data and tostring(ns.Data.BUILD):match("(%d+)$")
    if build and table and tostring(build) ~= table then
        notes[#notes + 1] = ("The recipe table is from build %s, the game is %s. Each recipe is checked against the game.")
            :format(table, build)
    end
    if prof.unread then
        notes[#notes + 1] = "A recipe learned since isn't in the path. Open the profession to read it."
    elseif not ns.Recipes.WindowOpen() and prof.t and ns.Clock() - prof.t > 86400 then
        notes[#notes + 1] = ("Recipes last read %s."):format(ns.Age(ns.Clock() - prof.t))
    end
    return plan
end

-- The rank cap someone at this skill has at least: 75, 150, 225...
function Pl.CapAt(skill)
    return math.max(1, math.ceil(math.max(skill, 1) / RANK_STEP)) * RANK_STEP
end

-- A path for someone else: order = { line, from, to }. No recipe is known, nothing is in the
-- bags, every reagent is bought at today's prices.
function Pl.ForCustomer(order)
    local R = ns.Recipes
    local line = order.line
    local name = ns.Data and ns.Data.NAMES[line] or "Profession"
    local ceiling = R.Ceiling(line)
    local top = TOP_RANK
    if ceiling > 0 and ceiling < top then top = ceiling end
    local from, target = order.from, order.to
    local capped = false
    if target > top then target, capped = top, true end
    local base = { ok = false, name = name, from = from, to = target, line = line, forOther = true, order = order }
    if from >= target then
        base.why = capped and ("%s stops at %d: no rank or recipe goes past it."):format(name, top)
            or ("%s %d to %d: nothing to do."):format(name, from, target)
        return base
    end
    local recipes = R.ForOrder(line)
    local plan = Pl.Build({
        skill = from, max = Pl.CapAt(from), target = target, offset = 0, seenSkill = from,
        recipes = recipes, supply = ns.Prices.Bare, marginal = ns.Prices.Marginal,
        value = ns.Prices.ValueOf, learn = function(r) return R.Learn(line, r, true) end,
    })
    plan.name, plan.line, plan.forOther, plan.order = name, line, true, order
    plan.prof = { line = line, name = name, recipes = recipes, offset = 0, seenSkill = from, skill = from }
    plan.shopping = Pl.Shopping(plan)
    Totals(plan)
    plan.options = {}
    local notes = plan.notes
    if capped then
        notes[#notes + 1] = ("%s stops at %d: no rank or recipe goes past it."):format(name, top)
    end
    Notes(plan, name)
    return plan
end
