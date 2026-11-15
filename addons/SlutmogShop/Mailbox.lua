-- Slutmog Shop: mailbox mode. For standing around a city mailbox in your wares: the shop emotes
-- back at people who emote at you, keeps a list of who looked, emoted and whispered, and gives
-- each of them a one-click reply. /slutshop mailbox turns it on; closing its window turns it off.
--
-- What it does by itself is emotes only, and few of them (one per person every two minutes, one
-- every six seconds at most). It never whispers or speaks without a click: the pitch is a button,
-- and only for somebody who emoted at you or whispered you first. If the game refuses emotes from
-- addons, the emote buttons in the list do the same thing with a click.
local ADDON, ns = ...
local M = {}
ns.Mailbox = M

local ROWS, ROW_H = 6, 26
local PERSON_GAP = 120          -- seconds between two emotes by itself at the same person
local LOOK_GAP = 900            -- ... at somebody who only looked
local GLOBAL_GAP = 6            -- seconds between any two emotes by itself
local PITCH_GAP = 600           -- seconds before the same person can be pitched again
local KEEP = 20                 -- visitors remembered (this session only; nothing is saved)

-- Their emote, by a word in its text, and what goes back. First match wins.
local REPLIES = {
    { "kiss", "BLUSH", "Blush" }, { "wink", "WINK", "Wink" }, { "flirt", "FLIRT", "Flirt" },
    { "whistle", "CURTSEY", "Curtsey" }, { "danc", "DANCE", "Dance" }, { "wave", "WAVE", "Wave" },
    { "greet", "WAVE", "Wave" }, { "hello", "WAVE", "Wave" }, { "bow", "CURTSEY", "Curtsey" },
    { "hug", "HUG", "Hug" }, { "cuddle", "HUG", "Hug" }, { "drool", "GIGGLE", "Giggle" },
    { "lick", "GIGGLE", "Giggle" }, { "cheer", "THANK", "Thank" }, { "applaud", "CURTSEY", "Curtsey" },
    { "clap", "CURTSEY", "Curtsey" }, { "love", "BLUSH", "Blush" }, { "sexy", "WINK", "Wink" },
    { "purr", "WINK", "Wink" }, { "stare", "WINK", "Wink" }, { "gaze", "WINK", "Wink" },
}
-- Nothing goes back to these.
local RUDE = { "spit", "rude", "slap", "insult", "mock", "taunt", "pity", "puke", "fart", "disgust", "threaten", "angry", "bonk" }
local DEFAULT_REPLY = { nil, "WINK", "Wink" }

-- The pitch, in the shop owner's voice. {item} and {price} are the ware whose turn it is.
M.PITCHES = {
    "You looked. It's for sale: {item}, {price}.",
    "That's {item}. {price} and it's yours.",
    "Staring is free. {item} is {price}.",
    "The mailbox isn't for sale. {item} is, {price}.",
}

local on = false
local frame, events
local visitors = {}             -- newest first: { name, what, at, reply = { word, token, label }, pitch = bool, pitchedAt, emotedAt }
local lastAuto = -1e9
local manual = false            -- the game refused an emote from the addon: buttons only
local pitchTurn = 0

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function Readable(v)
    if ns.Readable then return ns.Readable(v) end
    return true
end

local function Short(name)
    return (tostring(name):gsub("%-.*$", ""))
end

local function Me()
    if type(UnitName) ~= "function" then return nil end
    local ok, name = pcall(UnitName, "player")
    return ok and Readable(name) and type(name) == "string" and name or nil
end

-- Sends an emote. Returns false when the game would not have it.
local function Emote(token, name)
    local fn = C_ChatInfo and C_ChatInfo.PerformEmote
    if type(fn) == "function" then
        local ok, res = pcall(fn, token, name)
        return ok and res ~= false
    end
    if type(DoEmote) == "function" then return (pcall(DoEmote, token, name)) end
    return false
end

local function Find(name)
    for i, v in ipairs(visitors) do
        if v.name == name then return v, i end
    end
end

-- Somebody did something: to the top of the list.
local function Visit(name, what, reply, pitch)
    local v, i = Find(name)
    if v then table.remove(visitors, i) else v = { name = name } end
    v.what, v.at = what, Now()
    if reply ~= nil then v.reply = reply or nil end
    v.pitch = v.pitch or pitch or false
    table.insert(visitors, 1, v)
    while #visitors > KEEP do table.remove(visitors) end
    return v
