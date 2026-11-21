-- SkillPath: what reagents cost. Four sources, each named wherever its number is used:
--   * your bags (and bank): free;
--   * the auction house: every listing a scan read, cheapest first (item auctions are whole
--     lots, commodities are per unit), with the time of the scan;
--   * a vendor: the price a merchant showed you (unlimited stock only), or until you have seen
--     one, the item's own vendor price for the trade-supply reagents Data.lua lists;
--   * nothing: the guide says so instead of guessing.
-- The auction scan starts with one sweep of the whole auction house (an empty browse search,
-- page after page): the cheapest price and the number listed of every item, in a few queries.
-- Then only the items the path on screen uses are searched one by one for every listing, and
-- only when the sweep shows they changed since their last search. Each query waits for the
-- game's throttle and backs off while another addon (Slutmog Scout, Slutmog Shop) is searching.
-- Auctionator's last prices (when it is loaded) stand in for items this addon has never seen.
local ADDON, ns = ...
local P = {}
ns.Prices = P

local Call, Num, Str, Field = ns.Call, ns.Num, ns.Str, ns.Field

local LOT_CAP = 600          -- the lot-buying table covers this many units (more than any guide needs of one reagent)
local FOREIGN_QUIET = 3      -- seconds without another addon's results before the next query
local QUERY_TIMEOUT = 10
local START_DELAY = 5        -- after the auction house opens, so its own first search and other addons' go first
local FRESH_SKIP = 1800      -- an automatic scan skips prices younger than this
local SWEEP_TIMEOUT = 15     -- seconds without a page of the sweep before it counts as cut short
local SWEEP_AGAIN = 300      -- an automatic scan sweeps again only after this long
local SUMMARY_MATCH = 900    -- a sweep this recent still says whether an item changed
local DETAIL_ROUNDS = 3      -- search what the path uses, rebuild it, search what it uses now
local AUCTIONATOR_QTY = 1000 -- Auctionator keeps a price, not how many are listed
local OBS_MAX_GAP = 48 * 3600 -- sales: longer than the longest auction, everything could have run out
local OBS_KEEP = 7 * 86400     -- sales seen are kept for a week
local OBS_JOIN = 600           -- looks closer than this together count as one

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
local watched
function P.Invalidate() cache, bare, resale, watched = {}, {}, {}, nil end

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
    local now = ns.Clock()
    local ladder = type(rec) == "table" and type(rec.l) == "table" and Num(rec.t)
    local sum = type(rec) == "table" and type(rec.s) == "table" and Num(rec.s.t) and rec.s or nil
    local same = ladder and sum and rec.sm == sum.p and rec.sq == sum.q
    -- A sweep newer than the item's last search, that shows something else: it is the news. It has
    -- only the cheapest price, so it stands in only for items that aren't sold in whole lots.
    local news = sum and not same and (not ladder or sum.t > rec.t + 60)
    if news and (Num(sum.q) or 0) == 0 then
        sup.ah, sup.age = { t = sum.t, l = {} }, now - sum.t
    elseif news and Num(sum.p) and not sum.own and not (ladder and rec.lots) then
        sup.ah, sup.age, sup.summary = { t = sum.t, l = { { sum.p, sum.q } } }, now - sum.t, true
    elseif ladder then
        sup.ah = rec
        sup.age = now - (same and math.max(rec.t, sum.t) or rec.t)
    elseif not sum then
        local price, at = P.Auctionator(item)
        local swept = P.SweptAt()
        if price and not (swept and swept > at) then
            sup.ah, sup.age, sup.auctionator = { t = at, l = { { price, AUCTIONATOR_QTY } } }, now - at, true
        end
    end
    if sup.ah then sup.stale = sup.age > (Num(ns.db.staleHours) or 3) * 3600 end
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

