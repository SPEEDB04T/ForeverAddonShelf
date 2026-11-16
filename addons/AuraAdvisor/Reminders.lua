-- Aura Advisor: two reminders, shown the way the aura advice is (the game's spell-alert glow on
-- the action button that casts it, and a short line in tooltips; no frame of its own):
--
-- * Righteous Fury, for a Protection paladin who doesn't have it on.
-- * Your blessings on the party: each member's tooltip says which of yours they have and for
--   how long; out of a fight, in a group, the blessing most of them are missing (or that is
--   about to run out) glows, and its tooltip names who needs it.
--
-- Buffs are only read out of a fight (in a fight the game hides them); in a fight the last look
-- stands, and the times count down from it.
local _, ns = ...
local Data = ns.Data
local R = {}
ns.Reminders = R

local Plain, Secret = ns.Signals.Plain, ns.Signals.Secret
local GROUP = { "player", "party1", "party2", "party3", "party4" }
local RESCAN = 5            -- seconds between two looks at the party's buffs, when nothing changed
local MIN_GAP = 1           -- seconds between two looks at most, however often the buffs change
local KEEP_NAMES = 60       -- names remembered with the blessing you gave them

R.members = {}              -- unit -> { name, bless = key or nil, expires, duration, other = { key = true } }
R.knownBless = {}           -- key -> true: blessings you can cast
R.dirty = true

local function Now() return GetTime and GetTime() or 0 end

local function Call(f, ...)
    if not f then return nil end
    local ok, v = pcall(f, ...)
    if not ok then return nil end
    return Plain(v)
end

----------------------------------------------------------------------
-- Spells
----------------------------------------------------------------------
local blessNames
local function BlessByName(name)
    if not blessNames then
        blessNames = {}
        for key, def in pairs(Data.BLESSINGS) do
            blessNames[def.english:lower()] = key
            local localName = ns.SpellInfo(def.ids[1])
            if type(localName) == "string" then blessNames[localName:lower()] = key end
        end
    end
    local lower = name:lower()
    return blessNames[lower] or blessNames[(lower:gsub("^greater ", ""))]
        or blessNames[(lower:gsub("^großer ", ""):gsub("^grande ", ""))]
end

-- The blessing a spell is (the normal or the Greater one), or nil.
function R.BlessingOf(spellID, name)
    spellID = Plain(spellID)
    if type(spellID) == "number" then
        if Data.BLESSING_BY_ID[spellID] then return Data.BLESSING_BY_ID[spellID] end
        if type(name) ~= "string" then name = ns.SpellInfo(spellID) end
    end
    if type(name) == "string" then return BlessByName(name) end
end

-- The Greater (class-wide) form of a blessing?
local GREATER = {}
for _, def in pairs(Data.BLESSINGS) do
    for _, id in ipairs(def.greater) do GREATER[id] = true end
end
function R.IsGreater(spellID)
    spellID = Plain(spellID)
    if type(spellID) ~= "number" then return false end
    if GREATER[spellID] then return true end
    if Data.BLESSING_BY_ID[spellID] then return false end
    local name = ns.SpellInfo(spellID)
    return type(name) == "string" and name:lower():find("^greater ") ~= nil
end

local furyName
function R.IsFury(spellID, name)
    spellID = Plain(spellID)
    if type(spellID) == "number" then
        for _, id in ipairs(Data.RIGHTEOUS_FURY.ids) do if id == spellID then return true end end
        if type(name) ~= "string" then name = ns.SpellInfo(spellID) end
    end
    if type(name) ~= "string" then return false end
    furyName = furyName or ns.SpellInfo(Data.RIGHTEOUS_FURY.id)
    return name == Data.RIGHTEOUS_FURY.english or (furyName ~= nil and name == furyName)
end

-- Which blessings and whether Righteous Fury you know (after a level-up, a respec, at login).
function R.Resolve()
    local known = {}
    for key, def in pairs(Data.BLESSINGS) do
        for _, list in ipairs({ def.ids, def.greater }) do
            for _, id in ipairs(list) do
                if ns.PlayerKnows(id) then known[key] = true end
            end
        end
        if not known[key] then
            local _, _, byName = ns.SpellInfo(def.english)
            if byName then known[key] = true end
        end
    end
    R.knownBless = known
    local fury = false
    for _, id in ipairs(Data.RIGHTEOUS_FURY.ids) do
        if ns.PlayerKnows(id) then fury = true end
    end
    if not fury then
        local _, _, byName = ns.SpellInfo(Data.RIGHTEOUS_FURY.english)
        fury = byName ~= nil
    end
    R.knowsFury = fury
    R.talentProt = nil      -- read again
    R.dirty = true
