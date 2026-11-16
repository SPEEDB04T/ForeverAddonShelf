-- Slutmog Shop: shop ads for your slutmog wares, one click each.
--
-- You keep a list of wares (an item and its price). Each click posts one ad for the next ware
-- to the channel you picked (Trade to start with), with the ware as a real item link and its
-- price. A piece from the slutmog list has ready-made ads (Ads.lua) about how it looks and
-- about the buyer's life as a player, which take turns; such a piece in your bags goes on the
-- shelf by itself and waits for a price. Any other ware gets one of your ad lines with a fresh opener and your shop's name,
-- for example
--   Hit your 40s and the gentlemen don't stare like they used to? ~ Smuttanie's Necessities ~
--   NOW OPEN for all your mogging needs! [Tyrant's Legplates] only 10 gold pieces.
--
-- The game lets a line go to Trade or General only from a click or a key press, so the addon
-- never posts by itself. One ad goes out per click on the minimap button or the window's
-- Post button, per press of your key (Key Bindings > AddOns) or per /slutshop post (a macro
-- works too). A reminder in your own chat says when it is time for the next one.
local ADDON, ns = ...

-- Mailbox mode, tips, the counter and the numbers are their own addon since 1.19.0, Mailbox Slutting
-- (SuccuDev: "can we split off mailbox slutting to its own addon"). When it is installed the shop
-- reaches its parts under the old names: ns.Mailbox, ns.Tips, ns.Counter, ns.Stat and ns.Stats are
-- looked up there, and are nil without it. It reaches the shop through the global SlutmogShopAPI.
local MAIL = { Mailbox = true, Tips = true, Counter = true, Stat = true, Stats = true }
setmetatable(ns, { __index = function(_, k)
    if not MAIL[k] then return nil end
    local m = rawget(_G, "MailboxSlutting")
    if type(m) == "table" then return m[k] end
end })
SlutmogShopAPI = ns
local MAIL_MISSING = "that is the Mailbox Slutting addon now, and it is not installed (or turned off). It is on the same addon page."

ns.VERSION = "1.19.0"
ns.TITLE = "Slutmog Shop"
ns.ICON = "Interface\\Icons\\INV_Misc_Coin_02"
ns.ACCENT = { 0.96, 0.55, 0.78 }

local CHAT_LIMIT = 255          -- bytes in one chat message, link codes included
local ECHO_WAIT = 5             -- seconds for our own ad to come back in chat
local LOG_MAX = 30
local floor, max, min, random = math.floor, math.max, math.min, math.random

ns.CHAT_LIMIT = CHAT_LIMIT

local PREFIX = "|cfff58cc7Slutmog Shop|r: "
local function Print(msg)
    local text = PREFIX .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end
ns.Print = Print

---------------------------------------------------------------------------
-- What a new shop starts with
---------------------------------------------------------------------------
ns.DEFAULT_SHOP = "Smuttanie's Necessities"

ns.DEFAULT_OPENERS = {
    "Hit your 40s and the gentlemen don't stare like they used to?",
    "Still dressed like a Scarlet nun and wondering why nobody flirts?",
    "Did your last suitor fall asleep looking at your tabard?",
    "Level {level} and still covered from neck to knee?",
    "Bards still not writing songs about you?",
    "Nobody buys you a drink at the Lion's Pride anymore?",
    "Have the Stormwind guards stopped telling you to cover up?",
    "Was the last one to wink at you a murloc?",
    "Still wearing the robe they handed you in Northshire?",
    "Dressed for a siege and wondering why nobody asks you to dance?",
    "You saved Azeroth twice this week. Your wardrobe is next.",
    "Want the whole inn to forget their ale when you walk in?",
    "The Light protects. It has never once flattered.",
    "Your armor covers too much, and your love life shows it?",
}

-- The link and the shop's name are the whole call to action: no "whisper me".
ns.DEFAULT_LINES = {
    "{opener} ~ {shop} ~ NOW OPEN for all your mogging needs! {item} only {price}.",
    "{opener} ~ {shop} ~ {item} for {price}, and the blushing is free.",
    "{opener} {shop} has just the thing: {item}, {price}.",
    "{opener} ~ {shop} ~ On the shelves today: {items}.",
}

-- What 1.0.0 started with. A shop still on exactly these gets the new ones; edited lists stay.
local OLD_OPENERS = {
    "Hit your 40s and the gentlemen don't stare like they used to?",
    "Tired of armor that hides everything worth looking at?",
    "Your plate covers too much and your love life shows it?",
    "Still dressed like a Scarlet nun and wondering why nobody flirts?",
    "Nobody buys you a drink at the inn anymore?",
    "Want the whole inn to forget their ale when you walk in?",
    "Why wear more when you could wear so much less?",
    "Bards still not writing songs about you?",
    "High armor, low allure?",
    "Did your last suitor fall asleep looking at your tabard?",
    "Ready to turn heads in Goldshire... or anywhere else?",
    "Feeling more dusty tome than tempting succubus?",
    "Level {level} and still covered from neck to knee?",
    "Your enemies fear you. Shouldn't everyone else want you?",
}
local OLD_LINES = {
    "{opener} ~ {shop} ~ NOW OPEN for all your mogging needs! {item} only {price}.",
    "{opener} ~ {shop} ~ {item} for just {price}. Whisper me to shop!",
    "{opener} ~ {shop} ~ Less armor, more allure! Today: {items}. Whisper me!",
}

-- Tyrant's Legplates for 10 gold, the piece from the first ad this addon was made for.
-- Its link is fetched from the game at login; until then it is skipped.
ns.SEED_WARES = { { id = 14840, price = 10 * 10000 } }

local DEFAULTS = {
    channel = "Trade",      -- "SAY", "YELL", "GUILD" or the name of a chat channel
    gap = 60,               -- seconds that must pass between two ads (0: no limit)
    remind = 5,             -- minutes after an ad until the reminder (0: none)
    sound = true,           -- the reminder plays a sound
    prompt = true,          -- the reminder also puts a Post button in the middle of the screen
    stockOnly = true,       -- skip wares that are in neither your bags nor your bank
    autoAdd = true,         -- pieces from the slutmog list found in your bags go on the shelf by themselves
    order = "turns",        -- wares take turns ("turns") or come at random ("random")
    prices = "words",       -- "10 gold pieces" ("words") or "10g" ("short")
    wording = "items",      -- a piece's ready-made ads ("items"), turn about ("mixed") or only your lines ("mine")
}
ns.DEFAULTS = DEFAULTS

local KNOWN = { opener = true, shop = true, item = true, price = true, items = true, level = true, pair = true }
local WARE_TOKENS = { "item", "price", "level" }

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function Readable(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return true
end

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Copy(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end

local function SameList(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- The text as people read it: colours dropped, links reduced to their [Name]. Links colour
-- their name as |cffRRGGBB or, on this client, by quality as |cnIQ2: (up to the colon).
local function Plain(text)
    text = tostring(text or "")
    text = text:gsub("|cn[^:|]*:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return text
end
ns.Plain = Plain
ns.Readable = Readable

local function ItemInfo(link)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(fn) ~= "function" or link == nil then return end
    local ok, name, full, quality, ilvl, req, _, _, _, _, texture = pcall(fn, link)
    if not ok then return end
    return name, full, quality, ilvl, req, texture
end
ns.ItemInfo = ItemInfo

function ns.ItemID(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%-?%d+)"))
end

-- Items with a random suffix ("of the Monkey") share an id; the suffix field tells them apart.
-- An item string runs id:enchant:gem1:gem2:gem3:gem4:suffix:unique:..., so the suffix is field 7.
local function WareKey(link)
    if type(link) ~= "string" then return nil end
    local s = link:match("item:([%-%d:]*)")
    if not s then return nil end
    local fields = {}
    for part in (s .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = part end
    return (fields[1] or "") .. ":" .. (fields[7] or "")
end
ns.WareKey = WareKey

local function LinkName(link)
    if type(link) ~= "string" then return nil end
    return link:match("|h%[(.-)%]|h")
end
ns.LinkName = LinkName

function ns.WareName(w)
    return LinkName(w.link) or w.name or ("item " .. tostring(w.id))
end

---------------------------------------------------------------------------
-- Prices
---------------------------------------------------------------------------
function ns.PriceText(copper, style)
    copper = max(0, floor(tonumber(copper) or 0))
    style = style or (ns.db and ns.db.prices) or "words"
    local g, s, c = floor(copper / 10000), floor(copper % 10000 / 100), copper % 100
    local parts = {}
    if style == "short" then
        if g > 0 then parts[#parts + 1] = g .. "g" end
        if s > 0 then parts[#parts + 1] = s .. "s" end
        if c > 0 then parts[#parts + 1] = c .. "c" end
        return #parts > 0 and table.concat(parts, " ") or "free"
    end
    if g > 0 then parts[#parts + 1] = g .. " gold" end
    if s > 0 then parts[#parts + 1] = s .. " silver" end
    if c > 0 then parts[#parts + 1] = c .. " copper" end
    if #parts == 0 then return "free" end
    if #parts == 1 then
        local n = (g > 0 and g) or (s > 0 and s) or c
        return parts[1] .. (n == 1 and " piece" or " pieces")
    end
    if #parts == 2 then return parts[1] .. " and " .. parts[2] end
    return parts[1] .. ", " .. parts[2] .. " and " .. parts[3]
end

-- "10", "10g", "10 gold", "1g 50s", "2.5", "50s", "free" -> copper; nil when it is not a price.
function ns.ParsePrice(text)
    if type(text) ~= "string" then return nil end
    local s = Trim(text:lower():gsub(",", "."))
    s = s:gsub("pieces?", " "):gsub("%f[%a]and%f[%A]", " ")
    s = Trim(s)
    if s == "" then return nil end
    if s == "free" then return 0 end
    local n = tonumber(s)
    if n then
        if n < 0 then return nil end
        return floor(n * 10000 + 0.5)
    end
    local total, any = 0, false
    for num, unit in s:gmatch("(%d+%.?%d*)%s*(%a+)") do
        local v, u = tonumber(num), unit:sub(1, 1)
        if not v then return nil end
        if u == "g" then total = total + v * 10000
        elseif u == "s" then total = total + v * 100
        elseif u == "c" then total = total + v
        else return nil end
        any = true
    end
    local rest = s:gsub("(%d+%.?%d*)%s*(%a+)", ""):gsub("%s", "")
    if not any or rest ~= "" then return nil end
    return floor(total + 0.5)
end

-- Coins as the game draws them, for the shop window.
-- A unit's whole name, the way chat and whispers know it. On Forever characters have a surname, and
-- UnitName gives it as its second value, where other clients put the realm (SuccuDev: "tip thanks is
-- failing because people have last names too not just first names"). The game's own whisper menu
-- joins them like this (UnitPopupUtils.lua, GetFullPlayerName, Gethe/wow-ui-source branch forever).
function ns.FullName(unit)
    if type(UnitName) ~= "function" then return nil end
    local ok, name, second = pcall(UnitName, unit)
    if not (ok and ns.Readable(name) and type(name) == "string" and name ~= "") then return nil end
    if not (ns.Readable(second) and type(second) == "string" and second ~= "") then return name end
    -- whether the second one is a surname or a realm is not told; chat and whispers spell people
    -- "First Last" here (.agents/memory/pitfalls.md, "Names on this client"), so it goes after a space
    local c = Constants and Constants.CharacterNameSeparatorConsts
    local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
    return name .. (type(sep) == "string" and sep ~= "" and sep or " ") .. second
end

function ns.MoneyText(copper)
    copper = max(0, floor(tonumber(copper) or 0))
    if copper == 0 then return "free" end
    if type(GetMoneyString) == "function" then
        local ok, s = pcall(GetMoneyString, copper, true)
        if ok and type(s) == "string" then return s end
    end
    if C_CurrencyInfo and type(C_CurrencyInfo.GetCoinTextureString) == "function" then
        local ok, s = pcall(C_CurrencyInfo.GetCoinTextureString, copper)
        if ok and type(s) == "string" then return s end
    end
    return ns.PriceText(copper, "short")
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
local db

local function CleanList(list, fallback)
    if type(list) ~= "table" then return Copy(fallback) end
    local out = {}
    for _, v in ipairs(list) do
        if type(v) == "string" and Trim(v) ~= "" then out[#out + 1] = Trim(v) end
    end
    return out
end

local function InitDB()
    SlutmogShopDB = type(SlutmogShopDB) == "table" and SlutmogShopDB or {}
    db = SlutmogShopDB
    ns.db = db
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil then db[k] = v end
    end
    if type(db.shop) ~= "string" then db.shop = ns.DEFAULT_SHOP end
    if type(db.sets) ~= "table" then db.sets = {} end
    db.openers = CleanList(db.openers, ns.DEFAULT_OPENERS)
    db.lines = CleanList(db.lines, ns.DEFAULT_LINES)
    if SameList(db.openers, OLD_OPENERS) then db.openers = Copy(ns.DEFAULT_OPENERS) end
    if SameList(db.lines, OLD_LINES) then db.lines = Copy(ns.DEFAULT_LINES) end
    if db.wording ~= "items" and db.wording ~= "mixed" and db.wording ~= "mine" then db.wording = DEFAULTS.wording end
    if type(db.wares) ~= "table" then
        db.wares = {}
        for _, seed in ipairs(ns.SEED_WARES) do
            db.wares[#db.wares + 1] = { id = seed.id, price = seed.price }
        end
    end
    local kept = {}
    for _, w in ipairs(db.wares) do
        if type(w) == "table" and (type(w.id) == "number" or type(w.link) == "string") then
            w.id = w.id or ns.ItemID(w.link)
            w.price = max(0, floor(tonumber(w.price) or 0))
            w.unpriced = (w.unpriced == true and w.price == 0) or nil
            kept[#kept + 1] = w
        end
    end
    db.wares = kept
    if type(db.decks) ~= "table" then db.decks = {} end
    if type(db.passed) ~= "table" then db.passed = {} end
    if type(db.votes) ~= "table" then db.votes = {} end       -- ad as written in Ads.lua -> "yes" or "no"
    if type(db.sent) ~= "table" then db.sent = {} end         -- ad as written in Ads.lua -> times posted
    for ad, v in pairs(db.votes) do
        if type(ad) ~= "string" or (v ~= "yes" and v ~= "no") then db.votes[ad] = nil end
    end
    if type(db.log) ~= "table" then db.log = {} end
    if type(db.minimap) ~= "table" then db.minimap = {} end
    if type(db.posts) ~= "number" then db.posts = 0 end
    if type(db.lastWare) ~= "number" then db.lastWare = 0 end
end
ns.InitDB = InitDB

local plan, planWhy             -- the next ad, worked out once and kept until something changes

local function Changed()
    plan, planWhy = nil, nil
    if ns.UI and ns.UI.Refresh then pcall(ns.UI.Refresh) end
end
ns.Changed = Changed

function ns.Set(key, value)
    if not db then return end
    db[key] = value
    Changed()
end

function ns.ShopName()
    local s = db and Trim(db.shop) or ""
    return s ~= "" and s or ns.TITLE
end

function ns.SetShop(name)
    db.shop = Trim(name)
    Changed()
end

function ns.SetOpeners(list)
    db.openers = CleanList(list, {})
    Changed()
end

function ns.SetLines(list)
    db.lines = CleanList(list, {})
    Changed()
end

function ns.ResetLines()
    db.shop = ns.DEFAULT_SHOP
    db.openers = Copy(ns.DEFAULT_OPENERS)
    db.lines = Copy(ns.DEFAULT_LINES)
    db.decks.lines, db.decks.openers = nil, nil      -- the ready-made ads keep their turns
    Changed()
end

function ns.Reset()
    for k, v in pairs(DEFAULTS) do db[k] = v end
    Changed()
    if ns.Kit and ns.Kit.RefreshMinimap then ns.Kit.RefreshMinimap() end
end

---------------------------------------------------------------------------
-- Wares
---------------------------------------------------------------------------
local bagCount = {}             -- item id -> how many the last bag scan saw (ScanBags fills it)

-- How many of a ware you have: the game's count (bags and bank) or what the bag scan saw,
-- whichever is higher, in case the game's count comes up short.
function ns.Count(w)
    if not (w and w.id) then return nil end
    local seen = bagCount[w.id]
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(fn) == "function" then
        local ok, n = pcall(fn, w.id, true)
        if ok and Readable(n) and type(n) == "number" then return max(n, seen or 0) end
    end
    return seen
end

-- Your own auctions, as the auction house showed them the last time it was open: item id ->
-- { price = buyout for one, at = when seen }. An auction runs two days at most, so older notes go.
local AH_LIFE = 48 * 3600
function ns.OnAH(id)
    if not (db and id) or type(db.ah) ~= "table" then return nil end
    local a = db.ah[id]
    if type(a) ~= "table" then return nil end
    if type(a.at) ~= "number" or time() - a.at > AH_LIFE then
        db.ah[id] = nil
        return nil
    end
    return a
end

-- Where a ware is for the buyer: "bags" (you hand it over) or "ah" (it is up on the auction house).
function ns.Where(w)
    local n = ns.Count(w)
    if n and n > 0 then return "bags" end
    if w and ns.OnAH(w.id) then return "ah" end
    return "bags"
end

-- Undercut: someone else sells the piece for less than your buyout, so an ad would only send
-- buyers to them. Each time the auction house opens, the shop looks up the other listings of
-- every piece you have up (ns.MarketStep below); Slutmog Scout's Sell tab tells the lowest price
-- too. The newest reading counts (SuccuDev: "its failing to detect auctions being undercut": the
-- only reading was Scout's, from before the auctions went up, and it said nobody else sold them).
-- A reading older than MARKET_LIFE says nothing.
local MARKET_LIFE = 6 * 3600

-- The lowest price of other sellers and when it was read, newest first; low = false: nobody else.
function ns.MarketLow(id)
    local low, at
    local m = db and type(db.market) == "table" and db.market[id]
    if type(m) == "table" and type(m.t) == "number" then low, at = m.low, m.t end
    local api = SlutmogScoutAPI
    if type(api) == "table" and type(api.MarketLow) == "function" then
        local ok, l, t = pcall(api.MarketLow, id)
        local clear = function(v) return v == nil or Readable(v) end
        if ok and clear(l) and clear(t) then
            if type(l) == "number" or type(t) == "number" then
                t = type(t) == "number" and t or time()
                if not at or t > at then low, at = type(l) == "number" and l or false, t end
            end
        end
    end
    return low, at
end

-- Undercut at `price` (default: your buyout on the auction house).
function ns.Undercut(id, price)
    if price == nil then
        local a = ns.OnAH(id)
        price = a and a.price
    end
    if type(price) ~= "number" or price <= 0 then return false end
    local low, at = ns.MarketLow(id)
    if not at or time() - at > MARKET_LIFE then return false end
    return type(low) == "number" and low > 0 and low < price
end

-- A ware is undercut where the buyer would get it: in your bags at its asking price (SuccuDev
-- agreed to leave those out too, 2026-11-15), or on the auction house at your buyout.
function ns.WareUndercut(w)
    if not (w and w.id) then return false end
    local n = ns.Count(w)
    if n and n > 0 then return not w.unpriced and ns.Undercut(w.id, w.price) end
    return ns.Undercut(w.id)
end

local function InStock(w)
    local n = ns.Count(w)
    if n == nil then return true end
    if n > 0 then return not ns.WareUndercut(w) end
    return w ~= nil and ns.OnAH(w.id) ~= nil and not ns.Undercut(w.id)
end
ns.InStock = InStock

---------------------------------------------------------------------------
-- Sets: a top and a bottom sold together. db.sets = { { a = the top's key, b = the bottom's } }.
-- A ware is in one set at most. A set whose other half is gone from the shelf is simply not found.
---------------------------------------------------------------------------
local function WareByKey(key)
    for i, w in ipairs(db.wares) do
        if w.link and WareKey(w.link) == key then return i, w end
    end
end

local function IsBottom(w)
    local e = type(ns.ITEM_ADS) == "table" and ns.ITEM_ADS[w.id]
    if type(e) == "table" and type(e.pools) == "table" then
        for _, p in ipairs(e.pools) do
            if p == "legs" then return true end
        end
        return false                -- a piece on the list: the list says what it is
    end
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(fn) == "function" and w.link then
        local r = { pcall(fn, w.link) }
        if r[1] and r[10] == "INVTYPE_LEGS" then return true end
    end
    return false
end

-- The ware that ware i is sold with, and which half ware i is: "top" (it leads the ad) or "bottom".
function ns.SetWith(i)
    local w = db and db.wares[i]
    local key = w and w.link and WareKey(w.link)
    if not key or type(db.sets) ~= "table" then return nil end
    for _, s in ipairs(db.sets) do
        if s.a == key then
            local j = WareByKey(s.b)
            if j then return j, "top" end
        elseif s.b == key then
            local j = WareByKey(s.a)
            if j then return j, "bottom" end
        end
    end
    return nil
end

local function DropSets(key)
    for k = #db.sets, 1, -1 do
        local s = db.sets[k]
        if type(s) ~= "table" or s.a == key or s.b == key then table.remove(db.sets, k) end
    end
end

function ns.IsBottom(i)
    local w = db.wares[i]
    return w ~= nil and IsBottom(w)
end

-- Wares i and j are sold as a set from now on: one top and one bottom. The legs go second.
function ns.PairWares(i, j)
    local a, b = db.wares[i], db.wares[j]
    if not (a and b and a.link and b.link) or i == j then return false end
    if IsBottom(a) == IsBottom(b) then return false end     -- a set is one top and one bottom
    if IsBottom(a) then a, b = b, a end
    local ka, kb = WareKey(a.link), WareKey(b.link)
    if not (ka and kb) or ka == kb then return false end
    DropSets(ka)
    DropSets(kb)
    db.sets[#db.sets + 1] = { a = ka, b = kb }
    Changed()
    return true
end

function ns.Unpair(i)
    local w = db.wares[i]
    local key = w and w.link and WareKey(w.link)
    if not key or not ns.SetWith(i) then return false end
    DropSets(key)
    Changed()
    return true
end

function ns.FindWare(link)
    local key = WareKey(link)
    if not key then return nil end
    for i, w in ipairs(db.wares) do
        if (w.link and WareKey(w.link) == key) or (not w.link and key == tostring(w.id) .. ":") then return i, w end
    end
end

-- Adds an item with its price, or changes the price if it is already a ware.
function ns.AddWare(link, copper)
    if not db then return false, "not ready yet." end
    local id = ns.ItemID(link)
    if not id then return false, "that is not an item link." end
    copper = max(0, floor(tonumber(copper) or 0))
    local i, w = ns.FindWare(link)
    local key = WareKey(link)
    if key then db.passed[key] = nil end
    if w then
        w.link, w.id, w.price, w.unpriced = link, id, copper, nil
        Changed()
        return true, ("%s now costs %s."):format(link, ns.PriceText(copper)), i
    end
    db.wares[#db.wares + 1] = { id = id, link = link, price = copper }
    Changed()
    return true, ("%s added for %s."):format(link, ns.PriceText(copper)), #db.wares
end

function ns.RemoveWare(i)
    local w = db.wares[i]
    if not w then return false end
    table.remove(db.wares, i)
    local key = WareKey(w.link)
    if key then db.passed[key] = true end      -- the bag scan leaves a piece you took off the shelf alone
    if db.lastWare >= i then db.lastWare = max(0, db.lastWare - 1) end
    Changed()
    return true, w
end

function ns.MoveWare(i, delta)
    local j = i + delta
    local list = db.wares
    if not (list[i] and list[j]) then return false end
    list[i], list[j] = list[j], list[i]
    if db.lastWare == i then db.lastWare = j elseif db.lastWare == j then db.lastWare = i end
    Changed()
    return true
end

-- The next ad features ware i.
function ns.FeatureNext(i)
    if not db.wares[i] then return false end
    db.lastWare = i - 1
    if db.order == "random" then db.feature = i end
    Changed()
    return true
end

-- Links for wares the game had not loaded yet (the seeded one at first login).
local pending = {}
local function FillLinks()
    if not db then return end
    local filled = false
    for _, w in ipairs(db.wares) do
        if not w.link and w.id then
            local name, link = ItemInfo(w.id)
            if type(link) == "string" then
                w.link, w.name, filled = link, name, true
                pending[w.id] = nil
            elseif not pending[w.id] then
                pending[w.id] = true
                if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                    pcall(C_Item.RequestLoadItemDataByID, w.id)
                end
            end
        end
    end
    if filled then Changed() end
end
ns.FillLinks = FillLinks

---------------------------------------------------------------------------
-- Bag scan: every piece from the slutmog list in your bags goes on the shelf by itself. It has
-- no price yet, so it stays out of the ads until you give it one.
---------------------------------------------------------------------------
local function BagLink(bag, slot)
    local link
    if C_Container and type(C_Container.GetContainerItemLink) == "function" then
        local ok, v = pcall(C_Container.GetContainerItemLink, bag, slot)
        if ok then link = v end
    elseif type(GetContainerItemLink) == "function" then
        local ok, v = pcall(GetContainerItemLink, bag, slot)
        if ok then link = v end
    end
    local count = 1
    if C_Container and type(C_Container.GetContainerItemInfo) == "function" then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            if not link then link = info.hyperlink end
            if Readable(info.stackCount) and type(info.stackCount) == "number" then count = info.stackCount end
        end
    end
    if Readable(link) and type(link) == "string" then return link, count end
end

-- Returns how many pieces it put on the shelf. `all` also takes back pieces you removed before.
function ns.ScanBags(all)
    if not db then return 0 end
    local slots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if type(slots) ~= "function" then return 0 end
    local counts, added = {}, {}
    for bag = 0, (tonumber(NUM_BAG_SLOTS) or 4) do
        local ok, n = pcall(slots, bag)
        if ok and Readable(n) and type(n) == "number" then
            for slot = 1, n do
                local link, count = BagLink(bag, slot)
                local id = link and ns.ItemID(link)
                if id then
                    counts[id] = (counts[id] or 0) + count
                    local key = WareKey(link)
                    if (all or db.autoAdd) and key and ns.ItemAds(id) and not ns.FindWare(link)
                        and (all or not db.passed[key]) then
                        db.passed[key] = nil
                        db.wares[#db.wares + 1] = { id = id, link = link, price = 0, unpriced = true }
                        added[#added + 1] = link
                    end
                end
            end
        end
    end
    bagCount = counts
    if #added > 0 then
        local one = #added == 1
        Print(("found %s in your bags and put %s on the shelf. Click %s in the shop window (/slutshop) to set a "
            .. "price; until then %s out of the ads."):format(table.concat(added, ", "), one and "it" or "them",
            one and "it" or "each", one and "it stays" or "they stay"))
        Changed()
    end
    return #added
end

-- Your own auctions as rows { id, link, buyout, count, sold }, from whichever auction house this
-- client has: the new one (C_AuctionHouse, what Forever uses) or the old one. nil: neither answers.
local function OwnedAuctions()
    local rows = {}
    local AH = C_AuctionHouse
    if type(AH) == "table" and type(AH.GetNumOwnedAuctions) == "function" and type(AH.GetOwnedAuctionInfo) == "function" then
        local ok, n = pcall(AH.GetNumOwnedAuctions)
        if not ok or not Readable(n) or type(n) ~= "number" then return nil end
        local soldStatus = type(Enum) == "table" and type(Enum.AuctionStatus) == "table" and Enum.AuctionStatus.Sold or 1
        for i = 1, n do
            local iok, a = pcall(AH.GetOwnedAuctionInfo, i)
            if iok and type(a) == "table" then
                local key = a.itemKey
                local id = type(key) == "table" and key.itemID or nil
                if Readable(id) and type(id) == "number" then
                    local link, buyout, count, status = a.itemLink, a.buyoutAmount, a.quantity, a.status
                    rows[#rows + 1] = {
                        id = id, key = key,
                        link = Readable(link) and type(link) == "string" and link or nil,
                        buyout = Readable(buyout) and type(buyout) == "number" and buyout or 0,
                        count = Readable(count) and type(count) == "number" and count > 0 and count or 1,
                        sold = Readable(status) and status == soldStatus,
                    }
                end
            end
        end
        return rows
    end
    if type(GetNumAuctionItems) ~= "function" or type(GetAuctionItemInfo) ~= "function" then return nil end
    local ok, n = pcall(GetNumAuctionItems, "owner")
    if not ok or not Readable(n) or type(n) ~= "number" then return nil end
    for i = 1, n do
        local r = { pcall(GetAuctionItemInfo, "owner", i) }
        local count, buyout, sold, id = r[4], r[11], r[17], r[18]
        if r[1] and Readable(id) and type(id) == "number" then
            local link
            if type(GetAuctionItemLink) == "function" then
                local lok, v = pcall(GetAuctionItemLink, "owner", i)
                if lok and Readable(v) and type(v) == "string" then link = v end
            end
            rows[#rows + 1] = {
                id = id, link = link,
                buyout = Readable(buyout) and type(buyout) == "number" and buyout or 0,
                count = Readable(count) and type(count) == "number" and count > 0 and count or 1,
                sold = Readable(sold) and sold == 1,
            }
        end
    end
    return rows
end

-- Reads your own auctions (the auction house must be open). A piece from the slutmog list that is
-- up for sale goes on the shelf by itself, priced at its buyout. Returns how many it put there.
function ns.ScanAuctions()
    if not db then return 0 end
    local rows = OwnedAuctions()
    if not rows then return 0 end
    local found, added, now = {}, {}, time()
    for _, r in ipairs(rows) do
        if not r.sold then
            local id, link = r.id, r.link
            local each = math.floor(r.buyout / r.count)
            local old = found[id]
            if not old or (each > 0 and (old.price == 0 or each < old.price)) then found[id] = { price = each, at = now } end
            local key = link and WareKey(link)
            if db.autoAdd and key and ns.ItemAds(id) and not ns.FindWare(link) and not db.passed[key] then
                db.wares[#db.wares + 1] = { id = id, link = link, price = each, unpriced = each <= 0 or nil }
                added[#added + 1] = link
            end
        end
    end
    db.ah = found
    local keys = {}
    for _, r in ipairs(rows) do
        if not r.sold and r.key and found[r.id] then keys[r.id] = r.key end
    end
    -- and the wares in your bags, whose buyers could buy cheaper on the auction house
    local AH = C_AuctionHouse
    if type(AH) == "table" and type(AH.MakeItemKey) == "function" then
        for _, w in ipairs(db.wares) do
            local n = ns.Count(w)
            if w.id and not keys[w.id] and not w.unpriced and n and n > 0 then
                local ok, k = pcall(AH.MakeItemKey, w.id)
                if ok and type(k) == "table" then keys[w.id] = k end
            end
        end
    end
    if ns.QueueMarket then ns.QueueMarket(keys) end
    if #added > 0 then
        Print(("found %s among your auctions and put %s on the shelf at the buyout price."):format(
            table.concat(added, ", "), #added == 1 and "it" or "them"))
    end
    Changed()
    return #added
end

-- Asks the auction house for your auctions; the answer comes as an event. Only the new auction
-- house needs asking, and only when it is not busy (another addon's query must not be cut short).
function ns.AskAuctions()
    local AH = C_AuctionHouse
    if type(AH) ~= "table" or type(AH.QueryOwnedAuctions) ~= "function" then return false end
    if type(AH.IsThrottledMessageSystemReady) == "function" then
        local ok, ready = pcall(AH.IsThrottledMessageSystemReady)
        if not ok or not Readable(ready) or ready == false then return false end
    end
    local order = type(Enum) == "table" and type(Enum.AuctionHouseSortOrder) == "table" and Enum.AuctionHouseSortOrder.Price or 4
    return (pcall(AH.QueryOwnedAuctions, { { sortOrder = order, reverseSort = false } }))
end

-- The other listings of your auctioned pieces, one search at a time, when the auction house is
-- not busy. db.market[id] = { low = lowest unit buyout of somebody else (false: nobody), t = time() }.
local MARKET_FRESH = 120        -- seconds a reading counts as current: not looked up again
local MARKET_WAIT = 10          -- seconds to wait for an answer
local market = { queue = {}, open = false }
ns.MarketState = market

function ns.QueueMarket(keys)
    if type(C_AuctionHouse) ~= "table" or type(C_AuctionHouse.SendSearchQuery) ~= "function" then return 0 end
    db.market = type(db.market) == "table" and db.market or {}
    local now, n = time(), 0
    for id, key in pairs(keys) do
        local m = db.market[id]
        local queued = market.searching and market.searching.id == id
        for _, j in ipairs(market.queue) do queued = queued or j.id == id end
        if not queued and not (type(m) == "table" and type(m.t) == "number" and now - m.t < MARKET_FRESH) then
            market.queue[#market.queue + 1] = { id = id, key = key }
            n = n + 1
        end
    end
    ns.MarketStep()
    return n
end

local function Tick()
    if C_Timer and C_Timer.After and (market.searching or #market.queue > 0) and not market.ticking then
        market.ticking = true
        C_Timer.After(1, function()
            market.ticking = false
            ns.MarketStep()
        end)
    end
end

function ns.MarketStep()
    local AH = C_AuctionHouse
    if type(AH) ~= "table" or not market.open then return false end
    if market.searching then
        if GetTime() - market.sentAt <= MARKET_WAIT then Tick() return false end
        market.searching = nil      -- no answer: left as it was
    end
    if #market.queue == 0 then return false end
    if type(AH.IsThrottledMessageSystemReady) == "function" then
        local ok, ready = pcall(AH.IsThrottledMessageSystemReady)
        if not ok or not Readable(ready) or ready == false then Tick() return false end
    end
    local job = table.remove(market.queue, 1)
    local order = type(Enum) == "table" and type(Enum.AuctionHouseSortOrder) == "table" and Enum.AuctionHouseSortOrder.Price or 0
    if pcall(AH.SendSearchQuery, job.key, { { sortOrder = order, reverseSort = false } }, false) then
        market.searching, market.sentAt = job, GetTime()
    end
    Tick()
    return true
end

-- The answer for the piece being looked up: the cheapest one of somebody else's, for one.
function ns.MarketRead(itemKey)
    local job = market.searching
    local AH = C_AuctionHouse
    if not (job and type(AH) == "table" and type(itemKey) == "table") then return false end
    local id = itemKey.itemID
    if not (Readable(id) and id == job.id) then return false end
    if type(AH.GetNumItemSearchResults) ~= "function" or type(AH.GetItemSearchResultInfo) ~= "function" then return false end
    local ok, n = pcall(AH.GetNumItemSearchResults, job.key)
    if not ok or not Readable(n) or type(n) ~= "number" then return false end
    local low = false
    for i = 1, n do
        local iok, r = pcall(AH.GetItemSearchResultInfo, job.key, i)
        if iok and type(r) == "table" then
            local own = (Readable(r.containsOwnerItem) and r.containsOwnerItem) or (Readable(r.containsAccountItem) and r.containsAccountItem)
            local buy, qty = r.buyoutAmount, r.quantity
            if not own and Readable(buy) and type(buy) == "number" and buy > 0 then
                qty = Readable(qty) and type(qty) == "number" and qty > 0 and qty or 1
                local each = math.floor(buy / qty)
                if low == false or each < low then low = each end
            end
        end
    end
    db.market = type(db.market) == "table" and db.market or {}
    db.market[job.id] = { low = low, t = time() }
    market.searching = nil
    Changed()
    ns.MarketStep()
    return true
end

function ns.Unpriced()
    local n = 0
    for _, w in ipairs(db.wares) do if w.unpriced then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------
-- Turns: openers and ad lines come in a shuffled order, each used once before any repeats
---------------------------------------------------------------------------
local function Shuffled(n, avoidFirst)
    local t = {}
    for i = 1, n do t[i] = i end
    for i = n, 2, -1 do
        local j = random(i)
        t[i], t[j] = t[j], t[i]
    end
    if avoidFirst and n > 1 and t[1] == avoidFirst then
        local j = random(2, n)
        t[1], t[j] = t[j], t[1]
    end
    return t
end

local function Deck(key, n)
    local d = db.decks[key]
    if type(d) ~= "table" or d.n ~= n or type(d.order) ~= "table" or #d.order ~= n or type(d.pos) ~= "number" then
        d = { n = n, order = Shuffled(n), pos = 1 }
        db.decks[key] = d
    end
    if d.pos > n then
        d.order = Shuffled(n, d.order[n])
        d.pos = 1
    end
    return d
end

local function DeckOrder(key, n)
    local out = {}
    if n <= 0 then return out end
    local d = Deck(key, n)
    for k = d.pos, n do out[#out + 1] = d.order[k] end
    for k = 1, d.pos - 1 do out[#out + 1] = d.order[k] end
    return out
end

local function DeckTake(key, n, index)
    if n <= 0 or not index then return end
    local d = Deck(key, n)
    for k = d.pos, n do
        if d.order[k] == index then
            d.order[k], d.order[d.pos] = d.order[d.pos], d.order[k]
            d.pos = d.pos + 1
            return
        end
    end
    -- Not among the ones left this round: those could not be used (too long, or voted out), and
    -- the ad came from further back. That ends the round; the next one starts after this ad.
    d.order = Shuffled(n, d.order[n])
    for k = 1, n do
        if d.order[k] == index then
            d.order[k], d.order[1] = d.order[1], d.order[k]
            break
        end
    end
    d.pos = 2
end

-- The wares that may go into an ad, the one due next first.
local function Offer()
    local list, wares = {}, db.wares
    local n = #wares
    if n == 0 then return list end
    local start = db.lastWare or 0
    for k = 1, n do
        local i = (start + k - 1) % n + 1
        local w = wares[i]
        if w.link and not w.unpriced and (not db.stockOnly or InStock(w)) then list[#list + 1] = i end
    end
    if db.order == "random" and #list > 1 then
        local first = db.feature
        for i = #list, 2, -1 do
            local j = random(i)
            list[i], list[j] = list[j], list[i]
        end
        local avoid = db.lastWare
        for k, i in ipairs(list) do
            if (first and i == first) or (not first and k > 1 and list[1] == avoid) then
                list[1], list[k] = list[k], list[1]
                break
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Writing the ad
---------------------------------------------------------------------------
local function Uses(text, key)
    local low = text:lower()
    if key == "opener" then
        return low:find("{opener}", 1, true) or low:find("{hook}", 1, true)
    end
    return low:find("{" .. key .. "}", 1, true)
end

local function UsesWare(text)
    for _, key in ipairs(WARE_TOKENS) do
        if Uses(text, key) then return true end
    end
    return false
end

-- Puts the fields into the {tokens}. Returns the text and the first token that had no value.
local function Fill(template, fields)
    local missing
    local text = template:gsub("{(%a+)}", function(key)
        local k = key:lower()
        if k == "hook" then k = "opener" end
        if not KNOWN[k] then return nil end
        local v = fields[k]
        if v == nil then
            missing = missing or k
            return ""
        end
        return v
    end)
    text = Trim(text:gsub("%s%s+", " "))
    return text, missing
end
ns.Fill = Fill

-- Without an opener a line like "{opener} ~ {shop} ~ ..." would start with "~".
local function NoLead(text)
    return (text:gsub("^[%s~%-:;,%.!%?]+", ""))
end

local function LevelOf(w)
    local _, _, _, _, req = ItemInfo(w.link or w.id)
    if Readable(req) and type(req) == "number" and req > 0 then return tostring(req) end
end

local function WareFields(fields, w)
    fields.item, fields.price, fields.level = nil, nil, nil
    if not w then return end
    fields.item = w.link
    local a = ns.Where(w) == "ah" and ns.OnAH(w.id)
    fields.price = ns.PriceText(a and a.price > 0 and a.price or w.price)
    fields.level = LevelOf(w)
end

local function NoStockWhy()
    if #db.wares == 0 then
        return "you have no wares yet. Drop an item on the slot in the shop window (/slutshop)."
    end
    if ns.Unpriced() == #db.wares then
        return "your wares have no price yet. Click one in the shop window (/slutshop) and give it a price."
    end
    if db.stockOnly then
        return "none of your wares is in your bags, your bank or on the auction house (untick \"Only wares I still have\" in the options to advertise them anyway)."
    end
    return "the game has not loaded your wares' item links yet. Try again in a moment."
end

---------------------------------------------------------------------------
-- Ready-made ads (Ads.lua), taking turns per piece. A piece has ads of its own and draws on the
-- pools for its look, its armor type, its slot and its level range, plus a share of the ads that
-- fit any piece. {color} is the piece's own colour words, put in here.
---------------------------------------------------------------------------
local flat = setmetatable({}, { __mode = "k" })     -- a piece's entry -> its ads, built once per shop name

local function BuildAds(id, entry, shop)
    local list, seen = { src = {}, shop = shop }, {}
    local color = type(entry.color) == "string" and entry.color or nil
    -- A line about a level or a place people outgrow is only for pieces of about that level.
    local levels = type(ns.AD_LEVELS) == "table" and ns.AD_LEVELS or {}
    local req = type(entry.req) == "number" and entry.req or nil
    local function Add(ad)
        if type(ad) ~= "string" then return end
        local range = levels[ad]
        if type(range) == "table" and (not req or req < (range[1] or 0) or req > (range[2] or 999)) then return end
        local raw = ad
        if ad:find("{color}", 1, true) then
            if not color then return end
            ad = ad:gsub("{color}", function() return color end)
        end
        if not seen[ad] then
            seen[ad] = true
            list[#list + 1] = ad
            list.src[#list] = raw
        end
    end
    for _, ad in ipairs(entry) do Add(ad) end
    local pools = type(ns.AD_POOLS) == "table" and ns.AD_POOLS or {}
    if type(entry.pools) == "table" then
        for _, name in ipairs(entry.pools) do
            local pool = pools[name]
            if type(pool) == "table" then
                for _, ad in ipairs(pool) do Add(ad) end
            end
        end
    end
    -- A pool called shop_<word> is for a shop with that word in its name: lines that play on the name.
    local names = {}
    for name in pairs(pools) do
        if type(name) == "string" and name:sub(1, 5) == "shop_" and #name > 5 and shop:find(name:sub(6), 1, true) then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        if type(pools[name]) == "table" then
            for _, ad in ipairs(pools[name]) do Add(ad) end
        end
    end
    return list
end

function ns.ItemAds(id)
    local all = ns.ITEM_ADS
    if type(all) ~= "table" or type(id) ~= "number" then return nil end
    local entry = all[id]
    if type(entry) ~= "table" then return nil end
    local shop = db and type(db.shop) == "string" and db.shop:lower() or ""
    local list = flat[entry]
    if not list or list.shop ~= shop then
        list = BuildAds(id, entry, shop)
        flat[entry] = list
    end
    if #list > 0 then return list end
    return nil
end

function ns.ItemAdCount()
    local n = 0
    if type(ns.ITEM_ADS) == "table" then
        for _ in pairs(ns.ITEM_ADS) do n = n + 1 end
    end
    return n
end

-- An ad that names neither price nor shop gets an ending, by where the ware is. The endings take
-- turns too; one that makes the ad too long for a chat message gives way to the next.
local function Ended(ad, fields, where, turn, endings)
    if ad:find("{price}", 1, true) or ad:find("{shop}", 1, true) then
        local text, miss = Fill(ad, fields)
        if not miss and #text <= CHAT_LIMIT then return text end
        return nil
    end
    local tails
    if endings then
        tails = endings[where]
        if type(tails) ~= "table" or #tails == 0 then return nil end
    else
        tails = type(ns.AD_TAILS) == "table" and (ns.AD_TAILS[where] or ns.AD_TAILS.bags)
        if type(tails) ~= "table" or #tails == 0 then tails = { " {item}, {price} at {shop}." } end
    end
    for k = 0, #tails - 1 do
        local text, miss = Fill(ad .. tails[(turn + k) % #tails + 1], fields)
        if not miss and #text <= CHAT_LIMIT then return text end
    end
    return nil
end
ns.Ended = Ended

-- The lines for a set: the "sets" pool, and "sets_<word>" for a shop with that word in its name.
local setAds
local function SetAds(shop)
    if setAds and setAds.shop == shop then return setAds end
    local list, pools = { shop = shop }, ns.AD_POOLS
    if type(pools) == "table" then
        local names = {}
        for name in pairs(pools) do
            if name == "sets" or (type(name) == "string" and name:sub(1, 5) == "sets_" and #name > 5 and shop:find(name:sub(6), 1, true)) then
                names[#names + 1] = name
            end
        end
        table.sort(names)
        for _, name in ipairs(names) do
            if type(pools[name]) == "table" then
                for _, ad in ipairs(pools[name]) do list[#list + 1] = ad end
            end
        end
    end
    setAds = list
    return list
end

local function PriceAt(w, where)
    local a = where == "ah" and ns.OnAH(w.id)
    return a and a.price > 0 and a.price or w.price
end

-- The ware whose turn it is, for a line that is not an ad (the mailbox pitch): link, price, where.
function ns.WareOffer()
    local p = ns.Next()
    local w = p and p.ware and db.wares[p.ware]
    if not (w and w.link) or w.unpriced then return nil end
    local where = ns.Where(w)
    return { item = w.link, price = ns.PriceText(PriceAt(w, where)), where = where, shop = ns.ShopName() }
end

-- One ad for a top and its bottom, when both can be had in the same place: both linked, one price.
local function ComposeSetAd(wi, j, shop)
    local w, w2 = db.wares[wi], db.wares[j]
    if not (w and w2 and w.link and w2.link) or w.unpriced or w2.unpriced then return nil end
    if IsBottom(w) or not IsBottom(w2) then return nil end  -- the set lines say "top and bottom"
    if db.stockOnly and not InStock(w2) then return nil end
    local where = ns.Where(w)
    if ns.Where(w2) ~= where or type(ns.SET_TAILS) ~= "table" then return nil end
    local ads = SetAds(shop:lower())
    if #ads == 0 then return nil end
    local fields = { shop = shop, item = w.link, pair = w2.link, price = ns.PriceText(PriceAt(w, where) + PriceAt(w2, where)) }
    for _, ai in ipairs(DeckOrder("set", #ads)) do
        local src = ads[ai]
        if db.votes[src] ~= "no" then
            local text = Ended(src, fields, where, ai, ns.SET_TAILS)
            if text then
                return { text = text, kind = "item", where = where, deck = "set", decks = #ads, ad = ai, ware = wi, ware2 = j,
                         last = wi, wares = 2, set = true, src = src, vote = db.votes[src] }
            end
        end
    end
    return nil
end

-- The next ready-made ad for the ware due next, or nil when it has none (or none fits).
local function ComposeItemAd(offer, shop)
    local wi = offer[1]
    local w = wi and db.wares[wi]
    if w and shop ~= "" then
        local j, half = ns.SetWith(wi)
        if j and half == "top" then
            local p = ComposeSetAd(wi, j, shop)
            if p then return p end
        end
    end
    local ads = w and ns.ItemAds(w.id)
    if not ads or shop == "" then return nil end
    local fields = { shop = shop }
    WareFields(fields, w)
    local key = "item:" .. w.id
    local where = ns.Where(w)
    for _, ai in ipairs(DeckOrder(key, #ads)) do
        local src = ads.src and ads.src[ai] or ads[ai]
        if db.votes[src] ~= "no" then
            local text = Ended(ads[ai], fields, where, ai)
            if text then
                return { text = text, kind = "item", where = where, deck = key, decks = #ads, ad = ai, ware = wi, last = wi, wares = 1,
                         src = src, vote = db.votes[src] }
            end
        end
    end
    return nil
end

-- An ad from your own lines and openers.
local function ComposeLine(offer, shop)
    local lines, openers = db.lines, db.openers
    if #lines == 0 then return nil, "there is no ad line. Write one on the Lines tab of the shop window." end
    local why
    for _, li in ipairs(DeckOrder("lines", #lines)) do
        local line = lines[li]
        local wantsWare, wantsList = UsesWare(line), Uses(line, "items") and true or false
        if (wantsWare or wantsList) and #offer == 0 then
            why = why or NoStockWhy()
        elseif Uses(line, "shop") and shop == "" then
            why = why or "the shop has no name. Give it one on the Lines tab."
        else
            local fields = { shop = shop }
            local featured = offer[1] and db.wares[offer[1]]
            WareFields(fields, featured)
            local candidates = {}
            if Uses(line, "opener") then
                for _, oi in ipairs(DeckOrder("openers", #openers)) do
                    candidates[#candidates + 1] = { index = oi, raw = openers[oi] }
                end
            end
            candidates[#candidates + 1] = { raw = "" }
            for _, c in ipairs(candidates) do
                local opener, miss = "", nil
                if c.raw ~= "" then opener, miss = Fill(c.raw, fields) end
                if not miss then
                    fields.opener = opener
                    local usedWare = wantsWare or (c.raw ~= "" and UsesWare(c.raw))
                    if wantsList then
                        local parts, best, count = {}, nil, 0
                        for _, wi in ipairs(offer) do
                            local w = db.wares[wi]
                            parts[#parts + 1] = w.link .. " " .. ns.PriceText(w.price, "short")
                            fields.items = table.concat(parts, ", ")
                            local text, m = Fill(line, fields)
                            if m then
                                why = why or ("the ad line uses {" .. m .. "}, which has nothing to fill it.")
                                break
                            end
                            if c.raw == "" then text = NoLead(text) end
                            if #text > CHAT_LIMIT then break end
                            best, count = text, #parts
                        end
                        fields.items = nil
                        if best then
                            return { text = best, kind = "line", line = li, opener = c.index, ware = usedWare and offer[1] or nil,
                                     last = offer[max(count, usedWare and 1 or 0)], wares = count }
                        end
                    else
                        local text, m = Fill(line, fields)
                        if m then
                            why = why or ("the ad line uses {" .. m .. "}, which has nothing to fill it.")
                            break
                        end
                        if c.raw == "" then text = NoLead(text) end
                        if #text <= CHAT_LIMIT then
                            return { text = text, kind = "line", line = li, opener = c.index, ware = usedWare and offer[1] or nil,
                                     last = usedWare and offer[1] or nil, wares = usedWare and 1 or 0 }
                        end
                    end
                end
            end
            why = why or ("every ad line is too long for one chat message (" .. CHAT_LIMIT .. " letters, and an item "
                .. "link counts about 60 more than its name). Shorten them on the Lines tab.")
        end
    end
    return nil, why
end

-- "items": a piece with ready-made ads always uses them. "mixed": a ready-made ad, then one of
-- your lines, by turns. "mine": only your lines. Whatever is tried first, the other kind is the
-- fallback, so a ware without ready-made ads still gets your lines and the other way round.
local function Compose()
    if not db then return nil, "not ready yet." end
    local offer = Offer()
    local shop = Trim(db.shop)
    local wording = db.wording
    local itemFirst = wording == "items" or (wording == "mixed" and db.lastKind ~= "item")
    if wording ~= "mine" and itemFirst then
        local p = ComposeItemAd(offer, shop)
        if p then return p end
    end
    local p, why = ComposeLine(offer, shop)
    if p then return p end
    if wording == "mixed" and not itemFirst then
        local q = ComposeItemAd(offer, shop)
        if q then return q end
    end
    return nil, why
end

-- The next ad: { text, line, opener, ware, last, wares } or nil and why not.
function ns.Next()
    if not plan then plan, planWhy = Compose() end
    return plan, planWhy
end

local function Commit(p)
    if p.kind == "item" then
        DeckTake(p.deck, p.decks, p.ad)
    else
        DeckTake("lines", #db.lines, p.line)
        if p.opener then DeckTake("openers", #db.openers, p.opener) end
    end
    db.lastKind = p.kind
    if p.last then db.lastWare = p.last end
    db.feature = nil
    plan, planWhy = nil, nil
end

-- Another ad for the same ware: the one shown is put aside (it comes round again later) and the
-- ware keeps its turn.
function ns.Reroll()
    local p = ns.Next()
    if not p then return false end
    if p.kind == "item" then
        DeckTake(p.deck, p.decks, p.ad)
    else
        DeckTake("lines", #db.lines, p.line)
        if p.opener then DeckTake("openers", #db.openers, p.opener) end
    end
    if p.ware and db.order == "random" then db.feature = p.ware end
    plan, planWhy = nil, nil
    Changed()
    return true
end

function ns.Skip()
    local p = ns.Next()
    if p then Commit(p) end
    Changed()
    return p ~= nil
end

-- Your verdict on the ad that is up next, then on to the one after it. "No" takes a ready-made ad
-- out of your ads for good (for every piece that shares it). Your own ad lines are yours to edit,
-- so for them this is only a skip. Returns whether there was an ad, and whether the vote counted.
function ns.Vote(good)
    local p = ns.Next()
    if not p then return false, false end
    local counted = p.src ~= nil
    if counted then db.votes[p.src] = good and "yes" or "no" end
    Commit(p)
    Changed()
    return true, counted
end

function ns.VoteCounts()
    local yes, no = 0, 0
    for _, v in pairs(db.votes) do
        if v == "yes" then yes = yes + 1 else no = no + 1 end
    end
    return yes, no
end

function ns.ClearVotes()
    db.votes = {}
    Changed()
end

---------------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------------
local FIXED = {
    { key = "SAY", label = "Say" },
    { key = "YELL", label = "Yell" },
    { key = "GUILD", label = "Guild" },
    { key = "TURNS", label = "Trade and Yell by turns" },
}
ns.FIXED_CHANNELS = FIXED
-- "TURNS": one ad to Trade, the next to Yell, and so on (SuccuDev: "maybe we should cycle channels
-- between trade and yell"). Outside a capital city, where there is no Trade, every ad goes to Yell.
local TURNS = { "Trade", "YELL" }

local function Base(name)
    name = tostring(name or ""):lower()
    return Trim(name:match("^(.-) %- ") or name)
end

local function Joined()
    local out = {}
    if type(GetChannelList) ~= "function" then return out end
    local ok, list = pcall(function() return { GetChannelList() } end)
    if not ok or type(list) ~= "table" then return out end
    for i = 1, #list, 3 do
        local id, name, disabled = list[i], list[i + 1], list[i + 2]
        if Readable(id) and Readable(name) and type(name) == "string" then
            out[#out + 1] = { id = id, name = name, disabled = disabled and true or false }
        end
    end
    return out
end
ns.JoinedChannels = Joined

function ns.ChannelLabel(key)
    for _, c in ipairs(FIXED) do
        if c.key == key then return c.label end
    end
    return tostring(key)
end

-- chatType, channel number, label; or nil and why not.
function ns.ResolveChannel(key)
    key = key or db.channel
    if key == "TURNS" then
        local at = (tonumber(db and db.turn) or 1) == 2 and 2 or 1
        local chatType, id, label = ns.ResolveChannel(TURNS[at])
        if chatType then return chatType, id, label end
        return ns.ResolveChannel(TURNS[3 - at])
    end
    if key == "SAY" or key == "YELL" then return key, nil, ns.ChannelLabel(key) end
    if key == "GUILD" then
        if type(IsInGuild) == "function" and not IsInGuild() then return nil, "you are not in a guild." end
        return "GUILD", nil, "Guild"
    end
    local want = Base(key)
    local TRADE = "you are not in the Trade channel here. Trade only works in a capital city; pick another channel in the shop window."
    for _, c in ipairs(Joined()) do
        if Base(c.name) == want then
            if c.disabled then
                if want == "trade" then return nil, TRADE end
                return nil, ("the %s channel is switched off here."):format(c.name)
            end
            return "CHANNEL", c.id, c.name
        end
    end
    if want == "trade" then return nil, TRADE end
    return nil, ("you are not in the %s channel here. Join it (/join %s) or pick another channel in the shop window."):format(key, key)
end

---------------------------------------------------------------------------
-- Posting
---------------------------------------------------------------------------
ns.lastPostAt = nil
local awaiting                  -- the ad we wait to see come back in chat
local remindToken = 0

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function Log(channel, text, result)
    local entry = { t = type(time) == "function" and time() or 0, ch = tostring(channel),
                    text = Plain(text):sub(1, 120), res = result }
    table.insert(db.log, entry)
    while #db.log > LOG_MAX do table.remove(db.log, 1) end
    return entry
end

function ns.Wait()
    if not (db and ns.lastPostAt and db.gap and db.gap > 0) then return 0 end
    return max(0, db.gap - (Now() - ns.lastPostAt))
end

-- The shop's alerts are heard with the game in the background too (SuccuDev: "can you make sure the
-- sound is system wide"): they play on the Master channel, so the effects slider and its mute don't
-- hide them, and the first one turns on the game's "Sound in Background" if it is off.
local bgChecked = false
local function Background()
    if bgChecked then return end
    bgChecked = true
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(get) ~= "function" or type(set) ~= "function" then return end
    local ok, v = pcall(get, "Sound_EnableSoundWhenGameIsInBG")
    if ok and ns.Readable(v) and tostring(v) == "0" and pcall(set, "Sound_EnableSoundWhenGameIsInBG", "1") then
        ns.Print("turned on Sound in Background (System, Sound), so the shop's alerts reach you with the game in the background.")
    end
end

function ns.AlertSound(kit, fallback)
    if type(PlaySound) ~= "function" then return end
    Background()
    if not pcall(PlaySound, kit or fallback, "Master") then pcall(PlaySound, kit or fallback) end
end
local function Sound(kit, fallback) ns.AlertSound(kit, fallback) end

-- The prompt waits for the end of a fight: a window in the middle of the screen has no place in one.
local function ShowPrompt(token)
    if token ~= remindToken then return end
    -- the counter is up: its Post button lights up instead of a window in the middle of the screen
    if ns.Counter and ns.Counter.IsShown and ns.Counter.IsShown() then
        pcall(ns.Counter.Remind)
        return
    end
    if not db.prompt then return end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        C_Timer.After(3, function() ShowPrompt(token) end)
        return
    end
    if ns.UI and ns.UI.ShowPrompt then pcall(ns.UI.ShowPrompt) end
end

local function ScheduleReminder()
    remindToken = remindToken + 1
    local token = remindToken
    if not (db.remind and db.remind > 0) then return end
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(db.remind * 60, function()
        if token ~= remindToken then return end
        Print(("time for another ad for %s: click the minimap button, press your key or type /slutshop post.")
            :format(ns.ShopName()))
        if db.sound then Sound(SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3, 12867) end
        ShowPrompt(token)
    end)
end
ns.Snooze = ScheduleReminder

local function EchoMissed(sent)
    if awaiting ~= sent then return end
    awaiting = nil
    if sent.entry then sent.entry.res = "not seen" end
    Print(("your ad did not show up in %s. The game may have refused it without a word (it does that with a "
        .. "broken item link, or while you are silenced). The ad was: %s"):format(sent.label, sent.plain))
end

-- Posts the next ad. Call it only from a click, a key press or a slash command.
function ns.Post()
    if ns.Recheck then ns.Recheck() end
    if not db then return false end
    local wait = ns.Wait()
    if wait > 0 then
        Print(("next ad in %d sec. (Shortest gap between ads: %d sec, in the options.)"):format(math.ceil(wait), db.gap))
        return false
    end
    local p, why = ns.Next()
    if not p then
        Print("nothing to post: " .. tostring(why))
        return false
    end
    local chatType, id, label = ns.ResolveChannel(db.channel)
    if not chatType then
        Print(tostring(id))
        return false
    end
    if C_ChatInfo and type(C_ChatInfo.InChatMessagingLockdown) == "function" then
        local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
        if ok and Readable(locked) and locked then
            Print("the game holds back chat from addons right now (a boss fight or a timed run). Try again after it.")
            return false
        end
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then
        Print("this client has no way to send chat lines.")
        return false
    end
    local sent = { plain = Plain(p.text), label = label, text = p.text }
    awaiting = sent                     -- before sending: the line can come back at once
    local ok, err = pcall(send, p.text, chatType, nil, id)
    if not ok then
        if awaiting == sent then awaiting = nil end
        Log(label, p.text, "refused: " .. tostring(err))
        Print("the game refused the ad: " .. tostring(err))
        return false
    end
    ns.lastPostAt = Now()
    if db.channel == "TURNS" then db.turn = chatType == "YELL" and 1 or 2 end      -- the other one next
    db.posts = (db.posts or 0) + 1
    if ns.Stat then ns.Stat("ads") end      -- the counter's numbers (Mailbox Slutting)
    if ns.Counter and ns.Counter.Posted then pcall(ns.Counter.Posted) end
    if p.src then db.sent[p.src] = (tonumber(db.sent[p.src]) or 0) + 1 end
    sent.entry = Log(label, p.text, awaiting == sent and "sent" or "seen")
    Commit(p)
    if ns.UI and ns.UI.HidePrompt then pcall(ns.UI.HidePrompt) end
    ScheduleReminder()
    if awaiting == sent and C_Timer and C_Timer.After then
        C_Timer.After(ECHO_WAIT, function() EchoMissed(sent) end)
    end
    Changed()
    return true
end

-- Our own line coming back in chat proves it went out.
local function OnChat(text, guid)
    if not awaiting then return end
    local mine = false
    if Readable(guid) and type(UnitGUID) == "function" then
        local ok, me = pcall(UnitGUID, "player")
        if ok and Readable(me) and guid == me then mine = true end
    end
    if not mine and Readable(text) and type(text) == "string" and Plain(text) == awaiting.plain then mine = true end
    if not mine then return end
    if awaiting.entry then awaiting.entry.res = "seen" end
    awaiting = nil
end

function ns.Preview()
    local p, why = ns.Next()
    if not p then
        Print("nothing to post: " .. tostring(why))
        return
    end
    local _, _, label = ns.ResolveChannel(db.channel)
    Print(("next ad (%d/%d letters) to %s:"):format(#p.text, CHAT_LIMIT, label or ns.ChannelLabel(db.channel)))
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(p.text) end
end

---------------------------------------------------------------------------
-- Status (minimap tooltip, /slutshop status)
---------------------------------------------------------------------------
function ns.StatusLines()
    if not db then return {} end
    local inStock, loaded = 0, 0
    for _, w in ipairs(db.wares) do
        if w.link then loaded = loaded + 1 end
        if w.link and InStock(w) then inStock = inStock + 1 end
    end
    local lines = {
        "Shop: " .. ns.ShopName(),
        ("Wares: %d, %d of them in stock"):format(#db.wares, inStock),
        "Posting to: " .. ns.ChannelLabel(db.channel),
    }
    local ready = 0
    for _, w in ipairs(db.wares) do
        if ns.ItemAds(w.id) then ready = ready + 1 end
    end
    lines[#lines + 1] = db.wording == "mine" and "Ads: your own lines only"
        or ("Ready-made ads: for %d of your %d wares%s"):format(ready, #db.wares, db.wording == "mixed" and ", by turns with your lines" or "")
    local wait = ns.Wait()
    if wait > 0 then
        lines[#lines + 1] = ("Next ad in %d sec"):format(math.ceil(wait))
    else
        local p, why = ns.Next()
        lines[#lines + 1] = p and "Next ad: ready" or ("Next ad: " .. tostring(why))
    end
    lines[#lines + 1] = ("Ads posted: %d"):format(db.posts or 0)
    return lines
end

---------------------------------------------------------------------------
-- Shift-click an item while the shop window is open: it goes on the window's slot
---------------------------------------------------------------------------
local hooked = false
local function HookLinks()
    if hooked or type(hooksecurefunc) ~= "function" then return end
    local function Take(text)
        if ns.UI and ns.UI.TakeLink then pcall(ns.UI.TakeLink, text) end
    end
    if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.InsertLink) == "function" then
        hooked = pcall(hooksecurefunc, ChatFrameUtil, "InsertLink", Take)
    elseif type(ChatEdit_InsertLink) == "function" then
        hooked = pcall(hooksecurefunc, "ChatEdit_InsertLink", Take)
    end
end

---------------------------------------------------------------------------
-- Slash command, key bindings, addon list
---------------------------------------------------------------------------
local function ToggleWindow()
    if ns.UI and ns.UI.Toggle then
        ns.UI.Toggle()
    else
        Print("the shop window did not load. Type /reload once so the game finds the addon's files.")
    end
end
ns.ToggleWindow = ToggleWindow

local function OpenOptions()
    if ns.Kit and ns.Kit.Open then ns.Kit.Open() else Print("the options did not load. Type /reload once.") end
end
ns.OpenOptions = OpenOptions

local function PrintHelp()
    Print("commands:")
    local lines = {
        "/slutshop - open or close the shop window",
        "/slutshop post - post the next ad (works in a macro and from a key: Key Bindings > AddOns)",
        "/slutshop skip - pick another ad without posting",
        "/slutshop yes, /slutshop no - say whether the next ad is a good line; no drops it from your ads for good",
        "/slutshop votes - the lines you voted on (/slutshop votes reset forgets them)",
        "/slutshop preview - show the next ad in your own chat",
        "/slutshop add [item link] 10g - add a ware or change its price (shift-click the item to link it)",
        "/slutshop remove [item link] - stop selling it",
        "/slutshop list - your wares",
        "/slutshop scan - look through your bags for pieces from the slutmog list and put them on the shelf",
        "/slutshop ads [item link] - the ready-made ads for a piece (without a link: which wares have them)",
        "/slutshop set [top] [bottom] - sell two of your wares as a set, one ad for both (/slutshop unset [item] undoes it)",
        "/slutshop reroll - another ad for the same ware",
        "/slutshop prompt - the Post button in the middle of the screen, now",
        "/slutshop mailbox - start or stop dancing on the mailbox (the Mailbox Slutting addon; /smog mailbox and /mailslut open work too)",
        "/slutshop channel Trade - where ads go (Say, Yell, Guild, any channel you are in, or turns: Trade and Yell by turns)",
        "/slutshop options - the options",
        "/slutshop status - what the shop is set to",
    }
    for _, l in ipairs(lines) do
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
    end
end

-- The first item link in a line, with its colour code (|cffRRGGBB or |cnIQ2:) when it has one.
local function LinkIn(msg)
    local link = msg:match("(|c[^|]*|Hitem:.-|h.-|h|r)") or msg:match("(|Hitem:.-|h.-|h)")
    if not link then return nil, msg end
    local s, e = msg:find(link, 1, true)
    return link, Trim(msg:sub(1, s - 1) .. " " .. msg:sub(e + 1))
end

local function WareByWords(rest)
    local link, left = LinkIn(rest)
    if link then return ns.FindWare(link) end
    local n = tonumber(left)
    if n and db.wares[n] then return n, db.wares[n] end
    local want = Trim(left):lower()
    if want == "" then return nil end
    for i, w in ipairs(db.wares) do
        if ns.WareName(w):lower() == want then return i, w end
    end
end

local function Say(line)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage(line) end
end

-- /slutshop ads: which wares have ready-made ads. /slutshop ads [item] (or a ware's number or
-- name): that piece's ads, filled in as they would go out.
local function ShowAds(rest)
    if Trim(rest) == "" then
        local with, without = 0, {}
        for _, w in ipairs(db.wares) do
            if ns.ItemAds(w.id) then with = with + 1 else without[#without + 1] = w.link or ns.WareName(w) end
        end
        Print(("ready-made ads for %d of your %d wares (%d pieces on the slutmog list have them)."):format(with, #db.wares, ns.ItemAdCount()))
        if #without > 0 then Say("  Your own ad lines speak for: " .. table.concat(without, ", ")) end
        if db.wording == "mine" then Say("  They are switched off: Options > Which ads.") end
        Say("  /slutshop ads [item] shows a piece's ads.")
        return
    end
    local link = LinkIn(rest)
    local _, w
    if link then _, w = ns.FindWare(link) else _, w = WareByWords(rest) end
    local id = (w and w.id) or ns.ItemID(link)
    if not id then
        Print("shift-click the item into the command: /slutshop ads [item]")
        return
    end
    local shown = (w and w.link) or link or ("[" .. ns.WareName(w) .. "]")
    local ads = ns.ItemAds(id)
    if not ads then
        Print(("no ready-made ads for %s; your own ad lines speak for it."):format(shown))
        return
    end
    local fields = { shop = ns.ShopName(), item = shown, price = w and not w.unpriced and ns.PriceText(w.price) or "(your price)",
                     level = LevelOf({ link = (w and w.link) or link, id = id }) or "?" }
    Print(("%d ready-made ads for %s:"):format(#ads, shown))
    local where = w and ns.Where(w) or "bags"
    for k, ad in ipairs(ads) do Say(("  %d. %s"):format(k, Ended(ad, fields, where, k) or (Fill(ad, fields)))) end
end

local function Slash(msg)
    if not db then return end
    msg = Trim(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ToggleWindow()
    elseif cmd == "post" or cmd == "ad" then
        ns.Post()
    elseif cmd == "set" or cmd == "unset" then
        local found = {}
        for link in rest:gmatch("|H(item:[^|]+)|h") do
            local i = ns.FindWare(link)
            if i then found[#found + 1] = i end
        end
        if cmd == "unset" and found[1] and ns.Unpair(found[1]) then
            Print((db.wares[found[1]].link or "it") .. " is sold on its own again.")
        elseif cmd == "set" and found[1] and found[2] and ns.PairWares(found[1], found[2]) then
            local j = ns.SetWith(found[1])
            Print(("%s and %s are sold as a set now."):format(db.wares[found[1]].link, db.wares[j].link))
        elseif cmd == "set" then
            Print("shift-click two of your wares into the command: /slutshop set [top] [bottom]")
        else
            Print("shift-click a ware that is part of a set into the command: /slutshop unset [item]")
        end
    elseif cmd == "mailbox" then
        if ns.Mailbox then ns.Mailbox.Toggle() else Print(MAIL_MISSING) end
    elseif cmd == "counter" then
        if ns.Counter then ns.Counter.Toggle() else Print(MAIL_MISSING) end
    elseif cmd == "prompt" then
        if not (ns.UI and ns.UI.ShowPrompt and ns.UI.ShowPrompt(true)) then
            Print("nothing to post: " .. tostring(select(2, ns.Next())))
        end
    elseif cmd == "reroll" then
        if ns.Reroll() then ns.Preview() else Print("nothing to post: " .. tostring(select(2, ns.Next()))) end
    elseif cmd == "skip" or cmd == "next" then
        if ns.Skip() then ns.Preview() else Print("nothing to post: " .. tostring(select(2, ns.Next()))) end
    elseif cmd == "preview" or cmd == "test" then
        ns.Preview()
    elseif cmd == "yes" or cmd == "no" then
        local p = ns.Next()
        local had, counted = ns.Vote(cmd == "yes")
        if not had then
            Print("nothing to vote on: " .. tostring(select(2, ns.Next())))
        elseif not counted then
            Print("that one is your own ad line (edit it on the Lines tab). Skipped.")
        elseif cmd == "yes" then
            Print("kept as a good line: " .. p.src)
        else
            Print("dropped from your ads: " .. p.src)
        end
    elseif cmd == "votes" then
        if rest:lower() == "reset" then
            ns.ClearVotes()
            Print("votes forgotten; every ready-made ad is back.")
            return
        end
        local yes, no = ns.VoteCounts()
        Print(("%d good, %d dropped."):format(yes, no))
        for _, want in ipairs({ "yes", "no" }) do
            local list = {}
            for ad, v in pairs(db.votes) do if v == want then list[#list + 1] = ad end end
            table.sort(list)
            for _, ad in ipairs(list) do Say(("  %s: %s"):format(want == "yes" and "good" or "dropped", ad)) end
        end
    elseif cmd == "add" or cmd == "price" then
        local link, left = LinkIn(rest)
        if not link then
            Print("shift-click the item into the command: /slutshop add [item] 10g")
            return
        end
        local copper = ns.ParsePrice(left)
        if not copper then
            Print("give it a price after the link, like 10g, 2g 50s or 75s.")
            return
        end
        local _, text = ns.AddWare(link, copper)
        Print(text)
    elseif cmd == "remove" or cmd == "del" or cmd == "delete" then
        local i, w = WareByWords(rest)
        if not i then
            Print("that is not one of your wares. /slutshop list shows them.")
            return
        end
        ns.RemoveWare(i)
        Print((w.link or ns.WareName(w)) .. " is no longer for sale.")
    elseif cmd == "list" or cmd == "wares" then
        if #db.wares == 0 then
            Print("no wares yet. /slutshop opens the shop window; drop an item on its slot.")
            return
        end
        Print("your wares:")
        for i, w in ipairs(db.wares) do
            local n = ns.Count(w)
            local stock = n == nil and "" or (n > 0 and (" (" .. n .. " in stock"
                    .. (ns.WareUndercut(w) and ", cheaper on the auction house, not advertised)" or ")"))
                or (ns.Undercut(w.id) and " (undercut on the auction house, not advertised)"
                    or (ns.OnAH(w.id) and " (on the auction house)" or " (none left)")))
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(("  %d. %s %s%s"):format(i, w.link or ns.WareName(w),
                    w.unpriced and "no price yet" or ns.PriceText(w.price), stock))
            end
        end
    elseif cmd == "channel" then
        if rest == "" then
            Print("ads go to " .. ns.ChannelLabel(db.channel) .. ".")
            return
        end
        local up = rest:upper()
        if up == "BOTH" or up == "TRADE YELL" or up == "TRADE AND YELL" then up = "TURNS" end
        local key = (up == "SAY" or up == "YELL" or up == "GUILD" or up == "TURNS") and up or rest
        ns.Set("channel", key)
        local ok, why = ns.ResolveChannel(key)
        Print("ads go to " .. ns.ChannelLabel(key) .. "." .. (ok and "" or (" Right now " .. tostring(why))))
    elseif cmd == "scan" or cmd == "bags" then
        if ns.ScanBags(true) == 0 then
            Print(ns.ItemAdCount() == 0 and "the slutmog list did not load, so there is nothing to look for."
                or "nothing new in your bags: every piece from the slutmog list in them is on the shelf already.")
        end
    elseif cmd == "ads" then
        ShowAds(rest)
    elseif cmd == "options" or cmd == "config" then
        OpenOptions()
    elseif cmd == "status" then
        for _, l in ipairs(ns.StatusLines()) do Print(l) end
    else
        PrintHelp()
    end
end
ns.Slash = Slash

SLASH_SLUTMOGSHOP1 = "/slutshop"
SLASH_SLUTMOGSHOP2 = "/mogshop"
SLASH_SLUTMOGSHOP3 = "/smogshop"
-- Only a key of SlashCmdList: assigning the global itself taints every slash command (/tm, /invite).
SlashCmdList.SLUTMOGSHOP = function(msg) Slash(msg or "") end

-- /smog is Slutmog Scout's command, and it is what people type for anything slutmog (SuccuDev,
-- 2026-11-15: "smog mailbox isnt doing anything"). Scout has no "mailbox" or "shop" word and stays
-- silent on them, so those two come here; everything else goes to Scout as before.
local scoutHooked
function ns.HookScout()
    local theirs = SlashCmdList.SLUTMOGSCOUT
    if scoutHooked or type(theirs) ~= "function" then return false end
    scoutHooked = true
    SlashCmdList.SLUTMOGSCOUT = function(input, ...)
        local cmd, rest = tostring(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
        cmd = (cmd or ""):lower()
        if cmd == "mailbox" then return Slash("mailbox") end
        if cmd == "shop" then return Slash(rest or "") end
        return theirs(input, ...)
    end
    return true
end

BINDING_HEADER_SLUTMOGSHOP = "Slutmog Shop"
BINDING_NAME_SLUTMOGSHOP_POST = "Post the next ad"
BINDING_NAME_SLUTMOGSHOP_TOGGLE = "Open or close the shop window"
-- The tips went to Mailbox Slutting; the key you bound here keeps working.
BINDING_NAME_SLUTMOGSHOP_ACCEPTTIP = "Accept a tip (Mailbox Slutting does it)"
function SlutmogShop_AcceptTip()
    if ns.Tips and ns.Tips.Accept then ns.Tips.Accept() end
end

function SlutmogShop_Post() ns.Post() end
function SlutmogShop_Toggle() ToggleWindow() end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local stockSeen
local function StockKey()
    local parts = {}
    for i, w in ipairs(db.wares) do parts[i] = InStock(w) and ns.Where(w):sub(1, 1) or (ns.WareUndercut(w) and "u" or "0") end
    return table.concat(parts)
end

-- Stock can change without an event of ours (Slutmog Scout reads a lower price: undercut), so
-- the window asks now and then, and so does a post.
function ns.Recheck()
    if not db then return end
    local now = StockKey()
    if now ~= stockSeen then
        stockSeen = now
        Changed()
    end
end

local events = CreateFrame("Frame")
ns.events = events
-- One event this client does not know must not stop the rest from registering.
for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED", "AUCTION_OWNED_LIST_UPDATE",
                      "OWNED_AUCTIONS_UPDATED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_AUCTION_CREATED",
                      "AUCTION_HOUSE_CLOSED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
                      "CHANNEL_UI_UPDATE", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD" }) do
    pcall(events.RegisterEvent, events, ev)
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then InitDB() end
    elseif event == "PLAYER_LOGIN" then
        if not db then InitDB() end
        FillLinks()
        HookLinks()
        ns.ScanBags()
        stockSeen = StockKey()
        if ns.Options and ns.Kit then
            local ok, err = pcall(ns.Options.Init)
            if not ok then Print("the options did not start: " .. tostring(err)) end
        end
        if ns.UI and ns.UI.ListLooks then pcall(ns.UI.ListLooks) end
        pcall(ns.HookScout)
    elseif not db then
        return
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local id = ...
        if pending[id] then pending[id] = nil; FillLinks() end
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.ScanBags()
        local now = StockKey()
        if now ~= stockSeen then
            stockSeen = now
            Changed()
        elseif ns.UI and ns.UI.RefreshStock then
            pcall(ns.UI.RefreshStock)
        end
    elseif event == "AUCTION_OWNED_LIST_UPDATE" or event == "OWNED_AUCTIONS_UPDATED" then
        ns.ScanAuctions()
        stockSeen = StockKey()
    elseif event == "AUCTION_HOUSE_SHOW" or event == "AUCTION_HOUSE_AUCTION_CREATED" then
        ns.MarketState.open = true
        ns.AskAuctions()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ns.MarketState.open, ns.MarketState.searching, ns.MarketState.queue = false, nil, {}
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        ns.MarketRead((...))
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        ns.MarketStep()
    elseif event == "CHANNEL_UI_UPDATE" then
        Changed()
    else
        local text = ...
        local guid = select(12, ...)
        OnChat(text, guid)
    end
end)
