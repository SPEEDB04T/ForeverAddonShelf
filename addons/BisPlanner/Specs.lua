-- BiS Planner: starting weights for every spec.
--
-- From sixtysim.com's Forever stat pages (all dated 17 November 2026, read 20 November 2026):
-- its simulator's worth of one point of each stat on its benchmark gear: one boss for one minute
-- for damage, three minutes for healers. In one minute a healer never runs out of mana, so
-- intellect, spirit and mana per 5 look worthless and haste (one more cast before the kill) tops
-- the list; three minutes is the longest fight sixtysim runs, and there mana runs out first.
-- Shamans get no mana from spirit while casting, so sixtysim gives it no row for them.
-- Sixtysim calls them beta data until level 60 opens. The tanks' weights are estimates of ours:
-- sixtysim weighs tanks for threat only (it gives defense and dodge less than nothing), and a tank
-- wants to live first.
--
-- Each spec's own unit is 1 (strength, agility, attack power, spell damage or healing); only the
-- ratios matter. Hit counts in full only up to its cap, given in `cap` and shown on the menu:
-- past it, a point of hit is worth nothing, so set "Hit, at least" when your gear can reach it.
local _, ns = ...

local SIXTYSIM = "sixtysim.com, 17 Nov 2026"
local OURS = "an estimate: tanks live first"

local MELEE_CAP = "Hit up to 8% (80 rating) counts in full; expertise up to 65 (the boss's 6.5% dodge)."
local SPELL_CAP = "Hit up to 17% (170 rating, less what your talents give) counts in full."

