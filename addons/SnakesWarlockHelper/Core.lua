-- Snakes Warlock Helper: core (settings, safe API reads, events, refresh loop, slash commands)
--
-- Each feature is a module table on the addon namespace (State, Reminders, PetCalc, Strip, Panel).
-- A new feature adds its own file, reads what it needs from ns.State, and adds a tab with
-- ns.Panel.AddTab if it wants a place in the window.
local ADDON, ns = ...

ns.ADDON = ADDON
ns.TITLE = "Snakes Warlock Helper"
ns.VERSION = "1.0.0"

local defaults = {
    remind = { armor = true, soullink = true, demon = true, stone = true },
    combat = true,        -- keep showing reminders during a fight
    pulse = true,         -- slow breathing animation on reminder icons
    locked = true,        -- reminder strip can't be dragged
    iconSize = 32,
    expiring = 120,       -- out of combat, also remind when a buff has less than this many seconds left
    stripPoint = nil,
    panelPoint = nil,
}
local charDefaults = {
    school = "shadow",    -- which of your spells the demon bonuses are counted for: shadow | fire
    selfDps = nil,        -- your own dps, typed in with /swh dps; nil = estimate it
    lastPet = nil,        -- last demon summoned, used by the "no demon" reminder
    pets = {},            -- measurements of each demon, taken while it was out
}

----------------------------------------------------------------------
-- Safe reads. WoW Forever hides some values from addons during combat
-- ("secret values"); comparing or doing maths on one is an error.
----------------------------------------------------------------------
local issecret, canaccess = issecretvalue, canaccessvalue

function ns.Readable(v)
    if v == nil then return false end
    if issecret and issecret(v) then return false end
    if canaccess and not canaccess(v) then return false end
    return true
end
local Readable = ns.Readable

function ns.Read(v)
    if Readable(v) then return v end
    return nil
end

-- First result of fn(...), or nil when it failed or the result is hidden.
function ns.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok and Readable(a) then return a end
    return nil
end

local function clean(ok, ...)
    if not ok then return nil end
    local n = select("#", ...)
    local t = { ... }
    for i = 1, n do
        if not Readable(t[i]) then t[i] = nil end
    end
    return unpack(t, 1, n)
end

-- All results of fn(...); each hidden one comes back as nil.
function ns.CallN(fn, ...)
    if type(fn) ~= "function" then return nil end
    return clean(pcall(fn, ...))
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9" .. ns.TITLE .. "|r: " .. tostring(msg))
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local driver = CreateFrame("Frame")
local handlers = {}

function ns.On(event, fn)
    if not handlers[event] then
        handlers[event] = {}
        pcall(driver.RegisterEvent, driver, event)   -- an event this client doesn't have is skipped
    end
    table.insert(handlers[event], fn)
end

driver:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for i = 1, #list do list[i](event, ...) end
end)

----------------------------------------------------------------------
-- Refresh loop: a full refresh when something changed (at most 4 a second)
-- or every 2 seconds; timers on the icons tick once a second.
----------------------------------------------------------------------
local dirty, sinceCheck, sinceFull, sinceTimer = true, 0, 0, 0

function ns.MarkDirty() dirty = true end

function ns.RefreshAll()
    if ns.demo then return end
    ns.State.Refresh()
    ns.Strip.Show(ns.Reminders.Build())
    if ns.Panel.IsShown() then ns.Panel.Refresh() end
end

local function SafeRefresh()
    local ok, err = pcall(ns.RefreshAll)
    if not ok and not ns.errShown then
        ns.errShown = true
        ns.Print("error: " .. tostring(err))
    end
end

local function OnUpdate(_, elapsed)
    sinceCheck = sinceCheck + elapsed
    sinceFull = sinceFull + elapsed
    sinceTimer = sinceTimer + elapsed
    if sinceCheck >= 0.25 then
        sinceCheck = 0
        if dirty or sinceFull >= 2 then
            dirty, sinceFull = false, 0
            SafeRefresh()
        end
    end
    if sinceTimer >= 1 then
        sinceTimer = 0
        ns.Strip.UpdateTimers()
    end
end

----------------------------------------------------------------------
-- Start-up
----------------------------------------------------------------------
local function ApplyDefaults(db, def)
    for k, v in pairs(def) do
        if type(v) == "table" then
            if type(db[k]) ~= "table" then db[k] = {} end
            ApplyDefaults(db[k], v)
        elseif db[k] == nil then
            db[k] = v
        end
    end
