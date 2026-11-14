-- Friend Dots: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

-- ns.Set (FriendDots.lua) stores the value and redraws every dot.
local function Set(key)
    return function(value) ns.Set(key, value) end
end

local function Rows()
    return {
        { kind = "header", text = "Dots" },
        { kind = "check", label = "Show dots on friendly players",
          tip = "Unticked, friendly nameplates look the way the game draws them. Same as /fdots on and /fdots off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "choice", label = "Look",
          options = {
              { "dot", "Dots", "A small dot in the player's class colour." },
              { "icon", "Class icons", "The player's class icon." },
          },
          get = Get("style"), set = Set("style") },
        { kind = "slider", label = "Dot size", min = 4, max = 64, step = 1, format = "%d",
          get = Get("dotSize"), set = Set("dotSize") },
        { kind = "slider", label = "Icon size", min = 4, max = 64, step = 1, format = "%d",
          get = Get("iconSize"), set = Set("iconSize") },
        { kind = "slider", label = "Higher or lower", min = -100, max = 100, step = 1, format = "%d",
          tip = "Moves the dots up (above 0) or down (below 0) from where the nameplate sits.",
          get = Get("yOffset"), set = Set("yOffset") },
        { kind = "choice", label = "Where",
          options = {
              { "all", "Everywhere" },
              { "pvp", "Only in PvP", "Only in battlegrounds and arenas." },
          },
          get = Get("where"), set = Set("where") },
        { kind = "check", label = "Highlight your own party",
          tip = "Members of your own party get a bigger dot inside a gold ring and are drawn on top of other dots.",
          get = Get("groupRing"), set = Set("groupRing") },
        { kind = "check", label = "Dots on friendly NPCs too",
          get = Get("npcs"), set = Set("npcs") },

        { kind = "header", text = "Health and names" },
        { kind = "choice", label = "Health",
          options = {
              { "bar", "Line", "A hairline under the dot." },
              { "fill", "Dot drains", "The dot itself empties as health drops." },
              { "off", "Off" },
          },
          get = Get("hp"), set = Set("hp") },
        { kind = "check", label = "Show the health line at full health too",
          get = Get("hpAlways"), set = Set("hpAlways") },
        { kind = "choice", label = "Names",
          options = {
              { "off", "Off" },
              { "target", "Your target" },
              { "all", "Everyone" },
          },
          get = Get("names"), set = Set("names") },

        { kind = "header", text = "Nameplates" },
        { kind = "check", label = "Clicks go through the hidden nameplates",
          tip = "An invisible nameplate no longer catches clicks meant for the world. Changes outside combat.",
          get = Get("clickThrough"), set = Set("clickThrough") },
        { kind = "check", label = "Friendly player nameplates are on",
          tip = "The game's own setting. The dots sit on these nameplates: without them there are no dots. "
              .. "Same as /fdots plates.",
          get = function() return ns.PlatesShown() end,
          set = function(value) ns.SetPlates(value) end },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),
        { kind = "buttons", buttons = {
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local lines = { ns.db.enabled and "Dots are on." or "Dots are off." }
    if not ns.PlatesShown() then lines[#lines + 1] = "Friendly player nameplates are off, so no dots show." end
    return lines
end

local ready
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Friend Dots",
        icon = "Interface\\Icons\\INV_Misc_Orb_01",
        accent = { 0.50, 0.83, 1.00 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = function() ns.Set("enabled", not ns.db.enabled) end,
        altHint = "dots on or off",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function FriendDots_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
