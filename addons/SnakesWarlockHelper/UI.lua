-- Snakes Warlock Helper: shared look (colours, flat widgets) for the strip and the window.
-- Everything is drawn from plain colour textures, so it looks the same on any UI skin.
local _, ns = ...
local UI = {}
ns.UI = UI

UI.color = {
    bg     = { 0.055, 0.045, 0.085 },   -- window background
    raised = { 0.115, 0.095, 0.165 },   -- chips, bar tracks
    accent = { 0.58, 0.51, 0.79 },      -- warlock purple
    fel    = { 0.56, 0.86, 0.32 },      -- fel green: "your spells", the best choice
    amber  = { 1.00, 0.76, 0.25 },      -- running out
    text   = { 0.93, 0.91, 0.97 },
    dim    = { 0.66, 0.63, 0.74 },
    faint  = { 0.45, 0.43, 0.52 },
}
local C = UI.color

function UI.Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.Fill(parent, layer, c, alpha, sublevel)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
    t:SetColorTexture(c[1], c[2], c[3], alpha or 1)
    return t
end

function UI.SetFill(tex, c, alpha)
    tex:SetColorTexture(c[1], c[2], c[3], alpha or 1)
end

-- 1px outline inside the frame's edge.
function UI.Border(frame, c, alpha, layer)
    local b = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = UI.Fill(frame, layer or "BORDER", c, alpha)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        b[#b + 1] = t
    end
    return b
end

function UI.SetBorder(border, c, alpha)
    for _, t in ipairs(border) do UI.SetFill(t, c, alpha) end
end

function UI.Text(parent, font, c, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    c = c or C.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- Flat text button; `chip = true` gives it a filled background.
function UI.Button(parent, label, onClick, chip)
    local b = CreateFrame("Button", nil, parent)
    b.text = UI.Text(b, "GameFontHighlightSmall", C.dim, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    if chip then
        b.bg = UI.Fill(b, "BACKGROUND", C.raised)
        b.bg:SetAllPoints()
        b.border = UI.Border(b, C.accent, 0.35)
    end
    b:SetSize((b.text:GetStringWidth() or 40) + (chip and 16 or 4), chip and 20 or 16)
    function b:SetLabel(text)
        self.text:SetText(text)
        self:SetWidth((self.text:GetStringWidth() or 40) + (chip and 16 or 4))
    end
    function b:SetSelected(on)
        self.selected = on
        local c = on and C.text or C.dim
        self.text:SetTextColor(c[1], c[2], c[3])
        if self.border then UI.SetBorder(self.border, C.accent, on and 0.9 or 0.35) end
    end
    b:SetScript("OnEnter", function(self)
        self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.tip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetSelected(self.selected)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    return b
end

-- Tick box with a label; the whole line is clickable.
function UI.Check(parent, label, get, set)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    b.box = CreateFrame("Frame", nil, b)
    b.box:SetSize(13, 13)
    b.box:SetPoint("LEFT", 0, 0)
    b.box.bg = UI.Fill(b.box, "BACKGROUND", C.raised)
    b.box.bg:SetAllPoints()
    b.box.border = UI.Border(b.box, C.accent, 0.6)
    b.mark = UI.Fill(b.box, "ARTWORK", C.fel)
    b.mark:SetPoint("TOPLEFT", 3, -3)
    b.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    b.text = UI.Text(b, "GameFontHighlightSmall", C.text)
    b.text:SetPoint("LEFT", b.box, "RIGHT", 8, 0)
    b.text:SetText(label)
    function b:Sync()
        if get() then self.mark:Show() else self.mark:Hide() end
    end
    b:SetScript("OnClick", function(self)
        set(not get())
        self:Sync()
    end)
    b:SetScript("OnEnter", function(self) UI.SetBorder(self.box.border, C.accent, 1) end)
    b:SetScript("OnLeave", function(self) UI.SetBorder(self.box.border, C.accent, 0.6) end)
    b:Sync()
    return b
end

function UI.FormatAge(seconds)
    if not seconds or seconds < 90 then return "a moment ago" end
    if seconds < 3600 then return ("%d min ago"):format(seconds / 60) end
    if seconds < 172800 then return ("%d h ago"):format(seconds / 3600) end
    return ("%d days ago"):format(seconds / 86400)
end

function UI.FormatTimer(seconds)
    if seconds >= 60 then return ("%d:%02d"):format(seconds / 60, seconds % 60) end
    return ("%d"):format(seconds)
end

-- Position saved in the settings under `key`, relative to the screen.
function UI.SavePoint(frame, key)
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.db[key] = { point, relPoint, x, y }
end

function UI.RestorePoint(frame, key, point, x, y)
    local p = ns.db and ns.db[key]
    frame:ClearAllPoints()
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint(point, UIParent, point, x, y)
    end
end
