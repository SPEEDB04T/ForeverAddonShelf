-- Slutmog Shop: tips. When somebody opens a trade and puts in gold while you put in nothing at all,
-- a big button under the trade window takes it, and the shop thanks them once it goes through.
-- The game takes a trade only on a click or a key press (AcceptTrade needs a hardware event; an addon
-- calling it by itself is blocked), so this is one click, or the "Accept a tip" key binding. It can
-- not be done with no click at all.
local ADDON, ns = ...
local T = {}
ns.Tips = T

local SLOTS = 7                 -- MAX_TRADE_ITEMS: six to give and the "will not be traded" slot

local open = false              -- a trade window is open
local accepted = false          -- you pressed Accept on it
local theyAccepted = false
local last                      -- the tip on the table: { who = name, amount = copper }
local button

local function Readable(v)
    if ns.Readable then return ns.Readable(v) end
    return true
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if not ok then return nil end
    return a
end

-- Coins as a plain number, or nil when the game does not say.
local function Money(fn)
    local v = Call(fn)
    if v == nil or not Readable(v) then return nil end
    return tonumber(v)
end

-- Anything of yours in the trade? Unknown counts as yes.
local function GivingItems()
    if type(GetTradePlayerItemInfo) ~= "function" then return false end
    for i = 1, SLOTS do
        local ok, has = pcall(function()
            local name = GetTradePlayerItemInfo(i)
            return name ~= nil
        end)
        if not ok or has then return true end
    end
    return false
end

-- Who you are trading with, or nil.
local function Partner()
    local name = Call(UnitName, "NPC")
    if type(name) == "string" and Readable(name) and name ~= "" then return name end
    return nil
end

-- The tip on the table, in copper: gold from them, and nothing at all from you. nil when it is not one.
function T.Tip()
    if not open then return nil end
    local theirs, mine = Money(GetTargetTradeMoney), Money(GetPlayerTradeMoney)
    if not (theirs and mine) or theirs <= 0 or mine > 0 then return nil end
    if GivingItems() then return nil end
    return theirs
end

-- Accepts the trade, if it is a tip. On a click or a key press only.
function T.Accept()
    if not T.Tip() or type(AcceptTrade) ~= "function" then return false end
    return (pcall(AcceptTrade))
end
function SlutmogShop_AcceptTip() T.Accept() end

local function Sound()
    ns.AlertSound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND, 120)
    if type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
end

local function Tip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Accept tip")
    GameTooltip:AddLine("They give gold, you give nothing. Goes through once they accept too.", 1, 0.82, 0, true)
    GameTooltip:AddLine("The game wants a click or a key for every trade: there is an \"Accept a tip\" key binding too.", 1, 1, 1, true)
    GameTooltip:Show()
end

local function Build()
    if button then return button end
    local parent = (type(TradeFrame) == "table" and TradeFrame) or UIParent
    local ok, b = pcall(CreateFrame, "Button", "SlutmogShopTipButton", parent, "UIPanelButtonTemplate")
    if not (ok and b) then b = CreateFrame("Button", "SlutmogShopTipButton", parent) end
    b:SetSize(200, 30)
    if parent == UIParent then
        b:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    else
        b:SetPoint("TOP", parent, "BOTTOM", 0, -4)
    end
    b:SetScript("OnClick", function() T.Accept() end)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    b:Hide()
    button = b
    return b
end
T.Button = function() return button end

local function Fit(b)
    if ns.Mailbox and ns.Mailbox.Fit then ns.Mailbox.Fit(b, 200, 320) end
end

local function Update()
    local amount = T.Tip()
    local b = Build()
    if not amount then
        last = nil
        b:Hide()
        return
    end
    local new = not last or last.amount ~= amount
    last = { who = Partner() or (last and last.who), amount = amount }
    if accepted then
        b:SetText("Waiting for " .. (last.who or "them"))
        b:SetEnabled(false)
    else
        b:SetText("Accept tip: " .. ns.MoneyText(amount))
        b:SetEnabled(true)
    end
    Fit(b)
    if b.LockHighlight then
        if theyAccepted and not accepted then b:LockHighlight() else b:UnlockHighlight() end
    end
    b:Show()
    if new then Sound() end
end
T.Update = Update

-- It went through: thank them, and count it.
local function Done()
    local tip = last
    last = nil
    if not (tip and tip.amount and tip.amount > 0) then return end
    local db = ns.db
    if type(db) == "table" then
        db.tips = (tonumber(db.tips) or 0) + tip.amount
        db.tipCount = (tonumber(db.tipCount) or 0) + 1
    end
    ns.Print(string.format("%s tipped you %s. Tips so far: %s.", tip.who or "Somebody", ns.MoneyText(tip.amount),
        ns.MoneyText(type(db) == "table" and db.tips or tip.amount)))
    if tip.who then
        local mb = ns.Mailbox
        if mb and mb.IsOn and mb.IsOn() and mb.EmoteAt then
            mb.EmoteAt("THANK", tip.who)
        else
            local fn = (C_ChatInfo and C_ChatInfo.PerformEmote) or DoEmote
            if type(fn) == "function" then pcall(fn, "THANK", tip.who, true) end
        end
    end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SHOW", "TRADE_CLOSED", "TRADE_UPDATE", "TRADE_MONEY_CHANGED", "PLAYER_TRADE_MONEY",
    "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, a, b)
    if event == "TRADE_SHOW" then
        open, accepted, theyAccepted, last = true, false, false, nil
        Update()
    elseif event == "TRADE_CLOSED" then
        open = false
        if button then button:Hide() end
    elseif event == "TRADE_ACCEPT_UPDATE" then
        if Readable(a) and Readable(b) then
            accepted, theyAccepted = a == 1, b == 1
        end
        if open then Update() end
    elseif event == "UI_INFO_MESSAGE" then
        if Readable(b) and type(b) == "string" and b == (ERR_TRADE_COMPLETE or "Trade complete.") then Done() end
    elseif open then
        Update()
    end
end)
