-- SkillPath has no window of its own. It adds a page to two of the game's windows:
--   Professions: a side tab under the profession tabs (ForeverCore's shared column when that addon
--   is installed). Left: the path as numbered steps, each with its money. Right: the step you picked.
--   Auction house: a bottom tab after Buy / Sell / Auctions (through LibAHTab when another addon
--   brought it, so every addon's tabs line up). What to buy, the price scan, what to sell where.
-- The path can be someone else's (a profession and a skill range): both pages show it, and a small
-- window holds it as text to copy.
local _, ns = ...
local UI = {}
ns.UI = UI

local Num = ns.Num

-- A card is the crafting output log's 46-pixel item element (item card art, item button, two
-- lines of text). Lines, headers and notes are the other rows.
local CARD, LINE, HEAD, GAP, PAD = 46, 20, 26, 2, 4
local TRADE_KEY, AH_TAB = "skillpath", "SkillPathAuctionTab"

local ICON_BUY = "Interface\\Icons\\INV_Misc_Bag_08"
local ICON_SELL = "Interface\\Icons\\INV_Misc_Coin_02"
local ICON_TRAIN = "Interface\\Icons\\INV_Misc_Book_11"
local ICON_GAP = "Interface\\Icons\\INV_Misc_QuestionMark"

local function HasAtlas(name)
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, name)
        return ok and info ~= nil
    end
    return true
end

local function Art(texture, atlas, file)
    if texture.SetAtlas and HasAtlas(atlas) and pcall(texture.SetAtlas, texture, atlas) then return true end
    if file then texture:SetTexture(file) end
    return false
end

local function Color(name, r, g, b) return ns.GameColor(name, r, g, b) end
local function White() return Color("HIGHLIGHT_FONT_COLOR", 1, 1, 1) end
local function Gold() return Color("NORMAL_FONT_COLOR", 1, 0.82, 0) end
local function Grey() return Color("GRAY_FONT_COLOR", 0.5, 0.5, 0.5) end
local function Red() return Color("RED_FONT_COLOR", 1, 0.1, 0.1) end
local function Green() return Color("GREEN_FONT_COLOR", 0.1, 1, 0.1) end

-- The professions window's own recipe colours.
local DIFF = {
    [0] = { "DIFFICULT_DIFFICULTY_COLOR", 1, 0.5, 0.25 },
    [1] = { "FAIR_DIFFICULTY_COLOR", 1, 1, 0 },
    [2] = { "EASY_DIFFICULTY_COLOR", 0.25, 0.75, 0.25 },
    [3] = { "TRIVIAL_DIFFICULTY_COLOR", 0.5, 0.5, 0.5 },
}
function UI.DifficultyColor(r, s, offset)
    local key
    if r.y then
        local eff = s + (offset or 0)
        if eff >= r.g then
            key = 3
        elseif eff < r.y then
            key = 0
        else
            key = eff < math.floor((r.y + r.g) / 2) and 1 or 2
        end
    else
        key = r.colour or 0
    end
    local d = DIFF[key] or DIFF[0]
    return Color(d[1], d[2], d[3], d[4])
end


----------------------------------------------------------------------
-- Words
----------------------------------------------------------------------
local function Plural(n, one, many) return n == 1 and one or many end

-- Units and crafts to plan for: an expected 34.9 is 35.
local function Units(n) return math.max(0, math.ceil(n - 0.05)) end
UI.Units = Units

-- M: how money is written (coin icons on the pages, plain "1g 2s 3c" in the written guide).
local function CostText(cost, priced, M)
    M = M or ns.Money
    if not priced then return cost >= 0.5 and (M(cost) .. " + no price") or "no price" end
    if cost < 0.5 then return "free" end
    return M(cost)
end

function UI.CraftCount(step)
    return math.max(1, Units(step.crafts))
end

-- Every point of the step comes from an orange craft, so the count is exact.
local function Exact(step)
    for _, p in ipairs(step.points) do
        if not p.orange then return false end
    end
    return true
end