end

----------------------------------------------------------------------
-- Protection
----------------------------------------------------------------------
-- The points in each talent tree: GetTalentTabInfo's returns differ between clients, so take
-- its first small number (icons and tree ids are large).
local function TreePoints(i)
    local ok, a, b, c, d, e, f = pcall(GetTalentTabInfo, i)
    if not ok then return nil end
    for _, v in ipairs({ a, b, c, d, e, f }) do
        v = Plain(v)
        if type(v) == "number" and v >= 0 and v <= 100 then return v end
    end
end

-- Prot: you said tank, or your group role is tank, or most of your talent points are in
-- Protection (the second tree). A role of healer or damage says no.
function R.IsProt()
    local style = ns.db and ns.db.style
    if style == "tank" then return true end
    if style == "damage" or style == "healer" then return false end
    local role = Call(UnitGroupRolesAssigned, "player")
    if role == "TANK" then return true end
    if role == "HEALER" or role == "DAMAGER" then return false end
    if R.talentProt == nil then R.talentProt = R.TalentsProt() end
    return R.talentProt
end

-- Talents change rarely: read once, and again after SPELLS_CHANGED or a talent change (Resolve).
function R.TalentsProt()
    if GetSpecialization and GetSpecializationInfo then
        local spec = Call(GetSpecialization)
        if type(spec) == "number" then
            local id = Call(GetSpecializationInfo, spec)
            if type(id) == "number" then return id == 66 end
        end
    end
    if GetTalentTabInfo then
        local holy, prot, ret = TreePoints(1), TreePoints(2), TreePoints(3)
        if prot and prot > 0 and prot > (holy or 0) and prot > (ret or 0) then return true end
    end
    return false
end

local function InGroup()
    if IsInGroup then return Call(IsInGroup) == true end
    return Call(UnitExists, "party1") == true
end
R.InGroup = InGroup

-- In an inn or a city, or on a flight: nothing to remind you of.
local function AtRest()
    return Call(IsResting) == true or Call(UnitOnTaxi, "player") == true
end

-- Righteous Fury only matters when you tank for others: in a group, out of town.
function R.FuryWanted()
    if not (ns.db and ns.db.fury and R.knowsFury) or ns.fury then return false end
    if ns.IsDead() or not InGroup() or AtRest() then return false end
    return R.IsProt()
end

----------------------------------------------------------------------
-- The party's buffs
----------------------------------------------------------------------
local function AurasHidden()
    if ns.inCombat then return true end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and secret then return true end
    end
    return false
end

-- One unit's blessings: yours (with its time) and other paladins'. nil when the game hid any of it.
local function ScanUnit(unit)
    local rec = { other = {} }
    for i = 1, 40 do
        local name, spellID, source, expires, duration
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or Secret(data) then return nil end
            if data == nil then break end
            local read
            read, name, spellID, source, expires, duration = pcall(function()
                return data.name, data.spellId, data.sourceUnit, data.expirationTime, data.duration
            end)
            if not read then return nil end
        elseif UnitBuff then
            local ok, n, _, _, _, dur, exp, src, _, _, id = pcall(UnitBuff, unit, i)
            if not ok or Secret(n) then return nil end
            if n == nil then break end
            name, spellID, source, expires, duration = n, id, src, exp, dur
        else
            return nil
        end
        if Secret(name) or Secret(spellID) or Secret(source) or Secret(expires) or Secret(duration) then return nil end
        local key = R.BlessingOf(spellID, name)
        if key then
            local mine = source == "player"
            if not mine and type(source) == "string" then mine = Call(UnitIsUnit, source, "player") == true end
            if mine then
                rec.bless = key
                rec.expires = type(expires) == "number" and expires or 0
                rec.duration = type(duration) == "number" and duration or 0
            else
                rec.other[key] = true
            end
        end
    end
    return rec
