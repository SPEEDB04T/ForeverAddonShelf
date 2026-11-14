-- Follow Line: the Follow button every player gets, and the window the line is ordered in.
--
-- The Follow button is a secure button running "/follow <the player ahead>", so
-- the follow starts from the player's own click or key press, which is what the
-- game asks for. The game does not let addons change, show or hide such a button
-- during a fight, so a change that arrives then is applied when the fight ends.
local ADDON, ns = ...
local Line = ns.Line

local UI = {}
ns.UI = UI

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH, PAD, TITLE_H, NOTE_H, ROW_H, BTN_H, GAP = 272, 8, 20, 28, 18, 20, 4
local INNER = WIDTH - PAD * 2
local MAX_ROWS, MAX_BENCH = 40, 10
local BINDING = "CLICK FollowLineJoinButton:LeftButton"

local COLOR = {
    head    = { 1.00, 0.82, 0.00 },
    on      = { 0.40, 0.92, 0.45 },
    off     = { 1.00, 0.32, 0.26 },
    pending = { 1.00, 0.85, 0.30 },
    noaddon = { 0.62, 0.62, 0.62 },
    offline = { 0.50, 0.50, 0.50 },
    out     = { 0.62, 0.62, 0.62 },
    none    = { 0.62, 0.62, 0.62 },
}
local SHORT = {
    head = "leads", on = "following", off = "off the line", pending = "not got it yet",
    noaddon = "no addon", offline = "offline", out = "", none = "",
}

local frame, title, count, note, benchHead, moreNote
local button                    -- the Follow button
local rows, benchRows = {}, {}
local commands = {}

local function ClassColor(class)
    local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then return c.r, c.g, c.b end
    return 0.85, 0.85, 0.85
end

local function HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

local function Border(parent, r, g, b, a)
    local lines = {}
    for i = 1, 4 do
        local t = parent:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, a)
        lines[i] = t
    end
    lines[1]:SetPoint("TOPLEFT"); lines[1]:SetPoint("TOPRIGHT"); lines[1]:SetHeight(1)
    lines[2]:SetPoint("BOTTOMLEFT"); lines[2]:SetPoint("BOTTOMRIGHT"); lines[2]:SetHeight(1)
    lines[3]:SetPoint("TOPLEFT"); lines[3]:SetPoint("BOTTOMLEFT"); lines[3]:SetWidth(1)
    lines[4]:SetPoint("TOPRIGHT"); lines[4]:SetPoint("BOTTOMRIGHT"); lines[4]:SetWidth(1)
    return lines
end

----------------------------------------------------------------------
-- The Follow button
----------------------------------------------------------------------
local function BoundKey()
    if not GetBindingKey then return nil end
    local ok, key = pcall(GetBindingKey, BINDING)
    if ok and type(key) == "string" and key ~= "" then return key end
end

local function ButtonTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -4)
    GameTooltip:AddLine("Follow Line")
    if Line.target then
        GameTooltip:AddLine(("Click to follow %s, the player ahead of you in the line."):format(Line.target), 1, 1, 1, true)
    end
    local key = BoundKey()
    GameTooltip:AddLine(key and ("Your key for this: " .. key .. ".")
        or "Give it a key under Key Bindings > AddOns > Follow Line.", 0.6, 0.6, 0.6, true)
    if not ns.db.locked then GameTooltip:AddLine("Drag to move (not during a fight).", 1, 0.82, 0, true) end
    GameTooltip:Show()
end

local function CreateButton()
    local b = CreateFrame("Button", "FollowLineJoinButton", UIParent, "SecureActionButtonTemplate")
    button = b
    b:SetSize(196, 38)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:SetMovable(true)
    -- the game clicks on the way down or the way up depending on a setting of the player's
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("type", "macro")

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(0.05, 0.07, 0.10, 0.88)
    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(b)
    b.hl:SetColorTexture(1, 1, 1, 0.10)
    b.border = Border(b, ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 1)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(26, 26)
    b.icon:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.icon:SetTexture(ns.ICON)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 7, 0)
    b.label:SetPoint("TOPRIGHT", b, "TOPRIGHT", -6, -6)
    b.label:SetJustifyH("LEFT")
    b.label:SetWordWrap(false)

    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.sub:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 7, 0)
    b.sub:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 6)
    b.sub:SetJustifyH("LEFT")
    b.sub:SetWordWrap(false)

    b:SetScript("OnDragStart", function(self)
        if not ns.db.locked and not ns.InCombat() then
            self:StartMoving()
            self.moving = true
        end
    end)
    b:SetScript("OnDragStop", function(self)
        if not self.moving then return end
        self.moving = nil
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        if type(x) == "number" and type(y) == "number" then ns.db.buttonPoint = { x, y } end
    end)
    b:SetScript("OnEnter", ButtonTooltip)
    b:SetScript("OnLeave", HideTooltip)
    -- the border pulses while the player is off the line
    b:SetScript("OnUpdate", function(self, elapsed)
        local a = 1
        if self.flash then
            self.phase = (self.phase or 0) + elapsed * 5
            a = 0.35 + 0.65 * math.abs(math.sin(self.phase))
        end
        if a ~= self.borderAlpha then
            self.borderAlpha = a
            for _, t in ipairs(self.border) do t:SetAlpha(a) end
        end
    end)
    b:Hide()
