-- SkillPath: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

local function Set(key)
    return function(value)
        ns.db[key] = value
        ns.Changed()
    end
end

local function Rows()
    return {
        { kind = "header", text = "Guide" },
        { kind = "slider", label = "Target skill", min = 0, max = 450, step = 5,
          format = function(value) return value == 0 and "your rank's cap" or tostring(value) end,
          tip = "Where the guide stops. 0 goes as far as your current trainer rank allows; past it, the guide "
              .. "says where to train the next rank. Same as /skillpath target <skill>.",
          get = function() return ns.db.target or 0 end, set = Set("target") },
        { kind = "check", label = "A line for every skill point",
          tip = "Under each recipe, one line per point: the chance a craft gives it and the crafts and gold it takes.",
          get = Get("showPoints"), set = Set("showPoints") },
        { kind = "check", label = "Recipes you could learn",
          tip = "Recipes you don't know yet that would make the guide cheaper or take it further, with where "
              .. "the game says they are learned. They are never part of the guide itself.",
          get = Get("showOptions"), set = Set("showOptions") },
        { kind = "check", label = "Open beside the professions window",
          tip = "Shows the guide to the right of the professions window when you open a profession, and closes "
              .. "it with that window.",
          get = Get("autoShow"), set = function(value) ns.db.autoShow = value end },

        { kind = "header", text = "Reagents" },
        { kind = "check", label = "Reagents in the bank are free",
          tip = "Counts what is in your bank (and reagent bank) like what is in your bags: already yours, so it "
              .. "costs nothing. Off: only your bags count.",
          get = Get("useBank"), set = Set("useBank") },
        { kind = "check", label = "Scan when the auction house opens",
          tip = "A few seconds after you open the auction house, reads the price of every reagent the guide "
              .. "might use, one search at a time and only when the game allows the next. Reagents scanned in "
              .. "the last half hour are skipped. Slutmog Scout's and Slutmog Shop's searches go first.",
          get = Get("autoScan"), set = function(value) ns.db.autoScan = value end },
        { kind = "slider", label = "Old prices after", min = 1, max = 24, step = 1,
          format = function(value) return ("%d h"):format(value) end,
          tip = "An auction price scanned longer ago than this is still used, but the guide says it is old.",
          get = function() return ns.db.staleHours or 3 end, set = Set("staleHours") },
        { kind = "buttons", buttons = {
            { label = "Scan now",
              tip = "Reads every reagent's auction price now (the auction house must be open). Same as /skillpath scan.",
              click = function() ns.Prices.StartScan(true) end },
            { label = "Forget prices", confirm = true,
              tip = "Forgets every auction price on this realm and every vendor price seen. Same as /skillpath forget.",
              click = function() ns.Prices.Forget() end },
        } },

        { kind = "header", text = "Window" },
        { kind = "slider", label = "Window size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
          tip = "Makes the guide window bigger or smaller.",
          get = function() return ns.db.scale or 1 end,
          set = function(value)
              ns.db.scale = value
              ns.UI.ApplyScale()
          end },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Show / hide the guide", tip = "Same as /skillpath.",
              click = function() ns.UI.Toggle() end },
            { label = "Print the guide", tip = "Every step of the guide in chat. Same as /skillpath print.",
              click = function() ns.Report() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the window's place and size, back to how they started. "
                  .. "Saved recipes and prices are kept.",
              click = function() ns.ResetSettings() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    if not ns.db then return nil end
    local plan = ns.Plan()
    if not plan.ok then return { plan.why } end
    local cost = ns.Money(plan.total)
    return { ("%s %d to %d: %s expected%s."):format(plan.name, plan.from, plan.to, cost,
        plan.totalComplete and "" or " for the priced part") }
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
        clickHint = "show or hide the guide",
        status = Status,
    })
end
