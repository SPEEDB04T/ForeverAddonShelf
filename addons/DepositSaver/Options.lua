-- Deposit Saver: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key) return function() return ns.db[key] end end
local function Set(key) return function(value) ns.Set(key, value) end end

local function Rows()
    return {
        { kind = "header", text = "Warnings" },
        { kind = "check", label = "Warn when a buyback is due",
          tip = "A raid warning in the middle of the screen, with its sound, when an auction worth buying back is close to expiring. Never in a fight: it waits until the fight ends.",
          get = Get("warn"), set = Set("warn") },
        { kind = "check", label = "Also my own auctions",
          tip = "You can't buy your own auction. The warning then tells you to have an alt on another account or a guildmate buy it.",
          get = Get("warnOwn"), set = Set("warnOwn") },
        { kind = "check", label = "Open a window with Find it",
          tip = "With the warning, the game's dialog with a Find it button: it opens the item at the auction house (or as soon as you open it).",
          get = Get("popup"), set = Set("popup") },
        { kind = "check", label = "Play the raid warning sound", get = Get("sound"), set = Set("sound") },
        { kind = "check", label = "A line in chat with the item link", get = Get("chatLine"), set = Set("chatLine") },
        { kind = "slider", label = "Warn in the last", min = 5, max = 60, step = 5,
          format = function(v) return ("%d min"):format(v) end,
          get = Get("warnMinutes"), set = Set("warnMinutes") },
        { kind = "slider", label = "Repeat every", min = 1, max = 15, step = 1,
          format = function(v) return ("%d min"):format(v) end,
          get = Get("repeatMinutes"), set = Set("repeatMinutes") },
        { kind = "buttons", buttons = {
            { label = "Show a test warning", tip = "Same as /deposits test.", click = function() ns.Alert.Test() end },
        } },

        { kind = "header", text = "Worth it when" },
        { kind = "slider", label = "Auction house cut", min = 1, max = 15, step = 1,
          tip = "What the auction house keeps from a sale. 5% at the faction auction houses; the neutral ones take more.",
          format = function(v) return ("%d%%"):format(v) end,
          get = Get("cutPct"), set = Set("cutPct") },
        { kind = "slider", label = "Only if it saves at least", min = 0, max = 50000, step = 500,
          tip = "Smaller savings are shown in the list but don't warn.",
          format = function(v) return ns.Money(v) end,
          get = Get("minSaving"), set = Set("minSaving") },

        { kind = "header", text = "Sharing" },
        { kind = "note", text = "Each character shares the auctions of every character on its account. For characters on your other accounts or friends outside the guild: /deposits add First Last." },
        { kind = "check", label = "With my guild", get = Get("shareGuild"), set = Set("shareGuild") },
        { kind = "check", label = "With my party or raid", get = Get("shareGroup"), set = Set("shareGroup") },
        { kind = "buttons", buttons = {
            { label = "Ask everyone again", tip = "Same as /deposits sync.", click = function() ns.Slash("sync") end },
            { label = "Print the list", tip = "Same as /deposits list.", click = function() ns.Slash("list") end },
        } },

        { kind = "header", text = "Auction house" },
        { kind = "check", label = "Buyback list next to the auction house",
          tip = "Every tracked auction with its deposit, the cut a buyback costs and whether it is worth it. At the top, what the item you are posting would lose.",
          get = Get("panel"), set = Set("panel") },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),
        { kind = "buttons", buttons = {
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started. The tracked auctions and the sharing list stay.",
              click = function() ns.Reset() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local n, worth, soon = 0, 0, nil
    local now = ns.ServerNow()
    for _, rec in ipairs(ns.Records()) do
        n = n + 1
        if select(4, ns.Worth(rec)) then
            worth = worth + 1
            local left = ns.Left(rec, now)
            if left and left > 0 and (not soon or left < soon[1]) then soon = { left, rec } end
        end
    end
    local lines = { ("%d auctions tracked, %d worth buying back"):format(n, worth) }
    if soon then
        lines[#lines + 1] = ("Next: %s's %s in %s"):format(soon[2].owner or "?", ns.PlainName(soon[2]), ns.TimeText(soon[1]))
    end
    return lines
end

local ready
function Options.Ready() return ready end

function Options.Init()
    if ready then return end
    ready = true
    Kit.Setup({
        title = ns.TITLE,
        icon = ns.ICON,
        accent = { 1, 0.82, 0 },
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        clickHint = "options",
        alt = function() ns.Slash("list") end,
        altHint = "tracked auctions, in chat",
        status = Status,
    })
end

-- The addon's line in the list of addons next to the minimap.
function DepositSaver_OnAddonCompartmentClick(_, mouseButton)
    if ns.db and ready then Kit.Click(mouseButton) end
end
