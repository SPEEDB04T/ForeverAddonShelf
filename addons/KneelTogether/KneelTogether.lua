--[[
    Kneel Together
    One call, and everyone in the group who has the addon kneels on the same beat.

    How it works: the caller sends one hidden addon message to the group. Every
    client that hears it (the caller's own included) starts the same countdown
    and does the /kneel emote when it ends. Each client takes its own ping off
    the countdown, so the kneels reach the server together even when one player
    lags more than another.

    /kneelall               -> call the kneel (countdown from the options)
    /kneelall 5, now        -> with a 5 second countdown / right away
    /kneelall me            -> everyone kneels before you (you stay standing)
    /kneelall rise          -> everyone stands up again
    /kneelall cancel        -> call it off
    /kneelall check         -> who in the group has the addon
    /kneelall config        -> the options window
    /kneelall obey anyone|lead|off, /kneelall minimap, /kneelall reset
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cffd8a8ffKneel Together|r: "
local COMM = "KneelTogether"            -- addon message prefix (16 characters at most)
local MAX_DELAY = 10
local CALL_GAP = 2                      -- seconds between two calls from one player
local READY_AT = 0.7                    -- seconds before the kneel at which a mount is left

-- The only moves a call can ask for. Nothing else in a message is ever performed.
local MOVES = {
    K = { token = "KNEEL", word = "Kneel", done = "knelt" },
    S = { token = "STAND", word = "Rise", done = "stood up" },
}
local CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

local DEFAULTS = {
    delay    = 3,           -- countdown of my own calls, seconds
    before   = "target",    -- my calls: kneel before my target, or before "me"
    announce = false,       -- my calls: also one line in group chat
    obey     = "anyone",    -- whose calls I kneel for: anyone / lead / off
    dismount = true,        -- leave my mount before kneeling (never in the air)
    sound    = true,        -- a sound when a call comes in
}
local CHOICES = {
    before = { target = true, me = true },
    obey   = { anyone = true, lead = true, off = true },
}
local OBEY_WORDS = { anyone = "anyone in the group", lead = "the leader and assistants only", off = "nobody" }

-- Why someone did not do it, for the caller's summary.
local WHY = {
    moving = "was moving",
    off    = "ignores calls",
    rank   = "only kneels for the leader",
    locked = "emotes are locked there",
    fail   = "the game refused",
    out    = "sat it out",
    none   = "no answer, no addon?",
}

local db
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local issecret = issecretvalue

local VERSION = "1.0.5"
if C_AddOns and C_AddOns.GetAddOnMetadata then
    local ok, v = pcall(C_AddOns.GetAddOnMetadata, ADDON_NAME, "Version")
    if ok and type(v) == "string" and v ~= "" and not (issecret and issecret(v)) then VERSION = v end
end
ns.VERSION = VERSION

local function Print(msg) print(PREFIX .. tostring(msg)) end
ns.Print = Print

local function Plain(v)
    return v ~= nil and not (issecret and issecret(v))
end

-- Calls a game function that may be missing, may throw, or may hand back a
-- hidden value: the first two results, each nil unless it is readable.
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    if not Plain(a) then a = nil end
    if not Plain(b) then b = nil end
    return a, b
end

---------------------------------------------------------------------------
-- Names and the group
---------------------------------------------------------------------------
-- Names on this realm are two words ("First Last"), and the server spells the
-- realm in a sender ("CAMWOWUS1Realm9RPPvP") unlike GetNormalizedRealmName()
-- ("RPPvP"). So a sender is never compared as a string: it is looked up in the
-- group by name, the realm only breaks a tie (see pitfalls.md, "Who sent an
-- addon message").

-- A unit's name as the roster gives it: "First Last", or "First Last-Realm"
-- when the game gives a realm (another realm). The key for everything.
local function Key(unit)
    local name, realm = Ask(UnitName, unit)
    if type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function Me() return Key("player") end

local function InGroup() return Ask(IsInGroup) and true or false end

-- lower-case letters and digits only, for comparing realm spellings
local function Squeeze(s)
    return type(s) == "string" and s:lower():gsub("[^%w]", "") or ""
end

local function RealmAgrees(a, b)
    a, b = Squeeze(a), Squeeze(b)
    if a == "" or b == "" then return false end
    return a == b or a:sub(-#b) == b or b:sub(-#a) == a or a:sub(1, #b) == b or b:sub(1, #a) == a
end

local function MyRealmAgrees(realm)
    return RealmAgrees(realm, Ask(GetNormalizedRealmName)) or RealmAgrees(realm, Ask(GetRealmName))
end

local function IsMe(unit)
    return unit == "player" or Ask(UnitIsUnit, unit, "player") == true
end

local function GroupUnits()
    local units = {}
    if not InGroup() then
        units[1] = "player"
    elseif Ask(IsInRaid) then
        for i = 1, min(40, Ask(GetNumGroupMembers) or 0) do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, 4 do
            if Ask(UnitExists, "party" .. i) then units[#units + 1] = "party" .. i end
        end
    end
    return units
end

-- A sender or a name out of a message -> the group unit it is, or nil.
-- "First Last-Any Realm": the part before the first "-" is the name (space and
-- all); one group member with that name is the one, whatever the realm says.
local function UnitOf(full)
    if type(full) ~= "string" or full == "" then return nil end
    local who, realm = full:match("^(.-)%-(.*)$")
    if not who or who == "" then who, realm = full, nil end
    local hits = {}
    for _, unit in ipairs(GroupUnits()) do
        local name, urealm = Ask(UnitName, unit)
        if name == who then
            if type(urealm) ~= "string" or urealm == "" then urealm = nil end
            hits[#hits + 1] = { unit = unit, realm = urealm }
        end
    end
    if #hits <= 1 then return hits[1] and hits[1].unit end
    for _, hit in ipairs(hits) do                   -- the same name twice: the realm decides
        if realm then
            if hit.realm and RealmAgrees(hit.realm, realm) then return hit.unit end
            if not hit.realm and MyRealmAgrees(realm) then return hit.unit end
        elseif not hit.realm then
            return hit.unit
        end
    end
    return hits[1].unit
end

local function Ranked(unit)
    return Ask(UnitIsGroupLeader, unit) == true or Ask(UnitIsGroupAssistant, unit) == true
end

-- A player name out of a message: any letters, spaces kept ("First Last"),
-- an optional realm. No control characters, ";" or "|".
local function CleanName(name)
    if type(name) ~= "string" or #name > 80 then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or name:find("[%c;|]") then return nil end
    return name
end

---------------------------------------------------------------------------
-- What went over the wire, kept in the saved settings (last 40 lines), and
-- the senders that could not be found in the group
---------------------------------------------------------------------------
local LOG_SIZE = 40
local ignored = {}          -- [raw sender or "(hidden)"] = how many messages
ns.ignored = ignored

local function Stamp()
    local s = Ask(date, "%H:%M:%S")
    if type(s) == "string" then return s end
    return ("%.1f"):format(Ask(GetTime) or 0)
end

local function Log(dir, channel, sender, who, code, msg)
    if not (db and type(db.commLog) == "table") then return end
    local log = db.commLog
    log[#log + 1] = {
        at = Stamp(), dir = dir, channel = tostring(channel or "-"), sender = tostring(sender or "-"),
        unit = tostring(who or "-"), code = tostring(code == nil and "-" or code),
        msg = type(msg) == "string" and msg:sub(1, 40) or "(hidden)",
    }
    while #log > LOG_SIZE do table.remove(log, 1) end
end

---------------------------------------------------------------------------
-- Messages out
---------------------------------------------------------------------------
local function Channel()
    if not InGroup() then return nil end
    if LE_PARTY_CATEGORY_INSTANCE and LE_PARTY_CATEGORY_HOME
        and Ask(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) and not Ask(IsInGroup, LE_PARTY_CATEGORY_HOME) then
        return "INSTANCE_CHAT"
    end
    if Ask(IsInRaid) then return "RAID" end
    return "PARTY"
end

local function ChatLocked()
    if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then return false end
    local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
    return ok and ((issecret and issecret(v)) or v) and true or false
end

-- The realm's own switch for chat sent by addons. It is on for ordinary realms
-- and says nothing about addon messages inside a group, so it never stops a
-- call: it is only mentioned when the game has refused a message anyway.
local function RealmRestricts()
    return Ask(C_ChatInfo and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted) == true
end

-- What SendAddonMessage hands back when it does not send (0 is "sent").
local HELD = "the game is holding messages back, try again in a moment"
local REFUSED = {
    [3] = HELD,                                     -- too many addon messages
    [8] = HELD,                                     -- too many on this channel
    [5] = "the game says you are not in a group",
    [11] = "the game locks addon messages here right now (a boss fight, usually)",
}

local function Send(msg)
    local channel = Channel()
    if not channel then return false, "you are not in a group" end
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false, "this client has no addon messages" end
    if ChatLocked() then
        Log("out", channel, nil, nil, "chat locked", msg)
        return false, "the game locks chat here right now (a boss fight, usually)"
    end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, COMM, msg, channel)
    Log("out", channel, nil, nil, not ok and "error" or (Plain(result) and result or "hidden"), msg)
    if not ok then return false, "the game refused the message" end
    if not Plain(result) or result == 0 or result == true then return true end
    if REFUSED[result] then return false, REFUSED[result] end
    local why = "the game refused the message (code " .. tostring(result) .. ")"
    if RealmRestricts() then why = why .. "; this realm reports that it limits addon chat" end
    return false, why
end

---------------------------------------------------------------------------
-- The banner in the middle of the screen
---------------------------------------------------------------------------
-- A copy of the game's zone name, ZoneTextFrame (Blizzard_FrameXML/Mainline/
-- ZoneText.xml and ZoneText.lua): a 128x128 frame at TOP 0,-128, strata LOW,
-- the name in ZoneTextFont centred on it (512 wide, ARTWORK), the line under it
-- in PVPInfoTextFont coloured like the name, no backdrop, and the zone name's
-- fade: 0.5 s in, hold, 2 s out (FadingFrame.lua). Kneeling happens standing
-- still, so a real zone name and this one do not meet.
local banner
local FADE_IN, FADE_OUT = 0.5, 2.0      -- ZoneFadeInDuration, ZoneFadeOutDuration

local function Font(fs, name, fallback)
    local obj = _G[name] or _G[fallback]
    if obj then pcall(fs.SetFontObject, fs, obj) end
end

local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end

-- FadingFrame_OnUpdate, with the hold that can be moved while it is up.
local function Fade(b)
    local elapsed = Now() - b.start
    if elapsed < FADE_IN then
        b:SetAlpha(elapsed / FADE_IN)
    elseif elapsed < FADE_IN + b.hold then
        b:SetAlpha(1)
    elseif elapsed < FADE_IN + b.hold + FADE_OUT then
        b:SetAlpha(1 - (elapsed - FADE_IN - b.hold) / FADE_OUT)
    else
        b:Hide()
    end
end

local function Banner()
    if banner then return banner end
    local b = CreateFrame("Frame", "KneelTogetherBanner", UIParent)
    b:SetSize(128, 128)
    b:SetPoint("TOP", UIParent, "TOP", 0, -128)
    b:SetFrameStrata("LOW")
    pcall(b.SetToplevel, b, true)
    b:EnableMouse(false)
    b.big = b:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    Font(b.big, "ZoneTextFont", "GameFontNormalHuge")
    b.big:SetWidth(512)
    b.big:SetPoint("CENTER", b, "CENTER")
    b.small = b:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    Font(b.small, "PVPInfoTextFont", "GameFontNormalLarge")
    b.small:SetWidth(512)
    b.small:SetPoint("TOP", b.big, "BOTTOM")
    -- the game colours the line under a zone name like the name itself
    local ok, r, g, bl = pcall(b.big.GetTextColor, b.big)
    if ok and type(r) == "number" then b.small:SetTextColor(r, g, bl) end
    b.start, b.hold = 0, 0
    b:SetScript("OnUpdate", Fade)
    b:Hide()
    banner = b
    return b
end

-- seconds: starts to fade after that long (nil: stays until the next line).
-- A new line while it is up only changes the words, as zone text does; once it
-- is fading out (or gone) it fades in again.
local function Show(big, small, seconds)
    local b = Banner()
    local now = Now()
    if not b:IsShown() or now - b.start >= FADE_IN + b.hold then
        b.start = now
        b:SetAlpha(0)
        b:Show()
    end
    b.hold = seconds and math.max(0, now + seconds - b.start - FADE_IN) or math.huge
    b.big:SetText(big or "")
    b.small:SetText(small or "")
    b.bigText, b.smallText = big or "", small or ""       -- what it says, for /kneelall status and the tests
end

-- The game's red error line at the top of the screen, for "you cannot do that".
local function Error(text)
    local f = UIErrorsFrame
    if not f then return end
    if f.AddExternalErrorMessage then
        pcall(f.AddExternalErrorMessage, f, text)
    elseif f.AddMessage then
        local c = RED_FONT_COLOR
        pcall(f.AddMessage, f, text, c and c.r or 1, c and c.g or 0.1, c and c.b or 0.1)
    end
end

-- For LookShots (a screenshot helper on the developer's machine; nothing happens
-- without it): the banner is shot the first time it shows in each version. Its
-- frame is 128x128 like ZoneTextFrame while the text is 512 wide, hence the pad.
LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["KneelTogether"] = {
    version = VERSION,
    frames = {
        { label = "countdown banner", frame = function() return banner end, pad = 200 },
    },
}

function ns.BannerText()
    if not (banner and banner:IsShown()) or Now() - banner.start >= FADE_IN + banner.hold then return nil end
    return banner.bigText, banner.smallText
end

---------------------------------------------------------------------------
-- Doing the move
---------------------------------------------------------------------------
local pending           -- the call this client is counting down to
local myCalls = {}      -- [id] = my own calls whose answers are still coming in
local roll              -- my own roll call, while the answers come in
local lastCallAt, lastHereAt
local driver = CreateFrame("Frame")

local function Answer(call, result)
    if InGroup() then Send("A;" .. call.id .. ";" .. result) end
end

local function Sub(call)
    local line = call.mine and "your call" or ("called by " .. call.caller)
    if call.toward then
        line = line .. ", before " .. (call.forMe and "you" or call.toward)
    end
    return line
end

local function Try(fn, token, target)
    local ok, success = pcall(fn, token, target, true)
    if not ok then return false end
    if Plain(success) and success == false then return false end
    return true
end

local function Emote(token, toward)
    local fn = (C_ChatInfo and C_ChatInfo.PerformEmote) or DoEmote
    if type(fn) ~= "function" then return false end
    -- with a name: "kneels before <name>". If the game cannot find that
    -- player, the plain emote (which uses my own target, like /kneel).
    if toward and Try(fn, token, toward) then return true end
    return Try(fn, token, nil)
end

-- A little before the kneel: get off the mount, so the kneel shows.
local function Ready(call)
    if call.move ~= "K" or call.forMe or not db.dismount then return end
    if Ask(IsMounted) and not Ask(IsFlying) then pcall(Dismount) end
end

local function Perform(call)
    local move = MOVES[call.move]
    if call.forMe then
        Show("They kneel before you", Sub(call), 3)
        Answer(call, "target")
        return
    end
    local result
    if ChatLocked() then
        result = "locked"
    else
        local moving = (Ask(GetUnitSpeed, "player") or 0) > 0
        result = Emote(move.token, call.toward) and (moving and "moving" or "ok") or "fail"
    end
    Show(move.word .. "!", Sub(call), 2.5)
    if result ~= "ok" and result ~= "moving" then
        Error("The game would not let you " .. move.word:lower() .. ": type /" .. move.token:lower())
    end
    Answer(call, result)
end

local function Tick()
    local call = pending
    if not call then
        driver:SetScript("OnUpdate", nil)
        return
    end
    local left = call.fireAt - GetTime()
    if left <= READY_AT and not call.readied then
        call.readied = true
        Ready(call)
    end
    if left > 0 then
        local n = ceil(left - 0.001)
        if n ~= call.shown then
            call.shown = n
            Show(MOVES[call.move].word .. " in " .. n, Sub(call))
        end
        return
    end
    pending = nil
    driver:SetScript("OnUpdate", nil)
    Perform(call)
end

-- This client's ping in seconds, taken off the countdown.
local function Lag()
    if type(GetNetStats) ~= "function" then return 0 end
    local ok, _, _, home, world = pcall(GetNetStats)
    if not ok then return 0 end
    local ms = (Plain(world) and type(world) == "number" and world > 0 and world)
        or (Plain(home) and type(home) == "number" and home > 0 and home) or 0
    return min(500, ms) / 1000
end

-- from: the caller's roster name; unit: their group unit (nil for my own calls).
local function StartCall(from, id, moveKey, delay, toward, mine, unit)
    if mine then
        local own = myCalls[id]
        if own then
            if own.heard then return end            -- already started (the echo and the fallback both get here)
            own.heard = true
        end
    else
        if not unit then return end
        if db.obey == "off" then
            Send("A;" .. id .. ";off")
            return
        end
        if db.obey == "lead" and not Ranked(unit) then
            Send("A;" .. id .. ";rank")
            return
        end
    end
    local call = { id = id, caller = from, move = moveKey, mine = mine }
    if moveKey == "K" and toward then
        -- my own roster's spelling of that player; someone outside the group keeps the name sent
        local towardUnit = UnitOf(toward)
        call.toward = (towardUnit and Key(towardUnit)) or toward
        call.forMe = towardUnit ~= nil and IsMe(towardUnit)
    end
    call.fireAt = GetTime() + max(0, delay - (delay >= 1 and Lag() or 0))
    pending = call
    if db.sound and type(PlaySound) == "function" then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.READY_CHECK) or 8960)
    end
    driver:SetScript("OnUpdate", Tick)
    Tick()
end

---------------------------------------------------------------------------
-- Messages in
---------------------------------------------------------------------------
local function OnCall(from, unit, rest)
    local id, moveKey, delay, toward = rest:match("^(%w+);(%a);(%d+);(.*)$")
    if not id or not MOVES[moveKey] then return end
    delay = min(MAX_DELAY, tonumber(delay) or 0)
    local mine = IsMe(unit)
    StartCall(from, id, moveKey, delay, CleanName(toward), mine, not mine and unit or nil)
end

local function OnCancel(from, id)
    if pending and pending.id == id and pending.caller == from then
        pending = nil
        driver:SetScript("OnUpdate", nil)
        Show("Called off", from .. " cancelled it", 2)
    end
end

local function OnAnswer(from, rest)
    local id, result = rest:match("^(%w+);(%a+)$")
    local call = id and myCalls[id]
    if call then call.answers[from] = result end
end

local function OnRollCall()
    local now = GetTime()
    if lastHereAt and now - lastHereAt < 3 then return end
    lastHereAt = now
    Send("H;" .. VERSION .. ";" .. db.obey)
end

local function OnHere(from, rest)
    if not roll then return end
    local version, obey = rest:match("^([%w%.%-]+);(%a+)$")
    if version then roll.have[from] = { version = version, obey = obey } end
end

local function Ignore(sender, why)
    ignored[sender] = ignored[sender] or { count = 0 }
    ignored[sender].count = ignored[sender].count + 1
    ignored[sender].why = why
end

local function OnMessage(prefix, msg, channel, sender)
    if not Plain(prefix) or prefix ~= COMM then return end
    if not (Plain(msg) and Plain(channel)) then
        Log("in", Plain(channel) and channel, Plain(sender) and sender or "(hidden)", nil, "unreadable", nil)
        return
    end
    if type(msg) ~= "string" or not CHANNELS[channel] then return end
    if not Plain(sender) or type(sender) ~= "string" or sender == "" then
        Ignore("(hidden)", "the game hid who sent it")
        Log("in", channel, "(hidden)", "nobody", nil, msg)
        return
    end
    local unit = UnitOf(sender)
    local from = unit and Key(unit)
    Log("in", channel, sender, from or "nobody", nil, msg)
    if not from then
        Ignore(sender, "not found in the group")
        return
    end
    local kind, rest = msg:match("^(%a);?(.*)$")
    if kind == "C" then OnCall(from, unit, rest)
    elseif kind == "X" then OnCancel(from, rest)
    elseif kind == "A" then OnAnswer(from, rest)
    elseif kind == "Q" then OnRollCall()
    elseif kind == "H" then OnHere(from, rest)
    end
end

---------------------------------------------------------------------------
-- Calling
---------------------------------------------------------------------------
local function List(names, limit)
    limit = limit or 8
    if #names <= limit then return table.concat(names, ", ") end
    local shown = {}
    for i = 1, limit do shown[i] = names[i] end
    return table.concat(shown, ", ") .. " and " .. (#names - limit) .. " more"
end

-- A couple of seconds after the kneel: who did it and who did not.
local function Summary(call)
    local move = MOVES[call.move]
    local did, total, didnt = 0, 0, {}
    for _, unit in ipairs(GroupUnits()) do
        local name = Key(unit)
        if name and name ~= call.toward then
            total = total + 1
            local result = call.answers[name]
            if result == "ok" then
                did = did + 1
            elseif not result and Ask(UnitIsConnected, unit) == false then
                didnt[#didnt + 1] = name .. " (offline)"
            else
                didnt[#didnt + 1] = name .. " (" .. (WHY[result] or WHY.none) .. ")"
            end
        end
    end
    local line = did .. " of " .. total .. " " .. move.done
    if call.toward then line = line .. " before " .. call.toward end
    line = line .. "."
    if #didnt > 0 then line = line .. " Not: " .. List(didnt) .. "." end
    Print(line)
end

local function Announce(moveKey, delay, toward)
    if not db.announce then return end
    local channel = Channel()
    local fn = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not channel or type(fn) ~= "function" then return end
    local text = MOVES[moveKey].word
    if toward then text = text .. " before " .. toward end
    text = text .. (delay > 0 and (" in " .. delay .. "!") or " now!")
    pcall(fn, text, channel)
end

local idCount = 0
local function NewId()
    idCount = idCount + 1
    return ("%x%x"):format(math.random(0, 0xFFFFF), idCount % 256)
end

-- moveKey "K" (kneel) or "S" (rise); delay and before default to the settings.
function ns.Call(moveKey, delay, before)
    if not db then return end
    if not MOVES[moveKey] then moveKey = "K" end
    delay = max(0, min(MAX_DELAY, floor(tonumber(delay) or db.delay)))
    before = CHOICES.before[before] and before or db.before
    local now = GetTime()
    if lastCallAt and now - lastCallAt < CALL_GAP then
        Print("one call at a time: give it a moment.")
        return
    end

    -- sent as UnitName gives it: "First Last", plus the realm only when the game gives one
    local toward
    if moveKey == "K" then
        if before == "me" then
            toward = Key("player")
        elseif Ask(UnitExists, "target") and Ask(UnitIsPlayer, "target") then
            toward = Key("target")
        end
    end
    toward = CleanName(toward)
    local id = NewId()

    if not InGroup() then
        lastCallAt = now
        Print("you are not in a group, so this is only you.")
        StartCall(Me(), id, moveKey, delay, toward, true)
        return
    end

    -- Noted before it is sent: the call and the first answers can come back at once.
    local call = { id = id, move = moveKey, answers = {}, toward = moveKey == "K" and toward or nil }
    myCalls[id] = call
    local ok, why = Send(("C;%s;%s;%d;%s"):format(id, moveKey, delay, toward or ""))
    if not ok then
        myCalls[id] = nil
        Print("could not call it: " .. why .. ".")
        return
    end
    lastCallAt = now
    Announce(moveKey, delay, call.toward)
    if C_Timer and C_Timer.After then
        -- The call normally comes back to me like to everyone else, and I start
        -- on that. If it has not after a moment, start anyway.
        C_Timer.After(1.5, function()
            if myCalls[id] == call and not call.heard then
                StartCall(Me(), id, moveKey, max(0, delay - 1.5), toward, true)
            end
        end)
        C_Timer.After(delay + 2.5, function()
            if myCalls[id] == call then
                myCalls[id] = nil
                Summary(call)
            end
        end)
    end
end

function ns.Cancel()
    local call = pending
    if not call then
        Print("nothing to call off.")
        return
    end
    pending = nil
    driver:SetScript("OnUpdate", nil)
    if call.mine then
        myCalls[call.id] = nil
        Show("Called off", "your call", 2)
        if InGroup() then
            Send("X;" .. call.id)
            Print("called off for everyone.")
        end
    else
        Answer(call, "out")
        Show("Called off", "you sit this one out", 2)
    end
end

function ns.RollCall()
    if not db then return end
    if not InGroup() then
        Print("you are not in a group.")
        return
    end
    local mine, earlier = { have = {} }, roll
    roll = mine                                     -- before it is sent: answers can come back at once
    local ok, why = Send("Q")
    if not ok then
        roll = earlier
        Print("could not ask: " .. why .. ".")
        return
    end
    Print("asking who has the addon...")
    if C_Timer and C_Timer.After then
        C_Timer.After(2.5, function()
            if roll ~= mine then return end
            roll = nil
            local have, without = {}, {}
            for _, unit in ipairs(GroupUnits()) do
                local name = Key(unit)
                local entry = name and mine.have[name]
                if entry then
                    local note = entry.obey == "off" and " (ignores calls)"
                        or entry.obey == "lead" and " (leader's calls only)" or ""
                    have[#have + 1] = name .. note
                elseif name then
                    without[#without + 1] = name
                end
            end
            Print("has the addon (" .. #have .. "): " .. (#have > 0 and List(have, 20) or "nobody") .. ".")
            if #without > 0 then Print("no answer (" .. #without .. "): " .. List(without, 20) .. ".") end
        end)
    end
end

function ns.Pending() return pending end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function InitDB()
    if type(KneelTogetherDB) ~= "table" then KneelTogetherDB = {} end
    db = KneelTogetherDB
    for key, value in pairs(DEFAULTS) do
        if type(db[key]) ~= type(value) or (CHOICES[key] and not CHOICES[key][db[key]]) then db[key] = value end
    end
    db.delay = max(0, min(MAX_DELAY, floor(db.delay)))
    if type(db.commLog) ~= "table" then db.commLog = {} end
    while #db.commLog > LOG_SIZE do table.remove(db.commLog, 1) end
    ns.db = db
end

function ns.Set(key, value)
    if not db or DEFAULTS[key] == nil then return end
    if type(value) ~= type(DEFAULTS[key]) then return end
    if CHOICES[key] and not CHOICES[key][value] then return end
    if key == "delay" then value = max(0, min(MAX_DELAY, floor(value + 0.5))) end
    db[key] = value
end

function ns.Reset()
    for key, value in pairs(DEFAULTS) do db[key] = value end
    db.minimap = nil
    if ns.Kit then ns.Kit.RefreshMinimap() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("CHAT_MSG_ADDON")

f:SetScript("OnEvent", function(_, event, a, b, c, d)
    if event == "ADDON_LOADED" then
        if a == ADDON_NAME then
            InitDB()
            if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
                pcall(C_ChatInfo.RegisterAddonMessagePrefix, COMM)
            end
            if ns.Kit and ns.Options then           -- options window and minimap button
                local ok, err = pcall(ns.Options.Init)
                if not ok then Print("options error: " .. tostring(err)) end
            end
        end
        return
    end
    if not db then return end

    if event == "CHAT_MSG_ADDON" then
        local ok, err = pcall(OnMessage, a, b, c, d)
        if not ok and not ns.messageError then
            ns.messageError = tostring(err)         -- shown once by /kneelall status
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not db.welcomed then
            db.welcomed = true
            Print("loaded. /kneelall makes everyone in your group who has the addon kneel on the same beat. "
                .. "/kneelall config opens the options.")
        end
    end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function PrintStatus()
    Print("countdown " .. (db.delay == 0 and "none" or (db.delay .. " s"))
        .. "  |  kneel before " .. (db.before == "me" and "me" or "my target")
        .. "  |  group chat line " .. (db.announce and "on" or "off")
        .. "  |  I kneel for " .. OBEY_WORDS[db.obey])
    if ns.messageError then Print("a message could not be read: " .. ns.messageError) end
    for sender, entry in pairs(ignored) do
        Print(entry.count .. " message" .. (entry.count == 1 and "" or "s") .. " from " .. sender
            .. " ignored: " .. entry.why .. ".")
    end
    local log = db.commLog or {}
    if #log > 0 then
        Print("last addon messages (all " .. #log .. " are saved in KneelTogetherDB.commLog):")
        local function Safe(s) return (tostring(s):gsub("|", "||")) end     -- no chat codes from a message
        for i = max(1, #log - 4), #log do
            local e = log[i]
            if e.dir == "out" then
                print(("  %s out %s: %s (result %s)"):format(e.at, e.channel, Safe(e.msg), e.code))
            else
                print(("  %s in %s from %s = %s: %s"):format(e.at, e.channel, Safe(e.sender), Safe(e.unit), Safe(e.msg)))
            end
        end
    end
end

local function PrintHelp()
    Print("commands:")
    print("  /kneelall (call the kneel)   -  /kneelall 5 or now (countdown)   -  /kneelall me (before you)")
    print("  /kneelall rise   -  /kneelall cancel   -  /kneelall check (who has the addon)")
    print("  /kneelall config   -  /kneelall obey anyone|lead|off   -  /kneelall minimap   -  /kneelall reset")
end

-- Kit.lua and Options.lua sit next to this file. If a /reload ran this file without them
-- (files added by an update only load after a full restart), say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    Print("the options window and the minimap button appear after you restart the game once.")
    return false
end

local function SyncOptions()
    if ns.Kit then ns.Kit.Sync() end
end

local RISE = { rise = true, up = true, stand = true }

SLASH_KNEELTOGETHER1 = "/kneelall"
SLASH_KNEELTOGETHER2 = "/kneeltogether"
SlashCmdList.KNEELTOGETHER = function(msg)
    if not db then return end
    local words = {}
    for word in (msg or ""):lower():gmatch("%S+") do words[#words + 1] = word end
    local cmd = words[1]

    if cmd == "help" or cmd == "?" then
        PrintHelp()
    elseif cmd == "status" then
        PrintStatus()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if HasKit() then ns.Kit.Open() end
    elseif cmd == "minimap" then
        if not HasKit() then return end
        ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
        Print("minimap button " .. (ns.Kit.MinimapShown() and "on" or "off") .. ".")
        SyncOptions()
    elseif cmd == "reset" then
        ns.Reset()
        PrintStatus()
        SyncOptions()
    elseif cmd == "obey" then
        if CHOICES.obey[words[2]] then
            ns.Set("obey", words[2])
            Print("you now kneel for " .. OBEY_WORDS[db.obey] .. ".")
            SyncOptions()
        else
            Print("/kneelall obey anyone|lead|off (now: " .. db.obey .. ")")
        end
    elseif cmd == "cancel" or cmd == "stop" then
        ns.Cancel()
    elseif cmd == "check" or cmd == "who" then
        ns.RollCall()
    else
        -- a call: any mix of "rise", "me", "now" and a number of seconds
        local moveKey, delay, before = "K", nil, nil
        for _, word in ipairs(words) do
            if RISE[word] then moveKey = "S"
            elseif word == "kneel" then moveKey = "K"
            elseif word == "me" then before = "me"
            elseif word == "target" then before = "target"
            elseif word == "now" then delay = 0
            elseif tonumber(word) then delay = tonumber(word)
            else
                PrintHelp()
                return
            end
        end
        ns.Call(moveKey, delay, before)
    end
end
