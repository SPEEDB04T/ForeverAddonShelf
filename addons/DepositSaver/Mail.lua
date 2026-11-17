-- Deposit Saver: sending a bought-back item home. When you buy back a guildmate's, a group
-- member's or an alt's auction, the addon remembers who sold it and for how much. At a
-- mailbox a list next to the mail window shows those items: one click takes the item out of
-- the inbox (where the auction house puts it), the next fills in the game's Send Mail form
-- (the seller, the item attached, Cash on Delivery for the price you paid, a subject). You
-- press Send yourself. The seller pays the COD, gets the item back to post again, and the
-- buyback cost them only the auction house cut.
--
-- Copies: the window is ButtonFrameTemplate, like the mail window itself. Each row inherits
-- the inbox's own MailItemTemplate (Blizzard_MailFrame/MailFrame.xml) with its scripts
-- replaced; the row's button is UIPanelButtonTemplate, like the mail window's buttons.
local _, ns = ...
local Num, Str, Secret = ns.Num, ns.Str, ns.Secret

local Mail = {}
ns.Mail = Mail
local KEEP = 30 * 86400      -- mail is returned after 30 days; forget older buybacks
local ROWS = 6
local panel
local rows = {}
Mail.rows = rows

---------------------------------------------------------------------------
-- What to send back
---------------------------------------------------------------------------
-- Called just before a bought-back auction is forgotten.
function Mail.Remember(rec)
    if type(rec) ~= "table" or not Str(rec.owner) or not Num(rec.item) then return end
    if ns.IsMine(rec.owner) or rec.commodity then return end
    local price = ns.Price(rec)
    if not price or price <= 0 then return end
    ns.db.sendBack[rec.id] = {
        id = rec.id, seller = rec.owner, item = rec.item, link = rec.link,
        qty = Num(rec.qty) or 1, price = price, at = ns.ServerNow(),
    }
    return ns.db.sendBack[rec.id]
end

function Mail.Prune(now)
    now = now or ns.ServerNow()
    for id, e in pairs(ns.db.sendBack) do
        if type(e) ~= "table" or (Num(e.at) or 0) < now - KEEP then ns.db.sendBack[id] = nil end
    end
end