end

-- Points the button at the player ahead and shows or hides it. Not possible
-- during a fight: then it is done when the fight ends.
function UI.ApplySecure()
    if not button then return end
    if ns.InCombat() then
        UI.pending = true
        ns.dirty = true
        return
    end
    UI.pending = false
    if UI.layoutPending then UI.ApplyLayout() end
    local target = Line.target
    local m = target and Line.members[target]
    if m and not m.demo then
        button:SetAttribute("macrotext", "/follow " .. target)
    else
        button:SetAttribute("macrotext", nil)
    end
    button.target = target
    if target then button:Show() else button:Hide() end
    ns.dirty = true
end

local function RefreshButton()
    local target = Line.target
    if not button or not target then return end
    local on = Line.OnLine()
    local total = Line.line and #Line.line.order or 0
    local place = ("place %d of %d"):format(Line.place or 0, total)
    local sub
    if UI.pending and button.target ~= target then
        -- the line changed during a fight: the button still points at someone else
        sub = "changes after the fight: /follow " .. target
    elseif on then
        sub = place
    elseif Line.InRange(Line.members[target]) == false then
        sub = "too far away: walk closer first"
    else
        local key = BoundKey()
        sub = place .. (key and (", click or press " .. key) or ", click to fall in")
    end
    button.label:SetText((on and "Following " or "Follow ") .. target)
    button.sub:SetText(sub)
    button:SetAlpha(on and 0.5 or 1)
    button.flash = (Line.dropped and not on) and true or false
end

----------------------------------------------------------------------
-- The window: small parts
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
end

local function Tip(self)
    if not GameTooltip or not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(self.tipTitle or self.tip, 1, 1, 1, not self.tipTitle)
    if self.tipTitle then GameTooltip:AddLine(self.tip, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end

-- A small square button inside a row: move up, move down, take out, put in.
local function MiniButton(row, text, tip, onClick)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(15, 15)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetColorTexture(1, 1, 1, 0.07)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.35)
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("CENTER", b, "CENTER", 0, 0)
    label:SetText(text)
    b.tip = tip
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", HideTooltip)
    b:SetScript("OnClick", function()
        if row.member then ns.Safe(onClick, row.member.name) end
        ns.dirty = true
    end)
    return b
end

