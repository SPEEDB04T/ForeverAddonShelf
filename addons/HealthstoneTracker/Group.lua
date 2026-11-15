-- Healthstone Tracker: everyone in the group and what is known about their stone.
-- Players with the addon tell the group exactly what they carry. For players
-- without it the addon works from what can be seen: a warlock handing them a
-- stone in a trade, and the moment they use one.
local ADDON, ns = ...
local issecret = ns.issecret
local Norm, FullUnitName = ns.Norm, ns.FullUnitName

local G = {}
ns.Group = G

local PREFIX = "HSTracker"

G.members = {}      -- [name] = { name, unit, class, subgroup, isPlayer, hasAddon, version, item, count, cdEnd, seen, demo,
                    --            soul = { expires, by, setAt } (the soulstone buff on them),
                    --            soulItem, soulCount, soulCdEnd (a warlock's own soulstone) }
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
    { name = "Demo Priest",  class = "PRIEST",  given = 240, soul = 1130 },
    { name = "Demo Rogue",   class = "ROGUE",   used = 35 },
    { name = "Demo Hunter",  class = "HUNTER" },
    { name = "Demo Warlock", class = "WARLOCK", hasAddon = true, item = 9421, count = 1, soulCd = 1130 },
}

local function DemoMember(d)
    local m = { name = d.name, class = d.class, subgroup = 1, demo = true,
                hasAddon = d.hasAddon, version = d.hasAddon and ns.VERSION or nil, item = d.item, count = d.count }
    if d.hasAddon then m.soulCount = 0 end
    if d.soulCd then m.soulCdEnd = GetTime() + d.soulCd end
    if d.soul then m.soul = { expires = GetTime() + d.soul, by = "Demo Warlock" } end
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
                -- keyed by UnitName, the same name every lookup uses
                add(FullUnitName("raid" .. i) or name, "raid" .. i, class, subgroup)
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
    G.scanAll = true        -- look at everyone's buffs for a soulstone
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
-- Soulstones
----------------------------------------------------------------------
-- Who carries the "Soulstone Resurrection" buff is read from the buffs of
-- everyone in the group, so it works for players without the addon. Players
-- with the addon also report their own buff, and a warlock with the addon
-- says who they used it on, for the moments the game hides buffs from addons.
local SOUL_NAME = "Soulstone Resurrection"
local dirtyUnits = {}
local soulScanIn = 0

local function AurasLocked()
    local f = C_Secrets and C_Secrets.ShouldAurasBeSecret
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f)
    return (not ok) or issecret(v) or v == true
end

local function AuraDetails(aura)
    local exp, src = aura.expirationTime, aura.sourceUnit
    local by
    if not issecret(src) and type(src) == "string" then by = FullUnitName(src) end
    if issecret(exp) or type(exp) ~= "number" or exp <= GetTime() then exp = nil end
    return true, exp, by
end

-- Is the soulstone buff on this unit? Returns true (with when it runs out and
-- who cast it, where the game says), false, or nil when it can't be told.
local function ReadSoulAura(unit)
    local UA = C_UnitAuras
    if not UA then return nil end
    -- asking by spell works even while buffs are hidden from addons
    if UA.GetUnitAuraBySpellID then
        for id in pairs(ns.SOUL_SPELLS) do
            local ok, aura = pcall(UA.GetUnitAuraBySpellID, unit, id)
            if ok and not issecret(aura) and type(aura) == "table" then return AuraDetails(aura) end
        end
    end
    if AurasLocked() or not UA.GetAuraDataByIndex then return nil end
    local seen = 0
    for i = 1, 60 do
        local ok, aura = pcall(UA.GetAuraDataByIndex, unit, i, "HELPFUL")
        if not ok or issecret(aura) then return nil end
        if type(aura) ~= "table" then break end
        local id, name = aura.spellId, aura.name
        if issecret(id) or issecret(name) then return nil end
        seen = seen + 1
        if (type(id) == "number" and ns.SOUL_SPELLS[id]) or name == SOUL_NAME then
            return AuraDetails(aura)
        end
    end
    -- no buffs at all usually means they can't be read (out of sight), not that
    -- the player has none; only the player's own are always there to read
    if seen == 0 and unit ~= "player" then return nil end
    return false
