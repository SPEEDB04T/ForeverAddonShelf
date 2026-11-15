-- Imbue Advisor: core (settings, API compatibility, events, slash commands)
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.4.2"
ns.current = {}   -- [16]/[17] = imbue key currently on that weapon (or nil)

local defaults = {
    mode = "auto",              -- auto | melee | tank | caster | heal | pvp
    shown = true,
    locked = false,
    scale = 1,
    point = nil,
    targetLevelDiff = 0,        -- 0 = same-level mobs, 3 = raid boss
    warnMissing = true,         -- warn when entering combat without an imbue
    windfuryOffhandProcs = true,
    windfurySharedCooldown = true,
    tankRockbiterThreat = 2.0,  -- threat multiplier for Rockbiter in tank mode
    pvpSlowBonus = 0.5,         -- Frostbrand slow is worth +50% of the best dps option in PvP
    enchantCache = {},          -- enchantID -> imbue key, learned from tooltips
    others = "hover",           -- the list of other imbues: hover | always | off
    picks = {},                 -- "Name-Realm" -> { [16] = key, [17] = key }: imbues you chose yourself
}

----------------------------------------------------------------------
-- Imbue definitions. IDs cover Classic/TBC/Wrath ranks plus modern IDs;
-- if WoW Forever uses new IDs the addon falls back to the spell name.
----------------------------------------------------------------------
ns.IMBUE_ORDER = { "windfury", "flametongue", "frostbrand", "rockbiter", "earthliving" }
ns.IMBUES = {
    windfury = {
        english = "Windfury Weapon", token = "Windfury", short = "WF",
        ids = { 8232, 8235, 10486, 16362, 25505, 58801, 58803, 58804, 33757 },
        icon = "Interface\\Icons\\Spell_Nature_Cyclone",
    },
    flametongue = {
        english = "Flametongue Weapon", token = "Flametongue", short = "FT",
        ids = { 8024, 8027, 8030, 16339, 16341, 16342, 25489, 58785, 58789, 58790, 318038 },
        icon = "Interface\\Icons\\Spell_Fire_FlameTounge",
    },
    frostbrand = {
        english = "Frostbrand Weapon", token = "Frostbrand", short = "FB",
        ids = { 8033, 8038, 10456, 16355, 16356, 25500, 58794, 58795, 58796 },
        icon = "Interface\\Icons\\Spell_Frost_FrostBrand",
    },
    rockbiter = {
        english = "Rockbiter Weapon", token = "Rockbiter", short = "RB",
        ids = { 8017, 8018, 8019, 10399, 16314, 16315, 16316, 25479, 25485 },
        icon = "Interface\\Icons\\Spell_Nature_RockBiter",
    },
    earthliving = {
        english = "Earthliving Weapon", token = "Earthliving", short = "EL",
        ids = { 51730, 51988, 51991, 51992, 51993, 51994, 382021 },
        icon = "Interface\\Icons\\Spell_Shaman_GiftEarthmother",
    },
}

----------------------------------------------------------------------
-- Helpers / API compatibility (classic-style and retail-style clients)
----------------------------------------------------------------------
-- the name in the shaman class colour, as the game writes class names
local function PrintPrefix()
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.SHAMAN
    local hex = c and c.colorStr or "ff0070dd"
    return "|c" .. hex .. "Imbue Advisor|r: "
end

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PrintPrefix() .. tostring(msg))
end

function ns.SpellInfo(spell)
    if spell == nil then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spell)
        if ok and type(info) == "table" then return info.name, info.iconID, info.spellID end
        if ok then return nil end
    end
    if GetSpellInfo then
        local name, _, icon, _, _, _, spellID = GetSpellInfo(spell)
        return name, icon, spellID
    end
end

function ns.SpellDescription(id)
    local desc
    if C_Spell and C_Spell.GetSpellDescription then
        desc = C_Spell.GetSpellDescription(id)
    elseif GetSpellDescription then
        desc = GetSpellDescription(id)
    end
    if desc == "" then desc = nil end
    return desc
end

function ns.RequestSpellData(id)
    if C_Spell and C_Spell.RequestLoadSpellData then
        pcall(C_Spell.RequestLoadSpellData, id)
    end
