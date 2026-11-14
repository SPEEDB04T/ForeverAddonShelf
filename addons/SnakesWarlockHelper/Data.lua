-- Snakes Warlock Helper: spell, demon and talent data for WoW Forever (level 60, build 1.60).
-- Spell IDs and talent numbers come from talentsforever.com/data.json (generated 2026-11-13).
-- Damage numbers are only fallbacks: the addon reads the in-game tooltip first.
local _, ns = ...
local D = {}
ns.Data = D

local ICON = "Interface\\Icons\\"

-- GetSpellBonusDamage / GetSpellCritChance school indexes
D.SCHOOL = { fire = 3, shadow = 6 }
D.SCHOOL_NAME = { fire = "Fire", shadow = "Shadow" }

----------------------------------------------------------------------
-- Buffs the reminders watch. ids = ranks low to high (cast spells);
-- auraIds / auraNames = what the buff is called once it is on you.
----------------------------------------------------------------------
D.DEMON_ARMOR = {
    name = "Demon Armor", ids = { 706, 1086, 11733, 11734, 11735 },
    icon = ICON .. "Spell_Shadow_RagingScream", duration = 1800,
}
D.DEMON_SKIN = {
    name = "Demon Skin", ids = { 687, 696 },
    icon = ICON .. "Spell_Shadow_RagingScream", duration = 1800,
}
-- Either armor counts: one buff slot, whichever rank the warlock has.
D.ARMOR_AURA = {
    auraIds = { 706, 1086, 11733, 11734, 11735, 687, 696 },
    auraNames = { "Demon Armor", "Demon Skin" },
}
D.SOUL_LINK = {
    name = "Soul Link", ids = { 19028 }, auraIds = { 19028, 25228 }, auraNames = { "Soul Link" },
    icon = ICON .. "Spell_Shadow_GatherShadows",
}
D.SACRIFICE = {
    name = "Demonic Sacrifice", ids = { 18788 },
    auraIds = { 18788, 18789, 18790, 18791, 18792 },
    auraNames = { "Demonic Sacrifice", "Burning Wish", "Fel Stamina", "Touch of Shadow", "Fel Energy" },
    icon = ICON .. "Spell_Shadow_PsychicScream",
}
-- Weapon stones (weapon enchants on Forever).
D.FIRESTONE = {
    name = "Create Firestone", ids = { 6366, 17951, 17952, 17953 }, item = "firestone",
    icon = ICON .. "INV_Ammo_FireTar",
}
D.SPELLSTONE = {
    name = "Create Spellstone", ids = { 2362, 17727, 17728 }, item = "spellstone",
    icon = ICON .. "INV_Misc_Gem_Sapphire_01",
}

----------------------------------------------------------------------
-- Demon abilities that deal damage.
-- damage = average hit per rank (Forever values), used when the tooltip can't be read.
-- levels = demon level each rank becomes available. coeff = share of the demon's spell damage.
----------------------------------------------------------------------
D.ABILITIES = {
    firebolt = {
        name = "Firebolt", school = "fire", coeff = 0.571, cast = 2.0,
        ids = { 3110, 7799, 7800, 7801, 7802, 11762, 11763 },
        damage = { 8, 15, 27, 38, 55, 76, 90 },
        levels = { 1, 8, 18, 28, 38, 48, 58 },
        talent = "improved imp", talentPerRank = 0.10,
    },
    lash = {
        name = "Lash of Pain", school = "shadow", coeff = 0.429, cooldown = 12,
        ids = { 7814, 7815, 7816, 11778, 11779, 11780 },
        damage = { 33, 44, 60, 73, 87, 99 },
        levels = { 20, 28, 36, 44, 52, 60 },
        talent = "improved sayaad", talentPerRank = 0.10,
    },
}

