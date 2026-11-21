# BiS Planner

Your best gear for the stat weights and goals you set. You say what a point of each stat is worth to you, and what you want at least ("hit at least 30"); the planner picks one item per slot so the whole set reaches every goal and scores as high as it can with what is left.

`/bisplan` opens it. So does a left-click on its minimap button.

## Weights and goals

On the **Weights and goals** tab every stat has two boxes:

- **Weight**: what one point of the stat is worth. Strength 1 and Stamina 0.5 means two Stamina count like one Strength. Leave a stat empty and it counts for nothing.
- **At least**: a goal. The set must give at least this much of the stat. Goals come first: the planner gives up score to reach them, and as little as it can.

Goals count what the gear gives, not your own base stats or talents.

Hit, critical strike and haste are in the points the items carry (at level 60, 10 hit or 14 critical strike is 1%). Weapon damage has three stats of its own: main hand, off hand and ranged damage per second.

Keep more than one set of weights: **New** copies the one in use under a name you give it. Sets are shared by all your characters; which one is in use is per character.

## The plan

The **Plan** tab lists one item per slot, with the level it needs and where it comes from: the raid or dungeon and the boss ("Molten Core: Magmadar"), the token it is bought with ("From Desecrated Robe"), the quest, the vendor, the profession that makes it, the faction and standing, or the PvP rank.

- Hover a row for the item's tooltip and the **next best** items for that slot, with how much they lose.
- **Right-click** a row to leave that item out (you'll never get it, or don't want it). The plan fills the slot again. `/bisplan unhide` brings every left-out item back.
- **Shift-click** a row to link the item in chat.
- The line at the bottom has the score and how many goals are reached. Hover it for every goal and the totals of the stats you asked for.
- **Level**: the plan uses gear you can wear at your own level and follows you as you level. Type another level to plan ahead; empty the box to go back.

A slot with nothing you asked for stays empty rather than showing a random item.

The plan is worked out once and saved. It is planned again only when a weight, a goal, a filter or your level changes.

Item tooltips get a line: "In your plan: Head", or how the item scores against the plan's item for that slot. Options can turn it off.

## Options

`/bisplan options`, or right-click the minimap button.

- **Armor**: "Your class's own" (to begin with) uses only the heaviest armor your class wears at the plan's level: plate for warriors and paladins from 40, mail for hunters and shamans from 40, leather for rogues and druids, cloth for the rest. "Any you can wear" adds the lighter kinds, such as leather on a warrior.
- **Best quality**: leave out epics, or everything above uncommon.
- **Crafted gear**, **Reputation gear**, **PvP gear** (off to begin with: gear that needs a PvP rank, and Forever's "Premier" PvP sets).
- **Raid gear** and **Dungeon gear**: turn raid gear off to plan with what you can get outside raids. Raid gear includes what raid tokens buy.
- **Items with no known source** (off to begin with): items that bind when picked up and that no loot table names a way to get. Most of them are not in the game (cut items such as the class bracers from Ahn'Qiraj). Bind-on-equip items with no source may be world drops, so they stay either way and their row says "Binds when equipped".
- **Hands**: any, two-handed only, or one-handed only. **Weapons in the off hand** for classes that dual wield.
- The tooltip line and the minimap button.

## Commands

- `/bisplan`: the window
- `/bisplan print`: the plan in your chat window
- `/bisplan level 40`, `/bisplan level auto`
- `/bisplan unhide`: items you left out may be used again
- `/bisplan options`
- `/bisplan fetch`: see below

## What it knows and what it doesn't

The item list (10,982 items) is built from the game's own tables for Forever 1.60.1, and checked against GearQuest's stats: 98% of the items both know agree on every stat.

- **Left out as not in Forever**: Season of Discovery items (Forever's tables carry some of them, the game doesn't), Forever's level-30 copies of raid items, and developer items.
- **Class sets**: tier 3 and dungeon sets 1 and 2 have no class limit in the tables; the planner gives each set to its own class. (The game lets other classes wear dungeon set 1.)

- **Not counted**: set bonuses, "chance on hit" and "use" effects (the tooltip in the planner says so for such an item), random-suffix items ("of the Bear"), enchants.
- **Where items come from**: the game's tables name professions, factions and PvP ranks. Bosses, dungeons, raids, quests, vendors and tokens come from the loot tables of AtlasLoot Classic (its Forever edition, with Forever's own dungeons and raids), Forever Dungeon Journal, GearQuest Forever and Questie, read when the list is built. 10,021 of the 10,982 items have one. Of the rest, 432 bind when picked up and are left out; 529 bind when equipped and stay as possible world drops. The planner does not need those addons in the game.
- **Items without a level**: many quest rewards need no level to wear. The planner counts them from about the level their quest comes up ("Around level 33").
- **Weapon damage** is within about 1.5% of the tooltip's.
- **Unseen items**: about 1,700 item numbers in the game's tables have never been sent to the computer the list was built on, so they are not in the list. `/bisplan fetch` asks the game for them (a few minutes). They join the list when it is next rebuilt, which happens outside the game (`tools/BisPlanner/build_db.py` in the addon's source).
- The class rules (who wears plate, who uses which weapons) are Classic's.
