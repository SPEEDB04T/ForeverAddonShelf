-- Destroy Advisor: the rules. Walks the bags and says, for each item, whether it is safe to
-- destroy (or sell) and why. It errs on the side of keeping: an item is only suggested when
-- the addon can name a reason the player can check, and nothing a quest may still need is.
local _, ns = ...
local Judge = {}
ns.Judge = Judge

local Val, Num, Str, Field, Call, CallAll = ns.Val, ns.Num, ns.Str, ns.Field, ns.Call, ns.CallAll

local HEARTHSTONE = 6948
local QUEST_CLASS, ARMOR_CLASS, WEAPON_CLASS, PROJECTILE_CLASS, RECIPE_CLASS = 12, 4, 2, 6, 9
local BIND_QUEST = 4

-- What each class can ever learn to wear and wield (every expansion's list joined, so a class is
-- never told it can't use something it could train later). Item subclass ids (Enum.ItemArmorSubclass,
-- Enum.ItemWeaponSubclass). Subclasses missing here (cloth, miscellaneous, fishing poles ...) are
-- never judged.
local ARMOR = {
    [2] = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, SHAMAN = true, DRUID = true },  -- leather
    [3] = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true },                             -- mail
    [4] = { WARRIOR = true, PALADIN = true },                                                           -- plate
    [6] = { WARRIOR = true, PALADIN = true, SHAMAN = true },                                            -- shields
    [7] = { PALADIN = true },                                                                           -- librams
    [8] = { DRUID = true },                                                                             -- idols
    [9] = { SHAMAN = true },                                                                            -- totems
}
local WEAPON = {
    [0]  = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, SHAMAN = true },       -- one-handed axes
    [1]  = { WARRIOR = true, PALADIN = true, HUNTER = true, SHAMAN = true },                     -- two-handed axes
    [2]  = { WARRIOR = true, HUNTER = true, ROGUE = true },                                      -- bows
    [3]  = { WARRIOR = true, HUNTER = true, ROGUE = true },                                      -- guns
    [4]  = { WARRIOR = true, PALADIN = true, ROGUE = true, PRIEST = true, SHAMAN = true, DRUID = true },  -- one-handed maces
    [5]  = { WARRIOR = true, PALADIN = true, SHAMAN = true, DRUID = true },                      -- two-handed maces
    [6]  = { WARRIOR = true, PALADIN = true, HUNTER = true, DRUID = true },                      -- polearms
    [7]  = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, MAGE = true, WARLOCK = true },  -- one-handed swords
    [8]  = { WARRIOR = true, PALADIN = true, HUNTER = true },                                    -- two-handed swords
    [10] = { WARRIOR = true, HUNTER = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true },  -- staves
    [13] = { WARRIOR = true, HUNTER = true, ROGUE = true, SHAMAN = true, DRUID = true },          -- fist weapons
    [15] = { WARRIOR = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true },  -- daggers
    [16] = { WARRIOR = true, HUNTER = true, ROGUE = true },                                      -- thrown
    [18] = { WARRIOR = true, HUNTER = true, ROGUE = true },                                      -- crossbows
    [19] = { PRIEST = true, MAGE = true, WARLOCK = true },                                       -- wands
}
local SHOOTS_AMMO = { WARRIOR = true, HUNTER = true, ROGUE = true }
local NO_MANA = { WARRIOR = true, ROGUE = true }
-- Spells whose names mark a drink and a mana potion: Drink (Refreshing Spring Water) and
-- Restore Mana (Minor Mana Potion). Compared by name, so every rank and every language matches.
local DRINK_SPELL, MANA_POTION_SPELL = 430, 437

local CLASS_NAMES = { WARRIOR = "warriors", PALADIN = "paladins", HUNTER = "hunters", ROGUE = "rogues",
    PRIEST = "priests", SHAMAN = "shamans", MAGE = "mages", WARLOCK = "warlocks", DRUID = "druids" }