end

local function Remember(name, key)
    if type(name) ~= "string" or not ns.db then return end
    local book = ns.db.blessed
    if type(book) ~= "table" then book = {}; ns.db.blessed = book end
    if book[name] == key then return end
    local n = 0
    for _ in pairs(book) do n = n + 1 end
    if n >= KEEP_NAMES then
        -- start over, keeping the party you are with
        local keep = {}
        for _, rec in pairs(R.members) do
            if rec.name and book[rec.name] then keep[rec.name] = book[rec.name] end
        end
        book = keep
        ns.db.blessed = book
    end
    book[name] = key
end

function R.Scan(now)
    if AurasHidden() then return false end
    local members = {}
    for _, unit in ipairs(GROUP) do
        if Call(UnitExists, unit) then
            local name = Call(UnitName, unit)
            name = type(name) == "string" and name or nil
            local rec = ScanUnit(unit)
            if not rec then
                -- the game hid this one's buffs: keep the last look at the same person
                local old = R.members[unit]
                rec = (old and old.name == name) and old or nil
            end
            if rec then
                rec.name = name
                members[unit] = rec
                if rec.bless then Remember(rec.name, rec.bless) end
            end
        end
    end
    R.members, R.scanned, R.dirty = members, now, false
    return true
end

-- Can you bless them? Alive, online, close enough to see (not a range check: someone walking in
-- and out of range would make the glow come and go).
local function Reachable(unit)
    if unit == "player" then return not ns.IsDead() end
    if not Call(UnitExists, unit) then return false end
    if Call(UnitIsConnected, unit) == false then return false end
    if Call(UnitIsDeadOrGhost, unit) == true then return false end
    if Call(UnitIsVisible, unit) == false then return false end
    return true
end

