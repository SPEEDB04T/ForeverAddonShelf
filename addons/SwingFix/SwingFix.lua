--[[
    Swing Fix

    The game's own swing timer bars (Main Hand and Off Hand) only start when a
    swing happens and then count the swing time they were given. Everything
    that moves your next swing after that is ignored, so the bar is often
    wrong. This addon keeps those two bars right, and draws nothing of its own:

      - Casting: a spell with a cast time starts your swing over when it goes
        off. The bar starts a full swing at that moment (the game shows
        nothing until the next hit). A cast you stop changes nothing.
      - Parry: when you parry, your next swing comes sooner (40% of the swing
        time, never below the last 20%). The bar jumps forward.
      - Attack speed: when your attack speed changes in the middle of a swing
        (Flurry, a haste effect ending), the rest of the swing is stretched or
        shortened to match.

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
local PARRY_CUT, PARRY_FLOOR = 0.4, 0.2
local LOG_MAX = 400

local defaults = { enabled = true, log = true }
local db = defaults

local bars = {}        -- [frame] = { speed, dur, endT, last, speedAt }
local cast             -- { guid } while a spell with a cast time is being cast
local applying = false -- true while this addon itself moves a bar
local counts = { restarted = 0, parries = 0, rescaled = 0 }
local afterCast        -- { at, speed } from a cast going off until the next main hand swing

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

-- The swing time of a bar's hand right now; the last one the game gave when it can't be read.
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

-- Seconds left on the swing a bar is counting, nil when it counts none.
local function Left(bar, now)
    local left = bar.endT and bar.endT - now
    if left and left > 0 then return left end
end

-- Shows on the game's bar what we now know about the swing it is counting.
local function Move(frame, bar, now)
    if frame.swingDuration == nil then return end   -- the game is not showing a swing on it
    applying = true
    if bar.endT - now > 0.05 then
        frame.swingDuration, frame.swingEndTime = bar.dur, bar.endT
        if frame.OnUpdate then
            frame:SetScript("OnUpdate", frame.OnUpdate)
            pcall(frame.OnUpdate, frame, 0)
        end
    else
        pcall(frame.ClearSwingTimer, frame)
    end
    applying = false
end

-- Runs after every restart the game gives a bar: a swing happened.
local function OnBarRestart(frame, duration)
    if applying then return end
    local bar = bars[frame]
    if not bar then return end
    if not Plain(duration) or type(duration) ~= "number" or duration <= 0 then return end
    bar.dur, bar.endT, bar.last = duration, GetTime() + duration, duration
    bar.speedAt = HandSpeed(bar)
end

local function Handles(frame)
    if type(frame.ShouldHandleSwing) ~= "function" then return true end
    local ok, yes = pcall(frame.ShouldHandleSwing, frame)
    return ok and yes and true or false
end

local function SameCast(guid)
    if not cast then return false end
    if guid == nil or cast.guid == nil then return true end
    if not Plain(guid) or not Plain(cast.guid) then return true end
    return guid == cast.guid
end

-- A spell with a cast time went off: every hand starts a full swing now.
local function CastWentOff(guid)
    if not SameCast(guid) then return end
    cast = nil
    local now = GetTime()
    afterCast = { at = now }
    for _, bar in pairs(bars) do
        if bar.speed == 1 then afterCast.speed = HandSpeed(bar) end
    end
    if not db.enabled then return end
    for frame, bar in pairs(bars) do
        local speed = HandSpeed(bar)
        if speed and Handles(frame) then
            applying = true
            local ok = pcall(frame.ResetSwingTimer, frame, speed)
            applying = false
            if ok then
                bar.dur, bar.endT, bar.last, bar.speedAt = speed, now + speed, speed, speed
                counts.restarted = counts.restarted + 1
            end
        end
    end
end

-- You parried: the swing that is due first comes sooner.
local function Parried()
    if not db.enabled then return end
    local now = GetTime()
    local first, firstFrame, firstLeft
    for frame, bar in pairs(bars) do
        local left = Left(bar, now)
        if left and (not firstLeft or left < firstLeft) then
            first, firstFrame, firstLeft = bar, frame, left
        end
    end
    if not first then return end
    local floor = PARRY_FLOOR * first.dur
    if firstLeft <= floor + 0.01 then return end
    local left = math.max(firstLeft - PARRY_CUT * first.dur, floor)
    first.endT = now + left
    counts.parries = counts.parries + 1
    Log("PARRY_HASTE", string.format("%.2f", firstLeft), string.format("%.2f", left))
    Move(firstFrame, first, now)
end

-- Your attack speed changed: what is left of a running swing changes with it.
local function SpeedChanged()
    if not db.enabled then return end
    local now = GetTime()
    for frame, bar in pairs(bars) do
        local speed = HandSpeed(bar)
        local old = bar.speedAt
        if speed and old and old > 0 and math.abs(speed - old) > 0.005 then
            bar.speedAt = speed
            local left = Left(bar, now)
            -- Not when the swing was already started with the new speed.
            if left and left > 0.05 and math.abs(bar.dur - speed) > 0.02 then
                local k = speed / old
                bar.dur, bar.endT = bar.dur * k, now + left * k
                counts.rescaled = counts.rescaled + 1
                Log("SPEED", string.format("%.2f", old), string.format("%.2f", speed))
                Move(frame, bar, now)
            end
        end
    end
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
        print(("  This session: %d swings started at the end of a cast, %d parries, %d attack speed changes.")
            :format(counts.restarted, counts.parries, counts.rescaled))
    end
    print("  /swingfix on  -  /swingfix off  -  /swingfix log")
end

local function Slash(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "on" or cmd == "off" then
        db.enabled = (cmd == "on")
        print(PREFIX .. (db.enabled
            and "on. The swing bars follow casts, parries and attack speed changes."
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
        -- How long after a cast the next main hand swing came, next to the weapon's swing time.
        if afterCast and Plain(b) and b == 0 then
            Log("AFTER_CAST", string.format("%.2f", GetTime() - afterCast.at),
                afterCast.speed and string.format("%.2f", afterCast.speed) or nil)
            afterCast = nil
        end
    elseif event == "UNIT_SPELLCAST_START" then
        if a ~= "player" then return end
        Log("START", c)
        cast = { guid = b }
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if a ~= "player" then return end
        Log(cast and SameCast(b) and "WENT_OFF" or "INSTANT", c)
        CastWentOff(b)
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if a ~= "player" then return end
        if cast and SameCast(b) then
            Log(event:sub(16), c)
            cast = nil
        end
    elseif event == "UNIT_COMBAT" then
        if a == "player" then
            if Plain(b) and b == "PARRY" then Parried() end
            if db.log and UnitAffectingCombat and UnitAffectingCombat("player") then Log("ON_ME", b, c) end
        elseif a == "target" then
            -- For the log only: shows when a swing really landed.
            if db.log and UnitAffectingCombat and UnitAffectingCombat("player") then Log("TARGET_HIT", b, c) end
        end
    elseif event == "UNIT_ATTACK_SPEED" then
        if a == "player" then SpeedChanged() end
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

local function RegisterUnit(event, ...)
    if not (f.RegisterUnitEvent and pcall(f.RegisterUnitEvent, f, event, ...)) then
        pcall(f.RegisterEvent, f, event)
    end
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(f.RegisterEvent, f, "PLAYER_SWING")
for _, event in ipairs(CAST_EVENTS) do RegisterUnit(event, "player") end
RegisterUnit("UNIT_COMBAT", "target", "player")
RegisterUnit("UNIT_ATTACK_SPEED", "player")

SLASH_SWINGFIX1 = "/swingfix"
SlashCmdList["SWINGFIX"] = Slash

ns.counts = counts
