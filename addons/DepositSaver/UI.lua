-- Deposit Saver: the buyback list that sits to the right of the auction house window.
--
-- Copies: the window is the game's ButtonFrameTemplate (the portrait-window family the
-- auction house itself is built from) with its portrait hidden and its Inset holding the
-- list. Each row copies AuctionHouseItemListLineTemplate (Blizzard_AuctionHouseUI/Mainline/
-- Blizzard_AuctionHouseItemList.xml): the "auctionhouse-rowstripe-1" stripe on every other row
-- and the "auctionhouse-ui-row-highlight" highlight; the item cell copies
-- AuctionHouseTableCellItemDisplayTemplate (14 px icon in the 16 px
-- "auctionhouse-itemicon-small-border", Number14FontWhite). A row is two lines high (the
-- game's are one) because it carries the deposit, the cut and the verdict.
--
-- At the top, while the sell frame holds an item, one block says what this post would cost if
-- it doesn't sell and whether a buyback would then be worth it.
local _, ns = ...
local Num = ns.Num

local UI = {}
ns.UI = UI

local WIDTH, ROW_H, ROWS = 330, 38, 11
local rows = {}
local panel, preview

local function Template(frameType, name, parent, templates)
    for _, t in ipairs(templates) do
        local ok, f = pcall(CreateFrame, frameType, name, parent, t)
        if ok and f then return f, t end
    end
    return CreateFrame(frameType, name, parent), nil
end

function UI.Visible()
    return panel ~= nil and panel:IsShown() == true
end

local function SetTitle(f, text)
    if f.SetTitle then
        if pcall(f.SetTitle, f, text) then return end
    end
    local t = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
    if t and t.SetText then t:SetText(text) end
end

local function Font(fs, object)
    if _G[object] then fs:SetFontObject(_G[object]) end
end

local function Color(c, text)
    if type(c) == "table" and c.WrapTextInColorCode then
        local ok, s = pcall(c.WrapTextInColorCode, c, text)
        if ok then return s end
    end
    return text
end

-- One row: [icon] item ............ time left
--          owner · verdict
local function MakeRow(parent, i)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(ROW_H)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(i - 1) * ROW_H)
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(i - 1) * ROW_H)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    b.Stripe = b:CreateTexture(nil, "BACKGROUND")
    b.Stripe:SetAtlas("auctionhouse-rowstripe-1")
    b.Stripe:SetAllPoints()
    b.Stripe:SetShown(i % 2 == 1)

    b.Highlight = b:CreateTexture(nil, "HIGHLIGHT")
    b.Highlight:SetAtlas("auctionhouse-ui-row-highlight")
    b.Highlight:SetBlendMode("ADD")
    b.Highlight:SetAllPoints()

    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Icon:SetSize(14, 14)
    b.Icon:SetPoint("TOPLEFT", b, "TOPLEFT", 6, -4)
    b.IconBorder = b:CreateTexture(nil, "OVERLAY")
    b.IconBorder:SetAtlas("auctionhouse-itemicon-small-border")
    b.IconBorder:SetSize(16, 16)
    b.IconBorder:SetPoint("CENTER", b.Icon, "CENTER")

    b.Time = b:CreateFontString(nil, "ARTWORK")
    Font(b.Time, "Number14FontWhite")
    b.Time:SetJustifyH("RIGHT")
    b.Time:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, -4)

    b.Name = b:CreateFontString(nil, "ARTWORK")
    Font(b.Name, "Number14FontWhite")
    b.Name:SetJustifyH("LEFT")
    b.Name:SetWordWrap(false)
    b.Name:SetPoint("LEFT", b.Icon, "RIGHT", 4, 0)
    b.Name:SetPoint("RIGHT", b.Time, "LEFT", -6, 0)

    b.Detail = b:CreateFontString(nil, "ARTWORK")
    Font(b.Detail, "GameFontHighlightSmall")
    b.Detail:SetJustifyH("LEFT")
    b.Detail:SetWordWrap(false)
    b.Detail:SetPoint("TOPLEFT", b.Icon, "BOTTOMLEFT", 0, -5)
    b.Detail:SetPoint("RIGHT", b, "RIGHT", -6, 0)

    b:SetScript("OnClick", function(self, button)
        if not self.rec then return end
        if button == "RightButton" then
            self.rec.muted = not self.rec.muted or nil
            ns.Print((self.rec.muted and "No warnings for %s." or "Warnings back on for %s."):format(ns.ItemName(self.rec)))
            ns.Changed()
        else
            ns.Find(self.rec.id)
        end
    end)
    b:SetScript("OnEnter", function(self) UI.RowTooltip(self) end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    rows[i] = b
    return b
end

function UI.RowTooltip(b)
    local rec = b.rec
    if not rec or not GameTooltip then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    local shown = false
    if rec.link and GameTooltip.SetHyperlink then shown = pcall(GameTooltip.SetHyperlink, GameTooltip, rec.link) end
    if not shown and GameTooltip.SetItemByID and rec.item then shown = pcall(GameTooltip.SetItemByID, GameTooltip, rec.item) end
    if not shown then GameTooltip:AddLine(ns.ItemName(rec)) end
    local deposit, cut, saving, worth = ns.Worth(rec)
    local price, left = ns.Price(rec), ns.Left(rec)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Seller", rec.owner or "?", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
    GameTooltip:AddDoubleLine(rec.bidOnly and "Bid (no buyout)" or "Buyout", price and ns.Money(price) or "?",
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
    GameTooltip:AddDoubleLine("Listed for", ns.ListedText(rec), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
    GameTooltip:AddDoubleLine("Time left", left and ((rec.approx and "about " or "") .. ns.TimeText(math.max(left, 0))) or "?",
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
    GameTooltip:AddDoubleLine(rec.exact and "Deposit lost if it expires" or "Deposit lost if it expires (estimate)",
        deposit and ns.Money(deposit) or "?", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
    GameTooltip:AddDoubleLine(("Buyback loses the %s%% cut"):format(tostring(ns.db.cutPct)), cut and ns.Money(cut) or "?",
        NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
    if saving then
        if worth then
            GameTooltip:AddLine(("Buying it back saves %s."):format(ns.Money(saving)), GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b, true)
        elseif saving > 0 then
            GameTooltip:AddLine(("Saves only %s: under your minimum."):format(ns.Money(saving)), GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
        else
            GameTooltip:AddLine("Not worth it: the cut is more than the deposit.", GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
        end
    end
    if rec.commodity then
        GameTooltip:AddLine("Sold by unit: a purchase takes the cheapest units first, so this only works while theirs is the lowest price.",
            GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
    end
    if rec.owner == ns.Me() then
        GameTooltip:AddLine("Yours: someone else (an alt on another account, a guildmate) has to buy it.",
            GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: find it at the auction house", GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
    GameTooltip:AddLine(rec.muted and "Right-click: warn about it again" or "Right-click: no warnings for it",
        GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
    GameTooltip:Show()
end

local function ItemIcon(rec)
    local get = C_Item and C_Item.GetItemIconByID
    if get and rec.item then
        local ok, icon = pcall(get, rec.item)
        if ok and icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function Verdict(rec)
    local deposit, cut, saving, worth = ns.Worth(rec)
    if not cut or not deposit then
        return Color(GRAY_FONT_COLOR, "Deposit or price unknown")
    end
    local d = ns.Money(deposit) .. (rec.exact and "" or "?") .. " (" .. ns.Hours((ns.ListedDur(rec))) .. "h)"
    if worth then
        return Color(GREEN_FONT_COLOR, ("Buy back: saves %s"):format(ns.Money(saving))) .. "  "
            .. Color(GRAY_FONT_COLOR, ("deposit %s, cut %s"):format(d, ns.Money(cut)))
    end
    if saving and saving > 0 then
        return Color(GRAY_FONT_COLOR, ("Let it expire: saves only %s"):format(ns.Money(saving))) .. "  "
            .. Color(GRAY_FONT_COLOR, ("deposit %s, cut %s"):format(d, ns.Money(cut)))
    end
    return Color(GRAY_FONT_COLOR, ("Let it expire: cut %s, deposit %s"):format(ns.Money(cut), d))
end

local function FillRow(b, rec, now)
    b.rec = rec
    b.Icon:SetTexture(ItemIcon(rec))
    b.Name:SetText(ns.ItemName(rec))
    local left = ns.Left(rec, now)
    local t = left and ((rec.approx and "~" or "") .. ns.TimeText(math.max(left, 0))) or "?"
    if left and left <= (Num(ns.db.warnMinutes) or 15) * 60 then t = Color(RED_FONT_COLOR, t) end
    b.Time:SetText(t)
    local owner = rec.owner == ns.Me() and "You" or (rec.owner or "?")
    if rec.muted then owner = owner .. " (muted)" end
    b.Detail:SetText(Color(NORMAL_FONT_COLOR, owner) .. "  " .. Verdict(rec))
    b:Show()
end

---------------------------------------------------------------------------
-- This post (the sell frame)
---------------------------------------------------------------------------
local function SellFrame()
    local ah = AuctionHouseFrame
    if type(ah) ~= "table" then return nil end
    for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
        local f = ah[key]
        if type(f) == "table" and f.IsShown and f:IsShown() then return f end
    end
    return nil
end

-- deposit, price, item link, hours of what the sell frame would post now (nil when nothing is in it)
function UI.PostPreview()
    local f = SellFrame()
    if not f then return nil end
    local okI, loc = pcall(f.GetItem, f)
    if not okI or not loc then return nil end
    local okD, deposit = pcall(f.GetDepositAmount, f)
    local okP, price = pcall(f.GetTotalPrice, f)
    deposit, price = okD and Num(deposit) or nil, okP and Num(price) or nil
    local link
    if C_Item and C_Item.GetItemLink then
        local ok, v = pcall(C_Item.GetItemLink, loc)
        link = ok and ns.Str(v) or nil
    end
    local okT, dur = pcall(function() return f:GetDuration() end)
    dur = okT and Num(dur) or nil
    return deposit, price, link, (dur == 1 or dur == 2 or dur == 3) and ns.Hours(dur) or nil
end

local function PreviewText()
    local deposit, price, link, hours = UI.PostPreview()
    if not deposit or not price or price <= 0 then return nil end
    local cut = math.floor(price * (Num(ns.db.cutPct) or 5) / 100 + 0.5)
    local saving = deposit - cut
    local head = Color(NORMAL_FONT_COLOR, "This post") .. "  " .. (link or "")
    local body
    if saving > 0 then
        body = ("Unsold, it loses the %s deposit. A buyback costs only the %s cut: saves %s."):format(
            ns.Money(deposit), ns.Money(cut), Color(GREEN_FONT_COLOR, ns.Money(saving)))
    else
        body = ("Unsold, it loses the %s deposit. A buyback would cost the %s cut: not worth it."):format(
            ns.Money(deposit), ns.Money(cut))
    end
    if hours then body = ("Listed for %d hours. "):format(hours) .. body end
    return head .. "\n" .. body
end
UI.PreviewText = PreviewText

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local function Build()
    if panel or type(AuctionHouseFrame) ~= "table" then return panel end
    local f, used = Template("Frame", "DepositSaverPanel", AuctionHouseFrame, { "ButtonFrameTemplate", "BasicFrameTemplateWithInset" })
    UI.template = used
    panel = f
    UI.panel = f
    f:SetSize(WIDTH, 538)               -- the auction house window's height
    f:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 2, 0)
    if used == "ButtonFrameTemplate" and ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
    if used == "ButtonFrameTemplate" and ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
    SetTitle(f, "Buybacks")
    local inset = f.Inset or f
    if f.CloseButton then
        f.CloseButton:HookScript("OnClick", function()
            ns.db.panel = false
            ns.Print("Buyback list hidden. /deposits panel (or the options) shows it again.")
            if ns.HasKit() and ns.Options.Ready() then pcall(ns.Kit.Sync) end
        end)
    end

    preview = f:CreateFontString(nil, "ARTWORK")
    Font(preview, "GameFontHighlightSmall")
    preview:SetJustifyH("LEFT")
    preview:SetJustifyV("TOP")
    preview:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
    preview:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -8, -8)
    UI.preview = preview

    local scroll = Template("ScrollFrame", "DepositSaverPanelScroll", inset, { "UIPanelScrollFrameTemplate" })
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 26)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 40, ROW_H)
    scroll:SetScrollChild(content)
    UI.scroll, UI.content = scroll, content

    local empty = f:CreateFontString(nil, "ARTWORK")
    Font(empty, "GameFontDisable")
    empty:SetJustifyH("CENTER")
    empty:SetPoint("TOPLEFT", inset, "TOPLEFT", 16, -60)
    empty:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -16, -60)
    empty:SetText("No auctions tracked yet.\n\nYours show up here once the Auctions tab has loaded them. "
        .. "Guild and group members with Deposit Saver share theirs by themselves; /deposits add First Last "
        .. "shares with a character on another account.")
    UI.empty = empty

    local foot = f:CreateFontString(nil, "ARTWORK")
    Font(foot, "GameFontNormalSmall")
    foot:SetJustifyH("LEFT")
    foot:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 8, 8)
    foot:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -8, 8)
    UI.foot = foot

    for i = 1, ROWS do MakeRow(content, i) end
    return f
end

function UI.Refresh()
    if not ns.db then return end
    if not (ns.db.panel and ns.AuctionHouseOpen()) then
        if panel then panel:Hide() end
        return
    end
    Build()
    if not panel then return end
    panel:Show()
    local now = ns.ServerNow()
    local list = ns.Records()
    local text = PreviewText()
    local top = 0
    if text then
        preview:SetText(text)
        preview:Show()
        local ok, h = pcall(preview.GetStringHeight, preview)
        top = math.max(44, ((ok and Num(h)) or 30) + 14)
    else
        preview:SetText("")
        preview:Hide()
    end
    UI.scroll:ClearAllPoints()
    UI.scroll:SetPoint("TOPLEFT", panel.Inset or panel, "TOPLEFT", 4, -4 - top)
    UI.scroll:SetPoint("BOTTOMRIGHT", panel.Inset or panel, "BOTTOMRIGHT", -26, 26)
    for i = #rows + 1, #list do MakeRow(UI.content, i) end
    local worth = 0
    for i, b in ipairs(rows) do
        local rec = list[i]
        if rec then
            FillRow(b, rec, now)
            if select(4, ns.Worth(rec)) then worth = worth + 1 end
        else
            b.rec = nil
            b:Hide()
        end
    end
    UI.content:SetHeight(math.max(#list, 1) * ROW_H)
    UI.empty:SetShown(#list == 0 and not text)
    UI.foot:SetText(#list == 0 and ("Cut " .. tostring(ns.db.cutPct) .. "%")
        or ("%d tracked, %d worth buying back. Cut %s%%."):format(#list, worth, tostring(ns.db.cutPct)))
end

-- Hooked once the auction house exists: refresh when its view or the sell frame changes.
function UI.Attach()
    local ah = AuctionHouseFrame
    if type(ah) ~= "table" or not hooksecurefunc then return end
    if ah.SetDisplayMode then hooksecurefunc(ah, "SetDisplayMode", function() pcall(UI.Refresh) end) end
    for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
        local sf = ah[key]
        if type(sf) == "table" and sf.UpdatePostState then
            hooksecurefunc(sf, "UpdatePostState", function()
                pcall(ns.CacheSellState, sf)
                pcall(UI.Refresh)
            end)
        end
    end
    if ah.HookScript then
        ah:HookScript("OnShow", function() pcall(UI.Refresh) end)
        ah:HookScript("OnHide", function() if panel then panel:Hide() end end)
    end
    UI.attached = true
end

ns.Listen(function() if ns.AuctionHouseOpen() or UI.Visible() then UI.Refresh() end end)

-- A ticker keeps the time left current while the list is open.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(15, function() if UI.Visible() then pcall(UI.Refresh) end end)
end

LookShotsTargets = type(LookShotsTargets) == "table" and LookShotsTargets or {}
LookShotsTargets["DepositSaver"] = {
    version = ns.VERSION,
    frames = {
        { label = "buyback list", frame = function() return panel end },
    },
}
