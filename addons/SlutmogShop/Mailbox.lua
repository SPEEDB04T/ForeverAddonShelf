-- Slutmog Shop: mailbox mode. For standing around a city mailbox in your wares: the shop keeps a
-- list of who looked at you, emoted at you and whispered you, puts the one who is waiting for an
-- answer on a big button at the top, and gives everybody a one-click reply. /slutshop mailbox (or
-- /smog mailbox) turns it on; closing its window turns it off.
--
-- A reply is one of the game's own emotes (wink, smile, giggle...) done at them, on your click.
-- By itself the shop only dances and tries the game's emote back, and few of those: one per person
-- every two minutes, one every six seconds at most. It never says, emotes text or whispers without a click.
local ADDON, ns = ...
local M = {}
ns.Mailbox = M

local ROWS, ROW_H = 6, 26
local PERSON_GAP = 120          -- seconds between two emotes by itself at the same person
local LOOK_GAP = 900            -- ... at somebody who only looked
local GLOBAL_GAP = 6            -- seconds between any two emotes by itself
local PITCH_GAP = 600           -- seconds before the same person can be pitched again
local KEEP = 20                 -- visitors remembered (this session only; nothing is saved)
local WAIT = 300                -- seconds somebody counts as waiting for an answer
local FADE_FROM, FADE_TO = 60, 300      -- a row fades between these ages...
local FADE_MIN, DONE_ALPHA = 0.35, 0.55 -- ... down to this; an answered row is dimmed to this at once
local LOOK_KEEP, KEEP_FOR = 600, 1800   -- seconds a looker / an emoter or whisperer stays listed
local RELOOK = 120              -- somebody who looks again after this long is new again (with a sound)
local LOOK_WINDOW = 10          -- a looker can be answered this long after they target you...
local STILL = 3                 -- ... and only while they still do: seen on the last look (every 2 s)
local ALERT_GAP = 3             -- seconds between two alert sounds

-- Their emote, by a word in its text: the game's emote that goes back by itself, and which lines
-- the reply comes from. First match wins.
local REPLIES = {
    { "kiss", "BLUSH", "kiss" }, { "wink", "WINK", "wink" }, { "flirt", "FLIRT", "flirt" },
    { "whistle", "CURTSEY", "show" }, { "danc", "DANCE", "dance" }, { "wave", "WAVE", "wave" },
    { "greet", "WAVE", "wave" }, { "hello", "WAVE", "wave" }, { "bow", "CURTSEY", "show" },
    { "hug", "HUG", "hug" }, { "cuddle", "HUG", "hug" }, { "drool", "GIGGLE", "look" },
    { "lick", "GIGGLE", "flirt" }, { "cheer", "THANK", "show" }, { "applaud", "CURTSEY", "show" },
    { "clap", "CURTSEY", "show" }, { "love", "BLUSH", "kiss" }, { "sexy", "WINK", "flirt" },
    { "purr", "WINK", "flirt" }, { "stare", "WINK", "look" }, { "gaze", "WINK", "look" },
}
-- Nothing goes back to these.
local RUDE = { "spit", "rude", "slap", "insult", "mock", "taunt", "pity", "puke", "fart", "disgust", "threaten", "angry", "bonk" }
local DEFAULT_REPLY = { nil, "WINK", "any" }
local LOOK_REPLY = { nil, "WINK", "look" }
local WHISPER_REPLY = { nil, "WINK", "whisper" }

-- The replies: the game's own emotes, done at them (SuccuDev: "just make it simple emotes like wink
-- instead of custom, too tryhard otherwise"). Every group but "look" also draws on "any".
M.EMOTES = {
    look = { "WINK", "SMILE", "GIGGLE", "SHY", "WAVE" },     -- only targeted you: slight
    kiss = { "BLUSH", "KISS" },
    wink = { "WINK" },
    flirt = { "GIGGLE", "FLIRT" },
    show = { "CURTSEY", "THANK" },
    hug = { "HUG", "BLUSH" },
    wave = { "WAVE" },
    dance = { "DANCE" },
    whisper = { },
    any = { "WINK", "SMILE", "GIGGLE" },
}
-- What the buttons call them.
M.LABEL = {
    WINK = "Wink", SMILE = "Smile", GIGGLE = "Giggle", SHY = "Shy", WAVE = "Wave", BLUSH = "Blush",
    KISS = "Blow a kiss", FLIRT = "Flirt", CURTSEY = "Curtsey", THANK = "Thank", HUG = "Hug", DANCE = "Dance",
}

