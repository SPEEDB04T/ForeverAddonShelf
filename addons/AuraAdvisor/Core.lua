-- Aura Advisor: core (settings, your auras, events, the thinking loop, slash commands)
local ADDON, ns = ...
local Data, Signals, Advisor = ns.Data, ns.Signals, ns.Advisor

ns.ADDON = ADDON
do
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = false, nil
    if get then ok, v = pcall(get, ADDON or "AuraAdvisor", "Version") end
    ns.VERSION = (ok and type(v) == "string") and v or "?"
end

local defaults = {
    glow = true,                -- the game's spell-alert glow on the aura to switch to
    style = "auto",             -- auto | damage | tank | healer
    idle = "auto",              -- the aura between fights: auto | devotion | retribution | concentration
    sensitivity = "normal",     -- low | normal | high
    betweenFights = true,       -- suggest going back to the default aura after a fight
    sound = true,
    banner = true,              -- a line in the middle of the screen
    chat = false,               -- a line in the chat window
}
local CHOICES = {
    style = { auto = true, damage = true, tank = true, healer = true },
    idle = { auto = true, devotion = true, retribution = true, concentration = true },
    sensitivity = { low = true, normal = true, high = true },
}
local RANGES = {}
-- 1.0-1.1 had a bar of its own; 1.2 shows the advice on the game's bars. Its settings go.
local OLD_KEYS = { "show", "locked", "scale", "idleAlpha", "point", "v110" }

local TICK = 0.4                -- seconds between two looks at the fight
local HOLD = 0.8                -- a suggestion must stand this long before it is shown
local REALERT = 10              -- seconds before the same aura is announced again
local FORGET_AFTER = 6          -- seconds after a fight before its hits are forgotten

ns.known = {}                   -- key -> { key, name, icon, spellID, form }
ns.knownSet = {}                -- key -> true
ns.buffOthers = {}              -- key -> name: auras other paladins have on you (seen on your buffs)
ns.castOthers = {}              -- name -> key: auras party paladins were seen casting

local Plain, Secret = Signals.Plain, Signals.Secret

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cfff58cbaAura Advisor|r: " .. tostring(msg))
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local function Repair(db)
    for key, value in pairs(defaults) do
        local have = db[key]
        if type(have) ~= type(value) then
            db[key] = value
        elseif CHOICES[key] and not CHOICES[key][have] then
            db[key] = value
        elseif RANGES[key] then
            if have ~= have then have = value end
            db[key] = math.max(RANGES[key][1], math.min(RANGES[key][2], have))
        end
    end
    for _, key in ipairs(OLD_KEYS) do db[key] = nil end
end

-- Only real settings, and only values of the right kind.
function ns.Set(key, value)
    if defaults[key] == nil or type(value) ~= type(defaults[key]) then return false end
    if CHOICES[key] and not CHOICES[key][value] then return false end
    if RANGES[key] then value = math.max(RANGES[key][1], math.min(RANGES[key][2], value)) end
    ns.db[key] = value
    ns.thinkNow = true
    return true
end

----------------------------------------------------------------------
-- Spells
----------------------------------------------------------------------
function ns.SpellInfo(spell)
    if spell == nil then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spell)
        if ok and type(info) == "table" then return Plain(info.name), Plain(info.iconID), Plain(info.spellID) end
        if ok then return nil end
    end
    if GetSpellInfo then
        local ok, name, _, icon, _, _, _, spellID = pcall(GetSpellInfo, spell)
        if ok then return Plain(name), Plain(icon), Plain(spellID) end
    end
end

local function PlayerKnows(id)
    for _, f in ipairs({ IsPlayerSpell or false, IsSpellKnown or false }) do
        if f then
            local ok, known = pcall(f, id)
            if ok and Plain(known) then return true end
        end
    end
    return false
end

-- Aura names as this client spells them (and in English), lower case -> key
local names
local function Names()
    if names then return names end
    names = {}
    for key, def in pairs(Data.AURAS) do
        names[def.english:lower()] = key
        local localName = ns.SpellInfo(def.ids[1])
        if type(localName) == "string" then names[localName:lower()] = key end
    end
    return names
