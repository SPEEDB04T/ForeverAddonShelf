-- Mailbox Slutting: for dancing for tips, classic WoW style. The name is from where it started, on a
-- city mailbox; it works wherever you stand, and nothing it shows or sends mentions a mailbox.
--
--   Mailbox.lua  the dance, and the emotes back at whoever looks at you, emotes at you or whispers
--                you; the idle lines, the tip jar lines and the welcome back for your tippers
--   Tips.lua     the Accept tip button under the trade window, and the thank-you
--   Counter.lua  the counter: the window that stays up while you stand there, with your numbers
--   Core.lua     this file: saved data, the numbers and the slash command
--
-- It was part of Slutmog Shop until 1.18.0 (SuccuDev: "can we split off mailbox slutting to its own
-- addon"). The two share nothing now: no ad, no wares and no shop button in here (SuccuDev: "I dont
-- think you properly split it, I still see shop stuff in the mailslut window"). The one thing taken
-- from the shop is what you had saved there (tips, tippers, numbers), copied once.
local ADDON, ns = ...

ns.VERSION = "1.8.0"
ns.TITLE = "Mailbox Slutting"
ns.ICON = "Interface\\Icons\\INV_Letter_15"

local floor, max = math.floor, math.max

local PREFIX = "|cfff58cc7Mailbox Slutting|r: "
function ns.Print(msg)
    local text = PREFIX .. tostring(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end
local Print = ns.Print

function ns.Readable(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return true
end

---------------------------------------------------------------------------
-- Names and money (the same as in Slutmog Shop)
---------------------------------------------------------------------------
-- A unit's whole name, the way chat and whispers know it. On Forever characters have a surname, and
-- UnitName gives it as its second value, where other clients put the realm (SuccuDev: "tip thanks is
-- failing because people have last names too not just first names").
function ns.FullName(unit)
    if type(UnitName) ~= "function" then return nil end
    local ok, name, second = pcall(UnitName, unit)
    if not (ok and ns.Readable(name) and type(name) == "string" and name ~= "") then return nil end
    if not (ns.Readable(second) and type(second) == "string" and second ~= "") then return name end
    local c = Constants and Constants.CharacterNameSeparatorConsts
    local sep = c and c.CHARACTERNAME_SURNAME_SEPARATOR
    return name .. (type(sep) == "string" and sep ~= "" and sep or " ") .. second
end

-- "5 gold pieces", "5 gold and 20 silver": money in words, for a line in chat.
function ns.PriceText(copper, style)
    copper = max(0, floor(tonumber(copper) or 0))
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

-- Coins as the game draws them, for your own windows and chat.
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
-- Saved data
---------------------------------------------------------------------------
local db
local DEFAULTS = {
    sound = true,           -- the AFK warning and a tip play a sound
}

-- What moved here from Slutmog Shop's saved data, copied once (the shop's copy is left alone).
local MOVED = { "tips", "tipCount", "tippers", "stats", "counter", "counterPos", "mailLog", "jarPad" }

local function Deep(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = Deep(x) end
    return out
end

local function Migrate()
    if not db or db.migrated then return end
    local old = rawget(_G, "SlutmogShopDB")
    if type(old) ~= "table" then return end        -- the shop is not there, or not loaded yet
    db.migrated = true
    for _, key in ipairs(MOVED) do
        if db[key] == nil and old[key] ~= nil then db[key] = Deep(old[key]) end
    end
end
ns.Migrate = Migrate

local function InitDB()
    if type(MailboxSluttingDB) ~= "table" then MailboxSluttingDB = {} end
    db = MailboxSluttingDB
    for k, v in pairs(DEFAULTS) do
        if type(db[k]) ~= type(v) then db[k] = v end
    end
    ns.db = db
    Migrate()
end

---------------------------------------------------------------------------
-- The numbers
---------------------------------------------------------------------------
-- Per day (the last 30 kept) and all time. db.stats = { days = { [day] = {...} }, all = {...} }.
-- Keys: tips, tipCopper, visitors, emotes, jar, welcomes, open (seconds you were dancing).
local STAT_DAYS = 30
local function DayKey(t)
    t = t or time()
    if type(date) == "function" then
        local ok, d = pcall(date, "%Y-%m-%d", t)
        if ok and type(d) == "string" then return d end
    end
    return ("%08d"):format(floor(t / 86400))
end

-- Today's numbers and the all-time ones, made if they are not there yet.
local function Today()
    if not db then return nil end
    db.stats = type(db.stats) == "table" and db.stats or {}
    local s = db.stats
    s.days = type(s.days) == "table" and s.days or {}
    s.all = type(s.all) == "table" and s.all or {}
    local d = DayKey()
    if type(s.days[d]) ~= "table" then
        s.days[d] = {}
        local keys = {}
        for k in pairs(s.days) do keys[#keys + 1] = k end
        table.sort(keys)
        for i = 1, #keys - STAT_DAYS do s.days[keys[i]] = nil end
    end
    return s.days[d], s.all
end

function ns.Stat(key, n)
    local day, all = Today()
    if not day then return end
    n = n or 1
    day[key] = (tonumber(day[key]) or 0) + n
    all[key] = (tonumber(all[key]) or 0) + n
end

-- A number that is the biggest so far, not a sum (tipMax: the biggest tip). Its key ends in "Max".
function ns.StatMax(key, n)
    local day, all = Today()
    n = tonumber(n)
    if not (day and n) then return end
    if n > (tonumber(day[key]) or 0) then day[key] = n end
    if n > (tonumber(all[key]) or 0) then all[key] = n end
end

-- days nil: all time; 0: today; n: the last n days, today in.
function ns.Stats(days)
    local s = db and type(db.stats) == "table" and db.stats or {}
    if days == nil then return type(s.all) == "table" and s.all or {} end
    local out, now = {}, time()
    for i = 0, max(0, days - 1) do
        local t = type(s.days) == "table" and s.days[DayKey(now - i * 86400)]
        if type(t) == "table" then
            for k, v in pairs(t) do
                v = tonumber(v) or 0
                if type(k) == "string" and k:find("Max$") then out[k] = max(out[k] or 0, v)
                else out[k] = (out[k] or 0) + v end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Sound
---------------------------------------------------------------------------
-- The alerts are heard with the game in the background too (SuccuDev: "can you make sure the sound
-- is system wide"): they play on the Master channel, and the first one turns on the game's "Sound
-- in Background" if it is off.
local bgChecked = false
local function Background()
    if bgChecked then return end
    bgChecked = true
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if type(get) ~= "function" or type(set) ~= "function" then return end
    local ok, v = pcall(get, "Sound_EnableSoundWhenGameIsInBG")
    if ok and ns.Readable(v) and tostring(v) == "0" and pcall(set, "Sound_EnableSoundWhenGameIsInBG", "1") then
        Print("turned on Sound in Background (System, Sound), so the alerts reach you with the game in the background.")
    end
end

function ns.AlertSound(kit, fallback)
    if type(PlaySound) ~= "function" then return end
    Background()
    if not pcall(PlaySound, kit or fallback, "Master") then pcall(PlaySound, kit or fallback) end
end

---------------------------------------------------------------------------
-- The slash command
---------------------------------------------------------------------------
local function Help()
    Print("version " .. ns.VERSION .. ". /mailslut: the counter on or off. /mailslut open (or close): start or stop dancing. "
        .. "/mailslut stats: your numbers. /mailslut sound: the alert sounds on or off.")
end

local function Slash(msg)
    local cmd = tostring(msg or ""):match("^%s*(%S*)") or ""
    cmd = cmd:lower()
    if not db then
        Print("not loaded yet.")
    elseif cmd == "" or cmd == "counter" then
        if ns.Counter then ns.Counter.Toggle() end
    elseif cmd == "open" or cmd == "close" or cmd == "mailbox" or cmd == "dance" then
        if ns.Mailbox then ns.Mailbox.Toggle() end
    elseif cmd == "stats" then
        local t, all = ns.Stats(0), ns.Stats()
        Print(("today: %d tips, %s. All time: %d tips, %s."):format(tonumber(t.tips) or 0, ns.MoneyText(t.tipCopper or 0),
            tonumber(all.tips) or 0, ns.MoneyText(all.tipCopper or 0)))
    elseif cmd == "sound" then
        db.sound = not db.sound
        Print("the alert sounds are " .. (db.sound and "on." or "off."))
    else
        Help()
    end
end
ns.Slash = Slash

SLASH_MAILBOXSLUTTING1 = "/mailslut"
SLASH_MAILBOXSLUTTING2 = "/mailboxslutting"
-- Only a key of SlashCmdList: assigning the global itself taints every slash command (/tm, /invite).
SlashCmdList.MAILBOXSLUTTING = function(msg) Slash(msg or "") end

BINDING_HEADER_MAILBOXSLUTTING = "Mailbox Slutting"
BINDING_NAME_MAILBOXSLUTTING_ACCEPTTIP = "Accept a tip (a trade where only they give gold)"
BINDING_NAME_MAILBOXSLUTTING_TOGGLE = "Start or stop dancing for tips"
function MailboxSlutting_Toggle() if ns.Mailbox and db then ns.Mailbox.Toggle() end end

-- For a look from /dump, and so Slutmog Shop's old /slutshop mailbox can still find it.
MailboxSlutting = ns

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
ns.events = events
pcall(events.RegisterEvent, events, "ADDON_LOADED")
pcall(events.RegisterEvent, events, "PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then InitDB() end
    elseif event == "PLAYER_LOGIN" then
        if not db then InitDB() end
        Migrate()                       -- the shop's saved data is surely there by now
        -- LookShots (a helper on SuccuDev's machine only) takes a screenshot the first time the counter shows
        LookShotsTargets = LookShotsTargets or {}
        LookShotsTargets[ADDON] = {
            version = ns.VERSION,
            frames = {
                { label = "counter", frame = function()
                    local f = ns.Counter and ns.Counter.Frame()
                    return f and f:IsShown() and f or nil
                end },
            },
        }
    end
end)
