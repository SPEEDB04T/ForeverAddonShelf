-- Cozy Counter: reminds you of the three XP buffs WoW Forever gives (Well Fed from cooked
-- food, Well-Rested from the Cozy Sleeping Bag, and the Camp Tent's rest top-up at a
-- campfire) and counts the experience you lost while one was missing.
--
-- Auras and XP values can be secret in a fight. Every read goes through Plain(), which turns a
-- secret (or an error) into nil, and the buff state from before the fight stands in while the
-- live one can't be read.
local ADDON, ns = ...

local floor, max, min = math.floor, math.max, math.min
local PREFIX = "|cffffd100Cozy Counter:|r "

ns.KEYS = { "food", "bag", "camp" }

-- What each buff is on WoW Forever (sources and assumptions: README.md).
ns.INFO = {
    food = {
        title = "Well Fed",
        gives = "Cooked food: +5% experience from kills while Well Fed.",
        how = "Eat cooked food (most Cooking recipes). Lasts about 15 minutes; dying removes it.",
        names = { ["Well Fed"] = true },
        icon = 136000,                      -- Spell_Misc_Food
        iconPath = "Interface\\Icons\\Spell_Misc_Food",
    },
    bag = {
        title = "Well-Rested",
        gives = "Cozy Sleeping Bag: +1% experience per stack, up to 3 stacks.",
        how = "Lie down in your Cozy Sleeping Bag: one stack a minute. Lasts 2 hours, kept through death.",
        spellID = 429959,
        names = { ["Well-Rested"] = true, ["Well Rested"] = true },
        item = 211527,
        iconPath = "Interface\\Icons\\INV_Misc_Bag_08",
    },
    camp = {
        title = "Camp Tent rest",
        gives = "Camp Tent at a campfire: tops your rested XP up to 5% of a level, once an hour.",
        how = "Sit for a minute by a campfire that has a Camp Tent (Leatherworking). Rested XP doubles kill XP until it runs out.",
        tentSpell = 1229432,
        debuffID = 1229451,                 -- Boosted Rest: "cannot gain more rested experience from a Camp Tent for 1 hour"
        debuffName = "Boosted Rest",
        iconPath = "Interface\\Icons\\Spell_Fire_Fire",
    },
}

ns.DEFAULTS = {
    enabled = true,
    remind = { food = true, bag = true, camp = true },
    foodPct = 5,            -- % more kill XP while Well Fed
    bagPct = 1,             -- % more XP per Well-Rested stack
    bagStacks = 3,          -- most Well-Rested stacks
    bagQuests = true,       -- Well-Rested also counts on quest and other non-kill XP
    campShare = 5,          -- the tent's top-up, % of a level
    campHours = 1,          -- how often the tent can top you up
    needBag = true,         -- remind of the sleeping bag only when you carry one
    hideResting = true,     -- no reminders in an inn or city
    levelReport = true,     -- a chat line at every level-up
    locked = false,
    scale = 1,
    point = { "TOP", "TOP", 0, -150 },
    minimap = {},
}

----------------------------------------------------------------------
-- Safe reads
----------------------------------------------------------------------
local function Secret(v)
    return type(issecretvalue) == "function" and issecretvalue(v) and true or false
end
ns.Secret = Secret

-- The value, or nil if it is secret.
local function Plain(v)
    if Secret(v) then return nil end
    return v
end
ns.Plain = Plain

-- Calls fn and returns its first result if it is plain.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return Plain(v)
end
ns.Call = Call

local function Num(v)
    v = Plain(v)
    return type(v) == "number" and v or nil
end

function ns.Print(msg) print(PREFIX .. tostring(msg)) end

local function Now() return Call(GetTime) or 0 end
ns.Now = Now

function ns.Commas(n)
    n = floor((n or 0) + 0.5)
    if type(BreakUpLargeNumbers) == "function" then
        local ok, s = pcall(BreakUpLargeNumbers, n)
        if ok and type(s) == "string" then return s end
    end
    local s = tostring(n)
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

----------------------------------------------------------------------
-- Saved data
----------------------------------------------------------------------
local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function NewLost() return { food = 0, bag = 0, camp = 0 } end

