-- Turn-in Route: core (settings, safe API access, following the route, events, slash commands)
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.0.2"
ns.NAME = "Turn-in Route"
ns.ICON = "Interface\\Icons\\INV_Misc_Map_01"

local defaults = {
    point = nil,
    scale = 1,
    useHearth = true,     -- plan with the hearthstone when it is ready and the addon knows where it goes
    useFlights = true,    -- plan with the flight paths this character knows
    useBoats = true,      -- plan with boats, zeppelins and the tram
    follow = true,        -- once a stop is handed in, the arrow moves to the next one
}

----------------------------------------------------------------------
-- Safe API access. WoW Forever runs on the modern client, where a
-- value can be "secret" (unreadable by addons); those become nil.
----------------------------------------------------------------------
function ns.Val(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function ns.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return ns.Val(a), ns.Val(b), ns.Val(c), ns.Val(d)
end

function ns.Num(value)
    value = ns.Val(value)
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
        return value
    end
end

function ns.Str(value)
    value = ns.Val(value)
    if type(value) == "string" and value ~= "" then return value end
end

function ns.Field(tbl, key)
    if type(tbl) ~= "table" then return nil end
    return ns.Val(tbl[key])
end

-- The game's own text colours (NORMAL_FONT_COLOR and the like); the numbers are only for a client without them.
function ns.GameColor(name, r, g, b)
    local color = _G[name]
    if type(color) == "table" and type(color.r) == "number" then return color.r, color.g, color.b end
    return r, g, b
end

function ns.Print(msg)
    local text = "|cff40c8ebTurn-in Route|r: " .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

function ns.Now()
    return ns.Num(ns.Call(GetTime)) or 0
end

-- "under a minute", "4 min", "1 h 10 min"
function ns.Duration(seconds)
    seconds = seconds or 0
    if seconds < 45 then return "under a minute" end
    local minutes = math.floor(seconds / 60 + 0.5)
    if minutes < 60 then return minutes .. " min" end
    return ("%d h %d min"):format(math.floor(minutes / 60), minutes % 60)
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local function InitDB()
    if type(TurnInRouteDB) ~= "table" then TurnInRouteDB = {} end
    if type(TurnInRouteCharDB) ~= "table" then TurnInRouteCharDB = {} end
    for key, value in pairs(defaults) do
        if TurnInRouteDB[key] == nil then TurnInRouteDB[key] = value end
    end
    if type(TurnInRouteCharDB.flights) ~= "table" then TurnInRouteCharDB.flights = {} end
    ns.db, ns.cdb = TurnInRouteDB, TurnInRouteCharDB
end
ns.InitDB = InitDB

----------------------------------------------------------------------
-- The plan
----------------------------------------------------------------------
function ns.Compute()
    local quests, meta = ns.Places.Finished()
    local here = ns.Places.PlayerPos()
    ns.Travel.LearnSpeed()
    local travel = ns.Travel.Context(ns.db)
    ns.result = ns.Plan.Make(quests, here, travel)
    ns.result.error = meta.error
    return ns.result
end

local refreshQueued = false
function ns.Refresh()
    if not (ns.UI and ns.UI.AnyShown()) then return end
    if refreshQueued then return end
    refreshQueued = true
    ns.After(0.15, function()
        refreshQueued = false
        if ns.UI.AnyShown() then ns.UI.UpdateAll(ns.Compute()) end
    end)
end

----------------------------------------------------------------------
-- Following the route. The game's own super tracking (its quest arrow and
-- map pin) points at the next stop; once that stop's quests are handed in
-- it moves to the stop after, until the player tracks something else.
----------------------------------------------------------------------
ns.following = nil              -- the quest the route is tracking, while it follows
local advancing = false

local function SuperTracked()
    if not C_SuperTrack then return nil end
    return ns.Num(ns.Call(C_SuperTrack.GetSuperTrackedQuestID))
end

function ns.CanTrack()
    return C_SuperTrack ~= nil and type(C_SuperTrack.SetSuperTrackedQuestID) == "function"
end

function ns.IsTracked(questID)
    return questID ~= nil and SuperTracked() == questID
end

