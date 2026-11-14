-- Healthstone Tracker: the window. One line per player: stone icon, name, state.
-- Under the list: who carries a soulstone, and each warlock's own soulstone.
local ADDON, ns = ...
local issecret = ns.issecret

local UI = {}
ns.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, PAD, TITLE_H, ROW_H, MAX_ROWS = 178, 6, 18, 16, 25

local COLOR = {
    has     = { 0.40, 0.92, 0.45 },
    given   = { 0.62, 0.82, 0.62 },
    none    = { 1.00, 0.32, 0.26 },
    used    = { 1.00, 0.62, 0.22 },
    unknown = { 0.62, 0.62, 0.62 },
    cooling = { 1.00, 0.85, 0.30 },
    gold    = { 1.00, 0.82, 0.00 },
    canRes  = { 0.45, 0.90, 1.00 },
}
-- the soulstone item, next to the buff icon in ns.SOUL_ICON
local SOUL_ITEM_ICON = "Interface\\Icons\\INV_Misc_Orb_04"
local SOUL_GAP = 4      -- space above the soulstone part

local frame, title, count, note
local rows = {}
local soulRows = {}

local function Hex(c)
    return ("|cff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end

local function ClassColor(class)
    local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then return c.r, c.g, c.b end
    return 0.85, 0.85, 0.85
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
        if cd then return label .. " " .. ns.Clock(cd), COLOR.cooling end
        return label, COLOR.has
    elseif st == "given" then
        return "given", COLOR.given
    elseif st == "none" then
        return cd and ("none " .. ns.Clock(cd)) or "none", COLOR.none
    elseif st == "used" then
        return cd and ("used " .. ns.Clock(cd)) or "used", COLOR.used
    end
    return "?", COLOR.unknown
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
    local c = COLOR[st] or COLOR.unknown
    GameTooltip:AddLine(text:sub(1, 1):upper() .. text:sub(2), c[1], c[2], c[3], true)
    if m.isPlayer then
        -- nothing to add
    elseif m.hasAddon then
        GameTooltip:AddLine("Has Healthstone Tracker " .. tostring(m.version or ""), 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine("No addon: worked out from trades and uses seen.", 0.6, 0.6, 0.6, true)
    end
    local soul = ns.Group.DescribeSoul(m)
    if soul then GameTooltip:AddLine("Has a " .. soul .. ".", 0.72, 0.55, 1, true) end
    if ns.isWarlock and ns.db.clickTrade and not m.isPlayer and not m.demo then
        GameTooltip:AddLine("Click: open a trade and offer your healthstone.", 1, 0.82, 0)
    end
    GameTooltip:Show()
end

local function TitleTooltip(self)
    if not GameTooltip then return end
    local have, need, unknown, total = ns.Group.Summary()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Healthstone Tracker")
    GameTooltip:AddLine(("%d of %d have one, %d need one, %d not known."):format(have, total, need, unknown), 1, 1, 1, true)
    GameTooltip:AddLine("Players with the addon report their own bags. The others are worked out from trades and uses seen.", 0.6, 0.6, 0.6, true)
    GameTooltip:AddLine("Drag to move. Right-click: list everyone / only the missing. /hst help for more.", 1, 0.82, 0, true)
    GameTooltip:Show()
end

local function SoulTooltip(row)
    if not GameTooltip then return end
    local m, kind = row.member, row.kind
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if kind == "head" then
        GameTooltip:AddLine("Soulstones")
        GameTooltip:AddLine("Who carries a soulstone and for how long, then each warlock's own stone: ready, on cooldown, or none in the bags.", 1, 1, 1, true)
        GameTooltip:AddLine("Read from everyone's buffs, so it works for players without the addon. /hst soul hides this part.", 0.6, 0.6, 0.6, true)
    elseif m then
        local r, g, b = ClassColor(m.class)
        GameTooltip:AddLine(m.name, r, g, b)
        if kind == "holder" then
            local text = ns.Group.DescribeSoul(m)
            if text then GameTooltip:AddLine("Has a " .. text .. ".", 1, 1, 1, true) end
            if row.dead then
                GameTooltip:AddLine("Dead: can use it to come back to life.", COLOR.canRes[1], COLOR.canRes[2], COLOR.canRes[3], true)
            end
        else
            local text = ns.Group.DescribeSoulStone(m)
            GameTooltip:AddLine(text:sub(1, 1):upper() .. text:sub(2) .. ".", 1, 1, 1, true)
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

-- A line of the window: icon, name on the left, state on the right.
local function NewRow()
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_H)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 1, 1, 0.08)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ROW_H - 3, ROW_H - 3)
    icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    state:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    state:SetJustifyH("RIGHT")
    row.state = state

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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
    soulRows[i] = row
    return row
