-- Healthstone Tracker: the window. One line per player: stone icon, name, state.
-- Under the list: who carries a soulstone, and each warlock's own soulstone.
local ADDON, ns = ...
local issecret = ns.issecret

local UI = {}
ns.UI = UI

-- The window is built like the game's tooltip (SharedTooltipTemplates.xml on
-- Blizzard's forever branch): the TooltipBorderedFrameTemplate panel, a
-- GameTooltipHeaderText first line, GameTooltipText lines with a 2 px gap,
-- 12 px line icons, 10 px from every edge. Nothing a tooltip lacks: no title
-- icon, no divider, no row highlight.
-- Minimize: a 16 x 16 button at the right of the title line, the game's own tracker header
-- button (ObjectiveTrackerModuleMinimizeButtonTemplate in Blizzard_ObjectiveTracker/
-- Blizzard_ObjectiveTrackerModule.xml, branch forever): atlases
-- ui-questtrackerbutton-secondary-collapse / -expand (and -pressed), highlight
-- ui-questtrackerbutton-yellow-highlight (ADD). Minimized, the window is its title line
-- and the "have / total" count only.
local BACKDROP = {      -- only if the client lacks TooltipBorderedFrameTemplate
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}
local PAD = 10          -- tooltip text inset
local LINE_GAP = 2      -- tooltip line spacing
local ICON = 12         -- TooltipTextureTemplate
local TITLE_H = 14 + LINE_GAP   -- GameTooltipHeaderText is 14 px
local ROW_H = 12 + LINE_GAP     -- GameTooltipText is 12 px
local MIN_W, MAX_W, MAX_ROWS = 150, 320, 25
local BTN = 16          -- the game's minimize button size

-- The game's own font colours; the numbers are only for a client without them.
local function GameColor(name, r, g, b)
    local c = _G[name]
    if type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { r, g, b }
end
-- The tooltip's own colour words (GameTooltip_SetTitle / AddHighlightLine,
-- AddNormalLine, AddErrorLine, AddDisabledLine, AddInstructionLine):
-- white is the value, grey is "not now / not known", red is "missing".
local COLOR = {
    white = GameColor("HIGHLIGHT_FONT_COLOR", 1.0, 1.0, 1.0),
    gold  = GameColor("NORMAL_FONT_COLOR", 1.0, 0.82, 0.0),
    red   = GameColor("RED_FONT_COLOR", 1.0, 0.125, 0.125),
    grey  = GameColor("DISABLED_FONT_COLOR", 0.5, 0.5, 0.5),
    green = GameColor("GREEN_FONT_COLOR", 0.1, 1.0, 0.1),
}
-- what each healthstone state says, in those words
local STATE_COLOR = { has = COLOR.white, given = COLOR.white, none = COLOR.red, used = COLOR.grey, unknown = COLOR.grey }
local HINT = COLOR.grey         -- grey explanation lines in tooltips
local ACTION = COLOR.green      -- "Click: ..." lines, GameTooltip_AddInstructionLine
-- the soulstone item, next to the buff icon in ns.SOUL_ICON
local SOUL_ITEM_ICON = "Interface\\Icons\\INV_Misc_Orb_04"
local SOUL_GAP = ROW_H  -- one blank tooltip line above the soulstones

local frame, title, count, note, toggle
local rows = {}
local soulRows = {}

local function ClassColor(class)
    local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then return c.r, c.g, c.b end
    return COLOR.white[1], COLOR.white[2], COLOR.white[3]
end

local function AddLine(text, c, wrap)
    GameTooltip:AddLine(text, c[1], c[2], c[3], wrap)
end

local function Offline(m)
    if m.demo or not m.unit or not UnitIsConnected then return false end
    local ok, on = pcall(UnitIsConnected, m.unit)
    return ok and not issecret(on) and on == false
end

----------------------------------------------------------------------
-- Who is listed
----------------------------------------------------------------------
function UI.ShouldShow()
    local G = ns.Group
    if not ns.db or not ns.db.shown then return false end
    if G.demo then return true end
    if not G.grouped then return false end
    return (ns.db.always or G.warlocks > 0) and true or false
