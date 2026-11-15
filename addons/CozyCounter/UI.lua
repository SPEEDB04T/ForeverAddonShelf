-- Cozy Counter: the reminder. One greyed-out buff icon per missing buff, built as the game's
-- own buff icon (what it cost you is in the tooltip). Shown only
-- out of a fight, alive, on the ground and (by default) outside inns and cities; hidden at max
-- level or with XP gain switched off. It is a plain frame (nothing secure), so hiding it in a
-- fight is allowed.
local _, ns = ...
local UI = {}
ns.UI = UI

-- The game's buff icon: 30 wide, 40 high with the line under it, 5 apart (AuraContainerTemplate's
-- iconPadding). A bigger or smaller row comes from SetScale on the holder, never from the art.
local ICON, HEIGHT, GAP = 30, 40, 5
local holder
local buttons = {}
local testing = false

local NORMAL = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
local WHITE = HIGHLIGHT_FONT_COLOR or { r = 1, g = 1, b = 1 }
local GRAY = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
local GREEN = GREEN_FONT_COLOR or { r = 0.1, g = 1, b = 0.1 }
local function C(c) return c.r, c.g, c.b end

local function SpellIcon(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        local v = ns.Call(C_Spell.GetSpellTexture, id)
        if v then return v end
    end
    return ns.Call(GetSpellTexture, id)
end

local function Icon(key)
    local info = ns.INFO[key]
    if key == "bag" then
        return SpellIcon(info.spellID)
            or (C_Item and C_Item.GetItemIconByID and ns.Call(C_Item.GetItemIconByID, info.item))
            or info.iconPath
    elseif key == "camp" then
        return SpellIcon(info.tentSpell) or info.iconPath
    end
    return info.iconPath
end

local function HasKit()
    return ns.Kit and ns.Options and ns.Options.Ready and ns.Options.Ready()
end

----------------------------------------------------------------------
-- Tooltip
----------------------------------------------------------------------
local function Status(key)
    local s = ns.Current()
    if key == "food" then
        return s and s.food and "You are Well Fed." or "You are not Well Fed.", s and s.food
    elseif key == "bag" then
        local stacks = s and s.bag or 0
        if not ns.HasBag() then
            return "You don't carry a Cozy Sleeping Bag. Its quest chain starts at level 14 at the Burned-Out Remains (Westfall or The Barrens).", false
        end
        return ("Well-Rested: %d of %d stacks."):format(stacks, ns.db.bagStacks), stacks >= ns.db.bagStacks
    else
        if s and s.boosted then return "The Camp Tent has topped you up this hour (Boosted Rest).", true end
        local xp = ns.ReadXP()
        local want = xp and xp.max * ns.db.campShare / 100 or 0
        return ("Rested XP: %s, the tent gives %s."):format(ns.Commas(ns.Rested()), ns.Commas(want)), ns.Rested() >= want
    end
end

local function ShowTooltip(self)
    local key = self.key
    local info = ns.INFO[key]
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")     -- as AuraButtonMixin:OnEnter
    GameTooltip:AddLine(info.title, C(NORMAL))
    GameTooltip:AddLine(info.gives, C(WHITE))
    GameTooltip:AddLine(info.how, C(GRAY))
    local line, ok = Status(key)
    if ok then GameTooltip:AddLine(line, C(GREEN)) else GameTooltip:AddLine(line, C(WHITE)) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Lost to this, this session", ns.Commas(ns.session.lost[key]) .. " XP", C(NORMAL), C(WHITE))
    GameTooltip:AddDoubleLine("Lost to this, all time", ns.Commas(ns.char.lost[key]) .. " XP", C(NORMAL), C(WHITE))
    GameTooltip:AddDoubleLine("All buffs, this session", ns.Commas(ns.Total(ns.session.lost)) .. " XP", C(NORMAL), C(WHITE))
    GameTooltip:AddDoubleLine("All buffs, all time", ns.Commas(ns.Total(ns.char.lost)) .. " XP", C(NORMAL), C(WHITE))
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: what you lost, in chat", C(GRAY))
    GameTooltip:AddLine("Right-click: options", C(GRAY))
    if not ns.db.locked then GameTooltip:AddLine("Drag: move", C(GRAY)) end
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- Building: each icon is the game's buff icon, AuraButtonArtTemplate
-- (Blizzard_BuffFrame/BuffFrameTemplates.xml): a 30x40 button, the 30x30 icon at its top,
-- Duration (GameFontNormalSmall) under the icon, Count (NumberFontNormal) at the icon's
-- bottom right. No border, highlight or pushed art: the buff icon has none.
----------------------------------------------------------------------
local function BuildArt(b)
    -- the same layers by hand, for a client where the template is missing
    b:SetSize(ICON, HEIGHT)
    b.Icon = b:CreateTexture(nil, "BACKGROUND")
    b.Icon:SetSize(ICON, ICON)
    b.Icon:SetPoint("TOP", b, "TOP", 0, 0)
    b.Duration = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
    b.Duration:SetPoint("TOP", b.Icon, "BOTTOM", 0, 0)
    b.Duration:Hide()
    b.Count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.Count:SetPoint("BOTTOMRIGHT", b.Icon, "BOTTOMRIGHT", -2, 2)
end

local function MakeButton(key)
    local ok, b = pcall(CreateFrame, "Button", nil, holder, "AuraButtonArtTemplate")
    if not ok or not b then b = CreateFrame("Button", nil, holder) end
    if type(b.Icon) ~= "table" or type(b.Count) ~= "table" or type(b.Duration) ~= "table" then BuildArt(b) end
    b.key = key
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.Icon:SetTexture(Icon(key))
    b.Icon:SetDesaturated(true)          -- missing: the game's look for "not there"
    b.Count:Hide()
    if type(b.DebuffBorder) == "table" then b.DebuffBorder:Hide() end
    if type(b.TempEnchantBorder) == "table" then b.TempEnchantBorder:Hide() end
    if type(b.Symbol) == "table" then b.Symbol:Hide() end

    b:SetScript("OnEnter", ShowTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            if HasKit() then ns.Kit.Open() else ns.Print("the options window appears after you restart the game once.") end
        else
            ns.PrintSummary()
        end
    end)
    b:SetScript("OnDragStart", function()
        if not ns.db.locked and not InCombatLockdown() then holder:StartMoving() end
    end)
    b:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        local point, _, relPoint, x, y = holder:GetPoint(1)
        if point then ns.db.point = { point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5) } end
    end)
    b:Hide()
    buttons[key] = b
    return b
