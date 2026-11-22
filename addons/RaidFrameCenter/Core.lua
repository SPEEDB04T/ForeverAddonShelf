--[[
    Raid Frame Center
    Keeps the game's own raid frames and party frames centered on the spot you put them in
    Edit Mode, so they grow out from the middle (both sides at once) instead of to the right,
    and gives them a different size for each group size: party, 10, 20, 25 and 40 players.

    How it works, and why this way (Blizzard UI source, Gethe/wow-ui-source branch forever):
      * The raid frames (CompactRaidFrameContainer) and the party frames (PartyFrame) are Edit
        Mode frames anchored by their top left corner. The game resizes them to fit whoever is
        in the group, also in combat. Anchored by their top middle instead, every such resize
        keeps them centered, with no help from this addon, in combat too.
      * The game sets every raid frame's width and height back to the Edit Mode values on each
        roster change, in combat as well, and only its own layout code can place the frames
        again. Calling that code from an addon would taint the raid frames. So the size per
        group is a scale on the whole container: the shape (width, height) stays Edit Mode's.
      * Edit Mode puts its own Lua versions of SetPoint, ClearAllPoints and SetScale on these
        frames. This addon calls the frame's original methods instead, so nothing of Edit
        Mode's runs in the addon's name, and only hooks (hooksecurefunc) the rest.
      * Frames with protected unit buttons inside cannot be moved or scaled by an addon in
        combat: changes wait for the end of the fight.
      * While Edit Mode is open the frames go back to Edit Mode's own anchor, so dragging and
        saving work as usual. The middle of the box you see there is the spot remembered (per
        Edit Mode layout) and used once Edit Mode closes.

    /rfc            -> options window
    /rfc status     -> what it is doing now
    /rfc on | off   -> switch it on or off
]]

local ADDON_NAME, ns = ...

local PREFIX = "|cffffd100Raid Frame Center|r: "

local DEFAULTS = {
    enabled     = true,
    centerRaid  = true,     -- raid frames grow out from the middle
    centerParty = true,     -- party frames (raid style or not) too
    grow        = "down",   -- "down": top edge stays, "both": middle stays, "up": bottom edge stays
    sizeParty   = 100,      -- percent of the Edit Mode size, by group size
    size10      = 100,
    size20      = 100,
    size25      = 100,
    size40      = 100,
}
local CHOICES = { grow = { down = true, both = true, up = true } }
local SIZE_MIN, SIZE_MAX = 50, 200
ns.SIZE_MIN, ns.SIZE_MAX = SIZE_MIN, SIZE_MAX

local GROW_POINT = { down = "TOP", both = "CENTER", up = "BOTTOM" }

local db
local FrameMethods              -- the C methods every frame has, under Edit Mode's overrides
local targets = {}              -- "raid" / "party" -> state of that frame
ns.targets = targets
local inCombatWait = false
local editTicker

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end
ns.Print = Print

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
local function LoadDB()
    if type(RaidFrameCenterDB) ~= "table" then RaidFrameCenterDB = {} end
    db = RaidFrameCenterDB
    for k, v in pairs(DEFAULTS) do
        if db[k] == nil or type(db[k]) ~= type(v) then db[k] = v end
    end
    for k, allowed in pairs(CHOICES) do
        if not allowed[db[k]] then db[k] = DEFAULTS[k] end
    end
    for _, k in ipairs({ "sizeParty", "size10", "size20", "size25", "size40" }) do
        db[k] = math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor(db[k] + 0.5)))
    end
    if type(db.spots) ~= "table" then db.spots = {} end   -- [layout] = { raid = {l,b,w,h}, party = {...} }
    ns.db = db
end

---------------------------------------------------------------------------
-- Group size
---------------------------------------------------------------------------
-- Which size setting applies to a frame now.
local function SizeKey(which)
    if which == "party" then return "sizeParty" end
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    if not (IsInRaid and IsInRaid()) then return "sizeParty" end
    if n <= 10 then return "size10" end
    if n <= 20 then return "size20" end
    if n <= 25 then return "size25" end
    return "size40"
end
ns.SizeKey = SizeKey

