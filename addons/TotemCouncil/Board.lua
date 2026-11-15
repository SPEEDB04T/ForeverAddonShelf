-- Totem Council: the group plan window (every shaman in the group, what each
-- drops per element, a red dot where two plan the same totem) and the
-- accept/decline pop-up.
local ADDON, ns = ...

local Board = {}
ns.Board = Board

-- each row is one copy of the totem bar: 30 x 30 totem buttons, 8 apart,
-- the time left under each (10 px of GameFontNormalSmall), 4 px between rows
local CELL, GAP = ns.TOTEM_BUTTON, ns.TOTEM_GAP
local ROW_H, NAME_W, PAD, MAX_ROWS = CELL + 10 + 4, 150, 12, 12
local COL_W = CELL + GAP
local WIDTH = PAD * 2 + NAME_W + 4 * CELL + 3 * GAP
-- layout inside the game's ButtonFrameTemplate: title bar, header strip
-- beside the portrait, the inset with the rows, and the button bar
local ROWS_TOP, BAR_H, STATUS_H = 64, 26, 40
local ICON = "Interface\\Icons\\Spell_Nature_Windfury"

local C = ns.COLOR
local RED, BLUE, GRAY = C.red, C.blue, C.gray

local function MakeButton(parent, text, width)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    return b
end

----------------------------------------------------------------------
-- Accept / decline pop-up (one at a time, the rest wait their turn)
----------------------------------------------------------------------
local toast, toastQueue = nil, {}

-- StaticPopup's layout (Blizzard_StaticPopup_Game/GameDialog.xml and .lua):
-- 320 wide, text 290 wide under a 16 px top spacer, buttons 9 below the
-- text, 120 x 21 and 10 apart, 16 px under the buttons
local POPUP_W, POPUP_TEXT_W, POPUP_TOP, POPUP_GAP, POPUP_BOTTOM = 320, 290, 16, 9, 16
local POPUP_BUTTON_W, POPUP_BUTTON_H, POPUP_BUTTON_GAP = 120, 21, 10

local function NextToast()
    if not toast or toast:IsShown() then return end
    local req = table.remove(toastQueue, 1)
    while req and req.valid and not req.valid() do   -- skip requests that no longer apply
        req = table.remove(toastQueue, 1)
    end
    if not req then return end
    toast.req = req
    toast.text:SetText(req.text or "")
    toast:SetHeight(POPUP_TOP + (toast.text:GetStringHeight() or 12) + POPUP_GAP + POPUP_BUTTON_H + POPUP_BOTTOM)
    -- where StaticPopup1 sits, or under it while a game dialog is up, the way
    -- the game stacks its own dialogs
    toast:ClearAllPoints()
    local above = StaticPopup1
    if type(above) == "table" and above.IsShown and above:IsShown() then
        toast:SetPoint("TOP", above, "BOTTOM", 0, 0)
    else
        toast:SetPoint("TOP", UIParent, "TOP", 0, -135)
    end
    toast.left = 45
    toast.shownAt = GetTime()
    toast:Show()
end

local function CloseToast(answer)
    local req = toast.req
    toast.req = nil
    toast:Hide()
    if req then
        if answer == "y" and req.onAccept then ns.Safe(req.onAccept) end
        if answer == "n" and req.onDecline then ns.Safe(req.onDecline) end
    end
    NextToast()
end

