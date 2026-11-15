-- Totem Council: the totem bar. A copy of the game's own totem bar
-- (MultiCastActionBarFrame): four 30 x 30 buttons, earth, fire, water, air,
-- 8 apart, each with its element ring. The time left sits under each button
-- like a buff's. State is shown the way the default UI shows it: a totem that
-- is not down is a grey icon, one about to run out fades like a buff running
-- out, a clash with another shaman is one red dot plus the tooltip.
local ADDON, ns = ...

local HUD = {}
ns.HUD = HUD

local SIZE, GAP = ns.TOTEM_BUTTON, ns.TOTEM_GAP

local C = ns.COLOR
local RED, ORANGE, YELLOW = C.red, C.orange, C.yellow
local GRAY = C.gray

local function UseKeyDown()
    local ok, v
    if C_CVar and C_CVar.GetCVarBool then
        ok, v = pcall(C_CVar.GetCVarBool, "ActionButtonUseKeyDown")
    elseif GetCVarBool then
        ok, v = pcall(GetCVarBool, "ActionButtonUseKeyDown")
    end
    return ok and v
end

HUD.FormatTime = ns.FormatTime

local function JoinNames(list)
    return table.concat(list, ", ")
end

----------------------------------------------------------------------
-- Tooltip
----------------------------------------------------------------------
local function OnEnter(self)
    HUD.frame.hover = true
    local slot = self.slot
    local el = ns.ELEMENTS[slot]
    local st = ns.SlotStatus(slot)
    local a = st.active
    local planInfo = st.plan and ns.Info(st.plan)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(el.name .. " totem")      -- gold, like every game tooltip title
    if a then
        GameTooltip:AddDoubleLine(a.name or "Unknown totem", ns.FormatTime(st.remaining or 0), 1, 1, 1, 1, 1, 1)
    else
        GameTooltip:AddLine("No totem down", GRAY[1], GRAY[2], GRAY[3])
    end
    if planInfo then
        if st.state == "missing" then
            GameTooltip:AddLine("Missing: " .. planInfo.name, RED[1], RED[2], RED[3])
        elseif st.state == "offplan" then
            GameTooltip:AddLine("Your plan here is " .. planInfo.name, YELLOW[1], YELLOW[2], YELLOW[3])
        end
    else
        GameTooltip:AddLine("Nothing planned: right-click to pick one", GRAY[1], GRAY[2], GRAY[3])
    end
    if st.overlap then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Doubled up: " .. JoinNames(st.overlap) .. " has the same totem down.", ORANGE[1], ORANGE[2], ORANGE[3], true)
    end
    if st.conflict then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Same plan as " .. JoinNames(st.conflict) .. ". Open the group plan (/totems plan) to sort it out.", ORANGE[1], ORANGE[2], ORANGE[3], true)
    end
    GameTooltip:AddLine(" ")
    -- say what the click really does: in combat the button keeps the totem it
    -- had when the fight started
    local bound = self:GetAttribute("type1") == "spell" and self:GetAttribute("spell1") or nil
    local known = ns.db.clickCast and st.plan and ns.Known(st.plan) or nil
    local want = known and known.name or nil
    if bound then GameTooltip:AddLine("Left-click: drop " .. bound, 1, 1, 1) end
    if bound ~= want and InCombatLockdown() then
        GameTooltip:AddLine(want and ("Left-click changes to " .. want .. " after combat") or "Left-click turns off after combat",
            ORANGE[1], ORANGE[2], ORANGE[3], true)
    end
    GameTooltip:AddLine("Right-click: choose the totem to keep up", 1, 1, 1)
    if not ns.db.locked then GameTooltip:AddLine("Drag: move the bar (/totems lock)", GRAY[1], GRAY[2], GRAY[3]) end
    GameTooltip:Show()
end

local function OnLeave()
    HUD.frame.hover = false
    GameTooltip:Hide()
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
function HUD.SavePosition()
    local point, _, relPoint, x, y = HUD.frame:GetPoint()
    ns.db.point = { point, relPoint, x, y }
end

function HUD.RestorePosition()
    local f, p = HUD.frame, ns.db.point
    if not f then return end
    f:ClearAllPoints()
    if p then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    end
end

local function StartMove()
    local f = HUD.frame
    if not ns.db.locked and not InCombatLockdown() then
        f:StartMoving()
        f.moving = true
    end
end

local function StopMove()
    local f = HUD.frame
    if f.moving then
        f:StopMovingOrSizing()
        f.moving = nil
        HUD.SavePosition()
    end
end

local function CreateButton(f, slot, index)
    local b = CreateFrame("Button", "TotemCouncilButton" .. slot, f, "SecureActionButtonTemplate")
    b.slot = slot
    ns.TotemButtonArt(b, slot)
    b:SetPoint("LEFT", f, "LEFT", (index - 1) * (SIZE + GAP), 0)
    if UseKeyDown() then b:RegisterForClicks("AnyDown", "AnyUp") else b:RegisterForClicks("AnyUp") end
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", StartMove)
    b:SetScript("OnDragStop", StopMove)
    if b.cd.SetReverse then b.cd:SetReverse(true) end   -- fills up as the totem runs down, like the TotemFrame

    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)
    b:SetScript("PostClick", function(self, button, down)
        if down then return end
        if button == "RightButton" then
            -- a second right-click on the same icon closes the menu again
            local me = ns.Group.members[ns.playerName]
            if me then ns.Menu.OpenTotems(self, me, self.slot) end
        else
            ns.Menu.Close()
        end
    end)
    return b
