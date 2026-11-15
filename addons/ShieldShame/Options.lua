-- Shield Shame: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local ICON = "Interface\\Icons\\Spell_Nature_LightningShield"

local function Get(key) return function() return ns.db[key] end end
local function Set(key) return function(value) ns.Set(key, value) end end

local function Rows()
    return {
        { kind = "header", text = "Reminder" },
        { kind = "check", label = "Show the missing-shield icon",
          tip = "A greyed-out shield icon while no shield is up. Its tooltip says what that has cost you.",
          get = Get("remind"), set = Set("remind") },
        { kind = "check", label = "Also in fights",
          tip = "Keeps the icon up during a fight when your shield is gone, so you notice the moment its orbs run out.",
          get = Get("remindCombat"), set = Set("remindCombat") },
        { kind = "check", label = "None in inns or cities",
          tip = "No icon while you are resting in an inn or a city (out of a fight).",
          get = Get("hideResting"), set = Set("hideResting") },
        { kind = "check", label = "None while mounted",
          tip = "No icon while you are on a mount (out of a fight).",
          get = Get("hideMounted"), set = Set("hideMounted") },
        { kind = "check", label = "Lock the icon in place",
          tip = "Unlocked, drag the icon to move it. Same as /shame lock and /shame unlock.",
          get = Get("locked"), set = Set("locked") },
        { kind = "slider", label = "Icon size", min = 0.6, max = 2, step = 0.05,
          format = function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end,
          get = Get("scale"), set = function(v) ns.Set("scale", v) if ns.UI then ns.UI.Place() end end },
        { kind = "buttons", buttons = {
            { label = "Show the icon", tip = "Shows the reminder for placing it. Click again to stop. Same as /shame test.",
              click = function() if ns.UI then ns.UI.SetTesting(not ns.UI.Testing()) end end },
        } },

        { kind = "header", text = "Counting" },
        { kind = "check", label = "Count and remind at all",
          tip = "Same as /shame on and /shame off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "choice", label = "Count losses against",
          tip = "Lightning Shield and Water Shield can't be up together, so a gap is counted against one of them.",
          options = {
              { "auto", "The shield I used last", "The one you cast last. Before you have cast one: Water Shield if you have the talent, else Lightning Shield." },
              { "lightning", "Lightning Shield", "Counts every gap as Lightning Shield damage you did not deal." },
              { "water", "Water Shield", "Counts every gap as Water Shield mana you did not get. Needs the Water Shield talent." },
          },
          get = Get("measure"), set = Set("measure") },
        { kind = "slider", label = "Time between orbs", min = 0, max = 10, step = 0.5,
          tip = "The shield's text only says \"every few seconds\". 3 seconds is a guess; set it to what you see in the game. "
              .. "If the tooltip ever gives a number, that number is used instead.",
          format = function(v) return ("%.1f sec"):format(v) end,
          get = Get("icd"), set = Set("icd") },
        { kind = "check", label = "Hits by spells count too",
          tip = "The shield fires on spell, melee and ranged hits. Untick to count only physical hits (fewer false orbs from damage over time).",
          get = Get("spellHits"), set = Set("spellHits") },

        { kind = "header", text = "Shaming" },
        { kind = "check", label = "A line in chat after a costly fight",
          tip = "One mocking line in your own chat after a fight in which you lost orbs. Nobody else sees it.",
          get = Get("fightLine"), set = Set("fightLine") },
        { kind = "check", label = "Confess to my group",
          tip = "Also says what you lost in party or raid chat after such a fight, at most once a minute. Off unless you turn it on.",
          get = Get("confess"), set = Set("confess") },
        { kind = "buttons", buttons = {
            { label = "Print what I lost", click = function() ns.PrintSummary() end },
            { label = "New session", tip = "Starts the session count again.",
              click = function() ns.ResetSession() end },
            { label = "Clear all-time", confirm = true, tip = "Sets this character's all-time count back to 0.",
              click = function() ns.ResetAll() end },
        } },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),
        { kind = "buttons", buttons = {
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started. The counts stay.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local s, t = ns.session, ns.char.total
    return {
        ("Lost this session: %s damage, %s mana"):format(ns.Commas(s.damage), ns.Commas(s.mana)),
        ("Lost all time: %s damage, %s mana"):format(ns.Commas(t.damage), ns.Commas(t.mana)),
        ns.shield and "Shield up. For now." or "No shield up.",
    }
end

local ready
function Options.Ready() return ready end

function Options.Init()
    if ready then return end
    ready = true
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS.SHAMAN
    Kit.Setup({
        title = "Shield Shame",
        icon = ICON,
        accent = type(c) == "table" and type(c.r) == "number" and { c.r, c.g, c.b } or { 0, 0.44, 0.87 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = function() ns.PrintSummary() end,
        altHint = "what you lost, in chat",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function ShieldShame_OnAddonCompartmentClick(_, mouseButton)
    if ns.db and ready and not ns.disabled then Kit.Click(mouseButton) end
end
