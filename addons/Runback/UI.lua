-- Runback: what is on screen.
--   * The readout is a game tooltip (GameTooltipTemplate): gold graveyard name, then a line
--     for you and one for enemy players with the distance and the run back.
--   * The timers are the game's own timer bars, the ones it shows for breath and fatigue
--     (MirrorTimerTemplate in Blizzard_MirrorTimer/Mainline/MirrorTimer.xml, branch forever):
--     206 x 32, a 195 x 13 bar 2 under the top, the same four atlases and layers, the text
--     in GameFontHighlightSmall in the box under the bar, bars stacked with no gap. The
--     template itself is not inherited: its scripts belong to the game's three timers.
-- Both hang off one invisible anchor, top centre under the game's own timer bars. Drag
-- either to move both.
--   * Minimize: a 16 x 16 button at the right of the stack, the game's own tracker header
--     button (ObjectiveTrackerModuleMinimizeButtonTemplate in Blizzard_ObjectiveTracker/
--     Blizzard_ObjectiveTrackerModule.xml, branch forever): atlases
--     ui-questtrackerbutton-secondary-collapse / -expand (and -pressed), highlight
--     ui-questtrackerbutton-yellow-highlight (ADD). Minimized, the bars are hidden and the
--     readout shrinks to one tooltip line: "Runback" and the soonest countdown.
local ADDON_NAME, ns = ...
local UI = {}
ns.UI = UI

local MAX_BARS = 8
local BAR_W, BAR_H = 206, 32
local FILL_W, FILL_H = 195, 13
local DEFAULT_Y = -200          -- the game's own bars start at -100 and are 32 each

local anchor, tip, mover, toggle
local bars = {}
local shownTip = false
local lastReadout = -10
local barsWanted = 0      -- timers that have a bar (shown, or hidden while minimized)

local function Color(c, r, g, b)
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return r, g, b
end

local function Atlas(texture, name)
    if not (texture.SetAtlas and pcall(texture.SetAtlas, texture, name)) then return false end
    return true
end

---------------------------------------------------------------------------
-- Place
---------------------------------------------------------------------------
function UI.Place()
    if not anchor then return end
    anchor:ClearAllPoints()
    local pos = ns.db and ns.db.pos
    if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
        anchor:SetPoint("TOP", UIParent, "BOTTOMLEFT", pos.x, pos.y)
    else
        anchor:SetPoint("TOP", UIParent, "TOP", 0, DEFAULT_Y)
    end
end

local function StartMove()
    if ns.db.locked then return end
    anchor:StartMoving()
end

local function StopMove()
    anchor:StopMovingOrSizing()
    local x, top = anchor:GetCenter(), anchor:GetTop()
    if type(x) == "number" and type(top) == "number" then
        ns.db.pos = { x = math.floor(x + 0.5), y = math.floor(top + 0.5) }
    end
    UI.Place()
end

local function Draggable(frame)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
end

---------------------------------------------------------------------------
-- The readout
---------------------------------------------------------------------------
local function WantReadout()
    local db = ns.db
    if not ns.Active() or db.readout == "never" then return false end
    if db.readout == "always" then return true end
    local ok, dead = pcall(UnitIsDeadOrGhost, "player")
    if ok and not (issecretvalue and issecretvalue(dead)) and dead then return true end
    local ok2, pvp = pcall(UnitIsPVP, "player")
    return (ok2 and not (issecretvalue and issecretvalue(pvp)) and pvp) and true or false
end

local function Eligible(t)
    return t.kind ~= "self" or ns.db.own
end

local function EligibleCount()
    local n = 0
    for _, t in ipairs(ns.timers) do
        if n >= MAX_BARS then break end
        if Eligible(t) then n = n + 1 end
    end
    return n
end

-- The minimized readout: one tooltip line, the name and the soonest countdown.
local function Summary(s, now)
    local best
    for _, t in ipairs(ns.timers) do
        if Eligible(t) and t.backAt and not t.doneAt then
            local left = math.max(0, t.backAt - now)
            if not best or left < best then best = left end
        end
    end
    local right = ""
    if best then
        right = ns.Clock(best)
    elseif s and s.mine then
        right = ns.Clock(s.mine.secs)
    elseif barsWanted > 0 then
        right = barsWanted .. (barsWanted == 1 and " timer" or " timers")
    end
    local gr, gg, gb = Color(NORMAL_FONT_COLOR, 1, 0.82, 0)
    local wr, wg, wb = Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
    if tip:GetOwner() ~= anchor then tip:SetOwner(anchor, "ANCHOR_NONE") end
    tip:ClearLines()
    tip:AddDoubleLine("Runback", right, gr, gg, gb, wr, wg, wb)
    tip:ClearAllPoints()
    tip:SetPoint("TOP", anchor, "TOP", 0, 0)
    tip:Show()
    shownTip = true
end

