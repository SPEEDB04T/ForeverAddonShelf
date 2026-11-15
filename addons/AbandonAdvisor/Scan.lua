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
-- Places, for the hand-in route. Everything is turned into world
-- coordinates (yards, per continent) so distances between zones add up.
----------------------------------------------------------------------
local function MapName(mapID)
    local info = C_Map and Call(C_Map.GetMapInfo, mapID)
    return Str(Field(info, "name"))
end

-- A point on a zone map (0..1) as { continent, x, y } in world yards, or nil.
function Scan.WorldPos(mapID, x, y)
    if not (mapID and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, vector = pcall(CreateVector2D, x, y)
    if not ok or type(vector) ~= "table" then return nil end
    local continent, pos = Call(C_Map.GetWorldPosFromMapPos, mapID, vector)
    continent = Num(continent)
    local wx, wy = Num(Field(pos, "x")), Num(Field(pos, "y"))
    if not (continent and wx and wy) then return nil end
    return { continent = continent, x = wx, y = wy, map = mapID, zone = MapName(mapID) }
end

-- Where the player stands; nil inside instances and wherever the game hides it.
local function PlayerPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local mapID = Num(Call(C_Map.GetBestMapForUnit, "player"))
    if not mapID then return nil end
    local pos = Call(C_Map.GetPlayerMapPosition, mapID, "player")
    return Scan.WorldPos(mapID, Num(Field(pos, "x")), Num(Field(pos, "y")))
end

-- The game's own turn-in mark: the quest's map (past any waypoints, as the quest log's
-- "show on map" does) and its pin there, from the call the world map draws its quest pins with.
local function GameTurnIn(id, cache)
    if not (GetQuestUiMapID and C_QuestLog and C_QuestLog.GetQuestsOnMap) then return nil end
    local mapID = Num(Call(GetQuestUiMapID, id, true))
    if not mapID or mapID <= 0 then return nil end
    local pins = cache[mapID]
    if pins == nil then
        pins = Call(C_QuestLog.GetQuestsOnMap, mapID)
        if type(pins) ~= "table" then pins = false end
        cache[mapID] = pins
    end
    if not pins then return nil end
    for _, pin in ipairs(pins) do
        if Num(Field(pin, "questID")) == id then
            return Scan.WorldPos(mapID, Num(Field(pin, "x")), Num(Field(pin, "y")))
        end
    end
end

-- Questie (optional): the NPC or object that takes the quest, at its first known spawn.
local function QuestieTurnIn(db, id)
    if not (db and type(db.QueryNPCSingle) == "function") then return nil end
    local ok, zoneDB = pcall(QuestieLoader.ImportModule, QuestieLoader, "ZoneDB")
    if not (ok and type(zoneDB) == "table" and type(zoneDB.GetUiMapIdByAreaId) == "function") then return nil end
    local finishedBy = Call(db.QueryQuestSingle, id, "finishedBy")
    if type(finishedBy) ~= "table" then return nil end
    local lists = { { finishedBy[1], db.QueryNPCSingle }, { finishedBy[2], db.QueryObjectSingle } }
    for _, entry in ipairs(lists) do
        local ids, query = entry[1], entry[2]
        if type(ids) == "table" and type(query) == "function" then
            for _, who in ipairs(ids) do
                local spawns = Call(query, who, "spawns")
                if type(spawns) == "table" then
                    for areaId, points in pairs(spawns) do
                        local mapID = Num(Call(zoneDB.GetUiMapIdByAreaId, zoneDB, areaId))
                        local point = type(points) == "table" and points[1]
                        local x, y = type(point) == "table" and Num(point[1]), type(point) == "table" and Num(point[2])
                        if mapID and x and y then
                            local pos = Scan.WorldPos(mapID, x / 100, y / 100)
                            if pos then return pos end
                        end
                    end
                end
            end
        end
    end
end

-- Sets quest.turnIn = { continent, x, y, map, zone, source } on every finished quest the game
-- (or else Questie) can place, and returns where the player stands.
function Scan.TurnIns(quests)
    local cache, questie
    for _, quest in ipairs(quests) do
        if quest.ready then
            cache = cache or {}
            local pos = GameTurnIn(quest.id, cache)
            if pos then
                pos.source = "game"
            else
                if questie == nil then questie = Scan.Questie() or false end
                pos = QuestieTurnIn(questie or nil, quest.id)
                if pos then pos.source = "Questie" end
            end
            quest.turnIn = pos
        end
    end
    return PlayerPos()
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