-- The pitch, in the shop owner's voice. {item} and {price} are the ware whose turn it is.
M.PITCHES = {
    "You looked. It's for sale: {item}, {price}.",
    "That's {item}. {price} and it's yours.",
    "Staring is free. {item} is {price}.",
    "The mailbox isn't for sale. {item} is, {price}.",
}

local on = false
local frame, events
-- newest first: { name, kind = "look"|"emote"|"whisper", what, at, seen, reply = { word, token, label }, pitch = bool,
--                 pitchedAt, emotedAt (by itself), doneAt (answered: a click, or the game showed the emote going at them) }
local visitors = {}
local lastAuto = -1e9
local lastAlert = -1e9
local manual = false            -- the game refused an emote from the addon: buttons only
local pitchTurn = 0
local Sync

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

-- Makes a button wide enough for its label (at least w0, at most wmax). Returns the width.
local function Fit(b, w0, wmax)
    local tw
    if b.GetTextWidth then
        local ok, x = pcall(b.GetTextWidth, b)
        if ok and type(x) == "number" then tw = x end
    end
    local w = w0
    if tw then w = math.max(w0, math.ceil(tw) + 24) end
    if wmax then w = math.min(w, wmax) end
    b:SetWidth(w)
    return w, tw and tw + 24 <= (wmax or math.huge)
end
M.Fit = Fit

local CTA_W = 430 - 28          -- the row of big buttons, inside the window

-- The full name of a unit ("Name" or "Name-Realm"), or nil.
local function NameOf(unit)
    if type(UnitName) ~= "function" then return nil end
    local ok, name, realm = pcall(UnitName, unit)
    if not (ok and Readable(name) and type(name) == "string" and name ~= "") then return nil end
    if Readable(realm) and type(realm) == "string" and realm ~= "" then name = name .. "-" .. realm end
    return name
end

-- A unit the game knows this person by right now (your target, or a nameplate in view), or nil.
local function UnitFor(name)
    if type(UnitExists) ~= "function" then return nil end
    local function Is(unit)
        local ok, there = pcall(UnitExists, unit)
        if not (ok and Readable(there) and there) then return false end
        local full = NameOf(unit)
        return full ~= nil and (full == name or Short(full) == name or full == Short(name))
    end
    if Is("target") then return "target" end
    for i = 1, 40 do
        if Is("nameplate" .. i) then return "nameplate" .. i end
    end
    return nil
end

-- Whether an emote really went out is told by the game's echo ("You wink at Bob."), not by what
-- PerformEmote returns: the game's own chat box reads that as "restricted" (ChatFrameEditBox.lua,
-- Gethe/wow-ui-source branch forever), so false means it went out. Reading it the other way round
-- turned the shop to buttons-only after its first emote, which is why it emoted only sometimes.
local ECHO_WAIT = 2              -- seconds to wait for the echo
local MISSES = 3                 -- emotes in a row with no echo before the shop stops emoting by itself
local aimBy = "unit"             -- how an emote is aimed: at their unit (target, nameplate), or by name
local misses = 0
local pend                       -- the emote sent last, until its echo
local Missed                     -- set below, once Sync is known

local function Aim(name)
    if not name then return nil end
    local unit = aimBy == "unit" and UnitFor(name) or nil
    if unit then return unit, "unit" end
    return name, "name"
end

-- Any other emote stops the dance (SuccuDev: "keeps canceling my dance", then "fails to resume"), so
-- the shop dances again a moment after one of its own, unless you stopped dancing yourself. It tries
-- from a timer and again on any chat line that comes in, until the game echoes the dance: an emote
-- from a timer has never been seen to work on this client, one from a chat event has.
local REDANCE = 2                -- seconds after a wink or a smile before dancing again
local RETRY = 2                  -- seconds between two tries
local GIVE_UP = 20               -- seconds after which it stops trying
local dancing = false            -- you are dancing, as far as the shop knows
local due                        -- when the dance should be back, until its echo
local tried = -1e9

