-- Abandon Advisor: reads the player and the quest log into plain tables
local _, ns = ...
local Scan = {}
ns.Scan = Scan

local Call, Num, Str, Field = ns.Call, ns.Num, ns.Str, ns.Field
local min, sqrt, floor = math.min, math.sqrt, math.floor

-- Quest tag IDs (same numbers on Classic and modern clients)
local TAG_KIND = {
    [1] = "group", [21] = "class", [41] = "pvp", [62] = "raid", [81] = "dungeon", [83] = "legendary",
    [84] = "escort", [85] = "dungeon", [88] = "raid", [89] = "raid",
}

----------------------------------------------------------------------
-- Questie (optional): chain, class, item-start and drop-rate facts per quest
----------------------------------------------------------------------
function Scan.Questie()
    if type(QuestieLoader) ~= "table" or type(QuestieLoader.ImportModule) ~= "function" then return nil end
    local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
    if ok and type(db) == "table" and type(db.QueryQuestSingle) == "function" then return db end
    return nil
end

local function QuestieFacts(db, id, quest)
    if not db then return end
    local nextInChain = Num(Call(db.QueryQuestSingle, id, "nextQuestInChain"))
    if nextInChain and nextInChain ~= 0 then quest.chainNext = true end
    local classes = Num(Call(db.QueryQuestSingle, id, "requiredClasses"))
    if classes and classes ~= 0 then quest.classQuest = true end
    local startedBy = Call(db.QueryQuestSingle, id, "startedBy")
    if type(startedBy) == "table" and type(startedBy[3]) == "table" and #startedBy[3] > 0 then
        quest.itemStarted = true
    end
end

----------------------------------------------------------------------
-- Drop rates (Questie): the quest items that only come from killing things.
-- quest.drop = the item that needs the most kills: { item, rate (percent), left, kills }
----------------------------------------------------------------------
local dropCache = {}   -- [questID] = { total = item objectives in Questie, { pos, name, rate }, ... }

function Scan.HasDropRates(db)
    return db ~= nil and type(db.QueryItemSingle) == "function" and type(db.GetItemDroprate) == "function"
end

local function NotEmpty(value)
    return type(value) == "table" and next(value) ~= nil
end

-- The best drop rate among the creatures that drop the item: the one you would farm.
local function BestRate(db, itemId)
    local npcs = Call(db.QueryItemSingle, itemId, "npcDrops")
    if type(npcs) ~= "table" then return nil end
    local best
    for _, npcId in pairs(npcs) do
        local data = Call(db.GetItemDroprate, itemId, npcId)
        local rate = type(data) == "table" and Num(data[1]) or nil
        if rate and rate > 0 and (not best or rate > best) then best = rate end
    end
    return best
end

local function QuestDropItems(db, id)
    if dropCache[id] then return dropCache[id] end
    local objectives = Call(db.QueryQuestSingle, id, "objectives")
    local list = type(objectives) == "table" and objectives[3] or nil   -- [3] = items to collect
    if type(list) ~= "table" then return nil end
    local items = { total = 0 }
    for pos, entry in ipairs(list) do
        items.total = pos
        local itemId = type(entry) == "table" and Num(entry[1]) or nil
        -- An item you can also pick up from an object or buy does not hang on a drop rate.
        if itemId and not NotEmpty(Call(db.QueryItemSingle, itemId, "objectDrops"))
            and not NotEmpty(Call(db.QueryItemSingle, itemId, "vendors")) then
            local rate = BestRate(db, itemId)
            if rate then
                items[#items + 1] = { pos = pos, rate = min(rate, 100),
                    name = Str(Call(db.QueryItemSingle, itemId, "name")) }
            end
        end
    end
    if #items == 0 then return nil end   -- not cached: Questie may still be loading its drop tables
    dropCache[id] = items
    return items
end

