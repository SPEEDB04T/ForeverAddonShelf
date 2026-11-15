-- Destroy Advisor: a line in the game's item tooltips, and Baganator's junk marking.
local _, ns = ...
local Hooks = {}
ns.Hooks = Hooks

local function BagSlotOf(data)
    local guid = type(data) == "table" and ns.Val(rawget(data, "guid"))
    if not (guid and C_Item and C_Item.GetItemLocation) then return nil end
    local ok, location = pcall(C_Item.GetItemLocation, guid)
    if not (ok and location and location.IsBagAndSlot) then return nil end
    local okBag, isBag = pcall(location.IsBagAndSlot, location)
    if not (okBag and isBag) then return nil end
    local okSlot, bag, slot = pcall(location.GetBagAndSlot, location)
    if not okSlot then return nil end
    return ns.Num(bag), ns.Num(slot)
end

-- "Destroy Advisor: not needed, its quest is done" under the game's own lines.
function Hooks.AddLine(tooltip, bag, slot)
    if not (ns.db and ns.db.tooltip and tooltip and tooltip.AddLine) then return end
    if ns.UI and ns.UI.IsOwnTooltip and ns.UI.IsOwnTooltip() then return end   -- the list's rows say it themselves
    local owner = tooltip.GetOwner and tooltip:GetOwner()
    if type(owner) == "table" and owner.isDestroyAdvisorRow then return end
    if not (bag and slot) then return end
    local entry = ns.EntryAt(bag, slot)
    if not entry then return end
    local r, g, b = ns.GameColor("ORANGE_FONT_COLOR", 1, 0.5, 0.25)
    tooltip:AddLine(("%s: not needed, %s"):format(ns.NAME, entry.short), r, g, b, true)
    return true
end

local function TooltipHook()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType
        and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            local bag, slot = BagSlotOf(data)
            pcall(Hooks.AddLine, tooltip, bag, slot)
        end)
        return "postcall"
    end
    if hooksecurefunc and GameTooltip and GameTooltip.SetBagItem then
        hooksecurefunc(GameTooltip, "SetBagItem", function(tooltip, bag, slot)
            local ok, added = pcall(Hooks.AddLine, tooltip, bag, slot)
            if ok and added then tooltip:Show() end
        end)
        return "setbagitem"
    end
end

----------------------------------------------------------------------
-- Baganator: a junk plugin, so its bags can grey out what this addon would destroy
-- (picked in Baganator's options under the junk setting).
----------------------------------------------------------------------
ns.Baganator = nil

local function RegisterBaganator()
    local api = type(Baganator) == "table" and Baganator.API
    if not (type(api) == "table" and type(api.RegisterJunkPlugin) == "function") then return false end
    local ok = pcall(api.RegisterJunkPlugin, ns.NAME, "destroyadvisor", function(bagID, slotID, itemID)
        if not ns.db then return false end
        local entry = ns.Scan().bySlot[tostring(bagID) .. ":" .. tostring(slotID)]
        return entry ~= nil and (itemID == nil or entry.itemID == itemID)
    end)
    if not ok then return false end
    ns.Baganator = {
        Refresh = function()
            if type(api.RequestItemButtonsRefresh) == "function" then pcall(api.RequestItemButtonsRefresh) end
        end,
    }
    return true
end

function Hooks.Init()
    if Hooks.done then return end
    Hooks.done = true
    Hooks.tooltip = TooltipHook()
    Hooks.baganator = RegisterBaganator()
end
