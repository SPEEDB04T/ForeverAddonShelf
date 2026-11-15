-- Follow Line: the group, the line and the messages that keep everyone's copy the same.
--
-- One player orders the line and calls it. Everyone with the addon gets the same
-- order: the first name leads, each next player follows the one before them. A
-- follow only starts from the player's own click or key press (the Follow button
-- in UI.lua); the game tells the addon when a follow begins and ends, and each
-- player passes that on, so everyone sees who is on the line.
local ADDON, ns = ...
local issecret = ns.issecret
local Norm, FullUnitName, Qualified = ns.Norm, ns.FullUnitName, ns.Qualified

local L = {}
ns.Line = L

local PREFIX = "FollowLine"
local MAX_LINE = 40

L.members = {}      -- [name] = { name, unit, class, rank (2 leader, 1 assistant, 0), isPlayer, hasAddon, version,
                    --            stamp (the line they have), following (on their line), demo, demoState }
L.roster = {}       -- names in the game's order
L.grouped = false
L.total = 0
L.line = nil        -- { by, stamp, raw = names as called, order = those still in the group, index = [name] = place }
L.draft = {}        -- the order in the window, not sent until "Call line"
L.touched = false   -- the player changed the draft by hand
L.target = nil      -- who the player follows in the line
L.place = nil       -- the player's place in the line
L.following = nil   -- who the game says the player is following right now
L.dropped = false   -- the player fell off the line
L.lastStamp, L.lastBy = 0, ""