-- Seconds of your blessing left on a member (huge when it doesn't run out), or nil: none of yours.
function R.Left(rec, now)
    if not (rec and rec.bless) then return nil end
    if not rec.expires or rec.expires <= 0 then return math.huge end
    return rec.expires - now
end

-- Recast when under a minute is left, or under a tenth of a long Greater blessing.
local function Running(rec, now)
    local left = R.Left(rec, now)
    if not left then return false end
    return left > math.max(60, (rec.duration or 0) * 0.1)
end

-- unit -> the blessing that member needs from you; only members you blessed before (this one
-- ran out or is about to) or who still have it running short. Members you never blessed count
-- for nothing here: the advisor doesn't choose blessings for you.
function R.Needs(now)
    local needs = {}
    local book = ns.db and type(ns.db.blessed) == "table" and ns.db.blessed or {}
    for unit, rec in pairs(R.members) do
        if not Running(rec, now) and Reachable(unit) then
            local want = rec.bless or (rec.name and book[rec.name])
            if want and R.knownBless[want] and not rec.other[want] then needs[unit] = want end
        end
    end
    return needs
end

----------------------------------------------------------------------
-- What to glow: Righteous Fury first, else the blessing most of the party needs
----------------------------------------------------------------------
function R.Update(now)
    R.pick = nil
    if not ns.enabled or not ns.db or ns.IsDead() then return nil end
    if (R.dirty and now - (R.scanned or -MIN_GAP) >= MIN_GAP) or now - (R.scanned or -RESCAN) >= RESCAN then
        R.Scan(now)
    end
    if R.FuryWanted() then
        R.pick = { kind = "fury", id = "fury" }
        return R.pick
    end
    if not ns.db.blessings or ns.inCombat or not InGroup() or AtRest() then return nil end
    local count, who = {}, {}
    for unit, key in pairs(R.Needs(now)) do
        count[key] = (count[key] or 0) + 1
        who[key] = who[key] or {}
        local rec = R.members[unit]
        who[key][#who[key] + 1] = (unit == "player") and "you" or (rec and rec.name) or unit
    end
    local best
    for _, key in ipairs(Data.BLESSING_ORDER) do
        if count[key] and (not best or count[key] > count[best]) then best = key end
    end
    if best then
        table.sort(who[best])
        R.pick = { kind = "bless", key = best, id = "bless:" .. best, who = who[best] }
    end
    return R.pick
end

-- Does this spell answer the reminder?
function R.Matches(pick, spellID)
    if not pick then return false end
    if pick.kind == "fury" then return R.IsFury(spellID) end
    return R.BlessingOf(spellID) == pick.key
end

-- When a fight starts without Righteous Fury, in a group: one line on screen.
function R.OnCombatStart()
    if not (ns.db and ns.db.banner) or not InGroup() or not R.FuryWanted() then return end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(ns.IconText(Data.RIGHTEOUS_FURY.id, ns.SpellInfo(Data.RIGHTEOUS_FURY.id)
            or Data.RIGHTEOUS_FURY.english), 1, 0.82, 0.2)
    end
end

----------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------
local function TimeText(left)
    if left == math.huge then return "" end
    if left >= 60 then return (" %d min"):format(math.floor(left / 60)) end
    return (" %d s"):format(math.max(0, math.floor(left)))
end

-- Under a spell's tooltip: what the reminder wants of it. Two words, and who.
function R.TooltipSpell(tt, spellID, RGB)
    local pick = R.pick
    if not R.Matches(pick, spellID) then return false end
    tt:AddLine(" ")
    if pick.kind == "fury" then
        local r, g, b = RGB("RED_FONT_COLOR")
        tt:AddLine("Not on", r, g, b, true)
    else
        local r, g, b = RGB("GREEN_FONT_COLOR")
        tt:AddLine("Recast", r, g, b, true)
        r, g, b = RGB("GRAY_FONT_COLOR")
        tt:AddLine(table.concat(pick.who, ", "), r, g, b, true)
    end
    tt:Show()
    return true
end

-- Under a party member's tooltip: your blessing on them and how long it has left.
function R.TooltipUnit(tt, unit, RGB)
    if not (ns.enabled and ns.db and ns.db.blessings) or type(unit) ~= "string" or not next(R.knownBless) then return end
    local token
    for _, u in ipairs(GROUP) do
        if u == unit or Call(UnitIsUnit, unit, u) == true then token = u; break end
    end
    if not token or (token ~= "player" and not InGroup()) then return end
    local rec = R.members[token]
    if not rec then return end
    local left = R.Left(rec, Now())
    local dead = token ~= "player" and Call(UnitIsDeadOrGhost, token) == true
    local text
    if left and left > 0 and not dead then
        text = Data.BLESSINGS[rec.bless].short .. TimeText(left)
    elseif next(rec.other) and not dead then
        return          -- another paladin's blessing is on them: not yours to keep up
    else
        text = "No blessing"
    end
    local r, g, b = RGB("GRAY_FONT_COLOR")
    tt:AddLine(text, r, g, b, true)
    tt:Show()
end

-- For the minimap button's tooltip: only when someone is missing yours.
function R.StatusLine()
    if not (ns.db and ns.db.blessings and InGroup() and next(R.knownBless)) then return nil end
    local now, have, total = Now(), 0, 0
    for _, rec in pairs(R.members) do
        local left = R.Left(rec, now)
        if left and left > 0 then
            have, total = have + 1, total + 1
        elseif not next(rec.other) then
            total = total + 1       -- someone with another paladin's blessing isn't missing yours
        end
    end
    if total == 0 or have == total then return nil end
    return ("Blessed %d/%d"):format(have, total)
end

function R.PrintDebug()
    local now = Now()
    local known = {}
    for _, key in ipairs(Data.BLESSING_ORDER) do
        if R.knownBless[key] then known[#known + 1] = Data.BLESSINGS[key].short end
    end
    ns.Print(("blessings known: %s. Righteous Fury: %s, on: %s, prot: %s"):format(
        #known > 0 and table.concat(known, ", ") or "none", tostring(R.knowsFury), tostring(ns.fury and true or false),
        tostring(R.IsProt())))
    for _, unit in ipairs(GROUP) do
        local rec = R.members[unit]
        if rec then
            local left = R.Left(rec, now)
            ns.Print(("  %s: %s"):format(rec.name or unit,
                left and (Data.BLESSINGS[rec.bless].short .. TimeText(left)) or "no blessing of yours"))
        end
    end
    local pick = R.pick
    ns.Print("reminder: " .. (pick and (pick.kind == "fury" and "Righteous Fury"
        or (Data.BLESSINGS[pick.key].short .. " for " .. table.concat(pick.who, ", "))) or "none"))
end
