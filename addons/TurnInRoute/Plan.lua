-- Turn-in Route: the plan. Finished quests become stops (one NPC), stops become places
-- (a town or a camp in one zone), and the places are put in the order that takes the least
-- time with the flight paths, the hearthstone and the boats you have, without going back
-- to a zone you already left. Inside a place the stops are walked nearest first, then
-- straightened with 2-opt. Each place is one numbered leg.
local _, ns = ...
local Plan = {}
ns.Plan = Plan

local huge, floor = math.huge, math.floor

Plan.SAME_STOP = 15       -- yd: quests handed in this close together are one stop (one NPC)
Plan.TOWN = 250           -- yd: stops this close (chained) in one zone are one place
Plan.LABEL_NEAR = 400     -- yd: a place this close to a flight path, inn or dock takes its name
Plan.FAR = 1800           -- s: what a place with no known way there counts as
Plan.REVISIT = 600        -- s: added for going back to a zone the route already left
Plan.TURN_IN = 8          -- s: talking to the NPC and taking the reward, per quest
Plan.EXACT_UP_TO = 9      -- places: up to this many are ordered exactly (Held-Karp)
Plan.RIDE_BEFORE = 300    -- yd: a walk this long before a flight or boat is named in the leg
Plan.RIDE_AFTER = 200     -- yd: and after it

local function Dist(a, b)
    if a.continent ~= b.continent then return 1e6 end
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function Has(mask, i)
    return floor(mask / 2 ^ (i - 1)) % 2 == 1
end