-- One of the six buttons under the list.
local function CommandButton(label, tipTitle, tip, onClick)
    local b = CreateFrame("Button", nil, frame)
    b:SetSize((INNER - GAP * 2) / 3, BTN_H)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints(b)
    b.bg:SetColorTexture(1, 1, 1, 0.08)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(b)
    hl:SetColorTexture(1, 1, 1, 0.12)
    b.border = Border(b, 0, 0, 0, 1)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.label:SetText(label)
    b.tipTitle, b.tip = tipTitle, tip
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", HideTooltip)
    b:SetScript("OnClick", function()
        ns.Safe(onClick)
        ns.dirty = true
    end)
    commands[#commands + 1] = b
    return b
end

local function RowTooltip(row)
    local m = row.member
    if not m or not GameTooltip then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local r, g, b = ClassColor(m.class)
    GameTooltip:AddLine(m.name, r, g, b)
    local text, st = Line.Describe(m)
    local c = COLOR[st] or COLOR.none
    GameTooltip:AddLine(text:sub(1, 1):upper() .. text:sub(2) .. ".", c[1], c[2], c[3], true)
    if m.isPlayer or m.demo then
        -- nothing to add
    elseif m.hasAddon then
        GameTooltip:AddLine("Has Follow Line " .. tostring(m.version or ""), 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine("No Follow Line seen: they don't get a Follow button, and the addon can't tell whether they follow.", 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

-- A line of the window: place, name, state, and the buttons that move it.
local function NewRow(bench)
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_H)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(row)
    hl:SetColorTexture(1, 1, 1, 0.07)

    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.num:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.num:SetWidth(16)
    row.num:SetJustifyH("RIGHT")

    if bench then
        row.add = MiniButton(row, "+", "Put them at the end of the line", function(name) Line.Add(name) end)
        row.add:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    else
        row.rem = MiniButton(row, "x", "Take them out of the line", function(name) Line.Remove(name) end)
        row.rem:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.down = MiniButton(row, "v", "Move back one place", function(name) Line.Move(name, 1) end)
        row.down:SetPoint("RIGHT", row.rem, "LEFT", -1, 0)
        row.up = MiniButton(row, "^", "Move forward one place", function(name) Line.Move(name, -1) end)
        row.up:SetPoint("RIGHT", row.down, "LEFT", -1, 0)
    end

    row.state = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.state:SetPoint("RIGHT", bench and row.add or row.up, "LEFT", -5, 0)
    row.state:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.num, "RIGHT", 5, 0)
    row.name:SetPoint("RIGHT", row.state, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", StartMove)
    row:SetScript("OnDragStop", StopMove)
    row:SetScript("OnEnter", RowTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:Hide()
    return row
end

-- top = distance from the top of the window
local function Place(widget, top)
    widget:ClearAllPoints()
    widget:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -top)
    widget:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -top)
end

local function FillRow(row, m, number)
    row.member = m
    local r, g, b = ClassColor(m.class)
    local st = Line.Status(m)
    if st == "offline" then r, g, b = 0.5, 0.5, 0.5 end
    row.num:SetText(number and (number .. ".") or "")
    row.name:SetText(m.name .. (m.isPlayer and " (you)" or ""))
    row.name:SetTextColor(r, g, b)
    local c = COLOR[st] or COLOR.none
    row.state:SetText(SHORT[st] or "")
    row.state:SetTextColor(c[1], c[2], c[3])
    row:Show()
end

----------------------------------------------------------------------
-- Building the window
----------------------------------------------------------------------
function UI.ApplyLayout()
    if not frame then return end
    local db = ns.db
    frame:SetScale(db.scale or 1)
    frame:ClearAllPoints()
    local p = db.point
    if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", p[1], p[2])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
    end
    -- the Follow button can't be moved during a fight
    if ns.InCombat() then
        UI.layoutPending = true
        UI.pending = true
        return
    end
    UI.layoutPending = false
    button:SetScale(db.scale or 1)
    button:ClearAllPoints()
    local bp = db.buttonPoint
    if type(bp) == "table" and type(bp[1]) == "number" and type(bp[2]) == "number" then
        button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", bp[1], bp[2])
    else
        button:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    end
end

function UI.Create()
    CreateButton()

    frame = CreateFrame("Frame", "FollowLineFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(WIDTH, 120)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
        frame:SetBackdropColor(0.05, 0.06, 0.08, 0.90)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD + 1)
    icon:SetTexture(ns.ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    title:SetText("Follow Line")

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD + 2, -PAD + 1)
    local closeHl = close:CreateTexture(nil, "HIGHLIGHT")
    closeHl:SetAllPoints(close)
    closeHl:SetColorTexture(1, 0.3, 0.3, 0.35)
    local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeText:SetPoint("CENTER", close, "CENTER", 0, 0)
    closeText:SetText("x")
    close.tip = "Close (/line opens it again)"
    close:SetScript("OnEnter", Tip)
    close:SetScript("OnLeave", HideTooltip)
    close:SetScript("OnClick", function()
        ns.db.open = false
        ns.dirty = true
        if ns.Kit then ns.Kit.Sync() end
    end)

    count = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("RIGHT", close, "LEFT", -6, 0)
    count:SetJustifyH("RIGHT")

    note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(PAD + TITLE_H))
    note:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(PAD + TITLE_H))
    note:SetHeight(NOTE_H - 4)
    note:SetJustifyH("LEFT")
    note:SetJustifyV("TOP")
    note:SetWordWrap(true)

    benchHead = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    benchHead:SetJustifyH("LEFT")
    benchHead:SetText("Not in the line")
    benchHead:Hide()

    moreNote = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moreNote:SetJustifyH("LEFT")
    moreNote:Hide()

    CommandButton("Call line", "Call line", "Sends this order to everyone in the group with the addon. The first player leads; each of the others gets a Follow button for the player ahead of them.",
        function() Line.Call() end)
    CommandButton("Regroup", "Regroup", "Nudges everyone who is off the line: their Follow button flashes and they hear a sound.",
        function() Line.Regroup() end)
    CommandButton("Stop", "Stop", "Ends the line for everyone. Players who are following keep walking until they move by themselves.",
        function() Line.Stop() end)
    CommandButton("By distance", "By distance", "Keeps the leader and orders everyone else by who stands nearest, so nobody has to cross the group to find their place.",
        function() Line.ByDistance() end)
    CommandButton("Reverse", "Reverse", "Turns the order around: the last player leads.",
        function() Line.Reverse() end)
    CommandButton("Announce", "Announce", "Posts the order in group chat, for players without the addon.",
        function() Line.Announce() end)

    UI.ApplyLayout()
    frame:Hide()
