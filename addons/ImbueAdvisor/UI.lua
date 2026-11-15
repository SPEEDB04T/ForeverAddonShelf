-- Imbue Advisor: the on-screen frame (one click-to-cast button per weapon hand, and under it
-- a list of every imbue you know for when you want another one)
--
-- Each piece copies a widget the game already has (Gethe/wow-ui-source, branch forever):
--  * a hand button is the buff area's weapon-enchant icon (Blizzard_BuffFrame/BuffFrameTemplates.xml,
--    AuraButtonArtTemplate as BuffFrame.lua shows a "TempEnchant"): 30 px icon, the temp-enchant
--    border, the time left in small gold text under it, white under 90 s, fading in and out under 31 s;
--  * the list is the spell flyout's buttons (Blizzard_ActionBar/Shared/SpellFlyout.lua and .xml:
--    SmallActionButtonTemplate, 30 px, 4 px apart), without the flyout's background strip.
local _, ns = ...
local UI = {}
ns.UI = UI

local max = math.max
local SLOTS = { 16, 17 }
local SLOT_NAME = { [16] = "Main hand", [17] = "Off hand" }
local SLOT_LOWER = { [16] = "main hand", [17] = "off hand" }
local SLOT_SHORT = { [16] = "MH", [17] = "OH" }      -- chat report only
local MODE_LABEL = { melee = "Melee", tank = "Tank", caster = "Caster", heal = "Healer", pvp = "PvP" }

-- The game's own colours (the values after the name are the game's, for a client without one)
local function GameColor(name, r, g, b)
    local c = _G[name]
    if type(c) == "table" and c.GetRGB then return { c:GetRGB() } end
    return { r, g, b }
end
local function Hex(col)
    return ("|cff%02x%02x%02x"):format(col[1] * 255 + 0.5, col[2] * 255 + 0.5, col[3] * 255 + 0.5)
