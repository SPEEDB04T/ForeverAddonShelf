-- Abandon Advisor: its place in the game's own quest log (the world map's side panel).
--
-- With ForeverCore installed the advice is a side tab of the quest log, next to the
-- other Forever addons' tabs: ForeverCore owns that column and swaps the panels.
-- Without it the quest log gets a side button that opens the Abandon Advisor window.
--
-- The panel lives under the world map, so it sets no OnShow or OnHide script (addon
-- scripts in the map's close path taint it); ForeverCore tells it when it is visible.
local _, ns = ...
local QL = {}
ns.QuestLog = QL

local KEY = "abandonadvisor"
local NAME = "Abandon Advisor"
local ICON = "Interface\\Icons\\INV_Misc_Book_08"
local TOP_BAR = 29       -- the strip above the list, as tall as the quest log's search bar
local PAD = 12            -- the Map Legend's left padding (MapLegendFrameTemplate ScrollChild leftPadding)
local FALLBACK_WIDTH = 290

local visible = false
local panel, list, scrollContent, summary, empty

function QL.IsShown()
    return visible
end

-- "tab" (a real quest log tab), "button" (side button for the window) or nil.
function QL.Mode()
    return QL.mode
end

function QL.Status()
    if QL.mode == "tab" then return "tab in the quest log (ForeverCore)" end
    if QL.mode == "button" then return "side button on the quest log (no ForeverCore)" end
    if QL.error then return "not attached: " .. QL.error end
    return "not attached"
end

----------------------------------------------------------------------
-- Art
----------------------------------------------------------------------
local function SetTabIcon(tab)
    local icon = tab and tab.Icon
    if type(icon) ~= "table" or not icon.SetTexture then return end
    icon:SetTexture(ICON)
    if type(tab.SetFillToInterior) == "function" then
        -- The client's own fit for a square icon: it fills the tab art and the tab's mask cuts it to shape
        -- (SidePanelTabButtonMixin:UpdateIconInterior).
        tab:SetFillToInterior(true)
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

function QL.Update(res)
    if not panel or not res then return end
    local width = PanelWidth()
    scrollContent:SetWidth(width)
    summary:SetWidth(width - 2 * PAD)
    summary:SetText(ns.Score.Summary(res))
    local textHeight = ns.Num(summary:GetStringHeight())
    if not textHeight or textHeight < 10 then textHeight = 40 end

    local quests = ns.Score.Listed(res)
    local top = PAD + textHeight + PAD
    local rowsHeight = ns.UI.FillList(list, quests, top)
    empty:SetText(ns.Score.EmptyText(res))
    empty:SetShown(#quests == 0 and not res.error)
    scrollContent:SetHeight(top + rowsHeight + PAD)
end

local function Shown(shown)
    visible = shown and true or false
    if visible and ns.db then QL.Update(ns.Compute()) end
end

-- Built like the game's Map Legend panel, the quest log's other side-tab page
-- (Blizzard_UIPanels_Game/Mainline/MapLegendFrame.xml, MapLegendFrameTemplate): the quest log's
-- border frame, a scroll frame filling it with the quest log's parchment stretched over it,
-- and the title (Game15Font_Shadow) centred just above the border.
local function BuildBody()
    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -TOP_BAR)
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    local background = body:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(body)
    if ns.UI.HasAtlas("QuestLog-main-background") then
        background:SetAtlas("QuestLog-main-background")
    else
        -- A client without the quest log's parchment: the game's marble panel art.
        background:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble", "REPEAT", "REPEAT")
        background:SetHorizTile(true)
        background:SetVertTile(true)
    end
    QL.background = background

    -- The quest log's own frame around its list; a client without the template just has no frame.
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
            -- In the 22 px the quest log keeps free on the right for its own scroll bar.
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 2)
            bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, -4)
        end
    else
        scroll = CreateFrame("ScrollFrame", "AbandonAdvisorQuestLogScroll", body, "UIPanelScrollFrameTemplate")
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

    -- The quest log's empty text (QuestScrollFrame.EmptyText: Game16Font, centre, 50 up).
    empty = body:CreateFontString(nil, "ARTWORK", _G.Game16Font and "Game16Font" or "GameFontNormalLarge")
    empty:SetWidth(250)
    empty:SetPoint("CENTER", body, "CENTER", 0, 50)
    empty:SetText(_G.QUEST_LOG_NO_QUESTS or "Your quest log is empty.")
    empty:Hide()

    list = ns.UI.NewList(scrollContent)
end

local function BuildPanel(map)
    panel = CreateFrame("Frame", "AbandonAdvisorQuestLogPanel", map)
    -- The same box the quest log's own list takes (QuestMapFrame.xml, QuestsFrame).
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

-- No ForeverCore: one side button on the quest log that opens the window.
local function AttachButton(map)
    local tab = CreateFrame("Button", "AbandonAdvisorQuestLogTab", map, "LargeSideTabButtonTemplate")
    tab.tooltipText = NAME
    tab:SetCustomOnMouseUpHandler(function(_, mouseButton, upInside)
        if mouseButton == "LeftButton" and upInside then ns.UI.Toggle() end
    end)
    tab:SetChecked(false)

    local function shownTab(key)
        local other = map[key]
        if type(other) == "table" and other.IsShown and other:IsShown() then return other end
    end
    local above = shownTab("MapLegendTab") or shownTab("EventsTab") or shownTab("QuestsTab")
    if above then
        tab:SetPoint("TOP", above, "BOTTOM", 0, -3)
    else
        -- Forever hides the quest log's own tabs; start the column where its Quests tab would be.
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
        name = "AbandonAdvisorQuestLogTab",
        tooltip = NAME,
        panel = panel,
        order = 30,
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

-- Called once at login, when every enabled addon (ForeverCore among them) has loaded.
function QL.Init()
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        local ok = pcall(EventUtil.ContinueOnAddOnLoaded, "Blizzard_WorldMap", Attach)
        if ok then return end
    end
    Attach()
end

----------------------------------------------------------------------
-- LookShots (a helper on SuccuDev's machine only): the frames this addon
-- draws, so it can take a game screenshot of each the first time it shows.
-- The options window and minimap button are the shared kit's and listed there.
----------------------------------------------------------------------
local function VisiblePopup(which)
    if type(StaticPopup_FindVisible) ~= "function" then return nil end
    local ok, dialog = pcall(StaticPopup_FindVisible, which)
    if ok and type(dialog) == "table" then return dialog end
end

function QL.LookShotsFrames()
    return {
        { label = "window", frame = function() return _G.AbandonAdvisorFrame end },
        { label = "quest log tab page", frame = function() return QL.mode == "tab" and panel or nil end },
        { label = "quest log side button", frame = function() return QL.mode == "button" and QL.tab or nil end },
        { label = "row tooltip", frame = function()
            local tip = GameTooltip
            if type(tip) ~= "table" or not tip:IsShown() then return nil end
            local owner = tip.GetOwner and tip:GetOwner()
            if type(owner) == "table" and owner.isAbandonAdvisorRow then return tip end
        end },
        { label = "abandon question", frame = function() return VisiblePopup("ABANDONADVISOR_CONFIRM") end },
        { label = "group question", frame = function() return VisiblePopup("ABANDONADVISOR_GROUP") end },
    }
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["AbandonAdvisor"] = { version = ns.VERSION, frames = QL.LookShotsFrames() }

-- /abandon log: the quest log, on the Abandon Advisor tab.
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