end

local function InSight(m)
    if m.isPlayer then return true end
    if not m.unit then return false end
    if UnitIsConnected then
        local ok, on = pcall(UnitIsConnected, m.unit)
        if not ok or issecret(on) or not on then return false end
    end
    if UnitIsVisible then
        local ok, v = pcall(UnitIsVisible, m.unit)
        if not ok or issecret(v) or not v then return false end
    end
    return true
end

local function ScanSoul(m, now)
    if m.demo then return end
    local unit = m.isPlayer and "player" or m.unit
    if not unit then return end
    local found, exp, by = ReadSoulAura(unit)
    if found == nil then return end
    local s = m.soul
    local changed = false
    if found then
        if not s then
            s = { expires = exp or (now + ns.SOUL_DURATION) }
            m.soul = s
            changed = true
            -- a cast just seen names the warlock when the buff itself does not
            local cast = G.lastSoulCast
            if not by and cast and now - cast.at < 6 then by = cast.name end
        elseif exp and math.abs(exp - s.expires) > 2 then
            s.expires = exp
            changed = true
        end
        if by then s.by = by end
    elseif s and InSight(m) then
        if now - (s.setAt or 0) > 5 then
            m.soul = nil
            changed = true
        else
            -- just told about it: the buff may not be there to read yet, look again shortly
            G.rescanAt = (s.setAt or now) + 5.5
        end
    end
    if changed then
        ns.dirty = true
        if m.isPlayer then G.MarkState(false) end
    end
end

function G.OnUnitAura(unit)
    if issecret(unit) or type(unit) ~= "string" then return end
    if unit == "player" or G.byUnit[unit] then dirtyUnits[unit] = true end
end

local function MemberOfUnit(unit)
    local name = (unit == "player") and ns.playerName or G.byUnit[unit] or FullUnitName(unit)
    return name and G.members[name]
end

-- The group member a name from the server or from a message belongs to
-- (ns.UnitOfName: matched by name, space kept, realm only as a tie-break).
-- Returns the member, or nil and why.
function G.FindMember(name)
    local unit, why = ns.UnitOfName(name)
    if not unit then return nil, why end
    local m = MemberOfUnit(unit)
    if not m then return nil, "not in the list yet" end
    return m
end

-- Once a second: the units whose buffs changed, and everyone now and then.
local function ScanSouls(now)
    soulScanIn = soulScanIn - 1
    if G.rescanAt and now >= G.rescanAt then
        G.rescanAt = nil
        G.scanAll = true
    end
    if G.scanAll or soulScanIn <= 0 then
        G.scanAll = false
        soulScanIn = 10
        for unit in pairs(dirtyUnits) do dirtyUnits[unit] = nil end
        for _, m in pairs(G.members) do ScanSoul(m, now) end
        return
    end
    for unit in pairs(dirtyUnits) do
        dirtyUnits[unit] = nil
        local m = MemberOfUnit(unit)
        if m then ScanSoul(m, now) end
    end
end

local function IsDead(m)
    if m.demo or not UnitIsDead then return false end
    local unit = m.isPlayer and "player" or m.unit
    if not unit then return false end
    local ok, dead = pcall(UnitIsDead, unit)
    return ok and not issecret(dead) and dead and true or false
end

