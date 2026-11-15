-- Destroy Advisor: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

local function Set(key)
    return function(value)
        ns.db[key] = value
        ns.Changed(true)
    end
end

local function Rows()
    return {
        { kind = "header", text = "Suggest" },
        { kind = "check", label = "Poor quality (grey) items",
          tip = "Grey items are only worth their vendor price. At a merchant a click sells them.",
          get = Get("grey"), set = Set("grey") },
        { kind = "check", label = "Quest leftovers",
          tip = "Items that start a quest you have done or can't take, and quest items whose quests are all handed in "
              .. "or not for this character. Quest items are only judged with Questie installed; nothing a quest in "
              .. "your log asks for is ever suggested.",
          get = Get("quest"), set = Set("quest") },
        { kind = "check", label = "Bound gear your class can't use",
          tip = "Armor and weapons bound to you that this class can never wear or wield, at any level. "
              .. "Gear that isn't bound yet is left alone: it can still be sold or given away.",
          get = Get("gear"), set = Set("gear") },
        { kind = "check", label = "Bound things you already know",
          tip = "Recipes, pets, mounts and toys bound to you whose tooltip says you already know them.",
          get = Get("known"), set = Set("known") },
        { kind = "check", label = "Ammo and drinks your class can't use",
          tip = "Arrows and bullets for a class that can't shoot, and drinks and mana potions for warriors and rogues.",
          get = Get("useless"), set = Set("useless") },

        { kind = "header", text = "When your bags are full" },
        { kind = "check", label = "Say in chat what to destroy",
          tip = "Names up to three items that are safe to destroy when the last bag slot fills up, "
              .. "or when the game says your inventory is full. Same as /destroy full.",
          get = Get("fullChat"), set = function(value) ns.db.fullChat = value end },
        { kind = "check", label = "Open the list",
          tip = "Also opens the list when your bags fill up and something in them can go.",
          get = Get("fullOpen"), set = function(value) ns.db.fullOpen = value end },

        { kind = "header", text = "Tooltips" },
        { kind = "check", label = "Mark items in their tooltip",
          tip = "Adds a line to the tooltip of a bag item that is safe to destroy, saying why.",
          get = Get("tooltip"), set = function(value) ns.db.tooltip = value end },

        { kind = "header", text = "Kept items" },
        { kind = "note", text = "Right-click an item in the list and pick Keep to never see it suggested again. "
              .. "/destroy unkeep <item> undoes one." },
        { kind = "buttons", buttons = {
            { label = "Forget kept items", confirm = true,
              tip = "Every item you chose to keep is suggested again when it qualifies. Same as /destroy forget.",
              click = function() ns.ForgetKept() end },
        } },

        { kind = "header", text = "Window" },
        { kind = "slider", label = "Window size", min = 0.5, max = 2, step = 0.05, format = "%.2f",
          get = function() return ns.db.scale or 1 end,
          set = function(value)
              ns.db.scale = value
              ns.UI.ApplyScale()
          end },

        { kind = "header", text = "Minimap" },
        Kit.MinimapRow(),

        { kind = "header", text = "Actions" },
        { kind = "buttons", buttons = {
            { label = "Show / hide the list", tip = "Same as /destroy.",
              click = function() ns.UI.Toggle() end },
            { label = "Print the list", tip = "Lists every item that can go, with the reason, in chat. Same as /destroy list.",
              click = function() ns.Report() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the window's place and size, back to how they started. "
                  .. "Kept items stay kept.",
              click = function() ns.ResetSettings() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    if not ns.db then return nil end
    local s = ns.Scan()
    local n = #s.list
    local what = n == 0 and "Nothing in your bags needs destroying" or
        ("%d %s safe to destroy"):format(n, n == 1 and "item is" or "items are")
    return { ("%s; %d of %d bag slots free."):format(what, s.free, s.total) }
end
Options.Status = Status

function Options.Init()
    Kit.Setup({
        title = ns.NAME,
        icon = ns.ICON,
        accent = { 0.85, 0.27, 0.18 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.UI.Toggle() end,
        clickHint = "show or hide the list",
        status = Status,
    })
end
