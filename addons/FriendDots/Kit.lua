-- Shelf Kit: the minimap button and the options window shared by the addons on the Forever
-- Addon Shelf. Every addon carries its own copy of this file (the master is shared/Kit.lua in
-- the working folder; shared/sync-kit.ps1 copies it out), so each addon still works alone.
--
-- An addon describes itself once with Kit.Setup{ ... } and gets:
--   * a round button on the minimap rim (left-click: the addon's main action, right-click:
--     options, drag: move it), which picks a free spot the first time it appears;
--   * an options window built from a list of rows (tick boxes, choices, sliders, buttons);
--   * the same rows as a page under Options > AddOns, when the client has that.
-- Everything is drawn from plain colour textures, so it looks the same on any UI skin, and no
-- Blizzard frame is hooked or changed.
local ADDON, ns = ...
local Kit = {}
ns.Kit = Kit

local floor, max, min = math.floor, math.max, math.min

local C = {
    bg     = { 0.055, 0.055, 0.075 },
    raised = { 0.125, 0.125, 0.165 },
    text   = { 0.93, 0.93, 0.95 },
    dim    = { 0.68, 0.68, 0.74 },
    faint  = { 0.47, 0.47, 0.53 },
    accent = { 0.45, 0.65, 1.00 },      -- replaced by the addon's own colour in Setup
}

local WIDTH, PAD = 460, 16
local INNER = WIDTH - PAD * 2
local CONTROL_X = 176                   -- where the control of a choice or slider row starts
local ROW = 24

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
        Say("|cffff6060options error:|r " .. msg)
    end
    return false
end

----------------------------------------------------------------------
-- Flat widgets
----------------------------------------------------------------------
local function Fill(parent, layer, c, alpha)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    t:SetColorTexture(c[1], c[2], c[3], alpha or 1)
    return t
end

