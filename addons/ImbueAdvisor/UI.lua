-- Imbue Advisor: the on-screen frame (one click-to-cast button per weapon hand, and under it
-- a list of every imbue you know for when you want another one)
local _, ns = ...
local UI = {}
ns.UI = UI

local max = math.max
local SLOTS = { 16, 17 }
local SLOT_NAME = { [16] = "Main hand", [17] = "Off hand" }
local SLOT_LOWER = { [16] = "main hand", [17] = "off hand" }
local SLOT_SHORT = { [16] = "MH", [17] = "OH" }
local MODE_LABEL = { melee = "Melee", tank = "Tank", caster = "Caster", heal = "Healer", pvp = "PvP" }

local COLOR_OK = { 0.2, 0.9, 0.2 }       -- the imbue the button casts is on (also: the advisor's pick in the list)
local COLOR_WRONG = { 1.0, 0.8, 0.1 }    -- a different imbue is on
local COLOR_MISSING = { 1.0, 0.15, 0.15 } -- nothing on the weapon
local COLOR_PICK = { 0.35, 0.7, 1.0 }    -- an imbue you chose yourself
local COLOR_PLAIN = { 0.22, 0.22, 0.24 } -- any other imbue in the list

local BTN, GAP, PAD = 36, 8, 8
local ABTN, AGAP = 28, 5                 -- the buttons in the list
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

local function FormatTime(sec)
    if sec >= 60 then return ("%dm"):format(math.ceil(sec / 60)) end
    return ("%ds"):format(math.floor(sec))
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
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Imbue Advisor: " .. SLOT_NAME[slot])
    if self.use and self.picked then
        GameTooltip:AddDoubleLine("Your pick", self.use.name, 1, 1, 1, COLOR_PICK[1], COLOR_PICK[2], COLOR_PICK[3])
        if self.rec then GameTooltip:AddDoubleLine("Advisor's pick", self.rec.name, 1, 1, 1, 0.3, 1, 0.3) end
    elseif self.use then
        GameTooltip:AddDoubleLine("Use", self.use.name, 1, 1, 1, 0.3, 1, 0.3)
    end
    local e = ns.WeaponEnchants()[slot]
    local cur = ImbueName(ns.current[slot]) or (e.has and "something else" or "none")
    GameTooltip:AddDoubleLine("On weapon now", cur, 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine(" ")
    for _, row in ipairs(ns.Calc.SortedScores(res, sr)) do
        local r, g, b = 0.8, 0.8, 0.8
        if row.key == sr.best then
            r, g, b = 0.3, 1, 0.3
        elseif self.picked and self.use and row.key == self.use.key then
            r, g, b = COLOR_PICK[1], COLOR_PICK[2], COLOR_PICK[3]
        end
        GameTooltip:AddDoubleLine(row.name, ScoreText(sr, row), r, g, b, r, g, b)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(("Mode: %s (%s)"):format(MODE_LABEL[res.mode] or res.mode, res.modeReason), 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Left-click: apply   Right-click: report in chat", 0.5, 0.8, 1)
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
    GameTooltip:AddLine(info.name)
    if sr and sr.scores[info.key] then
        GameTooltip:AddLine(SLOT_NAME[slot] .. ": " .. ScoreText(sr, { key = info.key, value = sr.scores[info.key] }), 0.8, 0.8, 0.8)
    end
    if isBest then GameTooltip:AddLine("The advisor's pick", 0.3, 1, 0.3) end
    if inUse and main.picked then GameTooltip:AddLine("Your pick", COLOR_PICK[1], COLOR_PICK[2], COLOR_PICK[3]) end
    local hint
    if inUse then
        hint = "Click: put it on your " .. SLOT_LOWER[slot]
    elseif isBest then
        hint = "Click: put it on your " .. SLOT_LOWER[slot] .. " and go back to the advisor's pick"
    else
        hint = "Click: put it on your " .. SLOT_LOWER[slot] .. " and keep using it there"
    end
    GameTooltip:AddLine(hint, 0.5, 0.8, 1, true)
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

local function Backdrop(frame)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.6)
    frame:SetBackdropBorderColor(0.25, 0.45, 0.9, 0.9)
end

local function NewCastButton(name, parent, size)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(size, size)
    if UseKeyDown() then b:RegisterForClicks("AnyDown", "AnyUp") else b:RegisterForClicks("AnyUp") end

    b.border = b:CreateTexture(nil, "BACKGROUND")
    b.border:SetPoint("TOPLEFT", -2, 2)
    b.border:SetPoint("BOTTOMRIGHT", 2, -2)
    b.border:SetColorTexture(unpack(COLOR_MISSING))

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints()
    b.hl:SetColorTexture(1, 1, 1, 0.15)
    return b
end

-- Is the mouse on the frame or on the open list (with a little room around them)?
local function MouseIsNear(f)
    if f:IsMouseOver(4, -4, -4, 4) then return true end
    return f.list:IsShown() and f.list:IsMouseOver(6, -6, -4, 4) or false
end

-- Opens the list while the mouse is on the frame and closes it shortly after it leaves.
-- Nothing may be shown or hidden in a fight, so it only runs between fights.
local tick, away = 0, 0
local function HoverUpdate(self, elapsed)
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
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "ImbueAdvisorFrame", UIParent, template)
    UI.frame = f
    f:SetSize(PAD * 2 + BTN * 2 + GAP, BTN + 26)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", StartMove)
    f:SetScript("OnDragStop", StopMove)
    Backdrop(f)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.title:SetPoint("TOP", f, "TOP", 0, -6)

    -- The list of every imbue, best first, one column under each hand's button
    local list = CreateFrame("Frame", "ImbueAdvisorList", f, template)
    f.list = list
    list:SetFrameStrata("MEDIUM")
    list:EnableMouse(true)
    Backdrop(list)
    list:Hide()
    list.rows = 0

    f.buttons, f.alts = {}, {}
    for _, slot in ipairs(SLOTS) do
        local b = NewCastButton("ImbueAdvisorButton" .. slot, f, BTN)
        b.slot = slot
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnDragStart", StartMove)
        b:SetScript("OnDragStop", StopMove)

        b.label = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.label:SetPoint("TOPLEFT", 2, -2)
        b.label:SetText(SLOT_SHORT[slot])

        b.timer = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        b.timer:SetPoint("BOTTOM", 0, 2)

        -- a small blue corner: this hand uses an imbue you chose yourself
        b.pinEdge = b:CreateTexture(nil, "OVERLAY")
        b.pinEdge:SetSize(10, 10)
        b.pinEdge:SetPoint("TOPRIGHT", 2, 2)
        b.pinEdge:SetColorTexture(0, 0, 0, 1)
        b.pin = b:CreateTexture(nil, "OVERLAY", nil, 1)
        b.pin:SetSize(8, 8)
        b.pin:SetPoint("TOPRIGHT", 1, 1)
        b.pin:SetColorTexture(COLOR_PICK[1], COLOR_PICK[2], COLOR_PICK[3], 1)
        b.pinEdge:Hide()
        b.pin:Hide()

        b:SetScript("OnEnter", OnEnter)
        b:SetScript("OnLeave", OnLeave)
        b:SetScript("PostClick", function(_, button, down)
            if button == "RightButton" and not down then UI.PrintReport() end
        end)
        b:Hide()
        f.buttons[slot] = b

        f.alts[slot] = {}
        for i = 1, MAX_ALTS do
            local a = NewCastButton("ImbueAdvisorAlt" .. slot .. "_" .. i, list, ABTN)
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
    f.title:SetText(MODE_LABEL[res.mode] or res.mode)
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
        if b.picked then b.pin:Show(); b.pinEdge:Show() else b.pin:Hide(); b.pinEdge:Hide() end
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
    local width = max(76, PAD * 2 + n * BTN + max(0, n - 1) * GAP)
    f:SetWidth(width)
    local x0 = (width - (n * BTN + max(0, n - 1) * GAP)) / 2
    for i, slot in ipairs(shownSlots) do
        local b = f.buttons[slot]
        b.x = x0 + (i - 1) * (BTN + GAP)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", b.x, -20)
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
                local col = COLOR_PLAIN
                if row.key == sr.best then
                    col = COLOR_OK
                elseif row.key == b.use.key then
                    col = COLOR_PICK
                end
                a.border:SetColorTexture(col[1], col[2], col[3], 1)
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
        f.list:SetHeight(PAD * 2 + rowsMax * ABTN + (rowsMax - 1) * AGAP)
    end
    UI.PlaceList()

    local others = ns.db.others
    if others == "always" then
        UI.ShowList(true)
    elseif others ~= "hover" or rowsMax == 0 or not f:IsShown() then
        UI.ShowList(false)
    end
end

-- Under the frame, or above it when there is no room underneath. Best imbue next to the frame.
function UI.PlaceList()
    local f = UI.frame
    if not f or InCombatLockdown() then return end
    local list = f.list
    local up = false
    local bottom = f:GetBottom()
    if bottom and list.rows > 0 and bottom < list:GetHeight() + 4 then up = true end
    list.up = up
    list:ClearAllPoints()
    if up then
        list:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, -2)
        list:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, -2)
    else
        list:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 2)
        list:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, 2)
    end
    for _, slot in ipairs(SLOTS) do
        local b = f.buttons[slot]
        for _, a in ipairs(f.alts[slot]) do
            if a.info and b.x then
                local x = b.x + (BTN - ABTN) / 2
                local y = PAD + (a.index - 1) * (ABTN + AGAP)
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

