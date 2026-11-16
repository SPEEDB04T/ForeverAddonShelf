-- Mailbox Slutting: the counter. One window that stays on screen while you stand on the mailbox
-- (SuccuDev: "combine advertising and mailbox, big default screen on, assume I want buttons on my
-- screen at all times while dancing, maybe stats tracking"):
--   with Slutmog Shop installed: its next ad, the item and a big Post ad button (it lights up when
--   an ad is due), and the Wares and Options buttons;
--   mailbox mode, built into it (who is waiting and the reply, the visitors, Tip jar, Dance);
--   today's numbers (hover for the week and all time);
--   Open shop / Close shop (mailbox mode).
-- It is up by default and remembers where you put it. Its close button puts it away (/mailslut
-- counter brings it back); in a fight it steps aside and comes back after.
-- Same make as the game's own small windows: BasicFrameTemplateWithInset, panel buttons, the
-- tooltip divider between the parts.
local ADDON, ns = ...
local C = {}
ns.Counter = C

local W = 430
local AD_H = 92                 -- the ad part, under the title
local TITLE_H = 26
local BAR_H = 56                -- the numbers and the button bar
local ICON = 37

local frame, ev
local hiding = false            -- the counter is put away for a fight: mailbox mode stays on
local remind = false            -- an ad is due: the Post button lights up

local function Readable(v)
    if ns.Readable then return ns.Readable(v) end
    return true
end

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function FromTemplate(kind, parent, template, name)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
end

local function Button(parent, label, w, h)
    local b = FromTemplate("Button", parent, "UIPanelButtonTemplate") or CreateFrame("Button", nil, parent)
    b:SetSize(w or 80, h or 22)
    b:SetText(label)
    return b
end

local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    if fs.SetFontObject and _G[font] then pcall(fs.SetFontObject, fs, _G[font]) end
    fs:SetJustifyH("LEFT")
    return fs
end

local function Tip(owner, title, ...)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title)
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then GameTooltip:AddLine(line, 1, 0.82, 0, true) end
    end
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

local function Hover(widget, title, ...)
    local lines = { ... }
    widget:SetScript("OnEnter", function(self) Tip(self, title, unpack(lines)) end)
    widget:SetScript("OnLeave", HideTip)
end

local function Divider(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    t:SetHeight(8)
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, y)
    return t
end

local function Clock(sec)
    sec = math.max(0, math.floor(sec or 0))
    if sec >= 3600 then return ("%dh %dm"):format(math.floor(sec / 3600), math.floor(sec % 3600 / 60)) end
    if sec >= 60 then return ("%dm"):format(math.floor(sec / 60)) end
    return ("%ds"):format(sec)
end

local function Money(c)
    return ns.MoneyText and ns.MoneyText(c or 0) or tostring(c or 0)
end