end

function ns.KeyFromSpell(id, name)
    if type(id) == "number" and Data.KEY_BY_ID[id] then return Data.KEY_BY_ID[id] end
    if type(name) ~= "string" and type(id) == "number" then name = ns.SpellInfo(id) end
    if type(name) == "string" then return Names()[name:lower()] end
end

----------------------------------------------------------------------
-- Your auras: which you know, and which one is on
----------------------------------------------------------------------
-- Paladin auras sit on the stance bar: it lists them and says which one is on.
function ns.ScanForms()
    local forms, active, readable, listed = {}, nil, true, false
    local n = 0
    if GetNumShapeshiftForms then
        local ok, v = pcall(GetNumShapeshiftForms)
        if ok and type(Plain(v)) == "number" then n = v end
    end
    for i = 1, n do
        local ok, _, isActive, _, spellID = pcall(GetShapeshiftFormInfo, i)
        if ok then
            local key = ns.KeyFromSpell(Plain(spellID))
            if key then
                listed = true
                forms[key] = i
                if Secret(isActive) then
                    readable = false
                elseif isActive then
                    active = key
                end
            end
        end
    end
    ns.forms, ns.formsListed, ns.formsReadable = forms, listed, readable
    if listed and readable then
        ns.formCurrent = active
        ns.seenCurrent = active
    end
end

function ns.ResolveAuras()
    local known, set = {}, {}
    ns.ScanForms()
    for key, def in pairs(Data.AURAS) do
        local id
        for i = #def.ids, 1, -1 do
            if PlayerKnows(def.ids[i]) then id = def.ids[i]; break end
        end
        if not id then
            -- A lookup by name only finds spells in the spellbook (this catches new spell IDs).
            local _, _, byName = ns.SpellInfo(def.english)
            if byName then id = byName end
        end
        if not id and ns.forms[key] then id = def.ids[1] end
        if id then
            local name, icon, spellID = ns.SpellInfo(id)
            known[key] = { key = key, spellID = spellID or id, name = name or def.english,
                           icon = icon or def.icon, form = ns.forms[key] }
            set[key] = true
        end
    end
    ns.known, ns.knownSet = known, set
end

function ns.CurrentAura()
    if ns.formsListed and ns.formsReadable then return ns.formCurrent end
    return ns.seenCurrent
end

-- Your own buffs show your aura, the auras other paladins have on you, and Righteous Fury.
-- In a fight the game hides buffs: then this returns false and the last look stands.
function ns.ScanBuffs()
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if ok and secret then return false end
    end
    local own, others, fury = nil, {}, false
    local furyName = ns.SpellInfo(Data.RIGHTEOUS_FURY.id)
    for i = 1, 60 do
        local name, spellID, source
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or Secret(data) then return false end
            if data == nil then break end
            local read
            read, name, spellID, source = pcall(function() return data.name, data.spellId, data.sourceUnit end)
            if not read then return false end
        elseif UnitBuff then
            local ok, n, _, _, _, _, _, src, _, _, id = pcall(UnitBuff, "player", i)
            if not ok or Secret(n) then return false end
            if n == nil then break end
            name, spellID, source = n, id, src
        else
            return false
        end
        if Secret(name) or Secret(spellID) or Secret(source) then return false end
        local key = ns.KeyFromSpell(spellID, name)
        if key then
            if source == "player" then
                own = key
            elseif type(source) == "string" then
                local ok, who = pcall(UnitName, source)
                others[key] = (ok and type(Plain(who)) == "string") and who or true
            end
        elseif spellID == Data.RIGHTEOUS_FURY.id or name == Data.RIGHTEOUS_FURY.english
            or (furyName and name == furyName) then
            fury = true
        end
    end
    ns.buffOthers, ns.castOthers, ns.fury = others, {}, fury
    if not (ns.formsListed and ns.formsReadable) then ns.seenCurrent = own end
    return true
