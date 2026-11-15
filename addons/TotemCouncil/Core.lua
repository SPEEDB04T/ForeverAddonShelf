-- Totem Council: settings, the player's own totems, events, slash commands
local ADDON, ns = ...
local issecret = ns.issecret

local defaults = {
    shown = true,
    locked = false,
    scale = 1,
    idleAlpha = 0.55,       -- bar opacity when nothing needs attention
    clickCast = true,       -- left-click an icon to drop the planned totem
    clickThrough = false,   -- bar ignores the mouse completely
    sound = false,          -- soft ping when a planned totem goes missing in combat
    warnAlways = false,     -- warn about missing totems out of combat too
    soonSeconds = 10,       -- in combat a kept-up totem fades like a running-out buff below this
    autoAdopt = true,       -- an empty plan slot adopts the first totem dropped in it
    point = nil,
    boardPoint = nil,
    learned = {},           -- spellID -> { slot, name, icon, dur } for totems not in Data.lua
    durations = {},         -- spellID / key -> seconds, as read from the game
    debug = false,          -- /totems debug: record what the game reports about the group
    debugLog = {},
    commLog = {},           -- the last 40 addon messages in and out (always on; read from SavedVariables)
}
local charDefaults = {
    plan = {},              -- [slot] = totem key
}

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff3399ffTotem Council|r: " .. tostring(msg))
end

-- A value from the game as text; the game hides ("secret") some of them.
function ns.Show(v)
    if issecret(v) then return "<hidden>" end
    return tostring(v)
end

