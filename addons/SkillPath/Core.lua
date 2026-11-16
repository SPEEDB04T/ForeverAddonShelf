-- SkillPath: core (settings, safe API access, events, the recompute, slash commands)
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.2.0"
ns.NAME = "SkillPath"
ns.ICON = "Interface\\Icons\\INV_Misc_Note_01"

local defaults = {
    target = 0,          -- 0 = as far as your current trainer rank allows
    openOnTab = false,   -- a profession opens on the SkillPath tab
    showPoints = true,   -- each point's chance and cost under a craft step
    useBank = true,      -- reagents in the bank count as free, like those in the bags
    showOptions = true,  -- recipes you don't know yet that would help
    staleHours = 3,      -- an auction price older than this is called out as old
    autoScan = true,     -- read reagent prices a few seconds after the auction house opens
    sellVendor = true,   -- what the guide makes and doesn't use again counts at its vendor sell price
    sellAH = false,      -- ...or at the auction house, for as many as were seen to sell there
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
    db.point, db.scale, db.autoShow = nil, nil, nil     -- 1.1's own window
    ns.db = db
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

function ns.Plan()
    if plan then return plan end
    local prof = ns.Profession()
    plan = ns.Planner.ForProfession(prof)
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

----------------------------------------------------------------------
-- Chat
----------------------------------------------------------------------
-- The path in chat: the same numbered steps as the pages.
function ns.Report()
    local p = ns.Plan()
    if not (p.ok and ns.UI) then
        ns.Print(p.why or "No path yet.")
        return
    end
    local title, line = ns.UI.Summary(p)
    ns.Print(title .. ". " .. line)
    for _, s in ipairs(ns.UI.Steps(p)) do
        local text, sub = ns.UI.StepText(s, p)
        ns.Print(("  %d. %s: %s"):format(s.n, text, sub))
    end
    for _, note in ipairs(p.notes) do ns.Print("  " .. note) end
end

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
    if ns.Prices then ns.Prices.Debug() end
end

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
        if n and n >= 0 and n <= 450 then
            ns.db.target = math.floor(n)
            ns.Changed()
            ns.Print(n == 0 and "Target: your rank's cap." or ("Target: skill %d."):format(n))
        else
            ns.Print("Usage: /skillpath target <skill> (0: your rank's cap)")
        end
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
        ns.Print("Commands: /skillpath (the SkillPath tab), print, scan, target <skill>, forget, config, minimap, "
            .. "reset, debug")
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
    "MERCHANT_SHOW", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "GET_ITEM_INFO_RECEIVED" }
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
            -- Learned with the window closed (a trainer, a recipe item): the saved lists are behind.
            local char = ns.Char()
            for _, prof in pairs(char and char.profs or {}) do prof.unread = true end
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
    elseif event == "MERCHANT_SHOW" then
        if ns.Prices.ReadMerchant() > 0 then ns.Changed() end
    else
        ns.Prices.OnEvent(event, a, b)
        if event == "AUCTION_HOUSE_SHOW" and ns.UI then ns.UI.AuctionOpened() end
    end
end)
