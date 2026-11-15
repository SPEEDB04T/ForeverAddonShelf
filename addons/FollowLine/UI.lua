-- Follow Line: the Follow button every player gets, and the window the line is ordered in.
--
-- Both are built from the game's own parts so they sit in its UI: the Follow
-- button is an action button (ActionButtonTemplate's slot, mask, frame, pushed,
-- highlight and checked art) with its name beside it, and the window is the game's basic frame
-- with an inset, panel buttons and the quest log's row highlight.
--
-- The Follow button is a secure button running "/follow <the player ahead>", so
-- the follow starts from the player's own click or key press, which is what the
-- game asks for. The game does not let addons change, show or hide such a button
-- during a fight, so a change that arrives then is applied when the fight ends.
local ADDON, ns = ...
local Line = ns.Line

local UI = {}
ns.UI = UI

local WIDTH = 284
local LEFT, RIGHT, TOP, BOTTOM = 12, 14, 30, 10     -- inside the frame's inset
local NOTE_H, COUNT_H, ROW_H, BTN_H, GAP = 28, 14, 18, 22, 4
local INNER = WIDTH - LEFT - RIGHT
local MAX_ROWS, MAX_BENCH = 40, 10
local BINDING = "CLICK FollowLineJoinButton:LeftButton"
local BUTTON_SIZE = 45

-- The game's text colours, with their usual values for when a constant is missing.
local function FontColor(name, r, g, b)
    local c = _G[name]
    if type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { r, g, b }
