-- Snakes Warlock Helper: what the game says right now (spells known, talents, buffs, demon).
-- Everything else in the addon reads from here, so the API quirks live in one file.
local _, ns = ...
local D = ns.Data
local S = {}
ns.State = S

local Read, Call, CallN, Readable = ns.Read, ns.Call, ns.CallN, ns.Readable

S.pet = { exists = false }
S.scan = { ids = {}, names = {}, hidden = true }
S.mem = {}            -- last known state of each buff, for when auras can't be read (combat)
S.talents = nil       -- lower-case talent name -> rank
S.spellCache = {}
S.now, S.level = 0, 1

----------------------------------------------------------------------
-- Spells
----------------------------------------------------------------------
function S.SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local n = Call(C_Spell.GetSpellName, id)
        if n then return n end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = Call(C_Spell.GetSpellInfo, id)
        if type(info) == "table" then return Read(info.name) end
        return nil
    end
    return Call(GetSpellInfo, id)
end

function S.SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then
        local t = Call(C_Spell.GetSpellTexture, id)
        if t then return t end
    end
    return Call(GetSpellTexture, id)
end

-- Cast time in seconds, or nil.
function S.SpellCastTime(id)
    local ms
    if C_Spell and C_Spell.GetSpellInfo then
        local info = Call(C_Spell.GetSpellInfo, id)
        if type(info) == "table" then ms = Read(info.castTime) end
    elseif GetSpellInfo then
        local _, _, _, castTime = CallN(GetSpellInfo, id)
        ms = castTime
    end
    if type(ms) == "number" and ms > 0 then return ms / 1000 end
    return nil
end

-- Tooltip text of a spell. The client may need to load it first; it then fires
-- SPELL_DATA_LOAD_RESULT and the addon refreshes.
function S.SpellDesc(id)
    local desc
    if C_Spell and C_Spell.GetSpellDescription then
        desc = Call(C_Spell.GetSpellDescription, id)
    else
        desc = Call(GetSpellDescription, id)
    end
    if desc == nil or desc == "" then
        if C_Spell and C_Spell.RequestLoadSpellData then pcall(C_Spell.RequestLoadSpellData, id) end
        return nil
    end
    return desc
end