ns.session = { lost = NewLost(), gained = 0, gains = 0, start = 0 }

local function LoadSaved()
    if type(CozyCounterDB) ~= "table" then CozyCounterDB = {} end
    CopyDefaults(CozyCounterDB, ns.DEFAULTS)
    ns.db = CozyCounterDB
    if type(CozyCounterCharDB) ~= "table" then CozyCounterCharDB = {} end
    local c = CozyCounterCharDB
    if type(c.lost) ~= "table" then c.lost = NewLost() end
    CopyDefaults(c.lost, NewLost())
    if type(c.levelLost) ~= "table" then c.levelLost = NewLost() end
    CopyDefaults(c.levelLost, NewLost())
    c.gained = tonumber(c.gained) or 0
    c.gains = tonumber(c.gains) or 0
    if type(c.learned) ~= "table" then c.learned = {} end     -- [spellID] = { kind, pct, name }
    if type(c.other) ~= "table" then c.other = {} end         -- other XP auras seen: [name] = tooltip line
    ns.char = c
end
ns.LoadSaved = LoadSaved

function ns.Set(key, value)
    local default = ns.DEFAULTS[key]
    if default == nil or type(default) == "table" then return end
    if type(default) == "boolean" then value = value and true or false
    elseif type(value) ~= type(default) then return end
    ns.db[key] = value
    if key == "foodPct" then ns.db.foodManual = true end
    if key == "bagPct" then ns.db.bagManual = true end
    ns.Refresh()
end

function ns.SetRemind(key, value)
    ns.db.remind[key] = value and true or false
    ns.Refresh()
end

function ns.Reset()
    local minimap = ns.db.minimap
    for k in pairs(ns.db) do ns.db[k] = nil end
    CopyDefaults(ns.db, ns.DEFAULTS)
    ns.db.minimap = minimap or {}
    if ns.UI then ns.UI.Place() end
    if ns.Kit and ns.Kit.RefreshMinimap then pcall(ns.Kit.RefreshMinimap) end
    ns.Refresh()
end

function ns.ResetSession()
    ns.session = { lost = NewLost(), gained = 0, gains = 0, start = Now() }
    ns.Refresh()
end

function ns.ResetAll()
    ns.ResetSession()
    ns.char.lost, ns.char.levelLost = NewLost(), NewLost()
    ns.char.gained, ns.char.gains = 0, 0
    ns.Refresh()
end

----------------------------------------------------------------------
-- Level and XP
----------------------------------------------------------------------
local function MaxLevel()
    return Call(GetMaxLevelForPlayerExpansion) or Call(GetMaxPlayerLevel) or 60
end

-- XP gain is on: not at max level and not switched off at an XP-lock NPC.
function ns.Active()
    if not ns.db or not ns.db.enabled then return false end
    local level = Num(Call(UnitLevel, "player"))
    local top = Num(MaxLevel())
    if level and top and level >= top then return false end
    if Call(IsXPUserDisabled) == true then return false end
    return true
end

local function ReadXP()
    local xp = Num(Call(UnitXP, "player"))
    local most = Num(Call(UnitXPMax, "player"))
    local level = Num(Call(UnitLevel, "player"))
    if not xp or not most or not level or most <= 0 or xp < 0 then return nil end
    return { xp = xp, max = most, level = level }
end
ns.ReadXP = ReadXP

local function Rested()
    return Num(Call(GetXPExhaustion)) or 0
end
ns.Rested = Rested

----------------------------------------------------------------------
-- Buff state
----------------------------------------------------------------------
-- ns.state is the last full read: { food = bool, foodEnds, bag = stacks, bagEnds,
-- boosted = bool, boostedEnds, time }. While auras are secret, Current() uses it and lets
-- each buff run out at the time it was due to.
ns.state = nil
local tipSeen = {}