function Mail.Entries()
    local out = {}
    for _, e in pairs(ns.db.sendBack) do
        if type(e) == "table" then out[#out + 1] = e end
    end
    table.sort(out, function(a, b) return (Num(a.at) or 0) < (Num(b.at) or 0) end)
    return out
end

function Mail.Forget(id)
    ns.db.sendBack[id] = nil
    Mail.Refresh()
end

---------------------------------------------------------------------------
-- Where the item is now
---------------------------------------------------------------------------
local function ItemInfo(bag, slot)
    if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" then return info end
end

local function LastBag()
    return Num(NUM_TOTAL_EQUIPPED_BAG_SLOTS) or Num(NUM_BAG_SLOTS) or 4
end

-- The bag slot holding this item, best match first: the same link and stack size.
-- `used` keeps two identical buybacks from claiming the same slot.
function Mail.FindInBags(e, used)
    if not (C_Container and C_Container.GetContainerNumSlots) then return nil end
    local best, bestScore
    for bag = 0, LastBag() do
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (ok and Num(n)) or 0 do
            local info = ItemInfo(bag, slot)
            local key = bag .. ":" .. slot
            if info and not (used and used[key]) and not Secret(info.itemID) and info.itemID == e.item
                and not info.isLocked and not info.isBound then
                local score = 1
                if Str(e.link) and info.hyperlink == e.link then score = score + 2 end
                if Num(info.stackCount) == e.qty then score = score + 1 end
                if not bestScore or score > bestScore then best, bestScore = { bag, slot, key }, score end
            end
        end
    end
    if best then return best[1], best[2], best[3] end
end

-- The inbox mail holding this item. Mails with a COD on them are skipped: taking from one
-- would pay it.
function Mail.FindInInbox(e, used)
    if not (GetInboxNumItems and GetInboxItem) then return nil end
    local ok, n = pcall(GetInboxNumItems)
    for i = 1, (ok and Num(n)) or 0 do
        local hok, _, _, _, _, _, cod, _, hasItem = pcall(GetInboxHeaderInfo, i)
        if hok and hasItem and (Num(cod) or 0) == 0 then
            for a = 1, Num(ATTACHMENTS_MAX_RECEIVE) or 16 do
                local iok, _, itemID = pcall(GetInboxItem, i, a)
                local key = i .. ":" .. a
                if iok and itemID == e.item and not (used and used[key]) then return i, a, key end
            end
        end
    end
end

-- Each entry with where it is: "bags", "inbox" or nil (not found here).
function Mail.Locate()
    local list, usedBags, usedMail = Mail.Entries(), {}, {}
    for _, e in ipairs(list) do
        e.where, e.bag, e.slot, e.mail, e.attach = nil, nil, nil, nil, nil
        local bag, slot, key = Mail.FindInBags(e, usedBags)
        if bag then
            usedBags[key] = true
            e.where, e.bag, e.slot = "bags", bag, slot
        else
            local i, a, mkey = Mail.FindInInbox(e, usedMail)
            if i then
                usedMail[mkey] = true
                e.where, e.mail, e.attach = "inbox", i, a
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- The two clicks
---------------------------------------------------------------------------
function Mail.Subject(e)
    return ("Bought back: %s"):format(ns.PlainName(e))
end

local function MailOpen()
    return type(MailFrame) == "table" and MailFrame.IsShown ~= nil and MailFrame:IsShown() == true
end
Mail.MailOpen = MailOpen

local function Attached()
    local n = 0
    for i = 1, Num(ATTACHMENTS_MAX_SEND) or 12 do
        local ok, has = pcall(HasSendMailItem, i)
        if ok and has then n = n + 1 end
    end
    return n
end

function Mail.TakeOut(e)
    if not (e.mail and TakeInboxItem) then return false end
    local ok = pcall(TakeInboxItem, e.mail, e.attach)
    if ok then ns.Print(("Taking %s out of the mailbox. Click Fill in next."):format(ns.ItemName(e))) end
    return ok
end

-- Fills in the Send Mail form. The player presses Send.
function Mail.Fill(e)
    if not MailOpen() then
        ns.Print("Open a mailbox first.")
        return false
    end
    if not (e.bag and SendMailNameEditBox and ClickSendMailItemButton and C_Container and C_Container.PickupContainerItem) then
        ns.Print(("%s isn't in your bags."):format(ns.ItemName(e)))
        return false
    end
    if Attached() > 0 then
        ns.Print("The Send Mail form already has items attached. Send or clear that mail first, then click Fill in again.")
        return false
    end
    if MailFrameTab_OnClick and not (SendMailFrame and SendMailFrame:IsShown()) then
        pcall(MailFrameTab_OnClick, nil, 2)
    end
    if ClearCursor then pcall(ClearCursor) end
    pcall(C_Container.PickupContainerItem, e.bag, e.slot)
    pcall(ClickSendMailItemButton)
    if CursorHasItem and CursorHasItem() then
        pcall(ClearCursor)
        ns.Print("Couldn't attach the item.")
        return false
    end
    SendMailNameEditBox:SetText(e.seller)
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetText(Mail.Subject(e)) end
    if SendMailRadioButton_OnClick then pcall(SendMailRadioButton_OnClick, 2) end
    if MoneyInputFrame_SetCopper and SendMailMoney then pcall(MoneyInputFrame_SetCopper, SendMailMoney, e.price) end
    if SendMailFrame_Update then pcall(SendMailFrame_Update) end
    if SendMailFrame_CanSend then pcall(SendMailFrame_CanSend) end
    Mail.filled = e.id
    ns.Print(("Filled in: %s to %s, Cash on Delivery %s. Check it and press Send."):format(
        ns.ItemName(e), e.seller, ns.Money(e.price)))
    return true
end

-- The next step for an entry, as the row's button does it.
function Mail.Act(e)
    if e.where == "inbox" then return Mail.TakeOut(e) end
    if e.where == "bags" then return Mail.Fill(e) end
    ns.Print(("%s isn't in your bags or this mailbox. Right-click it to stop listing it."):format(ns.ItemName(e)))
    return false
end

-- SendMail goes out: if it carries a filled-in buyback to its seller, note it for MAIL_SEND_SUCCESS.
local function OnSendMail(name)
    Mail.sending = nil
    local e = Mail.filled and ns.db.sendBack[Mail.filled]
    if not e or type(name) ~= "string" or Secret(name) then return end
    if name:lower():gsub("%s+$", "") ~= e.seller:lower() then return end
    for i = 1, Num(ATTACHMENTS_MAX_SEND) or 12 do
        local ok, _, itemID = pcall(GetSendMailItem, i)
        if ok and itemID == e.item then
            Mail.sending = e.id
            return
        end
    end
end
Mail.OnSendMail = OnSendMail

local hooked
function Mail.Hook()
    if hooked or not hooksecurefunc then return end
    if type(SendMail) == "function" then
        hooked = true
        hooksecurefunc("SendMail", function(name) pcall(OnSendMail, name) end)
    end
end

function Mail.OnEvent(event)
    if event == "MAIL_SHOW" then
        Mail.Hook()
        Mail.Attach()
        Mail.Refresh()
    elseif event == "MAIL_SEND_SUCCESS" then
        local e = Mail.sending and ns.db.sendBack[Mail.sending]
        if e then
            ns.Print(("Sent %s back to %s, Cash on Delivery %s."):format(ns.ItemName(e), e.seller, ns.Money(e.price)))
            ns.db.sendBack[e.id] = nil
        end
        Mail.sending, Mail.filled = nil, nil
        Mail.Refresh()
    elseif event == "MAIL_FAILED" then
        Mail.sending = nil
    elseif event == "MAIL_CLOSED" then
        Mail.filled, Mail.sending = nil, nil
        if panel then panel:Hide() end
    else
        Mail.Refresh()
    end
end

---------------------------------------------------------------------------
-- The list next to the mail window
---------------------------------------------------------------------------
local function Font(fs, object)
    if fs and _G[object] then fs:SetFontObject(_G[object]) end
end

local function Template(frameType, name, parent, templates)
    for _, t in ipairs(templates) do
        local ok, f = pcall(CreateFrame, frameType, name, parent, t)
        if ok and f then return f, t end
    end
    return CreateFrame(frameType, name, parent), nil
end

local function ShowTip(owner, e)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if Str(e.link) and GameTooltip.SetHyperlink then
        pcall(GameTooltip.SetHyperlink, GameTooltip, e.link)
    else
        GameTooltip:SetText(ns.PlainName(e))
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Bought back from", e.seller, 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("You paid", ns.Money(e.price), 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddLine("Mailed back with Cash on Delivery for the same price: you get your gold back, "
        .. e.seller .. " gets the item to post again.", 1, 1, 1, true)
    if e.where == "inbox" then
        GameTooltip:AddLine("Click: take it out of the mailbox.", 0, 1, 0)
    elseif e.where == "bags" then
        GameTooltip:AddLine("Click: fill in the mail. You press Send.", 0, 1, 0)
    else
        GameTooltip:AddLine("Not in your bags or this mailbox.", 0.5, 0.5, 0.5)
    end
    GameTooltip:AddLine("Right-click: stop listing it.", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

local function MakeRow(parent, i)
    local name = "DepositSaverMailRow" .. i
    local r, used = Template("Frame", name, parent, { "MailItemTemplate" })
    r:SetSize(305, 45)
    r:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -6 - (i - 1) * 49)
    r.template = used
    r.sender = _G[name .. "Sender"]
    r.subject = _G[name .. "Subject"]
    r.expire = _G[name .. "ExpireTime"]
    local function T(v) return type(v) == "table" and v or nil end
    r.icon = T(rawget(r, "Button")) or T(_G[name .. "Button"])
    if not r.sender then
        r.sender = r:CreateFontString(nil, "ARTWORK")
        Font(r.sender, "GameFontNormal")
        r.sender:SetPoint("TOPLEFT", r, "TOPLEFT", 47, -4)
    end
    if not r.subject then
        r.subject = r:CreateFontString(nil, "ARTWORK")
        Font(r.subject, "GameFontHighlightSmall")
        r.subject:SetPoint("TOPLEFT", r.sender, "BOTTOMLEFT", 0, 0)
    end
    r.subject:SetWidth(170)
    r.subject:SetJustifyH("LEFT")
    if not r.icon then
        r.icon = CreateFrame("Button", nil, r, "ItemButtonTemplate")
        r.icon:SetSize(37, 37)
        r.icon:SetPoint("TOPLEFT", r, "TOPLEFT", 4, -3)
    end
    -- the inbox's scripts on the template's button are replaced with ours
    if r.icon.UnregisterAllEvents then r.icon:UnregisterAllEvents() end
    if r.icon.RegisterForClicks then r.icon:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    r.icon:Show()
    local cod = _G[name .. "ButtonCOD"]
    local codBg = _G[name .. "ButtonCODBackground"]
    r.codMark = { cod, codBg }
    r.count = _G[name .. "ButtonCount"]
    r.iconTex = T(rawget(r.icon, "Icon")) or T(_G[name .. "ButtonIcon"])

    local b = Template("Button", nil, r, { "UIPanelButtonTemplate" })
    b:SetSize(82, 22)
    b:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -4, 4)
    r.action = b

    local function Click(_, button)
        local e = r.entry
        if not e then return end
        if button == "RightButton" then
            ns.Print(("Stopped listing %s."):format(ns.ItemName(e)))
            Mail.Forget(e.id)
            return
        end
        if r.icon.SetChecked then r.icon:SetChecked(false) end
        Mail.Act(e)
        Mail.Refresh()
    end
    r.icon:SetScript("OnClick", Click)
    r.icon:SetScript("OnEvent", nil)
    r.icon:SetScript("OnUpdate", nil)
    r.icon:SetScript("OnEnter", function(self) if r.entry then ShowTip(self, r.entry) end end)
    r.icon:SetScript("OnLeave", HideTip)
    b:SetScript("OnClick", function(self) Click(self, "LeftButton") end)
    b:SetScript("OnEnter", function(self) if r.entry then ShowTip(self, r.entry) end end)
    b:SetScript("OnLeave", HideTip)
    if r.expire then
        r.expire:SetScript("OnEnter", nil)
        r.expire:SetScript("OnLeave", nil)
    end
    rows[i] = r
    return r