end

local function Sync()
    if not (frame and frame:IsShown()) then return end
    local now = Now()
    for r = 1, ROWS do
        local row, v = frame.rows[r], visitors[r]
        if v then
            row.name:SetText(Short(v.name))
            row.what:SetText(v.what)
            if v.reply then
                row.emote:SetText(v.reply[3])
                row.emote:Show()
            else
                row.emote:Hide()
            end
            if v.pitch then
                local done = v.pitchedAt and now - v.pitchedAt < PITCH_GAP
                row.pitch:SetText(done and "Pitched" or "Pitch")
                row.pitch:SetEnabled(not done and ns.WareOffer() ~= nil)
                row.pitch:Show()
            else
                row.pitch:Hide()
            end
            row:Show()
        else
            row:Hide()
        end
    end
    frame.empty:SetShown(#visitors == 0)
    frame.status:SetText(manual and "The game wants a click for emotes here: use the buttons."
        or "Emoting back by itself. Whispers and pitches wait for your click.")
end
M.Sync = Sync

-- An emote by itself, if the limits allow. The dance comes back a few seconds later.
local function Auto(v, gap)
    if manual or not v.reply then return false end
    local now = Now()
    if now - lastAuto < GLOBAL_GAP or (v.emotedAt and now - v.emotedAt < gap) then return false end
    if not Emote(v.reply[2], v.name) then
        manual = true
        ns.Print("the game does not let the shop emote by itself here. The buttons in the mailbox window do it with a click.")
        return false
    end
    lastAuto, v.emotedAt = now, now
    if C_Timer and C_Timer.After and v.reply[2] ~= "DANCE" then
        C_Timer.After(5, function()
            if on and not manual then Emote("DANCE") end
        end)
    end
    return true
end

local function ReplyFor(text)
    local l = text:lower()
    for _, word in ipairs(RUDE) do
        if l:find(word, 1, true) then return false end
    end
    for _, r in ipairs(REPLIES) do
        if l:find(r[1], 1, true) then return r end
    end
    return DEFAULT_REPLY
end

local function OnEmote(text, sender)
    if not (Readable(text) and Readable(sender) and type(text) == "string" and type(sender) == "string") then return end
    local me = Me()
    if sender == "" or (me and Short(sender) == me) then return end
    if not text:lower():find("%f[%a]you%f[%A]") then return end        -- only what is aimed at you
    local reply = ReplyFor(text)
    local v = Visit(sender, text, reply, true)
    if reply then Auto(v, PERSON_GAP) end
    Sync()
end

local function OnWhisper(text, sender)
    if not (Readable(text) and Readable(sender) and type(text) == "string" and type(sender) == "string") or sender == "" then return end
    local seen = Find(sender)
    Visit(sender, "whispered: " .. text, (seen and seen.reply) or DEFAULT_REPLY, true)
    Sync()
end

-- Who has you targeted: read off the nameplates in view (they must be shown for this to see anybody).
local function Look()
    if type(UnitExists) ~= "function" or type(UnitIsUnit) ~= "function" then return end
    local changed = false
    for i = 1, 40 do
        local unit = "nameplate" .. i
        local ok, hit = pcall(function()
            return UnitExists(unit) and UnitIsPlayer(unit) and UnitIsUnit(unit .. "target", "player")
        end)
        if ok and Readable(hit) and hit then
            local okName, name, realm = pcall(UnitName, unit)
            if okName and Readable(name) and type(name) == "string" then
                if Readable(realm) and type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
                local v = Find(name)
                if not v then
                    v = Visit(name, "has you targeted", DEFAULT_REPLY, false)
                    changed = true
                end
                if not v.emotedAt and Auto(v, LOOK_GAP) then changed = true end
            end
        end
    end
    if changed then Sync() end
end

local function Tick()
    if not on then return end
    Look()
    Sync()
    C_Timer.After(2, Tick)
end

local function Button(parent, label, w)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not (ok and b) then b = CreateFrame("Button", nil, parent) end
    b:SetSize(w, 20)
    b:SetText(label)
    return b
end

local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    if fs.SetFontObject and _G[font] then pcall(fs.SetFontObject, fs, _G[font]) end
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

function M.Pitch(v)
    local offer = ns.WareOffer()
    if not (v and v.pitch and offer) then return false end
    local now = Now()
    if v.pitchedAt and now - v.pitchedAt < PITCH_GAP then return false end
    pitchTurn = pitchTurn % #M.PITCHES + 1
    local text = M.PITCHES[pitchTurn]:gsub("{(%a+)}", function(k) return offer[k] end)
    if offer.where == "ah" then text = text .. " It's on the auction house." end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" or not pcall(send, text, "WHISPER", nil, v.name) then
        ns.Print("the game refused the whisper to " .. Short(v.name) .. ".")
        return false
    end
    v.pitchedAt = now
    Sync()
    return true
end

local function Build()
    if frame then return frame end
    local ok, f = pcall(CreateFrame, "Frame", "SlutmogShopMailbox", UIParent, "BasicFrameTemplateWithInset")
    if not (ok and f) then f = CreateFrame("Frame", "SlutmogShopMailbox", UIParent) end
    frame = f
    f:SetSize(400, 78 + ROWS * ROW_H)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -120, 60)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if type(f.TitleText) == "table" then f.TitleText:SetText("On the mailbox") end
    if type(f.CloseButton) ~= "table" then
        local okc, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
        if okc and close then
            close:SetPoint("TOPRIGHT", 0, 0)
            close:SetScript("OnClick", function() f:Hide() end)
        end
    end
    f:SetScript("OnHide", function() M.Stop(true) end)

    f.rows = {}
    for r = 1, ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30 - (r - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -30 - (r - 1) * ROW_H)
        row.pitch = Button(row, "Pitch", 62)
        row.pitch:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.emote = Button(row, "Wink", 66)
        row.emote:SetPoint("RIGHT", row.pitch, "LEFT", -4, 0)
        row.name = Text(row, "GameFontNormal")
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name:SetWidth(84)
        row.what = Text(row, "GameFontHighlightSmall")
        row.what:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.what:SetPoint("RIGHT", row.emote, "LEFT", -6, 0)
        row.emote:SetScript("OnClick", function()
            local v = visitors[r]
            if v and v.reply and Emote(v.reply[2], v.name) then v.emotedAt = Now() end
        end)
        row.pitch:SetScript("OnClick", function() M.Pitch(visitors[r]) end)
        row.pitch:SetScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Pitch")
            GameTooltip:AddLine("Whispers this person one line about the ware whose turn it is, with its price. "
                .. "Only for somebody who emoted at you or whispered you first, and once in ten minutes.", 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        row.pitch:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        row:Hide()
        f.rows[r] = row
    end
    f.empty = Text(f, "GameFontDisable")
    f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -40)
    f.empty:SetText("Nobody yet. Whoever emotes at you, whispers you or targets you shows up here.")
    f.status = Text(f, "GameFontHighlightSmall")
    f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 16)
    f.status:SetPoint("RIGHT", f, "RIGHT", -92, 0)
    f.dance = Button(f, "Dance", 72)
    f.dance:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    f.dance:SetScript("OnClick", function() Emote("DANCE") end)
    f:Hide()
    return f
