-- SkillPath: what the game says about the open profession. Every recipe, its colour, its grey
-- level and its reagents come from the trade skill API; the yellow level (which the API doesn't
-- give) comes from the client's own recipe table in Data.lua, and each row is checked against
-- the game's grey level and today's colour before the guide relies on it.
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
            local main, teach = part:match("^([^|]+)|?(.*)$")
            local spell, yellow, grey, ups = main:match("^(%d+):(%d+):(%d+):?(%d*)$")
            if spell then
                local row = { y = tonumber(yellow), g = tonumber(grey), ups = tonumber(ups) or 1 }
                local item, rank = (teach or ""):match("^(%d+):(%d+)$")
                if item then row.item, row.rank = tonumber(item), tonumber(rank) end
                rows[tonumber(spell)] = row
            end
        end
    end
    parsed[line] = rows
    return rows
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
    if type(slots) ~= "table" then return end
    local BASIC = EnumValue("CraftingReagentType", "Basic", 1)
    local CURRENCY = EnumValue("TradeskillSlotDataType", "Currency", 3)
    for _, slot in ipairs(slots) do
        local required = Field(slot, "required")
        local kind = Num(Field(slot, "reagentType"))
        local dataType = Num(Field(slot, "dataSlotType"))
        local qty = Num(Field(slot, "quantityRequired"))
        if required ~= false and (kind == nil or kind == BASIC) and qty and qty > 0 then
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
