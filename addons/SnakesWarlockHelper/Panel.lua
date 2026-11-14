-- Snakes Warlock Helper: the window. One tab per feature; a feature adds its own with
-- Panel.AddTab(key, label, build, refresh). The window holds no cast buttons, so it can be
-- opened and closed at any time, including during a fight.
local _, ns = ...
local UI, D = ns.UI, ns.Data
local C = UI.color
local Panel = {}
ns.Panel = Panel

local WIDTH, PAD = 324, 14
local INNER = WIDTH - PAD * 2
local HEADER, TABS = 34, 26
local tabs, tabOrder = {}, {}
local activeTab

-- build(content) creates the widgets once; refresh(content) updates them and returns the height.
function Panel.AddTab(key, label, build, refresh)
    tabs[key] = { key = key, label = label, build = build, refresh = refresh }
    tabOrder[#tabOrder + 1] = key
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
local function SelectTab(key)
    activeTab = tabs[key] and key or tabOrder[1]
    for _, k in ipairs(tabOrder) do
        local tab = tabs[k]
        if not tab.content then
            tab.content = CreateFrame("Frame", nil, Panel.frame)
            tab.content:SetPoint("TOPLEFT", PAD, -(HEADER + TABS + 10))
            tab.content:SetSize(INNER, 10)
            tab.build(tab.content)
        end
        local on = (k == activeTab)
        if on then tab.content:Show() else tab.content:Hide() end
        tab.button:SetSelected(on)
        if on then tab.button.line:Show() else tab.button.line:Hide() end
    end
    Panel.Refresh()
end

local function Create()
    if Panel.frame then return end
    local f = CreateFrame("Frame", "SnakesWarlockHelperPanel", UIParent)
    Panel.frame = f
    f:SetSize(WIDTH, 300)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SavePoint(self, "panelPoint")
    end)

    f.bg = UI.Fill(f, "BACKGROUND", C.bg, 0.95)
    f.bg:SetAllPoints()
    UI.Border(f, C.accent, 0.45)
    f.top = UI.Fill(f, "ARTWORK", C.accent, 0.9)      -- accent line along the top edge
    f.top:SetPoint("TOPLEFT")
    f.top:SetPoint("TOPRIGHT")
    f.top:SetHeight(2)

    f.title = UI.Text(f, "GameFontNormal", C.text)
    f.title:SetPoint("TOPLEFT", PAD, -12)
    f.title:SetText(ns.TITLE)
    f.version = UI.Text(f, "GameFontHighlightSmall", C.faint)
    f.version:SetPoint("BOTTOMLEFT", f.title, "BOTTOMRIGHT", 6, 1)
    f.version:SetText("v" .. ns.VERSION)

    f.close = UI.Button(f, "x", function() Panel.Close() end)
    f.close:SetSize(22, 22)
    f.close:SetPoint("TOPRIGHT", -6, -6)
    f.close.tip = "Close"

    -- Tab row
    local x = PAD
    for _, key in ipairs(tabOrder) do
        local tab = tabs[key]
        local b = UI.Button(f, tab.label, function() SelectTab(key) end)
        b:SetPoint("TOPLEFT", x, -HEADER)
        b.line = UI.Fill(b, "ARTWORK", C.fel, 0.9)
        b.line:SetPoint("BOTTOMLEFT", 0, -4)
        b.line:SetPoint("BOTTOMRIGHT", 0, -4)
        b.line:SetHeight(1)
        tab.button = b
        x = x + b:GetWidth() + 14
    end
    f.rule = UI.Fill(f, "ARTWORK", C.accent, 0.2)
    f.rule:SetPoint("TOPLEFT", PAD, -(HEADER + TABS - 3))
    f.rule:SetPoint("TOPRIGHT", -PAD, -(HEADER + TABS - 3))
    f.rule:SetHeight(1)

    if UISpecialFrames then table.insert(UISpecialFrames, "SnakesWarlockHelperPanel") end   -- Esc closes it
    f:Hide()
    -- Closing the window (Esc, the x) also ends the demo. Set after the first Hide, which
    -- would otherwise end a demo that is just starting.
    f:SetScript("OnHide", function()
        if ns.demo then
            ns.demo = nil
            ns.Strip.Show({})
            if ns.enabled then ns.MarkDirty() end
        end
    end)
    Panel.RestorePosition()
