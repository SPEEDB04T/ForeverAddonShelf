-- Shelf Kit: the minimap button and the options window shared by the addons on the Forever
-- Addon Shelf. Every addon carries its own copy of this file (the master is shared/Kit.lua in
-- the working folder; shared/sync-kit.ps1 copies it out), so each addon still works alone.
--
-- An addon describes itself once with Kit.Setup{ ... } and gets:
--   * a round button on the minimap rim (left-click: the addon's main action, right-click:
--     options, drag: move it), which picks a free spot the first time it appears;
--   * an options window built from a list of rows (tick boxes, choices, sliders, buttons);
--   * the same rows as a page under Options > AddOns, when the client has that.
-- It is drawn with the game's own pieces, laid out like the game's Options rows: the portrait
-- window (ButtonFrameTemplate), the Settings check box, dropdown and stepper slider, panel
-- buttons, the game's fonts and font colours. No Blizzard frame is hooked or changed.
-- Every template piece is looked for before use, so a client (or a test) without one still
-- gets working rows.
local ADDON, ns = ...
local Kit = {}
ns.Kit = Kit

local floor, max, min = math.floor, math.max, math.min

local function FontColor(c, r, g, b)
    if type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { r, g, b }
end
local GOLD  = FontColor(NORMAL_FONT_COLOR, 1, 0.82, 0)
local WHITE = FontColor(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
local GRAY  = FontColor(GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
local RED   = FontColor(RED_FONT_COLOR, 1, 0.125, 0.125)
local accent = GOLD                     -- the addon's own colour, set in Setup; minimap tooltip title only

local WIDTH = 540                       -- the window
local INNER = 480                       -- the rows
local CONTROL_X = 230                   -- where a row's control starts; its label sits left of it
local LABEL_W = CONTROL_X - 16
local SLIDER_W = 200
local ROW = 30
local MAX_VIEW = 520                    -- taller windows scroll
local PAGE_VIEW = 470                   -- the same on the Options page, under its title

local spec                              -- what the addon passed to Kit.Setup
local pages = {}                        -- every built set of rows (the window, the Options page)
local window, button

local function Readable(v)
    if v == nil then return false end
    if issecretvalue and issecretvalue(v) then return false end
    return true
end

local function Num(v)
    if Readable(v) and type(v) == "number" and v == v then return v end
end

local function Hex(c)
    return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5))
end

local function Say(msg)
    if spec and spec.print then
        spec.print(msg)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(tostring(spec and spec.title or ADDON) .. ": " .. tostring(msg))
    end
end

