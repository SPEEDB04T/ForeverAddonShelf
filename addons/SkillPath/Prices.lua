-- SkillPath: what reagents cost. Four sources, each named wherever its number is used:
--   * your bags (and bank): free;
--   * the auction house: every listing a scan read, cheapest first (item auctions are whole
--     lots, commodities are per unit), with the time of the scan;
--   * a vendor: the price a merchant showed you (unlimited stock only), or until you have seen
--     one, the item's own vendor price for the trade-supply reagents Data.lua lists;
--   * nothing: the guide says so instead of guessing.
-- The auction scan is one query at a time, only when the game's throttle says it is ready,
-- and it backs off while another addon (Slutmog Scout, Slutmog Shop) is searching.
local _, ns = ...
local P = {}
ns.Prices = P

local Call, Num, Str, Field = ns.Call, ns.Num, ns.Str, ns.Field

local LOT_CAP = 600          -- the lot-buying table covers this many units (more than any guide needs of one reagent)
local FOREIGN_QUIET = 3      -- seconds without another addon's results before the next query
local QUERY_TIMEOUT = 10
local START_DELAY = 5        -- after the auction house opens, so its own first search and other addons' go first
local FRESH_SKIP = 1800      -- an automatic scan skips prices younger than this

----------------------------------------------------------------------
-- Where prices live
----------------------------------------------------------------------
function P.RealmKey()
    local realm = Str(Call(GetRealmName)) or "realm"
    local faction = Str(Call(UnitFactionGroup, "player")) or "all"
    return realm .. "-" .. faction
end

local function AHStore()
    local key = P.RealmKey()
    local store = ns.db.ah[key]
    if type(store) ~= "table" then
        store = {}
        ns.db.ah[key] = store
    end
    return store
end
P.AHStore = AHStore

function P.ItemName(item)
    local name = Str(Call(C_Item and C_Item.GetItemInfo, item))
    if name then return name end
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
    return "item " .. tostring(item)
end

function P.ItemIcon(item)
    if C_Item and C_Item.GetItemIconByID then
        local icon = Call(C_Item.GetItemIconByID, item)
        if icon then return icon end
    end
    local packed = ns.CallAll(C_Item and C_Item.GetItemInfoInstant, item)
    return packed[5]
end

-- 1 = binds when picked up: it can't be bought.
local function BindType(item)
    local packed = ns.CallAll(C_Item and C_Item.GetItemInfo, item)
    return Num(packed[14])
end

function P.Count(item)
    local bank = ns.db.useBank and true or false
    if C_Item and C_Item.GetItemCount then
        local n = Num(Call(C_Item.GetItemCount, item, bank, false, bank, bank))
        if n then return n end
    end
    return Num(Call(GetItemCount, item, bank)) or 0
end

function P.Vendor(item)
    local seen = ns.db.vendor[item]
    if type(seen) == "table" and Num(seen.p) and Num(seen.q) and seen.q > 0 then
        return seen.p / seen.q, "vendor", seen.t
    end
    local data = ns.Data and ns.Data.VENDOR[item]
    if data then return data[1] / data[2], "item data" end
end

----------------------------------------------------------------------
-- Supply: what getting x more units of an item costs, past the free ones
----------------------------------------------------------------------
local cache = {}
local bare = {}
local resale = {}
function P.Invalidate() cache, bare, resale = {}, {}, {} end

local function Prefix(segs)
    local U, K = {}, {}
    local u, k = 0, 0
    for i, s in ipairs(segs) do
        u = u + s.q
        k = k + s.u * s.q
        U[i], K[i] = u, k
    end
    return U, K
end

