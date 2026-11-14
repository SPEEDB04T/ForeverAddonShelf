-- Totem Council: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

local function Set(key)
    return function(value) ns.db[key] = value end
end

-- Settings of the bar itself. The game only lets the bar change out of combat, so in a
-- fight the new value is kept and applied when the fight ends.
local function SetBar(key)
    return function(value)
        ns.db[key] = value
        ns.HUD.ApplySecure()
        if InCombatLockdown() then ns.Print("the bar changes when the fight is over.") end
    end
end

local function Percent(value)
    return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local function Rows()
    local rows = {}
    local function add(row) rows[#rows + 1] = row end

    if ns.isShaman then
        add({ kind = "header", text = "Totem bar" })
        add({ kind = "check", label = "Show the totem bar", tip = "Same as /totems.",
              get = Get("shown"), set = SetBar("shown") })
        add({ kind = "check", label = "Lock the bar in place",
              tip = "Unticked, you can drag the bar by one of its icons.",
              get = Get("locked"), set = Set("locked") })
        add({ kind = "slider", label = "Bar size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
              get = Get("scale"), set = SetBar("scale") })
        add({ kind = "slider", label = "Opacity while all is well", min = 0.1, max = 1, step = 0.05, format = Percent,
              tip = "How solid the bar is while nothing needs your attention. It is always solid in a fight, "
                  .. "under the mouse, and while a totem is missing or running out.",
              get = Get("idleAlpha"), set = Set("idleAlpha") })
        add({ kind = "check", label = "Left-click an icon to drop the planned totem",
              get = Get("clickCast"), set = SetBar("clickCast") })
        add({ kind = "check", label = "Bar ignores the mouse",
              tip = "Clicks go straight through the bar. Untick it here to get the bar's clicks and tooltips back.",
              get = Get("clickThrough"), set = SetBar("clickThrough") })

        add({ kind = "header", text = "Warnings" })
        add({ kind = "check", label = "Ping when a planned totem goes missing or doubles up",
              get = Get("sound"), set = Set("sound") })
        add({ kind = "check", label = "Warn about missing totems out of combat too",
              get = Get("warnAlways"), set = Set("warnAlways") })
        add({ kind = "slider", label = "Timer turns yellow below", min = 3, max = 30, step = 1, format = "%d s",
              tip = "A totem with less time left than this is shown as running out.",
              get = Get("soonSeconds"), set = Set("soonSeconds") })

        add({ kind = "header", text = "Plan" })
        add({ kind = "check", label = "Empty plan slots adopt the totem you drop",
              get = Get("autoAdopt"), set = Set("autoAdopt") })
    else
        add({ kind = "note", text = "The totem bar is for Shamans. On this character the addon only shows the "
            .. "group plan: who drops which totem, and where two shamans overlap." })
    end

    local buttons = {
        { label = "Group plan", tip = "Who drops what, the overlaps, and a way to settle them. Same as /totems plan.",
          click = function() ns.Board.Toggle() end },
        { label = "Demo on / off", tip = "Two pretend shamans join your group, so you can see the plan without one.",
          click = function() ns.ToggleDemo() end },
    }
    if ns.isShaman then
        buttons[#buttons + 1] = { label = "Clear my plan", confirm = true,
            tip = "Empties your four plan slots.", click = function() ns.ClearPlan() end }
    end
    add({ kind = "buttons", buttons = buttons })

    if ns.isShaman then
        add({ kind = "header", text = "Minimap" })
        add(Kit.MinimapRow())
        add({ kind = "buttons", buttons = {
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page and the bar's place back to how they started. Your plan stays.",
              click = function() ns.ResetSettings() end },
        } })
    end
    return rows
end
Options.Rows = Rows

local function Status()
    if not ns.isShaman then return nil end
    local planned, up = 0, 0
    for slot = 1, 4 do
        if ns.cdb.plan[slot] then planned = planned + 1 end
        if ns.active[slot] then up = up + 1 end
    end
    return { ("%d of 4 totems planned, %d standing."):format(planned, up) }
end

function Options.Init()
    Kit.Setup({
        title = "Totem Council",
        icon = "Interface\\Icons\\Spell_Nature_Windfury",
        accent = { 0.20, 0.60, 1.00 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.Board.Toggle() end,
        clickHint = "the group plan",
        status = Status,
        minimap = ns.isShaman and true or false,   -- other classes reach the plan with /totems plan
    })
end

-- The addon's line in the list of addons next to the minimap.
function TotemCouncil_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
