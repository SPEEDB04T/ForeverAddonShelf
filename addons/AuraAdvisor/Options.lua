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

local function Percent(value)
    return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local function Rows()
    return {
        { kind = "header", text = "Frame" },
        { kind = "choice", label = "Show the frame",
          tip = "The row of aura buttons. The aura that is on has a green edge, the one to switch to glows. "
              .. "Same as /aura show. In a fight a change waits until the fight is over.",
          options = {
              { "always", "Always", "The frame is always on screen." },
              { "combat", "In fights", "The frame appears when a fight starts and goes when it ends." },
              { "never", "Never", "No frame. The sound and the line on screen still tell you." },
          },
          get = Get("show"), set = Set("show") },
        { kind = "check", label = "Lock the frame in place",
          tip = "Unticked, you can drag the frame by the text under the buttons (outside a fight).",
          get = Get("locked"), set = Set("locked") },
        { kind = "slider", label = "Frame size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
          get = Get("scale"),
          set = function(value)
              if InCombatLockdown() then ns.Print("can't resize the frame in a fight.") return end
              ns.Set("scale", value)
          end },
        { kind = "slider", label = "Faded when it has nothing to say", min = 0.2, max = 1, step = 0.05, format = Percent,
          tip = "How solid the frame is while your aura is the right one. It turns fully solid when it suggests a switch.",
          get = Get("idleAlpha"), set = Set("idleAlpha") },

        { kind = "header", text = "Advice" },
        { kind = "choice", label = "Play style",
          tip = "What the advice is for. Same as /aura style.",
          options = {
              { "auto", "Auto", "Your group role if you have one; tank while Righteous Fury is on; damage otherwise." },
              { "damage", "Damage", "Retribution for physical hits, Devotion against elites and bosses." },
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
        { kind = "check", label = "Suggest the between-fights aura after a fight",
          tip = "Unticked, the advisor only speaks up in fights.",
          get = Get("betweenFights"), set = Set("betweenFights") },

        { kind = "header", text = "When it suggests a switch in a fight" },
        { kind = "check", label = "Play a sound", get = Get("sound"), set = Set("sound") },
        { kind = "check", label = "Show a line in the middle of the screen", get = Get("banner"), set = Set("banner") },
        { kind = "check", label = "Write a line in chat", get = Get("chat"), set = Set("chat") },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Why this aura?",
              tip = "Prints every aura's points and where they come from. Same as /aura.",
              click = function() ns.PrintWhy() end },
            { label = "Pretend Fire damage",
              tip = "Shows what a suggestion looks like without a fight. Same as /aura test fire; /aura test off ends it.",
              click = function() ns.Test(ns.testing and "off" or "fire") end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the frame's place and size, back to how they started.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local res = ns.result
    if not res then return { "Nothing worked out yet." } end
    local cur = res.current and ns.known[res.current]
    local lines = { "On now: " .. (cur and cur.name or "no aura") .. "." }
    if res.shown and ns.known[res.shown] then
        lines[#lines + 1] = "Switch to " .. ns.known[res.shown].name .. ": " .. tostring(res.reason) .. "."
    end
    return lines
end

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
    if not ns.enabled then ns.Print("only works on a Paladin.") return end
    Kit.Click(mouseButton)
end