local function Border(frame, c, alpha)
    local sides = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = Fill(frame, "BORDER", c, alpha)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        sides[#sides + 1] = t
    end
    return sides
end

local function SetBorder(sides, c, alpha)
    for _, t in ipairs(sides) do t:SetColorTexture(c[1], c[2], c[3], alpha or 1) end
end

local function Text(parent, font, c, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    c = c or C.text
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function ShowTip(owner, title, body)
    if not (GameTooltip and body) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", 1, 1, 1)
    GameTooltip:AddLine(body, 0.82, 0.82, 0.86, true)
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

-- Small filled button. `selected` draws it as the picked one of a group.
local function Chip(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent)
    b.bg = Fill(b, "BACKGROUND", C.raised)
    b.bg:SetAllPoints()
    b.border = Border(b, C.accent, 0.3)
    b.text = Text(b, "GameFontHighlightSmall", C.dim, "CENTER")
    b.text:SetPoint("CENTER")
    function b:SetLabel(text)
        self.text:SetText(text)
        self:SetSize((Num(self.text:GetStringWidth()) or 40) + 18, 20)
    end
    function b:SetSelected(on)
        self.selected = on and true or false
        local c = on and C.text or C.dim
        self.text:SetTextColor(c[1], c[2], c[3])
        self.bg:SetColorTexture(C.raised[1], C.raised[2], C.raised[3], 1)
        if on then self.bg:SetColorTexture(C.accent[1] * 0.45, C.accent[2] * 0.45, C.accent[3] * 0.45, 1) end
        SetBorder(self.border, C.accent, on and 0.95 or 0.3)
    end
    b:SetLabel(label)
    b:SetScript("OnEnter", function(self)
        self.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        SetBorder(self.border, C.accent, 0.95)
        ShowTip(self, self.tipTitle, self.tip)
    end)
    b:SetScript("OnLeave", function(self)
        self:SetSelected(self.selected)
        HideTip()
    end)
    b:SetScript("OnClick", function(self) if onClick then onClick(self) end end)
    return b
end

----------------------------------------------------------------------
-- Rows. Each builder returns the row's frame (with :Sync() when it shows
-- a setting) and its height. Rows are pinned by their two top corners.
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

function build.header(parent, y, def)
    local row = NewRow(parent, y, 26)
    row.text = Text(row, "GameFontHighlightSmall", C.accent)
    row.text:SetPoint("BOTTOMLEFT", 0, 5)
    row.text:SetText((def.text or ""):upper())
    row.rule = Fill(row, "ARTWORK", C.accent, 0.22)
    row.rule:SetPoint("BOTTOMLEFT", 0, 1)
    row.rule:SetPoint("BOTTOMRIGHT", 0, 1)
    row.rule:SetHeight(1)
    return row, 30
end

function build.note(parent, y, def)
    local row = NewRow(parent, y, ROW)
    row.text = Text(row, "GameFontHighlightSmall", C.faint)
    row.text:SetPoint("TOPLEFT", 0, -3)
    row.text:SetWidth(INNER)
    row.text:SetSpacing(2)
    row.text:SetJustifyV("TOP")
    row.text:SetText(def.text or "")
    -- A wrapped line is about 62 characters at this width; used when the client can't say.
    local height = Num(row.text:GetStringHeight())
    if not height or height < 8 then height = 13 * math.ceil(#(def.text or "") / 62) end
    row:SetHeight(height + 8)
    return row, height + 8
end

function build.check(parent, y, def)
    local row = NewRow(parent, y, ROW, "Button")
    row.box = CreateFrame("Frame", nil, row)
    row.box:SetSize(14, 14)
    row.box:SetPoint("LEFT", 0, 0)
    row.box.bg = Fill(row.box, "BACKGROUND", C.raised)
    row.box.bg:SetAllPoints()
    row.box.border = Border(row.box, C.accent, 0.55)
    row.mark = Fill(row.box, "ARTWORK", C.accent)
    row.mark:SetPoint("TOPLEFT", 3, -3)
    row.mark:SetPoint("BOTTOMRIGHT", -3, 3)
    row.text = Text(row, "GameFontHighlight", C.text)
    row.text:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
    row.text:SetText(def.label)
    function row:Sync()
        local ok, on = Run(def.get)
        if ok and on then self.mark:Show() else self.mark:Hide() end
    end
    row:SetScript("OnClick", function()
        local ok, on = Run(def.get)
        if ok then Run(def.set, not on) end
        Changed()
    end)
    row:SetScript("OnEnter", function(self)
        SetBorder(self.box.border, C.accent, 1)
        ShowTip(self, def.label, def.tip)
    end)
    row:SetScript("OnLeave", function(self)
        SetBorder(self.box.border, C.accent, 0.55)
        HideTip()
    end)
    return row, ROW
end

local function Label(row, def)
    row.label = Text(row, "GameFontHighlight", C.text)
    row.label:SetPoint("TOPLEFT", 0, -5)
    row.label:SetText(def.label)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) ShowTip(self, def.label, def.tip) end)
    row:SetScript("OnLeave", HideTip)
end

-- Lays chips out left to right from `left`, wrapping at the row's right edge.
-- Returns the height used.
local function Flow(row, chips, left, top)
    local x, y = left, top
    for _, chip in ipairs(chips) do
        local w = Num(chip:GetWidth()) or 58
        if x > left and x + w > INNER then
            x, y = left, y - 24
        end
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
        x = x + w + 5
    end
    return (top - y) + 24
end

local function ChipsWidth(chips)
    local total = 0
    for _, chip in ipairs(chips) do total = total + (Num(chip:GetWidth()) or 58) + 5 end
    return total - 5
end