end

local function MissingOnly()
    local filter = ns.db.filter
    if filter == "missing" then return true end
    if filter == "all" then return false end
    return ns.Group.total > 10
end

-- What the right-hand column says for one player.
local function StateText(m, st, cd)
    if st == "has" then
        local label = ns.StoneLabel(ns.Group.ItemOf(m))
        -- carried but can't be used yet: grey, like a disabled line
        if cd then return label .. " " .. ns.Clock(cd), COLOR.grey end
        return label, COLOR.white
    elseif st == "given" then
        return "given", COLOR.white
    elseif st == "none" then
        return cd and ("none " .. ns.Clock(cd)) or "none", COLOR.red
    elseif st == "used" then
        return cd and ("used " .. ns.Clock(cd)) or "used", COLOR.grey
    end
    return "?", COLOR.grey
end

----------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------
local function RowTooltip(row)
    local m = row.member
    if not m or not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local r, g, b = ClassColor(m.class)
    GameTooltip:AddLine(m.name, r, g, b)
    local text, st = ns.Group.Describe(m)
    local c = STATE_COLOR[st] or COLOR.grey
    GameTooltip:AddLine(text:sub(1, 1):upper() .. text:sub(2), c[1], c[2], c[3], true)
    if m.isPlayer then
        -- nothing to add
    elseif m.hasAddon then
        AddLine("Has Healthstone Tracker " .. tostring(m.version or ""), HINT)
    else
        AddLine("No addon: worked out from trades and uses seen.", HINT, true)
    end
    local soul = ns.Group.DescribeSoul(m)
    if soul then AddLine("Has a " .. soul .. ".", COLOR.white, true) end
    if ns.isWarlock and ns.db.clickTrade and not m.isPlayer and not m.demo then
        AddLine("Click: open a trade and offer your healthstone.", ACTION)
    end
    GameTooltip:Show()
end

local function TitleTooltip(self)
    if not GameTooltip then return end
    local have, need, unknown, total = ns.Group.Summary()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    AddLine("Healthstone Tracker", COLOR.white)     -- GameTooltip_SetTitle's colour
    AddLine(("%d of %d have one, %d need one, %d not known."):format(have, total, need, unknown), COLOR.white, true)
    AddLine("Players with the addon report their own bags. The others are worked out from trades and uses seen.", HINT, true)
    AddLine("Drag to move. Right-click: list everyone / only the missing. /hst help for more.", ACTION, true)
    GameTooltip:Show()
end

local function SoulTooltip(row)
    if not GameTooltip then return end
    local m, kind = row.member, row.kind
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if kind == "head" then
        AddLine("Soulstones", COLOR.white)
        AddLine("Who carries a soulstone and for how long, then each warlock's own stone: ready, on cooldown, or none in the bags.", COLOR.white, true)
        AddLine("Read from everyone's buffs, so it works for players without the addon. /hst soul hides this part.", HINT, true)
    elseif m then
        local r, g, b = ClassColor(m.class)
        GameTooltip:AddLine(m.name, r, g, b)
        if kind == "holder" then
            local text = ns.Group.DescribeSoul(m)
            if text then AddLine("Has a " .. text .. ".", COLOR.white, true) end
            if row.dead then AddLine("Dead: can use it to come back to life.", COLOR.white, true) end
        else
            local text = ns.Group.DescribeSoulStone(m)
            AddLine(text:sub(1, 1):upper() .. text:sub(2) .. ".", COLOR.white, true)
        end
    end
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

----------------------------------------------------------------------
-- Building the window
----------------------------------------------------------------------
local function SavePosition()
    local left, top = frame:GetLeft(), frame:GetTop()
    if type(left) == "number" and type(top) == "number" then
        ns.db.point = { left, top }
    end
end

local function StartMove()
    if not ns.db.locked then frame:StartMoving() end