end

function Panel.RestorePosition()
    if Panel.frame then UI.RestorePoint(Panel.frame, "panelPoint", "CENTER", 320, 60) end
end

function Panel.IsShown()
    return Panel.frame ~= nil and Panel.frame:IsShown()
end

function Panel.Refresh()
    if not Panel.IsShown() or not activeTab then return end
    local tab = tabs[activeTab]
    local height = tab.refresh(tab.content) or 100
    tab.content:SetHeight(height)
    Panel.frame:SetHeight(HEADER + TABS + 10 + height + PAD)
end

function Panel.Open(key)
    Create()
    Panel.frame:Show()
    SelectTab(key or activeTab or tabOrder[1])
end

function Panel.Close()
    if Panel.frame then Panel.frame:Hide() end
end

function Panel.Toggle()
    if Panel.IsShown() then Panel.Close() else Panel.Open() end
end

----------------------------------------------------------------------
-- Tab: Demons
----------------------------------------------------------------------
local ROW_H, ICON = 48, 30
local BAR_X = ICON + 10
local VALUE_W = 46
local BAR_W = INNER - BAR_X - VALUE_W

local demons = { rows = {} }

local function RowTooltip(self)
    local row, res = self.row, demons.res
    if not row or not res then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.title or row.name, 1, 1, 1)
    if row.isSacrifice then
        GameTooltip:AddLine(("Demonic Sacrifice: +%d%% %s damage for you."):format(row.pct * 100,
            D.SCHOOL_NAME[res.school]), C.dim[1], C.dim[2], C.dim[3], true)
        GameTooltip:AddLine(row.pact and "With Demonic Pact you can still keep a different demon out."
            or "Without Demonic Pact you have no demon out, so its damage, Soul Link and Master Demonologist are gone.",
            C.dim[1], C.dim[2], C.dim[3], true)
        GameTooltip:Show()
        return
    end
    for _, part in ipairs(row.parts) do
        GameTooltip:AddDoubleLine(part.label .. "  |cff736e85" .. part.detail .. "|r", ("%d dps"):format(part.dps),
            C.text[1], C.text[2], C.text[3], C.accent[1], C.accent[2], C.accent[3])
    end
    if row.unmeasured then
        GameTooltip:AddLine("Its melee hasn't been measured yet. Summon it once, out of combat, and it is remembered.",
            C.amber[1], C.amber[2], C.amber[3], true)
    end
    if row.youDps then
        GameTooltip:AddDoubleLine(("Your %s spells  +%.0f%%"):format(D.SCHOOL_NAME[res.school], (row.youPct or 0) * 100),
            ("+%d dps"):format(row.youDps), C.text[1], C.text[2], C.text[3], C.fel[1], C.fel[2], C.fel[3])
    else
        GameTooltip:AddDoubleLine(("Your %s spells"):format(D.SCHOOL_NAME[res.school]),
            ("+%.0f%%"):format((row.youPct or 0) * 100), C.text[1], C.text[2], C.text[3], C.fel[1], C.fel[2], C.fel[3])
    end
    for _, note in ipairs(row.notes or {}) do
        GameTooltip:AddLine("  " .. note, C.dim[1], C.dim[2], C.dim[3])
    end
    GameTooltip:AddLine(" ")
    if row.source == "live" then
        GameTooltip:AddLine("Measured from the demon that is out now.", C.faint[1], C.faint[2], C.faint[3], true)
    elseif row.source == "seen" then
        GameTooltip:AddLine(("Measured %s%s. Summon it again to update."):format(UI.FormatAge(row.age),
            row.seenLevel and row.seenLevel ~= ns.State.level and (" at level " .. row.seenLevel) or ""),
            C.faint[1], C.faint[2], C.faint[3], true)
    elseif row.source == "estimate" then
        GameTooltip:AddLine("Estimated from the spell tooltip. Summon it once to measure it.",
            C.faint[1], C.faint[2], C.faint[3], true)
    end
    GameTooltip:Show()
end

