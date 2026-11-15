# Snakes Warlock Helper

A quiet helper for warlocks on WoW Forever. It is built to grow: each feature is its own file and gets its own tab in the window.

## What it does now

### Buff reminders

A small row of icons appears only while something is missing, and disappears when it is fixed.

- **No demon out** (waits 4 seconds; stays quiet after Demonic Sacrifice unless you have Demonic Pact)
- **Soul Link** not on your demon
- **Demon Armor / Demon Skin** missing, or under 2 minutes left when you are out of combat
- **Firestone / Spellstone** missing from your weapon, or about to run out

Out of combat, click an icon to cast the missing buff. During a fight the icons only show: the game doesn't let addons put up clickable cast buttons mid-combat. The icons look like action bar buttons: purple border = missing, orange = running out (with a countdown).

Right-click an icon to quiet it for 10 minutes. Shift + right-click turns that reminder off. Nothing shows while you are dead or mounted.

### Demon comparison

`/swh` opens a window that ranks your demons by the damage each one is worth right now:

- **the demon's own damage**: its melee, measured from the demon while it is out, plus Firebolt or Lash of Pain from the in-game tooltip, with Unholy Power, Improved Imp / Sayaad, Master Demonologist, Soul Link and the orc racial applied
- **what it adds to your spells**: Soul Link, Master Demonologist and Demonic Knowledge, turned into dps using an estimate of your own dps (or the number you give with `/swh dps`)
- **Demonic Sacrifice**: what sacrificing the right demon adds, and whether that beats keeping one out

WoW Forever doesn't let addons read the combat log, so this is a model, not a meter. Melee is taken from each demon's character-sheet numbers the first time you have it out (out of combat) and remembered, with its age shown. A melee demon you haven't summoned yet shows "summon it once to measure it". Hover a row for the breakdown.

Not counted: Demonic Brand, mana, and anything a demon does besides damage.

## Commands

| Command | What it does |
| --- | --- |
| `/swh` | open or close the window |
| `/swh options` | open the options tab (also: right-click the minimap button) |
| `/swh minimap` | show or hide the minimap button |
| `/swh move` | unlock or lock the reminder icons so you can drag them |
| `/swh school shadow` / `fire` | which of your spells the demon bonuses count for |
| `/swh dps 450` / `auto` | your own dps, or let the addon estimate it |
| `/swh reset` | put the window and reminders back where they started |
| `/swh demo` | sample reminders and numbers; works on any class |
| `/swh debug` | print what the addon reads (talents, demon, buffs) |

`/snakes` works too.

## Install

Copy the `SnakesWarlockHelper` folder into `World of Warcraft\_forever_\Interface\AddOns\` and restart the game.

## Adding a feature

Add a Lua file to the `.toc` after `State.lua`. Read the game through `ns.State`, listen with `ns.On(event, fn)`, and add a tab with `ns.Panel.AddTab(key, label, build, refresh)`.

Tests: `python tests/SnakesWarlockHelper/run.py` (needs `pip install lupa==2.4`).