end
local GOLD = GameColor("NORMAL_FONT_COLOR", 1.0, 0.82, 0.0)
local WHITE = GameColor("HIGHLIGHT_FONT_COLOR", 1.0, 1.0, 1.0)
local GRAY = GameColor("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
local GREEN = GameColor("GREEN_FONT_COLOR", 0.1, 1.0, 0.1)
local YELLOW = GameColor("YELLOW_FONT_COLOR", 1.0, 1.0, 0.0)
local RED = GameColor("RED_FONT_COLOR", 1.0, 0.125, 0.125)
local ORANGE = GameColor("ORANGE_FONT_COLOR", 1.0, 0.5, 0.25)
local LIGHTBLUE = GameColor("LIGHTBLUE_FONT_COLOR", 0.53, 0.67, 1.0)

local COLOR_PICK = LIGHTBLUE    -- an imbue you chose yourself (tooltip and chat text)

-- AuraButtonArtTemplate: a 30 x 40 button, icon 30 x 30 at the top, duration text under it.
-- AuraContainerTemplate puts 5 px (iconPadding) between two of them.
local AURA_W, AURA_H, ICON, HAND_GAP = 30, 40, 30, 5
-- SpellFlyoutPopupButtonTemplate is a SmallActionButtonTemplate (30 px); SpellFlyout.lua puts
-- SPELLFLYOUT_DEFAULT_SPACING (4 px) between buttons.
local FBTN, FGAP = 30, 4
local WARN_FADE = 31                     -- BUFF_WARNING_TIME: under this the icon fades in and out
local WARN_WHITE = 90                    -- BUFF_DURATION_WARNING_TIME: under this the text turns white
local MAX_ALTS = #ns.IMBUE_ORDER
local CLOSE_AFTER = 0.3                  -- seconds off the frame before the list closes

local function UseKeyDown()
    local ok, v
    if C_CVar and C_CVar.GetCVarBool then
        ok, v = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
    elseif GetCVarBool then
        ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    end
    return ok and v
end

-- The game's own short time ("17 m", "45 s"), as the buff area writes it
local function FormatTime(sec)
    if SecondsToTimeAbbrev then
        local ok, fmt, v = pcall(SecondsToTimeAbbrev, sec)
        if ok and fmt then return fmt:format(v) end
    end
    if sec >= 60 then return ("%d m"):format(math.ceil(sec / 60)) end
    return ("%d s"):format(math.floor(sec))
end

local function ImbueName(key)
    if not key then return nil end
    local res = UI.result
    if res and res.imbues[key] then return res.imbues[key].name end
    return ns.IMBUES[key] and ns.IMBUES[key].english
end

local function ScoreText(sr, row)
    local txt = sr.unit == "dps" and ("%.1f dps"):format(row.value) or ("priority %.0f"):format(row.value)
    if sr.slowBonus and row.key == "frostbrand" then txt = txt .. " (incl. slow)" end
    return txt
end

-- /use <slot> points a weapon-targeted imbue at the right hand
local function CastMacro(info, slot)
    return "/cast " .. info.name .. "\n/use " .. slot
end

----------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------
local function OnEnter(self)
    local res = UI.result
    if not res then return end
    local slot = self.slot
    local sr = res.slots[slot]
    local W, G, P = WHITE, GREEN, COLOR_PICK
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Imbue Advisor: " .. SLOT_NAME[slot], GOLD[1], GOLD[2], GOLD[3])
    if self.use and self.picked then
        GameTooltip:AddDoubleLine("Your pick", self.use.name, W[1], W[2], W[3], P[1], P[2], P[3])
        if self.rec then GameTooltip:AddDoubleLine("Advisor's pick", self.rec.name, W[1], W[2], W[3], G[1], G[2], G[3]) end
    elseif self.use then
        GameTooltip:AddDoubleLine("Use", self.use.name, W[1], W[2], W[3], G[1], G[2], G[3])
    end
    local e = ns.WeaponEnchants()[slot]
    local cur = ImbueName(ns.current[slot]) or (e.has and "something else" or "none")
    GameTooltip:AddDoubleLine("On weapon now", cur, W[1], W[2], W[3], W[1], W[2], W[3])
    GameTooltip:AddLine(" ")
    for _, row in ipairs(ns.Calc.SortedScores(res, sr)) do
        local col = W
        if row.key == sr.best then
            col = G
        elseif self.picked and self.use and row.key == self.use.key then
            col = P
        end
        GameTooltip:AddDoubleLine(row.name, ScoreText(sr, row), col[1], col[2], col[3], col[1], col[2], col[3])
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(("Mode: %s (%s)"):format(MODE_LABEL[res.mode] or res.mode, res.modeReason), GRAY[1], GRAY[2], GRAY[3])
    GameTooltip:AddLine("Left-click: apply   Right-click: report in chat", GRAY[1], GRAY[2], GRAY[3])
    GameTooltip:Show()
end

local function OnLeave() GameTooltip:Hide() end

-- A button in the list of all imbues
local function AltOnEnter(self)
    local res, info = UI.result, self.info
    if not res or not info then return end
    local slot = self.slot
    local sr = res.slots[slot]
    local main = UI.frame.buttons[slot]
    local inUse = main.use and main.use.key == info.key
    local isBest = sr and sr.best == info.key
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(info.name, GOLD[1], GOLD[2], GOLD[3])
    if sr and sr.scores[info.key] then
        GameTooltip:AddLine(SLOT_NAME[slot] .. ": " .. ScoreText(sr, { key = info.key, value = sr.scores[info.key] }), WHITE[1], WHITE[2], WHITE[3])
    end
    if isBest then GameTooltip:AddLine("The advisor's pick", GREEN[1], GREEN[2], GREEN[3]) end
    if inUse and main.picked then GameTooltip:AddLine("Your pick", COLOR_PICK[1], COLOR_PICK[2], COLOR_PICK[3]) end
    local hint
    if inUse then
        hint = "Click: put it on your " .. SLOT_LOWER[slot]
    elseif isBest then
        hint = "Click: put it on your " .. SLOT_LOWER[slot] .. " and go back to the advisor's pick"
    else
        hint = "Click: put it on your " .. SLOT_LOWER[slot] .. " and keep using it there"
    end
    GameTooltip:AddLine(hint, GRAY[1], GRAY[2], GRAY[3], true)
    GameTooltip:Show()
end

-- The click itself casts (a secure macro). This runs after it: the imbue you clicked is the one
-- that hand uses from now on. Clicking the advisor's pick goes back to following the advisor.
local function AltPostClick(self, button, down)
    if button ~= "LeftButton" or down then return end
    local res, info = UI.result, self.info
    local sr = res and res.slots[self.slot]
    if not info or not sr or not sr.best then return end
    local main = UI.frame.buttons[self.slot]
    if main.use and main.use.key == info.key then return end
    ns.SetPick(self.slot, info.key ~= sr.best and info.key or nil)
    if GameTooltip:IsOwned(self) then AltOnEnter(self) end
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
function UI.SavePosition()
    local point, _, relPoint, x, y = UI.frame:GetPoint()
    ns.db.point = { point, relPoint, x, y }
end

function UI.RestorePosition()
    local f, p = UI.frame, ns.db.point
    f:ClearAllPoints()
    if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 0, -180) end
