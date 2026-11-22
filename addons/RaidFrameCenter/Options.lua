-- Raid Frame Center: the options window and the minimap button (both drawn by Kit.lua)
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

local function Size(label, key, tip)
    return { kind = "slider", label = label, min = ns.SIZE_MIN, max = ns.SIZE_MAX, step = 5, format = "%d%%",
             tip = tip, get = Get(key), set = Set(key) }
end

local function Rows()
    return {
        { kind = "header", text = "Centering" },
        { kind = "check", label = "Use Raid Frame Center",
          tip = "Switches the whole addon on or off. Off, the frames go back to Edit Mode's place and size. "
              .. "Same as /rfc on and /rfc off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "check", label = "Center the raid frames",
          tip = "The raid frames grow out from the middle of the box you placed in Edit Mode, "
              .. "the same amount to each side, whoever joins or leaves.",
          get = Get("centerRaid"), set = Set("centerRaid") },
        { kind = "check", label = "Center the party frames",
          tip = "The same for the party frames, raid style or not.",
          get = Get("centerParty"), set = Set("centerParty") },
        { kind = "choice", label = "Grow",
          options = {
              { "down", "Down", "The top edge stays where it is; more rows go below." },
              { "both", "Up and down", "The middle stays where it is." },
              { "up", "Up", "The bottom edge stays where it is; more rows go above." },
          },
          get = Get("grow"), set = Set("grow") },
        { kind = "note", text = "Move the frames in Edit Mode as usual. The middle of the box you see there "
              .. "is the middle they keep." },

        { kind = "header", text = "Size by group" },
        { kind = "note", text = "Percent of the size set in Edit Mode. Width and height keep Edit Mode's shape. "
              .. "A change during a fight waits for it to end." },
        Size("Party", "sizeParty", "Party frames, and raid frames in a party."),
        Size("Raid up to 10", "size10"),
        Size("Raid up to 20", "size20"),
        Size("Raid up to 25", "size25"),
        Size("Raid up to 40", "size40"),

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),
        { kind = "buttons", buttons = {
            { label = "Take the middle again",
              tip = "Forgets the remembered middle for this Edit Mode layout and takes it from where "
                  .. "Edit Mode puts the frames now. Same as /rfc forget.",
              click = function() ns.ForgetSpots() end },
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
        title = "Raid Frame Center",
        icon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
        accent = { 1, 0.82, 0 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = function()
            for _, line in ipairs(ns.StatusLines()) do ns.Print(line) end
        end,
        altHint = "what it is doing, in chat",
        status = ns.StatusLines,
    })
end

-- The addon's line in the list of addons next to the minimap.
function RaidFrameCenter_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
