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

The **Plan** tab lists one item per slot, with the level it needs and where it comes from when that is known: the profession that makes it, the faction and standing, the PvP rank, or "Binds when equipped". With Questie installed, quest rewards, drops and vendors are named too.

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

- **Best quality**: leave out epics, or everything above uncommon.
- **Crafted gear**, **Reputation gear**, **PvP rank gear** (off to begin with).
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

The item list (11,350 items) is built from the game's own tables for Forever 1.60.1, and checked against GearQuest's stats: 98.5% of the items both know agree on every stat.

- **Not counted**: set bonuses, "chance on hit" and "use" effects (the tooltip in the planner says so for such an item), random-suffix items ("of the Bear"), enchants.
- **Where items come from**: the game's tables name professions, factions and PvP ranks. They do not say which boss, dungeon or raid drops an item, so the planner can't leave out raid gear by itself: right-click what you won't get, or lower the best quality.
- **Items without a level**: many quest rewards need no level to wear. The planner counts them from about the level their quest comes up ("Around level 33").
- **Weapon damage** is within about 1.5% of the tooltip's.
- **Unseen items**: about 5,900 item numbers in the game's tables have never been sent to the computer the list was built on, so they are not in the list. `/bisplan fetch` asks the game for them (a few minutes). They join the list when it is next rebuilt, which happens outside the game (`tools/BisPlanner/build_db.py` in the addon's source).
- The class rules (who wears plate, who uses which weapons) are Classic's.
