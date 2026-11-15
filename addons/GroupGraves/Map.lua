-- Group Graves: the markers on the world map.
--
-- The markers are frames of our own laid over the map's canvas. Nothing is written into the
-- map: no data provider, no pin from the map's pools, no script on a map frame. On this
-- client the map's own code runs secure (gamepad interface), and addon values inside its pin
-- lists taint it. The map is only read: GetMapID, GetCanvas, GetCanvasScale,
-- GetGlobalPinScale, IsVisible and the pin level for corpses.
--
-- A marker takes the mouse for its tooltip only; presses go on to the map, so it can still
-- be dragged from on top of a marker. A left-click (press and release on the same marker) is
-- seen through the game-wide mouse events and puts a waypoint on the corpse.
local _, ns = ...
local Map = {}
ns.Map = Map

-- A marker is a copy of the game's own corpse pin (CorpsePinTemplate and CorpsePinMixin in
-- Blizzard_SharedMapDataProviders/DeathMapDataProvider): a 24 x 24 frame with the POIIcons
-- tombstone filling it on the ARTWORK layer, scaled by 0.8 (its SetScalingLimits(1, 0.8, 0.8))
-- times the map's pin scale over the canvas scale, no highlight, nothing drawn over it.
-- Whose corpse it is shows in the tooltip, and under the marker if names are switched on.
local TOMB   = "Interface\\Minimap\\POIIcons"
local TOMB_COORDS = { 0.56640625, 0.6328125, 0.001953125, 0.03515625 }
local BASE = 24                                         -- CorpsePinTemplate's size
local CORPSE_SCALE = 0.8                                -- CorpsePinMixin's scaling limits

-- The game's text colours, with their values as a fallback.
local function FontColor(name, r, g, b)
    local c = _G[name]
    if type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
    return { r, g, b }
end
local WHITE_TEXT = FontColor("HIGHLIGHT_FONT_COLOR", 1, 1, 1)
local GRAY_TEXT  = FontColor("GRAY_FONT_COLOR", 0.5, 0.5, 0.5)
local UNKNOWN_COLOR = FontColor("NORMAL_FONT_COLOR", 1, 0.82, 0)

local host, hostProblem
local active, free = {}, {}
local dirty = true
local drawn = {}                   -- what the last layout was made for
local hovered, pressed, pressedButton
local waypoint                     -- { key, map, x, y } of the waypoint we set

