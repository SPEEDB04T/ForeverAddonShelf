-- BiS Planner: your best gear for the stat weights and goals you set.
--
-- The item list (Data.lua) is built outside the game from the client's own tables. This file
-- reads it, decides what your class can wear at a level, builds the candidates per slot and
-- hands them to Solver.lua. The plan is saved, so the window and the tooltip line never plan
-- again until a weight, a goal, a filter or your level changes.
local ADDON, ns = ...
ns.NAME = "BiS Planner"
ns.VERSION = "1.0.0"
ns.ICON = "Interface\\Icons\\INV_Chest_Plate04"

local Solver = ns.Solver
local floor, max, min = math.floor, math.max, math.min

----------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------
function ns.Clean(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function ns.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return ns.Clean(a), ns.Clean(b), ns.Clean(c), ns.Clean(d)
end

function ns.Print(msg)
    local text = "|cffffd200BiS Planner|r: " .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

local function After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

function ns.Number(value)
    if value == floor(value) then return ("%d"):format(value) end
    return (("%.1f"):format(value))
end

----------------------------------------------------------------------
-- The stats you can weigh or set a goal for
----------------------------------------------------------------------
ns.STAT_GROUPS = {
    { "Attributes", {
        { "str", "Strength" }, { "agi", "Agility" }, { "sta", "Stamina" },
        { "int", "Intellect" }, { "spi", "Spirit" },
    } },
    { "Attack", {
        { "ap", "Attack power" }, { "rap", "Ranged attack power" }, { "hit", "Hit" },
        { "crit", "Critical strike" }, { "haste", "Haste" }, { "expertise", "Expertise" },
        { "mdps", "Main-hand weapon damage per second" }, { "odps", "Off-hand weapon damage per second" },
        { "rdps", "Ranged weapon damage per second" },
    } },
    { "Spells", {
        { "dmg", "Spell damage" }, { "heal", "Healing" },
        { "spFire", "Fire damage" }, { "spFrost", "Frost damage" }, { "spArcane", "Arcane damage" },
        { "spShadow", "Shadow damage" }, { "spNature", "Nature damage" }, { "spHoly", "Holy damage" },
        { "mp5", "Mana per 5 seconds" }, { "spellPen", "Spell penetration" },
    } },
    { "Defense", {
        { "armor", "Armor" }, { "defense", "Defense" }, { "dodge", "Dodge" }, { "parry", "Parry" },
        { "block", "Block" }, { "blockValue", "Block value" }, { "hp5", "Health per 5 seconds" },
    } },
    { "Resistances", {
        { "resFire", "Fire resistance" }, { "resFrost", "Frost resistance" }, { "resNature", "Nature resistance" },
        { "resShadow", "Shadow resistance" }, { "resArcane", "Arcane resistance" }, { "resHoly", "Holy resistance" },
    } },
}
ns.STAT_NAME = {}
for _, group in ipairs(ns.STAT_GROUPS) do
    for _, stat in ipairs(group[2]) do ns.STAT_NAME[stat[1]] = stat[2] end
end

----------------------------------------------------------------------
-- What each class can wear. Class ids are the game's (UnitClass's third return).
----------------------------------------------------------------------
local CLASS_ID = { WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11 }
ns.CLASS_ID = CLASS_ID

-- weapon subclasses: 0/1 axe, 2 bow, 3 gun, 4/5 mace, 6 polearm, 7/8 sword, 10 staff, 13 fist,
-- 15 dagger, 16 thrown, 18 crossbow, 19 wand
local function Set(...)
    local t = {}
    for i = 1, select("#", ...) do t[select(i, ...)] = true end
    return t
end
local WEAPONS = {
    WARRIOR = Set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = Set(0, 1, 4, 5, 6, 7, 8),
    HUNTER = Set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE = Set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST = Set(4, 10, 15, 19),
    SHAMAN = Set(0, 1, 4, 5, 10, 13, 15),
    MAGE = Set(7, 10, 15, 19),
    WARLOCK = Set(7, 10, 15, 19),
    DRUID = Set(4, 5, 10, 13, 15),
}
-- armor subclasses: 1 cloth, 2 leather, 3 mail, 4 plate, 6 shield, 7 libram, 8 idol, 9 totem.
-- The number is the level the class learns it at.
local ARMOR = {
    WARRIOR = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1 },
    PALADIN = { [1] = 1, [2] = 1, [3] = 1, [4] = 40, [6] = 1, [7] = 1 },
    HUNTER = { [1] = 1, [2] = 1, [3] = 40 },
    ROGUE = { [1] = 1, [2] = 1 },
    PRIEST = { [1] = 1 },
    SHAMAN = { [1] = 1, [2] = 1, [3] = 40, [6] = 1, [9] = 1 },
    MAGE = { [1] = 1 },
    WARLOCK = { [1] = 1 },
    DRUID = { [1] = 1, [2] = 1, [8] = 1 },
}
local DUAL_WIELD = { WARRIOR = 20, ROGUE = 10, HUNTER = 20 }

