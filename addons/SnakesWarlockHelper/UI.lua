-- Snakes Warlock Helper: shared look for the strip and the window. Every widget copies a whole
-- Blizzard widget from this client's UI (Gethe/wow-ui-source, branch forever), at the game's
-- own sizes; see the notes on each builder.
local _, ns = ...
local UI = {}
ns.UI = UI

-- The game's colour constants (ColorMixin objects in the client), with their values as fallback.
local function GameColor(c, r, g, b)
    if type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    return { r, g, b }
end
UI.color = {
    gold   = GameColor(NORMAL_FONT_COLOR, 1, 0.82, 0),           -- headings, tooltip titles
    white  = GameColor(HIGHLIGHT_FONT_COLOR, 1, 1, 1),           -- values, body text
    gray   = GameColor(GRAY_FONT_COLOR, 0.5, 0.5, 0.5),          -- hints
    green  = GameColor(GREEN_FONT_COLOR, 0.1, 1, 0.1),           -- "+N dps" in tooltips
    orange = GameColor(ORANGE_FONT_COLOR, 1, 0.5, 0.25),         -- tooltip warning line
}
local C = UI.color

-- True when the client has this XML template (always true outside the game).
function UI.HasTemplate(name)
    if C_XMLUtil and C_XMLUtil.GetTemplateInfo then
        local ok, info = pcall(C_XMLUtil.GetTemplateInfo, name)
        return ok and info ~= nil
    end
    return true
end

function UI.Sound(key)
    local id = SOUNDKIT and SOUNDKIT[key]
    if PlaySound and id then pcall(PlaySound, id) end
end

function UI.Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

function UI.Text(parent, font, c, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    if c then fs:SetTextColor(c[1], c[2], c[3]) end
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- Texture of a button state (Normal/Pushed/Highlight), placed the way the action bar places it.
local function PlaceState(tex, layer, w, h)
    if type(tex) ~= "table" then return end
    if layer then tex:SetDrawLayer(layer) end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT")
    tex:SetSize(w, h)
end
UI.PlaceState = PlaceState

-- ActionButtonTemplate (Blizzard_ActionBar/Mainline/ActionButtonTemplate.xml) as a stand-alone
-- button, which the game draws with the "AddRow" frame (BaseActionButtonMixin:UpdateButtonArt in
-- Blizzard_ActionBar/Mainline/ActionButtonOverrides.lua, the branch for buttons without bar art).
-- 45 x 45 like the template; callers change the on-screen size with SetScale on a parent.
UI.ACTION_SIZE = 45
function UI.ActionIcon(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(45, 45)
    b.tex = b:CreateTexture(nil, "BACKGROUND")                  -- $parentIcon: fills the button
    b.tex:SetAllPoints()
    if b.CreateMaskTexture then
        local ok, mask = pcall(b.CreateMaskTexture, b)
        if ok and mask then                                     -- IconMask, 45 x 45 on the icon's centre
            mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
            mask:SetPoint("CENTER", b.tex)
            mask:SetSize(45, 45)
            b.tex:AddMaskTexture(mask)
        end
    end
    b.slot = b:CreateTexture(nil, "BACKGROUND", nil, -1)        -- SlotBackground, shown without bar art
    b.slot:SetAllPoints()
    if b.slot.SetAtlas then b.slot:SetAtlas("UI-HUD-ActionBar-IconFrame-Background") end
    if b.SetNormalAtlas then
        b:SetNormalAtlas("UI-HUD-ActionBar-IconFrame-AddRow")
        PlaceState(b:GetNormalTexture(), "OVERLAY", 51, 51)
        b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-AddRow-Down")
        PlaceState(b:GetPushedTexture(), "OVERLAY", 51, 51)
        b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        PlaceState(b:GetHighlightTexture(), nil, 46, 45)
    end
    return b
end

-- UIPanelButtonTemplate. `b.text` is the button's own label.
function UI.Button(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetText(label)
    b.text = b:GetFontString() or UI.Text(b, "GameFontNormal", nil, "CENTER")
    b.text:SetText(label)
    b:SetSize(math.max(80, (b.text:GetStringWidth() or 40) + 24), 22)
    b:SetScript("OnClick", function(self)
        UI.Sound("IG_MAINMENU_OPTION")
        if onClick then onClick(self) end
    end)
    return b
end

-- UICheckButtonTemplate (Blizzard_SharedXML/Shared/Button/CheckButtonTemplates.xml) as it is:
-- 32 x 32, its own GameFontNormalSmall label at the box's right. The label is clickable too.
UI.CHECK_SIZE = 32
function UI.Check(parent, label, get, set)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    local own = rawget(b, "Text")                                -- the template's label
    if type(own) == "table" and own.SetText then
        b.text = own
    else
        b:SetSize(32, 32)
        b.text = UI.Text(b, "GameFontNormalSmall")
        b.text:SetPoint("LEFT", b, "RIGHT", -2, 0)
    end
    b.text:SetText(label)
    b:SetHitRectInsets(0, -((b.text:GetStringWidth() or 100) + 4), 0, 0)
    function b:Sync()
        self:SetChecked(get() and true or false)
    end
    b:SetScript("OnClick", function(self)
        local v = not get()
        set(v)
        UI.Sound(v and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
        self:Sync()
    end)
    b:Sync()
    return b
end

-- WowStyle1DropdownTemplate (Blizzard_Menu/Mainline/MenuTemplates.xml) with radio entries, the
-- way the game's settings pick one of a few values. `choices` = { { label, value }, ... }.
-- `dd.key` names it, `dd.Choose(value)` picks a value as a click would.
function UI.Dropdown(parent, key, width, choices, get, set)
    local dd
    local function choose(value)
        set(value)
        if dd.GenerateMenu then pcall(dd.GenerateMenu, dd) end
    end
    if UI.HasTemplate("WowStyle1DropdownTemplate") then
        dd = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
        dd:SetWidth(width)
        if dd.SetupMenu then
            dd:SetupMenu(function(_, root)
                for _, c in ipairs(choices) do
                    root:CreateRadio(c[1], function(v) return get() == v end, choose, c[2])
                end
            end)
        end
    else                                                         -- no menu system: cycle on click
        dd = UI.Button(parent, "", function()
            for i, c in ipairs(choices) do
                if c[2] == get() then choose(choices[i % #choices + 1][2]); break end
            end
        end)
        dd:SetWidth(width)
    end
    dd.key, dd.choices, dd.Choose = key, choices, choose
    function dd:Sync()
        if self.GenerateMenu then pcall(self.GenerateMenu, self) end
        if self.text then
            for _, c in ipairs(choices) do
                if c[2] == get() then self.text:SetText(c[1]) end
            end
        end
    end
    return dd
end

-- The buff frame's duration text (SecondsToTimeAbbrev, white under a minute, gold above:
-- Blizzard_BuffFrame/BuffFrame.lua, AuraButtonMixin:UpdateDuration).
function UI.SetDuration(fs, seconds)
    if not seconds or seconds <= 0 then fs:SetText(""); return end
    if SecondsToTimeAbbrev then
        fs:SetFormattedText(SecondsToTimeAbbrev(seconds))
    else
        fs:SetText(UI.FormatTimer(seconds))
    end
    local warn = BUFF_DURATION_WARNING_TIME or 60
    local c = seconds < warn and C.white or C.gold
    fs:SetVertexColor(c[1], c[2], c[3])
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
