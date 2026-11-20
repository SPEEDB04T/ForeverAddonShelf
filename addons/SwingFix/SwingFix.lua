--[[
    Swing Fix

    The game's own swing timer bars (Options > swing timer; Main Hand and Off
    Hand) start over the moment you begin casting a spell. The swing itself
    is held back while you cast and only starts over when the spell goes off,
    so the bar is wrong for the whole cast and for the swing after it.

    This addon corrects those two bars, and draws nothing of its own:
      - a restart that comes with the start of a cast is undone: the bar keeps
        counting the swing that was already running;
      - when the cast goes off, the bar starts a full swing from that moment;
      - a cast that is stopped or interrupted changes nothing.
    Instant spells and the Ranged bar are left alone.

    /swingfix          -> what it is doing
    /swingfix on|off   -> correct the bars, or leave them as the game draws them
    /swingfix log      -> keep a log of swings and casts in the saved file (on / off)
]]

local ADDON, ns = ...
ns = ns or {}

local PREFIX = "|cffffd100Swing Fix:|r "
local HANDS = {
    { frame = "SwingTimerMainHandFrame", speed = 1 },
    { frame = "SwingTimerOffHandFrame",  speed = 2 },
}
-- A bar restart this close before the cast event still belongs to that cast.
local START_WINDOW = 0.15
local LOG_MAX = 400

local defaults = { enabled = true, log = true }
local db = defaults

local bars = {}        -- [frame] = { speed, dur, endT, prevDur, prevEndT, at, last }
local cast             -- { guid, start } while a spell with a cast time is being cast
local applying = false -- true while this addon itself moves a bar
local counts = { undone = 0, restarted = 0 }

local function Plain(v)
    return not (issecretvalue and issecretvalue(v))
end

