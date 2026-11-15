-- Destroy Advisor: core (settings, safe API access, the bag scan, destroying and selling,
-- the "bags are full" suggestion, events, slash commands)
local ADDON, ns = ...

ns.ADDON = ADDON
ns.VERSION = "1.0.0"
ns.NAME = "Destroy Advisor"
ns.ICON = "Interface\\Icons\\INV_Misc_Bag_07_Red"

local defaults = {
    point = nil,
    scale = 1,
    grey = true,         -- poor quality (grey) items
    quest = true,        -- quest leftovers: their quests are done or not for this character
    known = true,        -- bound recipes, pets, mounts and toys already learned
    gear = true,         -- bound gear this class can never wear or wield
    useless = true,      -- ammo this class can't shoot, drinks for a class without mana
    fullChat = true,     -- say in chat what to destroy when the bags fill up
    fullOpen = false,    -- also open the list then
    tooltip = true,      -- a line in item tooltips
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

-- Every return value of fn, in a table (GetItemInfo has more than four).
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
    return ns.Val(rawget(tbl, key))
end

-- The game's own text colours (NORMAL_FONT_COLOR and the like); the numbers are only for a client without them.
function ns.GameColor(name, r, g, b)
    local color = _G[name]
    if type(color) == "table" and type(color.r) == "number" then return color.r, color.g, color.b end
    return r, g, b
end

-- A game string (ITEM_SPELL_KNOWN and the like), or the English text on a client without it.
function ns.Text(name, fallback)
    local value = _G[name]
    if type(value) == "string" and value ~= "" then return value end
    return fallback
end

function ns.Print(msg)
    local text = "|cffd8442eDestroy Advisor|r: " .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

function ns.After(seconds, fn)
    if C_Timer and C_Timer.After then C_Timer.After(seconds, fn) else fn() end
end

function ns.Now()
    return ns.Num(ns.Call(GetTime)) or 0
end

function ns.Money(copper)
    copper = math.floor(copper or 0)
    if GetCoinTextureString then
        local text = ns.Str(ns.Call(GetCoinTextureString, copper))
        if text then return text end
    end
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if g > 0 then return ("%dg %ds %dc"):format(g, s, c) end
    if s > 0 then return ("%ds %dc"):format(s, c) end
    return ("%dc"):format(c)
end

----------------------------------------------------------------------
-- Settings
----------------------------------------------------------------------
local function InitDB()
    if type(DestroyAdvisorDB) ~= "table" then DestroyAdvisorDB = {} end
    for key, value in pairs(defaults) do
        if DestroyAdvisorDB[key] == nil then DestroyAdvisorDB[key] = value end
    end
    if type(DestroyAdvisorDB.keep) ~= "table" then DestroyAdvisorDB.keep = {} end   -- [itemID] = name
    ns.db = DestroyAdvisorDB
end
ns.InitDB = InitDB

function ns.ResetSettings()
    local db = ns.db
    local keep, minimap = db.keep, db.minimap
    for key in pairs(db) do db[key] = nil end
    for key, value in pairs(defaults) do db[key] = value end
    db.keep, db.minimap = keep, nil
    if ns.UI then
        ns.UI.ApplyScale()
        ns.UI.RestorePosition()
    end
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.Changed()
    ns.Print("Settings reset. Kept items stay kept.")
end

----------------------------------------------------------------------
-- The scan. Judged once per change of the bags or the quest log; the
-- window, the tooltip line, the chat suggestion and Baganator all read it.
----------------------------------------------------------------------
local scan            -- { list = { entry, ... }, bySlot = { ["bag:slot"] = entry }, free, total, pending }

function ns.Scan()
    if not scan then scan = ns.Judge.All(ns.db) end
    return scan
end

function ns.EntryAt(bag, slot)
    if not ns.db then return nil end
    local s = ns.Scan()
    local entry = s.bySlot[bag .. ":" .. slot]
    if not entry then return nil end
    -- The slot may hold something else since the scan (moved, split, looted into it).
    local link = ns.Judge.LinkAt(bag, slot)
    if link ~= entry.link then
        ns.Changed()
        entry = ns.Scan().bySlot[bag .. ":" .. slot]
    end
    return entry
end

local refreshQueued = false
local baganatorQueued = false
function ns.Changed(fromQuests)
    scan = nil
    if fromQuests and ns.Baganator then baganatorQueued = true end
    if refreshQueued then return end
    refreshQueued = true
    ns.After(0.2, function()
        refreshQueued = false
        if ns.UI and ns.UI.IsShown() then ns.UI.Update() end
        if baganatorQueued then
            baganatorQueued = false
            if ns.Baganator then ns.Baganator.Refresh() end
        end
    end)
end

----------------------------------------------------------------------
-- Keeping an item (never suggested again)
----------------------------------------------------------------------
function ns.Keep(itemID, name)
    if not itemID then return end
    ns.db.keep[itemID] = name or true
    ns.Changed(true)
end

function ns.Unkeep(itemID)
    if not itemID then return end
    ns.db.keep[itemID] = nil
    ns.Changed(true)
end

function ns.KeptCount()
    local n = 0
    for _ in pairs(ns.db.keep) do n = n + 1 end
    return n
end

function ns.ForgetKept()
    local n = ns.KeptCount()
    ns.db.keep = {}
    ns.Changed(true)
    ns.Print(("Forgot %d kept %s; they are suggested again when they qualify."):format(n, n == 1 and "item" or "items"))
end

----------------------------------------------------------------------
-- Destroying and selling. Destroying picks the item up and shows the
-- game's own confirmation (the same one as dragging it out of the bag),
-- so nothing is ever destroyed without the player saying yes there.
----------------------------------------------------------------------
ns.atMerchant = false

local function CursorBusy()
    return CursorHasItem and ns.Call(CursorHasItem) and true or false
end

-- Which of the game's delete dialogs it would show for this item (GameDialogDefs.lua).
function ns.DeleteDialog(entry)
    local quest = entry.questItem
    local good = (entry.quality or 1) >= 3
    if quest then return good and "DELETE_GOOD_QUEST_ITEM" or "DELETE_QUEST_ITEM" end
    return good and "DELETE_GOOD_ITEM" or "DELETE_ITEM"
end

function ns.CanSell(entry)
    return ns.atMerchant and entry.value > 0
end

function ns.Destroy(entry)
    if type(entry) ~= "table" then return false end
    local now = ns.EntryAt(entry.bag, entry.slot)
    if not now or now.link ~= entry.link then
        ns.Print("That bag slot changed; the list is up to date again.")
        if ns.UI then ns.UI.Update() end
        return false
    end
    if not (C_Container and C_Container.PickupContainerItem) then return false end
    if CursorBusy() and ClearCursor then pcall(ClearCursor) end
    local which = ns.DeleteDialog(now)
    if not (StaticPopup_Show and type(StaticPopupDialogs) == "table" and StaticPopupDialogs[which]) then
        ns.Print("The game's confirmation is missing here, so nothing was destroyed. Drag "
            .. now.link .. " out of your bags to destroy it.")
        return false
    end
    pcall(C_Container.PickupContainerItem, now.bag, now.slot)
    if not CursorBusy() then
        ns.Print("Couldn't pick up " .. now.link .. " (locked or in use); try again in a moment.")
        return false
    end
    local ok = pcall(StaticPopup_Show, which, now.name or now.link)
    if not ok then
        if ClearCursor then pcall(ClearCursor) end
        return false
    end
    return true
end

function ns.Sell(entry)
    if type(entry) ~= "table" then return false end
    if not ns.CanSell(entry) then return false end
    local now = ns.EntryAt(entry.bag, entry.slot)
    if not now or now.link ~= entry.link then
        ns.Print("That bag slot changed; the list is up to date again.")
        if ns.UI then ns.UI.Update() end
        return false
    end
    if CursorBusy() and ClearCursor then pcall(ClearCursor) end
    if not (C_Container and C_Container.UseContainerItem) then return false end
    local ok = pcall(C_Container.UseContainerItem, now.bag, now.slot)
    if ok then ns.Print(("Sold %s%s for %s."):format(now.link, now.count > 1 and (" x" .. now.count) or "", ns.Money(now.value))) end
    return ok
end

-- The click on a row: sell at a merchant, otherwise destroy (the game asks first).
function ns.Act(entry)
    if ns.CanSell(entry) then return ns.Sell(entry) end
    return ns.Destroy(entry)
end

----------------------------------------------------------------------
-- Chat
----------------------------------------------------------------------
local function Short(entry)
    return ("%s%s (%s)"):format(entry.link, entry.count > 1 and (" x" .. entry.count) or "", entry.short)
end

function ns.Report()
    local s = ns.Scan()
    if #s.list == 0 then
        ns.Print(s.pending > 0 and "Nothing to destroy yet; the game is still loading some item names." or
            "Nothing in your bags needs destroying.")
        return
    end
    ns.Print(("%d %s to clear (%d of %d bag slots free):"):format(#s.list, #s.list == 1 and "item" or "items",
        s.free, s.total))
    for _, entry in ipairs(s.list) do
        local worth = entry.value > 0 and (" - " .. ns.Money(entry.value)) or ""
        ns.Print(("  %s%s: %s%s"):format(entry.link, entry.count > 1 and (" x" .. entry.count) or "", entry.reason, worth))
    end
end

-- Said once when the bags fill up (and when the game says so), at most every 20 seconds.
local lastFullSay = -100
local wasFull = false
function ns.BagsFull(why)
    if not ns.db then return end
    local now = ns.Now()
    if now - lastFullSay < 20 then return end
    lastFullSay = now
    local s = ns.Scan()
    if ns.db.fullChat then
        if #s.list == 0 then
            ns.Print("Your bags are full, and nothing in them is safe to destroy.")
        else
            local parts = {}
            for i = 1, math.min(3, #s.list) do parts[#parts + 1] = Short(s.list[i]) end
            local more = #s.list > 3 and (" and %d more; /destroy for the list"):format(#s.list - 3) or ""
            ns.Print(("Your bags are full. Safe to destroy: %s%s."):format(table.concat(parts, ", "), more))
        end
    end
    if ns.db.fullOpen and #s.list > 0 and ns.UI then ns.UI.Show() end
end

local function CheckFull()
    local free, total = ns.Judge.FreeSlots()
    local full = total > 0 and free == 0
    if full and not wasFull then ns.BagsFull("filled") end
    wasFull = full
end
ns.CheckFull = CheckFull

----------------------------------------------------------------------
-- Debug: every item in the bags with what the addon thinks of it
----------------------------------------------------------------------
local function Debug()
    local rows = ns.Judge.Explain(ns.db)
    local q = ns.Judge.Questie() and "yes" or "no"
    ns.Print(("Questie data: %s, merchant open: %s, %d kept items"):format(q, ns.atMerchant and "yes" or "no", ns.KeptCount()))
    for _, row in ipairs(rows) do ns.Print("  " .. row) end
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function ParseItemID(arg)
    local id = arg and (arg:match("item:(%d+)") or arg:match("^(%d+)$"))
    return id and tonumber(id) or nil
end

local function Slash(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "show" or cmd == "toggle" then
        ns.UI.Toggle()
    elseif cmd == "list" or cmd == "print" then
        ns.Report()
    elseif cmd == "keep" then
        local id = ParseItemID(arg)
        if id then
            ns.Keep(id, arg:match("%[(.-)%]"))
            ns.Print(("Kept %s: it is never suggested again. /destroy unkeep %d undoes it."):format(arg, id))
        else
            ns.Print("Usage: /destroy keep <shift-click an item>")
        end
    elseif cmd == "unkeep" then
        local id = ParseItemID(arg)
        if id and ns.db.keep[id] then
            ns.Unkeep(id)
            ns.Print(("%s is suggested again when it qualifies."):format(arg))
        else
            ns.Print("Usage: /destroy unkeep <shift-click an item, or its item number>")
        end
    elseif cmd == "forget" then
        ns.ForgetKept()
    elseif cmd == "full" then
        lastFullSay = -100
        ns.BagsFull("command")
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if ns.Kit and ns.Options then ns.Kit.Open() else ns.Print("The options aren't loaded; /reload loads them.") end
    elseif cmd == "minimap" then
        if ns.Kit and ns.Options then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("Minimap button: " .. (ns.Kit.MinimapShown() and "on" or "off"))
        else
            ns.Print("The minimap button isn't loaded; /reload loads it.")
        end
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 then
            ns.db.scale = n
            ns.UI.ApplyScale()
        else
            ns.Print("Usage: /destroy scale <0.5-2>")
        end
    elseif cmd == "reset" then
        ns.db.point, ns.db.scale = nil, 1
        ns.UI.ApplyScale()
        ns.UI.RestorePosition()
        ns.Print("Window position and scale reset.")
    elseif cmd == "debug" then
        Debug()
    else
        ns.Print("Commands: /destroy (the list), list (print it), full (what to destroy now), keep <item>, "
            .. "unkeep <item>, forget (forget kept items), config, minimap, scale <n>, reset, debug")
    end
    if ns.Kit then ns.Kit.Sync() end      -- an open options window follows what was typed
end

SLASH_DESTROYADVISOR1 = "/destroy"
SLASH_DESTROYADVISOR2 = "/destroyadvisor"
SlashCmdList = SlashCmdList or {}
SlashCmdList["DESTROYADVISOR"] = Slash

-- The addon's line in the list of addons next to the minimap: left-click the list,
-- right-click the options.
function DestroyAdvisor_Toggle(_, mouseButton)
    if not (ns.UI and ns.db) then return end
    if mouseButton == "RightButton" and ns.Kit then ns.Kit.Open() else ns.UI.Toggle() end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.eventFrame = frame
local EVENTS = { "PLAYER_LOGIN", "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED",
    "QUEST_TURNED_IN", "MERCHANT_SHOW", "MERCHANT_CLOSED", "UI_ERROR_MESSAGE", "BAG_OVERFLOW_WITH_FULL_INVENTORY",
    "GET_ITEM_INFO_RECEIVED", "NEW_RECIPE_LEARNED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "SKILL_LINES_CHANGED",
    "EQUIPMENT_SETS_CHANGED", "NEW_PET_ADDED", "NEW_MOUNT_ADDED", "NEW_TOY_ADDED" }
for _, event in ipairs(EVENTS) do pcall(frame.RegisterEvent, frame, event) end

local QUEST_EVENTS = { QUEST_LOG_UPDATE = true, QUEST_ACCEPTED = true, QUEST_REMOVED = true, QUEST_TURNED_IN = true,
    NEW_RECIPE_LEARNED = true, LEARNED_SPELL_IN_TAB = true, PLAYER_LEVEL_UP = true, SKILL_LINES_CHANGED = true,
    NEW_PET_ADDED = true, NEW_MOUNT_ADDED = true, NEW_TOY_ADDED = true, EQUIPMENT_SETS_CHANGED = true }

frame:SetScript("OnEvent", function(_, event, a, b)
    if event == "PLAYER_LOGIN" then
        InitDB()
        if ns.UI then ns.UI.Create() end
        if ns.Hooks then ns.Hooks.Init() end
        if ns.Kit and ns.Options then
            local ok, err = pcall(ns.Options.Init)
            if not ok then ns.Print("options error: " .. tostring(err)) end
        end
        wasFull = false
        return
    elseif not ns.db then
        return
    end
    if event == "BAG_UPDATE_DELAYED" then
        ns.Changed()
        CheckFull()
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
        ns.atMerchant = event == "MERCHANT_SHOW"
        if ns.UI and ns.UI.IsShown() then ns.UI.Update() end
    elseif event == "UI_ERROR_MESSAGE" then
        local message = ns.Val(b)
        if message ~= nil and message == ns.Text("ERR_INV_FULL", "Inventory is full.") then ns.BagsFull("error") end
    elseif event == "BAG_OVERFLOW_WITH_FULL_INVENTORY" then
        ns.BagsFull("overflow")
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if scan and scan.pending > 0 then ns.Changed() end
    elseif QUEST_EVENTS[event] then
        ns.Changed(true)
    end
end)
