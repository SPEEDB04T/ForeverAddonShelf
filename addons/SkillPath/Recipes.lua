-- SkillPath: what the game says about the open profession. Every recipe, its colour, its grey
-- level and its reagents come from the trade skill API; the yellow level (which the API doesn't
-- give) comes from the client's own recipe table in Data.lua, and each row is checked against
-- the game's grey level and today's colour before the guide relies on it.
-- A path for someone else (any profession, any skill range) is planned from Data.lua alone.
local _, ns = ...
local R = {}
ns.Recipes = R

local Call, Num, Str, Field = ns.Call, ns.Num, ns.Str, ns.Field

-- Enum.TradeskillRelativeDifficulty
local OPTIMAL, MEDIUM, EASY, TRIVIAL = 0, 1, 2, 3
R.OPTIMAL, R.MEDIUM, R.EASY, R.TRIVIAL = OPTIMAL, MEDIUM, EASY, TRIVIAL
local function EnumValue(group, key, fallback)
    local e = Enum and Enum[group]
    local v = type(e) == "table" and e[key]
    return type(v) == "number" and v or fallback
end

----------------------------------------------------------------------
-- Data.lua rows, parsed one skill line at a time when first needed
----------------------------------------------------------------------
local parsed = {}

-- A tool a recipe needs in the bags and doesn't use up: { key, items = every item that serves,
-- the plainest first }. One table per tool, shared by every recipe that needs it.
local needs = {}
local function Need(key)
    local need = needs[key]
    if need then return need end
    local id = tonumber(key:sub(2))
    local items = key:sub(1, 1) == "k" and ns.Data and ns.Data.TOOLS and ns.Data.TOOLS[id] or { id }
    need = { key = key, items = items }
    needs[key] = need
    return need
end

-- The skill line a profession ID belongs to (a profession tier maps to its line).
function R.Line(id)
    id = Num(id)
    if not id or not ns.Data then return nil end
    if ns.Data.LINES[id] then return id end
    local parent = ns.Data.PARENT[id]
    if parent and ns.Data.LINES[parent] then return parent end
end