function P.Supply(item)
    local sup = cache[item]
    if sup then return sup end
    sup = { item = item, have = P.Count(item), memo = {} }
    local v, from, seenAt = P.Vendor(item)
    sup.vendor, sup.vendorFrom, sup.vendorAt = v, from, seenAt
    local rec = AHStore()[item]
    if type(rec) == "table" and type(rec.l) == "table" and Num(rec.t) then
        sup.ah = rec
        sup.age = ns.Clock() - rec.t
        sup.stale = sup.age > (Num(ns.db.staleHours) or 3) * 3600
    end
    sup.bound = BindType(item) == 1
    -- Listings that beat the vendor, split into per-unit commodities and whole lots.
    local units, lots = {}, {}
    if sup.ah and not sup.bound then
        for _, e in ipairs(sup.ah.l) do
            local unit, qty = Num(e[1]), Num(e[2])
            if unit and qty and qty > 0 and (not v or unit < v) then
                if e[3] then
                    lots[#lots + 1] = { u = unit, q = qty, b = Num(e[4]) or unit * qty }
                else
                    units[#units + 1] = { u = unit, q = qty }
                end
            end
        end
    end
    table.sort(units, function(a, b) return a.u < b.u end)
    sup.units, sup.lots = units, lots
    sup.U, sup.K = Prefix(units)
    sup.listed = (sup.U[#sup.U] or 0)
    for _, lot in ipairs(lots) do sup.listed = sup.listed + lot.q end
    if #lots > 0 then
        -- The cheapest way to get at least x units out of whole lots alone (0/1 cover).
        local cap = 0
        for _, lot in ipairs(lots) do cap = cap + lot.q end
        cap = math.min(cap, LOT_CAP)
        local best = { [0] = 0 }
        for x = 1, cap do best[x] = math.huge end
        for _, lot in ipairs(lots) do
            for x = cap, 1, -1 do
                local from = x - lot.q
                if from < 0 then from = 0 end
                local c = best[from] + lot.b
                if c < best[x] then best[x] = c end
            end
        end
        sup.lotBest, sup.lotCap = best, cap
    end
    sup.priced = sup.vendor ~= nil or sup.listed > 0
    cache[item] = sup
    return sup
end

-- The same supply for someone who holds nothing (a path made for another player).
function P.Bare(item)
    local b = bare[item]
    if b then return b end
    local sup = P.Supply(item)
    b = setmetatable({ have = 0 }, { __index = sup })
    bare[item] = b
    return b
end

-- Cost of k units from commodities (cheapest first) and then the vendor; nil if there aren't k.
local function Divisible(sup, k)
    if k <= 0 then return 0 end
    local U, K, segs = sup.U, sup.K, sup.units
    local n = #segs
    if n == 0 or k > U[n] then
        if not sup.vendor then return nil end
        return (K[n] or 0) + sup.vendor * (k - (U[n] or 0))
    end
    local lo, hi = 1, n
    while lo < hi do
        local mid = math.floor((lo + hi) / 2)
        if U[mid] >= k then hi = mid else lo = mid + 1 end
    end
    return (K[lo - 1] or 0) + segs[lo].u * (k - (U[lo - 1] or 0))
end

-- Cost of a whole number x of units bought (not counting free ones); nil if they can't be had.
local function Whole(sup, x)
    if x <= 0 then return 0 end
    local memo = sup.memo[x]
    if memo ~= nil then return memo or nil end
    local best
    if sup.lotBest then
        for j = 0, math.min(x, sup.lotCap) do
            local fromLots = sup.lotBest[j]
            if fromLots < math.huge then
                local rest = Divisible(sup, x - j)
                if rest and (not best or fromLots + rest < best) then best = fromLots + rest end
            end
        end
    else
        best = Divisible(sup, x)
    end
    sup.memo[x] = best or false
    return best
end

-- Cost of x units bought, x may be fractional (an expected count): between the whole numbers.
function P.Cost(sup, x)
    if x <= 1e-9 then return 0 end
    local low = math.floor(x)
    local frac = x - low
    local a = Whole(sup, low)
    if frac < 1e-9 then return a end
    local b = Whole(sup, low + 1)
    if not (a and b) then return nil end
    return a + (b - a) * frac
end

-- What k more units cost when `used` units have already gone into earlier steps and `extra`
-- more are on hand from earlier crafts. nil: no price (or not enough listed).
function P.Marginal(sup, used, k, extra)
    local free = sup.have + (extra or 0)
    local before = used - free
    local after = used + k - free
    if after <= 1e-9 then return 0 end
    local a = P.Cost(sup, math.max(0, before))
    local b = P.Cost(sup, after)
    if not (a and b) then return nil end
    return b - a
end

-- Why an item has no price, in words.
function P.Missing(sup)
    if sup.bound then return "binds when picked up" end
    if sup.ah and sup.listed == 0 then
        return ("none listed at the last scan (%s)"):format(ns.Age(sup.age))
    end
    if sup.ah then
        return ("only %d listed at the last scan (%s)"):format(sup.listed, ns.Age(sup.age))
    end
    return "not scanned yet"
end

----------------------------------------------------------------------
-- Vendors: the price a merchant actually shows (with any discount)
----------------------------------------------------------------------
-- The reagents of the saved professions, and of the profession a path for someone else is for.
-- With outputs, also what the recipes make that the path could use: the ones you know, and the
-- ones that still give skill from where the path starts (scanned only when auction house sales
-- are counted).
function P.Interest(outputs)
    local set = {}
    local char = ns.Char()
    local order = ns.Order and ns.Order()
    local function Add(recipes, from)
        for _, r in ipairs(recipes or {}) do
            for _, slot in ipairs(r.slots or {}) do
                for _, item in ipairs(slot.items) do set[item] = true end
            end
            if r.item then set[r.item] = true end
            if outputs and r.out and (r.known or (r.g and r.g > from)) then set[r.out] = true end
        end
    end
    for _, prof in pairs(char and char.profs or {}) do Add(prof.recipes, prof.skill or 0) end
    if order then Add(ns.Recipes.ForOrder(order.line), order.from) end
    return set
end

local function Watched()
    return P.Interest(ns.db.sellAH)
end

local function MerchantItem(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = Call(C_MerchantFrame.GetItemInfo, i)
        if type(info) == "table" then
            return Num(Field(info, "price")), Num(Field(info, "stackCount")), Num(Field(info, "numAvailable")),
                Field(info, "hasExtendedCost") == true
        end
    end
    local packed = ns.CallAll(GetMerchantItemInfo, i)
    return Num(packed[3]), Num(packed[4]), Num(packed[5]), packed[8] == true
end

-- Records every reagent this merchant sells without limit. Returns how many.
function P.ReadMerchant()
    local n = Num(Call(GetMerchantNumItems)) or 0
    if n == 0 then return 0 end
    local interest = P.Interest()
    local got = 0
    for i = 1, n do
        local id = Num(Call(GetMerchantItemID, i))
        if id and (interest[id] or (ns.Data and ns.Data.VENDOR[id])) then
            local price, qty, available, extended = MerchantItem(i)
            if price and price > 0 and qty and qty > 0 and available == -1 and not extended then
                ns.db.vendor[id] = { p = price, q = qty, t = ns.Clock() }
                got = got + 1
            end
        end
    end
    return got
end

----------------------------------------------------------------------
-- The auction scan
----------------------------------------------------------------------
local AH = function() return C_AuctionHouse end
local scan = { queue = {}, open = false, active = false, pending = nil, lastForeign = -100, own = {}, tries = {},
    done = 0, total = 0, failed = 0, pumpQueued = false }
P.scanState = scan

function P.CanScan()
    local ah = AH()
    return type(ah) == "table" and type(ah.SendSearchQuery) == "function" and type(ah.MakeItemKey) == "function"
end

function P.IsOpen() return scan.open end
function P.IsScanning() return scan.active end
function P.Progress() return scan.done, scan.total end

-- The items a scan asks for: reagents of the saved professions that a vendor doesn't sell and
-- that can be bought. An automatic scan skips prices younger than half an hour.
-- What to search for, the reagents of the path on screen first. all (a scan you asked for):
-- prices read a moment ago and what a vendor sells too (an auction can be under the vendor).
function P.ScanList(all)
    local store = AHStore()
    local now = ns.Clock()
    local list = {}
    for item in pairs(Watched()) do
        local vendor = P.Vendor(item)
        local rec = store[item]
        local fresh = type(rec) == "table" and Num(rec.t) and now - rec.t < FRESH_SKIP
        if BindType(item) ~= 1 and (all or not (vendor or fresh)) then list[#list + 1] = item end
    end
    local plan = ns.Plan and ns.Plan()
    local used = plan and plan.ok and plan.used or {}
    table.sort(list, function(a, b)
        local ua, ub = used[a] ~= nil, used[b] ~= nil
        if ua ~= ub then return ua end
        return a < b
    end)
    return list
end

local function Pump()
    if scan.pumpQueued then return end
    scan.pumpQueued = true
    ns.After(0.3, function()
        scan.pumpQueued = false
        P.Next()
    end)
end

local function Finish()
    local wasActive = scan.active
    scan.active = false
    scan.pending = nil
    if wasActive then
        local failed = scan.failed > 0 and (" (%d didn't answer)"):format(scan.failed) or ""
        ns.Print(("Read %d auction %s%s."):format(scan.done, scan.done == 1 and "price" or "prices", failed))
    end
    ns.Changed()
end

function P.StartScan(manual)
    if not P.CanScan() then
        if manual then ns.Print("This client has no auction house search for addons.") end
        return false
    end
    if not scan.open then
        if manual then ns.Print("Open the auction house first.") end
        return false
    end
    if scan.active then
        if manual then ns.Print(("Already scanning: %d of %d done."):format(scan.done, scan.total)) end
        return false
    end
    scan.queue = P.ScanList(manual)
    scan.done, scan.failed, scan.total, scan.tries = 0, 0, #scan.queue, {}
    if #scan.queue == 0 then
        if manual then ns.Print("Nothing to scan: no profession read yet, or vendors sell every reagent.") end
        return false
    end
    scan.active = true
    if manual then ns.Print(("Reading %d auction %s."):format(#scan.queue, #scan.queue == 1 and "price" or "prices")) end
    ns.Changed()
    Pump()
    return true
end

-- Sends the next query when it is our turn.
function P.Next()
    if not (scan.active and scan.open) or scan.pending then return end
    local ah = AH()
    if #scan.queue == 0 then return Finish() end
    local now = ns.Now()
    -- Another addon's search just answered: let it finish its run first.
    if now - scan.lastForeign < FOREIGN_QUIET then
        ns.After(1, Pump)
        return
    end
    if type(ah.IsThrottledMessageSystemReady) == "function" then
        local ok, ready = pcall(ah.IsThrottledMessageSystemReady)
        if not ok or not ns.Val(ready) then
            ns.After(1, Pump)     -- AUCTION_HOUSE_THROTTLED_SYSTEM_READY usually comes first
            return
        end
    end
    local item = scan.queue[1]
    -- The search needs the item's data in the client.
    if not Str(Call(C_Item and C_Item.GetItemInfo, item)) then
        scan.tries[item] = (scan.tries[item] or 0) + 1
        table.remove(scan.queue, 1)
        if scan.tries[item] <= 3 then
            if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
            scan.queue[#scan.queue + 1] = item
        else
            scan.failed = scan.failed + 1
        end
        ns.After(0.5, Pump)
        return
    end
    local key = Call(ah.MakeItemKey, item)
    if not key then
        table.remove(scan.queue, 1)
        scan.failed = scan.failed + 1
        Pump()
        return
    end
    local order = Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price or 0
    local sent = pcall(ah.SendSearchQuery, key, { { sortOrder = order, reverseSort = false } }, false)
    table.remove(scan.queue, 1)
    if not sent then
        scan.failed = scan.failed + 1
        Pump()
        return
    end
    scan.own[item] = now
    local pending = { item = item, key = key, at = now }
    scan.pending = pending
    ns.After(QUERY_TIMEOUT, function()
        if scan.pending == pending then
            scan.pending = nil
            scan.failed = scan.failed + 1
            Pump()
        end
    end)
end

-- Reads what the game holds for one item's search.
local function ReadCommodity(item)
    local ah = AH()
    local n = Num(Call(ah.GetNumCommoditySearchResults, item)) or 0
    local list = {}
    for i = 1, n do
        local info = Call(ah.GetCommoditySearchResultInfo, item, i)
        local unit = Num(Field(info, "unitPrice"))
        local qty = Num(Field(info, "quantity"))
        if unit and qty then
            qty = qty - (Num(Field(info, "numOwnerItems")) or 0)     -- your own auctions aren't for sale to you
            if qty > 0 then list[#list + 1] = { unit, qty } end
        end
    end
    local full = Call(ah.HasFullCommoditySearchResults, item)
    return list, full == false
end

local function ReadItems(key)
    local ah = AH()
    local n = Num(Call(ah.GetNumItemSearchResults, key)) or 0
    local list = {}
    for i = 1, n do
        local info = Call(ah.GetItemSearchResultInfo, key, i)
        local buy = Num(Field(info, "buyoutAmount"))
        local qty = Num(Field(info, "quantity"))
        if buy and qty and qty > 0 and not Field(info, "containsOwnerItem") then
            list[#list + 1] = { buy / qty, qty, 1, buy }
        end
    end
    local full = Call(ah.HasFullItemSearchResults, key)
    return list, full == false
end

----------------------------------------------------------------------
-- Sales: the auction house never says what sold, only what is listed. Between two scans of an
-- item, the units that are no longer listed were bought, or cancelled, or ran out; that count,
-- over the hours between the scans, is the most it can have sold. Kept for a week.
----------------------------------------------------------------------
local OBS_MAX_GAP = 48 * 3600        -- longer than the longest auction: everything could have run out
local OBS_KEEP = 7 * 86400
local DEMAND_MIN_HOURS = 4           -- less watching than this isn't enough to say how fast it sells
local MAX_LISTINGS = 80

-- Units listed in `old` that aren't in `new`. Commodities are compared price by price, item
-- auctions lot by lot. When a list was cut short, only prices both lists cover are compared.
-- Two things that aren't sales are taken off:
--   * buyers take the cheapest first, so nothing dearer than the cheapest price that still has
--     units from before can have sold: what left above it was cancelled or ran out;
--   * units that now sit below the old cheapest price are most likely the same ones, listed
--     again lower.
local function Gone(old, new, cutOld, cutNew)
    local top = math.huge
    if cutOld and old[#old] then top = math.min(top, old[#old][1]) end
    if cutNew and new[#new] then top = math.min(top, new[#new][1]) end
    local function Key(e) return e[3] and (e[1] .. ":" .. e[2] .. ":" .. tostring(e[4])) or tostring(e[1]) end
    local now, lowest = {}, math.huge
    for _, e in ipairs(old) do
        if e[1] < lowest then lowest = e[1] end
    end
    local relisted = 0
    for _, e in ipairs(new) do
        if e[1] < top then
            local k = Key(e)
            now[k] = (now[k] or 0) + (e[3] and 1 or e[2])
            if e[1] < lowest then relisted = relisted + e[2] end
        end
    end
    local before, levels = {}, {}
    for _, e in ipairs(old) do
        if e[1] < top then
            local k = Key(e)
            if not before[k] then
                before[k] = { n = 0, per = e[3] and e[2] or 1, price = e[1] }
                levels[#levels + 1] = k
            end
            before[k].n = before[k].n + (e[3] and 1 or e[2])
        end
    end
    table.sort(levels, function(a, b)
        if before[a].price ~= before[b].price then return before[a].price < before[b].price end
        return a < b
    end)
    local gone = 0
    for _, k in ipairs(levels) do
        local b = before[k]
        local stay = math.min(b.n, now[k] or 0)
        gone = gone + (b.n - stay) * b.per
        if stay > 0 then break end
    end
    return math.max(0, gone - relisted)
end
P.Gone = Gone

local function Record(item, list, partial)
    table.sort(list, function(a, b) return a[1] < b[1] end)
    local cut = #list > MAX_LISTINGS
    while #list > MAX_LISTINGS do table.remove(list) end
    local now = ns.Clock()
    local store = AHStore()
    local prev = store[item]
    local obs = {}
    if type(prev) == "table" then
        for _, o in ipairs(type(prev.obs) == "table" and prev.obs or {}) do
            if Num(o.t) and now - o.t <= OBS_KEEP then obs[#obs + 1] = o end
        end
        local gap = Num(prev.t) and now - prev.t
        if gap and gap > 0 and gap <= OBS_MAX_GAP and not partial and not prev.partial and type(prev.l) == "table" then
            obs[#obs + 1] = { t = now, gone = Gone(prev.l, list, prev.cut, cut), dt = gap }
        end
    end
    store[item] = { t = now, l = list, partial = partial or nil, cut = cut or nil, obs = #obs > 0 and obs or nil }
end
P.Record = Record


-- At most how many units of an item left the auction house per day, and over how many hours
-- and scans that was seen. nil until it has been watched for DEMAND_MIN_HOURS.
function P.Demand(item)
    local rec = AHStore()[item]
    if type(rec) ~= "table" or type(rec.obs) ~= "table" then return nil end
    local gone, secs, n = 0, 0, 0
    local now = ns.Clock()
    for _, o in ipairs(rec.obs) do
        if Num(o.t) and Num(o.gone) and Num(o.dt) and now - o.t <= OBS_KEEP then
            gone, secs, n = gone + o.gone, secs + o.dt, n + 1
        end
    end
    if secs < DEMAND_MIN_HOURS * 3600 then return nil, secs / 3600, n end
    return gone / secs * 86400, secs / 3600, n
end

----------------------------------------------------------------------
-- What the guide makes and doesn't use again: what selling it gives back
----------------------------------------------------------------------
local AH_CUT = 0.05      -- the auction house keeps 5% of a sale; the deposit comes back when it sells

-- The vendor sell price (the game's item data). nil while the item isn't loaded.
function P.SellPrice(item)
    local packed = ns.CallAll(C_Item and C_Item.GetItemInfo, item)
    if packed[1] == nil then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item) end
        return nil
    end
    return Num(packed[11]) or 0
end

-- How units of an item that is left over are valued, with everything that number rests on:
--   vendor: the sell price per unit (0 when vendor sales aren't counted or it has none);
--   ah: what one sells for at the auction house after the cut, when it beats the vendor;
--   cap: how many are counted at that price (sales seen per day x days counted);
--   why: why the auction house isn't counted, in words.
function P.Resale(item)
    local res = resale[item]
    if res then return res end
    res = { item = item }
    local sell = P.SellPrice(item)
    res.sell = sell
    res.vendor = ns.db.sellVendor and sell or 0
    res.cap = 0
    local bound = BindType(item) == 1
    if not ns.db.sellAH then
        res.why = "auction house sales are off in the options"
    elseif bound then
        res.why = "it binds when picked up"
    else
        local latest = AHStore()[item]
        if type(latest) ~= "table" or not Num(latest.t) or type(latest.l) ~= "table" then
            res.why = "not scanned yet"
            res.waiting = true
        else
            res.age = ns.Clock() - latest.t
            res.stale = res.age > (Num(ns.db.staleHours) or 3) * 3600
            local cheapest = latest.l[1] and Num(latest.l[1][1])
            res.listed = 0
            for _, e in ipairs(latest.l) do res.listed = res.listed + (Num(e[2]) or 0) end
            res.lowest = cheapest
            local perDay, hours, scans = P.Demand(item)
            res.perDay, res.hours, res.scans = perDay, hours, scans
            if not cheapest then
                res.why = ("none listed at the last scan (%s)"):format(ns.Age(res.age))
            elseif not perDay then
                res.why = ("%.1f h of scans so far, it takes %d")
                    :format(hours or 0, DEMAND_MIN_HOURS)
                res.waiting = true
            else
                local net = cheapest * (1 - AH_CUT)
                if net <= (res.vendor or 0) then
                    res.why = "a vendor pays as much after the auction house cut"
                elseif perDay <= 0 then
                    res.why = ("none sold in %.0f h of scans"):format(hours)
                else
                    res.ah = net
                    res.cap = math.floor(perDay * (Num(ns.db.sellDays) or 3))
                    if res.cap <= 0 then
                        res.ah = nil
                        res.why = ("about %.1f a day sell, less than one in %d days"):format(perDay, ns.db.sellDays or 3)
                    end
                end
            end
        end
    end
    resale[item] = res
    return res
end

-- What n left-over units are worth: the first `cap` at the auction house price, the rest at the vendor.
function P.ValueOf(item, n)
    if n <= 1e-9 then return 0 end
    local res = P.Resale(item)
    local vendor = res.vendor or 0
    if res.ah then
        local atAH = math.min(n, res.cap)
        return atAH * res.ah + (n - atAH) * vendor
    end
    return n * vendor
end

-- Where n whole left-over units go: { item, n, ah = { n, each }, vendor = { n, each }, none (units
-- nothing buys), value, why (why the auction house isn't used, or only for some), res }.
function P.SellPlan(item, n)
    local res = P.Resale(item)
    local plan = { item = item, n = n, none = 0, value = 0, res = res, why = res.why }
    local rest = n
    if res.ah and res.cap > 0 then
        local atAH = math.min(rest, res.cap)
        plan.ah = { n = atAH, each = res.ah }
        plan.value = plan.value + atAH * res.ah
        rest = rest - atAH
        if rest > 0 then
            plan.why = ("about %s a day %s"):format(ns.Crafts(res.perDay), res.perDay == 1 and "sells" or "sell")
        end
    end
    if rest > 0 then
        if (res.vendor or 0) > 0 then
            plan.vendor = { n = rest, each = res.vendor }
            plan.value = plan.value + rest * res.vendor
        else
            plan.none = rest
        end
    end
    return plan
end

function P.OnEvent(event, a)
    if event == "AUCTION_HOUSE_SHOW" then
        scan.open = true
        if ns.db.autoScan then
            ns.After(START_DELAY, function()
                if scan.open and ns.db.autoScan then P.StartScan(false) end
            end)
        end
        ns.Changed()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        local was = scan.active
        scan.open, scan.queue, scan.pending = false, {}, nil
        if was then Finish() else ns.Changed() end
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if scan.active and not scan.pending then Pump() end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" or event == "ITEM_SEARCH_RESULTS_UPDATED" then
        local commodity = event == "COMMODITY_SEARCH_RESULTS_UPDATED"
        local item = commodity and Num(a) or Num(Field(a, "itemID"))
        if not item then return end
        local now = ns.Now()
        local ours = scan.pending and scan.pending.item == item
        local recent = scan.own[item] and now - scan.own[item] < 5
        if not (ours or recent) then scan.lastForeign = now end
        -- Results are facts whoever asked: keep them for reagents the guide uses.
        if ours or recent or Watched()[item] then
            local list, partial
            if commodity then list, partial = ReadCommodity(item) else list, partial = ReadItems(a) end
            Record(item, list, partial)
            ns.Changed()
        end
        if ours then
            scan.pending = nil
            scan.done = scan.done + 1
            Pump()
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        ns.ChangedSoon()
    end
end

function P.Forget()
    ns.db.ah[P.RealmKey()] = {}
    ns.db.vendor = {}
    ns.Changed()
    ns.Print("Forgot every auction and vendor price on this realm.")
end

-- How many reagents have a price, and how old the newest scan is.
function P.Summary()
    local store = AHStore()
    local n, newest = 0, nil
    for _, rec in pairs(store) do
        if type(rec) == "table" and Num(rec.t) then
            n = n + 1
            if not newest or rec.t > newest then newest = rec.t end
        end
    end
    return n, newest and (ns.Clock() - newest) or nil
end

function P.Debug()
    local n, age = P.Summary()
    ns.Print(("auction prices: %d items on %s, newest %s; scanning %s (%d of %d), auction house %s")
        :format(n, P.RealmKey(), age and ns.Age(age) or "never", scan.active and "yes" or "no", scan.done, scan.total,
            scan.open and "open" or "closed"))
end
