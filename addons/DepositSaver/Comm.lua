-- Deposit Saver: sharing auctions with the guild, the group and listed characters on other
-- accounts (addon messages; another account's SavedVariables can't be read).
--
-- Messages (prefix "DepositSaver", fields split by ";", version 1):
--   Q;1                                  send me your auctions
--   S;1;snap;owner;n                     owner's full list follows: n auctions
--   A;1;snap;owner;id;item;ilvl;suffix;pet;qty;unit;deposit;flags;expires
--                                        one auction (flags: e exact deposit, a rough time,
--                                        c commodity, b bid only; expires in server time)
--   E;1;snap;owner;n                     end of owner's list
--   G;1;id                               that auction is gone (bought back, cancelled)
-- Each client shares the auctions of every character on its own account, so an alt that is
-- offline is still shared by whichever character of that account is online.
local _, ns = ...
local Num, Str = ns.Num, ns.Str

local Comm = {}
ns.Comm = Comm
local PREFIX = "DepositSaver"
Comm.PREFIX = PREFIX
local PROTO = "1"

local queue = {}        -- { msg, channel, target }
Comm.queue = queue
Comm.inCount, Comm.outCount, Comm.badCount = 0, 0, 0
Comm.ignored = {}       -- [sender] = { n, why }
local heard = {}        -- [sender] = GetTime() of their last message (they are online)
local refused, pauseUntil = nil, 0
local snapSeq = 0
local buffers = {}      -- [owner] = { snap, ids = {}, n }
local shareDirty, shareAt, shareForce = false, 0, false
local replyAt = {}      -- [channel..target] = GetTime() of the last reply

local function Secret(v) return ns.Secret(v) end

local function Plain(v)
    if Secret(v) then return "hidden" end
    if v == nil then return nil end
    return tostring(v)
end

local function Log(dir, channel, sender, code, text)
    local db = ns.db
    if not db then return end
    local log = db.commLog
    log[#log + 1] = { t = time(), dir = dir, ch = Plain(channel), from = Plain(sender), code = Plain(code),
        msg = (type(text) == "string" and not Secret(text)) and text:sub(1, 40) or Plain(text) }
    while #log > 40 do table.remove(log, 1) end
end

local function Ignore(sender, why)
    local key = Secret(sender) and "a hidden sender" or tostring(sender)
    local e = Comm.ignored[key] or { n = 0 }
    Comm.ignored[key] = e
    e.n, e.why = e.n + 1, why
end

function Comm.Blocked()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return "this client has no addon messages" end
    if C_ChatInfo.InChatMessagingLockdown then
        local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and (Secret(v) or v) then return "chat is locked right now" end
    end
    return nil
end

local function Lower(s) return (tostring(s or ""):lower()) end

-- A listed character is reachable when it is an online friend or has messaged us lately.
-- (A whisper to someone offline makes the game print "No player named ..." each time.)
local function Reachable(name)
    if heard[name] and GetTime() - heard[name] < 3600 then return true end
    for who, t in pairs(heard) do
        if Lower(who) == Lower(name) or Lower(who):find("^" .. Lower(name):gsub("%p", "%%%0") .. "%-") then
            if GetTime() - t < 3600 then return true end
        end
    end
    if C_FriendList and C_FriendList.GetFriendInfo then
        local ok, info = pcall(C_FriendList.GetFriendInfo, name)
        if ok and type(info) == "table" and ns.Get(info, "connected") == true then return true end
    end
    return false
end
Comm.Reachable = Reachable

local function GroupChannel()
    local ok, raid = pcall(IsInRaid)
    if ok and raid == true then return "RAID" end
    local ok2, group = pcall(IsInGroup)
    if ok2 and group == true then return "PARTY" end
    return nil
end