----------------------------------------------------------------------
-- Items: one line of Data.lua each, read when first asked for
--   name|slot|class|subclass|level|item level|quality|flags|class mask|stats|source
----------------------------------------------------------------------
local RANGED_SLOT = { [15] = true, [25] = true, [26] = true, [28] = true }
local items = {}

local function ParseItem(id, line)
    local name, inv, class, sub, level, ilvl, quality, flags, mask, stats, source =
        line:match("^(.-)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(%a*)|(%d*)|([^|]*)|([^|]*)$")
    if not name then return false end
    local item = {
        id = id, name = name, inv = tonumber(inv), class = tonumber(class), sub = tonumber(sub),
        level = tonumber(level), ilvl = tonumber(ilvl), quality = tonumber(quality),
        mask = tonumber(mask), source = source ~= "" and source or nil, stats = {},
    }
    -- Quest rewards often need no level to wear: plan them for about when their quest comes up.
    if item.level <= 1 and item.ilvl > 10 then
        item.level = item.ilvl - 8
        item.guess = true
    end
    if item.level < 1 then item.level = 1 end
    item.unique = flags:find("u", 1, true) ~= nil
    item.boe = flags:find("e", 1, true) ~= nil
    item.special = flags:find("x", 1, true) ~= nil
    item.side = flags:find("a", 1, true) and "Alliance" or flags:find("h", 1, true) and "Horde" or nil
    local s = item.stats
    for key, value in stats:gmatch("(%w+):([%-%d%.]+)") do
        value = tonumber(value)
        if key == "sp" then                 -- spell power is both
            s.dmg = (s.dmg or 0) + value
            s.heal = (s.heal or 0) + value
        elseif key == "dps" then
            item.dps = value
        elseif key == "spd" then
            item.speed = value
        else
            s[key] = (s[key] or 0) + value
        end
    end
    if item.dps and RANGED_SLOT[item.inv] then s.rdps = item.dps end
    return item
end

function ns.Item(id)
    local item = items[id]
    if item == nil then
        local line = ns.ItemData and ns.ItemData[id]
        item = line and ParseItem(id, line) or false
        items[id] = item
    end
    return item or nil
end

-- The stats an item gives in a hand: its weapon damage counts for that hand.
local function HandStats(item, key)
    if not item.dps or item.class ~= 2 then return item.stats end
    local cacheKey = "_" .. key
    local t = item[cacheKey]
    if not t then
        t = {}
        for k, v in pairs(item.stats) do t[k] = v end
        t[key] = item.dps
        item[cacheKey] = t
    end
    return t
end
ns.HandStats = HandStats

----------------------------------------------------------------------
-- Saved settings
----------------------------------------------------------------------
local function CharKey()
    local name = ns.Call(UnitName, "player") or "Unknown"
    local realm = ns.Call(GetRealmName) or "Realm"
    return name .. " - " .. realm
end

function ns.Player()
    local _, class = ns.Call(UnitClass, "player")
    local side = ns.Call(UnitFactionGroup, "player")
    local level = ns.Call(UnitLevel, "player")
    return {
        class = CLASS_ID[class] and class or "WARRIOR",
        side = side,
        level = type(level) == "number" and level > 0 and level or 1,
    }
end

local FILTER_DEFAULTS = { maxQuality = 5, crafted = true, pvp = false, rep = true, weapons = "any" }

local function InitDB()
    if type(BisPlannerDB) ~= "table" then BisPlannerDB = {} end
    local db = BisPlannerDB
    db.version = 1
    if type(db.minimap) ~= "table" then db.minimap = {} end
    if db.tooltip == nil then db.tooltip = true end
    if type(db.profiles) ~= "table" then db.profiles = {} end
    if type(db.chars) ~= "table" then db.chars = {} end
    local key = CharKey()
    if type(db.chars[key]) ~= "table" then db.chars[key] = {} end
    local char = db.chars[key]
    if type(char.excluded) ~= "table" then char.excluded = {} end
    if type(char.filters) ~= "table" then char.filters = {} end
    for k, v in pairs(FILTER_DEFAULTS) do
        if char.filters[k] == nil then char.filters[k] = v end
    end
    if type(char.profile) ~= "string" or type(db.profiles[char.profile]) ~= "table" then
        local first
        for name, profile in pairs(db.profiles) do
            if type(profile) == "table" and (not first or name < first) then first = name end
        end
        char.profile = first or "Main"
        if not first then db.profiles.Main = {} end
    end
    for _, profile in pairs(db.profiles) do
        if type(profile.weights) ~= "table" then profile.weights = {} end
        if type(profile.goals) ~= "table" then profile.goals = {} end
    end
    ns.db, ns.char = db, char
