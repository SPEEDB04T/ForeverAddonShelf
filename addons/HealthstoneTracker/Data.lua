-- Healthstone Tracker: the healthstone items and spells, and small shared helpers
local ADDON, ns = ...

-- In combat this client hides some values from addons ("secret values").
-- Comparing or indexing one throws, so everything read from the game is checked.
local issecret = issecretvalue or function() return false end
ns.issecret = issecret

ns.COOLDOWN = 120                               -- healthstone cooldown in seconds
ns.DEFAULT_ICON = "Interface\\Icons\\INV_Stone_04"

-- [itemID] = { rank, bonus }: rank 1-5, bonus 0-2 = points in Improved Healthstone
ns.STONES = {
    [5512]  = { rank = 1, bonus = 0 }, [19004] = { rank = 1, bonus = 1 }, [19005] = { rank = 1, bonus = 2 },
    [5511]  = { rank = 2, bonus = 0 }, [19006] = { rank = 2, bonus = 1 }, [19007] = { rank = 2, bonus = 2 },
    [5509]  = { rank = 3, bonus = 0 }, [19008] = { rank = 3, bonus = 1 }, [19009] = { rank = 3, bonus = 2 },
    [5510]  = { rank = 4, bonus = 0 }, [19010] = { rank = 4, bonus = 1 }, [19011] = { rank = 4, bonus = 2 },
    [9421]  = { rank = 5, bonus = 0 }, [19012] = { rank = 5, bonus = 1 }, [19013] = { rank = 5, bonus = 2 },
}

-- [spellID] = rank: what a player casts when they eat a healthstone
ns.USE_SPELLS = {
    [6262]  = 1, [23468] = 1, [23469] = 1,
    [6263]  = 2, [23470] = 2, [23471] = 2,
    [5720]  = 3, [23472] = 3, [23473] = 3,
    [5723]  = 4, [23474] = 4, [23475] = 4,
    [11732] = 5, [23476] = 5, [23477] = 5,
}

-- Soulstones. A warlock uses the item on a player, who then carries the
-- "Soulstone Resurrection" buff for half an hour; the item has a half-hour cooldown.
ns.SOUL_COOLDOWN = 1800
ns.SOUL_DURATION = 1800
ns.SOUL_ICON = "Interface\\Icons\\Spell_Shadow_SoulGem"
ns.SOUL_ITEMS = { [5232] = 1, [16892] = 2, [16893] = 3, [16895] = 4, [16896] = 5 }
-- [spellID] = rank: cast by using the item, and the buff it leaves
ns.SOUL_SPELLS = { [20707] = 1, [20762] = 2, [20763] = 3, [20764] = 4, [20765] = 5 }
-- cast by a dead player who takes the resurrection
ns.SOUL_REZ = { [3026] = true, [20758] = true, [20759] = true, [20760] = true, [20761] = true }

-- Short label shown in the list. Rank 0 = a healthstone this file doesn't know.
ns.RANK_LABEL = { [0] = "has one", "Minor", "Lesser", "Regular", "Greater", "Major" }

-- A healthstone the tables above don't list (a new rank on this realm) is
-- still recognised by what using it casts.
local itemCache = {}
function ns.StoneInfo(itemID)
    local stone = ns.STONES[itemID]
    if stone then return stone end
    local cached = itemCache[itemID]
    if cached ~= nil then return cached or nil end
    cached = false
    if C_Item and C_Item.GetItemSpell then
        local ok, spellName, spellID = pcall(C_Item.GetItemSpell, itemID)
        if not ok or issecret(spellName) or issecret(spellID) then return nil end   -- hidden: ask again later
        local rank = type(spellID) == "number" and ns.USE_SPELLS[spellID]
        if rank then
            cached = { rank = rank, bonus = 0 }
        elseif type(spellName) == "string" and spellName:find("Healthstone", 1, true)
            and not spellName:find("Create", 1, true) then
            cached = { rank = 0, bonus = 0 }
            if type(spellID) == "number" then ns.USE_SPELLS[spellID] = 0 end
        end
    end
    itemCache[itemID] = cached
    return cached or nil
end

local spellCache = {}
function ns.IsStoneSpell(spellID)
    if ns.USE_SPELLS[spellID] then return true end
    local cached = spellCache[spellID]
    if cached ~= nil then return cached end
    cached = false
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if not ok or issecret(name) then return false end
        if type(name) == "string" and name:find("Healthstone", 1, true) and not name:find("Create", 1, true)
            and not name:find("Improved", 1, true) then
            cached = true
        end
    end
    spellCache[spellID] = cached
    return cached
end

-- Soulstone items and spells, with the same fallback by name for unlisted ranks.
local soulItemCache = {}
function ns.IsSoulItem(itemID)
    if ns.SOUL_ITEMS[itemID] then return true end
    local cached = soulItemCache[itemID]
    if cached ~= nil then return cached end
    cached = false
    if C_Item and C_Item.GetItemSpell then
        local ok, spellName, spellID = pcall(C_Item.GetItemSpell, itemID)
        if not ok or issecret(spellName) or issecret(spellID) then return false end
        if (type(spellID) == "number" and ns.SOUL_SPELLS[spellID]) or spellName == "Soulstone Resurrection" then
            cached = true
            if type(spellID) == "number" and not ns.SOUL_SPELLS[spellID] then ns.SOUL_SPELLS[spellID] = 0 end
        end
    end
    soulItemCache[itemID] = cached
    return cached