-- StaticPopupButtonTemplate's art and fonts
local function PopupButton(parent, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(POPUP_BUTTON_W, POPUP_BUTTON_H)
    local function art(setter, file, blend)
        if not b[setter] then return end
        b[setter](b, file)
        local getter = setter:gsub("^Set", "Get")
        local t = b[getter] and b[getter](b)
        if t then
            t:SetTexCoord(0, 1, 0, 0.71875)
            if blend and t.SetBlendMode then t:SetBlendMode(blend) end
        end
    end
    art("SetNormalTexture", "Interface\\Buttons\\UI-DialogBox-Button-Up")
    art("SetPushedTexture", "Interface\\Buttons\\UI-DialogBox-Button-Down")
    art("SetDisabledTexture", "Interface\\Buttons\\UI-DialogBox-Button-Disabled")
    art("SetHighlightTexture", "Interface\\Buttons\\UI-DialogBox-Button-Highlight", "ADD")
    if b.SetNormalFontObject then
        b:SetNormalFontObject("GameFontNormal")
        b:SetHighlightFontObject("GameFontHighlight")
        b:SetDisabledFontObject("GameFontDisable")
    end
    b:SetText(text)
    local fs = b.GetFontString and b:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", 0, 1)
    end
    return b
end

local function CreateToast()
    -- the game's pop-up dialog (StaticPopup): the same dialog panel
    -- (DefaultDialogPanelTemplate), white centred text, two dialog buttons;
    -- the dark dialog box if the template is missing on this client
    local ok, f = pcall(CreateFrame, "Frame", "TotemCouncilToast", UIParent, "DefaultDialogPanelTemplate")
    if not ok or not f then
        f = CreateFrame("Frame", "TotemCouncilToast", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        ns.DialogBackdrop(f)
    end
    toast = f
    toast:SetSize(POPUP_W, 72)
    toast:SetFrameStrata("DIALOG")
    toast:SetToplevel(true)
    toast:EnableMouse(true)
    toast.text = toast:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    toast.text:SetPoint("TOP", 0, -POPUP_TOP)
    toast.text:SetWidth(POPUP_TEXT_W)
    toast.accept = PopupButton(toast, ACCEPT or "Accept")
    toast.accept:SetPoint("TOPRIGHT", toast.text, "BOTTOM", -POPUP_BUTTON_GAP / 2, -POPUP_GAP)
    toast.accept:SetScript("OnClick", function()
        -- a request that only just appeared can't be accepted yet, so a
        -- double-click on the one before it does not accept this one unread
        if GetTime() - (toast.shownAt or 0) < 0.6 then return end
        CloseToast("y")
    end)
    toast.decline = PopupButton(toast, DECLINE or "Decline")
    toast.decline:SetPoint("TOPLEFT", toast.text, "BOTTOM", POPUP_BUTTON_GAP / 2, -POPUP_GAP)
    toast.decline:SetScript("OnClick", function() CloseToast("n") end)
    -- an unanswered request counts as declined after 45 seconds
    toast:SetScript("OnUpdate", function(self, elapsed)
        self.left = (self.left or 45) - elapsed
        if self.left <= 0 then CloseToast("n") end
    end)
    toast:Hide()
end

-- req = { text, icon, onAccept, onDecline, valid }
-- At most six wait their turn; more than that is dropped unanswered (the
-- sender's request simply runs out).
function Board.Toast(req)
    if not toast then CreateToast() end
    if #toastQueue >= 6 then return end
    toastQueue[#toastQueue + 1] = req
    NextToast()
end

----------------------------------------------------------------------
-- Window
----------------------------------------------------------------------
local frame, rows = nil, {}

local function CellEnter(self)
    local m, slot = self.member, self.slot
    if not m then return end
    local G = ns.Group
    local el = ns.ELEMENTS[slot]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(m.name .. ": " .. el.name)
    local key = G.Effective(m, slot)
    local info = key and ns.Info(key)
    if G.Fixed(m) then
        GameTooltip:AddLine(info and ("Last seen dropping " .. info.name) or "No totem seen yet", 1, 1, 1)
        GameTooltip:AddLine("No Totem Council: can't take suggestions. Announce posts the plan in chat.", GRAY[1], GRAY[2], GRAY[3], true)
    else
        GameTooltip:AddLine(info and ("Plans " .. info.name) or "Nothing planned", 1, 1, 1)
    end
    local live = m.isPlayer and ns.active[slot] or m.seen[slot]
    if live then
        local liveInfo = ns.Info(live.key)
        local left = m.isPlayer and (live.start + live.duration - GetTime()) or (live.expires - GetTime())
        GameTooltip:AddLine(("Down now: %s (%s)"):format(liveInfo and liveInfo.name or live.name or "a totem",
            ns.HUD.FormatTime(left)), C.green[1], C.green[2], C.green[3])
    end
    local conflict = G.conflictMap[m.name] and G.conflictMap[m.name][slot]
    if conflict then
        GameTooltip:AddLine("Same totem as " .. table.concat(conflict, ", ") .. " in this group.", RED[1], RED[2], RED[3], true)
    end
    local prop = G.proposal
    local line = prop and not prop.doneAt and prop.lines[m.name]
    if line and line[slot] ~= key then
        local newInfo = line[slot] and ns.Info(line[slot])
        GameTooltip:AddLine(("%s proposes: %s"):format(prop.from, newInfo and newInfo.name or "nothing"), BLUE[1], BLUE[2], BLUE[3], true)
    end
    if m.isPlayer then
        GameTooltip:AddLine("Click to change", GRAY[1], GRAY[2], GRAY[3])
    elseif not G.Fixed(m) then
        GameTooltip:AddLine("Click to suggest a totem", GRAY[1], GRAY[2], GRAY[3])
    end
    GameTooltip:Show()
end

local function CellClick(self)
    local m = self.member
    if not m or ns.Group.Fixed(m) then return end
    if m.isPlayer and not ns.isShaman then return end
    ns.Menu.OpenTotems(self, m, self.slot)
end

local function CreateRow(i)
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(WIDTH - PAD * 2, ROW_H)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(ROWS_TOP + (i - 1) * ROW_H))
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 0, -5)
    row.name:SetWidth(NAME_W - 6)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.sub:SetWidth(NAME_W - 6)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetWordWrap(false)
    row.cells = {}
    for index, slot in ipairs(ns.SLOT_ORDER) do
        local c = CreateFrame("Button", nil, row)
        c.slot = slot
        -- the same totem button as the bar; red dot = planned twice,
        -- the checked highlight = a proposed change
        ns.TotemButtonArt(c, slot)
        c:SetPoint("TOPLEFT", row, "TOPLEFT", NAME_W + (index - 1) * COL_W, 0)
        c:SetScript("OnEnter", CellEnter)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
        c:SetScript("OnClick", CellClick)
        row.cells[slot] = c
    end
    rows[i] = row
    return row
end

function Board.Create()
    if frame then return end
    -- the game's portrait panel with a button bar and an inset (the same
    -- frame as the friends list or the dungeon finder); a plain dialog box
    -- if the template is missing on this client
    local ok, f = pcall(CreateFrame, "Frame", "TotemCouncilBoard", UIParent, "ButtonFrameTemplate")
    if not ok or not f then
        f = CreateFrame("Frame", "TotemCouncilBoard", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
        ns.DialogBackdrop(f)
    end
    frame = f
    Board.frame = frame
    frame:SetSize(WIDTH, 200)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        ns.db.boardPoint = { point, relPoint, x, y }
    end)
    local p = ns.db.boardPoint
    if p then
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end

    -- title, portrait and close button come with the template when it loaded
    local function Child(t, key)
        local v = type(t) == "table" and rawget(t, key) or nil
        return type(v) == "table" and v or nil
    end
    local titleText = Child(Child(frame, "TitleContainer"), "TitleText")
    if titleText then
        titleText:SetText("Totem Council")
        frame.title = titleText
    else
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.title:SetPoint("TOP", 0, -16)
        frame.title:SetText("Totem Council")
    end
    local portrait = Child(Child(frame, "PortraitContainer"), "portrait")
    if portrait then
        if SetPortraitToTexture then
            pcall(SetPortraitToTexture, portrait, ICON)     -- round, like every portrait panel
        else
            portrait:SetTexture(ICON)
        end
    end
    frame.close = Child(frame, "CloseButton") or CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    if not Child(frame, "CloseButton") then frame.close:SetPoint("TOPRIGHT", -4, -4) end

    -- column headings: gold, like every list heading in the game
    for index, slot in ipairs(ns.SLOT_ORDER) do
        local el = ns.ELEMENTS[slot]
        local h = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("BOTTOM", frame, "TOPLEFT", PAD + NAME_W + (index - 1) * COL_W + CELL / 2, -(ROWS_TOP - 6))
        h:SetText(el.name)
    end

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.empty:SetPoint("TOPLEFT", PAD, -(ROWS_TOP + 6))
    frame.empty:SetWidth(WIDTH - PAD * 2)
    frame.empty:SetJustifyH("LEFT")
    frame.empty:SetText("No shamans in your group yet.\n\nWhen another shaman joins, their totems show up here: their plan if they have Totem Council, otherwise whatever they are seen dropping. A totem planned twice in one group gets a red dot.\n\n/totems demo adds two pretend shamans so you can try it.")

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.status:SetPoint("BOTTOMLEFT", PAD, BAR_H + 8)
    frame.status:SetWidth(WIDTH - PAD * 2)
    frame.status:SetJustifyH("LEFT")

    -- buttons sit in the template's bottom bar, like the game's panels
    frame.resolve = MakeButton(frame, "Sort it out", 110)
    frame.resolve:SetPoint("BOTTOMLEFT", 6, 4)
    frame.resolve:SetScript("OnClick", function() ns.Safe(ns.Group.Propose) end)
    frame.resolve:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Sort it out")
        GameTooltip:AddLine("Works out a plan with no totem dropped twice in one group and sends it to every shaman with Totem Council. Each one accepts or declines their own change.", 1, 1, 1, true)
        GameTooltip:AddLine("Shamans without the addon keep their totems; otherwise the one earlier in the alphabet keeps theirs and the other moves to the first free totem in their menu.", GRAY[1], GRAY[2], GRAY[3], true)
        GameTooltip:Show()
    end)
    frame.resolve:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.announce = MakeButton(frame, "Announce", 100)
    frame.announce:SetPoint("LEFT", frame.resolve, "RIGHT", 6, 0)
    frame.announce:SetScript("OnClick", function() ns.Safe(ns.Group.Announce) end)
    frame.announce:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Announce")
        GameTooltip:AddLine("Posts the plan for your group in party or raid chat, one line per shaman, so shamans without the addon can read it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame.announce:SetScript("OnLeave", function() GameTooltip:Hide() end)

    if not ok then
        -- the plain dialog box has a thick border: keep the buttons off it
        frame.resolve:SetPoint("BOTTOMLEFT", 16, 14)
    end

    frame:SetScript("OnShow", function() ns.Safe(Board.Refresh) end)
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "TotemCouncilBoard") end
    frame:Hide()
