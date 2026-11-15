-- Abandon Advisor: core (settings, safe API access, abandoning, events, slash commands)
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.4.1"

local defaults = {
    point = nil,
    scale = 1,
    autoOpen = true,      -- open the window when the game says the quest log is full
    target = 3,           -- how many free slots the advice aims for
    dropRates = true,     -- count a low drop rate (from Questie) against a quest
    groupSuggest = true,  -- suggest a quest when a group member abandons it
    groupShare = true,    -- tell the group's Abandon Advisors when you abandon a quest
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

-- The game's own text colours (RED_FONT_COLOR and the like); the numbers are only for a client without them.
function ns.GameColor(name, r, g, b)
    local color = _G[name]
    if type(color) == "table" and type(color.r) == "number" then return color.r, color.g, color.b end
    return r, g, b
end

function ns.ColorCode(name, r, g, b)
    r, g, b = ns.GameColor(name, r, g, b)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

function ns.Print(msg)
    local text = "|cffff7d0aAbandon Advisor|r: " .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local function InitDB()
    if type(AbandonAdvisorDB) ~= "table" then AbandonAdvisorDB = {} end
    if type(AbandonAdvisorCharDB) ~= "table" then AbandonAdvisorCharDB = {} end
    for key, value in pairs(defaults) do
        if AbandonAdvisorDB[key] == nil then AbandonAdvisorDB[key] = value end
    end
    if type(AbandonAdvisorCharDB.keep) ~= "table" then AbandonAdvisorCharDB.keep = {} end
    ns.db, ns.cdb = AbandonAdvisorDB, AbandonAdvisorCharDB
end

----------------------------------------------------------------------
-- Advice
----------------------------------------------------------------------
function ns.Compute()
    local player = ns.Scan.Player()
    local quests, meta = ns.Scan.Log(player)
    player.pos = ns.Scan.TurnIns(quests)
    ns.result = ns.Score.RateAll(quests, player, meta, {
        target = ns.db.target, keep = ns.cdb.keep, drops = ns.db.dropRates,
        partner = ns.db.groupSuggest and ns.partner or nil,
    })
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

function ns.ToggleKeep(questID)
    local keep = ns.cdb.keep
    if keep[questID] then keep[questID] = nil else keep[questID] = true end
    return keep[questID] == true
end

----------------------------------------------------------------------
-- Hand-in route. The game's own super tracking (its quest arrow and map
-- pin) points at a stop; once that quest leaves the log it moves to the
-- next stop, until the player tracks something else.
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

-- Tracks the first stop of the route as it stands now.
function ns.NextStop()
    advancing = false
    local res = ns.Compute()
    local stop = res.route and res.route.stops[1]
    if stop then
        local row = stop.rows[1]
        ns.Track(row.id)
        ns.Print(("Next hand-in: %s (%s)."):format(row.title, stop.zone or "unknown zone"))
        return true
    end
    ns.following = nil
    if res.ready > 0 then
        ns.Print("The game does not say where your finished quests are handed in; nothing to track.")
    else
        ns.Print("No finished quests left to hand in.")
    end
    return false
end

local function OnTrackedQuestGone(questID)
    if questID and questID == ns.following and not advancing then
        advancing = true
        ns.After(1, ns.NextStop)         -- once the log no longer lists it
    end
end

local function OnSuperTrackingChanged()
    local now = SuperTracked()
    if ns.following and now and now ~= 0 and now ~= ns.following then ns.following = nil end
end

