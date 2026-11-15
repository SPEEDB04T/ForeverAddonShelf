-- Slutmog Shop: the shop window (/slutshop, right-click on the minimap button).
--
-- It copies the game's Macro window (Blizzard_MacroUI.xml, Gethe/wow-ui-source branch
-- forever): the portrait window (ButtonFrameTemplate, 460 x 450 here against the macro
-- window's 338 x 424, for a list wide enough for item names and prices), top tabs
-- (PanelTopTabButtonTemplate at 51, -28, the second hanging off the first), 80 x 22 panel
-- buttons in the button bar (BOTTOMLEFT 4, 4 / BOTTOMRIGHT -5, 4 and -82, 4), and the text
-- shown on a TooltipBackdropTemplate box as the macro text is.
--   Wares tab:  an item slot (ItemButtonTemplate, the bag and mail slot), the game's money
--               input (MoneyInputFrameTemplate, gold and silver) and an Add button; under it
--               the wares, one row each, with the quest log's row highlight.
--   Lines tab:  the shop name (InputBoxTemplate) and two multi-line boxes
--               (InputScrollFrameTemplate) for the openers and the ad lines.
--   Under both: where ads go (WowStyle1DropdownTemplate), the next ad as it will read and
--               its length, like the macro window's character count.
-- Every template is looked for before use, so a client (or a test) without one still works.
local ADDON, ns = ...
local UI = {}
ns.UI = UI

local W, H = 460, 450
local PREVIEW_H = 104
local ROW_H = 22
local EMPTY_SLOT = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"
local ROW_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local frame, tab, slotLink
local rows = {}

local function Has(t, k)
    return type(t) == "table" and type(t[k]) == "table"
end

local function FromTemplate(kind, parent, template, name)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and f then return f end
end

local function Text(parent, font, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK", font)
    if fs.SetFontObject and _G[font] then pcall(fs.SetFontObject, fs, _G[font]) end
    return fs
end

local function Color(c, r, g, b)
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return r, g, b
end

local function Sound(kit)
    if kit and type(PlaySound) == "function" then pcall(PlaySound, kit) end
end

local function Button(parent, label, w, h)
    local b = FromTemplate("Button", parent, "UIPanelButtonTemplate") or CreateFrame("Button", nil, parent)
    b:SetSize(w or 80, h or 22)
    b:SetText(label)
    return b
end

local function Tip(owner, title, ...)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then GameTooltip:AddLine(line, Color(NORMAL_FONT_COLOR, 1, 0.82, 0)) end
    end
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

local function OnHover(widget, title, ...)
    local lines = { ... }
    widget:SetScript("OnEnter", function(self) Tip(self, title, unpack(lines)) end)
    widget:SetScript("OnLeave", HideTip)
end

local function SplitLines(text)
    local out = {}
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\r?\n") do out[#out + 1] = line end
    return out
end

local function JoinLines(list)
    return table.concat(list or {}, "\n")
end

local function Focused(box)
    return type(box) == "table" and type(box.HasFocus) == "function" and box:HasFocus()
end

---------------------------------------------------------------------------
-- The slot: drop an item on it, or shift-click one while the window is open
---------------------------------------------------------------------------
local function SlotIcon(texture)
    local slot = frame.slot
    if type(SetItemButtonTexture) == "function" and pcall(SetItemButtonTexture, slot, texture) then return end
    if Has(slot, "icon") then slot.icon:SetTexture(texture) end
end

local function SlotQuality(quality, link)
    local slot = frame.slot
    if type(SetItemButtonQuality) == "function" then pcall(SetItemButtonQuality, slot, quality, link) end
end

local function GetPrice()
    local money = frame.money
    if Has(money, "gold") and type(MoneyInputFrame_GetCopper) == "function" then
        local ok, copper = pcall(MoneyInputFrame_GetCopper, money)
        if ok and type(copper) == "number" then return copper end
    end
    if money and money.GetText then return ns.ParsePrice(money:GetText()) end
end

local function SetPrice(copper)
    local money = frame.money
    if not money then return end
    if type(MoneyInputFrame_SetCopper) == "function" and Has(money, "gold") then
        if not copper then
            if type(MoneyInputFrame_ResetMoney) == "function" then pcall(MoneyInputFrame_ResetMoney, money) end
            return
        end
        pcall(MoneyInputFrame_SetCopper, money, copper)
    elseif money.SetText then
        money:SetText(copper and ns.PriceText(copper, "short") or "")
    end
end

local function SyncSlot()
    local slot = frame.slot
    if not slotLink then
        SlotIcon(EMPTY_SLOT)
        SlotQuality(nil)
        frame.slotName:SetFontObject(GameFontDisable)
        frame.slotName:SetText("Drop an item here")
        frame.add:SetText("Add")
        frame.add:Disable()
        return
    end
    local name, _, quality, _, _, texture = ns.ItemInfo(slotLink)
    if not texture and C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, t = pcall(C_Item.GetItemIconByID, ns.ItemID(slotLink))
        if ok then texture = t end
    end
    SlotIcon(texture or EMPTY_SLOT)
    SlotQuality(quality, slotLink)
    frame.slotName:SetFontObject(GameFontNormal)
    frame.slotName:SetText(slotLink)
    frame.add:SetText(ns.FindWare(slotLink) and "Change" or "Add")
    frame.add:Enable()
    if slot.Count and slot.Count.Hide then slot.Count:Hide() end
end

function UI.SetSlot(link)
    if not frame then return end
    slotLink = link
    local _, w = ns.FindWare(link)
    if w then SetPrice(w.price) end
    SyncSlot()
    if Has(frame.money, "gold") and frame.money.gold.SetFocus then frame.money.gold:SetFocus() end
end

function UI.ClearSlot()
    if not frame then return end
    slotLink = nil
    SetPrice(nil)
    if frame.money and type(MoneyInputFrame_ClearFocus) == "function" then pcall(MoneyInputFrame_ClearFocus, frame.money) end
    SyncSlot()
end

local function DropCursorItem()
    if type(GetCursorInfo) ~= "function" then return false end
    local kind, _, link = GetCursorInfo()
    if kind ~= "item" or type(link) ~= "string" then return false end
    if type(ClearCursor) == "function" then ClearCursor() end
    UI.SetSlot(link)
    return true
end
UI.DropCursorItem = DropCursorItem

function UI.AddFromSlot()
    if not slotLink then return end
    local copper = GetPrice()
    if not copper or copper <= 0 then
        ns.Print("give it a price first, in the gold and silver boxes next to the slot.")
        return
    end
    local ok, text = ns.AddWare(slotLink, copper)
    if not ok then
        ns.Print(text)
        return
    end
    Sound(SOUNDKIT and SOUNDKIT.IG_BACKPACK_COIN_SELECT)
    UI.ClearSlot()
end

-- Shift-click on an item anywhere while the Wares tab is open (hooked in Core.lua).
function UI.TakeLink(text)
    if not (frame and frame:IsShown() and tab == 1) then return end
    if type(text) ~= "string" or not text:find("|Hitem:", 1, true) then return end
    UI.SetSlot(text)
end

---------------------------------------------------------------------------
-- Ware rows
---------------------------------------------------------------------------
local function WareMenu(row, i)
    local w = ns.db.wares[i]
    if not w then return end
    local function Generator(_, root)
        if root.CreateTitle then root:CreateTitle(ns.WareName(w)) end
        root:CreateButton("Advertise it next", function() ns.FeatureNext(i) end)
        local partner = ns.SetWith(i)
        if partner then
            root:CreateButton("Stop selling it as a set with " .. ns.WareName(ns.db.wares[partner]), function() ns.Unpair(i) end)
        elseif w.link then
            local sub = root:CreateButton("Sell as a set with")
            local nested = type(sub) == "table" and type(sub.CreateButton) == "function"
            for j, other in ipairs(ns.db.wares) do
                if j ~= i and other.link and ns.IsBottom(j) ~= ns.IsBottom(i) then    -- a top with a bottom
                    if nested then
                        sub:CreateButton(ns.WareName(other), function() ns.PairWares(i, j) end)
                    else
                        root:CreateButton("Sell as a set with " .. ns.WareName(other), function() ns.PairWares(i, j) end)
                    end
                end
            end
        end
        if w.link then root:CreateButton("Change the price", function() UI.SetSlot(w.link) end) end
        if i > 1 then root:CreateButton("Move up", function() ns.MoveWare(i, -1) end) end
        if i < #ns.db.wares then root:CreateButton("Move down", function() ns.MoveWare(i, 1) end) end
        root:CreateButton("Remove", function() ns.RemoveWare(i) end)
    end
    if MenuUtil and type(MenuUtil.CreateContextMenu) == "function" and pcall(MenuUtil.CreateContextMenu, row, Generator) then
        return
    end
    ns.RemoveWare(i)
    ns.Print((w.link or ns.WareName(w)) .. " is no longer for sale.")
end

local function Row(i)
    if rows[i] then return rows[i] end
    local content = frame.content
    local r = CreateFrame("Button", nil, content)
    rows[i] = r
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetHighlightTexture(ROW_HIGHLIGHT, "ADD")
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(18, 18)
    r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)
    r.stock = Text(r, "GameFontHighlightSmall")
    r.stock:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.stock:SetWidth(76)
    r.stock:SetJustifyH("RIGHT")
    r.price = Text(r, "GameFontHighlightSmall")
    r.price:SetPoint("RIGHT", r.stock, "LEFT", -6, 0)
    r.price:SetWidth(96)
    r.price:SetJustifyH("RIGHT")
    r.name = Text(r, "GameFontHighlight")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.name:SetPoint("RIGHT", r.price, "LEFT", -6, 0)
    r.name:SetJustifyH("LEFT")
    if r.name.SetWordWrap then r.name:SetWordWrap(false) end
    r:SetScript("OnClick", function(self, mouse)
        local w = ns.db.wares[self.index]
        if not w then return end
        if mouse == "RightButton" then
            WareMenu(self, self.index)
        elseif type(IsModifiedClick) == "function" and IsModifiedClick("CHATLINK") and w.link
            and type(HandleModifiedItemClick) == "function" then
            HandleModifiedItemClick(w.link)
        elseif w.link then
            UI.SetSlot(w.link)
        end
    end)
    r:SetScript("OnEnter", function(self)
        local w = ns.db.wares[self.index]
        if not (w and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if w.link and pcall(GameTooltip.SetHyperlink, GameTooltip, w.link) then
            GameTooltip:AddLine(" ")
        else
            GameTooltip:SetText(ns.WareName(w), Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
        end
        if w.unpriced then
            GameTooltip:AddLine("Found in your bags. It has no price yet, so it stays out of the ads.",
                Color(RED_FONT_COLOR, 1, 0.1, 0.1))
        else
            GameTooltip:AddLine("Price in the ad: " .. ns.PriceText(w.price), Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
        end
        local partner, half = ns.SetWith(self.index)
        if partner then
            GameTooltip:AddLine(("Sold as a set with %s: one ad for both, on %s turn."):format(ns.WareName(ns.db.wares[partner]),
                half == "top" and "this one's" or "the top's"), Color(NORMAL_FONT_COLOR, 1, 0.82, 0), true)
        end
        local ads = ns.ItemAds and ns.ItemAds(w.id)
        if ads and ns.db.wording ~= "mine" then
            GameTooltip:AddLine(("%d ready-made ads for it (/slutshop ads shows them)"):format(#ads), Color(NORMAL_FONT_COLOR, 1, 0.82, 0))
        elseif ads then
            GameTooltip:AddLine(("%d ready-made ads, switched off in the options"):format(#ads), Color(NORMAL_FONT_COLOR, 1, 0.82, 0))
        else
            GameTooltip:AddLine("Its ads come from your ad lines", Color(NORMAL_FONT_COLOR, 1, 0.82, 0))
        end
        GameTooltip:AddLine(w.unpriced and "Click: give it a price" or "Click: change the price",
            Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
        GameTooltip:AddLine("Right-click: advertise it next, sell it as a set, move or remove", Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", HideTip)
    return r
end

local function SyncRows()
    local db = ns.db
    local p = ns.Next()
    local nextWare = p and p.ware
    local gr, gg, gb = Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
    local wr, wg, wb = Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
    for i, w in ipairs(db.wares) do
        local r = Row(i)
        r.index = i
        local _, _, _, _, _, texture = ns.ItemInfo(w.link or w.id)
        r.icon:SetTexture(texture or EMPTY_SLOT)
        local n = ns.Count(w)
        local onAH = n ~= nil and n <= 0 and ns.OnAH(w.id) ~= nil
        local under = onAH and ns.Undercut(w.id)
        local out = n ~= nil and n <= 0 and (not onAH or under)
        local partner = ns.SetWith(i)
        local with = partner and ("  |cff808080+ " .. ns.WareName(db.wares[partner]) .. "|r") or ""
        if w.link then
            r.name:SetText((out and ns.WareName(w) or w.link) .. with)
        else
            r.name:SetText(ns.WareName(w) .. " (loading)")
        end
        if out then r.name:SetTextColor(gr, gg, gb) else r.name:SetTextColor(wr, wg, wb) end
        if r.icon.SetDesaturated then r.icon:SetDesaturated(out) end
        if w.unpriced then
            r.price:SetText("No price yet")
            r.price:SetTextColor(Color(RED_FONT_COLOR, 1, 0.1, 0.1))
        else
            r.price:SetText(ns.MoneyText(w.price))
            r.price:SetTextColor(wr, wg, wb)
        end
        if n == nil then
            r.stock:SetText("")
        elseif under then
            r.stock:SetText("Undercut on the AH")
            r.stock:SetTextColor(Color(RED_FONT_COLOR, 1, 0.1, 0.1))
        elseif onAH then
            r.stock:SetText("On the auction house")
            r.stock:SetTextColor(wr, wg, wb)
        elseif out then
            r.stock:SetText("none left")
            r.stock:SetTextColor(gr, gg, gb)
        else
            r.stock:SetText(n .. " in stock")
            r.stock:SetTextColor(wr, wg, wb)
        end
        if i == nextWare then r:LockHighlight() else r:UnlockHighlight() end
        r:Show()
    end
    for i = #db.wares + 1, #rows do rows[i]:Hide() end
    frame.content:SetHeight(math.max(10, #db.wares * ROW_H))
    if #db.wares == 0 then frame.empty:Show() else frame.empty:Hide() end
end

---------------------------------------------------------------------------
-- Where ads go
---------------------------------------------------------------------------
local function ChannelOptions()
    local out, seen = {}, {}
    for _, c in ipairs(ns.JoinedChannels()) do
        local base = c.name:match("^(.-) %- ") or c.name
        if not seen[base:lower()] then
            seen[base:lower()] = true
            out[#out + 1] = { key = base, label = base }
        end
    end
    local current = ns.db.channel
    local here = false
    for _, c in ipairs(ns.FIXED_CHANNELS) do
        out[#out + 1] = { key = c.key, label = c.label }
        if c.key == current then here = true end
    end
    for _, o in ipairs(out) do
        if o.key == current then here = true end
    end
    if not here then table.insert(out, 1, { key = current, label = current .. " (not here)" }) end
    return out
end

local function BuildChannelPicker(parent)
    for _, template in ipairs({ "WowStyle1DropdownTemplate", "WowStyle2DropdownTemplate" }) do
        local dd = FromTemplate("DropdownButton", parent, template)
        if dd and type(dd.SetupMenu) == "function" then
            dd:SetWidth(150)
            dd:SetupMenu(function(_, root)
                for _, o in ipairs(ChannelOptions()) do
                    root:CreateRadio(o.label,
                        function() return ns.db.channel == o.key end,
                        function() ns.Set("channel", o.key) end,
                        o.key)
                end
            end)
            return dd
        end
        if dd and dd.Hide then dd:Hide() end
    end
    -- Without the dropdown: a button that steps through the channels.
    local b = Button(parent, ns.ChannelLabel(ns.db.channel), 150, 22)
    b:SetScript("OnClick", function()
        local list, at = ChannelOptions(), 0
        for k, o in ipairs(list) do if o.key == ns.db.channel then at = k end end
        local o = list[at % #list + 1]
        if o then ns.Set("channel", o.key) end
    end)
    b.fallback = true
    return b
end

---------------------------------------------------------------------------
-- Preview and status
---------------------------------------------------------------------------
local adLink, adLink2         -- the ware the ad shown is about, and the other half of a set

local function ShowItem(item, link)
    local _, _, quality, _, _, texture = ns.ItemInfo(link)
    if not texture and C_Item and type(C_Item.GetItemIconByID) == "function" then
        local ok, t = pcall(C_Item.GetItemIconByID, ns.ItemID(link))
        if ok then texture = t end
    end
    if not (type(SetItemButtonTexture) == "function" and pcall(SetItemButtonTexture, item, texture or EMPTY_SLOT)) then
        item.icon:SetTexture(texture or EMPTY_SLOT)
    end
    if type(SetItemButtonQuality) == "function" then pcall(SetItemButtonQuality, item, quality, link) end
    if type(item.Count) == "table" and item.Count.Hide then item.Count:Hide() end
    item:Show()
end

-- An item button showing the ware an ad is for. links() gives the ware's link and, for a set, the
-- other half's. A click tries it on (a set whole); a shift-click links it.
local function NewItemButton(parent, links, second)
    local item = FromTemplate("Button", parent, "ItemButtonTemplate") or CreateFrame("Button", nil, parent)
    item:SetSize(37, 37)
    if not Has(item, "icon") then
        item.icon = item:CreateTexture(nil, "BORDER")
        item.icon:SetAllPoints(item)
    end
    item:RegisterForClicks("LeftButtonUp")
    item:SetScript("OnClick", function()
        local first, other = links()
        local link = second and other or first
        if not link then return end
        if type(IsModifiedClick) == "function" and IsModifiedClick("CHATLINK") and type(HandleModifiedItemClick) == "function" then
            HandleModifiedItemClick(link)
        elseif type(DressUpItemLink) == "function" then
            pcall(DressUpItemLink, first)                   -- a set is tried on whole
            if other then pcall(DressUpItemLink, other) end
        end
    end)
    item:SetScript("OnEnter", function(self)
        local first, other = links()
        local link = second and other or first
        if not (GameTooltip and link) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if pcall(GameTooltip.SetHyperlink, GameTooltip, link) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(other and "Half of the set this ad is for. Click to try the set on in the dressing room."
                or "The ware this ad is for. Click to try it on in the dressing room.", Color(NORMAL_FONT_COLOR, 1, 0.82, 0), true)
            GameTooltip:Show()
        end
    end)
    item:SetScript("OnLeave", HideTip)
    item:Hide()
    return item
end

---------------------------------------------------------------------------
-- The prompt: when it is time for another ad, a small window in the middle of the screen with
-- the ad as it will read, the ware, a big Post button and Reroll.
---------------------------------------------------------------------------
local prompt
local promptLink, promptLink2

local function SyncPrompt()
    if not (prompt and prompt:IsShown() and ns.db) then return end
    local p, why = ns.Next()
    local w = p and p.ware and ns.db.wares[p.ware]
    promptLink = w and w.link or nil
    local w2 = promptLink and p.ware2 and ns.db.wares[p.ware2]
    promptLink2 = w2 and w2.link or nil
    local text = prompt.text
    text:ClearAllPoints()
    if promptLink then
        ShowItem(prompt.item, promptLink)
        if promptLink2 then
            ShowItem(prompt.item2, promptLink2)
            text:SetPoint("TOPLEFT", prompt.item2, "TOPRIGHT", 10, 0)
        else
            prompt.item2:Hide()
            text:SetPoint("TOPLEFT", prompt.item, "TOPRIGHT", 10, 0)
        end
    else
        prompt.item:Hide()
        prompt.item2:Hide()
        text:SetPoint("TOPLEFT", prompt, "TOPLEFT", 18, -36)
    end
    text:SetPoint("BOTTOMRIGHT", prompt, "BOTTOMRIGHT", -18, 62)
    if p then
        text:SetText(p.text)
        text:SetTextColor(Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
    else
        text:SetText("Nothing to post: " .. tostring(why))
        text:SetTextColor(Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
    end
    prompt.post:SetEnabled(p ~= nil)
    prompt.reroll:SetEnabled(p ~= nil)
end

local function BuildPrompt()
    if prompt then return prompt end
    local f = FromTemplate("Frame", UIParent, "BasicFrameTemplateWithInset", "SlutmogShopPrompt")
        or FromTemplate("Frame", UIParent, "TooltipBackdropTemplate", "SlutmogShopPrompt")
        or CreateFrame("Frame", "SlutmogShopPrompt", UIParent)
    prompt = f
    f:SetSize(440, 196)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if Has(f, "TitleText") then f.TitleText:SetText("Time for an ad") end
    if not Has(f, "CloseButton") then
        local close = FromTemplate("Button", f, "UIPanelCloseButton")
        if close then
            close:SetPoint("TOPRIGHT", 0, 0)
            close:SetScript("OnClick", function() f:Hide() end)
        end
    end
    local function Links() return promptLink, promptLink2 end
    f.item = NewItemButton(f, Links, false)
    f.item:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -36)
    f.item2 = NewItemButton(f, Links, true)
    f.item2:SetPoint("TOPLEFT", f.item, "TOPRIGHT", 4, 0)
    f.text = Text(f, "GameFontHighlight")
    f.text:SetJustifyH("LEFT")
    f.text:SetJustifyV("TOP")
    if f.text.SetWordWrap then f.text:SetWordWrap(true) end

    f.post = Button(f, "Post ad", 200, 40)
    f.post:SetPoint("BOTTOM", f, "BOTTOM", 0, 14)
    if f.post.SetNormalFontObject and GameFontNormalLarge then pcall(f.post.SetNormalFontObject, f.post, GameFontNormalLarge) end
    if f.post.SetHighlightFontObject and GameFontHighlightLarge then pcall(f.post.SetHighlightFontObject, f.post, GameFontHighlightLarge) end
    f.post:SetScript("OnClick", function()
        if ns.Post() then f:Hide() end
    end)
    OnHover(f.post, "Post ad", "Posts the ad above, exactly as it reads.")

    f.reroll = Button(f, "Reroll", 84, 24)
    f.reroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 22)
    f.reroll:SetScript("OnClick", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.Reroll()
    end)
    OnHover(f.reroll, "Reroll", "Another ad for the same ware. The one shown is not voted on; it comes round again later.")

    f.later = Button(f, "Not now", 84, 24)
    f.later:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 22)
    f.later:SetScript("OnClick", function()
        f:Hide()
        if ns.Snooze then ns.Snooze() end
    end)
    OnHover(f.later, "Not now", "Closes this and asks again after the reminder time (Options > Remind me after).")
    f:Hide()
    return f
end

-- Shows the prompt. Not while the shop window is open (it has the same buttons) and not without an ad.
function UI.ShowPrompt(force)
    if not ns.db or not ns.Next() then return false end
    if not force and UI.IsOpen() then return false end
    local ok, err = pcall(BuildPrompt)
    if not ok then
        ns.Print("the ad prompt could not be built: " .. tostring(err))
        return false
    end
    prompt:Show()
    if prompt.Raise then prompt:Raise() end
    SyncPrompt()
    return true
end

function UI.HidePrompt()
    if prompt then prompt:Hide() end
end

function UI.Prompt()
    return prompt
end

local function SyncPreview()
    local p, why = ns.Next()
    local text = frame.preview
    local w = p and p.ware and ns.db.wares[p.ware]
    adLink = w and w.link or nil
    local w2 = adLink and p.ware2 and ns.db.wares[p.ware2]
    adLink2 = w2 and w2.link or nil
    local item, item2 = frame.item, frame.item2
    text:ClearAllPoints()
    if adLink then
        ShowItem(item, adLink)
        if adLink2 then
            ShowItem(item2, adLink2)
            text:SetPoint("TOPLEFT", item2, "TOPRIGHT", 8, 0)
        else
            item2:Hide()
            text:SetPoint("TOPLEFT", item, "TOPRIGHT", 8, 0)
        end
    else
        item:Hide()
        item2:Hide()
        text:SetPoint("TOPLEFT", frame.previewBox, "TOPLEFT", 9, -8)
    end
    text:SetPoint("BOTTOMRIGHT", frame.previewBox, "BOTTOMRIGHT", -9, 8)
    frame.reroll:SetEnabled(p ~= nil)
    if p then
        text:SetText(p.text)
        text:SetTextColor(Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
        frame.count:SetText(("%s%d/%d"):format(p.vote == "yes" and "You voted yes  " or "", #p.text, ns.CHAT_LIMIT))
    else
        text:SetText("Nothing to post: " .. tostring(why))
        text:SetTextColor(Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
        frame.count:SetText("")
    end
    frame.yes:SetEnabled(p ~= nil)
    frame.no:SetEnabled(p ~= nil)
end

local function Ago(seconds)
    if seconds < 90 then return "just now" end
    local m = math.floor(seconds / 60 + 0.5)
    if m < 90 then return m .. " min ago" end
    return math.floor(m / 60 + 0.5) .. " h ago"
end

function UI.Tick()
    if not (frame and frame:IsShown() and ns.db) then return end
    ns.Recheck()
    local wait = ns.Wait()
    local p = ns.Next()
    local chatType, why = ns.ResolveChannel(ns.db.channel)
    local status
    if not chatType then
        status = "Not in " .. ns.ChannelLabel(ns.db.channel) .. " here"
        frame.status.why = why
    elseif wait > 0 then
        status = ("Next ad in %d sec"):format(math.ceil(wait))
        frame.status.why = nil
    elseif ns.lastPostAt then
        status = ("%d posted, last %s"):format(ns.db.posts or 0, Ago(GetTime() - ns.lastPostAt))
        frame.status.why = nil
    else
        status = ("%d ads posted"):format(ns.db.posts or 0)
        frame.status.why = nil
    end
    frame.status:SetText(status)
    frame.post:SetEnabled(p ~= nil and wait <= 0 and chatType ~= nil)
end

---------------------------------------------------------------------------
-- Building the window
---------------------------------------------------------------------------
local function MultiBox(parent, name, w, h)
    local sf = FromTemplate("ScrollFrame", parent, "InputScrollFrameTemplate", name)
    if sf and Has(sf, "EditBox") then
        sf:SetSize(w, h)
        sf.EditBox:SetWidth(w - 18)
        if sf.EditBox.SetMaxLetters then sf.EditBox:SetMaxLetters(0) end
        if Has(sf, "CharCount") then sf.CharCount:Hide() end
        return sf, sf.EditBox
    end
    -- Without the template: the macro window's way, a scroll frame on a tooltip-style box.
    local bg = FromTemplate("Frame", parent, "TooltipBackdropTemplate") or CreateFrame("Frame", nil, parent)
    bg:SetSize(w + 10, h + 10)
    local scroll = FromTemplate("ScrollFrame", bg, "ScrollFrameTemplate") or CreateFrame("ScrollFrame", nil, bg)
    scroll:SetPoint("TOPLEFT", bg, "TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -5, 5)
    local box = CreateFrame("EditBox", name and (name .. "Text") or nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlightSmall)
    box:SetWidth(w - 18)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if scroll.SetScrollChild then scroll:SetScrollChild(box) end
    bg:EnableMouse(true)
    bg:SetScript("OnMouseDown", function() box:SetFocus() end)
    return bg, box
end

local function ListHook(box, set, get)
    box:HookScript("OnTextChanged", function(self, user)
        if user then set(SplitLines(self:GetText())) end
    end)
    box:HookScript("OnEditFocusLost", function(self) self:SetText(JoinLines(get())) end)
end

local function BuildWares(page)
    local slot = FromTemplate("Button", page, "ItemButtonTemplate", "SlutmogShopFrameSlot")
        or CreateFrame("Button", "SlutmogShopFrameSlot", page)
    frame.slot = slot
    slot:SetSize(37, 37)
    slot:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -10)
    if not Has(slot, "icon") then
        slot.icon = slot:CreateTexture(nil, "BORDER")
        slot.icon:SetAllPoints(slot)
    end
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:SetScript("OnReceiveDrag", DropCursorItem)
    slot:SetScript("OnClick", function(_, mouse)
        if DropCursorItem() then return end
        if mouse == "RightButton" then
            UI.ClearSlot()
        elseif slotLink and type(IsModifiedClick) == "function" and IsModifiedClick("CHATLINK")
            and type(HandleModifiedItemClick) == "function" then
            HandleModifiedItemClick(slotLink)
        end
    end)
    slot:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if slotLink and pcall(GameTooltip.SetHyperlink, GameTooltip, slotLink) then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Right-click: empty the slot", Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5))
        else
            GameTooltip:SetText("A ware for your shop", Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1))
            GameTooltip:AddLine("Drop an item here, or shift-click one in your bags while this window is open. "
                .. "Give it a price and click Add.", Color(NORMAL_FONT_COLOR, 1, 0.82, 0), true)
        end
        GameTooltip:Show()
    end)
    slot:SetScript("OnLeave", HideTip)

    frame.slotName = Text(page, "GameFontNormal")
    frame.slotName:SetPoint("TOPLEFT", slot, "TOPRIGHT", 10, -2)
    frame.slotName:SetWidth(230)
    frame.slotName:SetJustifyH("LEFT")
    if frame.slotName.SetWordWrap then frame.slotName:SetWordWrap(false) end

    local money = FromTemplate("Frame", page, "MoneyInputFrameTemplate", "SlutmogShopFramePrice")
    if money and Has(money, "gold") then
        if type(MoneyInputFrame_SetCopperShown) == "function" then pcall(MoneyInputFrame_SetCopperShown, money, false) end
        money:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 14, 1)
        for _, key in ipairs({ "gold", "silver", "copper" }) do
            if Has(money, key) then
                money[key]:HookScript("OnEnterPressed", function()
                    UI.AddFromSlot()
                    if type(MoneyInputFrame_ClearFocus) == "function" then pcall(MoneyInputFrame_ClearFocus, money) end
                end)
            end
        end
    else
        money = FromTemplate("EditBox", page, "InputBoxTemplate") or CreateFrame("EditBox", nil, page)
        money:SetSize(90, 20)
        money:SetAutoFocus(false)
        money:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 16, 0)
        money:SetScript("OnEnterPressed", function(self) UI.AddFromSlot(); self:ClearFocus() end)
        money:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    end
    frame.money = money

    local add = Button(page, "Add")
    frame.add = add
    add:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -17)
    add:SetScript("OnClick", UI.AddFromSlot)
    OnHover(add, "Add to the shop", "Puts the item in the slot on your list at this price, or changes its price if it is already there.")

    local list = FromTemplate("ScrollFrame", page, "ScrollFrameTemplate")
        or FromTemplate("ScrollFrame", page, "UIPanelScrollFrameTemplate")
        or CreateFrame("ScrollFrame", nil, page)
    frame.list = list
    list:SetPoint("TOPLEFT", page, "TOPLEFT", 6, -58)
    list:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -26, 4)
    local content = CreateFrame("Frame", nil, list)
    frame.content = content
    content:SetSize(W - 10 - 6 - 26, 10)
    if list.SetScrollChild then list:SetScrollChild(content) end
    if Has(list, "ScrollBar") and list.ScrollBar.SetHideIfUnscrollable then
        pcall(list.ScrollBar.SetHideIfUnscrollable, list.ScrollBar, true)
    end

    frame.empty = Text(page, "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", page, "TOPLEFT", 40, -90)
    frame.empty:SetPoint("TOPRIGHT", page, "TOPRIGHT", -40, -90)
    frame.empty:SetJustifyH("CENTER")
    frame.empty:SetText("No wares yet. Drop an item on the slot above, or shift-click one in your bags while "
        .. "this window is open, then give it a price.")
end

local function BuildLines(page)
    local shopLabel = Text(page, "GameFontNormal")
    shopLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -15)
    shopLabel:SetText("Shop name")

    local shop = FromTemplate("EditBox", page, "InputBoxTemplate", "SlutmogShopFrameShopName")
        or CreateFrame("EditBox", "SlutmogShopFrameShopName", page)
    frame.shop = shop
    shop:SetSize(300, 20)
    shop:SetPoint("TOPLEFT", page, "TOPLEFT", 106, -10)
    shop:SetAutoFocus(false)
    if shop.SetMaxLetters then shop:SetMaxLetters(60) end
    shop:HookScript("OnTextChanged", function(self, user)
        if user then
            ns.SetShop(self:GetText())
            if frame.SetTitle then pcall(frame.SetTitle, frame, ns.ShopName()) end
        end
    end)
    shop:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    shop:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local boxW = W - 10 - 28
    local openLabel = CreateFrame("Frame", nil, page)
    openLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -40)
    openLabel:SetSize(boxW, 14)
    openLabel.text = Text(openLabel, "GameFontNormal")
    openLabel.text:SetPoint("LEFT")
    openLabel.text:SetText("Openers, one per line")
    OnHover(openLabel, "Openers", "Each ad starts with one of these where an ad line says {opener}. They take turns, each used once before any comes back. A long one is swapped for a shorter one when the ad would not fit in one chat message.",
        "An opener may use {level}: the required level of the ware in the ad.")

    local openBox, openEdit = MultiBox(page, "SlutmogShopFrameOpeners", boxW, 84)
    openBox:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -60)
    frame.openers = openEdit
    ListHook(openEdit, ns.SetOpeners, function() return ns.db.openers end)

    local lineLabel = CreateFrame("Frame", nil, page)
    lineLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -156)
    lineLabel:SetSize(boxW, 14)
    lineLabel.text = Text(lineLabel, "GameFontNormal")
    lineLabel.text:SetPoint("LEFT")
    lineLabel.text:SetText("Ad lines, one per line")
    OnHover(lineLabel, "Ad lines", "Your own ads, for wares that have no ready-made ones (or for all of them: "
        .. "Options > Which ads). They take turns like the openers. Fill-ins:",
        "{opener}  one of the openers",
        "{shop}  your shop's name",
        "{item}  the next ware, as an item link people can click",
        "{price}  its price, like \"10 gold pieces\"",
        "{items}  as many wares with prices as fit, like \"[A] 10g, [B] 25g\"",
        "{level}  the ware's required level")

    local lineBox, lineEdit = MultiBox(page, "SlutmogShopFrameLines", boxW, 56)
    lineBox:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -176)
    frame.lines = lineEdit
    ListHook(lineEdit, ns.SetLines, function() return ns.db.lines end)

    -- What the lines are for, which depends on Options > Which ads (set in Refresh).
    local hint = Text(page, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", page, "TOPLEFT", 12, -242)
    hint:SetPoint("RIGHT", page, "RIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    frame.linesHint = hint
end

local LINES_HINT = {
    items = "Pieces on the slutmog list bring ads of their own; these lines speak for the rest.",
    mixed = "These lines take turns with the ready-made ads of pieces on the slutmog list.",
    mine = "Only these lines are used (Options > Which ads).",
}

local function BuildPreview(host)
    local pv = CreateFrame("Frame", nil, host)
    pv:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
    pv:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    pv:SetHeight(PREVIEW_H)

    local label = Text(pv, "GameFontNormal")
    label:SetPoint("TOPLEFT", pv, "TOPLEFT", 12, -14)
    label:SetText("Post to")

    local picker = BuildChannelPicker(pv)
    frame.channel = picker
    picker:SetPoint("LEFT", label, "RIGHT", 10, 0)

    frame.reroll = Button(pv, "Reroll", 70)
    frame.reroll:SetPoint("TOPRIGHT", pv, "TOPRIGHT", -6, -9)
    frame.reroll:SetScript("OnClick", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.Reroll()
    end)
    OnHover(frame.reroll, "Reroll", "Another ad for the same ware. The one shown is not voted on; it comes round again later.")

    frame.count = Text(pv, "GameFontHighlightSmall")
    frame.count:SetPoint("RIGHT", frame.reroll, "LEFT", -8, 0)

    local box = FromTemplate("Frame", pv, "TooltipBackdropTemplate") or CreateFrame("Frame", nil, pv)
    box:SetPoint("TOPLEFT", pv, "TOPLEFT", 6, -36)
    box:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -6, 6)
    frame.previewBox = box
    local function Links() return adLink, adLink2 end
    frame.item = NewItemButton(box, Links, false)
    frame.item:SetPoint("TOPLEFT", box, "TOPLEFT", 9, -9)
    frame.item2 = NewItemButton(box, Links, true)
    frame.item2:SetPoint("TOPLEFT", frame.item, "TOPRIGHT", 4, 0)
    frame.preview = Text(box, "GameFontHighlightSmall")
    frame.preview:SetPoint("TOPLEFT", box, "TOPLEFT", 9, -8)
    frame.preview:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -9, 8)
    frame.preview:SetJustifyH("LEFT")
    frame.preview:SetJustifyV("TOP")
    if frame.preview.SetWordWrap then frame.preview:SetWordWrap(true) end
    box:EnableMouse(true)
    OnHover(box, "The next ad", "This is what goes out when you click Post ad, exactly as people will read it. "
        .. "Yes and No move on to the next one without posting, and remember what you thought of this line.")
end

local function SelectTab(i)
    tab = i
    for k, page in ipairs(frame.pages) do
        if k == i then page:Show() else page:Hide() end
    end
    if type(PanelTemplates_SetTab) == "function" and frame.numTabs then pcall(PanelTemplates_SetTab, frame, i) end
end
UI.SelectTab = SelectTab

local function Build()
    if frame then return frame end
    local f = FromTemplate("Frame", UIParent, "ButtonFrameTemplate", "SlutmogShopFrame")
    local portrait = f ~= nil
    f = f or FromTemplate("Frame", UIParent, "BasicFrameTemplateWithInset", "SlutmogShopFrame")
        or CreateFrame("Frame", "SlutmogShopFrame", UIParent)
    frame = f
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    if f.SetToplevel then f:SetToplevel(true) end
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if type(f.SetTitle) == "function" then
        pcall(f.SetTitle, f, ns.ShopName())
    elseif Has(f, "TitleText") then
        f.TitleText:SetText(ns.ShopName())
    end
    if portrait and type(f.SetPortraitToAsset) == "function" then pcall(f.SetPortraitToAsset, f, ns.ICON) end
    if not Has(f, "CloseButton") then
        local close = FromTemplate("Button", f, "UIPanelCloseButton")
        if close then
            close:SetPoint("TOPRIGHT", 0, 0)
            close:SetScript("OnClick", function() f:Hide() end)
        end
    end

    local inset = Has(f, "Inset") and f.Inset or nil
    if not inset then
        inset = CreateFrame("Frame", nil, f)
        inset:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -60)
        inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 26)
    end
    f.host = inset

    f.pages = {}
    for i = 1, 2 do
        local page = CreateFrame("Frame", nil, inset)
        page:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, 0)
        page:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, PREVIEW_H)
        f.pages[i] = page
    end
    BuildWares(f.pages[1])
    BuildLines(f.pages[2])
    BuildPreview(inset)

    f.tabs = {}
    for i, label in ipairs({ "Wares", "Lines" }) do
        local t = FromTemplate("Button", f, "PanelTopTabButtonTemplate", "SlutmogShopFrameTab" .. i)
            or Button(f, label)
        t:SetID(i)
        t:SetText(label)
        if i == 1 then t:SetPoint("TOPLEFT", f, "TOPLEFT", 51, -28) else t:SetPoint("LEFT", f.tabs[i - 1], "RIGHT", 0, 0) end
        t:SetScript("OnClick", function()
            SelectTab(i)
            Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB)
        end)
        f.tabs[i] = t
    end
    if type(PanelTemplates_SetNumTabs) == "function" then pcall(PanelTemplates_SetNumTabs, f, #f.tabs) end

    local options = Button(f, "Options")
    options:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
    options:SetScript("OnClick", function() ns.OpenOptions() end)
    OnHover(options, "Options", "The gap between ads, the reminder, which wares go in and the minimap button.")

    f.post = Button(f, "Post ad")
    f.post:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
    f.post:SetScript("OnClick", function() ns.Post() end)
    if f.post.SetMotionScriptsWhileDisabled then f.post:SetMotionScriptsWhileDisabled(true) end
    OnHover(f.post, "Post ad", "Posts the ad shown above. The minimap button, your key (Key Bindings > AddOns) "
        .. "and /slutshop post do the same.")

    -- Post, Yes, No: your verdict on the line shown above
    f.yes = Button(f, "Yes", 52)
    f.yes:SetPoint("RIGHT", f.post, "LEFT", 0, 0)
    f.yes:SetScript("OnClick", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        ns.Vote(true)
    end)
    OnHover(f.yes, "Yes, good line", "Keeps this line and shows the next one, without posting.",
        "Your votes are saved, so the good and the bad lines can be told apart later (/slutshop votes lists them).")
    f.no = Button(f, "No", 52)
    f.no:SetPoint("RIGHT", f.yes, "LEFT", 0, 0)
    f.no:SetScript("OnClick", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        ns.Vote(false)
    end)
    OnHover(f.no, "No, bad line", "Drops this line from your ads for good, for every piece that shares it, and shows the next one.",
        "One of your own ad lines is only skipped: edit those on the Lines tab. /slutshop votes reset brings every line back.")
    f.skip = f.yes     -- the old Skip button's place

    f.status = Text(f, "GameFontHighlightSmall")
    f.status:SetPoint("LEFT", options, "RIGHT", 8, 0)
    f.status:SetPoint("RIGHT", f.no, "LEFT", -8, 0)
    f.status:SetJustifyH("CENTER")
    local statusHover = CreateFrame("Frame", nil, f)
    statusHover:SetAllPoints(f.status)
    statusHover:SetScript("OnEnter", function(self)
        if f.status.why then Tip(self, f.status:GetText(), f.status.why) end
    end)
    statusHover:SetScript("OnLeave", HideTip)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + (dt or 0)
        if elapsed < 0.5 then return end
        elapsed = 0
        UI.Tick()
    end)

    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "SlutmogShopFrame") end
    f:Hide()
    -- After the first Hide: OnHide runs on it otherwise.
    f:SetScript("OnShow", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN)
        UI.Refresh()
    end)
    f:SetScript("OnHide", function()
        Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        HideTip()
    end)
    SelectTab(1)
    SyncSlot()
    return f
end

---------------------------------------------------------------------------
-- Refreshing and opening
---------------------------------------------------------------------------
function UI.Refresh()
    SyncPrompt()
    if not (frame and ns.db and frame:IsShown()) then return end
    if type(frame.SetTitle) == "function" then pcall(frame.SetTitle, frame, ns.ShopName()) end
    if not Focused(frame.shop) then frame.shop:SetText(ns.db.shop or "") end
    if not Focused(frame.openers) then frame.openers:SetText(JoinLines(ns.db.openers)) end
    if not Focused(frame.lines) then frame.lines:SetText(JoinLines(ns.db.lines)) end
    if frame.linesHint then frame.linesHint:SetText(LINES_HINT[ns.db.wording] or LINES_HINT.items) end
    if frame.channel.fallback then
        frame.channel:SetText(ns.ChannelLabel(ns.db.channel))
    elseif frame.channel.GenerateMenu then
        pcall(frame.channel.GenerateMenu, frame.channel)
    end
    SyncSlot()
    SyncRows()
    SyncPreview()
    UI.Tick()
end

function UI.RefreshStock()
    if not (frame and frame:IsShown()) then return end
    SyncRows()
end

function UI.Open()
    local ok, err = pcall(Build)
    if not ok then
        ns.Print("the shop window could not be built: " .. tostring(err))
        return
    end
    UI.HidePrompt()
    frame:Show()
    if frame.Raise then frame:Raise() end
end

function UI.Close()
    if frame then frame:Hide() end
end

function UI.IsOpen()
    return frame ~= nil and frame:IsShown() and true or false
end

function UI.Toggle()
    if UI.IsOpen() then UI.Close() else UI.Open() end
end

function UI.Frame()
    return frame
end

-- LookShots (a helper on SuccuDev's machine only) takes a screenshot the first time the window shows.
function UI.ListLooks()
    LookShotsTargets = LookShotsTargets or {}
    LookShotsTargets[ADDON] = {
        version = ns.VERSION,
        frames = {
            { label = "shop window", frame = function() return frame and frame:IsShown() and frame or nil end },
            { label = "ad prompt", frame = function() return prompt and prompt:IsShown() and prompt or nil end },
        },
    }
end
