# Aura Advisor

For Paladins. A row of aura buttons that tells you when another aura fits the fight better: Fire Resistance when Fire hits are landing on you and your party, Concentration when your casts keep getting pushed back, Devotion or Retribution for melee, and back to your usual aura when the fight is over. Click a button to switch.

For WoW Forever (Interface 16001).

## What it looks at

| Aura | Gets suggested when |
| --- | --- |
| Devotion | Physical hits land on you and your party, more so from elites, bosses, crits and crushing blows. A tank's and healer's usual aura. |
| Retribution | Physical hits land (each one hits back). A damage paladin's usual aura; a tank's pick against three or more enemies. |
| Concentration | Your casts, or your party's, are pushed back by hits. |
| Fire / Frost / Shadow Resistance | Hits of that school land on you and your party; an enemy is casting a spell of that school; an enemy Mage, Warlock or Priest is in the fight. |

Hits on you count more than hits on your party. Everything fades over a few seconds, so the advice follows the fight. A switch costs a global cooldown, so another aura has to be clearly ahead before it is suggested, and one stray Fire hit changes nothing.

If another paladin in your party already has an aura up (seen on your buffs, or when they cast one), that aura is greyed out and never suggested: two of the same aura give nothing extra.

The play style comes from your group role, or Righteous Fury (tank), or is damage otherwise. You can set it yourself.

## The frame

The buttons look like the game's stance-bar buttons, in a panel with the game's tooltip border.

- The game's spell-alert glow (like a proc) and "Switch to ...": the suggestion, with the reason under it.
- Pressed in (lit like a checked action button): the aura that is on.
- Greyed: another paladin already has it up.
- Hover a button for the game's spell tooltip, with the advice under it.
- Left-click a button: switch to that aura. Right-click: every aura's points in chat.
- Drag the frame by the text under the buttons. In a fight a sound plays and a line appears in the middle of the screen when a switch is suggested (both can be turned off).

## Setup

1. Copy the `AuraAdvisor` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\AuraAdvisor\AuraAdvisor.toc`.
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.
3. `/aura test fire` shows what a suggestion looks like without a fight.

## Commands

| Command | What it does |
| --- | --- |
| `/aura` | What the advisor thinks right now, and why |
| `/aura config` | The options window (also: left-click the minimap button, or Options > AddOns) |
| `/aura show always\|combat\|never` | When the frame is on screen |
| `/aura style auto\|damage\|tank\|healer` | What the advice is for |
| `/aura default auto\|devotion\|retribution\|concentration` | Your aura between fights |
| `/aura sens low\|normal\|high` | How quickly it suggests a switch |
| `/aura sound` / `banner` / `chat` / `between` | Switch the sound, the line on screen, the chat line, or the between-fights suggestion on or off |
| `/aura test fire\|frost\|shadow\|melee\|push\|off` | A pretend fight |
| `/aura lock` / `unlock` / `scale <0.5-2>` / `minimap` / `reset` / `debug` | The rest |

## Notes

- **What the game lets an addon see.** WoW Forever hides the combat log from addons and hides damage numbers in fights. The damage school of each hit on you and your party is still shown, and so are pushed-back casts; those are what the advice mostly rests on. Enemy spell names are often hidden too: then a cast counts as "an enemy is casting something" and is shared out among the schools that have hit you so far. `/aura debug` shows how much of each the game let through.
- **Buttons in fights.** The game doesn't let addons add, remove or move click-to-cast buttons in a fight, so there is a button for every aura you know and only the glow and colours change. Settings that change the frame (hide it, size) wait for the fight to end.
- **Learned a new aura in the middle of a fight?** Its button appears when the fight is over.
- Clicking the aura that is already on does nothing (so it can't switch your aura off by accident).
- This version has been checked with an offline test only, not yet in the game.
