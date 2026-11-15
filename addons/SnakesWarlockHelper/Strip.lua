-- Snakes Warlock Helper: the reminder strip. A row of icons that exists only while something is
-- missing. Out of combat an icon can be clicked to cast the missing buff; in combat the icons are
-- display-only, because the game doesn't let addons show or move clickable cast buttons during a
-- fight.
--
-- Each icon is a stand-alone action button (ActionButtonTemplate at its own 45 x 45, drawn the way
-- the game draws buttons without bar art). The row sits in one frame scaled to the chosen icon
-- size, the way Edit Mode scales an action bar, with the action bar's 6 px gap. A buff running out
-- shows its time under the icon like the buff frame does; nothing is printed on the icon.
local _, ns = ...
local UI = ns.UI
local C = UI.color
local Strip = {}
ns.Strip = Strip

local SIZE = UI.ACTION_SIZE          -- 45, ActionButtonTemplate
local GAP = 6                        -- between action bar buttons
local TIMER_H = 14                   -- room under the row for a countdown
local MOVER_W = 180                  -- the drag box is at least this wide on screen, for its label
local icons, buttons = {}, {}
local current = {}

local function Scale()
    return ((ns.db and ns.db.iconSize) or 32) / SIZE
end

local function UseKeyDown()
    local ok, v
    if C_CVar and C_CVar.GetCVarBool then
        ok, v = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
    elseif GetCVarBool then
        ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    end
    return ok and v
end

----------------------------------------------------------------------
-- Tooltip and right-click
----------------------------------------------------------------------
local function ShowTip(icon)
    local e = icon and icon.entry
    if not e then return end
    local gold, white, gray, green = C.gold, C.white, C.gray, C.green
    GameTooltip:SetOwner(icon, "ANCHOR_BOTTOM", 0, -6)
    GameTooltip:AddLine(e.title, gold[1], gold[2], gold[3])
    GameTooltip:AddLine(e.text, white[1], white[2], white[3], true)
    if not ns.demo then
        if InCombatLockdown() then
            GameTooltip:AddLine("Can't be clicked during a fight.", gray[1], gray[2], gray[3])
        elseif e.spell or e.macro then
            GameTooltip:AddLine(e.macro and "Click to use it" or "Click to cast it", green[1], green[2], green[3])
        end
    end
    GameTooltip:AddLine("Right-click: quiet for 10 minutes", gray[1], gray[2], gray[3])
    GameTooltip:AddLine("Shift + right-click: turn this reminder off", gray[1], gray[2], gray[3])
    GameTooltip:Show()
end

local function HideTip() GameTooltip:Hide() end

local function RightClick(e)
    if not e or ns.demo then return end
    if IsShiftKeyDown() then ns.Reminders.Disable(e.key) else ns.Reminders.Snooze(e.key) end
    GameTooltip:Hide()
end

----------------------------------------------------------------------
-- Frames
----------------------------------------------------------------------
local function NewIcon(i)
    local ic = UI.ActionIcon(Strip.bar)
    -- The countdown hangs under the icon (AuraButtonArtTemplate's Duration: GameFontNormalSmall,
    -- TOP to the icon's BOTTOM). It lives on the unscaled strip frame so it stays readable at
    -- every icon size.
    ic.timer = Strip.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ic.timer:SetPoint("TOP", ic, "BOTTOM", 0, -1)
    -- Hovered without a cast button on top (during a fight, in the demo): the button's own
    -- highlight shows, plus the tooltip.
    ic:SetScript("OnEnter", function(self) ShowTip(self) end)
    ic:SetScript("OnLeave", HideTip)
    ic:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then RightClick(self.entry) end
    end)
    ic:Hide()
    icons[i] = ic
    return ic
end

local function NewButton(i)
    local b = CreateFrame("Button", "SnakesWarlockHelperCast" .. i, UIParent, "SecureActionButtonTemplate")
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Strip.frame:GetFrameLevel() + 10)
    if UseKeyDown() then b:RegisterForClicks("AnyDown", "AnyUp") else b:RegisterForClicks("AnyUp") end
    -- The template's own hover and pressed art, at the template's sizes (the button is scaled
    -- to the icon, so it is 45 x 45 in its own units).
    if b.SetHighlightAtlas then
        b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        UI.PlaceState(b:GetHighlightTexture(), nil, 46, 45)
        b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-AddRow-Down")
        UI.PlaceState(b:GetPushedTexture(), "OVERLAY", 51, 51)
    end
    b:SetScript("OnEnter", function(self) ShowTip(self.icon) end)
    b:SetScript("OnLeave", HideTip)
    b:SetScript("PostClick", function(self, button, down)
        if button == "RightButton" and not down then RightClick(self.entry) end
    end)
    b:Hide()
    buttons[i] = b
    return b
end

-- Edit Mode's selection box (EditModeSystemSelectionTemplate in
-- Blizzard_EditMode/Shared/EditModeSystemTemplates.xml): a nine-slice of the
-- editmode-actionbar-selected kit with the system's name in GameFontHighlightLarge.
local SELECTION_LAYOUT = {
    TopRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = 8 },
    TopLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = 8 },
    BottomLeftCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = -8, y = -8 },
    BottomRightCorner = { atlas = "%s-NineSlice-Corner", mirrorLayout = true, x = 8, y = -8 },
    TopEdge = { atlas = "_%s-NineSlice-EdgeTop" },
    BottomEdge = { atlas = "_%s-NineSlice-EdgeBottom" },
    LeftEdge = { atlas = "!%s-NineSlice-EdgeLeft" },
    RightEdge = { atlas = "!%s-NineSlice-EdgeRight" },
    Center = { atlas = "%s-NineSlice-Center", x = -8, y = 8, x1 = 8, y1 = -8 },
}

