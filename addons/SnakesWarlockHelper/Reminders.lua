-- Snakes Warlock Helper: which buffs are missing right now.
-- Build() returns a list for the icon strip; an empty list means nothing is shown at all.
local _, ns = ...
local D = ns.Data
local S = ns.State
local R = {}
ns.Reminders = R

R.snoozed = {}                 -- key -> time until which that reminder stays quiet
local SNOOZE = 600
local NO_DEMON_GRACE = 4       -- seconds without a demon before reminding

R.LABEL = {
    armor = "Demon Armor / Demon Skin",
    soullink = "Soul Link",
    demon = "No demon out",
    stone = "Firestone / Spellstone",
}
R.ORDER = { "demon", "soullink", "armor", "stone" }

function R.Snooze(key)
    R.snoozed[key] = GetTime() + SNOOZE
    ns.MarkDirty()
end

function R.Disable(key)
    ns.db.remind[key] = false
    ns.Print(("'%s' reminder turned off. Turn it back on in /swh options."):format(R.LABEL[key] or key))
    ns.MarkDirty()
end

-- One reminder: what to show and what a click does.
-- state: "missing" or "expiring"; remaining: seconds left when expiring.
local function entry(key, spell, text, state, remaining)
    return {
        key = key, icon = spell.icon, title = spell.name, text = text,
        spell = spell.name, state = state or "missing", remaining = remaining,
    }
end

local function ArmorSpell()
    return S.Resolve(D.DEMON_ARMOR) or S.Resolve(D.DEMON_SKIN)
end

local function SummonSpell(petKey)
    local def = petKey and D.PETS[petKey]
    if not def then return nil end
    for _, s in ipairs(def.summons) do
        local spell = S.Resolve(s)
        if spell then return spell end
    end
end

-- The demon to offer when none is out: the last one summoned, else the first one known.
local function DemonToSummon()
    local spell = SummonSpell(ns.cdb.lastPet)
    if spell then return spell end
    for i = #D.PET_ORDER, 1, -1 do
        spell = SummonSpell(D.PET_ORDER[i])
        if spell then return spell end
    end
end

function R.Build()
    local list = {}
    local db, now = ns.db, S.now
    if S.dead or S.mounted then return list end
    if S.inCombat and not db.combat then return list end

    local function add(e)
        if not e or not db.remind[e.key] then return end
        if R.snoozed[e.key] and R.snoozed[e.key] > now then return end
        list[#list + 1] = e
    end
    -- "Running out" only counts out of combat: nobody rebuffs mid-fight for a timer.
    local function expiring(remaining)
        return not S.inCombat and remaining and remaining < (db.expiring or 0)
    end

    -- Demon
    if not S.pet.exists and S.noPetSince and now - S.noPetSince >= NO_DEMON_GRACE then
        local sacrificed = S.BuffStatus("sacrifice", D.SACRIFICE) == "up"
        local pact = S.Talent("demonic pact") > 0
        if not sacrificed or pact then
            local spell = DemonToSummon()
            if spell then
                add(entry("demon", spell, sacrificed and "No demon out. Demonic Pact lets you keep a second one."
                    or "No demon out."))
            end
        end
    end

    -- Soul Link: only matters with a living demon
    if S.soulLinkKnown and S.pet.exists and S.pet.alive then
        local status = S.BuffStatus("soullink", D.SOUL_LINK)
        if status == "down" then
            local spell = S.Resolve(D.SOUL_LINK) or { name = D.SOUL_LINK.name, icon = D.SOUL_LINK.icon }
            add(entry("soullink", spell, "Soul Link is not on your demon."))
        end
    end

    -- Demon Armor / Demon Skin
    local armor = ArmorSpell()
    if armor then
        local status, remaining = S.BuffStatus("armor", D.ARMOR_AURA)
        if status == "down" then
            add(entry("armor", armor, armor.name .. " is missing."))
        elseif status == "up" and expiring(remaining) then
            add(entry("armor", armor, armor.name .. " is about to run out.", "expiring", remaining))
        end
    end

    -- Firestone / Spellstone on the weapon
    -- (the stone that matches the school picked in the window comes first)
    local first, second = D.SPELLSTONE, D.FIRESTONE
    if ns.cdb.school == "fire" then first, second = second, first end
    local stoneDef = S.Resolve(first) and first or (S.Resolve(second) and second)
    if stoneDef and S.weapon.equipped and S.weapon.enchanted ~= nil then
        local create = S.Resolve(stoneDef)
        local missing = not S.weapon.enchanted
        if missing or expiring(S.weapon.remaining) then
            local e = entry("stone", create, missing and "No Firestone or Spellstone on your weapon."
                or "Your weapon stone is about to run out.", missing and "missing" or "expiring", S.weapon.remaining)
            if not S.inCombat then
                -- Use a stone from the bags when there is one; otherwise make one.
                local item = S.FindBagItem(first.item) or S.FindBagItem(second.item)
                if item then
                    e.spell, e.macro, e.title = nil, "/use " .. item .. "\n/use 16", item
                end
            end
            add(e)
        end
    end

    return list
end

-- Sample list for /swh demo.
function R.DemoList()
    return {
        { key = "soullink", icon = D.SOUL_LINK.icon, title = "Soul Link", text = "Soul Link is not on your demon.",
          state = "missing" },
        { key = "armor", icon = D.DEMON_ARMOR.icon, title = "Demon Armor", text = "Demon Armor is about to run out.",
          state = "expiring", remaining = 95 },
    }
end
