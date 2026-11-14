# Abandon Advisor

A WoW Forever addon (Interface 16001) that rates every quest in your log and tells you which ones to abandon when you need room.

Open it with `/abandon` (or `/aa`). It also opens by itself when the game refuses a quest because your log is full.

## What it tells you

- **Hand in** (blue): the quest is finished. Handing it in frees the slot and costs nothing, so do these first.
- **Abandon** (red), **Maybe** (yellow), **Keep** (green): a score from the rules below. Hover a quest to see every reason and its points.
- **» marked quests**: the best ones to drop to reach your free-slot target (3 by default, change it with the - / + buttons).

Each quest has an Abandon button, which always asks before it abandons. Click a quest to show it in the quest log. Right-click to pin it as keep, so it is never suggested.

## The rules

Points toward abandoning: grey quest, far above your level, tiny XP, not started, group/dungeon/raid quest while you are solo, the only quest you have in another zone, repeatable, failed.

Points toward keeping: progress made, big XP, in your current zone, a zone holding four or more of your quests, item reward, class quest, legendary quest, and (with Questie installed) quests that lead to follow-ups or were started by an item.

## Install

1. Download `AbandonAdvisor-x.y.z.zip` from the latest release.
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns`, so you end up with `AddOns\AbandonAdvisor\AbandonAdvisor.toc`.
3. Restart the game.

## Commands

`/abandon` or `/aa`: no argument opens the window. `list` prints the advice in chat, `free <n>` sets the free-slot target, `auto` toggles opening on a full log, `unpin` releases all pinned quests, `scale <n>`, `reset`, `debug`.