-- Spell ID of a spell in the spellbook, looked up by name (nil when not learned).
local function SpellIDByName(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = Call(C_Spell.GetSpellInfo, name)
        if type(info) == "table" then return Read(info.spellID) end
        return nil
    end
    if GetSpellInfo then
        local _, _, _, _, _, _, id = CallN(GetSpellInfo, name)
        return id
    end
end

function S.Knows(id, isPet)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = Enum and Enum.SpellBookSpellBank
        bank = bank and (isPet and bank.Pet or bank.Player) or nil
        if Call(C_SpellBook.IsSpellKnown, id, bank) then return true end
    end
    if Call(IsSpellKnown, id, isPet and true or false) then return true end
    if not isPet and Call(IsPlayerSpell, id) then return true end
    return false
end

-- Highest rank the player knows of def ({ name =, ids = { low .. high } }):
-- { id, name, icon } or nil. Falls back to the name, which covers IDs new on this client.
function S.Resolve(def)
    local cached = S.spellCache[def]
    if cached ~= nil then return cached or nil end
    local found
    for i = #def.ids, 1, -1 do
        if S.Knows(def.ids[i]) then found = def.ids[i]; break end
    end
    if not found and def.name then found = SpellIDByName(def.name) end
    local res = false
    if found then
        res = { id = found, name = S.SpellName(found) or def.name, icon = S.SpellIcon(found) or def.icon }
    end
    S.spellCache[def] = res
    return res or nil
end

----------------------------------------------------------------------
-- Talents. Forever keeps them in one trait tree; older clients answer GetTalentInfo.
----------------------------------------------------------------------
local function ReadTraitTalents(out)
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo
        and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then return end
    local configID = Call(C_ClassTalents.GetActiveConfigID)
    if type(configID) ~= "number" then return end
    local info = Call(C_Traits.GetConfigInfo, configID)
    local treeID = type(info) == "table" and type(info.treeIDs) == "table" and Read(info.treeIDs[1])
    if type(treeID) ~= "number" then return end
    local nodes = Call(C_Traits.GetTreeNodes, treeID)
    if type(nodes) ~= "table" then return end
    for _, nodeID in ipairs(nodes) do
        local node = Call(C_Traits.GetNodeInfo, configID, nodeID)
        if type(node) == "table" then
            local rank = Read(node.activeRank)
            if type(rank) ~= "number" then rank = Read(node.ranksPurchased) end
            local entryID = type(node.activeEntry) == "table" and Read(node.activeEntry.entryID)
                or (type(node.entryIDs) == "table" and Read(node.entryIDs[1]))
            if type(rank) == "number" and rank > 0 and entryID then
                local entry = Call(C_Traits.GetEntryInfo, configID, entryID)
                local defID = type(entry) == "table" and Read(entry.definitionID)
                local def = defID and Call(C_Traits.GetDefinitionInfo, defID)
                if type(def) == "table" then
                    local name = Read(def.overrideName)
                    local spellID = Read(def.spellID)
                    if (not name or name == "") and spellID then name = S.SpellName(spellID) end
                    if type(name) == "string" and name ~= "" then
                        local key = name:lower()
                        out[key] = math.max(out[key] or 0, rank)
                    end
                end
            end
        end
    end
end

local function ReadClassicTalents(out)
    if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return end
    local tabs = Call(GetNumTalentTabs) or 0
    for tab = 1, tabs do
        for i = 1, (Call(GetNumTalents, tab) or 0) do
            local name, _, _, _, rank = CallN(GetTalentInfo, tab, i)
            if type(name) == "string" and type(rank) == "number" and rank > 0 then
                out[name:lower()] = rank
            end
        end
    end
end

function S.ReadTalents()
    local out = {}
    ReadTraitTalents(out)
    if next(out) == nil then ReadClassicTalents(out) end
    S.talents = out
end

-- Rank of a talent by its English name (0 when not taken or unreadable).
function S.Talent(name)
    if not S.talents then S.ReadTalents() end
    return S.talents[name] or 0
end

----------------------------------------------------------------------
-- Buffs on the player
----------------------------------------------------------------------
local function ScanAuras()
    local scan = { ids = {}, names = {}, hidden = false, count = 0 }
    local function add(id, name, expires)
        if not id and not name then scan.hidden = true; return end
        local e = { id = id, name = name, expires = (type(expires) == "number" and expires > 0) and expires or nil }
        if id then scan.ids[id] = e end
        if name then scan.names[name] = e end
        scan.count = scan.count + 1
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok then scan.hidden = true; break end
            if aura == nil then break end
            if not Readable(aura) or type(aura) ~= "table" then
                scan.hidden = true
            else
                add(Read(aura.spellId), Read(aura.name), Read(aura.expirationTime))
            end
        end
    elseif UnitBuff then
        for i = 1, 40 do
            local ok, name, _, _, _, _, expires, _, _, _, spellId = pcall(UnitBuff, "player", i)
            if not ok then scan.hidden = true; break end
            if name == nil then break end
            add(Read(spellId), Read(name), Read(expires))
        end
    else
        scan.hidden = true
    end
    -- In combat an empty list more likely means "not allowed to look" than "no buffs".
    if S.inCombat and scan.count == 0 then scan.hidden = true end
    return scan
end

local function AuraNames(def)
    if def._names then return def._names end
    local names = {}
    for _, n in ipairs(def.auraNames or {}) do names[n] = true end
    for _, id in ipairs(def.auraIds or {}) do
        local n = S.SpellName(id)
        if n then names[n] = true end
    end
    def._names = names
    return names
end

-- "up" (plus seconds left, or nil when it has no timer), "down", or "unknown".
-- When the buff list can't be read it answers from memory: the last time it could
-- be read, plus casts and demon changes seen since.
function S.BuffStatus(key, def)
    local scan, now = S.scan, S.now
    local found
    for _, id in ipairs(def.auraIds or {}) do
        found = found or scan.ids[id]
    end
    if not found then
        for name in pairs(AuraNames(def)) do
            found = found or scan.names[name]
        end
    end
    if found then
        S.mem[key] = { up = true, expires = found.expires }
        return "up", found.expires and math.max(0, found.expires - now) or nil
    end
    if not scan.hidden then
        S.mem[key] = { up = false }
        return "down"
    end
    local m = S.mem[key]
    if not m then return "unknown" end
    if m.up then
        if m.expires and m.expires <= now then m.up = false; return "down" end
        return "up", m.expires and (m.expires - now) or nil
    end
    return "down"
end

----------------------------------------------------------------------
-- The demon
----------------------------------------------------------------------
local function PetSpellIDs()
    local ids = {}
    if GetPetActionInfo then
        for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
            local _, _, _, _, _, _, spellID = CallN(GetPetActionInfo, i)
            if type(spellID) == "number" then ids[spellID] = true end
        end
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemInfo and bank then
        local n = Call(C_SpellBook.HasPetSpells)
        if type(n) == "number" then
            for i = 1, n do
                local info = Call(C_SpellBook.GetSpellBookItemInfo, i, bank)
                if type(info) == "table" then
                    local id = Read(info.spellID) or Read(info.actionID)
                    if type(id) == "number" then ids[id] = true end
                end
            end
        end
    elseif HasPetSpells and GetSpellBookItemInfo then
        local n = Call(HasPetSpells)
        if type(n) == "number" then
            for i = 1, n do
                local _, id = CallN(GetSpellBookItemInfo, i, "pet")
                if type(id) == "number" then
                    if bit and bit.band then id = bit.band(id, 0xFFFFFF) end
                    ids[id] = true
                end
            end
        end
    end
    return ids
end

local function ReadPet()
    local exists = Call(UnitExists, "pet")
    if exists == nil then return end        -- can't tell right now: keep what we knew
    local pet = { exists = exists and true or false }
    if pet.exists then
        local dead = Call(UnitIsDead, "pet")
        pet.alive = not dead
        pet.name = Call(UnitName, "pet")
        local ids = PetSpellIDs()
        for id in pairs(ids) do
            if D.SIGNATURE_TO_PET[id] then pet.key = D.SIGNATURE_TO_PET[id]; break end
        end
        local family = Call(UnitCreatureFamily, "pet")
        if type(family) == "string" then
            pet.family = family
            if not pet.key then
                local f = family:lower()
                for key, def in pairs(D.PETS) do
                    for _, name in ipairs(def.families) do
                        if f == name then pet.key = key end
                    end
                end
            end
        end
        -- Last resort: the summon we saw the player cast.
        pet.key = pet.key or S.lastSummon or (S.pet.exists and S.pet.key) or nil
        local def = pet.key and D.PETS[pet.key]
        local ability = def and def.ability and D.ABILITIES[def.ability]
        if ability then
            for rank = #ability.ids, 1, -1 do
                if ids[ability.ids[rank]] or S.Knows(ability.ids[rank], true) then pet.rank = rank; break end
            end
        end
    end
    S.pet = pet
end

-- Name of a bag item whose name contains `needle` (lower case), or nil.
function S.FindBagItem(needle)
    local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    local getLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
    if not numSlots or not getLink then return nil end
    for bag = 0, 4 do
        for slot = 1, (Call(numSlots, bag) or 0) do
            local link = Call(getLink, bag, slot)
            local name = type(link) == "string" and link:match("%[(.-)%]")
            if name and name:lower():find(needle, 1, true) then return name end
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
function S.Refresh()
    S.now = GetTime()
    S.level = Call(UnitLevel, "player") or S.level
    S.inCombat = InCombatLockdown() and true or false
    S.dead = Call(UnitIsDeadOrGhost, "player") and true or false
    S.mounted = (Call(IsMounted) or Call(UnitOnTaxi, "player")) and true or false
    S.scan = ScanAuras()
    ReadPet()

    S.soulLinkKnown = (S.Talent("soul link") > 0 or S.Resolve(D.SOUL_LINK) ~= nil) and true or false
    local status = S.BuffStatus("soullink", D.SOUL_LINK)
    S.soulLinkUp = (status == "up")

    -- Weapon stone: hasEnchant, expiration (ms)
    local has, expires = CallN(GetWeaponEnchantInfo)
    S.weapon = {
        equipped = Call(GetInventoryItemID, "player", 16) ~= nil,
        enchanted = has,                                    -- nil = can't tell
        remaining = type(expires) == "number" and expires / 1000 or nil,
    }

    -- How long the player has been without a demon (the reminder waits a few seconds,
    -- because the demon shows up late after a login, a flight or a dismount).
    if S.pet.exists or S.mounted or S.dead then
        S.noPetSince = nil
    else
        S.noPetSince = S.noPetSince or S.now
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local castToBuff = {}
local function mapCasts(def, key)
    for _, id in ipairs(def.ids) do castToBuff[id] = { key = key, duration = def.duration } end
end
mapCasts(D.DEMON_ARMOR, "armor")
mapCasts(D.DEMON_SKIN, "armor")
mapCasts(D.SOUL_LINK, "soullink")
mapCasts(D.SACRIFICE, "sacrifice")

local function OnSpellcast(_, unit, _, spellID)
    if unit ~= "player" or not Readable(spellID) then return end
    local buff = castToBuff[spellID]
    if buff then
        S.mem[buff.key] = { up = true, expires = buff.duration and (GetTime() + buff.duration) or nil }
        ns.MarkDirty()
    end
    local petKey = D.SUMMON_TO_PET[spellID]
    if petKey then
        S.lastSummon = petKey
        ns.cdb.lastPet = petKey
        ns.MarkDirty()
    end
end

local function OnPetChanged(_, unit)
    if unit ~= nil and unit ~= "player" then return end
    -- Soul Link ends when the demon goes; a new demon needs it cast again.
    if S.mem.soullink then S.mem.soullink = { up = false } end
    ns.MarkDirty()
end

local function OnSpellsChanged()
    S.spellCache = {}
    S.talents = nil
    ns.MarkDirty()
end

local function OnDeath()
    for key in pairs(S.mem) do S.mem[key] = { up = false } end
    ns.MarkDirty()
end

local function OnUnitChange(_, unit)
    if unit == "player" or unit == "pet" then ns.MarkDirty() end
end

function S.Enable()
    ns.On("UNIT_SPELLCAST_SUCCEEDED", OnSpellcast)
    ns.On("UNIT_PET", OnPetChanged)
    ns.On("PLAYER_DEAD", OnDeath)
    for _, ev in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_TALENT_UPDATE",
        "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "PLAYER_LEVEL_UP" }) do
        ns.On(ev, OnSpellsChanged)
    end
    for _, ev in ipairs({ "UNIT_AURA", "UNIT_INVENTORY_CHANGED", "UNIT_DAMAGE", "UNIT_ATTACK_POWER" }) do
        ns.On(ev, OnUnitChange)
    end
    for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
        "PET_BAR_UPDATE", "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_ALIVE", "PLAYER_UNGHOST",
        "PLAYER_EQUIPMENT_CHANGED", "SPELL_DATA_LOAD_RESULT", "BAG_UPDATE_DELAYED" }) do
        ns.On(ev, ns.MarkDirty)
    end