end
local GOLD = FontColor("NORMAL_FONT_COLOR", 1.0, 0.82, 0.0)
local WHITE = FontColor("HIGHLIGHT_FONT_COLOR", 1.0, 1.0, 1.0)
local GRAY = FontColor("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
local GREEN = FontColor("GREEN_FONT_COLOR", 0.1, 1.0, 0.1)
local RED = FontColor("RED_FONT_COLOR", 1.0, 0.1, 0.1)
local YELLOW = FontColor("YELLOW_FONT_COLOR", 1.0, 1.0, 0.0)
local HOTKEY = FontColor("ACTIONBAR_HOTKEY_FONT_COLOR", 0.6, 0.6, 0.6)
local RANGE_DOT = type(RANGE_INDICATOR) == "string" and RANGE_INDICATOR or "\226\151\143"   -- the game's dot

local function Hex(c)
    return ("ff%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255)
end
local function Paint(c, text) return "|c" .. Hex(c) .. text .. "|r" end

local COLOR = {
    head = GOLD, on = GREEN, off = RED, pending = YELLOW,
    noaddon = GRAY, offline = GRAY, out = GRAY, none = GRAY,
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
    return WHITE[1], WHITE[2], WHITE[3]
end

local function HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

-- A part the frame template made, or nil (a template part is a table).
local function Part(f, key)
    local v = f and f[key]
    if type(v) == "table" then return v end
end

----------------------------------------------------------------------
-- The Follow button
----------------------------------------------------------------------
local function BoundKey()
    if not GetBindingKey then return nil end
    local ok, key = pcall(GetBindingKey, BINDING)
    if ok and type(key) == "string" and key ~= "" then return key end
end

-- The key the way the action bars print it ("S-F", "M4").
local function ShortKey(key)
    if GetBindingText then
        local ok, text = pcall(GetBindingText, key, true)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return key
end

local function ButtonTooltip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Follow Line", GOLD[1], GOLD[2], GOLD[3])
    if Line.target then
        GameTooltip:AddLine(("Follow %s, the player ahead of you in the line."):format(Line.target), WHITE[1], WHITE[2], WHITE[3], true)
    end
    local key = BoundKey()
    GameTooltip:AddLine(key and ("Key: " .. key)
        or "Give it a key under Key Bindings > AddOns > Follow Line.", GRAY[1], GRAY[2], GRAY[3], true)
    if not ns.db.locked then GameTooltip:AddLine("Drag to move (not during a fight).", GRAY[1], GRAY[2], GRAY[3], true) end
    GameTooltip:Show()
end

local function CreateButton()
    local b = CreateFrame("Button", "FollowLineJoinButton", UIParent, "SecureActionButtonTemplate")
    button = b
    b:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:SetMovable(true)
    -- the name beside the button is part of what can be clicked
    b:SetHitRectInsets(0, -158, 0, 0)
    -- the game clicks on the way down or the way up depending on a setting of the player's
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("type", "macro")

    -- the action bars' slot: background, icon, frame, pushed, highlight
    b.slot = b:CreateTexture(nil, "BACKGROUND")
    b.slot:SetAllPoints(b)
    b.slot:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
    b.icon = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.icon:SetAllPoints(b)
    b.icon:SetTexture(ns.ICON)
    -- ActionButtonTemplate: the mask at its atlas size, centred on the icon
    local mask = b.CreateMaskTexture and b:CreateMaskTexture()
    if mask then
        mask:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask", true)
        mask:SetPoint("CENTER", b.icon, "CENTER", 0, 0)
        b.icon:AddMaskTexture(mask)
    end
    -- frame, pushed and highlight art at the template's 46 x 45 from the top left
    b:SetNormalAtlas("UI-HUD-ActionBar-IconFrame")
    b:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
    b:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    for _, t in ipairs({ b:GetNormalTexture(), b:GetPushedTexture(), b:GetHighlightTexture() }) do
        if type(t) == "table" then
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
            t:SetSize(BUTTON_SIZE + 1, BUTTON_SIZE)
        end
    end
    -- the template's CheckedTexture: an action button is checked while its action
    -- runs (auto attack, a channel), and this one while the player follows
    b.checked = b:CreateTexture(nil, "OVERLAY")
    b.checked:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    b.checked:SetBlendMode("ADD")
    b.checked:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.checked:SetSize(BUTTON_SIZE + 1, BUTTON_SIZE)
    b.checked:Hide()

    b.hotkey = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    b.hotkey:SetSize(32, 10)
    b.hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -4, -5)
    b.hotkey:SetJustifyH("RIGHT")

    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("TOPLEFT", b, "TOPRIGHT", 7, -6)
    b.label:SetWidth(150)
    b.label:SetJustifyH("LEFT")
    b.label:SetWordWrap(false)

    b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.sub:SetPoint("BOTTOMLEFT", b, "BOTTOMRIGHT", 7, 8)
    b.sub:SetWidth(150)
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
    local place = ("Place %d of %d"):format(Line.place or 0, total)
    local key = BoundKey()
    local inRange = Line.InRange(Line.members[target])     -- nil when the game can't tell
    local far = not on and inRange == false
    local sub
    if UI.pending and button.target ~= target then
        -- the line changed during a fight: the button still points at someone else
        sub = Paint(RED, "After the fight.") .. " Type /follow " .. target
    elseif on then
        sub = place
    elseif far then
        sub = Paint(RED, "Too far away:") .. " walk closer"
    else
        sub = place .. (key and "" or ", click to fall in")
    end
    button.label:SetText((on and "Following " or "Follow ") .. target)
    button.sub:SetText(sub)
    -- the action bars' states (ActionButton.lua): checked while the action runs; out of
    -- range the key turns red, and with no key a dot stands in for it while range is known
    button.checked:SetShown(on)
    button.hotkey:SetText(key and ShortKey(key) or (inRange ~= nil and RANGE_DOT or ""))
    local c = far and RED or HOTKEY
    button.hotkey:SetVertexColor(c[1], c[2], c[3])
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

-- Gold title, white text, the way the game's tooltips read.
local function Tip(self)
    if not GameTooltip or not self.tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.tipTitle then
        GameTooltip:AddLine(self.tipTitle, GOLD[1], GOLD[2], GOLD[3])
        GameTooltip:AddLine(self.tip, WHITE[1], WHITE[2], WHITE[3], true)
    else
        GameTooltip:AddLine(self.tip, WHITE[1], WHITE[2], WHITE[3], true)
    end
    GameTooltip:Show()
end

-- A small button inside a row, drawn with the game's own button art.
local ART = {
    up     = { "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up", "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down",
               "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled", "Interface\\Buttons\\UI-Common-MouseHilight", 16 },
    down   = { "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down",
               "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled", "Interface\\Buttons\\UI-Common-MouseHilight", 16 },
    remove = { "Interface\\Buttons\\UI-MinusButton-Up", "Interface\\Buttons\\UI-MinusButton-Down",
               "Interface\\Buttons\\UI-MinusButton-Disabled", "Interface\\Buttons\\UI-PlusButton-Hilight", 16 },
    add    = { "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-PlusButton-Down",
               "Interface\\Buttons\\UI-PlusButton-Disabled", "Interface\\Buttons\\UI-PlusButton-Hilight", 16 },
}
-- one size for all four (the plus and minus buttons' own 16 x 16) and one gap between them
local MINI_GAP = 2

local function MiniButton(row, art, tip, onClick)
    local a = ART[art]
    local b = CreateFrame("Button", nil, row)
    b:SetSize(a[5], a[5])
    b:SetNormalTexture(a[1])
    b:SetPushedTexture(a[2])
    b:SetDisabledTexture(a[3])
    b:SetHighlightTexture(a[4], "ADD")
    b.tip = tip
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", HideTooltip)
    b:SetScript("OnClick", function()
        if row.member then ns.Safe(onClick, row.member.name) end
        ns.dirty = true
    end)
    return b
end

-- One of the six buttons under the list: the game's red panel button.
local function CommandButton(label, tipTitle, tip, onClick)
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize((INNER - GAP * 2) / 3, BTN_H)
    b:SetText(label)
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
    local c = COLOR[st] or WHITE
    GameTooltip:AddLine(text:sub(1, 1):upper() .. text:sub(2) .. ".", c[1], c[2], c[3], true)
    if m.isPlayer or m.demo then
        -- nothing to add
    elseif m.hasAddon then
        GameTooltip:AddLine("Follow Line " .. tostring(m.version or ""), GRAY[1], GRAY[2], GRAY[3])
    else
        GameTooltip:AddLine("No Follow Line seen: they get no Follow button, and the addon can't tell whether they follow.", GRAY[1], GRAY[2], GRAY[3], true)
    end
    GameTooltip:Show()
end

-- A line of the window: place, name, state, and the buttons that move it.
local function NewRow(bench)
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_H)

    -- the quest log's row highlight
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(row)

    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.num:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.num:SetWidth(16)
    row.num:SetJustifyH("RIGHT")

    if bench then
        row.add = MiniButton(row, "add", "Put them at the end of the line", function(name) Line.Add(name) end)
        row.add:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    else
        row.rem = MiniButton(row, "remove", "Take them out of the line", function(name) Line.Remove(name) end)
        row.rem:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.down = MiniButton(row, "down", "Move back one place", function(name) Line.Move(name, 1) end)
        row.down:SetPoint("RIGHT", row.rem, "LEFT", -MINI_GAP, 0)
        row.up = MiniButton(row, "up", "Move forward one place", function(name) Line.Move(name, -1) end)
        row.up:SetPoint("RIGHT", row.down, "LEFT", -MINI_GAP, 0)
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
    widget:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT, -top)
    widget:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -RIGHT, -top)
