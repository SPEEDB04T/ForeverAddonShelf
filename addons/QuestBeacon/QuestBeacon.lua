-- Quest Beacon
--
-- You pick up a quest that cannot be shared while you are in a group: the addon tells the
-- group in group chat which quest it is and where you got it (who gives it, the area, the
-- coordinates and a map pin link anyone can click, addon or not).
--
-- A group member who also has the addon and does not have the quest gets a map pin on that
-- spot (and the arrow to it), unless they have a pin of their own. The pin goes away when
-- they pick the quest up.
--
-- Everything travels in the chat line itself; there are no hidden addon messages.
local ADDON_NAME, ns = ...

local PREFIX = "|cffffd100Quest Beacon:|r "
local function Print(msg) print(PREFIX .. tostring(msg)) end
ns.Print = Print

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local CHAT_LIMIT   = 255      -- bytes in one chat message, link codes included
local DECIDE_DELAY = 0.5      -- after QUEST_ACCEPTED, until the quest is in the log
local DECIDE_TRIES = 6
local ECHO_WAIT    = 4        -- our own line has to come back within this
local HOLD_STEP    = 2        -- chat is locked (a fight in an instance): look again
local HOLD_MAX     = 90
local REPEAT_GAP   = 600      -- the same quest is not called out twice in ten minutes
local LOG_SIZE     = 30
local PIN_TEXT     = "|A:Waypoint-MapPin-ChatIcon:13:13:0:0|a Map Pin Location"
local MARK         = " can't be shared - "          -- how a line of ours is recognised
local LINE_PATTERN = "^%[(.-)%] can't be shared %- "

local DEFAULTS = {
    enabled = true,
    where   = "party",        -- party: not in raids; always: raids too
    links   = true,           -- the clickable map pin in the line
    follow  = "track",        -- a group member's call: off, pin, track (pin and arrow)
}
local CHOICES = {
    where  = { party = true, always = true },
    follow = { off = true, pin = true, track = true },
}

local db
local offer                   -- the quest giver of the offer on screen: { id, name, at }
local awaiting                -- the line we sent and have not seen come back
local said, heard = {}, {}    -- [questID] = time; [title] = { at, who }
local waypoint                -- the pin we set: { title, map, x, y }
local linkTrouble, echoBlind  -- this session: links were refused; our own lines do not come back

