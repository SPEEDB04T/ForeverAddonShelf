-- Turn-in Route: the finished quests in the log and where each is handed in.
-- Everything is turned into world coordinates (yards, per continent) so
-- distances between zones add up.
local _, ns = ...
local Places = {}
ns.Places = Places

local Call, Num, Str, Field = ns.Call, ns.Num, ns.Str, ns.Field

-- Quest tag IDs (same numbers on Classic and modern clients)
local TAG_KIND = {
    [1] = "group", [21] = "class", [41] = "pvp", [62] = "raid", [81] = "dungeon", [83] = "legendary",
    [84] = "escort", [85] = "dungeon", [88] = "raid", [89] = "raid",
}
-- Quests for a group, a dungeon or a raid: their turn-in can wait for the group or sit inside
-- an instance, so they get their own list instead of a place on the route.
Places.GROUP_TAGS = { group = true, dungeon = true, raid = true }

function Places.MapName(mapID)
    local info = C_Map and Call(C_Map.GetMapInfo, mapID)
    return Str(Field(info, "name"))
end

-- A point on a map (0..1) as { continent, x, y, map, zone } in world yards, or nil.
function Places.WorldPos(mapID, x, y)
    if not (mapID and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, vector = pcall(CreateVector2D, x, y)
    if not ok or type(vector) ~= "table" then return nil end
    local continent, pos = Call(C_Map.GetWorldPosFromMapPos, mapID, vector)
    continent = Num(continent)
    local wx, wy = Num(Field(pos, "x")), Num(Field(pos, "y"))
    if not (continent and wx and wy) then return nil end
    return { continent = continent, x = wx, y = wy, map = mapID, mx = x, my = y, zone = Places.MapName(mapID) }
end

-- Where the player stands; nil inside instances and wherever the game hides it.
function Places.PlayerPos()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return nil end
    local mapID = Num(Call(C_Map.GetBestMapForUnit, "player"))
    if not mapID then return nil end
    local pos = Call(C_Map.GetPlayerMapPosition, mapID, "player")
    return Places.WorldPos(mapID, Num(Field(pos, "x")), Num(Field(pos, "y")))
end

----------------------------------------------------------------------
-- Turn-in places
----------------------------------------------------------------------
function Places.Questie()
    if type(QuestieLoader) ~= "table" or type(QuestieLoader.ImportModule) ~= "function" then return nil end
    local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
    if ok and type(db) == "table" and type(db.QueryQuestSingle) == "function" then return db end
    return nil
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
            return Places.WorldPos(mapID, Num(Field(pin, "x")), Num(Field(pin, "y")))
        end
    end
end

-- Questie (optional): the NPC or object that takes the quest, at its first known spawn, and its name.
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
                            local pos = Places.WorldPos(mapID, x / 100, y / 100)
                            if pos then
                                pos.npc = Str(Call(query, who, "name"))
                                return pos
                            end
                        end
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- The finished quests in the log
----------------------------------------------------------------------
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
    if not quest.tag and (quest.suggestedGroup or 0) >= 2 then quest.tag = "group" end
end

-- Returns the finished quests ({ id, title, level, zone, tag, tagName, xp, money, turnIn }) and
-- { error = text } when the client has no quest log the addon can read.
function Places.Finished()
    local quests, meta = {}, {}
    local C = C_QuestLog
    if not (C and C.GetNumQuestLogEntries and C.GetInfo) then
        meta.error = "This client does not expose the quest log the way the addon expects (C_QuestLog)."
        return quests, meta
    end
    local entries = Num((Call(C.GetNumQuestLogEntries))) or 0
    local header
    for index = 1, entries do
        local info = Call(C.GetInfo, index)
        if type(info) == "table" then
            if Field(info, "isHeader") then
                header = Str(Field(info, "title"))
            else
                local id = Num(Field(info, "questID"))
                if id and id > 0 and not Field(info, "isHidden") and not Field(info, "isTask")
                    and not Field(info, "isBounty") and not Field(info, "isInternalOnly")
                    and (Call(C.ReadyForTurnIn, id) == true or Call(C.IsComplete, id) == true) then
                    local quest = {
                        id = id, index = index, zone = header,
                        title = Str(Field(info, "title")) or Str(Call(C.GetTitleForQuestID, id)) or ("Quest " .. id),
                        suggestedGroup = Num(Field(info, "suggestedGroup")) or 0,
                        scaling = Field(info, "isScaling") == true,
                    }
                    local level = Num(Call(C.GetQuestDifficultyLevel, id)) or Num(Field(info, "difficultyLevel"))
                        or Num(Field(info, "level"))
                    if level and level > 0 then quest.level = level end
                    ReadTag(C, id, quest)
                    quest.xp = Num(Call(GetQuestLogRewardXP, id))
                    quest.money = Num(Call(GetQuestLogRewardMoney, id))
                    quests[#quests + 1] = quest
                end
            end
        end
    end
    local cache, questie = {}, nil
    for _, quest in ipairs(quests) do
        local pos = GameTurnIn(quest.id, cache)
        if pos then
            pos.source = "game"
        else
            if questie == nil then questie = Places.Questie() or false end
            pos = QuestieTurnIn(questie or nil, quest.id)
            if pos then pos.source = "Questie" end
        end
        quest.turnIn = pos
    end
    return quests, meta
end
