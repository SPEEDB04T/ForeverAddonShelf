-- Cozy Counter: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local ICON = "Interface\\Icons\\Spell_Misc_Food"

local function Get(key) return function() return ns.db[key] end end
local function Set(key) return function(value) ns.Set(key, value) end end
local function GetRemind(key) return function() return ns.db.remind[key] end end
local function SetRemind(key) return function(value) ns.SetRemind(key, value) end end
local function Pct(v) return ("%d%%"):format(v) end

local function Rows()
    return {
        { kind = "header", text = "Reminders" },
        { kind = "check", label = "Remind me of Well Fed",
          tip = "Well Fed comes from cooked food. An icon while you are not Well Fed. Cooked food gives more experience from kills.",
          get = GetRemind("food"), set = SetRemind("food") },
        { kind = "check", label = "Remind me of Well-Rested",
          tip = "Well-Rested comes from the Cozy Sleeping Bag. An icon while you have fewer Well-Rested stacks than the most there are. Lie down in your "
              .. "Cozy Sleeping Bag for a minute a stack.",
          get = GetRemind("bag"), set = SetRemind("bag") },
        { kind = "check", label = "Only if I carry the bag",
          tip = "Shows the Well-Rested icon only once you carry a Cozy Sleeping Bag. Without one there is nothing to lie down in, so no icon. What it costs is still counted.",
          get = Get("needBag"), set = Set("needBag") },
        { kind = "check", label = "Remind me of the Camp Tent",
          tip = "The Camp Tent at a campfire tops up your rested XP. An icon while your rested XP is below what a Camp Tent gives and you have not had the tent's "
              .. "top-up this hour (no Boosted Rest).",
          get = GetRemind("camp"), set = SetRemind("camp") },
        { kind = "check", label = "None in inns or cities",
          tip = "No reminder icons while you are in an inn or a city.",
          get = Get("hideResting"), set = Set("hideResting") },
        { kind = "check", label = "Lock the icons in place",
          tip = "Unlocked, drag an icon to move them. Same as /cozy lock and /cozy unlock.",
          get = Get("locked"), set = Set("locked") },
        { kind = "slider", label = "Icon size", min = 0.6, max = 2, step = 0.05,
          format = function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end,
          get = Get("scale"), set = function(v) ns.Set("scale", v) if ns.UI then ns.UI.Place() end end },
        { kind = "buttons", buttons = {
            { label = "Show all three", tip = "Shows every reminder for placing them. Click again, or start a fight, to stop. Same as /cozy test.",
              click = function() if ns.UI then ns.UI.SetTesting(not ns.UI.Testing()) end end },
        } },

        { kind = "header", text = "Counting" },
        { kind = "check", label = "Remind and count at all",
          tip = "Off at max level or with XP gain switched off anyway. Same as /cozy on and /cozy off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "slider", label = "Well Fed: more kill XP", min = 0, max = 25, step = 1, format = Pct,
          tip = "5% on WoW Forever. Learned from the buff's tooltip when it says, unless you set it here.",
          get = Get("foodPct"), set = Set("foodPct") },
        { kind = "slider", label = "Well-Rested: XP a stack", min = 0, max = 10, step = 1, format = Pct,
          tip = "1% a stack on WoW Forever. Learned from the buff's tooltip when it says, unless you set it here.",
          get = Get("bagPct"), set = Set("bagPct") },
        { kind = "slider", label = "Well-Rested: most stacks", min = 1, max = 5, step = 1,
          get = Get("bagStacks"), set = Set("bagStacks") },
        { kind = "check", label = "Well-Rested counts on quests",
          tip = "The buff says \"experience gains\", so quests and exploration count as well. Untick if the game "
              .. "shows it is kills only.",
          get = Get("bagQuests"), set = Set("bagQuests") },
        { kind = "slider", label = "Camp Tent: rest given", min = 0, max = 25, step = 1,
          format = function(v) return ("%d%% of a level"):format(v) end,
          get = Get("campShare"), set = Set("campShare") },
        { kind = "check", label = "Report at every level-up",
          tip = "A chat line at every level-up saying how much XP missing buffs cost you on that level.",
          get = Get("levelReport"), set = Set("levelReport") },
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
    local s, c = ns.session, ns.char
    local lines = {
        ("Lost this session: %s XP"):format(ns.Commas(ns.Total(s.lost))),
        ("Lost all time: %s XP"):format(ns.Commas(ns.Total(c.lost))),
    }
    if not ns.Active() then lines[#lines + 1] = "Not counting: max level, XP gain off, or switched off." end
    return lines
end

local ready
function Options.Ready() return ready end

function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Cozy Counter",
        icon = ICON,
        accent = { 1.00, 0.62, 0.25 },
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
function CozyCounter_OnAddonCompartmentClick(_, mouseButton)
    if ns.db and ready then Kit.Click(mouseButton) end
end
