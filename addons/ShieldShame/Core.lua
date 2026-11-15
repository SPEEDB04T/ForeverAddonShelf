-- Shield Shame: counts the damage and mana a shaman throws away by fighting without
-- Lightning Shield or Water Shield up, and tells them so, with feeling.
--
-- What is counted (details and what is an estimate: README.md):
--   * In a fight, every hit you take while no shield is up is a shield orb that never fired,
--     at most one per orb cooldown ("only one ball will fire every few seconds").
--   * An orb is worth the damage your best Lightning Shield rank does, or the mana Water Shield
--     returns, both read from the spell's own tooltip when the game gives it.
--   * Water Shield's passive regeneration is added for the unshielded seconds only if its
--     tooltip names one (WoW Forever's text does not).
--
-- Auras can be secret in a fight. The shield's state from before the fight then stands in,
-- with its orbs spent by the hits you take and topped up when you cast a shield.
local ADDON, ns = ...

local floor, max, min = math.floor, math.max, math.min

ns.VERSION = "1.1.0"

----------------------------------------------------------------------
-- The shields on WoW Forever (talentsforever.com data.json, beta client 1.60.1.70755,
-- read 2026-11-14; not yet confirmed in the live game). Numbers here are fallbacks only:
-- the live tooltip wins whenever it can be read.
----------------------------------------------------------------------
ns.SHIELDS = {
    lightning = {
        key = "lightning",
        english = "Lightning Shield",
        what = "damage",
        -- ranks 1-7, learned at 8, 16, 24, 32, 40, 48, 56
        ids = { 324, 325, 905, 945, 8134, 10431, 10432 },
        base = { 13, 24, 40, 64, 96, 134, 178 },     -- Nature damage an orb, no spell power
        coef = 0.267,                                -- of spell power, per orb
        learnLevel = 8,
        iconPath = "Interface\\Icons\\Spell_Nature_LightningShield",
    },
    water = {
        key = "water",
        english = "Water Shield",
        what = "mana",
        ids = { 408510 },                            -- a Restoration talent on WoW Forever
        auraIds = { 408510, 408511, 409941 },
        pct = 2,                                     -- % of maximum mana an orb
        iconPath = "Interface\\Icons\\Ability_Shaman_WaterShield",
    },
}
ns.KINDS = { "lightning", "water" }
-- Earth Shield is not a shaman spell on WoW Forever. If one shows up on you anyway (a later
-- patch, a rune), it counts as "a shield is up" and nothing is counted as lost.
ns.OTHER_SHIELD_IDS = { [974] = true, [408514] = true, [408519] = true, [409947] = true }
ns.OTHER_SHIELD_NAMES = { ["Earth Shield"] = true }

ns.CHARGES = 3        -- orbs a shield starts with (WoW Forever text: "3 balls", "3 globes")
ns.DURATION = 600     -- "Lasts 10 min."

ns.DEFAULTS = {
    enabled = true,
    measure = "auto",       -- "auto" (the shield you used last), "lightning" or "water"
    icd = 3,                -- seconds between orbs ("every few seconds"): an estimate
    spellHits = true,       -- hits by spells count too ("a spell, melee or ranged attack")
    remind = true,          -- the missing-shield icon
    remindCombat = true,    -- ... also in a fight
    hideResting = true,     -- no icon in an inn or city
    hideMounted = true,     -- no icon while mounted
    fightLine = false,      -- a roast in your chat for the fights that cost you (opt-in since 1.1.0)
    roastMinutes = 5,       -- at most one roast line this often
    confess = false,        -- also tell your party or raid (off unless you turn it on)
    locked = false,
    scale = 1,
    point = { "TOP", "TOP", 0, -190 },
    minimap = {},
    settingsVersion = 2,    -- 2: 1.1.0 turned the chat roast off for everyone once
}
ns.LOG_SIZE = 25          -- fights kept in the per-character fight log

----------------------------------------------------------------------
-- Safe reads
----------------------------------------------------------------------
local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) and true or false
end
ns.Secret = Secret

local function Plain(v)
    if Secret(v) then return nil end
    return v
end
ns.Plain = Plain

-- Calls fn and returns its results if the first is plain, else nil.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok or Secret(a) then return nil end
    return a, Plain(b), Plain(c), Plain(d)
end
ns.Call = Call

local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or nil
end
ns.Num = Num

local function Now() return Num(Call(GetTime)) or 0 end
ns.Now = Now

local function PrintPrefix()
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.SHAMAN
    local hex = type(c) == "table" and type(c.colorStr) == "string" and c.colorStr or "ff0070dd"
    return "|c" .. hex .. "Shield Shame|r: "
end

function ns.Print(msg)
    local text = PrintPrefix() .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

function ns.Commas(n)
    n = floor((n or 0) + 0.5)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, s = pcall(BreakUpLargeNumbers, n)
        if ok and type(s) == "string" then return s end
    end
    local s = tostring(n)
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

-- 1 -> "1 orb", 3 -> "3 orbs"
function ns.Count(n, word)
    return ns.Commas(n) .. " " .. word .. (floor((n or 0) + 0.5) == 1 and "" or "s")
end

function ns.Duration(sec)
    sec = floor((sec or 0) + 0.5)
    if sec < 60 then return sec .. "s" end
    if sec < 3600 then return ("%dm %02ds"):format(floor(sec / 60), sec % 60) end
    return ("%dh %02dm"):format(floor(sec / 3600), floor(sec % 3600 / 60))
end

----------------------------------------------------------------------
-- Saved data
----------------------------------------------------------------------
local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