local SIZE_NAMES = { sizeParty = "party", size10 = "raid up to 10", size20 = "raid up to 20",
                     size25 = "raid up to 25", size40 = "raid up to 40" }

---------------------------------------------------------------------------
-- Edit Mode, read only
---------------------------------------------------------------------------
local function EditModeActive()
    local em = EditModeManagerFrame
    if not (em and em.IsEditModeActive) then return false end
    local ok, active = pcall(em.IsEditModeActive, em)
    return ok and active and true or false
end

local function LayoutKey()
    local em = EditModeManagerFrame
    if em and em.GetActiveLayoutInfo then
        local ok, info = pcall(em.GetActiveLayoutInfo, em)
        if ok and type(info) == "table" and type(info.layoutName) == "string" and info.layoutName ~= "" then
            return info.layoutName
        end
    end
    return "default"
end

---------------------------------------------------------------------------
-- The frames
---------------------------------------------------------------------------
local function Num(v)
    if v == nil or (issecretvalue and issecretvalue(v)) or type(v) ~= "number" then return nil end
    return v
end

-- The frame's box in UIParent units, from UIParent's bottom left: l, b, w, h.
local function Box(frame)
    local l, b, w, h = frame:GetRect()
    l, b, w, h = Num(l), Num(b), Num(w), Num(h)
    if not (l and b and w and h) or w < 2 or h < 2 then return nil end
    local k = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    -- Wider than the screen: the raid container's 3000-wide layout pass, not a real box.
    local screen = Num(UIParent:GetWidth())
    if screen and w * k > screen then return nil end
    return { l * k, b * k, w * k, h * k }
end

local function Spot(which)
    local spots = db.spots[LayoutKey()]
    local s = spots and spots[which]
    if type(s) == "table" and Num(s[1]) and Num(s[2]) and Num(s[3]) and Num(s[4]) then return s end
    return nil
end

local function SaveSpot(which, box)
    local key = LayoutKey()
    db.spots[key] = db.spots[key] or {}
    db.spots[key][which] = box
end

local function Wanted(t)
    if not db.enabled then return false end
    if t.which == "raid" then return db.centerRaid end
    return db.centerParty
end

