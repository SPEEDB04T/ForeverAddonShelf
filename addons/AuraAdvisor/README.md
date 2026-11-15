# Aura Advisor

For Paladins. Tells you when another aura fits the fight better, on the game's own stance bar: Fire Resistance when Fire hits are landing on you and your party, Concentration when your casts keep getting pushed back, Devotion or Retribution for melee, and back to your usual aura when the fight is over. It has no bar or frame of its own.

For WoW Forever (Interface 16001).

## What it looks at

| Aura | Gets suggested when |
| --- | --- |
| Devotion | Physical hits land on you and your party, more so from elites, bosses, crits and crushing blows. A tank's and healer's usual aura. |
| Retribution | Physical hits land (each one hits back). A damage paladin's usual aura; a tank's pick against three or more enemies. |
| Concentration | Your casts, or your party's, are pushed back by hits. |
| Fire / Frost / Shadow Resistance | Hits of that school land on you and your party; an enemy is casting a spell of that school; an enemy Mage, Warlock or Priest is in the fight. |

Hits on you count more than hits on your party. Everything fades over a few seconds, so the advice follows the fight. A switch costs a global cooldown, so another aura has to be clearly ahead before it is suggested, and one stray Fire hit changes nothing.

If another paladin in your party already has an aura up (seen on your buffs, or when they cast one), that aura is never suggested: two of the same aura give nothing extra. Its tooltip line says who has it up.

The play style comes from your group role, or Righteous Fury (tank), or is damage otherwise. You can set it yourself.

## On your bars

- **The aura to switch to glows** with the game's own proc glow, on its button on the stance bar and on any action bar button that holds it (a macro that casts it counts too). In a fight the glow stays until you switch, another aura takes over or the fight ends; a pause in the hits doesn't take it down.
- **Hover an aura** on the stance bar or an action bar: under the game's own tooltip, a line says why to switch to it, or what speaks for or against it.
- In a fight a sound plays and a line appears in the middle of the screen when a switch is suggested, with the reason. Each can be turned off, and so can the glow.
## Setup

1. Copy the `AuraAdvisor` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\AuraAdvisor\AuraAdvisor.toc`.
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.
3. `/aura test fire` shows what a suggestion looks like without a fight.

## Commands

| Command | What it does |
| --- | --- |
| `/aura` | What the advisor thinks right now, and why |
| `/aura config` | The options window (also: left-click the minimap button, or Options > AddOns) |
| `/aura style auto\|damage\|tank\|healer` | What the advice is for |
| `/aura default auto\|devotion\|retribution\|concentration` | Your aura between fights |
| `/aura sens low\|normal\|high` | How quickly it suggests a switch |
| `/aura glow` / `sound` / `banner` / `chat` / `between` | Switch the glow, the sound, the line on screen, the chat line, or the between-fights suggestion on or off |
| `/aura test fire\|frost\|shadow\|melee\|push\|off` | A pretend fight |
| `/aura minimap` / `reset` / `debug` | The rest |

## Notes

- **What the game lets an addon see.** WoW Forever hides the combat log from addons and hides damage numbers in fights. The damage school of each hit on you and your party is still shown, and so are pushed-back casts; those are what the advice mostly rests on. Enemy spell names are often hidden too: then a cast counts as "an enemy is casting something" and is shared out among the schools that have hit you so far. `/aura debug` shows how much of each the game let through.
- **Only the game's own bars.** The glow goes on the stance bar and the game's action bars. Bars from other addons (Bartender, Dominos and the like) don't get it; the tooltip line, the sound and the line on screen still work there.
- **Dead or a ghost?** It says nothing until you're back on your feet.
- **Hidden stance bar?** Then the glow shows only on action bar buttons that hold the aura.
- This version has been checked with an offline test only, not yet in the game.
