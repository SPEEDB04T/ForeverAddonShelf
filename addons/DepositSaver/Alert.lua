-- Deposit Saver: the loud part. When a tracked auction that is worth buying back is in its
-- last minutes (15 by default), a raid warning goes up in the middle of the screen with the
-- raid warning sound, a chat line with the item link, and the game's dialog with a "Find it"
-- button that opens the item at the auction house. It repeats every 5 minutes, never in a
-- fight: a warning that comes due in combat waits until the fight ends.
local _, ns = ...
local Num = ns.Num

local Alert = {}
ns.Alert = Alert
local POPUP = "DEPOSITSAVER_BUYBACK"
Alert.POPUP = POPUP

local function InCombat()
    local ok, c = pcall(InCombatLockdown)
    if ok and c == true then return true end
    local ok2, a = pcall(UnitAffectingCombat, "player")
    return ok2 and a == true
end
Alert.InCombat = InCombat

-- The auctions to warn about now, most urgent first.
function Alert.Due(now)
    now = now or ns.ServerNow()
    local db, me, due = ns.db, ns.Me(), {}
    if not db.warn then return due end
    local window, every = (Num(db.warnMinutes) or 15) * 60, (Num(db.repeatMinutes) or 5) * 60
    for _, rec in ipairs(ns.Records()) do
        local left = ns.Left(rec, now)
        local _, _, _, worth = ns.Worth(rec)
        local mine = rec.owner == me
        if left and left > 0 and left <= window and worth and not rec.muted and (db.warnOwn or not mine)
            and (not Num(rec.warnedAt) or now - rec.warnedAt >= every - 2) then
            due[#due + 1] = rec
        end
    end
    return due
end

local function Text(rec, now, more)
    local _, _, saving = ns.Worth(rec)
    local price, left = ns.Price(rec), ns.Left(rec, now)
    local name = ns.PlainName(rec)
    local head
    if rec.owner == ns.Me() then
        head = ("Your %s expires in %s%s. Have an alt or guildmate buy it for %s: saves %s."):format(name,
            rec.approx and "about " or "", ns.TimeText(left), ns.Money(price), ns.Money(saving))
    else
        head = ("Buy back %s's %s: %s left. %s saves %s."):format(rec.owner or "?", name,
            ns.TimeText(left), ns.Money(price), ns.Money(saving))
    end
    if more > 0 then head = head .. (" (+%d more)"):format(more) end
    return head
end
Alert.Text = Text

local function RaidWarning(text)
    local color = ChatTypeInfo and ChatTypeInfo.RAID_WARNING
    if RaidWarningUtil and RaidWarningUtil.AddMessage and RaidWarningFrame then
        if pcall(RaidWarningUtil.AddMessage, text, color, 12, 1) then return true end
    end
    if RaidNotice_AddMessage and RaidWarningFrame then
        if pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color, 12) then return true end
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        pcall(UIErrorsFrame.AddMessage, UIErrorsFrame, text, 1, 0.82, 0)
        return true
    end
    return false
end

local function Sound()
    if not (ns.db.sound and PlaySound) then return end
    local kit = SOUNDKIT and (SOUNDKIT.RAID_WARNING or SOUNDKIT.READY_CHECK)
    if kit then pcall(PlaySound, kit, "Master") end
end

local function DefinePopup()
    if type(StaticPopupDialogs) ~= "table" or StaticPopupDialogs[POPUP] then return end
    StaticPopupDialogs[POPUP] = {
        text = "%s",
        button1 = "Find it",
        button2 = "Later",
        button3 = "Stop for this one",
        OnAccept = function(dialog, data)
            data = data or (type(dialog) == "table" and dialog.data)
            ns.Find(data)
        end,
        OnAlt = function(dialog, data)
            data = data or (type(dialog) == "table" and dialog.data)
            local rec = data and ns.db.auctions[data]
            if rec then
                rec.muted = true
                ns.Print("No more warnings for " .. ns.ItemName(rec) .. ".")
                ns.Changed()
            end
        end,
        showAlert = 1,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
end
Alert.DefinePopup = DefinePopup

function Alert.Warn(due, now)
    local rec = due[1]
    local text = Text(rec, now, #due - 1)
    RaidWarning(text)
    Sound()
    if ns.db.chatLine then
        ns.Print(Text(rec, now, 0):gsub(ns.PlainName(rec):gsub("%p", "%%%0"), ns.ItemName(rec), 1))
        for i = 2, math.min(#due, 4) do ns.Print("  also: " .. ns.Line(due[i], now)) end
    end
    if ns.db.popup and StaticPopup_Show then
        DefinePopup()
        local detail = text
        if #due > 1 then detail = detail .. "\n\n/deposits list shows the others." end
        pcall(StaticPopup_Show, POPUP, detail, nil, rec.id)
    end
    Alert.lastText, Alert.lastAt = text, now
end

Alert.held = false
function Alert.Check()
    if not ns.db then return end
    local now = ns.ServerNow()
    local due = Alert.Due(now)
    if #due == 0 then
        Alert.held = false
        return
    end
    if InCombat() then
        Alert.held = true          -- PLAYER_REGEN_ENABLED looks again
        return
    end
    Alert.held = false
    for _, rec in ipairs(due) do rec.warnedAt = now end
    Alert.Warn(due, now)
end

-- /deposits test: what a warning looks like, with a made-up auction.
function Alert.Test()
    local now = ns.ServerNow()
    local sample = { id = -1, owner = "A Guildmate", item = 2589, qty = 20, unit = 3000, deposit = 9000, exact = true,
        expires = now + 12 * 60 }
    if InCombat() then
        ns.Print("In a fight: the warning would wait until it ends.")
    end
    RaidWarning(Text(sample, now, 0))
    Sound()
    ns.Print("Test warning: " .. Text(sample, now, 0) .. " Real warnings also open a window with Find it.")
end

function Alert.Start()
    DefinePopup()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(5, function() pcall(Alert.Check) end)
    end
end