end

----------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------
local function NoteText()
    local line = Line.line
    if not (Line.grouped or Line.demo) then
        return "You're not in a group. /line demo shows how it looks."
    end
    if not line then
        return "Order the players (the first one leads), then press Call line."
    end
    if Line.DraftDiffers() then
        return "|cffffd100Order changed.|r Press Call line to send it to the group."
    end
    local by = (line.by == ns.playerName) and "you" or line.by
    if Line.place == 1 then
        return ("Called by %s. You lead."):format(by)
    elseif Line.target then
        return ("Called by %s. You follow %s."):format(by, Line.target)
    end
    return ("Called by %s. You are not in it."):format(by)
end

function UI.Refresh()
    if not frame then return end
    RefreshButton()
    if not ns.db.open then
        if frame:IsShown() then frame:Hide() end
        return
    end

    local line = Line.line
    if line then
        local on, followers = Line.Summary()
        local c = (followers > 0 and on == followers) and COLOR.on or COLOR.pending
        count:SetText(("|cff%02x%02x%02x%d / %d|r following"):format(c[1] * 255, c[2] * 255, c[3] * 255, on, followers))
    else
        count:SetText("")
    end
    note:SetText(NoteText())

    local top = PAD + TITLE_H + NOTE_H
    local shown = 0
    for i, name in ipairs(Line.draft) do
        local m = Line.members[name]
        if m and shown < MAX_ROWS then
            shown = shown + 1
            local row = rows[shown]
            if not row then
                row = NewRow(false)
                rows[shown] = row
            end
            Place(row, top)
            FillRow(row, m, i)
            top = top + ROW_H
        end
    end
    for i = shown + 1, #rows do
        rows[i].member = nil
        rows[i]:Hide()
    end

    local bench = Line.Bench()
    local benched = 0
    if #bench > 0 then
        top = top + 4
        Place(benchHead, top)
        benchHead:Show()
        top = top + ROW_H - 3
        for _, name in ipairs(bench) do
            local m = Line.members[name]
            if m and benched < MAX_BENCH then
                benched = benched + 1
                local row = benchRows[benched]
                if not row then
                    row = NewRow(true)
                    benchRows[benched] = row
                end
                Place(row, top)
                FillRow(row, m, nil)
                top = top + ROW_H
            end
        end
    else
        benchHead:Hide()
    end
    for i = benched + 1, #benchRows do
        benchRows[i].member = nil
        benchRows[i]:Hide()
    end
    if #bench > benched then
        Place(moreNote, top + 1)
        moreNote:SetText(("+%d more"):format(#bench - benched))
        moreNote:Show()
        top = top + ROW_H - 3
    else
        moreNote:Hide()
    end

    -- "Call line" stands out while there is something to send
    local call = commands[1]
    local ready = (Line.grouped or Line.demo) and (not line or Line.DraftDiffers())
    if ready then
        call.bg:SetColorTexture(ns.ACCENT[1], ns.ACCENT[2], ns.ACCENT[3], 0.35)
    else
        call.bg:SetColorTexture(1, 1, 1, 0.08)
    end

    top = top + 6
    local width = (INNER - GAP * 2) / 3
    for i, b in ipairs(commands) do
        local col, rowIndex = (i - 1) % 3, math.floor((i - 1) / 3)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (width + GAP), -(top + rowIndex * (BTN_H + GAP)))
    end
    top = top + BTN_H * 2 + GAP

    frame:SetHeight(top + PAD)
    if not frame:IsShown() then frame:Show() end
end
