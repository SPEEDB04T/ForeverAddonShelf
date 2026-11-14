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
local PAD = 8
local FALLBACK_WIDTH = 290

local visible = false
local panel, list, scrollContent, summary, targetText, empty

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
local function AtlasInfo(atlas)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    local info = ns.Call(C_Texture.GetAtlasInfo, atlas)
    if type(info) == "table" then return info end
end

-- The quest log's own parchment over the whole box, cropped rather than squashed.
local function CoverWithAtlas(texture, atlas, width, height)
    local info = AtlasInfo(atlas)
    local iw, ih = info and ns.Num(info.width), info and ns.Num(info.height)
    local left, right = info and ns.Num(info.leftTexCoord), info and ns.Num(info.rightTexCoord)
    local top, bottom = info and ns.Num(info.topTexCoord), info and ns.Num(info.bottomTexCoord)
    if not (iw and ih and left and right and top and bottom) or iw <= 0 or ih <= 0 then return false end
    texture:SetAtlas(atlas)
    if not (width and height) or width <= 0 or height <= 0 then return true end
    local box, native = width / height, iw / ih
    if native > box then
        local cut = (right - left) * (1 - box / native) / 2
        left, right = left + cut, right - cut
    else
        local cut = (bottom - top) * (1 - native / box) / 2
        top, bottom = top + cut, bottom - cut
    end
    texture:SetTexCoord(left, right, top, bottom)
    return true
end

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
    targetText:SetText(("Aim for %d free"):format(res.target or ns.db.target))

    local width = PanelWidth()
    scrollContent:SetWidth(width)
    summary:SetWidth(width - 2 * PAD)
    summary:SetText(ns.Score.Summary(res))
    local textHeight = ns.Num(summary:GetStringHeight())
    if not textHeight or textHeight < 10 then textHeight = 40 end

    local quests = res.rows or {}
    local top = PAD + textHeight + PAD
    local rowsHeight = ns.UI.FillList(list, quests, top)
    if #quests == 0 and not res.error then
        empty:ClearAllPoints()
        empty:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", PAD, -top)
        empty:Show()
        rowsHeight = 30
    else
        empty:Hide()
    end
    scrollContent:SetHeight(top + rowsHeight + PAD)
end

local function Shown(shown)
    visible = shown and true or false
    if visible and ns.db then QL.Update(ns.Compute()) end
end

local function BuildTopBar()
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", panel, "TOPLEFT", 8, -TOP_BAR / 2)
    title:SetText(NAME)

    local more = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    more:SetSize(20, 20)
    more:SetPoint("RIGHT", panel, "TOPRIGHT", -2, -TOP_BAR / 2)
    more:SetText("+")
    more:SetScript("OnClick", function() ns.UI.SetTarget(1) end)

    targetText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    targetText:SetPoint("RIGHT", more, "LEFT", -4, 0)

    local less = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    less:SetSize(20, 20)
    less:SetPoint("RIGHT", targetText, "LEFT", -4, 0)
    less:SetText("-")
    less:SetScript("OnClick", function() ns.UI.SetTarget(-1) end)
end

local function BuildBody()
    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -TOP_BAR)
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    local background = body:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(body)
    local function LayBackground(width, height)
        if not CoverWithAtlas(background, "QuestLog-main-background", width, height) then
            background:SetColorTexture(0.06, 0.05, 0.04, 0.95)
        end
    end
    LayBackground(ns.Num(body:GetWidth()), ns.Num(body:GetHeight()))
    body:SetScript("OnSizeChanged", function(_, width, height) LayBackground(width, height) end)

    -- The quest log's own frame around its list; a client without the template just has no frame.
    pcall(CreateFrame, "Frame", nil, body, "QuestLogBorderFrameTemplate")

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

    empty = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetText("Your quest log is empty.")
    empty:Hide()

    list = ns.UI.NewList(scrollContent, true)
end

local function BuildPanel(map)
    panel = CreateFrame("Frame", "AbandonAdvisorQuestLogPanel", map)
    -- The same box the quest log's own list takes (QuestMapFrame.xml, QuestsFrame).
    panel:SetPoint("TOPLEFT", map.ContentsAnchor, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", map.ContentsAnchor, "BOTTOMRIGHT", -22, 0)
    panel:SetFrameLevel((ns.Num(map:GetFrameLevel()) or 0) + 20)
    panel:EnableMouse(true)
    panel:Hide()
    BuildTopBar()
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
