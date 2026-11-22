-- Healthstone Tracker: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

local function Set(key, after)
    return function(value)
        ns.db[key] = value
        ns.dirty = true
        if after then after() end
    end
end

local function Rows()
    return {
        { kind = "header", text = "Window" },
        { kind = "check", label = "Show the window",
          tip = "It appears by itself when you are in a group with a warlock. Same as /hst.",
          get = Get("shown"), set = Set("shown") },
        { kind = "choice", label = "Who is listed",
          options = {
              { "auto", "Auto", "Everyone in a party, only the players without a healthstone in a raid." },
              { "all", "Everyone", "Every player in the group." },
              { "missing", "Only missing", "Only the players who still need a healthstone." },
          },
          get = Get("filter"), set = Set("filter") },
        { kind = "check", label = "Show soulstones too",
          tip = "Who carries the soulstone buff, and each warlock's own stone, under the healthstone list.",
          get = Get("soul"), set = Set("soul") },
        { kind = "check", label = "Show in every group",
          tip = "Also in groups without a warlock. Same as /hst always.",
          get = Get("always"), set = Set("always") },
        { kind = "check", label = "Minimized",
          tip = "Shrinks the window to its title line and the count. Same as the small button at its right, or /hst min.",
          get = Get("minimized"), set = Set("minimized", function() if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end end) },
        { kind = "check", label = "Lock the window in place",
          tip = "Unticked, you can drag the window by its title.",
          get = Get("locked"), set = Set("locked") },
        { kind = "slider", label = "Window size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
          get = Get("scale"), set = Set("scale", function() ns.UI.ApplyLayout() end) },

        { kind = "header", text = "Warlock" },
        { kind = "check", label = "Click a name to trade a stone",
          tip = "Click a player's name in the window: opens a trade with them and puts your healthstone in it. Only does something on a warlock.",
          get = Get("clickTrade"), set = Set("clickTrade") },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Announce in group chat",
              tip = "Posts who still needs a healthstone, and who has the soulstone.",
              click = function() ns.Group.Announce() end },
            { label = "Demo on / off",
              tip = "Six pretend players join, so you can see the window without a group.",
              click = function() ns.ToggleDemo() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the window's place and size, back to how they started.",
              click = function() ns.ResetSettings() end },
        } },
    }
end

Options.Rows = Rows

local function Status()
    local count = ns.me and ns.me.count or 0
    if count > 0 then
        return { count == 1 and "You carry a healthstone." or ("You carry %d healthstones."):format(count) }
    end
    return { "You carry no healthstone." }
end

function Options.Init()
    Kit.Setup({
        title = "Healthstone Tracker",
        icon = "Interface\\Icons\\INV_Stone_04",
        accent = { 0.56, 0.82, 0.31 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.ToggleWindow() end,
        clickHint = "show or hide the window",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function HealthstoneTracker_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
