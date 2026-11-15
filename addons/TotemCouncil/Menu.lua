-- Totem Council: a small pop-up list (built from plain frames, so it works
-- the same on every client and never touches Blizzard's dropdown code)
local ADDON, ns = ...

local Menu = {}
ns.Menu = Menu

-- Drawn with the art of the game's own dropdown menus (Blizzard_Menu,
-- MenuStyle1): the dropdown background, the quest-title highlight, the
-- tooltip divider and the yellow radio tick.
local ROW_H, ICON, RADIO, SEP_H = 18, 14, 16, 13
local PAD_X, PAD_TOP, PAD_BOTTOM = 8, 8, 12
local frame, rows = nil, {}
local C = ns.COLOR

-- an atlas from the current game, or the older file if this client lacks it
local function HasAtlas(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil
    end
    return true
end

local function Close()
    if frame then frame:Hide() end
end
Menu.Close = Close

local function CreateRow(i)
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_H)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.hl:SetBlendMode("ADD")
    row.radio = row:CreateTexture(nil, "ARTWORK")
    row.radio:SetSize(RADIO, RADIO)
    row.radio:SetPoint("LEFT", 0, 0)
    row.tick = row:CreateTexture(nil, "OVERLAY")
    row.tick:SetSize(RADIO, RADIO)
    row.tick:SetPoint("CENTER", row.radio, "CENTER")
    if HasAtlas("common-dropdown-tickradial") then
        row.radio:SetAtlas("common-dropdown-tickradial")
        row.tick:SetAtlas("common-dropdown-icon-radialtick-yellow")
    else
        -- older client: the classic radio button sheet (empty / checked)
        row.radio:SetTexture("Interface\\Buttons\\UI-RadioButton")
        row.radio:SetTexCoord(0, 0.25, 0, 1)
        row.tick:SetTexture("Interface\\Buttons\\UI-RadioButton")
        row.tick:SetTexCoord(0.25, 0.5, 0, 1)
    end
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.note = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.note:SetPoint("RIGHT", -2, 0)
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetHeight(SEP_H)
    row.line:SetPoint("LEFT", 0, 0)
    row.line:SetPoint("RIGHT", 0, 0)
    row.line:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    row:SetScript("OnClick", function(self)
        local item = self.item
        if not item or item.disabled or item.title or item.separator then return end
        Close()
        if item.func then ns.Safe(item.func) end
    end)
    rows[i] = row
    return row
end

local function Create()
    frame = CreateFrame("Frame", "TotemCouncilMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    if C_Texture and C_Texture.GetAtlasInfo and HasAtlas("common-dropdown-bg") then
        frame.bg = frame:CreateTexture(nil, "BACKGROUND")
        frame.bg:SetAtlas("common-dropdown-bg")
        frame.bg:SetPoint("TOPLEFT", -10, 3)
        frame.bg:SetPoint("BOTTOMRIGHT", 10, -3)
        frame.bg:SetAlpha(0.925)
    else
        ns.DialogBackdrop(frame)     -- older client: the dark dialog box
    end
    -- closes by itself shortly after the mouse leaves it
    frame:SetScript("OnUpdate", function(self, elapsed)
        local over = self:IsMouseOver() or (self.anchor and self.anchor.IsMouseOver and self.anchor:IsMouseOver())
        if over then
            self.away = 0
        else
            self.away = (self.away or 0) + elapsed
            if self.away > 1.2 then Close() end
        end
    end)
    -- and at once on a click anywhere else (a click on the icon it belongs to
    -- is left to that icon, which closes or re-opens the menu itself)
    pcall(frame.RegisterEvent, frame, "GLOBAL_MOUSE_DOWN")
    frame:SetScript("OnEvent", function(self)
        if not self:IsShown() or self:IsMouseOver() then return end
        if self.anchor and self.anchor.IsMouseOver and self.anchor:IsMouseOver() then return end
        Close()
    end)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "TotemCouncilMenu") end
    frame:Hide()