-- One running count: damage and mana lost, orbs missed, seconds fought with no shield, fights
-- that cost something, and (since 1.1.0) seconds fought at all and seconds of those with no
-- shield, for the uptime. "bare" is "seconds" counted only from 1.1.0 on, so an all-time
-- uptime is never worked out from older seconds without the fight time to go with them.
local TALLY = { damage = 0, mana = 0, hits = 0, seconds = 0, fights = 0, fought = 0, bare = 0 }
local function NewTally()
    local t = {}
    for k, v in pairs(TALLY) do t[k] = v end
    return t
end
ns.NewTally = NewTally

local function FixTally(t)
    if type(t) ~= "table" then return NewTally() end
    for k, v in pairs(TALLY) do
        if type(t[k]) ~= "number" then t[k] = v end
    end
    return t
end

ns.session = NewTally()
ns.fight = nil          -- the fight going on now
ns.lastFight = nil      -- the one before

local LOG_FIELDS = { len = 0, seen = 0, shielded = 0, cooldown = 0, lost = 0, casts = 0, damage = 0, mana = 0, bare = 0 }

local function LoadSaved()
    if type(ShieldShameDB) ~= "table" then ShieldShameDB = {} end
    local version = type(ShieldShameDB.settingsVersion) == "number" and ShieldShameDB.settingsVersion or 0
    CopyDefaults(ShieldShameDB, ns.DEFAULTS)
    -- 1.1.0: the chat roast became opt-in (SuccuDev, 2026-11-15: "still annoying in chat").
    -- Turned off once for settings saved before; anyone who turns it back on keeps it.
    if version < 2 then ShieldShameDB.fightLine = false end
    ShieldShameDB.settingsVersion = ns.DEFAULTS.settingsVersion
    ns.db = ShieldShameDB
    if type(ShieldShameCharDB) ~= "table" then ShieldShameCharDB = {} end
    local c = ShieldShameCharDB
    c.total = FixTally(c.total)
    if c.lastUsed ~= "lightning" and c.lastUsed ~= "water" then c.lastUsed = nil end
    if type(c.log) ~= "table" then c.log = {} end
    local log = {}
    for _, e in ipairs(c.log) do
        if type(e) == "table" then
            for k, v in pairs(LOG_FIELDS) do if type(e[k]) ~= "number" then e[k] = v end end
            log[#log + 1] = e
        end
    end
    while #log > ns.LOG_SIZE do table.remove(log, 1) end
    c.log = log
    ns.char = c
end
ns.LoadSaved = LoadSaved

function ns.Set(key, value)
    local default = ns.DEFAULTS[key]
    if default == nil or type(default) == "table" then return end
    if type(default) == "boolean" then value = value and true or false
    elseif type(value) ~= type(default) then return end
    if key == "settingsVersion" then return end
    if key == "measure" and value ~= "auto" and value ~= "lightning" and value ~= "water" then return end
    ns.db[key] = value
    ns.Refresh()
end

function ns.Reset()
    local minimap = ns.db.minimap
    for k in pairs(ns.db) do ns.db[k] = nil end
    CopyDefaults(ns.db, ns.DEFAULTS)
    ns.db.minimap = minimap or {}
    ns.db.settingsVersion = ns.DEFAULTS.settingsVersion
    if ns.UI then ns.UI.Place() end
    if ns.Kit and ns.Kit.RefreshMinimap then pcall(ns.Kit.RefreshMinimap) end
    ns.Refresh()
end

function ns.ResetSession()
    ns.session = NewTally()
    ns.roast = NewTally()
    ns.lastFight = nil
    ns.Refresh()
end

function ns.ResetAll()
    ns.ResetSession()
    ns.char.total = NewTally()
    ns.Refresh()
end

----------------------------------------------------------------------
-- Reading the spells: which shields you know and what an orb is worth
----------------------------------------------------------------------
local function Knows(id)
    for _, f in ipairs({ C_SpellBook and C_SpellBook.IsSpellKnown or false, IsPlayerSpell or false, IsSpellKnown or false }) do
        if f and Call(f, id) == true then return true end
    end
    return false
end
ns.Knows = Knows

local function SpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = Call(C_Spell.GetSpellInfo, spell)
        if type(info) == "table" then return Plain(info.name), Plain(info.iconID), Plain(info.spellID) end
    end
    if GetSpellInfo then
        local ok, name, _, icon, _, _, _, spellID = pcall(GetSpellInfo, spell)
        if ok then return Plain(name), Plain(icon), Plain(spellID) end
    end
end
ns.SpellInfo = SpellInfo

local function Description(id)
    local d
    if C_Spell and C_Spell.GetSpellDescription then d = Call(C_Spell.GetSpellDescription, id) end
    if (type(d) ~= "string" or d == "") and GetSpellDescription then d = Call(GetSpellDescription, id) end
    if type(d) ~= "string" or d == "" then
        if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
        return nil
    end
    return d
end
ns.Description = Description

-- Lower case, no colour codes, no thousands commas.
local function Clean(d)
    if type(d) ~= "string" or d == "" then return nil end
    d = d:lower():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    d = d:gsub("(%d),(%d%d%d)", "%1%2")
    return d
end

local WORDS = { one = 1, two = 2, three = 3, four = 4, five = 5, six = 6 }
local function Charges(d)
    local n = d:match("(%d+) balls") or d:match("(%d+) globes") or d:match("(%d+) orbs") or d:match("(%d+) charges")
    if n then return tonumber(n) end
    local w = d:match("(%a+) balls") or d:match("(%a+) globes") or d:match("(%a+) orbs") or d:match("(%a+) charges")
    return w and WORDS[w] or nil
end

local function Lasts(d)
    local m = tonumber(d:match("lasts (%d+%.?%d*) min"))
    if m then return m * 60 end
    return tonumber(d:match("lasts (%d+%.?%d*) sec"))
end

-- The orb cooldown, when the text gives a number. WoW Forever says "every few seconds".
local function Cooldown(d)
    local s = d:match("one [%a ]-every (%d+%.?%d*) sec") or d:match("once every (%d+%.?%d*) sec")
    return tonumber(s)
end

-- "... the attacker will be struck for 13 Nature damage ..." -> { damage = 13, ... }
function ns.ParseLightning(desc)
    local d = Clean(desc)
    if not d then return nil end
    local lo, hi = d:match("(%d+%.?%d*) to (%d+%.?%d*) nature damage")
    local dmg
    if lo then dmg = (tonumber(lo) + tonumber(hi)) / 2
    else dmg = tonumber(d:match("struck for (%d+%.?%d*)") or d:match("(%d+%.?%d*) nature damage")) end
    if not dmg then return nil end
    return { damage = dmg, charges = Charges(d), lasts = Lasts(d), icd = Cooldown(d) }
end

-- "... 2% of maximum mana is restored to the caster ..." -> { pct = 2, ... }
function ns.ParseWater(desc)
    local d = Clean(desc)
    if not d then return nil end
    local r = { charges = Charges(d), lasts = Lasts(d), icd = Cooldown(d) }
    r.mp5 = tonumber(d:match("(%d+%.?%d*) mana every 5 sec") or d:match("(%d+%.?%d*) mana per 5 sec"))
    r.pct = tonumber(d:match("(%d+%.?%d*)%% of [%a ]-maximum mana") or d:match("(%d+%.?%d*)%% of [%a ]-max mana")
        or d:match("(%d+%.?%d*)%% of [%a ]-total mana"))
    if not r.pct then
        local stripped = d:gsub("%d+%.?%d* mana every 5 sec", ""):gsub("%d+%.?%d* mana per 5 sec", "")
        r.flat = tonumber(stripped:match("restores? (%d+%.?%d*) mana") or stripped:match("(%d+%.?%d*) mana is restored")
            or stripped:match("(%d+%.?%d*) mana to the caster"))
    end
    if not r.pct and not r.flat and not r.mp5 then return nil end
    return r
end

local function MaxMana()
    local v = Num(Call(UnitPowerMax, "player", 0))
    if v and v > 0 then ns.maxMana = v end
    return ns.maxMana or 0
end
ns.MaxMana = MaxMana

-- ns.values.lightning = { id, rank, name, damage, source = "tooltip"|"estimate", charges, lasts, icd }
-- ns.values.water     = { id, name, pct, flat, mp5, source, charges, lasts, icd }
-- Kept from the last plain read, so a fight (where the tooltip may be hidden) still counts.
ns.values = {}

function ns.ReadValues()
    local v = {}
    local L = ns.SHIELDS.lightning
    for rank = #L.ids, 1, -1 do
        local id = L.ids[rank]
        if Knows(id) then
            local parsed = ns.ParseLightning(Description(id))
            local e = { id = id, rank = rank, name = SpellInfo(id) or L.english }
            if parsed then
                e.damage, e.source = parsed.damage, "tooltip"
                e.charges, e.lasts, e.icd = parsed.charges, parsed.lasts, parsed.icd
            else
                local sp = Num(Call(GetSpellBonusDamage, 4)) or 0     -- 4 = Nature
                e.damage, e.source = L.base[rank] + L.coef * max(0, sp), "estimate"
            end
            v.lightning = e
            break
        end
    end
    local W = ns.SHIELDS.water
    for _, id in ipairs(W.ids) do
        if Knows(id) then
            local parsed = ns.ParseWater(Description(id))
            local e = { id = id, name = SpellInfo(id) or W.english }
            if parsed and (parsed.pct or parsed.flat) then
                e.pct, e.flat, e.mp5, e.source = parsed.pct, parsed.flat, parsed.mp5, "tooltip"
                e.charges, e.lasts, e.icd = parsed.charges, parsed.lasts, parsed.icd
            else
                e.pct, e.mp5, e.source = W.pct, parsed and parsed.mp5, "estimate"
            end
            v.water = e
            break
        end
    end
    -- a fight can hide the tooltips: keep the last good read rather than forget a shield
    if InCombatLockdown and Call(InCombatLockdown) == true then
        for _, k in ipairs(ns.KINDS) do
            if not v[k] or (v[k].source == "estimate" and ns.values[k] and ns.values[k].source == "tooltip") then
                v[k] = ns.values[k] or v[k]
            end
        end
    end
    ns.values = v
    MaxMana()
    return v
end

-- What one orb of this shield is worth now: amount, "damage"|"mana".
function ns.OrbValue(kind)
    local e = ns.values[kind]
    if not e then return 0 end
    if kind == "lightning" then return e.damage or 0, "damage" end
    if e.flat then return e.flat, "mana" end
    return (e.pct or 0) / 100 * MaxMana(), "mana"
end

-- The orb cooldown used: the tooltip's number if it gives one, else the setting.
function ns.ICD(kind)
    local e = kind and ns.values[kind]
    return (e and e.icd) or ns.db.icd
end

-- Which shield the loss is counted against: the one picked in the options if you know it,
-- else the one you cast last, else Water Shield if you have it, else Lightning Shield.
function ns.Measured()
    local db = ns.db
    if not db then return nil end
    local v = ns.values
    if db.measure ~= "auto" and v[db.measure] then return db.measure end
    local last = ns.char and ns.char.lastUsed
    if last and v[last] then return last end
    if v.water then return "water" end
    if v.lightning then return "lightning" end
    return nil
end

----------------------------------------------------------------------
-- Is a shield up? ns.shield = { kind, charges, ends } or nil.
----------------------------------------------------------------------
local idKind
local function KindOf(spellId, name)
    if not idKind then
        idKind = {}
        for _, id in ipairs(ns.SHIELDS.lightning.ids) do idKind[id] = "lightning" end
        for _, id in ipairs(ns.SHIELDS.water.auraIds) do idKind[id] = "water" end
        for id in pairs(ns.OTHER_SHIELD_IDS) do idKind[id] = "other" end
    end
    if spellId and idKind[spellId] then return idKind[spellId] end
    if type(name) == "string" then
        for _, k in ipairs(ns.KINDS) do
            local e = ns.values[k]
            if name == ns.SHIELDS[k].english or (e and name == e.name) then return k end
        end
        if ns.OTHER_SHIELD_NAMES[name] then return "other" end
    end
    return nil
end
ns.KindOf = KindOf

-- Reads your buffs. Returns the shield (a table), false for none, or nil if auras are hidden.
local function ReadShield()
    if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then return nil end
    for i = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or Secret(aura) then return nil end
        if type(aura) ~= "table" then return false end
        local name, id = Plain(aura.name), Plain(aura.spellId)
        if name == nil and id == nil then return nil end
        local kind = KindOf(id, name)
        local source = Plain(aura.sourceUnit)
        if kind and (source == nil or source == "player") then
            local stacks = Num(aura.applications) or 0
            local ends = Num(aura.expirationTime) or 0
            return { kind = kind, charges = stacks > 0 and stacks or ns.CHARGES, ends = ends, live = true }
        end
    end
    return false
end
ns.ReadShield = ReadShield

-- The shield to count with: live if the game lets us read it, else the last one we know of,
-- run out at its time or when its orbs are spent.
function ns.CurrentShield(now)
    now = now or Now()
    local live = ReadShield()
    local info = ns.fightInfo
    if info then
        if live ~= nil then info.liveReads = info.liveReads + 1 else info.hiddenReads = info.hiddenReads + 1 end
    end
    if live ~= nil then
        ns.shield = live or nil
        ns.auraLive = true
        if live and live.kind ~= "other" and ns.char then ns.char.lastUsed = live.kind end
        return ns.shield, true
    end
    ns.auraLive = false
    local s = ns.shield
    if s and ((s.ends or 0) > 0 and now >= s.ends or (s.charges or 1) <= 0) then
        ns.shield = nil
    end
    return ns.shield, false
end

-- You cast a shield (UNIT_SPELLCAST_SUCCEEDED gives your own spell IDs even in a fight).
function ns.OnCast(spellID)
    spellID = Num(spellID)
    if not spellID then return end
    local kind = KindOf(spellID)
    if kind ~= "lightning" and kind ~= "water" then return end
    local e = ns.values[kind]
    local now = Now()
    ns.shield = { kind = kind, charges = (e and e.charges) or ns.CHARGES, ends = now + ((e and e.lasts) or ns.DURATION) }
    ns.char.lastUsed = kind
    if ns.fightInfo then ns.fightInfo.casts = ns.fightInfo.casts + 1 end
    if ns.UI then ns.UI.Update() end
end

----------------------------------------------------------------------
-- Counting
----------------------------------------------------------------------
local function Fighting()
    if ns.inCombat then return true end
    return Call(UnitAffectingCombat, "player") == true
end

-- Whether a hit or a second now counts: switched on, a shield to count against, in a fight,
-- alive and not on a flight path.
function ns.Counting()
    if not ns.db or not ns.db.enabled or ns.disabled then return false end
    if not ns.Measured() then return false end
    if not Fighting() then return false end
    if Call(UnitIsDeadOrGhost, "player") == true then return false end
    if Call(UnitOnTaxi, "player") == true then return false end
    return true
end

local function Add(field, amount)
    if amount == 0 then return end
    ns.session[field] = ns.session[field] + amount
    ns.char.total[field] = ns.char.total[field] + amount
    if ns.fight then ns.fight[field] = ns.fight[field] + amount end
end

-- One orb that never fired.
function ns.AddOrb(kind)
    local value, what = ns.OrbValue(kind)
    Add("hits", 1)
    Add(what or "damage", value or 0)
    return value, what
end

local HIT = { WOUND = true, BLOCK = true, ABSORB = true }
ns.unreadableHits = 0
ns.lastOrb = -1e9

-- UNIT_COMBAT for the player. action is plain on WoW Forever (the amount is not, and is not used).
function ns.OnHit(action, schoolMask, now)
    if not ns.Counting() then return nil end
    action = Plain(action)
    if type(action) ~= "string" then
        ns.unreadableHits = ns.unreadableHits + 1
        return nil
    end
    if not HIT[action] then return nil end
    local school = Num(schoolMask)
    if school and school ~= 1 and not ns.db.spellHits then return nil end
    now = now or Now()
    local info = ns.fightInfo
    if info then info.seen = info.seen + 1 end
    local s = ns.CurrentShield(now)
    local kind = s and s.kind ~= "other" and s.kind or ns.Measured()
    local ready = now - ns.lastOrb >= ns.ICD(kind)
    if s then
        -- a real orb fires; when we can't see the aura, spend one of ours
        if ready then
            ns.lastOrb = now
            if not ns.auraLive then
                s.charges = (s.charges or ns.CHARGES) - 1
                if s.charges <= 0 then
                    ns.shield = nil
                    if ns.UI then ns.UI.Update() end
                end
            end
        end
        if info then info.shielded = info.shielded + 1 end
        return "shielded"
    end
    if not ready then
        if info then info.cooldown = info.cooldown + 1 end
        return "cooldown"
    end
    ns.lastOrb = now
    if info then info.lost = info.lost + 1 end
    ns.AddOrb(ns.Measured())
    if ns.UI then ns.UI.Update() end
    return "lost"
end

-- Called about twice a second: unshielded time in a fight, and the passive regen (if any).
ns.lastTick = nil
function ns.Tick(now)
    now = now or Now()
    local last = ns.lastTick
    ns.lastTick = now
    if not last or not ns.Counting() then return end
    local dt = min(now - last, 5)
    if dt <= 0 then return end
    Add("fought", dt)
    local had = ns.shield ~= nil
    local s = ns.CurrentShield(now)
    if (s ~= nil) ~= had and ns.UI then ns.UI.Update() end
    if s then return end
    Add("seconds", dt)
    Add("bare", dt)
    local kind = ns.Measured()
    local e = ns.values[kind]
    if kind == "water" and e and e.mp5 and e.mp5 > 0 then Add("mana", e.mp5 / 5 * dt) end
end

----------------------------------------------------------------------
-- The shaming
----------------------------------------------------------------------
ns.LINES = {
    damage = {
        "{hits} hits taken with no Lightning Shield up. That's {amount} damage you could have zapped back for free. Shameful.",
        "Lightning Shield sat in your spellbook while you ate {hits} hits. {amount} damage, gone. Your ancestors are disappointed.",
        "{amount} damage never dealt, because recasting a shield was apparently too much to ask. {hits} hits, zero zaps.",
        "You fought naked. {hits} hits, {amount} damage of free lightning you left on the table. The elements saw that.",
    },
    mana = {
        "{hits} hits taken without Water Shield: {amount} mana you just didn't want, apparently.",
        "Thirsty? You threw away {amount} mana by fighting without Water Shield. {hits} globes that never popped.",
        "{amount} mana down the drain. Water Shield is one click. One. You took {hits} hits instead.",
        "Out of mana again? {amount} of it was yours for free. {hits} hits, no globes. Drink your shame.",
    },
}
ns.TEASE = {
    lightning = {
        "Fighting naked again?",
        "Your balls of lightning are still in the spellbook.",
        "Those mobs aren't going to zap themselves.",
    },
    water = {
        "No Water Shield. Hope you packed water.",
        "Your water globes are lonely.",
        "Free mana, one click away. Still not clicked.",
    },
}
ns.lineIndex = 0

local function Fill(template, hits, amount)
    return (template:gsub("{hits}", ns.Commas(hits)):gsub("{amount}", ns.Commas(amount)))
end

-- The line for a tally, or nil if it lost nothing worth a word.
function ns.ShameLine(t)
    if not t then return nil end
    local what = (t.damage >= t.mana and t.damage > 0) and "damage" or (t.mana > 0 and "mana") or nil
    if not what then return nil end
    local amount = t[what]
    if amount < 1 then return nil end
    ns.lineIndex = ns.lineIndex % #ns.LINES[what] + 1
    local line = Fill(ns.LINES[what][ns.lineIndex], t.hits, amount)
    local other = what == "damage" and "mana" or "damage"
    if t[other] >= 1 then line = line .. (" Plus %s %s."):format(ns.Commas(t[other]), other) end
    return line
end

function ns.Tease(kind)
    local list = ns.TEASE[kind] or ns.TEASE.lightning
    return list[floor(Now() / 60) % #list + 1]
end

-- What you'd say to your group, plain text (no colours in group chat).
local lastConfess = -1e9
function ns.Confess(t)
    if not ns.db.confess or not t then return false end
    local now = Now()
    if now - lastConfess < 60 then return false end
    local channel
    if Call(IsInRaid) == true then channel = "RAID" elseif Call(IsInGroup) == true then channel = "PARTY" end
    if not channel then return false end
    local parts = {}
    if t.damage >= 1 then parts[#parts + 1] = ns.Commas(t.damage) .. " damage" end
    if t.mana >= 1 then parts[#parts + 1] = ns.Commas(t.mana) .. " mana" end
    if #parts == 0 then return false end
    local msg = ("[Shield Shame] I fought without my shield: %s hits, %s lost. Point and laugh."):format(
        ns.Commas(t.hits), table.concat(parts, " and "))
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then return false end
    local ok = pcall(send, msg, channel)
    if ok then lastConfess = now end
    return ok
end

-- 1234 -> "1,234"; 12345 -> "12.3k"; 1234567 -> "1.2m". For the line under the icon.
function ns.Short(n)
    n = floor((n or 0) + 0.5)
    if n < 10000 then return ns.Commas(n) end
    if n < 1000000 then return (("%.1f"):format(n / 1000):gsub("%.0$", "")) .. "k" end
    return (("%.1f"):format(n / 1000000):gsub("%.0$", "")) .. "m"
end

-- Share of fight time with a shield up, 0-100, or nil before any fight time was counted.
function ns.Uptime(t)
    if not t or (t.fought or 0) < 1 then return nil end
    return max(0, min(100, 100 * (1 - (t.bare or 0) / t.fought)))
end

local function Pct(p) return ("%d%%"):format(floor(p + 0.5)) end
ns.Pct = Pct

-- What a tally lost, in words: "1,234 mana", "56 damage and 1,234 mana", or "nothing".
function ns.LostText(t)
    local parts = {}
    if t.damage >= 1 then parts[#parts + 1] = ns.Commas(t.damage) .. " damage" end
    if t.mana >= 1 then parts[#parts + 1] = ns.Commas(t.mana) .. " mana" end
    return #parts > 0 and table.concat(parts, " and ") or "nothing"
end

function ns.Summary()
    local lines = {}
    local function Line(label, t)
        local up = ns.Uptime(t)
        local tail = up and (", shield up %s of %s fought"):format(Pct(up), ns.Duration(t.fought))
            or (t.seconds >= 1 and (", %s in fights with no shield"):format(ns.Duration(t.seconds)) or "")
        lines[#lines + 1] = ("%s: |cffffffff%s lost|r (%s missed%s)."):format(
            label, ns.LostText(t), ns.Count(t.hits, "orb"), tail)
    end
    if ns.fight then Line("This fight", ns.fight) elseif ns.lastFight then Line("Last fight", ns.lastFight) end
    Line("This session", ns.session)
    Line("All time", ns.char.total)
    return lines
end

-- The verdict goes by uptime: this session's once it has a minute of fighting, else all time's.
function ns.Verdict()
    local t = (ns.session.fought or 0) >= 60 and ns.session or ns.char.total
    local up = ns.Uptime(t)
    if not up then
        if ns.char.total.hits == 0 then return "Not a single orb wasted. Suspicious, but fine." end
        return "That's a habit now. Recast your shield."
    end
    if up >= 95 then return "Shield up " .. Pct(up) .. " of the time. The elements grudgingly approve." end
    if up >= 80 then return "Shield up " .. Pct(up) .. " of the time. Sloppy. The elements are watching." end
    if up >= 50 then return "Shield up " .. Pct(up) .. " of the time. That's a habit now. Recast your shield." end
    return "Shield up " .. Pct(up) .. " of the time. Legendary negligence. Your totems have filed a complaint."
end

function ns.PrintSummary()
    if ns.disabled then
        ns.Print("Shield Shame is for shamans. You have nothing to be ashamed of here. Shield-wise.")
        return
    end
    for _, line in ipairs(ns.Summary()) do ns.Print(line) end
    if not ns.Measured() then
        ns.Print(("you don't know a shield yet (Lightning Shield comes at level %d), so there is nothing to count."):format(ns.SHIELDS.lightning.learnLevel))
    else
        ns.Print(ns.Verdict())
    end
end

----------------------------------------------------------------------
-- The fight log: the last LOG_SIZE fights on this character, for checking the counts against
-- what really happened (/shame log, or ShieldShameCharDB.log in the saved variables).
----------------------------------------------------------------------
local function ShieldText(s)
    if not s then return "none" end
    if s.kind == "other" then return "Earth Shield" end
    return ("%s (%s)"):format(ns.SHIELDS[s.kind].english, ns.Count(s.charges or 0, "orb"))
end

local function Stamp()
    if type(date) == "function" then
        local ok, v = pcall(date, "%m-%d %H:%M")
        if ok and type(v) == "string" then return v end
    end
    return ""
end

function ns.LogLine(e)
    local lost = {}
    if e.damage >= 1 then lost[#lost + 1] = ns.Commas(e.damage) .. " damage" end
    if e.mana >= 1 then lost[#lost + 1] = ns.Commas(e.mana) .. " mana" end
    local at = (e.at and e.at ~= "") and (e.at .. ", ") or ""
    return ("%s%s fight. Shield at the start: %s; auras %s. %s: %d shielded, %d lost, %d inside the orb cooldown. "
        .. "%s cast. No shield for %s. Lost %s."):format(
        at, ns.Duration(e.len), e.start or "?", e.auras or "?", ns.Count(e.seen, "hit"), e.shielded, e.lost, e.cooldown,
        ns.Count(e.casts, "shield"), ns.Duration(e.bare), #lost > 0 and table.concat(lost, " and ") or "nothing")
end

local function FightStart()
    ns.inCombat = true
    ns.fight = NewTally()
    ns.lastTick = Now()
    local info = { started = ns.lastTick, liveReads = 0, hiddenReads = 0, seen = 0, shielded = 0, cooldown = 0, lost = 0, casts = 0 }
    ns.fightInfo = info
    local s, live = ns.CurrentShield()
    info.start = ShieldText(s) .. (live and "" or " (auras hidden: the addon's own record)")
    if ns.UI then ns.UI.Update() end
end

-- Keeps the fight in the log if anything was counted in it.
local function LogFight(t, info)
    if not info or (t.fought or 0) < 1 then return end
    local auras = info.hiddenReads == 0 and "readable" or (info.liveReads == 0 and "hidden" or "sometimes hidden")
    local log = ns.char.log
    log[#log + 1] = {
        at = Stamp(), len = max(0, Now() - (info.started or Now())), start = info.start, auras = auras,
        seen = info.seen, shielded = info.shielded, cooldown = info.cooldown, lost = info.lost, casts = info.casts,
        damage = floor(t.damage + 0.5), mana = floor(t.mana + 0.5), bare = floor(t.bare + 0.5),
    }
    while #log > ns.LOG_SIZE do table.remove(log, 1) end
end

-- The roast: costly fights pile up in ns.roast and come out as one line, only once the pile is
-- worth reading (a full shield's orbs, or 5% of your max mana) and at most once every
-- roastMinutes. Every fight still goes into the session and all-time counts straight away.
ns.roast = NewTally()
ns.lastRoast = nil       -- when the last roast line was printed (nil: none yet this session)

function ns.WorthRoasting(t)
    if not t or t.fights == 0 then return false end
    if t.hits >= ns.ROAST_ORBS then return true end
    local most = MaxMana()
    return most > 0 and t.mana >= most * ns.ROAST_MANA_PCT / 100
end
ns.ROAST_ORBS = 3            -- a whole shield's worth of orbs
ns.ROAST_MANA_PCT = 5        -- or this share of your max mana

-- Returns the line it printed, or nil.
function ns.MaybeRoast(now)
    now = now or Now()
    local t = ns.roast
    if not ns.WorthRoasting(t) then return nil end
    if ns.lastRoast and now - ns.lastRoast < ns.db.roastMinutes * 60 then return nil end
    local line = ns.ShameLine(t)
    if not line then return nil end
    if t.fights > 1 then line = ("Last %d fights: %s"):format(t.fights, line) end
    ns.roast = NewTally()
    ns.lastRoast = now
    if ns.db.fightLine then ns.Print(line) end
    ns.Confess(t)
    return line
end

local function FightEnd()
    local t = ns.fight
    if t then ns.Tick() end
    local info = ns.fightInfo
    ns.inCombat = false
    ns.fight = nil
    ns.fightInfo = nil
    ns.lastTick = nil
    if t then
        ns.lastFight = t
        LogFight(t, info)
        if t.damage >= 1 or t.mana >= 1 then
            t.fights = 1
            ns.session.fights = ns.session.fights + 1
            ns.char.total.fights = ns.char.total.fights + 1
            for k in pairs(ns.roast) do ns.roast[k] = ns.roast[k] + t[k] end
        end
        ns.MaybeRoast()
    end
    ns.QueueRefresh()
end
ns.FightStart, ns.FightEnd = FightStart, FightEnd

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
function ns.Refresh()
    if ns.UI then ns.UI.Update() end
    if ns.Kit and ns.Options and ns.Kit.Sync then pcall(ns.Kit.Sync) end
end

local refreshQueued
local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    local function Run()
        refreshQueued = false
        if ns.disabled then return end
        if Call(InCombatLockdown) ~= true then ns.ReadValues() end
        ns.CurrentShield()
        if ns.UI then ns.UI.Update() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, Run) else Run() end
end
ns.QueueRefresh = QueueRefresh

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
local function HasKit()
    if ns.Kit and ns.Options and ns.Options.Ready and ns.Options.Ready() then return true end
    ns.Print("the options window and the minimap button appear after you restart the game once.")
    return false
end

local NAMES = { lightning = "Lightning Shield", water = "Water Shield", auto = "the shield you used last" }

local function Status()
    local measured = ns.Measured()
    ns.Print(("counting: %s, against %s (setting: %s). In a fight: %s. Auras %s."):format(
        ns.Counting() and "yes" or (ns.db.enabled and "not now" or "off"),
        measured and NAMES[measured] or "nothing (no shield known)", NAMES[ns.db.measure] or ns.db.measure,
        Fighting() and "yes" or "no",
        ns.auraLive and "readable" or "hidden, using the last read"))
    local s = ns.shield
    ns.Print(s and ("shield up: %s, %d orbs%s."):format(s.kind == "other" and "Earth Shield" or NAMES[s.kind], s.charges or 0,
        (s.ends or 0) > 0 and (", %s left"):format(ns.Duration(s.ends - Now())) or "") or "no shield up. Naturally.")
    local L, W = ns.values.lightning, ns.values.water
    if L then
        ns.Print(("Lightning Shield rank %d (%d): %s damage an orb (%s)."):format(L.rank, L.id, ns.Commas(L.damage),
            L.source == "tooltip" and "from its tooltip" or "estimated: base + 26.7% of spell power"))
    else
        ns.Print("Lightning Shield: not known.")
    end
    if W then
        local value = ns.OrbValue("water")
        local how
        if W.flat then
            how = "from its tooltip"
        else
            how = ("%s%% of max mana, %s"):format(tostring(W.pct), W.source == "tooltip" and "from its tooltip" or "estimated")
        end
        local regen = W.mp5 and (", %s mana every 5 sec while up"):format(tostring(W.mp5)) or ", no passive regen"
        ns.Print(("Water Shield: %s mana an orb (%s, %s max mana)%s."):format(ns.Commas(value), how, ns.Commas(MaxMana()), regen))
    else
        ns.Print("Water Shield: not known (a Restoration talent).")
    end
    ns.Print(("orb cooldown: %s sec (%s). Hits by spells: %s. Hits not readable: %d."):format(
        tostring(ns.ICD(measured)), (measured and ns.values[measured] and ns.values[measured].icd) and "from the tooltip" or "setting, an estimate",
        ns.db.spellHits and "counted" or "ignored", ns.unreadableHits))
end
ns.Status = Status

local function Slash(msg)
    msg = (type(msg) == "string" and msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not ns.db then return end
    if ns.disabled then
        ns.Print("Shield Shame is for shamans. You have nothing to be ashamed of here. Shield-wise.")
        return
    end
    if msg == "" or msg == "lost" or msg == "summary" then
        ns.PrintSummary()
    elseif msg == "options" or msg == "config" or msg == "o" then
        if HasKit() then ns.Kit.Open() end
    elseif msg == "on" or msg == "off" then
        ns.Set("enabled", msg == "on")
        ns.Print(msg == "on" and "counting and reminding on. Brace yourself." or "counting and reminding off. Coward.")
    elseif msg == "lock" or msg == "unlock" then
        ns.Set("locked", msg == "lock")
        ns.Print(msg == "lock" and "reminder locked in place." or "reminder unlocked: drag it to move it.")
    elseif msg == "lightning" or msg == "water" or msg == "auto" then
        ns.Set("measure", msg)
        ns.Print("counting losses against " .. NAMES[msg] .. ".")
    elseif msg == "reset session" or msg == "new" then
        ns.ResetSession()
        ns.Print("session count started again. A clean slate you don't deserve.")
    elseif msg == "reset all" then
        ns.ResetAll()
        ns.Print("every count on this character set back to 0. The evidence is gone.")
    elseif msg == "reset" then
        ns.Print("|cffffffff/shame reset session|r starts the session count again; |cffffffff/shame reset all|r also clears this character's all-time count.")
    elseif msg == "test" then
        if ns.UI then ns.UI.SetTesting(not ns.UI.Testing()) end
        ns.Print(ns.UI and ns.UI.Testing() and "showing the reminder. /shame test again to hide it." or "test reminder hidden.")
    elseif msg == "log" then
        local log = ns.char.log
        if #log == 0 then
            ns.Print("no fights logged yet on this character.")
        else
            local from = max(1, #log - 7)
            ns.Print(("the last %d of %d logged fights, oldest first:"):format(#log - from + 1, #log))
            for i = from, #log do ns.Print(ns.LogLine(log[i])) end
        end
    elseif msg == "status" or msg == "debug" then
        ns.ReadValues()
        ns.CurrentShield()
        Status()
    else
        ns.Print("|cffffffff/shame|r what you lost, |cffffffff/shame options|r, |cffffffff/shame on|r / |cffffffffoff|r, "
            .. "|cffffffff/shame lightning|r / |cffffffffwater|r / |cffffffffauto|r (what to count against), "
            .. "|cffffffff/shame lock|r / |cffffffffunlock|r, |cffffffff/shame test|r, |cffffffff/shame reset|r, |cffffffff/shame log|r (the last fights, hit by hit), |cffffffff/shame status|r.")
    end
end
ns.Slash = Slash

SLASH_SHIELDSHAME1 = "/shame"
SLASH_SHIELDSHAME2 = "/shieldshame"
SlashCmdList = SlashCmdList or {}
SlashCmdList.SHIELDSHAME = function(msg)
    local ok, err = pcall(Slash, msg)
    if not ok then ns.Print("error: " .. tostring(err)) end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.frame = frame

local UNIT_EVENTS = { UNIT_AURA = true, UNIT_COMBAT = true, UNIT_SPELLCAST_SUCCEEDED = true, UNIT_MAXPOWER = true }

local handlers = {}
function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    LoadSaved()
end

local function IsShaman()
    local _, class = Call(UnitClass, "player")
    return class == "SHAMAN"
end
ns.IsShaman = IsShaman

local elapsed = 0
function handlers.PLAYER_LOGIN()
    if not ns.db then LoadSaved() end
    if not IsShaman() then
        ns.disabled = true
        frame:UnregisterAllEvents()
        frame:SetScript("OnUpdate", nil)
        return
    end
    for event in pairs(handlers) do
        if event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" then
            if UNIT_EVENTS[event] and frame.RegisterUnitEvent then
                local ok = pcall(frame.RegisterUnitEvent, frame, event, "player")
                if not ok then pcall(frame.RegisterEvent, frame, event) end
            else
                pcall(frame.RegisterEvent, frame, event)
            end
        end
    end
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < 0.5 then return end
        elapsed = 0
        local ok, err = pcall(ns.Tick)
        if not ok and not ns.reported then
            ns.reported = true
            ns.Print("error: " .. tostring(err))
        end
    end)
    ns.ReadValues()
    ns.CurrentShield()
    if ns.UI then ns.UI.Init() end
    if ns.Kit and ns.Options then
        local ok, err = pcall(ns.Options.Init)
        if not ok then ns.Print("options could not start: " .. tostring(err)) end
    end
    if Fighting() then FightStart() end
    ns.Refresh()
end

function handlers.PLAYER_ENTERING_WORLD() QueueRefresh() end
function handlers.SPELLS_CHANGED() QueueRefresh() end
function handlers.PLAYER_LEVEL_UP() QueueRefresh() end
function handlers.UNIT_MAXPOWER(unit) if unit == "player" then MaxMana() end end
function handlers.UNIT_AURA(unit)
    if unit ~= "player" then return end
    ns.CurrentShield()
    if ns.UI then ns.UI.Update() end
end
function handlers.UNIT_COMBAT(unit, action, _, _, schoolMask)
    if unit == "player" then ns.OnHit(action, schoolMask) end
end
function handlers.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if unit == "player" then ns.OnCast(spellID) end
end
function handlers.PLAYER_REGEN_DISABLED() FightStart() end
function handlers.PLAYER_REGEN_ENABLED() FightEnd() end
function handlers.PLAYER_DEAD()
    ns.shield = nil          -- shields go when you die
    if ns.UI then ns.UI.Update() end
end
function handlers.PLAYER_ALIVE() QueueRefresh() end
function handlers.PLAYER_UNGHOST() QueueRefresh() end
function handlers.PLAYER_UPDATE_RESTING() QueueRefresh() end
function handlers.PLAYER_MOUNT_DISPLAY_CHANGED() QueueRefresh() end
ns.handlers = handlers

frame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok and not ns.reported then
        ns.reported = true
        ns.Print("error in " .. event .. ": " .. tostring(err))
    end
end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