-- One line in chat per distinct error, so a broken row never floods the error log.
local seen = {}
local function Run(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, a, b = pcall(fn, ...)
    if ok then return true, a, b end
    local msg = Readable(a) and tostring(a) or "blocked by a hidden value"
    if not seen[msg] then
        seen[msg] = true
        Say(Hex(RED) .. "options error:|r " .. msg)
    end
    return false
end

local function Sound(id)
    if id and PlaySound then pcall(PlaySound, id) end
end

-- A frame from a Blizzard template, or nil when the client doesn't have it.
local function FromTemplate(kind, parent, template)
    local ok, frame = pcall(CreateFrame, kind, nil, parent, template)
    if ok then return frame end
end

local function Has(t, key) return type(t) == "table" and type(t[key]) == "table" end

----------------------------------------------------------------------
-- Text and tooltips
----------------------------------------------------------------------
local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    fs:SetJustifyH("LEFT")
    return fs
end

-- The game's tooltip layout: gold title, white body.
local function ShowTip(owner, title, body)
    if not (GameTooltip and body) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", GOLD[1], GOLD[2], GOLD[3])
    GameTooltip:AddLine(body, WHITE[1], WHITE[2], WHITE[3], true)
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

-- Tooltip on hover, added after any scripts the widget's template already has.
local function OnHover(widget, title, body)
    local function enter(self) ShowTip(self, title, body) end
    if widget.HookScript and widget.GetScript and widget:GetScript("OnEnter") then
        widget:HookScript("OnEnter", enter)
        widget:HookScript("OnLeave", HideTip)
    else
        widget:SetScript("OnEnter", enter)
        widget:SetScript("OnLeave", HideTip)
    end
end

-- The red panel button, sized to its text. Fit() resizes it for a new text.
local function PanelButton(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    function b:Fit(text)
        self:SetText(text)
        local w = Num(self.GetTextWidth and self:GetTextWidth()) or #text * 6
        return max(96, w + 28)
    end
    b:SetSize(b:Fit(label), 22)
    b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    return b
end

----------------------------------------------------------------------
-- Rows. Each builder returns the row's frame (with :Sync() when it shows
-- a setting) and its height. Rows are pinned by their two top corners.
-- Like the game's Options rows: a gold label on the left, the control to
-- its right at CONTROL_X.
----------------------------------------------------------------------
local build = {}

local function NewRow(parent, y, height, kind)
    local row = CreateFrame(kind or "Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    row:SetHeight(height)
    return row
end

local function Changed()
    Kit.Sync()
end

-- The gold label of a row. Long labels wrap; returns the row height they need.
local function Label(row, def)
    row.label = Text(row, "GameFontNormal")
    row.label:SetPoint("TOPLEFT", 0, -8)
    row.label:SetWidth(LABEL_W)
    row.label:SetJustifyV("TOP")
    row.label:SetText(def.label or "")
    row:EnableMouse(true)
    OnHover(row, def.label, def.tip)
    local height = Num(row.label:GetStringHeight())
    if not height or height < 8 then height = 13 end
    height = max(ROW, height + 16)
    row:SetHeight(height)
    return height
end

function build.header(parent, y, def)
    local top = y < 0 and 14 or 2       -- room above every header but the first
    local row = NewRow(parent, y, top + 26)
    row.text = Text(row, "GameFontHighlightLarge")
    row.text:SetPoint("TOPLEFT", 0, -top)
    row.text:SetText(def.text or "")
    return row, top + 26
end

function build.note(parent, y, def)
    local row = NewRow(parent, y, ROW)
    row.text = Text(row, "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", 0, -4)
    row.text:SetWidth(INNER)
    row.text:SetSpacing(2)
    row.text:SetJustifyV("TOP")
    row.text:SetText(def.text or "")
    -- A wrapped line is about 80 characters at this width; used when the client can't say.
    local height = Num(row.text:GetStringHeight())
    if not height or height < 8 then height = 13 * math.ceil(#(def.text or "") / 80) end
    row:SetHeight(height + 10)
    return row, height + 10
end

function build.check(parent, y, def)
    local row = NewRow(parent, y, ROW, "Button")
    local height = Label(row, def)
    local box = FromTemplate("CheckButton", row, "MinimalCheckboxArtTemplate")
        or CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.box = box
    box:SetSize(30, 29)
    box:SetPoint("TOPLEFT", row, "TOPLEFT", CONTROL_X - 5, 0)
    function row:Sync()
        local ok, on = Run(def.get)
        box:SetChecked(ok and on and true or false)
    end
    local function Toggle()
        local ok, on = Run(def.get)
        if ok then
            Run(def.set, not on)
            Sound(SOUNDKIT and (on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON))
        end
        Changed()
    end
    box:SetScript("OnClick", Toggle)
    row:SetScript("OnClick", Toggle)    -- the label toggles it too
    OnHover(box, def.label, def.tip)
    return row, height
end

-- Lays items out left to right from `left`, wrapping at the row's right edge.
-- Returns the height used.
local function Width(item) return Num(rawget(item, "span")) or Num(item:GetWidth()) or 80 end

local function Flow(row, items, left, top, line, gap)
    local x, y = left, top
    for _, item in ipairs(items) do
        local w = Width(item)
        if x > left and x + w > INNER then
            x, y = left, y - line
        end
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
        x = x + w + gap
    end
    return (top - y) + line
end

local function ItemsWidth(items, gap)
    local total = 0
    for _, item in ipairs(items) do total = total + Width(item) + gap end
    return total - gap
end

local function Option(def, option)
    return option[1], option[2] or tostring(option[1]), option[3] or def.tip
end

-- A choice is the game's dropdown with one radio line per option.
local function Dropdown(row, def)
    local dd = FromTemplate("DropdownButton", row, "WowStyle1DropdownTemplate")
    if not (dd and type(dd.SetupMenu) == "function") then
        if dd then dd:Hide() end
        return
    end
    row.dropdown = dd
    dd:SetWidth(min(220, INNER - CONTROL_X))
    dd:SetPoint("TOPLEFT", row, "TOPLEFT", CONTROL_X, -3)
    dd:SetupMenu(function(_, root)
        for _, option in ipairs(def.options) do
            local value, text, tip = Option(def, option)
            local radio = root:CreateRadio(text,
                function() local ok, now = Run(def.get); return ok and now == value end,
                function() Run(def.set, value); Changed() end,
                value)
            if tip and type(radio) == "table" and type(radio.SetTitleAndTextTooltip) == "function" then
                pcall(radio.SetTitleAndTextTooltip, radio, text, tip)
            end
        end
    end)
    OnHover(dd, def.label, def.tip)
    function row:Sync()
        if dd.IsMenuOpen and dd:IsMenuOpen() then return end   -- it updates itself on a pick
        if dd.GenerateMenu then dd:GenerateMenu() end
    end
    return true
end

-- Without the dropdown: the game's round radio buttons in a line.
local function Radios(row, def, height)
    row.chips = {}
    for _, option in ipairs(def.options) do
        local value, text, tip = Option(def, option)
        local r = FromTemplate("CheckButton", row, "UIRadioButtonTemplate") or CreateFrame("CheckButton", nil, row)
        r:SetSize(16, 16)
        r.label = Text(r, "GameFontHighlightSmall")
        r.label:SetPoint("LEFT", r, "RIGHT", 3, 0)
        r.label:SetText(text)
        r.value = value
        r.span = 16 + 3 + (Num(r.label:GetStringWidth()) or #text * 6) + 12
        function r:SetSelected(on)
            self.selected = on and true or false
            self:SetChecked(self.selected)
        end
        r:SetScript("OnClick", function()
            Run(def.set, value)
            Changed()
        end)
        OnHover(r, def.label, tip)
        row.chips[#row.chips + 1] = r
    end
    if ItemsWidth(row.chips, 0) <= INNER - CONTROL_X then
        height = max(height, Flow(row, row.chips, CONTROL_X, -7, 22, 0) + 8)
    else
        height = height - 4 + Flow(row, row.chips, 12, -(height - 4), 22, 0)   -- under the label
    end
    function row:Sync()
        local ok, now = Run(def.get)
        for _, r in ipairs(self.chips) do r:SetSelected(ok and r.value == now) end
    end
    return height
end

function build.choice(parent, y, def)
    local row = NewRow(parent, y, ROW)
    local height = Label(row, def)
    if not Dropdown(row, def) then height = Radios(row, def, height) end
    row:SetHeight(height)
    return row, height
end

local function Format(def, value)
    if type(def.format) == "function" then return def.format(value) end
    return (def.format or "%d"):format(value)
end

function build.slider(parent, y, def)
    local row = NewRow(parent, y, ROW)
    local height = Label(row, def)
    local step = def.step or 1
    local function Clamp(v) return max(def.min, min(def.max, v)) end
    local function Snap(v)
        v = Clamp(floor((v - def.min) / step + 0.5) * step + def.min)
        return floor(v * 1000 + 0.5) / 1000     -- no 0.30000000000000004 in the saved settings
    end
    local function Shown(v)
        local ok, text = pcall(Format, def, Snap(v))
        return ok and tostring(text) or ""
    end
    local function Saved()
        local ok, now = Run(def.get)
        return Clamp(ok and Num(now) or def.min)
    end
    row.syncing = false
    local function OnValue(value)
        if row.syncing then return end
        value = Num(value)
        if not value then return end
        value = Snap(value)
        local ok, now = Run(def.get)
        if ok and now == value then return end
        Run(def.set, value)
        Changed()
    end

    -- The game's Options slider: a bar with arrow steppers and the value on its right.
    local mixin = MinimalSliderWithSteppersMixin
    local w = FromTemplate("Frame", row, "MinimalSliderWithSteppersTemplate")
    if w and type(w.Init) == "function" and Has(w, "Slider") and Has(w, "RightText")
        and Has(mixin, "Event") and Has(mixin, "Label") then
        row.control, row.slider, row.value = w, w.Slider, w.RightText
        w:SetWidth(SLIDER_W)
        w:SetPoint("LEFT", row, "TOPLEFT", CONTROL_X, -15)
        local steps = max(1, floor((def.max - def.min) / step + 0.5))
        row.syncing = true
        w:Init(Saved(), def.min, def.max, steps, { [mixin.Label.Right] = Shown })
        row.syncing = false
        w:RegisterCallback(mixin.Event.OnValueChanged, function(_, value) OnValue(value) end, row)
        OnHover(w.Slider, def.label, def.tip)
        function row:Sync()
            self.syncing = true
            w:SetValue(Saved())
            self.syncing = false
        end
        return row, height
    end

    -- Without it: the older game slider, with the value written next to it.
    if w then w:Hide() end
    local s = FromTemplate("Slider", row, "UISliderTemplate") or CreateFrame("Slider", nil, row)
    row.slider = s
    s:SetPoint("LEFT", row, "TOPLEFT", CONTROL_X, -15)
    s:SetSize(SLIDER_W - 40, 17)
    s:SetOrientation("HORIZONTAL")
    s:EnableMouse(true)
    s:SetMinMaxValues(def.min, def.max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    row.value = Text(row, "GameFontHighlightSmall")
    row.value:SetPoint("LEFT", s, "RIGHT", 10, 0)
    function row:Sync()
        local now = Saved()
        self.syncing = true
        s:SetValue(now)
        self.syncing = false
        self.value:SetText(Shown(now))
    end
    s:SetScript("OnValueChanged", function(_, value) OnValue(value) end)
    OnHover(s, def.label, def.tip)
    return row, height
end

function build.buttons(parent, y, def)
    local row = NewRow(parent, y, ROW)
    row.buttons = {}
    for _, b in ipairs(def.buttons) do
        local pb
        pb = PanelButton(row, b.label, function(self)
            -- A button that throws something away asks for a second click.
            if b.confirm and not self.armed then
                self.armed = true
                self:SetText("Click again to confirm")
                if C_Timer and C_Timer.After then
                    C_Timer.After(4, function()
                        if self.armed then
                            self.armed = nil
                            self:SetText(b.label)
                        end
                    end)
                end
                return
            end
            if self.armed then
                self.armed = nil
                self:SetText(b.label)
            end
            Sound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION)
            Run(b.click)
            Changed()
        end)
        if b.confirm then
            -- wide enough for the question, so the row doesn't jump when it is asked
            local asked = pb:Fit("Click again to confirm")
            pb:Fit(b.label)
            pb:SetWidth(max(asked, Num(pb:GetWidth()) or 0))
        end
        OnHover(pb, b.label, b.tip)
        row.buttons[#row.buttons + 1] = pb
    end
    local height = Flow(row, row.buttons, 0, -4, 28, 8) + 2
    row:SetHeight(height)
    return row, height
end

-- Builds `rows` into `parent` (INNER wide). Returns a page: its widgets and its height.
local function BuildPage(parent, rows)
    local page = { widgets = {}, height = 0 }
    local y = 0
    for _, def in ipairs(rows) do
        local builder = build[def.kind]
        if builder then
            local ok, row, height = Run(builder, parent, y, def)
            if ok and row then
                page.widgets[#page.widgets + 1] = row
                y = y - (height or ROW)
            end
        end
    end
    page.height = -y
    pages[#pages + 1] = page
    return page
end

local function Rows()
    local rows = spec.rows
    if type(rows) == "function" then
        local ok, list = Run(rows)
        rows = ok and list or {}
    end
    return rows or {}
end

-- Re-reads every setting into every built page (after a change, a reset, a slash command).
function Kit.Sync()
    for _, page in ipairs(pages) do
        for _, row in ipairs(page.widgets) do
            if row.Sync then Run(row.Sync, row) end
        end
    end
end

-- Puts `content` (already holding its rows) at `left, top` inside `host`. When it is taller
-- than `view`, it goes in the game's scroll frame instead. Returns the height shown.
local function Place(host, content, left, top, height, view)
    content:SetHeight(max(10, height))
    if view and height > view then
        local sf = FromTemplate("ScrollFrame", host, "ScrollFrameTemplate")
        if sf and type(sf.SetScrollChild) == "function" then
            sf:SetPoint("TOPLEFT", host, "TOPLEFT", left, top)
            sf:SetSize(INNER, view)
            content:SetParent(sf)
            content:ClearAllPoints()
            content:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
            sf:SetScrollChild(content)
            if Has(sf, "ScrollBar") and sf.ScrollBar.SetHideIfUnscrollable then
                sf.ScrollBar:SetHideIfUnscrollable(true)
            end
            return view, sf
        end
    end
    content:SetPoint("TOPLEFT", host, "TOPLEFT", left, top)
    return max(10, height)
end

----------------------------------------------------------------------
-- The options window: the game's portrait window, the addon's icon in
-- the portrait, the rows in the inset.
----------------------------------------------------------------------
local function Version()
    local version = spec.version
    if not version and C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, v = pcall(C_AddOns.GetAddOnMetadata, ADDON, "Version")
        if ok and Readable(v) and type(v) == "string" and v ~= "" then version = v end
    end
    return version
end

-- The game's portrait window; on a client without it, the plain framed window, then the
-- dialog border.
local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local function WindowFrame(name)
    for _, template in ipairs({ "ButtonFrameTemplate", "BasicFrameTemplateWithInset" }) do
        local ok, f = pcall(CreateFrame, "Frame", name, UIParent, template)
        if ok and f then return f, template end
    end
    local ok, f = pcall(CreateFrame, "Frame", name, UIParent, "BackdropTemplate")
    if ok and f then
        if f.SetBackdrop then pcall(f.SetBackdrop, f, DIALOG_BACKDROP) end
        return f, "BackdropTemplate"
    end
    return CreateFrame("Frame", name, UIParent)
end

local function CreateWindow()
    if window then return window end
    local name = ADDON .. "Options"
    local f, template = WindowFrame(name)
    window = f
    local portrait = template == "ButtonFrameTemplate"
    if portrait and ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)

    if portrait and type(f.SetTitle) == "function" then
        f:SetTitle(spec.title)
    elseif Has(f, "TitleText") then
        f.TitleText:SetText(spec.title)
    else
        f.title = Text(f, "GameFontNormal")
        f.title:SetPoint("TOP", 0, -8)
        f.title:SetText(spec.title)
    end
    if portrait and type(f.SetPortraitToAsset) == "function" and spec.icon then
        pcall(f.SetPortraitToAsset, f, spec.icon)
    end
    if not Has(f, "CloseButton") then
        local close = FromTemplate("Button", f, "UIPanelCloseButton")
        if close then
            close:SetPoint("TOPRIGHT", 0, 0)
            close:SetScript("OnClick", function() f:Hide() end)
        end
    end
    local version = Version()
    if version then
        f.version = Text(f, "GameFontDisableSmall")
        if portrait then f.version:SetPoint("TOPLEFT", 66, -36) else f.version:SetPoint("TOPLEFT", 18, -30) end
        f.version:SetText("Version " .. version)
    end
    f:SetScript("OnShow", function() Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN) end)
    f:SetScript("OnHide", function() Sound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE) end)

    -- In the portrait window the rows go in its inset, which starts 60 below the top (under
    -- the portrait) and ends 4 above the bottom. Otherwise under the title.
    local host, left, top, below = f, 18, -50, 22
    if portrait and Has(f, "Inset") then host, left, top, below = f.Inset, 16, -14, 20 end
    f.content = CreateFrame("Frame", nil, f)
    f.content:SetSize(INNER, 10)
    local page = BuildPage(f.content, Rows())
    local shown
    shown, f.scroll = Place(host, f.content, left, top, page.height, MAX_VIEW)
    f:SetSize(WIDTH, (host == f and 0 or 60) - top + shown + below)

    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, name) end   -- Esc closes it
    f:Hide()
    return f
end

function Kit.IsOpen()
    return window ~= nil and window:IsShown() and true or false
end

function Kit.Open()
    if not spec then return end
    if spec.openOptions then            -- the addon has its own options screen
        Run(spec.openOptions)
        return
    end
    local ok = Run(CreateWindow)
    if not (ok and window) then return end
    Kit.Sync()
    window:Show()
    if window.Raise then window:Raise() end
end

function Kit.Close()
    if window then window:Hide() end
end

function Kit.Toggle()
    if Kit.IsOpen() then Kit.Close() else Kit.Open() end
end

-- The same rows as a page under Options > AddOns, laid out like the game's own pages: the big
-- title, the divider under it, the rows below. Skipped quietly on a client without it.
local function RegisterPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = spec.title
    panel:Hide()
    panel.title = Text(panel, "GameFontHighlightHuge")
    panel.title:SetPoint("TOPLEFT", 7, -22)
    panel.title:SetText(spec.title)
    local version = Version()
    if version then
        panel.version = Text(panel, "GameFontDisableSmall")
        panel.version:SetPoint("BOTTOMLEFT", panel.title, "BOTTOMRIGHT", 10, 2)
        panel.version:SetText("Version " .. version)
    end
    panel.divider = panel:CreateTexture(nil, "ARTWORK")
    if panel.divider.SetAtlas then panel.divider:SetAtlas("Options_HorizontalDivider", true) end
    panel.divider:SetPoint("TOP", 0, -50)

    panel.content = CreateFrame("Frame", nil, panel)
    panel.content:SetSize(INNER, 10)
    local rows = Rows()
    if spec.openOptions then
        rows = {
            { kind = "note", text = spec.pageNote or ("The options are in the addon's own window.") },
            { kind = "buttons", buttons = { { label = "Open the options", click = function() Run(spec.openOptions) end } } },
        }
    end
    local page = BuildPage(panel.content, rows)
    panel.scroll = select(2, Place(panel, panel.content, 24, -66, page.height, PAGE_VIEW))
    panel:SetScript("OnShow", function() Kit.Sync() end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, spec.title)
    Settings.RegisterAddOnCategory(category)
    Kit.category, Kit.panel = category, panel
end

----------------------------------------------------------------------
-- Minimap button: the game's tracking-button art (round background,
-- the addon's icon, the gold ring, the round highlight).
----------------------------------------------------------------------
local BUTTON, RIM = 31, 5               -- LibDBIcon's size; the centre sits 5 outside the rim
local SPOTS = { 225, 195, 255, 165, 285, 135, 315, 105, 345, 75, 15, 45 }
local GAP = 22                          -- degrees two buttons need between them

-- Where the angle and the hide flag are kept: <saved settings>.minimap
local function Store()
    local ok, db = Run(spec.db)
    if not ok or type(db) ~= "table" then return {} end
    if type(db.minimap) ~= "table" then db.minimap = {} end
    return db.minimap
end

local function Radius()
    local width = Num(Minimap:GetWidth())
    if not width or width <= 0 then width = 198 end
    return width / 2 + RIM
end

local function PlaceButton()
    if not button then return end
    local angle = math.rad(button.angle or SPOTS[1])
    local radius = Radius()
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- Angles already used by other buttons on the minimap rim, whoever made them.
local function TakenAngles()
    local taken = {}
    local cx, cy = Minimap:GetCenter()
    cx, cy = Num(cx), Num(cy)
    local width = Num(Minimap:GetWidth()) or 198
    if not (cx and cy and Minimap.GetChildren) then return taken end
    local kids = { Minimap:GetChildren() }
    for _, kid in ipairs(kids) do
        pcall(function()
            if kid == button or not kid:IsShown() then return end
            local w, x, y = Num(kid:GetWidth()), kid:GetCenter()
            x, y = Num(x), Num(y)
            if not (w and x and y) or w < 20 or w > 44 then return end
            local scale = Num(kid:GetScale()) or 1
            local dx, dy = x * scale - cx, y * scale - cy
            if (dx * dx + dy * dy) ^ 0.5 < width / 2 - 24 then return end   -- not on the rim
            taken[#taken + 1] = math.deg(math.atan2(dy, dx)) % 360
        end)
    end
    return taken
end

local function FreeAngle()
    local taken = TakenAngles()
    local function free(angle)
        for _, other in ipairs(taken) do
            local d = math.abs(angle - other) % 360
            if min(d, 360 - d) < GAP then return false end
        end
        return true
    end
    for _, angle in ipairs(SPOTS) do
        if free(angle) then return angle end
    end
    for step = 0, 23 do
        if free(step * 15) then return step * 15 end
    end
    return SPOTS[1]
end

local function CursorAngle()
    local cx, cy = Minimap:GetCenter()
    local scale = Num(Minimap:GetEffectiveScale())
    local x, y = GetCursorPosition()
    cx, cy, x, y = Num(cx), Num(cy), Num(x), Num(y)
    if not (cx and cy and x and y and scale and scale > 0) then return nil end
    return math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
end

-- Title in the addon's colour, status lines white, the click hints grey.
local function ButtonTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(spec.title, accent[1], accent[2], accent[3])
    if spec.status then
        local ok, lines = Run(spec.status)
        if ok and type(lines) == "table" then
            for _, line in ipairs(lines) do GameTooltip:AddLine(line, WHITE[1], WHITE[2], WHITE[3], true) end
        end
    end
    local g1, g2, g3 = GRAY[1], GRAY[2], GRAY[3]
    if spec.clickHint then GameTooltip:AddLine("Left-click: " .. spec.clickHint, g1, g2, g3) end
    GameTooltip:AddLine("Right-click: " .. (spec.altHint or "options"), g1, g2, g3)
    GameTooltip:AddLine("Drag: move this button", g1, g2, g3)
    GameTooltip:Show()
end

-- A click on the minimap button or on the addon's line in the minimap's addon list.
function Kit.Click(mouseButton)
    if not spec then return end
    if mouseButton == "RightButton" then
        if spec.alt then Run(spec.alt) else Kit.Open() end
    elseif spec.click then
        Run(spec.click)
    else
        Kit.Open()
    end
    Kit.Sync()
end

local function CreateButton()
    if button or not (Minimap and Minimap.GetWidth) then return end
    local b = CreateFrame("Button", ADDON .. "MinimapButton", Minimap)
    button = b
    b:SetSize(BUTTON, BUTTON)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local background = b:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexture(spec.icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetSize(50, 50)
    ring:SetPoint("TOPLEFT")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- pressed: the icon sinks a little, like the game's own minimap buttons
    b:SetScript("OnMouseDown", function(self)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER", 1, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER")
    end)
    b:SetScript("OnClick", function(_, mouseButton) Kit.Click(mouseButton) end)
    b:SetScript("OnEnter", function(self) if not self.dragging then Run(ButtonTooltip, self) end end)
    b:SetScript("OnLeave", HideTip)
    b:SetScript("OnDragStart", function(self)
        self.dragging = true
        HideTip()
        self:SetScript("OnUpdate", function(me)
            local angle = CursorAngle()
            if angle then
                me.angle = angle
                PlaceButton()
            end
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
        self.icon:ClearAllPoints()
        self.icon:SetPoint("CENTER")
        self.settled = true
        Store().angle = self.angle
        PlaceButton()
    end)

    local store = Store()
    b.angle = Num(store.angle)
    b.settled = b.angle ~= nil
    if not b.angle then
        -- First time: take a free spot now, then look again once the other addons have put
        -- their buttons up, and keep that one.
        b.angle = FreeAngle()
        local function Settle()
            if button.settled or button.dragging then return end
            button.settled = true
            button.angle = FreeAngle()
            Store().angle = button.angle
            PlaceButton()
        end
        if C_Timer and C_Timer.After then C_Timer.After(3, Settle) else Settle() end
    end
    PlaceButton()
end

function Kit.MinimapShown()
    return Store().hide ~= true
end

function Kit.SetMinimapShown(shown)
    Store().hide = (not shown) or nil
    Kit.RefreshMinimap()
end

-- Re-reads the hide flag and the saved angle (after a settings reset, for instance).
function Kit.RefreshMinimap()
    if not spec or spec.minimap == false then return end
    if not Kit.MinimapShown() then
        if button then button:Hide() end
        return
    end
    Run(CreateButton)
    if not button then return end
    local angle = Num(Store().angle)
    if angle then
        button.angle = angle
    elseif button.settled then
        Store().angle = button.angle      -- the settings were reset: keep the spot
    end
    button:Show()
    PlaceButton()
end

-- A ready-made row for the options list.
function Kit.MinimapRow()
    return {
        kind = "check", label = "Show the minimap button",
        tip = "The round button on the edge of the minimap. Without it, the options are still under "
            .. "Options > AddOns and in the addon list next to the minimap.",
        get = Kit.MinimapShown, set = Kit.SetMinimapShown,
    }
end

----------------------------------------------------------------------
-- Setup. Call it once the saved settings are loaded.
--   title, icon, accent = { r, g, b }, version (optional), print = function(msg)
--   db = function() return <saved settings table> end
--   rows = { ... } or a function returning them
--   click = function() end      left-click (default: open the options), clickHint = "..."
--   alt = function() end        right-click (default: open the options), altHint = "..."
--   status = function() return { "line", ... } end   extra tooltip lines
--   openOptions = function() end                     the addon has its own options screen
--   pageNote = "..."                                 the Options page text when it does
--   minimap = false                                  no minimap button (wrong class, say)
----------------------------------------------------------------------
function Kit.Setup(def)
    if spec then return end
    spec = def
    if type(def.accent) == "table" then accent = def.accent end
    Kit.RefreshMinimap()
    Run(RegisterPage)
end
