-- Healthstone Tracker: everyone in the group and what is known about their stone.
-- Players with the addon tell the group exactly what they carry. For players
-- without it the addon works from what can be seen: a warlock handing them a
-- stone in a trade, and the moment they use one.
local ADDON, ns = ...
local issecret = ns.issecret
local Norm, FullUnitName, Qualified = ns.Norm, ns.FullUnitName, ns.Qualified

local G = {}
ns.Group = G

local PREFIX = "HSTracker"

G.members = {}      -- [name] = { name, unit, class, subgroup, isPlayer, hasAddon, version, item, count, cdEnd, seen, demo }
G.byUnit = {}       -- unit token -> name
G.grouped = false
G.warlocks = 0
G.total = 0

local queue = {}

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
    if type(s) ~= "string" or not s:find("^%d+$") or #s > 9 then return nil end
    local n = tonumber(s)
    if not n or n < lo or n > hi then return nil end
    return n
end

local function ClassOf(unit)
    local ok, _, class = pcall(UnitClass, unit)
    if ok and not issecret(class) and type(class) == "string" then return class end
end

local function Seen(m)
    if m.seen then return m.seen end
    local s = {}
    m.seen = s
    if not m.demo then ns.cdb.seen[m.name] = s end
    return s
end

----------------------------------------------------------------------
-- What is known about one player
----------------------------------------------------------------------
-- Returns the state and the seconds left on their healthstone cooldown (or nil):
--   "has"      carries one (they have the addon, or it is the player)
--   "none"     carries none (they have the addon)
--   "given"    no addon: a warlock traded them one and they haven't been seen using it
--   "used"     no addon: seen using one, so probably without one now
--   "unknown"  no addon and nothing seen
function G.Status(m)
    local src = m.isPlayer and ns.me or m
    local now = GetTime()
    local cd = src.cdEnd and src.cdEnd > now and (src.cdEnd - now) or nil
    if m.isPlayer or m.hasAddon then
        if (src.count or 0) > 0 then return "has", cd end
        return "none", cd
    end
    local s = m.seen
    if s then
        if s.givenAt and (not s.usedAt or s.usedAt < s.givenAt) then return "given", cd end
        if s.usedAt then return "used", cd end
    end
    return "unknown", cd
end

function G.ItemOf(m)
    if m.isPlayer then return ns.me.item end
    if m.hasAddon then return m.item end
    return m.seen and m.seen.givenItem or nil
end

local ORDER = { none = 1, used = 2, unknown = 3, given = 4, has = 5 }