local function NewRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(INNER, ROW_H)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) self.hover:Show(); RowTooltip(self) end)
    r:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
    r.hover = UI.Fill(r, "BACKGROUND", C.accent, 0.08)
    r.hover:SetPoint("TOPLEFT", -6, 2)
    r.hover:SetPoint("BOTTOMRIGHT", 6, 2)
    r.hover:Hide()

    r.iconEdge = UI.Fill(r, "BORDER", C.accent, 0.5)
    r.iconEdge:SetSize(ICON, ICON)
    r.iconEdge:SetPoint("TOPLEFT", 0, -4)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetPoint("TOPLEFT", r.iconEdge, "TOPLEFT", 1, -1)
    r.icon:SetPoint("BOTTOMRIGHT", r.iconEdge, "BOTTOMRIGHT", -1, 1)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    r.name = UI.Text(r, "GameFontHighlight", C.text)
    r.name:SetPoint("TOPLEFT", BAR_X, -3)
    r.value = UI.Text(r, "GameFontHighlight", C.text, "RIGHT")
    r.value:SetPoint("TOPRIGHT", 0, -3)

    r.track = UI.Fill(r, "BORDER", C.raised, 1)
    r.track:SetPoint("TOPLEFT", BAR_X, -20)
    r.track:SetSize(BAR_W, 6)
    r.pet = UI.Fill(r, "ARTWORK", C.accent, 1)
    r.pet:SetPoint("TOPLEFT", r.track, "TOPLEFT")
    r.pet:SetHeight(6)
    r.you = UI.Fill(r, "ARTWORK", C.fel, 1)
    r.you:SetPoint("TOPLEFT", r.pet, "TOPRIGHT")
    r.you:SetHeight(6)

    r.sub = UI.Text(r, "GameFontHighlightSmall", C.dim)
    r.sub:SetPoint("TOPLEFT", BAR_X, -30)
    r.sub:SetWidth(INNER - BAR_X)
    r.sub:SetWordWrap(false)
    return r
end

local function SetBar(r, petDps, youDps, scale)
    local petW = (petDps or 0) * scale
    local youW = (youDps or 0) * scale
    if petW >= 1 then
        r.pet:SetWidth(petW); r.pet:Show()
        r.you:ClearAllPoints()
        r.you:SetPoint("TOPLEFT", r.pet, "TOPRIGHT")
    else
        r.pet:Hide()
        r.you:ClearAllPoints()
        r.you:SetPoint("TOPLEFT", r.track, "TOPLEFT")
    end
    if youW >= 1 then r.you:SetWidth(youW); r.you:Show() else r.you:Hide() end
end

local function BuildDemons(content)
    demons.heading = UI.Text(content, "GameFontHighlightSmall", C.faint)
    demons.heading:SetPoint("TOPLEFT", 0, -3)
    demons.heading:SetText("DAMAGE EACH DEMON IS WORTH")

    demons.school = UI.Button(content, "Shadow", function()
        if ns.demo then return end
        ns.cdb.school = (ns.cdb.school == "fire") and "shadow" or "fire"
        ns.MarkDirty()
        Panel.Refresh()
    end, true)
    demons.school:SetPoint("TOPRIGHT", 0, 0)
    demons.school.tip = "Which of your own spells to count the demon bonuses for. Click to switch between Shadow and Fire."

    demons.empty = UI.Text(content, "GameFontHighlightSmall", C.dim)
    demons.empty:SetPoint("TOPLEFT", 0, -34)
    demons.empty:SetWidth(INNER)
    demons.empty:SetText("No demons learned yet.")

    demons.sacHeading = UI.Text(content, "GameFontHighlightSmall", C.faint)
    demons.sacHeading:SetText("DEMONIC SACRIFICE")
    demons.sacRow = NewRow(content)

    demons.rule = UI.Fill(content, "ARTWORK", C.accent, 0.2)
    demons.rule:SetSize(INNER, 1)
    demons.best = UI.Text(content, "GameFontHighlightSmall", C.fel)
    demons.best:SetWidth(INNER)
    demons.legend = UI.Text(content, "GameFontHighlightSmall", C.dim)
    demons.legend:SetWidth(INNER)
    demons.foot = UI.Text(content, "GameFontHighlightSmall", C.faint)
    demons.foot:SetWidth(INNER)
    demons.foot:SetSpacing(2)
end