function ns.RouteReport()
    local res = ns.Compute()
    if res.error then ns.Print(res.error); return end
    local route = res.route
    if res.ready == 0 then ns.Print("No finished quests to hand in."); return end
    if #route.stops == 0 then
        ns.Print("The game does not say where your finished quests are handed in.")
        return
    end
    ns.Print(ns.Score.RouteText(route))
    for _, stop in ipairs(route.stops) do
        local titles = {}
        for _, row in ipairs(stop.rows) do titles[#titles + 1] = row.title end
        local where = stop.zone or "unknown zone"
        if stop.leg then where = where .. ", " .. ns.Score.Yards(stop.leg) end
        ns.Print(("  %d. %s (%s)"):format(stop.number, table.concat(titles, ", "), where))
    end
    for _, row in ipairs(route.unplaced) do ns.Print(("  -  %s (no turn-in position)"):format(row.title)) end
end

----------------------------------------------------------------------
-- Abandoning. Selects the quest, marks it, checks the game agrees on
-- which quest is marked, and only then abandons it.
----------------------------------------------------------------------
function ns.Abandon(questID, title)
    local C = C_QuestLog
    local ok, err
    if C and C.SetSelectedQuest and C.SetAbandonQuest and C.AbandonQuest then
        local previous = ns.Num(ns.Call(C.GetSelectedQuest))
        ok, err = pcall(function()
            C.SetSelectedQuest(questID)
            C.SetAbandonQuest()
            if C.GetAbandonQuest then
                local marked = ns.Num(C.GetAbandonQuest())
                if marked and marked ~= 0 and marked ~= questID then
                    error("the game marked a different quest (" .. marked .. ")", 0)
                end
            end
            C.AbandonQuest()
        end)
        if previous and previous ~= 0 and previous ~= questID then pcall(C.SetSelectedQuest, previous) end
    elseif GetQuestLogIndexByID and SelectQuestLogEntry and SetAbandonQuest and AbandonQuest then
        ok, err = pcall(function()
            local index = GetQuestLogIndexByID(questID)
            if not index or index == 0 then error("quest is not in the log", 0) end
            SelectQuestLogEntry(index)
            SetAbandonQuest()
            if GetAbandonQuestName and title then
                local marked = ns.Str(GetAbandonQuestName())
                if marked and marked ~= title then error("the game marked a different quest (" .. marked .. ")", 0) end
            end
            AbandonQuest()
        end)
    else
        ok, err = false, "this client has no abandon function the addon knows"
    end
    if ok then
        ns.Print(("Abandoned: %s"):format(title or ("quest " .. tostring(questID))))
        if ns.cdb and ns.cdb.keep then ns.cdb.keep[questID] = nil end
    else
        ns.Print(("Could not abandon %s: %s"):format(title or ("quest " .. tostring(questID)), tostring(err)))
    end
    ns.Refresh()
    return ok
end

----------------------------------------------------------------------
-- Group. When you abandon a quest, the group members' Abandon Advisors
-- are told (an addon message, nothing in chat). When one of them
-- abandons a quest you also have, yours suggests dropping it too.
-- The game does not report another player's abandon by itself, so this
-- only works between players who both run the addon.
----------------------------------------------------------------------
local PREFIX = "AbandonAdv"                      -- addon message prefix (16 characters at most)
local SUGGEST_POPUP = "ABANDONADVISOR_GROUP"
local GROUP_CHANNELS = { PARTY = true, RAID = true, INSTANCE_CHAT = true }

ns.partner = {}                -- [questID] = who in the group abandoned it; this session only
local turnedIn = {}            -- [questID] = when QUEST_TURNED_IN came
local reward                   -- the quest whose reward panel was last open: { id, closed = time }
local suggestions, suggesting = {}, false

local function Now()
    return ns.Num(ns.Call(GetTime)) or 0
end

local function GroupChannel()
    -- Only a group made by the dungeon finder, with no group of your own, talks on INSTANCE_CHAT.
    if LE_PARTY_CATEGORY_INSTANCE and LE_PARTY_CATEGORY_HOME
        and ns.Call(IsInGroup, LE_PARTY_CATEGORY_INSTANCE) == true
        and ns.Call(IsInGroup, LE_PARTY_CATEGORY_HOME) ~= true then
        return "INSTANCE_CHAT"
    end
    if ns.Call(IsInRaid) == true then return "RAID" end
    if ns.Call(IsInGroup) == true then return "PARTY" end
    return nil
end

function ns.GroupMessages()
    return C_ChatInfo ~= nil and type(C_ChatInfo.SendAddonMessage) == "function"
end

local function ShareAbandon(questID)
    if not ns.db.groupShare or not ns.GroupMessages() then return end
    local channel = GroupChannel()
    if not channel then return end
    -- The realm's AreOutgoingAddonChatMessagesRestricted flag is true on ordinary realms and is
    -- not a reason to stay silent: send, and keep what the game answered for /abandon debug.
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, "A:" .. questID, channel)
    result = ns.Val(result)
    local sent = ok and (result == nil or result == 0 or result == true)
    ns.lastSend = ("quest %d to %s: %s"):format(questID, channel,
        sent and "sent" or ok and ("the game refused it (code " .. tostring(result) .. ")") or "the call failed")
    ns.CommLog("out", channel, nil, nil, ok and tostring(result) or "error", "A:" .. questID)
