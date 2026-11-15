-- Snakes Warlock Helper: the window. One tab per feature; a feature adds its own with
-- Panel.AddTab(key, label, build, refresh). The window holds no cast buttons, so it can be
-- opened and closed at any time, including during a fight.
--
-- Built like the character window (Blizzard_UIPanels_Game/Mainline/CharacterFrame.xml):
-- ButtonFrameTemplate with a portrait, an inset and PanelTabButtonTemplate tabs under the bottom
-- edge. The demon list copies the Skills tab's rows (Blizzard_UIPanels_Game/Camelot/SkillsFrame.xml).
local _, ns = ...
local UI, D = ns.UI, ns.Data
local C = UI.color
local Panel = {}
ns.Panel = Panel

local WIDTH = 338
local INSET_LEFT, INSET_TOP, INSET_RIGHT = 4, 60, 6      -- ButtonFrameTemplate's Inset anchors
local INSET_BOTTOM = math.abs(PANEL_INSET_BOTTOM_OFFSET or 4)   -- after ButtonFrameTemplate_HideButtonBar
local PAD = 10                                           -- content inside the inset
local INNER = WIDTH - INSET_LEFT - INSET_RIGHT - PAD * 2
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
            tab.content:SetPoint("TOPLEFT", INSET_LEFT + PAD, -(INSET_TOP + PAD))
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
    local f = CreateFrame("Frame", "SnakesWarlockHelperPanel", UIParent, "ButtonFrameTemplate")
    Panel.frame = f
    f:SetSize(WIDTH, 300)
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
    if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(f) end

    -- Title and portrait through the template's own mixin (PortraitFrameMixin).
    if type(rawget(f, "SetTitle")) == "function" then
        f:SetTitle(ns.TITLE)
    else
        f.title = UI.Text(f, "GameFontNormal", nil, "CENTER")
        f.title:SetPoint("TOP", 0, -5)
        f.title:SetText(ns.TITLE)
    end
    if type(rawget(f, "SetPortraitToAsset")) == "function" then
        f:SetPortraitToAsset("Interface\\Icons\\Spell_Shadow_GatherShadows")
    end
    -- The template's close button hides the window; OnHide below does the rest.

    -- Tabs, anchored like CharacterFrameTab1 and CharacterFrameTab2.
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
            UI.Sound("IG_CHARACTER_INFO_TAB")
            SelectTab(key)
        end)
        tab.button, tab.index = b, i
        prev = b
    end
    if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, #tabOrder) end

    if UISpecialFrames then table.insert(UISpecialFrames, "SnakesWarlockHelperPanel") end   -- Esc closes it
    f:Hide()
    -- Closing the window (Esc, the close button) also ends the demo. Set after the first Hide,
    -- which would otherwise end a demo that is just starting.
    f:SetScript("OnHide", function()
        UI.Sound("IG_CHARACTER_INFO_CLOSE")
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
    Panel.frame:SetHeight(INSET_TOP + PAD + height + PAD + INSET_BOTTOM)
end

function Panel.Open(key)
    Create()
    if not Panel.frame:IsShown() then UI.Sound("IG_CHARACTER_INFO_OPEN") end
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
-- SkillsEntryTemplate: 30 high, name on the left in GameFontHighlight, a 160 x 29
-- ColoredProgressBarTemplate on the right (blue fill, white, value written on the bar), and the
-- character-create line highlight at 10% while hovered.
local ROW_H, BAR_W, BAR_H = 30, 160, 29

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

local function NewBar(parent)
    if UI.HasTemplate("ColoredProgressBarTemplate") then
        local bar = CreateFrame("Frame", nil, parent, "ColoredProgressBarTemplate")
        bar:SetSize(BAR_W, BAR_H)
        if bar.SetFillTextureByColorType and ColoredProgressBarMixin then
            bar:SetFillTextureByColorType(ColoredProgressBarMixin.ColorType.Blue)   -- as SkillsBarMixin:OnLoad
        end
        local fill = rawget(bar, "Fill")
        if type(fill) == "table" then fill:SetVertexColor(1, 1, 1) end             -- UpdateBarColor(WHITE)
        return bar
    end
    local bar = CreateFrame("Frame", nil, parent)                 -- no template: the value alone
    bar:SetSize(BAR_W, BAR_H)
    bar.Text = UI.Text(bar, "GameFontHighlight", nil, "CENTER")
    bar.Text:SetAllPoints()
    return bar
end

local function NewRow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r:SetHeight(ROW_H)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) self.hl:SetAlpha(0.10); RowTooltip(self) end)
    r:SetScript("OnLeave", function(self) self.hl:SetAlpha(0); GameTooltip:Hide() end)

    -- BackgroundHighlight
    r.hl = CreateFrame("Frame", nil, r)
    r.hl:SetAllPoints()
    r.hl:SetAlpha(0)
    local left = r.hl:CreateTexture(nil, "BACKGROUND")
    left:SetAtlas("charactercreate-customize-dropdown-linemouseover-side")
    left:SetWidth(6)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT")
    local right = r.hl:CreateTexture(nil, "BACKGROUND")
    right:SetAtlas("charactercreate-customize-dropdown-linemouseover-side")
    right:SetTexCoord(1, 0, 0, 1)
    right:SetWidth(6)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT")
    local middle = r.hl:CreateTexture(nil, "BACKGROUND")
    middle:SetAtlas("charactercreate-customize-dropdown-linemouseover-middle")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")

    r.bar = NewBar(r)
    r.bar:SetPoint("RIGHT", -3, 0)
    r.name = UI.Text(r, "GameFontHighlight")
    r.name:SetHeight(15)
    r.name:SetPoint("LEFT", 2, 0)
    r.name:SetPoint("RIGHT", r.bar, "LEFT", -10, 0)
    r.name:SetWordWrap(false)
    return r
