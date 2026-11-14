-- Kneel Together: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local ICON = "Interface\\Icons\\Spell_Holy_PrayerOfHealing"

local function Get(key)
    return function() return ns.db[key] end
end

local function Set(key)
    return function(value) ns.Set(key, value) end
end

local function Rows()
    return {
        { kind = "header", text = "When you call" },
        { kind = "slider", label = "Countdown", min = 0, max = 10, step = 1,
          format = function(v) return v == 0 and "none" or (v .. " s") end,
          tip = "How long everyone sees \"Kneel in 3\" before it happens. With a countdown each player's "
              .. "ping is evened out, so the kneels land together. /kneelall 5 or /kneelall now for one call.",
          get = Get("delay"), set = Set("delay") },
        { kind = "choice", label = "Kneel before",
          options = {
              { "target", "My target", "Everyone kneels before the player you have targeted, you included. "
                  .. "With no player targeted, everyone just kneels." },
              { "me", "Me", "Everyone kneels before you, and you stay standing. Same as /kneelall me." },
          },
          get = Get("before"), set = Set("before") },
        { kind = "check", label = "Also say it in group chat",
          tip = "One line in party or raid chat (\"Kneel in 3!\"), for people who don't have the addon.",
          get = Get("announce"), set = Set("announce") },
        { kind = "buttons", buttons = {
            { label = "Kneel", tip = "Calls it now. Same as /kneelall.", click = function() ns.Call("K") end },
            { label = "Rise", tip = "Everyone stands up again. Same as /kneelall rise.",
              click = function() ns.Call("S") end },
            { label = "Call it off", tip = "Stops a countdown that is running. Same as /kneelall cancel.",
              click = function() ns.Cancel() end },
            { label = "Who has the addon?", tip = "Lists who in your group will hear a call. Same as /kneelall check.",
              click = function() ns.RollCall() end },
        } },

        { kind = "header", text = "When someone else calls" },
        { kind = "choice", label = "I kneel for",
          options = {
              { "anyone", "Anyone in my group" },
              { "lead", "Leader and assistants" },
              { "off", "Nobody" },
          },
          tip = "Whose calls move your character. Your own calls always do.",
          get = Get("obey"), set = Set("obey") },
        { kind = "check", label = "Get off my mount first",
          tip = "A mounted character doesn't kneel, so the addon dismounts you just before. Never in the air.",
          get = Get("dismount"), set = Set("dismount") },
        { kind = "check", label = "Sound when a call comes in",
          get = Get("sound"), set = Set("sound") },

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

local OBEY = { anyone = "You kneel for anyone in your group.", lead = "You kneel for the leader and assistants.",
               off = "You kneel for nobody." }

local function Status()
    local lines = { OBEY[ns.db.obey] or OBEY.anyone }
    if ns.Pending() then lines[#lines + 1] = "A call is counting down." end
    return lines
end

local ready
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Kneel Together",
        icon = ICON,
        accent = { 0.85, 0.66, 1.00 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.Call("K") end,
        clickHint = "call the kneel",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function KneelTogether_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