end

-- QUEST_REMOVED also fires for a hand-in. Forever can send QUEST_TURNED_IN late or not at all,
-- but it flags a handed-in quest completed by the time the quest leaves the log, so the check
-- waits a moment. A repeatable quest is never flagged: for those the open reward panel tells.
local function OnQuestRemoved(questID)
    questID = ns.Num(questID)
    if not questID then return end
    ns.partner[questID] = nil
    local now = Now()
    if reward and reward.id == questID and (not reward.closed or now - reward.closed < 3) then return end
    ns.After(1, function()
        local handedIn = turnedIn[questID]
        turnedIn[questID] = nil
        if handedIn and Now() - handedIn < 120 then return end
        if C_QuestLog and ns.Call(C_QuestLog.IsQuestFlaggedCompleted, questID) == true then return end
        ShareAbandon(questID)
    end)
end

local function FindRow(questID)
    for _, row in ipairs(ns.Compute().rows) do
        if row.id == questID then return row end
    end
end

local ShowSuggestion

local function EnsureSuggestPopup()
    if StaticPopupDialogs[SUGGEST_POPUP] then return end
    StaticPopupDialogs[SUGGEST_POPUP] = {
        text = "%s",
        button1 = "Abandon",
        button2 = "Keep",
        OnAccept = function(self, data)
            data = data or (self and self.data)
            if data then ns.Abandon(data.id, data.title) end
        end,
        OnCancel = function(self, data, reason)
            data = data or (self and self.data)
            if data and reason ~= "override" then      -- Keep or Escape: stop suggesting this quest
                ns.partner[data.id] = nil
                ns.Refresh()
            end
        end,
        OnHide = function()
            suggesting = false
            ns.After(0.2, function() ShowSuggestion() end)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- One question at a time, and none during a fight (PLAYER_REGEN_ENABLED asks again).
function ShowSuggestion()
    while not suggesting and #suggestions > 0 do
        if ns.Call(InCombatLockdown) == true then return end
        if not (StaticPopup_Show and StaticPopupDialogs) then
            suggestions = {}
            return
        end
        local id = table.remove(suggestions, 1)
        local who = ns.partner[id]
        local row = who and FindRow(id)
        if row and not row.locked then            -- still in the log, not finished, not pinned meanwhile
            local text = ("%s abandoned \"%s\".\n\nAbandon it too?"):format(who, row.title)
            if row.progress and row.progress > 0 then
                text = text .. ("\n\nYou are %d%% done with it. Progress and its quest items are lost."):format(
                    math.floor(row.progress * 100 + 0.5))
            end
            EnsureSuggestPopup()
            suggesting = StaticPopup_Show(SUGGEST_POPUP, text, nil, { id = row.id, title = row.title }) ~= nil
        end
    end
end

function ns.ClearSuggestions()
    for id in pairs(ns.partner) do ns.partner[id] = nil end
    suggestions = {}
    if suggesting and StaticPopup_Hide then pcall(StaticPopup_Hide, SUGGEST_POPUP) end
    suggesting = false
end

-- Who sent it, found in the group (pitfalls.md, "Who sent an addon message"). Names on this
-- realm have a space ("First Last") and senders spell the realm differently from
-- GetNormalizedRealmName() ("CAMWOWUS1Realm9RPPvP" against "RPPvP"), so the sender is matched
-- to a group unit by name, and the realm only settles a tie. Returns unit, name or nil.
local function Squeeze(text)
    return (tostring(text or ""):lower():gsub("[^%w]", ""))
end

local function RealmsAgree(a, b)
    a, b = Squeeze(a), Squeeze(b)
    if a == "" or b == "" then return a == b end
    return a == b or a:sub(-#b) == b or b:sub(-#a) == a or a:sub(1, #b) == b or b:sub(1, #a) == a
end

local function GroupUnits()
    local units = { "player" }
    if ns.Call(IsInRaid) == true then
        for i = 1, 40 do units[#units + 1] = "raid" .. i end
    else
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

function ns.FindSender(sender)
    local who, suffix = sender:match("^([^-]+)%-(.+)$")
    who = who or sender
    local candidates = {}
    for _, unit in ipairs(GroupUnits()) do
        local name, realm = ns.Call(UnitName, unit)
        if ns.Str(name) == who and (unit == "player" or ns.Call(UnitIsUnit, unit, "player") ~= true) then
            candidates[#candidates + 1] = { unit = unit, name = name, realm = ns.Str(realm) }
        end
    end
    if #candidates <= 1 then
        local c = candidates[1]
        if c then return c.unit, c.name end
        return nil
    end
    local own = { ns.Str(ns.Call(GetNormalizedRealmName)), ns.Str(ns.Call(GetRealmName)) }
    for _, c in ipairs(candidates) do
        local agrees = suffix == nil
        if c.realm then
            agrees = agrees or RealmsAgree(c.realm, suffix)
        else
            for _, spelling in ipairs(own) do agrees = agrees or RealmsAgree(spelling, suffix) end
        end
        if agrees then return c.unit, c.name end
    end
    return candidates[1].unit, candidates[1].name
end

-- What came in and went out, for /abandon debug and for reading SavedVariables after a /reload.
ns.ignoredSenders = {}         -- [sender] = messages not matched to anyone in the group, this session
local function Log(direction, channel, sender, unit, code, text)
    local log = ns.db.commLog
    if type(log) ~= "table" then log = {}; ns.db.commLog = log end
    log[#log + 1] = { t = ns.Num(ns.Call(time)), dir = direction, ch = channel, from = sender, unit = unit,
        code = code, msg = text and tostring(text):sub(1, 40) }
    while #log > 40 do table.remove(log, 1) end
end
ns.CommLog = Log

local function OnAddonMessage(prefix, text, channel, sender)
    if ns.Str(prefix) ~= PREFIX or not ns.db.groupSuggest then return end
    text, channel, sender = ns.Str(text), ns.Str(channel), ns.Str(sender)
    if not (text and channel) or not GROUP_CHANNELS[channel] then return end
    if not sender then                              -- hidden in combat or an instance
        ns.ignoredSenders["(hidden)"] = (ns.ignoredSenders["(hidden)"] or 0) + 1
        Log("in", channel, "(hidden)", "nobody", nil, text)
        return
    end
    local unit, who = ns.FindSender(sender)
    Log("in", channel, sender, unit or "nobody", nil, text)
    if unit == "player" then return end             -- your own message, echoed back
    if not unit then
        ns.ignoredSenders[sender] = (ns.ignoredSenders[sender] or 0) + 1
        return
    end
    local questID = tonumber(text:match("^A:(%d+)$"))
    if not questID then return end
    local row = FindRow(questID)
    if not row or row.locked then return end       -- not in your log, finished, pinned or not abandonable
    local known = ns.partner[questID]
    if known and (", " .. known .. ", "):find(", " .. who .. ", ", 1, true) then return end
    ns.partner[questID] = known and (known .. ", " .. who) or who
    ns.Print(("%s abandoned \"%s\", which is in your quest log too."):format(who, row.title))
    local queued = false
    for _, id in ipairs(suggestions) do queued = queued or id == questID end
    if not queued then suggestions[#suggestions + 1] = questID end
    ShowSuggestion()
    ns.Refresh()
end

----------------------------------------------------------------------
-- Chat report
----------------------------------------------------------------------
local VERDICT_TEXT = { turnin = "hand in", abandon = "abandon", maybe = "maybe", keep = "keep" }

function ns.Report()
    local res = ns.Compute()
    if res.error then ns.Print(res.error); return end
    ns.Print(ns.Score.Summary(res))
    local shown = 0
    for _, row in ipairs(res.rows) do
        if row.pick or row.verdict == "abandon" or row.verdict == "turnin" then
            shown = shown + 1
            local why = {}
            for i = 1, math.min(3, #row.reasons) do why[#why + 1] = row.reasons[i].short end
            ns.Print(("  %s[%s] %s|r: %s (%s)"):format(
                row.pick and ns.ColorCode("RED_FONT_COLOR", 1, 0.125, 0.125) .. "Â» "
                    or ns.ColorCode("HIGHLIGHT_FONT_COLOR", 1, 1, 1), row.level and tostring(row.level) or "?",
                row.title, VERDICT_TEXT[row.verdict], table.concat(why, ", ")))
        end
    end
    if shown == 0 then ns.Print("  Nothing stands out as worth abandoning.") end
end

local function Debug()
    local C = C_QuestLog or {}
    local names = { "GetNumQuestLogEntries", "GetInfo", "GetQuestObjectives", "GetMaxNumQuestsCanAccept",
        "ReadyForTurnIn", "IsComplete", "IsFailed", "IsQuestTrivial", "GetQuestDifficultyLevel", "GetQuestTagInfo",
        "CanAbandonQuest", "GetQuestWatchType", "GetDistanceSqToQuest", "SetSelectedQuest", "SetAbandonQuest",
        "GetAbandonQuest", "AbandonQuest" }
    local have, missing = {}, {}
    for _, name in ipairs(names) do
        if type(C[name]) == "function" then have[#have + 1] = name else missing[#missing + 1] = name end
    end
    ns.Print("C_QuestLog has: " .. table.concat(have, ", "))
    ns.Print("C_QuestLog missing: " .. (#missing > 0 and table.concat(missing, ", ") or "nothing"))
    local questie = ns.Scan.Questie()
    ns.Print("Questie data: " .. (questie and "yes" or "no") .. ", drop rates: "
        .. (ns.Scan.HasDropRates(questie) and "yes" or "no") .. (ns.db.dropRates and "" or " (turned off)"))
    local marks = {}
    for id, who in pairs(ns.partner) do marks[#marks + 1] = ("%d by %s"):format(id, who) end
    ns.Print(("Group: messages %s, channel %s, suggest %s, share %s, abandoned by others: %s"):format(
        ns.GroupMessages() and "available" or "not available", tostring(GroupChannel()),
        ns.db.groupSuggest and "on" or "off", ns.db.groupShare and "on" or "off",
        #marks > 0 and table.concat(marks, "; ") or "none"))
    ns.Print("Last abandon told to the group: " .. (ns.lastSend or "none this session"))
    local ignored = {}
    for sender, count in pairs(ns.ignoredSenders) do
        ignored[#ignored + 1] = ("%d from %s"):format(count, sender)
    end
    table.sort(ignored)
    ns.Print("Messages ignored, sender not found in the group: " .. (#ignored > 0 and table.concat(ignored, "; ") or "none"))
    ns.Print("Quest log: " .. (ns.QuestLog and ns.QuestLog.Status() or "module missing"))
    local res = ns.Compute()
    local p = res.player
    ns.Print(("player level %s, max %s, xpMax %s, zone %s, grouped %s, grey range %s"):format(
        tostring(p.level), tostring(p.maxLevel), tostring(p.xpMax), tostring(p.zone), tostring(p.grouped),
        tostring(p.greenRange)))
    for _, row in ipairs(res.rows) do
        local parts = {}
        for _, reason in ipairs(row.reasons) do parts[#parts + 1] = ("%+d %s"):format(reason.pts, reason.short) end
        if row.drop then parts[#parts + 1] = "drops: " .. ns.Score.DropText(row.drop) end
        ns.Print(("%d [%s] %s: %s %d | xp %s, prog %s, tag %s, zone %s | %s"):format(
            row.id, tostring(row.level), row.title, row.verdict, row.score, tostring(row.xp),
            row.progress and ("%.2f"):format(row.progress) or "-", tostring(row.tag), tostring(row.zone),
            table.concat(parts, "; ")))
    end
end

----------------------------------------------------------------------
-- Actions shared by the slash commands, the options window and the minimap button
----------------------------------------------------------------------
function ns.Unpin()
    ns.cdb.keep = {}
    ns.Print("All pinned quests released.")
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
-- Kit.lua and Options.lua are new in 1.2.0. The game only finds new files after a full restart,
-- so right after an update a /reload runs this file without them: say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    ns.Print("The options window and the minimap button appear after you restart the game once (this update added new files, and /reload does not load those).")
    return false
end

local function Slash(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        ns.UI.Toggle()
    elseif cmd == "log" or cmd == "tab" then
        ns.QuestLog.Open()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if HasKit() then ns.Kit.Open() end
    elseif cmd == "minimap" then
        if HasKit() then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("Minimap button: " .. (ns.Kit.MinimapShown() and "on" or "off"))
        end
    elseif cmd == "list" or cmd == "report" then
        ns.Report()
    elseif cmd == "route" then
        if arg == "next" or arg == "go" or arg == "follow" then
            ns.NextStop()
        elseif arg == "stop" or arg == "off" then
            ns.Track(nil)
            ns.Print("Stopped following the hand-in route.")
        else
            ns.RouteReport()
        end
    elseif cmd == "free" or cmd == "target" then
        local n = tonumber(arg)
        if n and n >= 1 and n <= 25 then
            ns.db.target = math.floor(n)
            ns.Print(("Advice now aims for %d free slots."):format(ns.db.target))
            ns.Refresh()
        else
            ns.Print("Usage: /abandon free <1-25>. Currently " .. ns.db.target .. ".")
        end
    elseif cmd == "auto" then
        ns.db.autoOpen = not ns.db.autoOpen
        ns.Print("Opening when the quest log is full: " .. (ns.db.autoOpen and "on" or "off"))
    elseif cmd == "drops" then
        ns.db.dropRates = not ns.db.dropRates
        ns.Print("Counting low drop rates against a quest: " .. (ns.db.dropRates and "on" or "off"))
        ns.Refresh()
    elseif cmd == "group" then
        ns.db.groupSuggest = not ns.db.groupSuggest
        ns.Print("Suggesting a quest when a group member abandons it: " .. (ns.db.groupSuggest and "on" or "off"))
        ns.Refresh()
    elseif cmd == "share" then
        ns.db.groupShare = not ns.db.groupShare
        ns.Print("Telling your group when you abandon a quest: " .. (ns.db.groupShare and "on" or "off"))
    elseif cmd == "unpin" then
        ns.Unpin()
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 then
            ns.db.scale = n
            ns.UI.ApplyScale()
        else
            ns.Print("Usage: /abandon scale <0.5-2>")
        end
    elseif cmd == "reset" then
        ns.db.point, ns.db.scale = nil, 1
        ns.UI.ApplyScale()
        ns.UI.RestorePosition()
        ns.Print("Window position and scale reset.")
    elseif cmd == "debug" then
        Debug()
    else
        ns.Print("Commands: /abandon (window), config (options), log (quest log tab), list, "
            .. "route (hand-in order; route next tracks the first stop and follows), free <n>, auto, drops, "
            .. "group, share, unpin, scale <n>, minimap, reset, debug")
    end
    if ns.Kit then ns.Kit.Sync() end      -- an open options window follows what was typed
end

SLASH_ABANDONADVISOR1 = "/abandon"
SLASH_ABANDONADVISOR2 = "/aa"
SLASH_ABANDONADVISOR3 = "/abandonadvisor"
SlashCmdList = SlashCmdList or {}
SlashCmdList["ABANDONADVISOR"] = Slash

-- The addon's line in the list of addons next to the minimap: left-click the window,
-- right-click the options.
function AbandonAdvisor_Toggle(_, mouseButton)
    if not (ns.UI and ns.db) then return end
    if mouseButton == "RightButton" and ns.Kit then ns.Kit.Open() else ns.UI.Toggle() end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local function IsLogFullError(a, b)
    a, b = ns.Val(a), ns.Val(b)
    if ERR_QUEST_LOG_FULL and (a == ERR_QUEST_LOG_FULL or b == ERR_QUEST_LOG_FULL) then return true end
    if LE_GAME_ERR_QUEST_LOG_FULL and a == LE_GAME_ERR_QUEST_LOG_FULL then return true end
    return false
end

local lastAuto = 0
local function OnLogFull()
    if not ns.db.autoOpen then return end
    local now = ns.Num(ns.Call(GetTime)) or 0
    if now - lastAuto < 10 and lastAuto ~= 0 then return end
    lastAuto = now
    if not ns.UI.IsShown() then
        ns.UI.Show()
        ns.Print("Your quest log is full. Marked quests are the ones to drop first. (/abandon auto turns this off)")
    end
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame
local EVENTS = { "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "GROUP_ROSTER_UPDATE", "UI_ERROR_MESSAGE", "CHAT_MSG_ADDON",
    "PLAYER_REGEN_ENABLED", "QUEST_COMPLETE", "QUEST_FINISHED", "SUPER_TRACKING_CHANGED" }
for _, event in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, event) end

frame:SetScript("OnEvent", function(_, event, a, b, c, d)
    if event == "PLAYER_LOGIN" then
        InitDB()
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        ns.UI.Create()
        if ns.QuestLog then ns.QuestLog.Init() end
        if ns.Kit and ns.Options then      -- missing until the first full restart after the update
            local ok, err = pcall(ns.Options.Init)
            if not ok then ns.Print("options error: " .. tostring(err)) end
        end
    elseif not ns.db then
        return
    elseif event == "UI_ERROR_MESSAGE" then
        if IsLogFullError(a, b) then OnLogFull() end
    elseif event == "CHAT_MSG_ADDON" then
        OnAddonMessage(a, b, c, d)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ShowSuggestion()
    elseif event == "QUEST_COMPLETE" then           -- the reward panel of a quest being handed in
        reward = { id = ns.Num(ns.Call(GetQuestID)) }
    elseif event == "QUEST_FINISHED" then           -- a quest panel closed
        if reward and not reward.closed then reward.closed = Now() end
    elseif event == "SUPER_TRACKING_CHANGED" then
        OnSuperTrackingChanged()
    else
        if event == "QUEST_REMOVED" then
            OnQuestRemoved(a)
            OnTrackedQuestGone(ns.Num(a))
        elseif event == "QUEST_TURNED_IN" then
            local id = ns.Num(a)
            if id then turnedIn[id] = Now() end
            OnTrackedQuestGone(id)
        elseif event == "GROUP_ROSTER_UPDATE" then
            if not GroupChannel() then ns.ClearSuggestions() end
        end
        ns.Refresh()
    end
end)