-- Players carrying a soulstone, the one running out first on top:
-- { { m = member, left = seconds, dead = true when they can use it now }, ... }
function G.SoulHolders()
    local now, list = GetTime(), {}
    for _, m in pairs(G.members) do
        local s = m.soul
        if s and s.expires > now then
            list[#list + 1] = { m = m, left = s.expires - now, dead = IsDead(m) }
        end
    end
    table.sort(list, function(a, b)
        if a.left ~= b.left then return a.left < b.left end
        return a.m.name < b.m.name
    end)
    return list
end

function G.SoulWarlocks()
    local list = {}
    for _, m in pairs(G.members) do
        if m.class == "WARLOCK" then list[#list + 1] = m end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- A warlock's own soulstone, and the seconds left on its cooldown:
--   "ready"     has one and can use it
--   "cooldown"  used one less than half an hour ago
--   "nostone"   off cooldown but carries none (they can make one)
--   "unknown"   no addon (or an older one) and no use seen
function G.SoulStatus(m)
    local src = m.isPlayer and ns.me or m
    local now = GetTime()
    if src.soulCdEnd and src.soulCdEnd > now then return "cooldown", src.soulCdEnd - now end
    if m.isPlayer or (m.hasAddon and src.soulCount) then
        return ((src.soulCount or 0) > 0) and "ready" or "nostone"
    end
    return "unknown"
end

function G.DescribeSoul(m)
    local s = m.soul
    if not s or s.expires <= GetTime() then return nil end
    return ("soulstone%s, %s left"):format(s.by and (" from " .. tostring(s.by)) or "", ns.Clock(s.expires - GetTime()))
end

function G.DescribeSoulStone(m)
    local st, left = G.SoulStatus(m)
    if st == "ready" then return "soulstone ready to use", st end
    if st == "cooldown" then return "soulstone on cooldown for " .. ns.Clock(left), st end
    if st == "nostone" then return "no soulstone in the bags (can make one)", st end
    return "soulstone not known (no addon, or an older version)", st
end

-- One line of plain text for chat.
function G.SoulLine()
    local holders = G.SoulHolders()
    if #holders > 0 then
        local parts = {}
        for i, h in ipairs(holders) do
            parts[i] = ("%s (%d min)"):format(h.m.name, math.max(1, math.floor(h.left / 60 + 0.5)))
        end
        return "Soulstone on: " .. table.concat(parts, ", ") .. "."
    end
    local ready, soonest, who = {}, nil, nil
    for _, m in ipairs(G.SoulWarlocks()) do
        local st, left = G.SoulStatus(m)
        if st == "ready" or st == "nostone" then
            ready[#ready + 1] = m.name
        elseif st == "cooldown" and (not soonest or left < soonest) then
            soonest, who = left, m.name
        end
    end
    if #ready > 0 then return "No soulstone up. Off cooldown: " .. table.concat(ready, ", ") .. "." end
    if who then return ("No soulstone up. Next: %s in %d min."):format(who, math.max(1, math.ceil(soonest / 60))) end
    return "No soulstone up."
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

-- nil when messages can go out, otherwise why not. The realm's switch
-- AreOutgoingAddonChatMessagesRestricted is not asked: it is on for ordinary
-- realms, and addon messages inside a group go out all the same.
function G.CommsBlocked()
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return "this client has no addon messages" end
    if C_ChatInfo.InChatMessagingLockdown then
        local ok, v = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and (issecret(v) or v) then return "chat is locked right now (it syncs again afterwards)" end
    end
    return nil
end

-- For the status line: a block, or what the game answered when it refused
-- the last message (cleared by the next one that goes out).
local refused
function G.CommsProblem()
    return G.CommsBlocked() or refused
end

-- What really happened, for reading back from SavedVariables after a
-- session: the last 40 messages in and out (db.commLog).
G.inCount, G.outCount = 0, 0
G.ignored = {}      -- [sender as given] = { n = count, why = reason }
local LOG_SIZE = 40

local function Plain(v)
    if issecret(v) then return "hidden" end
    if v == nil then return nil end
    return tostring(v)
end

local function Log(dir, channel, sender, unit, code, text)
    local db = ns.db
    if not db then return end
    local log = db.commLog
    if type(log) ~= "table" then
        log = {}
        db.commLog = log
    end
    log[#log + 1] = {
        t = time and time() or 0, dir = dir, ch = Plain(channel), from = Plain(sender),
        unit = unit or "nobody", code = Plain(code),
        msg = (type(text) == "string" and not issecret(text)) and text:sub(1, 40) or Plain(text),
    }
    while #log > LOG_SIZE do table.remove(log, 1) end
end

-- A message from someone not found in the group: counted, shown in /hst status.
local function Ignore(sender, why)
    local key = issecret(sender) and "a hidden sender" or tostring(sender)
    local e = G.ignored[key]
    if not e then
        local n = 0
        for _ in pairs(G.ignored) do n = n + 1 end
        if n >= 20 then key = "others" end
        e = G.ignored[key] or { n = 0 }
        G.ignored[key] = e
    end
    e.n = e.n + 1
    e.why = why or "not found in the group"
end

local function Enqueue(msg)
    if #queue >= 20 then table.remove(queue, 1) end
    queue[#queue + 1] = msg
end

-- "S;version;itemID;count;cooldown seconds left;soulstone itemID;count;cooldown
-- seconds left;seconds left on the soulstone buff on me". Version 1.0.0 sends
-- and reads only the first five fields.
local function StateMessage()
    local me, now = ns.me, GetTime()
    local function left(t) return (t and t > now) and math.min(3600, math.ceil(t - now)) or 0 end
    local mine = ns.playerName and G.members[ns.playerName]
    return ("S;%s;%d;%d;%d;%d;%d;%d;%d"):format(ns.VERSION, me.item or 0, me.count or 0, left(me.cdEnd),
        me.soulItem or 0, me.soulCount or 0, left(me.soulCdEnd), left(mine and mine.soul and mine.soul.expires))
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
    Log("out", channel, ns.playerName, "player", ok and (result == nil and "nil" or result) or "error", msg)
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
    G.outCount = G.outCount + 1
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
-- Names inside messages go out as players see them ("First Last", built from
-- UnitName alone) and are matched to a group unit on arrival.
function G.NoteGave(name, item)
    local m = name and G.FindMember(name)
    if not m or m.isPlayer or m.demo then return end
    RecordGift(m, ns.playerName, item)
    -- someone with the addon reports their own bags; the others need telling
    if not m.hasAddon then
        Enqueue(("G;%s;%d"):format(m.name, item or 0))
    end
end

-- The player used their soulstone, on `target` when the game said who.
function G.PlayerSoulstoned(target)
    local now = GetTime()
    G.MarkState(false)
    G.scanAll = true
    ns.dirty = true
    local m = target and G.FindMember(target)
    if not m or m.demo then return end
    m.soul = { expires = now + ns.SOUL_DURATION, by = ns.playerName, setAt = now }
    Enqueue(("R;%s;%d"):format(m.name, ns.SOUL_DURATION))
end

-- Someone else in the group was seen using a soulstone on somebody.
function G.ObserveSoulCast(unit)
    local m = MemberOfUnit(unit)
    if not m or m.isPlayer then return end
    local now = GetTime()
    if m.lastSoulCast and now - m.lastSoulCast < 1 then return end      -- reported as raidN and partyN
    m.lastSoulCast = now
    m.soulCdEnd = now + ns.SOUL_COOLDOWN
    G.lastSoulCast = { name = m.name, at = now }
    G.scanAll = true        -- the buff shows who got it
    ns.dirty = true
end

-- A dead player took the resurrection: their soulstone is spent.
function G.ObserveSoulRez(unit)
    local m = MemberOfUnit(unit)
    if not m or not m.soul then return end
    m.soul = nil
    if m.isPlayer then G.MarkState(false) end
    ns.dirty = true
end

----------------------------------------------------------------------
-- Receiving
----------------------------------------------------------------------
function G.OnAddonMessage(prefix, text, channel, sender)
    if issecret(prefix) or prefix ~= PREFIX then return end
    if issecret(text) or type(text) ~= "string" then
        Log("in", channel, sender, nil, nil, text)
        Ignore(sender, "the message itself was hidden")
        return
    end
    -- the sender is found by name among the group units, never by comparing
    -- "Name-Realm" strings: the server spells the realm unlike the client
    local unit, why = ns.UnitOfName(sender)
    local m = unit and MemberOfUnit(unit)
    Log("in", channel, sender, unit, nil, text)
    if not m then
        Ignore(sender, why or "not in the list yet")
        return
    end
    if m.isPlayer or m.demo then return end     -- our own message coming back
    G.inCount = G.inCount + 1
    local from = m.name
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
        -- soulstone fields, from version 1.1.0 on
        local sItem, sCount, sCd, buff = Int(f[6], 0, 9999999), Int(f[7], 0, 200), Int(f[8], 0, 3600), Int(f[9], 0, 3600)
        if sItem and sCount and sCd and buff then
            local now = GetTime()
            m.soulItem = sItem > 0 and sItem or nil
            m.soulCount = sCount
            m.soulCdEnd = sCd > 0 and (now + sCd) or nil
            if buff > 0 then
                if m.soul then m.soul.expires = now + buff else m.soul = { expires = now + buff } end
            elseif m.soul and now - (m.soul.setAt or 0) > 5 then
                m.soul = nil
            end
        end
        ns.dirty = true
    elseif kind == "Q" then
        G.MarkState(true)
    elseif kind == "R" then
        -- a warlock used their soulstone on someone
        local tm = Norm(f[2]) and G.FindMember(f[2])
        local left = Int(f[3], 1, 3600)
        if not tm or tm.demo or not left or m.class ~= "WARLOCK" then return end
        local now = GetTime()
        tm.soul = { expires = now + left, by = from, setAt = now }
        if tm.isPlayer then G.MarkState(false) end
        ns.dirty = true
    elseif kind == "G" then
        local tm = Norm(f[2]) and G.FindMember(f[2])
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
    end
    if #need > 0 then SendNames(send, channel, "Need a healthstone: ", need) end
    if #unknown > 0 then SendNames(send, channel, "Healthstone not known (no addon): ", unknown) end
    if ns.db.soul and (G.warlocks > 0 or #G.SoulHolders() > 0) then
        pcall(send, G.SoulLine(), channel)
    end
end

----------------------------------------------------------------------
-- Once a second
----------------------------------------------------------------------
function G.Tick(now)
    for _, m in pairs(G.members) do
        if m.cdEnd and m.cdEnd <= now then m.cdEnd = nil end
        if m.soulCdEnd and m.soulCdEnd <= now then m.soulCdEnd = nil end
        if m.soul and m.soul.expires <= now then
            m.soul = nil
            if m.isPlayer then G.MarkState(false) end
        end
    end
    if ns.me.cdEnd and ns.me.cdEnd <= now then
        ns.me.cdEnd = nil
        G.MarkState(false)
    end
    if ns.me.soulCdEnd and ns.me.soulCdEnd <= now then
        ns.me.soulCdEnd = nil
        G.MarkState(false)
    end
    if G.grouped then ScanSouls(now) end
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
    ns.Print(("%d of %d have a healthstone, %d need one, %d not known. Addon messages: %s, %d received, %d sent."):format(
        have, total, need, unknown, G.CommsProblem() or "ok", G.inCount, G.outCount))
    for who, e in pairs(G.ignored) do
        ns.Print(("  %d message%s from %s ignored: %s."):format(e.n, e.n == 1 and "" or "s", who, e.why))
    end
    for _, m in ipairs(G.SortedMembers()) do
        local who = (m.isPlayer and "you") or (m.hasAddon and ("addon " .. tostring(m.version))) or "no addon"
        ns.Print(("  %s (%s): %s"):format(m.name, who, (G.Describe(m))))
    end
    ns.Print(G.SoulLine())
    for _, h in ipairs(G.SoulHolders()) do
        ns.Print(("  %s: %s%s"):format(h.m.name, G.DescribeSoul(h.m) or "", h.dead and " (dead: can use it)" or ""))
    end
    for _, m in ipairs(G.SoulWarlocks()) do
        ns.Print(("  %s's stone: %s"):format(m.name, (G.DescribeSoulStone(m))))
    end
end