end

-- What the right-hand column says for a warlock's own soulstone.
local function SoulStoneText(m)
    local st, left = ns.Group.SoulStatus(m)
    if st == "ready" then return "ready", COLOR.has, true end
    if st == "cooldown" then return "cd " .. ns.Clock(left), COLOR.cooling, false end
    if st == "nostone" then return "no stone", COLOR.used, false end
    return "?", COLOR.unknown, false
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
            row.icon:SetAlpha(1)
            row:Show()
            return row
        end

        local head = line("head")
        head.icon:SetTexture(ns.SOUL_ICON)
        head.name:SetText("Soulstones")
        head.name:SetTextColor(COLOR.gold[1], COLOR.gold[2], COLOR.gold[3])
        local c = (#holders > 0) and COLOR.has or COLOR.none
        head.state:SetText((#holders > 0) and (#holders .. " up") or "none up")
        head.state:SetTextColor(c[1], c[2], c[3])

        for _, h in ipairs(holders) do
            local row = line("holder", h.m)
            row.dead = h.dead and true or false
            row.icon:SetTexture(ns.SOUL_ICON)
            local color = (h.dead and COLOR.canRes) or (h.left < 300 and COLOR.cooling) or COLOR.has
            row.state:SetText(h.dead and "can res" or ns.Clock(h.left))
            row.state:SetTextColor(color[1], color[2], color[3])
        end
        for _, m in ipairs(locks) do
            local row = line("warlock", m)
            local text, color, ready = SoulStoneText(m)
            row.icon:SetTexture(SOUL_ITEM_ICON)
            row.icon:SetDesaturated(not ready)
            row.icon:SetAlpha(ready and 1 or 0.4)
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

function UI.Create()
    frame = CreateFrame("Frame", "HealthstoneTrackerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(WIDTH, TITLE_H + PAD * 2)
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
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        frame:SetBackdropColor(0.05, 0.04, 0.07, 0.82)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    icon:SetTexture(ns.DEFAULT_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    title:SetText("Healthstones")

    count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -PAD - 1)
    count:SetJustifyH("RIGHT")

    -- one line under the list: "+3 more", or "everyone has one"
    note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetJustifyH("LEFT")
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
    local c = (need > 0 and COLOR.none) or (unknown > 0 and COLOR.cooling) or COLOR.has
    count:SetText(("%s%d|r / %d"):format(Hex(c), have, total))

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
            if off then r, g, b = 0.5, 0.5, 0.5 end
            row.name:SetText(m.name .. (off and " (offline)" or ""))
            row.name:SetTextColor(r, g, b)
            local text, color = StateText(m, st, cd)
            row.state:SetText(text)
            row.state:SetTextColor(color[1], color[2], color[3])
            local carries = (st == "has" or st == "given")
            row.icon:SetTexture(ns.StoneIcon(carries and G.ItemOf(m) or nil))
            row.icon:SetDesaturated(not carries)
            row.icon:SetAlpha(carries and 1 or 0.3)
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
        note:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + TITLE_H + lines * ROW_H + 2))
        note:SetText(text)
        note:Show()
        lines = lines + 1
    else
        note:Hide()
    end

    local soulHeight = DrawSouls(PAD + TITLE_H + lines * ROW_H)
    frame:SetHeight(PAD * 2 + TITLE_H + lines * ROW_H + soulHeight)
    if not frame:IsShown() then frame:Show() end
end
