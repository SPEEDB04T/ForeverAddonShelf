-- Totem Council: Tremor Totem pulses.
-- A Tremor Totem breaks fear, charm and sleep once every 4 seconds, counted
-- from the moment it was dropped (spell 8145, a 4000 ms periodic trigger of
-- 8146, party only). Two shamans whose totems pulse at the same moment leave
-- a fear running for up to 4 seconds; half a period apart it is 2. This file
-- works out when each Tremor in the party pulses and shows it on a small cast
-- bar under the totem bar, with a green stretch and an arrow for the moment
-- to drop (or re-drop) yours so the pulses end up evenly spread.
--
-- Whose pulse is known how:
--   mine          from my own cast
--   addon users   from their "X;age_ms;latency_ms" message (1.4.0 and newer)
--   anyone else   from their cast, when the game reports it (Group.ObserveCast)
-- Every drop time is "server time plus my own delay", so they compare fairly.
local ADDON, ns = ...
local issecret = ns.issecret

local T = {}
ns.Tremor = T

T.PERIOD = 4            -- seconds between pulses
T.TOLERANCE = 0.4       -- pulses this close to the best spread count as even
T.KEY = "tr"
local P = T.PERIOD
local SLOT = 2          -- earth
local W = 4 * ns.TOTEM_BUTTON + 3 * ns.TOTEM_GAP    -- as wide as the totem bar
local H = 11            -- the player cast bar's height (PlayerCastingBarFrame)
T.WIDTH = W