end

local function StartMove(self)
    local f = UI.frame
    if not ns.db.locked and not InCombatLockdown() then f:StartMoving(); f.moving = true end
end

local function StopMove()
    local f = UI.frame
    if f.moving then
        f:StopMovingOrSizing(); f.moving = nil; UI.SavePosition()
        UI.PlaceList()      -- it may have to open the other way now
    end
end

local function NewSecureButton(name, parent, w, h)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(w, h)
    if UseKeyDown() then b:RegisterForClicks("AnyDown", "AnyUp") else b:RegisterForClicks("AnyUp") end
    return b
end

-- A hand button: the buff area's weapon-enchant icon (AuraButtonArtTemplate shown as a
-- TempEnchant), at the game's size. Differences: it casts on click (a secure macro button, where
-- the game's cancels the enchant on right-click), and its icon is the imbue it casts, where the
-- game's shows the weapon.
local function NewHandButton(name, parent)
    local b = NewSecureButton(name, parent, AURA_W, AURA_H)

    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetSize(ICON, ICON)
    b.icon:SetPoint("TOP")

    b.timer = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")    -- DEFAULT_AURA_DURATION_FONT
    b.timer:SetPoint("TOP", b.icon, "BOTTOM")

    b.enchBorder = b:CreateTexture(nil, "OVERLAY")
    b.enchBorder:SetTexture("Interface\\Buttons\\UI-TempEnchant-Border")
    b.enchBorder:SetSize(32, 32)
    b.enchBorder:SetPoint("CENTER", b.icon, "CENTER")
    return b
end

-- A list button: the spell flyout's button (SpellFlyoutPopupButtonTemplate, which is a
-- SmallActionButtonTemplate with no bar art). Sizes, anchors and layers are the template's at
-- its own 30 px (ActionButtonTemplate.xml, and SmallActionButtonMixin_OnLoad / UpdateButtonArt in
-- ActionButton.lua and Mainline/ActionButtonOverrides.lua). The template itself is not inherited:
-- its scripts expect an action-bar slot or a flyout spell, and this is a secure macro button.
local function SetArt(t, atlas, w, h, layer, sub)
    t:SetAtlas(atlas)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT")
    t:SetSize(w, h)
    if layer then t:SetDrawLayer(layer, sub or 0) end
end

local function NewFlyoutButton(name, parent)
    local b = NewSecureButton(name, parent, FBTN, FBTN)

    b.slotBg = b:CreateTexture(nil, "BACKGROUND")
    b.slotBg:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
    b.slotBg:SetAllPoints()

    b.icon = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.icon:SetAllPoints()
    local mask = b.CreateMaskTexture and b:CreateMaskTexture()
    if mask and b.icon.AddMaskTexture then
        mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
        mask:SetSize(45, 45)
        mask:SetPoint("CENTER", b.icon, "CENTER")
        b.icon:AddMaskTexture(mask)
    else
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    b:SetNormalAtlas("UI-HUD-ActionBar-IconFrame-AddRow")
    b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-AddRow-Down")
    b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover", "ADD")
    local normal, pushed, hl = b:GetNormalTexture(), b:GetPushedTexture(), b:GetHighlightTexture()
    if normal then SetArt(normal, "UI-HUD-ActionBar-IconFrame-AddRow", 35, 35, "OVERLAY") end
    if pushed then SetArt(pushed, "UI-HUD-ActionBar-IconFrame-AddRow-Down", 35, 35, "OVERLAY") end
    if hl then SetArt(hl, "UI-HUD-ActionBar-IconFrame-Mouseover", 31.6, 30.9) end

    -- the template's CheckedTexture (what SpellFlyout shows on the spell in use): your own pick.
    -- A button's checked texture draws on ARTWORK, under the frame art moved to OVERLAY.
    b.pin = b:CreateTexture(nil, "ARTWORK")
    SetArt(b.pin, "UI-HUD-ActionBar-IconFrame-Mouseover", 31.6, 30.9, "ARTWORK")
    b.pin:SetBlendMode("ADD")
    b.pin:Hide()
    return b
end

