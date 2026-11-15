-- Turn-in Route: how you can get around. Walking or riding at your speed, the flight paths
-- this character knows (learned from the flight master's map), the hearthstone (where it
-- takes you is learned when you bind or use it), and the boats, zeppelins and tram.
-- Times are estimates in seconds; the game gives addons no paths or flight times.
local _, ns = ...
local Travel = {}
ns.Travel = Travel

local Call, Num, Str, Field = ns.Call, ns.Num, ns.Str, ns.Field
local sqrt, huge, max = math.sqrt, math.huge, math.max

Travel.WALK = 7               -- yd/s on foot
Travel.FLIGHT_SPEED = 32      -- yd/s on a flight path (the server's taxi speed)
Travel.FLIGHT_DETOUR = 1.25   -- flight paths bend between their nodes
Travel.FLIGHT_EXTRA = 25      -- s: the flight master, take-off and landing
Travel.HEARTH_TIME = 25       -- s: the 10 s cast and a loading screen
Travel.HEARTHSTONE = 6948     -- the Hearthstone item
Travel.HEARTH_SPELL = 8690    -- its spell

-- Boats, zeppelins and the tram, as points on zone maps (approximate: the dock, not the
-- deck). `time` is an average wait plus the ride. Faction nil: anyone may ride it.
Travel.TRANSPORTS = {
    { kind = "boat", faction = "Alliance", time = 240,
      a = { 1437, 0.046, 0.571, "Menethil Harbor" }, b = { 1439, 0.324, 0.438, "Auberdine" } },
    { kind = "boat", faction = "Alliance", time = 240,
      a = { 1437, 0.050, 0.634, "Menethil Harbor" }, b = { 1445, 0.716, 0.564, "Theramore Isle" } },
    { kind = "boat", faction = "Alliance", time = 180,
      a = { 1439, 0.331, 0.402, "Auberdine" }, b = { 1438, 0.552, 0.937, "Rut'theran Village" } },
    { kind = "tram", faction = "Alliance", time = 150,
      a = { 1453, 0.642, 0.082, "Stormwind" }, b = { 1455, 0.767, 0.512, "Ironforge" } },
    { kind = "boat", time = 240,
      a = { 1434, 0.259, 0.731, "Booty Bay" }, b = { 1413, 0.637, 0.386, "Ratchet" } },
    { kind = "zeppelin", faction = "Horde", time = 240,
      a = { 1411, 0.509, 0.138, "Orgrimmar" }, b = { 1420, 0.607, 0.588, "Undercity" } },
    { kind = "zeppelin", faction = "Horde", time = 240,
      a = { 1411, 0.506, 0.126, "Orgrimmar" }, b = { 1434, 0.316, 0.291, "Grom'gol" } },
    { kind = "zeppelin", faction = "Horde", time = 240,
      a = { 1420, 0.619, 0.590, "Undercity" }, b = { 1434, 0.314, 0.302, "Grom'gol" } },
}

local function Dist(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx * dx + dy * dy)
end
Travel.Dist = Dist

-- "Sentinel Hill" for "Sentinel Hill, Westfall"
function Travel.ShortName(name)
    return (tostring(name or "?"):match("^([^,]+)") or tostring(name)):gsub("%s+$", "")
end

----------------------------------------------------------------------
-- Learning
----------------------------------------------------------------------
local function KnownState(state, kind)
    if kind then return kind == "CURRENT" or kind == "REACHABLE" end
    local enum = Enum and Enum.FlightPathState
    local current = type(enum) == "table" and Num(enum.Current) or 0
    local reachable = type(enum) == "table" and Num(enum.Reachable) or 1
    return state == current or state == reachable
end

local function Store(key, name, mapID, x, y)
    local pos = ns.Places.WorldPos(mapID, x, y)
    if not (pos and name) then return false end
    local flights = ns.cdb.flights
    local isNew = flights[key] == nil
    flights[key] = { name = name, continent = pos.continent, x = pos.x, y = pos.y }
    return isNew
end

-- At a flight master: every node this character can fly to (or stands at) on this map.
-- Returns how many were new.
function Travel.LearnTaxi()
    local mapID = Num(Call(GetTaxiMapID))
    local new = 0
    if mapID and C_TaxiMap and type(C_TaxiMap.GetAllTaxiNodes) == "function" then
        local nodes = Call(C_TaxiMap.GetAllTaxiNodes, mapID)
        if type(nodes) == "table" then
            for _, node in ipairs(nodes) do
                local name = Str(Field(node, "name"))
                local pos = Field(node, "position")
                local x, y = Num(Field(pos, "x")), Num(Field(pos, "y"))
                if name and x and y and KnownState(Num(Field(node, "state"))) then
                    local key = Num(Field(node, "nodeID")) or name
                    if Store(key, name, mapID, x, y) then new = new + 1 end
                end
            end
            return new
        end
    end
    -- The older calls: one index per node on the open flight map.
    if mapID and NumTaxiNodes and TaxiNodeName and TaxiNodePosition and TaxiNodeGetType then
        for i = 1, Num(Call(NumTaxiNodes)) or 0 do
            local name = Str(Call(TaxiNodeName, i))
            local x, y = Call(TaxiNodePosition, i)
            x, y = Num(x), Num(y)
            if name and x and y and KnownState(nil, Str(Call(TaxiNodeGetType, i))) then
                if Store(name, name, mapID, x, y) then new = new + 1 end
            end
        end
    end
    return new
end

-- The hearthstone's place: where you stand when you bind it ("bound"), where you arrive after
-- using it ("arrived"), or roughly, while you are in the town it is bound to ("zone").
function Travel.LearnHearthHere(how)
    local bind = Str(Call(GetBindLocation))
    local pos = ns.Places.PlayerPos()
    if not (bind and pos) then return false end
    local old = ns.cdb.hearth
    if how == "zone" and old and old.name == bind then return false end
    ns.cdb.hearth = { name = bind, continent = pos.continent, x = pos.x, y = pos.y, map = pos.map,
        zone = pos.zone, approx = how == "zone" or nil }
    ns.Refresh()
    return true
end

local hearthing                -- when the hearthstone was last used, until you arrive
function Travel.OnSpellCast(spellID)
    spellID = Num(spellID)
    if spellID ~= Travel.HEARTH_SPELL then return end
    hearthing = ns.Now()
    ns.After(8, function()
        if hearthing then
            hearthing = nil
            Travel.LearnHearthHere("arrived")
        end
    end)
end

function Travel.OnArrived()
    if hearthing and ns.Now() - hearthing < 120 then
        ns.After(1, function()
            if hearthing then
                hearthing = nil
                Travel.LearnHearthHere("arrived")
            end
        end)
    end
end

function Travel.OnZoneText()
    local bind = Str(Call(GetBindLocation))
    if not bind then return end
    local old = ns.cdb.hearth
    if old and old.name == bind then return end
    if Str(Call(GetSubZoneText)) == bind or Str(Call(GetMinimapZoneText)) == bind or Str(Call(GetRealZoneText)) == bind then
        Travel.LearnHearthHere("zone")
    end
end

-- Your mount's speed, kept once seen.
function Travel.LearnSpeed()
    if not ns.cdb or ns.Call(IsMounted) ~= true then return end
    local _, run = Call(GetUnitSpeed, "player")
    run = Num(run)
    if run and run > Travel.WALK + 0.5 then ns.cdb.mountSpeed = run end
end

----------------------------------------------------------------------
-- What the plan may use now
----------------------------------------------------------------------
local function Cooldown()
    local fn = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if type(fn) ~= "function" then return 0 end
    local start, duration = Call(fn, Travel.HEARTHSTONE)
    start, duration = Num(start), Num(duration)
    if not (start and duration) or start <= 0 or duration <= 1.5 then return 0 end
    return max(0, start + duration - ns.Now())
end

local function HaveHearthstone()
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(fn) ~= "function" then return true end
    local count = Num(Call(fn, Travel.HEARTHSTONE))
    return count == nil or count > 0
end

function Travel.Hearth(use)
    local bind = Str(Call(GetBindLocation))
    local h = { name = bind, use = use ~= false, have = HaveHearthstone(), remaining = Cooldown() }
    local spot = ns.cdb and ns.cdb.hearth
    if bind and type(spot) == "table" and spot.name == bind and Num(spot.x) and Num(spot.y) and Num(spot.continent) then
        h.pos = { continent = spot.continent, x = spot.x, y = spot.y, zone = spot.zone }
        h.approx = spot.approx
    end
    h.usable = h.use and h.have and bind ~= nil and h.pos ~= nil and h.remaining < 3600
    return h
end

function Travel.HearthText(h)
    if not h then return "unknown" end
    if not h.use then return "not used (turned off)" end
    if not h.have then return "no Hearthstone in your bags" end
    if not h.name then return "not bound anywhere the game says" end
    if not h.pos then return h.name .. " (learned the next time you hearth there or pass through)" end
    if h.remaining > 0 then return ("%s, ready in %s"):format(h.name, ns.Duration(h.remaining)) end
    return h.name .. ", ready"
end

local function Docks(faction)
    local docks = {}
    for _, t in ipairs(Travel.TRANSPORTS) do
        if not t.faction or not faction or t.faction == faction then
            local a = ns.Places.WorldPos(t.a[1], t.a[2], t.a[3])
            local b = ns.Places.WorldPos(t.b[1], t.b[2], t.b[3])
            if a and b then
                local da = { kind = "dock", name = t.a[4], continent = a.continent, x = a.x, y = a.y, ride = t.kind }
                local db = { kind = "dock", name = t.b[4], continent = b.continent, x = b.x, y = b.y, ride = t.kind }
                da.partner, db.partner, da.time, db.time = db, da, t.time, t.time
                docks[#docks + 1] = da
                docks[#docks + 1] = db
            end
        end
    end
    return docks
end

-- Everything the planner may use, from the settings `db` ({ useHearth, useFlights, useBoats }).
function Travel.Context(db)
    db = db or {}
    local ctx = { speed = Travel.WALK, mounted = false, flights = {}, docks = {} }
    local mount = ns.cdb and Num(ns.cdb.mountSpeed)
    if mount and mount > Travel.WALK then ctx.speed, ctx.mounted = mount, true end
    ctx.useFlights, ctx.useBoats = db.useFlights ~= false, db.useBoats ~= false
    ctx.towns = {}                 -- every known flight path, used or not: they name the places
    for _, node in pairs(ns.cdb and ns.cdb.flights or {}) do
        if type(node) == "table" and Str(node.name) and Num(node.x) and Num(node.y) and Num(node.continent) then
            ctx.towns[#ctx.towns + 1] = { kind = "flight", name = Travel.ShortName(node.name),
                continent = node.continent, x = node.x, y = node.y }
        end
    end
    table.sort(ctx.towns, function(a, b) return a.name < b.name end)
    ctx.flightCount = #ctx.towns
    if ctx.useFlights then
        for i, town in ipairs(ctx.towns) do
            ctx.flights[i] = { kind = "flight", name = town.name, continent = town.continent, x = town.x, y = town.y }
        end
    end
    if ctx.useBoats then ctx.docks = Docks(Str(Call(UnitFactionGroup, "player"))) end
    ctx.hearth = Travel.Hearth(db.useHearth)
    return ctx
end

----------------------------------------------------------------------
-- The travel graph: points the plan cares about, the flight nodes and the docks.
-- Walking joins any two points on one continent; flights join flight nodes;
-- each dock joins its partner across the water.
----------------------------------------------------------------------
function Travel.Graph(ctx)
    local graph = { nodes = {}, ctx = ctx }
    for _, f in ipairs(ctx.flights) do Travel.Add(graph, f) end
    for _, d in ipairs(ctx.docks) do Travel.Add(graph, d) end
    for _, d in ipairs(ctx.docks) do d.link = d.partner.index end
    return graph
end

function Travel.Add(graph, node)
    graph.nodes[#graph.nodes + 1] = node
    node.index = #graph.nodes
    return node.index
end

-- Shortest times from node `src` to every node: { dist, prev, mode } (O(n^2), n is small).
function Travel.Shortest(graph, src)
    local nodes, speed = graph.nodes, graph.ctx.speed
    local n = #nodes
    local dist, prev, mode, done = {}, {}, {}, {}
    for i = 1, n do dist[i] = huge end
    dist[src] = 0
    local flySpeed = Travel.FLIGHT_SPEED / Travel.FLIGHT_DETOUR
    for _ = 1, n do
        local u, best = nil, huge
        for i = 1, n do
            if not done[i] and dist[i] < best then u, best = i, dist[i] end
        end
        if not u then break end
        done[u] = true
        local a = nodes[u]
        for v = 1, n do
            if not done[v] then
                local b = nodes[v]
                if a.continent == b.continent then
                    local d = Dist(a, b)
                    local w, m = d / speed, "walk"
                    if a.kind == "flight" and b.kind == "flight" then
                        local f = d / flySpeed + Travel.FLIGHT_EXTRA
                        if f < w then w, m = f, "fly" end
                    end
                    if best + w < dist[v] then dist[v], prev[v], mode[v] = best + w, u, m end
                end
            end
        end
        local v = a.link
        if v and not done[v] and best + a.time < dist[v] then
            dist[v], prev[v], mode[v] = best + a.time, u, a.ride
        end
    end
    return { dist = dist, prev = prev, mode = mode, src = src }
end

-- The steps from the tree's source to `dst`: { { from = node, to = node, mode } ... }
function Travel.Path(graph, tree, dst)
    local steps, v = {}, dst
    while v and v ~= tree.src and tree.prev[v] do
        table.insert(steps, 1, { from = graph.nodes[tree.prev[v]], to = graph.nodes[v], mode = tree.mode[v] })
        v = tree.prev[v]
    end
    return steps
end
