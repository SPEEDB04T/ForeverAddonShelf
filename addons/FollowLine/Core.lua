-- Follow Line: settings, events, slash commands
local ADDON, ns = ...

local issecret = issecretvalue or function() return false end
ns.issecret = issecret

ns.VERSION = "1.0.1"
do
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    if get then
        local ok, v = pcall(get, ADDON, "Version")
        if ok and type(v) == "string" and v ~= "" and not issecret(v) then ns.VERSION = v end
    end
end

ns.ICON = "Interface\\Icons\\Ability_Hunter_Pathfinding"
ns.ACCENT = { 0.35, 0.78, 0.95 }

-- Key Bindings > AddOns
BINDING_HEADER_FOLLOWLINE = "Follow Line"
_G["BINDING_NAME_CLICK FollowLineJoinButton:LeftButton"] = "Follow the player ahead of me in the line"

local defaults = {
    open = false,           -- the line window
    locked = false,         -- the window and the Follow button can't be dragged
    scale = 1,
    who = "auto",           -- whose line calls are taken: "auto" (anyone in a party, leader and assistants in a raid) | "leader" | "anyone"
    auto = false,           -- try to start following without a click (only where the game lets addons do that)
    sound = true,           -- a sound when a line is called for you and when you drop off
    alerts = true,          -- a chat line when someone else drops off
    point = nil,            -- { left, top } of the window
    buttonPoint = nil,      -- { x, y } of the Follow button's middle
}
local WHO = { auto = true, leader = true, anyone = true }

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff59c7f2Follow Line|r: " .. tostring(msg))
end

-- Run something without letting an error repeat every frame in the error log.
local seenErrors, errorCount = {}, 0
function ns.Safe(f, ...)
    local ok, err = pcall(f, ...)
    if ok then return true end
    local msg = issecret(err) and "blocked by a secret value" or tostring(err)
    if not seenErrors[msg] and errorCount < 5 then
        seenErrors[msg] = true
        errorCount = errorCount + 1
        ns.Print("|cffff6060error:|r " .. msg)
    end
    return false
end

----------------------------------------------------------------------
-- Names
----------------------------------------------------------------------
-- The short form the game uses in this group: "Name" on the player's realm, "Name-Realm" elsewhere.
function ns.Norm(name)
    if issecret(name) or type(name) ~= "string" or name == "" then return nil end
    if Ambiguate then
        local ok, short = pcall(Ambiguate, name, "none")
        if ok and type(short) == "string" and not issecret(short) and short ~= "" then name = short end
    end
    return name
end

function ns.FullUnitName(unit)
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or issecret(name) or issecret(realm) or type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
    return ns.Norm(name)
end

-- Names go out with their realm so players from another realm read them right.
function ns.Qualified(name)
    if name:find("-", 1, true) or not GetNormalizedRealmName then return name end
    local ok, realm = pcall(GetNormalizedRealmName)
    if ok and type(realm) == "string" and realm ~= "" and not issecret(realm) then return name .. "-" .. realm end
    return name
end

function ns.InCombat()
    if not InCombatLockdown then return false end
    local ok, v = pcall(InCombatLockdown)
    return ok and v and true or false
end

function ns.Sound(kind)
    if not (ns.db and ns.db.sound and PlaySound) then return end
    local kit = SOUNDKIT or {}
    local id
    if kind == "drop" then
        id = kit.RAID_WARNING or 8959
    else
        id = kit.READY_CHECK or 8960
    end
    pcall(PlaySound, id, "Master")
end

----------------------------------------------------------------------
-- Update loop
----------------------------------------------------------------------
ns.dirty = true
local driver = CreateFrame("Frame")
local acc, second = 0, 0

