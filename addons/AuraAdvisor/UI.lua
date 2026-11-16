-- Aura Advisor: the advice, shown in the game's own UI. There is no bar or frame of its own.
--
-- * The aura to switch to gets the game's spell-alert glow (ActionButtonSpellAlertTemplate,
--   Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.xml) on its button on the game's stance
--   bar, and on any action bar button that holds that aura, the way the game marks a proc.
-- * An aura's tooltip (stance bar, action bar, spell) gets a two-word line under it, and the
--   aura to switch to its short cause.
--
-- The glow frames are our own, made and run the way ActionButtonSpellAlertManager makes and
-- runs its own (1.4 x the button, centred), but not through the manager: none of the game's
-- tables ever holds anything of ours, and nothing on the game's buttons is changed. A child
-- frame on a button, shown and hidden, is allowed in a fight.
local addonName, ns = ...
local UI = {}
ns.UI = UI

-- LookShots (a screenshot helper on the developer's machine only) takes one game screenshot
-- of each listed frame the first time it shows. Harmless when LookShots is not installed.
-- The options window and minimap button are the shared kit's, which lists them itself.
do
    local version = "?"
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if get then
        local ok, v = pcall(get, addonName or "AuraAdvisor", "Version")
        if ok and type(v) == "string" then version = v end
    end
    LookShotsTargets = type(LookShotsTargets) == "table" and LookShotsTargets or {}
    LookShotsTargets["AuraAdvisor"] = {
        version = version,
        frames = {
            { label = "stance bar glow", frame = function() return UI.shotFrame end, pad = 60 },
        },
    }
end

----------------------------------------------------------------------
-- The game's colours
----------------------------------------------------------------------
local FALLBACK = {
    NORMAL_FONT_COLOR = { 1.0, 0.82, 0.0 },
    HIGHLIGHT_FONT_COLOR = { 1.0, 1.0, 1.0 },
    GREEN_FONT_COLOR = { 0.1, 1.0, 0.1 },
    GRAY_FONT_COLOR = { 0.5, 0.5, 0.5 },
    RED_FONT_COLOR = { 1.0, 0.1, 0.1 },
}

local function RGB(name)
    local c = _G[name]
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    local f = FALLBACK[name]
    return f[1], f[2], f[3]
end

local function Paint(name, text)
    local r, g, b = RGB(name)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5), text)
end
UI.Paint = Paint

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

----------------------------------------------------------------------
-- Which of the game's buttons hold an aura
----------------------------------------------------------------------
-- The game's own action bars, by the names Blizzard_ActionBar/Shared/ActionBar.lua gives them.
local BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
               "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }

-- The spell an action slot holds: the spell itself, or the one a macro casts.
local function SpellOfAction(slot)
    slot = Plain(slot)
    if type(slot) ~= "number" or not GetActionInfo then return nil end
    local ok, kind, id = pcall(GetActionInfo, slot)
    if not ok then return nil end
    kind, id = Plain(kind), Plain(id)
    if kind == "spell" then return id end
    if kind == "macro" and GetMacroSpell then
        local got, spell = pcall(GetMacroSpell, id)
        if got then return Plain(spell) end
    end
end

-- The aura an action slot holds.
local function KeyOfAction(slot)
    local spell = SpellOfAction(slot)
    if spell then return ns.KeyFromSpell(spell) end
end
UI.KeyOfAction = KeyOfAction

local function KeyOfForm(index)
    index = Plain(index)
    for key, info in pairs(ns.known) do
        if info.form == index then return key end
    end
end