----------------------------------------------------------------------
-- Demons. signature = spells only that demon has (to tell which one is out).
-- mdSchool = school Master Demonologist boosts (for you and the demon) while it is out.
-- sacSchool = school Demonic Sacrifice boosts when this demon is sacrificed
--             (Forever swapped Imp and Succubus compared with Classic).
----------------------------------------------------------------------
D.PET_ORDER = { "imp", "voidwalker", "sayaad", "felhunter" }
D.PETS = {
    imp = {
        name = "Imp", summons = { { name = "Summon Imp", ids = { 688 } } },
        icon = ICON .. "Spell_Shadow_SummonImp",
        melee = false, ability = "firebolt", mdSchool = "fire", sacSchool = "shadow",
        families = { "imp" },
        signature = { 3110, 7799, 7800, 7801, 7802, 11762, 11763,       -- Firebolt
                      6307, 7804, 7805, 11766, 11767, 4511,             -- Blood Pact, Phase Shift
                      2947, 8316, 8317, 11770, 11771 },                 -- Fire Shield
    },
    voidwalker = {
        name = "Voidwalker", summons = { { name = "Summon Voidwalker", ids = { 697 } } },
        icon = ICON .. "Spell_Shadow_SummonVoidWalker",
        melee = true, mdNote = "takes less physical damage",
        families = { "voidwalker" },
        signature = { 3716, 7809, 7810, 7811, 11774, 11775,             -- Torment
                      7812, 19438, 19440, 19441, 19442, 19443,          -- Sacrifice
                      17735, 17750, 17751, 17752,                       -- Suffering
                      17767, 17850, 17851, 17852, 17853, 17854 },       -- Consume Shadows
    },
    sayaad = {
        name = "Succubus", altName = "Incubus",
        summons = { { name = "Summon Succubus", ids = { 712 } }, { name = "Summon Incubus", ids = { 713 } } },
        icon = ICON .. "Spell_Shadow_SummonSuccubus",
        melee = true, ability = "lash", mdSchool = "shadow", sacSchool = "fire",
        families = { "succubus", "incubus", "sayaad" },
        signature = { 7814, 7815, 7816, 11778, 11779, 11780,            -- Lash of Pain
                      6358, 6360, 7813, 11784, 11785, 7870 },           -- Seduction, Soothing Kiss, Lesser Invisibility
    },
    felhunter = {
        name = "Felhunter", summons = { { name = "Summon Felhunter", ids = { 691 } } },
        icon = ICON .. "Spell_Shadow_SummonFelHunter",
        melee = true, mdNote = "takes less magic damage",
        families = { "felhunter" },
        signature = { 19505, 19731, 19734, 19736,                       -- Devour Magic
                      19244, 19647,                                     -- Spell Lock
                      19478, 19655, 19656, 19660, 19480 },              -- Tainted Blood, Paranoia
    },
}

D.SUMMON_TO_PET, D.SIGNATURE_TO_PET = {}, {}
for key, pet in pairs(D.PETS) do
    for _, s in ipairs(pet.summons) do
        for _, id in ipairs(s.ids) do D.SUMMON_TO_PET[id] = key end
    end
    for _, id in ipairs(pet.signature) do D.SIGNATURE_TO_PET[id] = key end
end

----------------------------------------------------------------------
-- Your own main spell per school, for estimating your dps.
-- coeff = share of spell damage the spell gets; cast = seconds when the client won't say.
----------------------------------------------------------------------
D.FILLERS = {
    shadow = {
        { name = "Shadow Bolt", coeff = 0.857, cast = 3.0,
          ids = { 686, 695, 705, 1088, 1106, 7641, 11659, 11660, 11661, 25307 } },
    },
    fire = {
        { name = "Incinerate", coeff = 0.714, cast = 2.5, ids = { 29722, 32231 } },
        { name = "Searing Pain", coeff = 0.429, cast = 1.5,
          ids = { 5676, 17919, 17920, 17921, 17922, 17923 } },
    },
}

----------------------------------------------------------------------
-- Talent numbers (WoW Forever).
----------------------------------------------------------------------
D.TALENT = {
    unholyPower = 0.02,          -- demon damage per rank (5)
    masterDemonologist = 0.02,   -- per rank (5): Imp = Fire, Succubus/Incubus = Shadow, for you and the demon
    soulLink = 0.03,             -- you and the demon both deal 3% more
    sacrifice = 0.15,            -- Imp: Shadow, Succubus/Incubus: Fire
    demonicKnowledge = { 0.33, 0.67, 1.0 },   -- share of your level added as spell damage, you and the demon
    orcCommand = 0.05,           -- orc racial: demon damage
}
