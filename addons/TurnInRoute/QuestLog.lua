-- Turn-in Route: its place in the game's own quest log (the world map's side panel).
--
-- With ForeverCore installed the route is a side tab of the quest log, next to the
-- other Forever addons' tabs: ForeverCore owns that column and swaps the panels.
-- Without it the quest log gets a side button that opens the Turn-in Route window.
--
-- The panel lives under the world map, so it sets no OnShow or OnHide script (addon
-- scripts in the map's close path taint it); ForeverCore tells it when it is visible.
local _, ns = ...
local QL = {}
ns.QuestLog = QL

local KEY = "turninroute"
local NAME = "Turn-in Route"
local TOP_BAR = 29       -- the strip above the list, as tall as the quest log's search bar
local PAD = 12            -- the Map Legend's left padding (MapLegendFrameTemplate ScrollChild leftPadding)
local FALLBACK_WIDTH = 290

local visible = false
local panel, list, scrollContent, summary, empty

function QL.IsShown()
    return visible
end

function QL.Mode()
    return QL.mode
end

function QL.Status()
    if QL.mode == "tab" then return "tab in the quest log (ForeverCore)" end
    if QL.mode == "button" then return "side button on the quest log (no ForeverCore)" end
    if QL.error then return "not attached: " .. QL.error end
    return "not attached"
end

local function SetTabIcon(tab)
    local icon = tab and tab.Icon
    if type(icon) ~= "table" or not icon.SetTexture then return end
    icon:SetTexture(ns.ICON)
    if type(tab.SetFillToInterior) == "function" then
        tab:SetFillToInterior(true)        -- SidePanelTabButtonMixin:UpdateIconInterior
    else
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetSize(26, 26)
    end
end

----------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------
local function PanelWidth()
    local width = panel and ns.Num(panel:GetWidth())
    if width and width > 100 then return width end
    return FALLBACK_WIDTH
end

function QL.Update(plan)
    if not panel or not plan then return end
    local width = PanelWidth()
    scrollContent:SetWidth(width)
    summary:SetWidth(width - 2 * PAD)
    summary:SetText(plan.error or ns.Plan.Summary(plan))
    local textHeight = ns.Num(summary:GetStringHeight())
    if not textHeight or textHeight < 10 then textHeight = 40 end
    local top = PAD + textHeight + PAD
    local height = ns.UI.FillList(list, plan, top)
    empty:SetShown(ns.UI.IsEmpty(plan) and not plan.error)
    scrollContent:SetHeight(top + height + PAD)
end

local function Shown(shown)
    visible = shown and true or false
    if visible and ns.db then QL.Update(ns.Compute()) end
end

-- Built like the game's Map Legend panel (MapLegendFrameTemplate): the quest log's border
-- frame, a scroll frame filling it on the quest log's parchment, and the title above the border.
local function BuildBody()
    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -TOP_BAR)
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    local background = body:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(body)
    if ns.UI.HasAtlas("QuestLog-main-background") then
        background:SetAtlas("QuestLog-main-background")
    else
        background:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
        background:SetHorizTile(true)
        background:SetVertTile(true)
    end
    QL.background = background

    local okBorder, border = pcall(CreateFrame, "Frame", nil, body, "QuestLogBorderFrameTemplate")
    if not (okBorder and type(border) == "table") then border = body end

    local title = body:CreateFontString(nil, "ARTWORK", _G.Game15Font_Shadow and "Game15Font_Shadow" or "GameFontNormalLarge")
    title:SetPoint("BOTTOM", border, "TOP", -1, 3)
    title:SetText(NAME)
    QL.title = title

    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, body, "ScrollFrameTemplate")
    if ok and scroll then
        scroll:SetAllPoints(body)
        local bar = scroll.ScrollBar
        if type(bar) == "table" and bar.ClearAllPoints then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 2)
            bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, -4)
        end
    else
        scroll = CreateFrame("ScrollFrame", "TurnInRouteQuestLogScroll", body, "UIPanelScrollFrameTemplate")
        scroll:SetAllPoints(body)
    end

    scrollContent = CreateFrame("Frame", nil, scroll)
    scrollContent:SetSize(FALLBACK_WIDTH, 100)
    scroll:SetScrollChild(scrollContent)
    scroll:SetScript("OnSizeChanged", function(_, width)
        width = ns.Num(width)
        if width and width > 0 then scrollContent:SetWidth(width) end
    end)

    summary = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", PAD, -PAD)
    summary:SetWidth(FALLBACK_WIDTH - 2 * PAD)
    summary:SetJustifyH("LEFT")
    summary:SetJustifyV("TOP")

    empty = body:CreateFontString(nil, "ARTWORK", _G.Game16Font and "Game16Font" or "GameFontNormalLarge")
    empty:SetWidth(250)
    empty:SetPoint("CENTER", body, "CENTER", 0, 50)
    empty:SetText("No finished quests to hand in.")
    empty:Hide()

    list = ns.UI.NewList(scrollContent)
end

