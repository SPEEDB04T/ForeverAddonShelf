-- Runback: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

local function Set(key)
    return function(value) ns.Set(key, value) end
end

local function Rows()
    return {
        { kind = "header", text = "Graveyard readout" },
        { kind = "check", label = "Count graveyards and run backs",
          tip = "Switches the whole addon on or off. Same as /runback on and /runback off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "choice", label = "Show the readout",
          options = {
              { "always", "Always" },
              { "pvp", "When it matters", "Only while you are flagged for PvP, or dead." },
              { "never", "Never", "The timer bars still show. /runback prints the numbers." },
          },
          get = Get("readout"), set = Set("readout") },
        { kind = "slider", label = "Path allowance", min = ns.ALLOW_MIN, max = ns.ALLOW_MAX, step = 5, format = "%d%%",
          tip = "The run is counted in a straight line from the graveyard to the body. This much is added "
              .. "for the way round hills and walls.",
          get = Get("allowance"), set = Set("allowance") },
        { kind = "check", label = "Minimized",
          tip = "Hides the timer bars and shrinks the readout to one line. Same as the small button at its right, or /runback min.",
          get = Get("minimized"), set = Set("minimized") },
        { kind = "check", label = "Lock in place",
          tip = "Unticked, drag the readout or a timer bar to move them.",
          get = Get("locked"), set = Set("locked") },

        { kind = "header", text = "Timers" },
        { kind = "check", label = "Enemy players who die near you",
          tip = "A bar for each enemy player you saw die, or got honor for: when they can be back at their body.",
          get = Get("enemy"), set = Set("enemy") },
        { kind = "check", label = "Group members who release",
          tip = "A bar for each group member running back, counted from where their ghost really is.",
          get = Get("group"), set = Set("group") },
        { kind = "check", label = "Your own run back",
          get = Get("own"), set = Set("own") },
        { kind = "check", label = "Sound when an enemy can be back",
          get = Get("sound"), set = Set("sound") },
        { kind = "check", label = "Chat lines for enemy kills",
          tip = "One line when they die, one when they release (if that was seen), one when they can be back.",
          get = Get("chat"), set = Set("chat") },
        { kind = "check", label = "Show test timers",
          tip = "Three test bars, to see what they look like and to move them. Same as /runback test.",
          get = function() return ns.Testing() end,
          set = function(value) ns.SetTesting(value) end },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),
        { kind = "buttons", buttons = {
            { label = "Forget learned graveyards", confirm = true,
              tip = "The addon notes where you really land when you release, and the speed of your ghost. "
                  .. "This forgets both.",
              click = function() ns.Forget() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started, and the readout back in the middle.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local lines = ns.SurveyLines()
    local n = #ns.timers
    if n > 0 then lines[#lines + 1] = n .. (n == 1 and " timer running." or " timers running.") end
    return lines
end

local ready
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Runback",
        icon = "Interface\\Icons\\Spell_Holy_Resurrection",
        accent = { 0.85, 0.78, 0.60 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = function()
            for _, line in ipairs(ns.SurveyLines()) do ns.Print(line) end
        end,
        altHint = "the nearest graveyard in chat",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function Runback_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