end

function UI.Place()
    if not holder then return end
    local p = ns.db.point
    holder:ClearAllPoints()
    holder:SetPoint(p[1] or "TOP", UIParent, p[2] or "TOP", p[3] or 0, p[4] or -150)
    holder:SetScale(ns.db.scale or 1)
end

function UI.Init()
    if holder then return end
    holder = CreateFrame("Frame", "CozyCounterReminder", UIParent)
    holder:SetSize(ICON, HEIGHT)
    holder:SetMovable(true)
    holder:SetClampedToScreen(true)
    holder:SetFrameStrata("LOW")             -- BuffFrame's strata
    for _, key in ipairs(ns.KEYS) do MakeButton(key) end
    UI.Place()
    holder:Hide()
    UI.holder, UI.buttons = holder, buttons
    UI.Update()
end

----------------------------------------------------------------------
-- Showing
----------------------------------------------------------------------
function UI.Testing() return testing end
function UI.SetTesting(on)
    testing = on and true or false
    UI.Update()
end

-- Which reminders to show now, in order.
function UI.Wanted()
    local db = ns.db
    if testing then return { "food", "bag", "camp" } end
    if not db or not ns.Active() then return {} end
    if InCombatLockdown() then return {} end
    if ns.Call(UnitIsDeadOrGhost, "player") == true then return {} end
    if ns.Call(UnitOnTaxi, "player") == true then return {} end
    if db.hideResting and ns.Call(IsResting) == true then return {} end
    local missing = ns.Missing()
    if not missing then return {} end
    local list = {}
    for _, key in ipairs(ns.KEYS) do
        if missing[key] and db.remind[key] and (key ~= "bag" or not db.needBag or ns.HasBag()) then
            list[#list + 1] = key
        end
    end
    return list
end

function UI.Update()
    if not holder or not ns.db then return end
    if testing and InCombatLockdown() then testing = false end
    local ok, list = pcall(UI.Wanted)
    if not ok then list = {} end
    for _, b in pairs(buttons) do b:Hide() end
    local n = #list
    if n == 0 then holder:Hide() return end
    holder:SetSize(n * ICON + (n - 1) * GAP, HEIGHT)
    local s = ns.Current()
    for i, key in ipairs(list) do
        local b = buttons[key]
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (ICON + GAP), 0)
        -- the stacks you have, shown only above 1, as AuraButtonMixin:Update does
        local stacks = key == "bag" and s and s.bag or 0
        if stacks > 1 then
            b.Count:SetText(stacks)
            b.Count:Show()
        else
            b.Count:Hide()
        end
        b:Show()
    end
    holder:Show()
end