end

local function Build()
    if panel or type(MailFrame) ~= "table" then return panel end
    local f, used = Template("Frame", "DepositSaverMailPanel", MailFrame, { "ButtonFrameTemplate", "BasicFrameTemplateWithInset" })
    Mail.template = used
    panel, Mail.panel = f, f
    local ok, h = pcall(MailFrame.GetHeight, MailFrame)
    f:SetSize(338, (ok and Num(h) and h > 200) and h or 424)
    if used == "ButtonFrameTemplate" and ButtonFrameTemplate_HidePortrait then pcall(ButtonFrameTemplate_HidePortrait, f) end
    if used == "ButtonFrameTemplate" and ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
    if f.SetTitle then pcall(f.SetTitle, f, "Send back") elseif f.TitleText then f.TitleText:SetText("Send back") end
    if f.CloseButton then
        f.CloseButton:HookScript("OnClick", function()
            ns.db.mailPanel = false
            ns.Print("Send-back list hidden. /deposits mail shows it again.")
            if ns.HasKit() and ns.Options.Ready() then pcall(ns.Kit.Sync) end
        end)
    end
    local inset = f.Inset or f
    Mail.inset = inset
    local note = f:CreateFontString(nil, "ARTWORK")
    Font(note, "GameFontHighlightSmall")
    note:SetJustifyH("LEFT")
    note:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 10, 10)
    note:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -10, 10)
    Mail.note = note
    for i = 1, ROWS do MakeRow(inset, i) end
    return f
