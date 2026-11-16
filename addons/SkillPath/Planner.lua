-- SkillPath: the guide. For every skill point from now to the target it picks the known recipe
-- with the lowest expected cost for that point, from:
--   * the chance a craft gives a point (orange always; yellow and green by the classic formula
--     from the recipe's yellow and grey levels: (grey - skill) / (grey - yellow));
--   * what its reagents cost at that point of the guide: what you hold first (and what earlier
--     steps made), then auction listings cheapest first, or a vendor when that is cheaper.
-- A recipe whose levels the game didn't confirm is only used where the game itself shows it orange.
local _, ns = ...
local Pl = {}
ns.Planner = Pl

local EPS = 1e-9

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

-- How many of the `need` units taken after `used` come out of what earlier steps made (your own
-- units, from bags and bank, are taken first).
local function FromMade(ctx, sup, item, need)
    local used, have, made = ctx.used[item] or 0, sup.have, ctx.made[item] or 0
    return math.max(0, math.min(used + need, have + made) - math.max(used, have))
end

-- Returns cost (gold for the priced reagents), whether every reagent is priced, the item chosen
-- for each slot, the missing items (with the reason), the items priced from an old scan, and
-- `extra`: credit (what selling this craft's output would give back), given (what made items it
-- uses would have sold for) and take[slot] (how many made units each slot uses).
local function CraftCost(ctx, r, crafts)
    local cost, priced = 0, true
    local choice, missing, stale = {}, nil, nil
    local extra = { credit = 0, given = 0, take = {} }
    if r.currency then
        priced = false
        missing = { { why = "it also costs a currency" } }
    end
    if r.unreadable then
        priced = false
        missing = missing or {}
        missing[#missing + 1] = { why = "the game didn't name one of its reagents" }
    end
    for i, slot in ipairs(r.slots or {}) do
        local need = slot.qty * crafts
        local bestCost, bestItem, bestSup, bestTake, bestGiven
        for _, item in ipairs(slot.items) do
            local sup = ctx.supply(item)
            local c = ctx.marginal(sup, ctx.used[item] or 0, need, ctx.made[item] or 0)
            if c then
                local take = FromMade(ctx, sup, item, need)
                local left = (ctx.made[item] or 0) - (ctx.madeUsed[item] or 0)
                local given = Value(ctx, item, left) - Value(ctx, item, math.max(0, left - take))
                if not bestCost or c + given < bestCost + bestGiven then
                    bestCost, bestItem, bestSup, bestTake, bestGiven = c, item, sup, take, given
                end
            end
        end
        if bestCost then
            cost = cost + bestCost
            choice[i] = bestItem
            extra.take[i] = bestTake
            extra.given = extra.given + bestGiven
            -- An auction price was part of it, and that scan is old.
            if bestCost > EPS and bestSup.stale and bestSup.listed > 0 then
                stale = stale or {}
                stale[#stale + 1] = bestItem
            end
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

local function Commit(ctx, r, crafts, choice, extra)
    for i, slot in ipairs(r.slots or {}) do
        local item = choice[i]
        if item then
            ctx.used[item] = (ctx.used[item] or 0) + slot.qty * crafts
            local take = extra and extra.take[i] or 0
            if take > 0 then ctx.madeUsed[item] = (ctx.madeUsed[item] or 0) + take end
        end
    end
    if r.out and r.outQty and r.outQty > 0 then
        ctx.made[r.out] = (ctx.made[r.out] or 0) + crafts * r.outQty
    end
end

-- What is left of everything the guide made, and what selling it gives back.
local function Leftovers(ctx)
    local list, back = {}, 0
    for item, made in pairs(ctx.made) do
        local left = made - (ctx.madeUsed[item] or 0)
        if left > 0.05 then
            local value = Value(ctx, item, left)
            back = back + value
            list[#list + 1] = { item = item, left = left, value = value }
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

local function Better(a, b)
    if not b then return true end
    if math.abs(a.perPoint - b.perPoint) > 0.5 then return a.perPoint < b.perPoint end
    if math.abs(a.craftsPerPoint - b.craftsPerPoint) > EPS then return a.craftsPerPoint < b.craftsPerPoint end
    return a.r.id < b.r.id
end

local function BetterUnpriced(a, b)
    if not b then return true end
    if math.abs(a.craftsPerPoint - b.craftsPerPoint) > EPS then return a.craftsPerPoint < b.craftsPerPoint end
    if math.abs(a.perPoint - b.perPoint) > 0.5 then return a.perPoint < b.perPoint end
    return a.r.id < b.r.id
end

----------------------------------------------------------------------
-- The whole guide
----------------------------------------------------------------------
-- args: skill, max, target, offset, seenSkill, recipes, supply(item), marginal(sup, used, k, extra),
-- value(item, n) (what n left-over units sell for; optional)
function Pl.Build(args)
    local ctx = {
        offset = args.offset or 0, seenSkill = args.seenSkill or args.skill,
        supply = args.supply, marginal = args.marginal, value = args.value, used = {}, made = {}, madeUsed = {},
    }
    local plan = { ok = true, from = args.skill, to = args.target, max = args.max, points = {}, steps = {},
        total = 0, totalComplete = true, missing = {}, stale = {}, notes = {}, untrusted = 0 }
    local candidates = {}
    for _, r in ipairs(args.recipes) do
        if r.known then
            if r.trust or r.colour == ns.Recipes.OPTIMAL then candidates[#candidates + 1] = r end
            if not r.trust then plan.untrusted = plan.untrusted + 1 end
        end
    end

    local s = args.skill
    local trained = false
    while s < args.target do
        if s >= args.max and not trained then
            plan.steps[#plan.steps + 1] = { kind = "train", at = s }
            trained = true
        end
        local limit = s < args.max and math.min(args.max, args.target) or args.target
        local best, bestUnpriced
        local unpriced = {}
        for _, r in ipairs(candidates) do
            local chance, gain, crafts, orange = AtSkill(ctx, r, s, limit)
            if chance then
                local cost, priced, choice, missing, stale, extra = CraftCost(ctx, r, crafts)
                local net = cost + extra.given - extra.credit
                local c = { r = r, chance = chance, gain = gain, crafts = crafts, orange = orange, cost = cost,
                    priced = priced, choice = choice, missing = missing, stale = stale, extra = extra, net = net,
                    perPoint = net / gain, craftsPerPoint = crafts / gain }
                if priced then
                    if Better(c, best) then best = c end
                else
                    unpriced[#unpriced + 1] = c
                    if BetterUnpriced(c, bestUnpriced) then bestUnpriced = c end
                end
            end
        end
        local pick = best or bestUnpriced
        if not pick then
            plan.steps[#plan.steps + 1] = { kind = "gap", from = s, to = args.target,
                why = ("Nothing you know gives skill at %d. Learn a new recipe."):format(s) }
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
        Commit(ctx, pick.r, pick.crafts, pick.choice, pick.extra)
        local point = { s = s, to = s + pick.gain, r = pick.r, chance = pick.chance, gain = pick.gain,
            crafts = pick.crafts, orange = pick.orange, cost = pick.priced and pick.cost or nil, known = pick.cost,
            priced = pick.priced, missing = pick.missing, stale = pick.stale, alts = alts,
            credit = pick.extra.credit, given = pick.extra.given, net = pick.priced and pick.net or nil }
        plan.points[#plan.points + 1] = point
        if pick.priced then
            plan.total = plan.total + pick.cost
        else
            plan.totalComplete = false
        end
        for _, m in ipairs(pick.missing or {}) do
            if m.item then plan.missing[m.item] = m.why end
        end
        -- A reagent with no price that keeps a maybe-cheaper recipe out is missing too: a scan could change the guide.
        for _, c in ipairs(alts or {}) do
            for _, m in ipairs(c.missing or {}) do
                if m.item then plan.missing[m.item] = m.why end
            end
        end
        for _, item in ipairs(pick.stale or {}) do plan.stale[item] = true end

        local last = plan.steps[#plan.steps]
        if last and last.kind == "craft" and last.r == pick.r and last.priced == pick.priced then
            last.to = point.to
            last.crafts = last.crafts + pick.crafts
            last.cost = last.cost + (pick.cost or 0)
            last.credit = last.credit + pick.extra.credit
            last.given = last.given + pick.extra.given
            last.points[#last.points + 1] = point
            if alts then
                for _, c in ipairs(alts) do last.alts[c.r.id] = c end
            end
            if pick.stale then last.stale = true end
        else
            local step = { kind = "craft", r = pick.r, name = pick.r.name, from = s, to = point.to,
                crafts = pick.crafts, cost = pick.cost or 0, priced = pick.priced, points = { point },
                credit = pick.extra.credit, given = pick.extra.given,
                stale = pick.stale and true or false, alts = {} }
            for _, c in ipairs(alts or {}) do step.alts[c.r.id] = c end
            plan.steps[#plan.steps + 1] = step
        end
        s = point.to
    end
    plan.reached = s
    plan.used, plan.made = ctx.used, ctx.made
    plan.leftovers, plan.back = Leftovers(ctx)
    plan.net = plan.total - plan.back
    plan.ctx = ctx
    return plan
end

----------------------------------------------------------------------
-- What to buy, and the recipes worth learning
----------------------------------------------------------------------
function Pl.Shopping(plan)
    local list = {}
    local Prices = ns.Prices
    for item, need in pairs(plan.used) do
        if need > EPS then
            local sup = Prices.Supply(item)
            local made = plan.made[item] or 0
            local free = sup.have + made
            local buy = math.max(0, math.ceil(need - free - EPS))
            local cost = Prices.Cost(sup, buy)
            local from
            if buy > 0 then
                local fromAH = sup.listed > 0
                if fromAH and sup.vendor then
                    from = "auction house and vendor"
                elseif fromAH then
                    from = "auction house"
                elseif sup.vendor then
                    from = sup.vendorFrom == "vendor" and "vendor" or "vendor (item data)"
                end
            end
            list[#list + 1] = { item = item, need = need, have = sup.have, made = made, buy = buy, cost = cost,
                from = from, missing = buy > 0 and not cost and Prices.Missing(sup) or nil, stale = sup.stale
                    and sup.listed > 0 and buy > 0 }
        end
    end
    table.sort(list, function(a, b)
        local ca, cb = a.cost or -1, b.cost or -1
        if ca ~= cb then return ca > cb end
        return a.item < b.item
    end)
    return list
end

-- Recipes you don't know that would make the path cheaper, or reach past where it stops.
function Pl.Options(plan, prof, limit)
    local out = {}
    local ctx = { offset = prof.offset or 0, seenSkill = prof.seenSkill, used = {}, made = {}, madeUsed = {},
        supply = ns.Prices.Supply, marginal = ns.Prices.Marginal, value = ns.Prices.ValueOf }
    for _, r in ipairs(prof.recipes or {}) do
        if not r.known and r.trust then
            local o = { r = r, learnAt = r.rank, source = r.source, covers = 0, saving = 0 }
            local function Try(s, lim)
                if o.learnAt and s < o.learnAt then return nil end
                local chance, gain, crafts = AtSkill(ctx, r, s, lim)
                if not chance then return nil end
                local cost, priced, _, _, _, extra = CraftCost(ctx, r, crafts)
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
-- The path for a saved profession, with its notes
----------------------------------------------------------------------
function Pl.ForProfession(prof)
    if not prof then
        return { ok = false, why = "Open a profession to get its path." }
    end
    local R = ns.Recipes
    local ceiling = R.Ceiling(prof.line)
    local skill, max = prof.skill or 0, prof.max or prof.skill or 0
    local target = (ns.db.target or 0) > 0 and ns.db.target or max
    local capped = false
    if ceiling > 0 and target > ceiling then target, capped = ceiling, true end
    local base = { ok = false, name = prof.name, from = skill, to = target, max = max, prof = prof }
    if skill >= target then
        if (ns.db.target or 0) == 0 and skill >= max then
            base.why = ("%s is at %d, your rank's cap. Train the next rank."):format(prof.name, skill)
        else
            base.why = ("%s is at %d. The target (%d) is reached."):format(prof.name, skill, target)
        end
        return base
    end
    local plan = Pl.Build({
        skill = skill, max = max, target = target, offset = prof.offset or 0, seenSkill = prof.seenSkill,
        recipes = prof.recipes or {}, supply = ns.Prices.Supply, marginal = ns.Prices.Marginal,
        value = ns.Prices.ValueOf,
    })
    plan.name, plan.prof, plan.line = prof.name, prof, prof.line
    plan.shopping = Pl.Shopping(plan)
    plan.options = ns.db.showOptions and Pl.Options(plan, prof, 5) or {}

    local notes = plan.notes
    if capped then
        notes[#notes + 1] = ("No %s recipe gives skill past %d. The path stops there."):format(prof.name, ceiling)
    end
    local nMissing, nStale = 0, 0
    for _ in pairs(plan.missing) do nMissing = nMissing + 1 end
    for _ in pairs(plan.stale) do nStale = nStale + 1 end
    plan.nMissing, plan.nStale = nMissing, nStale
    if nMissing > 0 then
        local has = nMissing == 1 and "reagent has" or "reagents have"
        if plan.totalComplete then
            notes[#notes + 1] = ("%d %s no price, so a cheaper recipe may be left out. Scan at the auction house.")
                :format(nMissing, has)
        else
            notes[#notes + 1] = ("%d %s no price and %s not in the cost. Scan at the auction house.")
                :format(nMissing, has, nMissing == 1 and "is" or "are")
        end
    end
    if nStale > 0 then
        notes[#notes + 1] = ("%d reagent %s over %d h old. Scan again."):format(nStale,
            nStale == 1 and "price is" or "prices are", ns.db.staleHours or 3)
    end
    if ns.db.sellAH then
        local waiting = 0
        for _, e in ipairs(plan.leftovers) do
            if ns.Prices.Resale(e.item).waiting then waiting = waiting + 1 end
        end
        if waiting > 0 then
            notes[#notes + 1] = ("%d %s no auction sales seen yet, so %s at the vendor price. Seeing sales takes "
                .. "scans hours apart."):format(waiting, waiting == 1 and "leftover has" or "leftovers have",
                waiting == 1 and "it counts" or "they count")
        end
    end
    if plan.untrusted > 0 then
        notes[#notes + 1] = ("%d known %s the game's colours and %s used only while orange (/skillpath debug).")
            :format(plan.untrusted, plan.untrusted == 1 and "recipe doesn't match" or "recipes don't match",
                plan.untrusted == 1 and "is" or "are")
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
