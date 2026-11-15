-- Abandon Advisor: the rules. Pure Lua: takes scanned tables, returns rated rows.
-- A higher score means the quest is a better one to abandon.
local _, ns = ...
local Score = {}
ns.Score = Score

local floor, max, min = math.floor, math.max, math.min

Score.ABANDON_AT = 40   -- score from which the verdict is "abandon"
Score.MAYBE_AT = 15     -- score from which the verdict is "maybe"

local VERDICT_ORDER = { turnin = 1, abandon = 2, maybe = 3, keep = 4 }

local function round(n) return floor(n + 0.5) end

local function add(row, pts, short, text)
    row.score = row.score + pts
    row.reasons[#row.reasons + 1] = { pts = pts, short = short, text = text or short }
end

local function levelRules(row, q, player)
    if q.scaling or not q.level or player.level <= 0 then return end
    local diff = q.level - player.level
    local trivial = q.trivial
    if trivial == nil then trivial = diff < -player.greenRange end
    row.trivial = trivial
    if trivial then
        add(row, 35, "grey", ("Grey for you (level %d): next to no XP"):format(q.level))
    elseif diff >= 5 then
        add(row, 30, ("%d levels above you"):format(diff),
            ("%d levels above you: not doable for a while"):format(diff))
    elseif diff >= 3 then
        add(row, 12, "orange", ("%d levels above you: hard right now"):format(diff))
    end
end

local function xpRules(row, q, player, ctx)
    if player.atMax or not q.xp then return end
    if player.xpMax > 0 then
        local pct = q.xp / player.xpMax * 100
        row.xpPct = pct
        if pct >= 4 then
            add(row, -15, "big XP", ("Worth %.1f%% of a level"):format(pct))
        elseif pct >= 2 then
            add(row, -5, "decent XP", ("Worth %.1f%% of a level"):format(pct))
        elseif pct < 0.75 then
            add(row, 15, "tiny XP", ("Only %.1f%% of a level in XP"):format(pct))
        end
    elseif ctx.medianXP and ctx.medianXP > 0 then
        local ratio = q.xp / ctx.medianXP
        if ratio >= 1.6 then
            add(row, -15, "big XP", "Much more XP than most of your log")
        elseif ratio <= 0.4 then
            add(row, 15, "tiny XP", "Much less XP than most of your log")
        end
    end
end

local function progressRules(row, q)
    if q.progress == nil then return end
    if q.progress <= 0 then
        add(row, 10, "not started", "Not started: nothing is lost by dropping it")
    else
        local pct = round(q.progress * 100)
        add(row, -round(50 * q.progress), pct .. "% done", ("%d%% done: dropping it throws that away"):format(pct))
    end
end

local function groupRules(row, q, player)
    local tag = q.tag
    if tag == "legendary" then
        add(row, -40, "legendary", "Legendary quest")
    elseif tag == "raid" then
        if not player.inRaid then add(row, 25, "raid quest", "Raid quest and you are not in a raid") end
    elseif tag == "dungeon" then
        if player.grouped then
            add(row, -10, "dungeon, grouped", "Dungeon quest and you are in a group")
        else
            add(row, 15, "dungeon quest", "Dungeon quest and you are not in a group")
        end
    elseif tag == "group" or (q.suggestedGroup or 0) >= 2 then
        local size = (q.suggestedGroup or 0) >= 2 and (" (%d players suggested)"):format(q.suggestedGroup) or ""
        if player.grouped then
            add(row, -5, "group quest, grouped", "Group quest" .. size .. " and you are in a group")
        else
            add(row, 30, "group quest, solo", "Group quest" .. size .. " and you are solo")
        end
    elseif tag == "pvp" then
        add(row, 5, "PvP quest", "PvP quest")
    end
end

local function placeRules(row, q, ctx)
    if q.sameZone then
        add(row, -20, "in this zone", "In the zone you are in now")
    elseif q.zone then
        local siblings = ctx.zoneCount[q.zone] or 1
        if siblings <= 1 then
            add(row, 10, "only quest there", ("Your only quest in %s: a trip for one quest"):format(q.zone))
        elseif siblings >= 4 then
            add(row, -8, siblings .. " quests there",
                ("%s holds %d of your quests: worth the trip"):format(q.zone, siblings))
        end
    end
end

local function otherRules(row, q, ctx)
    if q.classQuest then add(row, -30, "class quest", "Class quest") end
    if q.chainNext then add(row, -12, "chain", "Leads to follow-up quests") end
    if q.itemStarted then add(row, -12, "item-started", "Started from an item you may not get again") end
    if (q.items or 0) > 0 then add(row, -8, "item reward", "Rewards an item") end
    if (q.frequency or 0) > 0 then add(row, 15, "repeatable", "Repeatable: easy to pick up again") end
    if q.tracked and ctx.trackingMeans then add(row, -8, "tracked", "You are tracking it") end
end

-- "12" for 12.4, "4.5" for 4.52: a drop rate in percent
local function rateText(rate)
    if rate >= 10 then return ("%d"):format(round(rate)) end
    return ("%.1f"):format(rate)
end

-- For the tooltip: "Gnoll Paw 12%, about 58 kills for the 7 left"
function Score.DropText(drop)
    return ("%s %s%%, about %d kills for the %d left"):format(drop.item or "Quest item", rateText(drop.rate),
        min(999, max(1, round(drop.kills))), drop.left)
end

-- A quest whose items rarely drop costs many kills. Up to a dozen kills is what any kill quest
-- asks; past that every 2.5 kills still to go is a point, up to 25.
local function dropRules(row, q, ctx)
    local drop = q.drop
    if not drop or not ctx.drops then return end
    local pts = min(25, round((drop.kills - 12) / 2.5))
    if pts < 3 then return end
    local kills = min(999, round(drop.kills))
    add(row, pts, ("~%d kills for drops"):format(kills),
        ("%s drops %s%% of the time: about %d kills for the %d you still need"):format(
            drop.item or "Its quest item", rateText(drop.rate), kills, drop.left))
end

local function partnerRules(row, q, ctx)
    local who = ctx.partner[q.id]
    if who then
        add(row, 30, who .. " abandoned it", ("%s abandoned it: you would be doing it without your group"):format(who))
    end
end

function Score.Rate(q, player, ctx)
    local row = { score = 0, reasons = {} }
    for key, value in pairs(q) do row[key] = value end

    if q.ready then
        row.verdict, row.locked = "turnin", true
        add(row, 0, "finished", "Finished: hand it in to free the slot and collect the reward")
        return row
    end
    if q.failed then
        row.verdict, row.score = "abandon", 100
        row.reasons[1] = { pts = 100, short = "failed", text = "Failed: abandon it and pick it up again" }
        if q.canAbandon == false then row.verdict, row.locked = "keep", true end
        return row
    end

    levelRules(row, q, player)
    xpRules(row, q, player, ctx)
    progressRules(row, q)
    groupRules(row, q, player)
    placeRules(row, q, ctx)
    otherRules(row, q, ctx)
    dropRules(row, q, ctx)
    partnerRules(row, q, ctx)
    table.sort(row.reasons, function(a, b)
        local pa, pb = math.abs(a.pts), math.abs(b.pts)
        if pa ~= pb then return pa > pb end
        return a.short < b.short
    end)

    if q.canAbandon == false then
        row.verdict, row.locked = "keep", true
        table.insert(row.reasons, 1, { pts = 0, short = "cannot be abandoned", text = "The game does not allow abandoning this quest" })
    elseif ctx.keep and ctx.keep[q.id] then
        row.verdict, row.locked, row.pinned = "keep", true, true
        table.insert(row.reasons, 1, { pts = 0, short = "pinned", text = "You pinned this quest as keep" })
    elseif row.score >= Score.ABANDON_AT then
        row.verdict = "abandon"
    elseif row.score >= Score.MAYBE_AT then
        row.verdict = "maybe"
    else
        row.verdict = "keep"
    end
    return row
end

local function median(values)
    if #values == 0 then return nil end
    table.sort(values)
    local mid = floor((#values + 1) / 2)
    if #values % 2 == 1 then return values[mid] end
    return (values[mid] + values[mid + 1]) / 2
end

-- quests, player, meta come from Scan; opts = { target = n, keep = { [questID] = true },
-- drops = false to ignore drop rates, partner = { [questID] = "who in your group abandoned it" } }
function Score.RateAll(quests, player, meta, opts)
    opts = opts or {}
    local ctx = { zoneCount = {}, keep = opts.keep or {}, drops = opts.drops ~= false, partner = opts.partner or {} }
    local xps, tracked = {}, 0
    for _, q in ipairs(quests) do
        if not q.ready then
            if q.zone then ctx.zoneCount[q.zone] = (ctx.zoneCount[q.zone] or 0) + 1 end
            if q.xp and q.xp > 0 then xps[#xps + 1] = q.xp end
        end
        if q.tracked then tracked = tracked + 1 end
    end
    ctx.medianXP = median(xps)
    -- Tracking only says something when you track a minority of your quests.
    ctx.trackingMeans = #quests > 0 and tracked > 0 and tracked <= #quests / 2

    local rows, ready = {}, 0
    for _, q in ipairs(quests) do
        local row = Score.Rate(q, player, ctx)
        if row.verdict == "turnin" then ready = ready + 1 end
        rows[#rows + 1] = row
    end

    local count, cap = meta.count or #rows, meta.max or 25
    local free = max(0, cap - count)
    local target = max(1, opts.target or 3)
    local needed = max(0, target - free)

    -- Mark the best quests to drop until the target is met, whatever their verdict.
    local order = {}
    for _, row in ipairs(rows) do
        if not row.locked then order[#order + 1] = row end
    end
    table.sort(order, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)
    local picks = 0
    for i = 1, math.min(needed, #order) do
        order[i].pick = true
        picks = picks + 1
    end

    table.sort(rows, function(a, b)
        if (a.pick or false) ~= (b.pick or false) then return a.pick == true end
        local va, vb = VERDICT_ORDER[a.verdict], VERDICT_ORDER[b.verdict]
        if va ~= vb then return va < vb end
        if a.score ~= b.score then return a.score > b.score end
        return a.id < b.id
    end)

    return {
        rows = rows, player = player, count = count, max = cap, free = free, target = target,
        needed = needed, picks = picks, ready = ready,
        hiddenByCollapse = meta.hiddenByCollapse, error = meta.error,
    }
end

function Score.Summary(res)
    if res.error then return res.error end
    local parts = { ("Quest log %d/%d (%d free)."):format(res.count, res.max, res.free) }
    if res.ready > 0 then
        parts[#parts + 1] = ("%d finished: hand %s in first, it costs nothing."):format(
            res.ready, res.ready == 1 and "it" or "them")
    end
    if res.needed == 0 then
        parts[#parts + 1] = ("You already have %d free; no need to drop anything."):format(res.free)
    elseif res.picks < res.needed then
        parts[#parts + 1] = ("To reach %d free you need %d more, but only %d can be dropped."):format(
            res.target, res.needed, res.picks)
    else
        parts[#parts + 1] = ("To reach %d free, drop the %d marked quest%s."):format(
            res.target, res.picks, res.picks == 1 and "" or "s")
    end
    if res.hiddenByCollapse then
        parts[#parts + 1] = ("%d quests are under collapsed zone headers and not rated: expand them in the quest log.")
            :format(res.hiddenByCollapse)
    end
    return table.concat(parts, " ")
end