end

local function StopMove()
    frame:StopMovingOrSizing()
    SavePosition()
    UI.ApplyLayout()
end

-- A line of the window, laid out like a tooltip double line with a line
-- texture: 12 px icon, name on the left (TextLeft), state on the right
-- (TextRight), both GameTooltipText on the ARTWORK layer.
local function NewRow()
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_H)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON, ICON)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon = icon

    local state = row:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    state:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    state:SetJustifyH("RIGHT")
    row.state = state

    local name = row:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    name:SetPoint("RIGHT", state, "LEFT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", StartMove)
    row:SetScript("OnDragStop", StopMove)
    row:SetScript("OnLeave", HideTooltip)
    row:Hide()
    return row
end

-- top = distance from the top of the window
local function PlaceRow(row, top)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -top)
end

local function MakeRow(i)
    local row = NewRow()
    PlaceRow(row, PAD + TITLE_H + (i - 1) * ROW_H)
    row:SetScript("OnEnter", RowTooltip)
    row:SetScript("OnClick", function(self)
        if ns.isWarlock and ns.db.clickTrade and self.member then ns.Safe(ns.Trade.Offer, self.member) end
    end)
    rows[i] = row
    return row
end

local function MakeSoulRow(i)
    local row = NewRow()
    row:SetScript("OnEnter", SoulTooltip)
    if i == 1 then
        -- the heading: a plain gold line, the way a tooltip names a section
        row.icon:Hide()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    end
    soulRows[i] = row
    return row
end

-- What the right-hand column says for a warlock's own soulstone.
local function SoulStoneText(m)
    local st, left = ns.Group.SoulStatus(m)
    if st == "ready" then return "ready", COLOR.white, true end
    if st == "cooldown" then return "cd " .. ns.Clock(left), COLOR.grey, false end
    if st == "nostone" then return "no stone", COLOR.red, false end
    return "?", COLOR.grey, false
end

-- The soulstone part under the list: a heading, who carries one, then the
-- warlocks. Returns the height it took.
local function DrawSouls(top)
    local G = ns.Group
    local holders = ns.db.soul and G.SoulHolders() or {}
    local locks = ns.db.soul and G.SoulWarlocks() or {}
    local used = 0
    if #holders > 0 or #locks > 0 then
        local function line(kind, m)
            used = used + 1
            local row = soulRows[used] or MakeSoulRow(used)
            PlaceRow(row, top + SOUL_GAP + (used - 1) * ROW_H)
            row.kind, row.member, row.dead = kind, m, false
            if m then
                local r, g, b = ClassColor(m.class)
                row.name:SetText(m.name)
                row.name:SetTextColor(r, g, b)
            end
            row.icon:SetDesaturated(false)
            row:Show()
            return row
        end

        -- heading: the section's name only; the lines under it say the rest
        local head = line("head")
        head.name:SetText("Soulstones")
        head.name:SetTextColor(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3])
        head.state:SetText("")

        for _, h in ipairs(holders) do
            local row = line("holder", h.m)
            row.dead = h.dead and true or false
            row.icon:SetTexture(ns.SOUL_ICON)
            row.state:SetText(h.dead and "can res" or ns.Clock(h.left))
            row.state:SetTextColor(COLOR.white[1], COLOR.white[2], COLOR.white[3])
        end
        for _, m in ipairs(locks) do
            local row = line("warlock", m)
            local text, color, ready = SoulStoneText(m)
            row.icon:SetTexture(SOUL_ITEM_ICON)
            -- not ready: the game's "unavailable" look, desaturated
            row.icon:SetDesaturated(not ready)
            row.state:SetText(text)
            row.state:SetTextColor(color[1], color[2], color[3])
        end
    end
    for i = used + 1, #soulRows do
        soulRows[i].member, soulRows[i].kind = nil, nil
        soulRows[i]:Hide()
    end
    return used > 0 and (SOUL_GAP + used * ROW_H) or 0
end