-- Edit Mode's (or the game's) own anchor, as last seen.
local function RecordPoints(t)
    local f = t.frame
    local points = {}
    for i = 1, f:GetNumPoints() do
        local point, rel, relPoint, x, y = f:GetPoint(i)
        if rel == t.anchor then return end          -- ours, not theirs
        points[#points + 1] = { point, rel, relPoint, x, y }
    end
    if #points > 0 then t.points = points end
end

local function RestorePoints(t)
    if not t.points then return end
    local f = t.frame
    FrameMethods.ClearAllPoints(f)
    for _, p in ipairs(t.points) do
        FrameMethods.SetPoint(f, p[1], p[2], p[3], p[4], p[5])
    end
end

local function TargetScale(t)
    local base = t.baseScale or 1
    if not db.enabled then return base end
    return base * (db[SizeKey(t.which)] or 100) / 100
end

local function ApplyScale(t)
    local want = TargetScale(t)
    local now = Num(t.frame:GetScale()) or 1
    if math.abs(now - want) > 0.0005 then
        FrameMethods.SetScale(t.frame, want)
    end
end

local function Apply(t)
    local f = t.frame
    if EditModeActive() then
        -- Edit Mode's own anchor while it is open; the box it shows is the spot to remember.
        if t.ours then
            RestorePoints(t)
            t.ours = false
        end
        ApplyScale(t)
        return
    end

    if t.dirty or not t.points then
        if not t.ours or t.dirty then RecordPoints(t) end
        t.dirty = false
    end

    ApplyScale(t)

    if not Wanted(t) then
        if t.ours then
            RestorePoints(t)
            t.ours = false
        end
        return
    end

    local spot = Spot(t.which)
    if not spot and not t.ours then
        spot = Box(f)
        if spot then SaveSpot(t.which, spot) end
    end
    if not spot then return end

    local l, b, w, h = spot[1], spot[2], spot[3], spot[4]
    local y = (db.grow == "down" and b + h) or (db.grow == "up" and b) or (b + h / 2)
    t.anchor:ClearAllPoints()
    t.anchor:SetPoint("CENTER", UIParent, "BOTTOMLEFT", l + w / 2, y)

    local point = GROW_POINT[db.grow]
    FrameMethods.ClearAllPoints(f)
    FrameMethods.SetPoint(f, point, t.anchor, "CENTER", 0, 0)
    t.ours = true
end

local function Process()
    ns.pending = false
    if not db then return end
    if InCombatLockdown() then
        inCombatWait = true
        return
    end
    inCombatWait = false
    for _, t in pairs(targets) do
        local ok, err = pcall(Apply, t)
        if not ok then
            t.errors = (t.errors or 0) + 1
            if t.errors <= 3 then Print("could not place the " .. t.which .. " frames: " .. tostring(err)) end
        end
    end
end

local function Queue()
    if ns.pending then return end
    ns.pending = true
    C_Timer.After(0, Process)
end
ns.Queue = Queue
ns.Process = Process

-- While Edit Mode is open, keep the middle of the box the player sees (it shows the
-- preview group size there) as the spot to use afterwards.
local function CaptureEditSpots()
    if not db or not EditModeActive() then return end
    for which, t in pairs(targets) do
        if not t.ours and t.frame:IsShown() then
            local box = Box(t.frame)
            if box then SaveSpot(which, box) end
        end
    end
end
ns.CaptureEditSpots = CaptureEditSpots

local function Track(which, frame)
    if targets[which] or not frame then return end
    local t = {
        which = which,
        frame = frame,
        baseScale = Num(frame:GetScale()) or 1,
        anchor = CreateFrame("Frame", "RaidFrameCenter_" .. which .. "Spot", UIParent),
    }
    t.anchor:SetSize(1, 1)
    targets[which] = t

    -- Someone (Edit Mode, the frame manager) placed the frame: note it, take it back later.
    hooksecurefunc(frame, "SetPoint", function(_, _, rel)
        if rel == t.anchor then return end
        t.dirty = true
        t.ours = false
        if EditModeActive() then C_Timer.After(0, CaptureEditSpots) end
        Queue()
    end)
    -- Edit Mode's own size for the frame (party "Frame Size"): ours multiplies it.
    hooksecurefunc(frame, "SetScale", function(_, scale)
        if Num(scale) then t.baseScale = scale end
        Queue()
    end)

    -- The raid container is laid out 3000 wide and shrunk to fit one frame later. Anchored by
    -- its middle that would show one frame far to the left; shrink it now when we may.
    if which == "raid" and frame.LayoutFrames and frame.GetBounds then
        hooksecurefunc(frame, "LayoutFrames", function(self)
            if not (db and db.enabled and t.ours) or InCombatLockdown() then return end
            local ok, left, right, top, bottom = pcall(self.GetBounds, self)
            left, right, top, bottom = Num(left), Num(right), Num(top), Num(bottom)
            -- GetBounds reads the unit frames' rects, which share the container's scale.
            if ok and left and right and top and bottom and right > left and bottom > top then
                FrameMethods.SetSize(self, right - left, bottom - top)
            end
        end)
    end
    -- The container's real size arrives a frame after its layout: a box can be taken then.
    if which == "raid" and frame.RefreshSize then
        hooksecurefunc(frame, "RefreshSize", function()
            if not t.ours then Queue() end
        end)
    end
    Queue()
end

local function FindFrames()
    if CompactRaidFrameContainer then Track("raid", CompactRaidFrameContainer) end
    if PartyFrame then Track("party", PartyFrame) end
end

---------------------------------------------------------------------------
-- Changes from the options
---------------------------------------------------------------------------
function ns.Set(key, value)
    if not db then return end
    if key == "grow" then
        if not CHOICES.grow[value] then return end
    elseif key:sub(1, 4) == "size" then
        value = math.max(SIZE_MIN, math.min(SIZE_MAX, math.floor((tonumber(value) or 100) + 0.5)))
    end
    db[key] = value
    if InCombatLockdown() then Print("in combat: this takes effect when the fight ends.") end
    Queue()
end

function ns.ForgetSpots()
    if not db then return end
    db.spots[LayoutKey()] = nil
    for _, t in pairs(targets) do
        if t.ours and not InCombatLockdown() then
            RestorePoints(t)
            t.ours = false
        end
    end
    Queue()
    Print("the middle is taken again from where Edit Mode puts the frames now.")
end

function ns.Reset()
    if not db then return end
    for k, v in pairs(DEFAULTS) do db[k] = v end
    db.spots = {}
    for _, t in pairs(targets) do
        if t.ours and not InCombatLockdown() then
            RestorePoints(t)
            t.ours = false
        end
    end
    if ns.Kit and ns.Kit.RefreshMinimap then ns.Kit.RefreshMinimap() end
    Queue()
end

function ns.StatusLines()
    local lines = {}
    if not db then return lines end
    if not db.enabled then
        lines[1] = "Switched off: the frames are where Edit Mode puts them, at Edit Mode's size."
        return lines
    end
    local inRaid = IsInRaid and IsInRaid()
    local n = GetNumGroupMembers and GetNumGroupMembers() or 0
    local key = SizeKey(inRaid and "raid" or "party")
    lines[#lines + 1] = string.format("Group: %s (%d), size %d%%.", SIZE_NAMES[key], n, db[key])
    for _, which in ipairs({ "raid", "party" }) do
        local t = targets[which]
        local name = which == "raid" and "Raid frames" or "Party frames"
        if not t then
            lines[#lines + 1] = name .. ": not loaded yet."
        elseif not Wanted(t) then
            lines[#lines + 1] = name .. ": not centered (option off)."
        elseif t.ours then
            lines[#lines + 1] = name .. ": centered."
        elseif EditModeActive() then
            lines[#lines + 1] = name .. ": Edit Mode is open; centered again when it closes."
        else
            lines[#lines + 1] = name .. ": waiting" .. (inCombatWait and " for the fight to end." or ".")
        end
    end
    return lines
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function Slash(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "" or msg == "config" or msg == "options" then
        if ns.Kit and ns.Kit.Toggle then ns.Kit.Toggle() end
    elseif msg == "on" or msg == "off" then
        ns.Set("enabled", msg == "on")
        if ns.Kit and ns.Kit.Sync then ns.Kit.Sync() end
        Print(msg == "on" and "on." or "off.")
    elseif msg == "status" then
        for _, line in ipairs(ns.StatusLines()) do Print(line) end
    elseif msg == "forget" then
        ns.ForgetSpots()
    else
        Print("/rfc (options), /rfc status, /rfc on, /rfc off, /rfc forget (take the middle from Edit Mode again)")
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            LoadDB()
            local mt = getmetatable(CreateFrame("Frame"))
            FrameMethods = mt and type(mt.__index) == "table" and mt.__index
            if not FrameMethods then
                -- No method table to borrow: Edit Mode keeps the originals as <Name>Base.
                FrameMethods = setmetatable({}, { __index = function(_, k)
                    return function(f, ...) return (f[k .. "Base"] or f[k])(f, ...) end
                end })
            end
            ns.FrameMethods = FrameMethods
        elseif db and (arg1 == "Blizzard_CompactRaidFrames" or arg1 == "Blizzard_UnitFrame") then
            FindFrames()
        end
    elseif event == "PLAYER_LOGIN" then
        FindFrames()
        local em = EditModeManagerFrame
        if em and em.EnterEditMode and em.ExitEditMode then
            hooksecurefunc(em, "EnterEditMode", function()
                Queue()
                if editTicker then editTicker:Cancel() end
                editTicker = C_Timer.NewTicker(0.25, CaptureEditSpots)
            end)
            hooksecurefunc(em, "ExitEditMode", function()
                if editTicker then editTicker:Cancel() editTicker = nil end
                Queue()
            end)
        end
        SLASH_RAIDFRAMECENTER1 = "/rfc"
        SLASH_RAIDFRAMECENTER2 = "/raidframecenter"
        SlashCmdList["RAIDFRAMECENTER"] = Slash
        if ns.Options and ns.Options.Init then ns.Options.Init() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if inCombatWait then Queue() end
    else
        FindFrames()
        Queue()
    end
end)