end

-- items: { text, icon, note, checked, disabled, title, separator, func }
function Menu.Open(anchor, items)
    if not frame then Create() end
    local width, y = 120, -PAD_TOP
    for i, item in ipairs(items) do
        local row = rows[i] or CreateRow(i)
        row.item = item
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD_X, y)
        row:SetPoint("RIGHT", frame, "RIGHT", -PAD_X, 0)
        if item.separator then
            row:SetHeight(SEP_H)
            row.line:Show()
            row.icon:Hide()
            row.radio:Hide()
            row.tick:Hide()
            row.text:SetText("")
            row.note:SetText("")
            row:EnableMouse(false)
            y = y - SEP_H
        else
            row:SetHeight(ROW_H)
            row.line:Hide()
            row.text:SetText(item.text or "")
            row.note:SetText(item.note or "")
            -- a choice gets the game's radio button; the current one is ticked
            local choice = item.checked ~= nil and not item.title
            row.radio:SetShown(choice)
            row.tick:SetShown(choice and item.checked == true)
            local x = choice and (RADIO + 2) or 0
            row.icon:ClearAllPoints()
            row.icon:SetPoint("LEFT", x, 0)
            if item.icon then
                row.icon:SetTexture(item.icon)
                row.icon:Show()
                x = x + ICON + 4
            else
                row.icon:Hide()
            end
            row.text:ClearAllPoints()
            row.text:SetPoint("LEFT", x, 0)
            local c = (item.title and C.gold) or (item.disabled and C.gray) or C.white
            row.text:SetTextColor(c[1], c[2], c[3])
            row:EnableMouse(not (item.title or item.disabled))
            local w = x + (row.text:GetStringWidth() or 0) + 12 + (row.note:GetStringWidth() or 0)
            if w > width then width = w end
            y = y - ROW_H
        end
        row:Show()
    end
    for i = #items + 1, #rows do rows[i]:Hide() end
    frame:SetSize(width + PAD_X * 2, -y + PAD_BOTTOM)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    frame.anchor = anchor
    frame.away = 0
    if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end   -- it would sit on top of the list
    frame:Show()
end

-- The "which totem for this element" list, shared by the bar and the plan window.
-- member = whose totem is being picked; picking for someone else sends a suggestion.
function Menu.OpenTotems(anchor, member, slot)
    -- clicking the icon the menu is already open for closes it
    if frame and frame:IsShown() and frame.anchor == anchor then
        Close()
        return
    end
    local G = ns.Group
    local el = ns.ELEMENTS[slot]
    local own = member.isPlayer
    local items = { { text = own and (el.name .. " totem to keep up") or ("Suggest to " .. member.name), title = true } }
    local current = G.Effective(member, slot)

    -- who else in that subgroup already covers which totem
    local takenBy = {}
    for name, m in pairs(G.members) do
        if m ~= member and m.subgroup == member.subgroup then
            local key = G.Effective(m, slot)
            if key then takenBy[key] = takenBy[key] or name end
        end
    end

    local keys = G.KnownList(member, slot)
    for _, key in ipairs(keys) do
        local info = ns.Info(key)
        if info then
            items[#items + 1] = {
                text = info.name, icon = info.icon, checked = (key == current),
                note = (takenBy[key] and not info.stack) and ns.Paint("orange", takenBy[key]) or nil,
                func = function()
                    if own then ns.SetPlan(slot, key) else G.Suggest(member.name, slot, key) end
                end,
            }
        end
    end
    if #keys == 0 then
        items[#items + 1] = { text = "No " .. el.name:lower() .. " totems known", disabled = true }
    end
    if own then
        items[#items + 1] = {
            text = "No totem planned", checked = (current == nil),
            func = function() ns.SetPlan(slot, nil) end,
        }
        items[#items + 1] = { separator = true }
        items[#items + 1] = { text = "Group plan...", func = function() ns.Board.Show() end }
    end
    Menu.Open(anchor, items)
end