local function ReadDrops(db, id, quest)
    if quest.ready or not Scan.HasDropRates(db) then return end
    local items = QuestDropItems(db, id)
    if not items then return end
    local itemObjectives = {}
    for _, objective in ipairs(quest.objectives) do
        if objective.kind == "item" then itemObjectives[#itemObjectives + 1] = objective end
    end
    local worst
    for _, item in ipairs(items) do
        -- Find the game's objective for this item: by its name, else by its place among the item objectives.
        local objective
        if item.name then
            for _, candidate in ipairs(quest.objectives) do
                if candidate.text and candidate.text:find(item.name, 1, true) then
                    objective = candidate
                    break
                end
            end
        end
        if not objective and #itemObjectives == items.total then objective = itemObjectives[item.pos] end
        if objective and not objective.done then
            local left = (objective.need or 1) - (objective.have or 0)
            if left > 0 then
                local kills = left / (item.rate / 100)
                if not worst or kills > worst.kills then
                    worst = { item = item.name, rate = item.rate, left = left, kills = kills }
                end
            end
        end
    end
    quest.drop = worst
end

----------------------------------------------------------------------
-- Player
----------------------------------------------------------------------
-- Classic rule of thumb, used only when the client has no function for it.
local function FallbackGreenRange(level)
    if level <= 5 then return level end
    if level <= 39 then return floor(level / 10) + 4 end
    return floor(level / 5)
end

function Scan.Player()
    local level = Num(Call(UnitLevel, "player")) or 0
    local maxLevel = Num(Call(GetMaxPlayerLevel))
    local xpMax = Num(Call(UnitXPMax, "player")) or 0
    local atMax = (maxLevel ~= nil and maxLevel > 0 and level >= maxLevel) or xpMax <= 0
    local inRaid = Call(IsInRaid) == true
    local grouped = inRaid or Call(IsInGroup) == true
    if not grouped and GetNumGroupMembers then grouped = (Num(Call(GetNumGroupMembers)) or 0) > 0 end
    return {
        level = level,
        maxLevel = maxLevel,
        xpMax = xpMax,
        atMax = atMax,
        zone = Str(Call(GetRealZoneText)) or Str(Call(GetZoneText)),
        className = Str(Call(UnitClass, "player")),
        grouped = grouped,
        inRaid = inRaid,
        greenRange = Num(Call(UnitQuestTrivialLevelRange, "player")) or Num(Call(GetQuestGreenRange))
            or FallbackGreenRange(level),
    }
end

----------------------------------------------------------------------
-- One quest
----------------------------------------------------------------------
local function ReadObjectives(C, id, quest)
    local list = Call(C.GetQuestObjectives, id)
    quest.objectives = {}
    if type(list) ~= "table" then return end
    local sum = 0
    for _, objective in ipairs(list) do
        if type(objective) == "table" then
            local have, need = Num(Field(objective, "numFulfilled")), Num(Field(objective, "numRequired"))
            local done = Field(objective, "finished") == true
            local fraction = 0
            if done then
                fraction = 1
            elseif have and need and need > 0 then
                fraction = min(1, have / need)
            end
            sum = sum + fraction
            quest.objectives[#quest.objectives + 1] = {
                text = Str(Field(objective, "text")), have = have, need = need, done = done,
                kind = Str(Field(objective, "type")),
            }
        end
    end
    if #quest.objectives > 0 then quest.progress = sum / #quest.objectives end
end

local function ReadTag(C, id, quest)
    local a, b = Call(C.GetQuestTagInfo or GetQuestTagInfo, id)
    local tagID, tagName, elite
    if type(a) == "table" then
        tagID, tagName, elite = Num(Field(a, "tagID")), Str(Field(a, "tagName")), Field(a, "isElite") == true
    else
        tagID, tagName = Num(a), Str(b)
    end
    quest.tag = tagID and TAG_KIND[tagID] or nil
    quest.tagName = tagName
    if not quest.tag and elite then quest.tag = "group" end
end

local function ReadQuest(C, id, index, info, header, player, questie)
    local quest = {
        id = id,
        index = index,
        title = Str(Field(info, "title")) or Str(Call(C.GetTitleForQuestID, id)) or ("Quest " .. id),
        zone = header,
        scaling = Field(info, "isScaling") == true,
        suggestedGroup = Num(Field(info, "suggestedGroup")) or 0,
        frequency = Num(Field(info, "frequency")) or 0,
        onMap = Field(info, "isOnMap") == true,
    }

    local level = Num(Call(C.GetQuestDifficultyLevel, id)) or Num(Field(info, "difficultyLevel"))
        or Num(Field(info, "level"))
    if level and level > 0 then quest.level = level end

    quest.ready = Call(C.ReadyForTurnIn, id) == true or Call(C.IsComplete, id) == true
    quest.failed = Call(C.IsFailed, id) == true
    quest.canAbandon = Call(C.CanAbandonQuest, id) ~= false
    quest.tracked = C.GetQuestWatchType ~= nil and Call(C.GetQuestWatchType, id) ~= nil
    if C.IsQuestTrivial then
        local trivial = Call(C.IsQuestTrivial, id)
        if type(trivial) == "boolean" then quest.trivial = trivial end
    end

    ReadObjectives(C, id, quest)
    ReadTag(C, id, quest)

    quest.xp = Num(Call(GetQuestLogRewardXP, id))
    quest.money = Num(Call(GetQuestLogRewardMoney, id))
    quest.items = (Num(Call(GetNumQuestLogRewards, id)) or 0) + (Num(Call(GetNumQuestLogChoices, id, true)) or 0)

    local distanceSq, onContinent = Call(C.GetDistanceSqToQuest, id)
    distanceSq = Num(distanceSq)
    if distanceSq and distanceSq > 0 and onContinent ~= false then quest.distance = sqrt(distanceSq) end

    quest.sameZone = quest.onMap or (header ~= nil and player.zone ~= nil and header == player.zone)
    if header and player.className and header == player.className then quest.classQuest = true end
    if quest.tag == "class" then quest.classQuest = true end
    QuestieFacts(questie, id, quest)
    ReadDrops(questie, id, quest)
    return quest
end

----------------------------------------------------------------------
-- The whole log
----------------------------------------------------------------------
function Scan.Log(player)
    local quests, meta = {}, { count = 0, max = 25, collapsed = 0 }
    local C = C_QuestLog
    if not (C and C.GetNumQuestLogEntries and C.GetInfo) then
        meta.error = "This client does not expose the quest log the way the addon expects (C_QuestLog)."
        return quests, meta
    end
    local entries, numQuests = Call(C.GetNumQuestLogEntries)
    entries, numQuests = Num(entries) or 0, Num(numQuests)
    local questie = Scan.Questie()
    local header
    for index = 1, entries do
        local info = Call(C.GetInfo, index)
        if type(info) == "table" then
            if Field(info, "isHeader") then
                header = Str(Field(info, "title"))
                if Field(info, "isCollapsed") then meta.collapsed = meta.collapsed + 1 end
            else
                local id = Num(Field(info, "questID"))
                if id and id > 0 and not Field(info, "isHidden") and not Field(info, "isTask")
                    and not Field(info, "isBounty") and not Field(info, "isInternalOnly") then
                    quests[#quests + 1] = ReadQuest(C, id, index, info, header, player, questie)
                end
            end
        end
    end
    meta.max = Num(Call(C.GetMaxNumQuestsCanAccept)) or Num(MAX_QUESTLOG_QUESTS) or Num(MAX_QUESTS) or 25
    meta.count = #quests
    -- Quests under a collapsed zone header are not listed by some clients.
    if numQuests and numQuests > #quests and meta.collapsed > 0 then
        meta.hiddenByCollapse = numQuests - #quests
        meta.count = numQuests
    end
    return quests, meta
end