end

function M.Start()
    if on then return true end
    if not (C_Timer and C_Timer.After) then
        ns.Print("mailbox mode needs the game's timers, and this client has none.")
        return false
    end
    local ok, err = pcall(Build)
    if not ok then
        ns.Print("the mailbox window could not be built: " .. tostring(err))
        return false
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", function(_, event, text, sender)
            if not on then return end
            if event == "CHAT_MSG_TEXT_EMOTE" then OnEmote(text, sender) else OnWhisper(text, sender) end
        end)
    end
    pcall(events.RegisterEvent, events, "CHAT_MSG_TEXT_EMOTE")
    pcall(events.RegisterEvent, events, "CHAT_MSG_WHISPER")
    on, manual = true, false
    frame:Show()
    Emote("DANCE")
    Tick()
    ns.Print("mailbox mode is on. Close its window to turn it off.")
    return true
end

function M.Stop(fromHide)
    if not on then return end
    on = false
    if events then
        pcall(events.UnregisterEvent, events, "CHAT_MSG_TEXT_EMOTE")
        pcall(events.UnregisterEvent, events, "CHAT_MSG_WHISPER")
    end
    if frame and not fromHide then frame:Hide() end
    ns.Print("mailbox mode is off.")
end

function M.Toggle()
    if on then M.Stop() else M.Start() end
end

function M.IsOn() return on end
function M.Frame() return frame end
function M.Visitors() return visitors end
function M.Manual() return manual end