-- Auctionator's last price for an item (per unit) and when it was seen, when that addon is loaded.
function P.Auctionator(item)
    local api = type(Auctionator) == "table" and type(Auctionator.API) == "table" and Auctionator.API.v1
    if type(api) ~= "table" or type(api.GetAuctionPriceByItemID) ~= "function" then return nil end
    local ok, price = pcall(api.GetAuctionPriceByItemID, ADDON or "SkillPath", item)
    price = ok and Num(price) or nil
    if not price or price <= 0 then return nil end
    local days
    if type(api.GetAuctionAgeByItemID) == "function" then
        local ok2, d = pcall(api.GetAuctionAgeByItemID, ADDON or "SkillPath", item)
        days = ok2 and Num(d) or nil
    end
    return price, ns.Clock() - (days or 1) * 86400
end

-- When the last whole sweep of this realm's auction house finished (nil: never).
function P.SweptAt()
    local t = type(ns.db.swept) == "table" and ns.db.swept[P.RealmKey()]
    return Num(t)
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
    local swept = P.SweptAt()
    if swept then return ("none listed at the last scan (%s)"):format(ns.Age(ns.Clock() - swept)) end
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

local watchedSell
local function Watched()
    local sell = ns.db.sellAH and true or false
    if not watched or watchedSell ~= sell then watched, watchedSell = P.Interest(sell), sell end
    return watched
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
    done = 0, total = 0, failed = 0, pumpQueued = false, phase = nil, sweep = nil, round = 0, looked = {},
    swept = 0, same = 0, none = 0 }
P.scanState = scan
local Record     -- below, with the sales

function P.CanScan()
    local ah = AH()
    return type(ah) == "table" and type(ah.SendSearchQuery) == "function" and type(ah.MakeItemKey) == "function"
end

-- The whole auction house in a few queries: an empty browse search, page after page.
function P.CanSweep()
    local ah = AH()
    return P.CanScan() and type(ah.SendBrowseQuery) == "function" and type(ah.GetBrowseResults) == "function"
end

function P.IsOpen() return scan.open end
function P.IsScanning() return scan.active end
function P.Progress() return scan.done, scan.total, scan.phase end

-- The items a scan asks for: reagents of the saved professions that a vendor doesn't sell and
-- that can be bought. An automatic scan skips prices younger than half an hour.
-- What to search for, the reagents of the path on screen first. all (a scan you asked for):
-- prices read a moment ago and what a vendor sells too (an auction can be under the vendor).
-- Only used where the client has no browse search to sweep with.
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

