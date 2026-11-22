--[[
    Runback
    How far the nearest graveyard is from where you stand, and how long the run back
    from it takes: for you, and for an enemy player who dies here. When you or your
    group kill a player, when a group member dies and releases, and when you release
    yourself, a timer bar counts down to the moment they can be back on their feet.

    Where the numbers come from:
      * graveyards: Data.lua (built from the game's map tables and the classic graveyard
        list), corrected by where you really land when you release (RunbackDB.learned);
      * the run: straight line from the graveyard to the body, less the 39 yards from
        which a corpse can be taken, plus an allowance for the path, at ghost speed
        (measured on your own ghost; Night Elf wisps are faster);
      * enemy kills: the addon cannot read the combat log on this client, so it watches
        the enemy players it can see (target, focus, mouseover, nameplates, your group's
        targets) and the honor line in chat.

    /runback            -> status and the commands
    /runback config     -> options window
    /runback test       -> three test timers
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cffd9c79aRunback|r: "

local DEFAULTS = {
    enabled   = true,
    readout   = "always",   -- the graveyard readout: "always" | "pvp" (flagged for PvP, or dead) | "never"
    enemy     = true,       -- timers for enemy players who die near you
    group     = true,       -- timers for group members who release
    own       = true,       -- a timer for your own run back
    allowance = 15,         -- percent added to the straight line for the path
    sound     = true,       -- a sound when an enemy can be back
    chat      = true,       -- chat lines for enemy kills
    locked    = false,
}
local CHOICES = { readout = { always = true, pvp = true, never = true } }
local ALLOW_MIN, ALLOW_MAX = 0, 60
ns.ALLOW_MIN, ns.ALLOW_MAX = ALLOW_MIN, ALLOW_MAX

local RUN_SPEED    = 7          -- yards a second on foot
local GHOST_FACTOR = 1.25       -- a ghost runs a quarter faster
local WISP_FACTOR  = 1.5        -- a Night Elf's wisp half faster
local RECLAIM      = 39         -- yards from the corpse at which it can be taken
local SAME_YARD    = 80         -- two graveyard positions closer than this are the same one
local SEEN_FOR     = 20         -- an enemy must have been seen alive this many seconds before the body
local DONE_FOR     = 15         -- a finished timer stays this long
local UNKNOWN_FOR  = 20         -- a timer with no graveyard to count from stays this long
local AUTO_RELEASE = 360        -- the game releases a body by itself after six minutes
local STREAK_FOR   = 300        -- a second death within this many seconds makes the corpse wait
local CORPSE_WAIT  = { 0, 30, 60, 120 }   -- seconds before the corpse can be taken, by deaths in a row

local db
local timers = {}               -- the bars, oldest first
ns.timers = timers
local me = {}                   -- my own death: place, diedAt, ghostTicks, learned
local members = {}              -- group member key -> { place, diedAt }
local seenAlive = {}            -- enemy key -> when last seen alive
local streaks = {}              -- enemy key -> { n, at }
local myFaction, myRace, myKey

local floor, max, min, sqrt = math.floor, math.max, math.min, math.sqrt

local function Print(msg) print(PREFIX .. tostring(msg)) end
ns.Print = Print

---------------------------------------------------------------------------
-- Secret values: in fights this client hides some unit data from addons, and
-- comparing a hidden value throws. Everything read from the game goes through
-- Try(), which turns "hidden" and "the call failed" into nil.
---------------------------------------------------------------------------
local issecret = issecretvalue
local function Known(v)
    if issecret and issecret(v) then return nil end
    return v
end

local function Try(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return Known(a), Known(b), Known(c), Known(d)
end

local function Clock(seconds)
    seconds = max(0, floor(seconds + 0.5))
    return floor(seconds / 60) .. ":" .. string.format("%02d", seconds % 60)
end
ns.Clock = Clock

local function Yards(d) return floor(d + 0.5) .. " yd" end

---------------------------------------------------------------------------
-- Names. On this client UnitName gives the first name and the surname apart
-- ("Bunglfart", "Dunglode"); chat lines carry "Bunglfart Dunglode".
---------------------------------------------------------------------------
local function UnitKey(unit)
    local first, second = Try(UnitName, unit)
    if type(first) ~= "string" or first == "" or first == UNKNOWNOBJECT then return nil end
    if type(second) ~= "string" or second == "" then return first end
    return first .. " " .. second
end

local function FirstWord(text) return text:match("^(%S+)") or text end

---------------------------------------------------------------------------
-- Places: { inst = continent or instance id, x, y (world yards), zone }.
-- zone is the area id the graveyard list knows, "m<map>" for a zone it does
-- not know, nil when the game does not say.
---------------------------------------------------------------------------
local ZONE = (Enum and Enum.UIMapType and Enum.UIMapType.Zone) or 3

local function Position(unit)
    local x, y, _, inst = Try(UnitPosition, unit)
    if type(x) ~= "number" or type(y) ~= "number" or type(inst) ~= "number" then return nil end
    if x ~= x or y ~= y or (x == 0 and y == 0) then return nil end
    return inst, x, y
end

local function ZoneOf(unit)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return nil end
    local map = Try(C_Map.GetBestMapForUnit, unit)
    for _ = 1, 6 do
        if type(map) ~= "number" then return nil end
        local area = ns.Data.areas[map]
        if area then return area end
        local info = Try(C_Map.GetMapInfo, map)
        if type(info) ~= "table" then return nil end
        if info.mapType == ZONE then return "m" .. map end
        map = info.parentMapID
        if map == 0 then return nil end
    end
end

local function InstanceID()
    if not GetInstanceInfo then return nil end
    local ok, _, kind, _, _, _, _, _, id = pcall(GetInstanceInfo)
    if not ok then return nil end
    kind, id = Known(kind), Known(id)
    if type(kind) == "string" and kind ~= "none" and type(id) == "number" then return id, kind end
end

-- Where a unit is. Inside a dungeon or raid the game gives no position; a body in there is
-- put at the way in, so that is the place (entrance = the dungeon's name).
local function PlaceOf(unit)
    local inst, x, y = Position(unit)
    if inst then return { inst = inst, x = x, y = y, zone = ZoneOf(unit) } end
    local id = InstanceID()
    local e = id and ns.Data.entrances[id]
    if e then return { inst = e[1], x = e[2], y = e[3], entrance = e[4] } end
end
ns.PlaceOf = PlaceOf

local function Distance(a, b)
    if a.inst ~= b.inst then return nil end
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx * dx + dy * dy)
end

-- Your own corpse as the game reports it once you have released.
local function CorpsePlace()
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map and C_Map.GetBestMapForUnit
        and C_Map.GetWorldPosFromMapPos) then return nil end
    local map = Try(C_Map.GetBestMapForUnit, "player")
    for _ = 1, 6 do
        if type(map) ~= "number" then return nil end
        local pos = Try(C_DeathInfo.GetCorpseMapPosition, map)
        if type(pos) == "table" and pos.GetXY then
            local mx, my = pos:GetXY()
            mx, my = Known(mx), Known(my)
            if type(mx) == "number" and type(my) == "number" and mx >= 0 and mx <= 1 and my >= 0 and my <= 1
                and not (mx == 0 and my == 0) then
                local inst, world = Try(C_Map.GetWorldPosFromMapPos, map, pos)
                if type(inst) == "number" and type(world) == "table" and world.GetXY then
                    local x, y = world:GetXY()
                    x, y = Known(x), Known(y)
                    if type(x) == "number" and type(y) == "number" then return { inst = inst, x = x, y = y } end
                end
                return nil
            end
        end
        local info = Try(C_Map.GetMapInfo, map)
        map = type(info) == "table" and info.parentMapID or nil
        if map == 0 then map = nil end
    end
end

---------------------------------------------------------------------------
-- Graveyards
---------------------------------------------------------------------------
local usableBy                  -- graveyard id -> { A = true, H = true }

local function Usable(id, faction)
    if not usableBy then
        usableBy = {}
        for _, list in pairs(ns.Data.links) do
            for _, link in ipairs(list) do
                local u = usableBy[link[1]] or {}
                usableBy[link[1]] = u
                if link[2] == "" then u.A, u.H = true, true else u[link[2]] = true end
            end
        end
    end
    return usableBy[id] and usableBy[id][faction] or false
end

local function LearnedKey(zone, faction) return tostring(zone or "?") .. ":" .. faction end

-- The graveyard a body at `place` is sent to: { name, inst, x, y, dist, id or learned }.
-- The game takes the nearest of the graveyards tied to the zone for that faction. A zone the
-- list does not know (or a dungeon's way in) falls back to the nearest usable one anywhere.
local function Nearest(place, faction)
    if not (place and faction and db) then return nil end
    local best
    local function Offer(name, inst, x, y, id, learned)
        if inst ~= place.inst then return end
        local dx, dy = x - place.x, y - place.y
        local d = sqrt(dx * dx + dy * dy)
        if not best or d < best.dist then
            best = { name = name, inst = inst, x = x, y = y, dist = d, id = id, learned = learned }
        end
    end
    local found = false
    local learned = db.learned[LearnedKey(place.zone, faction)]
    if learned then
        for _, g in ipairs(learned) do
            found = true
            Offer(g.name, g.inst, g.x, g.y, nil, true)
        end
    end
    local links = type(place.zone) == "number" and ns.Data.links[place.zone]
    if links then
        for _, link in ipairs(links) do
            local yard = ns.Data.yards[link[1]]
            if yard and (link[2] == "" or link[2] == faction) and not db.bad[link[1]] then
                found = true
                Offer(yard[4], yard[1], yard[2], yard[3], link[1])
            end
        end
    end
    if not found then
        for id, yard in pairs(ns.Data.yards) do
            if Usable(id, faction) and not db.bad[id] then Offer(yard[4], yard[1], yard[2], yard[3], id) end
        end
        for key, list in pairs(db.learned) do
            if key:sub(-2) == ":" .. faction then
                for _, g in ipairs(list) do Offer(g.name, g.inst, g.x, g.y, nil, true) end
            end
        end
    end
    return best
end
ns.Nearest = Nearest

-- Where I really landed after releasing: the list is corrected from it.
local function Learn(place, faction, inst, x, y)
    if not (place and faction and inst) then return end
    local landing = { inst = inst, x = x, y = y }
    local guess = Nearest(place, faction)
    if guess and (Distance(guess, landing) or 1e9) < SAME_YARD then return end
    local key = LearnedKey(place.zone, faction)
    local list = db.learned[key] or {}
    for _, g in ipairs(list) do
        if (Distance(g, landing) or 1e9) < SAME_YARD then return end
    end
    local name = Try(GetMinimapZoneText)
    if type(name) ~= "string" or name == "" then name = Try(GetZoneText) end
    if type(name) ~= "string" or name == "" then name = "Graveyard" end
    list[#list + 1] = { inst = inst, x = floor(x * 10 + 0.5) / 10, y = floor(y * 10 + 0.5) / 10, name = name }
    db.learned[key] = list
    -- The listed graveyard was nearer to the body and the game still did not use it: it is
    -- not there on this server.
    local landed = Distance(place, landing)
    if guess and guess.id and landed and guess.dist < landed - 30 then db.bad[guess.id] = true end
end
ns.Learn = Learn

---------------------------------------------------------------------------
-- The run
---------------------------------------------------------------------------
local function GhostSpeed(race)
    if race == "NightElf" then return db.wispSpeed or RUN_SPEED * WISP_FACTOR end
    return db.ghostSpeed or RUN_SPEED * GHOST_FACTOR
end

local function RunSeconds(dist, race)
    return max(0, dist - RECLAIM) * (1 + db.allowance / 100) / GhostSpeed(race)
end
ns.RunSeconds = RunSeconds

local function Other(faction) return faction == "A" and "H" or "A" end

local function Identity()
    local group = Try(UnitFactionGroup, "player")
    if group == "Alliance" then myFaction = "A" elseif group == "Horde" then myFaction = "H" end
    local _, race = Try(UnitRace, "player")
    if type(race) == "string" then myRace = race end
    myKey = UnitKey("player") or myKey
end

local function InPvP()
    local _, kind = InstanceID()
    return kind == "pvp" or kind == "arena"
end

function ns.Active()
    return (db and db.enabled and myFaction and not InPvP()) and true or false
end

-- The readout: what a death where you stand would cost. Returns nil when there is nothing
-- to say, otherwise { place, mine = { yard, secs }, theirs = { yard, secs } or nil }.
function ns.Survey()
    if not ns.Active() then return nil end
    local place = PlaceOf("player")
    if not place then return { } end
    local out = { place = place }
    local yard = Nearest(place, myFaction)
    if yard then out.mine = { yard = yard, secs = RunSeconds(yard.dist, myRace) } end
    local theirs = Nearest(place, Other(myFaction))
    if theirs then out.theirs = { yard = theirs, secs = RunSeconds(theirs.dist, nil) } end
    return out
end

---------------------------------------------------------------------------
-- Timers
---------------------------------------------------------------------------
local function Changed()
    if ns.UI then ns.UI.Refresh() end
end

local function Find(name)
    if type(name) ~= "string" then return nil end
    for i, t in ipairs(timers) do
        if t.key == name then return t, i end
    end
    local first = FirstWord(name)
    for i, t in ipairs(timers) do
        if t.kind == "enemy" and (FirstWord(t.key) == name or t.key == first) then return t, i end
    end
end

local function Remove(t)
    for i, other in ipairs(timers) do
        if other == t then
            table.remove(timers, i)
            Changed()
            return
        end
    end
end

local function Add(t)
    local yard = t.place and Nearest(t.place, t.faction)
    if yard then
        t.yard = yard
        t.run = RunSeconds(yard.dist, t.race)
    end
    timers[#timers + 1] = t
    Changed()
    return t
end

local function CorpseWait(key, now)
    local s = streaks[key]
    if s and now - s.at < STREAK_FOR then s.n = min(#CORPSE_WAIT, s.n + 1) else s = { n = 1 } end
    s.at = now
    streaks[key] = s
    return CORPSE_WAIT[s.n]
end

local function NewEnemy(key, now, info)
    if not db.enemy then return end
    local place = PlaceOf("player")
    local t = Add({
        key = key, name = key, kind = "enemy", class = info and info.class, race = info and info.race,
        faction = (info and info.faction) or Other(myFaction), place = place,
        diedAt = now, wait = CorpseWait(key, now),
        seenBody = info and info.body or false, bodyAt = now, token = info and info.token,
    })
    if db.chat then
        if t.run then
            Print(key .. " died. Back in about " .. Clock(max(t.run, t.wait)) .. " after releasing ("
                .. t.yard.name .. ", " .. Yards(t.yard.dist) .. ").")
        else
            Print(key .. " died. No graveyard is known for this place yet.")
        end
    end
    return t
end

-- When a timer runs out: nil while the body has not been released.
local function BackAt(t)
    if not t.run then return nil end
    if t.live then return t.live end
    local start = t.releasedAt
    if not start and not t.seenBody then start = t.diedAt end      -- never saw the body: the earliest
    if not start then return nil end
    return max(start + t.run, t.diedAt + (t.wait or 0))
end

-- What a bar shows: text, the filled part (0 to 1), and the lines of its tooltip.
function ns.BarInfo(t, now)
    local back = t.backAt
    local text, value
    if t.doneAt then
        text, value = t.name .. ": " .. (t.kind == "enemy" and "can be back" or "at the body"), 0
    elseif not t.run then
        text, value = t.name .. ": no graveyard known", 1
    elseif not back then
        text, value = t.name .. ": not released", 1
    else
        local left = max(0, back - now)
        text = t.name .. "  " .. Clock(left)
        value = (t.total and t.total > 0) and min(1, left / t.total) or 0
    end
    local tip = {}
    if t.yard then
        tip[#tip + 1] = "From " .. t.yard.name .. ", " .. Yards(t.yard.dist) .. " away."
        tip[#tip + 1] = "The run takes about " .. Clock(t.run) .. "."
    else
        tip[#tip + 1] = "No graveyard is known for this place yet. It is learned the first time you release here."
    end
    if t.place and t.place.entrance then tip[#tip + 1] = "Counted to the way in of " .. t.place.entrance .. "." end
    if t.kind == "enemy" then
        if (t.wait or 0) > 0 then
            tip[#tip + 1] = "Killed again so soon, their corpse makes them wait " .. t.wait .. " sec."
        end
        if not t.run then
            -- nothing to add
        elseif not back then
            tip[#tip + 1] = "The body is still here. The timer starts when they release."
        elseif t.sure then
            tip[#tip + 1] = "Counted from the moment their body left your target."
        elseif t.seenBody then
            tip[#tip + 1] = "Counted from when the body was last seen. They may have released later."
        else
            tip[#tip + 1] = "Counted from the kill. They may have released later."
        end
    end
    return text, value, tip
end

---------------------------------------------------------------------------
-- Enemy players: seen alive, then seen dead
---------------------------------------------------------------------------
local TOKENS = { "target", "focus", "mouseover" }
for i = 1, 40 do TOKENS[#TOKENS + 1] = "nameplate" .. i end
local PARTY, RAID = {}, {}
for i = 1, 4 do PARTY[i] = "party" .. i .. "target" end
for i = 1, 40 do RAID[i] = "raid" .. i .. "target" end

local present = {}

local function LookAt(unit, now)
    if not Try(UnitExists, unit) then return end
    if not Try(UnitIsPlayer, unit) then return end
    if not Try(UnitCanAttack, "player", unit) then return end
    local key = UnitKey(unit)
    if not key then return end
    local dead = Try(UnitIsDeadOrGhost, unit)
    if dead == false then
        present[key] = "alive"
        seenAlive[key] = now
    elseif dead == true and present[key] ~= "alive" then
        local p = present[key]
        if type(p) ~= "table" then
            p = {}
            present[key] = p
            local _, class = Try(UnitClass, unit)
            local _, race = Try(UnitRace, unit)
            local group = Try(UnitFactionGroup, unit)
            p.class = type(class) == "string" and class or nil
            p.race = type(race) == "string" and race or nil
            p.faction = (group == "Alliance" and "A") or (group == "Horde" and "H") or nil
            p.body = true
        end
        -- a body on my target or focus tells me the release: the game clears it then
        if unit == "target" or unit == "focus" then p.token = unit end
    end
end

local function ScanEnemies(now)
    for key in pairs(present) do present[key] = nil end
    for _, unit in ipairs(TOKENS) do LookAt(unit, now) end
    if IsInRaid and IsInRaid() then
        for _, unit in ipairs(RAID) do LookAt(unit, now) end
    elseif IsInGroup and IsInGroup() then
        for _, unit in ipairs(PARTY) do LookAt(unit, now) end
    end

    for key, state in pairs(present) do
        local t = Find(key)
        if t and t.kind ~= "enemy" then t = nil end
        if state == "alive" then
            if t and now - t.diedAt > 1 then Remove(t) end           -- back on their feet
        elseif t then
            -- the body is (still, or again) here
            t.seenBody, t.bodyAt, t.releasedAt, t.token, t.sure = true, now, nil, state.token, nil
            t.class, t.race = t.class or state.class, t.race or state.race
        elseif seenAlive[key] and now - seenAlive[key] < SEEN_FOR then
            seenAlive[key] = nil
            NewEnemy(key, now, state)
        end
    end

    for _, t in ipairs(timers) do
        if t.kind == "enemy" and t.seenBody and not t.releasedAt and not present[t.key] then
            -- The body is no longer on anything I can read. Gone from my target or focus
            -- with nothing in its place: they released just now. Otherwise I looked away.
            t.releasedAt = t.bodyAt
            if t.token and not Try(UnitExists, t.token) then
                t.sure, t.releasedAt = true, now
                if db.chat and t.run then
                    Print(t.name .. " released. Back in about " .. Clock(max(0, BackAt(t) - now)) .. ".")
                end
            end
        end
    end
    for key, at in pairs(seenAlive) do
        if now - at > 120 then seenAlive[key] = nil end
    end
end

-- "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)" as a pattern.
local honorPattern
local function HonorName(text)
    if type(text) ~= "string" then return nil end
    if honorPattern == nil then
        honorPattern = false
        local fmt = COMBATLOG_HONORGAIN
        if type(fmt) == "string" and fmt:find("%%s") then
            local p = fmt:gsub("[%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
            p = p:gsub("%%s", "(.-)", 1):gsub("%%[sd]", ".-")
            honorPattern = "^" .. p
        end
    end
    local name = honorPattern and text:match(honorPattern) or text:match("^(.-) dies, honorable kill")
    if name and name ~= "" then return name end
end
ns.HonorName = HonorName

local function OnHonor(text)
    if not (ns.Active() and db.enemy) then return end
    local name = HonorName(Known(text))
    if not name then return end
    local now = GetTime()
    if Find(name) then return end
    seenAlive[name] = nil
    NewEnemy(name, now, nil)
end

---------------------------------------------------------------------------
-- Group members
---------------------------------------------------------------------------
local function ScanMember(unit, now, seen)
    local key = UnitKey(unit)
    if not key or key == myKey then return end
    seen[key] = true
    local dead = Try(UnitIsDeadOrGhost, unit)
    if dead == nil then return end
    local t = Find(key)
    if t and t.kind ~= "group" then t = nil end
    if not dead then
        members[key] = nil
        if t then Remove(t) end
        return
    end
    if Try(UnitIsFeignDeath, unit) then return end
    local ghost = Try(UnitIsGhost, unit)
    if ghost == nil then return end
    local m = members[key]
    if not ghost then
        if not m then members[key] = { place = PlaceOf(unit) or PlaceOf("player"), diedAt = now } end
        return
    end
    if not (m and m.place) then return end                   -- never saw where they died
    if not t then
        local _, class = Try(UnitClass, unit)
        local _, race = Try(UnitRace, unit)
        t = Add({
            key = key, name = key, kind = "group", faction = myFaction, place = m.place,
            class = type(class) == "string" and class or nil, race = type(race) == "string" and race or nil,
            diedAt = m.diedAt, releasedAt = now, seenBody = true,
        })
    end
    -- Their ghost shows on the map: count from where it really is.
    local inst, x, y = Position(unit)
    if inst and t.run and not t.doneAt then
        local d = Distance({ inst = inst, x = x, y = y }, m.place)
        if d then t.live = now + RunSeconds(d, t.race) end
    end
end

local function ScanGroup(now)
    local seen = {}
    if db.group and IsInGroup and IsInGroup() then
        if IsInRaid and IsInRaid() then
            for i = 1, 40 do
                if Try(UnitExists, "raid" .. i) then ScanMember("raid" .. i, now, seen) end
            end
        else
            for i = 1, 4 do
                if Try(UnitExists, "party" .. i) then ScanMember("party" .. i, now, seen) end
            end
        end
    end
    for key in pairs(members) do
        if not seen[key] then members[key] = nil end
    end
    for i = #timers, 1, -1 do
        if timers[i].kind == "group" and not seen[timers[i].key] then
            table.remove(timers, i)
            Changed()
        end
    end
end

---------------------------------------------------------------------------
-- Yourself
---------------------------------------------------------------------------
local function ScanSelf(now)
    local dead = Try(UnitIsDeadOrGhost, "player")
    if dead == nil then return end
    local t = Find("\1me")
    if not dead or Try(UnitIsFeignDeath, "player") then
        if me.diedAt then me = {} end
        if t then Remove(t) end
        return
    end
    local ghost = Try(UnitIsGhost, "player")
    if ghost == nil then return end
    if not me.diedAt then
        me.diedAt = now
        if not ghost then me.place = PlaceOf("player") end   -- logged in as a ghost: the corpse is asked for below
    end
    if not ghost then return end

    me.ghostTicks = (me.ghostTicks or 0) + 1
    local inst, x, y = Position("player")
    -- A moment after the release I stand at the graveyard the game chose.
    if me.ghostTicks == 4 and me.place and not me.learned and inst then
        me.learned = true
        Learn(me.place, myFaction, inst, x, y)
    end
    local speed = Try(GetUnitSpeed, "player")
    if type(speed) == "number" and speed > RUN_SPEED * 1.1 and speed < RUN_SPEED * 2.2 then
        local field = myRace == "NightElf" and "wispSpeed" or "ghostSpeed"
        if not db[field] or speed > db[field] then db[field] = floor(speed * 100 + 0.5) / 100 end
    end

    local corpse = CorpsePlace() or me.place
    if not (db.own and corpse) then
        if t then Remove(t) end
        return
    end
    if not t then
        t = Add({
            key = "\1me", name = "You", kind = "self", faction = myFaction, race = myRace,
            place = me.place or corpse, diedAt = me.diedAt, releasedAt = now, seenBody = true,
        })
    end
    if inst then
        local d = Distance({ inst = inst, x = x, y = y }, corpse)
        if d then
            local wait = Try(GetCorpseRecoveryDelay)
            if type(wait) ~= "number" then wait = 0 end
            t.run = t.run or RunSeconds(d, myRace)       -- no graveyard known: the distance itself is
            t.live = now + max(RunSeconds(d, myRace), wait)
        end
    end
end

---------------------------------------------------------------------------
-- Four times a second
---------------------------------------------------------------------------
local wasActive

local function Alert(t)
    if t.kind ~= "enemy" then return end
    if db.chat then Print(t.name .. " can be back now.") end
    if db.sound and PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
end

local function Tick()
    if not db then return end
    if not myFaction then Identity() end
    local active = ns.Active()
    if not active then
        if wasActive ~= false then
            wasActive = false
            for i = #timers, 1, -1 do
                if timers[i].kind ~= "test" then table.remove(timers, i) end
            end
            Changed()
        end
        if #timers == 0 then
            if ns.UI then ns.UI.Update(GetTime()) end
            return
        end
    else
        wasActive = true
    end
    local now = GetTime()
    if active then
        ScanSelf(now)
        ScanGroup(now)
        if db.enemy then ScanEnemies(now) end
    end

    for i = #timers, 1, -1 do
        local t = timers[i]
        if t.kind == "enemy" and t.seenBody and not t.releasedAt and now - t.diedAt > AUTO_RELEASE then
            t.releasedAt = t.diedAt + AUTO_RELEASE
        end
        local back = BackAt(t)
        t.backAt = back
        if back and not t.total then t.total = max(1, back - now) end
        if back and back - now > (t.total or 0) then t.total = back - now end
        if back and now >= back and not t.doneAt then
            t.doneAt = now
            Alert(t)
        elseif t.doneAt and back and now < back - 1 then
            t.doneAt = nil                                      -- a ghost that turned round
        end
        local gone = false
        if t.kind == "enemy" or t.kind == "test" then
            gone = (t.doneAt and now - t.doneAt > DONE_FOR) or (not t.run and now - t.diedAt > UNKNOWN_FOR)
        end
        if gone then
            table.remove(timers, i)
            Changed()
        end
    end
    if ns.UI then ns.UI.Update(now) end
end
ns.Tick = Tick

---------------------------------------------------------------------------
-- Test timers
---------------------------------------------------------------------------
function ns.Testing()
    for _, t in ipairs(timers) do
        if t.kind == "test" then return true end
    end
    return false
end

function ns.SetTesting(on)
    for i = #timers, 1, -1 do
        if timers[i].kind == "test" then table.remove(timers, i) end
    end
    if on then
        local now = GetTime()
        local yard = { name = "Test graveyard", dist = 420 }
        timers[#timers + 1] = { key = "\1t1", name = "Stonewall", kind = "test", class = "WARRIOR", yard = yard,
            run = 44, diedAt = now, releasedAt = now, seenBody = true, sure = true }
        timers[#timers + 1] = { key = "\1t2", name = "Moonwhisper", kind = "test", class = "PRIEST", yard = yard,
            run = 29, diedAt = now - 6, wait = 30 }
        timers[#timers + 1] = { key = "\1t3", name = "Emberhand", kind = "test", class = "MAGE", yard = yard,
            run = 44, diedAt = now, seenBody = true }
    end
    Changed()
    Tick()
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
local function InitDB()
    if type(RunbackDB) ~= "table" then RunbackDB = {} end
    db = RunbackDB
    for key, value in pairs(DEFAULTS) do
        if type(db[key]) ~= type(value) then db[key] = value end
    end
    for key, allowed in pairs(CHOICES) do
        if not allowed[db[key]] then db[key] = DEFAULTS[key] end
    end
    db.allowance = floor(max(ALLOW_MIN, min(ALLOW_MAX, db.allowance)) + 0.5)
    if type(db.learned) ~= "table" then db.learned = {} end
    if type(db.bad) ~= "table" then db.bad = {} end
    for key, list in pairs(db.learned) do
        local keep = {}
        if type(key) == "string" and type(list) == "table" then
            for _, g in ipairs(list) do
                if type(g) == "table" and type(g.inst) == "number" and type(g.x) == "number"
                    and type(g.y) == "number" and type(g.name) == "string" then
                    keep[#keep + 1] = g
                end
            end
        end
        db.learned[key] = #keep > 0 and keep or nil
    end
    for _, field in ipairs({ "ghostSpeed", "wispSpeed" }) do
        if type(db[field]) ~= "number" or db[field] < RUN_SPEED or db[field] > RUN_SPEED * 2.2 then db[field] = nil end
    end
    ns.db = db
end

function ns.Set(key, value)
    if not db or DEFAULTS[key] == nil then return end
    if key == "allowance" then
        value = floor(max(ALLOW_MIN, min(ALLOW_MAX, tonumber(value) or DEFAULTS.allowance)) + 0.5)
    end
    db[key] = value
    if key == "allowance" then
        for _, t in ipairs(timers) do
            if t.yard and t.kind ~= "test" then t.run = RunSeconds(t.yard.dist, t.race) end
        end
    end
    Changed()
end

function ns.Reset()
    for key, value in pairs(DEFAULTS) do db[key] = value end
    db.minimap, db.pos = nil, nil
    if ns.Kit then ns.Kit.RefreshMinimap() end
    if ns.UI then ns.UI.Place() end
    Changed()
end

function ns.Forget()
    db.learned, db.bad, db.ghostSpeed, db.wispSpeed = {}, {}, nil, nil
    Changed()
end

function ns.LearnedCount()
    local n = 0
    for _, list in pairs(db.learned) do n = n + #list end
    return n
end

-- The readout in words, for chat and the minimap button's tooltip.
function ns.SurveyLines()
    local s = ns.Survey()
    if not s then return { db.enabled and "Not counting here (battleground or arena)." or "Runback is off." } end
    if not s.place then return { "The game gives no position here." } end
    local lines = {}
    local function Line(who, e)
        lines[#lines + 1] = who .. ": " .. e.yard.name .. ", " .. Yards(e.yard.dist) .. ", run back " .. Clock(e.secs) .. "."
    end
    if s.mine then Line("You", s.mine) else lines[#lines + 1] = "You: no graveyard known for this place yet." end
    if s.theirs then Line("Enemy players", s.theirs) else lines[#lines + 1] = "Enemy players: no graveyard known for this place yet." end
    if s.place.entrance then lines[#lines + 1] = "Counted to the way in of " .. s.place.entrance .. "." end
    return lines
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_DEAD")
f:RegisterEvent("PLAYER_ALIVE")
f:RegisterEvent("PLAYER_UNGHOST")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")

local ticker

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDB()
            if ns.Kit and ns.Options then
                local ok, err = pcall(ns.Options.Init)
                if not ok then Print("options error: " .. tostring(err)) end
            end
        end
        return
    end
    if not db then return end

    if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        local ok, err = pcall(OnHonor, arg1)
        if not ok then ns.lastError = err end

    elseif event == "PLAYER_ENTERING_WORLD" then
        Identity()
        if ns.UI then ns.UI.Init() end
        if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(0.25, Tick) end
        Tick()
        if not db.welcomed then
            db.welcomed = true
            Print("loaded. It shows the nearest graveyard and the run back from it, and counts down when a player "
                .. "you killed can be back. Drag the readout to move it; /runback lists the options.")
        end

    else
        Tick()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function PrintStatus()
    Print((db.enabled and "on" or "OFF")
        .. "  |  readout " .. db.readout
        .. "  |  enemy timers " .. OnOff(db.enemy)
        .. "  |  group timers " .. OnOff(db.group)
        .. "  |  own timer " .. OnOff(db.own)
        .. "  |  path allowance " .. db.allowance .. "%"
        .. "  |  sound " .. OnOff(db.sound)
        .. "  |  chat lines " .. OnOff(db.chat))
    for _, line in ipairs(ns.SurveyLines()) do print("  " .. line) end
end

local function PrintHelp()
    Print("commands:")
    print("  /runback config (options window)   -  /runback test (three test timers)   -  /runback on|off")
    print("  /runback readout always|pvp|never   -  /runback enemy   -  /runback group   -  /runback own")
    print("  /runback allowance <" .. ALLOW_MIN .. "-" .. ALLOW_MAX .. "> (percent added for the path)   -  /runback sound   -  /runback chat")
    print("  /runback lock   -  /runback move (back to the middle)   -  /runback forget (learned graveyards)")
    print("  /runback minimap   -  /runback reset   -  /runback debug")
end

local function HasKit()
    if ns.Kit and ns.Options then return true end
    Print("the options window and the minimap button appear after a /reload.")
    return false
end

local function SyncOptions()
    if ns.Kit then ns.Kit.Sync() end
end

SLASH_RUNBACK1 = "/runback"
SLASH_RUNBACK2 = "/rb"
SlashCmdList.RUNBACK = function(msg)
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
        Print("minimap button " .. OnOff(ns.Kit.MinimapShown()) .. ".")
        SyncOptions()
        return
    elseif cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
    elseif cmd == "enemy" or cmd == "group" or cmd == "own" or cmd == "sound" or cmd == "chat" then
        db[cmd] = not db[cmd]
    elseif cmd == "lock" or cmd == "unlock" then
        if cmd == "lock" then db.locked = not db.locked else db.locked = false end
        Print(db.locked and "the readout and the bars are locked in place." or "drag the readout or a bar to move them.")
    elseif cmd == "readout" then
        if not CHOICES.readout[arg] then Print("/runback readout always|pvp|never") return end
        db.readout = arg
    elseif cmd == "allowance" then
        local n = tonumber(arg)
        if not n then Print("/runback allowance <" .. ALLOW_MIN .. "-" .. ALLOW_MAX .. ">") return end
        ns.Set("allowance", n)
    elseif cmd == "move" then
        db.pos = nil
        if ns.UI then ns.UI.Place() end
        Print("back in the middle, under the breath bar.")
        return
    elseif cmd == "test" then
        local on = not ns.Testing()
        ns.SetTesting(on)
        Print(on and "three test timers. /runback test again removes them." or "test timers removed.")
        SyncOptions()
        return
    elseif cmd == "forget" then
        ns.Forget()
        Print("learned graveyards and the measured ghost speed forgotten.")
        return
    elseif cmd == "reset" then
        ns.Reset()
    elseif cmd == "debug" then
        local inst, x, y = Position("player")
        local shown = 0
        for _ in pairs(present) do shown = shown + 1 end
        Print("build " .. tostring((select(4, GetBuildInfo()))) .. ", active: " .. tostring(ns.Active())
            .. ", faction: " .. tostring(myFaction) .. ", race: " .. tostring(myRace)
            .. ", position: " .. (inst and (inst .. " " .. floor(x) .. " " .. floor(y)) or "none")
            .. ", zone: " .. tostring(ZoneOf("player"))
            .. ", ghost speed: " .. tostring(db.ghostSpeed or db.wispSpeed or "not measured")
            .. ", learned graveyards: " .. ns.LearnedCount()
            .. ", timers: " .. #timers .. ", enemy players in view: " .. shown)
        if ns.lastError then Print("last error: " .. tostring(ns.lastError)) end
        return
    else
        PrintHelp()
        return
    end

    Changed()
    PrintStatus()
    SyncOptions()
end
