-- Mana Piñata: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local ICON = "Interface\\AddOns\\ManaPinata\\Art\\Pinata"

local function Get(key)
    return function() return ns.db[key] end
end

-- ns.Set (ManaPinata.lua) stores the value and updates every nameplate.
local function Set(key)
    return function(value) ns.Set(key, value) end
end

local function ToggleTest()
    ns.SetTesting(not ns.Testing())
    ns.Print(ns.Testing() and "test piñatas on every nameplate. Right-click again to hide them."
        or "test piñatas hidden.")
end

local function Rows()
    return {
        { kind = "header", text = "Piñata" },
        { kind = "check", label = "Piñata on Judgement of Wisdom",
          tip = "A piñata over every enemy with Judgement of Wisdom on it. Any paladin's Judgement of Wisdom "
              .. "counts, not only your own. Same as /pinata on and /pinata off.",
          get = Get("enabled"), set = Set("enabled") },
        { kind = "check", label = "Blue health bar too",
          tip = "That enemy's health bar is drawn in mana blue for as long as the debuff lasts, then goes back to "
              .. "its own colour. Same as /pinata bar.",
          get = Get("colorBar"), set = Set("colorBar") },
        { kind = "check", label = "Test piñatas on nameplates",
          tip = "Shows a test piñata on every nameplate. "
              .. "For sizing and placing it without a paladin around, with the blue health bar if that is on. "
              .. "The real ones are hidden meanwhile, and the test ends by itself when a fight starts. "
              .. "Same as /pinata test.",
          get = function() return ns.Testing() end,
          set = function(value) ns.SetTesting(value) end },

        { kind = "header", text = "Look" },
        { kind = "slider", label = "Size", min = 16, max = 96, step = 1, format = "%d",
          get = Get("size"), set = Set("size") },
        { kind = "slider", label = "Higher or lower", min = -100, max = 100, step = 1, format = "%d",
          tip = "Moves the piñata up (above 0) or down (below 0). At 0 it hangs just above the nameplate.",
          get = Get("yOffset"), set = Set("yOffset") },
        { kind = "slider", label = "Left or right", min = -100, max = 100, step = 1, format = "%d",
          get = Get("xOffset"), set = Set("xOffset") },
        { kind = "check", label = "Swing on its rope",
          tip = "Piñatas that are already up during a fight change when the fight ends.",
          get = Get("swing"), set = Set("swing") },

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
    local lines = { ns.db.enabled and "Piñatas are on." or "Piñatas are off." }
    if ns.Testing() then lines[#lines + 1] = "Test piñatas are showing." end
    if ns.NativeError() then lines[#lines + 1] = "Not working on this client: /pinata debug says why." end
    if ns.BarError() then lines[#lines + 1] = "Health bars can't be coloured on this client: /pinata debug says why." end
    return lines
end

local ready
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Mana Piñata",
        icon = ICON,
        accent = { 0.35, 0.78, 1.00 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = ToggleTest,
        altHint = "test piñatas on or off",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function ManaPinata_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
