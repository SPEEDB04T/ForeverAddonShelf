-- Snakes Warlock Helper: the window. One tab per feature; a feature adds its own with
-- Panel.AddTab(key, label, build, refresh). The window holds no cast buttons, so it can be
-- opened and closed at any time, including during a fight.
-- Built like the game's own windows: BasicFrameTemplateWithInset (title bar, close button,
-- inset) with PanelTabButtonTemplate tabs under the bottom edge, as on the character window.
local _, ns = ...
local UI, D = ns.UI, ns.Data
local C = UI.color
local Panel = {}
ns.Panel = Panel

local WIDTH, PAD = 344, 16
local INNER = WIDTH - PAD * 2
local CONTENT_Y = 36          -- below the template's title bar, inside the inset
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
            tab.content:SetPoint("TOPLEFT", PAD, -CONTENT_Y)
            tab.content:SetSize(INNER, 10)
            local inset = rawget(Panel.frame, "Inset")       -- draw above the template's inset
            if type(inset) == "table" then tab.content:SetFrameLevel(inset:GetFrameLevel() + 2) end
            tab.build(tab.content)
        end
        if k == activeTab then tab.content:Show() else tab.content:Hide() end
    end
    if PanelTemplates_SetTab then PanelTemplates_SetTab(Panel.frame, tabs[activeTab].index) end
    Panel.Refresh()
end

local function Create()
    if Panel.frame then return end
    local f = CreateFrame("Frame", "SnakesWarlockHelperPanel", UIParent, "BasicFrameTemplateWithInset")
    Panel.frame = f
    f:SetSize(WIDTH, 300)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        UI.SavePoint(self, "panelPoint")
    end)

    -- The template's title text (its name differs between client builds), else our own.
    local title = rawget(f, "TitleText")
    local container = rawget(f, "TitleContainer")
    if not title and type(container) == "table" then title = container.TitleText end
    if type(title) ~= "table" then
        title = UI.Text(f, "GameFontNormal", nil, "CENTER")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText(ns.TITLE)
    f.title = title
    -- The template's close button hides the window; OnHide below does the rest.

    -- Tabs hang under the bottom edge, like the character window's.
    local prev
    for i, key in ipairs(tabOrder) do
        local tab = tabs[key]
        local b = CreateFrame("Button", "SnakesWarlockHelperPanelTab" .. i, f, "PanelTabButtonTemplate")
        b:SetID(i)
        b:SetText(tab.label)
        if prev then
            b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
        else
            b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
        end
        b:SetScript("OnClick", function()
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
                pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
            end
            SelectTab(key)
        end)
        if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) end
        tab.button, tab.index = b, i
        prev = b
    end
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, #tabOrder) end

    if UISpecialFrames then table.insert(UISpecialFrames, "SnakesWarlockHelperPanel") end   -- Esc closes it
    f:Hide()
    -- Closing the window (Esc, the close button) also ends the demo. Set after the first Hide,
    -- which would otherwise end a demo that is just starting.
    f:SetScript("OnHide", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE then
            pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
        end
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
    Panel.frame:SetHeight(CONTENT_Y + height + PAD)
end

function Panel.Open(key)
    Create()
    if not Panel.frame:IsShown() and PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN then
        pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    end
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
local ROW_H, ICON = 50, 30
local BAR_X = ICON + 12
local VALUE_W = 46
local BAR_W = INNER - BAR_X - VALUE_W
local BAR_H = 8

local demons = { rows = {} }

local function Gray(text) return UI.Hex(C.gray) .. text .. "|r" end

local function RowTooltip(self)
    local row, res = self.row, demons.res
    if not row or not res then return end
    local gold, white, gray, green = C.gold, C.white, C.gray, C.green
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.title or row.name, gold[1], gold[2], gold[3])
    if row.isSacrifice then
        GameTooltip:AddLine(("Demonic Sacrifice: +%d%% %s damage for you."):format(row.pct * 100,
            D.SCHOOL_NAME[res.school]), white[1], white[2], white[3], true)
        GameTooltip:AddLine(row.pact and "With Demonic Pact you can still keep a different demon out."
            or "Without Demonic Pact you have no demon out, so its damage, Soul Link and Master Demonologist are gone.",
            white[1], white[2], white[3], true)
        GameTooltip:Show()
        return
    end
    for _, part in ipairs(row.parts) do
        GameTooltip:AddDoubleLine(part.label .. "  " .. Gray(part.detail), ("%d dps"):format(part.dps),
            white[1], white[2], white[3], white[1], white[2], white[3])
    end
    if row.unmeasured then
        GameTooltip:AddLine("Its melee hasn't been measured yet. Summon it once, out of combat, and it is remembered.",
            C.orange[1], C.orange[2], C.orange[3], true)
    end
    if row.youDps then
        GameTooltip:AddDoubleLine(("Your %s spells  +%.0f%%"):format(D.SCHOOL_NAME[res.school], (row.youPct or 0) * 100),
            ("+%d dps"):format(row.youDps), white[1], white[2], white[3], green[1], green[2], green[3])
    else
        GameTooltip:AddDoubleLine(("Your %s spells"):format(D.SCHOOL_NAME[res.school]),
            ("+%.0f%%"):format((row.youPct or 0) * 100), white[1], white[2], white[3], green[1], green[2], green[3])
    end
    for _, note in ipairs(row.notes or {}) do
        GameTooltip:AddLine("  " .. note, gray[1], gray[2], gray[3])
    end
    GameTooltip:AddLine(" ")
    if row.source == "live" then
        GameTooltip:AddLine("Measured from the demon that is out now.", gray[1], gray[2], gray[3], true)
    elseif row.source == "seen" then
        GameTooltip:AddLine(("Measured %s%s. Summon it again to update."):format(UI.FormatAge(row.age),
            row.seenLevel and row.seenLevel ~= ns.State.level and (" at level " .. row.seenLevel) or ""),
            gray[1], gray[2], gray[3], true)
    elseif row.source == "estimate" then
        GameTooltip:AddLine("Estimated from the spell tooltip. Summon it once to measure it.",
            gray[1], gray[2], gray[3], true)
    end
    GameTooltip:Show()