end

-- key -> who: auras another paladin already gives your party
function ns.OtherAuras()
    local taken = {}
    for key, who in pairs(ns.buffOthers) do taken[key] = who end
    for who, key in pairs(ns.castOthers) do taken[key] = who end
    return taken
end

local PARTY = { party1 = true, party2 = true, party3 = true, party4 = true }

local function PartyAuraCast(unit, spellID)
    local key = ns.KeyFromSpell(Plain(spellID))
    if not key then return end
    local ok, who = pcall(UnitName, unit)
    who = (ok and type(Plain(who)) == "string") and who or unit
    for k, name in pairs(ns.buffOthers) do
        if name == who then ns.buffOthers[k] = nil end      -- that paladin switched
    end
    ns.castOthers[who] = key
end

-- Paladins who left the party take their aura with them.
local function PruneOthers()
    local here = {}
    for unit in pairs(PARTY) do
        local ok, who = pcall(UnitName, unit)
        if ok and type(Plain(who)) == "string" then here[who] = true end
    end
    for who in pairs(ns.castOthers) do
        if not here[who] then ns.castOthers[who] = nil end
    end
    for key, who in pairs(ns.buffOthers) do
        if type(who) == "string" and not here[who] then ns.buffOthers[key] = nil end
    end
end

-- Returns the play style the advice is for, and why.
function ns.Style()
    local chosen = ns.db.style
    if chosen ~= "auto" then return chosen, "you chose it" end
    if UnitGroupRolesAssigned then
        local ok, role = pcall(UnitGroupRolesAssigned, "player")
        role = ok and Plain(role) or nil
        if role == "TANK" then return "tank", "your group role" end
        if role == "HEALER" then return "healer", "your group role" end
    end
    if ns.fury then return "tank", "Righteous Fury is on" end
    return "damage", "no tank or healer role, no Righteous Fury"
end

----------------------------------------------------------------------
-- The thinking loop
----------------------------------------------------------------------
local pending = { key = nil, since = 0 }
local lastAlert = {}

-- An aura in at most two words, for what shows during play: its own name when that is two
-- words ("Devotion Aura"), else the short one ("Fire Resistance").
function ns.TwoWords(key)
    local info, def = ns.known[key], Data.AURAS[key]
    local name = info and info.name
    if type(name) == "string" and select(2, name:gsub("%S+", "")) <= 2 then return name end
    return def and def.short or tostring(name)
end

-- The aura's icon and name, "|T...|t Fire Resistance": nothing else shows in play.
function ns.IconName(key)
    local info = ns.known[key]
    local text = ns.TwoWords(key)
    local get = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
    if info and info.spellID and get then
        local ok, tex = pcall(get, info.spellID)
        tex = ok and Plain(tex) or nil
        if type(tex) == "number" or (type(tex) == "string" and tex ~= "") then
            text = "|T" .. tex .. ":0|t " .. text
        end
    end
    return text
end

local function Alert(res, now)
    local info = ns.known[res.shown]
    if not info then return end
    if lastAlert[res.shown] and now - lastAlert[res.shown] < REALERT then return end
    lastAlert[res.shown] = now
    -- The aura and nothing else; the cause is in its tooltip.
    local text = ns.IconName(res.shown)
    if ns.db.banner and UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(text, 1, 0.82, 0.2)
    end
    if ns.db.chat then DEFAULT_CHAT_FRAME:AddMessage("|cfff58cba" .. text .. "|r") end
    if ns.db.sound and PlaySound then
        pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master")
    end
end

-- UnitIsDeadOrGhost when the game shows it; else what PLAYER_DEAD / PLAYER_ALIVE / PLAYER_UNGHOST said.
function ns.IsDead()
    if UnitIsDeadOrGhost then
        local ok, dead = pcall(UnitIsDeadOrGhost, "player")
        if ok and not Secret(dead) and dead ~= nil then return dead and true or false end
    end
    return ns.deadFlag and true or false