function build.choice(parent, y, def)
    local row = NewRow(parent, y, ROW)
    Label(row, def)
    row.chips = {}
    for _, option in ipairs(def.options) do
        local value, text = option[1], option[2] or tostring(option[1])
        local chip = Chip(row, text, function()
            Run(def.set, value)
            Changed()
        end)
        chip.value, chip.tipTitle, chip.tip = value, def.label, option[3] or def.tip
        row.chips[#row.chips + 1] = chip
    end
    local height
    if ChipsWidth(row.chips) <= INNER - CONTROL_X then
        height = Flow(row, row.chips, CONTROL_X, -2)
    else
        height = 22 + Flow(row, row.chips, 12, -24)     -- too many for one line: under the label
    end
    row:SetHeight(height)
    function row:Sync()
        local ok, now = Run(def.get)
        for _, chip in ipairs(self.chips) do chip:SetSelected(ok and chip.value == now) end
    end
    return row, height
end

local function Format(def, value)
    if type(def.format) == "function" then return def.format(value) end
    return (def.format or "%d"):format(value)
end

function build.slider(parent, y, def)
    local row = NewRow(parent, y, ROW)
    Label(row, def)
    local step = def.step or 1
    local s = CreateFrame("Slider", nil, row)
    row.slider = s
    s:SetPoint("TOPLEFT", row, "TOPLEFT", CONTROL_X, -4)
    s:SetSize(170, 16)
    s:SetOrientation("HORIZONTAL")
    s:EnableMouse(true)
    s:SetMinMaxValues(def.min, def.max)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s.track = Fill(s, "BACKGROUND", C.raised)
    s.track:SetPoint("LEFT", 0, 0)
    s.track:SetPoint("RIGHT", 0, 0)
    s.track:SetHeight(4)
    local thumb = Fill(s, "OVERLAY", C.accent)
    thumb:SetSize(8, 16)
    s:SetThumbTexture(thumb)
    row.value = Text(row, "GameFontHighlightSmall", C.dim)
    row.value:SetPoint("LEFT", s, "RIGHT", 10, 0)

    local function Snap(v)
        v = floor((v - def.min) / step + 0.5) * step + def.min
        v = max(def.min, min(def.max, v))
        return floor(v * 1000 + 0.5) / 1000     -- no 0.30000000000000004 in the saved settings
    end
    function row:Sync()
        local ok, now = Run(def.get)
        now = ok and Num(now) or def.min
        self.syncing = true
        s:SetValue(max(def.min, min(def.max, now)))
        self.syncing = false
        self.value:SetText(Format(def, now))
    end
    s:SetScript("OnValueChanged", function(_, value)
        if row.syncing then return end
        value = Num(value)
        if not value then return end
        value = Snap(value)
        local ok, now = Run(def.get)
        if ok and now == value then return end
        Run(def.set, value)
        Changed()
    end)
    s:SetScript("OnEnter", function(self) ShowTip(self, def.label, def.tip) end)
    s:SetScript("OnLeave", HideTip)
    return row, ROW
end

function build.buttons(parent, y, def)
    local row = NewRow(parent, y, ROW)
    row.chips = {}
    for _, b in ipairs(def.buttons) do
        local chip
        chip = Chip(row, b.label, function(self)
            -- A button that throws something away asks for a second click.
            if b.confirm and not self.armed then
                self.armed = true
                self.text:SetText("Click again to confirm")
                if C_Timer and C_Timer.After then
                    C_Timer.After(4, function()
                        if self.armed then
                            self.armed = nil
                            self.text:SetText(b.label)
                        end
                    end)
                end
                return
            end
            if self.armed then
                self.armed = nil
                self.text:SetText(b.label)
            end
            Run(b.click)
            Changed()
        end)
        if b.confirm then
            -- wide enough for the question, so the row doesn't jump when it is asked
            chip.text:SetText("Click again to confirm")
            local asked = (Num(chip.text:GetStringWidth()) or 120) + 18
            chip.text:SetText(b.label)
            if asked > (Num(chip:GetWidth()) or 0) then chip:SetWidth(asked) end
        end
        chip.tipTitle, chip.tip = b.label, b.tip
        row.chips[#row.chips + 1] = chip
    end
    local height = Flow(row, row.chips, 0, -2) + 2
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

----------------------------------------------------------------------
-- The options window
----------------------------------------------------------------------
local function Version()
    local version = spec.version
    if not version and C_AddOns and C_AddOns.GetAddOnMetadata then
        local ok, v = pcall(C_AddOns.GetAddOnMetadata, ADDON, "Version")
        if ok and Readable(v) and type(v) == "string" and v ~= "" then version = v end
    end
    return version
end

local function CreateWindow()
    if window then return window end
    local name = ADDON .. "Options"
    local f = CreateFrame("Frame", name, UIParent)
    window = f
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)

    f.bg = Fill(f, "BACKGROUND", C.bg, 0.96)
    f.bg:SetAllPoints()
    Border(f, C.accent, 0.45)
    f.top = Fill(f, "ARTWORK", C.accent, 0.9)
    f.top:SetPoint("TOPLEFT")
    f.top:SetPoint("TOPRIGHT")
    f.top:SetHeight(2)

    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(20, 20)
    f.icon:SetPoint("TOPLEFT", PAD, -12)
    f.icon:SetTexture(spec.icon)
    f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f.title = Text(f, "GameFontNormalLarge", C.text)
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
    f.title:SetText(spec.title)
    local version = Version()
    if version then
        f.version = Text(f, "GameFontHighlightSmall", C.faint)
        f.version:SetPoint("BOTTOMLEFT", f.title, "BOTTOMRIGHT", 7, 1)
        f.version:SetText("v" .. version)
    end

    f.close = Chip(f, "x", function() f:Hide() end)
    f.close:SetSize(22, 20)
    f.close:SetPoint("TOPRIGHT", -8, -10)
    f.close.tipTitle, f.close.tip = "Close", "Esc closes it too."

    f.content = CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", PAD, -44)
    f.content:SetSize(INNER, 10)
    local page = BuildPage(f.content, Rows())
    f.content:SetHeight(max(10, page.height))
    f:SetSize(WIDTH, 44 + page.height + PAD)

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

-- The same rows as a page under Options > AddOns. Skipped quietly on a client without it.
local function RegisterPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = spec.title
    panel:Hide()
    panel.title = Text(panel, "GameFontNormalLarge", C.text)
    panel.title:SetPoint("TOPLEFT", 14, -14)
    panel.title:SetText(spec.title)
    local version = Version()
    if version then
        panel.version = Text(panel, "GameFontHighlightSmall", C.faint)
        panel.version:SetPoint("BOTTOMLEFT", panel.title, "BOTTOMRIGHT", 7, 1)
        panel.version:SetText("v" .. version)
    end
    panel.content = CreateFrame("Frame", nil, panel)
    panel.content:SetPoint("TOPLEFT", 14, -44)
    panel.content:SetSize(INNER, 10)
    local rows = Rows()
    if spec.openOptions then
        rows = {
            { kind = "note", text = spec.pageNote or ("The options are in the addon's own window.") },
            { kind = "buttons", buttons = { { label = "Open the options", click = function() Run(spec.openOptions) end } } },
        }
    end
    local page = BuildPage(panel.content, rows)
    panel.content:SetHeight(max(10, page.height))
    panel:SetScript("OnShow", function() Kit.Sync() end)
    local category = Settings.RegisterCanvasLayoutCategory(panel, spec.title)
    Settings.RegisterAddOnCategory(category)
    Kit.category, Kit.panel = category, panel
end

----------------------------------------------------------------------
-- Minimap button
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

local function Place()
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

local function ButtonTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(spec.title, C.accent[1], C.accent[2], C.accent[3])
    if spec.status then
        local ok, lines = Run(spec.status)
        if ok and type(lines) == "table" then
            for _, line in ipairs(lines) do GameTooltip:AddLine(line, 1, 1, 1, true) end
        end
    end
    if spec.clickHint then GameTooltip:AddLine("Left-click: " .. spec.clickHint, 0.6, 0.6, 0.65) end
    if spec.altHint then
        GameTooltip:AddLine("Right-click: " .. spec.altHint, 0.6, 0.6, 0.65)
    else
        GameTooltip:AddLine("Right-click: options", 0.6, 0.6, 0.65)
    end
    GameTooltip:AddLine("Drag: move this button", 0.6, 0.6, 0.65)
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
    -- the usual three pieces: round background, the addon's icon, the gold ring over both
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
                Place()
            end
        end)
    end)
    b:SetScript("OnDragStop", function(self)
        self.dragging = nil
        self:SetScript("OnUpdate", nil)
        self.settled = true
        Store().angle = self.angle
        Place()
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
            Place()
        end
        if C_Timer and C_Timer.After then C_Timer.After(3, Settle) else Settle() end
    end
    Place()
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
    Place()
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
--   minimap = false                                  no minimap button (wrong class, say)
----------------------------------------------------------------------
function Kit.Setup(def)
    if spec then return end
    spec = def
    if type(def.accent) == "table" then C.accent = def.accent end
    Kit.RefreshMinimap()
    Run(RegisterPage)
end