-- What the shop tried and what came of it, the last 40, saved for looking into problems later.
local function Log(what)
    local db = ns.db
    if type(db) ~= "table" then return end
    db.mailLog = type(db.mailLog) == "table" and db.mailLog or {}
    local log = db.mailLog
    log[#log + 1] = string.format("%.1f %s", Now(), what)
    while #log > 40 do table.remove(log, 1) end
end
M.Log = Log

-- Sends an emote from the addon, at somebody if a name is given. Returns false when the game would not have it.
local Emote
Emote = function(token, name, from)
    local fn = (C_ChatInfo and C_ChatInfo.PerformEmote) or DoEmote
    if type(fn) ~= "function" then return false end
    local at, how = Aim(name)
    local ok, restricted = pcall(fn, token, at, true)
    Log(string.format("%s %s at %s (%s): %s", from or "?", token, tostring(at), how or "-",
        not ok and ("error " .. tostring(restricted)) or (Readable(restricted) and tostring(restricted) or "secret")))
    if not ok or (Readable(restricted) and restricted == true) then return false end
    if token == "DANCE" then
        dancing = true
    elseif dancing then
        due = Now() + REDANCE
        if C_Timer and C_Timer.After then
            C_Timer.After(REDANCE + 0.05, function() M.Redance("timer") end)
        end
    end
    local mine = { who = name and Short(name) or nil, how = how, token = token }
    pend = mine
    if C_Timer and C_Timer.After then
        C_Timer.After(ECHO_WAIT, function()
            if pend == mine then
                pend = nil
                Log("no echo for " .. token)
                if Missed then Missed() end
            end
        end)
    end
    return true
end

-- Dances again if it is time and the last try was a while ago.
function M.Redance(from)
    if not (on and dancing and due) then return false end
    local now = Now()
    if now < due or now - tried < RETRY then return false end
    if now - due > GIVE_UP then
        due = nil
        Log("gave up dancing again")
        return false
    end
    local done = Emote("DANCE", nil, from)
    if done then tried = now end           -- refused: the next chat line may try straight away
    if C_Timer and C_Timer.After then
        C_Timer.After(RETRY + 0.05, function() M.Redance("timer") end)
    end
    return done
end

-- Your own emote came back from the game: the last one went out. If it was meant for somebody and
-- does not name them, it went nowhere, so the other way of aiming is tried next time.
local function Echo(text)
    Log("echo " .. text)
    if not pend then
        -- one you did yourself: dancing or not is your call
        dancing = text:lower():find("danc", 1, true) ~= nil
        due = nil
        return
    end
    if pend.who and not text:find(pend.who, 1, true) then
        aimBy = pend.how == "unit" and "name" or "unit"
    end
    if pend.token == "DANCE" then due = nil end
    pend, misses = nil, 0
end
M.AimBy = function() return aimBy end

local SEND_GAP = 2               -- seconds between two replies, against a double click

-- The emote a visitor gets next: their group's and the "any" ones, in turn, so the same one does
-- not come up twice in a row.
local turn = {}
local function Pick(v, skip)
    local group = v.reply and v.reply[3] or "any"
    local pool, seen = {}, {}
    local function add(list)
        for _, t in ipairs(list or {}) do
            if not seen[t] then seen[t] = true; pool[#pool + 1] = t end
        end
    end
    add(M.EMOTES[group])
    if group ~= "any" and group ~= "look" then add(M.EMOTES.any) end
    if #pool == 0 then return nil end
    for _ = 1, #pool do
        turn[group] = (turn[group] or 0) % #pool + 1
        local t = pool[turn[group]]
        if t ~= skip or #pool == 1 then return t end
    end
end

-- The button text for a visitor's emote ("Wink"), or nil.
local function Label(v)
    return v and v.token and (M.LABEL[v.token] or v.token) or nil
end
M.Label = Label

local function Find(name)
    for i, v in ipairs(visitors) do
        if v.name == name then return v, i end
    end
end

-- Waiting for an answer: something came from them, a reply fits, and no answer went back since.
-- Somebody who only looked can be answered only in the first seconds, while they still have you
-- targeted (SuccuDev: "should only be able to do it within 10s of people targeting, while still targeted").
local function CanReply(v, now)
    if v.kind ~= "look" then return true end
    return now - v.at <= LOOK_WINDOW and v.seen ~= nil and now - v.seen <= STILL
end
M.CanReply = function(v) return CanReply(v, Now()) end

local function Waiting(v, now)
    return v.reply ~= nil and (not v.doneAt or v.doneAt < v.at) and now - v.at < WAIT and CanReply(v, now)
end
M.Waiting = function(v) return Waiting(v, Now()) end

local function Alert()
    local now = Now()
    if now - lastAlert < ALERT_GAP then return end
    lastAlert = now
    if type(PlaySound) == "function" then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081) end
    if type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
end

-- Somebody did something: to the top of the list, waiting for an answer again.
local function Visit(name, kind, what, reply, pitch)
    local v, i = Find(name)
    if v then table.remove(visitors, i) else v = { name = name } end
    v.kind, v.what, v.at = kind, what, Now()
    if reply ~= nil then v.reply = reply or nil end
    v.pitch = v.pitch or pitch or false
    if v.reply and (not v.token or reply) then v.token = Pick(v, v.token) end
    table.insert(visitors, 1, v)
    while #visitors > KEEP do table.remove(visitors) end
    if v.reply then Alert() end
    return v
end

-- Too old to matter: off the list.
local function Prune()
    local now = Now()
    for i = #visitors, 1, -1 do
        local v = visitors[i]
        local last = math.max(v.at, v.seen or 0, v.doneAt or 0)
        if now - last > (v.kind == "look" and LOOK_KEEP or KEEP_FOR) then table.remove(visitors, i) end
    end
end

local function Ago(sec)
    if sec < 10 then return "now" end
    if sec < 60 then return "<1m" end
    return math.floor(sec / 60) .. "m"
end

local function What(v, now)
    if v.kind == "look" then
        return (v.seen and now - v.seen < 5) and "is looking at you" or "looked at you"
    end
    return v.what
end

-- How bright a row is: new ones fade in, answered ones are dimmed, old ones fade out.
local function Alpha(v, now)
    local age = now - v.at
    if Waiting(v, now) then
        return age < 0.4 and math.max(0.2, age / 0.4) or 1
    end
    local a = (v.doneAt and v.doneAt >= v.at) and DONE_ALPHA or 1
    if age > FADE_FROM then
        local t = math.min(1, (age - FADE_FROM) / (FADE_TO - FADE_FROM))
        a = math.min(a, 1 - t * (1 - FADE_MIN))
    end
    return a
end
M.Alpha = function(v) return Alpha(v, Now()) end

-- Puts a visitor (or nobody) on a reply button.
local function SetReply(b, v)
    b.visitor = v
end

-- Who the big button is for: of those waiting, the one waiting longest, so nobody is skipped.
local function Next(now)
    local pick
    for _, v in ipairs(visitors) do
        if Waiting(v, now) then pick = v end
    end
    return pick
end
M.Next = function() return Next(Now()) end

local function Fade()
    if not (frame and frame:IsShown()) then return end
    local now = Now()
    for r = 1, ROWS do
        local v = visitors[r]
        if v then frame.rows[r]:SetAlpha(Alpha(v, now)) end
    end
    -- the big button pulses the way the game pulses a button that wants a click: its highlight, on and off
    local b = frame.cta.emote
    if b:IsShown() and b.visitor and math.floor(now * 2) % 2 == 0 then b:LockHighlight() else b:UnlockHighlight() end
end

Sync = function()
    if not (frame and frame:IsShown()) then return end
    local now = Now()
    local offer = ns.WareOffer()
    for r = 1, ROWS do
        local row, v = frame.rows[r], visitors[r]
        if v then
            row.name:SetText(Short(v.name))
            row.what:SetText(What(v, now))
            row.age:SetText(Ago(now - v.at))
            if v.reply then
                row.emote:SetText(Label(v) or "Emote")
                Fit(row.emote, 62)
                SetReply(row.emote, v)
                row.emote:SetEnabled(CanReply(v, now))
                row.emote:Show()
                row.done:SetShown((v.doneAt and v.doneAt >= v.at) and true or false)
            else
                SetReply(row.emote, nil)
                row.emote:Hide()
                row.done:Hide()
            end
            if v.pitch then
                local pitched = v.pitchedAt and now - v.pitchedAt < PITCH_GAP
                row.pitch:SetText(pitched and "Whispered" or "Whisper")
                Fit(row.pitch, 72)
                row.pitch:SetEnabled(not pitched and offer ~= nil)
                row.pitch:Show()
            else
                row.pitch:Hide()
            end
            row:Show()
        else
            SetReply(row.emote, nil)
            row:Hide()
        end
    end
    frame.empty:SetShown(#visitors == 0)

    -- the big button: whoever is waiting
    local cta, v = frame.cta, Next(now)
    if v then
        local who = Short(v.name)
        cta.text:SetText(v.kind == "emote" and v.what or (who .. " " .. What(v, now)))
        cta.text:SetFontObject(GameFontNormalLarge or GameFontNormal)
        local pitched = v.pitchedAt and now - v.pitchedAt < PITCH_GAP
        local canPitch = (v.pitch and offer ~= nil and not pitched) and true or false
        cta.again.visitor = v
        cta.again:Show()
        cta.pitch.visitor = v
        cta.pitch:SetShown(canPitch)
        -- the row of big buttons must fit the window: the send button gets what is left
        local room = CTA_W - Fit(cta.again, 100) - 6 - (canPitch and (Fit(cta.pitch, 110) + 6) or 0)
        local label = Label(v) or "Emote"
        cta.emote:SetText(label .. " at " .. who)
        local _, fits = Fit(cta.emote, 150, room)
        if not fits then
            cta.emote:SetText(label)
            Fit(cta.emote, 150, room)
        end
        SetReply(cta.emote, v)
        cta.emote:Show()
    else
        cta.text:SetText(#visitors == 0 and "Nobody yet. Stand where they can see you." or "Nobody is waiting for an answer.")
        cta.text:SetFontObject(GameFontDisableLarge or GameFontDisable)
        SetReply(cta.emote, nil)
        cta.emote:Hide()
        cta.again.visitor = nil
        cta.again:Hide()
        cta.pitch.visitor = nil
        cta.pitch:Hide()
    end
    frame.status:SetText(manual and "No emotes back by itself here: the replies are your click."
        or "The big button does that emote at them. Whisper price whispers your ware.")
    Fade()
end
M.Sync = function() Sync() end

-- They got their answer.
local function Done(v)
    if not v then return end
    v.doneAt = Now()
    Sync()
end

local lastSend = -1e9
-- The reply, on a click: the game's emote, at them. Then the next one is ready for next time.
function M.Reply(v)
    if not (v and v.token) then return false end
    local now = Now()
    if now - lastSend < SEND_GAP or not CanReply(v, now) then return false end
    if not Emote(v.token, v.name, "click") then
        ns.Print("the game refused the emote.")
        return false
    end
    lastSend = now
    v.emotedAt = now
    v.token = Pick(v, v.token)
    Done(v)
    return true
end

-- Another emote for them, without doing it.
function M.Another(v)
    if not (v and v.reply) then return false end
    v.token = Pick(v, v.token)
    Sync()
    return true
end

-- No echo, or the game said no. A few of those in a row: the shop stops emoting by itself.
Missed = function()
    misses = misses + 1
    if misses >= MISSES and on and not manual then
        manual = true
        ns.Print("the game does not let the shop emote by itself here. The buttons in the mailbox window do it with a click.")
        Sync()
    end
end

-- An emote by itself, if the limits allow. The dance comes back a few seconds later.
local function Auto(v, gap)
    if manual or not v.reply then return false end
    local now = Now()
    if now - lastAuto < GLOBAL_GAP or (v.emotedAt and now - v.emotedAt < gap) then return false end
    if not Emote(v.reply[2], v.name, "event") then
        Missed()
        return false
    end
    lastAuto, v.emotedAt = now, now
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

-- Was it your own emote? The game shows those to you too ("You greet everyone with a hearty hello!").
-- The name check alone missed them, so the wording and the sender's GUID count as well.
local function Mine(text, sender, guid)
    local me = Me()
    if me and Short(sender) == me then return true end
    if text:match("^You ") then return true end
    if guid ~= nil and Readable(guid) and type(UnitGUID) == "function" then
        local ok, mine = pcall(UnitGUID, "player")
        if ok and Readable(mine) and mine ~= nil and mine == guid then return true end
    end
    return false
end
M.Mine = Mine

local function OnEmote(text, sender, guid)
    if not (Readable(text) and Readable(sender) and type(text) == "string" and type(sender) == "string") then return end
    if sender == "" then return end
    if Mine(text, sender, guid) then
        Echo(text)
        -- your own emote, as the game showed it: whoever it names has their answer ("You wink at Bob.")
        local hit = false
        for _, v in ipairs(visitors) do
            if text:find(Short(v.name), 1, true) and not (v.doneAt and v.doneAt >= v.at) then
                v.doneAt = Now()
                hit = true
            end
        end
        if hit then Sync() end
        return
    end
    if not text:lower():find("%f[%a]you%f[%A]") then return end        -- only what is aimed at you
    local reply = ReplyFor(text)
    local v = Visit(sender, "emote", text, reply, true)
    if reply then Auto(v, PERSON_GAP) end
    Sync()
end

local function OnWhisper(text, sender)
    if not (Readable(text) and Readable(sender) and type(text) == "string" and type(sender) == "string") or sender == "" then return end
    local seen = Find(sender)
    Visit(sender, "whisper", "whispered: " .. text, (seen and seen.reply) or WHISPER_REPLY, true)
    Sync()
end

-- Who has you targeted: read off the nameplates in view (they must be shown for this to see anybody).
local function Look()
    if type(UnitExists) ~= "function" or type(UnitIsUnit) ~= "function" then return end
    local now = Now()
    for i = 1, 40 do
        local unit = "nameplate" .. i
        local ok, hit = pcall(function()
            return UnitExists(unit) and UnitIsPlayer(unit) and UnitIsUnit(unit .. "target", "player")
        end)
        if ok and Readable(hit) and hit then
            local name = NameOf(unit)
            if name then
                local v = Find(name)
                if not v then
                    v = Visit(name, "look", nil, LOOK_REPLY, false)
                elseif v.kind == "look" and now - math.max(v.at, v.seen or 0) > RELOOK then
                    v = Visit(name, "look", nil, nil, false)      -- looked away and came back
                elseif v.kind == "look" and now - (v.seen or v.at) > STILL then
                    v.at = now                                    -- targeted you again: a new ten seconds, quietly
                end
                v.seen = now
                Auto(v, LOOK_GAP)
            end
        end
    end
end

local function Tick()
    if not on then return end
    Look()
    Prune()
    Sync()
    C_Timer.After(2, Tick)
end

local function Button(parent, label, w, h)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not (ok and b) then b = CreateFrame("Button", nil, parent) end
    b:SetSize(w, h or 20)
    b:SetText(label)
    return b
end

-- A reply button: the game's panel button. Its click is what lets the emote go out.
local function ReplyButton(parent, label, w, h)
    local b = Button(parent, label, w, h)
    b:SetScript("OnClick", function(self) M.Reply(self.visitor) end)
    return b
end

local function Text(parent, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    if fs.SetFontObject and _G[font] then pcall(fs.SetFontObject, fs, _G[font]) end
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
    return fs
end

local function PitchTip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Whisper price")
    GameTooltip:AddLine("Whispers this person one line about the ware whose turn it is, with its price. "
        .. "Only for somebody who emoted at you or whispered you first, and once in ten minutes.", 1, 0.82, 0, true)
    GameTooltip:Show()
end

local function ReplyTip(self)
    local v = self.visitor
    if not (GameTooltip and v and v.reply) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText((Label(v) or "Emote") .. " at " .. Short(v.name))
    GameTooltip:AddLine("Does the game's /" .. v.token:lower() .. " at them.", 1, 0.82, 0, true)
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
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
    if v.kind == "whisper" then v.doneAt = now end      -- a whisper is answered by the pitch
    Sync()
    return true
end

local TOP = 96                  -- title, who is waiting, the big button

local function Build()
    if frame then return frame end
    local ok, f = pcall(CreateFrame, "Frame", "SlutmogShopMailbox", UIParent, "BasicFrameTemplateWithInset")
    if not (ok and f) then f = CreateFrame("Frame", "SlutmogShopMailbox", UIParent) end
    frame = f
    f:SetSize(430, TOP + ROWS * ROW_H + 46)
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
    local since = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < 0.1 then return end
        since = 0
        Fade()
    end)

    -- who is waiting, and the one big button for them
    local cta = {}
    f.cta = cta
    cta.text = Text(f, "GameFontNormalLarge")
    cta.text:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34)
    cta.text:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    cta.emote = ReplyButton(f, "Wink", 190, 30)
    cta.emote:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -58)
    cta.emote:SetScript("OnEnter", ReplyTip)
    cta.emote:SetScript("OnLeave", HideTip)
    cta.again = Button(f, "Other emote", 100, 30)
    cta.again:SetPoint("LEFT", cta.emote, "RIGHT", 6, 0)
    cta.again:SetScript("OnClick", function(self) M.Another(self.visitor) end)
    cta.again:Hide()
    cta.pitch = Button(f, "Whisper price", 110, 30)
    cta.pitch:SetPoint("LEFT", cta.again, "RIGHT", 6, 0)
    cta.pitch:SetScript("OnClick", function(self) M.Pitch(self.visitor) end)
    cta.pitch:SetScript("OnEnter", PitchTip)
    cta.pitch:SetScript("OnLeave", HideTip)
    cta.emote:Hide()
    cta.pitch:Hide()

    f.rows = {}
    for r = 1, ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -TOP - (r - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -TOP - (r - 1) * ROW_H)
        row.pitch = Button(row, "Whisper", 72)
        row.pitch:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.emote = ReplyButton(row, "Emote", 62)
        row.emote:SetPoint("RIGHT", row.pitch, "LEFT", -4, 0)
        row.emote:SetScript("OnEnter", ReplyTip)
        row.emote:SetScript("OnLeave", HideTip)
        row.done = row:CreateTexture(nil, "ARTWORK")        -- the game's ready-check tick: answered
        row.done:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        row.done:SetSize(14, 14)
        row.done:SetPoint("RIGHT", row.emote, "LEFT", -4, 0)
        row.done:Hide()
        row.age = Text(row, "GameFontDisableSmall")
        row.age:SetJustifyH("RIGHT")
        row.age:SetWidth(28)
        row.age:SetPoint("RIGHT", row.done, "LEFT", -4, 0)
        row.name = Text(row, "GameFontNormal")
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name:SetWidth(84)
        row.what = Text(row, "GameFontHighlightSmall")
        row.what:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.what:SetPoint("RIGHT", row.age, "LEFT", -6, 0)
        row.pitch:SetScript("OnClick", function() M.Pitch(visitors[r]) end)
        row.pitch:SetScript("OnEnter", PitchTip)
        row.pitch:SetScript("OnLeave", HideTip)
        row:Hide()
        f.rows[r] = row
    end
    f.empty = Text(f, "GameFontDisable")
    f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -TOP - 6)
    f.empty:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    if f.empty.SetWordWrap then f.empty:SetWordWrap(true) end
    f.empty:SetText("Whoever emotes at you, whispers you or targets you shows up here.")
    f.status = Text(f, "GameFontHighlightSmall")
    f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 16)
    f.status:SetPoint("RIGHT", f, "RIGHT", -92, 0)
    if f.status.SetWordWrap then f.status:SetWordWrap(true) end
    f.dance = Button(f, "Dance", 72)
    f.dance:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 12)
    f.dance:SetScript("OnClick", function() Emote("DANCE", nil, "click") end)
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
        events:SetScript("OnEvent", function(_, event, text, sender, ...)
            if not on then return end
            if event == "CHAT_MSG_TEXT_EMOTE" then OnEmote(text, sender, (select(10, ...)))
            elseif event == "CHAT_MSG_WHISPER" then OnWhisper(text, sender) end
            M.Redance(event)
        end)
    end
    for _, e in ipairs({ "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
        "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY", "CHAT_MSG_SYSTEM" }) do
        pcall(events.RegisterEvent, events, e)
    end
    on, manual, misses, pend, dancing, due = true, false, 0, nil, false, nil
    frame:Show()
    Emote("DANCE", nil, "start")
    Tick()
    ns.Print("mailbox mode is on. The big button winks or smiles at whoever is waiting. Close the window to turn it off.")
    return true
end

function M.Stop(fromHide)
    if not on then return end
    on = false
    if events then
        pcall(events.UnregisterAllEvents, events)
    end
    if frame and not fromHide then
        frame:Hide()
    end
    ns.Print("mailbox mode is off.")
end

function M.Toggle()
    if on then M.Stop() else M.Start() end
end

function M.IsOn() return on end
function M.Frame() return frame end
function M.Visitors() return visitors end
function M.Manual() return manual end