local function Log(what, a, b)
    if not db.log then return end
    local list = db.entries
    if type(list) ~= "table" then list = {}; db.entries = list end
    local function Text(v)
        if v == nil then return "" end
        if not Plain(v) then return "?" end
        return tostring(v)
    end
    list[#list + 1] = string.format("%.2f %s %s %s", GetTime(), what, Text(a), Text(b))
    while #list > LOG_MAX do table.remove(list, 1) end
end

-- Is the player still casting, as far as the game tells us? nil when unknown.
local function StillCasting()
    if not UnitCastingInfo then return nil end
    local ok, name = pcall(UnitCastingInfo, "player")
    if not ok then return nil end
    if not Plain(name) then return true end
    return name ~= nil
end

-- Puts a bar back on the swing it was counting (or empties it when that swing is over).
local function PutBack(frame, dur, endT, now)
    applying = true
    if dur and endT and endT - now > 0.05 then
        frame.swingDuration, frame.swingEndTime = dur, endT
        if frame.OnUpdate then
            frame:SetScript("OnUpdate", frame.OnUpdate)
            pcall(frame.OnUpdate, frame, 0)
        end
    else
        pcall(frame.ClearSwingTimer, frame)
    end
    applying = false
    counts.undone = counts.undone + 1
end

-- Runs after every restart the game gives a bar.
local function OnBarRestart(frame, duration)
    if applying then return end
    local bar = bars[frame]
    if not bar then return end
    if not Plain(duration) or type(duration) ~= "number" or duration <= 0 then return end
    local now = GetTime()

    if cast and StillCasting() == false then cast = nil end
    if cast and db.enabled then
        PutBack(frame, bar.dur, bar.endT, now)
        return
    end

    bar.prevDur, bar.prevEndT, bar.at = bar.dur, bar.endT, now
    bar.dur, bar.endT, bar.last = duration, now + duration, duration
end

local function HandSpeed(bar)
    if UnitAttackSpeed then
        local ok, main, off = pcall(UnitAttackSpeed, "player")
        if ok then
            local speed = bar.speed == 2 and off or main
            if Plain(speed) and type(speed) == "number" and speed > 0 then return speed end
        end
    end
    return bar.last
end

local function Handles(frame)
    if type(frame.ShouldHandleSwing) ~= "function" then return true end
    local ok, yes = pcall(frame.ShouldHandleSwing, frame)
    return ok and yes and true or false
end

local function CastStarted(guid)
    local now = GetTime()
    cast = { guid = guid, start = now }
    if not db.enabled then return end
    -- The game may have restarted the bars a moment before telling us about the cast.
    for frame, bar in pairs(bars) do
        if bar.at and now - bar.at <= START_WINDOW then
            bar.dur, bar.endT, bar.at = bar.prevDur, bar.prevEndT, nil
            PutBack(frame, bar.dur, bar.endT, now)
        end
    end
end

local function SameCast(guid)
    if not cast then return false end
    if guid == nil or cast.guid == nil then return true end
    if not Plain(guid) or not Plain(cast.guid) then return true end
    return guid == cast.guid
end

local function CastWentOff(guid)
    if not SameCast(guid) then return end
    cast = nil
    if not db.enabled then return end
    local now = GetTime()
    for frame, bar in pairs(bars) do
        local speed = HandSpeed(bar)
        if speed and Handles(frame) then
            applying = true
            local ok = pcall(frame.ResetSwingTimer, frame, speed)
            applying = false
            if ok then
                bar.dur, bar.endT, bar.at, bar.last = speed, now + speed, nil, speed
                counts.restarted = counts.restarted + 1
            end
        end
    end
end

local function CastEndedEarly(guid)
    if SameCast(guid) then cast = nil end
end

local function FindBars()
    local found = 0
    for _, hand in ipairs(HANDS) do
        local frame = _G[hand.frame]
        if type(frame) == "table" and type(frame.ResetSwingTimer) == "function" then
            if not bars[frame] then
                bars[frame] = { speed = hand.speed }
                hooksecurefunc(frame, "ResetSwingTimer", OnBarRestart)
            end
            found = found + 1
        end
    end
    return found
end

local function OnOff(v) return v and "on" or "off" end

local function Status()
    local found = 0
    for _ in pairs(bars) do found = found + 1 end
    print(PREFIX .. "correcting the swing bars is " .. OnOff(db.enabled) .. ", the log is " .. OnOff(db.log) .. ".")
    if found == 0 then
        print("  The game's swing timer bars were not found, so nothing is changed.")
    else
        local shown = true
        if GetCVarBool then
            local ok, value = pcall(GetCVarBool, "showSwingTimer")
            if ok then shown = value and true or false end
        end
        if not shown then
            print("  The game's swing timer is switched off in the game options.")
        end
        print(("  This session: %d restarts at the start of a cast undone, %d swings started at the end of a cast.")
            :format(counts.undone, counts.restarted))
    end
    print("  /swingfix on  -  /swingfix off  -  /swingfix log")
end

local function Slash(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        print(PREFIX .. (db.enabled
            and "the swing bars now start over when a cast goes off, not when it starts."
            or "off. The swing bars are as the game draws them."))
    elseif cmd == "log" then
        db.log = not db.log
        if not db.log then db.entries = nil end
        print(PREFIX .. "the log is " .. OnOff(db.log) .. ".")
    else
        Status()
    end
end

local f = CreateFrame("Frame")
ns.frame = f

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
}

local function OnEvent(_, event, a, b, c)
    if event == "PLAYER_SWING" then
        Log("SWING", a, b)
    elseif event == "UNIT_SPELLCAST_START" then
        if a ~= "player" then return end
        Log("START", c)
        CastStarted(b)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if a ~= "player" then return end
        Log(cast and SameCast(b) and "WENT_OFF" or "INSTANT", c)
        CastWentOff(b)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if a ~= "player" then return end
        if cast and SameCast(b) then Log(event:sub(16), c) end
        CastEndedEarly(b)
    elseif event == "UNIT_COMBAT" then
        -- Hits on the target, for the log only: shows when a swing really landed.
        if a == "target" and db.log and UnitAffectingCombat and UnitAffectingCombat("player") then
            Log("TARGET_HIT", b, c)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        cast = nil
        FindBars()
    elseif event == "ADDON_LOADED" then
        if a == ADDON then
            if type(SwingFixDB) ~= "table" then SwingFixDB = {} end
            db = SwingFixDB
            for k, v in pairs(defaults) do
                if db[k] == nil then db[k] = v end
            end
        elseif a == "Blizzard_SwingTimer" then
            FindBars()
        end
    elseif event == "PLAYER_LOGIN" then
        if FindBars() == 0 then
            print(PREFIX .. "the game's swing timer bars were not found, so nothing is changed.")
        end
    end
end

f:SetScript("OnEvent", function(self, event, ...)
    local ok, err = pcall(OnEvent, self, event, ...)
    if not ok and not ns.errorShown then
        ns.errorShown = true
        print(PREFIX .. "error: " .. tostring(err))
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(f.RegisterEvent, f, "PLAYER_SWING")
for _, event in ipairs(CAST_EVENTS) do
    if not (f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, event, "player")) then
        pcall(f.RegisterEvent, f, event)
    end
end
if not (f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, "UNIT_COMBAT", "target")) then
    pcall(f.RegisterEvent, f, "UNIT_COMBAT")
end

SLASH_SWINGFIX1 = "/swingfix"
SlashCmdList["SWINGFIX"] = Slash

ns.counts = counts