local function BuildPanel(map)
    panel = CreateFrame("Frame", "TurnInRouteQuestLogPanel", map)
    panel:SetPoint("TOPLEFT", map.ContentsAnchor, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", map.ContentsAnchor, "BOTTOMRIGHT", -22, 0)
    panel:SetFrameLevel((ns.Num(map:GetFrameLevel()) or 0) + 20)
    panel:EnableMouse(true)
    panel:Hide()
    BuildBody()
end

----------------------------------------------------------------------
-- Attaching to the quest log
----------------------------------------------------------------------
local function CoreTabs()
    local core = ForeverCore
    local tabs = type(core) == "table" and core.QuestLogTabs
    if type(tabs) == "table" and type(tabs.Register) == "function" and type(tabs.Select) == "function" then
        return tabs
    end
end

-- No ForeverCore: one side button on the quest log that opens the window, under any
-- other addon's button already there.
local function AttachButton(map)
    local tab = CreateFrame("Button", "TurnInRouteQuestLogTab", map, "LargeSideTabButtonTemplate")
    tab.tooltipText = NAME
    tab:SetCustomOnMouseUpHandler(function(_, mouseButton, upInside)
        if mouseButton == "LeftButton" and upInside then ns.UI.Toggle() end
    end)
    tab:SetChecked(false)

    local function shown(frame)
        if type(frame) == "table" and frame.IsShown and frame:IsShown() then return frame end
    end
    local above = shown(_G.AbandonAdvisorQuestLogTab) or shown(map.MapLegendTab) or shown(map.EventsTab)
        or shown(map.QuestsTab)
    if above then
        tab:SetPoint("TOP", above, "BOTTOM", 0, -3)
    else
        local y
        if type(QuestMapFrameOverrides) == "table" then
            local _, offsetY = ns.Call(QuestMapFrameOverrides.GetQuestsTabAnchorOffset)
            y = ns.Num(offsetY)
        end
        tab:SetPoint("TOPLEFT", map, "TOPRIGHT", 0, y or -28)
    end
    SetTabIcon(tab)
    QL.tab = tab
    QL.mode = "button"
end

local function AttachTab(map, tabs)
    BuildPanel(map)
    local tab = tabs.Register(KEY, {
        name = "TurnInRouteQuestLogTab",
        tooltip = NAME,
        panel = panel,
        order = 31,
        shown = Shown,
    })
    SetTabIcon(tab)
    QL.tab = tab
    QL.mode = "tab"
end

local attached = false
local function Attach()
    if attached then return end
    attached = true
    local ok, err = pcall(function()
        local map = QuestMapFrame
        if type(map) ~= "table" then error("this client has no QuestMapFrame", 0) end
        local tabs = CoreTabs()
        if tabs and type(map.ContentsAnchor) == "table" then
            AttachTab(map, tabs)
        else
            AttachButton(map)
        end
    end)
    if not ok then QL.error = tostring(err) end
end

function QL.Init()
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        local ok = pcall(EventUtil.ContinueOnAddOnLoaded, "Blizzard_WorldMap", Attach)
        if ok then return end
    end
    Attach()
end

----------------------------------------------------------------------
-- LookShots (a helper on SuccuDev's machine only): the frames this addon
-- draws. The options window and minimap button are the shared kit's.
----------------------------------------------------------------------
local function OwnedTooltip(flag)
    local tip = GameTooltip
    if type(tip) ~= "table" or not tip:IsShown() then return nil end
    local owner = tip.GetOwner and tip:GetOwner()
    if type(owner) == "table" and owner[flag] then return tip end
end

function QL.LookShotsFrames()
    return {
        { label = "window", frame = function() return _G.TurnInRouteFrame end },
        { label = "quest log tab page", frame = function() return QL.mode == "tab" and panel or nil end },
        { label = "quest log side button", frame = function() return QL.mode == "button" and QL.tab or nil end },
        { label = "row tooltip", frame = function() return OwnedTooltip("isTurnInRouteRow") end },
        { label = "leg tooltip", frame = function() return OwnedTooltip("isTurnInRouteHeader") end },
    }
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["TurnInRoute"] = { version = ns.VERSION, frames = QL.LookShotsFrames() }

-- /turnin log: the quest log, on the Turn-in Route tab.
function QL.Open()
    if QL.mode ~= "tab" then
        if QL.mode == "button" then
            ns.Print("The quest log tab needs the ForeverCore addon; opening the window instead.")
        else
            ns.Print("Not attached to the quest log on this client; opening the window instead.")
        end
        ns.UI.Show()
        return false
    end
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("The quest log can't be opened from here in combat.")
        return false
    end
    local tabs = CoreTabs()
    local open = type(ForeverCore) == "table" and ForeverCore.OpenMap
    if not tabs or type(open) ~= "function" then
        ns.UI.Show()
        return false
    end
    local ok, opened = pcall(open)
    if not (ok and opened) then
        ns.Print("Could not open the map; opening the window instead.")
        ns.UI.Show()
        return false
    end
    pcall(tabs.Select, KEY)
    return true
end