---------------------------------------------------------------------------
-- The numbers
---------------------------------------------------------------------------
-- One line for today, under the mailbox part.
function C.StatsLine()
    local t = ns.Stats and ns.Stats(0) or {}
    local parts = {}
    local tips = tonumber(t.tips) or 0
    parts[#parts + 1] = tips == 1 and "1 tip" or (tips .. " tips")
    if tips > 0 then parts[#parts + 1] = Money(t.tipCopper) end
    if ns.Shop() then parts[#parts + 1] = (tonumber(t.ads) or 0) .. " ads" end
    parts[#parts + 1] = (tonumber(t.visitors) or 0) .. " visitors"
    if (tonumber(t.open) or 0) > 0 then parts[#parts + 1] = "open " .. Clock(t.open) end
    return "Today: " .. table.concat(parts, ", ")
end

local function StatLines(title, t)
    local open = tonumber(t.open) or 0
    local copper = tonumber(t.tipCopper) or 0
    local lines = {
        ("%s: %d tips, %s"):format(title, tonumber(t.tips) or 0, Money(copper)),
        (ns.Shop() and ("    %d ads, "):format(tonumber(t.ads) or 0) or "    ")
            .. ("%d visitors, %d emotes back"):format(tonumber(t.visitors) or 0, tonumber(t.emotes) or 0),
        ("    %d tip jar lines, %d welcomed back, open %s"):format(tonumber(t.jar) or 0, tonumber(t.welcomes) or 0, Clock(open)),
    }
    if open >= 600 then lines[#lines + 1] = ("    %s an hour open"):format(Money(math.floor(copper * 3600 / open))) end
    return lines
end

local function StatsTip(self)
    if not (GameTooltip and ns.Stats) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Your numbers")
    for _, set in ipairs({ { "Today", ns.Stats(0) }, { "Last 7 days", ns.Stats(7) }, { "All time", ns.Stats() } }) do
        for _, line in ipairs(StatLines(set[1], set[2] or {})) do GameTooltip:AddLine(line, 1, 1, 1) end
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Keeping it current
---------------------------------------------------------------------------
local adLink

function C.Sync()
    if not (frame and frame:IsShown() and ns.db) then return end
    -- Slutmog Shop's part: its name on top, and its next ad (only when the shop was there at login)
    local shop = frame.post and ns.Shop() or nil
    local title = shop and type(shop.ShopName) == "function" and shop.ShopName() or ns.TITLE
    if type(frame.SetTitle) == "function" then pcall(frame.SetTitle, frame, title)
    elseif type(frame.TitleText) == "table" then frame.TitleText:SetText(title) end
    if shop then
        local p, why = shop.Next()
        local w = p and p.ware and shop.db.wares[p.ware]
        adLink = w and w.link or nil
        local icon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
        local tex = w and w.id and type(icon) == "function" and select(2, pcall(icon, w.id)) or nil
        if not Readable(tex) then tex = nil end
        frame.item.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
        if p then
            frame.ad:SetText(p.text)
            frame.ad:SetTextColor(1, 1, 1)
        else
            frame.ad:SetText("Nothing to post: " .. tostring(why))
            frame.ad:SetTextColor(0.5, 0.5, 0.5)
        end
        local wait = shop.Wait and shop.Wait() or 0
        if not p then
            frame.post:SetText("Post ad")
            frame.post:SetEnabled(false)
        elseif wait > 0 then
            frame.post:SetText(("Next ad in %d:%02d"):format(math.floor(wait / 60), math.ceil(wait) % 60))
            frame.post:SetEnabled(false)
        else
            local _, _, label = shop.ResolveChannel()
            frame.post:SetText(shop.db.channel == "TURNS" and label and ("Post ad to " .. (label:match("^(.-) %- ") or label)) or "Post ad")
            frame.post:SetEnabled(true)
        end
        frame.reroll:SetEnabled(p ~= nil)
    end
    -- the numbers and the shop's state
    frame.stats:SetText(C.StatsLine())
    local open = ns.Mailbox and ns.Mailbox.IsOn()
    frame.open:SetText(open and "Close shop" or "Open shop")
    if ns.Mailbox and ns.Mailbox.Sync then ns.Mailbox.Sync() end
end

local function Pulse()
    if not (frame and frame:IsShown()) then return end
    if not frame.post then return end
    local on = remind and frame.post:IsEnabled() and math.floor(Now() * 2) % 2 == 0
    if on then frame.post:LockHighlight() else frame.post:UnlockHighlight() end
end

-- An ad is due: the Post button lights up until you post (instead of the ad prompt).
function C.Remind()
    remind = true
    C.Sync()
    Pulse()
end
function C.Reminding() return remind end
function C.Posted()
    remind = false
    if frame and frame.post then frame.post:UnlockHighlight() end
    C.Sync()
end

---------------------------------------------------------------------------
-- Building it
---------------------------------------------------------------------------
local function SavePosition(f)
    if not (ns.db and f.GetPoint) then return end
    local ok, point, _, rel, x, y = pcall(f.GetPoint, f)
    if ok and point then ns.db.counterPos = { point = point, rel = rel, x = x, y = y } end
end

local function Place(f)
    f:ClearAllPoints()
    local pos = ns.db and ns.db.counterPos
    if type(pos) == "table" and type(pos.point) == "string" then
        f:SetPoint(pos.point, UIParent, pos.rel or pos.point, tonumber(pos.x) or 0, tonumber(pos.y) or 0)
    else
        f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 40)
    end
end

local function Build()
    if frame then return frame end
    local f = FromTemplate("Frame", UIParent, "BasicFrameTemplateWithInset", "MailboxSluttingCounter")
        or CreateFrame("Frame", "MailboxSluttingCounter", UIParent)
    frame = f
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    if type(f.CloseButton) == "table" then
        f.CloseButton:SetScript("OnClick", function() C.Close() end)
    else
        local close = FromTemplate("Button", f, "UIPanelCloseButton")
        if close then
            close:SetPoint("TOPRIGHT", 0, 0)
            close:SetScript("OnClick", function() C.Close() end)
        end
    end

    -- the ad: Slutmog Shop's, so only with the shop installed
    local shop = ns.Shop()
    local adH = shop and AD_H or 0
    if shop then
    local item = CreateFrame("Button", nil, f)
    item:SetSize(ICON, ICON)
    item:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -TITLE_H - 8)
    item.icon = item:CreateTexture(nil, "ARTWORK")
    item.icon:SetAllPoints(item)
    item:SetScript("OnEnter", function(self)
        if adLink and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, adLink)
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave", HideTip)
    f.item = item
    f.ad = Text(f, "GameFontHighlightSmall")
    f.ad:SetJustifyV("TOP")
    if f.ad.SetWordWrap then f.ad:SetWordWrap(true) end
    f.ad:SetPoint("TOPLEFT", item, "TOPRIGHT", 10, 0)
    f.ad:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.ad:SetHeight(40)
    f.post = Button(f, "Post ad", 190, 30)
    f.post:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -TITLE_H - 52)
    if f.post.SetNormalFontObject and GameFontNormalLarge then pcall(f.post.SetNormalFontObject, f.post, GameFontNormalLarge) end
    if f.post.SetHighlightFontObject and GameFontHighlightLarge then pcall(f.post.SetHighlightFontObject, f.post, GameFontHighlightLarge) end
    if f.post.SetMotionScriptsWhileDisabled then f.post:SetMotionScriptsWhileDisabled(true) end
    f.post:SetScript("OnClick", function()
        local s = ns.Shop()
        if s and s.Post() then C.Posted() end
    end)
    Hover(f.post, "Post ad", "Posts the ad above, exactly as it reads. It lights up when the next one is due.")
    f.reroll = Button(f, "Reroll", 80, 22)
    f.reroll:SetPoint("LEFT", f.post, "RIGHT", 6, 0)
    f.reroll:SetScript("OnClick", function()
        local s = ns.Shop()
        if s and s.Reroll then s.Reroll() end
        C.Sync()
    end)
    Hover(f.reroll, "Reroll", "Another ad for the same ware.")
    Divider(f, -TITLE_H - AD_H + 4)
    end

    -- mailbox mode
    local top = TITLE_H + adH
    local panel, mailH = nil, 0
    if ns.Mailbox and ns.Mailbox.Embed then
        local ok, p, h = pcall(ns.Mailbox.Embed, f)
        if ok and p then
            panel, mailH = p, h or 0
            panel:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
            panel:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
        end
    end
    f.mailbox = panel
    Divider(f, -top - mailH + 2)

    -- the numbers, and the bar
    f.stats = Text(f, "GameFontHighlightSmall")
    f.stats:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 38)
    f.stats:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    local statsHover = CreateFrame("Frame", nil, f)
    statsHover:SetAllPoints(f.stats)
    statsHover:EnableMouse(true)
    statsHover:SetScript("OnEnter", StatsTip)
    statsHover:SetScript("OnLeave", HideTip)
    f.open = Button(f, "Open shop", 110, 24)
    f.open:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.open:SetScript("OnClick", function()
        if ns.Mailbox then ns.Mailbox.Toggle() end
        C.Sync()
    end)
    Hover(f.open, "Open shop / Close shop", "Open: you dance, and the shop winks at whoever keeps you targeted, "
        .. "emotes back at whoever emotes at you, welcomes back your tippers and minds the tip jar. Close: all of that stops"
        .. (shop and "; the ads still work." or "."))
    if shop then
        f.options = Button(f, "Options", 80, 24)
        f.options:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
        f.options:SetScript("OnClick", function()
            local s = ns.Shop()
            if s and s.OpenOptions then s.OpenOptions() end
        end)
        f.wares = Button(f, "Wares", 80, 24)
        f.wares:SetPoint("RIGHT", f.options, "LEFT", -4, 0)
        f.wares:SetScript("OnClick", function()
            local s = ns.Shop()
            if s and s.UI and s.UI.Toggle then s.UI.Toggle() end
        end)
        Hover(f.wares, "Wares", "The shop window: your wares, prices and ad lines.")
    end

    f:SetSize(W, top + mailH + BAR_H)
    Place(f)
    local since = 0
    f:SetScript("OnUpdate", function(_, dt)
        since = since + (dt or 0)
        Pulse()
        if since < 0.5 then return end
        since = 0
        C.Sync()
    end)
    f:Hide()
    f:SetScript("OnShow", function() C.Sync() end)
    return f
end

---------------------------------------------------------------------------
-- Up, away, and out of a fight
---------------------------------------------------------------------------
function C.Show()
    if not ns.db then return false end
    local ok, err = pcall(Build)
    if not ok then
        ns.Print("the counter could not be built: " .. tostring(err))
        return false
    end
    ns.db.counter = true
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        C.hidden = true                 -- up after the fight
        return true
    end
    frame:Show()
    C.Sync()
    return true
end

-- The close button: put away until /mailslut counter, and the shop is closed.
function C.Close()
    if ns.db then ns.db.counter = false end
    if ns.Mailbox and ns.Mailbox.IsOn() then ns.Mailbox.Stop() end
    if frame then frame:Hide() end
    ns.Print("the counter is put away. /mailslut counter brings it back.")
end

function C.Toggle()
    if frame and frame:IsShown() then C.Close() else C.Show() end
end

function C.IsShown() return frame ~= nil and frame:IsShown() end
function C.Frame() return frame end
function C.Hiding() return hiding end

local function Fight(on)
    if not frame then return end
    if on and frame:IsShown() then
        hiding = true
        frame:Hide()
        hiding = false
        C.hidden = true
    elseif not on and C.hidden then
        C.hidden = false
        if ns.db and ns.db.counter ~= false then frame:Show() end
    end
end
C.Fight = Fight

ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if ns.db and ns.db.counter ~= false then C.Show() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        Fight(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Fight(false)
    end
end)