-- Width of a font string's whole text, or 0 where the client can't say.
local function TextWidth(fs)
    if not fs or not fs:IsShown() then return 0 end
    local f = fs.GetUnboundedStringWidth or fs.GetStringWidth
    local ok, w = pcall(f, fs)
    return (ok and type(w) == "number") and w or 0
end

-- Like a tooltip, the window is as wide as its widest line.
local function FitWidth()
    local widest = TextWidth(title) + 12 + TextWidth(count)
    local function rowWidth(row)
        if not row:IsShown() then return end
        local w = TextWidth(row.name) + 12 + TextWidth(row.state)
        if row.icon:IsShown() then w = w + ICON + 4 end
        if w > widest then widest = w end
    end
    for _, row in ipairs(rows) do rowWidth(row) end
    for _, row in ipairs(soulRows) do rowWidth(row) end
    if TextWidth(note) > widest then widest = TextWidth(note) end
    local w = math.ceil(widest) + BTN + 4 + PAD * 2
    frame:SetWidth(math.max(MIN_W, math.min(MAX_W, w)))
end

function UI.ApplyLayout()
    if not frame then return end
    frame:SetScale(ns.db.scale or 1)
    frame:ClearAllPoints()
    local p = ns.db.point
    if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
    else
        frame:SetPoint("LEFT", UIParent, "LEFT", 260, 60)
    end
end

