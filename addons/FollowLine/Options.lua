-- Follow Line: the options window and the minimap button (both drawn by Kit.lua)
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
        { kind = "header", text = "The line" },
        { kind = "choice", label = "Whose line calls you take",
          options = {
              { "auto", "Auto", "Anyone in a party; only the leader and the assistants in a raid." },
              { "leader", "Leader", "Only the group's leader (and a raid's assistants)." },
              { "anyone", "Anyone", "Anyone in the group, in a raid too." },
          },
          get = Get("who"), set = Set("who") },
        { kind = "check", label = "Follow without a click",
          tip = "Only where the game allows it. The game normally only starts a follow from your own click or key press. Where it does let addons do it, this makes you fall in by yourself when a line is called. If the game refuses, this turns itself off again.",
          get = Get("auto"), set = Set("auto") },
        { kind = "check", label = "Sound on call and drop-off",
          tip = "A sound when a line is called for you and when you drop off it.",
          get = Get("sound"), set = Set("sound") },
        { kind = "check", label = "Say when others drop off",
          tip = "A line in chat when someone else drops off the line.",
          get = Get("alerts"), set = Set("alerts") },
        { kind = "note", text = "Your key for falling in: Key Bindings > AddOns > Follow Line. It does the same as clicking the Follow button." },

        { kind = "header", text = "Window" },
        { kind = "check", label = "Show the line window",
          tip = "Where the line is ordered and called, and where you see who is following. Same as /line.",
          get = Get("open"), set = Set("open") },
        { kind = "check", label = "Lock window and Follow button",
          tip = "Keeps the line window and the Follow button in place. Unticked, you can drag both.",
          get = Get("locked"), set = Set("locked") },
        { kind = "slider", label = "Size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
          get = Get("scale"), set = Set("scale", function() ns.UI.ApplyLayout() end) },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Announce in group chat",
              tip = "Posts the order in group chat, for players without the addon.",
              click = function() ns.Line.Announce() end },
            { label = "Demo on / off",
              tip = "Four pretend players join, so you can see the window and the Follow button without a group.",
              click = function() ns.ToggleDemo() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the place and size of the window and the Follow button, back to how they started.",
              click = function() ns.ResetSettings() end },
        } },
    }
end

Options.Rows = Rows

local function Status()
    local Line = ns.Line
    local line = Line.line
    if not line then return { "No line called." } end
    local on, followers, total = Line.Summary()
    local out = { ("Line of %d, called by %s: %d of %d following."):format(total, line.by, on, followers) }
    if Line.place == 1 then
        out[2] = "You lead."
    elseif Line.target then
        out[2] = ("You follow %s%s."):format(Line.target, Line.OnLine() and "" or " (not following right now)")
    end
    return out
end

function Options.Init()
    Kit.Setup({
        title = "Follow Line",
        icon = ns.ICON,
        accent = ns.ACCENT,
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.ToggleWindow() end,
        clickHint = "show or hide the line window",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function FollowLine_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
