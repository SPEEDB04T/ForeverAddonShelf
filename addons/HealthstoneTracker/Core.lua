-- Healthstone Tracker: settings, the player's own healthstones, events, slash commands
local ADDON, ns = ...
local issecret = ns.issecret

ns.VERSION = "1.3.4"
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
    soul = true,            -- show the soulstone part of the window
    point = nil,            -- { left, top } of the window
}
local charDefaults = {
    seen = {},              -- [name] = { givenAt, givenBy, givenItem, usedAt } for players without the addon
                            -- also soulItem: the last soulstone carried, to ask its cooldown once it is used up
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
        local red = (RED_FONT_COLOR and RED_FONT_COLOR.GenerateHexColorMarkup) and RED_FONT_COLOR:GenerateHexColorMarkup() or "|cffff2020"
        ns.Print(red .. "error:|r " .. msg)
    end
    return false
end

----------------------------------------------------------------------
-- The player's own healthstones
----------------------------------------------------------------------
ns.me = { count = 0, item = nil, byItem = {}, where = nil, cdEnd = nil,
          soulCount = 0, soulItem = nil, soulCdEnd = nil }
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
    local soulCount, soulItem = 0, nil
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
                elseif type(id) == "number" and ns.IsSoulItem(id) then
                    soulCount = soulCount + StackAt(bag, slot)
                    if not soulItem or (ns.SOUL_ITEMS[id] or 0) > (ns.SOUL_ITEMS[soulItem] or 0) then soulItem = id end
                end
            end
        end
    end
    local me = ns.me
    local changed = (count ~= me.count) or (best ~= me.item) or (soulCount ~= me.soulCount) or (soulItem ~= me.soulItem)
    me.count, me.item, me.byItem, me.where = count, best, byItem, where
    me.soulCount, me.soulItem = soulCount, soulItem
    if soulItem and ns.cdb then ns.cdb.soulItem = soulItem end
    if changed then
        ns.Group.MarkState(false)
        ns.dirty = true
    end
    ns.Trade.AfterScan()
end

-- The real cooldown, read from the stone in the bags. Without a stone the
-- timer started by the player's own use keeps counting.
-- true and when the item's cooldown ends (nil = ready), or false when the game won't say.
local function ItemCooldown(itemID)
    local read = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown)
    if not read or type(itemID) ~= "number" then return false end
    local ok, start, duration = pcall(read, itemID)
    if not ok or issecret(start) or issecret(duration) or type(start) ~= "number" or type(duration) ~= "number" then return false end
    local cdEnd = (duration > 2 and start > 0) and (start + duration) or nil
    if cdEnd and cdEnd <= GetTime() then cdEnd = nil end
    return true, cdEnd
end

local function Differs(a, b)
    return (a == nil) ~= (b == nil) or (a and b and math.abs(a - b) > 1.5) or false
end

local function ReadCooldown()
    local me = ns.me
    local ok, cdEnd = ItemCooldown(me.item)
    if ok and Differs(cdEnd, me.cdEnd) then
        me.cdEnd = cdEnd
        ns.Group.MarkState(false)
        ns.dirty = true
    end
    -- The soulstone is used up when it is cast, so its cooldown is asked by the
    -- last one carried. Without one in the bags "no cooldown" is not trusted.
    if not ns.isWarlock then return end
    local ok2, soulEnd = ItemCooldown(me.soulItem or (ns.cdb and ns.cdb.soulItem))
    if ok2 and (soulEnd or (me.soulCount or 0) > 0) and Differs(soulEnd, me.soulCdEnd) then
        me.soulCdEnd = soulEnd
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

-- The game names who a cast is aimed at only when it starts.
local soulTarget, soulTargetAt

function events.UNIT_SPELLCAST_SENT(unit, target, _, spellID)
    if issecret(unit) or issecret(spellID) or unit ~= "player" or type(spellID) ~= "number" then return end
    if not ns.IsSoulSpell(spellID) then return end
    soulTarget = (not issecret(target)) and ns.Norm(target) or nil
    soulTargetAt = GetTime()
end

function events.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if issecret(unit) or issecret(spellID) or type(unit) ~= "string" or type(spellID) ~= "number" then return end
    local mine = (unit == "player")
    local theirs = (unit:find("^party%d+$") or unit:find("^raid%d+$")) and true or false
    if not (mine or theirs) then return end
    if ns.IsStoneSpell(spellID) then
        if mine then OnPlayerUse() else ns.Group.ObserveUse(unit) end
    elseif ns.SOUL_REZ[spellID] then
        ns.Group.ObserveSoulRez(unit)
    elseif ns.IsSoulSpell(spellID) then
        if mine then
            local target = (soulTargetAt and GetTime() - soulTargetAt < 15) and soulTarget or nil
            soulTarget, soulTargetAt = nil, nil
            ns.me.soulCdEnd = GetTime() + ns.SOUL_COOLDOWN
            ns.Group.PlayerSoulstoned(target)
            C_Timer.After(0.5, function()
                ns.Safe(ns.ScanBags)
                ns.Safe(ReadCooldown)
            end)
        else
            ns.Group.ObserveSoulCast(unit)
        end
    end