local function Tick(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    second = second + acc
    acc = 0
    if second >= 1 then
        second = 0
        ns.Safe(ns.Line.Tick, GetTime())
        ns.dirty = true     -- "too far" on the Follow button comes and goes as people move
    end
    if ns.dirty then
        ns.dirty = false
        ns.Safe(ns.UI.Refresh)
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local events = {}

function events.PLAYER_ENTERING_WORLD()
    seenErrors, errorCount = {}, 0
    ns.Line.Rebuild()
end

function events.GROUP_ROSTER_UPDATE()
    ns.Line.Rebuild()
end

function events.PARTY_LEADER_CHANGED()
    ns.Line.Rebuild()
end

function events.UNIT_CONNECTION()
    ns.dirty = true
end

function events.CHAT_MSG_ADDON(prefix, text, channel, sender)
    ns.Line.OnAddonMessage(prefix, text, channel, sender)
end

function events.AUTOFOLLOW_BEGIN(name)
    ns.Line.OnFollowBegin(name)
end

function events.AUTOFOLLOW_END()
    ns.Line.OnFollowEnd()
end

-- the Follow button can only change outside a fight
function events.PLAYER_REGEN_ENABLED()
    ns.UI.ApplySecure()
    ns.dirty = true
end

function events.PLAYER_REGEN_DISABLED()
    ns.dirty = true
end

-- The game refused to let the addon start a follow by itself.
local function Refused(addon, func)
    if issecret(addon) or issecret(func) or addon ~= ADDON then return end
    ns.Line.DirectRefused(func)
end
events.ADDON_ACTION_FORBIDDEN = Refused
events.ADDON_ACTION_BLOCKED = Refused

local function Init()
    FollowLineDB = FollowLineDB or {}
    for k, v in pairs(defaults) do
        if FollowLineDB[k] == nil then FollowLineDB[k] = v end
    end
    ns.db = FollowLineDB
    if not WHO[ns.db.who] then ns.db.who = "auto" end
    if type(ns.db.scale) ~= "number" or ns.db.scale < 0.5 or ns.db.scale > 2 then ns.db.scale = 1 end

    local _, class = UnitClass("player")
    ns.playerClass = (not issecret(class)) and class or nil
    ns.playerName = ns.FullUnitName("player") or UnitName("player")

    -- each part on its own, so one failing does not take the others with it
    ns.Safe(ns.UI.Create)
    ns.Safe(ns.Line.Init)
    if ns.Kit and ns.Options then ns.Safe(ns.Options.Init) end

    for ev in pairs(events) do pcall(driver.RegisterEvent, driver, ev) end
    driver:SetScript("OnEvent", function(_, event, ...)
        local handler = events[event]
        if handler then ns.Safe(handler, ...) end
    end)
    driver:SetScript("OnUpdate", function(self, elapsed) ns.Safe(Tick, self, elapsed) end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() ns.Safe(Init) end)

----------------------------------------------------------------------
-- Actions shared by the slash commands, the options window and the minimap button
----------------------------------------------------------------------
function ns.ToggleWindow()
    ns.db.open = not ns.db.open
    ns.dirty = true
end

function ns.ToggleDemo()
    ns.Line.SetDemo(not ns.Line.demo)
    if ns.Line.demo then ns.db.open = true end
    ns.Print(ns.Line.demo and "demo on: four pretend players joined. /line demo again to remove them." or "demo off.")
    ns.dirty = true
end

function ns.ResetSettings()
    local db = ns.db
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(defaults) do db[k] = v end
    ns.UI.ApplyLayout()
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.Print("settings reset.")
    ns.dirty = true
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function Help()
    ns.Print("commands:")
    ns.Print("  /line  - show or hide the line window")
    ns.Print("  /line call  - send the line as it is ordered in the window (also: /line go)")
    ns.Print("  /line stop  - end the line")
    ns.Print("  /line regroup  - nudge everyone who is off the line")
    ns.Print("  /line order <names>  - set the order, the first name leads (the rest keep their places behind)")
    ns.Print("  /line head <name> | add <name> | remove <name> | reverse | distance")
    ns.Print("  /line announce  - post the order in group chat, for players without the addon")
    ns.Print("  /line who auto | leader | anyone  - whose line calls you take (now: " .. ns.db.who .. ")")
    ns.Print("  /line auto  - try to follow without a click, where the game allows it (" .. OnOff(ns.db.auto) .. ")")
    ns.Print("  /line sound | alerts  - sound (" .. OnOff(ns.db.sound) .. "), chat line when someone drops off (" .. OnOff(ns.db.alerts) .. ")")
    ns.Print("  /line config | minimap | lock | unlock | scale <0.5-2> | status | demo | reset")
    ns.Print("  Key: Key Bindings > AddOns > Follow Line.")
end

SLASH_FOLLOWLINE1 = "/line"
SLASH_FOLLOWLINE2 = "/followline"
SLASH_FOLLOWLINE3 = "/fline"
SlashCmdList.FOLLOWLINE = function(msg)
    if not ns.db then return end
    local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    local db, Line = ns.db, ns.Line
    if cmd == "" then
        ns.ToggleWindow()
    elseif cmd == "call" or cmd == "go" or cmd == "start" then
        Line.Call()
    elseif cmd == "stop" or cmd == "end" then
        Line.Stop()
    elseif cmd == "regroup" or cmd == "ping" then
        Line.Regroup()
    elseif cmd == "order" then
        Line.SetOrder(arg)
    elseif cmd == "head" or cmd == "lead" then
        Line.SetHead(arg)
    elseif cmd == "add" then
        Line.Add(arg)
    elseif cmd == "remove" or cmd == "kick" then
        Line.Remove(arg)
    elseif cmd == "reverse" then
        Line.Reverse()
    elseif cmd == "distance" or cmd == "near" then
        Line.ByDistance()
    elseif cmd == "announce" or cmd == "report" then
        Line.Announce()
    elseif cmd == "who" then
        local want = arg:lower()
        if WHO[want] then
            db.who = want
            ns.Print("taking line calls from: " .. want .. ".")
        else
            ns.Print("usage: /line who auto | leader | anyone (now: " .. db.who .. ")")
        end
    elseif cmd == "auto" then
        db.auto = not db.auto
        ns.Print(db.auto and "will try to follow without a click. If the game refuses, this turns itself off again."
            or "following only on your click or key.")
    elseif cmd == "sound" then
        db.sound = not db.sound
        ns.Print("sound " .. OnOff(db.sound) .. ".")
    elseif cmd == "alerts" then
        db.alerts = not db.alerts
        ns.Print("chat line when someone drops off: " .. OnOff(db.alerts) .. ".")
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if ns.Kit then ns.Kit.Open() end
    elseif cmd == "minimap" then
        if ns.Kit then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("minimap button " .. OnOff(ns.Kit.MinimapShown()) .. ".")
        end
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        ns.Print(db.locked and "window and Follow button locked." or "unlocked: drag the window or the Follow button to move them.")
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 then
            db.scale = n
            ns.UI.ApplyLayout()
        else
            ns.Print("usage: /line scale 1.2")
        end
    elseif cmd == "demo" then
        ns.ToggleDemo()
    elseif cmd == "status" then
        Line.PrintStatus()
    elseif cmd == "reset" then
        ns.ResetSettings()
    else
        Help()
    end
    ns.dirty = true
    if ns.Kit then ns.Kit.Sync() end      -- an open options window follows what was typed
end
