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
--   * Everything is per fight. After a fight that took your mana (Water Shield) or health
--     (Lightning Shield) below a line, 50% by default, with a shield missing, one line says
--     what that cost. Other fights are only logged.
--
-- Auras can be secret in a fight. The shield's state from before the fight then stands in,
-- with its orbs spent by the hits you take and topped up when you cast a shield.
local ADDON, ns = ...

local floor, max, min = math.floor, math.max, math.min

ns.VERSION = "1.2.2"

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
    hurtLine = true,        -- one line in chat after a fight that took you below hurtPct with a shield missing
    hurtPct = 50,           -- "a fight that hurt": your mana (Water Shield) or health (Lightning Shield) went below this
    confess = false,        -- also tell your party or raid (off unless you turn it on)
    locked = false,
    scale = 1,
    point = { "TOP", "TOP", 0, -190 },
    minimap = {},
    settingsVersion = 3,    -- 3: 1.2.0 went per fight; the old roast settings are gone
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

-- What one fight cost: damage and mana lost, orbs missed, seconds fought, and seconds of those
-- with no shield up. Everything is per fight (SuccuDev, 2026-11-15: "theres no point to all
-- time it should be per fight").
local TALLY = { damage = 0, mana = 0, hits = 0, fought = 0, bare = 0 }
local function NewTally()
    local t = {}
    for k, v in pairs(TALLY) do t[k] = v end
    return t
end
ns.NewTally = NewTally

ns.fight = nil          -- the fight going on now
ns.lastFight = nil      -- the one before

local LOG_FIELDS = { len = 0, seen = 0, shielded = 0, cooldown = 0, lost = 0, casts = 0, damage = 0, mana = 0, bare = 0 }

local function LoadSaved()
    if type(ShieldShameDB) ~= "table" then ShieldShameDB = {} end
    CopyDefaults(ShieldShameDB, ns.DEFAULTS)
    ShieldShameDB.fightLine, ShieldShameDB.roastMinutes = nil, nil      -- 1.0.1-1.1.0's roast
    ShieldShameDB.settingsVersion = ns.DEFAULTS.settingsVersion
    ns.db = ShieldShameDB
    if type(ShieldShameCharDB) ~= "table" then ShieldShameCharDB = {} end
    local c = ShieldShameCharDB
    c.total = nil                                                       -- 1.0.0-1.1.0's all-time count
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
    if ns.UI then ns.UI.Place() end
    if ns.Kit and ns.Kit.RefreshMinimap then pcall(ns.Kit.RefreshMinimap) end
    ns.Refresh()
end

function ns.ClearLog()
    ns.char.log = {}
    ns.lastFight = nil
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
    if amount == 0 or not ns.fight then return end
    ns.fight[field] = ns.fight[field] + amount
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
    if ns.fightInfo then ns.SampleLow(ns.fightInfo) end
    if not last or not ns.Counting() then return end
    local dt = min(now - last, 5)
    if dt <= 0 then return end
    Add("fought", dt)
    local had = ns.shield ~= nil
    local s = ns.CurrentShield(now)
    if (s ~= nil) ~= had and ns.UI then ns.UI.Update() end
    if s then return end
    Add("bare", dt)
    local kind = ns.Measured()
    local e = ns.values[kind]
    if kind == "water" and e and e.mp5 and e.mp5 > 0 then Add("mana", e.mp5 / 5 * dt) end
end

----------------------------------------------------------------------
-- The shaming
----------------------------------------------------------------------
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
-- Said after the line for a fight that hurt, in turn.
ns.JABS = {
    mana = { "Drink your shame.", "One click. One.", "The elements saw that.", "Your ancestors are disappointed." },
    health = { "Those mobs aren't going to zap themselves.", "The elements saw that.", "Fighting naked again?", "Your totems have filed a complaint." },
}
ns.jabIndex = 0

function ns.Tease(kind)
    local list = ns.TEASE[kind] or ns.TEASE.lightning
    return list[floor(Now() / 60) % #list + 1]
end

-- 1234 -> "1,234"; 12345 -> "12.3k"; 1234567 -> "1.2m". For the line under the icon.
function ns.Short(n)
    n = floor((n or 0) + 0.5)
    if n < 10000 then return ns.Commas(n) end
    if n < 1000000 then return (("%.1f"):format(n / 1000):gsub("%.0$", "")) .. "k" end
    return (("%.1f"):format(n / 1000000):gsub("%.0$", "")) .. "m"
end

-- Share of a fight with a shield up, 0-100, or nil if no fight time was counted.
function ns.Uptime(t)
    if not t or (t.fought or 0) < 1 then return nil end
    return max(0, min(100, 100 * (1 - (t.bare or 0) / t.fought)))
end

local function Pct(p) return ("%d%%"):format(floor(p + 0.5)) end
ns.Pct = Pct

-- What a fight lost, in words: "1,234 mana", "56 damage and 1,234 mana", or "nothing".
function ns.LostText(t)
    local parts = {}
    if (t.damage or 0) >= 1 then parts[#parts + 1] = ns.Commas(t.damage) .. " damage" end
    if (t.mana or 0) >= 1 then parts[#parts + 1] = ns.Commas(t.mana) .. " mana" end
    return #parts > 0 and table.concat(parts, " and ") or "nothing"
end

----------------------------------------------------------------------
-- How low a fight took you. Sampled with the tick (twice a second) while a fight is on.
----------------------------------------------------------------------
local function PctOf(cur, most)
    cur, most = Num(cur), Num(most)
    if not cur or not most or most <= 0 then return nil end
    return max(0, min(100, 100 * cur / most))
end
function ns.ManaPct()
    local most = Num(Call(UnitPowerMax, "player", 0))
    if most and most > 0 then ns.maxMana = most end
    return PctOf(Call(UnitPower, "player", 0), most)
end
function ns.HealthPct() return PctOf(Call(UnitHealth, "player"), Call(UnitHealthMax, "player")) end

-- Keeps the lowest mana and health of the fight, and how much mana the missing shield had
-- cost by the time mana was at its lowest (that much higher is where it would have bottomed out).
function ns.SampleLow(info)
    local mp = ns.ManaPct()
    if mp and (not info.lowMana or mp < info.lowMana) then
        info.lowMana = mp
        info.manaLostAtLow = ns.fight and ns.fight.mana or 0
    end
    local hp = ns.HealthPct()
    if hp and (not info.lowHealth or hp < info.lowHealth) then info.lowHealth = hp end
end

-- Did this fight hurt, with a shield missing? Returns "mana", "health" or nil.
-- Water Shield's loss matters when the fight took your mana below the line, Lightning Shield's
-- when it took your health below it. Where the game hides how low you went, a loss of a whole
-- shield's 3 orbs, or 5% of your max mana, stands in.
ns.FALLBACK_ORBS, ns.FALLBACK_MANA_PCT = 3, 5
function ns.Hurt(t, info)
    if not t or not info then return nil end
    local line = ns.db.hurtPct
    if t.mana >= 1 then
        if info.lowMana then
            if info.lowMana < line then return "mana" end
        elseif t.hits >= ns.FALLBACK_ORBS or (MaxMana() > 0 and t.mana >= MaxMana() * ns.FALLBACK_MANA_PCT / 100) then
            return "mana"
        end
    end
    if t.damage >= 1 then
        if info.lowHealth then
            if info.lowHealth < line then return "health" end
        elseif t.hits >= ns.FALLBACK_ORBS then
            return "health"
        end
    end
    return nil
end

-- The line for a fight that hurt.
function ns.HurtLine(t, info, what)
    local line
    if what == "mana" then
        local most = MaxMana()
        local share = most > 0 and (" (%s of your bar)"):format(Pct(100 * t.mana / most)) or ""
        if info.lowMana then
            line = ("That fight took you down to %s mana, and you fought it without Water Shield: %s mana%s you never got."):format(
                Pct(info.lowMana), ns.Commas(t.mana), share)
            local before = info.manaLostAtLow or 0
            if before >= 1 and most > 0 then
                line = line .. (" With it up you'd have bottomed out at %s."):format(Pct(min(100, info.lowMana + 100 * before / most)))
            end
        else
            line = ("That fight cost you %s mana%s with no Water Shield up: %s that never popped."):format(
                ns.Commas(t.mana), share, ns.Count(t.hits, "globe"))
        end
    else
        if info.lowHealth then
            line = ("That fight took you down to %s health, and Lightning Shield wasn't up: %s damage you never zapped back."):format(
                Pct(info.lowHealth), ns.Commas(t.damage))
        else
            line = ("That fight cost you %s damage with no Lightning Shield up: %s that never fired."):format(
                ns.Commas(t.damage), ns.Count(t.hits, "orb"))
        end
    end
    local jabs = ns.JABS[what]
    ns.jabIndex = ns.jabIndex % #jabs + 1
    return line .. " " .. jabs[ns.jabIndex]
end

-- What you'd say to your group, plain text (no colours in group chat).
local lastConfess = -1e9
function ns.Confess(t, info, what)
    if not ns.db.confess or not t then return false end
    local now = Now()
    if now - lastConfess < 60 then return false end
    local channel
    if Call(IsInRaid) == true then channel = "RAID" elseif Call(IsInGroup) == true then channel = "PARTY" end
    if not channel then return false end
    local msg
    if what == "mana" then
        local low = info and info.lowMana
        msg = ("[Shield Shame] %sI had no Water Shield up: %s mana wasted. Point and laugh."):format(
            low and ("That fight took me to %s mana and "):format(Pct(low)) or "", ns.Commas(t.mana))
    else
        local low = info and info.lowHealth
        msg = ("[Shield Shame] %sI had no Lightning Shield up: %s damage never dealt. Point and laugh."):format(
            low and ("That fight took me to %s health and "):format(Pct(low)) or "", ns.Commas(t.damage))
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then return false end
    local ok = pcall(send, msg, channel)
    if ok then lastConfess = now end
    return ok
end

-- "Last fight: 240 mana lost (6 orbs missed, shield up 40% of 1m 12s). Lowest: 31% mana, 64% health."
function ns.FightText(label, t, lowMana, lowHealth)
    local up = ns.Uptime(t)
    local text = ("%s: |cffffffff%s lost|r (%s missed%s)."):format(label, ns.LostText(t), ns.Count(t.hits, "orb"),
        up and (", shield up %s of %s"):format(Pct(up), ns.Duration(t.fought)) or "")
    local low = {}
    if lowMana then low[#low + 1] = Pct(lowMana) .. " mana" end
    if lowHealth then low[#low + 1] = Pct(lowHealth) .. " health" end
    if #low > 0 then text = text .. " Lowest: " .. table.concat(low, ", ") .. "." end
    return text
end

-- The logged fights that hurt, added up: how many, damage, mana, out of how many fights.
function ns.RecentHurt()
    local n, damage, mana = 0, 0, 0
    for _, e in ipairs(ns.char.log) do
        if e.hurt then n, damage, mana = n + 1, damage + e.damage, mana + e.mana end
    end
    return n, damage, mana, #ns.char.log
end

function ns.Summary()
    local lines = {}
    if ns.fight then
        local i = ns.fightInfo or {}
        lines[#lines + 1] = ns.FightText("This fight", ns.fight, i.lowMana, i.lowHealth)
    elseif ns.lastFight then
        lines[#lines + 1] = ns.FightText("Last fight", ns.lastFight, ns.lastFight.lowMana, ns.lastFight.lowHealth)
    else
        lines[#lines + 1] = "No fight yet since you logged in."
    end
    local n, damage, mana, of = ns.RecentHurt()
    if of > 0 then
        if n == 0 then
            lines[#lines + 1] = ("None of your last %s took you below %d%% with a shield missing. Suspicious, but fine."):format(
                ns.Count(of, "fight"), ns.db.hurtPct)
        else
            lines[#lines + 1] = ("%d of your last %s took you below %d%% with a shield missing. Those cost you %s."):format(
                n, ns.Count(of, "fight"), ns.db.hurtPct, ns.LostText({ damage = damage, mana = mana }))
        end
    end
    return lines
end

function ns.PrintSummary()
    if ns.disabled then
        ns.Print("Shield Shame is for shamans. You have nothing to be ashamed of here. Shield-wise.")
        return
    end
    if not ns.Measured() then
        ns.Print(("you don't know a shield yet (Lightning Shield comes at level %d), so there is nothing to count."):format(ns.SHIELDS.lightning.learnLevel))
        return
    end
    for _, line in ipairs(ns.Summary()) do ns.Print(line) end
end

----------------------------------------------------------------------
-- The fight log: the last LOG_SIZE fights on this character. /shame sums up the ones that
-- hurt; /shame log shows each one hit by hit, to check the counts against the game.
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
    local at = (e.at and e.at ~= "") and (e.at .. ", ") or ""
    local low = {}
    if type(e.lowMana) == "number" then low[#low + 1] = Pct(e.lowMana) .. " mana" end
    if type(e.lowHealth) == "number" then low[#low + 1] = Pct(e.lowHealth) .. " health" end
    return ("%s%s fight%s. Shield at the start: %s; auras %s. %s: %d shielded, %d lost, %d inside the orb cooldown. "
        .. "%s cast. No shield for %s. Lost %s.%s"):format(
        at, ns.Duration(e.len), e.hurt and ", |cffffffffhurt|r" or "", e.start or "?", e.auras or "?", ns.Count(e.seen, "hit"),
        e.shielded, e.lost, e.cooldown, ns.Count(e.casts, "shield"), ns.Duration(e.bare),
        ns.LostText(e), #low > 0 and (" Lowest: " .. table.concat(low, ", ") .. ".") or "")
end

local function FightStart()
    ns.inCombat = true
    ns.fight = NewTally()
    ns.lastTick = Now()
    local info = { started = ns.lastTick, liveReads = 0, hiddenReads = 0, seen = 0, shielded = 0, cooldown = 0, lost = 0, casts = 0 }
    ns.fightInfo = info
    local s, live = ns.CurrentShield()
    info.start = ShieldText(s) .. (live and "" or " (auras hidden: the addon's own record)")
    ns.SampleLow(info)
    if ns.UI then ns.UI.Update() end
end

-- Keeps the fight in the log if anything was counted in it.
local function LogFight(t, info, hurt)
    if not info or (t.fought or 0) < 1 then return end
    local auras = info.hiddenReads == 0 and "readable" or (info.liveReads == 0 and "hidden" or "sometimes hidden")
    local log = ns.char.log
    log[#log + 1] = {
        at = Stamp(), len = max(0, Now() - (info.started or Now())), start = info.start, auras = auras,
        seen = info.seen, shielded = info.shielded, cooldown = info.cooldown, lost = info.lost, casts = info.casts,
        damage = floor(t.damage + 0.5), mana = floor(t.mana + 0.5), bare = floor(t.bare + 0.5),
        lowMana = info.lowMana and floor(info.lowMana + 0.5), lowHealth = info.lowHealth and floor(info.lowHealth + 0.5),
        hurt = hurt and true or nil,
    }
    while #log > ns.LOG_SIZE do table.remove(log, 1) end
end

-- Ends the fight; after one that hurt, says so (if that is on). Returns the line, or nil.
local function FightEnd()
    local t = ns.fight
    if t then ns.Tick() end
    local info = ns.fightInfo
    ns.inCombat = false
    ns.fight = nil
    ns.fightInfo = nil
    ns.lastTick = nil
    local said
    if t then
        if info then t.lowMana, t.lowHealth = info.lowMana, info.lowHealth end
        ns.lastFight = t
        local what = ns.Hurt(t, info)
        LogFight(t, info, what)
        if what then
            said = ns.HurtLine(t, info, what)
            if ns.db.hurtLine then ns.Print(said) end
            ns.Confess(t, info, what)
        end
    end
    ns.QueueRefresh()
    return said
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
    ns.Print("the options window and the minimap button appear after a /reload.")
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
    elseif msg == "reset" or msg == "reset all" or msg == "reset session" or msg == "clear" then
        ns.ClearLog()
        ns.Print("fight log cleared. The evidence is gone.")
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
            .. "|cffffffff/shame lock|r / |cffffffffunlock|r, |cffffffff/shame test|r, |cffffffff/shame log|r (the last fights, hit by hit), |cffffffff/shame reset|r (clears the log), |cffffffff/shame status|r.")
    end
end
ns.Slash = Slash

SLASH_SHIELDSHAME1 = "/shame"
SLASH_SHIELDSHAME2 = "/shieldshame"
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