local function Known(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function ClassColor(class)
    local c = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
                      or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c then return c.r, c.g, c.b end
    return UNKNOWN_COLOR[1], UNKNOWN_COLOR[2], UNKNOWN_COLOR[3]
end

local function WorldMap()
    local map = WorldMapFrame
    if type(map) == "table" and map.GetCanvas and map.GetMapID then return map end
end

---------------------------------------------------------------------------
-- Tooltip
---------------------------------------------------------------------------
local SOURCE_LINE = {
    self = "Position sent by their own addon.",
    seen = "Position noted by your addon when they died.",
    test = "A test marker (/graves test removes it).",
}

local function AddGrave(tip, g, first)
    local r, gr, b = ClassColor(g.class)
    if first then
        tip:SetText(g.name .. "'s corpse", r, gr, b)
    else
        tip:AddLine(" ")
        tip:AddLine(g.name .. "'s corpse", r, gr, b)
    end
    local w, gy = WHITE_TEXT, GRAY_TEXT
    tip:AddLine("Died " .. ns.Ago(g.at) .. " in " .. ns.Where(g) .. ".", w[1], w[2], w[3])
    if g.inst then
        tip:AddLine("Died inside " .. g.inst .. ": the game puts the corpse at the way in.", w[1], w[2], w[3], true)
    end
    if not g.released then
        tip:AddLine("Has not released yet.", w[1], w[2], w[3])
    end
    local source = SOURCE_LINE[g.source]
    if g.source == "relay" then source = "Position passed on by " .. tostring(g.via or "someone") .. "." end
    if source then tip:AddLine(source, gy[1], gy[2], gy[3], true) end
end

-- Like the game's corpse pin: the tooltip opens away from the middle of the map.
local function Anchor(pin)
    local ok, x, parentX = pcall(function()
        local px = pin:GetCenter()
        local hx = host and host:GetCenter()
        return px, hx
    end)
    x, parentX = Known(x), Known(parentX)
    if ok and type(x) == "number" and type(parentX) == "number" and x > parentX then return "ANCHOR_LEFT" end
    return "ANCHOR_RIGHT"
end

-- The corpse pin's scale, times the player's marker size (the default size is the game's).
local function Size()
    local size = ns.db and ns.db.size or ns.SIZE_DEFAULT or 22
    return CORPSE_SCALE * size / (ns.SIZE_DEFAULT or 22)
end

-- Every marker under the cursor: a wipe puts several on one spot.
local function Near(a, b)
    local reach = BASE * Size() * 0.5
    local dx, dy = a.sx - b.sx, a.sy - b.sy
    return dx * dx + dy * dy <= reach * reach
end

local function PinEnter(pin)
    hovered = pin
    local tip = GameTooltip
    if not (tip and pin.grave) then return end
    tip:SetOwner(pin, Anchor(pin))
    AddGrave(tip, pin.grave, true)
    local extra = 0
    for _, other in ipairs(active) do
        if other ~= pin and other.grave and Near(other, pin) then
            if extra < 7 then AddGrave(tip, other.grave, false) end
            extra = extra + 1
        end
    end
    local gy = GRAY_TEXT
    if extra > 7 then tip:AddLine("... and " .. (extra - 7) .. " more here.", gy[1], gy[2], gy[3]) end
    if C_Map and C_Map.SetUserWaypoint then
        tip:AddLine(" ")
        local mine = waypoint and waypoint.key == pin.grave.key
        tip:AddLine(mine and "Click: remove the waypoint" or "Click: waypoint to this corpse", gy[1], gy[2], gy[3])
    end
    tip:Show()
end

local function PinLeave(pin)
    if hovered == pin then hovered = nil end
    if GameTooltip then GameTooltip:Hide() end
end

---------------------------------------------------------------------------
-- Markers
---------------------------------------------------------------------------
local function Tombstone(pin, layer)
    local tex = pin:CreateTexture(nil, layer)
    tex:SetTexture(TOMB)
    tex:SetTexCoord(TOMB_COORDS[1], TOMB_COORDS[2], TOMB_COORDS[3], TOMB_COORDS[4])
    tex:SetAllPoints(pin)
    return tex
end

-- Made with no parent and then moved under the map: the gamepad interface follows frames
-- that are created inside an open window.
local function FrameUnder(parent)
    local frame = CreateFrame("Frame")
    frame:SetParent(parent)
    return frame
end

local function CreatePin()
    local pin = FrameUnder(host)
    pin:SetSize(BASE, BASE)

    pin.tomb = Tombstone(pin, "ARTWORK")

    -- Names (off unless switched on): the game's outlined small font, under the marker.
    local font = _G.GameFontNormalSmallOutline and "GameFontNormalSmallOutline" or "GameFontHighlightSmall"
    pin.label = pin:CreateFontString(nil, "OVERLAY", font)
    pin.label:SetPoint("TOP", pin, "BOTTOM", 0, -2)

    pin:EnableMouse(true)
    if pin.SetMouseClickEnabled then pin:SetMouseClickEnabled(false) end
    pin:SetScript("OnEnter", PinEnter)
    pin:SetScript("OnLeave", PinLeave)
    pin:Hide()
    return pin
end

local function ReleaseAll()
    for i = #active, 1, -1 do
        local pin = active[i]
        active[i] = nil
        if hovered == pin then
            hovered = nil
            if GameTooltip then GameTooltip:Hide() end
        end
        if pressed == pin then pressed = nil end
        pin.grave = nil
        pin:Hide()
        pin:ClearAllPoints()
        free[#free + 1] = pin
    end
end

local function PinLevel(map, canvas)
    local level
    pcall(function()
        local levels = map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
        level = levels and levels:GetValidFrameLevel("PIN_FRAME_LEVEL_CORPSE")
    end)
    level = Known(level)
    if type(level) == "number" then return level end
    return (canvas:GetFrameLevel() or 0) + 1
end

local function Layout(map, canvas, mapID, width, height, canvasScale, pinScale)
    ReleaseAll()
    if not (ns.db and mapID and width > 0 and height > 0) then return end
    local scale = Size() * pinScale / canvasScale     -- the same size on screen at any zoom
    local level
    for _, g in pairs(ns.graves) do
        if ns.Visible(g) then
            local x, y = ns.OnMap(g, mapID)
            if x then
                level = level or PinLevel(map, canvas)
                local pin = table.remove(free) or CreatePin()
                active[#active + 1] = pin
                pin.grave = g
                pin.sx, pin.sy = width * x * canvasScale, height * y * canvasScale
                pin:SetScale(scale)
                pin:ClearAllPoints()
                pin:SetPoint("CENTER", canvas, "TOPLEFT", width * x / scale, -height * y / scale)
                pin:SetFrameLevel(level)
                local r, gr, b = ClassColor(g.class)
                pin:SetAlpha(g.released and 1 or 0.7)       -- still lying there, not released
                if ns.db.names then
                    pin.label:SetText(g.name)
                    pin.label:SetTextColor(r, gr, b)
                    pin.label:Show()
                else
                    pin.label:Hide()
                end
                pin:Show()
            end
        end
    end
    -- A marker redrawn under a resting mouse keeps its tooltip.
    for _, pin in ipairs(active) do
        if pin.IsMouseOver and pin:IsMouseOver() then
            PinEnter(pin)
            break
        end
    end
end

-- Runs only while the map is open (the host frame is a child of the canvas).
local function OnUpdate()
    local map = WorldMap()
    if not (map and map:IsVisible()) then return end
    local canvas = map:GetCanvas()
    local mapID = Known(map:GetMapID())
    local width, height = canvas:GetWidth() or 0, canvas:GetHeight() or 0
    local canvasScale = map.GetCanvasScale and map:GetCanvasScale() or 1
    if type(canvasScale) ~= "number" or canvasScale <= 0 then canvasScale = 1 end
    local pinScale = map.GetGlobalPinScale and map:GetGlobalPinScale() or 1
    if type(pinScale) ~= "number" or pinScale <= 0 then pinScale = 1 end
    if not dirty and drawn.mapID == mapID and drawn.width == width and drawn.height == height
        and drawn.canvasScale == canvasScale and drawn.pinScale == pinScale then
        return
    end
    dirty = false
    drawn.mapID, drawn.width, drawn.height = mapID, width, height
    drawn.canvasScale, drawn.pinScale = canvasScale, pinScale
    local ok, err = pcall(Layout, map, canvas, mapID, width, height, canvasScale, pinScale)
    if not ok and hostProblem ~= err then
        hostProblem = err
        ns.Print("map marker error: " .. tostring(err))
    end
end

function Map.Init()
    if host then return true end
    local map = WorldMap()
    if not map then
        hostProblem = "this client has no world map frame the addon knows"
        return false
    end
    local ok, err = pcall(function()
        local canvas = map:GetCanvas()
        local frame = FrameUnder(canvas)
        frame:SetAllPoints(canvas)
        frame:EnableMouse(false)
        frame:SetScript("OnUpdate", OnUpdate)
        host = frame
    end)
    if not ok then
        hostProblem = tostring(err)
        return false
    end
    hostProblem = nil
    dirty = true
    return true
end

---------------------------------------------------------------------------
-- Waypoint on a corpse
---------------------------------------------------------------------------
local function OurWaypointStands()
    if not (waypoint and C_Map and C_Map.GetUserWaypoint) then return false end
    local ok, point = pcall(C_Map.GetUserWaypoint)
    if not ok or type(point) ~= "table" or point.uiMapID ~= waypoint.map then return false end
    local pos = point.position
    local x, y
    if type(pos) == "table" then
        if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    end
    return type(x) == "number" and type(y) == "number"
        and math.abs(x - waypoint.x) < 0.001 and math.abs(y - waypoint.y) < 0.001
end

local function ClearWaypoint()
    local ours = OurWaypointStands()          -- never remove a waypoint the player set since
    waypoint = nil
    if ours and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
    return ours
end

function Map.Waypoint(g)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        ns.Print("this client has no map waypoints.")
        return false
    end
    if waypoint and waypoint.key == g.key then
        ClearWaypoint()
        ns.Print("waypoint removed.")
        return false
    end
    if C_Map.CanSetUserWaypointOnMap then
        local ok, can = pcall(C_Map.CanSetUserWaypointOnMap, g.map)
        if ok and Known(can) == false then
            ns.Print("the game allows no waypoint on that map.")
            return false
        end
    end
    local ok, err = pcall(function()
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(g.map, g.x, g.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end)
    if not ok then
        ns.Print("the waypoint could not be set: " .. tostring(err))
        return false
    end
    waypoint = { key = g.key, map = g.map, x = g.x, y = g.y }
    ns.Print("waypoint set on " .. g.name .. "'s corpse. Click the marker again to remove it.")
    return true
end

-- Markers changed (or a setting did): redraw when the map next shows a frame.
function Map.Refresh()
    dirty = true
    if not host then Map.Init() end
    -- The corpse our waypoint pointed at is gone (they are alive again): so is the waypoint.
    if waypoint then
        local g = ns.graves[waypoint.key]
        if not g or g.map ~= waypoint.map or g.x ~= waypoint.x or g.y ~= waypoint.y then ClearWaypoint() end
    end
end

function Map.Describe()
    if not host then return "no markers (" .. tostring(hostProblem or "not set up yet") .. ")" end
    return #active .. " drawn" .. (hostProblem and (", last error: " .. tostring(hostProblem)) or "")
end

-- For the tests.
Map.pins = active
function Map.Draw() OnUpdate() end

---------------------------------------------------------------------------
-- Clicks, through the game-wide mouse events
---------------------------------------------------------------------------
local clicks = CreateFrame("Frame")
pcall(clicks.RegisterEvent, clicks, "GLOBAL_MOUSE_DOWN")
pcall(clicks.RegisterEvent, clicks, "GLOBAL_MOUSE_UP")
clicks:SetScript("OnEvent", function(_, event, button)
    if event == "GLOBAL_MOUSE_DOWN" then
        pressed, pressedButton = nil, button
        if hovered and hovered:IsVisible() and hovered:IsMouseOver() then pressed = hovered end
        return
    end
    local pin = pressed
    pressed = nil
    if pin and pin == hovered and button == pressedButton and button == "LeftButton"
        and pin.grave and pin:IsVisible() and pin:IsMouseOver() then
        local ok, err = pcall(Map.Waypoint, pin.grave)
        if not ok then ns.Print("waypoint error: " .. tostring(err)) end
        if hovered == pin then PinEnter(pin) end      -- the click hint changed
    end
end)