-- Tracks questID and follows the route from it; nil stops tracking.
function ns.Track(questID)
    if not ns.CanTrack() then return false end
    ns.following = questID
    local ok = pcall(C_SuperTrack.SetSuperTrackedQuestID, questID or 0)
    if not ok then ns.following = nil end
    ns.Refresh()
    return ok
end

-- Tracks the first stop of the route as it stands now, from where you stand.
function ns.NextStop()
    advancing = false
    local plan = ns.Compute()
    local leg = plan.legs[1]
    if leg then
        local quest = leg.quests[1]
        ns.Track(quest.id)
        ns.Print(("Leg 1 of %d: %s. Next hand-in: %s."):format(#plan.legs, leg.text, quest.title))
        return true
    end
    ns.following = nil
    if #plan.unknown + #plan.inside > 0 then
        ns.Print("No finished quest left on the route; the ones left are in the lists under it.")
    else
        ns.Print("No finished quests left to hand in.")
    end
    return false
end

local function OnQuestGone(questID)
    if questID and questID == ns.following and ns.db.follow and not advancing then
        advancing = true
        ns.After(1, ns.NextStop)         -- once the log no longer lists it
    end
end

local function OnSuperTrackingChanged()
    local now = SuperTracked()
    if ns.following and now and now ~= 0 and now ~= ns.following then ns.following = nil end
end

----------------------------------------------------------------------
-- Chat report
----------------------------------------------------------------------
function ns.Report()
    local plan = ns.Compute()
    if plan.error then ns.Print(plan.error); return end
    ns.Print(ns.Plan.Summary(plan))
    for _, leg in ipairs(plan.legs) do
        local titles = {}
        for _, quest in ipairs(leg.quests) do titles[#titles + 1] = quest.title end
        ns.Print(("  %d. %s (%d), %s: %s"):format(leg.number, leg.text, #leg.quests, ns.Duration(leg.seconds),
            table.concat(titles, ", ")))
    end
    for _, quest in ipairs(plan.inside) do
        ns.Print(("  -  %s (hand in inside %s)"):format(quest.title, quest.turnIn.instance))
    end
    for _, quest in ipairs(plan.unknown) do
        ns.Print(("  -  %s (turn-in place unknown)"):format(quest.title))
    end
end

local function Debug()
    local plan = ns.Compute()
    local t = plan.travel
    ns.Print(("speed %.1f yd/s (%s), flights known %d, docks %d, hearth %s"):format(t.speed,
        t.mounted and "your mount" or "on foot", t.flightCount, #t.docks, ns.Travel.HearthText(t.hearth)))
    for _, node in ipairs(t.flights) do
        ns.Print(("  flight path: %s (continent %s, %d, %d)"):format(node.name, tostring(node.continent), node.x, node.y))
    end
    ns.Print(("route %s, %d legs; nearest-yards order would take %s"):format(ns.Duration(plan.seconds), #plan.legs,
        plan.yardsSeconds and ns.Duration(plan.yardsSeconds) or "-"))
    for _, leg in ipairs(plan.legs) do
        ns.Print(("  %d. %s | %s | %ds travel, %ds between stops%s"):format(leg.number, leg.text, leg.zone or "?",
            math.floor(leg.travel), math.floor(leg.inside), leg.noWay and " | no known way" or ""))
    end
    ns.Print("Quest log: " .. (ns.QuestLog and ns.QuestLog.Status() or "module missing"))
end

----------------------------------------------------------------------
-- Actions shared by the slash commands, the options window and the minimap button
----------------------------------------------------------------------
function ns.ForgetFlights()
    ns.cdb.flights = {}
    ns.cdb.hearth = nil
    ns.Print("Forgot this character's flight paths and hearthstone place. Open a flight master's map to learn them again.")
    ns.Refresh()
end

function ns.ResetSettings()
    local db = ns.db
    for key in pairs(db) do db[key] = nil end
    for key, value in pairs(defaults) do db[key] = value end
    ns.UI.ApplyScale()
    ns.UI.RestorePosition()
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.Refresh()
    ns.Print("Settings reset.")
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function Slash(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        ns.UI.Toggle()
    elseif cmd == "list" or cmd == "route" or cmd == "print" then
        ns.Report()
    elseif cmd == "next" or cmd == "go" or cmd == "follow" or cmd == "start" then
        ns.NextStop()
    elseif cmd == "stop" or cmd == "off" then
        ns.Track(nil)
        ns.Print("Stopped following the route.")
    elseif cmd == "log" or cmd == "tab" then
        ns.QuestLog.Open()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if ns.Kit then ns.Kit.Open() end
    elseif cmd == "minimap" then
        if ns.Kit then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("Minimap button: " .. (ns.Kit.MinimapShown() and "on" or "off"))
        end
    elseif cmd == "hearth" or cmd == "flights" or cmd == "boats" then
        local key = ({ hearth = "useHearth", flights = "useFlights", boats = "useBoats" })[cmd]
        ns.db[key] = not ns.db[key]
        ns.Print(("Planning with %s: %s"):format(cmd == "hearth" and "the hearthstone"
            or cmd == "flights" and "flight paths" or "boats, zeppelins and the tram", ns.db[key] and "on" or "off"))
        ns.Refresh()
    elseif cmd == "forget" then
        ns.ForgetFlights()
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 then
            ns.db.scale = n
            ns.UI.ApplyScale()
        else
            ns.Print("Usage: /turnin scale <0.5-2>")
        end
    elseif cmd == "reset" then
        ns.db.point, ns.db.scale = nil, 1
        ns.UI.ApplyScale()
        ns.UI.RestorePosition()
        ns.Print("Window position and scale reset.")
    elseif cmd == "debug" then
        Debug()
    else
        ns.Print("Commands: /turnin (the route window), list (print the route), next (arrow to the first stop, "
            .. "then on along the route), stop, log (quest log tab), config, hearth, flights, boats, forget, "
            .. "scale <n>, minimap, reset, debug")
    end
    if ns.Kit then ns.Kit.Sync() end      -- an open options window follows what was typed
end

SLASH_TURNINROUTE1 = "/turnin"
SLASH_TURNINROUTE2 = "/turnins"
SLASH_TURNINROUTE3 = "/turninroute"
-- Only add our key: assigning the SlashCmdList global itself (even to the same table) taints it,
-- and the game then forbids /tm, /invite and other protected slash commands in our name.
SlashCmdList["TURNINROUTE"] = Slash

-- The addon's line in the list of addons next to the minimap: left-click the window,
-- right-click the options.
function TurnInRoute_Toggle(_, mouseButton)
    if not (ns.UI and ns.db) then return end
    if mouseButton == "RightButton" and ns.Kit then ns.Kit.Open() else ns.UI.Toggle() end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.eventFrame = frame
local EVENTS = { "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "SUPER_TRACKING_CHANGED",
    "TAXIMAP_OPENED", "HEARTHSTONE_BOUND", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_ENTERING_WORLD",
    "PLAYER_MOUNT_DISPLAY_CHANGED", "BAG_UPDATE_COOLDOWN" }
for _, event in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, event) end

frame:SetScript("OnEvent", function(_, event, a, b, c)
    if event == "PLAYER_LOGIN" then
        InitDB()
        ns.UI.Create()
        if ns.QuestLog then ns.QuestLog.Init() end
        if ns.Kit and ns.Options then
            local ok, err = pcall(ns.Options.Init)
            if not ok then ns.Print("options error: " .. tostring(err)) end
        end
        return
    elseif not ns.db then
        return
    end
    if event == "SUPER_TRACKING_CHANGED" then
        OnSuperTrackingChanged()
        return
    elseif event == "TAXIMAP_OPENED" then
        local learned = ns.Travel.LearnTaxi()
        if learned > 0 then ns.Print(("Learned %d new flight %s."):format(learned, learned == 1 and "path" or "paths")) end
    elseif event == "HEARTHSTONE_BOUND" then
        ns.Travel.LearnHearthHere("bound")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if a == "player" then ns.Travel.OnSpellCast(c) end
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        ns.Travel.OnArrived()
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        ns.Travel.OnZoneText()
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        ns.After(0.5, ns.Travel.LearnSpeed)
        return
    elseif event == "QUEST_REMOVED" then
        OnQuestGone(ns.Num(a))
    elseif event == "QUEST_TURNED_IN" then
        OnQuestGone(ns.Num(a))
    end
    ns.Refresh()
end)