end

local function FillRow(row, m, number, last)
    row.member = m
    local r, g, b = ClassColor(m.class)
    local st = Line.Status(m)
    if st == "offline" then r, g, b = GRAY[1], GRAY[2], GRAY[3] end
    row.num:SetText(number and (number .. ".") or "")
    row.name:SetText(m.name .. (m.isPlayer and " (you)" or ""))
    row.name:SetTextColor(r, g, b)
    local c = COLOR[st] or WHITE
    row.state:SetText(SHORT[st] or "")
    row.state:SetTextColor(c[1], c[2], c[3])
    if row.up then
        if number == 1 then row.up:Disable() else row.up:Enable() end
        if last then row.down:Disable() else row.down:Enable() end
    end
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
        button:SetPoint("CENTER", UIParent, "CENTER", -80, -170)
    end
end

local function HideWindow()
    UI.hiding = true
    frame:Hide()
    UI.hiding = false
end

function UI.Create()
    CreateButton()

    frame = CreateFrame("Frame", "FollowLineFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, 120)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", StartMove)
    frame:SetScript("OnDragStop", StopMove)
    -- Escape and the close button close it like any game window; /line opens it again
    -- (IsShown stays true when only the whole UI is hidden, as with Alt+Z: then it stays open)
    frame:SetScript("OnHide", function(self)
        if not UI.hiding and not self:IsShown() and ns.db.open then
            ns.db.open = false
            if ns.Kit then ns.Kit.Sync() end
        end
    end)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "FollowLineFrame") end

    title = Part(frame, "TitleText") or (Part(frame, "TitleContainer") and Part(frame.TitleContainer, "TitleText"))
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", frame, "TOP", -6, -4)
    end
    title:SetText("Follow Line")

    count = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    count:SetJustifyH("LEFT")

    note = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetHeight(NOTE_H - 4)
    note:SetJustifyH("LEFT")
    note:SetJustifyV("TOP")
    note:SetWordWrap(true)

    benchHead = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    benchHead:SetJustifyH("LEFT")
    benchHead:SetText("Not in the line")
    benchHead:Hide()

    moreNote = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moreNote:SetJustifyH("LEFT")
    moreNote:Hide()

    CommandButton("Call line", "Call line", "Sends this order to everyone in the group with the addon. The first player leads; each of the others gets a Follow button for the player ahead of them.",
        function() Line.Call() end)
    CommandButton("Regroup", "Regroup", "Nudges everyone who is off the line: they get a chat line naming whom to follow, and a sound.",
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
    HideWindow()
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
        return Paint(GOLD, "Order changed.") .. " Press Call line to send it to the group."
    end
    local by = (line.by == ns.playerName) and "you" or line.by
    if Line.place == 1 then
        return ("Called by %s. You lead; the others get the Follow buttons."):format(by)
    elseif Line.target then
        return ("Called by %s. You follow %s."):format(by, Line.target)
    end
    return ("Called by %s. You are not in it."):format(by)
end

function UI.Refresh()
    if not frame then return end
    RefreshButton()
    if not ns.db.open then
        if frame:IsShown() then HideWindow() end
        return
    end

    local top = TOP
    local line = Line.line
    if line then
        local on, followers = Line.Summary()
        local c = (followers > 0 and on == followers) and GREEN or WHITE
        count:SetText(("Following: %s"):format(Paint(c, ("%d of %d"):format(on, followers))))
        Place(count, top)
        count:Show()
        top = top + COUNT_H
    else
        count:Hide()
    end
    Place(note, top)
    note:SetText(NoteText())
    top = top + NOTE_H

    local shown, last = 0, 0
    for _, name in ipairs(Line.draft) do
        if Line.members[name] then last = last + 1 end
    end
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
            FillRow(row, m, i, shown == last)
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

    -- "Call line" lights up, the way the game marks a button it wants pressed,
    -- while there is something to send
    local call = commands[1]
    local ready = (Line.grouped or Line.demo) and (not line or Line.DraftDiffers())
    if ready then call:LockHighlight() else call:UnlockHighlight() end

    top = top + 8
    local width = (INNER - GAP * 2) / 3
    for i, b in ipairs(commands) do
        local col, rowIndex = (i - 1) % 3, math.floor((i - 1) / 3)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", LEFT + col * (width + GAP), -(top + rowIndex * (BTN_H + GAP)))
    end
    top = top + BTN_H * 2 + GAP

    frame:SetHeight(top + BOTTOM)
    if not frame:IsShown() then frame:Show() end
end