-- The game's frame-that-looks-like-a-tooltip: TooltipBorderedFrameTemplate
-- (tooltip nine-slice, background at 0.8). A client without it gets the old
-- tooltip border and background files instead.
local function NewWindow()
    local ok, f = pcall(CreateFrame, "Frame", "HealthstoneTrackerFrame", UIParent, "TooltipBorderedFrameTemplate")
    if ok and f and f.NineSlice then return f end
    f = CreateFrame("Frame", "HealthstoneTrackerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if f.SetBackdrop then
        f:SetBackdrop(BACKDROP)
        local bg, edge = TOOLTIP_DEFAULT_BACKGROUND_COLOR, TOOLTIP_DEFAULT_COLOR
        if type(bg) == "table" and bg.r then f:SetBackdropColor(bg.r, bg.g, bg.b, 0.8) else f:SetBackdropColor(0.09, 0.09, 0.19, 0.8) end
        if type(edge) == "table" and edge.r then f:SetBackdropBorderColor(edge.r, edge.g, edge.b, 1) end
    end
    return f
end

-- LookShots (a helper on SuccuDev's machine only) takes one game screenshot
-- of each listed frame per version; harmless when it is not installed. The
-- hover tooltips are the game's own GameTooltip, and the options window and
-- minimap button are the shared kit's, which lists them itself.
LookShotsTargets = type(LookShotsTargets) == "table" and LookShotsTargets or {}
LookShotsTargets[ADDON] = {
    version = ns.VERSION,
    frames = {
        { label = "window", frame = function() return frame end },
    },
}

function UI.ToggleLook()
    if not toggle then return end
    local what = (ns.db and ns.db.minimized) and "expand" or "collapse"
    pcall(toggle.SetNormalAtlas, toggle, "ui-questtrackerbutton-secondary-" .. what)
    pcall(toggle.SetPushedAtlas, toggle, "ui-questtrackerbutton-secondary-" .. what .. "-pressed")
end

function UI.Create()
    frame = NewWindow()
    frame:SetSize(MIN_W, TITLE_H + PAD * 2)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
    frame:SetScript("OnEnter", TitleTooltip)
    frame:SetScript("OnLeave", HideTooltip)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.db.filter = MissingOnly() and "all" or "missing"
            ns.dirty = true
        end
    end)
    -- first line: TextLeft1 / TextRight1, GameTooltipHeaderText, white
    title = frame:CreateFontString(nil, "ARTWORK", "GameTooltipHeaderText")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    title:SetJustifyH("LEFT")
    title:SetTextColor(COLOR.white[1], COLOR.white[2], COLOR.white[3])
    title:SetText("Healthstones")

    count = frame:CreateFontString(nil, "ARTWORK", "GameTooltipHeaderText")
    count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + BTN + 4), -PAD)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(COLOR.white[1], COLOR.white[2], COLOR.white[3])

    -- the game's tracker minimize button, right of the count
    toggle = CreateFrame("Button", "HealthstoneTrackerMinimizeButton", frame)
    toggle:SetSize(BTN, BTN)
    toggle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(PAD - 1))
    pcall(toggle.SetHighlightAtlas, toggle, "ui-questtrackerbutton-yellow-highlight", "ADD")
    toggle:SetScript("OnClick", function()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
        ns.SetMinimized(not ns.db.minimized)
    end)
    UI.ToggleLook()

    -- one line under the list: "+3 more", or "everyone has one" (a disabled line)
    note = frame:CreateFontString(nil, "ARTWORK", "GameTooltipText")
    note:SetJustifyH("LEFT")
    note:SetTextColor(COLOR.grey[1], COLOR.grey[2], COLOR.grey[3])
    note:Hide()

    UI.ApplyLayout()
    frame:Hide()
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------
function UI.Refresh()
    if not frame then return end
    if not UI.ShouldShow() then
        if frame:IsShown() then frame:Hide() end
        return
    end
    local G = ns.Group
    local have, need, unknown, total = G.Summary()
    count:SetText(("%d / %d"):format(have, total))
    UI.ToggleLook()

    if ns.db.minimized then
        -- the title line and the count only
        for i = 1, #rows do rows[i].member = nil rows[i]:Hide() end
        for i = 1, #soulRows do soulRows[i].member, soulRows[i].kind = nil, nil soulRows[i]:Hide() end
        note:Hide()
        frame:SetHeight(PAD * 2 + TITLE_H - LINE_GAP)
        FitWidth()
        if not frame:IsShown() then frame:Show() end
        return
    end

    local missingOnly = MissingOnly()
    local shown, hidden = 0, 0
    for _, m in ipairs(G.SortedMembers()) do
        local st, cd = G.Status(m)
        local listed = not missingOnly or st == "none" or st == "used" or st == "unknown"
        if listed and shown < MAX_ROWS then
            shown = shown + 1
            local row = rows[shown] or MakeRow(shown)
            row.member = m
            local r, g, b = ClassColor(m.class)
            local off = Offline(m)
            if off then r, g, b = COLOR.grey[1], COLOR.grey[2], COLOR.grey[3] end
            row.name:SetText(m.name .. (off and " (offline)" or ""))
            row.name:SetTextColor(r, g, b)
            local text, color = StateText(m, st, cd)
            row.state:SetText(text)
            row.state:SetTextColor(color[1], color[2], color[3])
            local carries = (st == "has" or st == "given")
            row.icon:SetTexture(ns.StoneIcon(carries and G.ItemOf(m) or nil))
            -- no stone: the game's "unavailable" look, desaturated
            row.icon:SetDesaturated(not carries)
            row:Show()
        elseif listed then
            hidden = hidden + 1
        end
    end
    for i = shown + 1, #rows do
        rows[i].member = nil
        rows[i]:Hide()
    end

    local lines = shown
    local text
    if hidden > 0 then
        text = ("+%d more"):format(hidden)
    elseif shown == 0 then
        text = "Everyone has one."
    elseif missingOnly and shown < total then
        text = ("%d with a stone not listed"):format(total - shown)
    end
    if text then
        note:ClearAllPoints()
        note:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + TITLE_H + lines * ROW_H + 1))
        note:SetText(text)
        note:Show()
        lines = lines + 1
    else
        note:Hide()
    end

    local soulHeight = DrawSouls(PAD + TITLE_H + lines * ROW_H)
    -- the last line has no gap under it, as in a tooltip
    frame:SetHeight(PAD * 2 + TITLE_H + lines * ROW_H + soulHeight - LINE_GAP)
    FitWidth()
    if not frame:IsShown() then frame:Show() end
end
