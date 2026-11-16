# Aura Advisor

For Paladins. Tells you when another aura fits the fight better, on the game's own stance bar: Fire Resistance when Fire hits are landing on you and your party, Concentration when your casts keep getting pushed back, Devotion or Retribution for melee, and back to your usual aura when the fight is over. It has no bar or frame of its own.

For WoW Forever (Interface 16001).

## What it looks at

| Aura | Gets suggested when |
| --- | --- |
| Devotion | Physical hits land on you and your party, more so when crits and crushing blows land. A tank's and healer's usual aura. |
| Retribution | Physical hits land (each one hits back). A damage paladin's usual aura; a tank's pick against three or more enemies. |
| Concentration | Your casts, or your party's, are pushed back by hits. |
| Fire / Frost / Shadow Resistance | Hits of that school land on you and your party; an enemy is casting a spell of that school (the game shows its name). |

Only what actually happens counts: hits taken, casts pushed back, enemy spells seen being cast. What an enemy is (its class, an elite or a boss) and what it might cast count for nothing, and in a fight no switch is suggested that can't say what caused it (`/aura` shows it).

Hits on you count more than hits on your party. A party member's hits on themselves (a warlock's own Hellfire, Life Tap) don't count. Everything fades over a few seconds, so the advice follows the fight. A switch costs a global cooldown, so another aura has to be clearly ahead before it is suggested, and one stray Fire hit changes nothing.

If another paladin in your party already has an aura up (seen on your buffs, or when they cast one), that aura is never suggested: two of the same aura give nothing extra. Its tooltip says "Already up"; /aura says who has it.

The play style comes from your group role, or Righteous Fury (tank), or is damage otherwise. You can set it yourself.

## On your bars

- **The aura to switch to glows** with the game's own proc glow, on its button on the stance bar and on any action bar button that holds it (a macro that casts it counts too). In a fight the glow stays until you switch, another aura takes over or the fight ends; a pause in the hits doesn't take it down.
- **Hover an aura** on the stance bar or an action bar: under the game's own tooltip, "Switch now" and the cause in grey ("8 Fire hits", "Shadow Bolt, 2 hits", "3 pushbacks") on the aura to switch to; that aura's name on the one you have on; "Already up" on one another paladin has. The tooltip is the only place a cause shows.
- In a fight a sound plays and the aura's icon and name appear in the middle of the screen when a switch is suggested, nothing more. Each can be turned off, and so can the glow. A chat line only if you turn it on (`/aura chat`).
- **The minimap button's tooltip** shows the aura on ("Devotion Aura", or "No aura") and, in green, the one to switch to.

## Setup

1. Copy the `AuraAdvisor` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\AuraAdvisor\AuraAdvisor.toc`.
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.
3. `/aura test fire` shows what a suggestion looks like without a fight.

## Commands

| Command | What it does |
| --- | --- |
| `/aura` | One line: the aura on, the one to switch to and why |
| `/aura config` | The options window (also: left-click the minimap button, or Options > AddOns) |
| `/aura style auto\|damage\|tank\|healer` | What the advice is for |
| `/aura default auto\|devotion\|retribution\|concentration` | Your aura between fights |
| `/aura sens low\|normal\|high` | How quickly it suggests a switch |
| `/aura glow` / `sound` / `banner` / `chat` / `between` | Switch the glow, the sound, the line on screen, the chat line, or the between-fights suggestion on or off |
| `/aura test fire\|frost\|shadow\|melee\|push\|off` | A pretend fight |
| `/aura minimap` / `reset` / `debug` | The rest (`debug` also lists every aura's points) |

## Notes

- **What the game lets an addon see.** WoW Forever hides the combat log from addons and hides damage numbers in fights. The damage school of each hit on you and your party is still shown, and so are pushed-back casts; those are what the advice mostly rests on. Enemy spell names are often hidden too: such a cast counts for no aura, only the hits it lands do. `/aura debug` shows how much of each the game let through.
- **Only the game's own bars.** The glow goes on the stance bar and the game's action bars. Bars from other addons (Bartender, Dominos and the like) don't get it; the tooltip line, the sound and the line on screen still work there.
- **Dead or a ghost?** It says nothing until you're back on your feet.
- **Hidden stance bar?** Then the glow shows only on action bar buttons that hold the aura.
- This version has been checked with an offline test only, not yet in the game.
