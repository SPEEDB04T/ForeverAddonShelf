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
    return ns.FullName and ns.FullName("NPC") or nil
end

-- The tip on the table, in copper: gold from them, and nothing at all from you. nil when it is not one.
function T.Tip()
    if not open then return nil end
    local theirs, mine = Money(GetTargetTradeMoney), Money(GetPlayerTradeMoney)
    if not (theirs and mine) or theirs <= 0 or mine > 0 then return nil end
    if GivingItems() then return nil end
    return theirs
end

local pre                       -- the thank-you sent with your Accept click
local trade = 0                 -- counts trade windows, so one click thanks once
local kept                      -- the tip on the table, kept while the trade goes through
local owed                      -- the last tip's thank-you, until the game shows it went out
local mode = "accept"           -- what the button does: "accept" a tip or "thank" for one
local Say                       -- set below

local function Now() return (type(GetTime) == "function" and GetTime()) or 0 end

-- Accepts the trade, if it is a tip. On a click or a key press only. When they have accepted already,
-- this click finishes the trade, so the thank-you goes out with it: the game takes a chat line from
-- an addon most surely on a click.
function T.Accept()
    if mode == "thank" then return T.Thank() end
    if not T.Tip() or type(AcceptTrade) ~= "function" then return false end
    local ok = pcall(AcceptTrade)
    -- The click is the one moment the game surely lets a chat line out, so the thank-you goes with it,
    -- whoever accepts first (when you accepted first, it used to wait for their click and the game
    -- dropped it: SuccuDev, "its not reliably emote thanking"). Once per trade.
    if ok and last and last.who and not (pre and pre.trade == trade) then
        pre = { who = last.who, amount = last.amount, at = Now(), trade = trade }
        Say(pre)
    end
    return ok
end
function SlutmogShop_AcceptTip() T.Accept() end

local function Sound()
    ns.AlertSound(SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND, 120)
    if type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
end

local function Tip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if mode == "thank" then
        GameTooltip:SetText("Thank them")
        GameTooltip:AddLine("The game did not let the thank-you out by itself. This click sends it.", 1, 0.82, 0, true)
        GameTooltip:Show()
        return
    end
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
    kept = { who = last.who, amount = amount, at = Now(), trade = trade }
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