---------------------------------------------------------------------------
-- Reading the game: values can be hidden ("secret") and calls can fail
---------------------------------------------------------------------------
local function Known(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return Known(a), Known(b)
end

local function Text(v)
    v = Known(v)
    if type(v) == "string" and v ~= "" then return v end
end

local function Plain(text) return (tostring(text):gsub("|", "||")) end   -- no chat codes from someone else's line

local function Log(what, channel, text, note)
    if not db then return end
    local log = db.log
    local entry = { at = date and date("%H:%M:%S") or "", what = what, channel = channel or "",
                    text = text and text:sub(1, 160) or "", note = note or "" }
    log[#log + 1] = entry
    while #log > LOG_SIZE do table.remove(log, 1) end
    return entry
end

-- Both parts of a unit's name. On this client a player's surname comes as the second value
-- ("Bunglfart", "Dunglode"); on other clients the second value is a realm, or nothing.
local function NameParts(unit)
    local first, second = Read(UnitName, unit)
    return Text(first), Text(second)
end

local function FullName(unit)
    local first, second = NameParts(unit)
    if first and second then return first .. " " .. second end
    return first
end

---------------------------------------------------------------------------
-- Where am I, and who gave the quest
---------------------------------------------------------------------------
local function XY(pos)
    pos = Known(pos)
    if type(pos) ~= "table" then return nil end
    local x, y
    if type(pos.GetXY) == "function" then x, y = Read(pos.GetXY, pos) else x, y = Known(pos.x), Known(pos.y) end
    if type(x) == "number" and type(y) == "number" and x > 0 and x < 1 and y > 0 and y < 1 then return x, y end
end

local function MapInfo(map)
    local info = C_Map and Read(C_Map.GetMapInfo, map)
    if type(info) == "table" then return info end
end

local function CanPin(map)
    return C_Map and Read(C_Map.CanSetUserWaypointOnMap, map) == true
end

-- The same spot on the map above (a cave or a building's own map takes no pin; its zone does).
local function OnParent(map, x, y)
    local info = MapInfo(map)
    local parent = info and Known(info.parentMapID)
    if type(parent) ~= "number" or parent <= 0 then return nil end
    local parentInfo = MapInfo(parent)
    local kind = parentInfo and Known(parentInfo.mapType)
    if type(kind) == "number" and kind < 3 then return nil end          -- a continent is too coarse
    if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local continent, world = Read(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x, y))
    if type(continent) ~= "number" or type(world) ~= "table" then return nil end
    local _, pos = Read(C_Map.GetMapPosFromWorldPos, continent, world, parent)
    local px, py = XY(pos)
    if px then return parent, px, py end
end

-- { zone, sub, map, x, y, pin }: x and y only where the game gives a position (not in
-- instances), pin only where the game takes a map pin.
local function Spot()
    local spot = {}
    local map = C_Map and Read(C_Map.GetBestMapForUnit, "player")
    if type(map) == "number" then
        local x, y = XY(Read(C_Map.GetPlayerMapPosition, map, "player"))
        if x then
            for _ = 1, 3 do
                if CanPin(map) then break end
                local parent, px, py = OnParent(map, x, y)
                if not parent then break end
                map, x, y = parent, px, py
            end
            spot.map, spot.x, spot.y, spot.pin = map, x, y, CanPin(map)
        end
        local info = MapInfo(map)
        spot.zone = info and Text(info.name)
    end
    spot.zone = spot.zone or Text(Read(GetRealZoneText)) or Text(Read(GetZoneText))
    local sub = Text(Read(GetSubZoneText))
    if sub and sub ~= spot.zone then spot.sub = sub end
    return spot
end

local function GiverName()
    for _, unit in ipairs({ "questnpc", "npc" }) do
        if Read(UnitExists, unit) and not Read(UnitIsPlayer, unit) then
            local name = FullName(unit)
            if name then return name end
        end
    end
end

---------------------------------------------------------------------------
-- The line
---------------------------------------------------------------------------
local function PinLink(spot)
    local label = type(MAP_PIN_HYPERLINK) == "string" and MAP_PIN_HYPERLINK or PIN_TEXT
    return ("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r"):format(
        spot.map, floor(spot.x * 10000 + 0.5), floor(spot.y * 10000 + 0.5), label)
end

local function Compose(title, giver, spot, sub, zone, coords, link)
    local place = zone and spot.zone or nil
    if sub and spot.sub then place = place and (spot.sub .. ", " .. place) or spot.sub end
    local text = "[" .. title .. "]" .. MARK
    if giver and place then
        text = text .. "pick it up from " .. giver .. ", " .. place
    elseif giver then
        text = text .. "pick it up from " .. giver
    else
        text = text .. "I picked it up " .. (place and ("in " .. place) or "here")
    end
    if coords and spot.x then text = text .. (" (%.1f, %.1f)"):format(spot.x * 100, spot.y * 100) end
    if link then text = text .. " " .. link end
    return text
end

-- The fullest line that fits in one chat message. Dropped in this order: the area inside the
-- zone; with a pin link (which carries both) the written coordinates and then the zone; and
-- last the end of the title.
local function Build(title, giver, spot, withLink)
    local link = withLink and spot.pin and spot.x and PinLink(spot) or nil
    local tries = { { true, true, true }, { false, true, true } }
    if link then
        tries[3] = { false, true, false }
        tries[4] = { false, false, false }
    end
    local text
    for _, try in ipairs(tries) do
        text = Compose(title, giver, spot, try[1], try[2], try[3], link)
        if #text <= CHAT_LIMIT then return text end
    end
    local last = tries[#tries]
    local keep = max(8, #title - (#text - CHAT_LIMIT) - 3)
    local short = title:sub(1, keep):gsub("[\128-\191]*$", "")       -- never half a letter
    short = short:gsub("[\192-\255]$", "") .. "..."
    text = Compose(short, giver, spot, last[1], last[2], last[3], link)
    if #text > CHAT_LIMIT then text = Compose(short, nil, spot, false, false, false, link) end
    if #text > CHAT_LIMIT then text = Compose(short, nil, spot, false, false, false, nil):sub(1, CHAT_LIMIT) end
    return text
end
ns.Build = Build

-- What a line says: the quest, and the pin if it carries one.
local function Parse(text)
    local title = text:match(LINE_PATTERN)
    if not title or title == "" then return nil end
    local map, x, y = text:match("|Hworldmap:(%d+):(%d+):(%d+)|h")
    map, x, y = tonumber(map), tonumber(x), tonumber(y)
    if map and map > 0 and x and y and x > 0 and x < 10000 and y > 0 and y < 10000 then
        return title, map, x / 10000, y / 10000
    end
    return title
end
ns.Parse = Parse

---------------------------------------------------------------------------
-- The group
---------------------------------------------------------------------------
local function Channel()
    if not Read(IsInGroup) then return nil end
    local raid = Read(IsInRaid) and true or false
    if raid and db.where ~= "always" then return nil end
    if Read(IsInGroup, LE_PARTY_CATEGORY_INSTANCE or 2) then return "INSTANCE_CHAT" end
    return raid and "RAID" or "PARTY"
end

local function Others()
    local units = {}
    local raid = Read(IsInRaid) and true or false
    for i = 1, raid and 40 or 4 do
        local unit = (raid and "raid" or "party") .. i
        if Read(UnitExists, unit) and not Read(UnitIsUnit, unit, "player") then units[#units + 1] = unit end
    end
    return units
end

-- True only when the game says so for every other member.
local function EveryoneHas(questID)
    if not (C_QuestLog and C_QuestLog.IsUnitOnQuest) then return false end
    local units = Others()
    if #units == 0 then return false end
    for _, unit in ipairs(units) do
        if Read(C_QuestLog.IsUnitOnQuest, unit, questID) ~= true then return false end
    end
    return true
end

-- A title in a line can be cut short ("Some Long Ti..."): then the beginning has to agree.
local function SameTitle(called, full)
    if called == full then return true end
    if called:sub(-3) ~= "..." or #called < 8 then return false end
    return full:sub(1, #called - 3) == called:sub(1, -4)
end
ns.SameTitle = SameTitle

local function HaveQuestTitled(title)
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return false end
    local n = Read(C_QuestLog.GetNumQuestLogEntries)
    if type(n) ~= "number" then return false end
    for i = 1, n do
        local info = Read(C_QuestLog.GetInfo, i)
        local mine = type(info) == "table" and not Known(info.isHeader) and Known(info.title)
        if type(mine) == "string" and SameTitle(title, mine) then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The map pin for a quest a group member called out
---------------------------------------------------------------------------
local function OurPinStands()
    if not (waypoint and C_Map and C_Map.GetUserWaypoint) then return false end
    local point = Read(C_Map.GetUserWaypoint)
    if type(point) ~= "table" or Known(point.uiMapID) ~= waypoint.map then return false end
    local pos = Known(point.position)
    local x, y
    if type(pos) == "table" then
        if type(pos.GetXY) == "function" then x, y = Read(pos.GetXY, pos) else x, y = Known(pos.x), Known(pos.y) end
    end
    return type(x) == "number" and type(y) == "number"
        and abs(x - waypoint.x) < 0.001 and abs(y - waypoint.y) < 0.001
end

-- Never removes a pin the player has set or moved since.
local function ClearPin()
    local ours = OurPinStands()
    waypoint = nil
    if ours and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    return ours
end

local function SetPin(title, map, x, y, who)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false, "no map pins on this client"
    end
    if Read(C_Map.HasUserWaypoint) and not OurPinStands() then return false, "you have a pin of your own" end
    if not CanPin(map) then return false, "the game takes no pin on that map" end
    local ok = pcall(function() C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y)) end)
    waypoint = { title = title, map = map, x = x, y = y }
    if not ok or not OurPinStands() then
        waypoint = nil
        return false, "the game did not take the pin"
    end
    if db.follow == "track" and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    Print("map pin set where " .. Plain(who or "a group member") .. " picked up [" .. Plain(title)
        .. "]. It goes away when you pick the quest up.")
    return true
end

function ns.Pin() return waypoint end

---------------------------------------------------------------------------
-- Sending, and making sure it arrived
---------------------------------------------------------------------------
local function ChatLocked()
    return C_ChatInfo and Read(C_ChatInfo.InChatMessagingLockdown) and true or false
end

local Send

-- Our line did not come back. With a pin link in it, the game probably refused the link:
-- say it again without. Without one, stop relying on lines coming back.
local function EchoMissed(sent)
    if awaiting ~= sent then return end
    awaiting = nil
    if sent.rich then
        linkTrouble = true
        db.linkFails = (db.linkFails or 0) + 1
        Log("lost", sent.channel, sent.text, "no echo: sent again without the pin link")
        Send(sent.plain, sent.plain, sent.channel)
    else
        echoBlind = true
        Log("lost", sent.channel, sent.text, "no echo")
        Print("could not see the line arrive in group chat. For the rest of this session it is sent "
            .. "without the map pin link.")
    end
end

function Send(text, plain, channel)
    if ChatLocked() then
        local waited = 0
        local function Again()
            waited = waited + HOLD_STEP
            if not ChatLocked() then
                Send(text, plain, channel)
            elseif waited >= HOLD_MAX then
                Log("dropped", channel, text, "chat stayed locked")
                Print("chat stayed locked, so the group was not told. The line was: " .. plain)
            else
                C_Timer.After(HOLD_STEP, Again)
            end
        end
        C_Timer.After(HOLD_STEP, Again)
        return
    end
    local fn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local rich = text ~= plain
    -- head: the line up to and including "can't be shared - ", which no link is part of
    local sent = { text = text, plain = plain, channel = channel, rich = rich,
                   head = text:sub(1, (text:find(MARK, 1, true) or 0) + #MARK - 1) }
    if not echoBlind then awaiting = sent end       -- before sending: the line can come back at once
    local ok, err = pcall(fn, text, channel)
    if not ok then
        if awaiting == sent then awaiting = nil end
        Log("failed", channel, text, tostring(err))
        if rich then
            linkTrouble = true
            Send(plain, plain, channel)
        else
            Print("the game refused the line to the group: " .. tostring(err))
        end
        return
    end
    sent.entry = Log(rich and "out" or "out plain", channel, text, sent.back)
    if echoBlind then return end
    C_Timer.After(ECHO_WAIT, function() EchoMissed(sent) end)
end

---------------------------------------------------------------------------
-- A quest was accepted
---------------------------------------------------------------------------
local function Decide(p)
    local index = C_QuestLog and Read(C_QuestLog.GetLogIndexForQuestID, p.id)
    local info = type(index) == "number" and index > 0 and Read(C_QuestLog.GetInfo, index) or nil
    if type(info) ~= "table" then
        p.tries = p.tries + 1
        if p.tries < DECIDE_TRIES then C_Timer.After(DECIDE_DELAY, function() Decide(p) end) end
        return
    end
    local title = Text(info.title) or Text(Read(C_QuestLog.GetTitleForQuestID, p.id))
    if not title then return end

    -- the pin that led here has done its job
    if waypoint and SameTitle(waypoint.title, title) then ClearPin() end

    if not db.enabled then return end
    if Known(info.isHidden) or Known(info.isTask) or Known(info.isBounty) then return end
    if Read(C_QuestLog.IsPushableQuest, p.id) ~= false then return end     -- shareable, or the game won't say
    local channel = Channel()
    if not channel then return end

    local now = GetTime()
    if said[p.id] and now - said[p.id] < REPEAT_GAP then return end
    for called, other in pairs(heard) do
        if now - other.at >= REPEAT_GAP then
            heard[called] = nil
        elseif SameTitle(called, title) then
            Log("skip", channel, title, (other.who or "someone") .. " already called it out")
            return
        end
    end
    if EveryoneHas(p.id) then
        Log("skip", channel, title, "everyone in the group has it")
        return
    end
    said[p.id] = now

    local plain = Build(title, p.giver, p.spot, false)
    local text = plain
    if db.links and not linkTrouble and not echoBlind then text = Build(title, p.giver, p.spot, true) end
    Send(text, plain, channel)
end

local function OnAccepted(a, b)
    local id = tonumber(Known(b)) or tonumber(Known(a))      -- some clients send (log index, quest id)
    if not id then return end
    local giver
    if offer and (offer.id == id or (offer.id == nil and GetTime() - offer.at < 300)) then giver = offer.name end
    giver = giver or GiverName()
    local p = { id = id, giver = giver, spot = Spot(), tries = 0 }
    C_Timer.After(DECIDE_DELAY, function() Decide(p) end)
end

local function OnOffer()
    local id = Read(GetQuestID)
    offer = { id = type(id) == "number" and id > 0 and id or nil, name = GiverName(), at = GetTime() }
end

---------------------------------------------------------------------------
-- Group chat: our own line coming back, and other members' lines
---------------------------------------------------------------------------
local CHAT_EVENTS = {
    CHAT_MSG_PARTY = "PARTY", CHAT_MSG_PARTY_LEADER = "PARTY",
    CHAT_MSG_RAID = "RAID", CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT", CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
}

-- Does a chat sender fit one spelling of a name? A realm may follow after a dash.
local function Fits(sender, spelling)
    if sender == spelling then return true end
    if sender:sub(1, #spelling + 1) == spelling .. "-" then return true, sender:sub(#spelling + 2) end
    return false
end

local function Squash(text) return (text:gsub("[%s%-']", ""):lower()) end

-- The group units a sender's name fits. Chat spells a sender "First Last" while UnitName gives
-- "First", "Last"; the second value can also be a realm. So: "First Second" on every unit first,
-- "First" alone only when that fitted nobody, and then a realm after the dash decides between several.
local function UnitsNamed(sender, units)
    local names, fits = {}, {}
    for i, unit in ipairs(units) do
        local first, second = NameParts(unit)
        names[i] = { unit = unit, first = first, second = second }
    end
    for _, n in ipairs(names) do
        if n.first and n.second and Fits(sender, n.first .. " " .. n.second) then fits[#fits + 1] = n.unit end
    end
    if #fits > 0 then return fits end
    local byRealm = {}
    for _, n in ipairs(names) do
        if n.first then
            local ok, realm = Fits(sender, n.first)
            if ok then
                fits[#fits + 1] = n.unit
                if realm and n.second and Squash(realm) == Squash(n.second) then byRealm[#byRealm + 1] = n.unit end
            end
        end
    end
    if #fits > 1 and #byRealm > 0 then return byRealm end
    return fits
end

-- Who sent a chat line: the group unit and how it was told ("guid" or "name"). Without a unit:
-- "nobody" (not in my group), "others" (several members, none of them me), "unsure" (several, one
-- of them me) or "hidden" (the game does not say).
local function Sender(sender, guid)
    guid, sender = Text(guid), Text(sender)
    local units = Others()
    table.insert(units, 1, "player")
    if guid and Text(Read(UnitGUID, "player")) then
        for _, unit in ipairs(units) do
            if Read(UnitGUID, unit) == guid then return unit, "guid" end
        end
        return nil, "nobody"
    end
    if not sender or not NameParts("player") then return nil, "hidden" end
    local fits = UnitsNamed(sender, units)
    if #fits == 1 then return fits[1], "name" end
    if #fits == 0 then return nil, "nobody" end
    for _, unit in ipairs(fits) do
        if unit == "player" then return nil, "unsure" end
    end
    return nil, "others"
end

-- For the saved log: the sender as the game spelled it, and what it was taken for.
local function SenderNote(sender, unit, how)
    sender = Text(sender)
    return ('"%s" = %s'):format(sender or "?", unit and (unit .. " by " .. how) or how)
end

local function Who(sender)
    sender = Text(sender)
    if not sender then return nil end
    return sender:match("^([^%-]+)") or sender
end

local function OnChat(channel, text, sender, guid)
    -- mine: true, false (someone else's), or nil when the game does not say who sent it
    local unit, how = Sender(sender, guid)
    local mine
    if unit then mine = unit == "player" elseif how == "nobody" or how == "others" then mine = false end
    text = Known(text)
    -- Our line came back: from us (or from a hidden sender), and readable as ours or hidden.
    if awaiting and awaiting.channel == channel and mine ~= false
        and (type(text) ~= "string" or text:sub(1, #awaiting.head) == awaiting.head) then
        awaiting.back = "came back, sender " .. SenderNote(sender, unit, how)
        if awaiting.entry then awaiting.entry.note = awaiting.back end
        awaiting = nil
    end
    if mine ~= false or type(text) ~= "string" then return end

    local title, map, x, y = Parse(text)
    if not title then return end
    local who = Who(sender)
    heard[title] = { at = GetTime(), who = who }
    Log("in", channel, text, SenderNote(sender, unit, how))
    if db.follow == "off" or not map then return end
    if HaveQuestTitled(title) then return end
    local ok, why = SetPin(title, map, x, y, who)
    if not ok then Log("no pin", channel, title, why) end
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function InitDB()
    if type(QuestBeaconDB) ~= "table" then QuestBeaconDB = {} end
    db = QuestBeaconDB
    for key, value in pairs(DEFAULTS) do
        if type(db[key]) ~= type(value) or (CHOICES[key] and not CHOICES[key][db[key]]) then db[key] = value end
    end
    if type(db.log) ~= "table" then db.log = {} end
    while #db.log > LOG_SIZE do table.remove(db.log, 1) end
    ns.db = db
end

function ns.Set(key, value)
    if not db or DEFAULTS[key] == nil then return end
    if type(value) ~= type(DEFAULTS[key]) then return end
    if CHOICES[key] and not CHOICES[key][value] then return end
    db[key] = value
    if key == "links" and value then linkTrouble, echoBlind = nil, nil end      -- try again
    if key == "follow" and value == "off" then ClearPin() end
end

function ns.Reset()
    for key, value in pairs(DEFAULTS) do db[key] = value end
    linkTrouble, echoBlind = nil, nil
end

-- What the line would look like for a quest picked up right here. Nothing is sent.
function ns.Test()
    local giver = FullName("target") or "the quest giver"
    local spot = Spot()
    Print("picking up a quest here that can't be shared would tell your group:")
    print("  " .. Build("A Quest You Cannot Share", giver, spot, db.links))
    if not spot.x then
        print("  (the game gives no position here, so there are no coordinates and no map pin)")
    elseif not spot.pin then
        print("  (the game takes no map pin on this map, so the line has none)")
    end
    print("  Nothing was sent.")
end

function ns.StatusLines()
    local lines = {}
    if not db.enabled then
        lines[1] = "Not telling the group."
    else
        lines[1] = db.where == "always" and "Tells your party or raid." or "Tells your party (not raids)."
    end
    if db.enabled and db.links and (linkTrouble or echoBlind) then
        lines[#lines + 1] = "The map pin link is left out this session: the game did not pass it on."
    end
    if waypoint then lines[#lines + 1] = "Map pin set for [" .. Plain(waypoint.title) .. "]." end
    return lines
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("QUEST_DETAIL")
f:RegisterEvent("QUEST_ACCEPTED")
for event in pairs(CHAT_EVENTS) do pcall(f.RegisterEvent, f, event) end

local problem
local function Guard(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not problem then problem = tostring(err) end        -- shown by /beacon status
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON_NAME then
            InitDB()
            if ns.Kit and ns.Options then            -- the options window
                local ok, err = pcall(ns.Options.Init)
                if not ok then Print("options error: " .. tostring(err)) end
            end
        end
        return
    end
    if not db then return end

    if event == "QUEST_ACCEPTED" then
        Guard(OnAccepted, ...)
    elseif event == "QUEST_DETAIL" then
        Guard(OnOffer)
    elseif CHAT_EVENTS[event] then
        local text, sender = ...
        Guard(OnChat, CHAT_EVENTS[event], text, sender, (select(12, ...)))
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not db.welcomed then
            db.welcomed = true
            Print("loaded. When you pick up a quest that can't be shared, your group is told where to get it. "
                .. "/beacon opens the options.")
        end
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local FOLLOW_WORDS = { off = "nothing", pin = "a map pin", track = "a map pin and the arrow to it" }

local function PrintStatus()
    for _, line in ipairs(ns.StatusLines()) do Print(line) end
    Print("map pin link in the line " .. (db.links and "on" or "off")
        .. "  |  when a group member calls one out: " .. FOLLOW_WORDS[db.follow])
    if problem then Print("an error was caught: " .. problem) end
    if (db.linkFails or 0) > 0 then
        Print(db.linkFails .. (db.linkFails == 1 and " line" or " lines") .. " so far had to be sent again without the pin link.")
    end
    local log = db.log
    if #log > 0 then
        Print("last lines (all " .. #log .. " are saved in QuestBeaconDB.log):")
        for i = max(1, #log - 4), #log do
            local e = log[i]
            print(("  %s %s %s: %s%s"):format(e.at, e.what, e.channel, Plain(e.text),
                e.note ~= "" and ("  (" .. Plain(e.note) .. ")") or ""))
        end
    end
end

local function PrintHelp()
    Print("commands:")
    print("  /beacon (options)   -  /beacon on, off   -  /beacon raid (raids too, or not)")
    print("  /beacon links (map pin link in the line)   -  /beacon follow off|pin|track")
    print("  /beacon test (show the line, send nothing)   -  /beacon status   -  /beacon reset")
end

-- Kit.lua and Options.lua sit next to this file. If a /reload ran this file without them
-- (files added by an update only load after a full restart), say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    Print("the options window appears after you restart the game once.")
    return false
end

local function SyncOptions()
    if ns.Kit then ns.Kit.Sync() end
end

SLASH_QUESTBEACON1 = "/beacon"
SLASH_QUESTBEACON2 = "/questbeacon"
SlashCmdList.QUESTBEACON = function(msg)
    if not db then return end
    local words = {}
    for word in (msg or ""):lower():gmatch("%S+") do words[#words + 1] = word end
    local cmd = words[1]

    if not cmd or cmd == "config" or cmd == "options" or cmd == "opt" then
        if HasKit() then ns.Kit.Open() end
    elseif cmd == "on" or cmd == "off" then
        ns.Set("enabled", cmd == "on")
        Print(cmd == "on" and "your group is told about quests that can't be shared."
            or "off: your group is not told.")
        SyncOptions()
    elseif cmd == "raid" or cmd == "raids" then
        ns.Set("where", db.where == "always" and "party" or "always")
        Print(db.where == "always" and "raids are told too." or "only parties are told, not raids.")
        SyncOptions()
    elseif cmd == "links" or cmd == "link" or cmd == "pin" then
        local want = not db.links
        if words[2] == "on" then want = true elseif words[2] == "off" then want = false end
        ns.Set("links", want)
        Print("map pin link in the line " .. (db.links and "on." or "off."))
        SyncOptions()
    elseif cmd == "follow" then
        if CHOICES.follow[words[2]] then
            ns.Set("follow", words[2])
            Print("when a group member calls a quest out you get " .. FOLLOW_WORDS[db.follow] .. ".")
            SyncOptions()
        else
            Print("/beacon follow off|pin|track (now: " .. db.follow .. ")")
        end
    elseif cmd == "test" then
        ns.Test()
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "reset" then
        ns.Reset()
        PrintStatus()
        SyncOptions()
    else
        PrintHelp()
    end
end