-- Is the mouse on the frame or on the open list (with a little room around them)?
local function MouseIsNear(f)
    if f:IsMouseOver(4, -4, -4, 4) then return true end
    return f.list:IsShown() and f.list:IsMouseOver(6, -6, -4, 4) or false
end

-- Opens the list while the mouse is on the frame and closes it shortly after it leaves.
-- Nothing may be shown or hidden in a fight, so it only runs between fights.
-- Under 31 s left the buff area fades a weapon-enchant icon between 30 % and 100 % every
-- 1.5 s (AuraContainerTemplate: auraWarningFlashPeriod, auraWarningMinAlpha/MaxAlpha). Only the
-- textures and text change, never the secure button, so this is safe in a fight.
local fadeClock = 0
local function FadeUpdate(f, elapsed)
    fadeClock = (fadeClock + elapsed) % 1.5
    local p = fadeClock / 0.75
    if p > 1 then p = 2 - p end
    local alpha = 1 - 0.7 * p
    for _, slot in ipairs(SLOTS) do
        local b = f.buttons[slot]
        local a = b.fading and alpha or 1
        if b.alpha ~= a then
            b.alpha = a
            b.icon:SetAlpha(a); b.enchBorder:SetAlpha(a); b.timer:SetAlpha(a)
        end
    end
end

local tick, away = 0, 0
local function HoverUpdate(self, elapsed)
    FadeUpdate(self, elapsed)
    tick = tick + elapsed
    if tick < 0.1 then return end
    local dt = tick
    tick = 0
    if ns.db.others ~= "hover" or InCombatLockdown() then return end
    if MouseIsNear(self) then
        away = 0
        if not self.list:IsShown() then UI.ShowList(true) end
    elseif self.list:IsShown() then
        away = away + dt
        if away >= CLOSE_AFTER and not self.moving then UI.ShowList(false) end
    end
end

function UI.Create()
    if UI.frame then return end
    -- No panel and no title: like the buff area, the icons stand on their own
    local f = CreateFrame("Frame", "ImbueAdvisorFrame", UIParent)
    UI.frame = f
    f:SetSize(AURA_W * 2 + HAND_GAP, AURA_H)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", StartMove)
    f:SetScript("OnDragStop", StopMove)

    -- The list of every imbue, best first, one flyout column under each hand's button.
    -- It holds the buttons and draws nothing itself.
    local list = CreateFrame("Frame", "ImbueAdvisorList", f)
    f.list = list
    list:SetFrameStrata("MEDIUM")
    list:EnableMouse(true)
    list:Hide()
    list.rows = 0

    f.buttons, f.alts = {}, {}
    for _, slot in ipairs(SLOTS) do
        local b = NewHandButton("ImbueAdvisorButton" .. slot, f)
        b.slot = slot
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", StartMove)
        b:SetScript("OnDragStop", StopMove)
        b:SetScript("OnEnter", OnEnter)
        b:SetScript("OnLeave", OnLeave)
        b:SetScript("PostClick", function(_, button, down)
            if button == "RightButton" and not down then UI.PrintReport() end
        end)
        b:Hide()
        f.buttons[slot] = b

        f.alts[slot] = {}
        for i = 1, MAX_ALTS do
            local a = NewFlyoutButton("ImbueAdvisorAlt" .. slot .. "_" .. i, list)
            a.slot = slot
            a:SetScript("OnEnter", AltOnEnter)
            a:SetScript("OnLeave", OnLeave)
            a:SetScript("PostClick", AltPostClick)
            a:Hide()
            f.alts[slot][i] = a
        end
    end

    f:SetScale(ns.db.scale or 1)
    UI.RestorePosition()
    f:Hide()
    f:SetScript("OnUpdate", HoverUpdate)
end

-- Recommendation changed: the buttons follow when that is allowed (not in a fight).
function UI.Update(res)
    UI.result = res
    local f = UI.frame
    if not f then return end
    for _, slot in ipairs(SLOTS) do
        local sr = res.slots[slot]
        f.buttons[slot].rec = sr and sr.best and res.imbues[sr.best] or nil
    end
    UI.ApplySecure()
    UI.UpdateStatus()
end