----------------------------------------------------------------------
-- Stops and places
----------------------------------------------------------------------
local function MakeStops(placed)
    local stops = {}
    for _, quest in ipairs(placed) do
        local t, hit = quest.turnIn, nil
        for _, stop in ipairs(stops) do
            if stop.continent == t.continent and Dist(stop, t) <= Plan.SAME_STOP then hit = stop; break end
        end
        if hit then
            hit.quests[#hit.quests + 1] = quest
        else
            stops[#stops + 1] = { kind = "stop", quests = { quest }, x = t.x, y = t.y, continent = t.continent,
                zone = t.zone or quest.zone or "?", map = t.map, mx = t.mx, my = t.my, npc = t.npc }
        end
    end
    return stops
end

local function ZoneKey(stop)
    return tostring(stop.continent) .. ":" .. tostring(stop.zone)
end

local function MakePlaces(stops)
    local places, byZone, zones = {}, {}, {}
    for _, stop in ipairs(stops) do
        local key = ZoneKey(stop)
        if not byZone[key] then byZone[key] = {}; zones[#zones + 1] = key end
        table.insert(byZone[key], stop)
    end
    for _, key in ipairs(zones) do
        local list, group, made, id = byZone[key], {}, {}, 0
        for i = 1, #list do
            if not group[i] then
                id = id + 1
                group[i] = id
                local queue = { i }
                while #queue > 0 do
                    local a = table.remove(queue)
                    for j = 1, #list do
                        if not group[j] and Dist(list[a], list[j]) <= Plan.TOWN then
                            group[j] = id
                            queue[#queue + 1] = j
                        end
                    end
                end
            end
        end
        for i, stop in ipairs(list) do
            local place = made[group[i]]
            if not place then
                place = { kind = "place", stops = {}, zone = stop.zone, zoneKey = key, continent = stop.continent }
                made[group[i]] = place
                places[#places + 1] = place
            end
            place.stops[#place.stops + 1] = stop
        end
    end
    for _, place in ipairs(places) do
        local x, y, mx, my, nm, quests = 0, 0, 0, 0, 0, 0
        for _, stop in ipairs(place.stops) do
            x, y = x + stop.x, y + stop.y
            if stop.mx and stop.my then mx, my, nm = mx + stop.mx, my + stop.my, nm + 1 end
            quests = quests + #stop.quests
        end
        place.x, place.y = x / #place.stops, y / #place.stops
        if nm > 0 then place.mx, place.my = mx / nm, my / nm end
        place.questCount = quests
    end
    return places
end

-- "north-east", "central" ... from map coordinates (0..1, y down)
function Plan.Compass(mx, my)
    if not (mx and my) then return nil end
    local ns_ = my < 0.38 and "north" or my > 0.62 and "south" or ""
    local ew = mx < 0.38 and "west" or mx > 0.62 and "east" or ""
    if ns_ == "" and ew == "" then return "central" end
    if ns_ ~= "" and ew ~= "" then return ns_ .. "-" .. ew end
    return ns_ .. ew
end

local function Nearest(list, point, within)
    local best, bestD
    for _, node in ipairs(list or {}) do
        local d = Dist(node, point)
        if d <= within and (not bestD or d < bestD) then best, bestD = node, d end
    end
    return best
end

-- A place is named after the flight path, inn or dock it sits at, or else the part of its zone.
local function Label(places, ctx)
    for _, place in ipairs(places) do
        local town = Nearest(ctx.towns, place, Plan.LABEL_NEAR)
        local hearth = ctx.hearth
        if town then
            place.label = town.name
        elseif hearth and hearth.pos and hearth.name and Dist(hearth.pos, place) <= Plan.LABEL_NEAR then
            place.label = hearth.name
        else
            local dock = Nearest(ctx.docks, place, Plan.LABEL_NEAR)
            if dock then
                place.label = dock.name
            else
                local compass = Plan.Compass(place.mx, place.my)
                place.label = compass and (compass .. " " .. place.zone) or place.zone
                place.wild = true
            end
        end
    end
    local count = {}
    for _, place in ipairs(places) do count[place.label] = (count[place.label] or 0) + 1 end
    for _, place in ipairs(places) do
        if count[place.label] > 1 and not place.wild then
            local compass = Plan.Compass(place.mx, place.my)
            if compass then place.label = ("%s (%s)"):format(place.label, compass) end
        end
    end
end

----------------------------------------------------------------------
-- Walking the stops of one place: nearest first from the entry, then 2-opt (entry fixed)
----------------------------------------------------------------------
local function PathYards(list)
    local total = 0
    for i = 2, #list do total = total + Dist(list[i - 1], list[i]) end
    return total
end

local function TwoOpt(list, fixedFirst, cost)
    cost = cost or PathYards
    local n = #list
    if n < 3 then return list end
    local best = cost(list)
    local improved, passes = true, 0
    while improved and passes < 8 do
        improved, passes = false, passes + 1
        for i = fixedFirst and 2 or 1, n - 1 do
            for j = i + 1, n do
                local tryList = {}
                for k = 1, i - 1 do tryList[k] = list[k] end
                for k = i, j do tryList[k] = list[j - (k - i)] end
                for k = j + 1, n do tryList[k] = list[k] end
                local c = cost(tryList)
                if c < best - 1e-6 then list, best, improved = tryList, c, true end
            end
        end
    end
    return list
end
Plan.TwoOpt = TwoOpt

local function NearestFirst(items, first)
    local order, left = { first }, {}
    for _, item in ipairs(items) do if item ~= first then left[#left + 1] = item end end
    local cur = first
    while #left > 0 do
        local bi, bd = 1, huge
        for i, item in ipairs(left) do
            local d = Dist(cur, item)
            if d < bd then bi, bd = i, d end
        end
        cur = table.remove(left, bi)
        order[#order + 1] = cur
    end
    return order
end

local function WalkStops(stops, entry)
    return TwoOpt(NearestFirst(stops, entry), true)
end

----------------------------------------------------------------------
-- Ordering the places
----------------------------------------------------------------------
local function Order(places, T, TS, TH, inside, hearth)
    local n = #places
    local usable = hearth and hearth.usable
    local remaining = usable and hearth.remaining or huge
    local same = {}                -- the other places in each place's zone
    for j = 1, n do
        same[j] = {}
        for k = 1, n do
            if k ~= j and places[k].zoneKey == places[j].zoneKey then same[j][#same[j] + 1] = k end
        end
    end
    local function Revisit(visited, last, j)
        if last and places[last].zoneKey == places[j].zoneKey then return 0 end
        for _, k in ipairs(same[j]) do
            if visited(k) then return Plan.REVISIT end
        end
        return 0
    end

    if n <= Plan.EXACT_UP_TO then
        -- Held-Karp over (visited set, last place, hearth used)
        local obj, real, parent, hearthed = {}, {}, {}, {}
        local function Key(mask, last, h) return (mask * n + (last - 1)) * 2 + h end
        local function Relax(key, o, r, from, viaHearth)
            if obj[key] == nil or o < obj[key] then
                obj[key], real[key], parent[key], hearthed[key] = o, r, from, viaHearth
            end
        end
        for j = 1, n do
            local bit = 2 ^ (j - 1)
            local c = TS[j]
            Relax(Key(bit, j, 0), c + inside[j], c + inside[j], false, false)
            if usable and remaining <= 0 then
                c = ns.Travel.HEARTH_TIME + TH[j]
                Relax(Key(bit, j, 1), c + inside[j], c + inside[j], false, true)
            end
        end
        local full = 2 ^ n - 1
        for mask = 1, full do
            for last = 1, n do
                if Has(mask, last) then
                    for h = 0, 1 do
                        local key = Key(mask, last, h)
                        local o = obj[key]
                        if o then
                            local r = real[key]
                            local visited = function(k) return Has(mask, k) end
                            for j = 1, n do
                                if not Has(mask, j) then
                                    local nextMask = mask + 2 ^ (j - 1)
                                    local pen = Revisit(visited, last, j)
                                    local c = T[last][j]
                                    Relax(Key(nextMask, j, h), o + c + pen + inside[j], r + c + inside[j], key, false)
                                    if h == 0 and usable and r >= remaining then
                                        c = ns.Travel.HEARTH_TIME + TH[j]
                                        Relax(Key(nextMask, j, 1), o + c + pen + inside[j], r + c + inside[j], key, true)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        local bestKey, bestO
        for last = 1, n do
            for h = 0, 1 do
                local key = Key(full, last, h)
                if obj[key] and (not bestO or obj[key] < bestO) then bestKey, bestO = key, obj[key] end
            end
        end
        local order, hearthAt, key = {}, nil, bestKey
        while key do
            local last = floor(key / 2) % n + 1
            table.insert(order, 1, last)
            if hearthed[key] then hearthAt = last end
            key = parent[key] or nil
        end
        local at
        for i, j in ipairs(order) do if j == hearthAt then at = i end end
        return order, at
    end

    -- Many places: nearest first by time, then 2-opt on the whole time, with the hearthstone
    -- put where it saves the most.
    local function Evaluate(order)
        local function Run(hearthBefore)
            local o, r, last = 0, 0, nil
            local seen = {}
            local visited = function(k) return seen[k] end
            for i, j in ipairs(order) do
                local c
                if i == hearthBefore then
                    if r < remaining then return huge end
                    c = ns.Travel.HEARTH_TIME + TH[j]
                elseif last then
                    c = T[last][j]
                else
                    c = TS[j]
                end
                o = o + c + Revisit(visited, last, j) + inside[j]
                r = r + c + inside[j]
                seen[j], last = true, j
            end
            return o
        end
        local best, at = Run(nil), nil
        if usable then
            for k = 1, #order do
                local o = Run(k)
                if o < best then best, at = o, k end
            end
        end
        return best, at
    end
    local order, left, last = {}, {}, nil
    for j = 1, n do left[j] = j end
    while #left > 0 do
        local bi, bc = 1, huge
        for i, j in ipairs(left) do
            local c = (last and T[last][j] or TS[j])
            if last and places[last].zoneKey ~= places[j].zoneKey then c = c + 1 end   -- finish a zone first
            if c < bc then bi, bc = i, c end
        end
        last = table.remove(left, bi)
        order[#order + 1] = last
    end
    order = TwoOpt(order, false, function(list) return (Evaluate(list)) end)
    local _, at = Evaluate(order)
    return order, at
end

----------------------------------------------------------------------
-- The words of a leg, from the path the travel graph found
----------------------------------------------------------------------
local RIDE_NAMES = { boat = "boat", zeppelin = "zeppelin", tram = "Deeprun Tram" }

local function Describe(graph, tree, dst, viaHearth, label, ctx)
    local go = ctx.mounted and "ride" or "run"
    local parts, walk, lastMode, lastName = {}, 0, nil, nil
    if viaHearth then
        parts[1] = "hearth to " .. (ctx.hearth.name or "your inn")
        lastName, lastMode = ctx.hearth.name, "hearth"
    end
    local steps = tree and ns.Travel.Path(graph, tree, dst.index) or {}
    for _, step in ipairs(steps) do
        if step.mode == "walk" then
            walk = walk + Dist(step.from, step.to)
        else
            if walk >= Plan.RIDE_BEFORE and step.from.name then parts[#parts + 1] = go .. " to " .. step.from.name end
            if step.mode == "fly" then
                local text = "fly to " .. step.to.name
                if lastMode == "fly" and walk == 0 then parts[#parts] = text else parts[#parts + 1] = text end
            else
                parts[#parts + 1] = ("take the %s to %s"):format(RIDE_NAMES[step.mode] or step.mode, step.to.name)
            end
            walk, lastMode, lastName = 0, step.mode, step.to.name
        end
    end
    if #parts == 0 then
        parts[1] = go .. " to " .. label
    elseif walk >= Plan.RIDE_AFTER and lastName ~= label then
        parts[#parts + 1] = "then " .. go .. " to " .. label
    end
    local text = table.concat(parts, ", ")
    return (text:gsub("^%l", string.upper)), lastMode or "walk"
end

----------------------------------------------------------------------
-- The plan
----------------------------------------------------------------------
function Plan.Make(quests, here, ctx)
    local Travel = ns.Travel
    local plan = { legs = {}, inside = {}, unknown = {}, seconds = 0, located = here ~= nil, travel = ctx }
    local placed = {}
    -- Every finished quest goes where its turn-in is, whatever its tag; only a turn-in
    -- inside an instance (where the route cannot lead) or an unknown one is left off.
    for _, quest in ipairs(quests or {}) do
        local turnIn = quest.turnIn
        if turnIn and turnIn.instance then
            plan.inside[#plan.inside + 1] = quest
        elseif not (turnIn and turnIn.x and turnIn.y and turnIn.continent) then
            plan.unknown[#plan.unknown + 1] = quest
        else
            placed[#placed + 1] = quest
        end
    end
    table.sort(plan.inside, function(a, b)
        if a.turnIn.instance ~= b.turnIn.instance then return a.turnIn.instance < b.turnIn.instance end
        return a.id < b.id
    end)
    if #placed == 0 then return plan end

    local stops = MakeStops(placed)
    local places = MakePlaces(stops)
    Label(places, ctx)

    local graph = Travel.Graph(ctx)
    for _, place in ipairs(places) do
        Travel.Add(graph, place)
        for _, stop in ipairs(place.stops) do Travel.Add(graph, stop) end
    end
    local start = here and { kind = "start", x = here.x, y = here.y, continent = here.continent }
    if start then Travel.Add(graph, start) end
    local hearth = ctx.hearth
    local hearthNode = hearth and hearth.usable and { kind = "hearth", name = hearth.name, x = hearth.pos.x,
        y = hearth.pos.y, continent = hearth.pos.continent }
    if hearthNode then Travel.Add(graph, hearthNode) end

    local trees = {}
    local function TreeFrom(node)
        if not trees[node.index] then trees[node.index] = Travel.Shortest(graph, node.index) end
        return trees[node.index]
    end
    local function Time(tree, node)
        local d = tree and tree.dist[node.index]
        if not d or d == huge then return Plan.FAR, true end
        return d, false
    end

    -- Place-to-place times (centroid to centroid) and the time spent inside each place.
    local n, speed = #places, ctx.speed
    local T, TS, TH, inside = {}, {}, {}, {}
    for i, a in ipairs(places) do
        T[i] = {}
        local tree = TreeFrom(a)
        for j, b in ipairs(places) do T[i][j] = i == j and 0 or (Time(tree, b)) end
        local first = Nearest(a.stops, a, huge) or a.stops[1]
        inside[i] = PathYards(WalkStops(a.stops, first)) / speed + Plan.TURN_IN * a.questCount
        TS[i] = start and (Time(TreeFrom(start), a)) or 0
        TH[i] = hearthNode and (Time(TreeFrom(hearthNode), a)) or huge
    end
    local order, hearthAt = Order(places, T, TS, TH, inside, hearthNode and hearth)
    plan.hearthUsed = hearthAt ~= nil

    -- The legs, each from where the last one ended.
    local exit = start
    for k, j in ipairs(order) do
        local place = places[j]
        local viaHearth = hearthAt == k
        local tree = viaHearth and TreeFrom(hearthNode) or (exit and TreeFrom(exit)) or nil
        local entry, travel, noWay = place.stops[1], 0, false
        if tree then
            local best = huge
            for _, stop in ipairs(place.stops) do
                local d = tree.dist[stop.index]
                if d < best then entry, best = stop, d end
            end
            travel, noWay = Time(tree, entry)
        else
            entry = Nearest(place.stops, place, huge) or entry
        end
        if viaHearth then travel = travel + Travel.HEARTH_TIME end
        local walked = WalkStops(place.stops, entry)
        local questList = {}
        for _, stop in ipairs(walked) do
            for _, quest in ipairs(stop.quests) do questList[#questList + 1] = quest end
        end
        local text, how
        if noWay then
            text, how = ("Go to %s (no known way there yet)"):format(place.label), "none"
        elseif not tree then
            text, how = "Go to " .. place.label, "start"
        else
            text, how = Describe(graph, tree, entry, viaHearth, place.label, ctx)
        end
        local insideTime = PathYards(walked) / speed + Plan.TURN_IN * #questList
        local leg = { number = k, text = text, label = place.label, zone = place.zone, quests = questList,
            stops = walked, travel = travel, inside = insideTime, seconds = travel + insideTime,
            noWay = noWay or nil, how = how or "walk", hearth = viaHearth or nil }
        plan.legs[k] = leg
        plan.seconds = plan.seconds + leg.seconds
        exit = walked[#walked]
    end

    -- For comparison: the old order (stops by straight-line yards from where you stand),
    -- timed with the same travel (no hearthstone; it never planned one).
    local yards = {}
    for _, stop in ipairs(stops) do yards[#yards + 1] = stop end
    local function YardsCost(list)
        local total, cur = 0, start
        for _, stop in ipairs(list) do
            if cur then total = total + Dist(cur, stop) end
            cur = stop
        end
        return total
    end
    local first = start and Nearest(yards, start, huge) or yards[1]
    yards = TwoOpt(NearestFirst(yards, first), false, YardsCost)
    local t, cur = 0, start
    for _, stop in ipairs(yards) do
        if cur then t = t + (Time(TreeFrom(cur), stop)) end
        t = t + Plan.TURN_IN * #stop.quests
        cur = stop
    end
    plan.yardsSeconds, plan.yardsOrder = t, yards
    return plan
end

----------------------------------------------------------------------
-- One line for the window's top and the chat
----------------------------------------------------------------------
local function Plural(n, one, many) return n == 1 and ("1 " .. one) or (n .. " " .. many) end

function Plan.Summary(plan)
    local count = 0
    for _, leg in ipairs(plan.legs) do count = count + #leg.quests end
    local extra = {}
    if #plan.inside > 0 then
        extra[#extra + 1] = Plural(#plan.inside, "quest handed in inside a dungeon", "quests handed in inside a dungeon")
    end
    if #plan.unknown > 0 then
        extra[#extra + 1] = Plural(#plan.unknown, "quest with no known turn-in place", "quests with no known turn-in place")
    end
    local extraText = #extra > 0 and (" " .. table.concat(extra, " and ") .. " listed below the route.") or ""
    if count == 0 then
        if #extra == 0 then return "No finished quests in your quest log." end
        return "No finished quest on the route." .. extraText
    end
    local ctx = plan.travel or {}
    local text = ("%s, %s, about %s."):format(Plural(#plan.legs, "leg", "legs"), Plural(count, "turn-in", "turn-ins"),
        ns.Duration(plan.seconds))
    text = text .. " Hearthstone: " .. ns.Travel.HearthText(ctx.hearth) .. "."
    local known = ctx.flightCount or 0
    if known == 0 then
        text = text .. " Flight paths: none known yet (open a flight master's map to add them)."
    elseif ctx.useFlights == false then
        text = text .. (" Flight paths: %d known, not used (turned off)."):format(known)
    else
        text = text .. (" Flight paths: %d known."):format(known)
    end
    if not plan.located then text = text .. " Your position is unknown here, so the route starts at its first stop." end
    return text .. extraText
end