end

local function Anchor()
    if not panel then return end
    panel:ClearAllPoints()
    -- an opened letter sits to the right of the mail window: go next to it then
    if type(OpenMailFrame) == "table" and OpenMailFrame.IsShown and OpenMailFrame:IsShown() then
        panel:SetPoint("TOPLEFT", OpenMailFrame, "TOPRIGHT", 2, 0)
    else
        panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 2, 0)
    end
end
Mail.Anchor = Anchor

local function Fill(r, e)
    r.entry = e
    r.sender:SetText(e.seller)
    local state
    if e.where == "inbox" then state = "in your mailbox"
    elseif e.where == "bags" then state = "in your bags"
    else state = "|cff808080not here|r" end
    r.subject:SetText(ns.PlainName(e) .. " - " .. state)
    if r.expire then
        if r.expire.SetText then r.expire:SetText(ns.Money(e.price)) end
        r.expire:Show()
    end
    local tex
    if C_Item and C_Item.GetItemIconByID then
        local ok, t = pcall(C_Item.GetItemIconByID, e.item)
        if ok then tex = t end
    end
    if r.iconTex and r.iconTex.SetTexture then r.iconTex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark") end
    for _, t in ipairs(r.codMark) do if t then t:Show() end end   -- the inbox's own "COD" mark
    if r.count and r.count.SetText then r.count:SetText(e.qty > 1 and e.qty or "") end
    if e.where == "inbox" then
        r.action:SetText("Take out"); r.action:Enable()
    elseif e.where == "bags" then
        r.action:SetText("Fill in"); r.action:Enable()
    else
        r.action:SetText("Fill in"); r.action:Disable()
    end
    r:Show()