-- Layout and click actions. Blocked in combat, so it waits for combat to end.
function UI.ApplySecure()
    local f = UI.frame
    if not f then return end
    if InCombatLockdown() then UI.pending = true; return end
    UI.pending = false
    local res = UI.result

    local shownSlots = {}
    for _, slot in ipairs(SLOTS) do
        local b = f.buttons[slot]
        local key, picked = ns.UseKey(res, slot)
        b.use = key and res.imbues[key] or nil
        b.picked = b.use and picked or false
        b.icon:SetTexture(b.use and b.use.icon or nil)
        if b.use then
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", CastMacro(b.use, slot))
            shownSlots[#shownSlots + 1] = slot
        else
            b:SetAttribute("type1", nil)
            b:SetAttribute("macrotext1", nil)
            b:Hide()
        end
    end
    local n = #shownSlots
    f:SetWidth(max(AURA_W, n * AURA_W + max(0, n - 1) * HAND_GAP))
    for i, slot in ipairs(shownSlots) do
        local b = f.buttons[slot]
        b.x = (i - 1) * (AURA_W + HAND_GAP)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", b.x, 0)
        b:Show()
    end
    if ns.db.shown and n > 0 then f:Show() else f:Hide() end

    -- The list: every imbue that hand can take, best first. The order only changes when the
    -- numbers do, so a button never moves from under the mouse because you clicked one.
    local rowsMax = 0
    for _, slot in ipairs(SLOTS) do
        local b = f.buttons[slot]
        local sr = res and res.slots[slot]
        local rows = b.use and ns.Calc.SortedScores(res, sr) or {}
        if #rows < 2 then rows = {} end         -- one imbue known: nothing else to offer
        rowsMax = max(rowsMax, #rows)
        for i, a in ipairs(f.alts[slot]) do
            local row = rows[i]
            if row then
                local info = res.imbues[row.key]
                a.info = info
                a.icon:SetTexture(info.icon)
                if b.picked and row.key == b.use.key then a.pin:Show() else a.pin:Hide() end
                a:SetAttribute("type1", "macro")
                a:SetAttribute("macrotext1", CastMacro(info, slot))
                a.index = i
                a:Show()
            else
                a.info = nil
                a:SetAttribute("type1", nil)
                a:SetAttribute("macrotext1", nil)
                a:Hide()
            end
        end
    end
    f.list.rows = rowsMax
    if rowsMax > 0 then
        f.list:SetHeight(rowsMax * FBTN + (rowsMax - 1) * FGAP)
    end
    UI.PlaceList()

    local others = ns.db.others
    if others == "always" then
        UI.ShowList(true)
    elseif others ~= "hover" or rowsMax == 0 or not f:IsShown() then
        UI.ShowList(false)
    end
end

-- Under the frame (below the time-left text), or above it when there is no room underneath.
-- Best imbue next to the frame. One gap everywhere: the flyout's 4 px.
function UI.PlaceList()
    local f = UI.frame
    if not f or InCombatLockdown() then return end
    local list = f.list
    local up = false
    local bottom = f:GetBottom()
    if bottom and list.rows > 0 and bottom < list:GetHeight() + FGAP then up = true end
    list.up = up
    list:ClearAllPoints()
    if up then
        list:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, FGAP)
        list:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, FGAP)
    else
        list:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -FGAP)
        list:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -FGAP)
    end
    for _, slot in ipairs(SLOTS) do
        local b = f.buttons[slot]
        for _, a in ipairs(f.alts[slot]) do
            if a.info and b.x then
                local x = b.x                           -- same 30 px column as the hand's icon
                local y = (a.index - 1) * (FBTN + FGAP)
                a:ClearAllPoints()
                if up then
                    a:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", x, y)
                else
                    a:SetPoint("TOPLEFT", list, "TOPLEFT", x, -y)
                end
            end
        end
    end
end

function UI.ShowList(want)
    local f = UI.frame
    if not f or InCombatLockdown() then return end
    if want and f.list.rows > 0 and ns.db.others ~= "off" then
        UI.PlaceList()
        f.list:Show()
    else
        f.list:Hide()
    end
    away = 0
end

-- A fight is starting. This is the last moment anything may be hidden: a list that opened
-- because the mouse was on the frame closes, so it is not stuck open for the whole fight.
function UI.CombatStart()
    local f = UI.frame
    if not f or InCombatLockdown() then return end
    if ns.db.others ~= "always" then f.list:Hide() end
end

