-- Healthstone Tracker: settings, the player's own healthstones, events, slash commands
local ADDON, ns = ...
local issecret = ns.issecret

ns.VERSION = "1.0.0"
do
    local get = C_AddOns and C_AddOns.GetAddOnMetadata
    if get then
        local ok, v = pcall(get, ADDON, "Version")
        if ok and type(v) == "string" and v ~= "" and not issecret(v) then ns.VERSION = v end
    end
end

local defaults = {
    shown = true,
    locked = false,
    scale = 1,
    filter = "auto",        -- "auto" (everyone in a party, only the missing in a raid) | "all" | "missing"
    always = false,         -- show in groups without a warlock too
    clickTrade = true,      -- warlock: click a name to open a trade and offer the stone
    point = nil,            -- { left, top } of the window
}
local charDefaults = {
    seen = {},              -- [name] = { givenAt, givenBy, givenItem, usedAt } for players without the addon
}
local FILTERS = { auto = true, all = true, missing = true }

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8fd14fHealthstones|r: " .. tostring(msg))
end

-- Run something without letting an error repeat every frame in the error log.
local seenErrors, errorCount = {}, 0
function ns.Safe(f, ...)
    local ok, err = pcall(f, ...)
    if ok then return true end
    local msg = issecret(err) and "blocked by a secret value" or tostring(err)
    if not seenErrors[msg] and errorCount < 5 then
        seenErrors[msg] = true
        errorCount = errorCount + 1
        ns.Print("|cffff6060error:|r " .. msg)
    end
    return false
end

----------------------------------------------------------------------
-- The player's own healthstones
----------------------------------------------------------------------
ns.me = { count = 0, item = nil, byItem = {}, where = nil, cdEnd = nil }
ns.dirty = true

local function StackAt(bag, slot)
    if C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            local n = info.stackCount
            if not issecret(n) and type(n) == "number" and n > 0 then return n end
        end
    end
    return 1
end

-- Counts the healthstones in the bags. When the game hides the bags (secret
-- values) nothing changes and the last known count stays.
function ns.ScanBags()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID) then return end
    local byItem, count, best, bestScore, where = {}, 0, nil, -1, nil
    for bag = 0, 4 do
        local ok, slots = pcall(C_Container.GetContainerNumSlots, bag)
        if not ok or issecret(slots) then return end
        if type(slots) == "number" then
            for slot = 1, slots do
                local ok2, id = pcall(C_Container.GetContainerItemID, bag, slot)
                if not ok2 or issecret(id) then return end
                local stone = type(id) == "number" and ns.StoneInfo(id)
                if stone then
                    local n = StackAt(bag, slot)
                    count = count + n
                    byItem[id] = (byItem[id] or 0) + n
                    local score = stone.rank * 10 + stone.bonus
                    if score > bestScore then best, bestScore, where = id, score, { bag, slot } end
                end
            end
        end
    end
    local me = ns.me
    local changed = (count ~= me.count) or (best ~= me.item)
    me.count, me.item, me.byItem, me.where = count, best, byItem, where
    if changed then
        ns.Group.MarkState(false)
        ns.dirty = true
    end
    ns.Trade.AfterScan()
end

-- The real cooldown, read from the stone in the bags. Without a stone the
-- timer started by the player's own use keeps counting.
local function ReadCooldown()
    local me = ns.me
    if not me.item then return end
    local read = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown)
    if not read then return end
    local ok, start, duration = pcall(read, me.item)
    if not ok or issecret(start) or issecret(duration) or type(start) ~= "number" or type(duration) ~= "number" then return end
    local cdEnd = (duration > 2 and start > 0) and (start + duration) or nil
    if cdEnd and cdEnd <= GetTime() then cdEnd = nil end
    local old = me.cdEnd
    if (cdEnd == nil) ~= (old == nil) or (cdEnd and old and math.abs(cdEnd - old) > 1.5) then
        me.cdEnd = cdEnd
        ns.Group.MarkState(false)
        ns.dirty = true
    end
end

local function OnPlayerUse()
    ns.me.cdEnd = GetTime() + ns.COOLDOWN
    ns.Group.MarkState(false)
    ns.dirty = true
    C_Timer.After(0.5, function()
        ns.Safe(ns.ScanBags)
        ns.Safe(ReadCooldown)
    end)
end

----------------------------------------------------------------------
-- Update loop
----------------------------------------------------------------------
local driver = CreateFrame("Frame")
local acc, second, scanIn = 0, 0, 0

local function Tick(_, elapsed)
    acc = acc + elapsed
    if acc < 0.25 then return end
    second = second + acc
    acc = 0
    if second >= 1 then
        second = 0
        -- bag events can be missed, so look again now and then while grouped
        scanIn = scanIn - 1
        if ns.Trade.Waiting() or (scanIn <= 0 and (ns.Group.grouped or ns.Group.demo)) then
            scanIn = 5
            ns.Safe(ns.ScanBags)
            ns.Safe(ReadCooldown)
        end
        ns.Safe(ns.Group.Tick, GetTime())
        ns.dirty = true     -- cooldown timers count down
    end
    if ns.dirty then
        ns.dirty = false
        ns.Safe(ns.UI.Refresh)
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local events = {}

function events.BAG_UPDATE_DELAYED()
    ns.ScanBags()
    ReadCooldown()
end

function events.BAG_UPDATE_COOLDOWN()
    ReadCooldown()
end