-- What the path on screen depends on: what it buys (dearest first), what it makes, the
-- reagents with no price that keep a maybe-cheaper recipe out, recipe items, and with auction
-- house sales on, what it has left to sell.
function P.PathItems(plan)
    local list, seen = {}, {}
    local function Add(item)
        if item and not seen[item] then
            seen[item] = true
            list[#list + 1] = item
        end
    end
    if not (plan and plan.ok) then return list end
    for _, e in ipairs(plan.shopping or {}) do Add(e.item) end
    local rest = {}
    for item in pairs(plan.used or {}) do rest[#rest + 1] = item end
    for item in pairs(plan.missing or {}) do rest[#rest + 1] = item end
    for _, l in pairs(plan.learned or {}) do
        if l.info and l.info.item then rest[#rest + 1] = l.info.item end
    end
    for _, o in ipairs(plan.options or {}) do
        if o.item then rest[#rest + 1] = o.item end
    end
    if ns.db.sellAH then
        for _, l in ipairs(plan.leftovers or {}) do rest[#rest + 1] = l.item end
    end
    table.sort(rest)
    for _, item in ipairs(rest) do Add(item) end
    return list
end

local function CopyList(l)
    local out = {}
    for i, e in ipairs(l) do out[i] = { e[1], e[2], e[3], e[4] } end
    return out
end

-- What one item of the path needs after the sweep: "search" (every listing, one query), or
-- settled without a query: "same" (the sweep shows what its last search showed), "none" (not
-- listed), "skip" (bound, or a vendor sells it for less than any auction).
local function Settle(item, manual)
    if BindType(item) == 1 then return "skip" end
    local now = ns.Clock()
    local rec = AHStore()[item]
    local sum = type(rec) == "table" and type(rec.s) == "table" and Num(rec.s.t) and now - rec.s.t <= SUMMARY_MATCH
        and rec.s or nil
    local swept = P.SweptAt()
    local none = (sum and (Num(sum.q) or 0) == 0) or (not sum and swept and now - swept <= SUMMARY_MATCH)
    local vendor = P.Vendor(item)
    if vendor and not manual and (none or not sum or not (Num(sum.p) and sum.p < vendor)) then return "skip" end
    if none then
        Record(item, {}, false, false)
        return "none"
    end
    if sum and type(rec.l) == "table" and Num(rec.t) and rec.sm == sum.p and rec.sq == sum.q and not rec.partial then
        Record(item, CopyList(rec.l), false)
        return "same"
    end
    return "search"
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
    scan.phase = nil
    if wasActive then
        local failed = scan.failed > 0 and (" (%d didn't answer)"):format(scan.failed) or ""
        if scan.sweep then
            local n = scan.done + scan.same + scan.none
            ns.Print(("Read the auction house: %d %s; for the path %d (%d searched, %d unchanged, %d not listed)%s.")
                :format(scan.swept, scan.swept == 1 and "item" or "items", n, scan.done, scan.same, scan.none, failed))
        else
            ns.Print(("Read %d auction %s%s."):format(scan.done, scan.done == 1 and "price" or "prices", failed))
        end
    end
    ns.Changed()
end

-- The next set of searches: what the path uses now and wasn't looked at in this scan. The
-- path is rebuilt between rounds, since new prices can send it to other recipes.
local function NextRound()
    scan.round = scan.round + 1
    if scan.round > DETAIL_ROUNDS then return Finish() end
    ns.Changed()
    local queue = {}
    for _, item in ipairs(P.PathItems(ns.Plan())) do
        if not scan.looked[item] then
            scan.looked[item] = true
            local what = Settle(item, scan.manual)
            if what == "search" then
                queue[#queue + 1] = item
            elseif what == "same" then
                scan.same = scan.same + 1
            elseif what == "none" then
                scan.none = scan.none + 1
            end
        end
    end
    if #queue == 0 then return Finish() end
    scan.queue = queue
    scan.total = scan.total + #queue
    ns.Redraw()
    Pump()
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
    scan.manual = manual and true or false
    scan.done, scan.failed, scan.total, scan.tries = 0, 0, 0, {}
    scan.round, scan.looked, scan.swept, scan.same, scan.none = 0, {}, 0, 0, 0
    scan.sweep, scan.queue = nil, {}
    if P.CanSweep() then
        local swept = P.SweptAt()
        scan.active = true
        if manual or not swept or ns.Clock() - swept >= SWEEP_AGAIN then
            scan.phase = "sweep"
            if manual then ns.Print("Reading the auction house.") end
            ns.Redraw()
            Pump()
        else
            -- Swept a moment ago (the auction house opened again): only the path's searches.
            scan.phase = "detail"
            scan.sweep = { done = true, seen = {} }
            NextRound()
        end
        return true
    end
    scan.phase = "detail"
    scan.queue = P.ScanList(manual)
    scan.total = #scan.queue
    if #scan.queue == 0 then
        if manual then ns.Print("Nothing to scan: no profession read yet, or vendors sell every reagent.") end
        return false
    end
    scan.active = true
    if manual then ns.Print(("Reading %d auction %s."):format(#scan.queue, #scan.queue == 1 and "price" or "prices")) end
    ns.Redraw()
    Pump()
    return true
end

-- Browse results, by item: the cheapest price, how many are listed, and whether one is yours.
local function AddBrowse(into, results, watch)
    for _, info in ipairs(type(results) == "table" and results or {}) do
        local id = Num(Field(Field(info, "itemKey"), "itemID"))
        local p, q = Num(Field(info, "minPrice")), Num(Field(info, "totalQuantity"))
        if id and p and q and q > 0 and (not watch or watch[id]) then
            local own = Field(info, "containsOwnerItem") == true
            local s = into[id]
            if s then
                if p < s.p then s.p = p end
                s.q = s.q + q
                s.own = s.own or own
            else
                into[id] = { p = p, q = q, own = own }
            end
        end
    end
end

-- Keeps the browse figures of the items SkillPath watches. Returns how many items they cover.
-- What a sweep showed of one item: its cheapest price and how many are listed. Between two looks
-- (sweep or search), the units no longer listed are counted as gone, as a search does, so an
-- item the path doesn't search yet still learns how fast it sells. Not for items sold in lots
-- (what a lot's row counts isn't known).
local function KeepSummary(rec, p, q, own, now)
    local prev = type(rec.s) == "table" and rec.s or nil
    local seen = false
    if not rec.lots and prev and Num(prev.q) and Num(prev.t) then
        local baseQ, baseT = prev.q, prev.t
        if Num(rec.t) and rec.t > prev.t then
            -- Searched since the last sweep: its listings are the newer baseline.
            baseQ, baseT = nil, rec.t
            if type(rec.l) == "table" and not rec.partial and not rec.cut then
                baseQ = 0
                for _, e in ipairs(rec.l) do baseQ = baseQ + (Num(e[2]) or 0) end
            end
        end
        local gap = now - baseT
        if baseQ and gap > 0 and gap <= OBS_MAX_GAP then
            local obs = {}
            for _, o in ipairs(type(rec.obs) == "table" and rec.obs or {}) do
                if Num(o.t) and now - o.t <= OBS_KEEP then obs[#obs + 1] = o end
            end
            local gone, last = math.max(0, baseQ - q), obs[#obs]
            if gap < OBS_JOIN and last and last.t == baseT and Num(last.gone) and Num(last.dt) then
                -- Looked again a moment later (the Buy tab's pages): one longer look, not many short ones.
                last.t, last.gone, last.dt = now, last.gone + gone, last.dt + gap
            else
                obs[#obs + 1] = { t = now, gone = gone, dt = gap }
            end
            rec.obs = obs
            seen = true
        end
    end
    rec.s = { p = p, q = q, t = now, own = own or nil, o = seen or nil }
end

local function KeepBrowse(seen)
    local watch, store, now = Watched(), AHStore(), ns.Clock()
    local n = 0
    for id, s in pairs(seen) do
        n = n + 1
        if watch[id] then
            local rec = store[id]
            if type(rec) ~= "table" then
                rec = {}
                store[id] = rec
            end
            KeepSummary(rec, s.p, s.q, s.own, now)
        end
    end
    return n
end

local function SweepDone(complete)
    local sweep = scan.sweep
    if not sweep or sweep.done then return end
    sweep.done = true
    local now = ns.Clock()
    scan.swept = KeepBrowse(sweep.seen)
    if complete then
        -- Not in a whole sweep: not listed at all.
        for id, rec in pairs(AHStore()) do
            if type(rec) == "table" and not sweep.seen[id] then KeepSummary(rec, nil, 0, nil, now) end
        end
        if type(ns.db.swept) ~= "table" then ns.db.swept = {} end
        ns.db.swept[P.RealmKey()] = now
    end
    scan.phase = "detail"
    NextRound()
end

-- A page of the sweep came in: ask for the next one, or end it there.
local function SweepPage()
    local sweep = scan.sweep
    local ah = AH()
    sweep.last = ns.Now()
    local full = Call(ah.HasFullBrowseResults)
    if full ~= false then return SweepDone(full == true) end
    local got = 0
    for _ in pairs(sweep.seen) do got = got + 1 end
    if got <= (sweep.asked or -1) then return end      -- the same page again
    sweep.asked = got
    if type(ah.RequestMoreBrowseResults) ~= "function" or not pcall(ah.RequestMoreBrowseResults) then
        SweepDone(false)
    end
end

local function SweepWatch(sweep, wait)
    ns.After(wait or SWEEP_TIMEOUT, function()
        if scan.sweep ~= sweep or sweep.done or not scan.active then return end
        local quiet = ns.Now() - (sweep.last or sweep.at)
        if quiet >= SWEEP_TIMEOUT - 0.01 then
            SweepDone(false)       -- cut short: what came in is kept, nothing is taken as unlisted
        else
            SweepWatch(sweep, SWEEP_TIMEOUT - quiet)
        end
    end)
end

-- Sends the next query when it is our turn.
function P.Next()
    if not (scan.active and scan.open) or scan.pending then return end
    if scan.phase == "sweep" and scan.sweep then return end      -- its pages come in as events
    local ah = AH()
    if scan.phase ~= "sweep" and #scan.queue == 0 then
        if scan.sweep then return NextRound() end
        return Finish()
    end
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
    if scan.phase == "sweep" then
        local sweep = { seen = {}, at = now }
        scan.sweep = sweep
        local sent = pcall(ah.SendBrowseQuery, { searchString = "", sorts = {}, filters = {}, itemClassFilters = {} })
        if not sent then
            SweepDone(false)
            return
        end
        SweepWatch(sweep)
        return
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

-- Browse results: pages of our sweep, or a search someone else made (the player, another
-- addon), whose figures are kept too; only a whole sweep says what isn't listed.
function P.OnBrowse(event, added)
    local ah = AH()
    local sweep = scan.sweep
    if scan.active and scan.phase == "sweep" and sweep and not sweep.done then
        if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
            sweep.seen = {}      -- every result so far
            AddBrowse(sweep.seen, Call(ah.GetBrowseResults))
        else
            AddBrowse(sweep.seen, added)
        end
        return SweepPage()
    end
    scan.lastForeign = ns.Now()
    local seen = {}
    AddBrowse(seen, event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" and Call(ah.GetBrowseResults) or added, Watched())
    if next(seen) then
        KeepBrowse(seen)
        ns.PricesChanged()
    end
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

-- sum: the sweep's figures to keep with it (false: none; nil: keep the last ones).
Record = function(item, list, partial, sum)
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
        local swept = type(prev.s) == "table" and prev.s.o and Num(prev.s.t) and prev.s.t > prev.t
        if gap and gap > 0 and gap <= OBS_MAX_GAP and not partial and not prev.partial and type(prev.l) == "table"
            and not swept then
            obs[#obs + 1] = { t = now, gone = Gone(prev.l, list, prev.cut, cut), dt = gap }
        end
    end
    local s = type(prev) == "table" and type(prev.s) == "table" and prev.s or nil
    if sum ~= nil then s = sum or nil end
    local sm, sq
    if s and Num(s.t) and now - s.t <= SUMMARY_MATCH then sm, sq = s.p, s.q end
    local lots = type(prev) == "table" and prev.lots or nil
    for _, e in ipairs(list) do
        if e[3] then lots = true end
    end
    store[item] = { t = now, l = list, partial = partial or nil, cut = cut or nil, obs = #obs > 0 and obs or nil,
        s = s, sm = sm, sq = sq, lots = lots }
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
        if scan.sweep and not scan.sweep.done then scan.sweep.done = true end
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
            ns.PricesChanged()
        end
        if ours then
            scan.pending = nil
            scan.done = scan.done + 1
            Pump()
        end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        P.OnBrowse(event, a)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        ns.ChangedSoon()
    end
end

function P.Forget()
    ns.db.ah[P.RealmKey()] = {}
    ns.db.vendor = {}
    if type(ns.db.swept) == "table" then ns.db.swept[P.RealmKey()] = nil end
    ns.Changed()
    ns.Print("Forgot every auction and vendor price on this realm.")
end

-- How many reagents have a price, and how old the newest scan is.
function P.Summary()
    local store = AHStore()
    local n, newest = 0, nil
    for _, rec in pairs(store) do
        if type(rec) == "table" then
            local t = Num(rec.t)
            local s = type(rec.s) == "table" and Num(rec.s.t) and (Num(rec.s.q) or 0) > 0 and rec.s.t
            if s and (not t or s > t) then t = s end
            if t and (Num(rec.t) or s) then
                n = n + 1
                if not newest or t > newest then newest = t end
            end
        end
    end
    return n, newest and (ns.Clock() - newest) or nil
end

function P.Debug()
    local n, age = P.Summary()
    local swept = P.SweptAt()
    ns.Print(("auction prices: %d items on %s, newest %s; last whole sweep %s; scanning %s (%s, %d of %d), auction house %s")
        :format(n, P.RealmKey(), age and ns.Age(age) or "never", swept and ns.Age(ns.Clock() - swept) or "never",
            scan.active and "yes" or "no", scan.phase or "-", scan.done, scan.total, scan.open and "open" or "closed"))
end
