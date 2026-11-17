-- Deposit Saver: tracks the auctions of your characters and your guild or group, and says
-- when one is worth buying back before it expires.
--
-- An auction that expires unsold loses its deposit. If someone in the group buys it instead,
-- the seller gets the deposit back and the group only loses the auction house cut (5% of the
-- price); the item and the gold stay in the group. So a buyback is worth it when the deposit
-- is bigger than the cut.
--
-- The game's owned-auction data (C_AuctionHouse.GetOwnedAuctions) has no deposit, so the
-- deposit is read when the auction is posted (C_AuctionHouse.CalculateItemDeposit /
-- CalculateCommodityDeposit at PostItem / PostCommodity) and kept with the auction. Auctions
-- posted without this addon get an estimate from the vendor price.
local ADDON, ns = ...

ns.VERSION = "1.1.2"
ns.TITLE = "Deposit Saver"
ns.ICON = "Interface\\Icons\\INV_Misc_Coin_02"

local DEFAULTS = {
    warn = true,          -- the centre-screen warning
    mailPanel = true,     -- the send-back list at the mailbox
    warnOwn = true,       -- also warn about my own auctions (someone else has to buy them)
    popup = true,         -- the "Find it" window with the warning
    sound = true,
    chatLine = true,      -- a line in chat with the item link
    warnMinutes = 15,     -- warn in the last N minutes
    repeatMinutes = 5,    -- and again every N minutes
    cutPct = 5,           -- the auction house cut
    minSaving = 0,        -- copper: smaller savings are not worth a warning
    shareGuild = true,
    shareGroup = true,
    panel = true,         -- the list next to the auction house
}
ns.DEFAULTS = DEFAULTS

-- Deposit as a share of the vendor price, per duration (1, 2, 3 = the sell frame's three
-- durations). Only used for auctions posted without this addon; every post the addon sees
-- replaces the guess with what the game really charged.
-- WoW Forever's AuctionHouse table (client 1.60.1.70938): DepositRate 5 at the faction houses
-- (25 at Blackwater), i.e. 5% of the vendor price for 12 hours, doubling with each longer duration.
-- Seen in game: 10s on an item that sells to a vendor for 2g. Real posts teach the exact rates.
local DEFAULT_RATES = { 0.05, 0.10, 0.20 }
local DEFAULT_HOURS = { 12, 24, 48 }
ns.DEFAULT_RATES, ns.DEFAULT_HOURS = DEFAULT_RATES, DEFAULT_HOURS

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Secret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end
ns.Secret = Secret

local function Num(v)
    if Secret(v) or type(v) ~= "number" or v ~= v then return nil end
    return v
end
ns.Num = Num

local function Str(v)
    if Secret(v) or type(v) ~= "string" then return nil end
    return v
end
ns.Str = Str

local function Get(t, k)
    if type(t) ~= "table" or Secret(t) then return nil end
    local ok, v = pcall(function() return t[k] end)
    if ok and not Secret(v) then return v end
    return nil
end
ns.Get = Get

function ns.Print(msg)
    local line = "|cffffd100Deposit Saver:|r " .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(line)
    else
        print(line)
    end
end

function ns.ServerNow()
    local ok, t = pcall(GetServerTime)
    t = ok and Num(t) or nil
    return t or time()
end

-- "First Last" the way the realm spells names (UnitName gives the surname as its second value).
function ns.Me()
    if ns.me then return ns.me end
    local ok, a, b = pcall(UnitName, "player")
    a, b = ok and Str(a) or nil, ok and Str(b) or nil
    if not a or a == "" then return "?" end
    ns.me = (b and b ~= "") and (a .. " " .. b) or a
    return ns.me
end

-- Copper as the game writes money: coin icons when the client has them.
function ns.Money(c)
    c = math.floor(math.max(Num(c) or 0, 0) + 0.5)
    if GetMoneyString then
        local ok, s = pcall(GetMoneyString, c, true)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    local g, s, k = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if k > 0 or #parts == 0 then parts[#parts + 1] = k .. "c" end
    return table.concat(parts, " ")
end

