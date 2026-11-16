# Cozy Counter

For WoW Forever (Interface 16001). Reminds you of the three XP buffs the game gives and counts the experience you lost while one of them was missing.

## What it does

- **Reminder.** One greyed-out buff icon per missing buff, built as the game's own buff icon (`AuraButtonArtTemplate`: 30 px icon, 5 px apart). It shows only out of a fight, alive, on the ground and (by default) outside inns and cities. It is off at max level or with XP gain switched off. Hover an icon for what the buff gives, how to get it, and what missing it has cost you; left-click prints the count in chat; right-click opens the options; drag moves the icons (lock them in the options; size with the "Icon size" slider).
  - **Well Fed** icon while you are not Well Fed.
  - **Well-Rested** icon while you have fewer than 3 stacks, and only once you carry a Cozy Sleeping Bag (option). With 2 stacks it shows "2" at the bottom right, as the buff itself does.
  - **Camp Tent** icon while your rested XP is below what a tent gives (5% of a level) and you have not had the tent's top-up this hour (no Boosted Rest debuff).
- **Lost XP.** Every XP gain while a buff is missing adds what that buff would have added: per buff and in total, for this session and all-time on this character (saved per character). At every level-up a chat line says what missing buffs cost on that level (option).
- **Where to see it:** the reminder's tooltip, the minimap button's tooltip, the level-up line, `/cozy`.

## Commands

`/cozy` what you lost, `/cozy options`, `/cozy on` / `off`, `/cozy lock` / `unlock`, `/cozy test` (show all three icons for placing them), `/cozy reset session`, `/cozy reset all` (clears this character's all-time count), `/cozy status` (what the addon sees now), `/cozy buffs` (XP buffs it has learned from tooltips).

## The buffs on WoW Forever, and what is assumed

Found on 2026-11-14. Not seen in the game by this addon's author: check `/cozy status` and the percent sliders.

| Buff | What it gives | How the addon knows it |
|---|---|---|
| Well Fed (cooked food) | +5% experience from kills, about 15 min, lost on death (Warcraft Tavern, "Cooked Food Provides an XP Buff", and its Experience guide) | buff named "Well Fed", or any buff whose tooltip says it raises experience from kills (learned, `/cozy buffs`) |
| Well-Rested (Cozy Sleeping Bag, item 211527) | +1% experience a stack, one stack a minute lying in the bag, 3 stacks most; lasts 2 hours, kept through death (Warcraft Tavern Cozy Sleeping Bag guide, spell 429959; Destructoid) | spell 429959 or a buff named "Well-Rested" |
| Camp Tent at a campfire (Leatherworking) | tops your rested XP up to 5% of a level, no effect if you already have more; then the debuff Boosted Rest (spell 1229451): "You cannot gain more rested experience from a Camp Tent for 1 hour" (Warcraft Tavern camping guides, wowforeverleveling.com) | your rested XP (`GetXPExhaustion`) and the Boosted Rest debuff |

No source names a campfire buff that raises experience by itself: the campfire's own buff (Welcoming Campfire) only unlocks the camp features, which are stat buffs. So "the campfire XP buff" is taken to be the Camp Tent's rested top-up, which you can only get at a campfire.

How the loss is worked out, per XP gain:

1. The kill line in chat gives the XP and its rested part (`+N exp Rested bonus`). Other XP (quests, exploration) is read from the XP bar.
2. The part that is not rested is divided by (1 + the percent of the buffs you had) to get the base XP.
3. Well Fed missing: base x 5% (kills only). Well-Rested short of 3 stacks: base x 1% per missing stack (kills, and quests too unless you untick "Well-Rested counts on quests": the buff only says "experience gains"). Buffs are assumed to add up, not multiply.
4. Camp Tent missing: the counter pretends you sat at a tent the moment you needed it, once an hour: it would have topped your rested XP up to 5% of a level, and rested XP doubles a kill's base XP until it runs out. Whatever part of a kill your own rested XP did not double comes out of that pretend pool, as lost.

Every percent is a slider in the options. The food and bag percents are learned from the buff tooltips when they say a number, unless you set them yourself.

## Secret values

In a fight the game can hide auras, XP and chat text. The addon reads the buffs once more when the fight starts and uses that read until it can see them again, letting each buff run out at its due time. A secret chat line still counts from the XP bar (as a kill); a secret XP bar still counts from the chat line. The reminder is never shown in a fight.

## Files

`Core.lua` (buffs, counting, slash command), `UI.lua` (the reminder), `Kit.lua` (shared options window and minimap button, a copy of `shared/Kit.lua`), `Options.lua`. Tests: `python tests/CozyCounter/run.py`.

A new addon needs only a `/reload` on WoW Forever.