local queue = {}
local partial = {}  -- [sender] = a line arriving in several messages

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------
local function Split(s, sep)
    local out, pos = {}, 1
    while true do
        local i = s:find(sep, pos, true)
        if not i then
            out[#out + 1] = s:sub(pos)
            break
        end
        out[#out + 1] = s:sub(pos, i - 1)
        pos = i + 1
    end
    return out
end

-- A whole number between lo and hi, or nil.
local function Int(s, lo, hi)
    if type(s) ~= "string" or not s:find("^%d+$") or #s > 10 then return nil end
    local n = tonumber(s)
    if not n or n < lo or n > hi then return nil end
    return n
end

local function Copy(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end

local function ServerTime()
    if GetServerTime then
        local ok, t = pcall(GetServerTime)
        if ok and type(t) == "number" and not issecret(t) then return math.floor(t) end
    end
    return math.floor(time())
end

local function Short(name)
    return (name:gsub("%-.*$", ""))
end

local function SameName(a, b)
    if not a or not b then return false end
    return a == b or Short(a) == Short(b)
end

local function ClassOf(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if ok and not issecret(class) and type(class) == "string" then return class end
end

-- 2 for the group's leader, 0 for anyone else, nil when the game won't say.
local function LeaderRank(unit)
    if not UnitIsGroupLeader then return nil end
    local ok, v = pcall(UnitIsGroupLeader, unit)
    if not ok or issecret(v) then return nil end
    return v and 2 or 0
end

local function InRaid()
    return (IsInRaid and IsInRaid()) and true or false
end

function L.Offline(m)
    if m.demo or m.isPlayer or not m.unit or not UnitIsConnected then return false end
    local ok, on = pcall(UnitIsConnected, m.unit)
    return ok and not issecret(on) and on == false
end

-- Close enough to start following them? true, false, or nil when the game won't say.
function L.InRange(m)
    if not m or m.demo or not m.unit then return nil end
    if UnitIsVisible then
        local ok, v = pcall(UnitIsVisible, m.unit)
        if ok and not issecret(v) and v == false then return false end
    end
    if CheckInteractDistance then
        local ok, v = pcall(CheckInteractDistance, m.unit, 4)      -- 4 = follow distance
        if ok and not issecret(v) and type(v) == "boolean" then return v end
    end
    return nil
end

function L.OnLine()
    return L.target ~= nil and SameName(L.following, L.target)
end

----------------------------------------------------------------------
-- The draft: the order shown in the window
----------------------------------------------------------------------
local function DraftPlace(name)
    for i, n in ipairs(L.draft) do
        if n == name then return i end
    end
end

local function DefaultOrder()
    local order = {}
    local me = ns.playerName and L.members[ns.playerName] and ns.playerName
    for _, name in ipairs(L.roster) do
        if name ~= me then order[#order + 1] = name end
    end
    if me then
        -- in the demo, alone, you stand second, so the demo shows your Follow button;
        -- in a group the caller leads
        local alone = L.demo and not L.grouped and #order > 0
        table.insert(order, alone and 2 or 1, me)
    end
    return order
end

local function Touch()
    L.touched = true
    ns.dirty = true
end

-- Group members who are not in the draft, in the game's order.
function L.Bench()
    local out = {}
    for _, name in ipairs(L.roster) do
        if not DraftPlace(name) then out[#out + 1] = name end
    end
    return out
end

-- Is the order in the window different from the line everyone has?
function L.DraftDiffers()
    local line = L.line
    if not line then return false end
    if #L.draft ~= #line.order then return true end
    for i, name in ipairs(L.draft) do
        if line.order[i] ~= name then return true end
    end
    return false
end

-- The group member a typed name means: the exact name, or the only one starting with it.
function L.Find(text)
    if type(text) ~= "string" then return nil end
    text = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    local found, many
    for _, name in ipairs(L.roster) do
        local lower = name:lower()
        if lower == text or Short(lower) == text then return name end
        if lower:sub(1, #text) == text then
            if found then many = true end
            found = name
        end
    end
    if many then return nil, "more than one player starts with '" .. text .. "'" end
    return found
end

local function Resolve(text)
    local name, why = L.Find(text)
    if not name then
        ns.Print(why or ("nobody in the group is called '" .. tostring(text) .. "'."))
    end
    return name
end

function L.Move(name, by)
    local i = DraftPlace(name)
    local j = i and (i + by)
    if not i or j < 1 or j > #L.draft then return end
    L.draft[i], L.draft[j] = L.draft[j], L.draft[i]
    Touch()
end

function L.Add(text)
    local name = Resolve(text)
    if not name or DraftPlace(name) then return end
    L.draft[#L.draft + 1] = name
    Touch()
end

function L.Remove(text)
    local name = Resolve(text)
    local i = name and DraftPlace(name)
    if not i then return end
    table.remove(L.draft, i)
    Touch()
end

function L.SetHead(text)
    local name = Resolve(text)
    if not name then return end
    local i = DraftPlace(name)
    if i then table.remove(L.draft, i) end
    table.insert(L.draft, 1, name)
    Touch()
end

function L.Reverse()
    local n = #L.draft
    for i = 1, math.floor(n / 2) do
        L.draft[i], L.draft[n + 1 - i] = L.draft[n + 1 - i], L.draft[i]
    end
    Touch()
end

-- "/line order ann bob": those names in that order first, everyone else already in the line behind them.
function L.SetOrder(text)
    local order, seen = {}, {}
    for word in tostring(text or ""):gmatch("[^%s,>]+") do
        local name = Resolve(word)
        if not name then return end
        if not seen[name] then
            seen[name] = true
            order[#order + 1] = name
        end
    end
    if #order == 0 then
        ns.Print("usage: /line order <name> <name> ... (the first one leads)")
        return
    end
    for _, name in ipairs(L.draft) do
        if not seen[name] then order[#order + 1] = name end
    end
    L.draft = order
    Touch()
end

local function PositionOf(m)
    if not UnitPosition or not m or m.demo then return nil end
    local unit = m.isPlayer and "player" or m.unit
    if not unit then return nil end
    local ok, y, x, _, map = pcall(UnitPosition, unit)
    if not ok or issecret(x) or issecret(y) or issecret(map) or type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, map
end

-- Keeps the leader and puts everyone else in the order that needs the least
-- walking: the nearest player to the leader second, the nearest to them third...
function L.ByDistance()
    local head = L.draft[1]
    local hx, hy, hmap = PositionOf(head and L.members[head])
    local pos, count = {}, 0
    for i = 2, #L.draft do
        local x, y, map = PositionOf(L.members[L.draft[i]])
        if x and map == hmap then
            pos[L.draft[i]] = { x, y }
            count = count + 1
        end
    end
    if not hx or count == 0 then
        ns.Print("can't see where everyone stands here (the game hides positions inside dungeons and raids).")
        return false
    end
    local order, cx, cy = { head }, hx, hy
    while count > 0 do
        local best, bestDist
        for name, p in pairs(pos) do
            local d = (p[1] - cx) ^ 2 + (p[2] - cy) ^ 2
            if not best or d < bestDist or (d == bestDist and name < best) then best, bestDist = name, d end
        end
        order[#order + 1] = best
        cx, cy = pos[best][1], pos[best][2]
        pos[best] = nil
        count = count - 1
    end
    -- players whose place the game didn't give keep their order, at the end
    local placed = {}
    for _, name in ipairs(order) do placed[name] = true end
    for _, name in ipairs(L.draft) do
        if not placed[name] then order[#order + 1] = name end
    end
    L.draft = order
    Touch()
    return true
end

----------------------------------------------------------------------
-- The line everyone has
----------------------------------------------------------------------
function L.MarkState(jitter)
    -- in a raid everyone answers the same question: spread the answers out
    local at = GetTime() + ((jitter and L.total > 5) and math.random() * 3 or 0)
    if not L.stateDirty or at < (L.stateAt or 0) then L.stateAt = at end
    L.stateDirty = true
end

-- Works out who is still in the line and who the player follows.
function L.Recompute(quiet)
    local line = L.line
    local was = L.target
    if not line then
        L.target, L.place = nil, nil
    else
        local order, index = {}, {}
        for _, name in ipairs(line.raw) do
            if L.members[name] and not index[name] then
                order[#order + 1] = name
                index[name] = #order
            end
        end
        line.order, line.index = order, index
        local i = ns.playerName and index[ns.playerName]
        L.place = i
        L.target = (i and i > 1) and order[i - 1] or nil
    end
    if L.target ~= was then
        if not L.target then L.dropped = false end
        ns.UI.ApplySecure()
        L.MarkState(false)
        if not quiet and L.target and was then
            ns.Print(("the line changed: you now follow %s."):format(L.target))
        end
    end
    ns.dirty = true
end

local function CombatNote()
    if ns.InCombat() and L.target then
        return (" The Follow button changes when the fight ends; until then type /follow %s."):format(L.target)
    end
    return ""
end

local function SetLine(by, stamp, raw)
    L.line = { by = by, stamp = stamp, raw = raw, order = {}, index = {} }
    L.lastStamp, L.lastBy = stamp, by
    L.dropped = false
    L.Recompute(true)
    L.draft = Copy(L.line.order)
    L.touched = false
    for _, m in pairs(L.members) do
        if m.demo then m.stamp = stamp end
    end
    L.MarkState(false)
    ns.dirty = true
end

local function ClearLine()
    L.line = nil
    L.dropped = false
    L.directUntil = nil
    L.Recompute(true)
    if not L.touched then L.draft = DefaultOrder() end
    L.MarkState(false)
    ns.dirty = true
end

----------------------------------------------------------------------
-- Roster
----------------------------------------------------------------------
local DEMO = {
    { name = "Demo Warrior", class = "WARRIOR", state = "on" },
    { name = "Demo Priest",  class = "PRIEST",  state = "off" },
    { name = "Demo Mage",    class = "MAGE",    state = "noaddon" },
    { name = "Demo Rogue",   class = "ROGUE",   state = "on" },
}

function L.Rebuild()
    local old = L.members
    local members, roster = {}, {}

    local function add(name, unit, class, rank)
        name = Norm(name)
        if not name or members[name] then return end
        local m = old[name]
        if not m or m.demo then m = { name = name } end
        m.unit = unit
        if type(class) == "string" then m.class = class end
        if rank ~= nil then m.rank = rank end
        m.isPlayer = (name == ns.playerName)
        members[name] = m
        roster[#roster + 1] = name
    end

    local grouped = (IsInGroup and IsInGroup()) and true or false
    if grouped and InRaid() then
        for i = 1, GetNumGroupMembers() do
            local ok, name, rank, _, _, _, class = pcall(GetRaidRosterInfo, i)
            if ok and not issecret(name) and not issecret(rank) and not issecret(class) then
                add(name, "raid" .. i, class, type(rank) == "number" and rank or nil)
            end
        end
    elseif grouped then
        add(ns.playerName, "player", ns.playerClass, LeaderRank("player"))
        for i = 1, 4 do
            local unit = "party" .. i
            local name = FullUnitName(unit)
            if name then add(name, unit, ClassOf(unit), LeaderRank(unit)) end
        end
    end
    if ns.playerName and not members[ns.playerName] then
        add(ns.playerName, "player", ns.playerClass, LeaderRank("player"))
    end

    if L.demo then
        for _, d in ipairs(DEMO) do
            local m = old[d.name]
            if not (m and m.demo) then
                m = { name = d.name, class = d.class, demo = true, demoState = d.state, hasAddon = d.state ~= "noaddon" }
            end
            if not members[d.name] then
                members[d.name] = m
                roster[#roster + 1] = d.name
            end
        end
    end

    L.members, L.roster, L.total = members, roster, #roster

    local active = grouped or L.demo
    if not active then
        -- left the group: nothing of the line is left
        for i = #queue, 1, -1 do queue[i] = nil end
        partial = {}
        L.stateDirty, L.wantRequest, L.resendAt = false, false, nil
        L.touched = false
        if L.line then ClearLine() end
    elseif grouped and not L.grouped then
        -- just joined (or logged in / reloaded inside a group): ask everyone, tell everyone
        L.wantRequest = true
        L.MarkState(false)
    end
    L.grouped = grouped

    -- players who left are out of the draft and out of the line
    for i = #L.draft, 1, -1 do
        if not members[L.draft[i]] then table.remove(L.draft, i) end
    end
    if L.line then
        L.Recompute()
        if #L.line.order < 2 then
            ns.Print("the line ended: fewer than two of its players are left.")
            ClearLine()
        elseif not L.touched then
            L.draft = Copy(L.line.order)
        end
    elseif not L.touched then
        L.draft = DefaultOrder()
    end
    ns.dirty = true
end

function L.SetDemo(on)
    L.demo = on and true or false
    if not L.demo and not L.grouped and L.line then ClearLine() end
    L.touched = false
    L.Rebuild()
end

----------------------------------------------------------------------
-- Who may call a line
----------------------------------------------------------------------
function L.MayCall(name)
    local m = L.members[name]
    if not m then return false end
    local who = ns.db.who
    if who == "anyone" then return true end
    if who == "auto" and not InRaid() then return true end
    return (m.rank or 0) > 0
end

local ignoredFrom = {}
local function NoteIgnored(from)
    if ignoredFrom[from] then return end
    ignoredFrom[from] = true
    ns.Print(("%s called a line, but you only take them from the leader and assistants. /line who anyone changes that."):format(from))
end

----------------------------------------------------------------------
-- Sending
----------------------------------------------------------------------
local function AddonChannel()
    if not (IsInGroup and IsInGroup()) then return nil end
    if LE_PARTY_CATEGORY_INSTANCE and LE_PARTY_CATEGORY_HOME
        and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and not IsInGroup(LE_PARTY_CATEGORY_HOME) then
        return "INSTANCE_CHAT"
    end
    if InRaid() then return "RAID" end
    return "PARTY"
end

-- nil when messages can go out, otherwise why not. The realm's switch
-- AreOutgoingAddonChatMessagesRestricted is not asked: it is on for ordinary
-- realms, and addon messages inside a group go out all the same.
function L.CommsBlocked()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return "this client has no addon messages" end
    if C_ChatInfo.InChatMessagingLockdown then
        local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and (issecret(v) or v) then return "chat is locked right now" end
    end
    return nil
end

-- For the status line: a block, or what the game answered when it refused
-- the last message (cleared by the next one that goes out).
local refused
function L.CommsProblem()
    return L.CommsBlocked() or refused
end

local function Enqueue(msg)
    if #queue >= 20 then table.remove(queue, 1) end
    queue[#queue + 1] = msg
end

-- "S;version;stamp of the line I have (0 = none);1 when I follow my place in it"
local function StateMessage()
    return ("S;%s;%d;%d"):format(ns.VERSION, L.line and L.line.stamp or 0, L.OnLine() and 1 or 0)
end

-- "L;stamp;part;parts;Name-Realm,Name-Realm,...": a long line goes out in parts.
local function EnqueueLine()
    local line = L.line
    if not line then return end
    local chunks, cur = {}, ""
    for _, name in ipairs(line.order) do
        local q = Qualified(name)
        if cur ~= "" and #cur + 1 + #q > 200 then
            chunks[#chunks + 1] = cur
            cur = q
        else
            cur = (cur == "") and q or (cur .. "," .. q)
        end
    end
    chunks[#chunks + 1] = cur
    for i, chunk in ipairs(chunks) do
        Enqueue(("L;%d;%d;%d;%s"):format(line.stamp, i, #chunks, chunk))
    end
end

-- Calls and stops go out at once (a few in a row at most); the rest one a second.
local sendErrors = 0
local function Flush(now)
    local channel = AddonChannel()
    if not channel then
        for i = #queue, 1, -1 do queue[i] = nil end
        L.stateDirty, L.wantRequest = false, false
        return
    end
    if L.CommsBlocked() then return end
    for _ = 1, 4 do
        local msg, kind
        if #queue > 0 then
            msg, kind = queue[1], "queue"
        elseif L.wantRequest then
            msg, kind = "Q", "request"
        elseif L.stateDirty and now >= (L.stateAt or 0) then
            msg, kind = StateMessage(), "state"
        else
            return
        end
        local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel)
        if not ok then
            -- the game rejects this very message: after a few tries give up on it,
            -- so everything behind it is not stuck for good
            sendErrors = sendErrors + 1
            if sendErrors < 3 then return end
        else
            local sent = not (type(result) == "number" and result ~= 0) and result ~= false
            if not sent then                -- throttled or refused: try again next second
                if result ~= 3 and result ~= 8 then     -- 3 and 8 are the game's throttles
                    refused = "the game refused the last message (code " .. tostring(result) .. ")"
                end
                return
            end
        end
        sendErrors, refused = 0, nil
        if kind == "request" then
            L.wantRequest = false
            return
        elseif kind == "state" then
            L.stateDirty = false
            return
        end
        table.remove(queue, 1)
    end
end

----------------------------------------------------------------------
-- Following
----------------------------------------------------------------------
-- Only with "follow without a click" on: asks the game to follow the player
-- ahead. Where the game keeps that for a click or a key press it refuses, and
-- DirectRefused turns the option off again.
function L.TryDirect()
    if not (ns.db.auto and L.target and FollowUnit) or L.OnLine() then return end
    local m = L.members[L.target]
    if not m or m.demo or not m.unit then return end
    L.directAt = GetTime()
    pcall(FollowUnit, m.unit)
end

function L.DirectRefused()
    if not ns.db.auto then return end
    ns.db.auto = false
    L.directUntil, L.directWorks = nil, false
    ns.Print("the game only starts a follow from your own click or key press, so 'follow without a click' is off again. Use the Follow button or your key.")
    if ns.Kit then ns.Kit.Sync() end
    ns.dirty = true
end

function L.OnFollowBegin(name)
    if issecret(name) or type(name) ~= "string" or name == "" then
        L.following = L.target or "?"       -- the game won't say who: take it to be the line
    else
        L.following = Norm(name) or "?"
    end
    if L.directAt and GetTime() - L.directAt < 2 then L.directWorks = true end
    if L.OnLine() then
        L.dropped = false
        L.directUntil = nil
    end
    L.MarkState(false)
    ns.dirty = true
end

function L.OnFollowEnd()
    local was = L.OnLine()
    L.following = nil
    L.directUntil = nil
    if was then
        L.dropped = true
        ns.Sound("drop")
        ns.Print(("you dropped off the line. Press the Follow button or your key to follow %s again."):format(L.target))
    end
    L.MarkState(false)
    ns.dirty = true
end

-- Someone asked everyone who is off the line to fall in.
local lastNudge = 0
local function Nudge(by)
    if not L.target or L.OnLine() then return end
    local now = GetTime()
    if now - lastNudge < 3 then return end
    lastNudge = now
    L.dropped = true
    if by ~= ns.playerName then
        ns.Sound("call")
        ns.Print(("%s asks everyone to fall in: follow %s.%s"):format(by, L.target, CombatNote()))
    end
    L.directUntil = now + 15
    L.TryDirect()
    ns.dirty = true
end

----------------------------------------------------------------------
-- Calling, stopping, nudging
----------------------------------------------------------------------
local function NextStamp()
    return math.max(ServerTime(), L.lastStamp + 1)
end

-- What calling did, for the one who called: who got a Follow button and who has to be told.
function L.TellCaller()
    local line = L.line
    if not line then return end
    local with, without = 0, {}
    for i = 2, #line.order do
        local name = line.order[i]
        local m = L.members[name]
        if m and not m.isPlayer then
            if m.hasAddon then with = with + 1 else without[#without + 1] = name end
        end
    end
    if L.place == 1 then
        ns.Print("you lead, so you get no Follow button: the players behind you do.")
    end
    if with > 0 then
        ns.Print(("%d %s Follow Line and now %s a Follow button."):format(
            with, with == 1 and "player has" or "players have", with == 1 and "has" or "have"))
    end
    if #without > 0 then
        ns.Print(("no Follow Line seen for %s, so no Follow button for them. Press Announce (/line announce) to tell them whom to /follow."):format(
            table.concat(without, ", ")))
    end
end

function L.Call()
    if not (L.grouped or L.demo) then
        ns.Print("you're not in a group.")
        return false
    end
    local order = {}
    for _, name in ipairs(L.draft) do
        if L.members[name] and #order < MAX_LINE then order[#order + 1] = name end
    end
    if #order < 2 then
        ns.Print("put at least two players in the line first.")
        return false
    end
    if L.grouped then
        local why = L.CommsBlocked()
        if why then
            ns.Print("can't send the line: " .. why .. ".")
            return false
        end
    end
    SetLine(ns.playerName, NextStamp(), order)
    EnqueueLine()
    Flush(GetTime())
    ns.Print("line called: " .. table.concat(L.line.order, " > ") .. "." .. CombatNote())
    L.TellCaller()
    local me = L.members[ns.playerName]
    if InRaid() and me and (me.rank or 0) == 0 then
        ns.Print("you're not the raid leader or an assistant: players only take your line if they set /line who anyone.")
    end
    if L.target then
        L.directUntil = GetTime() + 15
        L.TryDirect()
    end
    return true
end

function L.Stop()
    if not L.line then
        ns.Print("there is no line to end.")
        return false
    end
    local stamp = NextStamp()
    L.lastStamp, L.lastBy = stamp, ns.playerName
    local wasOn = L.OnLine()
    ClearLine()
    Enqueue(("X;%d"):format(stamp))
    Flush(GetTime())
    ns.Print("line ended.")
    if wasOn and L.directWorks and FollowUnit then pcall(FollowUnit, "player") end   -- following yourself stops a follow
    return true
end

function L.Regroup()
    if not L.line then
        ns.Print("there is no line. Call one first.")
        return false
    end
    Enqueue("P")
    Flush(GetTime())
    local on, followers = L.Summary()
    ns.Print(("asked everyone to fall in (%d of %d following)."):format(on, followers))
    Nudge(ns.playerName)
    return true
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
local function Newer(stamp, by)
    -- a stamp from far in the future is a mistake; taking it would shut out every real call after it
    if stamp > ServerTime() + 86400 then return false end
    return stamp > L.lastStamp or (stamp == L.lastStamp and by > L.lastBy)
end

local function TellPlace(by)
    local n = #L.line.order
    if L.place == 1 then
        ns.Print(("%s called a line of %d: you lead."):format(by, n))
    elseif L.target then
        ns.Print(("%s called a line: you follow %s (place %d of %d). Press the Follow button or your key.%s"):format(
            by, L.target, L.place, n, CombatNote()))
    else
        ns.Print(("%s called a line. You are not in it."):format(by))
    end
end

function L.OnAddonMessage(prefix, text, channel, sender)
    if issecret(prefix) or issecret(text) or issecret(sender) then return end
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local from = Norm(sender)
    if not from or from == ns.playerName then return end
    local m = L.members[from]
    if not m or m.demo then return end      -- only people in the group are listened to
    local f = Split(text, ";")
    local kind = f[1]
    if kind == "S" then
        local stamp, fol = Int(f[3], 0, 9999999999), Int(f[4], 0, 1)
        if not (stamp and fol) then return end
        local line = L.line
        local wasOn = m.following and line and m.stamp == line.stamp
        m.hasAddon = true
        -- the version ends up in a tooltip: keep it to plain characters
        m.version = (tostring(f[2] or ""):gsub("[^%w%._%-]", "")):sub(1, 12)
        m.stamp = stamp
        m.following = (fol == 1)
        if wasOn and not m.following and m.stamp == line.stamp and (line.index[from] or 0) > 1 then
            local now = GetTime()
            if ns.db.alerts and now - (m.alertAt or -10) > 5 then
                m.alertAt = now
                ns.Print(from .. " dropped off the line.")
            end
        end
        ns.dirty = true
    elseif kind == "Q" then
        L.MarkState(true)
        -- the one who called the line gives it to whoever just joined or reloaded
        if L.line and L.line.by == ns.playerName and not L.resendAt then
            L.resendAt = GetTime() + ((L.total > 5) and (1 + math.random() * 2) or 1)
        end
    elseif kind == "L" then
        local stamp, part, parts = Int(f[2], 1, 9999999999), Int(f[3], 1, 9), Int(f[4], 1, 9)
        if not (stamp and part and parts) or part > parts or type(f[5]) ~= "string" then return end
        if not L.MayCall(from) then
            NoteIgnored(from)
            return
        end
        if not Newer(stamp, from) then return end
        local p = partial[from]
        if not p or p.stamp ~= stamp or p.parts ~= parts then
            p = { stamp = stamp, parts = parts, got = {}, n = 0 }
            partial[from] = p
        end
        if not p.got[part] then
            p.got[part] = f[5]
            p.n = p.n + 1
        end
        if p.n < parts then return end
        partial[from] = nil
        local raw, seen = {}, {}
        for i = 1, parts do
            for _, word in ipairs(Split(p.got[i], ",")) do
                local name = (#word <= 80 and not word:find("[|%c]")) and Norm(word) or nil
                if name and not seen[name] and #raw < MAX_LINE then
                    seen[name] = true
                    raw[#raw + 1] = name
                end
            end
        end
        if #raw < 2 then return end
        SetLine(from, stamp, raw)
        TellPlace(from)
        if L.target then
            ns.Sound("call")
            L.directUntil = GetTime() + 15
            L.TryDirect()
        end
    elseif kind == "X" then
        local stamp = Int(f[2], 1, 9999999999)
        if not stamp or not L.MayCall(from) or not Newer(stamp, from) then return end
        L.lastStamp, L.lastBy = stamp, from
        if not L.line then return end
        local wasOn = L.OnLine()
        ClearLine()
        ns.Print(from .. " ended the line.")
        if wasOn and L.directWorks and FollowUnit then pcall(FollowUnit, "player") end
    elseif kind == "P" then
        if L.line and L.MayCall(from) then Nudge(from) end
    end
end

----------------------------------------------------------------------
-- What is known about one player
----------------------------------------------------------------------
-- "none"     no line has been called
-- "out"      not in the line
-- "offline"
-- "head"     leads the line
-- "on"       following the player ahead of them
-- "off"      has the line but is not following
-- "pending"  has the addon but hasn't got this line yet
-- "noaddon"  can't tell: they follow by hand
function L.Status(m)
    local line = L.line
    if not line then return "none" end
    local i = line.index[m.name]
    if not i then return "out" end
    if L.Offline(m) then return "offline" end
    if i == 1 then return "head" end
    if m.isPlayer then return L.OnLine() and "on" or "off" end
    if m.demo then return m.demoState end
    if not m.hasAddon then return "noaddon" end
    if m.stamp ~= line.stamp then return "pending" end
    return m.following and "on" or "off"
end

-- following, those who could be (in the line behind the leader, with the addon), everyone in the line
function L.Summary()
    local line = L.line
    if not line then return 0, 0, 0 end
    local on, followers = 0, 0
    for i = 2, #line.order do
        local m = L.members[line.order[i]]
        local st = m and L.Status(m)
        if st == "on" or st == "off" or st == "pending" then
            followers = followers + 1
            if st == "on" then on = on + 1 end
        end
    end
    return on, followers, #line.order
end

local TEXT = {
    none = "no line called",
    out = "not in the line",
    offline = "offline",
    head = "leads the line",
    on = "following",
    off = "off the line",
    pending = "hasn't got the line yet",
    noaddon = "no addon: follows by hand",
}

function L.Describe(m)
    local st = L.Status(m)
    local text = TEXT[st]
    local line = L.line
    local i = line and line.index[m.name]
    if i and i > 1 and (st == "on" or st == "off" or st == "noaddon" or st == "pending") then
        text = text .. (st == "on" and " " or ", should follow ") .. line.order[i - 1]
    end
    return text, st
end

function L.PrintStatus()
    local line = L.line
    if not line then
        ns.Print("no line called. Addon messages: " .. (L.CommsProblem() or "ok") .. ".")
    else
        local on, followers, total = L.Summary()
        ns.Print(("line of %d called by %s, %d of %d following. Addon messages: %s."):format(
            total, line.by, on, followers, L.CommsProblem() or "ok"))
        for i, name in ipairs(line.order) do
            local m = L.members[name]
            ns.Print(("  %d. %s: %s"):format(i, name, m and (L.Describe(m)) or "?"))
        end
    end
    local bench = {}
    for _, name in ipairs(L.roster) do
        if not (line and line.index[name]) then bench[#bench + 1] = name end
    end
    if line and #bench > 0 then ns.Print("  not in the line: " .. table.concat(bench, ", ")) end
    if L.target then
        ns.Print(("you follow %s%s."):format(L.target, L.OnLine() and "" or " (not following right now)"))
    end
end

----------------------------------------------------------------------
-- Announce: the order as plain chat, for players without the addon
----------------------------------------------------------------------
function L.Announce()
    local channel = AddonChannel()
    if not channel then
        ns.Print("you're not in a group.")
        return
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if not send then return end
    if C_ChatInfo and C_ChatInfo.InChatMessagingLockdown then
        local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and (issecret(v) or v) then
            ns.Print("chat is locked right now. Try again after the fight.")
            return
        end
    end
    local order = L.line and L.line.order or L.draft
    if #order < 2 then
        ns.Print("put at least two players in the line first.")
        return
    end
    local lead = "Follow line: "
    local text = lead
    for i, name in ipairs(order) do
        local part = (i == 1 and "" or " > ") .. name
        if #text + #part > 240 then
            pcall(send, text, channel)
            text = "... " .. name
        else
            text = text .. part
        end
    end
    pcall(send, text, channel)
    pcall(send, "Each of you follows the player before you: /follow and their name.", channel)
end

----------------------------------------------------------------------
-- Once a second
----------------------------------------------------------------------
function L.Tick(now)
    if L.resendAt and now >= L.resendAt then
        L.resendAt = nil
        if L.line and L.line.by == ns.playerName then EnqueueLine() end
    end
    if L.directUntil then
        if now >= L.directUntil or not ns.db.auto or L.OnLine() then
            L.directUntil = nil
        elseif L.InRange(L.members[L.target]) ~= false then
            L.TryDirect()
        end
    end
    Flush(now)
end

function L.Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    L.Rebuild()
end
