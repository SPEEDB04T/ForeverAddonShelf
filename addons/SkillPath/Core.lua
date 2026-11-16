-- SkillPath: core (settings, safe API access, events, the recompute, slash commands)
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.4.0"
ns.NAME = "SkillPath"
ns.ICON = "Interface\\Icons\\INV_Misc_Note_01"

local defaults = {
    openOnTab = false,   -- a profession opens on the SkillPath tab
    showPoints = true,   -- each point's chance and cost under a craft step
    useBank = true,      -- reagents in the bank count as free, like those in the bags
    showOptions = true,  -- recipes you don't know yet that would help
    staleHours = 3,      -- an auction price older than this is called out as old
    autoScan = true,     -- read reagent prices a few seconds after the auction house opens
    sellVendor = true,   -- what the guide makes and doesn't use again counts at its vendor sell price
    sellAH = true,       -- ...or at the auction house, for as many as were seen to sell there
    sellDays = 3,        -- how many days of those sales to count
}

----------------------------------------------------------------------
-- Safe API access. WoW Forever runs on the modern client, where a
-- value can be "secret" (unreadable by addons); those become nil.
----------------------------------------------------------------------
function ns.Val(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function ns.Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then return nil end
    return ns.Val(a), ns.Val(b), ns.Val(c), ns.Val(d)
end

-- Every return value of fn, in a table (GetProfessionInfo has more than four).
function ns.CallAll(fn, ...)
    local out = {}
    if type(fn) ~= "function" then return out end
    local packed = { pcall(fn, ...) }
    if not packed[1] then return out end
    for i = 2, table.maxn(packed) do out[i - 1] = ns.Val(packed[i]) end
    return out
end

function ns.Num(value)
    value = ns.Val(value)
    if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
        return value
    end
end

function ns.Str(value)
    value = ns.Val(value)
    if type(value) == "string" and value ~= "" then return value end
end

function ns.Field(tbl, key)
    if type(tbl) ~= "table" then return nil end
    local ok, value = pcall(function() return tbl[key] end)
    if not ok then return nil end
    return ns.Val(value)
end

-- The game's own text colours (NORMAL_FONT_COLOR and the like); the numbers are only for a client without them.
function ns.GameColor(name, r, g, b)
    local color = _G[name]
    if type(color) == "table" and type(color.r) == "number" then return color.r, color.g, color.b end
    return r, g, b
end

function ns.Print(msg)
    local text = "|cffffd200SkillPath|r: " .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

-- Seconds since the client started (for throttles and timeouts).
function ns.Now()
    return ns.Num(ns.Call(GetTime)) or 0
end

-- Wall-clock seconds (for how old a price is; survives a /reload).
function ns.Clock()
    return ns.Num(ns.Call(time)) or 0
end

function ns.Money(copper)
    copper = math.floor((copper or 0) + 0.5)
    if GetCoinTextureString then
        local text = ns.Str(ns.Call(GetCoinTextureString, copper))
        if text then return text end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return ("%dg %ds %dc"):format(g, s, c) end
    if s > 0 then return ("%ds %dc"):format(s, c) end
    return ("%dc"):format(c)
end

-- Money as plain text, for the written guide: "12g 34s 56c", without the parts that are zero.
function ns.Coins(copper)
    copper = math.floor((copper or 0) + 0.5)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- "40 min", "3 h", "2 days"
function ns.Age(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 90 then return "just now" end
    if seconds < 5400 then return ("%d min ago"):format(math.floor(seconds / 60 + 0.5)) end
    if seconds < 172800 then return ("%d h ago"):format(math.floor(seconds / 3600 + 0.5)) end
    return ("%d days ago"):format(math.floor(seconds / 86400 + 0.5))
end

-- Expected crafts: whole numbers as they are, the rest to one decimal.
function ns.Crafts(n)
    if math.abs(n - math.floor(n + 0.5)) < 0.05 then return tostring(math.floor(n + 0.5)) end
    return ("%.1f"):format(n)
end

----------------------------------------------------------------------
-- Settings. Professions are per character (keyed by GUID; on Forever
-- UnitName gives the surname in the realm slot, so names are no key).
-- Auction prices are per realm and faction; vendor prices are shared.
----------------------------------------------------------------------
local function InitDB()
    if type(SkillPathDB) ~= "table" then SkillPathDB = {} end
    local db = SkillPathDB
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
    if type(db.chars) ~= "table" then db.chars = {} end
    if type(db.ah) ~= "table" then db.ah = {} end
    if type(db.vendor) ~= "table" then db.vendor = {} end
    if type(db.trainer) ~= "table" then db.trainer = {} end
    if type(db.targets) ~= "table" then db.targets = {} end     -- per profession: [skill line] = skill
    local order = db.order
    if type(order) ~= "table" or not (ns.Num(order.line) and ns.Num(order.from) and ns.Num(order.to)) then
        db.order = nil
    end
    db.point, db.scale, db.autoShow = nil, nil, nil     -- 1.1's own window
    ns.db = db
    -- 1.2 had one target for every profession, and left auction house sales out unless asked.
    if not db.v13 then
        db.v13 = true
        if db.sellAH == false then db.sellAH = true end
        local old = ns.Num(db.target)
        local char = ns.Char()
        if old and old > 0 and char and char.last then db.targets[char.last] = old end
    end
    db.target = nil
end
ns.InitDB = InitDB
ns.defaults = defaults

function ns.Char()
    local db = ns.db
    if not db then return nil end
    local key = ns.Str(ns.Call(UnitGUID, "player")) or "unknown"
    local char = db.chars[key]
    if type(char) ~= "table" then
        char = { profs = {} }
        db.chars[key] = char
    end
    if type(char.profs) ~= "table" then char.profs = {} end
    return char
end

function ns.ResetSettings()
    local db = ns.db
    for key, value in pairs(defaults) do db[key] = value end
    db.targets = {}
    db.timerChat = nil      -- how plans are sent is found out again
    db.minimap = nil
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.Changed()
    ns.Print("Settings reset. Saved recipes and prices are kept.")
end

----------------------------------------------------------------------
-- The guide. Built on demand from the saved profession and prices, and
-- thrown away whenever something it rests on changes.
----------------------------------------------------------------------
local plan

-- The profession the guide is for: the open one, else the last one opened.
function ns.Profession()
    local char = ns.Char()
    if not char then return nil end
    local line = char.last
    return line and char.profs[line] or nil, line
end

-- A plan for someone else: { line, from, to }, or nil for your own path.
function ns.Order()
    return ns.db and ns.db.order or nil
end

function ns.SetOrder(line, from, to)
    ns.db.order = line and { line = line, from = from, to = to } or nil
    ns.Changed()
end

function ns.Plan()
    if plan then return plan end
    local order = ns.Order()
    if order then
        plan = ns.Planner.ForCustomer(order)
    else
        plan = ns.Planner.ForProfession((ns.Profession()))
    end
    return plan
end

local refreshQueued = false
function ns.Changed()
    plan = nil
    if ns.Prices then ns.Prices.Invalidate() end
    if refreshQueued then return end
    refreshQueued = true
    ns.After(0.2, function()
        refreshQueued = false
        if ns.UI and ns.UI.IsShown() then ns.UI.Update() end
        if ns.Kit then ns.Kit.Sync() end
    end)
end

-- Item data that arrives one item at a time (names, vendor prices): one rebuild for the lot.
local soonQueued = false
function ns.ChangedSoon()
    if soonQueued then return end
    soonQueued = true
    ns.After(1, function()
        soonQueued = false
        ns.Changed()
    end)
end

----------------------------------------------------------------------
-- Chat
----------------------------------------------------------------------
-- The written guide in your own chat window: the same numbered steps as the pages.
function ns.Report()
    local p = ns.Plan()
    if not (p.ok and ns.UI) then
        ns.Print(p.why or "No path yet.")
        return
    end
    for _, line in ipairs(ns.UI.Guide(p)) do ns.Print(line) end
end

-- A chat message holds 255 characters: longer lines are cut at a space.
local function Wrap(lines, width)
    local out = {}
    for _, line in ipairs(lines) do
        while #line > width do
            local cut = width
            for i = width, math.floor(width / 2), -1 do
                if line:sub(i, i) == " " then
                    cut = i
                    break
                end
            end
            out[#out + 1] = line:sub(1, cut):gsub("%s+$", "")
            line = "    " .. line:sub(cut + 1):gsub("^%s+", "")
        end
        out[#out + 1] = line
    end
    return out
end
ns.Wrap = Wrap

-- The written guide to another player. On this client only chat sent inside your own key press
-- or click is sure to go out: what an addon sends by itself (from a timer) can be dropped with no
-- error. The game shows you every line you sent, so each line is checked against that echo. The
-- first line goes with the command. The rest go a line a second from a timer while their echoes
-- come back; once one doesn't, your clicks on "Send next" send them, a few lines a click.
local ECHO_WAIT = 3       -- seconds a line may take to come back
local CLICK_LINES = 3     -- lines one click sends
local sending, held

-- A line as the game may hand it back: without the spaces around it, runs of spaces as one.
local function Plain(text)
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function SendChanged(open)
    if ns.UI and ns.UI.SendChanged then return ns.UI.SendChanged(open) end
    return false
end

local function StopSend(text)
    sending = nil
    if text then ns.Print(text) end
    SendChanged()
end

-- Waits for your click (or /skillpath send next).
local function Ask(job)
    job.ask = true
    job.token = job.token + 1
    local button = SendChanged(true)
    if not job.told then
        job.told = true
        ns.Print(button and "Click \"Send next\" in the guide window for the next lines (or /skillpath send next)."
            or "/skillpath send next sends the next lines.")
    end
end

local function NoEcho(job, blocked)
    local missing, total = job.acked + 1, #job.lines
    if not job.fromKey then
        -- A line the addon sent by itself didn't come back. Where such lines have come back before,
        -- that is this one line's trouble (the other player left, say), not the game's rule.
        local rule = blocked or ns.db.timerChat ~= true
        if rule then ns.db.timerChat = false end
        job.mode, job.i, job.fails = "click", job.acked, 0
        ns.Print(("Line %d of %d didn't go out%s. Your clicks send the rest."):format(missing, total,
            rule and ": the game drops chat an addon sends by itself" or ""))
        Ask(job)
    elseif job.acked == 0 then
        StopSend(job.channel == "PARTY" and "The first line didn't go out: are you in a party? Stopped."
            or ("%s didn't get the first line: offline, or the name is wrong? Stopped."):format(job.who))
    elseif job.fails >= 1 and job.failed == missing then
        StopSend(("Line %d of %d didn't go out twice. Stopped: %d lines reached %s."):format(missing, total, job.acked, job.who))
    else
        -- Too many at once, perhaps: one line a click from here, starting with the lost one.
        job.fails, job.failed = 1, missing
        job.i, job.batch = job.acked, 1
        ns.Print(("Line %d of %d didn't go out. One line a click from here."):format(missing, total))
        Ask(job)
    end
end

local Tick
-- Sends the next n lines now: inside your key press or click (fromKey), or from a timer.
local function Push(job, n, fromKey)
    job.fromKey, job.pushed, job.waited, job.ask = fromKey, 0, 0, nil
    job.token = job.token + 1
    for _ = 1, n do
        local line = job.lines[job.i + 1]
        if not line then break end
        -- Counted first: the echo may come back before the call returns.
        job.i = job.i + 1
        job.pushed = job.pushed + 1
        if not pcall(job.send, line, job.channel, nil, job.target) then
            StopSend("The game didn't take the message. Stopped.")
            return false
        end
        if sending ~= job then return false end
        if job.ask then return true end     -- the game said at once that it blocked the line
    end
    SendChanged()
    local token = job.token
    ns.After(1, function() Tick(job, token) end)
    return true
end

-- A second after the last lines went: on with the next once every echo is back.
Tick = function(job, token)
    if sending ~= job or token ~= job.token then return end
    if job.acked >= job.i then
        if job.mode == "timer" and not job.fromKey then ns.db.timerChat = true end
        if job.i >= #job.lines then
            StopSend(("Sent the plan to %s."):format(job.who))
        elseif job.mode == "timer" then
            Push(job, 1, false)
        else
            Ask(job)
        end
        return
    end
    job.waited = job.waited + 1
    if job.waited < ECHO_WAIT then
        ns.After(1, function() Tick(job, token) end)
    else
        NoEcho(job)
    end
end

-- The game showing you a line you sent (CHAT_MSG_WHISPER_INFORM, or your own party line).
function ns.SendEcho(channel, text)
    local job = sending
    if not job or job.channel ~= channel or job.acked >= job.i then return end
    -- Text the game won't let an addon read can't be compared: it counts.
    text = ns.Str(text)
    if text and Plain(text) ~= Plain(job.lines[job.acked + 1]) then return end
    job.acked = job.acked + 1
    if job.failed and job.acked >= job.failed then job.fails, job.failed = 0, nil end
end

-- The game saying it blocked something this addon did: a line sent from a timer.
function ns.SendBlocked(addon)
    local job = sending
    if job and not job.fromKey and not job.ask and job.acked < job.i and ns.Str(addon) == ADDON then NoEcho(job, true) end
end

-- The "Send next" button and /skillpath send next: the next lines, inside your click.
function ns.SendNext()
    local job = sending
    if not job then
        ns.Print("Nothing is being sent.")
        return false
    elseif not job.ask then
        ns.Print("The last lines are still going out.")
        return false
    end
    return Push(job, job.batch, true)
end

-- nil, or what the guide window shows of the plan being sent.
function ns.SendState()
    local job = sending
    if not job then return nil end
    return { click = job.mode == "click", ask = job.ask == true, sent = job.acked, total = #job.lines }
end

function ns.Send(to)
    to = ns.Str(to)
    if not to then
        ns.Print("Usage: /skillpath send <player> (or party). /skillpath send stop ends it.")
        return false
    end
    if to:lower() == "stop" then
        held = nil
        StopSend(sending and "Stopped sending." or "Nothing is being sent.")
        return false
    end
    if to:lower() == "next" then return ns.SendNext() end
    if sending then
        ns.Print("Still sending the last plan. /skillpath send stop ends it.")
        return false
    end
    local p = ns.Plan()
    if not (p.ok and ns.UI) then
        ns.Print(p.why or "No path yet.")
        return false
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then
        ns.Print("This client has no chat function for addons.")
        return false
    end
    local channel, target, who = "WHISPER", to, to
    if to:lower() == "party" then channel, target, who = "PARTY", nil, "your party" end
    local click = ns.db.timerChat == false
    local job = { lines = Wrap(ns.UI.Guide(p, true), 240), i = 0, acked = 0, token = 0, fails = 0, send = send,
        channel = channel, target = target, who = who, mode = click and "click" or "timer", batch = CLICK_LINES }
    -- A plan with names the game is still loading is held back once; asked again, it goes as it is.
    local unnamed = ns.UI.Unnamed(job.lines)
    if unnamed > 0 and held ~= to then
        held = to
        ns.Print(("%d %s in the plan %s still loading from the game. Try again in a moment (asked again, it is "
            .. "sent as it is)."):format(unnamed, unnamed == 1 and "name" or "names", unnamed == 1 and "is" or "are"))
        return false
    end
    held = nil
    sending = job
    ns.Print(("Sending %d lines to %s."):format(#job.lines, who))
    return Push(job, click and CLICK_LINES or 1, true)
end
function ns.Sending() return sending ~= nil end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function Debug()
    local prof, line = ns.Profession()
    ns.Print(("data build %s, game build %s"):format(ns.Data and ns.Data.BUILD or "?",
        tostring(select(2, ns.Call(GetBuildInfo)) or "?")))
    if not prof then
        ns.Print("No profession saved yet: open one.")
        return
    end
    local known, trusted, total = 0, 0, 0
    for _, r in ipairs(prof.recipes or {}) do
        total = total + 1
        if r.known then known = known + 1 end
        if r.known and r.trust then trusted = trusted + 1 end
    end
    ns.Print(("%s (line %s): skill %s/%s, modifier %s, offset %s, %d recipes listed, %d known, %d known and checked")
        :format(prof.name or "?", tostring(line), tostring(prof.skill), tostring(prof.max), tostring(prof.mod),
            tostring(prof.offset), total, known, trusted))
    for _, r in ipairs(prof.recipes or {}) do
        if r.known and not r.trust then
            ns.Print(("  not trusted: %s (%s)"):format(r.name or r.id, r.why or "?"))
        end
    end
    local same, differ = ns.Recipes.TrainCheck()
    if same + #differ > 0 then
        ns.Print(("trainer table: %d rows as a trainer showed them, %d not"):format(same, #differ))
        for _, text in ipairs(differ) do ns.Print("  " .. text) end
    end
    if ns.Prices then ns.Prices.Debug() end
end

local FOR_USAGE = "Usage: /skillpath for <profession> <from> <to>, like /skillpath for engineering 75 225. "
    .. "/skillpath for me: back to your own path."

-- A plan for someone else: "engineering 75 225", "eng 75-225", "tailoring 1 to 150".
local function For(arg)
    local low = arg:lower()
    if low == "" or low == "me" or low == "off" or low == "clear" then
        if low ~= "" and ns.Order() then
            ns.SetOrder(nil)
            ns.Print("Back to your own path.")
        elseif low ~= "" then
            ns.Print("The path is your own already.")
        else
            ns.Print(FOR_USAGE)
        end
        return false
    end
    local name, from, to = arg:match("^(.-)%s+(%d+)%D+(%d+)$")
    from, to = tonumber(from), tonumber(to)
    local line, full = ns.Recipes.LineByName(name)
    if not line then
        local names = {}
        for _, n in pairs(ns.Data and ns.Data.NAMES or {}) do names[#names + 1] = n end
        table.sort(names)
        ns.Print(name and ("No profession called \"%s\". The ones in the table: %s."):format(name,
            table.concat(names, ", ")) or FOR_USAGE)
        return false
    end
    if from < 1 then from = 1 end
    if to <= from or to > ns.Planner.TOP then
        ns.Print(("%s %d to %d isn't a range to level. "):format(full, from, to) .. FOR_USAGE)
        return false
    end
    ns.SetOrder(line, from, to)
    local p = ns.Plan()
    if p.ok and ns.UI then
        local title, text = ns.UI.Summary(p, ns.Coins)
        ns.Print(title .. ". " .. text)
        ns.Print("/skillpath guide: the written plan to copy. /skillpath send <player>: whisper it. "
            .. "/skillpath for me: back to your own path.")
    else
        ns.Print(p.why or "No path.")
    end
    return true
end
ns.For = For

local function Slash(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        ns.UI.Toggle()
    elseif cmd == "print" or cmd == "list" then
        ns.Report()
    elseif cmd == "scan" then
        ns.Prices.StartScan(true)
    elseif cmd == "target" then
        local n = tonumber(arg)
        local prof, line = ns.Profession()
        if ns.Order() then
            ns.Print("The plan for someone else has its own range: /skillpath for <profession> <from> <to>.")
        elseif not (n and n >= 0 and n <= math.max(ns.Planner.TOP, prof and prof.max or 0)) then
            ns.Print(("Usage: /skillpath target <skill>, up to %d (0: your rank's cap)"):format(ns.Planner.TOP))
        elseif not (prof and line) then
            ns.Print("Open a profession first: each has its own target.")
        else
            n = math.floor(n)
            ns.db.targets[line] = n > 0 and n or nil
            ns.Changed()
            ns.Print(n == 0 and ("%s target: your rank's cap."):format(prof.name)
                or ("%s target: skill %d."):format(prof.name, n))
        end
    elseif cmd == "for" then
        For(arg)
    elseif cmd == "guide" or cmd == "copy" then
        ns.UI.ShowGuide()
    elseif cmd == "send" then
        ns.Send(arg)
    elseif cmd == "forget" then
        ns.Prices.Forget()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if ns.Kit and ns.Options then ns.Kit.Open() else ns.Print("The options aren't loaded; /reload loads them.") end
    elseif cmd == "minimap" then
        if ns.Kit and ns.Options then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("Minimap button: " .. (ns.Kit.MinimapShown() and "on" or "off"))
        else
            ns.Print("The minimap button isn't loaded; /reload loads it.")
        end
    elseif cmd == "reset" then
        ns.ResetSettings()
    elseif cmd == "debug" then
        Debug()
    else
        ns.Print("Commands: /skillpath (the SkillPath tab), print, scan, target <skill>, for <profession> <from> "
            .. "<to>, for me, guide, send <player>, forget, config, minimap, reset, debug")
    end
    if ns.Kit then ns.Kit.Sync() end      -- an open options window follows what was typed
end
ns.Slash = Slash

SLASH_SKILLPATH1 = "/skillpath"
SLASH_SKILLPATH2 = "/spath"
-- Only the entry: writing the SlashCmdList global itself (even "SlashCmdList = SlashCmdList or {}")
-- taints every slash command, and the game then blocks /tm marking and /invite.
SlashCmdList["SKILLPATH"] = Slash

-- The addon's line in the list of addons next to the minimap: left-click the SkillPath tab,
-- right-click the options.
function SkillPath_Toggle(_, mouseButton)
    if not (ns.UI and ns.db) then return end
    if mouseButton == "RightButton" and ns.Kit and ns.Options then ns.Kit.Open() else ns.UI.Toggle() end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.eventFrame = frame
local EVENTS = { "PLAYER_LOGIN", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED",
    "TRADE_SKILL_CLOSE", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL", "NEW_RECIPE_LEARNED", "BAG_UPDATE_DELAYED",
    "MERCHANT_SHOW", "TRAINER_SHOW", "TRAINER_UPDATE", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "GET_ITEM_INFO_RECEIVED",
    "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "ADDON_ACTION_BLOCKED" }
for _, event in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, event) end

local snapshotQueued = false
local function QueueSnapshot(thenShow)
    if thenShow then ns.showAfterSnapshot = true end
    if snapshotQueued then return end
    snapshotQueued = true
    ns.After(0.3, function()
        snapshotQueued = false
        local took = ns.Recipes.Snapshot()
        if took then ns.Changed() end
        if ns.showAfterSnapshot then
            ns.showAfterSnapshot = false
            if ns.UI then ns.UI.ProfessionsShown() end
        end
    end)
end
ns.QueueSnapshot = QueueSnapshot

-- The trainer's list arrives a moment after the window. On opening it, the recipes the path
-- wants from this trainer go to chat: the SkillPath tab isn't on screen there.
local trainerQueued, trainerSay = false, false
local function QueueTrainer(opened)
    if opened then trainerSay = true end
    if trainerQueued then return end
    trainerQueued = true
    ns.After(0.3, function()
        trainerQueued = false
        local read, lines = ns.Recipes.ReadTrainer()
        if read <= 0 then return end
        ns.Changed()
        if not trainerSay then return end
        trainerSay = false
        local p = ns.Plan()
        local prof = p.ok and not p.forOther and lines[p.line] and p.prof
        for _, step in ipairs(prof and p.steps or {}) do
            if step.kind == "train" and #step.learn > 0 then
                if step.at <= (prof.skill or 0) then
                    local names = {}
                    for _, l in ipairs(step.learn) do
                        names[#names + 1] = l.unknown and l.r.name or ("%s (%s)"):format(l.r.name, ns.Money(l.fee))
                    end
                    ns.Print(("Learn here for %s: %s."):format(p.name, table.concat(names, ", ")))
                end
                break
            end
        end
    end)
end

frame:SetScript("OnEvent", function(_, event, a, b)
    if event == "PLAYER_LOGIN" then
        InitDB()
        ns.Recipes.UpdateSkills()
        if ns.UI then ns.UI.Init() end
        if ns.Kit and ns.Options then
            local ok, err = pcall(ns.Options.Init)
            if not ok then ns.Print("options error: " .. tostring(err)) end
        end
        return
    elseif not ns.db then
        return
    end
    if event == "TRADE_SKILL_SHOW" then
        ns.tradeOpen = true
        QueueSnapshot(true)
    elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED"
        or event == "NEW_RECIPE_LEARNED" then
        if ns.tradeOpen then
            QueueSnapshot(false)
        elseif event == "NEW_RECIPE_LEARNED" then
            -- Learned with the window closed (a trainer, a recipe item): marked in the saved list.
            -- A recipe the list doesn't hold leaves it behind until the profession is opened.
            if not (ns.Num(a) and ns.Recipes.MarkLearned(a)) then
                local char = ns.Char()
                for _, prof in pairs(char and char.profs or {}) do prof.unread = true end
            end
            ns.Changed()
        end
    elseif event == "TRADE_SKILL_CLOSE" then
        ns.tradeOpen = false
        ns.showAfterSnapshot = false
        if ns.UI then ns.UI.ProfessionsHidden() end
    elseif event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
        if ns.Recipes.UpdateSkills() then ns.Changed() end
        if ns.Recipes.WindowOpen() then QueueSnapshot(false) end
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.Changed()
    elseif event == "CHAT_MSG_WHISPER_INFORM" then
        ns.SendEcho("WHISPER", a)
    elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        ns.SendEcho("PARTY", a)
    elseif event == "ADDON_ACTION_BLOCKED" then
        ns.SendBlocked(a)
    elseif event == "MERCHANT_SHOW" then
        if ns.Prices.ReadMerchant() > 0 then ns.Changed() end
    elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
        if event == "TRAINER_SHOW" or ns.Now() >= (ns.Recipes.trainerQuiet or 0) then
            QueueTrainer(event == "TRAINER_SHOW")
        end
    else
        ns.Prices.OnEvent(event, a, b)
        if event == "AUCTION_HOUSE_SHOW" and ns.UI then ns.UI.AuctionOpened() end
    end
end)