end

function events.UNIT_AURA(unit)
    ns.Group.OnUnitAura(unit)
end

-- out of the fight, buffs can be read again
function events.PLAYER_REGEN_ENABLED()
    ns.Group.scanAll = true
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
    if type(HealthstoneTrackerCharDB.soulItem) ~= "number" then HealthstoneTrackerCharDB.soulItem = nil end
    ns.db, ns.cdb = HealthstoneTrackerDB, HealthstoneTrackerCharDB
    if not FILTERS[ns.db.filter] then ns.db.filter = "auto" end

    local _, class = UnitClass("player")
    ns.playerClass = (not issecret(class)) and class or nil
    ns.isWarlock = (ns.playerClass == "WARLOCK")
    ns.playerName = UnitName("player")

    -- each part on its own, so one failing does not take the others with it
    ns.Safe(ns.Group.Init)
    ns.Safe(ns.UI.Create)
    if ns.Kit and ns.Options then ns.Safe(ns.Options.Init) end   -- missing until the first full restart after the update
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
-- Actions shared by the slash commands, the options window and the minimap button
----------------------------------------------------------------------
function ns.ToggleWindow()
    local db = ns.db
    db.shown = not db.shown
    if not db.shown then
        ns.Print("window hidden. /hst shows it again.")
    elseif not ns.UI.ShouldShow() then
        ns.Print("window on. It appears when you are in a group with a warlock (/hst always for any group, /hst demo for a preview).")
    end
    ns.dirty = true
end

function ns.ToggleDemo()
    ns.Group.SetDemo(not ns.Group.demo)
    ns.Print(ns.Group.demo and "demo on: six pretend players joined. /hst demo again to remove them." or "demo off.")
    ns.dirty = true
end

function ns.ResetSettings()
    local db = ns.db
    local log = db.commLog      -- the message log is a record, not a setting
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(defaults) do db[k] = v end
    db.commLog = log
    ns.UI.ApplyLayout()
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.Print("settings reset.")
    ns.dirty = true
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function Help()
    ns.Print("commands:")
    ns.Print("  /hst  - show or hide the window")
    ns.Print("  /hst all | missing | auto  - who is listed (now: " .. ns.db.filter .. "; auto = everyone in a party, only the missing in a raid)")
    ns.Print("  /hst announce  - post who still needs a healthstone, and who has the soulstone, in group chat")
    ns.Print("  /hst soul  - show the soulstone part of the window (" .. OnOff(ns.db.soul) .. ")")
    ns.Print("  /hst always  - show in groups without a warlock too (" .. OnOff(ns.db.always) .. ")")
    ns.Print("  /hst trade  - warlock: click a name to open a trade and offer your stone (" .. OnOff(ns.db.clickTrade) .. ")")
    ns.Print("  /hst config  - open the options window")
    ns.Print("  /hst minimap  - show or hide the minimap button")
    ns.Print("  /hst lock | unlock | scale <0.5-2> | status | demo | reset")
end

-- Kit.lua and Options.lua are new in 1.2.0. The game only finds new files after a full restart,
-- so right after an update a /reload runs this file without them: say so instead of erroring.
local function HasKit()
    if ns.Kit and ns.Options then return true end
    ns.Print("the options window and the minimap button appear after you restart the game once (this update added new files, and /reload does not load those).")
    return false
end

SLASH_HEALTHSTONETRACKER1 = "/hst"
SLASH_HEALTHSTONETRACKER2 = "/healthstones"
SLASH_HEALTHSTONETRACKER3 = "/healthstonetracker"
SlashCmdList.HEALTHSTONETRACKER = function(msg)
    if not ns.db then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local db = ns.db
    if cmd == "" then
        ns.ToggleWindow()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if HasKit() then ns.Kit.Open() end
    elseif cmd == "minimap" then
        if HasKit() then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("minimap button " .. OnOff(ns.Kit.MinimapShown()) .. ".")
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
    elseif cmd == "soul" or cmd == "soulstone" or cmd == "soulstones" or cmd == "ss" then
        db.soul = not db.soul
        ns.Print("soulstones in the window: " .. OnOff(db.soul) .. ".")
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
        ns.ToggleDemo()
    elseif cmd == "status" then
        ns.Group.PrintStatus()
    elseif cmd == "reset" then
        ns.ResetSettings()
    else
        Help()
    end
    ns.dirty = true
    if ns.Kit then ns.Kit.Sync() end      -- an open options window follows what was typed
end