-- Border colours and timers (runs every second, safe in combat)
function UI.UpdateStatus()
    local f = UI.frame
    if not f or not f:IsShown() then return end
    local ench = ns.WeaponEnchants()
    for _, slot in ipairs(SLOTS) do
        local b = f.buttons[slot]
        if b:IsShown() and b.use then
            local e = ench[slot]
            local col
            if not e.has then
                col = COLOR_MISSING
            elseif ns.current[slot] == b.use.key then
                col = COLOR_OK
            else
                col = COLOR_WRONG
            end
            b.border:SetColorTexture(col[1], col[2], col[3], 1)
            if e.has and e.exp then
                b.timer:SetText(FormatTime(e.exp))
            else
                b.timer:SetText(e.has and "" or "|cffff4040none|r")
            end
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
            ns.Print(("%s (%s): |cff40ff40%s|r   [%s%s]"):format(SLOT_SHORT[slot], weapon,
                res.imbues[sr.best].name, table.concat(parts, ", "), sr.unit == "dps" and " dps" or ""))
            local key, picked = ns.UseKey(res, slot)
            if picked then
                ns.Print(("   your pick for the %s: |cff59b3ff%s|r  (/imbue advisor goes back)"):format(
                    SLOT_LOWER[slot], res.imbues[key].name))
            end
        end
    end
    local fallback = {}
    for key, info in pairs(res.imbues) do
        if not info.params.parsed then fallback[#fallback + 1] = info.name end
    end
    if #fallback > 0 then
        ns.Print("|cffffaa00couldn't read the tooltip of " .. table.concat(fallback, ", ") ..
            "; using estimated numbers. /imbue debug shows the text.|r")
    end
    if not st.mhWeapon then ns.Print("no main-hand weapon equipped.") end
end

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