local function RefreshDemons(content)
    local res = ns.demo and ns.PetCalc.DemoResult() or ns.PetCalc.Evaluate()
    demons.res = res
    local schoolName = D.SCHOOL_NAME[res.school]
    demons.school:SetLabel("Your spells: " .. schoolName)

    local top = 0
    for _, row in ipairs(res.rows) do top = math.max(top, row.total or 0) end
    if res.sacrifice and res.sacrifice.youDps then top = math.max(top, res.sacrifice.youDps) end
    local scale = top > 0 and (BAR_W / top) or 0

    local y = -30
    for i, row in ipairs(res.rows) do
        local r = demons.rows[i] or NewRow(content)
        demons.rows[i] = r
        r.row = row
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r.icon:SetTexture(row.icon)
        local best = (res.bestKey == row.key)
        r.name:SetText(row.name .. (best and ("  " .. UI.Hex(C.fel) .. "best|r") or ""))
        if row.total then
            r.value:SetText((row.source == "estimate" and "~" or "") .. ("%d"):format(row.total))
            r.value:SetTextColor(C.text[1], C.text[2], C.text[3])
        else
            r.value:SetText("?")
            r.value:SetTextColor(C.faint[1], C.faint[2], C.faint[3])
        end
        SetBar(r, row.petDps, row.petDps and row.youDps, scale)

        local gain = row.youDps and ("you +%d"):format(row.youDps) or ("you +%.0f%%"):format((row.youPct or 0) * 100)
        local state
        if row.source == "live" then
            state = UI.Hex(C.fel) .. "out now|r"
        elseif row.source == "seen" then
            state = "measured " .. UI.FormatAge(row.age)
        elseif row.source == "estimate" then
            state = "estimate"
        end
        if row.unmeasured or not row.petDps then
            r.sub:SetText(UI.Hex(C.amber) .. "summon it once to measure it|r")
        else
            r.sub:SetText(("demon %d  \194\183  %s%s"):format(row.petDps, gain, state and ("  \194\183  " .. state) or ""))
        end
        r:Show()
        y = y - ROW_H
    end
    for i = #res.rows + 1, #demons.rows do demons.rows[i]:Hide() end
    if #res.rows == 0 then
        demons.empty:Show()
        y = y - 24
    else
        demons.empty:Hide()
    end

    -- Demonic Sacrifice
    local sac = res.sacrifice
    if sac then
        y = y - 6
        demons.sacHeading:ClearAllPoints()
        demons.sacHeading:SetPoint("TOPLEFT", 0, y)
        demons.sacHeading:Show()
        y = y - 16
        local r = demons.sacRow
        r.row = { isSacrifice = true, title = "Sacrifice your " .. sac.name, pct = sac.pct, pact = sac.pact }
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r.icon:SetTexture(sac.icon)
        r.name:SetText("Sacrifice your " .. sac.name)
        r.value:SetText(sac.youDps and ("+%d"):format(sac.youDps) or ("+%d%%"):format(sac.pct * 100))
        SetBar(r, nil, sac.youDps, scale)
        r.sub:SetText(("+%d%% %s for you  \194\183  %s"):format(sac.pct * 100, schoolName,
            sac.pact and "adds to a demon kept out" or "instead of a demon"))
        r:Show()
        y = y - ROW_H
    else
        demons.sacHeading:Hide()
        demons.sacRow:Hide()
    end

    -- Verdict, legend and what the numbers assume
    y = y - 4
    demons.rule:ClearAllPoints()
    demons.rule:SetPoint("TOPLEFT", 0, y)
    y = y - 9
    demons.best:ClearAllPoints()
    demons.best:SetPoint("TOPLEFT", 0, y)
    demons.best:SetText(res.best or "")
    if res.best then y = y - (demons.best:GetStringHeight() or 12) - 6 end

    demons.legend:ClearAllPoints()
    demons.legend:SetPoint("TOPLEFT", 0, y)
    -- Colour swatches are drawn as tinted textures: the game font has no square glyph.
    local function swatch(c)
        return ("|TInterface\\Buttons\\WHITE8X8:8:8:0:0:8:8:0:8:0:8:%d:%d:%d|t"):format(c[1] * 255, c[2] * 255, c[3] * 255)
    end
    demons.legend:SetText(("%s the demon's own damage    %s added to your spells"):format(swatch(C.accent), swatch(C.fel)))
    y = y - 16

    local me = res.me
    local foot
    if not me then
        foot = "Your own dps couldn't be estimated, so your gains show as percentages. /swh dps <number> sets it."
    elseif me.source == "manual" then
        foot = ("Your spells: %d dps, set by you (/swh dps auto to estimate)."):format(me.dps)
    else
        foot = ("Your spells: about %d dps, estimated from %s. /swh dps <number> sets it yourself."):format(
            me.dps, me.spell or "your main spell")
    end
    if res.talents.soulLink then foot = foot .. " Soul Link is counted as up." end
    foot = foot .. " Not counted: Demonic Brand, mana, utility."
    demons.foot:ClearAllPoints()
    demons.foot:SetPoint("TOPLEFT", 0, y)
    demons.foot:SetText(foot)
    y = y - (demons.foot:GetStringHeight() or 36)

    return -y