end

local soulSpellCache = {}
function ns.IsSoulSpell(spellID)
    if ns.SOUL_SPELLS[spellID] then return true end
    local cached = soulSpellCache[spellID]
    if cached ~= nil then return cached end
    cached = false
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if not ok or issecret(name) then return false end
        if name == "Soulstone Resurrection" then
            cached = true
            ns.SOUL_SPELLS[spellID] = 0
        end
    end
    soulSpellCache[spellID] = cached
    return cached
end

function ns.StoneLabel(itemID)
    local stone = itemID and ns.StoneInfo(itemID)
    return ns.RANK_LABEL[stone and stone.rank or 0] or ns.RANK_LABEL[0]
end

function ns.StoneName(itemID)
    if itemID and C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok and not issecret(name) and type(name) == "string" and name ~= "" then return name end
    end
    return "Healthstone"
end

function ns.StoneIcon(itemID)
    if itemID and C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and not issecret(icon) and icon then return icon end
    end
    return ns.DEFAULT_ICON
end

----------------------------------------------------------------------
-- Names
----------------------------------------------------------------------
-- Names on this client are often two words ("First Last"): a name is never
-- cut or split at a space. The same realm comes spelled two ways at once:
-- GetNormalizedRealmName() says "RPPvP", names from the server say
-- "CAMWOWUS1Realm9RPPvP". So a name is never compared with a realm glued on;
-- it is matched to a group unit by name, the realm only breaking a tie
-- (see .agents/memory/pitfalls.md, "Who sent an addon message").

-- A usable plain name string, or nil.
function ns.Norm(name)
    if issecret(name) or type(name) ~= "string" or name == "" then return nil end
    return name
end

-- The unit's name as the game gives it: "Name", or "Name-Realm" when the game
-- gives a realm (another realm). This is the key of the member table.
function ns.FullUnitName(unit)
    local ok, name, realm = pcall(UnitName, unit)
    if not ok or issecret(name) or issecret(realm) or type(name) ~= "string" or name == "" then return nil end
    if type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
    return name
end

-- "CAMWOWUS1Realm9RPPvP" -> "camwowus1realm9rppvp"
local function Squeeze(s)
    if type(s) ~= "string" then return "" end
    return (s:lower():gsub("[^%w]", ""))
end

local function Agree(a, b)
    if a == "" or b == "" then return a == b end
    return a == b or a:sub(-#b) == b or b:sub(-#a) == a or a:sub(1, #b) == b or b:sub(1, #a) == a
end

local function OwnRealmAgrees(suffix)
    if suffix == "" then return true end
    for _, f in ipairs({ GetNormalizedRealmName, GetRealmName }) do
        if f then
            local ok, r = pcall(f)
            if ok and not issecret(r) and Agree(suffix, Squeeze(r)) then return true end
        end
    end
    return false
end

-- The group units to look through: in a raid the raid units (the player is
-- one of them), otherwise the player and the party.
local function GroupUnits()
    local units = {}
    if IsInRaid and IsInRaid() then
        local n = GetNumGroupMembers and GetNumGroupMembers() or 0
        for i = 1, math.min(40, tonumber(n) or 0) do units[#units + 1] = "raid" .. i end
    else
        units[1] = "player"
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    return units
end

-- Which group unit a name from the server or from a message belongs to.
-- Returns the unit, or nil and why: "hidden" (a secret or unusable name),
-- "not found in the group", or "several with that name".
function ns.UnitOfName(full)
    if issecret(full) then return nil, "hidden" end
    if type(full) ~= "string" or full == "" then return nil, "hidden" end
    local dash = full:find("-", 1, true)
    local who = dash and full:sub(1, dash - 1) or full
    local suffix = Squeeze(dash and full:sub(dash + 1) or "")
    if who == "" then return nil, "hidden" end
    local first, agreeing, count = nil, nil, 0
    for _, unit in ipairs(GroupUnits()) do
        local ok, name, realm = pcall(UnitName, unit)
        if ok and not issecret(name) and not issecret(realm) and name == who then
            count = count + 1
            first = first or unit
            local agrees
            if type(realm) == "string" and realm ~= "" then
                agrees = suffix ~= "" and Agree(suffix, Squeeze(realm))
            else
                agrees = OwnRealmAgrees(suffix)
            end
            if agrees and not agreeing then agreeing = unit end
        end
    end
    if count == 1 then return first end
    if agreeing then return agreeing end
    if count == 0 then return nil, "not found in the group" end
    return nil, "several with that name"
end

-- 75 -> "1:15"
function ns.Clock(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

-- 200 -> "3 min"
function ns.Ago(seconds)
    seconds = math.max(0, seconds)
    if seconds < 60 then return "just now" end
    if seconds < 3600 then return ("%d min ago"):format(math.floor(seconds / 60)) end
    return ("%d h ago"):format(math.floor(seconds / 3600))
end