local function Readout()
    if not tip then return end
    local s = WantReadout() and ns.Survey()
    barsWanted = EligibleCount()
    if ns.db.minimized then
        if (s and s.place) or barsWanted > 0 then
            Summary(s, GetTime())
        else
            if shownTip then tip:Hide() end
            shownTip = false
        end
        return
    end
    if not (s and s.place) then
        if shownTip then tip:Hide() end
        shownTip = false
        return
    end
    local gr, gg, gb = Color(NORMAL_FONT_COLOR, 1, 0.82, 0)
    local wr, wg, wb = Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
    local dr, dg, db_ = Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
    if tip:GetOwner() ~= anchor then tip:SetOwner(anchor, "ANCHOR_NONE") end
    tip:ClearLines()
    local function Row(who, e)
        tip:AddDoubleLine(who, math.floor(e.yard.dist + 0.5) .. " yd    " .. ns.Clock(e.secs), wr, wg, wb, wr, wg, wb)
    end
    local enemy = (FACTION_HORDE and FACTION_ALLIANCE and UnitFactionGroup and UnitFactionGroup("player") == "Alliance")
        and FACTION_HORDE or FACTION_ALLIANCE or "Enemy"
    if s.mine then
        tip:AddLine(s.mine.yard.name, gr, gg, gb)
        Row("You", s.mine)
    else
        tip:AddLine("Graveyard", gr, gg, gb)
        tip:AddLine("None known here yet for you.", dr, dg, db_)
    end
    if s.theirs then
        local same = s.mine and s.mine.yard.inst == s.theirs.yard.inst
            and math.abs(s.mine.yard.x - s.theirs.yard.x) < 1 and math.abs(s.mine.yard.y - s.theirs.yard.y) < 1
        if not same then tip:AddLine(s.theirs.yard.name, gr, gg, gb) end
        Row(enemy, s.theirs)
    else
        tip:AddLine(enemy .. ": none known here yet.", dr, dg, db_)
    end
    if s.place.entrance then tip:AddLine("To the way in of " .. s.place.entrance .. ".", dr, dg, db_) end
    tip:ClearAllPoints()
    tip:SetPoint("TOP", anchor, "TOP", 0, 0)
    tip:Show()
    shownTip = true
end

---------------------------------------------------------------------------
-- The bars
---------------------------------------------------------------------------
local function BarTooltip(bar)
    local t = bar.timer
    if not (t and GameTooltip) then return end
    local _, _, lines = ns.BarInfo(t, GetTime())
    GameTooltip:SetOwner(bar, "ANCHOR_BOTTOM")
    local cr, cg, cb = Color(NORMAL_FONT_COLOR, 1, 0.82, 0)
    local class = t.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[t.class]
    if class then cr, cg, cb = class.r, class.g, class.b end
    GameTooltip:AddLine(t.name, cr, cg, cb)
    local wr, wg, wb = Color(HIGHLIGHT_FONT_COLOR, 1, 1, 1)
    for _, line in ipairs(lines) do GameTooltip:AddLine(line, wr, wg, wb, true) end
    local dr, dg, db_ = Color(GRAY_FONT_COLOR, 0.5, 0.5, 0.5)
    GameTooltip:AddLine("Right-click to dismiss. Drag to move.", dr, dg, db_)
    GameTooltip:Show()
end

local function NewBar(i)
    local bar = CreateFrame("Button", "RunbackBar" .. i, anchor)
    bar:SetSize(BAR_W, BAR_H)
    bar:Hide()

    local fill = CreateFrame("StatusBar", nil, bar)
    fill:SetSize(FILL_W, FILL_H)
    fill:SetPoint("TOP", 0, -2)
    fill:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
    if not pcall(fill.SetStatusBarTexture, fill, "ui-castingbar-filling-standard") or not fill:GetStatusBarTexture() then
        fill:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    end
    fill:SetMinMaxValues(0, 1)
    fill:SetValue(1)
    bar.StatusBar = fill

    local box = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    Atlas(box, "ui-castingbar-textbox")
    box:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, -14)
    bar.TextBorder = box

    local back = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
    Atlas(back, "ui-castingbar-background")
    back:SetPoint("TOPLEFT", fill, "TOPLEFT", -1, 1)
    back:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 1, -1)

    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetPoint("TOPLEFT", fill, "BOTTOMLEFT", 0, 0)
    text:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 2)
    bar.Text = text

    local border = bar:CreateTexture(nil, "OVERLAY")
    Atlas(border, "ui-castingbar-frame")
    border:SetPoint("TOPLEFT", fill, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 2, -2)

    Draggable(bar)
    bar:RegisterForClicks("RightButtonUp")
    bar:SetScript("OnClick", function(self)
        local t = self.timer
        if not t then return end
        for n, other in ipairs(ns.timers) do
            if other == t then
                table.remove(ns.timers, n)
                break
            end
        end
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        UI.Refresh()
    end)
    bar:SetScript("OnEnter", BarTooltip)
    bar:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    bars[i] = bar
    return bar
end

local function Paint(now)
    for _, bar in ipairs(bars) do
        local t = bar.timer
        if t and bar:IsShown() then
            local text, value = ns.BarInfo(t, now)
            bar.StatusBar:SetValue(value)
            bar.Text:SetText(text)
        end
    end
end

