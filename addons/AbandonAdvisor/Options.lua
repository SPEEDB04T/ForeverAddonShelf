-- Abandon Advisor: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function Get(key)
    return function() return ns.db[key] end
end

local function Rows()
    return {
        { kind = "header", text = "Advice" },
        { kind = "slider", label = "Free slots to aim for", min = 1, max = 25, step = 1, format = "%d",
          tip = "The advice marks enough quests to leave you this many free slots. Same as /abandon free.",
          get = Get("target"),
          set = function(value)
              ns.db.target = value
              ns.Refresh()
          end },
        { kind = "check", label = "Count low drop rates",
          tip = "Counts low drop rates against a quest, using Questie's drop rates. A quest whose items rarely drop still needs many kills, so it scores "
              .. "higher for abandoning. Does nothing without Questie. Same as /abandon drops.",
          get = Get("dropRates"),
          set = function(value)
              ns.db.dropRates = value
              ns.Refresh()
          end },

        { kind = "header", text = "Group" },
        { kind = "check", label = "Suggest group abandons",
          tip = "When a group member abandons a quest you also have, you are asked whether to abandon it too, and "
              .. "the quest scores higher. Only works for group members who use Abandon Advisor as well. "
              .. "Same as /abandon group.",
          get = Get("groupSuggest"),
          set = function(value)
              ns.db.groupSuggest = value
              ns.Refresh()
          end },
        { kind = "check", label = "Share my abandons",
          tip = "When you abandon a quest, sends it to your group members' Abandon Advisor. It is an addon message: nothing shows "
              .. "in chat. Same as /abandon share.",
          get = Get("groupShare"), set = function(value) ns.db.groupShare = value end },

        { kind = "header", text = "Window" },
        { kind = "check", label = "Open when the log is full",
          tip = "When the game says your quest log is full, the Abandon Advisor window opens with the quests to "
              .. "drop first. Same as /abandon auto.",
          get = Get("autoOpen"), set = function(value) ns.db.autoOpen = value end },
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
            { label = "Show / hide the window", tip = "Same as /abandon.",
              click = function() ns.UI.Toggle() end },
            { label = "Quest log tab", tip = "Opens the advice inside the quest log. Same as /abandon log.",
              click = function() ns.QuestLog.Open() end },
            { label = "Print the advice", tip = "Lists the quests to drop in chat. Same as /abandon list.",
              click = function() ns.Report() end },
        } },
        { kind = "buttons", buttons = {
            { label = "Release pinned quests", confirm = true,
              tip = "Quests you pinned as keepers can be suggested again. Same as /abandon unpin.",
              click = function() ns.Unpin() end },
            { label = "Reset settings", confirm = true,
              tip = "Puts every setting on this page, and the window's place and size, back to how they started. "
                  .. "Pinned quests stay pinned.",
              click = function() ns.ResetSettings() end },
        } },
    }
end
Options.Rows = Rows

local function Status()
    local res = ns.Compute()
    if type(res) ~= "table" then return nil end
    return { ns.Score.Summary(res) }
end

function Options.Init()
    Kit.Setup({
        title = "Abandon Advisor",
        icon = "Interface\\Icons\\INV_Misc_Book_08",
        accent = { 1.00, 0.49, 0.04 },
        version = ns.VERSION,
        print = ns.Print,
        db = function() return ns.db end,
        rows = Rows,
        click = function() ns.UI.Toggle() end,
        clickHint = "show or hide the quests to drop",
        status = Status,
    })
end
