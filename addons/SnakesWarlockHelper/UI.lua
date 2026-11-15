-- Snakes Warlock Helper: shared look for the strip and the window, built from the game's own
-- templates, art, fonts and colours so it reads as part of the default UI.
local _, ns = ...
local UI = {}
ns.UI = UI

-- The game's colour constants (ColorMixin objects in the client), with their values as fallback.
local function GameColor(c, r, g, b)
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    return { r, g, b }
end
local warlock = RAID_CLASS_COLORS and RAID_CLASS_COLORS.WARLOCK
UI.color = {
    gold    = GameColor(NORMAL_FONT_COLOR, 1, 0.82, 0),           -- headings, labels, tooltip titles
    white   = GameColor(HIGHLIGHT_FONT_COLOR, 1, 1, 1),           -- values, body text
    gray    = GameColor(GRAY_FONT_COLOR, 0.5, 0.5, 0.5),          -- hints
    green   = GameColor(GREEN_FONT_COLOR, 0.1, 1, 0.1),           -- the best choice, "your spells"
    orange  = GameColor(ORANGE_FONT_COLOR, 1, 0.5, 0.25),         -- running out, not measured yet
    warlock = GameColor(warlock, 0.53, 0.53, 0.93),               -- the demon's own damage
}
local C = UI.color

-- Art from the game (Dragonflight-style action buttons, the target frame's status bar).
UI.BAR = "Interface\\TargetingFrame\\UI-StatusBar"
UI.TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
UI.ROW_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function PlayClick(on)
    if PlaySound and SOUNDKIT then
        local id = on == false and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
        if id then pcall(PlaySound, id) end
    end
end
UI.PlayClick = PlayClick

function UI.Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.Text(parent, font, c, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    if c then fs:SetTextColor(c[1], c[2], c[3]) end
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- An icon framed like an action button: slot background, masked icon, the bar's icon frame.
-- `size` is the icon's edge; the frame art is drawn at the action bar's proportions (46 x 45).
function UI.IconFrame(f, size)
    f.slot = f:CreateTexture(nil, "BACKGROUND")
    f.slot:SetAllPoints()
    if f.slot.SetAtlas then f.slot:SetAtlas("UI-HUD-ActionBar-IconFrame-Background") end
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    if f.CreateMaskTexture then
        local ok, mask = pcall(f.CreateMaskTexture, f)
        if ok and mask then
            mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
            mask:SetAllPoints(f.tex)
            f.tex:AddMaskTexture(mask)
            f.mask = mask
        end
    end
    f.frameArt = f:CreateTexture(nil, "OVERLAY", nil, 1)
    f.frameArt:SetPoint("TOPLEFT")
    if f.frameArt.SetAtlas then f.frameArt:SetAtlas("UI-HUD-ActionBar-IconFrame") end
    UI.SizeIconFrame(f, size)
end

function UI.SizeIconFrame(f, size)
    f:SetSize(size, size)
    f.frameArt:SetSize(size * 46 / 45, size)
    for _, t in ipairs(f.overlays or {}) do t:SetSize(size * 46 / 45, size) end
end

-- One more layer of action-bar art over an icon frame (border, glow, highlight), kept the
-- frame's size by SizeIconFrame.
function UI.IconOverlay(f, atlas, sublevel, add)
    local t = f:CreateTexture(nil, "OVERLAY", nil, sublevel)
    t:SetPoint("TOPLEFT")
    if t.SetAtlas then t:SetAtlas(atlas) end
    if add then t:SetBlendMode("ADD") end
    f.overlays = f.overlays or {}
    f.overlays[#f.overlays + 1] = t
    t:SetSize(f:GetWidth() * 46 / 45, f:GetHeight())
    return t
end

-- Blizzard push button. `b.text` is the button's own label.
function UI.Button(parent, label, onClick, small)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b.small = small
    if small and GameFontNormalSmall then
        b:SetNormalFontObject(GameFontNormalSmall)
        b:SetHighlightFontObject(GameFontHighlightSmall)
        b:SetDisabledFontObject(GameFontDisableSmall)
    end
    b:SetText(label)
    b.text = b:GetFontString() or UI.Text(b, small and "GameFontNormalSmall" or "GameFontNormal", nil, "CENTER")
    function b:SetLabel(text)
        self:SetText(text)
        self.text:SetText(text)
        self:SetSize(math.max(60, (self.text:GetStringWidth() or 40) + 24), self.small and 20 or 22)
    end
    b:SetLabel(label)
    -- Selected choice of a group: held lit, the way the game marks the current option.
    function b:SetSelected(on)
        self.selected = on
        if on then self:LockHighlight() else self:UnlockHighlight() end
    end
    b:HookScript("OnEnter", function(self)
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(self.tipTitle or self.text:GetText() or "", C.gold[1], C.gold[2], C.gold[3])
            GameTooltip:AddLine(self.tip, C.white[1], C.white[2], C.white[3], true)
            GameTooltip:Show()
        end
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION) end
        if onClick then onClick(self) end
    end)
    return b
end

-- Blizzard check box with a label; the label is clickable too.
function UI.Check(parent, label, get, set)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(24, 24)
    b.text = UI.Text(b, "GameFontHighlight")
    b.text:SetPoint("LEFT", b, "RIGHT", 2, 1)
    b.text:SetText(label)
    -- The template's own label (Mainline) stays empty; this one is used instead.
    local own = rawget(b, "Text")
    if type(own) == "table" and own.SetText then own:SetText("") end
    b:SetHitRectInsets(0, -((b.text:GetStringWidth() or 100) + 4), 0, 0)
    function b:Sync()
        self:SetChecked(get() and true or false)
    end
    b:SetScript("OnClick", function(self)
        local v = not get()
        set(v)
        PlayClick(v)
        self:Sync()
    end)
    b:Sync()
    return b
end

-- A bar track in the game's style: status bar texture over a dark tint, in a tooltip border.
function UI.BarFrame(parent, width, height)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(width + 6, height + 6)
    if f.SetBackdrop then
        f:SetBackdrop({ edgeFile = UI.TOOLTIP_BORDER, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
        f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    end
    f.track = f:CreateTexture(nil, "BACKGROUND")
    f.track:SetTexture(UI.BAR)
    f.track:SetVertexColor(0, 0, 0, 0.55)
    f.track:SetPoint("TOPLEFT", 3, -3)
    f.track:SetSize(width, height)
    return f
end

function UI.BarSegment(f, c, height)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetTexture(UI.BAR)
    t:SetVertexColor(c[1], c[2], c[3], 1)
    t:SetHeight(height)
    return t
end

-- |T escape of the bar texture, tinted: a legend swatch that matches the bars.
function UI.Swatch(c)
    return ("|T%s:10:16:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(UI.BAR, c[1] * 255, c[2] * 255, c[3] * 255)
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
