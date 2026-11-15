-- Destroy Advisor: the list window. A copy of the game's loot window (Blizzard_UIPanels_Game
-- LootFrame.xml/.lua on the forever branch): the same ScrollingFlatPanelTemplate, and rows
-- built like LootFrameItemElementTemplate (item card art, quality tint, stripe at the top right).
-- Each row is one item that is safe to get rid of, with the reason under its name.
local _, ns = ...
local UI = {}
ns.UI = UI

-- LootFrame.lua: ScrollBoxElementHeight 46, ScrollBoxSpacing 2, ScrollBoxPad 6.
local ROW_HEIGHT, ROW_GAP, PAD = 46, 2, 6
-- The loot window is 220 wide and at most 290 high; this one is wider for the reason line
-- and taller so a full bag of junk fits without much scrolling.
local PANEL_WIDTH, PANEL_MAX_HEIGHT = 300, 410
local ROW_WIDTH = PANEL_WIDTH - PAD - PAD * 2     -- what the list view leaves a row (ScrollingFlatPanelMixin:Resize)
local FRAME_NAME = "DestroyAdvisorFrame"

local frame          -- the window
local mode           -- "scrollbox" (the loot window's build) or "classic" (a client without it)
local classicRows = {}

local Num, Text = ns.Num, ns.Text

local function QualityColor(quality)
    quality = quality or 1
    if ColorManager and ColorManager.GetColorDataForItemQuality then
        local ok, data = pcall(ColorManager.GetColorDataForItemQuality, quality)
        if ok and type(data) == "table" and data.color and data.color.GetRGB then return data.color:GetRGB() end
    end
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if type(c) == "table" and c.r then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function HasAtlas(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil
    end
    return true
end

local function Art(texture, atlas, file)
    if texture.SetAtlas and HasAtlas(atlas) and pcall(texture.SetAtlas, texture, atlas) then return true end
    if file then texture:SetTexture(file) end
    return false
end

local function ColorOf(name, r, g, b)
    return ns.GameColor(name, r, g, b)
end

----------------------------------------------------------------------
-- The tooltip of a row: the game's own item tooltip, then what a click does
----------------------------------------------------------------------
function UI.IsOwnTooltip()
    return UI.inRowTooltip == true
end

local function OwnsTooltip(row)
    return GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row)
end

function UI.ShowTooltip(row)
    local entry = row.entry
    if not (entry and GameTooltip) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    UI.inRowTooltip = true
    local ok = pcall(GameTooltip.SetBagItem, GameTooltip, entry.bag, entry.slot)
    UI.inRowTooltip = false
    if not ok then GameTooltip:SetText(entry.name or entry.link) end
    local wr, wg, wb = ColorOf("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
    local gr, gg, gb = ColorOf("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(entry.reason, wr, wg, wb, true)
    if ns.CanSell(entry) then
        GameTooltip:AddLine(("Click to sell it for %s"):format(ns.Money(entry.value)), gr, gg, gb)
    else
        GameTooltip:AddLine("Click to destroy it (the game asks first)", gr, gg, gb)
    end
    GameTooltip:AddLine("Right-click to keep it or for more", gr, gg, gb)
    GameTooltip:Show()
    UI.tooltipRow = row
end

----------------------------------------------------------------------
-- Clicks
----------------------------------------------------------------------
function UI.Keep(entry)
    ns.Keep(entry.itemID, entry.name)
    ns.Print(("Keeping %s: it is never suggested again. /destroy unkeep %d undoes it."):format(entry.link, entry.itemID))
end

function UI.Menu(row)
    local entry = row.entry
    if not entry then return end
    if MenuUtil and MenuUtil.CreateContextMenu then
        local ok = pcall(MenuUtil.CreateContextMenu, row.Item, function(_, root)
            root:CreateTitle(entry.name or entry.link)
            if ns.CanSell(entry) then
                root:CreateButton(("Sell for %s"):format(ns.Money(entry.value)), function() ns.Sell(entry) end)
            end
            root:CreateButton("Destroy", function() ns.Destroy(entry) end)
            root:CreateButton("Keep (never suggest it again)", function() UI.Keep(entry) end)
        end)
        if ok then return end
    end
    UI.Keep(entry)      -- a client without the game's menus: right-click keeps
end

function UI.Click(row, button)
    local entry = row.entry
    if not entry then return end
    if IsModifiedClick and IsModifiedClick() and HandleModifiedItemClick then
        HandleModifiedItemClick(entry.link)     -- shift-click links it, ctrl-click tries it on
        return
    end
    if button == "RightButton" then
        UI.Menu(row)
    else
        ns.Act(entry)
    end
end

----------------------------------------------------------------------
-- A row: LootFrameElementTemplate + LootFrameItemElementTemplate, built in Lua
----------------------------------------------------------------------
local function NewItemButton(row)
    local ok, item = pcall(CreateFrame, "ItemButton", nil, row)
    if not ok or not item then item = CreateFrame("Button", nil, row, "ItemButtonTemplate") end
    return item
end

local function BuildRow(row)
    row.built = true
    row.isDestroyAdvisorRow = true     -- the tooltip hook leaves these rows' tooltips alone
    row:SetHeight(ROW_HEIGHT)

    row.NameFrame = row:CreateTexture(nil, "BACKGROUND")
    row.NameFrame:SetAllPoints()
    Art(row.NameFrame, "looting_itemcard_bg", "Interface\\QuestFrame\\UI-QuestItemNameFrame")

    row.QualityStripe = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.QualityStripe:SetSize(100, 13)
    row.QualityStripe:SetPoint("TOPRIGHT", 0, 0)
    if not Art(row.QualityStripe, "looting_raritytag_frame") then row.QualityStripe:Hide() end

    row.BorderFrame = row:CreateTexture(nil, "BORDER")
    row.BorderFrame:SetAllPoints()
    if not Art(row.BorderFrame, "looting_itemcard_stroke_normal") then row.BorderFrame:Hide() end

    row.HighlightNameFrame = row:CreateTexture(nil, "OVERLAY")
    row.HighlightNameFrame:SetAllPoints()
    Art(row.HighlightNameFrame, "looting_itemcard_stroke_clickstate", "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.HighlightNameFrame:SetBlendMode("ADD")
    row.HighlightNameFrame:SetAlpha(0.7)
    row.HighlightNameFrame:Hide()

    row.PushedNameFrame = row:CreateTexture(nil, "OVERLAY")
    row.PushedNameFrame:SetAllPoints()
    Art(row.PushedNameFrame, "looting_itemcard_stroke_clickstate", "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.PushedNameFrame:SetBlendMode("ADD")
    row.PushedNameFrame:Hide()

    local item = NewItemButton(row)
    row.Item = item
    item:SetSize(37, 37)
    item:SetPoint("TOPLEFT", 5, -4)
    item:SetHitRectInsets(0, -(ROW_WIDTH - 45), 0, 0)    -- the whole row is the button, as in the loot window
    item:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    item:RegisterForDrag("LeftButton")

    row.IconQuestTexture = row:CreateTexture(nil, "OVERLAY")
    row.IconQuestTexture:SetSize(37, 38)
    row.IconQuestTexture:SetPoint("TOP", item, "TOP", 0, 0)
    row.IconQuestTexture:Hide()

    row.QualityText = row:CreateFontString(nil, "ARTWORK", "GameFontWhiteTiny2")
    row.QualityText:SetPoint("TOPRIGHT", -4, -2)
    row.QualityText:SetJustifyH("RIGHT")

    -- The name, then the reason under it (the loot window has one two-line name here).
    row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Text:SetPoint("TOPLEFT", item, "TOPRIGHT", 8, -9)
    row.Text:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)

    row.Reason = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Reason:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -3)
    row.Reason:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Reason:SetJustifyH("LEFT")
    row.Reason:SetWordWrap(false)
    row.Reason:SetTextColor(ColorOf("QUEST_OBJECTIVE_FONT_COLOR", 0.8, 0.8, 0.8))

    item:SetScript("OnEnter", function()
        row.HighlightNameFrame:Show()
        UI.ShowTooltip(row)
    end)
    item:SetScript("OnLeave", function()
        if OwnsTooltip(row) then GameTooltip:Hide() end
        if ResetCursor then ResetCursor() end
        row.HighlightNameFrame:Hide()
    end)
    item:SetScript("OnMouseDown", function() row.PushedNameFrame:Show() end)
    item:SetScript("OnMouseUp", function() row.PushedNameFrame:Hide() end)
    item:SetScript("OnClick", function(_, button) UI.Click(row, button) end)
    -- Dragging picks the item up, as from the bag.
    item:SetScript("OnDragStart", function()
        local entry = row.entry
        if entry and C_Container and C_Container.PickupContainerItem then
            pcall(C_Container.PickupContainerItem, entry.bag, entry.slot)
        end
    end)
end

local function InitRow(row, entry)
    row.entry = entry
    local r, g, b = QualityColor(entry.quality)
    local count = entry.count or 1
    row.Text:SetText(entry.name or entry.link)
    row.Text:SetTextColor(r, g, b)
    row.NameFrame:SetVertexColor(r, g, b)
    row.Reason:SetText(entry.reason)
    -- The stripe says what the item is worth (the loot window shows its quality there).
    if entry.value > 0 then
        row.QualityText:SetText(ns.Money(entry.value))
    else
        row.QualityText:SetText(Text("ITEM_UNSELLABLE", "No sell price"))
    end

    local item = row.Item
    if SetItemButtonTexture then SetItemButtonTexture(item, entry.icon) elseif item.icon then item.icon:SetTexture(entry.icon) end
    if SetItemButtonCount then
        SetItemButtonCount(item, count)
    elseif item.Count then
        item.Count:SetText(count > 1 and tostring(count) or "")
        item.Count:SetShown(count > 1)
    end
    if SetItemButtonQuality then pcall(SetItemButtonQuality, item, entry.quality, entry.link, false, entry.bound) end
    if SetItemButtonTextureVertexColor then     -- locked (being moved, traded, mailed): the loot window's red
        if entry.locked then SetItemButtonTextureVertexColor(item, 0.9, 0, 0) else SetItemButtonTextureVertexColor(item, 1, 1, 1) end
    end

    if entry.startsQuest and TEXTURE_ITEM_QUEST_BANG then
        row.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        row.IconQuestTexture:Show()
    elseif entry.questItem and TEXTURE_ITEM_QUEST_BORDER then
        row.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
        row.IconQuestTexture:Show()
    else
        row.IconQuestTexture:Hide()
    end
    if OwnsTooltip(row) then UI.ShowTooltip(row) end
end
UI.InitRow = InitRow

----------------------------------------------------------------------
-- The window
----------------------------------------------------------------------
local function ElementsHeight(n)
    if ScrollUtil and ScrollUtil.CalculateScrollBoxElementExtent then
        local ok, h = pcall(ScrollUtil.CalculateScrollBoxElementExtent, n, ROW_HEIGHT, ROW_GAP)
        if ok and type(h) == "number" then return math.max(h, ROW_HEIGHT) end
    end
    return math.max(n * ROW_HEIGHT + math.max(0, n - 1) * ROW_GAP, ROW_HEIGHT)
end

local function CanUseLootBuild()
    if not (CreateScrollBoxListLinearView and ScrollUtil and ScrollUtil.InitScrollBoxWithScrollBar and CreateDataProvider) then
        return false
    end
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, "ScrollingFlatPanelTemplate")
        if not (ok and info) then return false end
    end
    return true
end

local function CreateLootBuild()
    local ok, f = pcall(CreateFrame, "Frame", nil, UIParent, "ScrollingFlatPanelTemplate")
    if not (ok and f and f.ScrollBox and f.ScrollBar and f.Resize) then return nil end
    f.panelWidth, f.panelMaxHeight = PANEL_WIDTH, PANEL_MAX_HEIGHT
    f.CalculateElementsHeight = function(self) return ElementsHeight(self.ScrollBox:GetDataProviderSize()) end
    -- The close animation ends in HideUIPanel; a plain Hide does the same for a window that isn't a UI panel.
    f.OnHideAnimFinished = function(self) self:Hide() end

    local view = CreateScrollBoxListLinearView(PAD, PAD, PAD, PAD, ROW_GAP)
    view:SetElementExtent(ROW_HEIGHT)
    view:SetElementInitializer("Frame", function(row, entry)
        if not row.built then BuildRow(row) end
        InitRow(row, entry)
    end)
    ScrollUtil.InitScrollBoxWithScrollBar(f.ScrollBox, f.ScrollBar, view)
    pcall(function()      -- LootFrameMixin:OnLoad's shadows over the list's top and bottom
        f.ScrollBox:SetShadowsFrameLevel(f.ScrollBox.ScrollTarget:GetFrameLevel() + 15)
        f.ScrollBox:SetShadowsScale(0.2)
        f.ScrollBox:GetUpperShadowTexture():SetTexCoord(0, 1, 1, 0)
        f.ScrollBox:GetUpperShadowTexture():SetPoint("TOPLEFT", 30, 0)
        f.ScrollBox:GetUpperShadowTexture():SetPoint("TOPRIGHT", -30, 0)
        f.ScrollBox:GetLowerShadowTexture():SetPoint("BOTTOMLEFT", 30, 0)
        f.ScrollBox:GetLowerShadowTexture():SetPoint("BOTTOMRIGHT", -30, 0)
    end)
    if f.SetTitle then f:SetTitle(ns.NAME) end
    f.Empty = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.Empty:SetPoint("TOPLEFT", f.ScrollBox, "TOPLEFT", 12, -PAD)
    f.Empty:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.Empty:SetHeight(ROW_HEIGHT)
    f.Empty:SetJustifyH("CENTER")
    return f
end

-- A client without the loot window's build: the game's basic window with a scroll frame.
local function CreateClassic()
    local f = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(PANEL_WIDTH + 24, 200)
    if f.TitleText then f.TitleText:SetText(ns.NAME) end
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -28)
    scroll:SetPoint("BOTTOMRIGHT", -30, 8)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(ROW_WIDTH, ROW_HEIGHT)
    scroll:SetScrollChild(child)
    f.Scroll, f.Child = scroll, child
    f.Empty = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.Empty:SetPoint("TOPLEFT", 12, -30)
    f.Empty:SetPoint("RIGHT", -12, 0)
    f.Empty:SetHeight(ROW_HEIGHT)
    f.Empty:SetJustifyH("CENTER")
    return f
end

local function ClassicRow(i)
    local row = classicRows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, frame.Child)
    BuildRow(row)
    local y = -PAD - (i - 1) * (ROW_HEIGHT + ROW_GAP)
    row:SetPoint("TOPLEFT", frame.Child, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", frame.Child, "TOPRIGHT", 0, y)
    classicRows[i] = row
    return row
end

function UI.Create()
    if frame then return frame end
    if CanUseLootBuild() then frame = CreateLootBuild() end
    if frame then
        mode = "scrollbox"
    else
        mode = "classic"
        frame = CreateClassic()
    end
    _G[FRAME_NAME] = frame
    frame:Hide()
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SavePosition()
    end)
    frame:SetScript("OnHide", function()
        if UI.tooltipRow and OwnsTooltip(UI.tooltipRow) then GameTooltip:Hide() end
    end)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, FRAME_NAME) end   -- Escape closes it
    UI.ApplyScale()
    UI.RestorePosition()
    return frame