end

function ns.ItemInfoInstant(item)
    if not item then return end
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if f then return f(item) end
end

local function PlayerKnows(id)
    local any = false
    for _, f in ipairs({ IsPlayerSpell or false, IsSpellKnown or false }) do
        if f then
            any = true
            local ok, known = pcall(f, id)
            if ok and known then return true end
        end
    end
    if not any then return nil end    -- nil = can't tell on this client
    return false
end

-- Returns { key, spellID, name, icon } for the highest known rank, or nil.
function ns.ResolveImbue(key)
    local def = ns.IMBUES[key]
    local knownID
    for i = #def.ids, 1, -1 do
        if PlayerKnows(def.ids[i]) then knownID = def.ids[i]; break end
    end
    if not knownID then
        -- Name lookup only resolves spells in the spellbook (catches new spell IDs).
        local names = { def.english }
        local localName = ns.SpellInfo(def.ids[1])
        if localName and localName ~= def.english then table.insert(names, 1, localName) end
        for _, n in ipairs(names) do
            local _, _, id = ns.SpellInfo(n)
            if id and PlayerKnows(id) ~= false then knownID = id; break end
        end
    end
    if not knownID then return nil end
    local name, icon, id = ns.SpellInfo(knownID)
    return { key = key, spellID = id or knownID, name = name or def.english, icon = icon or def.icon }
end

function ns.WeaponEnchants()
    local hasMH, mhExp, mhCharges, mhID, hasOH, ohExp, ohCharges, ohID = GetWeaponEnchantInfo()
    return {
        [16] = { has = hasMH and true or false, exp = mhExp and mhExp / 1000, id = mhID },
        [17] = { has = hasOH and true or false, exp = ohExp and ohExp / 1000, id = ohID },
    }
end

----------------------------------------------------------------------
-- Your own picks: an imbue you chose for a hand is used there instead of the advisor's,
-- on this character, until you go back.
----------------------------------------------------------------------
function ns.Pick(slot)
    local mine = ns.db and ns.db.picks and ns.charKey and ns.db.picks[ns.charKey]
    return mine and mine[slot] or nil
end

-- The imbue a hand's button casts: your pick while you still know it, else the advisor's.
-- Returns the key, and true when it is your own pick and not the advisor's.
function ns.UseKey(res, slot)
    local sr = res and res.slots[slot]
    if not sr or not sr.best then return nil, false end
    local pick = ns.Pick(slot)
    if pick and pick ~= sr.best and sr.scores[pick] and res.imbues[pick] then return pick, true end
    return sr.best, false
end

-- key = nil goes back to the advisor's pick for that hand.
function ns.SetPick(slot, key)
    if not ns.charKey then return end
    if type(ns.db.picks) ~= "table" then ns.db.picks = {} end
    local picks = ns.db.picks
    local mine = picks[ns.charKey]
    if key then
        if not mine then mine = {}; picks[ns.charKey] = mine end
        mine[slot] = key
    elseif mine then
        mine[slot] = nil
        if next(mine) == nil then picks[ns.charKey] = nil end
    end
    ns.PicksChanged()
end

function ns.ClearPicks()
    if ns.charKey and type(ns.db.picks) == "table" then ns.db.picks[ns.charKey] = nil end
    ns.PicksChanged()
end

function ns.HasPicks()
    return (ns.Pick(16) or ns.Pick(17)) and true or false
end