----------------------------------------------------------------------
-- The bags
----------------------------------------------------------------------
function Judge.Bags()
    local last = Num(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or Num(NUM_BAG_SLOTS) or 4
    local bags = {}
    for bag = 0, last do bags[#bags + 1] = bag end
    return bags
end

-- Free and total slots of the ordinary bags (a full soul or ammo pouch doesn't stop looting).
function Judge.FreeSlots()
    local free, total = 0, 0
    if not (C_Container and C_Container.GetContainerNumSlots) then return free, total end
    for _, bag in ipairs(Judge.Bags()) do
        local slots = Num(Call(C_Container.GetContainerNumSlots, bag)) or 0
        local n, family = nil, nil
        if C_Container.GetContainerNumFreeSlots then n, family = Call(C_Container.GetContainerNumFreeSlots, bag) end
        if (Num(family) or 0) == 0 then
            total = total + slots
            free = free + (Num(n) or 0)
        end
    end
    return free, total
end

function Judge.LinkAt(bag, slot)
    if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
    local info = Call(C_Container.GetContainerItemInfo, bag, slot)
    return Str(Field(info, "hyperlink"))
end

local function ItemInfo(link)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local r = CallAll(fn, link)
    return {
        name = Str(r[1]), quality = Num(r[3]), minLevel = Num(r[5]), itemType = Str(r[6]), subType = Str(r[7]),
        equipLoc = Str(r[9]), sellPrice = Num(r[11]), classID = Num(r[12]), subclassID = Num(r[13]),
        bindType = Num(r[14]),
    }
end

local function Instant(itemID)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local r = CallAll(fn, itemID)
    return { subType = Str(r[3]), equipLoc = Str(r[4]), classID = Num(r[6]), subclassID = Num(r[7]) }
end

-- The item's tooltip lines (C_TooltipInfo), each { left, right, leftRed, rightRed }.
local function IsRed(color)
    if type(color) ~= "table" then return false end
    local r, g, b = Num(color.r), Num(color.g), Num(color.b)
    return r ~= nil and g ~= nil and b ~= nil and r > 0.95 and g < 0.2 and b < 0.2
end

function Judge.TooltipLines(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return nil end
    local data = Call(C_TooltipInfo.GetBagItem, bag, slot)
    local lines = Field(data, "lines")
    if type(lines) ~= "table" then return nil end
    local out = {}
    for _, line in ipairs(lines) do
        if type(line) == "table" then
            out[#out + 1] = {
                left = Str(Field(line, "leftText")), right = Str(Field(line, "rightText")),
                leftRed = IsRed(Field(line, "leftColor")), rightRed = IsRed(Field(line, "rightColor")),
            }
        end
    end
    return out
end

-- One bag slot, read once. nil for an empty slot; pending = true while the game still loads its data.
function Judge.Read(bag, slot)
    if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
    local info = Call(C_Container.GetContainerItemInfo, bag, slot)
    if type(info) ~= "table" then return nil end
    local itemID, link = Num(Field(info, "itemID")), Str(Field(info, "hyperlink"))
    if not (itemID and link) then return nil end
    local item = {
        bag = bag, slot = slot, itemID = itemID, link = link,
        name = Str(Field(info, "itemName")), quality = Num(Field(info, "quality")),
        count = Num(Field(info, "stackCount")) or 1, icon = Val(Field(info, "iconFileID")),
        bound = Field(info, "isBound") == true, noValue = Field(info, "hasNoValue") == true,
        hasLoot = Field(info, "hasLoot") == true, locked = Field(info, "isLocked") == true,
    }
    local full = ItemInfo(link)
    local instant = Instant(itemID)
    item.name = item.name or full.name
    item.quality = item.quality or full.quality
    item.classID = full.classID or instant.classID
    item.subclassID = full.subclassID or instant.subclassID
    item.subType = full.subType or instant.subType
    item.equipLoc = full.equipLoc or instant.equipLoc
    item.bindType = full.bindType
    item.sellPrice = full.sellPrice
    if not (full.name and item.name and item.classID and item.quality) then
        item.pending = true
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        return item
    end
    if C_Container.GetContainerItemQuestInfo then
        local quest = Call(C_Container.GetContainerItemQuestInfo, bag, slot)
        item.isQuestItem = Field(quest, "isQuestItem") == true
        item.startsQuest = Num(Field(quest, "questID"))
        item.questActive = Field(quest, "isActive") == true
    end
    item.questItem = item.isQuestItem or item.classID == QUEST_CLASS or item.bindType == BIND_QUEST
    local each = (not item.noValue and item.sellPrice) or 0
    item.value = each * item.count
    return item
end

----------------------------------------------------------------------
-- Questie (optional): which quests an item belongs to, and who may take them.
-- QuestieDB's own library first, then Questie's module of the same data.
----------------------------------------------------------------------
function Judge.Questie()
    local lib = rawget(_G, "LibQuestieDB")
    if type(lib) == "table" and type(lib.Item) == "table" and type(lib.Quest) == "table"
        and type(lib.Item.Get) == "function" and type(lib.Quest.Get) == "function" then
        return { item = lib.Item.Get, quest = lib.Quest.Get }
    end
    if type(QuestieLoader) == "table" and type(QuestieLoader.ImportModule) == "function" then
        local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
        if ok and type(db) == "table" and type(db.QueryItemSingle) == "function" and type(db.QueryQuestSingle) == "function" then
            return { item = db.QueryItemSingle, quest = db.QueryQuestSingle }
        end
    end
    return nil
end

local function QList(value)
    if type(value) == "number" then return { value } end
    if type(value) ~= "table" then return {} end
    local out = {}
    for _, id in ipairs(value) do
        id = Num(id)
        if id and id > 0 then out[#out + 1] = id end
    end
    return out
end

-- Questie's race and class masks: bit (id - 1) set for each race or class that may take it; 0 = anyone.
-- Arithmetic, not bit.band: the masks go past 32 bits.
local function HasBit(mask, id)
    if not (mask and id) or mask == 0 then return true end
    local bit = 2 ^ (id - 1)
    return math.floor(mask / bit) % 2 == 1
end
Judge.HasBit = HasBit

----------------------------------------------------------------------
-- Context: the quest log and the character, gathered once per scan
----------------------------------------------------------------------
function Judge.Context(db)
    local _, classFile = Call(UnitClass, "player")
    local _, _, classID = Call(UnitClass, "player")
    local _, _, raceID = Call(UnitRace, "player")
    local ctx = {
        db = db or {}, keep = (db and db.keep) or {}, class = classFile, classID = Num(classID), raceID = Num(raceID),
        log = {}, objectives = {}, questie = Judge.Questie(), done = {}, sets = {},
    }
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local n = Num(Call(C_QuestLog.GetNumQuestLogEntries)) or 0
        for i = 1, n do
            local info = Call(C_QuestLog.GetInfo, i)
            local id = Num(Field(info, "questID"))
            if id and id > 0 and not Field(info, "isHeader") then
                ctx.log[id] = Str(Field(info, "title")) or true
                local objectives = C_QuestLog.GetQuestObjectives and Call(C_QuestLog.GetQuestObjectives, id)
                if type(objectives) == "table" then
                    for _, objective in ipairs(objectives) do
                        local text = Str(Field(objective, "text"))
                        if text then ctx.objectives[#ctx.objectives + 1] = text end
                    end
                end
            end
        end
    end
    return ctx
end

local function Completed(ctx, id)
    if ctx.done[id] == nil then
        local done = false
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            done = Call(C_QuestLog.IsQuestFlaggedCompleted, id) == true
        elseif IsQuestFlaggedCompleted then
            done = Call(IsQuestFlaggedCompleted, id) == true
        end
        ctx.done[id] = done
    end
    return ctx.done[id]
end

-- "log" (in the quest log), "done" (handed in), "notyou" (other races or classes only, or a quest
-- it excludes was done), "open" (could still be taken).
function Judge.QuestState(ctx, id)
    if ctx.log[id] then return "log" end
    if C_QuestLog and C_QuestLog.IsOnQuest and Call(C_QuestLog.IsOnQuest, id) == true then return "log" end
    if Completed(ctx, id) then return "done" end
    local q = ctx.questie
    if q then
        local races = Num(Call(q.quest, id, "requiredRaces"))
        if races and not HasBit(races, ctx.raceID) then return "notyou" end
        local classes = Num(Call(q.quest, id, "requiredClasses"))
        if classes and not HasBit(classes, ctx.classID) then return "notyou" end
        for _, other in ipairs(QList(Call(q.quest, id, "exclusiveTo"))) do
            if Completed(ctx, other) then return "notyou" end
        end
    end
    return "open"
end

function Judge.QuestTitle(ctx, id)
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and Str(Call(C_QuestLog.GetTitleForQuestID, id))
    if not title and type(ctx.log[id]) == "string" then title = ctx.log[id] end
    if not title and ctx.questie then title = Str(Call(ctx.questie.quest, id, "name")) end
    return title or ("quest " .. id)
end

local function InObjectives(ctx, name)
    if not name then return false end
    for _, text in ipairs(ctx.objectives) do
        if text:find(name, 1, true) then return true end
    end
    return false
end

local function InEquipmentSet(item)
    if not (C_Container and C_Container.GetContainerItemEquipmentSetInfo) then return false end
    local inSet = Call(C_Container.GetContainerItemEquipmentSetInfo, item.bag, item.slot)
    return inSet == true
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return Str(Call(C_Spell.GetSpellName, id)) end
    if GetSpellInfo then return Str(Call(GetSpellInfo, id)) end
end

local function ItemSpellName(itemID)
    local fn = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    return Str(Call(fn, itemID))
end

local function Lines(item)
    if item.lines == nil then item.lines = Judge.TooltipLines(item.bag, item.slot) or false end
    return item.lines or nil
end

-- The "Classes: Paladin" line, when it is red (not this class).
local function ClassLine(item)
    local lines = Lines(item)
    if not lines then return nil end
    local pattern = ns.Text("ITEM_CLASSES_ALLOWED", "Classes: %s")
    local prefix = pattern:match("^(.-)%%s") or "Classes: "
    for _, line in ipairs(lines) do
        if line.left and line.leftRed and line.left:sub(1, #prefix) == prefix then
            return line.left:sub(#prefix + 1)
        end
    end
end

local function RedRight(item)
    local lines = Lines(item)
    if not lines then return false end
    for _, line in ipairs(lines) do
        if line.right and line.rightRed then return true end
    end
    return false
end

local function AlreadyKnown(item)
    local lines = Lines(item)
    if not lines then return false end
    local known = ns.Text("ITEM_SPELL_KNOWN", "Already known")
    for _, line in ipairs(lines) do
        if line.left == known then return true end
    end
    return false
end

----------------------------------------------------------------------
-- The judgement. Returns a suggestion { rule, reason, short } or nil, and a word on
-- why it is kept when the item looked like a candidate ("kept", "quest", ...).
----------------------------------------------------------------------
local function Suggest(rule, reason, short)
    return { rule = rule, reason = reason, short = short or reason }
end

local function TitleList(ctx, ids)
    local titles = {}
    for i = 1, math.min(2, #ids) do titles[#titles + 1] = Judge.QuestTitle(ctx, ids[i]) end
    local text = table.concat(titles, ", ")
    if #ids > 2 then text = text .. (" and %d more"):format(#ids - 2) end
    return text
end

function Judge.Item(item, ctx)
    if not item or item.pending then return nil, "loading" end
    local rules = ctx.db
    if ctx.keep[item.itemID] then return nil, "kept" end
    if item.itemID == HEARTHSTONE then return nil, "hearthstone" end
    if item.hasLoot then return nil, "openable" end
    if InObjectives(ctx, item.name) then return nil, "quest" end
    local q = ctx.questie
    local related = q and QList(Call(q.item, item.itemID, "relatedQuests")) or {}
    local openQuest = false
    for _, id in ipairs(related) do
        local state = Judge.QuestState(ctx, id)
        if state == "log" then return nil, "quest" end
        if state == "open" then openQuest = true end
    end
    if InEquipmentSet(item) then return nil, "set" end

    -- Items that start a quest.
    local starts = item.startsQuest or (q and Num(Call(q.item, item.itemID, "startQuest"))) or nil
    if starts and starts > 0 then
        if item.questActive then return nil, "quest" end
        local state = Judge.QuestState(ctx, starts)
        if state == "log" or state == "open" or not rules.quest then return nil, "quest" end
        local title = Judge.QuestTitle(ctx, starts)
        if state == "done" then
            return Suggest("quest", ("Starts a quest you have done: %s"):format(title), "its quest is done")
        end
        return Suggest("quest", ("Starts a quest this character can't take: %s"):format(title), "its quest isn't for you")
    end

    -- Quest items: only judged when Questie names their quests, and every one of them is done
    -- or not for this character.
    if item.questItem then
        if not rules.quest or #related == 0 or openQuest then return nil, "quest" end
        local anyDone, anyNotYou = false, false
        for _, id in ipairs(related) do
            if Judge.QuestState(ctx, id) == "done" then anyDone = true else anyNotYou = true end
        end
        local one = #related == 1
        local state = (anyDone and anyNotYou) and "done or not for you" or (anyDone and "done" or "not for you")
        local short = (one and "its quest is " or "its quests are ") .. state
        return Suggest("quest", ("%s%s: %s"):format(short:sub(1, 1):upper(), short:sub(2), TitleList(ctx, related)), short)
    end
    if openQuest then return nil, "quest" end   -- a quest that can still be taken uses it

    -- Grey items.
    if item.quality == 0 then
        if not rules.grey then return nil, "rule off" end
        if item.value > 0 then return Suggest("grey", "Poor quality: only worth its vendor price", "poor quality") end
        return Suggest("grey", "Poor quality and worth nothing", "poor quality")
    end

    local class = ctx.class
    -- Ammo this class can't shoot.
    if item.classID == PROJECTILE_CLASS and class and CLASS_NAMES[class] and not SHOOTS_AMMO[class] then
        if not rules.useless then return nil, "rule off" end
        return Suggest("useless", ("Ammunition, and %s can't shoot"):format(CLASS_NAMES[class]), "you can't shoot it")
    end
    -- Drinks and mana potions for a class without mana.
    if class and NO_MANA[class] and item.classID == 0 then
        local spell = ItemSpellName(item.itemID)
        if spell and (spell == SpellName(DRINK_SPELL) or spell == SpellName(MANA_POTION_SPELL)) then
            if not rules.useless then return nil, "rule off" end
            return Suggest("useless", ("Only restores mana, and %s have none"):format(CLASS_NAMES[class]), "you have no mana")
        end
    end

    -- Everything below is about items bound to this character: unbound ones can still be sold
    -- at the auction house or given away.
    if not item.bound then return nil, "tradeable" end

    -- Bound gear this class can never use.
    local equippable = item.equipLoc and item.equipLoc ~= "" and item.equipLoc ~= "INVTYPE_BAG"
        and item.equipLoc ~= "INVTYPE_QUIVER" and item.equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
    if equippable and (item.classID == ARMOR_CLASS or item.classID == WEAPON_CLASS) then
        local classes = ClassLine(item)
        if classes then
            if not rules.gear then return nil, "rule off" end
            return Suggest("gear", ("Bound to you, and only for %s"):format(classes), "not for your class")
        end
        local table_ = item.classID == ARMOR_CLASS and ARMOR or WEAPON
        local allowed = table_[item.subclassID or -1]
        if allowed and class and CLASS_NAMES[class] and not allowed[class] and RedRight(item) then
            if not rules.gear then return nil, "rule off" end
            local what = item.subType or (item.classID == ARMOR_CLASS and "this armor" or "this weapon")
            return Suggest("gear", ("Bound to you, and %s can never use %s"):format(CLASS_NAMES[class], what),
                "your class can't use it")
        end
        return nil, "usable"
    end

    -- Bound recipes, pets, mounts and toys that are already learned.
    if not equippable and AlreadyKnown(item) then
        if not rules.known then return nil, "rule off" end
        return Suggest("known", "Bound to you, and already learned", "already learned")
    end
    return nil, "useful"
end

----------------------------------------------------------------------
-- The whole bag scan
----------------------------------------------------------------------
local function Sort(a, b)
    if (a.value == 0) ~= (b.value == 0) then return a.value == 0 end   -- worthless first: they can only be destroyed
    if a.value ~= b.value then return a.value < b.value end
    if a.bag ~= b.bag then return a.bag < b.bag end
    return a.slot < b.slot
end

function Judge.All(db)
    local ctx = Judge.Context(db)
    local result = { list = {}, bySlot = {}, free = 0, total = 0, pending = 0 }
    if not (C_Container and C_Container.GetContainerNumSlots) then return result end
    result.free, result.total = Judge.FreeSlots()
    for _, bag in ipairs(Judge.Bags()) do
        local slots = Num(Call(C_Container.GetContainerNumSlots, bag)) or 0
        for slot = 1, slots do
            local item = Judge.Read(bag, slot)
            if item and item.pending then
                result.pending = result.pending + 1
            elseif item then
                local ok, suggestion = pcall(Judge.Item, item, ctx)
                if ok and suggestion then
                    item.rule, item.reason, item.short = suggestion.rule, suggestion.reason, suggestion.short
                    item.lines = nil
                    result.list[#result.list + 1] = item
                    result.bySlot[bag .. ":" .. slot] = item
                end
            end
        end
    end
    table.sort(result.list, Sort)
    return result
end

-- /destroy debug: one line per item, with the verdict.
function Judge.Explain(db)
    local ctx = Judge.Context(db)
    local rows = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return rows end
    for _, bag in ipairs(Judge.Bags()) do
        local slots = Num(Call(C_Container.GetContainerNumSlots, bag)) or 0
        for slot = 1, slots do
            local item = Judge.Read(bag, slot)
            if item then
                local ok, suggestion, why = pcall(Judge.Item, item, ctx)
                local verdict
                if not ok then
                    verdict = "error: " .. tostring(suggestion)
                elseif suggestion then
                    verdict = "SUGGEST (" .. suggestion.rule .. "): " .. suggestion.reason
                else
                    verdict = "keep: " .. tostring(why)
                end
                rows[#rows + 1] = ("%d:%d %s - %s"):format(bag, slot, item.link, verdict)
            end
        end
    end
    return rows
end