end

function ns.Think(now)
    Signals.ScanEnemies(now)
    local sum = Signals.Summary(now)
    local style, styleWhy = ns.Style()
    local res = Advisor.Advise(sum, {
        known = ns.knownSet, current = ns.CurrentAura(), others = ns.OtherAuras(),
        style = style, idle = ns.db.idle, sensitivity = ns.db.sensitivity,
        sticky = ns.sticky, betweenFights = ns.db.betweenFights,
    })
    res.style, res.styleWhy = style, styleWhy
    ns.sticky = res.suggest

    -- Dead or a ghost: your aura is gone and nothing can be cast, so say nothing at all (no
    -- glow, sound, banner, chat or tooltip line) until you're back on your feet.
    if ns.IsDead() then
        pending.key, ns.held, ns.shownKey, ns.sticky = nil, nil, nil, nil
        res.dead = true
        ns.result, ns.summary = res, sum
        if ns.UI then ns.UI.Update(res) end
        return res
    end

    -- A suggestion is shown once it has stood for a moment. In a fight it then stays until you
    -- switch, another suggestion takes its place or the fight ends: hits come in bursts, and a
    -- pause between two pulls of a boss is no reason to take it down.
    if res.suggest ~= pending.key then pending.key, pending.since = res.suggest, now end
    local fresh = res.suggest and (res.suggest == ns.shownKey or now - pending.since >= HOLD)
    local held = ns.held
    if fresh then
        res.shown = res.suggest
        if held and ns.inCombat and held.key == res.suggest and not res.why[res.suggest] then
            -- still ahead, but the hits behind it have faded: keep saying why it came up
            res.reason, res.held = held.reason, true
        else
            ns.held = ns.inCombat and { key = res.suggest, reason = res.reason } or nil
        end
    elseif held and ns.inCombat and held.key ~= res.current and ns.knownSet[held.key]
        and not ns.OtherAuras()[held.key] then
        res.shown, res.reason, res.held = held.key, held.reason, true
    else
        ns.held = nil
    end
    local changed = res.shown ~= ns.shownKey
    ns.shownKey = res.shown
    ns.result, ns.summary = res, sum
    -- Between fights the glow alone says it; sound and banner are for fights.
    if changed and res.shown and (not res.quiet or (not res.current and ns.inCombat)) then
        Alert(res, now)
    end
    if ns.UI then ns.UI.Update(res) end
    return res
end

local driver = CreateFrame("Frame")
local elapsed, buffTry = 0, 0
local knownDirty, formsDirty, buffDirty = true, true, true

local function OnUpdate(_, dt)
    elapsed = elapsed + dt
    if elapsed < TICK and not ns.thinkNow then return end
    elapsed = 0
    ns.thinkNow = nil
    local now = GetTime()
    if ns.forgetAt and now >= ns.forgetAt and not ns.inCombat then
        ns.forgetAt = nil
        if not ns.testing then Signals.Reset() end
    end
    if knownDirty then
        knownDirty, formsDirty = false, false
        ns.ResolveAuras()
        ns.UI.Refresh()
    elseif formsDirty then
        formsDirty = false
        ns.ScanForms()
    end
    if buffDirty and now >= buffTry then
        buffTry = now + 2
        if ns.ScanBuffs() then buffDirty = false end
    end
    local ok, err = pcall(ns.Think, now)
    if not ok and not ns.thinkError then
        ns.thinkError = Plain(err) and tostring(err) or "a hidden value"
        ns.Print("error (said once): " .. ns.thinkError)
    end
end