-- The time-left text and the icon (runs every second; only textures and text, so safe in combat).
--  * the imbue is on: the time in gold, white under 90 s, as the buff area writes it
--  * a different imbue is on: its time in yellow
--  * nothing is on: the icon greyed out and "None" in red
function UI.UpdateStatus()
    local f = UI.frame
    if not f or not f:IsShown() then return end
    local ench = ns.WeaponEnchants()
    for _, slot in ipairs(SLOTS) do
        local b = f.buttons[slot]
        if b:IsShown() and b.use then
            local e = ench[slot]
            local col
            b.state = not e.has and "missing" or (ns.current[slot] == b.use.key and "on" or "other")
            b.icon:SetDesaturated(b.state == "missing")
            if b.state == "missing" then
                b.timer:SetText(NONE or "None")
                col = RED
            else
                b.timer:SetText(e.exp and FormatTime(e.exp) or "")
                if b.state == "other" then
                    col = YELLOW
                else
                    col = (e.exp and e.exp < WARN_WHITE) and WHITE or GOLD
                end
            end
            b.timer:SetTextColor(col[1], col[2], col[3])
            b.fading = e.has and e.exp and e.exp < WARN_FADE or false
        else
            b.fading = false
        end
    end
end

----------------------------------------------------------------------
-- Chat output
----------------------------------------------------------------------
function UI.PrintReport()
    local res = ns.result
    if not res then ns.Print("nothing calculated yet.") return end
    local st = res.stats
    ns.Print(("mode %s (%s), target level %+d, hit %.0f%%, crit %.1f%%"):format(
        MODE_LABEL[res.mode] or res.mode, res.modeReason, ns.db.targetLevelDiff, st.landed * 100, st.crit * 100))
    for _, slot in ipairs(SLOTS) do
        local sr = res.slots[slot]
        if sr and sr.best then
            local h = st.hands[slot]
            local parts = {}
            for _, row in ipairs(ns.Calc.SortedScores(res, sr)) do
                parts[#parts + 1] = ("%s %s"):format(ns.IMBUES[row.key].short,
                    sr.unit == "dps" and ("%.1f"):format(row.value) or ("p%.0f"):format(row.value))
            end
            local weapon = h and ("%.2fs%s"):format(h.baseSpeed, (slot == 16 and st.twoHand) and " 2H" or "") or "-"
            ns.Print(("%s (%s): %s%s|r   [%s%s]"):format(SLOT_SHORT[slot], weapon, Hex(GREEN),
                res.imbues[sr.best].name, table.concat(parts, ", "), sr.unit == "dps" and " dps" or ""))
            local key, picked = ns.UseKey(res, slot)
            if picked then
                ns.Print(("   your pick for the %s: %s%s|r  (/imbue advisor goes back)"):format(
                    SLOT_LOWER[slot], Hex(COLOR_PICK), res.imbues[key].name))
            end
        end
    end
    local fallback = {}
    for key, info in pairs(res.imbues) do
        if not info.params.parsed then fallback[#fallback + 1] = info.name end
    end
    if #fallback > 0 then
        ns.Print(Hex(ORANGE) .. "couldn't read the tooltip of " .. table.concat(fallback, ", ") ..
            "; using estimated numbers. /imbue debug shows the text.|r")
    end
    if not st.mhWeapon then ns.Print("no main-hand weapon equipped.") end
end

-- LookShots (a screenshot helper on the developer's machine only) takes one picture of each
-- frame listed here the first time it shows. Nothing happens when it is not installed.
LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["ImbueAdvisor"] = {
    version = ns.VERSION,
    frames = {
        { label = "hand buttons", frame = function() return UI.frame end },
        -- the open list, with enough room around it to show the hand buttons above or below it
        { label = "list of other imbues", pad = 56,
          frame = function() return UI.frame and UI.frame.list:IsShown() and UI.frame.list or nil end },
    },
}

function UI.PrintDebug()
    local res = ns.result
    if not res then ns.Print("nothing calculated yet.") return end
    for _, key in ipairs(ns.IMBUE_ORDER) do
        local info = res.imbues[key]
        if info then
            local kv = {}
            for k, v in pairs(info.params) do kv[#kv + 1] = k .. "=" .. tostring(v) end
            table.sort(kv)
            ns.Print(("%s (id %d): %s"):format(info.name, info.spellID, table.concat(kv, " ")))
            ns.Print("   tooltip: " .. tostring(info.desc))
        else
            ns.Print(ns.IMBUES[key].english .. ": not known")
        end
    end
    ns.Print(("current: MH=%s OH=%s pick: MH=%s OH=%s"):format(tostring(ns.current[16]), tostring(ns.current[17]),
        tostring(ns.Pick(16)), tostring(ns.Pick(17))))
end
