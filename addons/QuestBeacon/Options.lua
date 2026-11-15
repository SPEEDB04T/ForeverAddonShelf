-- Quest Beacon: the options window (drawn by Kit.lua). No minimap button: there is nothing to
-- click day to day. The options are under Options > AddOns, in the addon list next to the
-- minimap, and behind /beacon.
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
        { kind = "header", text = "When you pick up a quest that can't be shared" },
        { kind = "check", label = "Tell my group where to get it",
          tip = "One line in group chat: the quest, who gives it, the area and the coordinates. Nothing is "
              .. "said for quests you can share, when everyone in the group already has the quest, or when "
              .. "a group member called the same quest out in the last ten minutes. Same as /beacon on and "
              .. "/beacon off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "choice", label = "Tell",
          options = {
              { "party", "Parties", "Not raids." },
              { "always", "Parties and raids" },
          },
          get = Get("where"), set = Set("where") },
        { kind = "check", label = "Add a map pin to the line",
          tip = "A link at the end of the line. Anyone who clicks it gets a pin on that spot on their map, "
              .. "with or without this addon. If the game does not pass the link on, the line is sent again "
              .. "without it.",
          get = Get("links"), set = Set("links") },

        { kind = "header", text = "When a group member calls one out" },
        { kind = "choice", label = "Give me",
          tip = "Only for a quest you do not have, and only while you have no map pin of your own. The pin "
              .. "goes away when you pick the quest up.",
          options = {
              { "off", "Nothing" },
              { "pin", "A map pin" },
              { "track", "A map pin and the arrow", "The game's arrow and distance to the pin." },
          },
          get = Get("follow"), set = Set("follow") },

        { kind = "buttons", buttons = {
            { label = "Show a test line",
              tip = "Prints in your own chat what your group would be told for a quest picked up where "
                  .. "you stand. Nothing is sent. Same as /beacon test.",
              click = function() ns.Test() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local ready
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Quest Beacon",
        icon = "Interface\\Icons\\INV_Misc_Map_01",
        accent = { 1.00, 0.82, 0.00 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        status = ns.StatusLines,
        minimap = false,
    })
end

-- The addon's line in the list of addons next to the minimap.
function QuestBeacon_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
