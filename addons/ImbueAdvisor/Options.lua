-- Imbue Advisor: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

local function Set(key)
    return function(value) ns.db[key] = value end
end

-- Settings the recommendation is worked out from: change one and it is worked out again.
local function SetCalc(key)
    return function(value)
        ns.db[key] = value
        ns.MarkDirty()
    end
end

local function Percent(value)
    return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local function Rows()
    return {
        { kind = "header", text = "Frame" },
        { kind = "check", label = "Show the frame",
          tip = "The frame with the imbue to put on each weapon. Same as /imbue. In a fight it changes when the fight is over.",
          get = Get("shown"),
          set = function(value)
              ns.db.shown = value
              ns.UI.ApplySecure()
          end },
        { kind = "check", label = "Lock the frame in place",
          tip = "Unticked, you can drag the frame.",
          get = Get("locked"), set = Set("locked") },
        { kind = "slider", label = "Frame size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
          get = Get("scale"),
          set = function(value)
              if InCombatLockdown() then ns.Print("can't resize the frame in combat.") return end
              ns.db.scale = value
              ns.UI.frame:SetScale(value)
          end },
        { kind = "choice", label = "Other imbues",
          tip = "A list of all your imbues under the frame, best first. Click one to put it on that hand and keep using it there. The green one is the advisor's pick: click it to go back.",
          options = {
              { "hover", "When pointed at", "The list opens while the mouse is on the frame." },
              { "always", "Always", "The list stays open, in a fight too." },
              { "off", "Never", "No list. /imbue pick mh flametongue still works." },
          },
          get = Get("others"),
          set = function(value)
              ns.db.others = value
              ns.UI.ApplySecure()
          end },

        { kind = "header", text = "Recommendation" },
        { kind = "choice", label = "Play style",
          tip = "What the imbues are picked for.",
          options = {
              { "auto", "Auto", "Worked out from your talents and gear." },
              { "melee", "Melee", "Most damage with weapons." },
              { "tank", "Tank", "Most threat." },
              { "caster", "Caster", "Most spell damage." },
              { "heal", "Healer", "Most healing." },
              { "pvp", "PvP", "Damage, with extra credit for Frostbrand's slow." },
          },
          get = Get("mode"), set = SetCalc("mode") },
        { kind = "slider", label = "Target's level above yours", min = 0, max = 3, step = 1, format = "+%d",
          tip = "0 for monsters of your level, 3 for a raid boss. Higher targets are missed and resist more.",
          get = Get("targetLevelDiff"), set = SetCalc("targetLevelDiff") },
        { kind = "check", label = "Windfury on the off hand can proc",
          get = Get("windfuryOffhandProcs"), set = SetCalc("windfuryOffhandProcs") },
        { kind = "check", label = "Windfury on both hands shares one cooldown",
          get = Get("windfurySharedCooldown"), set = SetCalc("windfurySharedCooldown") },
        { kind = "slider", label = "Rockbiter threat as a tank", min = 1, max = 4, step = 0.1, format = "x%.1f",
          tip = "How much more threat Rockbiter's damage is counted as in tank mode.",
          get = Get("tankRockbiterThreat"), set = SetCalc("tankRockbiterThreat") },
        { kind = "slider", label = "Frostbrand's slow in PvP", min = 0, max = 1, step = 0.05, format = Percent,
          tip = "The slow is counted as this much of your best damage imbue in PvP mode.",
          get = Get("pvpSlowBonus"), set = SetCalc("pvpSlowBonus") },

        { kind = "header", text = "Warnings" },
        { kind = "check", label = "Warn when a fight starts without an imbue",
          get = Get("warnMissing"), set = Set("warnMissing") },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Print the numbers",
              tip = "Prints what each imbue is worth on each hand. Same as /imbue report.",
              click = function() ns.UI.PrintReport() end },
            { label = "Use the advisor's picks",
              tip = "Forgets the imbues you chose yourself on this character. Same as /imbue advisor.",
              click = function() ns.ClearPicks() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the frame's place and size, back to how they started.",
              click = function() ns.ResetSettings() end },
        } },
    }
end
Options.Rows = Rows

local MODE_NAMES = { auto = "auto", melee = "melee", tank = "tank", caster = "caster", heal = "healer", pvp = "PvP" }

local function Status()
    local lines = { "Play style: " .. (MODE_NAMES[ns.db.mode] or tostring(ns.db.mode)) .. "." }
    if ns.HasPicks() then lines[#lines + 1] = "Using an imbue you picked yourself." end
    return lines
end

function Options.Init()
    Kit.Setup({
        title = "Imbue Advisor",
        icon = "Interface\\Icons\\Spell_Nature_Cyclone",
        accent = { 0.00, 0.44, 0.87 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.ToggleFrame() end,
        clickHint = "show or hide the frame",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function ImbueAdvisor_OnAddonCompartmentClick(_, mouseButton)
    if not ns.db then return end
    if not ns.enabled then ns.Print("only works on a Shaman.") return end
    Kit.Click(mouseButton)
end
