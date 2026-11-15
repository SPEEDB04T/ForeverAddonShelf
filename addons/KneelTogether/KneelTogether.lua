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

local VERSION = "1.0.2"
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
-- "Name-MyRealm" -> "Name"; players from other realms keep their realm.
local function Short(name)
    if type(name) ~= "string" or name == "" then return nil end
    local short = Ask(Ambiguate, name, "none")
    if type(short) == "string" and short ~= "" then return short end
    return name
end

local function FullName(unit)
    local name, realm = Ask(UnitFullName, unit)
    if type(name) ~= "string" or name == "" then
        name, realm = Ask(UnitName, unit)
    end
    if type(name) ~= "string" or name == "" then return nil end
    if type(realm) ~= "string" or realm == "" then realm = Ask(GetNormalizedRealmName) end
    if type(realm) == "string" and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function ShortOf(unit) return Short(FullName(unit)) end
local function Me() return ShortOf("player") end

local function InGroup() return Ask(IsInGroup) and true or false end

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

local function UnitOf(short)
    for _, unit in ipairs(GroupUnits()) do
        if ShortOf(unit) == short then return unit end
    end
end

local function Ranked(unit)
    return Ask(UnitIsGroupLeader, unit) == true or Ask(UnitIsGroupAssistant, unit) == true
end

-- A player name out of a message: letters (any alphabet), an optional realm.
local function CleanName(name)
    if type(name) ~= "string" or name == "" or #name > 80 then return nil end
    if name:find("[%c%s;|]") then return nil end
    return name
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
    if ChatLocked() then return false, "the game locks chat here right now (a boss fight, usually)" end
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, COMM, msg, channel)
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
-- Built like the game's own zone name (ZoneText.xml): the big line in the zone
-- name font and colour, the line under it in the game's white, no backdrop, and
-- a short fade at the end the way a zone name goes.
local banner
local FADE = 0.6

local function Font(fs, name, fallback)
    local obj = _G[name] or _G[fallback]
    if obj then pcall(fs.SetFontObject, fs, obj) end
end

local function Banner()
    if banner then return banner end
    local b = CreateFrame("Frame", "KneelTogetherBanner", UIParent)
    b:SetSize(512, 96)
    b:SetPoint("TOP", UIParent, "TOP", 0, -170)
    b:SetFrameStrata("HIGH")
    b:EnableMouse(false)
    b.big = b:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    Font(b.big, "ZoneTextFont", "GameFontNormalHuge")
    b.big:SetWidth(512)
    b.big:SetPoint("TOP", b, "TOP", 0, 0)
    b.small = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    Font(b.small, "GameFontHighlightLarge", "GameFontHighlight")
    b.small:SetWidth(512)
    b.small:SetPoint("TOP", b.big, "BOTTOM", 0, -4)
    -- the fade; without animations (or in the tests) it simply hides
    local ok, group = pcall(b.CreateAnimationGroup, b)
    if ok and type(group) == "table" and group.CreateAnimation then
        local ok2, alpha = pcall(group.CreateAnimation, group, "Alpha")
        if ok2 and type(alpha) == "table" and alpha.SetFromAlpha then
            alpha:SetFromAlpha(1)
            alpha:SetToAlpha(0)
            alpha:SetDuration(FADE)
            group:SetScript("OnFinished", function() b:Hide(); b:SetAlpha(1) end)
            b.fade = group
        end
    end
    b.stamp = 0
    b:Hide()
    banner = b
    return b
end

local function Hide(b)
    b.hiding = true
    if b.fade then b.fade:Play() else b:Hide() end
end

-- seconds: hide by itself after that long (nil: stays until the next line).
local function Show(big, small, seconds)
    local b = Banner()
    if b.fade and b.fade.IsPlaying and b.fade:IsPlaying() then b.fade:Stop() end
    b.hiding = nil
    b:SetAlpha(1)
    b.big:SetText(big or "")
    b.small:SetText(small or "")
    b:Show()
    b.stamp = b.stamp + 1
    b.bigText, b.smallText = big or "", small or ""       -- what it says, for /kneelall status and the tests
    if seconds and C_Timer and C_Timer.After then
        local stamp = b.stamp
        C_Timer.After(seconds, function()
            if b.stamp == stamp then Hide(b) end
        end)
    end
end

function ns.BannerText()
    if not (banner and banner:IsShown()) or banner.hiding then return nil end
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
    if result == "ok" or result == "moving" then
        Show(move.word .. "!", Sub(call), 2.5)
    else
        Show(move.word .. "!", "the game would not let you: type /" .. move.token:lower(), 4)
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

local function StartCall(from, id, moveKey, delay, toward, mine)
    if mine then
        local own = myCalls[id]
        if own then
            if own.heard then return end            -- already started (the echo and the fallback both get here)
            own.heard = true
        end
    else
        local unit = UnitOf(from)
        if not unit then return end                 -- not someone in my group
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
        call.toward = Short(toward)
        call.forMe = call.toward ~= nil and call.toward == Me()
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
local function OnCall(from, rest)
    local id, moveKey, delay, toward = rest:match("^(%w+);(%a);(%d+);(.*)$")
    if not id or not MOVES[moveKey] then return end
    delay = min(MAX_DELAY, tonumber(delay) or 0)
    StartCall(from, id, moveKey, delay, CleanName(toward), from == Me())
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

local function OnMessage(prefix, msg, channel, sender)
    if not (Plain(prefix) and Plain(msg) and Plain(channel) and Plain(sender)) then return end
    if prefix ~= COMM or type(msg) ~= "string" or not CHANNELS[channel] then return end
    local from = Short(sender)
    if not from then return end
    local kind, rest = msg:match("^(%a);?(.*)$")
    if kind == "C" then OnCall(from, rest)
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
        local name = ShortOf(unit)
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

    local toward
    if moveKey == "K" then
        if before == "me" then
            toward = FullName("player")
        elseif Ask(UnitExists, "target") and Ask(UnitIsPlayer, "target") then
            toward = FullName("target")
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
    local call = { id = id, move = moveKey, answers = {}, toward = moveKey == "K" and Short(toward) or nil }
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
                local name = ShortOf(unit)
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
