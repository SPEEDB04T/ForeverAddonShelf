# Abandon Advisor

A WoW Forever addon (Interface 16001) that rates every quest in your log and tells you which ones to abandon when you need room.

It sits in the game's quest log: open the map / quest log and click the Abandon Advisor side tab (the book icon). The tab needs the ForeverCore addon, which the other Forever addons already use; without it the quest log gets a side button that opens the Abandon Advisor window instead.

The window also opens with `/abandon` (or `/aa`), and by itself when the game refuses a quest because your log is full.

## What it tells you

- **Hand in** (blue, the quest giver's turn-in mark): the quest is finished. Handing it in frees the slot and costs nothing, so do these first.
- **Abandon** (red cross), **Maybe** (yellow question mark), **Keep** (green tick): a score from the rules below. Hover a quest to see every reason and its points.
- **» marked quests**: the best ones to drop to reach your free-slot target (3 by default, change it with the - / + buttons).

Each quest has an Abandon button, which always asks before it abandons. Click a quest to show it in the quest log. Right-click to pin it as keep, so it is never suggested.

## The rules

Points toward abandoning: grey quest, far above your level, tiny XP, not started, group/dungeon/raid quest while you are solo, the only quest you have in another zone, repeatable, failed, a low drop rate, a group member abandoned it.

Drop rates need Questie. For each item a quest still needs from kills, the addon takes the best drop rate Questie lists and works out the kills left (5 more at 10% is about 50 kills). Up to a dozen kills costs nothing; beyond that the quest gains a point per 2.5 kills, up to 25. Items you can also pick up from an object or buy are left out.

Points toward keeping: progress made, big XP, in your current zone, a zone holding four or more of your quests, item reward, class quest, legendary quest, and (with Questie installed) quests that lead to follow-ups or were started by an item.

## In a group

When a group member abandons a quest that is also in your log, Abandon Advisor says so in chat, asks whether you want to abandon it too (Abandon / Keep), and adds 30 points to that quest until you answer Keep or leave the group. Nothing is asked for a finished or pinned quest, and the question waits until you are out of combat.

The game does not tell addons when someone else abandons a quest, so this works through Abandon Advisor itself: each copy tells the group when its player abandons a quest (an addon message, nothing appears in chat). A group member without Abandon Advisor is not noticed. Either half can be turned off in the options.

## Install

1. Download `AbandonAdvisor-x.y.z.zip` from the latest release.
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns`, so you end up with `AddOns\AbandonAdvisor\AbandonAdvisor.toc`.
3. Restart the game.

## Commands

`/abandon` or `/aa`: no argument opens the window. `config` opens the options window (also: right-click the minimap button, or Options > AddOns), `minimap` shows or hides the minimap button, `log` opens the quest log on the Abandon Advisor tab, `list` prints the advice in chat, `free <n>` sets the free-slot target, `auto` toggles opening on a full log, `drops` toggles the drop-rate rule, `group` toggles the group suggestions, `share` toggles telling your group about your abandons, `unpin` releases all pinned quests, `scale <n>`, `reset`, `debug`.
