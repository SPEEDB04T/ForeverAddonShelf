-- Slutmog Scout: the options window and the minimap button (both drawn by Kit.lua)
local _, ns = ...
local Kit = ns.Kit
local Options = {}
ns.Options = Options

local function GetOpt(key)
  return function()
    return ns.db.opts[key] and true or false
  end
end

local function SetOpt(key)
  return function(value)
    ns.db.opts[key] = value and true or false
  end
end

local function Rows()
  return {
    { kind = "header", text = "Scanning" },
    { kind = "check", label = "Scan at the auction house",
      tip = "Scans when you open the auction house, at most once every 30 minutes. Same as /smog auto.",
      get = GetOpt("autoScan"), set = SetOpt("autoScan") },
    { kind = "check", label = "Show prices on item tooltips",
      tip = "Adds the last scanned price and where to farm it to the tooltip of a tracked piece. Same as /smog tooltip.",
      get = GetOpt("tooltip"), set = SetOpt("tooltip") },

    { kind = "header", text = "List" },
    { kind = "slider", label = "Hide the most common", min = 0, max = ns.COMMON_CUT_MAX or 60, step = 5, format = "%d%%",
      tip = "Hides that share of the list: the pieces that drop most often across a realm (from the Classic loot tables), never worth flipping. 0 hides none. Filter > Show easy, common pieces shows them anyway. Same as /smog common 40.",
      get = function() return ns.CommonCut() end,
      set = function(v) ns.SetCommonCut(v) end },

    { kind = "header", text = "Window" },
    { kind = "slider", label = "Window size", min = 60, max = 200, step = 5, format = "%d%%",
      tip = "Makes the whole window bigger or smaller. Same as dragging its bottom-right corner, or /smog scale 120.",
      get = function() return math.floor(ns.WindowScale() * 100 + 0.5) end,
      set = function(v) ns.SetWindowScale(v / 100) end },

    { kind = "header", text = "Minimap" },
    Kit.MinimapRow(),

    { kind = "header", text = "Open" },
    { kind = "buttons", buttons = {
      { label = "Price list", tip = "Same as /smog.",
        click = function() ns.Toggle(nil, true) end },
      { label = "Farm guide", tip = "Where the most valuable pieces drop. Same as /smog farm.",
        click = function() ns.Toggle("farm", true) end },
      { label = "Measured farms", tip = "What your own farming has dropped. Same as /smog measured.",
        click = function() ns.Toggle("measured", true) end },
    } },

    { kind = "header", text = "Actions" },
    { kind = "buttons", buttons = {
      { label = "Scan now", tip = "Scans the auction house. It has to be open. Same as /smog scan.",
        click = function() ns.StartScan() end },
      { label = "Check the list", tip = "Checks the built-in pieces against this game build. Same as /smog verify.",
        click = function() ns.SelfCheck(true) end },
      { label = "Self-test", tip = "Checks that this game has what the addon needs. Same as /smog selftest.",
        click = function() ns.SelfTest() end },
    } },
    { kind = "buttons", buttons = {
      { label = "Bring back removed pieces", confirm = true,
        tip = "Built-in pieces you took off the list are listed again. Same as /smog restore.",
        click = function() ns.RestoreHidden() end },
      { label = "Clear saved prices", confirm = true,
        tip = "Forgets every scanned price and the price history. Same as /smog wipe.",
        click = function() ns.WipePrices() end },
      { label = "Clear measured farms", confirm = true,
        tip = "Forgets what your own farming has dropped. Same as /smog clearfarm yes.",
        click = function() ns.ClearMeasured() end },
    } },
  }
end
Options.Rows = Rows

local function Status()
  local last = ns.db.lastScan
  if not last then
    return { "No auction house scan yet." }
  end
  local minutes = math.floor((time() - last) / 60)
  if minutes < 1 then
    return { "Last scan: just now." }
  elseif minutes < 120 then
    return { ("Last scan: %d min ago."):format(minutes) }
  elseif minutes < 48 * 60 then
    return { ("Last scan: %d hours ago."):format(math.floor(minutes / 60)) }
  end
  return { ("Last scan: %d days ago."):format(math.floor(minutes / 1440)) }
end

function Options.Init()
  Kit.Setup({
    title = "Slutmog Scout",
    icon = "Interface\\Icons\\INV_Chest_Plate06",
    accent = { 1.00, 0.40, 0.67 },
    print = ns.Print,
    db = function() return ns.db end,
    rows = Rows,
    click = function() ns.Toggle() end,
    clickHint = "open or close the price list",
    status = Status,
  })
end
