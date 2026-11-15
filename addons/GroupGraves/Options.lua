-- Group Graves: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

-- ns.Set (Core.lua) stores the value and redraws the markers.
local function Set(key)
    return function(value) ns.Set(key, value) end
end

local function Rows()
    return {
        { kind = "header", text = "Markers" },
        { kind = "check", label = "Mark where group members died",
          tip = "The game's corpse tombstone on the world map. Point at it to see whose corpse it is. "
              .. "Same as /graves on and /graves off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "check", label = "Mark from the moment of death",
          tip = "Unticked, a marker appears when the member releases: until then their own dot on the map "
              .. "is on the body anyway.",
          get = Get("early"), set = Set("early") },
        { kind = "slider", label = "Marker size", min = ns.SIZE_MIN, max = ns.SIZE_MAX, step = 1, format = "%d",
          get = Get("size"), set = Set("size") },
        { kind = "check", label = "Names under the markers",
          tip = "Without names, point at a marker to see whose corpse it is.",
          get = Get("names"), set = Set("names") },
        { kind = "check", label = "Battlegrounds and arenas too",
          tip = "Also mark corpses in battlegrounds and arenas. Same as /graves pvp.",
          get = Get("pvp"), set = Set("pvp") },
        { kind = "check", label = "Show test markers",
          tip = "Three test markers around you, to see what the markers look like without anyone dying. "
              .. "Same as /graves test.",
          get = function() return ns.Testing() end,
          set = function(value) ns.SetTesting(value) end },

        { kind = "header", text = "Chat" },
        { kind = "choice", label = "Line when someone releases",
          options = {
              { "off", "Never" },
              { "party", "In a party", "Not in raids, where a wipe would fill the chat." },
              { "always", "Always" },
          },
          get = Get("chat"), set = Set("chat") },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),
        { kind = "buttons", buttons = {
            { label = "Forget every marker", confirm = true,
              tip = "Removes all markers now. Members who are still dead and have the addon show up again "
                  .. "when they next report in.",
              click = function() ns.Clear() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local lines = { ns.db.enabled and "Markers are on." or "Markers are off." }
    local n = ns.Count()
    if n > 0 then lines[#lines + 1] = n .. (n == 1 and " corpse marked." or " corpses marked.") end
    return lines
end

local ready
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Group Graves",
        icon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
        accent = { 0.85, 0.78, 0.60 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = function() ns.PrintList() end,
        altHint = "list the marked corpses in chat",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function GroupGraves_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
