-- Slutmog Scout: farm spots.
-- Random BoE greens/blues drop from any mob whose level sits in the item's
-- band, so a "spot" is a dense camp of mobs at the right level.
-- Outdoor rows are hand-written from classic-era knowledge: lo/hi are the mob
-- levels of the camp and are approximate. Humanoid camps are preferred (they
-- also drop cloth and coin). Dungeon rows come from Dungeons.lua (generated).
local ADDON, ns = ...

ns.SPOTS = {
  -- mob level 5-16 ----------------------------------------------------------
  { zone = "Elwynn Forest", area = "Fargodeep and Jasperlode mines", lo = 5, hi = 9, mobs = "Kobolds", note = "Packed tunnels." },
  { zone = "Durotar", area = "Razormane Grounds / Kolkar Crag", lo = 6, hi = 10, mobs = "Quilboar and centaur", note = "Razormane quilboar and Kolkar centaur camps; separate trips." },
  { zone = "Dun Morogh", area = "Frostmane Hold", lo = 7, hi = 10, mobs = "Frostmane trolls", note = "Cave and camp west of Kharanos." },
  { zone = "Tirisfal Glades", area = "Agamand Mills", lo = 7, hi = 12, mobs = "Undead", note = "Dense mills and crypt north of Brill." },
  { zone = "Teldrassil", area = "Gnarlpine Hold / Ban'ethil Barrow Den", lo = 7, hi = 11, mobs = "Gnarlpine furbolgs", note = "Camp plus the den below it." },
  { zone = "Mulgore", area = "Venture Co. Mine / Palemane Rock", lo = 7, hi = 11, mobs = "Goblins and gnolls", note = "Mine east of Thunder Bluff." },
  { zone = "Westfall", area = "Jangolode Mine / Gold Coast Quarry", lo = 11, hi = 16, mobs = "Defias and kobolds", note = "Humanoids inside and around both mines." },
  { zone = "The Barrens", area = "Thorn Hill / Agama'gor", lo = 10, hi = 16, mobs = "Razormane quilboar", note = "Large quilboar camps either side of the Crossroads." },
  { zone = "Loch Modan", area = "Stonesplinter Valley", lo = 10, hi = 15, mobs = "Stonesplinter troggs", note = "Valley and caves south of Thelsamar." },
  { zone = "Silverpine Forest", area = "Fenris Isle", lo = 12, hi = 16, mobs = "Rot Hide gnolls", note = "Whole island of humanoids." },
  -- mob level 17-31 ---------------------------------------------------------
  { zone = "Hillsbrad Foothills", area = "Durnholde Keep", lo = 19, hi = 24, mobs = "Syndicate humans", note = "Tight humanoid packs with fast respawns." },
  { zone = "Stonetalon Mountains", area = "Windshear Crag", lo = 17, hi = 22, mobs = "Venture Co. goblins", note = "Loggers and operators all over the crag." },
  { zone = "Ashenvale", area = "Thistlefur Village", lo = 22, hi = 26, mobs = "Thistlefur furbolgs", note = "Dense village and the hold behind it." },
  { zone = "Wetlands", area = "Angerfang Encampment / Dun Algaz", lo = 24, hi = 29, mobs = "Dragonmaw orcs", note = "Orc camp in the east plus the tunnels south." },
  { zone = "Duskwood", area = "Vul'Gol Ogre Mound", lo = 25, hi = 30, mobs = "Splinter Fist ogres", note = "Ogres outside and inside the cave." },
  { zone = "Thousand Needles", area = "Galak centaur camps", lo = 24, hi = 30, mobs = "Galak centaur", note = "Loop between the camps north of Freewind Post." },
  { zone = "Ashenvale", area = "Foulweald / Satyrnaar", lo = 26, hi = 31, mobs = "Furbolgs and satyrs", note = "East Ashenvale camps; satyrs die fast." },

  -- mob level 30-44 ---------------------------------------------------------
  { zone = "Arathi Highlands", area = "Boulderfist Hall / Witherbark", lo = 30, hi = 36, mobs = "Ogres and trolls", note = "Southern ogre cave and the troll village next to it." },
  { zone = "Desolace", area = "Kolkar / Magram / Gelkis villages", lo = 30, hi = 38, mobs = "Centaur", note = "Pick the clan you are not friendly with." },
  { zone = "Stranglethorn Vale", area = "Kurzen's Compound", lo = 32, hi = 37, mobs = "Kurzen humans", note = "Camp plus the cave behind it." },
  { zone = "Alterac Mountains", area = "Crushridge Hold / Strahnbrad", lo = 32, hi = 40, mobs = "Ogres and Syndicate", note = "Ogre ruins in the middle of the zone." },
  { zone = "Arathi Highlands", area = "Stromgarde Keep", lo = 33, hi = 40, mobs = "Syndicate, ogres, Witherbark", note = "Three packed factions in one ruined city." },
  { zone = "Stranglethorn Vale", area = "Venture Co. camps (Lake Nazferiti)", lo = 34, hi = 40, mobs = "Venture Co. goblins", note = "Goblin camps around Lake Nazferiti." },
  { zone = "Swamp of Sorrows", area = "Fallow Sanctuary / Stonard edge", lo = 35, hi = 40, mobs = "Lost Ones, murlocs", note = "Draenei camp in the north." },
  { zone = "Dustwallow Marsh", area = "Stonemaul Ruins", lo = 35, hi = 43, mobs = "Stonemaul ogres, Grimtotem", note = "Ogre ruins and Grimtotem camps in the marsh." },
  { zone = "Badlands", area = "Angor Fortress / Dustbelcher camps", lo = 35, hi = 44, mobs = "Shadowforge dwarves, ogres", note = "Fortress in the north, ogre camps in the west." },

  -- mob level 40-53 ---------------------------------------------------------
  { zone = "Stranglethorn Vale", area = "Mosh'Ogg Mound / Bloodsail camps", lo = 40, hi = 45, mobs = "Ogres and pirates", note = "Ogre mound in the middle, pirates on the south coast." },
  { zone = "Tanaris", area = "Wastewander camps (Noonshade, Waterspring)", lo = 40, hi = 45, mobs = "Wastewander bandits", note = "The classic humanoid grind east of Gadgetzan." },
  { zone = "Feralas", area = "Gordunni Outpost / Woodpaw Hills", lo = 40, hi = 45, mobs = "Ogres and gnolls", note = "Ogres by Camp Mojache, gnolls to the south-east." },
  { zone = "The Hinterlands", area = "Witherbark / Vilebranch villages", lo = 41, hi = 48, mobs = "Trolls", note = "Shadra'Alor, Hiri'watha and Zun'watha." },
  { zone = "Tanaris", area = "Lost Rigger Cove", lo = 43, hi = 46, mobs = "Southsea pirates", note = "Very dense; the best open-world humanoid camp in the low 40s." },
  { zone = "Searing Gorge", area = "The Cauldron / Slag Pit", lo = 43, hi = 49, mobs = "Dark Iron dwarves", note = "Pit floor and the tunnels under it." },
  { zone = "Tanaris", area = "Dunemaul Compound", lo = 45, hi = 49, mobs = "Dunemaul ogres", note = "South-west ruins." },
  { zone = "Azshara", area = "Ruins of Eldarath / Temple of Zin-Malor", lo = 45, hi = 51, mobs = "Spitelash naga", note = "Coast ruins, almost never contested." },
  { zone = "Blasted Lands", area = "Dreadmaul Hold / Dreadmaul Post", lo = 45, hi = 51, mobs = "Dreadmaul ogres", note = "Ogre camps in the north of the zone." },
  { zone = "The Hinterlands", area = "Jintha'Alor", lo = 46, hi = 51, mobs = "Elite Vilebranch trolls", note = "Elite terraces; bring a friend or outlevel it." },
  { zone = "Felwood", area = "Jadefire Run / Jadefire Glen / Deadwood Village", lo = 47, hi = 53, mobs = "Satyrs and furbolgs", note = "Satyr camps at both ends of the zone." },

  -- mob level 50-61 ---------------------------------------------------------
  { zone = "Burning Steppes", area = "Dreadmaul Rock / Blackrock Stronghold", lo = 50, hi = 56, mobs = "Firegut ogres, Blackrock orcs", note = "Ogres in the east, orcs in the west." },
  { zone = "Felwood", area = "Jaedenar / Shadow Hold", lo = 50, hi = 55, mobs = "Jaedenar cultists", note = "Cultists outside and down the hold." },
  { zone = "Western Plaguelands", area = "Ruins of Andorhal / Sorrow Hill", lo = 51, hi = 57, mobs = "Undead", note = "Huge undead density around the city." },
  { zone = "Winterspring", area = "Winterfall Village / Timbermaw Post", lo = 53, hi = 58, mobs = "Winterfall furbolgs", note = "Humanoid furbolg camps; also Timbermaw rep." },
  { zone = "Western Plaguelands", area = "Hearthglen", lo = 54, hi = 58, mobs = "Elite Scarlet Crusade", note = "Elite humanoid town in the north." },
  { zone = "Eastern Plaguelands", area = "Tyr's Hand", lo = 55, hi = 60, mobs = "Elite Scarlet Crusade", note = "The classic level-60 world-drop farm: elite humanoids, fast respawns." },
  { zone = "Eastern Plaguelands", area = "Plaguewood / Corin's Crossing", lo = 55, hi = 59, mobs = "Undead", note = "Non-elite undead in large numbers." },
  { zone = "Eastern Plaguelands", area = "Zul'Mashar", lo = 56, hi = 59, mobs = "Mossflayer trolls", note = "Troll city in the north-east corner." },
  { zone = "Silithus", area = "Twilight's Hammer camps", lo = 57, hi = 60, mobs = "Twilight cultists", note = "Three camps of humanoids; also drops Encrypted Twilight Texts." },
  { zone = "Winterspring", area = "Frostmaul Hold / Ice Thistle Hills", lo = 56, hi = 60, mobs = "Frostmaul giants, yetis", note = "Giants and yetis: slow kills and no cloth, so only the level-band greens." },
  { zone = "Deadwind Pass", area = "Deadwind Ravine ogre camps", lo = 58, hi = 61, mobs = "Elite Deadwind ogres", note = "Small elite camps, rarely farmed." },
}

-- Dungeons: names, level ranges and locations from Forever's own dungeon data.
for _, d in ipairs(ns.DUNGEON_SPOTS or {}) do
  ns.SPOTS[#ns.SPOTS + 1] = {
    zone = d.zone, area = d.area, lo = d.lo, hi = d.hi,
    mobs = "Elite trash and bosses", dungeon = true, inst = d.zone,
    note = "Trash drops the same random greens as outdoor mobs of this level; clear and reset.",
  }
end
