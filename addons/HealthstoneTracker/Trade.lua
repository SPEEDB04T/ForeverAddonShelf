-- Healthstone Tracker: trades.
-- Notices when the player hands a healthstone to someone (so players without
-- the addon can be marked as having one), and lets a warlock click a name to
-- open a trade with the stone already in it.
local ADDON, ns = ...
local issecret = ns.issecret

local T = {}
ns.Trade = T

local partner           -- who the trade window is with
local before = {}       -- [itemID] = how many the player had when the stone went into the window
local pending           -- after the window closed: { partner, items = before, at }
local want              -- click-to-trade: { name, at }

local function LinkItemID(link)
    if issecret(link) or type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

-- Which healthstones sit in the player's side of the trade window.
function T.Look()
    if not partner or not GetTradePlayerItemLink then return end
    for i = 1, 6 do
        local ok, link = pcall(GetTradePlayerItemLink, i)
        local id = ok and LinkItemID(link)
        if id and ns.StoneInfo(id) and not before[id] then
            ns.ScanBags()
            local n = ns.me.byItem[id] or 0
            if n > 0 then before[id] = n end
        end
    end
end

local function PlaceStone()
    ns.ScanBags()
    local where = ns.me.where
    if not where or not (C_Container and C_Container.PickupContainerItem and ClickTradeButton) then return end
    if GetCursorInfo and GetCursorInfo() then return end    -- the player is holding something
    pcall(C_Container.PickupContainerItem, where[1], where[2])
    pcall(ClickTradeButton, 1)
    if GetCursorInfo and GetCursorInfo() and ClearCursor then pcall(ClearCursor) end
end

function T.OnShow()
    partner = ns.FullUnitName("NPC")
    before = {}
    if want and partner == want.name and GetTime() - want.at < 10 then
        want = nil
        PlaceStone()
    end
    want = nil
    T.Look()
end

function T.OnClosed()
    if partner and next(before) then
        pending = { partner = partner, items = before, at = GetTime() }
        ns.ScanBags()       -- the bags may already have changed
    end
    partner, before = nil, {}
end

function T.Waiting()
    return pending ~= nil
end

-- A stone that was in the trade window and has now left the bags was given away.
function T.AfterScan()
    if not pending then return end
    if GetTime() - pending.at > 10 then
        pending = nil
        return
    end
    local p = pending
    for id, was in pairs(p.items) do
        if (ns.me.byItem[id] or 0) < was then
            p.items[id] = nil
            ns.Group.NoteGave(p.partner, id)
        end
    end
    if pending == p and next(p.items) == nil then pending = nil end
end

-- Warlock: open a trade with this player; the stone goes in when it opens.
function T.Offer(m)
    if not m or m.isPlayer or m.demo or not m.unit then return end
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("can't open a trade in combat.")
        return
    end
    if (ns.me.count or 0) == 0 then
        ns.Print("you have no healthstone to hand over. Create one first.")
        return
    end
    if not InitiateTrade then return end
    want = { name = m.name, at = GetTime() }
    pcall(InitiateTrade, m.unit)
end