function R.Rows(line)
    if parsed[line] then return parsed[line] end
    local text = ns.Data and ns.Data.LINES[line]
    local rows = {}
    if type(text) == "string" then
        for part in text:gmatch("[^;]+") do
            local main, rest = part:match("^([%d:]+)(.*)$")
            local spell, yellow, grey, ups = (main or ""):match("^(%d+):(%d+):(%d+):?(%d*)$")
            if spell then
                local row = { y = tonumber(yellow), g = tonumber(grey), ups = tonumber(ups) or 1 }
                if rest:sub(1, 1) == "@" then row.auto = true end     -- comes with the profession
                local item, rank = rest:match("|(%d+):(%d+)")
                if item then row.item, row.rank = tonumber(item), tonumber(rank) end
                local out, qty = rest:match(">(%d+)%*(%d+)")
                if out then row.out, row.outQty = tonumber(out), tonumber(qty) end
                local ability = rest:match("!(%d+)")
                if ability then row.ability = tonumber(ability) end
                for one, id in rest:gmatch("%^(#?)(%d+)") do
                    row.tools = row.tools or {}
                    row.tools[#row.tools + 1] = Need((one == "#" and "i" or "k") .. id)
                end
                local reagents = rest:match("=([%d%*,]+)")
                if reagents then
                    row.slots = {}
                    for id, n in reagents:gmatch("(%d+)%*(%d+)") do
                        row.slots[#row.slots + 1] = { qty = tonumber(n), items = { tonumber(id) } }
                    end
                end
                rows[tonumber(spell)] = row
            end
        end
    end
    parsed[line] = rows
    return rows
end

-- The tools a recipe needs in the bags (nil: none, or a recipe Data.lua doesn't have).
function R.Tools(line, id)
    local row = R.Rows(line)[id]
    return row and row.tools
end

-- Data.lua's trainer table for a line: [recipe] = { at = skill, fee = copper (nil: not known) }.
-- nil when the line has no table.
local trained = {}
function R.Train(line)
    if trained[line] == nil then
        local text = ns.Data and ns.Data.TRAIN and ns.Data.TRAIN[line]
        local rows = false
        if type(text) == "string" then
            rows = {}
            for spell, skill, fee in text:gmatch("(%d+):(%d+):(%d*)") do
                rows[tonumber(spell)] = { at = tonumber(skill), fee = tonumber(fee) }
            end
        end
        trained[line] = rows
    end
    return trained[line] or nil
end

-- The rank that raises a line's cap to `cap`: { cap, skill (what it asks for), fee (nil: not
-- known), level, how = "trainer", "book" (with item) or "quest" }. nil when the table has none.
function R.Rank(line, cap)
    local text = ns.Data and ns.Data.RANKS and ns.Data.RANKS[line]
    if type(text) ~= "string" then return nil end
    for c, skill, fee, level, how in text:gmatch("(%d+):(%d+):(%d*):(%d+):(%w+)") do
        if tonumber(c) == cap then
            local info = { cap = cap, skill = tonumber(skill), fee = tonumber(fee), level = tonumber(level),
                how = how == "q" and "quest" or "trainer" }
            local item = how:match("^b(%d+)$")
            if item then info.how, info.item = "book", tonumber(item) end
            return info
        end
    end
end

-- The highest grey level of any recipe in the line: no skill past it can be reached by crafting.
function R.Ceiling(line)
    local top = 0
    for _, row in pairs(R.Rows(line)) do if row.g > top then top = row.g end end
    return top
end

----------------------------------------------------------------------
-- Colours: what the recipe's levels say about a skill, and whether the
-- game agrees
----------------------------------------------------------------------
-- 0 orange, 3 grey, "mid" yellow or green (the API's names: Optimal, Trivial, Medium/Easy).
function R.ColourAt(y, g, skill)
    if skill >= g then return TRIVIAL end
    if skill < y then return OPTIMAL end
    return "mid"
end

local function Agrees(expected, colour)
    if expected == "mid" then return colour == MEDIUM or colour == EASY end
    return expected == colour
end

-- The skill the game colours recipes by is the skill shown, or the skill with its bonus
-- (racial, items). Picks the one the game's own colours agree with, then marks every
-- recipe whose row doesn't fit.
function R.Check(recipes, skill, mod)
    local offsets = { 0 }
    if mod and mod ~= 0 then offsets[2] = mod end
    local best, bestHits = 0, -1
    for _, offset in ipairs(offsets) do
        local hits = 0
        for _, r in ipairs(recipes) do
            if r.known and r.y and r.colour and Agrees(R.ColourAt(r.y, r.g, skill + offset), r.colour) then
                hits = hits + 1
            end
        end
        if hits > bestHits then best, bestHits = offset, hits end
    end
    local good, bad = 0, 0
    for _, r in ipairs(recipes) do
        r.trust, r.why = true, nil
        if not r.y then
            r.trust, r.why = false, "not in the recipe table"
        elseif r.apiGrey and r.apiGrey ~= r.g then
            r.trust, r.why = false, ("the game says grey at %d, the table %d"):format(r.apiGrey, r.g)
        elseif r.known and r.colour and not Agrees(R.ColourAt(r.y, r.g, skill + best), r.colour) then
            r.trust, r.why = false, "its colour in the game doesn't match its levels"
        elseif r.known and r.canSkillUp == false and R.ColourAt(r.y, r.g, skill + best) ~= TRIVIAL then
            r.trust, r.why = false, "the game says it gives no skill now"
        end
        if r.known then
            if r.trust then good = good + 1 else bad = bad + 1 end
        end
    end
    return best, good, bad
end

----------------------------------------------------------------------
-- Reading the open profession
----------------------------------------------------------------------
function R.WindowOpen()
    return ns.tradeOpen == true
end

local function ReadReagents(r, schematic)
    r.slots = {}
    local slots = Field(schematic, "reagentSlotSchematics")
    if type(slots) ~= "table" then
        r.unreadable = true          -- no reagents read is not "no reagents"
        return
    end
    local BASIC = EnumValue("CraftingReagentType", "Basic", 1)
    local CURRENCY = EnumValue("TradeskillSlotDataType", "Currency", 3)
    for _, slot in ipairs(slots) do
        local required = Field(slot, "required")
        local kind = Num(Field(slot, "reagentType"))
        local dataType = Num(Field(slot, "dataSlotType"))
        local qty = Num(Field(slot, "quantityRequired"))
        if required ~= false and (kind == nil or kind == BASIC) and not (qty and qty > 0) then
            r.unreadable = true      -- a required slot with no count
        elseif required ~= false and (kind == nil or kind == BASIC) then
            if dataType == CURRENCY then
                r.currency = true
            else
                local items = {}
                local reagents = Field(slot, "reagents")
                if type(reagents) == "table" then
                    for _, reagent in ipairs(reagents) do
                        local id = Num(Field(reagent, "itemID"))
                        if id then items[#items + 1] = id end
                    end
                end
                if #items > 0 then
                    r.slots[#r.slots + 1] = { qty = qty, items = items }
                else
                    r.unreadable = true      -- a required slot the game didn't name an item for
                end
            end
        end
    end
    local out = Num(Field(schematic, "outputItemID"))
    if out then
        local low = Num(Field(schematic, "quantityMin")) or 1
        local high = Num(Field(schematic, "quantityMax")) or low
        r.out, r.outQty = out, (math.max(low, 0) + math.max(high, low)) / 2
    end
end

local function ReadRecipe(T, id, rows)
    local info = Call(T.GetRecipeInfo, id)
    if type(info) ~= "table" then return nil end
    if Field(info, "isDummyRecipe") or Field(info, "isRecraft") or Field(info, "isSalvageRecipe")
        or Field(info, "isGatheringRecipe") or Field(info, "disabled") then
        return nil
    end
    local row = rows[id]
    local r = {
        id = id,
        name = Str(Field(info, "name")) or ("recipe " .. id),
        icon = Field(info, "icon"),
        known = Field(info, "learned") == true,
        colour = Num(Field(info, "relativeDifficulty")),
        apiGrey = Num(Field(info, "maxTrivialLevel")),
        canSkillUp = Field(info, "canSkillUp"),
        ups = row and row.ups or 1,
    }
    if r.apiGrey == 0 then r.apiGrey = nil end
    if row then r.y, r.g, r.item, r.rank = row.y, row.g, row.item, row.rank end
    -- The points an orange craft gives: the game says it for an orange recipe.
    local apiUps = Num(Field(info, "numSkillUps"))
    if r.colour == OPTIMAL and apiUps and apiUps > 0 then r.ups = apiUps end
    ReadReagents(r, Call(T.GetRecipeSchematic, id, false))
    if not r.known then r.source = Str(Call(T.GetRecipeSourceText, id)) end
    if r.source then r.source = r.source:gsub("|n", " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
    return r
end

local function ProfessionInfo(T)
    for _, fn in ipairs({ T.GetChildProfessionInfo, T.GetBaseProfessionInfo }) do
        local info = Call(fn)
        if type(info) == "table" then
            local line = R.Line(Field(info, "professionID")) or R.Line(Field(info, "parentProfessionID"))
            local skill = Num(Field(info, "skillLevel"))
            if line and skill then return info, line, skill end
        end
    end
end

-- Saves the open profession for the guide. False when there is nothing (yet) to read: another
-- player's or a guild's list, an NPC crafting order, a list still loading, a profession
-- Data.lua doesn't cover.
function R.Snapshot()
    local T = C_TradeSkillUI
    if type(T) ~= "table" then return false end
    if Call(T.IsTradeSkillLinked) or Call(T.IsTradeSkillGuild) or Call(T.IsNPCCrafting) then return false end
    if T.IsTradeSkillReady and not Call(T.IsTradeSkillReady) then return false end
    if Call(T.IsDataSourceChanging) then return false end
    local info, line, skill = ProfessionInfo(T)
    if not info then return false end
    local ids = Call(T.GetAllRecipeIDs)
    if type(ids) ~= "table" or #ids == 0 then ids = Call(T.GetFilteredRecipeIDs) end
    if type(ids) ~= "table" then return false end
    local rows = R.Rows(line)
    local recipes, seen = {}, {}
    for _, raw in ipairs(ids) do
        local id = Num(raw)
        if id and not seen[id] then
            seen[id] = true
            local r = ReadRecipe(T, id, rows)
            if r then recipes[#recipes + 1] = r end
        end
    end
    table.sort(recipes, function(a, b) return a.id < b.id end)
    local mod = Num(Field(info, "skillModifier")) or 0
    local offset, good, bad = R.Check(recipes, skill, mod)
    local char = ns.Char()
    local build = select(2, ns.Call(GetBuildInfo))
    char.profs[line] = {
        line = line,
        name = Str(Field(info, "parentProfessionName")) or Str(Field(info, "professionName"))
            or (ns.Data.NAMES[line] or "Profession"),
        skill = skill,
        seenSkill = skill,       -- the skill the colours were read at
        max = Num(Field(info, "maxSkillLevel")) or skill,
        mod = mod,
        offset = offset,
        good = good,
        bad = bad,
        t = ns.Clock(),
        build = build and tostring(build) or nil,
        recipes = recipes,
    }
    char.last = line
    return true
end

----------------------------------------------------------------------
-- Recipes for someone else's path: every recipe of a skill line, from Data.lua
----------------------------------------------------------------------
function R.SpellName(id)
    local name = Str(Call(C_Spell and C_Spell.GetSpellName, id))
    if name then return name end
    return Str(Call(GetSpellInfo, id))
end

local function SpellIcon(id)
    local icon = Call(C_Spell and C_Spell.GetSpellTexture, id)
    if icon then return icon end
    return Call(GetSpellTexture, id)
end

-- The skill line a typed profession name means ("eng" is Engineering). nil when none or several fit.
function R.LineByName(text)
    text = Str(text) and text:lower() or nil
    if not (text and ns.Data) then return nil end
    local found
    for line, name in pairs(ns.Data.NAMES) do
        local low = name:lower()
        if low == text then return line, name end
        if low:sub(1, #text) == text then
            if found then return nil end
            found = line
        end
    end
    if found then return found, ns.Data.NAMES[found] end
end

local ordered = {}
function R.Forget() ordered, trained = {}, {} end

-- Only what comes with the profession is known: the path says what else to learn and when. A
-- recipe your own professions window showed keeps the name and icon the game gave it there.
function R.ForOrder(line)
    if ordered[line] then return ordered[line] end
    local mine = {}
    local char = ns.Char()
    local prof = char and char.profs[line]
    for _, r in ipairs(prof and prof.recipes or {}) do mine[r.id] = r end
    local list, named = {}, true
    for id, row in pairs(R.Rows(line)) do
        if row.slots and #row.slots > 0 then
            local own = mine[id]
            local name = own and own.name or R.SpellName(id)
            if not name then named = false end
            list[#list + 1] = {
                id = id, name = name or ("recipe " .. id),
                icon = own and own.icon or SpellIcon(id) or "Interface\\Icons\\INV_Misc_QuestionMark",
                known = row.auto or false, trust = not (own and own.trust == false), ups = row.ups or 1,
                y = row.y, g = row.g,
                item = row.item, rank = row.rank, slots = row.slots, out = row.out, outQty = row.outQty,
            }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    -- Kept only once the game has given every name.
    if named then ordered[line] = list end
    return list
end

----------------------------------------------------------------------
-- The trainer's window: which recipes it teaches, at what skill, for how much
----------------------------------------------------------------------
-- db.trainer[line] = { t, top (the highest skill any listed recipe asks for), list = { [recipe] =
-- { rank, cost, blocked } } }. The game says nothing about a recipe you haven't learned except
-- here, so this is what turns "a trainer should teach it" into a skill and a fee.
local function ReadServices()
    local db, char = ns.db, ns.Char()
    local n = Num(Call(GetNumTrainerServices)) or 0
    if n <= 0 then return 0 end
    -- Recipe names by profession (a trainer service has a name, no recipe ID): the saved
    -- professions' own lists, and for any other profession the names of Data.lua's recipes.
    local byName = {}
    for line, prof in pairs(char.profs) do
        local names = {}
        for _, recipe in ipairs(prof.recipes or {}) do
            if recipe.name then
                names[recipe.name] = names[recipe.name] or {}
                table.insert(names[recipe.name], recipe.id)
            end
        end
        byName[prof.name or ""] = { line = line, names = names }
    end
    setmetatable(byName, { __index = function(t, skill)
        local found = false
        for line, name in pairs(ns.Data and ns.Data.NAMES or {}) do
            if name == skill then
                local names = {}
                for id in pairs(R.Rows(line)) do
                    local spell = R.SpellName(id)
                    if spell then
                        names[spell] = names[spell] or {}
                        table.insert(names[spell], id)
                    end
                end
                found = { line = line, names = names }
            end
        end
        rawset(t, skill, found)
        return found
    end })
    local level = Num(Call(UnitLevel, "player")) or 0
    local read, lines = 0, {}
    for i = 1, n do
        local name, kind, _, reqLevel = Call(GetTrainerServiceInfo, i)
        name = Str(name)
        local skill, rank = Call(GetTrainerServiceSkillReq, i)
        skill = Str(skill) or Str(Call(GetTrainerServiceSkillLine, i))
        local prof = skill and byName[skill]
        local ids = name and prof and prof.names[name]
        if ids and kind ~= "header" then
            local entry = { rank = Num(rank) or 0, cost = Num(Call(GetTrainerServiceCost, i)) }
            -- What you have learned already may show no fee: unknown, not free.
            if kind == "used" and entry.cost == 0 then entry.cost = nil end
            reqLevel = Num(reqLevel)
            if reqLevel and reqLevel > level then entry.blocked = ("needs level %d"):format(reqLevel) end
            for j = 1, Num(Call(GetTrainerServiceNumAbilityReq, i)) or 0 do
                local ability, has = Call(GetTrainerServiceAbilityReq, i, j)
                if Str(ability) and has == false then entry.blocked = "needs " .. ability end
            end
            db.trainer = type(db.trainer) == "table" and db.trainer or {}
            local seen = db.trainer[prof.line]
            if type(seen) ~= "table" or type(seen.list) ~= "table" then
                seen = { top = 0, list = {} }
                db.trainer[prof.line] = seen
            end
            seen.t = ns.Clock()
            if entry.rank > (Num(seen.top) or 0) then seen.top = entry.rank end
            for _, id in ipairs(ids) do
                local old = seen.list[id]
                if not entry.cost and type(old) == "table" then entry.cost = Num(old.cost) end
                seen.list[id] = entry
            end
            read = read + 1
            lines[prof.line] = true
        end
    end
    return read, lines
end

-- The trainer's window leaves out what its filter hides (by default the recipes you know), and a
-- path for someone else needs those too: every kind is switched on for the read and put back
-- right after, before the window draws again.
local FILTERS = { "available", "unavailable", "used" }
function R.ReadTrainer()
    if not (ns.db and ns.Char() and GetNumTrainerServices and GetTrainerServiceInfo) then return 0 end
    if IsTradeskillTrainer and Call(IsTradeskillTrainer) == false then return 0 end
    local off = {}
    if type(GetTrainerServiceTypeFilter) == "function" and type(SetTrainerServiceTypeFilter) == "function" then
        -- Switching the filter makes the game say the list changed: that isn't a reason to read it again.
        R.trainerQuiet = math.huge
        for _, kind in ipairs(FILTERS) do
            local ok, on = pcall(GetTrainerServiceTypeFilter, kind)
            if ok and not ns.Val(on) and pcall(SetTrainerServiceTypeFilter, kind, true) then off[#off + 1] = kind end
        end
    end
    local ok, read, lines = pcall(ReadServices)
    for _, kind in ipairs(off) do pcall(SetTrainerServiceTypeFilter, kind, false) end
    R.trainerQuiet = #off > 0 and ns.Now() + 0.5 or 0
    if not ok then return 0 end
    return read or 0, lines
end

-- How a recipe you haven't learned can be learned: { how = "trainer", at, fee, seen, table } or
-- { how = "item", item, at }. nil (and why) when the path can't count on it.
--   * On a trainer's list that was read: at the skill and fee it showed (seen).
--   * In Data.lua's trainer table: at its skill and fee (table). The fee is before any reputation
--     discount, so the real one is never higher. A list that was read past that skill and doesn't
--     have the recipe wins: that trainer doesn't teach it.
--   * Taught by a recipe item (Data.lua): from the skill the item asks for.
--   * None of those: no trainer teaches it (a quest or a drop does), so the path leaves it out.
--     Only a profession with no trainer table still takes such a recipe to be a trainer's,
--     learned at its yellow skill.
--   * What it makes only a specialisation can use (Gnomish or Goblin Engineering): only that
--     specialisation is taught it, so it is left out unless you have it.
-- other: the path is for someone else. Their level and specialisation aren't known, and a recipe
-- you know yourself isn't on your trainer's list any more.
function R.Learn(line, r, other)
    local row = R.Rows(line)[r.id]
    local ability = row and row.ability
    if ability then
        local has = not other and (Call(IsPlayerSpell, ability) == true or Call(IsSpellKnown, ability) == true)
        if not has then return nil, "only " .. (R.SpellName(ability) or "a specialisation") .. " learns it" end
    end
    local seen = ns.db and type(ns.db.trainer) == "table" and ns.db.trainer[line]
    local entry = type(seen) == "table" and type(seen.list) == "table" and seen.list[r.id]
    local rows = R.Train(line)
    local known = rows and rows[r.id]
    if type(entry) == "table" then
        if entry.blocked and not other then return nil, "the trainer " .. entry.blocked end
        local fee = Num(entry.cost)
        -- The list shows no fee for what you have learned already: the table's then.
        if not fee and known and known.fee then
            return { how = "trainer", at = Num(entry.rank) or 0, fee = known.fee, seen = true, table = true }
        end
        return { how = "trainer", at = Num(entry.rank) or 0, fee = fee, seen = true }
    end
    -- A list that was read past this skill and doesn't have the recipe.
    local function Unlisted(at)
        if not (type(seen) == "table" and at <= (Num(seen.top) or 0)) then return false end
        if other then
            local char = ns.Char()
            local prof = char and char.profs[line]
            for _, own in ipairs(prof and prof.recipes or {}) do
                if own.id == r.id and own.known then return false end
            end
        end
        return true
    end
    if known and not Unlisted(known.at) then
        return { how = "trainer", at = known.at, fee = known.fee, seen = false, table = true }
    end
    if r.item then return { how = "item", item = r.item, at = r.rank or 0 } end
    if not r.y then return nil, "not in the recipe table" end
    if known then return nil, "not on the trainer's list" end
    if rows then return nil, "no trainer teaches it" end
    if Unlisted(r.y) then return nil, "not on the trainer's list" end
    return { how = "trainer", at = r.y, seen = false }
end

-- The trainer table against what trainers showed: how many rows agree, and one line for each
-- that doesn't (/skillpath debug). Fees can differ by a reputation discount alone.
function R.TrainCheck()
    local same, lines = 0, {}
    for line, seen in pairs(ns.db and type(ns.db.trainer) == "table" and ns.db.trainer or {}) do
        local rows = R.Train(line) or {}
        local list = type(seen) == "table" and type(seen.list) == "table" and seen.list or {}
        for id, entry in pairs(list) do
            local row = rows[id]
            local name = R.SpellName(id) or tostring(id)
            if type(entry) ~= "table" then
            elseif not row then
                lines[#lines + 1] = ("%s (%d): a trainer teaches it at %s, the table doesn't have it"):format(
                    name, id, tostring(entry.rank))
            elseif Num(entry.rank) ~= row.at or (Num(entry.cost) and row.fee and Num(entry.cost) ~= row.fee) then
                lines[#lines + 1] = ("%s (%d): trainer %s for %s, table %d for %s"):format(name, id,
                    tostring(entry.rank), tostring(entry.cost), row.at, tostring(row.fee))
            else
                same = same + 1
            end
        end
        for id, row in pairs(rows) do
            if not list[id] and row.at <= (Num(type(seen) == "table" and seen.top) or 0) then
                lines[#lines + 1] = ("%s (%d): the table has it at %d, the trainer's list read doesn't"):format(
                    R.SpellName(id) or tostring(id), id, row.at)
            end
        end
    end
    table.sort(lines)
    return same, lines
end

-- A recipe learned with the professions window closed (at the trainer, from a recipe item).
function R.MarkLearned(id)
    local char = ns.Char()
    local found = false
    for _, prof in pairs(char and char.profs or {}) do
        for _, recipe in ipairs(prof.recipes or {}) do
            if recipe.id == id then
                recipe.known, found = true, true
            end
        end
    end
    return found
end

-- The skill of every profession, from the spellbook's list (works with the window closed).
-- True when a saved profession's skill or cap changed.
function R.UpdateSkills()
    local char = ns.Char()
    if not (char and GetProfessions and GetProfessionInfo) then return false end
    local changed = false
    local list = ns.CallAll(GetProfessions)
    for i = 1, 6 do
        local index = list[i]
        if index then
            local p = ns.CallAll(GetProfessionInfo, index)
            local rank, maxRank, line, mod = Num(p[3]), Num(p[4]), R.Line(p[7]), Num(p[8])
            local prof = line and char.profs[line]
            if prof and rank then
                if prof.skill ~= rank or (maxRank and prof.max ~= maxRank) then changed = true end
                prof.skill = rank
                if maxRank and maxRank > 0 then prof.max = maxRank end
                if mod then prof.mod = mod end
            end
        end
    end
    return changed
end