local function OnEvent(_, event, a1, a2, a3, a4, a5)
    if event == "UNIT_COMBAT" then
        Signals.OnUnitCombat(a1, a2, a3, a4, a5)
    elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        Signals.OnCastStart(a1, a3)
        if event == "UNIT_SPELLCAST_CHANNEL_START" then Signals.OnFriendlyCast(a1, a3, true) end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        Signals.OnChannelStop(a1)
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        Signals.OnCastDelayed(a1)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit = Plain(a1)
        if unit == "player" then
            local key = ns.KeyFromSpell(Plain(a3))
            if key then
                ns.seenCurrent = key
                formsDirty, ns.thinkNow = true, true
            end
        elseif unit and PARTY[unit] then
            PartyAuraCast(unit, a3)
            Signals.OnFriendlyCast(unit, a3, false)
        end
    elseif event == "UNIT_AURA" then
        if Plain(a1) == "player" then buffDirty = true end
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.inCombat, ns.forgetAt = true, nil
        if ns.testing then ns.testing = nil; Signals.Reset() end
        ns.thinkNow = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.inCombat = false
        ns.forgetAt = GetTime() + FORGET_AFTER
        buffDirty, formsDirty = true, true
        ns.held, ns.thinkNow = nil, true    -- the fight is over: so is its suggestion
    elseif event == "PLAYER_DEAD" then
        ns.seenCurrent, ns.deadFlag, ns.held = nil, true, nil
        formsDirty, buffDirty, ns.thinkNow = true, true, true
        -- the fight you died in is over for you: its hits don't count once you're back
        if not ns.testing then Signals.Reset() end
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        -- PLAYER_ALIVE also fires on release, as a ghost: IsDead() still says so then
        local ok, dead = pcall(UnitIsDeadOrGhost or function() return false end, "player")
        if event == "PLAYER_UNGHOST" or (ok and not Secret(dead) and not dead) then ns.deadFlag = false end
        ns.seenCurrent = nil
        formsDirty, buffDirty, ns.thinkNow = true, true, true
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_USABLE" then
        formsDirty, ns.thinkNow = true, true
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        PruneOthers()
        buffDirty = true
    else    -- spells, level, stance bar layout, entering the world
        knownDirty, buffDirty = true, true
    end
end

local EVENTS = {
    "UNIT_COMBAT", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_SUCCEEDED", "UNIT_AURA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_DEAD",
    "PLAYER_ALIVE", "PLAYER_UNGHOST",
    "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_USABLE", "GROUP_ROSTER_UPDATE",
    "PLAYER_ROLES_ASSIGNED", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "LEARNED_SPELL_IN_TAB", "PLAYER_TALENT_UPDATE",
}

local function Init()
    if type(AuraAdvisorDB) ~= "table" then AuraAdvisorDB = {} end
    ns.db = AuraAdvisorDB
    Repair(ns.db)

    local _, class = UnitClass("player")
    if class ~= "PALADIN" then return end
    ns.enabled = true
    ns.inCombat = InCombatLockdown() and true or false

    ns.UI.Create()
    if ns.Kit and ns.Options then
        local ok, err = pcall(ns.Options.Init)
        if not ok then ns.Print("options error: " .. tostring(err)) end
    end
    for _, ev in ipairs(EVENTS) do pcall(driver.RegisterEvent, driver, ev) end
    driver:SetScript("OnEvent", OnEvent)
    driver:SetScript("OnUpdate", OnUpdate)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", Init)

----------------------------------------------------------------------
-- Actions shared by the slash commands, the options window and the minimap button
----------------------------------------------------------------------
function ns.Reset()
    if InCombatLockdown() then ns.Print("can't reset in a fight.") return end
    local minimap = ns.db.minimap
    for k in pairs(ns.db) do ns.db[k] = nil end
    for k, v in pairs(defaults) do ns.db[k] = v end
    ns.db.minimap = minimap
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.thinkNow = true
    ns.Print("settings reset")
end

local STYLE_NAME = { damage = "damage", tank = "tank", healer = "healer" }

-- The numbers behind the advice.
function ns.PrintWhy()
    local res = ns.result
    if not res then ns.Print("nothing yet") return end
    if res.dead then ns.Print("dead") return end
    -- One line: the aura on, and the one to switch to with its cause. The points are in /aura debug.
    local line = res.current and ns.known[res.current] and ns.TwoWords(res.current) or "No aura"
    if res.shown and ns.known[res.shown] then
        line = line .. ". Switch: " .. ns.TwoWords(res.shown)
        if type(res.reason) == "string" and res.reason ~= "" then line = line .. " (" .. res.reason .. ")" end
    end
    ns.Print(line)