end

function ns.Profile()
    local profile = ns.db.profiles[ns.char.profile]
    if type(profile) ~= "table" then
        profile = { weights = {}, goals = {} }
        ns.db.profiles[ns.char.profile] = profile
    end
    return profile
end

function ns.ProfileNames()
    local names = {}
    for name in pairs(ns.db.profiles) do names[#names + 1] = name end
    table.sort(names)
    return names
end

function ns.SetProfile(name)
    if type(ns.db.profiles[name]) ~= "table" then return false end
    ns.char.profile = name
    ns.Changed()
    return true
end

function ns.NewProfile(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "Give the set of weights a name." end
    if ns.db.profiles[name] then return false, ("There is already a set called %s."):format(name) end
    -- starts as a copy of the one in use
    local from = ns.Profile()
    local copy = { weights = {}, goals = {} }
    for k, v in pairs(from.weights) do copy.weights[k] = v end
    for k, v in pairs(from.goals) do copy.goals[k] = v end
    ns.db.profiles[name] = copy
    ns.char.profile = name
    ns.Changed()
    return true
end

function ns.DeleteProfile(name)
    name = name or ns.char.profile
    if not ns.db.profiles[name] then return false end
    local count = 0
    for _ in pairs(ns.db.profiles) do count = count + 1 end
    if count <= 1 then
        ns.db.profiles[name] = { weights = {}, goals = {} }     -- the last one is emptied instead
    else
        ns.db.profiles[name] = nil
        if ns.char.profile == name then ns.char.profile = ns.ProfileNames()[1] end
    end
    ns.Changed()
    return true
end

-- kind: "weights" or "goals". A goal of 0 or less, or an empty box, is no goal.
function ns.SetStat(kind, key, value)
    if not ns.STAT_NAME[key] then return end
    if type(value) ~= "number" or value ~= value or value == 0 then value = nil end
    if kind == "goals" and value and value < 0 then value = nil end
    local profile = ns.Profile()
    if profile[kind][key] == value then return end
    profile[kind][key] = value
    ns.Changed()
end

function ns.PlanLevel()
    local level = ns.char.level
    if type(level) == "number" and level >= 1 then return floor(level) end
    return ns.Player().level
end

function ns.SetLevel(level)
    if type(level) == "number" and level >= 1 then
        ns.char.level = min(floor(level), 100)
        if ns.char.level == ns.Player().level then ns.char.level = nil end
    else
        ns.char.level = nil
    end
    ns.Changed()
end

function ns.DualWield()
    local value = ns.char.filters.dualWield
    if value ~= nil then return value and true or false end
    local player = ns.Player()
    local at = DUAL_WIELD[player.class]
    return at ~= nil and ns.PlanLevel() >= at
end

----------------------------------------------------------------------
-- What you can wear
----------------------------------------------------------------------
local function HasBit(mask, bit)
    return floor(mask / 2 ^ bit) % 2 == 1
end

-- ctx: { class, side, level, filters, excluded }
function ns.Usable(item, ctx)
    if item.level > ctx.level then return false end
    if item.quality > (ctx.filters.maxQuality or 5) then return false end
    if ctx.excluded[item.id] then return false end
    if item.side and ctx.side and item.side ~= ctx.side then return false end
    if item.mask and item.mask > 0 and not HasBit(item.mask, CLASS_ID[ctx.class] - 1) then return false end
    local source = item.source
    if source then
        local kind = source:sub(1, 1)
        if kind == "c" and not ctx.filters.crafted then return false end
        if kind == "p" and not ctx.filters.pvp then return false end
        if kind == "r" and not ctx.filters.rep then return false end
    end
    if item.class == 2 then
        return WEAPONS[ctx.class][item.sub] == true
    end
    if item.class == 4 and item.sub >= 1 and item.inv ~= 16 then    -- every class wears cloaks
        local at = ARMOR[ctx.class][item.sub]
        return at ~= nil and ctx.level >= at
    end
    return true
end

----------------------------------------------------------------------
-- Slots
----------------------------------------------------------------------
local SIMPLE = {
    { "Head", 1 }, { "Neck", 2 }, { "Shoulder", 3 }, { "Back", 16 }, { "Chest", 5, 20 }, { "Wrist", 9 },
    { "Hands", 10 }, { "Waist", 6 }, { "Legs", 7 }, { "Feet", 8 },
}
-- inventory type -> the pool it goes in
local POOL = {
    [11] = "Ring", [12] = "Trinket", [17] = "TwoHand", [13] = "OneHand", [21] = "MainHand",
    [22] = "OffHand", [14] = "Shield", [23] = "Held", [15] = "Ranged", [25] = "Ranged", [26] = "Ranged", [28] = "Ranged",
}
for _, def in ipairs(SIMPLE) do
    for i = 2, #def do POOL[def[i]] = def[1] end
end
ns.POOL = POOL

-- Rows of a plan, in the order shown. group: the rows an item of that pool is compared with.
ns.ROWS = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Wrist", "Hands", "Waist", "Legs", "Feet",
    "Ring 1", "Ring 2", "Trinket 1", "Trinket 2", "Main hand", "Off hand", "Ranged",
}
local ROW_GROUP = {
    Ring = { "Ring 1", "Ring 2" }, Trinket = { "Trinket 1", "Trinket 2" },
    TwoHand = { "Main hand" }, OneHand = { "Main hand", "Off hand" }, MainHand = { "Main hand" },
    OffHand = { "Off hand" }, Shield = { "Off hand" }, Held = { "Off hand" },
}
function ns.RowsFor(item)
    local pool = POOL[item.inv]
    if not pool then return nil end
    return ROW_GROUP[pool] or { pool }
end

local function Context()
    local player = ns.Player()
    return {
        class = player.class, side = player.side, level = ns.PlanLevel(),
        filters = ns.char.filters, excluded = ns.char.excluded,
    }
end
ns.Context = Context

local function Pools(ctx)
    local pools = {}
    for id in pairs(ns.ItemData or {}) do
        local item = ns.Item(id)
        local pool = item and POOL[item.inv]
        if pool and ns.Usable(item, ctx) then
            local list = pools[pool]
            if not list then list = {}; pools[pool] = list end
            list[#list + 1] = item
        end
    end
    -- the same order every time, so the same settings give the same plan
    for _, list in pairs(pools) do
        table.sort(list, function(a, b) return a.id < b.id end)
    end
    return pools
end
ns.Pools = Pools

local function Cands(list, statKey)
    local out = {}
    for i, item in ipairs(list or {}) do
        out[i] = { item = item, stats = statKey and HandStats(item, statKey) or item.stats }
    end
    return out
end

local function Sum(a, b)
    local t = {}
    for k, v in pairs(a) do t[k] = v end
    for k, v in pairs(b) do t[k] = (t[k] or 0) + v end
    return t
end

-- Every pair from a pool (rings, trinkets). The same item twice only when it isn't unique.
local function Pairs(list, weights, goals)
    local pool = Solver.Prune(Cands(list), weights, goals)
    local out = {}
    for i = 1, #pool do
        local a = pool[i]
        for j = i, #pool do
            local b = pool[j]
            if i ~= j or not a.item.unique then
                out[#out + 1] = { items = { a.item, b.item }, stats = Sum(a.stats, b.stats) }
            end
        end
    end
    if #out == 0 and pool[1] then       -- one unique item and nothing else
        out[1] = { items = { pool[1].item }, stats = pool[1].stats }
    end
    return Solver.Prune(out, weights, goals, 12, 6)
end

local function WeaponCands(pools, ctx, weights, goals)
    local mode = ctx.filters.weapons or "any"
    local out = {}
    if mode ~= "1h" then
        for _, cand in ipairs(Solver.Prune(Cands(pools.TwoHand, "mdps"), weights, goals)) do
            out[#out + 1] = { items = { cand.item }, stats = cand.stats, twoHand = true }
        end
    end
    if mode ~= "2h" then
        local mainList = {}
        for _, item in ipairs(pools.OneHand or {}) do mainList[#mainList + 1] = item end
        for _, item in ipairs(pools.MainHand or {}) do mainList[#mainList + 1] = item end
        local offList, offWeapons = {}, {}
        for _, item in ipairs(pools.Shield or {}) do offList[#offList + 1] = item end
        for _, item in ipairs(pools.Held or {}) do offList[#offList + 1] = item end
        if ns.DualWield() then
            for _, item in ipairs(pools.OneHand or {}) do offWeapons[#offWeapons + 1] = item end
            for _, item in ipairs(pools.OffHand or {}) do offWeapons[#offWeapons + 1] = item end
        end
        local mains = Solver.Prune(Cands(mainList, "mdps"), weights, goals)
        local offs = Solver.Prune(Cands(offList), weights, goals)
        for _, cand in ipairs(Solver.Prune(Cands(offWeapons, "odps"), weights, goals)) do
            offs[#offs + 1] = cand
        end
        for _, a in ipairs(mains) do
            if #offs == 0 then out[#out + 1] = { items = { a.item }, stats = a.stats } end
            for _, b in ipairs(offs) do
                if a.item ~= b.item or not a.item.unique then
                    out[#out + 1] = { items = { a.item, b.item }, stats = Sum(a.stats, b.stats) }
                end
            end
        end
        if #mains == 0 then
            for _, b in ipairs(offs) do out[#out + 1] = { items = { false, b.item }, stats = b.stats } end
        end
    end
    return Solver.Prune(out, weights, goals, 14, 6)
end

----------------------------------------------------------------------
-- Planning
----------------------------------------------------------------------
local function HasAny(t)
    for _, v in pairs(t) do
        if type(v) == "number" and v ~= 0 then return true end
    end
    return false
end

-- What a setting change would have to differ in for the saved plan to be out of date.
local function Stamp()
    local profile = ns.Profile()
    local parts = { ns.VERSION, ns.DataInfo and ns.DataInfo.build or "?", ns.Player().class, tostring(ns.PlanLevel()),
        tostring(ns.DualWield()) }
    for _, kind in ipairs({ "weights", "goals" }) do
        local keys = {}
        for key in pairs(profile[kind]) do keys[#keys + 1] = key end
        table.sort(keys)
        for _, key in ipairs(keys) do parts[#parts + 1] = kind:sub(1, 1) .. key .. "=" .. tostring(profile[kind][key]) end
    end
    local keys = {}
    for key in pairs(ns.char.filters) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. tostring(ns.char.filters[key]) end
    local out = {}
    for id in pairs(ns.char.excluded) do out[#out + 1] = id end
    table.sort(out)
    parts[#parts + 1] = "x" .. table.concat(out, ".")
    return table.concat(parts, ";")
end
ns.Stamp = Stamp

-- The best few others for a row: ranked the way the plan was (score plus what the goals paid).
local function Alternatives(list, statKey, weights, lambda, taken, pickedValue)
    local ranked = {}
    for _, item in ipairs(list) do
        if not taken[item.id] then
            local stats = statKey and HandStats(item, statKey) or item.stats
            local value = Solver.Score(stats, weights)
            for key, price in pairs(lambda) do value = value + price * (stats[key] or 0) end
            if value > 0 then ranked[#ranked + 1] = { id = item.id, value = value } end
        end
    end
    table.sort(ranked, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return a.id < b.id
    end)
    local out = {}
    for i = 1, min(3, #ranked) do
        out[i] = { id = ranked[i].id, diff = ranked[i].value - pickedValue }
    end
    return out
end

-- Builds the plan and saves it. Returns the plan, or nil and why not.
function ns.MakePlan()
    local profile = ns.Profile()
    local weights, goals = profile.weights, profile.goals
    local char = ns.char
    if not (HasAny(weights) or HasAny(goals)) then
        char.plan = nil
        return nil, "Give at least one stat a weight or a goal first."
    end
    local ctx = Context()
    local pools = Pools(ctx)
    local slots = {}
    for _, def in ipairs(SIMPLE) do
        slots[#slots + 1] = { key = def[1], cands = Solver.Prune(Cands(pools[def[1]]), weights, goals) }
    end
    slots[#slots + 1] = { key = "Ranged", cands = Solver.Prune(Cands(pools.Ranged), weights, goals) }
    slots[#slots + 1] = { key = "Rings", cands = Pairs(pools.Ring, weights, goals) }
    slots[#slots + 1] = { key = "Trinkets", cands = Pairs(pools.Trinket, weights, goals) }
    slots[#slots + 1] = { key = "Weapons", cands = WeaponCands(pools, ctx, weights, goals) }

    local result = Solver.Solve(slots, weights, goals)
    local picked = {}       -- row name -> { item, statKey, pool list }
    local taken = {}
    local function Put(row, item, statKey, list)
        if not item then return end
        picked[row] = { item = item, statKey = statKey, list = list }
        taken[item.id] = true
    end
    for _, def in ipairs(SIMPLE) do
        local cand = result.picks[def[1]]
        if cand then Put(def[1], cand.item, nil, pools[def[1]]) end
    end
    if result.picks.Ranged then Put("Ranged", result.picks.Ranged.item, nil, pools.Ranged) end
    local rings = result.picks.Rings
    if rings then
        Put("Ring 1", rings.items[1], nil, pools.Ring)
        Put("Ring 2", rings.items[2], nil, pools.Ring)
    end
    local trinkets = result.picks.Trinkets
    if trinkets then
        Put("Trinket 1", trinkets.items[1], nil, pools.Trinket)
        Put("Trinket 2", trinkets.items[2], nil, pools.Trinket)
    end
    local weapons = result.picks.Weapons
    if weapons then
        local a, b = weapons.items[1], weapons.items[2]
        if a then
            local list = {}
            for _, name in ipairs(weapons.twoHand and { "TwoHand" } or { "OneHand", "MainHand" }) do
                for _, item in ipairs(pools[name] or {}) do list[#list + 1] = item end
            end
            Put("Main hand", a, "mdps", list)
            picked["Main hand"].twoHand = weapons.twoHand
        end
        if b then
            local weapon = b.class == 2
            local list = {}
            for _, name in ipairs(weapon and { "OneHand", "OffHand" } or { "Shield", "Held" }) do
                for _, item in ipairs(pools[name] or {}) do list[#list + 1] = item end
            end
            Put("Off hand", b, weapon and "odps" or nil, list)
        end
    end

    local plan = {
        stamp = Stamp(), level = ctx.level, profile = char.profile, time = time(),
        score = result.score, feasible = result.feasible, rows = {}, goals = {}, totals = {},
    }
    for _, row in ipairs(ns.ROWS) do
        local p = picked[row]
        if p then
            local stats = p.statKey and HandStats(p.item, p.statKey) or p.item.stats
            local score = Solver.Score(stats, weights)
            local value, useful = score, score ~= 0
            for key, price in pairs(result.lambda) do value = value + price * (stats[key] or 0) end
            for key in pairs(result.goals) do
                if (stats[key] or 0) > 0 then useful = true end
            end
            -- an item that gives nothing you asked for is not a pick: the slot is left open
            if useful then
                for key, amount in pairs(stats) do
                    if weights[key] or goals[key] then plan.totals[key] = (plan.totals[key] or 0) + amount end
                end
                plan.rows[#plan.rows + 1] = {
                    slot = row, id = p.item.id, score = score, twoHand = p.twoHand or nil,
                    alts = Alternatives(p.list, p.statKey, weights, result.lambda, taken, value),
                }
            end
        end
    end
    local keys = {}
    for key in pairs(result.goals) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local g = result.goals[key]
        plan.goals[#plan.goals + 1] = { key = key, have = g.have, want = g.want, met = g.met }
    end
    char.plan = plan
    return plan
end

-- The saved plan when it still fits the settings, else a new one.
function ns.Plan()
    local plan = ns.char.plan
    if type(plan) == "table" and plan.stamp == Stamp() then return plan end
    return ns.MakePlan()
end

function ns.PlanRow(slot)
    local plan = ns.char and ns.char.plan
    if type(plan) ~= "table" then return nil end
    for _, row in ipairs(plan.rows) do
        if row.slot == slot then return row end
    end
end

-- A setting changed: plan again shortly (once, however many changes come together).
local pending = false
function ns.Changed()
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh(true) end
    if pending then return end
    pending = true
    After(0.3, function()
        pending = false
        if not ns.db then return end
        ns.Plan()
        if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    end)
end

function ns.Exclude(id, out)
    ns.char.excluded[id] = out and true or nil
    ns.Changed()
end

function ns.ExcludedCount()
    local n = 0
    for _ in pairs(ns.char.excluded) do n = n + 1 end
    return n
end

function ns.BringBack()
    local n = ns.ExcludedCount()
    ns.char.excluded = {}
    ns.Changed()
    return n
end

function ns.ResetSettings()
    local key = CharKey()
    BisPlannerDB.chars[key] = nil
    BisPlannerDB.tooltip = nil
    InitDB()
    ns.Changed()
end

----------------------------------------------------------------------
-- Where an item comes from, as far as the client's own tables say. Drops and quests come
-- from Questie when it is installed.
----------------------------------------------------------------------
local questie
local function Questie()
    if questie ~= nil then return questie or nil end
    questie = false
    if type(QuestieLoader) == "table" and type(QuestieLoader.ImportModule) == "function" then
        local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
        if ok and type(db) == "table" and type(db.QueryItemSingle) == "function" then questie = db end
    end
    return questie or nil
end

local function QuestieSource(id)
    local db = Questie()
    if not db then return nil end
    local function Query(fn, key, field)
        if type(fn) ~= "function" then return nil end
        local ok, value = pcall(fn, key, field)
        if ok then return value end
    end
    local quests = Query(db.QueryItemSingle, id, "questRewards")
    if type(quests) == "table" and quests[1] then
        local name = Query(db.QueryQuestSingle, quests[1], "name")
        if type(name) == "string" then return "Quest: " .. name end
    end
    local npcs = Query(db.QueryItemSingle, id, "npcDrops")
    if type(npcs) == "table" and npcs[1] then
        local name = Query(db.QueryNPCSingle, npcs[1], "name")
        if type(name) == "string" then
            return #npcs > 3 and "Drops from many creatures" or ("Drops from " .. name)
        end
    end
    local vendors = Query(db.QueryItemSingle, id, "vendors")
    if type(vendors) == "table" and vendors[1] then
        local name = Query(db.QueryNPCSingle, vendors[1], "name")
        if type(name) == "string" then return "Sold by " .. name end
    end
end

function ns.SourceText(item)
    local source = item.source
    if source then
        local kind, rest = source:sub(1, 1), source:sub(2)
        if kind == "c" then
            local name = ns.Professions and ns.Professions[tonumber(rest)]
            return name and ("Crafted: " .. name) or "Crafted"
        elseif kind == "p" then
            return "PvP rank " .. rest
        elseif kind == "r" then
            local faction, standing = rest:match("^(%d+)%.(%d+)$")
            local name = ns.Factions and ns.Factions[tonumber(faction)]
            local label = standing and _G["FACTION_STANDING_LABEL" .. (tonumber(standing) + 1)]
            if name and type(label) == "string" then return ("Reputation: %s (%s)"):format(name, label) end
            return name and ("Reputation: " .. name) or "Reputation reward"
        end
    end
    local found = QuestieSource(item.id)
    if found then return found end
    if item.boe then return "Binds when equipped" end
    return nil
end

function ns.Owned(id)
    if ns.Call(C_Item and C_Item.IsEquippedItem or IsEquippedItem, id) == true then return "equipped" end
    local count = ns.Call(C_Item and C_Item.GetItemCount or GetItemCount, id, true)
    if type(count) == "number" and count > 0 then return "owned" end
    return nil
end

----------------------------------------------------------------------
-- The line on item tooltips
----------------------------------------------------------------------
-- What the tooltip says about an item: { score, inPlan = "Head" } or { score, other = row, diff }.
function ns.Judge(id)
    local item = ns.Item(id)
    local plan = ns.char and ns.char.plan
    if not item or type(plan) ~= "table" then return nil end
    local rows = ns.RowsFor(item)
    if not rows then return nil end
    local weights = ns.Profile().weights
    local pool = POOL[item.inv]
    local hand = (pool == "TwoHand" or pool == "OneHand" or pool == "MainHand") and "mdps" or pool == "OffHand" and "odps"
    local score = Solver.Score(hand and HandStats(item, hand) or item.stats, weights)
    local worst
    for _, name in ipairs(rows) do
        local row = ns.PlanRow(name)
        if row then
            if row.id == id then return { score = score, inPlan = name } end
            if not worst or row.score < worst.score then worst = row end
        end
    end
    if not worst then return { score = score } end
    return { score = score, other = worst, diff = score - worst.score }
end

local function TooltipLine(tooltip, id)
    if not (ns.db and ns.db.tooltip) or type(id) ~= "number" then return end
    local verdict = ns.Judge(id)
    if not verdict then return end
    local gold, white = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }, HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
    if verdict.inPlan then
        tooltip:AddDoubleLine("BiS Planner", "In your plan: " .. verdict.inPlan, gold.r, gold.g, gold.b, white.r, white.g, white.b)
    elseif verdict.other then
        local other = ns.Item(verdict.other.id)
        local c = verdict.diff > 0 and (GREEN_FONT_COLOR or { r = 0.1, g = 1, b = 0.1 }) or white
        tooltip:AddDoubleLine("BiS Planner",
            ("%s%s against %s"):format(verdict.diff > 0 and "+" or "", ns.Number(verdict.diff), other and other.name or "your plan"),
            gold.r, gold.g, gold.b, c.r, c.g, c.b)
    end
end
ns.TooltipLine = TooltipLine

local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        local ok = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function(tooltip, data)
            if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
            local id = type(data) == "table" and ns.Clean(data.id) or nil
            pcall(TooltipLine, tooltip, id)
        end)
        if ok then return end
    end
    if GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function(tooltip)
            local _, link = ns.Call(tooltip.GetItem, tooltip)
            local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
            pcall(TooltipLine, tooltip, id)
        end)
    end
end

----------------------------------------------------------------------
-- Items the game has never sent this computer: ask for them, so the next rebuild of the
-- item list (outside the game) can read them from the game's cache.
----------------------------------------------------------------------
local fetch
function ns.Fetch()
    if fetch then
        ns.Print(("Still asking: %d of %d done."):format(fetch.at, #fetch.ids))
        return
    end
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if type(request) ~= "function" or not (C_Timer and C_Timer.NewTicker) then
        ns.Print("This game version can't ask for items by number.")
        return
    end
    local ids = {}
    for id in tostring(ns.MissingItems or ""):gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
    if #ids == 0 then
        ns.Print("Nothing to ask for: every item in the list is known.")
        return
    end
    fetch = { ids = ids, at = 0, found = 0 }
    ns.Print(("Asking the game for %d items it has not shown this computer yet. About %d minutes."):format(
        #ids, max(1, floor(#ids / 40 / 60 + 0.5))))
    fetch.ticker = C_Timer.NewTicker(0.25, function()
        for _ = 1, 10 do
            fetch.at = fetch.at + 1
            local id = fetch.ids[fetch.at]
            if not id then break end
            pcall(request, id)
        end
        if fetch.at >= #fetch.ids then
            fetch.ticker:Cancel()
            local done = fetch
            After(5, function()
                ns.Print(("Done: %d of %d exist. They join the planner when its item list is next rebuilt."):format(
                    done.found, #done.ids))
                fetch = nil
            end)
        end
    end)
end

----------------------------------------------------------------------
-- Chat output and slash commands
----------------------------------------------------------------------
function ns.GoalText(goal)
    return ("%s %s of %s"):format(ns.STAT_NAME[goal.key] or goal.key, ns.Number(goal.have), ns.Number(goal.want))
end

function ns.Summary(plan)
    local met, total = 0, #plan.goals
    for _, goal in ipairs(plan.goals) do
        if goal.met then met = met + 1 end
    end
    local text = ("Level %d, score %s"):format(plan.level, ns.Number(floor(plan.score * 10 + 0.5) / 10))
    if total == 0 then return text end
    if met == total then
        return text .. (total == 1 and ", goal reached" or (", all %d goals reached"):format(total))
    end
    return text .. (", %d of %d goals reached"):format(met, total)
end

function ns.Report()
    local plan, why = ns.Plan()
    if not plan then
        ns.Print(why)
        return
    end
    ns.Print(("%s (%s)."):format(ns.Summary(plan), plan.profile))
    for _, row in ipairs(plan.rows) do
        local item = ns.Item(row.id)
        ns.Print(("%s: %s"):format(row.slot, item and item.name or ("item " .. row.id)))
    end
    for _, goal in ipairs(plan.goals) do
        if not goal.met then ns.Print("Not reached: " .. ns.GoalText(goal) .. ".") end
    end
end

local function Help()
    ns.Print("Commands: /bisplan (the window), /bisplan print, /bisplan level <number> (or: /bisplan level auto), "
        .. "/bisplan unhide (items you left out come back), /bisplan options, /bisplan fetch")
end

local function Slash(msg)
    if not ns.db then return end
    local cmd, rest = tostring(msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" then
        if ns.UI then ns.UI.Toggle() end
    elseif cmd == "print" or cmd == "plan" then
        ns.Report()
    elseif cmd == "level" then
        local level = tonumber(rest)
        if level and level >= 1 then
            ns.SetLevel(level)
            ns.Print(("Planning for level %d."):format(ns.PlanLevel()))
        elseif rest == "auto" or rest == "" then
            ns.SetLevel(nil)
            ns.Print("Planning for your own level.")
        else
            Help()
        end
    elseif cmd == "unhide" then
        local n = ns.BringBack()
        ns.Print(n == 0 and "No item was left out." or ("%d left-out %s back."):format(n, n == 1 and "item is" or "items are"))
    elseif cmd == "options" or cmd == "config" then
        if ns.Kit then ns.Kit.Open() end
    elseif cmd == "fetch" then
        ns.Fetch()
    else
        Help()
    end
end

SLASH_BISPLANNER1 = "/bisplan"
SLASH_BISPLANNER2 = "/bisplanner"
-- Only the entry: writing the SlashCmdList global itself taints every slash command.
SlashCmdList["BISPLANNER"] = Slash

function BisPlanner_Toggle(_, mouseButton)
    if not (ns.UI and ns.db) then return end
    if mouseButton == "RightButton" and ns.Kit then ns.Kit.Toggle() else ns.UI.Toggle() end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.eventFrame = frame
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
frame:SetScript("OnEvent", function(_, event, a, b)
    if event == "ADDON_LOADED" then
        if a ~= ADDON then return end
        InitDB()
        if ns.Options then ns.Options.Init() end
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then InitDB() end
        HookTooltips()
        -- the name and class are known now: bring the saved plan up to date
        After(2, function()
            local profile = ns.Profile()
            if HasAny(profile.weights) or HasAny(profile.goals) then ns.Plan() end
        end)
    elseif event == "PLAYER_LEVEL_UP" then
        if not ns.db or ns.char.level then return end
        After(1, function()
            local old = ns.char.plan
            local plan = ns.Plan()
            if not (plan and old) then return end
            local was, changed = {}, 0
            for _, row in ipairs(old.rows) do was[row.slot] = row.id end
            for _, row in ipairs(plan.rows) do
                if was[row.slot] ~= row.id then changed = changed + 1 end
            end
            if changed > 0 then
                ns.Print(("Your plan has %d new %s at this level. /bisplan shows it."):format(
                    changed, changed == 1 and "item" or "items"))
            end
            if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
        end)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if fetch and ns.Clean(b) == true then fetch.found = fetch.found + 1 end
    end
end)