end

function HUD.Create()
    if HUD.frame or not ns.isShaman then return end
    local f = CreateFrame("Frame", "TotemCouncilHUD", UIParent)
    HUD.frame = f
    f:SetSize(4 * SIZE + 3 * GAP, SIZE)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)

    f.buttons = {}
    for index, slot in ipairs(ns.SLOT_ORDER) do
        f.buttons[slot] = CreateButton(f, slot, index)
    end

    HUD.RestorePosition()
    HUD.ApplySecure()   -- decides shown or hidden (after combat, if the UI was reloaded mid-fight)
end

-- Visibility, scale, mouse and click actions. The game blocks these in
-- combat, so they wait for combat to end.
function HUD.ApplySecure()
    local f = HUD.frame
    if not f then return end
    if InCombatLockdown() then
        HUD.pending = true
        return
    end
    HUD.pending = false
    f:SetScale(ns.db.scale or 1)
    for _, slot in ipairs(ns.SLOT_ORDER) do
        local b = f.buttons[slot]
        local known = ns.db.clickCast and ns.Known(ns.cdb.plan[slot]) or nil
        if known then
            b:SetAttribute("type1", "spell")
            b:SetAttribute("spell1", known.name)
        else
            b:SetAttribute("type1", nil)
            b:SetAttribute("spell1", nil)
        end
        b:EnableMouse(not ns.db.clickThrough)
    end
    if ns.db.shown then f:Show() else f:Hide() end
end

----------------------------------------------------------------------
-- Drawing (runs ten times a second; nothing here is blocked in combat)
----------------------------------------------------------------------
-- b.state is the one state the button shows, most urgent first; tests read it:
--   "warn"     planned totem not down while it matters (grey icon, sound)
--   "overlap"  another shaman has the same totem down (red dot)
--   "expiring" a kept-up totem in its last seconds in combat (buff fade)
--   "conflict" another shaman plans the same totem (red dot)
--   "offplan"  a different totem than planned is down (tooltip only)
function HUD.Update()
    local f = HUD.frame
    if not f or not f:IsShown() then return end
    if HUD.pending and not InCombatLockdown() then HUD.ApplySecure() end
    local now = GetTime()
    local attention = false
    local soon = ns.db.soonSeconds or 10

    for _, slot in ipairs(ns.SLOT_ORDER) do
        local b = f.buttons[slot]
        local st = ns.SlotStatus(slot)
        local a = st.active
        local planInfo = st.plan and ns.Info(st.plan)

        -- icon: the totem that is down, else the planned one in grey, else
        -- the element's empty slot
        local icon = (a and a.icon) or (planInfo and planInfo.icon) or nil
        if b.shownIcon ~= icon then
            b.icon:SetTexture(icon)
            b.shownIcon = icon
        end
        if icon then b.icon:Show() else b.icon:Hide() end
        b.icon:SetDesaturated(a == nil)

        -- sweep
        if b.cdEntry ~= a then
            b.cdEntry = a
            if a then
                b.cd:SetCooldown(a.start, a.duration)
                b.cd:Show()
            else
                b.cd:Hide()
            end
        end

        -- time left, under the button like a buff's
        ns.SetDuration(b, a and (st.remaining or 0) or nil)

        local state
        if st.warn then
            state = "warn"
        elseif st.overlap then
            state = "overlap"
        elseif a and ns.inCombat and not st.temp and (a.duration or 0) > 15 and (st.remaining or 0) <= soon then
            -- temporary totems are not there to be refreshed, and short ones
            -- (Fire Nova, Mana Tide, Stoneclaw) would fade their whole life
            state = "expiring"
        elseif st.conflict then
            state = "conflict"
        elseif st.state == "offplan" then
            state = "offplan"
        end
        b.state = state
        if state == "warn" or state == "overlap" then attention = true end

        -- the one marker: a clash with another shaman, now or in the plans
        local clash = (st.overlap or st.conflict) and true or false
        if b.clash ~= clash then
            b.marker:SetShown(clash)
            b.clash = clash
        end

        -- running out: the buff fade, on the whole button as the buff bar does
        local alpha = (state == "expiring") and ns.WarningAlpha(now) or 1
        if b.shownAlpha ~= alpha then
            b:SetAlpha(alpha)
            b.shownAlpha = alpha
        end
    end

    local alpha = (attention or ns.inCombat or f.hover) and 1 or (ns.db.idleAlpha or 0.55)
    if f.shownAlpha ~= alpha then
        f:SetAlpha(alpha)
        f.shownAlpha = alpha
    end
end
