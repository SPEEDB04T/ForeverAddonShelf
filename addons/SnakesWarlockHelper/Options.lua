-- Snakes Warlock Helper: the minimap button (drawn by Kit.lua). The options themselves are
-- the Options tab of the addon's own window (Panel.lua), so the page under Options > AddOns
-- only points there.
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Status()
    local list = ns.Reminders.Build()
    local n = type(list) == "table" and #list or 0
    if n == 0 then return { "Nothing is missing." } end
    return { n == 1 and "1 reminder showing." or ("%d reminders showing."):format(n) }
end

local ready
-- Warlocks only: called from Core's Init once the saved settings are loaded.
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Snakes Warlock Helper",
        icon = "Interface\\Icons\\Spell_Shadow_GatherShadows",
        accent = { 0.58, 0.51, 0.79 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        openOptions = function() ns.Panel.Open("options") end,
        pageNote = "The options are a tab of the addon's own window. /swh options opens it too.",
        click = function() ns.Panel.Toggle() end,
        clickHint = "open or close the window",
        status = Status,
    })
end

function Options.Ready()
    return ready == true
end
