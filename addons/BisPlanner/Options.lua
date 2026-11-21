-- BiS Planner: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Filter(key)
    return function() return ns.char.filters[key] end
end

local function SetFilter(key)
    return function(value)
        ns.char.filters[key] = value
        ns.Changed()
    end
end

local function Rows()
    return {
        { kind = "header", text = "Gear the plan may use" },
        { kind = "choice", label = "Best quality",
          tip = "Gear above this quality is left out of the plan.",
          options = { { 5, "Any" }, { 4, "Epic" }, { 3, "Rare" }, { 2, "Uncommon" } },
          get = function() return math.max(2, math.min(5, ns.char.filters.maxQuality or 5)) end,
          set = SetFilter("maxQuality") },
        { kind = "choice", label = "Armor",
          tip = "Your class's own: only the heaviest armor your class wears at the plan's level (plate for warriors and paladins from 40, mail for hunters and shamans from 40, leather for rogues and druids, cloth for the rest). Any: everything you can wear, such as leather on a warrior.",
          options = { { "own", "Your class's own" }, { "any", "Any you can wear" } },
          get = function() return ns.char.filters.armor == "any" and "any" or "own" end,
          set = SetFilter("armor") },
        { kind = "check", label = "Crafted gear",
          tip = "Gear a profession makes. The plan row names the profession.",
          get = Filter("crafted"), set = SetFilter("crafted") },
        { kind = "check", label = "Reputation gear",
          tip = "Gear that needs a standing with a faction. The plan row names the faction and the standing.",
          get = Filter("rep"), set = SetFilter("rep") },
        { kind = "check", label = "PvP gear",
          tip = "Gear that needs a PvP rank, and Forever's \"Premier\" PvP sets. The plan row names the rank.",
          get = Filter("pvp"), set = SetFilter("pvp") },

        { kind = "header", text = "Weapons" },
        { kind = "choice", label = "Hands",
          tip = "Any: whichever scores best, a two-hander or a main hand with an off hand.",
          options = { { "any", "Any" }, { "2h", "Two-handed" }, { "1h", "One-handed" } },
          get = function()
              local value = ns.char.filters.weapons
              return (value == "2h" or value == "1h") and value or "any"
          end,
          set = SetFilter("weapons") },
        { kind = "check", label = "Weapons in the off hand",
          tip = "The off hand may hold a weapon, for classes that dual wield. Off: a shield or a held item only.",
          get = function() return ns.DualWield() end,
          set = SetFilter("dualWield") },

        { kind = "header", text = "Tooltips" },
        { kind = "check", label = "Planner line on item tooltips",
          tip = "An item's tooltip says whether it is in your plan, or how it scores against the plan's item for that slot.",
          get = function() return ns.db.tooltip end,
          set = function(value) ns.db.tooltip = value and true or false end },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Open the planner", tip = "Same as /bisplan.",
              click = function() ns.UI.Toggle() end },
            { label = "Print the plan", tip = "Same as /bisplan print.",
              click = function() ns.Report() end },
            { label = "Bring back left-out items",
              tip = "Items you right-clicked out of the plan may be used again. Same as /bisplan unhide.",
              click = function()
                  local n = ns.BringBack()
                  ns.Print(n == 0 and "No item was left out." or ("%d left-out %s back."):format(n, n == 1 and "item is" or "items are"))
              end },
            { label = "Reset settings", confirm = true,
              tip = "This character's filters, level and left-out items. Your sets of weights are kept.",
              click = function() ns.ResetSettings() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    if not ns.db then return nil end
    local plan = ns.char.plan
    if type(plan) ~= "table" then return { "No plan yet: give a stat a weight or a goal." } end
    return { ns.Summary(plan) .. "." }
end
Options.Status = Status

function Options.Init()
    Kit.Setup({
        title = ns.NAME,
        icon = ns.ICON,
        accent = { 1, 0.82, 0 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.UI.Toggle() end,
        clickHint = "open the planner",
        status = Status,
    })
end