end

-- Rows are pinned left and right to the content, so they follow its width.
local function Place(r, y)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 0, y)
    r:SetPoint("TOPRIGHT", 0, y)
end

local function SetBar(r, value, top, text)
    if r.bar.SetFillPercent then r.bar:SetFillPercent(top > 0 and (value or 0) / top or 0) end
    if r.bar.SetText then r.bar:SetText(text) end
    local t = rawget(r.bar, "Text")
    if type(t) == "table" then t:SetText(text) end
end

local function BuildDemons(content)
    demons.schoolLabel = UI.Text(content, "GameFontHighlight")
    demons.schoolLabel:SetPoint("TOPLEFT", 2, -6)
    demons.schoolLabel:SetText("Count the bonuses for your")
    demons.school = UI.Dropdown(content, "school", 120, {
        { "Shadow spells", "shadow" },
        { "Fire spells", "fire" },
    }, function() return ns.demo and "shadow" or (ns.cdb.school or "shadow") end, function(v)
        if ns.demo then return end
        ns.cdb.school = v
        ns.MarkDirty()
        Panel.Refresh()
    end)
    demons.school:SetPoint("TOPRIGHT", -3, 0)

    demons.empty = UI.Text(content, "GameFontDisable")
    demons.empty:SetPoint("TOPLEFT", 2, -40)
    demons.empty:SetText("No demons learned yet.")

    demons.sacHeading = UI.Text(content, "GameFontNormal")
    demons.sacHeading:SetText("Demonic Sacrifice")
    demons.sacRow = NewRow(content)

    demons.best = UI.Text(content, "GameFontHighlight")
    demons.best:SetWidth(INNER - 4)
    demons.foot = UI.Text(content, "GameFontDisableSmall")
    demons.foot:SetWidth(INNER - 4)
    demons.foot:SetSpacing(2)
end