-- /totems debug: what the game reports is kept in the saved settings (and
-- shown in chat), so a problem in a real group can be looked at afterwards.
function ns.Debug(line)
    if not (ns.db and ns.db.debug) then return end
    local log = ns.db.debugLog
    if type(log) ~= "table" then
        log = {}
        ns.db.debugLog = log
    end
    local stamp = date and date("%H:%M:%S ") or ""
    log[#log + 1] = stamp .. line
    while #log > 500 do table.remove(log, 1) end
    ns.Print("|cff999999" .. line .. "|r")
end

-- Every addon message in and out, the last 40, always kept (not only with
-- /totems debug) and never printed: written to SavedVariables at /reload or
-- logout, so what really happened in a group can be read afterwards.
-- e = { dir = "in"/"out", channel, from (raw sender), unit (who it resolved
-- to, "me", "nobody" or "hidden"), code (the send result), msg }
function ns.CommLog(e)
    if not ns.db then return end
    local log = ns.db.commLog
    if type(log) ~= "table" then
        log = {}
        ns.db.commLog = log
    end
    local function safe(v, n)
        if v == nil then return nil end
        local s = issecret(v) and "<hidden>" or tostring(v)
        return n and s:sub(1, n) or s
    end
    log[#log + 1] = {
        t = (date and date("%H:%M:%S")) or ("%.1f"):format(GetTime()),
        dir = e.dir, channel = safe(e.channel), from = safe(e.from, 60),
        unit = safe(e.unit), code = safe(e.code), msg = safe(e.msg, 40),
    }
    while #log > 40 do table.remove(log, 1) end
end

-- Run something without letting an error repeat every frame in the error log.
local seenErrors, errorCount = {}, 0
function ns.Safe(f, ...)
    local ok, err = pcall(f, ...)
    if ok then return true end
    local msg = issecret(err) and "blocked by a secret value" or tostring(err)
    if not seenErrors[msg] and errorCount < 5 then
        seenErrors[msg] = true
        errorCount = errorCount + 1
        ns.Print("|cffff6060error:|r " .. msg)
    end
    return false
end

-- Error lines are capped per zone, so a later problem still gets reported.
function ns.ResetErrors()
    seenErrors, errorCount = {}, 0
end

----------------------------------------------------------------------
-- Look: the game's own colours and button art, so every frame reads as
-- part of the default UI. Values match Blizzard's in case a constant is missing.
----------------------------------------------------------------------
local function GameColor(c, r, g, b)
    if type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { r, g, b }
end
ns.COLOR = {
    gold   = GameColor(NORMAL_FONT_COLOR, 1, 0.82, 0),
    white  = GameColor(HIGHLIGHT_FONT_COLOR, 1, 1, 1),
    gray   = GameColor(GRAY_FONT_COLOR, 0.5, 0.5, 0.5),
    red    = GameColor(RED_FONT_COLOR, 1, 0.125, 0.125),
    orange = GameColor(ORANGE_FONT_COLOR, 1, 0.5, 0.25),
    yellow = GameColor(YELLOW_FONT_COLOR, 1, 1, 0),
    green  = GameColor(GREEN_FONT_COLOR, 0.1, 1, 0.1),
    blue   = GameColor(LIGHTBLUE_FONT_COLOR, 0.53, 0.67, 1),
}
local shamanColor = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS.SHAMAN
ns.COLOR.shaman = GameColor(shamanColor, 0, 0.44, 0.87)

-- text in one of those colours
function ns.Paint(key, text)
    local c = ns.COLOR[key] or ns.COLOR.white
    local function hex(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x%s|r"):format(hex(c[1]), hex(c[2]), hex(c[3]), tostring(text))
end

-- One button of the game's own totem bar (MultiCastActionButton and the
-- MultiCastSlotButton under it, Blizzard_ActionBar/Shared/
-- MultiCastActionBarFrame.xml and .lua), at the game's size: 30 x 30, the
-- action-button frame resized to 30 x 30 as MultiCastActionButton_OnLoad
-- does, the element's empty-slot picture behind the icon and the element's
-- coloured ring (overlayTex, 34 x 34) on top. Bigger or smaller comes from
-- the parent's scale, never from resizing the art.
ns.TOTEM_BUTTON = 30
ns.TOTEM_GAP = 8            -- the game's totem bar: x = 8 between buttons
local TOTEMBAR = "Interface\\Buttons\\UI-TotemBar"
-- SLOT_EMPTY_TCOORDS and SLOT_OVERLAY_TCOORDS (locals in the game's file)
local SLOT_EMPTY = {
    [1] = { 67 / 128, 97 / 128, 100 / 256, 130 / 256 },  -- fire
    [2] = { 66 / 128, 96 / 128, 3 / 256, 33 / 256 },     -- earth
    [3] = { 39 / 128, 69 / 128, 209 / 256, 239 / 256 },  -- water
    [4] = { 66 / 128, 96 / 128, 36 / 256, 66 / 256 },    -- air
}
local SLOT_OVERLAY = {
    [1] = { 36 / 128, 70 / 128, 172 / 256, 206 / 256 },
    [2] = { 1 / 128, 35 / 128, 172 / 256, 206 / 256 },
    [3] = { 1 / 128, 35 / 128, 207 / 256, 240 / 256 },
    [4] = { 36 / 128, 70 / 128, 137 / 256, 171 / 256 },
}

-- rounds the icon's corners to fit inside the frame art, as
-- ActionButtonTemplate's IconMask does
function ns.IconMask(b, icon, size)
    if not b.CreateMaskTexture or not icon.AddMaskTexture then return end
    local m = b:CreateMaskTexture()
    if not m then return end
    m:SetAtlas("UI-HUD-ActionBar-IconFrame-Mask")
    m:SetPoint("CENTER", icon, "CENTER")
    m:SetSize(size, size)
    icon:AddMaskTexture(m)
end

function ns.TotemButtonArt(b, slot)
    local S = ns.TOTEM_BUTTON
    b:SetSize(S, S)

    -- MultiCastSlotButtonTemplate: the element's empty slot (BACKGROUND)
    b.slotBg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.slotBg:SetTexture(TOTEMBAR)
    b.slotBg:SetAllPoints()
    local e = SLOT_EMPTY[slot]
    if e then b.slotBg:SetTexCoord(e[1], e[2], e[3], e[4]) end

    -- ActionButtonTemplate: icon (BACKGROUND) with its mask
    b.icon = b:CreateTexture(nil, "BACKGROUND")
    b.icon:SetAllPoints()
    ns.IconMask(b, b.icon, S)

    -- NormalTexture, PushedTexture, HighlightTexture, each 30 x 30 at TOPLEFT
    local function frameArt(setter, getter, atlas)
        if not b[setter] then return end
        b[setter](b, atlas)
        local t = b[getter] and b[getter](b)
        if t then
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT")
            t:SetSize(S, S)
        end
    end
    frameArt("SetNormalAtlas", "GetNormalTexture", "UI-HUD-ActionBar-IconFrame")
    frameArt("SetPushedAtlas", "GetPushedTexture", "UI-HUD-ActionBar-IconFrame-Down")
    frameArt("SetHighlightAtlas", "GetHighlightTexture", "UI-HUD-ActionBar-IconFrame-Mouseover")

    -- the template's CheckedTexture (Mouseover atlas, ADD); shown by hand
    -- because these are plain buttons, not check buttons
    b.checked = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.checked:SetAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
    if b.checked.SetBlendMode then b.checked:SetBlendMode("ADD") end
    b.checked:SetPoint("TOPLEFT")
    b.checked:SetSize(S, S)
    b.checked:Hide()

    -- MultiCastActionButtonTemplate: the element ring, 34 x 34 CENTER, OVERLAY
    b.overlayTex = b:CreateTexture(nil, "OVERLAY")
    b.overlayTex:SetTexture(TOTEMBAR)
    b.overlayTex:SetSize(34, 34)
    b.overlayTex:SetPoint("CENTER")
    local o = SLOT_OVERLAY[slot]
    if o then b.overlayTex:SetTexCoord(o[1], o[2], o[3], o[4]) end

    -- cooldown: inset 3 from the icon, swipe black at 0.64, no edge, no bling
    b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetPoint("TOPLEFT", 3, -3)
    b.cd:SetPoint("BOTTOMRIGHT", -3, 3)
    b.cd.noCooldownCount = true     -- keep cooldown-text addons off it; the time is under the button
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(true) end
    if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
    if b.cd.SetDrawBling then b.cd:SetDrawBling(false) end
    if b.cd.SetSwipeColor then b.cd:SetSwipeColor(0, 0, 0, 0.64) end

    -- TextOverlayContainer: above the cooldown. Holds the one marker the bar
    -- uses, in the hotkey's place: the game's range dot (RANGE_INDICATOR),
    -- in red, as action buttons show it when the target is out of range.
    b.textOverlay = CreateFrame("Frame", nil, b)
    b.textOverlay:SetAllPoints()
    b.textOverlay:SetFrameLevel(b.cd:GetFrameLevel() + 2)
    b.marker = b.textOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    b.marker:SetSize(32, 10)
    if b.marker.SetJustifyH then b.marker:SetJustifyH("RIGHT") end
    b.marker:SetPoint("TOPRIGHT", -4, -5)
    local red = ns.COLOR.red
    b.marker:SetTextColor(red[1], red[2], red[3])
    b.marker:SetText(type(RANGE_INDICATOR) == "string" and RANGE_INDICATOR or "\226\151\143")
    b.marker:Hide()

    -- AuraButtonArtTemplate's Duration: GameFontNormalSmall, TOP to the
    -- icon's BOTTOM; gold, white under a minute (BUFF_DURATION_WARNING_TIME)
    b.duration = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.duration:SetPoint("TOP", b, "BOTTOM", 0, 0)
    b.duration:Hide()
    return b
end

-- the duration text the game's buff icons use (SecondsToTimeAbbrev: "2 m",
-- then whole seconds below 90), gold, white below a minute
local DURATION_WARNING = 60
function ns.SetDuration(b, left)
    if not left then
        b.duration:Hide()
        return
    end
    b.duration:SetText(ns.FormatTime(left))
    local c = left < DURATION_WARNING and ns.COLOR.white or ns.COLOR.gold
    b.duration:SetTextColor(c[1], c[2], c[3])
    b.duration:Show()
end

function ns.FormatTime(sec)
    if sec < 0 then sec = 0 end
    if SecondsToTimeAbbrev then
        local ok, fmt, v = pcall(SecondsToTimeAbbrev, sec)
        if ok and type(fmt) == "string" and type(v) == "number" then
            local ok2, text = pcall(string.format, fmt, v)
            if ok2 then return text end
        end
    end
    -- the same rule as the game's SecondsToTimeAbbrev (threshold 1.5)
    if sec >= 86400 * 1.5 then return ("%d d"):format(math.ceil(sec / 86400)) end
    if sec >= 3600 * 1.5 then return ("%d h"):format(math.ceil(sec / 3600)) end
    if sec >= 60 * 1.5 then return ("%d m"):format(math.ceil(sec / 60)) end
    return ("%d s"):format(math.floor(sec))
end

-- The fade the game's buff icons use while they run out
-- (AuraContainerTemplate: period 1.5 s, alpha 0.3 to 1.0, BOUNCE).
function ns.WarningAlpha(now)
    local p = (now % 1.5) / 0.75
    if p > 1 then p = 2 - p end
    return 0.3 + 0.7 * p
end

-- the game's dark dialog box (StaticPopup look), for frames without a template
function ns.DialogBackdrop(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop(BACKDROP_DARK_DIALOG_32_32 or {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileEdge = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
end

local function PlayerDead()
    if not UnitIsDeadOrGhost then return false end
    local ok, dead = pcall(UnitIsDeadOrGhost, "player")
    return ok and not issecret(dead) and dead and true or false
end

----------------------------------------------------------------------
-- The player's own totems
-- ns.active[slot] = { key, spellID, name, rawName, icon, start, duration, castAt, src }
----------------------------------------------------------------------
ns.active = {}
ns.unknown = {}     -- [slot] = true: the game hides this slot and nothing has been seen in it yet
ns.dirty = true

local function SetActive(slot, entry)
    ns.active[slot] = entry
    ns.dirty = true
    ns.Group.MarkLive()     -- other Totem Council users are told what is down
end

-- Reads one slot from the game. Returns false when the game hides it (secret),
-- true when the slot was readable (ns.active is then exact).
function ns.ReadSlot(slot)
    if not GetTotemInfo then return false end
    local ok, have, name, start, dur, icon, _, spellID = pcall(GetTotemInfo, slot)
    if not ok or issecret(have) or issecret(name) or issecret(start) or issecret(dur) then return false end
    ns.unknown[slot] = nil
    local now = GetTime()
    local cur = ns.active[slot]
    local up = have and type(name) == "string" and name ~= "" and type(start) == "number" and start > 0
        and type(dur) == "number" and dur > 0 and start + dur > now
    if not up then
        -- right after a cast the totem may not be registered yet
        if cur and cur.castAt and now - cur.castAt < 0.6 then return true end
        if cur then SetActive(slot, nil) end
        return true
    end
    local sid = (not issecret(spellID)) and type(spellID) == "number" and spellID > 0 and spellID or nil
    local shownIcon = (not issecret(icon)) and icon or nil
    if cur and cur.rawName == name and math.abs((cur.start + cur.duration) - (start + dur)) < 0.05 then
        cur.src = "read"
        return true
    end
    local key = (sid and ns.KeyBySpellID(sid)) or ns.KeyByName(name)
    if not key and sid then key = ns.Learn(sid, slot, name, shownIcon, dur) end
    local info = key and ns.Info(key)
    if key then ns.RememberDuration(key, sid, dur) end
    SetActive(slot, {
        key = key, spellID = sid, rawName = name,
        name = info and info.name or name,
        icon = shownIcon or (info and info.icon),
        start = start, duration = dur, src = "read",
        castAt = cur and cur.castAt,
    })
    return true
end

function ns.ReadAllSlots()
    for slot = 1, 4 do ns.ReadSlot(slot) end
end

-- After a loading screen or a death the totems are gone. Readable slots say
-- so themselves; in hidden slots the old timers would keep counting.
local function ForgetTotems(afterLoading)
    for slot = 1, 4 do
        if ns.active[slot] then SetActive(slot, nil) end
        if afterLoading then ns.unknown[slot] = true end
    end
    ns.ReadAllSlots()
end

-- The player's own cast is always visible, so it keeps the timers going in
-- places where the totem slots themselves are hidden.
local function OnPlayerCast(spellID)
    local key = ns.KeyBySpellID(spellID)
    local name, icon = ns.SpellInfo(spellID)
    if not key and name then key = ns.KeyByExactName(name) end
    if not key then return end
    local info = ns.Info(key)
    local slot = info and info.slot
    if not slot then return end
    local now = GetTime()
    ns.unknown[slot] = nil
    SetActive(slot, {
        key = key, spellID = spellID,
        name = name or info.name, icon = icon or info.icon,
        start = now, duration = ns.Duration(key, spellID), src = "cast", castAt = now,
    })
    -- a temporary totem (Grounding, Fire Nova, ...) never becomes the plan by being dropped
    if ns.db.autoAdopt and not ns.cdb.plan[slot] and not info.temp then ns.SetPlan(slot, key) end
    C_Timer.After(0.3, function() ns.Safe(ns.ReadSlot, slot) end)
end

local function OnTotemUpdate(slot)
    if issecret(slot) or type(slot) ~= "number" then
        ns.ReadAllSlots()
        return
    end
    if slot < 1 or slot > 4 then return end
    if ns.ReadSlot(slot) then return end
    -- Hidden slot: something changed. Keep the totem if the player just cast
    -- it, otherwise it died, expired or was replaced.
    local cur = ns.active[slot]
    if not cur then return end
    if cur.castAt and GetTime() - cur.castAt < 0.6 then return end
    C_Timer.After(0.4, function()
        ns.Safe(function()
            if ns.active[slot] ~= cur then return end   -- a new cast took the slot
            if ns.ReadSlot(slot) then return end
            SetActive(slot, nil)
        end)
    end)
end

----------------------------------------------------------------------
-- Plan
----------------------------------------------------------------------
function ns.SetPlan(slot, key)
    if key and not ns.ValidKey(key, slot) then return end
    ns.cdb.plan[slot] = key
    ns.dirty = true
    ns.HUD.ApplySecure()
    ns.Group.BroadcastState()
end

-- A planned totem is not down and it is worth saying so: not while dead, and
-- not for a hidden slot nothing has been seen in yet (it may well be up).
local function ShouldWarn(slot)
    return ns.active[slot] == nil and ns.cdb.plan[slot] ~= nil
        and (ns.inCombat or ns.db.warnAlways) and not ns.unknown[slot] and not ns.dead
        and true or false
end

-- Everything the bar needs to draw one element.
function ns.SlotStatus(slot)
    local a, plan = ns.active[slot], ns.cdb.plan[slot]
    local st = { active = a, plan = plan }
    if a then
        st.remaining = a.start + a.duration - GetTime()
        -- a temporary totem standing in for the planned one is the player's own
        -- call: no "different totem" note or running-out fade for it. The
        -- missing warning comes back by itself once it is gone.
        local info = a.key and ns.Info(a.key)
        st.temp = info and info.temp or false
        st.state = (plan and a.key ~= plan and not st.temp) and "offplan" or "ok"
    elseif plan then
        st.state = "missing"
    else
        st.state = "empty"
    end
    st.warn = ShouldWarn(slot)
    st.overlap = ns.Group.Overlaps(slot)
    st.conflict = ns.Group.PlanConflictsFor(slot)
    return st
end

local function Ping()
    if not ns.db.sound then return end
    pcall(PlaySound, (SOUNDKIT and SOUNDKIT.MAP_PING) or 3175, "Master")
end

local wasWarn, wasOverlap = {}, {}
local function CheckAlerts()
    if not ns.isShaman then return end
    for slot = 1, 4 do
        local warn = ShouldWarn(slot)
        if warn and not wasWarn[slot] then Ping() end
        wasWarn[slot] = warn
        local overlap = ns.Group.Overlaps(slot) ~= nil
        if overlap and not wasOverlap[slot] then Ping() end
        wasOverlap[slot] = overlap
    end
end

----------------------------------------------------------------------
-- Update loop
----------------------------------------------------------------------
local driver = CreateFrame("Frame")
local fast, slow = 0, 0

local function Tick(_, elapsed)
    fast = fast + elapsed
    if fast < 0.1 then return end
    slow = slow + fast
    fast = 0
    local now = GetTime()
    for slot = 1, 4 do
        local a = ns.active[slot]
        if a and a.start + a.duration <= now then SetActive(slot, nil) end
    end
    if slow >= 1 then
        slow = 0
        if ns.isShaman then ns.ReadAllSlots() end
        ns.Group.Tick(now)
        ns.dirty = true
    end
    ns.dead = PlayerDead()
    -- each step on its own, so a problem in one does not stop the others
    ns.Safe(CheckAlerts)
    ns.Safe(ns.HUD.Update)
    if ns.dirty then
        ns.dirty = false
        ns.Safe(ns.Board.Refresh)
    end
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local events = {}

function events.PLAYER_TOTEM_UPDATE(slot)
    if ns.isShaman then OnTotemUpdate(slot) end
end

function events.UNIT_SPELLCAST_SUCCEEDED(unit, _, spellID)
    if issecret(unit) or type(unit) ~= "string" then return end
    if unit == "player" then
        if issecret(spellID) or type(spellID) ~= "number" then return end
        if ns.isShaman then OnPlayerCast(spellID) end
    elseif unit:find("^party%d+$") or unit:find("^raid%d+$") then
        ns.Group.ObserveCast(unit, spellID)     -- copes with a hidden spell itself
    end
end

function events.PLAYER_LOGOUT()
    if ns.db and ns.db.debug then ns.Group.DebugSnapshot() end
end

function events.PLAYER_ENTERING_WORLD()
    ns.ResetErrors()
    ns.inCombat = InCombatLockdown() and true or false
    if ns.isShaman then ns.Safe(ForgetTotems, true) end
    ns.Safe(ns.Group.Rebuild)
    ns.Safe(ns.HUD.ApplySecure)
end

function events.PLAYER_DEAD()
    if ns.isShaman then ForgetTotems(false) end
end

function events.GROUP_ROSTER_UPDATE()
    ns.Group.Rebuild()
end

function events.PLAYER_REGEN_DISABLED()
    ns.inCombat = true
    ns.dirty = true
end

function events.PLAYER_REGEN_ENABLED()
    ns.inCombat = false
    ns.dirty = true
    ns.HUD.ApplySecure()
end

function events.SPELLS_CHANGED()
    ns.InvalidateKnown()
    ns.HUD.ApplySecure()
    ns.Group.BroadcastState()
end

function events.CHAT_MSG_ADDON(prefix, text, channel, sender)
    ns.Group.OnAddonMessage(prefix, text, channel, sender)
end

local function Init()
    TotemCouncilDB = TotemCouncilDB or {}
    TotemCouncilCharDB = TotemCouncilCharDB or {}
    for k, v in pairs(defaults) do
        if TotemCouncilDB[k] == nil then TotemCouncilDB[k] = type(v) == "table" and {} or v end
    end
    for k, v in pairs(charDefaults) do
        if TotemCouncilCharDB[k] == nil then TotemCouncilCharDB[k] = type(v) == "table" and {} or v end
    end
    ns.db, ns.cdb = TotemCouncilDB, TotemCouncilCharDB

    local _, class = UnitClass("player")
    ns.isShaman = (class == "SHAMAN")
    ns.playerName = UnitName("player")
    ns.inCombat = InCombatLockdown() and true or false

    -- drop plan entries that no longer mean anything
    for slot, key in pairs(ns.cdb.plan) do
        if not ns.ValidKey(key, slot) then ns.cdb.plan[slot] = nil end
    end

    -- each part on its own, so one failing does not take the others with it
    ns.Safe(ns.Group.Init)
    ns.Safe(ns.HUD.Create)
    ns.Safe(ns.Board.Create)
    -- Kit.lua and Options.lua are new in 1.1.0. After an update the game only
    -- loads new files once it has been restarted, so a /reload runs without
    -- them: everything else must still work.
    if ns.Options then ns.Safe(ns.Options.Init) end

    for ev in pairs(events) do pcall(driver.RegisterEvent, driver, ev) end
    driver:SetScript("OnEvent", function(_, event, ...)
        local handler = events[event]
        if handler then ns.Safe(handler, ...) end
    end)
    driver:SetScript("OnUpdate", function(self, elapsed) ns.Safe(Tick, self, elapsed) end)

    if ns.isShaman and not ns.db.welcomed then
        ns.db.welcomed = true
        ns.Print("drag the totem bar where you want it, then /totems lock. Right-click an icon to pick the totem you want kept up. /totems help for more.")
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function() ns.Safe(Init) end)

----------------------------------------------------------------------
-- Actions shared by the slash commands, the options window and the minimap button
----------------------------------------------------------------------
function ns.ToggleDemo()
    ns.Group.SetDemo(not ns.Group.demo)
    ns.Print(ns.Group.demo and "demo on: two pretend shamans joined your group. /totems demo again to remove them." or "demo off.")
    if ns.Group.demo then ns.Board.Show() end
end

function ns.ClearPlan()
    for slot = 1, 4 do ns.cdb.plan[slot] = nil end
    ns.dirty = true
    ns.HUD.ApplySecure()
    ns.Group.BroadcastState()
    ns.Print("plan cleared.")
end

function ns.ResetSettings()
    if InCombatLockdown() then ns.Print("can't reset in combat.") return end
    local db = ns.db
    local learned, durations = db.learned, db.durations
    for k in pairs(db) do db[k] = nil end
    for k, v in pairs(defaults) do db[k] = type(v) == "table" and {} or v end
    db.learned, db.durations, db.welcomed = learned, durations, true
    ns.HUD.RestorePosition()
    ns.HUD.ApplySecure()
    if ns.Kit then ns.Kit.RefreshMinimap() end
    ns.Print("settings reset.")
end

----------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------
local function OnOff(v) return v and "on" or "off" end

local function Help()
    ns.Print("commands:")
    ns.Print("  /totems  - show or hide the totem bar")
    ns.Print("  /totems plan  - open the group plan (who drops what, conflicts, sort it out)")
    ns.Print("  /totems config  - open the options window")
    ns.Print("  /totems minimap  - show or hide the minimap button")
    ns.Print("  /totems lock | unlock | scale <0.5-2> | fade <0.1-1>")
    ns.Print("  /totems click  - left-click drops the planned totem (" .. OnOff(ns.db.clickCast) .. ")")
    ns.Print("  /totems mouse  - bar reacts to the mouse (" .. OnOff(not ns.db.clickThrough) .. ")")
    ns.Print("  /totems sound  - ping when a planned totem goes missing or doubles up (" .. OnOff(ns.db.sound) .. ")")
    ns.Print("  /totems warn  - warn out of combat too (" .. OnOff(ns.db.warnAlways) .. ")")
    ns.Print("  /totems adopt  - empty plan slots adopt what you drop (" .. OnOff(ns.db.autoAdopt) .. ")")
    ns.Print("  /totems clear | status | demo | reset")
    ns.Print("  /totems debug  - record what the game reports about your group, to track down a problem (" .. OnOff(ns.db.debug) .. ")")
end

local function Status()
    for _, slot in ipairs(ns.SLOT_ORDER) do
        local el = ns.ELEMENTS[slot]
        local a, plan = ns.active[slot], ns.cdb.plan[slot]
        local planInfo = plan and ns.Info(plan)
        local hidden = "?"
        if C_Secrets and C_Secrets.ShouldTotemSlotBeSecret then
            local ok, v = pcall(C_Secrets.ShouldTotemSlotBeSecret, slot)
            if ok and not issecret(v) then hidden = v and "hidden" or "readable" end
        end
        ns.Print(("%s: plan %s, active %s (%s), slot %s"):format(el.name,
            planInfo and planInfo.name or "none",
            a and a.name or "none",
            a and (("%ds left, from %s"):format(math.floor(a.start + a.duration - GetTime()), a.src)) or "-",
            hidden))
    end
    ns.Group.PrintStatus()
    if ns.db.debug then ns.Group.DebugSnapshot() end
end

SLASH_TOTEMCOUNCIL1 = "/totems"
SLASH_TOTEMCOUNCIL2 = "/totemcouncil"
SLASH_TOTEMCOUNCIL3 = "/tcouncil"
SlashCmdList.TOTEMCOUNCIL = function(msg)
    if not ns.db then return end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local db = ns.db
    if cmd == "plan" or cmd == "group" or cmd == "council" then
        ns.Board.Toggle()
    elseif cmd == "demo" then
        ns.ToggleDemo()
    elseif cmd == "config" or cmd == "options" or cmd == "opt" then
        if ns.Kit then ns.Kit.Open() else ns.Print("the options window appears after you restart the game once (this update added new files).") end
    elseif cmd == "status" then
        Status()
    elseif cmd == "debug" then
        if not db.debug then
            db.debug, db.debugLog = true, {}
            ns.Print("recording what the game reports about your group. Drop totems with the other shaman for a minute, then /totems debug again and /reload.")
            ns.Group.DebugSnapshot()
        else
            ns.Group.DebugSnapshot()
            db.debug = false
            ns.Print("recording stopped. /reload or log out to save it.")
        end
    elseif cmd == "help" or cmd == "?" then
        Help()
    elseif not ns.isShaman then
        ns.Print("the totem bar is for Shamans. /totems plan opens the group plan.")
    elseif cmd == "minimap" then
        if ns.Kit then
            ns.Kit.SetMinimapShown(not ns.Kit.MinimapShown())
            ns.Print("minimap button " .. OnOff(ns.Kit.MinimapShown()) .. ".")
        else
            ns.Print("the minimap button appears after you restart the game once (this update added new files).")
        end
    elseif cmd == "" then
        if InCombatLockdown() then ns.Print("can't show or hide the bar in combat.") return end
        db.shown = not db.shown
        ns.HUD.ApplySecure()
        ns.Print(db.shown and "bar shown." or "bar hidden. /totems shows it again.")
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        ns.Print(db.locked and "bar locked." or "bar unlocked: drag an icon to move it.")
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2 and not InCombatLockdown() then
            db.scale = n
            ns.HUD.ApplySecure()
        else
            ns.Print("usage: /totems scale 1.2 (out of combat)")
        end
    elseif cmd == "fade" or cmd == "alpha" then
        local n = tonumber(arg)
        if n and n >= 0.1 and n <= 1 then
            db.idleAlpha = n
        else
            ns.Print("usage: /totems fade 0.5 (opacity while nothing needs attention)")
        end
    elseif cmd == "click" then
        db.clickCast = not db.clickCast
        ns.HUD.ApplySecure()
        ns.Print("left-click casting " .. OnOff(db.clickCast) .. (InCombatLockdown() and " (applies after combat)" or ""))
    elseif cmd == "mouse" then
        db.clickThrough = not db.clickThrough
        ns.HUD.ApplySecure()
        ns.Print((db.clickThrough and "bar now ignores the mouse. /totems mouse to undo." or "bar reacts to the mouse again.")
            .. (InCombatLockdown() and " (applies after combat)" or ""))
    elseif cmd == "sound" then
        db.sound = not db.sound
        ns.Print("totem ping (missing or doubled up) " .. OnOff(db.sound))
    elseif cmd == "warn" then
        db.warnAlways = not db.warnAlways
        ns.Print(db.warnAlways and "warning about missing totems in and out of combat." or "warning about missing totems in combat only.")
    elseif cmd == "adopt" then
        db.autoAdopt = not db.autoAdopt
        ns.Print("adopting dropped totems into empty plan slots " .. OnOff(db.autoAdopt))
    elseif cmd == "clear" then
        ns.ClearPlan()
    elseif cmd == "reset" then
        ns.ResetSettings()
    else
        Help()
    end
    if ns.Kit then ns.Kit.Sync() end    -- an open options window follows what was typed
end

-- LookShots (a helper on the developer's machine only): the frames this addon
-- draws itself, so each gets a screenshot the first time it shows. Harmless
-- without it. The options window and minimap button are listed by the kit.
LookShotsTargets = LookShotsTargets or {}
LookShotsTargets[ADDON] = {
    version = ns.VERSION,
    frames = {
        { label = "totem bar", frame = function() return TotemCouncilHUD end },
        { label = "group plan", frame = function() return TotemCouncilBoard end },
        { label = "accept box", frame = function() return TotemCouncilToast end },
        { label = "totem menu", frame = function() return TotemCouncilMenu end },
    },
}
