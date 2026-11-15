-- Slutmog Shop: the options (drawn by Kit.lua) and the minimap button.
-- Left-click on the minimap button posts the next ad, right-click opens the shop window.
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
        { kind = "header", text = "Posting" },
        { kind = "slider", label = "Shortest gap between ads", min = 0, max = 300, step = 10,
          tip = "The Post button, the minimap button and your key wait this long after an ad before the next one "
              .. "can go out, so a double click does not spam the channel. 0: no wait.",
          format = function(v) return v == 0 and "none" or ("%d sec"):format(v) end,
          get = Get("gap"), set = Set("gap") },
        { kind = "slider", label = "Remind me after", min = 0, max = 30, step = 1,
          tip = "A line in your own chat, this long after your last ad, saying it is time for the next one. "
              .. "Nobody else sees it. The game does not let addons post to Trade by themselves, so the "
              .. "reminder is as far as it can go. 0: no reminder.",
          format = function(v) return v == 0 and "never" or ("%d min"):format(v) end,
          get = Get("remind"), set = Set("remind") },
        { kind = "check", label = "Play a sound with the reminder",
          get = Get("sound"), set = Set("sound") },
        { kind = "check", label = "Show a Post button with the reminder",
          tip = "With the reminder, a small window opens in the middle of the screen: the next ad as it will read, "
              .. "the ware it is for, a big Post ad button and Reroll. It waits for the end of a fight.",
          get = Get("prompt"), set = Set("prompt") },

        { kind = "header", text = "Wares in the ads" },
        { kind = "choice", label = "Which ads",
          options = {
              { "items", "Ready-made", "Every piece on the slutmog list comes with ads of its own, written for it, "
                  .. "which take turns. Wares that are not on the list use your ad lines." },
              { "mixed", "By turns", "A ready-made ad, then one of your own ad lines, and so on." },
              { "mine", "Only mine", "Only the openers and ad lines on the Lines tab of the shop window." },
          },
          get = Get("wording"), set = Set("wording") },
        { kind = "check", label = "Put pieces from my bags on the shelf",
          tip = "Every piece from the slutmog list in your bags becomes a ware by itself. It has no price at "
              .. "first and stays out of the ads until you give it one. /slutshop scan looks again, also for "
              .. "pieces you took off the shelf before.",
          get = Get("autoAdd"), set = function(v) ns.Set("autoAdd", v); if v then ns.ScanBags() end end },
        { kind = "check", label = "Only wares I still have",
          tip = "Skips wares that are in neither your bags nor your bank, so a sold piece drops out of the ads "
              .. "by itself and comes back when you have another.",
          get = Get("stockOnly"), set = Set("stockOnly") },
        { kind = "choice", label = "Next ware",
          options = {
              { "turns", "In list order", "Each ware in turn, from the top of your list." },
              { "random", "At random", "Any ware, never the same one twice in a row." },
          },
          get = Get("order"), set = Set("order") },
        { kind = "choice", label = "Prices",
          options = {
              { "words", "10 gold pieces" },
              { "short", "10g" },
          },
          get = Get("prices"), set = Set("prices") },

        { kind = "header", text = "Shop" },
        Kit.MinimapRow(),
        { kind = "buttons", buttons = {
            { label = "Open the shop window",
              tip = "Your wares, openers and ad lines. Same as /slutshop.",
              click = function() if ns.UI then ns.UI.Open() end end },
            { label = "Show the next ad",
              tip = "Prints the next ad in your own chat. Nothing is sent. Same as /slutshop preview.",
              click = function() ns.Preview() end },
        } },
        { kind = "buttons", buttons = {
            { label = "Restore the openers", confirm = true,
              tip = "Puts the shop name, the openers and the ad lines back to how they started. Your wares stay. "
                  .. "The ready-made ads never change.",
              click = function() ns.ResetLines() end },
            { label = "Forget my votes", confirm = true,
              tip = "Brings back every ready-made ad you answered No to in the shop window, and forgets the Yes votes too.",
              click = function() ns.ClearVotes() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page back to how it started. Your wares, openers and ad lines stay.",
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
        title = ns.TITLE,
        icon = ns.ICON,
        accent = ns.ACCENT,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.Post() end,
        clickHint = "post the next ad",
        alt = function() ns.ToggleWindow() end,
        altHint = "open the shop window",
        status = ns.StatusLines,
    })
end

-- The addon's line in the list of addons next to the minimap.
function SlutmogShop_OnAddonCompartmentClick(_, mouseButton)
    if ns.db then Kit.Click(mouseButton) end
end