end

function ns.PrintPoints()
    local res = ns.result
    if not res or res.dead then return end
    ns.Print(("play style: %s (%s)"):format(STYLE_NAME[res.style] or tostring(res.style), tostring(res.styleWhy)))
    for _, key in ipairs(Data.ORDER) do
        local info = ns.known[key]
        if info then
            local mark = ""
            if key == res.shown then
                mark = "  " .. ns.UI.Paint("NORMAL_FONT_COLOR", "<- switch to this")
            elseif key == res.current then
                mark = "  " .. ns.UI.Paint("GREEN_FONT_COLOR", "<- on")
            end
            ns.Print(("  %s: %.1f points%s%s"):format(info.name, res.scores[key] or 0,
                res.why[key] and (" (" .. res.why[key] .. ")") or "", mark))
        end
    end
    if res.quiet then ns.Print("  nothing is hitting you") end
end

function ns.PrintDebug()
    local st = Signals.stats
    ns.PrintPoints()
    ns.Print("version " .. ns.VERSION .. ", client " .. tostring((GetBuildInfo and select(4, GetBuildInfo())) or "?"))
    local list = {}
    for _, key in ipairs(Data.ORDER) do
        local info = ns.known[key]
        if info then list[#list + 1] = ("%s (id %s, bar slot %s)"):format(info.name, tostring(info.spellID), tostring(info.form or "-")) end
    end
    ns.Print("auras known: " .. (#list > 0 and table.concat(list, ", ") or "none"))
    ns.Print(("stance bar lists auras: %s, can be read: %s. On now: %s."):format(tostring(ns.formsListed),
        tostring(ns.formsReadable), tostring(ns.CurrentAura() or "none")))
    ns.Print(("hits seen on you and your party: %d (of %d events; school hidden: %d, event hidden: %d)"):format(
        st.hits, st.combat, st.hiddenSchool, st.hiddenEvent))
    ns.Print(("hits a party member dealt themselves (Hellfire, Life Tap), not counted: %d"):format(st.selfHarm or 0))
    ns.Print(("casts pushed back: %d. Enemy casts seen: %d (name readable: %d, school known: %d)"):format(
        st.pushes, st.enemyCasts, st.namedCasts, st.schoolCasts))
    local e = Signals.enemies
    ns.Print(("enemies in the fight: %d"):format(e.engaged or 0))
    local taken = {}
    for key, who in pairs(ns.OtherAuras()) do
        taken[#taken + 1] = Data.AURAS[key].short .. " (" .. (type(who) == "string" and who or "another paladin") .. ")"
    end
    ns.Print("auras from other paladins: " .. (#taken > 0 and table.concat(taken, ", ") or "none"))
    local glowing = {}
    for b, a in pairs(ns.UI.alerts) do
        if a and a.on then glowing[#glowing + 1] = (b.GetName and b:GetName()) or "a button" end
    end
    ns.Print("glowing on: " .. (#glowing > 0 and table.concat(glowing, ", ") or "nothing")
        .. (ns.held and ns.result and ns.result.held and " (held until you switch or the fight ends)" or ""))
end

-- A pretend burst of damage, to see what the advisor does without a fight.
local TESTS = {
    fire = "fire", frost = "frost", shadow = "shadow",
    melee = "physical", physical = "physical", push = "push", pushback = "push",
}
function ns.Test(kind)
    if kind == "off" or kind == "stop" then
        ns.testing = nil
        Signals.Reset()
        ns.thinkNow = true
        ns.Print("test off")
        return true
    end
    local what = TESTS[kind]
    if not what then return false end
    if ns.inCombat then ns.Print("not in a fight") return true end
    if ns.IsDead() then ns.Print("not while dead") return true end
    Signals.Reset()
    ns.testing = true
    local now = GetTime()
    for i = 0, 7 do
        if what == "push" then
            Signals.Push(now - i * 0.4, true)
            Signals.Hit(now - i * 0.4, true, "physical", true, false)
        else
            Signals.Hit(now - i * 0.4, i % 2 == 0, what, true, false)
        end
    end
    ns.thinkNow = true
    ns.Print("test: " .. (what == "push" and "pushbacks" or Data.SCHOOL_NAME[what]) .. " (/aura test off)")
    return true
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
-- Kit.lua and Options.lua are separate files; if one is missing (an update that added it,
-- before the next /reload), say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    ns.Print("/reload once more for the options")
    return false
end

local function Help()
    ns.Print("commands:")
    ns.Print("  /aura  - the aura on, the one to switch to and why")
    ns.Print("  /aura config  - the options window")
    ns.Print("  /aura style auto|damage|tank|healer  (now: " .. ns.db.style .. ")")
    ns.Print("  /aura default auto|devotion|retribution|concentration  - your aura between fights (now: " .. ns.db.idle .. ")")
    ns.Print("  /aura sens low|normal|high  - how quickly it suggests a switch (now: " .. ns.db.sensitivity .. ")")
    ns.Print("  /aura glow | sound | banner | chat | between  - switch that on or off")
    ns.Print("  /aura test fire|frost|shadow|melee|push|off  - a pretend fight")
    ns.Print("  /aura minimap | reset | debug")
end

local TOGGLES = {
    glow = { "glow", "glow" },
    sound = { "sound", "sound" },
    banner = { "banner", "line on screen" },
    chat = { "chat", "chat line" },
    between = { "betweenFights", "default after a fight" },
}

SLASH_AURAADVISOR1 = "/aura"
SLASH_AURAADVISOR2 = "/auraadvisor"
SlashCmdList.AURAADVISOR = function(msg)
    if not ns.db then return end
    if not ns.enabled then ns.Print("Paladins only") return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if cmd == "" or cmd == "why" or cmd == "report" then
        ns.PrintWhy()
    elseif cmd == "help" or cmd == "?" then
        Help()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if HasKit() then ns.Kit.Open() end
    elseif cmd == "minimap" then
        if HasKit() then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("minimap button " .. (ns.Kit.MinimapShown() and "on" or "off"))
        end
    elseif cmd == "show" or cmd == "lock" or cmd == "unlock" or cmd == "scale" then
        ns.Print("no bar any more: it glows on your stance bar (/aura glow)")
    elseif cmd == "style" or cmd == "role" then
        if ns.Set("style", arg) then
            ns.Print("play style: " .. arg)
        else
            ns.Print("usage: /aura style auto|damage|tank|healer   (now: " .. ns.db.style .. ")")
        end
    elseif cmd == "default" or cmd == "idle" then
        if ns.Set("idle", arg) then
            ns.Print("aura between fights: " .. arg)
        else
            ns.Print("usage: /aura default auto|devotion|retribution|concentration   (now: " .. ns.db.idle .. ")")
        end
    elseif cmd == "sens" or cmd == "sensitivity" then
        if ns.Set("sensitivity", arg) then
            ns.Print("sensitivity: " .. arg)
        else
            ns.Print("usage: /aura sens low|normal|high   (now: " .. ns.db.sensitivity .. ")")
        end
    elseif TOGGLES[cmd] then
        local key, text = TOGGLES[cmd][1], TOGGLES[cmd][2]
        ns.Set(key, not ns.db[key])
        ns.Print(text .. " " .. (ns.db[key] and "on" or "off"))
    elseif cmd == "test" then
        if not ns.Test(arg) then ns.Print("usage: /aura test fire|frost|shadow|melee|push|off") end
    elseif cmd == "reset" then
        ns.Reset()
    elseif cmd == "debug" then
        ns.PrintDebug()
    else
        Help()
    end
    if ns.Kit then ns.Kit.Sync() end
end
