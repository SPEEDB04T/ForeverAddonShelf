-- Turn-in Route: the options window and the minimap button (both drawn by Kit.lua)
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
        ns.Refresh()
    end
end

local function Rows()
    return {
        { kind = "header", text = "Route" },
        { kind = "check", label = "Use the hearthstone",
          tip = "Plans a hearth when it is ready (or will be by then) and the addon knows where it takes you: "
              .. "it learns that when you bind it or arrive with it. Same as /turnin hearth.",
          get = Get("useHearth"), set = Set("useHearth") },
        { kind = "check", label = "Use flight paths",
          tip = "Plans flights between the flight paths this character knows. The addon learns them each time "
              .. "you open a flight master's map. Same as /turnin flights.",
          get = Get("useFlights"), set = Set("useFlights") },
        { kind = "check", label = "Use boats and zeppelins",
          tip = "Plans the boats, zeppelins and the Deeprun Tram your faction can ride. Same as /turnin boats.",
          get = Get("useBoats"), set = Set("useBoats") },
        { kind = "check", label = "Follow the route",
          tip = "Once the super tracked quest is handed in, the quest arrow moves on to the next stop of the route.",
          get = Get("follow"), set = function(value) ns.db.follow = value end },

        { kind = "header", text = "Window" },
        { kind = "slider", label = "Window size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
          get = function() return ns.db.scale or 1 end,
          set = function(value)
              ns.db.scale = value
              ns.UI.ApplyScale()
          end },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Show / hide the window", tip = "Same as /turnin.",
              click = function() ns.UI.Toggle() end },
            { label = "Quest log tab", tip = "Opens the route inside the quest log. Same as /turnin log.",
              click = function() ns.QuestLog.Open() end },
            { label = "Print the route", tip = "Lists the legs in chat. Same as /turnin list.",
              click = function() ns.Report() end },
        } },
        { kind = "buttons", buttons = {
            { label = "Forget flight paths", confirm = true,
              tip = "Forgets this character's flight paths and hearthstone place; they are learned again as you play. "
                  .. "Same as /turnin forget.",
              click = function() ns.ForgetFlights() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the window's place and size, back to how they started. "
                  .. "Learned flight paths stay.",
              click = function() ns.ResetSettings() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local plan = ns.Compute()
    if type(plan) ~= "table" then return nil end
    return { plan.error or ns.Plan.Summary(plan) }
end

function Options.Init()
    Kit.Setup({
        title = "Turn-in Route",
        icon = ns.ICON,
        accent = { 0.25, 0.78, 0.92 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.UI.Toggle() end,
        clickHint = "show or hide the route",
        status = Status,
    })
end