local function RefreshDemons(content)
    local res = ns.demo and ns.PetCalc.DemoResult() or ns.PetCalc.Evaluate()
    demons.res = res
    local schoolName = D.SCHOOL_NAME[res.school]
    demons.school:Sync()

    local top = 0
    for _, row in ipairs(res.rows) do top = math.max(top, row.total or 0) end
    if res.sacrifice and res.sacrifice.youDps then top = math.max(top, res.sacrifice.youDps) end

    local y = -34
    local unmeasured = {}
    for i, row in ipairs(res.rows) do
        local r = demons.rows[i] or NewRow(content)
        demons.rows[i] = r
        r.row = row
        Place(r, y)
        local state
        if row.source == "live" then state = "out now"
        elseif row.source == "estimate" then state = "estimate" end
        if row.unmeasured or not row.petDps then
            state = "not measured"
            unmeasured[#unmeasured + 1] = row.name
        end
        r.name:SetText(row.name .. (state and ("  " .. Gray("(" .. state .. ")")) or ""))
        if row.total then
            SetBar(r, row.total, top, (row.source == "estimate" and "~" or "") .. ("%d dps"):format(row.total))
        else
            SetBar(r, 0, top, "?")
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
        y = y - 10
        demons.sacHeading:ClearAllPoints()
        demons.sacHeading:SetPoint("TOPLEFT", 2, y)
        demons.sacHeading:Show()
        y = y - 18
        local r = demons.sacRow
        r.row = { isSacrifice = true, title = "Sacrifice your " .. sac.name, pct = sac.pct, pact = sac.pact }
        Place(r, y)
        r.name:SetText("Sacrifice your " .. sac.name)
        if sac.youDps then
            SetBar(r, sac.youDps, top, ("+%d dps"):format(sac.youDps))
        else
            SetBar(r, 0, top, ("+%d%% %s"):format(sac.pct * 100, schoolName))
        end
        r:Show()
        y = y - ROW_H
    else
        demons.sacHeading:Hide()
        demons.sacRow:Hide()
    end

    -- Verdict and what the numbers assume
    y = y - 10
    demons.best:ClearAllPoints()
    demons.best:SetPoint("TOPLEFT", 2, y)
    demons.best:SetText(res.best or "")
    if res.best then y = y - (demons.best:GetStringHeight() or 12) - 8 end

    local me = res.me
    local foot = ""
    if #unmeasured > 0 then
        foot = table.concat(unmeasured, ", ") .. ": summon it once to measure it. "
    end
    if not me then
        foot = foot .. "Your own dps couldn't be estimated, so your gains show as percentages. /swh dps <number> sets it."
    elseif me.source == "manual" then
        foot = foot .. ("Your spells: %d dps, set by you (/swh dps auto to estimate)."):format(me.dps)
    else
        foot = foot .. ("Your spells: about %d dps, estimated from %s. /swh dps <number> sets it yourself."):format(
            me.dps, me.spell or "your main spell")
    end
    if res.talents.soulLink then foot = foot .. " Soul Link is counted as up." end
    foot = foot .. " Not counted: Demonic Brand, mana, utility. Hover a demon for the breakdown."
    demons.foot:ClearAllPoints()
    demons.foot:SetPoint("TOPLEFT", 2, y)
    demons.foot:SetText(foot)
    y = y - (demons.foot:GetStringHeight() or 36)

    return -y
end

Panel.AddTab("demons", "Demons", BuildDemons, RefreshDemons)

----------------------------------------------------------------------
-- Tab: Options
----------------------------------------------------------------------
local options = { checks = {} }
local SIZES = { { "Small", 26 }, { "Medium", 32 }, { "Large", 40 } }

local function BuildOptions(content)
    local y = 0
    local function heading(text)
        local h = UI.Text(content, "GameFontNormal")
        h:SetPoint("TOPLEFT", 2, y - 4)
        h:SetText(text)
        y = y - 24
    end
    local function check(label, get, set)
        local c = UI.Check(content, label, get, function(v) set(v); ns.MarkDirty() end)
        c:SetPoint("TOPLEFT", 0, y)
        options.checks[#options.checks + 1] = c
        y = y - UI.CHECK_SIZE                          -- boxes stacked edge to edge
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
    check("Lock in place (untick to drag them)",
        function() return ns.db.locked end,
        function(v) ns.db.locked = v; ns.Strip.ApplyLock() end)

    local label = UI.Text(content, "GameFontHighlight")
    label:SetPoint("TOPLEFT", 4, y - 8)
    label:SetText("Icon size")
    local sizes = {}
    for _, s in ipairs(SIZES) do sizes[#sizes + 1] = { s[1], s[2] } end
    options.size = UI.Dropdown(content, "iconSize", 120, sizes,
        function() return ns.db.iconSize end,
        function(v) ns.db.iconSize = v; ns.MarkDirty(); Panel.Refresh() end)
    options.size:SetPoint("TOPLEFT", 90, y - 2)
    y = y - 36

    if ns.Options and ns.Options.Ready() then       -- warlocks only: other classes have no button
        heading("Minimap")
        check("Show the minimap button",
            function() return ns.Kit.MinimapShown() end,
            function(v) ns.Kit.SetMinimapShown(v) end)
        y = y - 8
    end

    options.hint = UI.Text(content, "GameFontDisableSmall")
    options.hint:SetPoint("TOPLEFT", 2, y)
    options.hint:SetWidth(INNER - 4)
    options.hint:SetSpacing(2)
    options.hint:SetText("Reminders only appear while something is missing. Click one to cast it (out of combat). "
        .. "Right-click one to quiet it for 10 minutes.")
    options.height = -y
end

local function RefreshOptions()
    for _, c in ipairs(options.checks) do c:Sync() end
    options.size:Sync()
    return options.height + (options.hint:GetStringHeight() or 36)
end

Panel.AddTab("options", "Options", BuildOptions, RefreshOptions)