ns.SPECS = {
    WARRIOR = {
        { name = "Arms", source = SIXTYSIM, cap = MELEE_CAP,
          w = { str = 1, agi = 0.61, ap = 0.45, hit = 0.02, crit = 0.79, haste = 0.45, expertise = 1.75, mdps = 7.32 } },
        { name = "Fury", source = SIXTYSIM, cap = MELEE_CAP .. " Past 8% hit still helps white swings.",
          w = { str = 1, agi = 0.57, ap = 0.45, hit = 0.98, crit = 0.74, haste = 0.88, expertise = 1.84, mdps = 4.38, odps = 1.77 } },
        { name = "Protection", source = OURS, cap = "Hit up to 8% (80 rating) and expertise for threat.",
          w = { sta = 1, armor = 0.06, defense = 1.2, dodge = 1, parry = 0.9, block = 0.5, blockValue = 0.4,
                agi = 0.6, str = 0.5, ap = 0.2, hit = 0.5, expertise = 0.6, crit = 0.3, mdps = 1.5 } },
    },
    PALADIN = {
        { name = "Holy", source = SIXTYSIM, cap = "Hit does nothing for healing. Weighed for a three-minute fight, where mana runs out.",
          w = { heal = 1, int = 1.85, spi = 0.57, mp5 = 2.4, crit = 1.73, haste = 0.67 } },
        { name = "Protection", source = OURS, cap = "Hit up to 8% (80 rating) for swings, 17% for Consecration.",
          w = { sta = 1, armor = 0.06, defense = 1.2, dodge = 1, parry = 0.9, block = 0.5, blockValue = 0.5,
                str = 0.4, agi = 0.5, int = 0.2, hit = 0.5, expertise = 0.6, crit = 0.3, dmg = 0.6, mdps = 1 } },
        { name = "Retribution", source = SIXTYSIM, cap = MELEE_CAP,
          w = { str = 1, agi = 1.1, int = 1.29, ap = 0.41, hit = 0.66, crit = 1.6, haste = 1.76, expertise = 2.45,
                mdps = 5.39, dmg = 1.69, spHoly = 1.41 } },
    },
    HUNTER = {
        { name = "Beast Mastery", source = SIXTYSIM, cap = "Hit up to 8% (80 rating) counts in full.",
          w = { agi = 1, int = 0.39, rap = 0.35, hit = 0.26, crit = 0.75, haste = 0.74, expertise = 0.53, rdps = 3.29 } },
        { name = "Marksmanship", source = SIXTYSIM, cap = "Hit up to 8% (80 rating) counts in full.",
          w = { agi = 1, int = 0.4, rap = 0.34, hit = 0.22, crit = 0.84, haste = 0.67, rdps = 3.39, mp5 = 0.01 } },
        -- sixtysim gives haste -0.27 (its weaving rotation) and calls that figure unreliable: left at 0
        { name = "Survival", source = SIXTYSIM, cap = "Hit up to 8% (80 rating) counts in full.",
          w = { agi = 1, str = 0.18, int = 0.41, ap = 0.17, rap = 0.21, hit = 0.03, crit = 0.82, expertise = 0.55, rdps = 1.88 } },
    },
    ROGUE = {
        { name = "Assassination", source = SIXTYSIM, cap = "Hit up to 8% (80 rating) for attacks, 17% for poisons; expertise up to 65.",
          w = { ap = 1, str = 1.1, agi = 2.12, hit = 1.85, crit = 2.07, haste = 1.17, expertise = 2.58, mdps = 8.13, odps = 3.19 } },
        { name = "Combat", source = SIXTYSIM, cap = MELEE_CAP,
          w = { ap = 1, str = 1.1, agi = 1.92, hit = 1.58, crit = 1.61, haste = 1.12, expertise = 2.16, mdps = 10.2, odps = 2.88 } },
        { name = "Subtlety", source = SIXTYSIM, cap = MELEE_CAP,
          w = { ap = 1, str = 1.1, agi = 1.93, hit = 1.56, crit = 1.69, haste = 1.03, expertise = 2.36, mdps = 10.2, odps = 1.85 } },
    },
    PRIEST = {
        { name = "Discipline", source = SIXTYSIM, cap = "Hit does nothing for healing. Weighed for a three-minute fight, where mana runs out.",
          w = { heal = 1, int = 1.76, spi = 0.97, crit = 1.01, haste = 0.11, mp5 = 2.5 } },
        { name = "Holy", source = SIXTYSIM, cap = "Hit does nothing for healing. Weighed for a three-minute fight, where mana runs out.",
          w = { heal = 1, int = 1.83, spi = 0.99, crit = 0.82, haste = 0.81, mp5 = 2.23 } },
        { name = "Shadow", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spShadow = 1, int = 0.27, hit = 1.34, crit = 0.93, haste = 0.34 } },
    },
    SHAMAN = {
        { name = "Elemental", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spNature = 0.86, spFire = 0.11, int = 0.47, hit = 0.96, crit = 0.75, haste = 1.34, mp5 = 0.04 } },
        { name = "Enhancement", source = SIXTYSIM, cap = MELEE_CAP .. " Spells want 17%.",
          w = { ap = 1, str = 2.2, agi = 1.75, int = 1.93, hit = 2.11, crit = 2.91, haste = 3.1, expertise = 3.87,
                mdps = 13.7, dmg = 1.48, spNature = 0.64 } },
        { name = "Restoration", source = SIXTYSIM, cap = "Hit does nothing for healing. Weighed for a three-minute fight, where mana runs out.",
          w = { heal = 1, int = 2.39, crit = 1.07, haste = 0.5, mp5 = 2.2 } },
    },
    MAGE = {
        { name = "Arcane", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spArcane = 0.98, int = 1.03, spi = 0.1, hit = 1, crit = 0.66, haste = 2.22, mp5 = 0.15 } },
        { name = "Fire", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spFire = 0.96, spArcane = 0.04, int = 0.28, hit = 1.57, crit = 0.78, haste = 0.94 } },
        { name = "Frost", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spFrost = 0.99, int = 0.17, hit = 1.08, crit = 0.64, haste = 1.23 } },
    },
    WARLOCK = {
        { name = "Affliction", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spShadow = 0.91, spFire = 0.09, int = 0.45, hit = 1.14, crit = 0.87, haste = 1.73, mp5 = 0.16 } },
        { name = "Demonology", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spShadow = 0.83, spFire = 0.17, int = 0.21, hit = 1.32, crit = 0.82, haste = 1.83 } },
        { name = "Destruction", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spShadow = 0.82, spFire = 0.18, int = 0.3, hit = 1.07, crit = 0.82, haste = 0.86, mp5 = 0.06 } },
    },
    DRUID = {
        { name = "Balance", source = SIXTYSIM, cap = SPELL_CAP,
          w = { dmg = 1, spArcane = 0.66, spNature = 0.34, int = 0.24, hit = 0.87, crit = 0.73, haste = 1.06, mp5 = 0.02 } },
        -- cats and bears fight with their paws: weapon damage does nothing
        { name = "Feral (cat)", source = SIXTYSIM, cap = "Hit up to 8% (80 rating, less Nature's Reach) counts in full; expertise up to 65.",
          w = { agi = 1, str = 0.99, ap = 0.41, hit = 0.89, crit = 0.72, haste = 0.46, expertise = 0.87 } },
        { name = "Feral (bear)", source = OURS, cap = "Hit up to 8% (80 rating) and expertise for threat.",
          w = { sta = 1, armor = 0.12, agi = 1, defense = 1.2, dodge = 1, str = 0.4, ap = 0.2, hit = 0.5,
                expertise = 0.6, crit = 0.3 } },
        { name = "Restoration", source = SIXTYSIM, cap = "Hit does nothing for healing. Weighed for a three-minute fight, where mana runs out.",
          w = { heal = 1, int = 1.55, spi = 1.47, crit = 0.68, haste = 0.22, mp5 = 2.43 } },
    },
}

function ns.Specs(class)
    return ns.SPECS[class or ns.Player().class] or {}
end

-- The spec's weights replace the set's own; its goals stay.
function ns.ApplySpec(spec)
    if type(spec) ~= "table" or type(spec.w) ~= "table" then return false end
    local profile = ns.Profile()
    profile.weights = {}
    for key, value in pairs(spec.w) do
        if ns.STAT_NAME[key] and value ~= 0 then profile.weights[key] = value end
    end
    ns.Changed()
    return true
end

-- "fury", "feral bear", "bm": the player's own spec whose name starts with it, or nil
function ns.FindSpec(text, class)
    text = tostring(text or ""):lower():gsub("[%(%)]", ""):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    if text == "" then return nil end
    if text == "bm" then text = "beast" elseif text == "mm" then text = "marks" end
    for _, spec in ipairs(ns.Specs(class)) do
        local name = spec.name:lower():gsub("[%(%)]", "")
        if name:sub(1, #text) == text then return spec end
    end
end