-- 12 min, 1 h 5 min, under a minute
function ns.TimeText(sec)
    sec = Num(sec) or 0
    if sec < 60 then return "under a minute" end
    local m = math.floor(sec / 60 + 0.5)
    if m < 60 then return m .. " min" end
    local h = math.floor(m / 60)
    m = m % 60
    if h >= 48 then return math.floor(h / 24 + 0.5) .. " days" end
    return m > 0 and (h .. " h " .. m .. " min") or (h .. " h")
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
-- DepositSaverDB (account-wide, so every character on this account sees the others' auctions):
--   settings (DEFAULTS), minimap = {hide, angle}
--   auctions[auctionID] = record (see Store below)
--   chars[name] = { seen = server time } for this account's characters
--   whisper = { "First Last", ... }: characters on other accounts (and friends) to share with
--   rates[duration] = deposit / vendor price, learned from posts
--   hours[duration] = how long that duration lasts, learned from the first read after a post
--   commLog = the last 40 messages in and out
function ns.InitDB()
    local db = type(DepositSaverDB) == "table" and DepositSaverDB or {}
    DepositSaverDB = db
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if type(db.minimap) ~= "table" then db.minimap = { hide = false } end
    for _, k in ipairs({ "auctions", "chars", "whisper", "rates", "hours", "commLog", "sendBack" }) do
        if type(db[k]) ~= "table" then db[k] = {} end
    end
    if (tonumber(db.depositFix) or 0) < 1 then
        db.rates = {}
        for _, rec in pairs(db.auctions) do
            if type(rec) == "table" and rec.src == "own" and (tonumber(rec.deposit) or 0) <= 0 then
                rec.deposit, rec.exact = nil, false
            end
        end
        db.depositFix = 1
    end
    for d, r in pairs(db.rates) do
        if type(r) ~= "number" or r <= 0 or r > 5 then db.rates[d] = nil end
    end
    local c = type(db.chars[ns.Me()]) == "table" and db.chars[ns.Me()] or {}
    c.seen = ns.ServerNow()
    db.chars[ns.Me()] = c
    ns.db = db
    return db
end

function ns.Set(key, value)
    if not ns.db then return end
    ns.db[key] = value
    ns.Changed()
end

function ns.Reset()
    for k, v in pairs(DEFAULTS) do ns.db[k] = v end
    ns.db.minimap = { hide = false }
    if ns.Kit and ns.Kit.RefreshMinimap then pcall(ns.Kit.RefreshMinimap) end
    ns.Changed()
end

-- One of this account's characters (its auctions come from the game, not from messages).
function ns.IsMine(owner)
    return owner ~= nil and ns.db ~= nil and ns.db.chars[owner] ~= nil
end

---------------------------------------------------------------------------
-- Listeners (the panel, the options window)
---------------------------------------------------------------------------
local listeners = {}
function ns.Listen(fn) listeners[#listeners + 1] = fn end
function ns.Changed()
    for _, fn in ipairs(listeners) do pcall(fn) end
end

---------------------------------------------------------------------------
-- The arithmetic
---------------------------------------------------------------------------
-- What the buyer pays: the buyout (or the bid when there is no buyout) for every unit.
function ns.Price(rec)
    local unit = Num(rec.unit)
    if not unit or unit <= 0 then return nil end
    return unit * math.max(Num(rec.qty) or 1, 1)
end

-- deposit, cut, saving, worth: worth is true when buying it back loses less than letting it expire.
function ns.Worth(rec)
    local price, deposit = ns.Price(rec), Num(rec.deposit)
    if not price or not deposit then return deposit, nil, nil, false end
    local pct = Num(ns.db and ns.db.cutPct) or 5
    local cut = math.floor(price * pct / 100 + 0.5)
    local saving = deposit - cut
    local floor = Num(ns.db and ns.db.minSaving) or 0
    return deposit, cut, saving, saving > 0 and saving >= floor
end

-- The cut on a price as a share of it, and the deposit as a share: "deposit 12% of the price".
function ns.DepositShare(rec)
    local price, deposit = ns.Price(rec), Num(rec.deposit)
    if not price or not deposit or price <= 0 then return nil end
    return deposit / price
end

function ns.Left(rec, now)
    local e = Num(rec.expires)
    if not e then return nil end
    return e - (now or ns.ServerNow())
end

local function VendorPrice(itemID)
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not get or not itemID then return nil end
    local ok, v = pcall(function() return select(11, get(itemID)) end)
    return ok and Num(v) or nil
end
ns.VendorPrice = VendorPrice

local function DurationGuess()
    local d
    if GetCVar then
        local ok, v = pcall(GetCVar, "auctionHouseDurationDropdown")
        d = ok and tonumber(v) or nil
    end
    if d ~= 1 and d ~= 2 and d ~= 3 then d = 2 end
    return d
end

-- The shortest duration that fits the time left, or the one the sell frame is set to.
function ns.DurationFor(rec, now)
    local d = DurationGuess()
    local left = ns.Left(rec, now or ns.ServerNow())
    if left then
        for dur = 1, 3 do
            if left <= ns.Hours(dur) * 3600 + 60 then
                if d < dur then d = dur end
                return d
            end
        end
        return 3
    end
    return d
end

-- How long the auction was listed for (1, 2, 3), and whether that is known or judged from the
-- time left. A judged one only ever goes up: with less time left a long auction would look short.
function ns.ListedDur(rec)
    if rec.dur then return rec.dur, true end
    local d = ns.DurationFor(rec)
    local g = Num(rec.durGuess)
    if g and g > d then d = g end
    return d, false
end

-- "24 hours", or "24 hours?" when judged from the time left
function ns.ListedText(rec)
    local d, known = ns.ListedDur(rec)
    return ("%d hours%s"):format(ns.Hours(d), known and "" or "?")
end

-- An estimate for an auction whose post the addon did not see.
function ns.EstimateDeposit(rec)
    local vendor = VendorPrice(rec.item)
    if not vendor then return nil end
    local dur = ns.ListedDur(rec)
    local rate = Num(ns.db.rates[dur]) or DEFAULT_RATES[dur] or DEFAULT_RATES[2]
    return math.floor(vendor * math.max(Num(rec.qty) or 1, 1) * rate + 0.5)
end

function ns.Hours(dur)
    return Num(ns.db and ns.db.hours[dur]) or DEFAULT_HOURS[dur] or 24
end

---------------------------------------------------------------------------
-- The store
---------------------------------------------------------------------------
-- record = { id, owner, item (itemID), ilvl, suffix, pet, qty, unit (copper per unit),
--   bidOnly, deposit, exact (deposit read from the game), expires (server time), approx
--   (time left only known roughly), seen (server time it was last confirmed), commodity,
--   dur, created, src ("own" for this account, "comm" from a message), link, from (sender) }
function ns.Records()
    local list, now = {}, ns.ServerNow()
    for _, rec in pairs(ns.db.auctions) do
        local left = ns.Left(rec, now)
        if not left or left > -60 then list[#list + 1] = rec end
    end
    table.sort(list, function(a, b)
        local la, lb = Num(a.expires) or math.huge, Num(b.expires) or math.huge
        if la ~= lb then return la < lb end
        return (Num(a.id) or 0) < (Num(b.id) or 0)
    end)
    return list
end

function ns.Forget(id, quiet)
    local rec = ns.db.auctions[id]
    if not rec then return end
    ns.db.auctions[id] = nil
    if not quiet then ns.Changed() end
    return rec
end

-- Drops auctions that ran out (an hour of grace for clocks that disagree).
function ns.Prune()
    local now, n = ns.ServerNow(), 0
    for id, rec in pairs(ns.db.auctions) do
        local left = ns.Left(rec, now)
        if (left and left < -3600) or (not left and (Num(rec.seen) or 0) < now - 3 * 86400) then
            ns.db.auctions[id] = nil
            n = n + 1
        end
    end
    if ns.Mail then ns.Mail.Prune(now) end
    return n
end

function ns.ItemName(rec)
    if Str(rec.link) then return rec.link end
    local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if get and rec.item then
        local ok, name, link = pcall(get, rec.item)
        if ok and Str(link) then return link end
        if ok and Str(name) then return name end
    end
    return "item " .. tostring(rec.item)
end

function ns.PlainName(rec)
    local s = ns.ItemName(rec)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", ""):gsub("|h", ""):gsub("^%[(.*)%]$", "%1"))
end

---------------------------------------------------------------------------
-- Posts: the deposit the game charged
---------------------------------------------------------------------------
local pending = {}   -- posts waiting for AUCTION_HOUSE_AUCTION_CREATED
ns.pending = pending

local function ItemFromLocation(loc)
    local id, link
    if C_Item and C_Item.GetItemID then
        local ok, v = pcall(C_Item.GetItemID, loc)
        id = ok and Num(v) or nil
    end
    if C_Item and C_Item.GetItemLink then
        local ok, v = pcall(C_Item.GetItemLink, loc)
        link = ok and Str(v) or nil
    end
    return id, link
end

local function SellFrameDeposit()
    local ah = AuctionHouseFrame
    if type(ah) ~= "table" then return nil end
    for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
        local f = ah[key]
        if type(f) == "table" and f.IsShown and f:IsShown() and f.GetDepositAmount then
            local ok, d = pcall(f.GetDepositAmount, f)
            if ok and Num(d) then return d end
        end
    end
    return nil
end

-- What the sell frame shows, kept from its last update: the hook on PostItem runs after the
-- item has left its bag slot, so the deposit can't be worked out again from the slot then.
ns.sellState = nil
function ns.CacheSellState(f)
    if type(f) ~= "table" or not f.GetItem then return end
    local ok, loc = pcall(f.GetItem, f)
    if not ok or not loc then return end
    local id, link = ItemFromLocation(loc)
    if not id then return end
    local okD, d = pcall(f.GetDepositAmount, f)
    local okT, dur = pcall(function() return f:GetDuration() end)
    local okQ, qty = pcall(function() return f:GetQuantity() end)
    ns.sellState = { item = id, link = link, deposit = okD and Num(d) or nil, dur = okT and Num(dur) or nil,
        qty = okQ and Num(qty) or nil, t = GetTime() }
end

-- Called (after the game's own call) for PostItem / ConfirmPostItem / PostCommodity / ConfirmPostCommodity.
function ns.CapturePost(kind, loc, duration, qty, a, b)
    local id, link = ItemFromLocation(loc)
    duration, qty = Num(duration), math.max(Num(qty) or 1, 1)
    local s = ns.sellState
    if s and GetTime() - s.t > 600 then s = nil end
    if s and ((id and s.item ~= id) or (s.dur and s.dur ~= duration) or (s.qty and s.qty ~= qty)) then s = nil end
    if not id and s then id, link = s.item, s.link end
    link = link or (s and s.link)
    if not id or not duration then return end
    local unit, bidOnly
    if kind == "commodity" then
        unit = Num(a)
    else
        -- PostItem(item, duration, quantity, bid, buyout): the price is per item
        unit = Num(b)
        if not unit or unit <= 0 then unit, bidOnly = Num(a), true end
    end
    local deposit = s and s.deposit and s.deposit > 0 and s.deposit or nil
    if deposit then
        -- the sell frame's number, read before the post
    elseif kind == "commodity" and C_AuctionHouse.CalculateCommodityDeposit then
        local ok, d = pcall(C_AuctionHouse.CalculateCommodityDeposit, id, duration, qty)
        deposit = ok and Num(d) or nil
    elseif C_AuctionHouse.CalculateItemDeposit then
        local ok, d = pcall(C_AuctionHouse.CalculateItemDeposit, loc, duration, qty)
        deposit = ok and Num(d) or nil
    end
    if not deposit or deposit <= 0 then deposit = SellFrameDeposit() end
    if deposit and deposit <= 0 then deposit = nil end
    local now = GetTime()
    -- A confirmation repeats the post it confirms: replace it.
    for i = #pending, 1, -1 do
        local p = pending[i]
        if p.item == id and p.unit == unit and p.post == qty and now - p.t < 30 then
            table.remove(pending, i)
        elseif now - p.t > 60 then
            table.remove(pending, i)
        end
    end
    local copies, each = 1, qty
    if kind ~= "commodity" and qty > 1 then copies, each = qty, 1 end   -- one auction per copy
    for i = 1, copies do
        local part = deposit
        if deposit and copies > 1 then
            part = math.floor(deposit / copies)
            if i == copies then part = deposit - part * (copies - 1) end
        end
        pending[#pending + 1] = { item = id, link = link, dur = duration, qty = each, unit = unit, bidOnly = bidOnly,
            deposit = part, commodity = kind == "commodity", t = now, post = qty }
    end
    -- learn the deposit rate for estimates
    local vendor = VendorPrice(id)
    if deposit and vendor and vendor > 0 then
        ns.db.rates[duration] = deposit / (vendor * qty)
    end
end

function ns.OnAuctionCreated(auctionID)
    auctionID = Num(auctionID)
    local p = table.remove(pending, 1)
    if not auctionID or not p then return end
    local now = ns.ServerNow()
    local rec = ns.db.auctions[auctionID] or {}
    rec.id, rec.owner, rec.src = auctionID, ns.Me(), "own"
    rec.item, rec.link, rec.qty, rec.unit, rec.bidOnly = p.item, p.link, p.qty, p.unit, p.bidOnly
    rec.commodity, rec.dur, rec.created, rec.seen = p.commodity, p.dur, now, now
    if p.deposit then
        rec.deposit, rec.exact = p.deposit, true
    else
        rec.deposit, rec.exact = ns.EstimateDeposit(rec), false
    end
    rec.expires, rec.approx = now + ns.Hours(p.dur) * 3600, true
    ns.db.auctions[auctionID] = rec
    ns.Changed()
    if ns.Comm then ns.Comm.ShareOwn() end
    ns.WantOwned(3)
end

---------------------------------------------------------------------------
-- Reading this character's auctions
---------------------------------------------------------------------------
local ACTIVE = Enum and Enum.AuctionStatus and Num(Enum.AuctionStatus.Active) or 0

local function BandMin(band)
    band = Num(band)
    if not band or not C_AuctionHouse.GetTimeLeftBandInfo then return nil end
    local ok, lo = pcall(C_AuctionHouse.GetTimeLeftBandInfo, band)
    return ok and Num(lo) or nil
end

local function OwnedList()
    if C_AuctionHouse.GetOwnedAuctions then
        local ok, list = pcall(C_AuctionHouse.GetOwnedAuctions)
        if ok and type(list) == "table" and not Secret(list) then return list end
    end
    local out = {}
    local okN, n = pcall(C_AuctionHouse.GetNumOwnedAuctions)
    for i = 1, (okN and Num(n) or 0) do
        local ok, a = pcall(C_AuctionHouse.GetOwnedAuctionInfo, i)
        if ok and type(a) == "table" then out[#out + 1] = a end
    end
    return out
end

function ns.ReadOwned()
    local me, now = ns.Me(), ns.ServerNow()
    local found, changed = {}, false
    for _, a in ipairs(OwnedList()) do
        local id = Num(Get(a, "auctionID"))
        local key = Get(a, "itemKey")
        local item = Num(Get(key, "itemID"))
        local status = Num(Get(a, "status"))
        if id and item and status == ACTIVE then
            found[id] = true
            local rec = ns.db.auctions[id]
            if not rec then
                rec = { id = id, created = nil }
                ns.db.auctions[id] = rec
            end
            local qty = math.max(Num(Get(a, "quantity")) or 1, 1)
            if rec.exact and Num(rec.created) and not rec.checked then
                -- matched to the wrong post (one the addon missed): the deposit isn't this auction's
                if (rec.item and rec.item ~= item) or (rec.qty and rec.qty ~= qty) then
                    rec.deposit, rec.exact, rec.dur = nil, false, nil
                end
            end
            rec.checked = true
            if Num(rec.deposit) and rec.qty and qty < rec.qty and rec.exact then
                -- part of it sold: that part's deposit came back
                rec.deposit = math.floor(rec.deposit * qty / rec.qty + 0.5)
            end
            rec.owner, rec.src, rec.item, rec.seen = me, "own", item, now
            rec.ilvl, rec.suffix, rec.pet = Num(Get(key, "itemLevel")), Num(Get(key, "itemSuffix")), Num(Get(key, "battlePetSpeciesID"))
            rec.link = Str(Get(a, "itemLink")) or rec.link
            rec.qty = qty
            local buyout, bid = Num(Get(a, "buyoutAmount")), Num(Get(a, "bidAmount"))
            if buyout and buyout > 0 then
                rec.unit, rec.bidOnly = buyout, nil
            elseif bid and bid > 0 then
                rec.unit, rec.bidOnly = bid, true
            end
            if rec.commodity == nil and C_AuctionHouse.GetItemCommodityStatus then
                -- 2 = commodity (Enum.ItemCommodityStatus); only known for items the client has
                local ok, s = pcall(C_AuctionHouse.GetItemCommodityStatus, item)
                if ok and Num(s) then rec.commodity = Num(s) == 2 end
            end
            local secs = Num(Get(a, "timeLeftSeconds"))
            if secs then
                -- learn how long the duration lasts from an auction posted moments ago
                if rec.dur and Num(rec.created) and now - rec.created < 300 then
                    local hours = math.floor((secs + now - rec.created) / 3600 + 0.5)
                    if hours >= 1 then ns.db.hours[rec.dur] = hours end
                end
                rec.expires, rec.approx = now + secs, nil
            else
                local lo = BandMin(Get(a, "timeLeft"))
                if lo and (not Num(rec.expires) or rec.expires < now + lo) then
                    -- the band says at least this long: never earlier than that
                    rec.expires, rec.approx = now + lo, true
                elseif not Num(rec.expires) then
                    rec.expires, rec.approx = nil, true
                end
            end
            if not rec.dur then rec.durGuess = (ns.ListedDur(rec)) end
            if not Num(rec.deposit) or (not rec.exact and Num(rec.deposit) <= 0) then
                rec.deposit, rec.exact = ns.EstimateDeposit(rec), false
            elseif not rec.exact then
                rec.deposit = ns.EstimateDeposit(rec) or rec.deposit   -- estimates follow what's learned
            end
            changed = true
        end
    end
    -- this character's auctions that are gone (sold, cancelled or expired)
    for id, rec in pairs(ns.db.auctions) do
        if rec.owner == me and not found[id] then
            ns.db.auctions[id] = nil
            changed = true
        end
    end
    ns.db.chars[me] = { seen = now, read = now }
    ns.ownedReadAt = GetTime()
    if changed then ns.Changed() end
    if ns.Comm then ns.Comm.ShareOwn() end
    return changed
end

-- Ask the game for this character's auctions (the Auctions tab asks too; we only read).
local wantAt
function ns.WantOwned(delay)
    wantAt = GetTime() + (delay or 0)
end

function ns.PollOwned()
    if not wantAt or GetTime() < wantAt or not ns.AuctionHouseOpen() then return end
    local okR, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
    if okR and ready == false then return end
    wantAt = nil
    if C_AuctionHouse.QueryOwnedAuctions then
        local sorts = { { sortOrder = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Name) or 1, reverseSort = false } }
        pcall(C_AuctionHouse.QueryOwnedAuctions, sorts)
    end
end

function ns.AuctionHouseOpen()
    return type(AuctionHouseFrame) == "table" and AuctionHouseFrame.IsShown ~= nil and AuctionHouseFrame:IsShown() == true
end

---------------------------------------------------------------------------
-- Things seen at the auction house that end an auction
---------------------------------------------------------------------------
function ns.OnPurchased(auctionID)
    auctionID = Num(auctionID)
    local rec = auctionID and ns.db.auctions[auctionID]
    if not rec then return end
    local back = ns.Mail and ns.Mail.Remember(rec)
    ns.Forget(auctionID)
    local _, _, saving = ns.Worth(rec)
    ns.Print(("Bought back %s%s. Its deposit stays in the group%s."):format(ns.ItemName(rec),
        rec.owner and (" from " .. rec.owner) or "", saving and saving > 0 and (" (saved " .. ns.Money(saving) .. ")") or ""))
    if back then
        ns.Print(("At a mailbox, the send-back list fills in a mail to %s with Cash on Delivery %s, so you get your gold back."):format(
            back.seller, ns.Money(back.price)))
    end
    if ns.Comm then ns.Comm.Gone(auctionID) end
end

-- Search results for an item: refresh the time left of tracked auctions, and drop a tracked
-- auction that a full search of exactly its item no longer shows.
function ns.OnSearchResults(itemKey)
    local item = Num(Get(itemKey, "itemID"))
    if not item then return end
    local recs = {}
    for _, rec in pairs(ns.db.auctions) do
        if rec.item == item and not rec.commodity and rec.owner ~= ns.Me() then recs[#recs + 1] = rec end
    end
    if #recs == 0 then return end
    local okN, n = pcall(C_AuctionHouse.GetNumItemSearchResults, itemKey)
    n = okN and Num(n) or 0
    local seen, now = {}, ns.ServerNow()
    for i = 1, n do
        local ok, r = pcall(C_AuctionHouse.GetItemSearchResultInfo, itemKey, i)
        local id = ok and Num(Get(r, "auctionID")) or nil
        if id then
            seen[id] = true
            local rec = ns.db.auctions[id]
            local secs = Num(Get(r, "timeLeftSeconds"))
            if rec and secs then rec.expires, rec.approx, rec.seen = now + secs, nil, now end
        end
    end
    local okF, full = pcall(C_AuctionHouse.HasFullItemSearchResults, itemKey)
    if okF and full == true then
        local ilvl, suffix = Num(Get(itemKey, "itemLevel")), Num(Get(itemKey, "itemSuffix"))
        for _, rec in ipairs(recs) do
            local sameKey = (rec.ilvl == nil or ilvl == nil or rec.ilvl == ilvl) and (Num(rec.suffix) or 0) == (suffix or 0)
            if sameKey and not seen[rec.id] and now - (Num(rec.seen) or 0) > 120 then
                ns.db.auctions[rec.id] = nil
            end
        end
    end
    ns.Changed()
end

---------------------------------------------------------------------------
-- Finding an auction at the auction house
---------------------------------------------------------------------------
ns.pendingFind = nil

local function NameSearch(name)
    local ah = AuctionHouseFrame
    if ah.SetDisplayMode and AuctionHouseFrameDisplayMode then
        ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
    end
    ah.SearchBar.SearchBox:SetText(name)
    ah.SearchBar:StartSearch()
end

local function KeyOf(rec)
    return { itemID = rec.item, itemLevel = rec.ilvl or 0, itemSuffix = rec.suffix or 0, battlePetSpeciesID = rec.pet or 0 }
end
ns.KeyOf = KeyOf

-- Shows the item's listings (or searches its name), then says which one to buy.
function ns.Find(id)
    local rec = id and ns.db.auctions[id]
    if not rec then
        ns.Print("That auction is no longer tracked (sold, bought back or expired).")
        return false
    end
    local price = ns.Price(rec)
    local what = ("%s from %s for %s%s"):format(ns.ItemName(rec), rec.owner or "?", price and ns.Money(price) or "?",
        rec.bidOnly and " (bid, no buyout)" or "")
    if not ns.AuctionHouseOpen() then
        ns.pendingFind = id
        ns.Print("Open the auction house and it will look for " .. what .. ".")
        return false
    end
    ns.pendingFind = nil
    local shown = false
    if not rec.commodity and AuctionHouseFrame.SelectBrowseResult and C_AuctionHouse.GetItemKeyInfo then
        local key = KeyOf(rec)
        local okI, info = pcall(C_AuctionHouse.GetItemKeyInfo, key)
        if okI and type(info) == "table" then
            shown = pcall(AuctionHouseFrame.SelectBrowseResult, AuctionHouseFrame, { itemKey = key, minPrice = rec.unit })
        end
    end
    if not shown then
        shown = pcall(NameSearch, ns.PlainName(rec))
    end
    if not shown then
        ns.Print("Could not search the auction house. Look for " .. what .. " by hand.")
        return false
    end
    local left = ns.Left(rec)
    ns.Print(("Buy %s%s.%s"):format(what, left and (", " .. ns.TimeText(left) .. " left") or "",
        rec.commodity and " It sells by unit, so it only works if theirs is the cheapest." or ""))
    return true
end

---------------------------------------------------------------------------
-- Hooks
---------------------------------------------------------------------------
local hookedPosts, hookedFrame = false, false
function ns.HookPosts()
    if hookedPosts or type(C_AuctionHouse) ~= "table" or not hooksecurefunc then return end
    hookedPosts = true
    local function hook(name, kind)
        if C_AuctionHouse[name] then
            hooksecurefunc(C_AuctionHouse, name, function(...)
                local ok, err = pcall(ns.CapturePost, kind, ...)
                if not ok then ns.lastError = err end
            end)
        end
    end
    hook("PostItem", "item")
    hook("ConfirmPostItem", "item")
    hook("PostCommodity", "commodity")
    hook("ConfirmPostCommodity", "commodity")
end

function ns.HookFrame()
    if hookedFrame or type(AuctionHouseFrame) ~= "table" then return end
    hookedFrame = true
    if ns.UI then pcall(ns.UI.Attach) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local frame = CreateFrame("Frame")
ns.frame = frame
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
    "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_CANCELED", "AUCTION_HOUSE_PURCHASE_COMPLETED",
    "ITEM_SEARCH_RESULTS_UPDATED", "GET_ITEM_INFO_RECEIVED", "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE",
    "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "BAG_UPDATE_DELAYED" }) do
    pcall(frame.RegisterEvent, frame, e)
end

local function HasKit() return ns.Kit ~= nil and ns.Options ~= nil end
ns.HasKit = HasKit

local function OnLogin()
    ns.InitDB()
    ns.Prune()
    ns.HookPosts()
    if type(AuctionHouseFrame) == "table" then ns.HookFrame() end
    if HasKit() then
        local ok, err = pcall(ns.Options.Init)
        if not ok then ns.Print("options error: " .. tostring(err)) end
    end
    if ns.Comm then ns.Comm.Start() end
    if ns.Alert then ns.Alert.Start() end
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(1, function() pcall(ns.PollOwned) end)
    end
end

frame:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "ADDON_LOADED" then
        if a1 == "Blizzard_AuctionHouseUI" and ns.db then ns.HookFrame() end
        return
    elseif event == "PLAYER_LOGIN" then
        local ok, err = pcall(OnLogin)
        if not ok then ns.Print("could not start: " .. tostring(err)) end
        return
    end
    if not ns.db then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if ns.Alert then pcall(ns.Alert.Check) end
    elseif event == "AUCTION_HOUSE_SHOW" then
        ns.HookFrame()
        ns.WantOwned(2)
        if C_Timer then
            -- the auction window can be built after this event
            C_Timer.After(1.5, function()
                ns.HookFrame()
                if ns.UI then pcall(ns.UI.Refresh) end
                if ns.pendingFind and ns.AuctionHouseOpen() then pcall(ns.Find, ns.pendingFind) end
            end)
        end
        ns.Changed()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ns.Changed()
    elseif event == "OWNED_AUCTIONS_UPDATED" then
        local ok, err = pcall(ns.ReadOwned)
        if not ok then ns.lastError = err end
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        pcall(ns.OnAuctionCreated, a1)
    elseif event == "AUCTION_CANCELED" then
        local id = Num(a1)
        if id and ns.db.auctions[id] then
            ns.Forget(id)
            if ns.Comm then ns.Comm.Gone(id) end
        end
        ns.WantOwned(2)
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        pcall(ns.OnPurchased, a1)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        pcall(ns.OnSearchResults, a1)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if ns.UI and ns.UI.Visible() then pcall(ns.UI.Refresh) end
    elseif event == "CHAT_MSG_ADDON" then
        if ns.Comm then pcall(ns.Comm.OnMessage, a1, a2, a3, a4) end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if ns.Comm then pcall(ns.Comm.OnRoster) end
    elseif event:sub(1, 5) == "MAIL_" or event == "BAG_UPDATE_DELAYED" then
        if ns.Mail and (event ~= "BAG_UPDATE_DELAYED" or ns.Mail.MailOpen()) then
            local ok, err = pcall(ns.Mail.OnEvent, event)
            if not ok then ns.lastError = err end
        end
    end
end)

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function Line(rec, now)
    local deposit, cut, saving, worth = ns.Worth(rec)
    local left = ns.Left(rec, now)
    local verdict
    if not cut then
        verdict = "no price known"
    elseif worth then
        verdict = "|cff20ff20buy back, saves " .. ns.Money(saving) .. "|r"
    else
        verdict = "|cff808080let it expire: the cut " .. ns.Money(cut) .. " is more than the deposit " .. ns.Money(deposit or 0) .. "|r"
    end
    return ("%s - %s, listed %s, %s%s left, deposit %s%s: %s"):format(rec.owner or "?", ns.ItemName(rec),
        ns.ListedText(rec), rec.approx and "about " or "", left and ns.TimeText(math.max(left, 0)) or "?",
        deposit and ns.Money(deposit) or "?", rec.exact and "" or " (estimate)", verdict)
end
ns.Line = Line

local function Slash(msg)
    msg = type(msg) == "string" and msg or ""
    local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if not ns.db then
        ns.Print("not started yet.")
        return
    end
    if cmd == "" or cmd == "options" or cmd == "config" then
        if HasKit() and ns.Options.Ready() then
            ns.Kit.Toggle()
        else
            ns.Print("The options window loads after a /reload. Until then: /deposits list, status, test, sync, add, remove, panel, mail.")
        end
    elseif cmd == "mail" then
        if ns.Mail then ns.Mail.Slash() else ns.Print("The send-back list loads after a /reload.") end
    elseif cmd == "list" then
        local list, now = ns.Records(), ns.ServerNow()
        if #list == 0 then
            ns.Print("No auctions tracked. Open the auction house on each character, and the guild's or group's come in by themselves.")
        else
            ns.Print(#list .. " auctions tracked, soonest first:")
            for _, rec in ipairs(list) do ns.Print(Line(rec, now)) end
        end
    elseif cmd == "status" then
        local n, worth = 0, 0
        for _, rec in ipairs(ns.Records()) do
            n = n + 1
            if select(4, ns.Worth(rec)) then worth = worth + 1 end
        end
        ns.Print(("%d auctions tracked, %d worth buying back. Cut %s%%. Warnings %s."):format(n, worth, tostring(ns.db.cutPct),
            ns.db.warn and ("on, last " .. ns.db.warnMinutes .. " min, every " .. ns.db.repeatMinutes .. " min") or "off"))
        if ns.Comm then
            for _, l in ipairs(ns.Comm.StatusLines()) do ns.Print(l) end
        end
    elseif cmd == "test" then
        if ns.Alert then ns.Alert.Test() end
    elseif cmd == "sync" then
        if ns.Comm then
            ns.Comm.Request()
            ns.Comm.ShareOwn(true)
            ns.Print("Asked the guild, group and listed characters for their auctions, and sent yours.")
        end
    elseif cmd == "add" or cmd == "remove" then
        local name = rest ~= "" and rest or nil
        if not name then
            ns.Print("Give a character name: /deposits " .. cmd .. " First Last")
        elseif ns.Comm then
            if cmd == "add" then ns.Comm.AddWhisper(name) else ns.Comm.RemoveWhisper(name) end
        end
    elseif cmd == "who" then
        local list = ns.db.whisper
        ns.Print(#list == 0 and "No characters listed. /deposits add First Last adds one (an alt on another account, a friend)."
            or ("Also shared with: " .. table.concat(list, ", ")))
    elseif cmd == "panel" then
        ns.Set("panel", not ns.db.panel)
        ns.Print(ns.db.panel and "The buyback list shows next to the auction house." or "The buyback list is hidden. /deposits panel brings it back.")
        if HasKit() and ns.Options.Ready() then pcall(ns.Kit.Sync) end
    elseif cmd == "rates" then
        ns.Print("Deposit per listing time, as a share of the vendor price:")
        for d = 1, 3 do
            local learned = Num(ns.db.rates[d])
            ns.Print(("%d hours: %s%% (%s)"):format(ns.Hours(d), tostring(math.floor((learned or DEFAULT_RATES[d]) * 1000 + 0.5) / 10),
                learned and "learned from your last post" or "the game's table; your next post teaches the real one"))
        end
    elseif cmd == "clear" then
        local n = 0
        for id, rec in pairs(ns.db.auctions) do
            if not ns.IsMine(rec.owner) then ns.db.auctions[id] = nil; n = n + 1 end
        end
        ns.Changed()
        ns.Print(n .. " auctions of other players forgotten. They come back when their owners share again.")
    else
        ns.Print("/deposits: options. list: every tracked auction. status. test: a sample warning. sync: ask everyone again. "
            .. "add / remove First Last: share with a character on another account. who. panel: the list at the auction house. mail: bought-back items to mail back. rates: deposit per listing time. clear.")
    end
end
ns.Slash = Slash

SLASH_DEPOSITSAVER1 = "/deposits"
SLASH_DEPOSITSAVER2 = "/depositsaver"
SlashCmdList["DEPOSITSAVER"] = function(msg)
    local ok, err = pcall(Slash, msg)
    if not ok then ns.Print("error: " .. tostring(err)) end
end