---------------------------------------------------------------------------
-- The minimize button
---------------------------------------------------------------------------
local function ToggleLook()
    local what = ns.db.minimized and "expand" or "collapse"
    pcall(toggle.SetNormalAtlas, toggle, "ui-questtrackerbutton-secondary-" .. what)
    pcall(toggle.SetPushedAtlas, toggle, "ui-questtrackerbutton-secondary-" .. what .. "-pressed")
end

-- At the right of whatever is on top: the readout, or the first bar. Not there when there
-- is nothing to minimize or to bring back.
function UI.PlaceToggle()
    if not toggle then return end
    local target
    if shownTip then
        target = tip
    elseif not ns.db.minimized and bars[1] and bars[1]:IsShown() then
        target = bars[1]
    end
    if not target then
        toggle:Hide()
        return
    end
    ToggleLook()
    toggle:ClearAllPoints()
    toggle:SetPoint("TOPLEFT", target, "TOPRIGHT", 2, target == tip and -2 or 0)
    toggle:Show()
end

function UI.SetMinimized(value)
    if not ns.db then return end
    ns.Set("minimized", value and true or false)
end

-- Which timer sits in which bar, and where the first bar hangs.
function UI.Refresh()
    if not anchor then return end
    local minimized = ns.db.minimized
    local n = 0
    for _, t in ipairs(ns.timers) do
        if n >= MAX_BARS then break end
        if Eligible(t) then
            n = n + 1
            if not minimized then
                local bar = bars[n] or NewBar(n)
                bar.timer = t
                bar:ClearAllPoints()
                if n == 1 then
                    if shownTip then
                        bar:SetPoint("TOP", tip, "BOTTOM", 0, -4)
                    else
                        bar:SetPoint("TOP", anchor, "TOP", 0, 0)
                    end
                else
                    bar:SetPoint("TOP", bars[n - 1], "BOTTOM", 0, 0)
                end
                bar:Show()
            end
        end
    end
    for i = minimized and 1 or n + 1, #bars do
        bars[i].timer = nil
        bars[i]:Hide()
    end
    barsWanted = n
    if minimized and tip then
        -- the readout is the one line: it comes and goes with the timers
        local ok, err = pcall(Readout)
        if not ok then ns.lastError = err end
    end
    UI.PlaceToggle()
    Paint(GetTime())
end

-- From Core's tick: the readout twice a second, and the bars follow it when it comes or goes.
function UI.Update(now)
    if not anchor then return end
    if now - lastReadout >= 0.5 then
        lastReadout = now
        local was = shownTip
        local ok, err = pcall(Readout)
        if not ok then ns.lastError = err end
        if was ~= shownTip then UI.Refresh() end
    end
    Paint(now)
end

function UI.Init()
    if anchor then
        UI.Place()
        return
    end
    anchor = CreateFrame("Frame", "RunbackAnchor", UIParent)
    anchor:SetSize(BAR_W, 1)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    UI.Place()

    local ok, made = pcall(CreateFrame, "GameTooltip", "RunbackReadout", UIParent, "GameTooltipTemplate")
    if ok and made then
        tip = made
        tip:SetFrameStrata("LOW")            -- under the game's windows, not over them like a real tooltip
        tip:SetOwner(anchor, "ANCHOR_NONE")
        tip:Hide()
        -- a tooltip takes no mouse: a clear frame over it carries the drag
        mover = CreateFrame("Frame", nil, anchor)
        mover:SetAllPoints(tip)
        Draggable(mover)
        mover:SetScript("OnUpdate", function(self)
            local over = shownTip and not ns.db.locked
            if self.over ~= over then
                self.over = over
                self:EnableMouse(over)
            end
        end)
    end

    toggle = CreateFrame("Button", "RunbackMinimizeButton", anchor)
    toggle:SetSize(16, 16)
    toggle:SetFrameLevel(anchor:GetFrameLevel() + 5)
    toggle:Hide()
    pcall(toggle.SetHighlightAtlas, toggle, "ui-questtrackerbutton-yellow-highlight", "ADD")
    toggle:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        UI.SetMinimized(not ns.db.minimized)
    end)

    -- between Core's ticks the bars keep moving
    local since = 0
    anchor:SetScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < 0.05 then return end
        since = 0
        if bars[1] and bars[1]:IsShown() then Paint(GetTime()) end
    end)
    UI.Refresh()
end

function UI.Describe()
    local n = 0
    for _, bar in ipairs(bars) do
        if bar:IsShown() then n = n + 1 end
    end
    return (anchor and "ready" or "not built") .. (ns.db and ns.db.minimized and ", minimized" or "") .. ", readout " .. (shownTip and "shown" or "hidden") .. ", bars " .. n
end

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(get, ADDON_NAME, "Version")
    return (ok and type(v) == "string") and v or "?"
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets[ADDON_NAME] = {
    version = Version(),
    frames = {
        { label = "readout", frame = function() return shownTip and tip or nil end },
        { label = "minimize button", frame = function() return toggle and toggle:IsShown() and toggle or nil end, pad = 40 },
        { label = "timer bars", frame = function() return bars[1] and bars[1]:IsShown() and bars[1] or nil end, pad = 80 },
    },
}