end

local function NewRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(INNER, ROW_H)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) self.hover:Show(); RowTooltip(self) end)
    r:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
    -- the quest log's row highlight
    r.hover = r:CreateTexture(nil, "BACKGROUND")
    r.hover:SetTexture(UI.ROW_HIGHLIGHT)
    r.hover:SetBlendMode("ADD")
    r.hover:SetAlpha(0.7)
    r.hover:SetPoint("TOPLEFT", -6, 1)
    r.hover:SetPoint("BOTTOMRIGHT", 6, 1)
    r.hover:Hide()

    r.iconFrame = CreateFrame("Frame", nil, r)
    UI.IconFrame(r.iconFrame, ICON)
    r.iconFrame:SetPoint("TOPLEFT", 0, -5)
    r.icon = r.iconFrame.tex

    r.name = UI.Text(r, "GameFontHighlight")
    r.name:SetPoint("TOPLEFT", BAR_X, -3)
    r.value = UI.Text(r, "GameFontHighlight", nil, "RIGHT")
    r.value:SetPoint("TOPRIGHT", 0, -3)

    r.bar = UI.BarFrame(r, BAR_W, BAR_H)
    r.bar:SetPoint("TOPLEFT", BAR_X - 3, -18)
    r.track = r.bar.track
    r.pet = UI.BarSegment(r.bar, C.warlock, BAR_H)
    r.pet:SetPoint("TOPLEFT", r.track, "TOPLEFT")
    r.you = UI.BarSegment(r.bar, C.green, BAR_H)
    r.you:SetPoint("TOPLEFT", r.pet, "TOPRIGHT")

    r.sub = UI.Text(r, "GameFontHighlightSmall")
    r.sub:SetPoint("TOPLEFT", BAR_X, -36)
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
    demons.heading = UI.Text(content, "GameFontNormal")
    demons.heading:SetPoint("TOPLEFT", 0, -4)
    demons.heading:SetText("Damage each demon is worth")

    demons.school = UI.Button(content, "Shadow", function()
        if ns.demo then return end
        ns.cdb.school = (ns.cdb.school == "fire") and "shadow" or "fire"
        ns.MarkDirty()
        Panel.Refresh()
    end, true)
    demons.school:SetPoint("TOPRIGHT", 0, 0)
    demons.school.tipTitle = "Your spells"
    demons.school.tip = "Which of your own spells to count the demon bonuses for. Click to switch between Shadow and Fire."

    demons.empty = UI.Text(content, "GameFontDisable")
    demons.empty:SetPoint("TOPLEFT", 0, -34)
    demons.empty:SetWidth(INNER)
    demons.empty:SetText("No demons learned yet.")

    demons.sacHeading = UI.Text(content, "GameFontNormal")
    demons.sacHeading:SetText("Demonic Sacrifice")
    demons.sacRow = NewRow(content)

    demons.best = UI.Text(content, "GameFontHighlight", C.green)
    demons.best:SetWidth(INNER)
    demons.legend = UI.Text(content, "GameFontHighlightSmall")
    demons.legend:SetWidth(INNER)
    demons.foot = UI.Text(content, "GameFontDisableSmall")
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

    local y = -28
    for i, row in ipairs(res.rows) do
        local r = demons.rows[i] or NewRow(content)
        demons.rows[i] = r
        r.row = row
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r.icon:SetTexture(row.icon)
        local best = (res.bestKey == row.key)
        r.name:SetText(row.name .. (best and ("  " .. UI.Hex(C.green) .. "best|r") or ""))
        if row.total then
            r.value:SetText((row.source == "estimate" and "~" or "") .. ("%d"):format(row.total))
            r.value:SetTextColor(C.white[1], C.white[2], C.white[3])
        else
            r.value:SetText("?")
            r.value:SetTextColor(C.gray[1], C.gray[2], C.gray[3])
        end
        SetBar(r, row.petDps, row.petDps and row.youDps, scale)

        local gain = row.youDps and ("you +%d"):format(row.youDps) or ("you +%.0f%%"):format((row.youPct or 0) * 100)
        local state
        if row.source == "live" then
            state = UI.Hex(C.green) .. "out now|r"
        elseif row.source == "seen" then
            state = Gray("measured " .. UI.FormatAge(row.age))
        elseif row.source == "estimate" then
            state = Gray("estimate")
        end
        if row.unmeasured or not row.petDps then
            r.sub:SetText(UI.Hex(C.orange) .. "summon it once to measure it|r")
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
        y = y - 8
        demons.sacHeading:ClearAllPoints()
        demons.sacHeading:SetPoint("TOPLEFT", 0, y)
        demons.sacHeading:Show()
        y = y - 18
        local r = demons.sacRow
        r.row = { isSacrifice = true, title = "Sacrifice your " .. sac.name, pct = sac.pct, pact = sac.pact }
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 0, y)
        r.icon:SetTexture(sac.icon)
        r.name:SetText("Sacrifice your " .. sac.name)
        r.value:SetText(sac.youDps and ("+%d"):format(sac.youDps) or ("+%d%%"):format(sac.pct * 100))
        r.value:SetTextColor(C.white[1], C.white[2], C.white[3])
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
    y = y - 8
    demons.best:ClearAllPoints()
    demons.best:SetPoint("TOPLEFT", 0, y)
    demons.best:SetText(res.best or "")
    if res.best then y = y - (demons.best:GetStringHeight() or 12) - 8 end

    demons.legend:ClearAllPoints()
    demons.legend:SetPoint("TOPLEFT", 0, y)
    demons.legend:SetText(("%s the demon's own damage    %s added to your spells"):format(
        UI.Swatch(C.warlock), UI.Swatch(C.green)))
    y = y - 18

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
        local h = UI.Text(content, "GameFontNormal")
        h:SetPoint("TOPLEFT", 0, y - 4)
        h:SetText(text)
        y = y - 24
    end
    local function check(label, get, set)
        local c = UI.Check(content, label, get, function(v) set(v); ns.MarkDirty() end)
        c:SetPoint("TOPLEFT", 0, y)
        options.checks[#options.checks + 1] = c
        y = y - 26
    end

    heading("Remind me about")
    for _, key in ipairs(ns.Reminders.ORDER) do
        check(ns.Reminders.LABEL[key],
            function() return ns.db.remind[key] end,
            function(v) ns.db.remind[key] = v end)
    end

    y = y - 8
    heading("Reminder icons")
    check("Keep showing them during fights",
        function() return ns.db.combat end, function(v) ns.db.combat = v end)
    check("Glow while something is missing",
        function() return ns.db.pulse end, function(v) ns.db.pulse = v end)
    check("Lock in place (untick to drag them)",
        function() return ns.db.locked end,
        function(v) ns.db.locked = v; ns.Strip.ApplyLock() end)

    y = y - 4
    local label = UI.Text(content, "GameFontHighlight")
    label:SetPoint("TOPLEFT", 4, y - 5)
    label:SetText("Size")
    local x = 46
    for _, s in ipairs(SIZES) do
        local b = UI.Button(content, s[1], function()
            ns.db.iconSize = s[2]
            ns.MarkDirty()
            Panel.Refresh()
        end, true)
        b:SetWidth(72)
        b:SetPoint("TOPLEFT", x, y)
        b.size = s[2]
        options.sizes[#options.sizes + 1] = b
        x = x + 72 + 4
    end
    y = y - 32

    if ns.Options and ns.Options.Ready() then       -- warlocks only: other classes have no button
        heading("Minimap")
        check("Show the minimap button",
            function() return ns.Kit.MinimapShown() end,
            function(v) ns.Kit.SetMinimapShown(v) end)
        y = y - 8
    end

    options.hint = UI.Text(content, "GameFontDisableSmall")
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