end

function Mail.Refresh()
    if not ns.db then return end
    local list = Mail.Entries()
    if not (MailOpen() and ns.db.mailPanel and #list > 0) then
        if panel then panel:Hide() end
        return
    end
    Build()
    if not panel then return end
    Anchor()
    list = Mail.Locate()
    for i = #rows + 1, math.min(#list, ROWS) do MakeRow(Mail.inset, i) end
    for i, r in ipairs(rows) do
        if list[i] and i <= ROWS then Fill(r, list[i]) else r.entry = nil; r:Hide() end
    end
    local text = "One click takes an item out of the mailbox, the next fills in the mail with Cash on Delivery for what you paid. You press Send."
    if #list > ROWS then text = ("%d more after these are sent. "):format(#list - ROWS) .. text end
    Mail.note:SetText(text)
    panel:Show()
end

local attached
function Mail.Attach()
    if attached or type(MailFrame) ~= "table" then return end
    attached = true
    if MailFrame.HookScript then MailFrame:HookScript("OnHide", function() if panel then panel:Hide() end end) end
    if type(OpenMailFrame) == "table" and OpenMailFrame.HookScript then
        OpenMailFrame:HookScript("OnShow", Anchor)
        OpenMailFrame:HookScript("OnHide", Anchor)
    end
end

function Mail.Visible()
    return panel ~= nil and panel:IsShown() == true
end

-- /deposits mail
function Mail.Slash()
    local list = Mail.Locate()
    if MailOpen() then
        ns.db.mailPanel = not ns.db.mailPanel
        ns.Print(ns.db.mailPanel and "Send-back list shown." or "Send-back list hidden.")
        Mail.Refresh()
    end
    if #list == 0 then
        ns.Print("Nothing to send back. Items you buy back from someone show up here, ready to mail to them with Cash on Delivery.")
        return
    end
    ns.Print(#list .. " bought back, to mail back with Cash on Delivery:")
    for _, e in ipairs(list) do
        local where = e.where == "bags" and "in your bags" or e.where == "inbox" and "in your mailbox" or "not found here"
        ns.Print(("%s to %s for %s (%s)"):format(ns.ItemName(e), e.seller, ns.Money(e.price), where))
    end
end

if type(LookShotsTargets) == "table" and type(LookShotsTargets["DepositSaver"]) == "table" then
    local t = LookShotsTargets["DepositSaver"]
    t.frames = type(t.frames) == "table" and t.frames or {}
    t.frames[#t.frames + 1] = { label = "send-back list", frame = function() return panel end }
end

ns.Listen(function() if MailOpen() then Mail.Refresh() end end)