-- For display: those who need a stone first, then the unknown, then the rest.
function G.SortedMembers()
    local list, state = {}, {}
    for _, m in pairs(G.members) do
        list[#list + 1] = m
        state[m] = ORDER[G.Status(m)]
    end
    table.sort(list, function(a, b)
        if state[a] ~= state[b] then return state[a] < state[b] end
        return a.name < b.name
    end)
    return list
end

-- have, need, unknown, total
function G.Summary()
    local have, need, unknown, total = 0, 0, 0, 0
    for _, m in pairs(G.members) do
        total = total + 1
        local st = G.Status(m)
        if st == "has" or st == "given" then
            have = have + 1
        elseif st == "unknown" then
            unknown = unknown + 1
        else
            need = need + 1
        end
    end
    return have, need, unknown, total
end

----------------------------------------------------------------------
-- Roster
----------------------------------------------------------------------
local DEMO = {
    { name = "Demo Mage",    class = "MAGE",    hasAddon = true, item = 9421, count = 1 },
    { name = "Demo Warrior", class = "WARRIOR", hasAddon = true, count = 0 },
    { name = "Demo Priest",  class = "PRIEST",  given = 240 },
    { name = "Demo Rogue",   class = "ROGUE",   used = 35 },
    { name = "Demo Hunter",  class = "HUNTER" },
}

local function DemoMember(d)
    local m = { name = d.name, class = d.class, subgroup = 1, demo = true,
                hasAddon = d.hasAddon, version = d.hasAddon and ns.VERSION or nil, item = d.item, count = d.count }
    if d.given then m.seen = { givenAt = time() - d.given, givenBy = ns.playerName or "a warlock", givenItem = 9421 } end
    if d.used then
        m.seen = { usedAt = time() - d.used }
        m.cdEnd = GetTime() + ns.COOLDOWN - d.used
    end
    return m
end

function G.MarkState(jitter)
    -- in a raid everyone answers the same question: spread the answers out
    local at = GetTime() + ((jitter and G.total > 5) and math.random() * 3 or 0)
    if not G.stateDirty or at < (G.stateAt or 0) then G.stateAt = at end
    G.stateDirty = true
end

function G.Rebuild()
    local old = G.members
    local members, byUnit = {}, {}
    local newcomer = false

    local function add(name, unit, class, subgroup)
        name = Norm(name)
        if not name then return end
        byUnit[unit] = name
        local m = members[name] or old[name]
        if not m or m.demo then
            m = { name = name }
            if name ~= ns.playerName then newcomer = true end
        end
        m.unit = unit
        if type(class) == "string" then m.class = class end
        m.subgroup = type(subgroup) == "number" and subgroup or 1
        m.isPlayer = (name == ns.playerName)
        m.seen = ns.cdb.seen[name]
        members[name] = m
    end

    local grouped = (IsInGroup and IsInGroup()) and true or false
    if grouped and IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local ok, name, _, subgroup, _, _, class = pcall(GetRaidRosterInfo, i)
            if ok and not issecret(name) and not issecret(subgroup) and not issecret(class) then
                add(name, "raid" .. i, class, subgroup)
            end
        end
        -- inside a raid, partyN units are the player's subgroup mates
        for i = 1, 4 do
            local name = FullUnitName("party" .. i)
            if name then byUnit["party" .. i] = name end
        end
    elseif grouped then
        for i = 1, 4 do
            local unit = "party" .. i
            local name = FullUnitName(unit)
            if name then add(name, unit, ClassOf(unit), 1) end
        end
    end
    if ns.playerName and not members[ns.playerName] then
        add(ns.playerName, "player", ns.playerClass, 1)
    end

    if G.demo then
        for _, d in ipairs(DEMO) do
            local m = old[d.name]
            if not (m and m.demo) then m = DemoMember(d) end
            members[d.name] = m
        end
    end

    local warlocks, total = 0, 0
    for _, m in pairs(members) do
        total = total + 1
        if m.class == "WARLOCK" then warlocks = warlocks + 1 end
    end
    G.members, G.byUnit, G.warlocks, G.total = members, byUnit, warlocks, total

    if grouped and not G.grouped then
        -- just joined (or logged in / reloaded inside a group): ask everyone, tell everyone
        G.wantRequest = true
        G.MarkState(false)
    elseif grouped and newcomer then
        G.MarkState(true)
    elseif not grouped and G.grouped then
        -- left the group: what was seen about those players no longer matters
        for name in pairs(ns.cdb.seen) do ns.cdb.seen[name] = nil end
        for i = #queue, 1, -1 do queue[i] = nil end
        G.stateDirty, G.wantRequest = false, false
        local me = ns.playerName and members[ns.playerName]
        if me then me.seen = nil end
    end
    G.grouped = grouped
    ns.dirty = true
end

function G.SetDemo(on)
    G.demo = on and true or false
    G.Rebuild()
end

----------------------------------------------------------------------
-- Things seen (works for players without the addon)
----------------------------------------------------------------------
function G.ObserveUse(unit)
    local name = G.byUnit[unit]
    local m = name and G.members[name]
    if not m or m.isPlayer then return end
    local now = GetTime()
    if m.lastUse and now - m.lastUse < 1 then return end    -- same cast reported as raidN and partyN
    m.lastUse = now
    m.cdEnd = now + ns.COOLDOWN
    if m.hasAddon then
        -- their own message follows; until then, one less
        if (m.count or 0) > 0 then m.count = m.count - 1 end
    else
        Seen(m).usedAt = time()
    end
    ns.dirty = true
end

local function RecordGift(m, by, item)
    local s = Seen(m)
    s.givenAt, s.givenBy, s.givenItem = time(), by, (item and item > 0) and item or nil
    if s.usedAt and s.usedAt >= s.givenAt then s.usedAt = s.givenAt - 1 end    -- the new stone is the later fact
    ns.dirty = true
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
    if IsInRaid and IsInRaid() then return "RAID" end
    return "PARTY"
end

-- nil when messages can go out, otherwise why not.
function G.CommsBlocked()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return "this client has no addon messages" end
    if C_ChatInfo.AreOutgoingAddonChatMessagesRestricted then
        local ok, v = pcall(C_ChatInfo.AreOutgoingAddonChatMessagesRestricted)
        if ok and not issecret(v) and v then return "this realm blocks addon messages" end
    end
    if C_ChatInfo.InChatMessagingLockdown then
        local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and (issecret(v) or v) then return "chat is locked right now (it syncs again afterwards)" end
    end
    return nil
end

local function Enqueue(msg)
    if #queue >= 20 then table.remove(queue, 1) end
    queue[#queue + 1] = msg
end

-- "S;version;itemID;count;cooldown seconds left"
local function StateMessage()
    local me = ns.me
    local cd = me.cdEnd and math.max(0, math.ceil(me.cdEnd - GetTime())) or 0
    return ("S;%s;%d;%d;%d"):format(ns.VERSION, me.item or 0, me.count or 0, cd)
end

-- One message a second at most: a request first, then the player's state,
-- then whatever is queued. The state never goes twice in a row while other
-- messages wait.
local lastKind, sendErrors = nil, 0
local function Flush(now)
    local channel = AddonChannel()
    if not channel then
        for i = #queue, 1, -1 do queue[i] = nil end
        G.stateDirty, G.wantRequest = false, false
        return
    end
    if G.CommsBlocked() then return end
    local msg, kind
    if G.wantRequest then
        msg, kind = "Q", "request"
    elseif G.stateDirty and now >= (G.stateAt or 0) and not (lastKind == "state" and #queue > 0) then
        msg, kind = StateMessage(), "state"
    elseif #queue > 0 then
        msg, kind = queue[1], "queue"
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
        if not sent then return end     -- throttled or refused: try again next second
    end
    sendErrors = 0
    lastKind = kind
    if kind == "request" then
        G.wantRequest = false
    elseif kind == "state" then
        G.stateDirty = false
    else
        table.remove(queue, 1)
    end
end

-- The player traded a healthstone to someone.
function G.NoteGave(name, item)
    local m = name and G.members[name]
    if not m or m.isPlayer or m.demo then return end
    RecordGift(m, ns.playerName, item)
    -- someone with the addon reports their own bags; the others need telling
    if not m.hasAddon then
        Enqueue(("G;%s;%d"):format(Qualified(name), item or 0))
    end
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
function G.OnAddonMessage(prefix, text, channel, sender)
    if issecret(prefix) or issecret(text) or issecret(sender) then return end
    if prefix ~= PREFIX or type(text) ~= "string" then return end
    local from = Norm(sender)
    if not from or from == ns.playerName then return end
    local m = G.members[from]
    if not m or m.demo then return end      -- only people in the group are listened to
    local f = Split(text, ";")
    local kind = f[1]
    if kind == "S" then
        local item, count, cd = Int(f[3], 0, 9999999), Int(f[4], 0, 200), Int(f[5], 0, 3600)
        if not (item and count and cd) then return end
        m.hasAddon = true
        -- the version ends up in a tooltip: keep it to plain characters
        m.version = (tostring(f[2] or ""):gsub("[^%w%._%-]", "")):sub(1, 12)
        m.item = item > 0 and item or nil
        m.count = count
        m.cdEnd = cd > 0 and (GetTime() + cd) or nil
        ns.dirty = true
    elseif kind == "Q" then
        G.MarkState(true)
    elseif kind == "G" then
        local target = Norm(f[2])
        local tm = target and G.members[target]
        local item = Int(f[3], 0, 9999999)
        if not tm or tm.isPlayer or tm.demo or not item then return end
        RecordGift(tm, from, item)
    end
end

----------------------------------------------------------------------
-- Announce: who still needs one, as plain chat
----------------------------------------------------------------------
local function SendNames(send, channel, lead, names)
    local line = lead
    for i, name in ipairs(names) do
        local part = (line == lead and "" or ", ") .. name
        if #line + #part > 240 then
            pcall(send, line, channel)
            line = lead .. name
        else
            line = line .. part
        end
    end
    pcall(send, line, channel)
end

function G.Announce()
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
    local need, unknown = {}, {}
    for _, m in ipairs(G.SortedMembers()) do
        if not m.demo then
            local st = G.Status(m)
            if st == "none" or st == "used" then
                need[#need + 1] = m.name
            elseif st == "unknown" then
                unknown[#unknown + 1] = m.name
            end
        end
    end
    if #need == 0 and #unknown == 0 then
        pcall(send, "Healthstones: everyone has one.", channel)
        return
    end
    if #need > 0 then SendNames(send, channel, "Need a healthstone: ", need) end
    if #unknown > 0 then SendNames(send, channel, "Healthstone not known (no addon): ", unknown) end
end

----------------------------------------------------------------------
-- Once a second
----------------------------------------------------------------------
function G.Tick(now)
    for _, m in pairs(G.members) do
        if m.cdEnd and m.cdEnd <= now then m.cdEnd = nil end
    end
    if ns.me.cdEnd and ns.me.cdEnd <= now then
        ns.me.cdEnd = nil
        G.MarkState(false)
    end
    Flush(now)
end

function G.Init()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    -- what was seen more than two hours ago says little about now
    local cutoff = time() - 7200
    for name, s in pairs(ns.cdb.seen) do
        if type(s) ~= "table" or math.max(tonumber(s.givenAt) or 0, tonumber(s.usedAt) or 0) < cutoff then
            ns.cdb.seen[name] = nil
        end
    end
    G.Rebuild()
end

function G.Describe(m)
    local st, cd = G.Status(m)
    local text
    if st == "has" then
        text = ns.StoneName(G.ItemOf(m))
    elseif st == "none" then
        text = "no healthstone"
    elseif st == "given" then
        text = ("got one from %s %s"):format(tostring(m.seen.givenBy or "a warlock"), ns.Ago(time() - m.seen.givenAt))
    elseif st == "used" then
        text = "used one " .. ns.Ago(time() - m.seen.usedAt)
    else
        text = "nothing seen yet"
    end
    if cd then text = text .. ", cooldown " .. ns.Clock(cd) end
    return text, st
end

function G.PrintStatus()
    local have, need, unknown, total = G.Summary()
    ns.Print(("%d of %d have a healthstone, %d need one, %d not known. Addon messages: %s."):format(
        have, total, need, unknown, G.CommsBlocked() or "ok"))
    for _, m in ipairs(G.SortedMembers()) do
        local who = (m.isPlayer and "you") or (m.hasAddon and ("addon " .. tostring(m.version))) or "no addon"
        ns.Print(("  %s (%s): %s"):format(m.name, who, (G.Describe(m))))
    end
end
