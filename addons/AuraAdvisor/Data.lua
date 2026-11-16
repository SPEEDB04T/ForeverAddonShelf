-- Aura Advisor: what the addon knows about the auras, damage schools and enemy spells.
-- Spell IDs and ranks are from talentsforever.com/data.json (generated 2026-11-13, beta
-- client 1.60.1.70755). WoW Forever has six auras: Devotion, Retribution, Concentration and
-- the three resistance auras. There is no Sanctity Aura and no talent that changes an aura.
local _, ns = ...
local Data = {}
ns.Data = Data

Data.ORDER = { "devotion", "retribution", "concentration", "shadow", "frost", "fire" }
Data.AURAS = {
    devotion = {
        english = "Devotion Aura", short = "Devotion", level = 1,
        ids = { 465, 10290, 643, 10291, 1032, 10292, 10293 },
        icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
        does = "more armor for your party",
    },
    retribution = {
        english = "Retribution Aura", short = "Retribution", level = 16,
        ids = { 7294, 10298, 10299, 10300, 10301 },
        icon = "Interface\\Icons\\Spell_Holy_AuraOfLight",
        does = "Holy damage to whatever strikes your party",
    },
    concentration = {
        english = "Concentration Aura", short = "Concentration", level = 22,
        ids = { 19746 },
        icon = "Interface\\Icons\\Spell_Holy_MindSooth",
        does = "35% chance that a hit does not push a cast back",
    },
    shadow = {
        english = "Shadow Resistance Aura", short = "Shadow Resistance", level = 28, school = "shadow",
        ids = { 19876, 19895, 19896 },
        icon = "Interface\\Icons\\Spell_Shadow_SealOfKings",
        does = "Shadow resistance for your party and raid",
    },
    frost = {
        english = "Frost Resistance Aura", short = "Frost Resistance", level = 32, school = "frost",
        ids = { 19888, 19897, 19898 },
        icon = "Interface\\Icons\\Spell_Frost_WizardMark",
        does = "Frost resistance for your party and raid",
    },
    fire = {
        english = "Fire Resistance Aura", short = "Fire Resistance", level = 36, school = "fire",
        ids = { 19891, 19899, 19900 },
        icon = "Interface\\Icons\\Spell_Fire_SealOfFire",
        does = "Fire resistance for your party and raid",
    },
}

Data.RIGHTEOUS_FURY = { id = 25780, english = "Righteous Fury" }

-- spell ID -> aura key
Data.KEY_BY_ID = {}
for key, def in pairs(Data.AURAS) do
    for _, id in ipairs(def.ids) do Data.KEY_BY_ID[id] = key end
end

Data.SCHOOL_NAME = {
    physical = "physical", fire = "Fire", frost = "Frost", shadow = "Shadow", other = "other magic",
}

----------------------------------------------------------------------
-- Damage school of a hit, from the school mask the game sends with it.
-- 1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane.
-- Returns "physical", "fire", "frost", "shadow" or "other" (magic no aura resists).
----------------------------------------------------------------------
local function HasBit(mask, bit)
    return mask % (bit * 2) >= bit
end

function Data.SchoolOfMask(mask)
    if type(mask) ~= "number" or mask ~= mask or mask < 0 then return nil end
    mask = math.floor(mask)
    if mask == 0 or mask == 1 then return "physical" end
    if HasBit(mask, 4) then return "fire" end
    if HasBit(mask, 16) then return "frost" end
    if HasBit(mask, 32) then return "shadow" end
    return "other"
end

----------------------------------------------------------------------
-- Damage school of an enemy spell, from the name of the spell the game shows it casting.
-- Used only for spells that are still being cast (the hit itself reports its school).
-- Returns "fire", "frost", "shadow", or nil when the name doesn't clearly say: then the cast
-- counts for no aura.
----------------------------------------------------------------------
-- A name ending in one of these is a buff or a shield, not an attack.
local NOT_AN_ATTACK = {
    "ward", "armor", "barrier", "block", "shield", "resistance", "protection", "form", "aura",
    "totem", "weapon", "mending", "heal",
}
-- A name starting with one of these makes something, it hits nobody.
local NOT_AN_ATTACK_START = { "summon", "conjure", "create", "enchant" }
-- Names that contain a school word but are another school, or no attack at all.
local OTHER_SCHOOL = { "holy fire", "mana burn", "frost trap", "shadowmeld", "shadowstep", "fire elemental totem",
                       "inner fire", "icy veins", "cold snap", "cold blood", "shadow trance" }

-- A word of the name that starts with one of these.
local WORDS = {
    fire = { "fire", "flame", "scorch", "pyro", "immolat", "incinerat", "lava", "magma", "molten",
             "conflag", "hellfire", "inferno", "blaze", "sear", "ignite", "meteor", "cinder", "ember" },
    frost = { "frost", "ice", "icy", "blizzard", "freez", "chill", "cold", "glacial", "hail" },
    shadow = { "shadow", "corruption", "agony", "drain", "void", "siphon", "necrotic" },
}
-- Part of the name, anywhere.
local PHRASES = {
    shadow = { "mind blast", "mind flay", "death coil", "touch of weakness", "devouring plague" },
}

function Data.SchoolOfSpellName(name)
    if type(name) ~= "string" or name == "" then return nil end
    local lower = name:lower()
    for _, phrase in ipairs(OTHER_SCHOOL) do
        if lower:find(phrase, 1, true) then return nil end
    end
    for _, ending in ipairs(NOT_AN_ATTACK) do
        if lower:sub(-#ending) == ending then return nil end
    end
    for _, start in ipairs(NOT_AN_ATTACK_START) do
        if lower:sub(1, #start) == start then return nil end
    end
    for school, list in pairs(PHRASES) do
        for _, phrase in ipairs(list) do
            if lower:find(phrase, 1, true) then return school end
        end
    end
    for word in lower:gmatch("%a+") do
        for _, school in ipairs({ "fire", "frost", "shadow" }) do
            for _, start in ipairs(WORDS[school]) do
                if word:sub(1, #start) == start then return school end
            end
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Spells that hurt the one casting them. A party warlock's own Hellfire burns them every
-- second it is channelled, and Life Tap costs health: those hits are not an enemy's, so they
-- must not count. The game doesn't tell an addon who dealt a hit (no combat log), so these
-- are told apart by what the one who was hit is casting.
----------------------------------------------------------------------
Data.SELF_HARM = {
    { english = "Hellfire", school = "fire", channel = true, ids = { 1949, 11683, 11684, 27213 } },
    { english = "Life Tap", school = "shadow", ids = { 1454, 1455, 1456, 11687, 11688, 11689, 27222 } },
}
Data.SELF_HARM_BY_ID = {}
for _, s in ipairs(Data.SELF_HARM) do
    for _, id in ipairs(s.ids) do Data.SELF_HARM_BY_ID[id] = s end
end
