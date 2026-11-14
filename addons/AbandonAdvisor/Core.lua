-- Abandon Advisor: core (settings, safe API access, abandoning, events, slash commands)
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.0.0"

local defaults = {
    point = nil,
    scale = 1,
    autoOpen = true,   -- open the window when the game says the quest log is full
    target = 3,        -- how many free slots the advice aims for
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
    ns.result = ns.Score.RateAll(quests, player, meta, { target = ns.db.target, keep = ns.cdb.keep })
    return ns.result
end

local refreshQueued = false
function ns.Refresh()
    if not (ns.UI and ns.UI.IsShown()) then return end
    if refreshQueued then return end
    refreshQueued = true
    ns.After(0.15, function()
        refreshQueued = false
        if ns.UI.IsShown() then ns.UI.Update(ns.Compute()) end
    end)
end

function ns.ToggleKeep(questID)
    local keep = ns.cdb.keep
    if keep[questID] then keep[questID] = nil else keep[questID] = true end
    return keep[questID] == true
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
                row.pick and "|cffff5555» " or "|cffdddddd", row.level and tostring(row.level) or "?",
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
    ns.Print("Questie data: " .. (ns.Scan.Questie() and "yes" or "no"))
    local res = ns.Compute()
    local p = res.player
    ns.Print(("player level %s, max %s, xpMax %s, zone %s, grouped %s, grey range %s"):format(
        tostring(p.level), tostring(p.maxLevel), tostring(p.xpMax), tostring(p.zone), tostring(p.grouped),
        tostring(p.greenRange)))
    for _, row in ipairs(res.rows) do
        local parts = {}
        for _, reason in ipairs(row.reasons) do parts[#parts + 1] = ("%+d %s"):format(reason.pts, reason.short) end
        ns.Print(("%d [%s] %s: %s %d | xp %s, prog %s, tag %s, zone %s | %s"):format(
            row.id, tostring(row.level), row.title, row.verdict, row.score, tostring(row.xp),
            row.progress and ("%.2f"):format(row.progress) or "-", tostring(row.tag), tostring(row.zone),
            table.concat(parts, "; ")))
    end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function Slash(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        ns.UI.Toggle()
    elseif cmd == "list" or cmd == "report" then
        ns.Report()
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
    elseif cmd == "unpin" then
        ns.cdb.keep = {}
        ns.Print("All pinned quests released.")
        ns.Refresh()
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
        ns.Print("Commands: /abandon (window), list, free <n>, auto, unpin, scale <n>, reset, debug")
    end
end

SLASH_ABANDONADVISOR1 = "/abandon"
SLASH_ABANDONADVISOR2 = "/aa"
SLASH_ABANDONADVISOR3 = "/abandonadvisor"
SlashCmdList = SlashCmdList or {}
SlashCmdList["ABANDONADVISOR"] = Slash

function AbandonAdvisor_Toggle()
    if ns.UI and ns.db then ns.UI.Toggle() end
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
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "GROUP_ROSTER_UPDATE", "UI_ERROR_MESSAGE" }
for _, event in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, event) end

frame:SetScript("OnEvent", function(_, event, a, b)
    if event == "PLAYER_LOGIN" then
        InitDB()
        ns.UI.Create()
    elseif not ns.db then
        return
    elseif event == "UI_ERROR_MESSAGE" then
        if IsLogFullError(a, b) then OnLogFull() end
    else
        ns.Refresh()
    end
end)