----------------------------------------------------------------------
-- Which imbue is on a weapon right now (tooltip scan, cached by enchant ID)
----------------------------------------------------------------------
local scanTip
local function TooltipLines(slot)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local data = C_TooltipInfo.GetInventoryItem("player", slot)
        if data and data.lines then
            for _, l in ipairs(data.lines) do
                if l.leftText then lines[#lines + 1] = l.leftText end
            end
        end
        return lines
    end
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "ImbueAdvisorScanTip", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    scanTip:SetInventoryItem("player", slot)
    for i = 1, scanTip:NumLines() do
        local fs = _G["ImbueAdvisorScanTipTextLeft" .. i]
        local t = fs and fs:GetText()
        if t then lines[#lines + 1] = t end
    end
    scanTip:Hide()
    return lines
end

local tokens
local function Tokens()
    if tokens then return tokens end
    tokens = {}
    for _, key in ipairs(ns.IMBUE_ORDER) do
        local def = ns.IMBUES[key]
        tokens[#tokens + 1] = { key, def.token:lower() }
        local localName = ns.SpellInfo(def.ids[1])
        if localName then tokens[#tokens + 1] = { key, localName:lower() } end
    end
    return tokens
end

function ns.ImbueFromTooltip(slot)
    local lines = TooltipLines(slot)
    -- pass 1: lines with a duration, e.g. "Windfury 3 (30 min)"; pass 2: any line
    for pass = 1, 2 do
        for i = 2, #lines do
            local L = lines[i]:lower()
            if pass == 2 or L:find("%(%d+%s*%a+%)") then
                for _, t in ipairs(Tokens()) do
                    if L:find(t[2], 1, true) then return t[1] end
                end
            end
        end
    end
end

function ns.ScanCurrent()
    local ench = ns.WeaponEnchants()
    for _, slot in ipairs({ 16, 17 }) do
        local e = ench[slot]
        if not e.has then
            ns.current[slot] = nil
        elseif e.id and ns.db.enchantCache[e.id] then
            ns.current[slot] = ns.db.enchantCache[e.id]
        else
            local key = ns.ImbueFromTooltip(slot)
            ns.current[slot] = key
            if key and e.id then ns.db.enchantCache[e.id] = key end
        end
    end
end

----------------------------------------------------------------------
-- Refresh loop (throttled; full recalculation only out of combat)
----------------------------------------------------------------------
local driver = CreateFrame("Frame")
local dirty, currentDirty, elapsed, statusElapsed = true, true, 0, 0

function ns.MarkDirty() dirty = true end
function ns.MarkCurrentDirty() currentDirty = true end

function ns.Refresh()
    local ok, res = pcall(ns.Calc.Evaluate, ns.db)
    if not ok then
        if not ns.errShown then ns.Print("calculation error: " .. tostring(res)); ns.errShown = true end
        return
    end
    ns.result = res
    ns.UI.Update(res)
end

local function OnUpdate(_, e)
    elapsed = elapsed + e
    statusElapsed = statusElapsed + e
    if elapsed >= 0.5 then
        elapsed = 0
        if currentDirty then currentDirty = false; ns.ScanCurrent() end
        if dirty and not InCombatLockdown() then dirty = false; ns.Refresh() end
    end
    if statusElapsed >= 1 then
        statusElapsed = 0
        ns.UI.UpdateStatus()
    end
end

-- The off hand is worked out for what the main hand uses, so a new pick means a new calculation.
-- In a fight the buttons can't change: everything waits for the fight to end.
function ns.PicksChanged()
    dirty = true
    if InCombatLockdown() then
        ns.UI.pending = true
        ns.Print("the buttons change when the fight is over.")
    elseif ns.enabled then
        dirty = false
        ns.Refresh()
    end
end

local function WarnMissing()
    if not ns.db.warnMissing or not ns.result then return end
    local ench = ns.WeaponEnchants()
    for _, slot in ipairs({ 16, 17 }) do
        local key = ns.UseKey(ns.result, slot)
        if key and not ench[slot].has then
            local name = ns.result.imbues[key].name
            -- red like the game's own error messages
            local r, g, b = 1.0, 0.125, 0.125
            if RED_FONT_COLOR and RED_FONT_COLOR.GetRGB then r, g, b = RED_FONT_COLOR:GetRGB() end
            UIErrorsFrame:AddMessage(("No imbue on %s: use %s"):format(slot == 16 and "main hand" or "off hand", name), r, g, b)
        end
    end
end

local playerEvents = {
    UNIT_INVENTORY_CHANGED = true, UNIT_ATTACK_POWER = true, UNIT_ATTACK_SPEED = true,
    UNIT_DAMAGE = true, UNIT_AURA = true,
}
local globalEvents = {
    "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP",
    "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED",
    "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_ROLES_ASSIGNED", "GROUP_ROSTER_UPDATE",
    "ZONE_CHANGED_NEW_AREA", "SPELL_DATA_LOAD_RESULT", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
}

local function OnEvent(_, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        ns.UI.CombatStart()     -- hiding is still allowed here; a moment later it is not
        WarnMissing()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.UI.ApplySecure()
        dirty = true
        return
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        currentDirty = true
    end
    dirty = true
end

local function Init()
    ImbueAdvisorDB = ImbueAdvisorDB or {}
    for k, v in pairs(defaults) do
        if ImbueAdvisorDB[k] == nil then
            ImbueAdvisorDB[k] = type(v) == "table" and {} or v
        end
    end
    ns.db = ImbueAdvisorDB
    if ns.db.others ~= "hover" and ns.db.others ~= "always" and ns.db.others ~= "off" then ns.db.others = "hover" end
    ns.charKey = (UnitName("player") or "?") .. "-" .. (GetRealmName and GetRealmName() or "")

    local _, class = UnitClass("player")
    if class ~= "SHAMAN" then return end
    ns.enabled = true

    ns.UI.Create()
    if ns.Kit and ns.Options then       -- both missing until the first full restart after the update
        local ok, err = pcall(ns.Options.Init)
        if not ok then ns.Print("options error: " .. tostring(err)) end
    end
    for ev in pairs(playerEvents) do
        if driver.RegisterUnitEvent then
            pcall(driver.RegisterUnitEvent, driver, ev, "player")
        else
            pcall(driver.RegisterEvent, driver, ev)
        end
    end
    for _, ev in ipairs(globalEvents) do pcall(driver.RegisterEvent, driver, ev) end
    driver:SetScript("OnEvent", function(self, event, arg1)
        if playerEvents[event] and arg1 and arg1 ~= "player" then return end
        OnEvent(self, event, arg1)
    end)
    driver:SetScript("OnUpdate", OnUpdate)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", Init)

----------------------------------------------------------------------
-- Actions shared by the slash commands, the options window and the minimap button
----------------------------------------------------------------------
function ns.ToggleFrame()
    if InCombatLockdown() then ns.Print("can't toggle in combat.") return end
    ns.db.shown = not ns.db.shown
    ns.UI.ApplySecure()
end

function ns.ResetSettings()
    if InCombatLockdown() then ns.Print("can't reset in combat.") return end
    local cache, picks = ns.db.enchantCache, ns.db.picks
    for k in pairs(ns.db) do ns.db[k] = nil end
    for k, v in pairs(defaults) do ns.db[k] = type(v) == "table" and {} or v end
    ns.db.enchantCache = cache
    if type(picks) == "table" then      -- your other characters keep the imbues they picked
        if ns.charKey then picks[ns.charKey] = nil end
        ns.db.picks = picks
    end
    ns.UI.RestorePosition(); ns.UI.frame:SetScale(1); ns.MarkDirty()
    ns.UI.ApplySecure()
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.Print("settings reset")
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
-- Kit.lua and Options.lua are new in 1.1.0. The game only finds new files after a full restart,
-- so right after an update a /reload runs this file without them: say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    ns.Print("the options window and the minimap button appear after you restart the game once (this update added new files, and /reload does not load those).")
    return false
end

local MODES = { auto = true, melee = true, tank = true, caster = true, heal = true, pvp = true }
local OTHERS = { hover = "opens when you point at the frame", always = "always open", off = "off" }
local HANDS = { mh = 16, main = 16, mainhand = 16, oh = 17, off = 17, offhand = 17 }

-- "wf", "windfury", "wind": which imbue was typed
local function ImbueFromWord(word)
    if not word or word == "" then return nil end
    for _, key in ipairs(ns.IMBUE_ORDER) do
        if ns.IMBUES[key].short:lower() == word or key:sub(1, #word) == word then return key end
    end
end

local function PickCommand(arg)
    local hand, word = arg:match("^(%S+)%s+(%S+)")
    local slot = hand and HANDS[hand]
    local res = ns.result
    if not slot or not word then
        ns.Print("usage: /imbue pick mh|oh windfury|flametongue|frostbrand|rockbiter|earthliving|advisor")
        return
    end
    local hname = slot == 16 and "main hand" or "off hand"
    if word == "advisor" or word == "auto" or word == "best" then
        ns.SetPick(slot, nil)
        ns.Print(hname .. ": back to the advisor's pick")
        return
    end
    local key = ImbueFromWord(word)
    if not key then
        ns.Print("no imbue called '" .. word .. "'. Try wf, ft, fb, rb or el.")
    elseif not res or not res.slots[slot] or not res.slots[slot].best then
        ns.Print("nothing to imbue in your " .. hname .. ".")
    elseif not res.imbues[key] then
        ns.Print("you don't know " .. ns.IMBUES[key].english .. ".")
    else
        ns.SetPick(slot, key ~= res.slots[slot].best and key or nil)
        ns.Print(hname .. ": " .. res.imbues[key].name .. " from now on")
    end
end

local function Help()
    ns.Print("commands:")
    ns.Print("  /imbue  - show or hide the frame")
    ns.Print("  /imbue config  - open the options window")
    ns.Print("  /imbue minimap  - show or hide the minimap button")
    ns.Print("  /imbue mode auto|melee|tank|caster|heal|pvp  (now: " .. ns.db.mode .. ")")
    ns.Print("  /imbue report  - print the numbers behind the recommendation")
    ns.Print("  /imbue others hover|always|off  - the list of your other imbues (now: " .. tostring(ns.db.others) .. ")")
    ns.Print("  /imbue pick mh|oh <imbue>  - use an imbue of your own choice on that hand")
    ns.Print("  /imbue advisor  - go back to the advisor's picks")
    ns.Print("  /imbue target <0-3>  - target level difference (now: " .. ns.db.targetLevelDiff .. ")")
    ns.Print("  /imbue lock | unlock | scale <0.5-2> | warn | reset | debug")
end

SLASH_IMBUEADVISOR1 = "/imbue"
SLASH_IMBUEADVISOR2 = "/ia"
SlashCmdList.IMBUEADVISOR = function(msg)
    if not ns.db then return end
    if not ns.enabled then ns.Print("only works on a Shaman.") return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" then
        ns.ToggleFrame()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if HasKit() then ns.Kit.Open() end
    elseif cmd == "minimap" then
        if HasKit() then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("minimap button " .. (ns.Kit.MinimapShown() and "on" or "off"))
        end
    elseif cmd == "mode" then
        if MODES[arg] then
            ns.db.mode = arg; ns.MarkDirty(); ns.Print("mode set to " .. arg)
        else
            ns.Print("modes: auto, melee, tank, caster, heal, pvp")
        end
    elseif cmd == "others" or cmd == "other" then
        if OTHERS[arg] then
            ns.db.others = arg; ns.UI.ApplySecure(); ns.Print("other imbues: " .. OTHERS[arg])
        else
            ns.Print("usage: /imbue others hover|always|off   (now: " .. tostring(ns.db.others) .. ")")
        end
    elseif cmd == "pick" or cmd == "use" then
        PickCommand(arg)
    elseif cmd == "advisor" then
        ns.ClearPicks(); ns.Print("back to the advisor's picks")
    elseif cmd == "report" then
        ns.UI.PrintReport()
    elseif cmd == "debug" then
        ns.UI.PrintDebug()
    elseif cmd == "target" then
        local n = tonumber(arg)
        if n and n >= -5 and n <= 5 then
            ns.db.targetLevelDiff = n; ns.MarkDirty(); ns.Print("target level difference: " .. n)
        else
            ns.Print("usage: /imbue target 0   (3 for raid bosses)")
        end
    elseif cmd == "lock" or cmd == "unlock" then
        ns.db.locked = (cmd == "lock"); ns.Print(ns.db.locked and "frame locked" or "frame unlocked (drag to move)")
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 and not InCombatLockdown() then
            ns.db.scale = n; ns.UI.frame:SetScale(n)
        else
            ns.Print("usage: /imbue scale 1.2 (out of combat)")
        end
    elseif cmd == "warn" then
        ns.db.warnMissing = not ns.db.warnMissing
        ns.Print("missing-imbue warning " .. (ns.db.warnMissing and "on" or "off"))
    elseif cmd == "reset" then
        ns.ResetSettings()
    else
        Help()
    end
    if ns.Kit then ns.Kit.Sync() end      -- an open options window follows what was typed
end