end

local function Init()
    SnakesWarlockHelperDB = SnakesWarlockHelperDB or {}
    SnakesWarlockHelperCharDB = SnakesWarlockHelperCharDB or {}
    ApplyDefaults(SnakesWarlockHelperDB, defaults)
    ApplyDefaults(SnakesWarlockHelperCharDB, charDefaults)
    ns.db, ns.cdb = SnakesWarlockHelperDB, SnakesWarlockHelperCharDB

    local _, class = UnitClass("player")
    ns.enabled = (class == "WARLOCK")
    if not ns.enabled then return end

    ns.State.Enable()
    ns.Strip.Enable()
    driver:SetScript("OnUpdate", OnUpdate)
end

ns.On("PLAYER_LOGIN", Init)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function Help()
    ns.Print("commands:")
    ns.Print("  /swh  - open or close the window")
    ns.Print("  /swh options  - open the options tab")
    ns.Print("  /swh move  - unlock or lock the reminder icons so you can drag them")
    ns.Print("  /swh school shadow|fire  - which of your spells the demon bonuses count for")
    ns.Print("  /swh dps <number>|auto  - your own dps, or let the addon estimate it")
    ns.Print("  /swh reset  - put the window and the reminders back where they started")
    ns.Print("  /swh demo  - show sample reminders and numbers (works on any class)")
end

local function SetDemo(on)
    ns.demo = on or nil
    if on then
        ns.Strip.Show(ns.Reminders.DemoList())
        ns.Panel.Open("demons")
        ns.Print("demo on: sample reminders and numbers. /swh demo again to turn it off.")
    else
        ns.Strip.Show({})
        ns.Panel.Close()
        if ns.enabled then ns.MarkDirty() end
        ns.Print("demo off.")
    end
end

function SnakesWarlockHelper_Toggle()
    if not ns.db then return end
    if not ns.enabled and not ns.demo then
        ns.Print("this character isn't a warlock. /swh demo shows what it looks like.")
        return
    end
    ns.Panel.Toggle()
end

SLASH_SNAKESWARLOCKHELPER1 = "/swh"
SLASH_SNAKESWARLOCKHELPER2 = "/snakes"
SlashCmdList.SNAKESWARLOCKHELPER = function(msg)
    if not ns.db then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "demo" then
        SetDemo(not ns.demo)
        return
    elseif cmd == "help" or cmd == "?" then
        Help()
        return
    end
    if not ns.enabled and not ns.demo then
        ns.Print("this character isn't a warlock. /swh demo shows what it looks like.")
        return
    end
    if cmd == "" then
        ns.Panel.Toggle()
    elseif cmd == "options" or cmd == "config" then
        ns.Panel.Open("options")
    elseif cmd == "move" or cmd == "unlock" or cmd == "lock" then
        if cmd == "move" then ns.db.locked = not ns.db.locked else ns.db.locked = (cmd == "lock") end
        ns.Strip.ApplyLock()
        ns.Print(ns.db.locked and "reminders locked." or "reminders unlocked: drag the box, then /swh move again.")
    elseif cmd == "school" then
        if arg == "shadow" or arg == "fire" then
            ns.cdb.school = arg
            ns.Panel.Refresh()
            ns.Print("counting demon bonuses for your " .. arg .. " spells.")
        else
            ns.Print("usage: /swh school shadow   or   /swh school fire")
        end
    elseif cmd == "dps" then
        local n = tonumber(arg)
        if n and n > 0 then
            ns.cdb.selfDps = n
            ns.Print(("using %d as your own dps."):format(n))
        elseif arg == "auto" or arg == "" then
            ns.cdb.selfDps = nil
            ns.Print("estimating your own dps from your main spell.")
        else
            ns.Print("usage: /swh dps 450   or   /swh dps auto")
        end
        ns.Panel.Refresh()
    elseif cmd == "reset" then
        ns.db.stripPoint, ns.db.panelPoint = nil, nil
        ns.Strip.RestorePosition()
        ns.Panel.RestorePosition()
        ns.Print("positions reset.")
    elseif cmd == "debug" then
        ns.State.PrintDebug()
    else
        Help()
    end
end