local function NewMover(f)
    local nine = UI.HasTemplate("NineSliceCodeTemplate") and NineSliceUtil and NineSliceUtil.ApplyLayout
    local m = CreateFrame("Frame", nil, f, nine and "NineSliceCodeTemplate" or nil)
    m:SetFrameLevel(f:GetFrameLevel() + 20)
    m:SetAllPoints(f)
    if nine then pcall(NineSliceUtil.ApplyLayout, m, SELECTION_LAYOUT, "editmode-actionbar-selected") end
    m.label = m:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    m.label:SetPoint("CENTER")
    m.label:SetText("Warlock reminders")
    m:EnableMouse(true)
    m:RegisterForDrag("LeftButton")
    m:SetScript("OnDragStart", function()
        if not InCombatLockdown() then f:StartMoving(); f.moving = true end
    end)
    m:SetScript("OnDragStop", function()
        if f.moving then f:StopMovingOrSizing(); f.moving = nil; UI.SavePoint(f, "stripPoint") end
    end)
    m:Hide()
    return m
end

local function Create()
    if Strip.frame then return end
    local f = CreateFrame("Frame", "SnakesWarlockHelperStrip", UIParent)
    Strip.frame = f
    f:SetSize(32, 32)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:Hide()

    Strip.bar = CreateFrame("Frame", nil, f)      -- holds the icons; scaled to the icon size
    Strip.bar:SetSize(SIZE, SIZE)

    Strip.mover = NewMover(f)
    Strip.RestorePosition()
end

function Strip.RestorePosition()
    if Strip.frame then UI.RestorePoint(Strip.frame, "stripPoint", "CENTER", 0, -170) end
end

----------------------------------------------------------------------
-- Showing a list of reminders
----------------------------------------------------------------------
function Strip.Show(list)
    Create()
    current = list or {}
    local n = #current
    local now = GetTime()
    local scale = Scale()
    Strip.bar:SetScale(scale)

    for i = 1, math.max(n, #icons) do
        local e, ic = current[i], icons[i]
        if e then
            ic = ic or NewIcon(i)
            e.expiresAt = e.remaining and (now + e.remaining) or nil
            ic.entry = e
            ic:ClearAllPoints()
            ic:SetPoint("TOPLEFT", Strip.bar, "TOPLEFT", (i - 1) * (SIZE + GAP), 0)
            ic.tex:SetTexture(e.icon)
            ic:Show()
            ic.timer:Show()
        elseif ic then
            ic.entry = nil
            ic.timer:SetText("")
            ic.timer:Hide()
            ic:Hide()
        end
    end

    -- Wide enough for the icons, or for the drag box while unlocked. Anchored by its centre,
    -- so the row grows evenly to both sides.
    local slots = math.max(n, 1)
    local width = slots * SIZE + (slots - 1) * GAP
    Strip.bar:SetSize(width, SIZE)
    local screenW = width * scale
    if not ns.db.locked then screenW = math.max(screenW, MOVER_W) end
    Strip.frame:SetSize(screenW, SIZE * scale + TIMER_H)
    Strip.bar:ClearAllPoints()                    -- the row is centred in the strip
    Strip.bar:SetPoint("TOP", Strip.frame, "TOP", 0, 0)
    if n > 0 or not ns.db.locked then Strip.frame:Show() else Strip.frame:Hide() end
    Strip.UpdateTimers()
    Strip.ApplySecure()
end

function Strip.UpdateTimers()
    if not Strip.frame or not Strip.frame:IsShown() then return end
    local now = GetTime()
    for i = 1, #current do
        local e, ic = current[i], icons[i]
        if ic and e then
            if e.state == "expiring" and e.expiresAt and e.expiresAt > now then
                UI.SetDuration(ic.timer, e.expiresAt - now)
            else
                ic.timer:SetText("")
            end
        end
    end
end

-- Click-to-cast overlays. Only touched out of combat; dropped when a fight starts.
function Strip.ApplySecure()
    if not Strip.frame or InCombatLockdown() then return end
    local scale = Scale()
    for i = 1, math.max(#current, #buttons) do
        local e, b = current[i], buttons[i]
        if e and (e.spell or e.macro) and not ns.demo then
            b = b or NewButton(i)
            b.entry, b.icon = e, icons[i]
            b:SetAttribute("type1", e.macro and "macro" or "spell")
            b:SetAttribute("spell", e.spell)
            b:SetAttribute("macrotext", e.macro)
            b:SetScale(scale)
            b:ClearAllPoints()
            b:SetAllPoints(icons[i])
            b:Show()
        elseif b then
            b.entry = nil
            b:SetAttribute("type1", nil)
            b:Hide()
            b:ClearAllPoints()
        end
    end
end

local function OnCombatStart()
    -- Fires just before the lockdown: last chance to detach the cast buttons, so the
    -- icons stay free to appear, move and disappear during the fight.
    for _, b in ipairs(buttons) do
        b:Hide()
        b:ClearAllPoints()
    end
    if Strip.frame and Strip.frame.moving then
        Strip.frame:StopMovingOrSizing()
        Strip.frame.moving = nil
        UI.SavePoint(Strip.frame, "stripPoint")
    end
end

function Strip.ApplyLock()
    Create()
    if ns.db.locked then Strip.mover:Hide() else Strip.mover:Show() end
    Strip.Show(current)
end

function Strip.Enable()
    Create()
    ns.On("PLAYER_REGEN_DISABLED", OnCombatStart)
    ns.On("PLAYER_REGEN_ENABLED", function() Strip.ApplySecure() end)
    Strip.ApplyLock()
end
