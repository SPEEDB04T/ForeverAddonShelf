-- Aura Advisor: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

-- ns.Set (Core.lua) checks the value, stores it and makes the advisor think again.
local function Set(key)
    return function(value) ns.Set(key, value) end
end

local function Rows()
    return {
        { kind = "header", text = "Advice" },
        { kind = "check", label = "Glow the aura to switch to",
          tip = "The game's spell-alert glow on that aura's stance bar button, and on any action bar button with it. "
              .. "In a fight it stays until you switch, the advice changes or the fight ends. Its tooltip says why. "
              .. "Same as /aura glow.",
          get = Get("glow"), set = Set("glow") },
        { kind = "choice", label = "Play style",
          tip = "What the advice is for. Same as /aura style.",
          options = {
              { "auto", "Auto", "Your group role if you have one; tank while Righteous Fury is on; damage otherwise." },
              { "damage", "Damage", "Retribution for physical hits, Devotion when crits and crushing blows land." },
              { "tank", "Tank", "Devotion for physical hits, Retribution against three or more enemies." },
              { "healer", "Healer", "Devotion for physical hits; Concentration as soon as casts get pushed back." },
          },
          get = Get("style"), set = Set("style") },
        { kind = "choice", label = "Aura between fights",
          tip = "The aura the advisor sends you back to when nothing is hitting you. Same as /aura default.",
          options = {
              { "auto", "Auto", "Retribution for damage, Devotion for a tank or healer." },
              { "devotion", "Devotion", "Devotion Aura." },
              { "retribution", "Retribution", "Retribution Aura." },
              { "concentration", "Concentration", "Concentration Aura." },
          },
          get = Get("idle"), set = Set("idle") },
        { kind = "choice", label = "Sensitivity",
          tip = "How far ahead another aura must be before the advisor suggests it. Same as /aura sens.",
          options = {
              { "low", "Low", "Only clear cases. Few suggestions." },
              { "normal", "Normal", "" },
              { "high", "High", "Suggests a switch early. More suggestions." },
          },
          get = Get("sensitivity"), set = Set("sensitivity") },
        { kind = "check", label = "Suggest default after a fight",
          tip = "Suggests your aura between fights (above) once a fight is over. Unticked, the advisor only speaks up in fights.",
          get = Get("betweenFights"), set = Set("betweenFights") },

        { kind = "header", text = "Alerts in a fight" },
        { kind = "check", label = "Play a sound", get = Get("sound"), set = Set("sound") },
        { kind = "check", label = "Show a line on screen",
          tip = "The aura's icon and name in the middle of the screen when a switch is suggested in a fight. Same as /aura banner.",
          get = Get("banner"), set = Set("banner") },
        { kind = "check", label = "Write a line in chat",
          tip = "The aura's name in chat when a switch is suggested in a fight. Off unless you turn it on. Same as /aura chat.",
          get = Get("chat"), set = Set("chat") },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Why this aura?",
              tip = "Prints the aura on, the one to switch to and why, in one line. Same as /aura; /aura debug has every aura's points.",
              click = function() ns.PrintWhy() end },
            { label = "Pretend Fire damage",
              tip = "Shows what a suggestion looks like without a fight. Same as /aura test fire; /aura test off ends it.",
              click = function() ns.Test(ns.testing and "off" or "fire") end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local res = ns.result
    if not res then return {} end
    if res.dead then return { "Dead" } end
    -- The aura on, then the one to switch to: names only.
    local lines = { res.current and ns.known[res.current] and ns.TwoWords(res.current) or "No aura" }
    if res.shown and ns.known[res.shown] then
        lines[#lines + 1] = ns.UI.Paint("GREEN_FONT_COLOR", ns.TwoWords(res.shown))
    end
    return lines
end

Options.Status = Status

local ready
function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = "Aura Advisor",
        icon = "Interface\\Icons\\Spell_Holy_DevotionAura",
        accent = { 0.96, 0.55, 0.73 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = function() ns.PrintWhy() end,
        altHint = "why this aura, in chat",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function AuraAdvisor_OnAddonCompartmentClick(_, mouseButton)
    if not ns.db then return end
    if not ns.enabled then ns.Print("Paladins only") return end
    Kit.Click(mouseButton)
end
