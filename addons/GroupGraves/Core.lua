--[[
    Group Graves
    Marks where the members of your group died on the world map, and keeps
    the marker there after they release their spirit (the game moves their
    own dot to the graveyard, so nobody can see where the body is any more).

    Where the positions come from:
      * everyone with the addon tells the group where they died, and where
        the game says their corpse is once they have released;
      * for members without the addon, your own addon notes where their dot
        was while they lay dead, before they released;
      * someone who joins later asks the group and is told both kinds.

    /graves             -> current settings, the marked corpses, the commands
    /graves list        -> the marked corpses
    /graves early       -> mark from the moment of death, not only after the release
    /graves names       -> names under the markers
    /graves size <n>
    /graves chat off|party|always
    /graves pvp         -> also in battlegrounds and arenas
    /graves test        -> three test markers around you
    /graves clear, /graves on|off, /graves reset, /graves debug
    /graves config, /graves minimap
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cffd9c79aGroup Graves|r: "
local COMM   = "GroupGraves"       -- addon message prefix
local PROTO  = "1"                 -- first field of every message

local DEFAULTS = {
    enabled = true,
    early   = false,    -- false: a marker appears when the member releases
    size    = 22,
    names   = false,
    chat    = "party",  -- chat line when a member releases: "off" | "party" | "always"
    pvp     = false,    -- also in battlegrounds and arenas
}
local CHOICES = {
    chat = { off = true, party = true, always = true },
}
local SIZE_MIN, SIZE_MAX = 12, 40
ns.SIZE_MIN, ns.SIZE_MAX = SIZE_MIN, SIZE_MAX
ns.SIZE_DEFAULT = DEFAULTS.size                   -- the size at which a marker matches the game's corpse pin

local MAX_AGE       = 2 * 3600  -- a saved marker older than this is dropped at login
local MISSING_TICKS = 10        -- seconds a marker survives without its member in the group
local CORPSE_LOOKS  = 10        -- seconds to wait for the game to place a released corpse
local QUERY_EVERY   = 30        -- at most one "who is dead?" per this many seconds
local MOVED         = 0.0005    -- map fraction: less than this is the same spot

local TESTS = {
    { "Stonewall",   "WARRIOR", -0.030,  0.012 },
    { "Moonwhisper", "PRIEST",   0.022,  0.026 },
    { "Emberhand",   "MAGE",     0.006, -0.034 },
}

local db
local graves = {}                  -- key (name, or name-realm) -> grave
ns.graves = graves
local me = { state = "A" }         -- "A" alive, "D" dead (body), "G" released (ghost)
local myKey, myRealm, myClass = nil, "", nil

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local function Print(msg) print(PREFIX .. tostring(msg)) end
ns.Print = Print

---------------------------------------------------------------------------
-- Secret values: in fights this client hides some unit data from addons,
-- and comparing a hidden value throws. Everything read from the game goes
-- through Try(), which turns "hidden" and "the call failed" into nil.
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

---------------------------------------------------------------------------
-- Names. A marker is filed under the member's name, with the realm added
-- only for someone from another realm, however the game spelled it.
---------------------------------------------------------------------------
local function Squash(realm) return (realm:gsub("[%s%-']", "")) end

local function MakeKey(name, realm)
    if type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" then
        realm = Squash(realm)
        if realm ~= "" and realm ~= myRealm then return name .. "-" .. realm, name end
    end
    return name, name
end

local function UnitKey(unit)
    local name, realm = Try(UnitName, unit)
    if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
    return MakeKey(name, realm)
end

local function SenderKey(sender)
    if type(sender) ~= "string" then return nil end
    local name, realm = sender:match("^([^%-]+)%-(.+)$")
    return MakeKey(name or sender, realm)
end

local function Identity()
    local realm = Try(GetNormalizedRealmName) or Try(GetRealmName)
    myRealm = type(realm) == "string" and Squash(realm) or ""
    local name = Try(UnitName, "player")
    if type(name) == "string" and name ~= "" then myKey = name end
    local _, class = Try(UnitClass, "player")
    if type(class) == "string" then myClass = class end
end

---------------------------------------------------------------------------
-- Places
---------------------------------------------------------------------------
local function XY(pos)
    if type(pos) ~= "table" then return nil end
    local x, y
    if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    x, y = Known(x), Known(y)
    if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y then return nil end
    return x, y
end

local function OnTheMap(x, y)
    return x and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

-- Where a unit is: map, x, y. Nothing inside dungeons, where the game gives no positions.
local function UnitSpot(unit)
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local map = Try(C_Map.GetBestMapForUnit, unit)
    if type(map) ~= "number" then return nil end
    local x, y = XY(Try(C_Map.GetPlayerMapPosition, map, unit))
    if not OnTheMap(x, y) or (x == 0 and y == 0) then return nil end
    return map, x, y
end

local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2

local function MapInfo(map)
    if not (C_Map and C_Map.GetMapInfo) then return nil end
    local info = Try(C_Map.GetMapInfo, map)
    if type(info) == "table" then return info end
end

local function ToWorld(map, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local continent, pos = Try(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if type(continent) ~= "number" then return nil end
    local wx, wy = XY(pos)
    if not wx then return nil end
    return continent, wx, wy
end

local function FromWorld(continent, wx, wy, map)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local _, pos = Try(C_Map.GetMapPosFromWorldPos, continent, CreateVector2D(wx, wy), map)
    local x, y = XY(pos)
    if OnTheMap(x, y) then return x, y end
end

local continentOf = {}            -- map -> its continent, false when it has none
local function MapContinent(map)
    local known = continentOf[map]
    if known == nil then
        known = ToWorld(map, 0.5, 0.5) or false
        continentOf[map] = known
    end
    return known or nil
end

-- A spot read on a continent map, moved to the zone map it lies in when the game can tell.
local function Lower(map, x, y)
    local info = MapInfo(map)
    if not (info and info.mapType == CONTINENT and C_Map.GetMapInfoAtPosition) then return map, x, y end
    local zone = Try(C_Map.GetMapInfoAtPosition, map, x, y)
    if type(zone) ~= "table" or type(zone.mapID) ~= "number" or zone.mapID == map then return map, x, y end
    local continent, wx, wy = ToWorld(map, x, y)
    if not continent then return map, x, y end
    local zx, zy = FromWorld(continent, wx, wy, zone.mapID)
    if zx then return zone.mapID, zx, zy end
    return map, x, y
end

-- Your own corpse once you have released, as the game reports it: on the map you are on,
-- then on its parents up to the continent (a corpse in the next zone still shows there).
local function CorpseSpot()
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition and C_Map and C_Map.GetBestMapForUnit) then return nil end
    local map = Try(C_Map.GetBestMapForUnit, "player")
    for _ = 1, 6 do
        if type(map) ~= "number" then return nil end
        local x, y = XY(Try(C_DeathInfo.GetCorpseMapPosition, map))
        if OnTheMap(x, y) and not (x == 0 and y == 0) then return Lower(map, x, y) end
        local info = MapInfo(map)
        if info and type(info.mapType) == "number" and info.mapType > CONTINENT
            and type(info.parentMapID) == "number" and info.parentMapID ~= 0 then
            map = info.parentMapID
        else
            map = nil
        end
    end
end

-- Where a grave sits on another map (fractions), or nil when it is not on it.
function ns.OnMap(g, map)
    if not (g.map and map) then return nil end
    if g.map == map then return g.x, g.y end
    if g.noWorld then return nil end
    if not g.cont then
        local continent, wx, wy = ToWorld(g.map, g.x, g.y)
        if not continent then
            g.noWorld = true
            return nil
        end
        g.cont, g.wx, g.wy = continent, wx, wy
    end
    if MapContinent(map) ~= g.cont then return nil end
    return FromWorld(g.cont, g.wx, g.wy, map)
end

local function ZoneName(map)
    local info = map and MapInfo(map)
    local name = info and Known(info.name)
    if type(name) == "string" and name ~= "" then return name end
    return "an unknown place"
end

function ns.Where(g)
    if not g.map then return "no position" end
    return ZoneName(g.map) .. " " .. floor(g.x * 100 + 0.5) .. ", " .. floor(g.y * 100 + 0.5)
end

function ns.Ago(at)
    local s = max(0, time() - (at or time()))
    if s < 10 then return "just now" end
    if s < 90 then return floor(s) .. " sec ago" end
    if s < 5400 then return floor(s / 60 + 0.5) .. " min ago" end
    return string.format("%.1f h ago", s / 3600)
end

---------------------------------------------------------------------------
-- When the addon is at work, and which markers show
---------------------------------------------------------------------------
local function InPvP()
    if not IsInInstance then return false end
    local inInstance, kind = Try(IsInInstance)
    return (inInstance and (kind == "pvp" or kind == "arena")) and true or false
end

function ns.Active()
    return (db and db.enabled and (db.pvp or not InPvP())) and true or false
end

function ns.Visible(g)
    if not (db and db.enabled and g.map) then return false end
    if g.source == "test" then return true end
    return ns.Active() and (g.released or db.early) and true or false
end

local function Changed()
    if ns.Map then ns.Map.Refresh() end
end

---------------------------------------------------------------------------
-- The group
---------------------------------------------------------------------------
local roster = { units = {}, keys = {}, isUnit = {}, unique = {}, complete = true }

local function ReadRoster()
    local r = { units = {}, keys = {}, isUnit = {}, unique = {}, complete = true }
    local function Add(unit)
        if not Try(UnitExists, unit) then return end
        local key, short = UnitKey(unit)
        if not key then
            r.complete = false                    -- a name the game hides right now
            return
        end
        if key == myKey then return end
        r.units[#r.units + 1] = unit
        r.keys[key] = unit
        r.isUnit[unit] = true
        if r.unique[short] == nil then r.unique[short] = key else r.unique[short] = false end
    end
    if IsInRaid and IsInRaid() then
        for i = 1, 40 do Add("raid" .. i) end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do Add("party" .. i) end
    end
    roster = r
end

-- The name a member is filed under here, for a name that arrived in a message.
local function RosterKey(key, short)
    if roster.keys[key] then return key end
    return roster.unique[short] or nil
end

local function ClassOf(unit)
    local _, class = Try(UnitClass, unit)
    if type(class) == "string" then return class end
end

local function ValidClass(class)
    if type(class) == "string" and class ~= "" and (not RAID_CLASS_COLORS or RAID_CLASS_COLORS[class]) then
        return class
    end
end

---------------------------------------------------------------------------
-- Markers
---------------------------------------------------------------------------
local Flush -- forward
local relayAt = {}                 -- key -> when a marker we saw ourselves is passed on

local function Announce(g)
    if g.told then return end
    g.told = true
    if not (g.map and db) or db.chat == "off" then return end
    if db.chat == "party" and IsInRaid and IsInRaid() then return end
    Print(g.name .. " released. Their corpse is marked on your map: " .. ns.Where(g) .. ".")
end

local function Remove(key)
    if graves[key] then
        graves[key] = nil
        relayAt[key] = nil
        Changed()
    end
end

local function WipeReal()          -- everything but the test markers
    local any = false
    for key, g in pairs(graves) do
        if g.source ~= "test" then
            graves[key] = nil
            any = true
        end
    end
    for key in pairs(relayAt) do relayAt[key] = nil end
    if any then Changed() end
end

function ns.Count()
    local n = 0
    for _, g in pairs(graves) do
        if ns.Visible(g) then n = n + 1 end
    end
    return n
end

-- One group member, looked at through the game's own unit data. This is what marks
-- members who don't have the addon: while they lie dead their dot is on the body.
local function ScanUnit(unit)
    local key, short = UnitKey(unit)
    if not key or key == myKey then return end
    if Try(UnitIsConnected, unit) == false then return end      -- offline: nothing to learn
    local dead = Try(UnitIsDeadOrGhost, unit)
    if dead == nil then return end
    local g = graves[key]
    if not dead then
        if g then Remove(key) end                               -- back on their feet
        return
    end
    if Try(UnitIsFeignDeath, unit) then return end
    local ghost = Try(UnitIsGhost, unit)
    if ghost == nil then return end
    if ghost then
        if g and not g.released then
            g.released = true
            Changed()
            Announce(g)
        end
        return
    end
    if g and g.source == "self" then return end                 -- their own report is better
    local map, x, y = UnitSpot(unit)
    if not map then return end
    if g and g.source == "seen" and g.map == map and abs(g.x - x) < MOVED and abs(g.y - y) < MOVED then
        return
    end
    graves[key] = {
        key = key, name = short, class = ClassOf(unit) or (g and g.class),
        map = map, x = x, y = y, at = (g and g.at) or time(),
        released = false, source = "seen",
    }
    Changed()
end

local function Prune()
    if not roster.complete then return end
    local any = false
    for key, g in pairs(graves) do
        if g.source ~= "test" then
            if roster.keys[key] then
                g.missing = nil
            else
                g.missing = (g.missing or 0) + 1
                if g.missing >= MISSING_TICKS then
                    graves[key] = nil
                    relayAt[key] = nil
                    any = true
                end
            end
        end
    end
    if any then Changed() end
end

---------------------------------------------------------------------------
-- Messages out
--   1;S;<state>;<map>;<x>;<y>;<age>;<class>;<dungeon>     my own state (A / D / G)
--   1;R;<name>;<state>;<map>;<x>;<y>;<age>;<class>;<dungeon>   a member without the addon
--   1;Q                                                    who is dead?
---------------------------------------------------------------------------
local stateDirty = false
local queryAt, lastQuery = nil, -1000
local fails, holdUntil = 0, 0
local lastProblem

local function Channel()
    if not (IsInGroup and IsInGroup()) then return nil end
    if LE_PARTY_CATEGORY_INSTANCE and LE_PARTY_CATEGORY_HOME
        and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "INSTANCE_CHAT"
    end
    if IsInRaid and IsInRaid() then return "RAID" end
    return "PARTY"
end

-- nil when messages can go out, otherwise why not. The realm's switch
-- AreOutgoingAddonChatMessagesRestricted is not asked: it is on for ordinary
-- realms, and addon messages inside a group go out all the same. A message the
-- game does refuse shows up in lastProblem.
local function CommsBlocked()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return "this client has no addon messages" end
    if C_ChatInfo.InChatMessagingLockdown then
        local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and ((issecret and issecret(v)) or v) then return "chat is locked right now (it is sent afterwards)" end
    end
    return nil
end

local function Fraction(v) return string.format("%.5f", v or 0) end
local function Clean(text) return (tostring(text or ""):gsub("[;%c]", " ")) end

local function Fields(state, map, x, y, at, class, inst)
    local age = at and max(0, time() - at) or 0
    return state .. ";" .. (map or 0) .. ";" .. Fraction(x) .. ";" .. Fraction(y) .. ";" .. floor(age)
        .. ";" .. (class or "") .. ";" .. Clean(inst)
end

local function StateMessage()
    return PROTO .. ";S;" .. Fields(me.state, me.map, me.x, me.y, me.at, myClass, me.inst)
end

local function RelayMessage(g)
    return PROTO .. ";R;" .. Clean(g.key) .. ";"
        .. Fields(g.released and "G" or "D", g.map, g.x, g.y, g.at, g.class, g.inst)
end

-- nil when it went out, otherwise "nogroup", "blocked" or "failed".
local function Send(text)
    local channel = Channel()
    if not channel then return "nogroup" end
    local blocked = CommsBlocked()
    if blocked then
        lastProblem = blocked
        return "blocked"
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, COMM, text, channel)
    if ok and (result == nil or result == true or result == 0) then
        fails, lastProblem = 0, nil
        return nil
    end
    fails = fails + 1
    lastProblem = "the game refused a message (" .. tostring(Known(result)) .. ")"
    holdUntil = GetTime() + min(30, 2 ^ fails)      -- never hammer a refusal
    return "failed"
end

function Flush()
    if not ns.Active() then return end
    local now = GetTime()
    if now < holdUntil then return end
    if stateDirty then
        local why = Send(StateMessage())
        if why == nil or why == "nogroup" then stateDirty = false else return end
    end
    if queryAt and now >= queryAt then
        local why = Send(PROTO .. ";Q")
        if why == nil then lastQuery = now end
        if why == nil or why == "nogroup" then queryAt = nil else return end
    end
    local sent = 0
    for key, at in pairs(relayAt) do
        if now >= at then
            local g = graves[key]
            if g and g.source == "seen" and g.map then
                if sent >= 3 then return end              -- the rest goes next second
                local why = Send(RelayMessage(g))
                if why == nil or why == "nogroup" then relayAt[key] = nil else return end
                sent = sent + 1
            else
                relayAt[key] = nil
            end
        end
    end
end

local function AskSoon()
    if GetTime() - lastQuery >= QUERY_EVERY then queryAt = GetTime() + 2 end
end

---------------------------------------------------------------------------
-- Your own death
---------------------------------------------------------------------------
local function InstanceName()
    if not GetInstanceInfo then return nil end
    local name, kind = Try(GetInstanceInfo)
    if type(name) == "string" and name ~= "" and type(kind) == "string" and kind ~= "none" then return name end
end

local function UpdateSelf()
    local dead = Try(UnitIsDeadOrGhost, "player")
    if dead == nil then return end
    local state = "A"
    if dead and not Try(UnitIsFeignDeath, "player") then
        local ghost = Try(UnitIsGhost, "player")
        if ghost == nil then return end
        state = ghost and "G" or "D"
    end

    if state ~= me.state then
        if state == "A" then
            me.map, me.x, me.y, me.at, me.inst = nil, nil, nil, nil, nil
        elseif state == "D" then
            me.map, me.x, me.y = UnitSpot("player")
            me.at, me.inst = time(), InstanceName()
        elseif me.state == "A" then               -- never saw the death (logged in as a ghost)
            me.map, me.x, me.y, me.at, me.inst = nil, nil, nil, time(), nil
        end
        me.state, me.fixed, me.looks = state, nil, 0
        stateDirty = true
    end

    -- Released: the game knows where the corpse lies a moment later. It fills in a death in
    -- a dungeon (the corpse is put at the way in) and corrects a body that fell.
    if me.state == "G" and not me.fixed then
        local map, x, y = CorpseSpot()
        if map then
            me.fixed = true
            if not me.map or (map == me.map and (abs(x - me.x) > MOVED or abs(y - me.y) > MOVED)) then
                me.map, me.x, me.y = map, x, y
                stateDirty = true
            end
        else
            me.looks = (me.looks or 0) + 1
            if me.looks >= CORPSE_LOOKS then me.fixed = true end
        end
    end
end

---------------------------------------------------------------------------
-- Messages in
---------------------------------------------------------------------------
local function Split(text)
    local parts = {}
    for part in (text .. ";"):gmatch("([^;]*);") do parts[#parts + 1] = part end
    return parts
end

-- fields: parts[i] = state, then map, x, y, age, class, dungeon
local function TakeState(key, short, parts, i, source, via)
    local state = parts[i]
    relayAt[key] = nil                            -- no need to pass this one on any more
    local g = graves[key]
    if state == "A" then
        if source == "self" then Remove(key) end
        return
    end
    if state ~= "D" and state ~= "G" then return end
    local released = state == "G"
    local map, x, y = tonumber(parts[i + 1]), tonumber(parts[i + 2]), tonumber(parts[i + 3])
    if not (map and map > 0 and map == floor(map) and OnTheMap(x, y) and x == x and y == y) then
        -- no position (they died in a dungeon): keep what is known, note the release
        if g and released and not g.released then
            g.released = true
            Changed()
            Announce(g)
        end
        return
    end
    local age = tonumber(parts[i + 4]) or 0
    if age ~= age then age = 0 end
    age = max(0, min(MAX_AGE, age))
    local inst = parts[i + 6]
    local unit = roster.keys[key]
    graves[key] = {
        key = key, name = short,
        class = ValidClass(parts[i + 5]) or (g and g.class) or (unit and ClassOf(unit)) or nil,
        map = map, x = x, y = y, at = time() - age,
        released = released, source = source, via = via,
        inst = (type(inst) == "string" and inst ~= "") and inst:sub(1, 60) or nil,
        told = g and g.told or nil,
    }
    Changed()
    if released then Announce(graves[key]) end
end

local function OnQuery()
    if me.state ~= "A" then
        C_Timer.After(0.3 + math.random() * 1.2, function()
            stateDirty = true
            Flush()
        end)
    end
    -- Members without the addon can't answer: whoever saw them die passes it on, a little
    -- later and at a random moment, and stays quiet if someone else was quicker.
    local now = GetTime()
    for key, g in pairs(graves) do
        if g.source == "seen" and not relayAt[key] then
            relayAt[key] = now + 1.5 + math.random() * 2.5
        end
    end
end

local function OnMessage(prefix, text, channel, sender)
    if Known(prefix) ~= COMM or not db or not ns.Active() then return end
    text, channel, sender = Known(text), Known(channel), Known(sender)
    if type(text) ~= "string" or type(sender) ~= "string" then return end
    if channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT" then return end
    if not myKey then Identity() end
    if not myKey then return end                  -- can't tell my own messages from others' yet
    local senderKey, senderShort = SenderKey(sender)
    if not senderKey or senderKey == myKey then return end
    local parts = Split(text)
    if parts[1] ~= PROTO then return end
    local kind = parts[2]
    if kind == "Q" then
        OnQuery()
    elseif kind == "S" then
        TakeState(RosterKey(senderKey, senderShort) or senderKey, senderShort, parts, 3, "self", nil)
    elseif kind == "R" then
        local aboutKey, aboutShort = SenderKey(parts[3])
        if not aboutKey or aboutKey == myKey then return end
        local key = RosterKey(aboutKey, aboutShort)
        if not key then return end                -- not someone in my group
        relayAt[key] = nil
        local g = graves[key]
        if g and (g.source == "self" or g.source == "seen") then return end   -- first-hand is better
        if parts[4] == "A" then return end
        TakeState(key, aboutShort, parts, 4, "relay", senderShort)
    end
end

---------------------------------------------------------------------------
-- Once a second
---------------------------------------------------------------------------
local wasGrouped, wasActive, aloneTicks = false, nil, 0

local function Tick()
    if not db then return end
    if not myKey then Identity() end
    if not myKey then return end                  -- the game hasn't said who I am yet
    local active = ns.Active()
    if active ~= wasActive then
        wasActive = active
        if active and me.state ~= "A" then stateDirty = true end
        Changed()
    end
    UpdateSelf()
    local grouped = (IsInGroup and IsInGroup()) and true or false
    if grouped then
        aloneTicks = 0
        if not wasGrouped then                    -- joined: ask who is dead, say if I am
            AskSoon()
            if me.state ~= "A" then stateDirty = true end
        end
    else
        -- Not at once: right after logging in the game doesn't know the group yet.
        aloneTicks = aloneTicks + 1
        if aloneTicks == 5 then WipeReal() end
        stateDirty, queryAt = false, nil
    end
    wasGrouped = grouped
    if grouped and active then
        ReadRoster()
        for _, unit in ipairs(roster.units) do ScanUnit(unit) end
        Prune()
        Flush()
    end
end
ns.Tick = Tick

---------------------------------------------------------------------------
-- Test markers
---------------------------------------------------------------------------
function ns.Testing()
    for _, g in pairs(graves) do
        if g.source == "test" then return true end
    end
    return false
end

function ns.SetTesting(on)
    for key, g in pairs(graves) do
        if g.source == "test" then graves[key] = nil end
    end
    local placed = false
    if on then
        local map, x, y = UnitSpot("player")
        if map then
            for i, t in ipairs(TESTS) do
                local key = "~test" .. i
                graves[key] = {
                    key = key, name = t[1], class = t[2], map = map,
                    x = max(0.02, min(0.98, x + t[3])), y = max(0.02, min(0.98, y + t[4])),
                    at = time() - i * 45, released = true, source = "test", told = true,
                }
            end
            placed = true
        else
            Print("no test markers here: the game gives addons no map position inside dungeons.")
        end
    end
    Changed()
    return placed
end

---------------------------------------------------------------------------
-- Saved settings. The markers are saved too, so a /reload keeps them.
---------------------------------------------------------------------------
local function InitDB()
    if type(GroupGravesDB) ~= "table" then GroupGravesDB = {} end
    db = GroupGravesDB
    for key, value in pairs(DEFAULTS) do
        if type(db[key]) ~= type(value) then db[key] = value end
    end
    for key, allowed in pairs(CHOICES) do
        if not allowed[db[key]] then db[key] = DEFAULTS[key] end
    end
    db.size = floor(max(SIZE_MIN, min(SIZE_MAX, db.size)) + 0.5)

    local now = time()
    if type(db.graves) == "table" then
        for key, g in pairs(db.graves) do
            if type(key) == "string" and type(g) == "table" and g.source ~= "test"
                and type(g.name) == "string" and type(g.map) == "number"
                and type(g.x) == "number" and type(g.y) == "number"
                and type(g.at) == "number" and now - g.at < MAX_AGE then
                g.key, g.missing, g.noWorld = key, nil, nil
                graves[key] = g
            end
        end
    end
    db.graves = graves

    local saved = db.me
    if type(saved) == "table" and (saved.state == "D" or saved.state == "G")
        and type(saved.at) == "number" and now - saved.at < MAX_AGE then
        me = saved
        me.fixed, me.looks = nil, 0
    else
        me = { state = "A" }
    end
    db.me = me
    ns.db = db
end

---------------------------------------------------------------------------
-- For Options.lua: the same changes the slash commands make
---------------------------------------------------------------------------
function ns.Set(key, value)
    if not db or DEFAULTS[key] == nil then return end
    if key == "size" then
        value = floor(max(SIZE_MIN, min(SIZE_MAX, tonumber(value) or DEFAULTS.size)) + 0.5)
    end
    db[key] = value
    Changed()
end

function ns.Reset()
    for key, value in pairs(DEFAULTS) do db[key] = value end
    db.minimap = nil
    if ns.Kit then ns.Kit.RefreshMinimap() end
    Changed()
end

function ns.Clear()
    for key in pairs(graves) do graves[key] = nil end
    for key in pairs(relayAt) do relayAt[key] = nil end
    Changed()
end

local SOURCE = {
    self  = "sent by their addon",
    seen  = "seen by your addon",
    relay = "passed on",
    test  = "test marker",
}

function ns.PrintList()
    local list = {}
    for _, g in pairs(graves) do
        if g.map then list[#list + 1] = g end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    if #list == 0 then
        Print("no corpses marked.")
        return
    end
    Print(#list .. (#list == 1 and " corpse marked:" or " corpses marked:"))
    for _, g in ipairs(list) do
        local source = SOURCE[g.source] or "?"
        if g.source == "relay" and g.via then source = "passed on by " .. g.via end
        print("  " .. g.name .. ": " .. ns.Where(g) .. ", died " .. ns.Ago(g.at) .. ", "
            .. (g.released and "released" or "not released yet") .. " (" .. source .. ")"
            .. (ns.Visible(g) and "" or " - not shown"))
    end
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
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("UNIT_HEALTH")
f:RegisterEvent("CHAT_MSG_ADDON")

local ticker

f:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            InitDB()
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM)
            end
            if ns.Kit and ns.Options then         -- options window and minimap button
                local ok, err = pcall(ns.Options.Init)
                if not ok then Print("options error: " .. tostring(err)) end
            end
        end
        return
    end
    if not db then return end

    if event == "CHAT_MSG_ADDON" then
        OnMessage(arg1, arg2, arg3, arg4)

    elseif event == "UNIT_HEALTH" then
        -- A death shows here at once; the once-a-second look is the safety net.
        if roster.isUnit[arg1] and ns.Active() then
            if Try(UnitIsDeadOrGhost, arg1) or next(graves) then ScanUnit(arg1) end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        Identity()
        if ns.Map then ns.Map.Init() end
        if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(1, Tick) end
        if arg1 or arg2 then AskSoon() end        -- logged in or reloaded while in a group
        Tick()
        if not db.welcomed then
            db.welcomed = true
            Print("loaded. When someone in your group dies and releases, their corpse stays marked on your world map. "
                .. "/graves test shows three test markers, /graves lists the options.")
        end

    else
        -- Group or zone changed, or I died, released, came back, or a fight ended. The full
        -- look, so a setting switched a moment ago is noticed before anything is sent
        -- (otherwise the death would go out twice).
        Tick()
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function PrintStatus()
    Print((db.enabled and "on" or "OFF")
        .. "  |  markers " .. (db.early and "from the moment of death" or "once released")
        .. "  |  size " .. db.size
        .. "  |  names " .. OnOff(db.names)
        .. "  |  chat line " .. db.chat
        .. "  |  battlegrounds " .. OnOff(db.pvp)
        .. "  |  corpses marked: " .. ns.Count())
end

local function PrintHelp()
    Print("commands:")
    print("  /graves list (the marked corpses)   -  /graves test (three test markers around you)")
    print("  /graves early (mark from the moment of death)   -  /graves names   -  /graves size <" .. SIZE_MIN .. "-" .. SIZE_MAX .. ">")
    print("  /graves chat off|party|always (chat line when someone releases)   -  /graves pvp (also in battlegrounds)")
    print("  /graves clear (forget every marker)   -  /graves on|off   -  /graves reset   -  /graves debug")
    print("  /graves config (options window)   -  /graves minimap (minimap button on/off)")
end

-- Kit.lua and Options.lua only load after a full game restart when the addon was copied in
-- while the game ran: say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    Print("the options window and the minimap button appear after you restart the game once.")
    return false
end

local function SyncOptions()                      -- an open options window follows what was typed
    if ns.Kit then ns.Kit.Sync() end
end

SLASH_GROUPGRAVES1 = "/graves"
SLASH_GROUPGRAVES2 = "/groupgraves"
SlashCmdList.GROUPGRAVES = function(msg)
    if not db then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(%S*)")

    if cmd == "" or cmd == "help" or cmd == "status" then
        PrintStatus()
        PrintHelp()
        return

    elseif cmd == "list" then
        ns.PrintList()
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

    elseif cmd == "early" then
        db.early = not db.early

    elseif cmd == "names" then
        db.names = not db.names

    elseif cmd == "pvp" then
        db.pvp = not db.pvp

    elseif cmd == "size" then
        local n = tonumber(arg)
        if not n then Print("/graves size <" .. SIZE_MIN .. "-" .. SIZE_MAX .. ">") return end
        db.size = floor(max(SIZE_MIN, min(SIZE_MAX, n)) + 0.5)

    elseif cmd == "chat" then
        if not CHOICES.chat[arg] then Print("/graves chat always|off|party") return end
        db.chat = arg

    elseif cmd == "test" then
        local on = not ns.Testing()
        if ns.SetTesting(on) then
            Print("three test markers are around you on the world map. /graves test again removes them.")
        elseif not on then
            Print("test markers removed.")
        end
        SyncOptions()
        return

    elseif cmd == "clear" then
        ns.Clear()
        Print("every marker forgotten.")
        return

    elseif cmd == "reset" then
        ns.Reset()

    elseif cmd == "debug" then
        local total = 0
        for _ in pairs(graves) do total = total + 1 end
        Print("build " .. tostring((select(4, GetBuildInfo()))) .. ", active: " .. tostring(ns.Active())
            .. ", channel: " .. tostring(Channel())
            .. ", messages: " .. (CommsBlocked() or "can go out")
            .. ", you: " .. me.state .. (me.map and (" at " .. ns.Where(me)) or "")
            .. ", markers: " .. total .. " (" .. ns.Count() .. " shown)"
            .. ", world map: " .. (ns.Map and ns.Map.Describe() or "Map.lua not loaded"))
        if lastProblem then Print("last message problem: " .. lastProblem) end
        return

    else
        PrintHelp()
        return
    end

    Changed()
    PrintStatus()
    SyncOptions()
end
