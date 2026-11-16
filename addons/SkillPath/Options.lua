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
        { kind = "header", text = "Path" },
        { kind = "slider", label = "Target skill", min = 0, max = 450, step = 5,
          format = function(value) return value == 0 and "your rank's cap" or tostring(value) end,
          tip = "Where the path stops. 0: your rank's cap. Same as /skillpath target <skill>.",
          get = function() return ns.db.target or 0 end, set = Set("target") },
        { kind = "check", label = "Each point's chance and cost",
          tip = "Under a craft step: every skill point, the chance a craft gives it and what it costs.",
          get = Get("showPoints"), set = Set("showPoints") },
        { kind = "check", label = "Recipes worth learning",
          tip = "Recipes you don't know that would make the path cheaper or longer, and where the game says "
              .. "they are learned.",
          get = Get("showOptions"), set = Set("showOptions") },
        { kind = "check", label = "Open on the SkillPath tab",
          tip = "The professions window opens on the SkillPath tab. Off: on its recipe list, as usual.",
          get = Get("openOnTab"), set = function(value) ns.db.openOnTab = value end },

        { kind = "header", text = "Reagents" },
        { kind = "check", label = "Reagents in the bank are free",
          tip = "What is in your bank counts like what is in your bags. Off: only your bags count.",
          get = Get("useBank"), set = Set("useBank") },
        { kind = "check", label = "Scan when the auction house opens",
          tip = "Reads reagent prices a few seconds after the auction house opens, one search at a time. "
              .. "Prices under half an hour old are skipped. Slutmog Scout's and Slutmog Shop's searches go first.",
          get = Get("autoScan"), set = function(value) ns.db.autoScan = value end },
        { kind = "slider", label = "Old prices after", min = 1, max = 24, step = 1,
          format = function(value) return ("%d h"):format(value) end,
          tip = "An older auction price is still used, and marked old.",
          get = function() return ns.db.staleHours or 3 end, set = Set("staleHours") },
        { kind = "buttons", buttons = {
            { label = "Scan now", tip = "The auction house must be open. Same as /skillpath scan.",
              click = function() ns.Prices.StartScan(true) end },
            { label = "Forget prices", confirm = true,
              tip = "Every auction price on this realm and every vendor price seen. Same as /skillpath forget.",
              click = function() ns.Prices.Forget() end },
        } },

        { kind = "header", text = "Selling what you make" },
        { kind = "check", label = "Count leftovers at the vendor price",
          tip = "What the path makes and never uses counts at its vendor price, so a recipe whose result sells "
              .. "for more can be the cheaper way up. Off: it counts as nothing.",
          get = Get("sellVendor"), set = Set("sellVendor") },
        { kind = "check", label = "Count auction house sales",
          tip = "Leftovers count at the cheapest auction price after the 5% cut, for as many as were seen to "
              .. "sell: units listed at one scan and gone at the next. An item needs 4 hours of scans first. "
              .. "The rest counts at the vendor price. What you craft is scanned too.",
          get = Get("sellAH"), set = Set("sellAH") },
        { kind = "slider", label = "Days of sales to count", min = 1, max = 14, step = 1,
          format = function(value) return ("%d %s"):format(value, value == 1 and "day" or "days") end,
          tip = "With 2 a day sold and 3 days, 6 count at the auction price. The rest go to a vendor.",
          get = function() return ns.db.sellDays or 3 end, set = Set("sellDays") },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Open the SkillPath tab",
              tip = "In the professions window or the auction house, whichever is open. Same as /skillpath.",
              click = function() ns.UI.Toggle() end },
            { label = "Print the path", tip = "Same as /skillpath print.",
              click = function() ns.Report() end },
            { label = "Reset settings", confirm = true, tip = "Saved recipes and prices are kept.",
              click = function() ns.ResetSettings() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    if not ns.db then return nil end
    local plan = ns.Plan()
    if not plan.ok then return { plan.why } end
    local title, line = ns.UI.Summary(plan)
    return { title .. ". " .. line }
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
        clickHint = "open the SkillPath tab",
        status = Status,
    })
end