-- The supply the path was priced from (someone else's path starts with empty bags).
local function Supply(plan, item)
    local ctx = plan and plan.ctx
    if ctx and ctx.supply then return ctx.supply(item) end
    return ns.Prices.Supply(item)
end

-- Where one reagent comes from, in a line.
function UI.SourceText(item, plan, M)
    M = M or ns.Money
    local sup = Supply(plan, item)
    local parts = {}
    if sup.have > 0 then parts[#parts + 1] = ("you have %d"):format(sup.have) end
    if sup.listed > 0 then
        local cheapest
        for _, u in ipairs(sup.units) do cheapest = cheapest and math.min(cheapest, u.u) or u.u end
        for _, l in ipairs(sup.lots) do cheapest = cheapest and math.min(cheapest, l.u) or l.u end
        if sup.auctionator then
            parts[#parts + 1] = ("Auctionator's price %s each (%s)"):format(M(cheapest), ns.Age(sup.age))
        elseif sup.summary then
            parts[#parts + 1] = ("auction from %s each (%d listed, %s, cheapest only)"):format(M(cheapest), sup.listed, ns.Age(sup.age))
        else
            parts[#parts + 1] = ("auction from %s each (%d listed, %s)"):format(M(cheapest), sup.listed, ns.Age(sup.age))
        end
    end
    if sup.vendor then
        parts[#parts + 1] = ("vendor %s each%s"):format(M(sup.vendor),
            sup.vendorFrom == "vendor" and "" or " (item data)")
    end
    if not sup.priced then parts[#parts + 1] = ns.Prices.Missing(sup) end
    return table.concat(parts, "; ")
end

-- Why nothing buys a leftover.
local function NoSaleText(sp)
    local res = sp.res
    local vendor
    if not ns.db.sellVendor then
        vendor = "vendor sales are off in the options"
    elseif res.sell == nil then
        vendor = "its vendor price isn't loaded yet"
    else
        vendor = "no vendor buys it"
    end
    if res.why then return vendor .. "; auction house: " .. res.why end
    return vendor
end

-- Where left-over units go, in a few words. counts: say how many go where.
local function DestText(sp, M, counts)
    M = M or ns.Money
    if sp.ah and sp.vendor then
        if counts then
            return ("%d at auction (%s each), %d to a vendor (%s each)"):format(sp.ah.n, M(sp.ah.each), sp.vendor.n,
                M(sp.vendor.each))
        end
        return ("auction house (%s each), then a vendor (%s each)"):format(M(sp.ah.each), M(sp.vendor.each))
    elseif sp.ah and sp.none > 0 then
        return ("auction house (%s each) for as many as sell"):format(M(sp.ah.each))
    elseif sp.ah then
        return ("auction house, %s each"):format(M(sp.ah.each))
    elseif sp.vendor then
        return ("vendor, %s each"):format(M(sp.vendor.each))
    end
    return "no sale"
end

-- What a craft step's result is for: none (it makes nothing), n (units this step makes), used
-- ("all" or "some" go into later steps), left (the path's left-over units of it, with where they go).
local function Output(plan, step, byItem)
    local r = step.r
    if not (r.out and r.outQty and r.outQty > 0) then return { none = true, enchant = plan.line == 333 } end
    local made, used = plan.made[r.out] or 0, plan.madeUsed[r.out] or 0
    local o = { item = r.out, n = Units(step.crafts * r.outQty), left = byItem[r.out] }
    if used >= made - 0.05 or not o.left then o.used = "all" elseif used > 0.05 then o.used = "some" end
    return o
end

local function OutputText(o, M)
    if o.none then
        return o.enchant and "Makes nothing to sell: the enchant goes on gear" or "Makes nothing to sell"
    end
    local head = ("Makes %d: "):format(o.n)
    if o.used == "all" then return head .. "used by later steps" end
    local dest = DestText(o.left.sp, M, o.left.left == o.n)
    if o.used == "some" then return head .. "later steps use some, the rest: " .. dest end
    return head .. dest
end
UI.OutputText = OutputText

-- What the whole path costs: spend (the shopping list and the trainer), back (what selling the
-- rest gives), net (only when every reagent and fee is priced).
function UI.Totals(plan)
    local steps = UI.Steps(plan)
    local back = 0
    for _, s in ipairs(steps) do
        if s.kind == "sell" then back = s.back end
    end
    local t = { spend = plan.spend or 0, back = back, missing = {} }
    for _, e in ipairs(plan.shopping or {}) do
        if e.buy > 0 and not e.cost then t.missing[#t.missing + 1] = ns.Prices.ItemName(e.item) end
    end
    if plan.complete and not plan.gapAt then t.net = t.spend - back end
    return t
end

-- The profession and where the path goes; what it costs.
function UI.Summary(plan, M)
    M = M or ns.Money
    if not plan.ok then return plan.name or ns.NAME, plan.why or "" end
    local title = ("%s %d to %d"):format(plan.name, plan.from, plan.to)
    if plan.forOther then title = title .. ", for someone else" end
    local t = UI.Totals(plan)
    if #t.missing > 0 and t.spend < 0.5 then
        return title, "No prices yet. Scan at the auction house."
    end
    local parts = {}
    local spend = "Spend " .. CostText(t.spend, true, M)
    if plan.gapAt then spend = spend .. (" to reach %d"):format(plan.gapAt) end
    parts[#parts + 1] = spend .. "."
    if #t.missing > 0 then
        local names = t.missing[1]
        if #t.missing == 2 then
            names = names .. ", " .. t.missing[2]
        elseif #t.missing > 2 then
            names = names .. (" and %d more"):format(#t.missing - 1)
        end
        parts[#parts + 1] = "Not priced: " .. names .. "."
    end
    if plan.feesUnknown > 0 then parts[#parts + 1] = "Trainer fees not read." end
    if t.back >= 0.5 then parts[#parts + 1] = ("Sell back %s."):format(M(t.back)) end
    if t.net and t.back >= 0.5 then
        parts[#parts + 1] = t.net >= 0 and ("Net cost %s."):format(M(t.net)) or ("You keep %s."):format(M(-t.net))
    end
    return title, table.concat(parts, " ")
end

function UI.PriceStatus()
    local P = ns.Prices
    if P.IsScanning() then
        local done, total, phase = P.Progress()
        if phase == "sweep" then return "Reading the auction house" end
        return ("Reading prices: %d of %d"):format(done, total)
    end
    local n, age = P.Summary()
    if n == 0 then return "No auction prices yet" end
    return ("Prices: %d %s, scanned %s"):format(n, Plural(n, "item", "items"), ns.Age(age))
end

----------------------------------------------------------------------
-- The path as numbered steps: buy, train, craft, sell
----------------------------------------------------------------------
-- What is left over, with where each unit goes: entries { item, left, sp, value }, and the same
-- entries by destination (an item can be in two: some to the auction house, the rest to a vendor).
local function SellGroups(plan)
    local g = { entries = {}, ah = {}, vendor = {}, none = {}, byItem = {}, back = 0 }
    for _, l in ipairs(plan.leftovers or {}) do
        local sp = ns.Prices.SellPlan(l.item, l.left)
        local e = { item = l.item, left = l.left, sp = sp, value = sp.value }
        g.entries[#g.entries + 1] = e
        g.byItem[l.item] = e
        g.back = g.back + sp.value
        if sp.ah then g.ah[#g.ah + 1] = e end
        if sp.vendor then g.vendor[#g.vendor + 1] = e end
        if sp.none > 0 then g.none[#g.none + 1] = e end
    end
    return g
end

function UI.Steps(plan)
    plan = plan or ns.Plan()
    if plan.view then return plan.view end
    local steps = {}
    if not plan.ok then return steps end
    -- spares: reagents the average run has enough of (your own, or made on the way), where only
    -- the spare for bad luck is left to buy.
    local buy, spares, cost, unpriced, spare, odds = {}, {}, 0, 0, 0, false
    for _, e in ipairs(plan.shopping or {}) do
        if e.buy > 0 then
            buy[#buy + 1] = e
            if e.cost then cost = cost + e.cost else unpriced, cost = unpriced + 1, cost + (e.costListed or 0) end
        elseif e.spare then
            spares[#spares + 1] = e
        end
        if e.spare then
            spare, odds = spare + (e.spareCost or 0), true
        end
    end
    if #buy > 0 or #spares > 0 then
        steps[#steps + 1] = { kind = "buy", key = "buy", entries = buy, spares = spares, cost = cost,
            unpriced = unpriced, spare = spare, odds = odds }
    end
    local sell = SellGroups(plan)
    local seen = {}
    for _, s in ipairs(plan.steps) do
        if s.kind == "craft" then
            -- The key of a step stays the same when a skill point moves where it starts.
            seen[s.r.id] = (seen[s.r.id] or 0) + 1
            steps[#steps + 1] = { kind = "craft", key = ("craft:%s:%d"):format(tostring(s.r.id), seen[s.r.id]),
                step = s, out = Output(plan, s, sell.byItem) }
        elseif s.kind == "train" then
            steps[#steps + 1] = { kind = "train", key = "train:" .. tostring(s.rank or s.at), train = s, at = s.at }
        elseif s.kind == "learn" then
            steps[#steps + 1] = { kind = "learn", key = "learn:" .. tostring(s.r.id), learn = s }
        elseif s.kind == "tool" then
            steps[#steps + 1] = { kind = "tool", key = "tool:" .. tostring(s.item), tool = s }
        elseif s.kind == "gap" then
            steps[#steps + 1] = { kind = "gap", key = "gap", step = s }
        end
    end
    if #sell.entries > 0 then
        steps[#steps + 1] = { kind = "sell", key = "sell", entries = sell.entries, ah = sell.ah, vendor = sell.vendor,
            none = sell.none, back = sell.back }
    end
    for i, s in ipairs(steps) do s.n = i end
    plan.view = steps
    return steps
end

local function StepKey(s) return s.key end
UI.StepKey = StepKey

local function Names(list, name, limit)
    local out = {}
    for i, e in ipairs(list) do
        if i > limit then
            out[#out + 1] = ("%d more"):format(#list - limit)
            break
        end
        out[#out + 1] = name(e)
    end
    return table.concat(out, ", ")
end

-- Under a shopping list with spare on it: what the spare is for.
local SPARE_NOTE = "The amounts are averages: a craft that isn't orange can give no point, so a run often needs more "
    .. ("of something. With the spare bought as well, %s need nothing more."):format(ns.Planner.SPARE_ODDS)
UI.SPARE_NOTE = SPARE_NOTE

-- The recipe a tool is got for ("the next step" when the path doesn't say).
local function ToolFor(t)
    return t.forR and t.forR.name or "the next step"
end

-- Where a craft step's tool comes from.
local TOOL_HOW = {
    held = "Yours: keep it in your bags",
    kept = "Got earlier on the path: keep it in your bags",
    made = "Made right before: keep it in your bags",
    bought = "Bought (on the shopping list): keep it in your bags",
}
UI.TOOL_HOW = TOOL_HOW

local function FeeText(train, M)
    M = M or ns.Money
    local n = #train.learn + #(train.ranks or {})
    if n == 0 then return nil end
    if train.unknown >= n then return "fee not read" end
    if train.unknown > 0 then return M(train.fee) .. " + fees not read" end
    return train.fee >= 0.5 and M(train.fee) or "free"
end

-- A profession rank by the cap it gives.
local RANK_NAME = { [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local function RankName(rank) return RANK_NAME[rank.cap] or "the next rank" end
UI.RankName = RankName

-- "needs level 20" when the rank asks for a level you (or someone else, unknown) may not have.
local function RankNeed(rank, plan)
    local level = rank.level or 0
    if level <= 0 then return nil end
    if not (plan and plan.forOther) and (tonumber(ns.Call(UnitLevel, "player")) or 0) >= level then return nil end
    return ("needs level %d"):format(level)
end

local function RankFee(rank, M)
    if not rank.fee then return "fee not read" end
    return rank.fee >= 0.5 and (M or ns.Money)(rank.fee) or "free"
end

-- "train Expert", "buy and read Expert Cookbook for Expert", "do the quest for Artisan"
local function RankDo(rank)
    if rank.how == "book" then
        return ("buy and read %s for %s"):format(ns.Prices.ItemName(rank.item), RankName(rank))
    elseif rank.how == "quest" then
        return ("do the quest for %s"):format(RankName(rank))
    end
    return "train " .. RankName(rank)
end

-- title, second line, icon, the title's colour, whether the second line is a problem, and the
-- money at the right with its colour ("grey": not paid here, "green": comes back, "red": unknown)
function UI.StepText(s, plan, M)
    M = M or ns.Money
    local r, g, b = Gold()
    if s.kind == "buy" then
        local n = #s.entries
        if n == 0 then
            return "Buy spare reagents", Names(s.spares, function(e) return ns.Prices.ItemName(e.item) end, 3),
                ICON_BUY, r, g, b, false, M(s.spare), "grey"
        end
        local sub = Names(s.entries, function(e) return ns.Prices.ItemName(e.item) end, 3)
        local money, color
        if s.unpriced == 0 then
            money = M(s.cost)
        elseif s.unpriced == n and s.cost < 0.5 then
            money, color = "no prices", "red"
        else
            money, color = ("%s + %d not priced"):format(M(s.cost), s.unpriced), "red"
        end
        return ("Buy %d %s"):format(n, Plural(n, "reagent", "reagents")), sub, ICON_BUY, r, g, b, false, money, color
    elseif s.kind == "craft" then
        local step = s.step
        local title = ("%s%d x %s"):format(Exact(step) and "" or "About ", UI.CraftCount(step), step.name)
        local sub = ("%d to %d. %s%s"):format(step.from, step.to, OutputText(s.out, M), step.stale and ". Old price" or "")
        r, g, b = UI.DifficultyColor(step.r, step.from, plan and plan.ctx and plan.ctx.offset or 0)
        local money = step.priced and (step.cost < 0.5 and "uses your own" or ("uses " .. M(step.cost)))
            or (step.cost >= 0.5 and ("uses " .. M(step.cost) .. " + no price") or "no price")
        return title, sub, step.r.icon, r, g, b, false, money, step.priced and "grey" or "red"
    elseif s.kind == "train" then
        local t = s.train
        local n = #t.learn
        local title
        local rank = t.ranks and t.ranks[#t.ranks]
        if rank and rank.how ~= "trainer" then
            title = RankDo(rank):gsub("^%l", string.upper)
            if n > 0 then title = title .. (", trainer: %d %s"):format(n, Plural(n, "recipe", "recipes")) end
        elseif rank and n > 0 then
            title = ("Trainer: %s, %d %s"):format(RankDo(rank), n, Plural(n, "recipe", "recipes"))
        elseif rank then
            title = "Trainer: " .. RankDo(rank)
        elseif n == 1 then
            title = "Trainer: learn " .. t.learn[1].r.name
        else
            title = ("Trainer: learn %d recipes"):format(n)
        end
        local sub = ("At skill %d"):format(t.at)
        if t.rank then sub = sub .. (". Raises the cap to %d"):format(t.rank) end
        local need = rank and RankNeed(rank, plan)
        if need then sub = sub .. ". " .. need:gsub("^%l", string.upper) end
        if n > 1 or (n == 1 and t.rank) then
            sub = sub .. ". " .. Names(t.learn, function(l) return l.r.name end, 2)
        end
        local money = FeeText(t, M)
        return title, sub, ICON_TRAIN, r, g, b, false, money, t.unknown > 0 and "red" or nil
    elseif s.kind == "learn" then
        local l = s.learn
        return "Learn " .. l.r.name, ("At skill %d, from %s"):format(l.at, ns.Prices.ItemName(l.item)), l.r.icon,
            r, g, b, false, CostText(l.cost, true, M)
    elseif s.kind == "tool" then
        local t = s.tool
        local name = ns.Prices.ItemName(t.item)
        local sub
        if t.how == "make" then
            r, g, b = UI.DifficultyColor(t.r, t.at, plan and plan.ctx and plan.ctx.offset or 0)
            sub = ("At skill %d. Make 1, keep it in your bags: %s needs it"):format(t.at, ToolFor(t))
        else
            sub = ("At skill %d. On the shopping list; keep it in your bags: %s needs it"):format(t.at, ToolFor(t))
        end
        if t.stale then sub = sub .. ". Old price" end
        if t.priced == false then
            local money = t.cost >= 0.5 and ("uses " .. M(t.cost) .. " + no price") or "no price"
            return "Tool: " .. name, sub, ns.Prices.ItemIcon(t.item), r, g, b, false, money, "red"
        end
        local money = t.cost < 0.5 and "uses your own" or ((t.how == "make" and "uses " or "") .. M(t.cost))
        return "Tool: " .. name, sub, ns.Prices.ItemIcon(t.item), r, g, b, false, money, "grey"
    elseif s.kind == "gap" then
        return "Learn a recipe", ("No recipe here gives skill past %d"):format(s.step.from), ICON_GAP, r, g, b, true
    end
    local parts = {}
    local function Count(list, pick, words)
        local n = 0
        for _, e in ipairs(list) do n = n + pick(e.sp) end
        if n > 0 then parts[#parts + 1] = words:format(n) end
    end
    Count(s.ah, function(sp) return sp.ah.n end, "%d at auction")
    Count(s.vendor, function(sp) return sp.vendor.n end, "%d to a vendor")
    Count(s.none, function(sp) return sp.none end, "%d no sale")
    return s.back >= 0.5 and "Sell the rest" or "What is left over", table.concat(parts, ", "), ICON_SELL, r, g, b, false,
        s.back >= 0.5 and ("get " .. M(s.back)) or "nothing", s.back >= 0.5 and "green" or "grey"
end

----------------------------------------------------------------------
-- The written guide: the same path as plain text, to copy or to send
----------------------------------------------------------------------
local function GuideSell(L, title, list, line)
    if #list == 0 then return end
    L[#L + 1] = title
    for _, e in ipairs(list) do L[#L + 1] = "  " .. line(e) end
end

-- Lines of plain text: totals, the shopping list, the numbered steps, what to sell where, notes
-- (brief: without the notes, which are for whoever runs the addon).
function UI.Guide(plan, brief)
    plan = plan or ns.Plan()
    local M = ns.Coins
    local L = {}
    if not plan.ok then
        L[1] = plan.why or "No path yet."
        return L
    end
    local Name = ns.Prices.ItemName
    local steps = UI.Steps(plan)
    local title, line = UI.Summary(plan, M)
    L[#L + 1] = ("%s: leveling plan"):format(title:gsub(", for someone else", ""))
    local n, age = ns.Prices.Summary()
    if n > 0 then
        L[#L + 1] = ("Prices: auction house, scanned %s, and vendors."):format(ns.Age(age))
    else
        L[#L + 1] = "Prices: vendors only (no auction house scan yet)."
    end
    L[#L + 1] = line
    for _, s in ipairs(steps) do
        if s.kind == "buy" then
            L[#L + 1] = "BUY"
            for _, e in ipairs(s.entries) do
                local text = ("  %d x %s: "):format(e.buy, Name(e.item))
                if e.cost then
                    text = text .. M(e.cost) .. (e.from and (", " .. e.from) or "")
                    if e.spare then
                        text = text .. ("; plus %d spare%s"):format(e.spare,
                            e.spareCost and (": +" .. M(e.spareCost)) or ": not that many listed")
                    end
                elseif e.short then
                    text = text .. ("%d listed for %s, %d more not listed"):format(e.listed, M(e.costListed or 0), e.short)
                else
                    text = text .. "no price (" .. (e.missing or "not scanned yet") .. ")"
                end
                if e.spare and not e.cost then text = text .. ("; plus %d spare"):format(e.spare) end
                L[#L + 1] = text
            end
            for _, e in ipairs(s.spares) do
                L[#L + 1] = ("  %s: the average run has enough; %d spare%s"):format(Name(e.item), e.spare,
                    e.spareCost and (": +" .. M(e.spareCost)) or "")
            end
            if s.odds then L[#L + 1] = "  " .. SPARE_NOTE end
        end
    end
    L[#L + 1] = "STEPS"
    for _, s in ipairs(steps) do
        local text
        if s.kind == "buy" then
            text = "Buy everything on the list above."
        elseif s.kind == "craft" then
            local step = s.step
            local uses = {}
            for _, slot in ipairs(step.r.slots or {}) do
                for _, item in ipairs(slot.items) do
                    local u = step.uses[item]
                    if u then uses[#uses + 1] = ("%d %s"):format(Units(u.n), Name(item)) end
                end
            end
            text = ("%d to %d: %s%d x %s. Uses %s. %s."):format(step.from, step.to, Exact(step) and "" or "about ",
                UI.CraftCount(step), step.name, table.concat(uses, ", "), OutputText(s.out, M))
            local subs = {}
            for _, sub in pairs(step.subs) do subs[#subs + 1] = sub end
            table.sort(subs, function(a, b) return a.r.id < b.r.id end)
            for _, sub in ipairs(subs) do
                -- The recipe is named only when it says more than "74 Bolt of Linen Cloth" did.
                if sub.r.name == Name(sub.item) and Units(sub.crafts) == Units(sub.n) then
                    text = text .. (" Make %d %s first."):format(Units(sub.n), Name(sub.item))
                else
                    text = text .. (" Make %d %s first (%d x %s)."):format(Units(sub.n), Name(sub.item),
                        Units(sub.crafts), sub.r.name)
                end
            end
        elseif s.kind == "train" then
            local t = s.train
            local parts = {}
            local trainer = #t.learn > 0
            for _, rank in ipairs(t.ranks or {}) do
                local need = RankNeed(rank, plan)
                parts[#parts + 1] = ("%s (cap %d, %s%s)"):format(RankDo(rank), rank.cap, RankFee(rank, M),
                    need and (", " .. need) or "")
                if rank.how == "trainer" then trainer = true end
            end
            for _, l in ipairs(t.learn) do
                parts[#parts + 1] = ("learn %s (%s)"):format(l.r.name, l.unknown and "fee not read" or CostText(l.fee, true, M))
            end
            text = ("%s skill %d: %s."):format(trainer and "Trainer at" or "At", t.at, table.concat(parts, "; "))
        elseif s.kind == "learn" then
            local l = s.learn
            text = ("At skill %d: learn %s from %s (%s)."):format(l.at, l.r.name, Name(l.item), CostText(l.cost, true, M))
        elseif s.kind == "tool" then
            local t = s.tool
            if t.how == "make" then
                local uses = {}
                for _, slot in ipairs(t.r.slots or {}) do
                    for _, item in ipairs(slot.items) do
                        local u = t.uses[item]
                        if u then uses[#uses + 1] = ("%d %s"):format(Units(u.n), Name(item)) end
                    end
                end
                text = ("At skill %d: make 1 %s (uses %s). Keep it in your bags: %s needs it, and crafting doesn't "
                    .. "use it up."):format(t.at, Name(t.item), table.concat(uses, ", "), ToolFor(t))
            else
                text = ("At skill %d: have the %s from the list above in your bags. %s needs it, and crafting doesn't "
                    .. "use it up."):format(t.at, Name(t.item), ToolFor(t))
            end
        elseif s.kind == "gap" then
            text = ("Stops at %d: no recipe here gives skill past it."):format(s.step.from) .. UI.GapWait(s.step, " ")
        else
            text = s.back >= 0.5 and "Sell the rest, as listed below." or "Nothing left over sells (listed below)."
        end
        L[#L + 1] = ("  %d. %s"):format(s.n, text)
    end
    for _, s in ipairs(steps) do
        if s.kind == "sell" then
            L[#L + 1] = s.back >= 0.5 and ("SELL (about %s back)"):format(M(s.back)) or "LEFT OVER"
            GuideSell(L, " Auction house:", s.ah, function(e)
                local res = e.sp.res
                return ("%d x %s at %s each after the cut (cheapest listed %s, about %s a day sell)"):format(e.sp.ah.n,
                    Name(e.item), M(e.sp.ah.each), M(res.lowest or 0), ns.Crafts(res.perDay or 0))
            end)
            GuideSell(L, " Vendor:", s.vendor, function(e)
                return ("%d x %s at %s each%s"):format(e.sp.vendor.n, Name(e.item), M(e.sp.vendor.each),
                    e.sp.why and (" (auction house: " .. e.sp.why .. ")") or "")
            end)
            GuideSell(L, " No sale:", s.none, function(e)
                return ("%d x %s (%s)"):format(e.sp.none, Name(e.item), NoSaleText(e.sp))
            end)
        end
    end
    if #plan.notes > 0 and not brief then
        L[#L + 1] = "NOTES"
        for _, note in ipairs(plan.notes) do L[#L + 1] = "  " .. note end
    end
    return L
end

----------------------------------------------------------------------
-- Tooltips
----------------------------------------------------------------------
local function OwnsTooltip(row)
    return GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row)
end

local function ItemTip(tip, item)
    if not pcall(tip.SetItemByID, tip, item) then tip:SetText(ns.Prices.ItemName(item)) end
    tip:AddLine(" ")
end

local function ShopTip(tip, e, plan)
    ItemTip(tip, e.item)
    local wr, wg, wb = White()
    local gr, gg, gb = Grey()
    local text = ("Need %d."):format(Units(e.need))
    if not (plan and plan.forOther) then text = text .. (" You have %d."):format(e.have) end
    if e.made > 0.05 then text = text .. (" Earlier steps make %d."):format(Units(e.made)) end
    tip:AddLine(text, wr, wg, wb, true)
    if e.spare then
        tip:AddLine(("%d spare for bad luck%s. With every spare bought, %s need nothing more."):format(e.spare,
            e.spareCost and (": " .. ns.Money(e.spareCost) .. " more") or e.cost and ": not that many are listed" or "",
            ns.Planner.SPARE_ODDS), wr, wg, wb, true)
    end
    tip:AddLine(UI.SourceText(e.item, plan), gr, gg, gb, true)
end

-- What one leftover goes for, and what that rests on.
function UI.SellLines(e)
    local sp = e.sp or ns.Prices.SellPlan(e.item, e.left)
    local res = sp.res
    local lines = {}
    if sp.ah then
        lines[#lines + 1] = ("Auction house: %d at %s each after the 5%% cut (cheapest listed %s, %s)."):format(sp.ah.n,
            ns.Money(sp.ah.each), ns.Money(res.lowest), ns.Age(res.age))
        lines[#lines + 1] = ("About %s a day %s (seen over %.0f h). %d listed now."):format(ns.Crafts(res.perDay),
            res.perDay == 1 and "sells" or "sell", res.hours, res.listed or 0)
        if res.stale then lines[#lines + 1] = "Old price: scan again." end
    elseif res.why then
        lines[#lines + 1] = "Auction house: no, " .. res.why .. "."
    end
    if sp.vendor then
        lines[#lines + 1] = ("Vendor: %d at %s each."):format(sp.vendor.n, ns.Money(sp.vendor.each))
    elseif not ns.db.sellVendor then
        lines[#lines + 1] = "Vendor sales are off in the options."
    elseif res.sell == nil then
        lines[#lines + 1] = "Vendor price not loaded yet."
    elseif res.sell == 0 then
        lines[#lines + 1] = "No vendor buys it."
    end
    return lines
end

local function SellTip(tip, e)
    ItemTip(tip, e.item)
    local wr, wg, wb = White()
    local gr, gg, gb = Grey()
    tip:AddLine(("%d left after your crafts: %s."):format(e.left, e.value >= 0.5 and ns.Money(e.value) or "no sale"),
        wr, wg, wb, true)
    for _, line in ipairs(UI.SellLines(e)) do tip:AddLine(line, gr, gg, gb, true) end
end

local function OptionTip(tip, o)
    local r = o.r
    tip:SetText(r.name, Gold())
    local wr, wg, wb = White()
    local gr, gg, gb = Grey()
    if o.covers > 0 then
        tip:AddLine(("Gives %d more skill %s."):format(o.covers, Plural(o.covers, "point", "points")), wr, wg, wb, true)
    end
    if o.saving >= 1 then
        tip:AddLine(("Saves about %s from %d to %d (before what the recipe costs)."):format(
            ns.Money(o.saving), o.from, o.to), wr, wg, wb, true)
    end
    tip:AddLine(("Orange below %d, grey from %d."):format(r.y, r.g), gr, gg, gb)
    if o.learnAt and o.learnAt > 0 then tip:AddLine(("Needs skill %d to learn."):format(o.learnAt), gr, gg, gb) end
    if o.item then tip:AddLine("Taught by " .. ns.Prices.ItemName(o.item) .. ".", gr, gg, gb, true) end
    if o.why then tip:AddLine("Not in the path: " .. o.why .. ".", gr, gg, gb, true) end
    if o.source then tip:AddLine(o.source, gr, gg, gb, true) end
    tip:AddLine(" ")
    for _, slot in ipairs(r.slots or {}) do
        for i, item in ipairs(slot.items) do
            tip:AddLine(("%s%d x %s"):format(i > 1 and "or " or "", slot.qty, ns.Prices.ItemName(item)), wr, wg, wb)
        end
    end
end

local function ReagentTip(tip, item, plan)
    ItemTip(tip, item)
    local gr, gg, gb = Grey()
    tip:AddLine(UI.SourceText(item, plan), gr, gg, gb, true)
end

-- A step's row: the whole title (the row cuts it off), and what its money means.
function UI.StepTip(tip, s, plan)
    local title, sub, _, r, g, b, _, money = UI.StepText(s, plan)
    tip:SetText(title, r, g, b)
    local wr, wg, wb = White()
    local gr, gg, gb = Grey()
    if sub and sub ~= "" then tip:AddLine(sub, wr, wg, wb, true) end
    if s.kind == "buy" then
        tip:AddLine(("Pay %s."):format(money), wr, wg, wb, true)
        tip:AddLine("Everything the path takes from outside, in whole units. The \"uses\" amounts on the craft "
            .. "steps are part of this, not on top of it.", gr, gg, gb, true)
        if s.odds then
            tip:AddLine(("Spare for bad luck: %s more. With it, %s need nothing more."):format(ns.Money(s.spare),
                ns.Planner.SPARE_ODDS), gr, gg, gb, true)
        end
    elseif s.kind == "craft" then
        tip:AddLine(("Reagents: %s."):format(money), wr, wg, wb, true)
        tip:AddLine("What the reagents this step takes are worth. They are on the shopping list already, so "
            .. "nothing is paid here.", gr, gg, gb, true)
    elseif s.kind == "train" then
        for _, rank in ipairs(s.train.ranks or {}) do
            tip:AddDoubleLine(RankName(rank) .. " rank", RankFee(rank), wr, wg, wb, wr, wg, wb)
        end
        for _, l in ipairs(s.train.learn) do
            tip:AddDoubleLine(l.r.name, l.unknown and "fee not read" or CostText(l.fee, true), wr, wg, wb, wr, wg, wb)
        end
    elseif s.kind == "tool" then
        tip:AddLine("A tool stays in your bags while you craft: crafting doesn't use it up. Its cost is on the "
            .. "shopping list already.", gr, gg, gb, true)
    elseif s.kind == "sell" then
        tip:AddLine("What the path made and didn't use, and where each piece sells.", gr, gg, gb, true)
    end
end

function UI.ShowTooltip(row)
    local e = row.element
    if not (e and e.tip and GameTooltip) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    e.tip(GameTooltip)
    if e.hint then GameTooltip:AddLine(e.hint, Green()) end
    GameTooltip:Show()
    UI.tooltipRow = row
end

----------------------------------------------------------------------
-- Cards for items and recipes
----------------------------------------------------------------------
local function ItemLink(item)
    return function() return (select(2, ns.Call(C_Item and C_Item.GetItemInfo, item))) end
end

local function RecipeLink(id)
    return function()
        local T = C_TradeSkillUI
        return T and ns.Str(ns.Call(T.GetRecipeLink, id))
    end
end

-- click: what a click on the card does (nil: nothing); hint: the tooltip's last line saying so.
function UI.ShopCard(e, click, hint, plan)
    local sub, bad, money, color
    if e.buy == 0 and e.spare then
        -- Only spare is left to buy.
        return { kind = "card", icon = ns.Prices.ItemIcon(e.item), count = e.spare,
            title = ("%d x %s"):format(e.spare, ns.Prices.ItemName(e.item)),
            sub = "Spare only: the average run has enough" .. (e.from and (", " .. e.from) or ""),
            money = e.spareCost and ns.Money(e.spareCost) or nil, moneyColor = "grey", link = ItemLink(e.item),
            tip = function(tip) ShopTip(tip, e, plan) end, click = click, hint = hint, entry = e, what = "shop" }
    end
    if e.cost then
        sub = e.from or ""
        if e.spare then sub = sub .. ("%s+%d spare"):format(sub ~= "" and ", " or "", e.spare) end
        if e.stale then sub = sub .. ", old price" end
        money = ns.Money(e.cost)
    elseif e.short then
        sub, bad = ("Only %d listed. %d more not on the auction house"):format(e.listed, e.short), true
        money, color = e.costListed and ns.Money(e.costListed) or nil, "red"
    else
        sub, bad = "No price: " .. (e.missing or "not scanned yet"), true
    end
    return { kind = "card", icon = ns.Prices.ItemIcon(e.item), count = e.buy,
        title = ("%d x %s"):format(e.buy, ns.Prices.ItemName(e.item)),
        sub = sub, bad = bad, money = money, moneyColor = color, link = ItemLink(e.item),
        tip = function(tip) ShopTip(tip, e, plan) end, click = click, hint = hint, entry = e, what = "shop" }
end

-- where: "ah", "vendor" or "none": the part of the leftover that goes there.
function UI.SellCard(e, where, click, hint)
    local sp = e.sp
    local count, sub, money, color
    if where == "ah" then
        count = sp.ah.n
        sub = ("%s each, about %s a day %s"):format(ns.Money(sp.ah.each), ns.Crafts(sp.res.perDay or 0),
            sp.res.perDay == 1 and "sells" or "sell")
        money, color = ns.Money(sp.ah.n * sp.ah.each), "green"
    elseif where == "vendor" then
        count = sp.vendor.n
        sub = ("%s each"):format(ns.Money(sp.vendor.each))
        if sp.why then sub = sub .. ". Auction: " .. sp.why end
        money, color = ns.Money(sp.vendor.n * sp.vendor.each), "green"
    else
        count = sp.none
        sub = NoSaleText(sp)
        sub = sub:sub(1, 1):upper() .. sub:sub(2)
    end
    return { kind = "card", icon = ns.Prices.ItemIcon(e.item), count = count,
        title = ("%d x %s"):format(count, ns.Prices.ItemName(e.item)),
        sub = sub, money = money, moneyColor = color, link = ItemLink(e.item), tip = function(tip) SellTip(tip, e) end,
        click = click, hint = hint, entry = e, where = where, what = "sell" }
end

-- The sell step's rows: by where each piece goes.
function UI.SellRows(s, click, hint)
    local els = {}
    local function Group(title, list, where)
        if #list == 0 then return end
        els[#els + 1] = { kind = "head", text = title }
        for _, e in ipairs(list) do
            els[#els + 1] = UI.SellCard(e, where, click and function() click(e) end, hint)
        end
    end
    Group("Auction house", s.ah, "ah")
    Group("Vendor", s.vendor, "vendor")
    Group("No sale", s.none, "none")
    return els
end

function UI.OptionCard(o)
    local sub
    if o.covers > 0 then
        sub = ("%d more %s, to %d"):format(o.covers, o.covers == 1 and "point" or "points", o.to)
    else
        sub = ("Saves about %s"):format(ns.Money(o.saving))
    end
    if o.item then
        sub = sub .. ". Recipe item"
    elseif o.learnAt and o.learnAt > 0 then
        sub = sub .. (". Needs skill %d"):format(o.learnAt)
    end
    local r, g, b = Grey()
    return { kind = "card", icon = o.r.icon, desaturate = true, dim = true, title = o.r.name, color = { r, g, b },
        sub = sub, link = RecipeLink(o.r.id), tip = function(tip) OptionTip(tip, o) end, option = o, what = "option" }
end

-- One line per point; a run of orange points is one line.
function UI.PointLines(step)
    local out, pts, i = {}, step.points, 1
    while i <= #pts do
        local p = pts[i]
        if p.orange then
            local j, cost, priced = i, p.known or 0, p.priced
            while pts[j + 1] and pts[j + 1].orange and pts[j + 1].gain == p.gain do
                j = j + 1
                cost, priced = cost + (pts[j].known or 0), priced and pts[j].priced
            end
            out[#out + 1] = { kind = "line", left = ("%d to %d: orange, %s every craft"):format(p.s, pts[j].to,
                p.gain > 1 and (p.gain .. " points") or "a point"), right = CostText(cost, priced) }
            i = j + 1
        else
            local crafts = ns.Crafts(p.crafts)
            out[#out + 1] = { kind = "line", left = ("%d: %d%% chance, about %s %s"):format(p.s,
                math.floor(p.chance * 100 + 0.5), crafts, crafts == "1" and "craft" or "crafts"),
                right = CostText(p.known or 0, p.priced) }
            i = i + 1
        end
    end
    return out
end

----------------------------------------------------------------------
-- A scrolling list of cards, lines, headers and notes
----------------------------------------------------------------------
local function NewItemButton(parent)
    local ok, item = pcall(CreateFrame, "ItemButton", nil, parent)
    if not ok or type(item) ~= "table" then item = CreateFrame("Button", nil, parent, "ItemButtonTemplate") end
    item:SetSize(37, 37)
    item:EnableMouse(false)
    return item
end

local function SetIcon(item, icon, count, desaturate)
    if SetItemButtonTexture then SetItemButtonTexture(item, icon) elseif item.icon then item.icon:SetTexture(icon) end
    count = count or 0
    if SetItemButtonCount then
        SetItemButtonCount(item, count)
    elseif item.Count then
        item.Count:SetText(count > 1 and tostring(count) or "")
    end
    if SetItemButtonDesaturated then pcall(SetItemButtonDesaturated, item, desaturate and true or false) end
end

local function MoneyColor(name)
    if name == "grey" then return Grey() end
    if name == "green" then return Green() end
    if name == "red" then return Red() end
    return White()
end

local function BuildRow(row)
    row:EnableMouse(true)

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetAllPoints()
    Art(row.Background, "looting_itemcard_bg", "Interface\\QuestFrame\\UI-QuestItemNameFrame")
    row.Border = row:CreateTexture(nil, "BORDER")
    row.Border:SetAllPoints()
    row.hasBorder = Art(row.Border, "looting_itemcard_stroke_normal")
    row.Selected = row:CreateTexture(nil, "ARTWORK")
    row.Selected:SetAllPoints()
    Art(row.Selected, "looting_itemcard_stroke_clickstate", "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Selected:SetBlendMode("ADD")
    row.Highlight = row:CreateTexture(nil, "OVERLAY")
    row.Highlight:SetAllPoints()
    Art(row.Highlight, "looting_itemcard_stroke_clickstate", "Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row.Highlight:SetBlendMode("ADD")
    row.Highlight:SetAlpha(0.5)
    row.Highlight:Hide()

    -- A card: step number (the step list only), icon, two lines, and the money at the right of the first.
    row.Num = row:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    row.Num:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.Num:SetWidth(24)
    row.Num:SetJustifyH("CENTER")
    row.Item = NewItemButton(row)
    row.Money = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Money:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
    row.Money:SetJustifyH("RIGHT")
    row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Text:SetPoint("TOPLEFT", row.Item, "TOPRIGHT", 8, -3)
    row.Text:SetPoint("RIGHT", row.Money, "LEFT", -6, 0)
    row.Text:SetJustifyH("LEFT")
    row.Text:SetWordWrap(false)
    row.Sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Sub:SetPoint("TOPLEFT", row.Text, "BOTTOMLEFT", 0, -3)
    row.Sub:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Sub:SetJustifyH("LEFT")
    row.Sub:SetWordWrap(false)

    -- A line: text on the left, a cost on the right.
    row.Right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Right:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Right:SetJustifyH("RIGHT")
    row.Line = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Line:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.Line:SetPoint("RIGHT", row.Right, "LEFT", -8, 0)
    row.Line:SetJustifyH("LEFT")
    row.Line:SetWordWrap(false)

    -- A header, and a note that wraps.
    row.Title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.Title:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 5)
    row.Title:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(false)
    row.Note = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Note:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.Note:SetJustifyH("LEFT")
    row.Note:SetJustifyV("TOP")
    row.Note:SetWordWrap(true)

    row:SetScript("OnEnter", function(self)
        local e = self.element
        if e and e.click then self.Highlight:Show() end
        UI.ShowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        if OwnsTooltip(self) then GameTooltip:Hide() end
        self.Highlight:Hide()
    end)
    row:SetScript("OnMouseUp", function(self, button)
        local e = self.element
        if not e then return end
        if IsModifiedClick and IsModifiedClick() then
            local link = e.link and e.link()
            if link and HandleModifiedItemClick then HandleModifiedItemClick(link) end
            return
        end
        if e.click then e.click(button) end
    end)
end

local function InitRow(row, e, width)
    row.element = e
    local card = e.kind == "card"
    row.Background:SetShown(card)
    row.Border:SetShown(card and row.hasBorder)
    row.Selected:SetShown(card and e.selected and true or false)
    row.Highlight:Hide()
    row.Num:SetShown(card and e.n ~= nil)
    row.Item:SetShown(card)
    row.Text:SetShown(card)
    row.Sub:SetShown(card)
    row.Money:SetShown(card)
    row.Line:SetShown(e.kind == "line")
    row.Right:SetShown(e.kind == "line")
    row.Title:SetShown(e.kind == "head")
    row.Note:SetShown(e.kind == "text")
    if card then
        row.Item:ClearAllPoints()
        row.Item:SetPoint("TOPLEFT", row, "TOPLEFT", e.n and 32 or 5, -4)
        row.Num:SetText(e.n and tostring(e.n) or "")
        SetIcon(row.Item, e.icon, e.count, e.desaturate)
        row.Text:SetText(e.title)
        if e.color then row.Text:SetTextColor(e.color[1], e.color[2], e.color[3]) else row.Text:SetTextColor(White()) end
        row.Sub:SetText(e.sub or "")
        if e.bad then row.Sub:SetTextColor(Red()) else row.Sub:SetTextColor(White()) end
        row.Money:SetText(e.money or "")
        row.Money:SetTextColor(MoneyColor(e.moneyColor))
        local shade = e.dim and 0.6 or 1
        row.Background:SetVertexColor(shade, shade, shade)
    elseif e.kind == "line" then
        row.Line:SetText(e.left)
        row.Right:SetText(e.right or "")
        row.Right:SetTextColor(MoneyColor(e.rightColor))
    elseif e.kind == "head" then
        row.Title:SetText(e.text)
    elseif e.kind == "text" then
        row.Note:SetWidth(math.max(40, width - 16))
        row.Note:SetText(e.text)
        if e.bad then row.Note:SetTextColor(Red()) else row.Note:SetTextColor(White()) end
    end
    if OwnsTooltip(row) then
        if e.tip then UI.ShowTooltip(row) else GameTooltip:Hide() end
    end
end

local function Extent(row, e)
    if e.kind == "card" then return CARD end
    if e.kind == "line" then return LINE end
    if e.kind == "head" then return HEAD end
    local h = Num(row.Note:GetStringHeight())
    if not h or h < 10 then h = 12 end
    return h + 8
end

-- parent: the frame the list fills. name: the scroll frame's name on a client without ScrollFrameTemplate.
function UI.NewList(parent, name)
    local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, parent, "ScrollFrameTemplate")
    if not (ok and type(scroll) == "table") then
        scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    end
    -- The template hangs its scroll bar outside the scroll frame, on the right.
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -PAD)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, PAD)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(300, CARD)
    scroll:SetScrollChild(child)

    local list = { scroll = scroll, child = child, rows = {}, elements = {} }
    -- top: back to the first row (what the list shows changed, not just its numbers).
    function list:Set(elements, top)
        self.elements = elements
        local width = Num(scroll:GetWidth())
        if not width or width < 60 then width = 300 end
        self.width = width
        child:SetWidth(width)
        local y = 0
        for i, e in ipairs(elements) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, child)
                BuildRow(row)
                self.rows[i] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
            InitRow(row, e, width)
            local h = Extent(row, e)
            row:SetHeight(h)
            row:Show()
            y = y + h + GAP
        end
        for i = #elements + 1, #self.rows do
            self.rows[i].element = nil
            self.rows[i]:Hide()
        end
        child:SetHeight(math.max(y, CARD))
        if top then
            self.tops = (self.tops or 0) + 1
            if type(scroll.SetVerticalScroll) == "function" then pcall(scroll.SetVerticalScroll, scroll, 0) end
        end
    end
    -- The rows on screen.
    function list:Shown()
        local out = {}
        for _, row in ipairs(self.rows) do
            if row:IsShown() then out[#out + 1] = row end
        end
        return out
    end
    -- The professions window is wider with an addon page open than without.
    scroll:HookScript("OnSizeChanged", function(_, width)
        width = Num(width)
        if width and width >= 60 and math.abs(width - (list.width or 0)) > 1 then list:Set(list.elements) end
    end)
    return list
end

local function NewInset(parent)
    local ok, inset = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
    if ok and type(inset) == "table" then return inset end
    return CreateFrame("Frame", nil, parent)
end

local function AddNotes(elements, plan)
    if #(plan.notes or {}) == 0 then return end
    elements[#elements + 1] = { kind = "head", text = "Notes" }
    for _, note in ipairs(plan.notes) do elements[#elements + 1] = { kind = "text", text = note } end
end

-- No path: why, and the other thing the page can do.
local function EmptyRows(plan)
    local els = { { kind = "text", text = plan.why or "No path yet." } }
    if not plan.forOther then
        els[#els + 1] = { kind = "text",
            text = "A plan for someone else: the button above, or /skillpath for <profession> <from> <to>." }
    end
    return els
end

----------------------------------------------------------------------
-- A plan for someone else: the popup that asks for it
----------------------------------------------------------------------
local ORDER_POPUP = "SKILLPATH_ORDER"

local function PopupBox(dialog)
    if type(dialog) ~= "table" then return nil end
    local ok, box = pcall(function() return dialog:GetEditBox() end)
    if ok and type(box) == "table" then return box end
    for _, key in ipairs({ "EditBox", "editBox" }) do
        if type(dialog[key]) == "table" then return dialog[key] end
    end
end

-- The order as you would type it: "Engineering 75 225".
function UI.OrderText()
    local order = ns.Order()
    if not order then return UI.lastOrder or "Engineering 75 225" end
    return ("%s %d %d"):format(ns.Data and ns.Data.NAMES[order.line] or "", order.from, order.to)
end

function UI.AcceptOrder(text)
    text = ns.Str(text)
    if not text then return false end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    UI.lastOrder = text
    return ns.For(text)
end

if type(StaticPopupDialogs) == "table" then
    -- Only the entry: the game's table itself is never written.
    StaticPopupDialogs[ORDER_POPUP] = {
        text = "Plan for someone else.\nProfession, their skill now, the skill they want:",
        button1 = ACCEPT or "Accept",
        button2 = CANCEL or "Cancel",
        hasEditBox = true,
        editBoxWidth = 220,
        maxLetters = 48,
        OnShow = function(self)
            local box = PopupBox(self)
            if not box then return end
            box:SetText(UI.OrderText())
            box:HighlightText()
        end,
        OnAccept = function(self)
            local box = PopupBox(self)
            if box then UI.AcceptOrder(box:GetText()) end
        end,
        EditBoxOnEnterPressed = function(self)
            UI.AcceptOrder(self:GetText())
            if StaticPopup_Hide then StaticPopup_Hide(ORDER_POPUP) end
        end,
        EditBoxOnEscapePressed = function()
            if StaticPopup_Hide then StaticPopup_Hide(ORDER_POPUP) end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function UI.AskOrder()
    if StaticPopup_Show and type(StaticPopupDialogs) == "table" and StaticPopupDialogs[ORDER_POPUP] then
        StaticPopup_Show(ORDER_POPUP)
    else
        ns.Print("/skillpath for <profession> <from> <to>, like /skillpath for engineering 75 225.")
    end
end

----------------------------------------------------------------------
-- The written guide: a window with the text to copy
----------------------------------------------------------------------
local guide = {}
UI.guide = guide

local function FromTemplate(kind, parent, template, name)
    local ok, f = pcall(CreateFrame, kind, name, parent, template)
    if ok and type(f) == "table" then return f end
end

-- The game's multi-line edit box (InputScrollFrameTemplate), or a plain one in a scroll frame.
local function TextBox(parent)
    local sf = FromTemplate("ScrollFrame", parent, "InputScrollFrameTemplate", "SkillPathGuideScroll")
    if sf and type(sf.EditBox) == "table" then
        if sf.EditBox.SetMaxLetters then sf.EditBox:SetMaxLetters(0) end
        if type(sf.CharCount) == "table" then sf.CharCount:Hide() end
        return sf, sf.EditBox
    end
    local scroll = FromTemplate("ScrollFrame", parent, "ScrollFrameTemplate")
        or CreateFrame("ScrollFrame", "SkillPathGuideScroll2", parent, "UIPanelScrollFrameTemplate")
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlightSmall)
    scroll:SetScrollChild(box)
    return scroll, box
end

local GUIDE_HINT = "Ctrl+C copies the selected text. /skillpath send <player> whispers it."

local function BuildGuide()
    local f = FromTemplate("Frame", UIParent, "BasicFrameTemplateWithInset", "SkillPathGuideFrame")
        or CreateFrame("Frame", "SkillPathGuideFrame", UIParent)
    f:SetSize(560, 460)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    -- Esc closes it. Only an entry is added: the game's list itself is never written.
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, "SkillPathGuideFrame") end

    f.Hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.Hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    f.Hint:SetPoint("RIGHT", f, "RIGHT", -120, 0)
    f.Hint:SetJustifyH("LEFT")
    f.Hint:SetText(GUIDE_HINT)
    f.Select = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.Select:SetSize(100, 22)
    f.Select:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 6)
    f.Select:SetText("Select all")
    -- There while a plan being sent goes out on your clicks (see ns.Send).
    f.Next = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.Next:SetSize(150, 22)
    f.Next:SetPoint("RIGHT", f.Select, "LEFT", -6, 0)
    f.Next:SetText("Send next")
    f.Next:SetScript("OnClick", function() ns.SendNext() end)
    f.Next:Hide()

    local holder, box = TextBox(f)
    holder:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -32)
    holder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 36)
    box:SetWidth(500)
    -- The text is the plan's: typing in it puts it back.
    box:SetScript("OnTextChanged", function(self, user)
        if user and guide.text then
            self:SetText(guide.text)
            self:HighlightText()
        end
    end)
    box:SetScript("OnEscapePressed", function() f:Hide() end)
    f.Select:SetScript("OnClick", function()
        box:SetFocus()
        box:HighlightText()
    end)
    guide.frame, guide.box = f, box
end

local function SetGuide(plan)
    local title = UI.Summary(plan, ns.Coins)
    local text = table.concat(UI.Guide(plan), "\n")
    local f = guide.frame
    if type(f.SetTitle) == "function" then
        pcall(f.SetTitle, f, title)
    elseif type(f.TitleText) == "table" then
        f.TitleText:SetText(title)
    end
    guide.title = title
    if text ~= guide.text then
        guide.text = text
        guide.box:SetText(text)
    end
end

-- /skillpath guide and the Copy guide buttons.
function UI.ShowGuide()
    local plan = ns.Plan()
    if not plan.ok then
        ns.Print(plan.why or "No path yet.")
        return false
    end
    if not guide.frame then
        local ok, err = pcall(BuildGuide)
        if not ok then
            guide.frame, guide.error = nil, tostring(err)
            ns.Print("The guide window didn't open (" .. guide.error .. "). /skillpath print puts it in chat.")
            return false
        end
    end
    SetGuide(plan)
    guide.frame:Show()
    guide.box:SetFocus()
    guide.box:HighlightText()
    UI.SendChanged()
    return true
end

-- The guide window's "Send next" button: there while the plan being sent goes out on your clicks,
-- and ready once the last lines have come back. With open, the window is brought up for it.
-- Returns whether the button is there to click.
function UI.SendChanged(open)
    local state = ns.SendState()
    local click = state and state.click
    if open and click and state.ask and not UI.GuideShown() then UI.ShowGuide() end
    local f = guide.frame
    if not (f and f.Next) then return false end
    f.Hint:ClearAllPoints()
    f.Hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
    if click then
        f.Next:SetText(("Send next (%d/%d)"):format(state.sent, state.total))
        f.Next:SetEnabled(state.ask)
        f.Next:Show()
        f.Hint:SetPoint("RIGHT", f.Next, "LEFT", -8, 0)
        f.Hint:SetText("The game sends chat only on your own click.")
    else
        f.Next:Hide()
        f.Hint:SetPoint("RIGHT", f, "RIGHT", -120, 0)
        f.Hint:SetText(GUIDE_HINT)
    end
    return click and UI.GuideShown() or false
end

-- Where the path stops for want of a recipe: the trainer recipe that may be taught there already.
function UI.GapWait(step, lead)
    local wait = step.wait
    if not wait then return "" end
    return lead .. ("A trainer may teach %s by then (by skill %d at the latest): the trainer's list hasn't been read.")
        :format(wait.r.name, wait.at)
end

-- How many names in the written guide the game hasn't loaded yet: they read "item 1234" or
-- "recipe 1234" until it has.
function UI.Unnamed(lines)
    local n = 0
    for _, line in ipairs(lines) do
        for _ in line:gmatch("%f[%a]item %d+") do n = n + 1 end
        for _ in line:gmatch("%f[%a]recipe %d+") do n = n + 1 end
    end
    return n
end

function UI.GuideShown()
    return guide.frame ~= nil and guide.frame:IsShown() and true or false
end

----------------------------------------------------------------------
-- The head of both pages: the path and its cost, the prices, the buttons
----------------------------------------------------------------------
local function HeadButton(page, text, width, tip, click)
    local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", click)
    b:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(text, Gold())
        GameTooltip:AddLine(tip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        if OwnsTooltip(self) then GameTooltip:Hide() end
    end)
    return b
end

-- top: where the first row starts under the page's top; scan: the auction page's button.
local function BuildHead(page, top, scan)
    -- To the right of the window's portrait.
    page.Title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    page.Title:SetPoint("TOPLEFT", page, "TOPLEFT", 66, -top - 4)
    local x = -10
    local function Place(b, width)
        b:SetPoint("TOPRIGHT", page, "TOPRIGHT", x, -top)
        x = x - width - 4
        return b
    end
    if scan then
        page.Scan = Place(HeadButton(page, "Scan prices", 100,
            "Reads the auction prices of every reagent, one search at a time.",
            function() ns.Prices.StartScan(true) end), 100)
    end
    page.Copy = Place(HeadButton(page, "Copy guide", 96,
        "The path as text: what to buy, each step, what to sell where. To copy, or to whisper with "
            .. "/skillpath send <player>.", function() UI.ShowGuide() end), 96)
    page.Order = Place(HeadButton(page, "Plan for someone", 130,
        "A path for another player: a profession, the skill they have and the skill they want. It starts "
            .. "with no recipe known and nothing in the bags, at today's prices.", function() UI.AskOrder() end), 130)
    page.Mine = Place(HeadButton(page, "My path", 76, "Back to the path of your own profession.",
        function() ns.SetOrder(nil) end), 76)
    page.Title:SetPoint("RIGHT", page.Mine, "LEFT", -8, 0)
    page.Title:SetJustifyH("LEFT")
    page.Title:SetWordWrap(false)

    page.Prices = page:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    page.Prices:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -top - 29)
    page.Cost = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    page.Cost:SetPoint("TOPLEFT", page.Title, "BOTTOMLEFT", 0, -6)
    page.Cost:SetPoint("RIGHT", page.Prices, "LEFT", -10, 0)
    page.Cost:SetJustifyH("LEFT")
    page.Cost:SetWordWrap(false)
end

local function UpdateHead(page, plan)
    local title, line = UI.Summary(plan)
    page.Title:SetText(title)
    page.Cost:SetText(line)
    page.Prices:SetText(UI.PriceStatus())
    page.Mine:SetShown(ns.Order() ~= nil)
    page.Copy:SetEnabled(plan.ok and true or false)
    if type(page.Scan) == "table" then page.Scan:SetEnabled(not ns.Prices.IsScanning()) end
end

----------------------------------------------------------------------
-- Professions window: the page
----------------------------------------------------------------------
local trade = { hidden = {} }
UI.trade = trade

local function TradeFrame()
    local book = _G.ProfessionsFrame
    return type(book) == "table" and book or nil
end

-- ForeverCore's shared side-tab column for addon pages in the professions window.
local function CoreTabs()
    local core = _G.ForeverCore
    local tabs = type(core) == "table" and core.ProfessionTabs
    if type(tabs) == "table" and type(tabs.Register) == "function" and type(tabs.Select) == "function"
        and type(tabs.ShowNative) == "function" then
        return tabs
    end
end

local function NativeTabs(book)
    local list = {}
    if type(book.ProfessionsOverviewTab) == "table" then list[1] = book.ProfessionsOverviewTab end
    for _, tab in ipairs(book.rightProfessionTabs or {}) do list[#list + 1] = tab end
    return list
end

-- The game checks its side tab when it shows a page. After our page it needs telling again.
local function CheckNativeTab(book)
    local line
    if type(Professions) == "table" and type(Professions.GetEffectiveSkillLineID) == "function" then
        line = Num(ns.Call(Professions.GetEffectiveSkillLineID))
    end
    local onBook = type(book.BookPage) == "table" and book.BookPage:IsShown() and true or false
    if type(book.ProfessionsOverviewTab) == "table" then book.ProfessionsOverviewTab:SetChecked(onBook) end
    for _, tab in ipairs(book.rightProfessionTabs or {}) do
        tab:SetChecked(not onBook and line ~= nil and line ~= 0 and tab.skillLine == line)
    end
end

-- Above the game's pages (level 100), below the window's portrait, title and border.
local function PageLevel(book)
    local portrait = book.PortraitContainer
    local top = type(portrait) == "table" and portrait.GetFrameLevel and Num(portrait:GetFrameLevel())
    if top and top > 110 then return top - 10 end
    return (Num(book:GetFrameLevel()) or 0) + 200
end

-- The crafting page's rank bar is in the HIGH strata: faded out with its page, it still takes the
-- mouse through ours. A frame over it takes the mouse instead.
local function CoverRankBar(book, page)
    local bar = type(book.CraftingPage) == "table" and book.CraftingPage.RankBar
    if type(bar) ~= "table" or trade.rankCover then return end
    local cover = CreateFrame("Frame", nil, page)
    local box = type(bar.Border) == "table" and bar.Border or bar
    cover:SetPoint("TOPLEFT", box, "TOPLEFT", -2, 2)
    cover:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 2, -2)
    cover:SetFrameStrata("HIGH")
    cover:SetFrameLevel((Num(bar:GetFrameLevel()) or 0) + 10)
    cover:EnableMouse(true)
    trade.rankCover = cover
end

local function DetailButton(right, width, click)
    local b = CreateFrame("Button", nil, right, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetScript("OnClick", click)
    b:SetScript("OnEnter", function(self)
        if not (GameTooltip and self.tip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText(self:GetText() or "", Gold())
        GameTooltip:AddLine(self.tip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        if OwnsTooltip(self) then GameTooltip:Hide() end
    end)
    return b
end

-- The picked step's box on a page: icon, two lines, the rows under them, and the buttons: in the
-- professions window Show recipe and Create, at the auction house Buy.
local function BuildDetail(right, scroll, button)
    local d = { right = right }
    d.Icon = NewItemButton(right)
    d.Icon:SetPoint("TOPLEFT", right, "TOPLEFT", 12, -12)
    if button == "buy" then
        d.Button = DetailButton(right, 110, function(self)
            if self.entries then UI.BuyList(self.entries) end
        end)
        d.Button:SetPoint("TOPRIGHT", right, "TOPRIGHT", -12, -12)
        d.Button:SetText("Buy all")
        d.Button.tip = "One item at a time: the auction house says what that many cost now, and nothing is bought "
            .. "until you click Buy for that price. What a vendor sells is left for the vendor."
    elseif button then
        d.Button = DetailButton(right, 110, function(self)
            if self.step then UI.ShowRecipe(self.step) end
        end)
        d.Button:SetPoint("TOPRIGHT", right, "TOPRIGHT", -12, -12)
        d.Button:SetText("Show recipe")
        d.Make = DetailButton(right, 100, function(self)
            if self.step then UI.MakeStep(self.step, self.count) end
        end)
        d.Make:SetPoint("RIGHT", d.Button, "LEFT", -4, 0)
        d.Make:Hide()
    end
    d.Title = right:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    d.Title:SetPoint("TOPLEFT", d.Icon, "TOPRIGHT", 10, -1)
    if button then
        d.Title:SetPoint("RIGHT", d.Button, "LEFT", -8, 0)
    else
        d.Title:SetPoint("RIGHT", right, "RIGHT", -12, 0)
    end
    d.Title:SetJustifyH("LEFT")
    d.Title:SetWordWrap(false)
    d.Sub = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d.Sub:SetPoint("TOPLEFT", d.Title, "BOTTOMLEFT", 0, -4)
    d.Sub:SetPoint("RIGHT", right, "RIGHT", -12, 0)
    d.Sub:SetJustifyH("LEFT")
    d.Sub:SetWordWrap(false)
    local holder = CreateFrame("Frame", nil, right)
    holder:SetPoint("TOPLEFT", right, "TOPLEFT", 0, -58)
    holder:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)
    return d, UI.NewList(holder, scroll)
end

local function BuildTradePage(book)
    local page = CreateFrame("Frame", "SkillPathTradePage", book)
    -- The box the game's own pages fill: inside the window's border, under its title bar.
    page:SetPoint("TOPLEFT", book, "TOPLEFT", 3, -24)
    page:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -3, 3)
    page:SetFrameLevel(PageLevel(book))
    pcall(CoverRankBar, book, page)
    page:EnableMouse(true)
    if page.EnableMouseWheel then
        page:EnableMouseWheel(true)
        page:SetScript("OnMouseWheel", function() end)
    end
    page:Hide()

    local bg = page:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Art(bg, "Profession-Background-Overview", "Interface\\FrameGeneral\\UI-Background-Marble")

    BuildHead(page, 6, false)

    local left = NewInset(page)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -54)
    left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 4, 4)
    left:SetWidth(400)
    local right = NewInset(page)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -4, 4)

    trade.page = page
    trade.list = UI.NewList(left, "SkillPathStepScroll")
    trade.detail, trade.detailList = BuildDetail(right, "SkillPathDetailScroll", true)
    page:SetScript("OnShow", function(self)
        self:SetFrameLevel(PageLevel(book))
        UI.Update()
    end)
    page:SetScript("OnHide", function()
        if UI.tooltipRow and OwnsTooltip(UI.tooltipRow) then GameTooltip:Hide() end
    end)
end

-- Where the units of one reagent of a craft step come from.
local function UseText(u)
    local buy, made = UI.Units(u.buy), UI.Units(u.made)
    local own = math.max(0, UI.Units(u.n) - buy - made)
    local parts = {}
    if buy > 0 then parts[#parts + 1] = ("%d bought"):format(buy) end
    if made > 0 then parts[#parts + 1] = ("%d made first"):format(made) end
    if own > 0 then parts[#parts + 1] = ("%d on hand"):format(own) end
    if u.noPrice then parts[#parts + 1] = "no price" end
    return table.concat(parts, ", "), u.noPrice
end

-- A step's reagents (step: r, uses), and what it makes first.
local function ReagentRows(els, step, count, plan)
    els[#els + 1] = { kind = "head", text = ("Reagents for %d %s"):format(count, Plural(count, "craft", "crafts")) }
    for _, slot in ipairs(step.r.slots or {}) do
        local any = false
        for _, item in ipairs(slot.items) do
            local u = step.uses[item]
            if u then
                any = true
                local sub, bad = UseText(u)
                els[#els + 1] = { kind = "card", icon = ns.Prices.ItemIcon(item),
                    title = ("%d x %s"):format(UI.Units(u.n), ns.Prices.ItemName(item)), sub = sub, bad = bad,
                    link = ItemLink(item), tip = function(tip) ReagentTip(tip, item, plan) end, what = "reagent" }
            end
        end
        if not any then
            local first = slot.items[1]
            els[#els + 1] = { kind = "card", icon = ns.Prices.ItemIcon(first),
                title = ("%d x %s"):format(slot.qty * count, ns.Prices.ItemName(first)), sub = "No price", bad = true,
                link = ItemLink(first), tip = function(tip) ReagentTip(tip, first, plan) end, what = "reagent" }
        end
    end
    if step.r.currency then els[#els + 1] = { kind = "text", text = "Also costs a currency, which isn't counted." } end
    local subs = {}
    for _, sub in pairs(step.subs or {}) do subs[#subs + 1] = sub end
    table.sort(subs, function(a, b) return a.r.id < b.r.id end)
    if #subs > 0 then
        els[#els + 1] = { kind = "head", text = "Make first" }
        for _, sub in ipairs(subs) do
            els[#els + 1] = { kind = "card", icon = sub.r.icon, title = ("%d x %s"):format(UI.Units(sub.crafts), sub.r.name),
                sub = ("Makes %d %s: cheaper than buying them"):format(UI.Units(sub.n), ns.Prices.ItemName(sub.item)),
                link = RecipeLink(sub.r.id), what = "sub" }
        end
    end
end

-- The rows under a craft step's header.
local function CraftDetail(s, plan)
    local step = s.step
    local els = {}
    local count = UI.CraftCount(step)
    local _, _, _, _, _, _, _, money, color = UI.StepText(s, plan)
    els[#els + 1] = { kind = "line", left = "Reagents (on the shopping list already)", right = money,
        rightColor = color }
    ReagentRows(els, step, count, plan)
    if step.tools then
        els[#els + 1] = { kind = "head", text = "Tools (not used up)" }
        for _, t in ipairs(step.tools) do
            els[#els + 1] = { kind = "card", icon = ns.Prices.ItemIcon(t.item), title = ns.Prices.ItemName(t.item),
                sub = TOOL_HOW[t.how] or TOOL_HOW.held, link = ItemLink(t.item),
                tip = function(tip) ReagentTip(tip, t.item, plan) end, what = "tool" }
        end
    end
    els[#els + 1] = { kind = "head", text = "What it makes" }
    local o = s.out
    if o.none then
        els[#els + 1] = { kind = "text", text = UI.OutputText(o) .. "." }
    else
        local left = o.left
        els[#els + 1] = { kind = "card", icon = ns.Prices.ItemIcon(o.item),
            title = ("%d x %s"):format(o.n, ns.Prices.ItemName(o.item)), sub = (UI.OutputText(o):gsub("^Makes %d+: ", "")),
            money = left and left.value >= 0.5 and ns.Money(left.value) or nil, moneyColor = "green",
            link = ItemLink(o.item), what = "output",
            tip = left and function(tip)
                ItemTip(tip, o.item)
                local wr, wg, wb = White()
                local gr, gg, gb = Grey()
                tip:AddLine(("%d left at the end of the path: %s."):format(left.left,
                    left.value >= 0.5 and ns.Money(left.value) or "no sale"), wr, wg, wb, true)
                for _, line in ipairs(UI.SellLines(left)) do tip:AddLine(line, gr, gg, gb, true) end
            end or function(tip) ReagentTip(tip, o.item, plan) end }
    end
    for _, p in ipairs(step.points) do
        if p.missing then
            for _, m in ipairs(p.missing) do
                local text = m.item and ("No price for %s: %s."):format(ns.Prices.ItemName(m.item), m.why)
                    or ("No price: %s."):format(m.why)
                els[#els + 1] = { kind = "text", text = text, bad = true }
            end
            break
        end
    end
    local alts = {}
    for _, c in pairs(step.alts or {}) do alts[#alts + 1] = c end
    table.sort(alts, function(x, y) return x.r.id < y.r.id end)
    for _, c in ipairs(alts) do
        local why = c.missing and c.missing[1]
        els[#els + 1] = { kind = "text", bad = true, text = ("%s might be cheaper, but %s has no price."):format(
            c.r.name, why and why.item and ns.Prices.ItemName(why.item) or "a reagent") }
    end
    if step.r.known and not step.r.trust then
        els[#els + 1] = { kind = "text",
            text = "Its levels don't match the colours the game shows, so it is used only while orange." }
    end
    if ns.db.showPoints then
        els[#els + 1] = { kind = "head", text = "Each point" }
        for _, line in ipairs(UI.PointLines(step)) do els[#els + 1] = line end
    end
    return els
end

-- The rows under a trainer step's header.
local function TrainDetail(s, plan)
    local t = s.train
    local els = {}
    local _, _, _, _, _, _, _, money, color = UI.StepText(s, plan)
    if money then els[#els + 1] = { kind = "line", left = "Trainer fees", right = money, rightColor = color } end
    for _, rank in ipairs(t.ranks or {}) do
        local name, text = RankName(rank)
        if rank.how == "book" then
            text = ("At skill %d the rank is full. %s teaches %s (a vendor sells it): the cap goes to %d.")
                :format(t.at, ns.Prices.ItemName(rank.item), name, rank.cap)
        elseif rank.how == "quest" then
            text = ("At skill %d the rank is full. %s comes from a quest: the cap goes to %d.")
                :format(t.at, name, rank.cap)
        else
            text = ("At skill %d the rank is full. A %s trainer teaches %s: the cap goes to %d.")
                :format(t.at, plan.name, name, rank.cap)
        end
        local need = RankNeed(rank, plan)
        if need then text = text .. (" It %s."):format(need) end
        els[#els + 1] = { kind = "text", text = text }
        els[#els + 1] = { kind = "line", left = name .. " rank", right = RankFee(rank),
            rightColor = not rank.fee and "red" or nil }
    end
    if #t.learn > 0 then
        els[#els + 1] = { kind = "head", text = t.rank and "Learn on the same visit" or "Learn" }
        for _, l in ipairs(t.learn) do
            els[#els + 1] = { kind = "card", icon = l.r.icon, title = l.r.name,
                sub = l.info.seen and ("Trainer, from skill %d"):format(l.info.at)
                    or l.info.table and ("Trainer, from skill %d (built-in table)"):format(l.info.at)
                    or ("Trainer, from skill %d (not read from a trainer yet)"):format(l.info.at),
                money = l.unknown and "fee not read" or (l.fee >= 0.5 and ns.Money(l.fee) or "free"),
                moneyColor = l.unknown and "red" or nil, link = RecipeLink(l.r.id), what = "learn" }
        end
    end
    return els
end

local function LearnDetail(s, plan)
    local l = s.learn
    return {
        { kind = "line", left = "Recipe item (on the shopping list already)", right = ns.Money(l.cost) },
        { kind = "card", icon = ns.Prices.ItemIcon(l.item), title = ns.Prices.ItemName(l.item),
            sub = "Teaches " .. l.r.name, money = l.cost >= 0.5 and ns.Money(l.cost) or "free", link = ItemLink(l.item),
            tip = function(tip) ReagentTip(tip, l.item, plan) end, what = "learn" },
    }
end

-- The rows under a tool step's header: why, and how it is got.
local function ToolDetail(s, plan, search, hint)
    local t = s.tool
    local els = {}
    local _, _, _, _, _, _, _, money, color = UI.StepText(s, plan)
    els[#els + 1] = { kind = "text", text = ("%s needs %s in your bags. Crafting doesn't use it up: keep it for "
        .. "the steps after too."):format(ToolFor(t), ns.Prices.ItemName(t.item)) }
    if t.how == "make" then
        els[#els + 1] = { kind = "line", left = "Reagents (on the shopping list already)", right = money,
            rightColor = color }
        ReagentRows(els, t, 1, plan)
    else
        els[#els + 1] = { kind = "line", left = "On the shopping list already", right = money, rightColor = color }
        for _, e in ipairs(plan.shopping or {}) do
            if e.item == t.item then
                els[#els + 1] = UI.ShopCard(e, search and function() search(e) end, hint, plan)
                break
            end
        end
    end
    return els
end

local SEARCH_HINT = "Click to search for it."

-- The picked step of a page (view: the professions window's or the auction house's, where a
-- click on an item searches for it).
-- Create N: the step's crafts, as many as your bags have reagents for. Not for a recipe that
-- makes no item (an enchant goes on an item you pick: Show recipe opens the game's page for it).
local function MakeButton(d, step, want)
    local mk = d.Make
    local T = C_TradeSkillUI
    if not (mk and T and T.CraftRecipe and step.r and step.r.out) then return end
    local info = ns.Call(T.GetRecipeInfo, step.r.id)
    local have = Num(ns.Field(info, "numAvailable"))
    local n = have and math.min(want, math.floor(have)) or want
    mk.step = step
    if n >= 1 then
        mk.count = n
        mk:SetText(("Create %d"):format(n))
        mk:SetEnabled(true)
        mk.tip = n < want and ("Your bags have the reagents for %d of the step's %d crafts."):format(n, want)
            or "Crafts them all, one after another, as the game's Create All does."
    else
        mk.count = 0
        mk:SetText("Create")
        mk:SetEnabled(false)
        mk.tip = "Not enough reagents in your bags yet: get what the shopping list says first."
    end
    mk:Show()
end

local buying

-- Only what the auction house sells: an all-vendor list has no Buy button.
local function BuyButton(d, entries)
    local here = false
    for _, e in ipairs(entries) do
        if UI.AuctionCount(e) > 0 then here = true end
    end
    if not here then return end
    local b = d.Button
    b.entries = entries
    b:SetText(buying and "Buying..." or (#entries == 1 and "Buy" or "Buy all"))
    b:SetEnabled(not buying and #entries > 0)
    b:Show()
end

local function AnchorTitle(d)
    local to = (d.Make and d.Make:IsShown() and d.Make) or (d.Button and d.Button:IsShown() and d.Button)
    if to then
        d.Title:SetPoint("RIGHT", to, "LEFT", -8, 0)
    else
        d.Title:SetPoint("RIGHT", d.right, "RIGHT", -12, 0)
    end
end

local function Detail(view, s, plan, top)
    local d = view.detail
    if d.Button then
        d.Button:Hide()
        d.Button.step, d.Button.entries = nil, nil
    end
    if d.Make then
        d.Make:Hide()
        d.Make.step = nil
    end
    if not s then
        d.Icon:Hide()
        d.Title:SetText("")
        d.Sub:SetText("")
        AnchorTitle(d)
        view.detailList:Set({}, top)
        return
    end
    local search = view.search and function(entry) UI.SearchAuction(entry.item) end or nil
    local hint = search and SEARCH_HINT or nil
    local title, sub, icon, r, g, b, _, money, color = UI.StepText(s, plan)
    d.Icon:Show()
    SetIcon(d.Icon, icon, 0, false)
    d.Title:SetText(title)
    d.Title:SetTextColor(r, g, b)
    d.Sub:SetText(sub)
    local els = {}
    if s.kind == "buy" then
        els[#els + 1] = { kind = "line", left = "Everything the path takes from outside", right = money,
            rightColor = color }
        if s.odds then
            els[#els + 1] = { kind = "line", left = "Spare for bad luck, on top", right = ns.Money(s.spare),
                rightColor = "grey" }
            els[#els + 1] = { kind = "text", text = SPARE_NOTE }
        end
        if not search then
            els[#els + 1] = { kind = "text", text = "At the auction house, the SkillPath tab searches for each." }
        end
        for _, e in ipairs(s.entries) do
            els[#els + 1] = UI.ShopCard(e, search and function() search(e) end, hint, plan)
        end
        for _, e in ipairs(s.spares) do
            els[#els + 1] = UI.ShopCard(e, search and function() search(e) end, hint, plan)
        end
        if d.Button and search then
            local all = {}
            for _, e in ipairs(s.entries) do all[#all + 1] = e end
            for _, e in ipairs(s.spares) do all[#all + 1] = e end
            BuyButton(d, all)
        end
    elseif s.kind == "craft" then
        if d.Button and not plan.forOther and s.step.r.known then
            d.Button.step = s.step
            d.Button:Show()
            MakeButton(d, s.step, UI.CraftCount(s.step))
        end
        els = CraftDetail(s, plan)
    elseif s.kind == "train" then
        els = TrainDetail(s, plan)
    elseif s.kind == "learn" then
        els = LearnDetail(s, plan)
    elseif s.kind == "tool" then
        if d.Button and not search and not plan.forOther and s.tool.r and s.tool.r.known then
            d.Button.step = s.tool
            d.Button:Show()
            MakeButton(d, s.tool, 1)
        elseif d.Button and search and s.tool.how == "buy" then
            for _, e in ipairs(plan.shopping or {}) do
                if e.item == s.tool.item then BuyButton(d, { e }) end
            end
        end
        els = ToolDetail(s, plan, search, hint)
    elseif s.kind == "gap" then
        local further = {}
        for _, o in ipairs(plan.options or {}) do
            if o.covers > 0 then further[#further + 1] = UI.OptionCard(o) end
        end
        els[#els + 1] = { kind = "text", text = s.step.why .. UI.GapWait(s.step, " ")
            .. (#further > 0 and " Recipes that would go on:" or "") }
        for _, card in ipairs(further) do els[#els + 1] = card end
    elseif s.kind == "sell" then
        els[#els + 1] = { kind = "line", left = "What selling the rest gives", right = money, rightColor = color }
        for _, e in ipairs(UI.SellRows(s, search, hint)) do els[#els + 1] = e end
    end
    AnchorTitle(d)
    view.detailList:Set(els, top)
end

-- A page: every step in order on the left, the picked one on the right.
local function UpdateView(view)
    local page = view.page
    if not (page and page:IsVisible() and ns.db) then return end
    local plan = ns.Plan()
    UpdateHead(page, plan)

    local steps = UI.Steps(plan)
    local sel
    for _, s in ipairs(steps) do
        if StepKey(s) == view.selected then
            sel = s
            break
        end
    end
    sel = sel or steps[1]
    local key = sel and StepKey(sel) or nil
    local moved = key ~= view.shownKey
    view.selected, view.shownKey = key, key

    local els = {}
    for _, s in ipairs(steps) do
        local t, sub, icon, r, g, b, bad, money, color = UI.StepText(s, plan)
        els[#els + 1] = { kind = "card", n = s.n, icon = icon, title = t, color = { r, g, b }, sub = sub, bad = bad,
            money = money, moneyColor = color, selected = s == sel, step = s, what = "step",
            tip = function(tip) UI.StepTip(tip, s, plan) end,
            click = function()
                view.selected = StepKey(s)
                UI.Update()
            end }
    end
    if not plan.ok then
        els = EmptyRows(plan)
    elseif #(plan.options or {}) > 0 then
        els[#els + 1] = { kind = "head", text = "Recipes worth finding" }
        for _, o in ipairs(plan.options) do els[#els + 1] = UI.OptionCard(o) end
    end
    AddNotes(els, plan)
    -- Another path: back to the top of the steps.
    local path = plan.ok and ("%s:%s:%s"):format(tostring(plan.line), tostring(plan.forOther), tostring(plan.to)) or "none"
    view.list:Set(els, path ~= view.path)
    view.path = path
    Detail(view, sel, plan, moved)
end

local function UpdateTrade() UpdateView(trade) end

----------------------------------------------------------------------
-- Professions window: the side tab
----------------------------------------------------------------------
local function SetTabIcon(tab)
    local icon = type(tab) == "table" and tab.Icon
    if type(icon) ~= "table" or not icon.SetTexture then return end
    icon:SetTexture(ns.ICON)
    if type(tab.SetFillToInterior) == "function" then tab:SetFillToInterior(true) end
end

-- Without ForeverCore: our own tab under the game's, and the game's pages faded out under ours
-- (never hidden: hiding them from addon code would run the game's page scripts tainted).
local function OwnSelect(on)
    local book = TradeFrame()
    if not (book and trade.page and trade.tab) then return end
    on = on and true or false
    if on then
        for _, page in ipairs(book.Pages or {}) do
            if page:IsShown() and trade.hidden[page] == nil then
                trade.hidden[page] = Num(page:GetAlpha()) or 1
                page:SetAlpha(0)
            end
        end
        for _, tab in ipairs(NativeTabs(book)) do tab:SetChecked(false) end
    else
        for page, alpha in pairs(trade.hidden) do page:SetAlpha(alpha) end
        trade.hidden = {}
    end
    trade.tab:SetChecked(on)
    trade.page:SetShown(on)
end

local function OwnAnchor(book)
    local above = type(book.ProfessionsOverviewTab) == "table" and book.ProfessionsOverviewTab or nil
    for _, tab in ipairs(book.rightProfessionTabs or {}) do
        if tab:IsShown() then above = tab end
    end
    trade.tab:ClearAllPoints()
    if above then
        trade.tab:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2)
    else
        trade.tab:SetPoint("TOPLEFT", book, "TOPRIGHT", 0, -60)
    end
end

local function OwnTab(book)
    local tab = CreateFrame("Button", "SkillPathTradeTab", book, "LargeSideTabButtonTemplate")
    tab.tooltipText = ns.NAME
    tab:SetCustomOnMouseUpHandler(function(_, mouseButton, upInside)
        if mouseButton ~= "LeftButton" or not upInside then return end
        local on = not trade.page:IsShown()
        OwnSelect(on)
        if not on then CheckNativeTab(book) end
    end)
    tab:SetChecked(false)
    trade.tab = tab
    OwnAnchor(book)
    local function back() OwnSelect(false) end
    for _, native in ipairs(NativeTabs(book)) do native:HookScript("OnMouseUp", back) end
    for _, page in ipairs(book.Pages or {}) do page:HookScript("OnShow", back) end
    book:HookScript("OnShow", function() OwnAnchor(book) end)
    book:HookScript("OnHide", back)
end

local function AttachTrade()
    if trade.attached then return end
    local book = TradeFrame()
    if not book then return end
    trade.attached = true
    local ok, err = pcall(function()
        BuildTradePage(book)
        local core = CoreTabs()
        if core then
            trade.tab = core.Register(TRADE_KEY, { icon = ns.ICON, tooltip = ns.NAME, page = trade.page })
            trade.mode = "core"
        else
            OwnTab(book)
            trade.mode = "own"
        end
        SetTabIcon(trade.tab)
    end)
    if not ok then
        trade.error, trade.mode = tostring(err), nil
        if trade.page then trade.page:Hide() end
    end
end
UI.AttachTrade = AttachTrade

function UI.TradeShown()
    return trade.page ~= nil and trade.page:IsVisible() and true or false
end

function UI.SelectTrade()
    AttachTrade()
    if trade.mode == "core" then
        local core = CoreTabs()
        if core then pcall(core.Select, TRADE_KEY) end
    elseif trade.mode == "own" then
        OwnSelect(true)
    end
    return UI.TradeShown()
end

-- Back to the game's own page.
function UI.ShowNative()
    if not UI.TradeShown() then return end
    local book = TradeFrame()
    if trade.mode == "core" then
        local core = CoreTabs()
        if core then pcall(core.ShowNative) end
    else
        OwnSelect(false)
    end
    if book then pcall(CheckNativeTab, book) end
end

-- The step's recipe on the game's crafting page, with the number of crafts filled in.
function UI.ShowRecipe(step)
    local T = C_TradeSkillUI
    if not (T and T.OpenRecipe and step and step.r) then return end
    UI.ShowNative()
    pcall(T.OpenRecipe, step.r.id)
    local count = UI.CraftCount(step)
    ns.After(0.3, function()
        local book = TradeFrame()
        local box = book and type(book.CraftingPage) == "table" and book.CraftingPage.CreateMultipleInputBox
        if type(box) == "table" and box.SetValue and box:IsShown() then pcall(box.SetValue, box, count) end
    end)
end

----------------------------------------------------------------------
-- Auction house: the page and its tab
----------------------------------------------------------------------
local auction = { search = true }
UI.auction = auction

local function AuctionFrame()
    local ah = _G.AuctionHouseFrame
    return type(ah) == "table" and ah or nil
end

-- The game's Buy tab, searching for the item.
function UI.SearchAuction(item)
    local ah = AuctionFrame()
    local name = ns.Prices.ItemName(item)
    if not (ah and name and type(AuctionHouseFrameDisplayMode) == "table") then return false end
    return (pcall(function()
        ah:SetDisplayMode(AuctionHouseFrameDisplayMode.Buy)
        ah.SearchBar:SetSearchText(name)
        ah.SearchBar:StartSearch()
    end))
end

-- Create N on a craft step: the game crafts them one after another. If the game won't, its page
-- for the recipe opens instead.
function UI.MakeStep(step, n)
    local T = C_TradeSkillUI
    if not (T and T.CraftRecipe and step and step.r and Num(n) and n >= 1) then return end
    if not pcall(T.CraftRecipe, step.r.id, n) then UI.ShowRecipe(step) end
end

-- Buying the list from the SkillPath tab, one item at a time: the auction house quotes what that
-- many cost now, and the purchase goes through only when you click Buy on that price. What a
-- vendor sells is left for the vendor; what is sold in whole lots (not per unit) is left for the
-- game's Buy tab, which is searched for it at the end.
local BUY_POPUP = "SKILLPATH_BUY"
local QUOTE_WAIT = 10

local function Name(item) return ns.Prices.ItemName(item) or ("item " .. tostring(item)) end

local function Names(items)
    local out = {}
    for i, item in ipairs(items) do out[i] = Name(item) end
    return table.concat(out, ", ")
end

local function SoldInLots(item)
    local ah = C_AuctionHouse
    local status = ah and ah.GetItemCommodityStatus and Num(ns.Call(ah.GetItemCommodityStatus, item))
    local E = type(Enum) == "table" and type(Enum.ItemCommodityStatus) == "table" and Enum.ItemCommodityStatus or {}
    if status and status == (E.Item or 1) then return true end
    if status and status == (E.Commodity or 2) then return false end
    local rec = ns.Prices.AHStore()[item]
    return type(rec) == "table" and rec.lots and true or false
end

-- How many of an entry to buy here: the path's and the spare, less what a vendor sells cheaper.
function UI.AuctionCount(e)
    local n = (e.buy or 0) + (e.spare or 0)
    local from = e.from or ""
    if from:find("^vendor") then return 0 end
    if from == "auction house and vendor" then
        local sup = ns.Prices.Supply(e.item)
        n = math.min(n, math.floor(Num(sup and sup.listed) or n))
    end
    return n
end

local function BuyDone(note, search)
    local b = buying
    buying = nil
    if StaticPopup_Hide then StaticPopup_Hide(BUY_POPUP) end
    if not b then return end
    local parts = {}
    if b.bought > 0 then
        parts[#parts + 1] = ("Bought %s for %s."):format(Names(b.got), ns.Money(b.spent))
    end
    if note then parts[#parts + 1] = note end
    if #b.vendor > 0 then parts[#parts + 1] = ("From a vendor: %s."):format(Names(b.vendor)) end
    if #b.byHand > 0 then
        parts[#parts + 1] = ("Buy on the Buy tab: %s."):format(Names(b.byHand))
        if search then UI.SearchAuction(b.byHand[1]) end
    end
    if #parts > 0 then ns.Print(table.concat(parts, " ")) end
    UI.Update()
end

local function ShowQuote(b)
    local e, n, total = b.entry, b.n, b.quote
    local lines = { ("Buy %d %s for %s?"):format(n, Name(e.item), ns.Money(total)) }
    local spare = n - (e.buy or 0)
    if spare > 0 and (e.buy or 0) > 0 then
        lines[#lines + 1] = ("%d for the path and %d spare."):format(e.buy, spare)
    elseif spare > 0 then
        lines[#lines + 1] = "All of it spare: the average run has enough."
    end
    local planned = e.cost and (e.cost + (e.spareCost or 0)) or nil
    if planned and total > planned * 1.2 + 100 then
        lines[#lines + 1] = ("|cffff2020The path counted %s: the price went up since the scan.|r"):format(ns.Money(planned))
    end
    local money = Num(ns.Call(GetMoney))
    if money and total > money then
        lines[#lines + 1] = ("|cffff2020You have %s.|r"):format(ns.Money(money))
    end
    if #b.queue > 1 then lines[#lines + 1] = ("Item %d of %d."):format(b.i, #b.queue) end
    if StaticPopup_Show then StaticPopup_Show(BUY_POPUP, table.concat(lines, "\n")) end
end

local function BuyNext()
    local b = buying
    if not b then return end
    local ah = C_AuctionHouse
    b.entry, b.quote, b.confirmed = nil, nil, false
    while true do
        b.i = b.i + 1
        local e = b.queue[b.i]
        if not e then return BuyDone(nil, true) end
        local n = UI.AuctionCount(e)
        if n <= 0 then
            b.vendor[#b.vendor + 1] = e.item
        elseif SoldInLots(e.item) or not (ah and ah.StartCommoditiesPurchase) then
            b.byHand[#b.byHand + 1] = e.item
        else
            b.entry, b.n = e, n
            local token = {}
            b.token = token
            if pcall(ah.StartCommoditiesPurchase, e.item, n) then
                ns.After(QUOTE_WAIT, function()
                    if buying == b and b.token == token and not b.quote then
                        pcall(ah.CancelCommoditiesPurchase)
                        b.byHand[#b.byHand + 1] = e.item
                        BuyNext()
                    end
                end)
                return
            end
            b.byHand[#b.byHand + 1] = e.item
            b.entry = nil
        end
    end
end

function UI.BuyList(entries)
    if buying or not UI.AuctionShown() then return end
    local queue = {}
    for _, e in ipairs(entries or {}) do
        if (e.buy or 0) + (e.spare or 0) > 0 then queue[#queue + 1] = e end
    end
    if #queue == 0 then return end
    buying = { queue = queue, i = 0, bought = 0, spent = 0, got = {}, vendor = {}, byHand = {} }
    UI.Update()
    BuyNext()
end

function UI.Buying() return buying end

function UI.ConfirmBuy()
    local b = buying
    if not (b and b.entry and b.quote) or b.confirmed then return end
    b.confirmed = true
    if not pcall(C_AuctionHouse.ConfirmCommoditiesPurchase, b.entry.item, b.n) then
        BuyDone(("The auction house didn't take the purchase of %s."):format(Name(b.entry.item)))
    end
end

function UI.SkipBuy()
    local b = buying
    if not b then return end
    if b.entry then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
    BuyNext()
end

function UI.StopBuying()
    local b = buying
    if not b then return end
    if b.entry and not b.confirmed then pcall(C_AuctionHouse.CancelCommoditiesPurchase) end
    BuyDone()
end

function UI.BuyEvent(event, a, b2)
    local b = buying
    if not b then return end
    if event == "AUCTION_HOUSE_CLOSED" then
        BuyDone("Stopped: the auction house closed.")
    elseif not b.entry then
        return
    elseif event == "COMMODITY_PRICE_UPDATED" then
        local total = Num(b2)
        if b.confirmed or not total then return end
        b.quote = total
        ShowQuote(b)
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        if b.confirmed then return end
        if StaticPopup_Hide then StaticPopup_Hide(BUY_POPUP) end
        b.byHand[#b.byHand + 1] = b.entry.item
        BuyNext()
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" and b.confirmed then
        b.bought = b.bought + 1
        b.spent = b.spent + b.quote
        b.got[#b.got + 1] = b.entry.item
        BuyNext()
    elseif event == "COMMODITY_PURCHASE_FAILED" and b.confirmed then
        BuyDone(("Buying %s failed (the price may have changed): click Buy all again."):format(Name(b.entry.item)))
    end
end

if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs[BUY_POPUP] = {
        text = "%s",
        button1 = "Buy",
        button2 = CANCEL or "Cancel",
        button3 = "Skip",
        OnAccept = function() UI.ConfirmBuy() end,
        OnCancel = function() UI.StopBuying() end,
        OnAlt = function() UI.SkipBuy() end,
        noCancelOnReuse = true,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

local function BuildAuctionPage(ah)
    local page = CreateFrame("Frame", "SkillPathAuctionPage", ah)
    -- Under the title bar, above the money bar: the box the game's Auctions page takes.
    page:SetPoint("TOPLEFT", ah, "TOPLEFT", 4, -24)
    page:SetPoint("BOTTOMRIGHT", ah, "BOTTOMRIGHT", -4, 27)
    page:Hide()

    BuildHead(page, 4, true)

    -- The same two boxes as the professions window: every step, and the picked one.
    local left = NewInset(page)
    left:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -52)
    left:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
    left:SetWidth(390)
    local right = NewInset(page)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 4, 0)
    right:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)

    auction.page = page
    auction.list = UI.NewList(left, "SkillPathAuctionStepScroll")
    auction.detail, auction.detailList = BuildDetail(right, "SkillPathAuctionDetailScroll", "buy")
    page:SetScript("OnShow", function() UI.Update() end)
    page:SetScript("OnHide", function()
        if UI.tooltipRow and OwnsTooltip(UI.tooltipRow) then GameTooltip:Hide() end
    end)
end

local function UpdateAuction() UpdateView(auction) end

-- Without LibAHTab: the tab it would make, after the game's last one.
local function OwnAuctionTab(ah)
    local root = CreateFrame("Frame", nil, ah)
    root:SetSize(10, 10)
    root:SetPoint("TOPLEFT", ah.Tabs[#ah.Tabs], "TOPRIGHT")
    local tab = CreateFrame("Button", AH_TAB, root, "AuctionHouseFrameDisplayModeTabTemplate")
    tab:SetText(ns.NAME)
    tab:SetPoint("TOPLEFT", root, "TOPLEFT", 3, 0)
    -- The game sizes a tab's label when the tab shows. On the first opening that measure comes
    -- out a little short and the label is cut ("SkillPa..."), so it is taken again a frame later.
    local function Fit()
        if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 20, nil, 70) end
    end
    Fit()
    tab:HookScript("OnShow", function() ns.After(0, Fit) end)
    ns.After(0, Fit)
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    tab:SetScript("OnClick", function() UI.SelectAuction() end)
    -- The game showing one of its own pages puts ours away.
    hooksecurefunc(ah, "SetDisplayMode", function(_, displayMode)
        if type(displayMode) == "table" and #displayMode > 0 then
            auction.page:Hide()
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
        end
    end)
    auction.tab = tab
end

local function AttachAuction()
    if auction.attached then return end
    local ah = AuctionFrame()
    if not (ah and type(ah.Tabs) == "table" and #ah.Tabs > 0) then return end
    auction.attached = true
    local ok, err = pcall(function()
        BuildAuctionPage(ah)
        local lib = type(LibStub) == "table" and LibStub.GetLibrary and LibStub:GetLibrary("LibAHTab-1-0", true)
        if type(lib) == "table" and lib.CreateTab and lib.SetSelected and lib.GetButton then
            lib:CreateTab(AH_TAB, auction.page, ns.NAME, ns.NAME)
            auction.tab, auction.lib, auction.mode = lib:GetButton(AH_TAB), lib, "lib"
        else
            OwnAuctionTab(ah)
            auction.mode = "own"
        end
    end)
    if not ok then
        auction.error, auction.mode = tostring(err), nil
        if auction.page then auction.page:Hide() end
    end
end
UI.AttachAuction = AttachAuction

function UI.AuctionShown()
    return auction.page ~= nil and auction.page:IsVisible() and true or false
end

function UI.SelectAuction()
    AttachAuction()
    if auction.mode == "lib" then
        pcall(auction.lib.SetSelected, auction.lib, AH_TAB)
    elseif auction.mode == "own" then
        local ah = AuctionFrame()
        pcall(function()
            ah:SetDisplayMode({})       -- hides every page of the game's
            ah.displayMode = nil
            for _, tab in ipairs(ah.Tabs) do PanelTemplates_DeselectTab(tab) end
            PanelTemplates_SelectTab(auction.tab)
            if ah.SetTitle then ah:SetTitle(ns.NAME) end
        end)
        auction.page:Show()
    end
    return UI.AuctionShown()
end

----------------------------------------------------------------------
-- What the rest of the addon calls
----------------------------------------------------------------------
function UI.Init()
    if EventUtil and EventUtil.ContinueOnAddOnLoaded then
        pcall(EventUtil.ContinueOnAddOnLoaded, "Blizzard_Professions", AttachTrade)
        pcall(EventUtil.ContinueOnAddOnLoaded, "Blizzard_AuctionHouseUI", AttachAuction)
    end
    AttachTrade()
    AttachAuction()
end

function UI.Update()
    UpdateTrade()
    UpdateAuction()
    if UI.GuideShown() then
        local plan = ns.Plan()
        if plan.ok then SetGuide(plan) end
    end
end

function UI.IsShown()
    return UI.TradeShown() or UI.AuctionShown() or UI.GuideShown()
end

local function Visible(frame)
    return frame ~= nil and frame.IsVisible ~= nil and frame:IsVisible() and true or false
end

-- /skillpath and the minimap button: the SkillPath tab of whichever window is open.
function UI.Toggle()
    if Visible(TradeFrame()) then
        if UI.TradeShown() then
            UI.ShowNative()
            return
        elseif UI.SelectTrade() then
            return
        end
    end
    if Visible(AuctionFrame()) and UI.SelectAuction() then return end
    ns.Report()
    ns.Print("Open a profession or the auction house, then use the SkillPath tab.")
end

-- A profession opened and its recipes were read.
function UI.ProfessionsShown()
    AttachTrade()
    if ns.db.openOnTab then UI.SelectTrade() end
    UI.Update()
end

function UI.ProfessionsHidden() end

function UI.AuctionOpened()
    AttachAuction()
    UI.Update()
end

function UI.Status()
    return ("professions tab: %s%s; auction tab: %s%s"):format(trade.mode or "not attached",
        trade.error and (" (" .. trade.error .. ")") or "", auction.mode or "not attached",
        auction.error and (" (" .. auction.error .. ")") or "")
end

LookShotsTargets = LookShotsTargets or {}
LookShotsTargets["SkillPath"] = {
    version = ns.VERSION,
    frames = {
        { label = "professions page", frame = function() return UI.TradeShown() and trade.page or nil end },
        { label = "professions side tab", frame = function()
            return trade.tab and Visible(TradeFrame()) and trade.tab or nil
        end },
        { label = "auction house page", frame = function() return UI.AuctionShown() and auction.page or nil end },
        { label = "auction house tab", frame = function()
            return auction.tab and Visible(AuctionFrame()) and auction.tab or nil
        end },
        { label = "written guide window", frame = function() return UI.GuideShown() and guide.frame or nil end },
        { label = "row tooltip", frame = function()
            local row = UI.tooltipRow
            if row and GameTooltip and GameTooltip:IsShown() and OwnsTooltip(row) then return GameTooltip end
        end },
    },
}