-- Where a broadcast goes: { {channel, target}, ... }
function Comm.Targets()
    local out, db = {}, ns.db
    if db.shareGuild and IsInGuild then
        local ok, g = pcall(IsInGuild)
        if ok and g == true then out[#out + 1] = { "GUILD" } end
    end
    if db.shareGroup then
        local ch = GroupChannel()
        if ch then out[#out + 1] = { ch } end
    end
    for _, name in ipairs(db.whisper) do
        if Reachable(name) then out[#out + 1] = { "WHISPER", name } end
    end
    return out
end

local function Enqueue(msg, channel, target)
    if #queue >= 400 then table.remove(queue, 1) end
    queue[#queue + 1] = { msg, channel, target }
end

local function Broadcast(msg, targets)
    for _, t in ipairs(targets or Comm.Targets()) do Enqueue(msg, t[1], t[2]) end
end

function Comm.Flush()
    if #queue == 0 or GetTime() < pauseUntil or Comm.Blocked() then return end
    local item = queue[1]
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, item[1], item[2], item[3])
    Log("out", item[2] .. (item[3] and (" " .. item[3]) or ""), ns.Me(), ok and (result == nil and "nil" or result) or "error", item[1])
    if ok then
        local sent = not (type(result) == "number" and result ~= 0) and result ~= false
        if not sent then
            if result ~= 3 and result ~= 8 then        -- 3 and 8 are the game's throttles
                refused = "the game refused the last message (code " .. tostring(result) .. ")"
                table.remove(queue, 1)
            end
            pauseUntil = GetTime() + 1.5
            return
        end
    end
    table.remove(queue, 1)
    if ok then
        refused = nil
        Comm.outCount = Comm.outCount + 1
    end
end

local function Field(v)
    if v == nil then return "" end
    return tostring(v)
end

local function Flags(rec)
    return (rec.exact and "e" or "") .. (rec.approx and "a" or "") .. (rec.commodity and "c" or "") .. (rec.bidOnly and "b" or "")
end

local function OwnersOnAccount()
    local out, seen = {}, {}
    for name, c in pairs(ns.db.chars) do
        if type(c) == "table" and c.read then out[#out + 1] = name; seen[name] = true end
    end
    -- A character that has posted since login but whose list hasn't been read yet.
    for _, rec in pairs(ns.db.auctions) do
        if rec.src == "own" and rec.owner and not seen[rec.owner] then
            out[#out + 1] = rec.owner; seen[rec.owner] = true
        end
    end
    table.sort(out)
    return out
end

-- The lists of this account's characters, to the given targets (default: everyone).
local function SendLists(targets)
    targets = targets or Comm.Targets()
    if #targets == 0 then return 0 end
    local byOwner = {}
    for _, rec in ipairs(ns.Records()) do
        if ns.IsMine(rec.owner) then
            byOwner[rec.owner] = byOwner[rec.owner] or {}
            table.insert(byOwner[rec.owner], rec)
        end
    end
    local sent = 0
    for _, owner in ipairs(OwnersOnAccount()) do
        local list = byOwner[owner] or {}
        snapSeq = snapSeq + 1
        local snap = tostring(snapSeq % 1000)
        Broadcast(table.concat({ "S", PROTO, snap, owner, #list }, ";"), targets)
        for _, rec in ipairs(list) do
            Broadcast(table.concat({ "A", PROTO, snap, owner, Field(rec.id), Field(rec.item), Field(rec.ilvl), Field(rec.suffix),
                Field(rec.pet), Field(rec.qty), Field(rec.unit), Field(rec.deposit), Flags(rec), Field(rec.expires) }, ";"), targets)
        end
        Broadcast(table.concat({ "E", PROTO, snap, owner, #list }, ";"), targets)
        sent = sent + 1
    end
    return sent
end
Comm.SendLists = SendLists

-- This account's lists changed: send them soon (several changes in a row go out once).
function Comm.ShareOwn(now)
    shareDirty = true
    shareAt = GetTime() + (now and 0 or 2)
end

function Comm.Request(targets)
    Broadcast("Q;" .. PROTO, targets)
end

function Comm.Gone(id)
    Broadcast("G;" .. PROTO .. ";" .. tostring(id))
end

function Comm.Tick()
    if shareDirty and GetTime() >= shareAt then
        shareDirty = false
        SendLists()
    end
    Comm.Flush()
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local function Split(s)
    local out = {}
    for part in (s .. ";"):gmatch("([^;]*);") do out[#out + 1] = part end
    return out
end

local function N(s) return tonumber(s) end

local function Upsert(owner, f, sender)
    local id = N(f[5])
    if not id or not N(f[6]) then return nil end
    local rec = ns.db.auctions[id]
    if rec and rec.src == "own" then return id end
    local flags = f[13] or ""
    local exact = flags:find("e", 1, true) ~= nil
    -- only the owner's own account shares its auctions: its latest numbers win, even when a
    -- deposit it called exact before is now an estimate (it was matched to the wrong post)
    local deposit = N(f[12])
    rec = rec or {}
    rec.id, rec.owner, rec.src, rec.from = id, owner, "comm", sender
    rec.item, rec.ilvl, rec.suffix, rec.pet = N(f[6]), N(f[7]), N(f[8]), N(f[9])
    rec.qty, rec.unit, rec.deposit = math.max(N(f[10]) or 1, 1), N(f[11]), deposit
    rec.exact = exact
    rec.approx = flags:find("a", 1, true) ~= nil or nil
    rec.commodity = flags:find("c", 1, true) ~= nil
    rec.bidOnly = flags:find("b", 1, true) ~= nil or nil
    rec.expires, rec.seen = N(f[14]), ns.ServerNow()
    if rec.link and not tostring(rec.link):find("item:" .. rec.item .. ":", 1, true) then rec.link = nil end
    ns.db.auctions[id] = rec
    return id
end

local function Reply(channel, sender)
    local target = channel == "WHISPER" and sender or nil
    local key = channel .. (target or "")
    if replyAt[key] and GetTime() - replyAt[key] < 10 then return end
    replyAt[key] = GetTime()
    if channel == "GUILD" and not ns.db.shareGuild then return end
    if (channel == "PARTY" or channel == "RAID") and not ns.db.shareGroup then return end
    SendLists({ { channel, target } })
end

function Comm.OnMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX or Secret(prefix) then return end
    if Secret(text) or Secret(channel) or type(text) ~= "string" then
        Ignore(sender, "hidden message")
        return
    end
    Log("in", channel, sender, nil, text)
    local who = Str(sender)
    if not who then
        Ignore(sender, "hidden sender")
        return
    end
    heard[who] = GetTime()
    local f = Split(text)
    local kind = f[1]
    if f[2] ~= PROTO then
        Ignore(who, "another version of the addon")
        return
    end
    Comm.inCount = Comm.inCount + 1
    if kind == "Q" then
        -- our own question coming back to us is answered by nobody
        if who ~= ns.Me() and not who:find("^" .. ns.Me():gsub("%p", "%%%0") .. "%-") then Reply(channel, who) end
        return
    elseif kind == "G" then
        local id = N(f[3])
        local rec = id and ns.db.auctions[id]
        if rec then
            ns.Forget(id)
        end
        return
    end
    local owner = f[4]
    if not owner or owner == "" then
        Comm.badCount = Comm.badCount + 1
        return
    end
    if ns.IsMine(owner) then return end      -- our own lists coming back, or a stale copy
    if kind == "S" then
        buffers[owner] = { snap = f[3], ids = {}, n = 0, want = N(f[5]) }
    elseif kind == "A" then
        local id = Upsert(owner, f, who)
        local b = buffers[owner]
        if id and b and b.snap == f[3] then
            b.ids[id] = true
            b.n = b.n + 1
        end
        ns.Changed()
    elseif kind == "E" then
        local b = buffers[owner]
        buffers[owner] = nil
        if b and b.snap == f[3] and b.n == N(f[5]) then
            -- the whole list arrived: whatever of theirs is not in it is gone
            for id, rec in pairs(ns.db.auctions) do
                if rec.owner == owner and rec.src ~= "own" and not b.ids[id] then ns.db.auctions[id] = nil end
            end
            ns.Changed()
        end
    else
        Comm.badCount = Comm.badCount + 1
    end
end

---------------------------------------------------------------------------
-- The whisper list
---------------------------------------------------------------------------
function Comm.AddWhisper(name)
    for _, n in ipairs(ns.db.whisper) do
        if Lower(n) == Lower(name) then
            ns.Print(name .. " is already on the list.")
            return
        end
    end
    table.insert(ns.db.whisper, name)
    ns.Print(("Shares with %s whenever %s is online. Put %s on your friends list so the addon can see that "
        .. "(or it waits until %s's addon sends something)."):format(name, name, name, name))
    if Reachable(name) then
        Comm.Request({ { "WHISPER", name } })
        SendLists({ { "WHISPER", name } })
    end
end

function Comm.RemoveWhisper(name)
    for i, n in ipairs(ns.db.whisper) do
        if Lower(n) == Lower(name) then
            table.remove(ns.db.whisper, i)
            ns.Print(n .. " taken off the list.")
            return
        end
    end
    ns.Print(name .. " is not on the list. /deposits who shows it.")
end

local lastGroup
function Comm.OnRoster()
    local ch = GroupChannel()
    if ch and ch ~= lastGroup and ns.db.shareGroup then
        Comm.Request({ { ch } })
        SendLists({ { ch } })
    end
    lastGroup = ch
end

function Comm.StatusLines()
    local lines = {}
    local targets = {}
    for _, t in ipairs(Comm.Targets()) do targets[#targets + 1] = t[2] and (t[2]) or t[1]:lower() end
    lines[#lines + 1] = ("Sharing with: %s. Messages: %d in, %d out, %d waiting."):format(
        #targets > 0 and table.concat(targets, ", ") or "nobody right now", Comm.inCount, Comm.outCount, #queue)
    local problem = Comm.Blocked() or refused
    if problem then lines[#lines + 1] = "Not sending: " .. problem .. "." end
    for who, e in pairs(Comm.ignored) do
        lines[#lines + 1] = ("%d messages from %s ignored: %s."):format(e.n, who, e.why or "?")
    end
    return lines
end

function Comm.Start()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    end
    lastGroup = GroupChannel()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(0.25, function() pcall(Comm.Tick) end)
    end
    if C_Timer and C_Timer.After then
        -- the guild roster is not known straight after login
        C_Timer.After(8, function()
            Comm.Request()
            Comm.ShareOwn(true)
        end)
    end
end