end

----------------------------------------------------------------------
-- /swh debug
----------------------------------------------------------------------
function S.PrintDebug()
    S.Refresh()
    local t = {}
    for name, rank in pairs(S.talents or {}) do t[#t + 1] = name .. " " .. rank end
    table.sort(t)
    ns.Print("talents read: " .. (#t > 0 and table.concat(t, ", ") or "none"))
    local pet = S.pet
    ns.Print(("demon: exists=%s alive=%s type=%s family=%s ability rank=%s"):format(
        tostring(pet.exists), tostring(pet.alive), tostring(pet.key), tostring(pet.family), tostring(pet.rank)))
    ns.Print(("buff list: %d readable, hidden=%s, in combat=%s"):format(S.scan.count or 0, tostring(S.scan.hidden),
        tostring(S.inCombat)))
    ns.Print(("armor=%s  soul link=%s (known=%s)  sacrifice=%s"):format(
        S.BuffStatus("armor", D.ARMOR_AURA), S.BuffStatus("soullink", D.SOUL_LINK), tostring(S.soulLinkKnown),
        S.BuffStatus("sacrifice", D.SACRIFICE)))
    ns.Print(("weapon: equipped=%s stone=%s"):format(tostring(S.weapon.equipped), tostring(S.weapon.enchanted)))
    local res = ns.PetCalc.Evaluate()
    for _, row in ipairs(res.rows) do
        ns.Print(("%s: demon %s, you %s, total %s (%s)"):format(row.name, tostring(row.petDps and math.floor(row.petDps)),
            tostring(row.youDps and math.floor(row.youDps)), tostring(row.total and math.floor(row.total)), row.source))
    end
end