function events.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if issecret(unit) or issecret(spellID) or type(unit) ~= "string" or type(spellID) ~= "number" then return end
    if not ns.IsStoneSpell(spellID) then return end
    if unit == "player" then
        OnPlayerUse()
    elseif unit:find("^party%d+$") or unit:find("^raid%d+$") then
        ns.Group.ObserveUse(unit)
    end
end

function events.PLAYER_ENTERING_WORLD()
    seenErrors, errorCount = {}, 0
    ns.Safe(ns.Group.Rebuild)
    ns.Safe(ns.ScanBags)
    ns.Safe(ReadCooldown)
end

function events.GROUP_ROSTER_UPDATE()
    ns.Group.Rebuild()
end

function events.UNIT_CONNECTION()
    ns.dirty = true
end

function events.CHAT_MSG_ADDON(prefix, text, channel, sender)
    ns.Group.OnAddonMessage(prefix, text, channel, sender)
end

function events.TRADE_SHOW() ns.Trade.OnShow() end
function events.TRADE_PLAYER_ITEM_CHANGED() ns.Trade.Look() end
function events.TRADE_ACCEPT_UPDATE() ns.Trade.Look() end
function events.TRADE_CLOSED() ns.Trade.OnClosed() end
function events.TRADE_REQUEST_CANCEL() ns.Trade.OnClosed() end

local function Init()
    HealthstoneTrackerDB = HealthstoneTrackerDB or {}
    HealthstoneTrackerCharDB = HealthstoneTrackerCharDB or {}
    for k, v in pairs(defaults) do
        if HealthstoneTrackerDB[k] == nil then HealthstoneTrackerDB[k] = v end
    end
    for k, v in pairs(charDefaults) do
        if type(HealthstoneTrackerCharDB[k]) ~= type(v) then HealthstoneTrackerCharDB[k] = {} end
    end
    ns.db, ns.cdb = HealthstoneTrackerDB, HealthstoneTrackerCharDB
    if not FILTERS[ns.db.filter] then ns.db.filter = "auto" end

    local _, class = UnitClass("player")
    ns.playerClass = (not issecret(class)) and class or nil
    ns.isWarlock = (ns.playerClass == "WARLOCK")
    ns.playerName = UnitName("player")

    -- each part on its own, so one failing does not take the others with it
    ns.Safe(ns.Group.Init)
    ns.Safe(ns.UI.Create)
    ns.Safe(ns.ScanBags)
    ns.Safe(ReadCooldown)

    for ev in pairs(events) do pcall(driver.RegisterEvent, driver, ev) end
    driver:SetScript("OnEvent", function(_, event, ...)
        local handler = events[event]
        if handler then ns.Safe(handler, ...) end
    end)
    driver:SetScript("OnUpdate", function(self, elapsed) ns.Safe(Tick, self, elapsed) end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() ns.Safe(Init) end)

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function Help()
    ns.Print("commands:")
    ns.Print("  /hst  - show or hide the window")
    ns.Print("  /hst all | missing | auto  - who is listed (now: " .. ns.db.filter .. "; auto = everyone in a party, only the missing in a raid)")
    ns.Print("  /hst announce  - post who still needs a healthstone in group chat")
    ns.Print("  /hst always  - show in groups without a warlock too (" .. OnOff(ns.db.always) .. ")")
    ns.Print("  /hst trade  - warlock: click a name to open a trade and offer your stone (" .. OnOff(ns.db.clickTrade) .. ")")
    ns.Print("  /hst lock | unlock | scale <0.5-2> | status | demo | reset")
end

SLASH_HEALTHSTONETRACKER1 = "/hst"
SLASH_HEALTHSTONETRACKER2 = "/healthstones"
SLASH_HEALTHSTONETRACKER3 = "/healthstonetracker"
SlashCmdList.HEALTHSTONETRACKER = function(msg)
    if not ns.db then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local db = ns.db
    if cmd == "" then
        db.shown = not db.shown
        if not db.shown then
            ns.Print("window hidden. /hst shows it again.")
        elseif not ns.UI.ShouldShow() then
            ns.Print("window on. It appears when you are in a group with a warlock (/hst always for any group, /hst demo for a preview).")
        end
    elseif FILTERS[cmd] then
        db.filter = cmd
        ns.Print("listing: " .. cmd .. ".")
    elseif cmd == "announce" or cmd == "report" then
        ns.Group.Announce()
    elseif cmd == "always" then
        db.always = not db.always
        ns.Print(db.always and "showing in every group." or "showing only in groups with a warlock.")
    elseif cmd == "trade" then
        db.clickTrade = not db.clickTrade
        ns.Print("click a name to trade your stone: " .. OnOff(db.clickTrade) .. (ns.isWarlock and "" or " (warlocks only)"))
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        ns.Print(db.locked and "window locked." or "window unlocked: drag it to move it.")
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 then
            db.scale = n
            ns.UI.ApplyLayout()
        else
            ns.Print("usage: /hst scale 1.2")
        end
    elseif cmd == "demo" then
        ns.Group.SetDemo(not ns.Group.demo)
        ns.Print(ns.Group.demo and "demo on: five pretend players joined. /hst demo again to remove them." or "demo off.")
    elseif cmd == "status" then
        ns.Group.PrintStatus()
    elseif cmd == "reset" then
        for k in pairs(db) do db[k] = nil end
        for k, v in pairs(defaults) do db[k] = v end
        ns.UI.ApplyLayout()
        ns.Print("settings reset.")
    else
        Help()
    end
    ns.dirty = true
end
