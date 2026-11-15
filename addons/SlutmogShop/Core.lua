-- Slutmog Shop: shop ads for your slutmog wares, one click each.
--
-- You keep a list of wares (an item and its price), some openers and some ad lines. Each
-- click posts one ad to the channel you picked (Trade to start with): an ad line with a
-- fresh opener, your shop's name and the next ware as a real item link with its price, for
-- example
--   Hit your 40s and the gentlemen don't stare like they used to? ~ Smuttanie's Necessities ~
--   NOW OPEN for all your mogging needs! [Tyrant's Legplates] only 10 gold pieces.
--
-- The game lets a line go to Trade or General only from a click or a key press, so the addon
-- never posts by itself. One ad goes out per click on the minimap button or the window's
-- Post button, per press of your key (Key Bindings > AddOns) or per /slutshop post (a macro
-- works too). A reminder in your own chat says when it is time for the next one.
local ADDON, ns = ...

ns.VERSION = "1.0.0"
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

ns.DEFAULT_LINES = {
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
    stockOnly = true,       -- skip wares that are in neither your bags nor your bank
    order = "turns",        -- wares take turns ("turns") or come at random ("random")
    prices = "words",       -- "10 gold pieces" ("words") or "10g" ("short")
}
ns.DEFAULTS = DEFAULTS

local KNOWN = { opener = true, shop = true, item = true, price = true, items = true, level = true }
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

-- The text as people read it: colours dropped, links reduced to their [Name].
local function Plain(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return text
end
ns.Plain = Plain

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
    db.openers = CleanList(db.openers, ns.DEFAULT_OPENERS)
    db.lines = CleanList(db.lines, ns.DEFAULT_LINES)
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
            kept[#kept + 1] = w
        end
    end
    db.wares = kept
    if type(db.decks) ~= "table" then db.decks = {} end
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
    db.decks = {}
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
function ns.Count(w)
    if not (w and w.id) then return nil end
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(fn) ~= "function" then return nil end
    local ok, n = pcall(fn, w.id, true)
    if ok and Readable(n) and type(n) == "number" then return n end
    return nil
end

local function InStock(w)
    local n = ns.Count(w)
    return n == nil or n > 0
end
ns.InStock = InStock

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
    if w then
        w.link, w.id, w.price = link, id, copper
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
        if w.link and (not db.stockOnly or InStock(w)) then list[#list + 1] = i end
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
    fields.price = ns.PriceText(w.price)
    fields.level = LevelOf(w)
end

local function NoStockWhy()
    if #db.wares == 0 then
        return "you have no wares yet. Drop an item on the slot in the shop window (/slutshop)."
    end
    if db.stockOnly then
        return "none of your wares is in your bags or bank (untick \"Only wares I still have\" in the options to advertise them anyway)."
    end
    return "the game has not loaded your wares' item links yet. Try again in a moment."
end

local function Compose()
    if not db then return nil, "not ready yet." end
    local lines, openers = db.lines, db.openers
    if #lines == 0 then return nil, "there is no ad line. Write one on the Lines tab of the shop window." end
    local offer = Offer()
    local shop = Trim(db.shop)
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
                            return { text = best, line = li, opener = c.index, ware = usedWare and offer[1] or nil,
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
                            return { text = text, line = li, opener = c.index, ware = usedWare and offer[1] or nil,
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

-- The next ad: { text, line, opener, ware, last, wares } or nil and why not.
function ns.Next()
    if not plan then plan, planWhy = Compose() end
    return plan, planWhy
end

local function Commit(p)
    DeckTake("lines", #db.lines, p.line)
    if p.opener then DeckTake("openers", #db.openers, p.opener) end
    if p.last then db.lastWare = p.last end
    db.feature = nil
    plan, planWhy = nil, nil
end

function ns.Skip()
    local p = ns.Next()
    if p then Commit(p) end
    Changed()
    return p ~= nil
end

---------------------------------------------------------------------------
-- Channels
---------------------------------------------------------------------------
local FIXED = {
    { key = "SAY", label = "Say" },
    { key = "YELL", label = "Yell" },
    { key = "GUILD", label = "Guild" },
}
ns.FIXED_CHANNELS = FIXED

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

local function Sound(kit, fallback)
    if type(PlaySound) ~= "function" then return end
    pcall(PlaySound, kit or fallback)
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
    end)
end

local function EchoMissed(sent)
    if awaiting ~= sent then return end
    awaiting = nil
    if sent.entry then sent.entry.res = "not seen" end
    Print(("your ad did not show up in %s. The game may have refused it without a word (it does that with a "
        .. "broken item link, or while you are silenced). The ad was: %s"):format(sent.label, sent.plain))
end

-- Posts the next ad. Call it only from a click, a key press or a slash command.
function ns.Post()
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
    db.posts = (db.posts or 0) + 1
    sent.entry = Log(label, p.text, awaiting == sent and "sent" or "seen")
    Commit(p)
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
        Print("the shop window did not load. Restart the game once so it finds the addon's files.")
    end
end
ns.ToggleWindow = ToggleWindow

local function OpenOptions()
    if ns.Kit and ns.Kit.Open then ns.Kit.Open() else Print("the options did not load. Restart the game once.") end
end
ns.OpenOptions = OpenOptions

local function PrintHelp()
    Print("commands:")
    local lines = {
        "/slutshop - open or close the shop window",
        "/slutshop post - post the next ad (works in a macro and from a key: Key Bindings > AddOns)",
        "/slutshop skip - pick another ad without posting",
        "/slutshop preview - show the next ad in your own chat",
        "/slutshop add [item link] 10g - add a ware or change its price (shift-click the item to link it)",
        "/slutshop remove [item link] - stop selling it",
        "/slutshop list - your wares",
        "/slutshop channel Trade - where ads go (Say, Yell, Guild or any channel you are in)",
        "/slutshop options - the options",
        "/slutshop status - what the shop is set to",
    }
    for _, l in ipairs(lines) do
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then DEFAULT_CHAT_FRAME:AddMessage("  " .. l) end
    end
end

local function LinkIn(msg)
    local link = msg:match("(|c%x+|Hitem:.-|h.-|h|r)") or msg:match("(|Hitem:.-|h.-|h)")
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

local function Slash(msg)
    if not db then return end
    msg = Trim(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        ToggleWindow()
    elseif cmd == "post" or cmd == "ad" then
        ns.Post()
    elseif cmd == "skip" or cmd == "next" then
        if ns.Skip() then ns.Preview() else Print("nothing to post: " .. tostring(select(2, ns.Next()))) end
    elseif cmd == "preview" or cmd == "test" then
        ns.Preview()
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
            local stock = n == nil and "" or (n > 0 and (" (" .. n .. " in stock)") or " (none left)")
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage(("  %d. %s %s%s"):format(i, w.link or ns.WareName(w), ns.PriceText(w.price), stock))
            end
        end
    elseif cmd == "channel" then
        if rest == "" then
            Print("ads go to " .. ns.ChannelLabel(db.channel) .. ".")
            return
        end
        local up = rest:upper()
        local key = (up == "SAY" or up == "YELL" or up == "GUILD") and up or rest
        ns.Set("channel", key)
        local ok, why = ns.ResolveChannel(key)
        Print("ads go to " .. ns.ChannelLabel(key) .. "." .. (ok and "" or (" Right now " .. tostring(why))))
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
SlashCmdList = SlashCmdList or {}
SlashCmdList.SLUTMOGSHOP = function(msg) Slash(msg or "") end

BINDING_HEADER_SLUTMOGSHOP = "Slutmog Shop"
BINDING_NAME_SLUTMOGSHOP_POST = "Post the next ad"
BINDING_NAME_SLUTMOGSHOP_TOGGLE = "Open or close the shop window"

function SlutmogShop_Post() ns.Post() end
function SlutmogShop_Toggle() ToggleWindow() end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local stockSeen
local function StockKey()
    local parts = {}
    for i, w in ipairs(db.wares) do parts[i] = InStock(w) and "1" or "0" end
    return table.concat(parts)
end

local events = CreateFrame("Frame")
ns.events = events
-- One event this client does not know must not stop the rest from registering.
for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "GET_ITEM_INFO_RECEIVED", "BAG_UPDATE_DELAYED",
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
        stockSeen = StockKey()
        if ns.Options and ns.Kit then
            local ok, err = pcall(ns.Options.Init)
            if not ok then Print("the options did not start: " .. tostring(err)) end
        end
        if ns.UI and ns.UI.ListLooks then pcall(ns.UI.ListLooks) end
    elseif not db then
        return
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        local id = ...
        if pending[id] then pending[id] = nil; FillLinks() end
    elseif event == "BAG_UPDATE_DELAYED" then
        local now = StockKey()
        if now ~= stockSeen then
            stockSeen = now
            Changed()
        elseif ns.UI and ns.UI.RefreshStock then
            pcall(ns.UI.RefreshStock)
        end
    elseif event == "CHANNEL_UI_UPDATE" then
        Changed()
    else
        local text = ...
        local guid = select(12, ...)
        OnChat(text, guid)
    end
end)