end

Panel.AddTab("demons", "Demons", BuildDemons, RefreshDemons)

----------------------------------------------------------------------
-- Tab: Options
----------------------------------------------------------------------
local options = { checks = {}, sizes = {} }
local SIZES = { { "Small", 26 }, { "Medium", 32 }, { "Large", 40 } }

local function BuildOptions(content)
    local y = 0
    local function heading(text)
        local h = UI.Text(content, "GameFontHighlightSmall", C.faint)
        h:SetPoint("TOPLEFT", 0, y - 3)
        h:SetText(text)
        y = y - 22
    end
    local function check(label, get, set)
        local c = UI.Check(content, label, get, function(v) set(v); ns.MarkDirty() end)
        c:SetPoint("TOPLEFT", 0, y)
        c:SetWidth(INNER)
        options.checks[#options.checks + 1] = c
        y = y - 22
    end

    heading("REMIND ME ABOUT")
    for _, key in ipairs(ns.Reminders.ORDER) do
        check(ns.Reminders.LABEL[key],
            function() return ns.db.remind[key] end,
            function(v) ns.db.remind[key] = v end)
    end

    y = y - 8
    heading("REMINDER ICONS")
    check("Keep showing them during fights",
        function() return ns.db.combat end, function(v) ns.db.combat = v end)
    check("Breathing glow",
        function() return ns.db.pulse end, function(v) ns.db.pulse = v end)
    check("Lock in place (untick to drag them)",
        function() return ns.db.locked end,
        function(v) ns.db.locked = v; ns.Strip.ApplyLock() end)

    y = y - 6
    local label = UI.Text(content, "GameFontHighlightSmall", C.text)
    label:SetPoint("TOPLEFT", 0, y - 4)
    label:SetText("Size")
    local x = 44
    for _, s in ipairs(SIZES) do
        local b = UI.Button(content, s[1], function()
            ns.db.iconSize = s[2]
            ns.MarkDirty()
            Panel.Refresh()
        end, true)
        b:SetPoint("TOPLEFT", x, y)
        b.size = s[2]
        options.sizes[#options.sizes + 1] = b
        x = x + b:GetWidth() + 6
    end
    y = y - 30

    if ns.Options and ns.Options.Ready() then       -- warlocks only: other classes have no button
        heading("MINIMAP")
        check("Show the minimap button",
            function() return ns.Kit.MinimapShown() end,
            function(v) ns.Kit.SetMinimapShown(v) end)
        y = y - 8
    end

    options.hint = UI.Text(content, "GameFontHighlightSmall", C.faint)
    options.hint:SetPoint("TOPLEFT", 0, y)
    options.hint:SetWidth(INNER)
    options.hint:SetSpacing(2)
    options.hint:SetText("Reminders only appear while something is missing. Click one to cast it (out of combat). "
        .. "Right-click one to quiet it for 10 minutes.")
    options.height = -y
end

local function RefreshOptions()
    for _, c in ipairs(options.checks) do c:Sync() end
    for _, b in ipairs(options.sizes) do b:SetSelected(b.size == ns.db.iconSize) end
    return options.height + (options.hint:GetStringHeight() or 36)
end

Panel.AddTab("options", "Options", BuildOptions, RefreshOptions)
