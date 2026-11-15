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

-- The frames this addon draws itself, for the LookShots helper (screenshots of
-- them on SuccuDev's machine; harmless when it is absent). The options window
-- and the minimap button are the kit's, and the kit lists those.
LookShotsTargets = type(LookShotsTargets) == "table" and LookShotsTargets or {}
LookShotsTargets[ADDON] = {
    version = ns.VERSION,
    frames = {
        { label = "line window", frame = function() return _G.FollowLineFrame end },
        -- the name and place are written up to 157 px to the right of the button
        { label = "follow button", frame = function() return _G.FollowLineJoinButton end, pad = 170 },
    },
}

ns.ICON = "Interface\\Icons\\Ability_Hunter_Pathfinding"
ns.ACCENT = { 0.35, 0.78, 0.95 }

-- Key Bindings > AddOns
BINDING_HEADER_FOLLOWLINE = "Follow Line"
_G["BINDING_NAME_CLICK FollowLineJoinButton:LeftButton"] = "Follow the player ahead of me in the line"
_G["BINDING_NAME_CLICK FollowLineRodButton:LeftButton"] = "Use the furbolg rod"
_G["BINDING_NAME_CLICK FollowLineTorchButton:LeftButton"] = "Light the torch"

local defaults = {
    open = false,           -- the line window
    locked = false,         -- the window and the Follow button can't be dragged
    scale = 1,
    who = "auto",           -- whose line calls are taken: "auto" (anyone in a party, leader and assistants in a raid) | "leader" | "anyone"
    auto = false,           -- try to start following without a click (only where the game lets addons do that)
    sound = true,           -- a sound when a line is called for you and when you drop off
    alerts = true,          -- a chat line when someone else drops off
    items = true,           -- the furbolg rod and torch buttons beside the Follow button while in a line
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
-- Character names on this client are two words, and UnitName gives them as two
-- values: UnitName("player") is "Ann", "Lee", the surname where other
-- clients put the realm. Message and chat senders spell the same player
-- "Ann Lee" (a space, no realm), and a realm, when one comes, follows
-- a dash ("...-CAMWOWUS1Realm9RPPvP", while GetNormalizedRealmName() says "RPPvP").
-- So players are found by the spellings their unit gives (Line.Lookup), and the
-- realm only chooses between equal names.

-- A group unit's name: its key "First Last" (shown to the player and put inside
-- messages), then UnitName's two values. The second value may be a surname or a
-- realm; when the first is already two words it can only be a realm, so the key
-- keeps the old "First Last-Realm".
function ns.UnitKey(unit)
    local ok, first, second = pcall(UnitName, unit)
    if not ok or issecret(first) or issecret(second) or type(first) ~= "string" or first == "" then return nil end
    if type(second) ~= "string" or second == "" then second = nil end
    if not second then return first, first, nil end
    return first .. (first:find(" ", 1, true) and "-" or " ") .. second, first, second
end

-- "Roleplay PvP", "RPPvP" and "CAMWOWUS1Realm9RPPvP" squeezed to compare them.
function ns.Squeeze(s)
    if type(s) ~= "string" or issecret(s) then return "" end
    return (s:lower():gsub("[^%w]", ""))
end

-- Does a realm as a sender spells it agree with this one? Equal, or one ends or starts with the other.
function ns.RealmAgrees(a, b)
    a, b = ns.Squeeze(a), ns.Squeeze(b)
    if a == "" or b == "" then return false end
    if a == b then return true end
    local long, short = a, b
    if #short > #long then long, short = short, long end
    return long:sub(-#short) == short or long:sub(1, #short) == short
end

-- The player's own realm, both spellings the client knows.
function ns.OwnRealms()
    local out = {}
    for _, f in ipairs({ GetNormalizedRealmName, GetRealmName }) do
        local ok, v = pcall(f)
        if ok and type(v) == "string" and v ~= "" and not issecret(v) then out[#out + 1] = v end
    end
    return out
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

-- a toy learned or an item in the bags changed: the rod and torch buttons look again
local function ToysChanged()
    ns.UI.ApplySecure()
end
events.TOYS_UPDATED = ToysChanged
events.NEW_TOY_ADDED = ToysChanged
events.BAG_UPDATE_DELAYED = ToysChanged

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
    ns.playerName = ns.UnitKey("player")
    if type(ns.db.commLog) ~= "table" then ns.db.commLog = {} end

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
    local log = db.commLog      -- the message log is not a setting: it stays
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(defaults) do db[k] = v end
    db.commLog = type(log) == "table" and log or {}
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
    ns.Print("  /line order <names>  - set the order, the first name leads (the rest keep their places behind); commas between full names")
    ns.Print("  /line head <name> | add <name> | remove <name> | reverse | distance")
    ns.Print("  /line announce  - post the order in group chat, for players without the addon")
    ns.Print("  /line who auto | leader | anyone  - whose line calls you take (now: " .. ns.db.who .. ")")
    ns.Print("  /line auto  - try to follow without a click, where the game allows it (" .. OnOff(ns.db.auto) .. ")")
    ns.Print("  /line sound | alerts  - sound (" .. OnOff(ns.db.sound) .. "), chat line when someone drops off (" .. OnOff(ns.db.alerts) .. ")")
    ns.Print("  /line items  - furbolg rod and torch buttons beside the Follow button (" .. OnOff(ns.db.items) .. "); /line items debug says what the game reports about them")
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
    elseif (cmd == "items" or cmd == "torch" or cmd == "rod") and arg:lower() == "debug" then
        ns.UI.ItemsDebug()
    elseif cmd == "items" or cmd == "torch" or cmd == "rod" then
        db.items = not db.items
        ns.UI.ApplySecure()
        ns.Print("furbolg rod and torch buttons: " .. OnOff(db.items) .. "."
            .. (ns.InCombat() and " They change when the fight ends." or ""))
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