end

function UI.Mode() return mode end
function UI.Frame() return frame end

function UI.ApplyScale()
    if frame and ns.db then frame:SetScale(Num(ns.db.scale) or 1) end
end

-- Saved as the top-left corner, so the window grows and shrinks downwards like the loot window.
function UI.SavePosition()
    if not (frame and ns.db) then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    local parentTop = UIParent and UIParent.GetTop and UIParent:GetTop()
    if not (left and top and parentTop) then return end
    local scale = frame:GetScale() or 1
    ns.db.point = { "TOPLEFT", left, top - parentTop / scale }
end

function UI.RestorePosition()
    if not frame then return end
    frame:ClearAllPoints()
    local p = ns.db and ns.db.point
    if type(p) == "table" and type(p[2]) == "number" and type(p[3]) == "number" then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", p[2], p[3])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

local function EmptyText(s)
    if s.pending > 0 then return "Nothing yet: the game is still loading some item names." end
    return "Nothing in your bags needs destroying."
end

function UI.Update()
    if not (frame and ns.db) then return end
    local s = ns.Scan()
    local empty = #s.list == 0
    frame.Empty:SetText(empty and EmptyText(s) or "")
    frame.Empty:SetShown(empty)
    if mode == "scrollbox" then
        local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
        frame.ScrollBox:SetDataProvider(CreateDataProvider(s.list), retain)
        frame:Resize()
    else
        for i, entry in ipairs(s.list) do
            local row = ClassicRow(i)
            InitRow(row, entry)
            row:Show()
        end
        for i = #s.list + 1, #classicRows do
            classicRows[i].entry = nil
            classicRows[i]:Hide()
        end
        local height = ElementsHeight(#s.list) + PAD * 2
        frame.Child:SetHeight(height)
        frame:SetHeight(math.min(height + 36, PANEL_MAX_HEIGHT))
    end
end

function UI.IsShown()
    return frame ~= nil and frame:IsShown() and true or false
end

function UI.Show()
    UI.Create()
    UI.Update()
    if mode == "scrollbox" and frame.Open then
        frame:Open()
    else
        frame:Show()
    end
end

function UI.Hide()
    if not frame then return end
    if mode == "scrollbox" and frame.Close and frame:IsShown() then frame:Close() else frame:Hide() end
end

function UI.Toggle()
    if UI.IsShown() then UI.Hide() else UI.Show() end
end

-- The rows on screen (tests and LookShots).
function UI.Rows()
    local out = {}
    if not frame then return out end
    if mode == "scrollbox" then
        if frame.ScrollBox.ForEachFrame then
            frame.ScrollBox:ForEachFrame(function(row) out[#out + 1] = row end)
        end
    else
        for _, row in ipairs(classicRows) do
            if row:IsShown() then out[#out + 1] = row end
        end
    end
    return out
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["DestroyAdvisor"] = {
    version = ns.VERSION,
    frames = {
        { label = "list window", frame = function() return frame and frame:IsShown() and frame or nil end },
        { label = "row tooltip", frame = function()
            local row = UI.tooltipRow
            if row and GameTooltip and GameTooltip:IsShown() and OwnsTooltip(row) then return GameTooltip end
        end },
    },
}