----------------------------------------------------------------------
-- Timing
----------------------------------------------------------------------
-- My round trip to the server, in seconds (0 when the game won't say).
function T.Latency()
    if not GetNetStats then return 0 end
    local ok, _, _, home, world = pcall(GetNetStats)
    if not ok then return 0 end
    local v = world
    if issecret(v) or type(v) ~= "number" or not (v > 0) then v = home end
    if issecret(v) or type(v) ~= "number" or not (v > 0) then return 0 end
    return math.min(v, 1000) / 1000
end

-- When my Tremor Totem was dropped, or nil when none is down. The cast is
-- the steadier moment; the totem slot's own start time is used without it.
function T.MyDrop()
    local a = ns.active[SLOT]
    if not a or a.key ~= T.KEY or type(a.start) ~= "number" then return nil end
    if type(a.castAt) == "number" and math.abs(a.castAt - a.start) < 1 then return a.castAt end
    return a.start
end

-- Every Tremor Totem in my party whose drop time is known, mine first, then
-- by name; and the names of shamans whose Tremor is down with no known timing.
function T.Collect(now)
    local list, unknown = {}, {}
    local G = ns.Group
    local me = G.members[ns.playerName]
    if not me then return list, unknown end
    local drop = T.MyDrop()
    for name, m in pairs(G.members) do
        if not m.isPlayer and m.subgroup == me.subgroup then
            local s = m.seen[SLOT]
            if s and s.key == T.KEY and s.expires > now and G.Near(m) then
                if type(s.drop) == "number" then
                    list[#list + 1] = { name = name, drop = s.drop, cue = m.cue and true or false }
                else
                    unknown[#unknown + 1] = name
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    table.sort(unknown)
    if drop then table.insert(list, 1, { name = ns.playerName, mine = true, drop = drop, cue = true }) end
    return list, unknown
end

-- The widest stretch without a pulse, and the pulse it starts at.
local function Widest(phases)
    local p = {}
    for i, v in ipairs(phases) do p[i] = v % P end
    table.sort(p)
    local n = #p
    if n == 0 then return P, 0 end
    local widest, from = P - (p[n] - p[1]), p[n]
    for i = 1, n - 1 do
        local gap = p[i + 1] - p[i]
        if gap > widest then widest, from = gap, p[i] end
    end
    return widest, from
end

function T.WorstGap(phases)
    return (Widest(phases))
end

-- Where one more pulse does the most good: the middle of the widest stretch.
function T.Target(phases)
    if #phases == 0 then return nil end
    local widest, from = Widest(phases)
    return (from + widest / 2) % P
end

-- The two pulses closest together.
local function ClosestPair(list)
    local sorted = {}
    for i, e in ipairs(list) do sorted[i] = e end
    table.sort(sorted, function(a, b)
        if a.phase ~= b.phase then return a.phase < b.phase end
        return a.name < b.name
    end)
    local n = #sorted
    local best, a, b
    for i = 1, n do
        local j = i % n + 1
        local gap = (sorted[j].phase - sorted[i].phase) % P
        if not best or gap < best then best, a, b = gap, sorted[i], sorted[j] end
    end
    return a, b
end

-- Of two shamans whose pulses are bunched up, the one who dropped later
-- moves; the same rule on both sides, so they don't both re-drop at once.
-- Drops within 0.3 s of each other go by name instead.
local function Later(a, b)
    local d = a.drop - b.drop
    if math.abs(d) < 0.3 then return a.name > b.name end
    return d > 0
end

-- Everything the bar shows:
--   list, unknown   from T.Collect, each entry with its phase (drop mod 4)
--   count           Tremor Totems with known timing
--   mine            my entry, or nil
--   origin          the totem the bar counts to: mine, else the oldest drop
--   worst           the longest stretch without a pulse right now
--   target, best    the best moment (as a phase) for my drop, and the longest
--                   stretch there would be then
--   even            the pulses are as spread out as they can be
--   move            dropping mine on the mark is the thing to do
--   mover           who should re-drop instead, when that is known
function T.Advice(now)
    local list, unknown = T.Collect(now)
    local st = { list = list, unknown = unknown, count = #list, worst = P, even = true }
    if #list == 0 then return st end
    local others, all = {}, {}
    for _, e in ipairs(list) do
        e.phase = e.drop % P
        all[#all + 1] = e.phase
        if e.mine then
            st.mine = e
        else
            others[#others + 1] = e.phase
            if not st.origin or e.drop < st.origin.drop then st.origin = e end
        end
    end
    if st.mine then st.origin = st.mine end
    st.worst = T.WorstGap(all)
    if #others == 0 then return st end

    st.target = T.Target(others)
    local with = { st.target }
    for i, v in ipairs(others) do with[i + 1] = v end
    st.best = T.WorstGap(with)

    if not st.mine then
        st.even, st.move = false, true
        return st
    end
    st.even = (st.worst - st.best) <= T.TOLERANCE
    if st.even then return st end
    local a, b = ClosestPair(list)
    local other = (a == st.mine and b) or (b == st.mine and a) or nil
    if other then
        -- someone who can't see this bar (no addon, or an older one) can't
        -- be expected to move
        st.move = (not other.cue) or Later(st.mine, other)
        if not st.move then st.mover = other.name end
    else
        local first, second = a, b
        if Later(a, b) then first, second = b, a end    -- second dropped later
        st.mover = (second.cue and second.name) or (first.cue and first.name) or nil
    end
    return st
end

----------------------------------------------------------------------
-- Telling the other Totem Council users (sent by Group's Flush)
----------------------------------------------------------------------
local sentDrop      -- my drop, as the others were last told

-- "X;<milliseconds since my drop>;<my round trip in ms>", or nil when the
-- others already know. The age is worked out as the message leaves.
function T.Outgoing()
    local drop = T.MyDrop()
    if not drop then
        sentDrop = nil
        return nil
    end
    if sentDrop and math.abs(sentDrop - drop) < 0.05 then return nil end
    local age = math.floor((GetTime() - drop) * 1000 + 0.5)
    if age < 0 then age = 0 end
    return ("X;%d;%d"):format(age, math.floor(T.Latency() * 1000 + 0.5)), drop
end

function T.Sent(drop)
    sentDrop = drop
end

-- someone joined, reloaded or asked: tell them again
function T.Resend()
    sentDrop = nil
end

-- A shaman's "X" message. The message took their delay up and mine down;
-- taking their round trip off leaves "server time plus my delay", the same
-- clock my own drops are on.
function T.OnMessage(m, ageText, latText)
    local age, lat = tonumber(ageText), tonumber(latText)
    if not age or age ~= age or age < 0 or age > 600000 then return end
    if not lat or lat ~= lat or lat < 0 then lat = 0 end
    if lat > 1000 then lat = 1000 end
    local now = GetTime()
    local drop = now - age / 1000 - lat / 1000
    local expires = drop + ns.Duration(T.KEY)
    m.cue = true
    if expires <= now then return end
    local s = m.seen[SLOT]
    if not (s and s.key == T.KEY) then
        s = { key = T.KEY, start = now, expires = expires }
        m.seen[SLOT] = s
    elseif s.dropSrc == "cast" and type(s.drop) == "number" and math.abs(s.drop - drop) < 1 then
        -- the same drop, already seen as their cast: that needs no arithmetic
        ns.Group.Touch()
        return
    end
    s.drop, s.dropSrc = drop, "msg"
    if expires - s.expires > 3 then s.expires = expires end    -- a re-drop, heard of before its "T" message
    ns.Debug(("tremor: %s dropped %.2f s ago (their delay %d ms)"):format(m.name, now - drop, lat))
    ns.Group.Touch()
end

----------------------------------------------------------------------
-- The bar: the game's own player cast bar (CastingBarFrameBaseTemplate,
-- Blizzard_UIPanels_Game/Mainline/CastingBarFrame.xml), 11 high, with its
-- fill, background, frame, spark and the text box under it.
--
-- Other shamans' pulses are the peg an empowered cast is held on
-- (ui-castingbar-empower-cursor, 12 x 17 in the same file), drawn 14 x 20
-- and tinted the shaman class colour. The stage pip used before
-- (ui-castingbar-empower-pip) is a dark line 2 pixels wide: not seen.
--
-- The moment to drop is two things (1.4.1; the experience bar's rested tick
-- used before is a thin grey peg):
--   the stretch of bar where a drop keeps the pulses even, drawn like a
--   stage of an empowered cast (CastingBarFrameStageTierTemplate, a slice of
--   the bar in another fill), in the channel fill's green;
--   over its middle the waypoint arrow (SuperTrackedFrame.Arrow,
--   Blizzard_QuestNavigation/SuperTrackedFrame.xml, Navigation-Tracked-Arrow
--   22 x 18), turned to point down at the bar.
----------------------------------------------------------------------
local ARROW_W, ARROW_H = 22, 18     -- Navigation-Tracked-Arrow's own size
local ARROW_IN = 6                  -- how far its tip reaches into the bar
local PEG_W, PEG_H = 14, 20
T.ZONE = T.TOLERANCE / P * W        -- half the green stretch, in pixels

local function Atlas(tex, atlas, useSize)
    if tex.SetAtlas then tex:SetAtlas(atlas, useSize and true or false) end
end

local function FirstName(name)
    return tostring(name):match("^(%S+)") or tostring(name)
end

local function OnEnter(self)
    if ns.HUD.frame then ns.HUD.frame.hover = true end
    local st = T.state
    if not st then return end
    local C = ns.COLOR
    local now = GetTime()
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Tremor Totem pulses")
    for _, e in ipairs(st.list) do
        local left = P - ((now - e.drop) % P)
        GameTooltip:AddDoubleLine(e.mine and "Your totem" or e.name, ("next in %.1f s"):format(left), 1, 1, 1, 1, 1, 1)
    end
    if st.count > 1 then
        GameTooltip:AddLine(("Longest wait for a pulse: %.1f s"):format(st.worst), 1, 1, 1)
    end
    if st.move and st.best then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine((st.mine and "Re-drop" or "Drop") .. (" yours when the spark is in the green, best at the arrow: the longest wait is then %.1f s."):format(st.best),
            C.gold[1], C.gold[2], C.gold[3], true)
    elseif st.mover then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(st.mover .. " dropped later and is shown when to re-drop.", C.gold[1], C.gold[2], C.gold[3], true)
    end
    if #st.unknown > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(table.concat(st.unknown, ", ") .. ": Tremor is down, but when it was dropped is not known.",
            C.gray[1], C.gray[2], C.gray[3], true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("A full bar is a pulse of " .. ((st.origin and not st.origin.mine) and (st.origin.name .. "'s") or "your") .. " totem. Each blue peg is another shaman's.",
        C.gray[1], C.gray[2], C.gray[3], true)
    GameTooltip:Show()
end

local function OnLeave()
    if ns.HUD.frame then ns.HUD.frame.hover = false end
    GameTooltip:Hide()
end

-- frame levels above the bar: the green stretch, the pegs, then the spark
-- and the arrow, so the spark is never hidden while it crosses the green
local function Level(frame, bar, above)
    local level = bar.GetFrameLevel and bar:GetFrameLevel()
    if type(level) == "number" and frame.SetFrameLevel then frame:SetFrameLevel(level + above) end
end

local function NewPip(bar)
    local pip = CreateFrame("Frame", nil, bar)
    Level(pip, bar, 2)
    pip:SetSize(PEG_W, PEG_H)
    pip.BasePip = pip:CreateTexture(nil, "ARTWORK", nil, 2)
    Atlas(pip.BasePip, "ui-castingbar-empower-cursor")
    pip.BasePip:SetAllPoints()
    local c = type(RAID_CLASS_COLORS) == "table" and RAID_CLASS_COLORS.SHAMAN
    if type(c) == "table" and type(c.r) == "number" then
        pip.BasePip:SetVertexColor(c.r, c.g, c.b)
    else
        pip.BasePip:SetVertexColor(0, 0.44, 0.87)
    end
    pip:Hide()
    return pip
end

-- Navigation-Tracked-Arrow points up; turn it over so it points at the bar.
local function PointDown(tex)
    local ulx, uly, llx, lly, urx, ury, lrx, lry
    if tex.GetTexCoord then ulx, uly, llx, lly, urx, ury, lrx, lry = tex:GetTexCoord() end
    if type(lry) == "number" then
        tex:SetTexCoord(llx, lly, ulx, uly, lrx, lry, urx, ury)
    elseif tex.SetRotation then
        tex:SetRotation(math.pi)
    end
end

-- one slice of the green stretch, from l to r pixels along the bar
local function Slice(bar, tex, l, r)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", bar, "TOPLEFT", l, 0)
    tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", r, 0)
    tex:Show()
end

-- The mark at x pixels along the bar: the arrow there, the green stretch
-- T.ZONE either side of it, carried over to the other end where it runs
-- off the bar (the bar is a loop).
function T.PlaceMark(bar, x)
    local mark = bar.mark
    mark.x = x
    mark.arrow:ClearAllPoints()
    mark.arrow:SetPoint("BOTTOM", bar, "TOPLEFT", x, -ARROW_IN)
    local l, r = x - T.ZONE, x + T.ZONE
    mark.left, mark.right, mark.wrap = math.max(0, l), math.min(W, r), nil
    Slice(bar, mark.zone, mark.left, mark.right)
    if l < 0 then
        mark.wrap = { W + l, W }
    elseif r > W then
        mark.wrap = { 0, r - W }
    end
    if mark.wrap then
        Slice(bar, mark.zone2, mark.wrap[1], mark.wrap[2])
    else
        mark.zone2:Hide()
    end
end

function T.Create()
    local hud = ns.HUD.frame
    if T.bar or not hud then return end
    local bar = CreateFrame("StatusBar", "TotemCouncilTremorBar", hud)
    T.bar = bar
    bar:SetSize(W, H)
    -- under the totem bar, below the time-left text of its buttons and with
    -- room for the arrow that stands on the bar
    bar:SetPoint("TOPLEFT", hud, "BOTTOMLEFT", 0, -22)
    -- the fill by atlas name, as CastingBarMixin does; and on the texture
    -- itself, in case this client's status bar wants a file there
    bar:SetStatusBarTexture("ui-castingbar-filling-standard")
    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill.SetAtlas then fill:SetAtlas("ui-castingbar-filling-standard") end
    bar:SetMinMaxValues(0, P)
    bar:SetValue(0)

    bar.TextBorder = bar:CreateTexture(nil, "BACKGROUND", nil, 0)
    Atlas(bar.TextBorder, "ui-castingbar-textbox")
    bar.TextBorder:SetPoint("TOPLEFT", 0, 0)
    bar.TextBorder:SetPoint("BOTTOMRIGHT", 0, -12)

    bar.Background = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    Atlas(bar.Background, "ui-castingbar-background")
    bar.Background:SetPoint("TOPLEFT", -1, 1)
    bar.Background:SetPoint("BOTTOMRIGHT", 1, -1)

    bar.Border = bar:CreateTexture(nil, "ARTWORK", nil, 4)
    Atlas(bar.Border, "ui-castingbar-frame")
    bar.Border:SetPoint("TOPLEFT", -2, 2)
    bar.Border:SetPoint("BOTTOMRIGHT", 2, -2)

    -- the spark and the arrow sit on a frame of their own, above the green
    -- stretch and the pegs
    bar.top = CreateFrame("Frame", nil, bar)
    bar.top:SetAllPoints(bar)
    Level(bar.top, bar, 3)

    bar.spark = bar.top:CreateTexture(nil, "OVERLAY", nil, 2)
    Atlas(bar.spark, "ui-castingbar-pip")
    bar.spark:SetSize(8, 20)
    bar.spark:SetPoint("CENTER", bar, "LEFT", 0, 0)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("TOP", bar, "TOP", 0, -10)
    if bar.text.SetWidth then bar.text:SetWidth(W) end

    bar.pips = {}

    -- the mark: the green stretch (two slices, for when it runs round the
    -- end of the bar) and the arrow over its middle
    local mark = CreateFrame("Frame", nil, bar)
    bar.mark = mark
    mark:SetAllPoints(bar)
    Level(mark, bar, 1)
    mark.zone = mark:CreateTexture(nil, "ARTWORK", nil, 1)
    Atlas(mark.zone, "ui-castingbar-filling-channel")
    mark.zone2 = mark:CreateTexture(nil, "ARTWORK", nil, 1)
    Atlas(mark.zone2, "ui-castingbar-filling-channel")
    mark.zone2:Hide()
    mark.arrow = bar.top:CreateTexture(nil, "OVERLAY", nil, 4)
    Atlas(mark.arrow, "Navigation-Tracked-Arrow")
    mark.arrow:SetSize(ARROW_W, ARROW_H)
    PointDown(mark.arrow)
    mark.arrow:Hide()
    mark:Hide()

    bar:SetScript("OnEnter", OnEnter)
    bar:SetScript("OnLeave", OnLeave)
    bar:SetScript("OnUpdate", function() ns.Safe(T.Draw) end)
    bar:Hide()
    bar.shown = false
end

local function BarText(st)
    if not st.mine then return "Drop Tremor in the green" end
    if st.count == 1 then return "Tremor pulse" end
    if st.even then return ("Longest wait %.1f s"):format(st.worst) end
    if st.move then return "Re-drop in the green" end
    if st.mover then return FirstName(st.mover) .. " to re-drop" end
    return ("Longest wait %.1f s"):format(st.worst)
end

-- where along the bar a moment sits, in pixels from its left edge
local function Along(bar, moment)
    return ((moment - bar.origin) % P) / P * W
end

-- Ten times a second: who pulses when, and what to say about it.
function T.Update()
    local bar = T.bar
    if not bar then return end
    local now = GetTime()
    local st = T.Advice(now)
    T.state = st
    local show = ns.db.tremorBar ~= false and st.count > 0
    if bar.shown ~= show then
        bar:SetShown(show)
        bar.shown = show
    end
    if not show then return end

    local mouse = not ns.db.clickThrough
    if bar.mouse ~= mouse then
        bar:EnableMouse(mouse)
        bar.mouse = mouse
    end
    bar.origin = st.origin.drop

    local text = BarText(st)
    if bar.shownText ~= text then
        bar.text:SetText(text)
        bar.shownText = text
    end

    -- a peg for every pulse that is not the bar's own
    local n = 0
    for _, e in ipairs(st.list) do
        if e ~= st.origin then
            n = n + 1
            local pip = bar.pips[n]
            if not pip then
                pip = NewPip(bar)
                bar.pips[n] = pip
            end
            local x = math.floor(math.max(3, math.min(W - 3, Along(bar, e.drop))) + 0.5)
            if pip.x ~= x then
                pip:ClearAllPoints()
                pip:SetPoint("CENTER", bar, "LEFT", x, 0)
                pip.x = x
            end
            pip.owner = e.name
            pip:Show()
        end
    end
    for i = n + 1, #bar.pips do bar.pips[i]:Hide() end

    -- the mark: press when the spark is under the arrow. My totem lands one
    -- round trip after the key press, so the mark sits that much early.
    local markAt = st.move and st.target and ((st.target - T.Latency()) % P) or nil
    if markAt then
        local x = math.floor(Along(bar, markAt) + 0.5)
        if bar.mark.x ~= x then T.PlaceMark(bar, x) end
    end
    bar.mark:SetShown(markAt ~= nil)
    bar.mark.arrow:SetShown(markAt ~= nil)
    T.Draw()
end

-- Every frame while the bar is shown: the fill and the spark.
function T.Draw()
    local bar = T.bar
    if not bar or not bar.origin then return end
    local pos = (GetTime() - bar.origin) % P
    bar.value = pos
    bar:SetValue(pos)
    bar.spark:SetPoint("CENTER", bar, "LEFT", pos / P * W, 0)
end

-- /totems status
function T.PrintStatus()
    local now = GetTime()
    local st = T.Advice(now)
    if st.count == 0 and #st.unknown == 0 then return end
    local parts = {}
    for _, e in ipairs(st.list) do
        parts[#parts + 1] = ("%s in %.1f s"):format(e.mine and "yours" or e.name, P - ((now - e.drop) % P))
    end
    for _, name in ipairs(st.unknown) do parts[#parts + 1] = name .. " timing unknown" end
    ns.Print(("Tremor pulses: %s. Longest wait %.1f s%s."):format(table.concat(parts, ", "), st.worst,
        st.best and (", %.1f s at best"):format(st.best) or ""))
end