-- The thank-you grows with the tip (SuccuDev: "need to scale thanks on tips based on amount"). Each
-- step: from how much copper, and its lines, in /e after your name ("Smuttanie hugs Bob for the tip
-- of 5 gold pieces."). Every line names them and the amount, so people around see what tipping gets.
-- Worded like the game's own emotes, nothing said in Smuttanie's voice (SuccuDev: "dont add text as if
-- smuttanie's writing in emotes. it has to be clean, minimalistic, feel similar to ingame emotes").
T.THANKS = {
    { 0, {                                  -- under a gold
        "thanks {who} for the tip of {amount}.",
        "drops {who}'s {amount} in the tip jar.",
    } },
    { 10000, {                              -- a gold or more
        "thanks {who} for the tip of {amount}.",
        "curtseys before {who} for the tip of {amount}.",
    } },
    { 50000, {                              -- 5 gold or more
        "blows {who} a kiss for the tip of {amount}.",
        "hugs {who} for the tip of {amount}.",
    } },
    { 200000, {                             -- 20 gold or more
        "gives {who} a big hug for the tip of {amount}.",
        "bows before {who} for the tip of {amount}.",
    } },
    { 1000000, {                            -- 100 gold or more
        "is speechless at {who}'s tip of {amount}.",
        "bows deeply before {who} for the tip of {amount}.",
    } },
}
T.Random = function(n) return math.random(n) end
local lastThanks = {}

-- The lines for this much copper.
function T.Step(amount)
    local pick = T.THANKS[1]
    for _, step in ipairs(T.THANKS) do
        if amount >= step[1] then pick = step end
    end
    return pick[2], pick[1]
end

-- One thank-you for this tip, not the same line twice in a row.
function T.Thanks(who, amount)
    local lines, at = T.Step(amount)
    local i = T.Random(#lines)
    if #lines > 1 and i == lastThanks[at] then i = i % #lines + 1 end
    lastThanks[at] = i
    local money = ns.PriceText(amount, "words")
    local line = lines[i]:gsub("{who}", function() return who end)
    line = line:gsub("{amount}", function() return money end)
    return line
end

-- A little whisper after it, a few seconds later like a person would (SuccuDev: "whisper can be a cute
-- little thank you <3 or something, with a natural delay randomized").
T.WHISPERS = { "thank you <3", "aww, thank you <3", "ty ty <3", "thank you!! <3" }
T.DELAY_MIN, T.DELAY_MAX = 3, 8
local ECHO_WAIT = 2             -- seconds for the game to show a line went out
local THANK_SHOWN = 60          -- seconds the Thank button stays up
local lastWhisper

local function Send(text, kind, target)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" then return false end
    return (pcall(send, text, kind, nil, target))
end

-- Thanked out loud with the amount, as an emote everybody around sees (SuccuDev: "not a whisper. in
-- emote with the thank. it advertises to others they can tip me"). A text emote plays no animation,
-- so the dance goes on.
local function Log(what)
    if ns.Mailbox and ns.Mailbox.Log then ns.Mailbox.Log("tip " .. what) end
end
T.Log = Log

Say = function(tip)
    tip.text = tip.text or T.Thanks(tip.who, tip.amount)
    local ok = Send(tip.text, "EMOTE")
    Log("/e " .. tip.text .. ": " .. (ok and "sent" or "error"))
    return ok
end

local function Line()
    local list = T.WHISPERS
    local line = list[math.random(#list)]
    if #list > 1 then
        while line == lastWhisper do line = list[math.random(#list)] end
    end
    lastWhisper = line
    return line
end

-- The game drops a chat line from an addon that comes with no click, without a word. So each line is
-- watched for: if it does not show up, the button under where the trade was says "Thank Bob", and
-- that click sends what is missing.
local function ShowThank()
    if not owed then return end
    local b = Build()
    mode = "thank"
    if b.SetParent then pcall(b.SetParent, b, UIParent) end
    b:SetText("Thank " .. owed.who)
    b:SetEnabled(true)
    if b.UnlockHighlight then b:UnlockHighlight() end
    Fit(b)
    b:Show()
    local mine = owed
    if C_Timer and C_Timer.After then
        C_Timer.After(THANK_SHOWN, function()
            if owed == mine and mode == "thank" then
                mode, owed = "accept", nil
                b:Hide()
            end
        end)
    end
end

local RETRIES = 3               -- more tries at the thank-you, each on a chat line that comes in
local function Watch(tip, what)
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(ECHO_WAIT, function()
        if owed == tip and not tip[what] then
            Log("no echo for the " .. (what == "said" and "thank-you" or "whisper"))
            tip["need_" .. what] = true
            ShowThank()
        end
    end)
end

-- A line from the shop after a chat line from somebody else gets out where one from a timer does not
-- (the same as the dance in mailbox mode), so a thank-you that did not go out is tried again then.
local function Retry()
    local tip = owed
    if not (tip and tip.need_said and not tip.said) then return end
    tip.tries = (tip.tries or 0) + 1
    if tip.tries > RETRIES then return end
    Log("trying the thank-you again")
    tip.need_said = nil
    Say(tip)
    Watch(tip, "said")
end
T.Retry = Retry

-- The Thank button: what did not go out by itself goes out now.
function T.Thank()
    local tip = owed
    if not tip then return false end
    if tip.need_said and not tip.said then Say(tip) end
    if tip.need_whispered then Send(tip.line, "WHISPER", tip.who) end
    tip.need_said, tip.need_whispered = nil, nil
    mode = "accept"
    if button then button:Hide() end
    return true
end
T.Owed = function() return owed end
T.Mode = function() return mode end

local function Whisper(tip)
    tip.line = Line()
    local delay = T.DELAY_MIN + math.random() * (T.DELAY_MAX - T.DELAY_MIN)
    local function Go()
        if owed ~= tip then return end
        Send(tip.line, "WHISPER", tip.who)
        Watch(tip, "whispered")
    end
    if C_Timer and C_Timer.After then C_Timer.After(delay, Go) else Go() end
end

-- It went through: thank them, and count it.
local function Done(why)
    local tip = last
    if not tip and kept and kept.trade == trade and Now() - kept.at < 30 then tip = kept end
    last, kept = nil, nil
    if not (tip and tip.amount and tip.amount > 0) then return end
    Log("went through (" .. tostring(why) .. "): " .. tostring(tip.who) .. " " .. tostring(tip.amount))
    local db = ns.db
    if type(db) == "table" then
        db.tips = (tonumber(db.tips) or 0) + tip.amount
        db.tipCount = (tonumber(db.tipCount) or 0) + 1
        if ns.Stat then
            ns.Stat("tips")
            ns.Stat("tipCopper", tip.amount)
        end
        -- who tipped, so mailbox mode can welcome them back when they come by again
        if tip.who then
            db.tippers = type(db.tippers) == "table" and db.tippers or {}
            local t = type(db.tippers[tip.who]) == "table" and db.tippers[tip.who] or {}
            t.n, t.total, t.last = (tonumber(t.n) or 0) + 1, (tonumber(t.total) or 0) + tip.amount, time()
            db.tippers[tip.who] = t
        end
    end
    ns.Print(string.format("%s tipped you %s. Tips so far: %s.", tip.who or "Somebody", ns.MoneyText(tip.amount),
        ns.MoneyText(type(db) == "table" and db.tips or tip.amount)))
    if not tip.who then return end
    local early = pre and pre.who == tip.who and pre.trade == trade and Now() - pre.at < 120
    owed = { who = tip.who, amount = tip.amount, said = early and pre.seen or nil, text = early and pre.text or nil }
    pre = nil
    if not early then Say(owed) end
    Watch(owed, "said")
    Whisper(owed)
end

-- Your own line came back from the game: it went out.
local function Mine(sender, guid)
    if Readable(guid) and guid ~= nil and guid == Call(UnitGUID, "player") then return true end
    if not Readable(sender) or type(sender) ~= "string" then return false end
    local me, full = Call(UnitName, "player"), ns.FullName and ns.FullName("player")
    local short = sender:match("^([^%-]+)")
    return (me ~= nil and (sender == me or short == me or sender:match("^(%S+)") == me)) or (full ~= nil and short == full)
end

local function Echo(event, text, sender, guid)
    if not (Readable(text) and type(text) == "string") then return end
    if event == "CHAT_MSG_EMOTE" and Mine(sender, guid) then
        local hit = false
        if owed and (owed.text == text or (not owed.text and owed.who and text:find(owed.who, 1, true))) then
            owed.said, hit = true, true
        end
        if pre and pre.text == text then pre.seen, hit = true, true end
        if hit then Log("echo of the thank-you") end
    elseif event == "CHAT_MSG_WHISPER_INFORM" and owed and owed.line == text then
        owed.whispered = true
    end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "TRADE_SHOW", "TRADE_CLOSED", "TRADE_UPDATE", "TRADE_MONEY_CHANGED", "PLAYER_TRADE_MONEY",
    "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE",
    "CHAT_MSG_EMOTE", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function(_, event, a, b, ...)
    if event == "TRADE_SHOW" then
        open, accepted, theyAccepted, last, kept = true, false, false, nil, nil
        trade = trade + 1
        if mode == "thank" then mode = "accept" end
        if button and button.SetParent and type(TradeFrame) == "table" then pcall(button.SetParent, button, TradeFrame) end
        Update()
    elseif event == "TRADE_CLOSED" then
        open = false
        if button and mode ~= "thank" then button:Hide() end
        -- both had accepted: it went through, even if the game's "Trade complete." does not come
        if accepted and theyAccepted and C_Timer and C_Timer.After then
            local mine = trade
            C_Timer.After(1, function() if trade == mine and (last or kept) then Done("closed") end end)
        end
    elseif event == "TRADE_ACCEPT_UPDATE" then
        if Readable(a) and Readable(b) then
            accepted, theyAccepted = a == 1, b == 1
        end
        if open then Update() end
    elseif event == "UI_INFO_MESSAGE" then
        local done = ERR_TRADE_COMPLETE or "Trade complete."
        if (Readable(b) and b == done) or (Readable(a) and a == done) then Done("complete") end
    elseif event == "CHAT_MSG_EMOTE" or event == "CHAT_MSG_WHISPER_INFORM" then
        Echo(event, a, b, (select(10, ...)))
        if event == "CHAT_MSG_EMOTE" and not Mine(b, (select(10, ...))) then Retry() end
    elseif event:find("^CHAT_MSG_") then
        if not Mine(b, (select(10, ...))) then Retry() end
    elseif open then
        Update()
    end
end)