-- The stance bar's button first (StanceButton i is stance bar slot i), then the action bars.
local function Targets(key)
    local list = {}
    local info = ns.known[key]
    if not info then return list end
    if info.form then
        local b = _G["StanceButton" .. info.form]
        if type(b) == "table" then list[#list + 1] = b end
    end
    for _, prefix in ipairs(BARS) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if type(b) == "table" and KeyOfAction(b.action) == key then list[#list + 1] = b end
        end
    end
    return list
end
UI.Targets = Targets

-- The action bar buttons for a reminder (Righteous Fury, a blessing). For a blessing, its normal
-- form when one is on your bars, else the Greater one: one spell glows, not two side by side.
local function ReminderTargets(pick)
    local R = ns.Reminders
    local normal, greater = {}, {}
    if not (R and pick) then return normal end
    for _, prefix in ipairs(BARS) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if type(b) == "table" then
                local spell = SpellOfAction(b.action)
                if spell and R.Matches(pick, spell) then
                    local list = R.IsGreater(spell) and greater or normal
                    list[#list + 1] = b
                end
            end
        end
    end
    return #normal > 0 and normal or greater
end
UI.ReminderTargets = ReminderTargets

----------------------------------------------------------------------
-- The glow
----------------------------------------------------------------------
local alerts = {}       -- the game's button -> our glow on it (false: this client can't make one)
UI.alerts = alerts

-- ActionButtonSpellAlertMixin stops the loop when the frame hides (the bar hid, say); start it
-- again when it shows, while the suggestion stands.
local function OnAlertShow(a)
    if a.on and not a.ProcStartAnim:IsPlaying() and not a.ProcLoop:IsPlaying() then a.ProcLoop:Play() end
end

-- 1.4 x the button, as the game sizes its alerts.
local function Fit(a, b)
    local w, h = b:GetSize()
    w, h = Plain(w), Plain(h)
    if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then w, h = 30, 30 end
    a:SetSize(w * 1.4, h * 1.4)
end

-- Built the way ActionButtonSpellAlerts.lua's GetAlertFrame builds it.
local function GlowFrame(b)
    local a = alerts[b]
    if a ~= nil then return a or nil end
    local ok, f = pcall(CreateFrame, "Frame", nil, b, "ActionButtonSpellAlertTemplate")
    if not ok or type(f) ~= "table" or type(f.ProcStartAnim) ~= "table" or type(f.ProcLoop) ~= "table" then
        alerts[b] = false
        return nil
    end
    f.button = b
    Fit(f, b)
    f:SetPoint("CENTER", b, "CENTER", 0, 0)
    f:HookScript("OnShow", OnAlertShow)
    f:Hide()
    alerts[b] = f
    return f
end

-- As ActionButtonSpellAlertManager's ShowAlert / HideAlert.
local function SetGlow(a, on)
    if (a.on and true or false) == on then return end
    a.on = on
    if on then
        -- the bars may have been rescaled since; sized again outside a fight only
        if a.button and not (InCombatLockdown and InCombatLockdown()) then Fit(a, a.button) end
        a:Show()
        a.ProcStartAnim:Play()
    else
        a.ProcStartAnim:Stop()
        a.ProcLoop:Stop()
        a:Hide()
    end
end

-- Which buttons hold what changes with the bars; look again on the next think.
function UI.Refresh()
    UI.dirty = true
    ns.thinkNow = true
end

-- One thing glows at a time (the game marks one thing to do, not three): Righteous Fury when a
-- tank is without it, else the aura to switch to, else a blessing that ran out. One with no
-- button on your bars passes its turn to the next.
local function Candidates(res)
    local order = {}
    if not (ns.db and res) or res.dead then return order, "" end
    local rem = res.reminder
    if rem and rem.kind == "fury" then order[#order + 1] = { rem.id, rem } end
    if ns.db.glow and res.shown then order[#order + 1] = { "aura:" .. res.shown } end
    if rem and rem.kind ~= "fury" then order[#order + 1] = { rem.id, rem } end
    local ids = {}
    for i, c in ipairs(order) do ids[i] = c[1] end
    return order, table.concat(ids, ",")
end

function UI.Update(res)
    local order, sig = Candidates(res)
    if sig == UI.sig and not UI.dirty then return end
    UI.sig, UI.dirty = sig, false
    local id, list = nil, {}
    for _, c in ipairs(order) do
        local found = c[2] and ReminderTargets(c[2]) or Targets(res.shown)
        if #found > 0 then id, list = c[1], found; break end
    end
    UI.glowKey = id
    local want = {}
    for _, b in ipairs(list) do want[b] = true end
    for b, a in pairs(alerts) do
        if a and not want[b] then SetGlow(a, false) end
    end
    UI.shotFrame = nil
    for _, b in ipairs(list) do
        local a = GlowFrame(b)
        if a then
            SetGlow(a, true)
            UI.shotFrame = UI.shotFrame or a
        end
    end
end

----------------------------------------------------------------------
-- Tooltips: the advice under the game's own aura tooltip
----------------------------------------------------------------------
local function AddAdvice(tt, key)
    local res = ns.result
    if not (key and res and ns.enabled and ns.known[key]) or res.dead then return end
    -- Two words, and on the aura to switch to its cause, as short ("8 Fire hits"). The only
    -- place a cause shows in play.
    local text, color, cause
    if key == res.shown then
        text, color = "Switch now", "GREEN_FONT_COLOR"
        if type(res.reason) == "string" and res.reason ~= "" then cause = res.reason end
    elseif key == res.current and res.shown and ns.known[res.shown] then
        text, color = ns.TwoWords(res.shown), "GREEN_FONT_COLOR"    -- the one to switch to
    elseif ns.OtherAuras()[key] then
        text, color = "Already up", "RED_FONT_COLOR"                -- another paladin has it
    end
    if not text then return end
    local r, g, b = RGB(color)
    tt:AddLine(" ")
    tt:AddLine(text, r, g, b, true)
    if cause then
        r, g, b = RGB("GRAY_FONT_COLOR")
        tt:AddLine(cause, r, g, b, true)
    end
    tt:Show()
end

-- Under Righteous Fury's or a blessing's tooltip: what the reminder wants of it.
local function AddReminder(tt, spell)
    if spell and ns.Reminders and ns.enabled then ns.Reminders.TooltipSpell(tt, spell, RGB) end
end

local function AddUnit(tt, unit)
    if ns.Reminders and ns.enabled then ns.Reminders.TooltipUnit(tt, Plain(unit), RGB) end
end

local HOOKS = {
    SetShapeshift = function(tt, index) AddAdvice(tt, KeyOfForm(index)) end,
    SetAction = function(tt, slot)
        local spell = SpellOfAction(slot)
        AddAdvice(tt, spell and ns.KeyFromSpell(spell))
        AddReminder(tt, spell)
    end,
    SetSpellByID = function(tt, id)
        id = Plain(id)
        AddAdvice(tt, ns.KeyFromSpell(id))
        AddReminder(tt, id)
    end,
    SetUnit = function(tt, unit) AddUnit(tt, unit) end,
}

local function Hook(name)
    return function(...)
        local ok, err = pcall(HOOKS[name], ...)
        if not ok and not UI.hookError then
            UI.hookError = true
            ns.Print("tooltip error (said once): " .. tostring(Plain(err) or "a hidden value"))
        end
    end
end

----------------------------------------------------------------------
-- Setup
----------------------------------------------------------------------
-- What the bars hold changes with these; the game updates its buttons on the same events, so
-- the look waits for the next think, after the game's own handlers.
local BAR_EVENTS = { "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
                     "UPDATE_MULTI_ACTIONBAR", "UPDATE_SHAPESHIFT_FORMS", "PLAYER_ENTERING_WORLD",
                     "UPDATE_MACROS", "ACTIONBAR_HIDEGRID" }

function UI.Create()
    if UI.events then return end
    local f = CreateFrame("Frame")
    UI.events = f
    for _, ev in ipairs(BAR_EVENTS) do pcall(f.RegisterEvent, f, ev) end
    f:SetScript("OnEvent", UI.Refresh)
    -- A unit's tooltip: this client builds it through TooltipDataProcessor (that covers the party
    -- frames and units in the world); older ones through SetUnit.
    local unitHooked = false
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Unit then
        local onUnit = Hook("SetUnit")
        unitHooked = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Unit, function(tt)
            if tt ~= GameTooltip or not tt.GetUnit then return end
            local ok, _, unit = pcall(tt.GetUnit, tt)
            if ok then onUnit(tt, unit) end
        end)
    end
    if hooksecurefunc and GameTooltip then
        for name in pairs(HOOKS) do
            if (name ~= "SetUnit" or not unitHooked) and type(GameTooltip[name]) == "function" then
                hooksecurefunc(GameTooltip, name, Hook(name))
            end
        end
    end
    UI.dirty = true
end