-- The text of an aura's tooltip, or nil.
local function TooltipText(instanceID, filter)
    if not instanceID or not C_TooltipInfo or not C_TooltipInfo.GetUnitBuffByAuraInstanceID then return nil end
    local fn = filter == "HARMFUL" and C_TooltipInfo.GetUnitDebuffByAuraInstanceID or C_TooltipInfo.GetUnitBuffByAuraInstanceID
    local data = Call(fn, "player", instanceID, filter)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local parts = {}
    for _, line in ipairs(data.lines) do
        local left = type(line) == "table" and Plain(line.leftText)
        if type(left) == "string" then parts[#parts + 1] = left end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "\n")
end
ns.TooltipText = TooltipText

-- Reads an aura's tooltip once per spell (out of a fight only) and learns what it gives.
local function Learn(aura, kind)
    local id = aura.spellId
    if not id or tipSeen[id] or InCombatLockdown() then return end
    tipSeen[id] = true
    local text = TooltipText(aura.auraInstanceID, "HELPFUL")
    if not text then return end
    local lower = text:lower()
    if not lower:find("experience", 1, true) then return end
    local pct = tonumber(lower:match("experience[^%%%d]-(%d+)%%") or lower:match("(%d+)%%[^\n]-experience"))
    if not kind then
        if lower:find("kill", 1, true) or lower:find("slay", 1, true) then kind = "food" end
    end
    if kind == "food" and pct then
        ns.char.learned[id] = { kind = "food", pct = pct, name = aura.name }
        if not ns.db.foodManual and ns.db.foodPct ~= pct then
            ns.db.foodPct = pct
            ns.Print(("learned from %s's tooltip: +%d%% kill XP."):format(tostring(aura.name), pct))
        end
    elseif kind == "bag" and pct then
        local stacks = aura.applications or 1
        if stacks <= 1 then
            ns.char.learned[id] = { kind = "bag", pct = pct, name = aura.name }
            if not ns.db.bagManual and ns.db.bagPct ~= pct then
                ns.db.bagPct = pct
                ns.Print(("learned from %s's tooltip: +%d%% XP a stack."):format(tostring(aura.name), pct))
            end
        else
            tipSeen[id] = nil   -- try again at one stack
        end
    elseif aura.name then
        local first = text:match("[^\n]*[Ee]xperience[^\n]*")
        ns.char.other[aura.name] = first or text
    end
end

-- Walks one aura list. Returns false if any part of it is secret.
local function Walk(filter, fn)
    if not C_UnitAuras or type(C_UnitAuras.GetAuraDataByIndex) ~= "function" then return false end
    for i = 1, 255 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
        if not ok or Secret(aura) then return false end
        if type(aura) ~= "table" then return true end
        local plain = {
            name = Plain(aura.name), spellId = Plain(aura.spellId),
            applications = Plain(aura.applications), expirationTime = Plain(aura.expirationTime),
            auraInstanceID = Plain(aura.auraInstanceID),
        }
        if plain.name == nil and plain.spellId == nil then return false end
        fn(plain)
    end
    return true
end

-- Reads every buff now. Returns the state, or nil if the game hides auras at the moment.
local function ReadState()
    local s = { food = false, foodEnds = 0, bag = 0, bagEnds = 0, boosted = false, boostedEnds = 0, time = Now() }
    local info = ns.INFO
    local learned = ns.char and ns.char.learned or {}
    local okHelp = Walk("HELPFUL", function(a)
        local ends = type(a.expirationTime) == "number" and a.expirationTime or 0
        local known = a.spellId and learned[a.spellId]
        if (a.name and info.food.names[a.name]) or (known and known.kind == "food") then
            s.food, s.foodEnds = true, max(s.foodEnds, ends)
            Learn(a, "food")
        elseif a.spellId == info.bag.spellID or (a.name and info.bag.names[a.name]) then
            local stacks = type(a.applications) == "number" and a.applications or 1
            s.bag, s.bagEnds = max(s.bag, max(1, stacks)), ends
            Learn(a, "bag")
        else
            Learn(a, nil)
            local now = a.spellId and learned[a.spellId]
            if now and now.kind == "food" then s.food, s.foodEnds = true, max(s.foodEnds, ends) end
        end
    end)
    if not okHelp then return nil end
    local okHarm = Walk("HARMFUL", function(a)
        if a.spellId == info.camp.debuffID or a.name == info.camp.debuffName then
            s.boosted = true
            s.boostedEnds = type(a.expirationTime) == "number" and a.expirationTime or 0
        end
    end)
    if not okHarm then return nil end
    return s
end
ns.ReadState = ReadState

-- The buff state to count with: live if it can be read, else the last one, aged.
function ns.Current()
    local live = ReadState()
    if live then
        ns.state = live
        return live, true
    end
    local last = ns.state
    if not last then return nil, false end
    local now = Now()
    local function Up(ends) return ends == 0 or ends > now end
    return {
        food = last.food and Up(last.foodEnds), foodEnds = last.foodEnds,
        bag = Up(last.bagEnds) and last.bag or 0, bagEnds = last.bagEnds,
        boosted = last.boosted and Up(last.boostedEnds), boostedEnds = last.boostedEnds,
        time = now,
    }, false
end

-- Whether the character carries a Cozy Sleeping Bag (bags or bank).
function ns.HasBag()
    local id = ns.INFO.bag.item
    local n = (C_Item and Num(Call(C_Item.GetItemCount, id, true))) or Num(Call(GetItemCount, id, true))
    return n ~= nil and n > 0
end

-- Which buffs are missing now: { food = true, ... } plus the state used.
function ns.Missing(s)
    s = s or ns.Current()
    if not s then return nil end
    local db = ns.db
    local missing = {}
    if not s.food then missing.food = true end
    if (s.bag or 0) < db.bagStacks then missing.bag = true end
    if not s.boosted then
        local xp = ReadXP()
        local want = xp and xp.max * db.campShare / 100 or 0
        if Rested() < want then missing.camp = true end
    end
    return missing, s
end

----------------------------------------------------------------------
-- Lost XP
----------------------------------------------------------------------
-- The tent's rest you could have had: when it is missing, the counter pretends you sat at a
-- tent the moment you needed it, once per campHours, and spends that pretend pool on kills.
ns.camp = { pool = 0, readyAt = 0 }

local function AddLost(key, amount)
    if amount <= 0 then return end
    ns.session.lost[key] = ns.session.lost[key] + amount
    ns.char.lost[key] = ns.char.lost[key] + amount
    ns.char.levelLost[key] = ns.char.levelLost[key] + amount
end

-- One XP gain. kind is "kill" or "other" (quests, exploration); rested is the part of a kill
-- that came from rested XP. Returns what it counted as lost, per buff.
function ns.Account(kind, amount, rested, s, restedBefore, xpMax)
    amount, rested = tonumber(amount) or 0, tonumber(rested) or 0
    if amount <= 0 or not ns.Active() then return nil end
    s = s or ns.Current()
    if not s then return nil end
    local db = ns.db
    local now = Now()
    local kill = kind == "kill"
    local bagApplies = kill or db.bagQuests
    local stacks = min(s.bag or 0, db.bagStacks)

    local pct = 0
    if kill and s.food then pct = pct + db.foodPct end
    if bagApplies then pct = pct + db.bagPct * stacks end
    local base = max(0, amount - rested) / (1 + pct / 100)

    local lost = { food = 0, bag = 0, camp = 0 }
    if kill and not s.food then lost.food = base * db.foodPct / 100 end
    if bagApplies then lost.bag = base * db.bagPct * (db.bagStacks - stacks) / 100 end

    local camp = ns.camp
    if s.boosted then
        camp.pool = 0
        camp.readyAt = max(camp.readyAt, s.boostedEnds or 0)
    elseif kill then
        local short = max(0, base - rested)        -- the part of this kill rested XP did not double
        if short > 0 then
            if camp.pool <= 0 and now >= camp.readyAt then
                local most = xpMax or (ReadXP() or {}).max or 0
                local have = restedBefore or Rested()
                camp.pool = max(0, most * db.campShare / 100 - have)
                camp.readyAt = now + db.campHours * 3600
            end
            lost.camp = min(short, camp.pool)
            camp.pool = camp.pool - lost.camp
        end
    end

    for key, v in pairs(lost) do AddLost(key, v) end
    ns.session.gained = ns.session.gained + amount
    ns.session.gains = ns.session.gains + 1
    ns.char.gained = ns.char.gained + amount
    ns.char.gains = ns.char.gains + 1
    if ns.UI then ns.UI.Update() end
    return lost
end

function ns.Total(t) return (t.food or 0) + (t.bag or 0) + (t.camp or 0) end

----------------------------------------------------------------------
-- Reading XP gains: the chat line says which XP came from a kill and how much of it was rested;
-- the XP bar says how much came in all together (quests, exploration). Both are collected for a
-- moment and then settled together, so nothing is counted twice.
----------------------------------------------------------------------
local pending
local lastXP

local function Pattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("%%%d*%$?s", "\001"):gsub("%%%d*%$?d", "\002")
    p = p:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
    p = p:gsub("\001", "(.-)"):gsub("\002", "(%%d+)")
    return "^" .. p
end

local killPatterns
local function KillPatterns()
    if killPatterns then return killPatterns end
    killPatterns = {}
    for _, key in ipairs({ "COMBATLOG_XPGAIN_FIRSTPERSON", "COMBATLOG_XPGAIN_EXHAUSTION1",
        "COMBATLOG_XPGAIN_EXHAUSTION2", "COMBATLOG_XPGAIN_EXHAUSTION4", "COMBATLOG_XPGAIN_EXHAUSTION5",
        "COMBATLOG_XPGAIN_FIRSTPERSON_GROUP", "COMBATLOG_XPGAIN_FIRSTPERSON_RAID",
        "COMBATLOG_XPGAIN_EXHAUSTION1_GROUP", "COMBATLOG_XPGAIN_EXHAUSTION1_RAID" }) do
        local p = Pattern(Plain(_G[key]))
        if p then killPatterns[#killPatterns + 1] = p end
    end
    killPatterns[#killPatterns + 1] = "^(.-) dies, you gain (%d+) experience"
    return killPatterns
end

-- "Wolf dies, you gain 120 experience. (+60 exp Rested bonus)" -> 120, 60. nil if not a kill.
function ns.ParseKill(text)
    if type(text) ~= "string" then return nil end
    for _, p in ipairs(KillPatterns()) do
        local victim, amount = text:match(p)
        amount = tonumber(amount)
        if victim and amount then
            local rested = tonumber(text:match("%+(%d+) exp Rested")) or 0
            if rested == 0 and pending and (pending.restedBefore or 0) > 0 then
                -- another language: the first bonus in brackets while rested XP was there
                local bonus = tonumber(text:match("%(%+?(%d+)"))
                if bonus and not text:lower():find("group", 1, true) then rested = bonus end
            end
            return amount, min(rested, amount)
        end
    end
    return nil
end

local function Settle()
    local p = pending
    pending = nil
    if not p then return end
    local s = p.state
    local killed = 0
    for _, k in ipairs(p.kills) do
        killed = killed + k.amount
        ns.Account("kill", k.amount, k.rested, s, p.restedBefore, p.xpMax)
    end
    if p.delta then
        local rest = p.delta - killed
        if rest > 0 then
            local kind = (p.secretChat and #p.kills == 0) and "kill" or "other"
            ns.Account(kind, rest, 0, s, p.restedBefore, p.xpMax)
        end
    end
end
ns.Settle = Settle

local function Pending()
    if pending then return pending end
    local xp = lastXP
    pending = { kills = {}, delta = nil, state = (ns.Current()), restedBefore = ns.lastRested or Rested(),
                xpMax = xp and xp.max }
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, Settle)
    end
    return pending
end

function ns.OnChatXP(text)
    if not ns.Active() then return end
    local p = Pending()
    if Secret(text) then p.secretChat = true return end
    local amount, rested = ns.ParseKill(text)
    if amount then p.kills[#p.kills + 1] = { amount = amount, rested = rested } end
end

function ns.OnXPUpdate()
    local now = ReadXP()
    local before = lastXP
    -- An unreadable bar drops the baseline: what came in meanwhile was counted from the chat
    -- line, and the next readable value only starts a new baseline.
    lastXP = now
    if not before or not now or not ns.Active() then
        ns.lastRested = Rested()
        return
    end
    local delta
    if now.level == before.level then
        delta = now.xp - before.xp
    elseif now.level == before.level + 1 then
        delta = (before.max - before.xp) + now.xp
    end
    if delta and delta > 0 then
        local p = Pending()
        p.delta = (p.delta or 0) + delta
    end
    ns.lastRested = Rested()
end

----------------------------------------------------------------------
-- Reports
----------------------------------------------------------------------
function ns.Summary()
    local s, c = ns.session, ns.char
    local lines = {}
    local function Line(label, t, gained)
        local total = ns.Total(t)
        local share = gained > 0 and (" (%.1f%% of the %s you got)"):format(total * 100 / gained, ns.Commas(gained)) or ""
        lines[#lines + 1] = ("%s: |cffffffff%s XP lost|r%s"):format(label, ns.Commas(total), share)
        lines[#lines + 1] = ("   Well Fed %s, Sleeping bag %s, Camp Tent %s"):format(
            ns.Commas(t.food), ns.Commas(t.bag), ns.Commas(t.camp))
    end
    Line("This session", s.lost, s.gained)
    Line("All time on this character", c.lost, c.gained)
    return lines
end

function ns.PrintSummary()
    for _, line in ipairs(ns.Summary()) do ns.Print(line) end
    if not ns.Active() then ns.Print("not counting now: max level, XP gain switched off, or the addon is off.") end
end

local function LevelUp(level)
    local t = ns.char.levelLost
    local total = ns.Total(t)
    if ns.db.levelReport and total >= 1 then
        ns.Print(("level %s reached. Missing buffs cost you %s XP on the way (Well Fed %s, Sleeping bag %s, Camp Tent %s)."):format(
            tostring(level), ns.Commas(total), ns.Commas(t.food), ns.Commas(t.bag), ns.Commas(t.camp)))
    end
    ns.char.levelLost = NewLost()
end

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
local refreshQueued
function ns.Refresh()
    if ns.UI then ns.UI.Update() end
    if ns.Kit and ns.Options and ns.Kit.Sync then pcall(ns.Kit.Sync) end
end

local function QueueRefresh()
    if refreshQueued then return end
    refreshQueued = true
    local function Run()
        refreshQueued = false
        if not InCombatLockdown() then ns.Current() end
        if ns.UI then ns.UI.Update() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.2, Run) else Run() end
end
ns.QueueRefresh = QueueRefresh

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
local function HasKit()
    if ns.Kit and ns.Options and ns.Options.Ready and ns.Options.Ready() then return true end
    ns.Print("the options window and the minimap button appear after you restart the game once.")
    return false
end

local function Slash(msg)
    msg = (type(msg) == "string" and msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not ns.db then return end
    if msg == "" or msg == "lost" or msg == "summary" then
        ns.PrintSummary()
    elseif msg == "options" or msg == "config" or msg == "o" then
        if HasKit() then ns.Kit.Open() end
    elseif msg == "on" or msg == "off" then
        ns.Set("enabled", msg == "on")
        ns.Print(msg == "on" and "reminders and counting on." or "reminders and counting off.")
    elseif msg == "lock" or msg == "unlock" then
        ns.Set("locked", msg == "lock")
        ns.Print(msg == "lock" and "reminder locked in place." or "reminder unlocked: drag it to move it.")
    elseif msg == "reset session" or msg == "new" then
        ns.ResetSession()
        ns.Print("session count started again.")
    elseif msg == "reset all" then
        ns.ResetAll()
        ns.Print("every count on this character set back to 0.")
    elseif msg == "reset" then
        ns.Print("|cffffffff/cozy reset session|r starts the session count again; |cffffffff/cozy reset all|r also clears this character's all-time count.")
    elseif msg == "test" then
        if ns.UI then ns.UI.SetTesting(not ns.UI.Testing()) end
        ns.Print(ns.UI and ns.UI.Testing() and "showing all three reminders. /cozy test again to stop." or "test reminders hidden.")
    elseif msg == "status" or msg == "debug" then
        local s, live = ns.Current()
        local xp = ReadXP()
        ns.Print(("counting: %s. Auras %s."):format(ns.Active() and "yes" or "no", live and "readable" or (s and "hidden, using the last read" or "not read yet")))
        if s then
            ns.Print(("Well Fed: %s. Well-Rested: %d/%d. Boosted Rest: %s. Rested XP: %s of %s."):format(
                s.food and "yes" or "no", s.bag or 0, ns.db.bagStacks, s.boosted and "yes" or "no",
                ns.Commas(Rested()), xp and ns.Commas(xp.max) or "?"))
        end
        ns.Print(("counting with: food +%d%% kill XP, bag +%d%% a stack (%d stacks), tent %d%% of a level every %dh. Bag carried: %s."):format(
            ns.db.foodPct, ns.db.bagPct, ns.db.bagStacks, ns.db.campShare, ns.db.campHours, ns.HasBag() and "yes" or "no"))
    elseif msg == "buffs" then
        local any = false
        for id, l in pairs(ns.char.learned) do
            any = true
            ns.Print(("learned: %s (%s) %s, +%s%%."):format(tostring(l.name), tostring(id), l.kind, tostring(l.pct)))
        end
        for name, line in pairs(ns.char.other) do
            any = true
            ns.Print(("other XP buff seen: %s: %s"):format(name, line))
        end
        if not any then ns.Print("no XP buff tooltips read yet.") end
    else
        ns.Print("|cffffffff/cozy|r what you lost, |cffffffff/cozy options|r, |cffffffff/cozy on|r / |cffffffffoff|r, "
            .. "|cffffffff/cozy lock|r / |cffffffffunlock|r, |cffffffff/cozy test|r, |cffffffff/cozy reset|r, "
            .. "|cffffffff/cozy status|r, |cffffffff/cozy buffs|r.")
    end
end
ns.Slash = Slash

SLASH_COZYCOUNTER1 = "/cozy"
SLASH_COZYCOUNTER2 = "/cozycounter"
SlashCmdList = SlashCmdList or {}
SlashCmdList.COZYCOUNTER = function(msg)
    local ok, err = pcall(Slash, msg)
    if not ok then ns.Print("error: " .. tostring(err)) end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.frame = frame

local handlers = {}
function handlers.ADDON_LOADED(name)
    if name ~= ADDON then return end
    LoadSaved()
    ns.session.start = Now()
end

function handlers.PLAYER_LOGIN()
    if not ns.db then LoadSaved() end
    lastXP = ReadXP()
    ns.lastRested = Rested()
    if ns.UI then ns.UI.Init() end
    if ns.Kit and ns.Options then
        local ok, err = pcall(ns.Options.Init)
        if not ok then ns.Print("options could not start: " .. tostring(err)) end
    end
    ns.Current()
    ns.Refresh()
end

function handlers.PLAYER_ENTERING_WORLD() lastXP = ReadXP() or lastXP QueueRefresh() end
function handlers.UNIT_AURA(unit) if unit == "player" then QueueRefresh() end end
function handlers.PLAYER_REGEN_DISABLED()
    ns.Current()                -- one last plain read before the fight hides auras
    if ns.UI then ns.UI.Update() end
end
function handlers.PLAYER_REGEN_ENABLED() QueueRefresh() end
function handlers.CHAT_MSG_COMBAT_XP_GAIN(text) ns.OnChatXP(text) end
function handlers.PLAYER_XP_UPDATE(unit) if unit == nil or unit == "player" then ns.OnXPUpdate() end end
function handlers.PLAYER_LEVEL_UP(level) LevelUp(Plain(level)) QueueRefresh() end
function handlers.UPDATE_EXHAUSTION() ns.lastRested = Rested() QueueRefresh() end
function handlers.PLAYER_UPDATE_RESTING() QueueRefresh() end
function handlers.ENABLE_XP_GAIN() QueueRefresh() end
function handlers.DISABLE_XP_GAIN() QueueRefresh() end
function handlers.PLAYER_DEAD() QueueRefresh() end
function handlers.PLAYER_ALIVE() QueueRefresh() end
function handlers.PLAYER_UNGHOST() QueueRefresh() end
function handlers.BAG_UPDATE_DELAYED() QueueRefresh() end
function handlers.PLAYER_CONTROL_LOST() QueueRefresh() end
function handlers.PLAYER_CONTROL_GAINED() QueueRefresh() end
ns.handlers = handlers

frame:SetScript("OnEvent", function(_, event, ...)
    local fn = handlers[event]
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok and not ns.reported then
        ns.reported = true
        ns.Print("error in " .. event .. ": " .. tostring(err))
    end
end)
for event in pairs(handlers) do
    pcall(frame.RegisterEvent, frame, event)
end