end

function Board.Show()
    if not frame then return end
    frame:Show()
end

function Board.Toggle()
    if not frame then return end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

local function SubLabel(m, inRaid)
    local parts = {}
    if inRaid then parts[#parts + 1] = "Group " .. m.subgroup end
    if m.isPlayer then
        parts[#parts + 1] = "you"
    elseif m.demo then
        parts[#parts + 1] = m.hasAddon and "demo, has addon" or "demo, no addon"
    elseif m.hasAddon then
        parts[#parts + 1] = "shared plan"
    else
        parts[#parts + 1] = "no addon, as seen"
    end
    return table.concat(parts, " - ")
end

function Board.Refresh()
    if not frame or not frame:IsShown() then return end
    local G = ns.Group
    local list = G.SortedMembers()
    local inRaid = IsInRaid and IsInRaid() or false
    local prop = G.proposal
    local now = GetTime()
    local shown = math.min(#list, MAX_ROWS)

    for i = 1, shown do
        local m = list[i]
        local row = rows[i] or CreateRow(i)
        row.name:SetText(m.name)
        -- the player in white, other shamans in the game's shaman class colour
        local nc = m.isPlayer and C.white or C.shaman
        row.name:SetTextColor(nc[1], nc[2], nc[3])
        local sub = SubLabel(m, inRaid)
        local vote = prop and prop.lines[m.name] and prop.votes[m.name]
        if vote == "y" then
            sub = sub .. " - accepted"
        elseif vote == "n" then
            sub = sub .. " - declined"
        elseif prop and prop.lines[m.name] and not prop.doneAt then
            sub = sub .. " - asked"
        end
        row.sub:SetText(sub)
        local line = prop and not prop.doneAt and prop.lines[m.name]
        for _, slot in ipairs(ns.SLOT_ORDER) do
            local c = row.cells[slot]
            c.member = m
            local key = G.Effective(m, slot)
            local proposed = line and line[slot] ~= key
            local showKey = key
            if proposed then showKey = line[slot] end
            local info = showKey and ns.Info(showKey)
            if info then
                c.icon:SetTexture(info.icon)
                c.icon:Show()
            else
                c.icon:Hide()
            end
            local conflict = G.conflictMap[m.name] and G.conflictMap[m.name][slot]
            -- c.state for tests: "proposed" or "conflict"
            c.state = (proposed and "proposed") or (conflict and "conflict") or nil
            c.checked:SetShown(proposed and true or false)
            c.marker:SetShown(conflict and true or false)
            -- as on the bar: grey while that totem is not down, the time
            -- left under it while it is
            local live = m.isPlayer and ns.active[slot] or m.seen[slot]
            local left = live and (m.isPlayer and (live.start + live.duration - now) or (live.expires - now)) or nil
            c.icon:SetDesaturated(not live)
            ns.SetDuration(c, left)
        end
        row:Show()
    end
    for i = shown + 1, #rows do rows[i]:Hide() end

    local alone = #list == 0 or (#list == 1 and list[1].isPlayer)
    frame.empty:SetShown(alone)
    if alone then
        frame.empty:ClearAllPoints()
        frame.empty:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(ROWS_TOP + 6 + shown * ROW_H))
    end
    local others = G.OtherShamans()
    local status
    if prop and not prop.doneAt then
        local yes, total = G.ProposalProgress()
        status = ("Proposal from %s: %d of %d accepted. Highlighted totems are the proposed changes."):format(prop.from, yes, total)
    elseif others == 0 then
        status = ""
    elseif G.conflictCount > 0 then
        status = ("%d totem(s) planned twice in one group; a red dot marks them. Click a totem to change it."):format(G.conflictCount)
    else
        status = "No conflicts: every group gets each totem once."
    end
    if #list > MAX_ROWS then status = status .. (" (+%d more shamans not shown)"):format(#list - MAX_ROWS) end
    local blocked = others > 0 and G.CommsProblem()
    if blocked then status = status .. "\n" .. ns.Paint("gray", "Plans can't sync: " .. blocked .. ".") end
    frame.status:SetText(status)
    frame.resolve:SetEnabled(others > 0)
    frame.announce:SetEnabled(others > 0)

    local body = math.max(shown, 3) * ROW_H
    if alone then
        body = math.max(body, shown * ROW_H + (frame.empty:GetStringHeight() or 90) + 12)
    end
    frame:SetHeight(ROWS_TOP + body + STATUS_H + BAR_H + 8)
end
