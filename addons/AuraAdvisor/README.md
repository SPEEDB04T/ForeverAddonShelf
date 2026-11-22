# Aura Advisor

For Paladins. Tells you when another aura fits the fight better, on the game's own stance bar: Fire Resistance when Fire hits are landing on you and your party, Concentration when your casts keep getting pushed back, Devotion or Retribution for physical hits, and back to your usual aura just after a fight. It also reminds a tank of Righteous Fury and keeps track of your blessings on the party. It has no bar or frame of its own, and the only sound is the Righteous Fury warning's.

For WoW Forever (Interface 16001).

## What it looks at

| Aura | Gets suggested when |
| --- | --- |
| Devotion | Physical hits land on you and your party, more so when crits and crushing blows land. A tank's and healer's usual aura. |
| Retribution | Physical hits land (each one hits back). A damage paladin's usual aura; a tank's pick against three or more enemies. |
| Concentration | Your casts, or your party's, are pushed back by hits. |
| Fire / Frost / Shadow Resistance | Hits of that school land on two of you, or often on one of you; an enemy is casting a spell of that school at you or your party (the game shows its name). |

Only what actually happens counts: hits taken, casts pushed back, enemy spells seen being cast at you or your party. What an enemy is (its class, an elite or a boss) and what it might cast count for nothing, and in a fight no switch is suggested that can't say what caused it (`/aura` shows it).

Hits on you count more than hits on your party. Hits on a party member out of your aura's reach (about 40 yards, or out of sight) don't count: in a battleground your party is spread over the map. A party member's hits on themselves (a warlock's own Hellfire, Life Tap) don't count, nor do hits you are immune to, interrupted enemy casts, or casts at someone outside your party. One damage-over-time spell ticking on one of you isn't enough for a resistance aura. Everything fades over a few seconds, so the advice follows the fight. A switch costs a global cooldown, so another aura has to be clearly ahead before it is suggested, and one stray Fire hit changes nothing.

Back to your usual aura is suggested only for a minute after a fight (never in a battleground or arena, where fights stop and start all the time): an aura you keep on after that is your choice, and logging in with it suggests nothing. When the game won't say which aura you have on (right after dying, with the stance bar hidden), it doesn't guess "No aura".

If another paladin in your party already has an aura up (seen on your buffs, or when they cast one), that aura is never suggested: two of the same aura give nothing extra. Its tooltip says "Already up"; /aura says who has it.

The play style comes from your group role, or Righteous Fury (tank), or is damage otherwise. You can set it yourself.

## On your bars

- **The aura to switch to glows** with the game's own proc glow, on its button on the stance bar and on any action bar button that holds it (a macro that casts it counts too). In a fight the glow stays until you switch, another aura takes over or the fight ends; a pause in the hits doesn't take it down, but 20 seconds of other hits do (the Fire add is dead, the melee goes on).
- **Hover an aura** on the stance bar or an action bar: under the game's own tooltip, "Switch now" and the cause in grey ("8 Fire hits", "Shadow Bolt, 2 hits", "3 pushbacks") on the aura to switch to; that aura's name on the one you have on; "Already up" on one another paladin has. The tooltip is the only place a cause shows.
- In a fight the aura's icon and name appear in the middle of the screen when a switch is suggested, nothing more, and no sound. The line and the glow can each be turned off. A chat line only if you turn it on (`/aura chat`).
- **The minimap button's tooltip** shows the aura on ("Devotion Aura", or "No aura") and, in green, the one to switch to.
- One thing glows at a time: Righteous Fury first, then the aura to switch to, then a blessing. One with no button on your bars lets the next one glow.

## Righteous Fury

In a group, as a Protection paladin (tank role, the Tank play style, or most of your talent points in Protection), while Righteous Fury is off:

- a **raid warning**, "No Righteous Fury", shows in the middle of the screen with the game's raid warning sound: as a fight starts and every 8 seconds of it, when it comes off between fights (you died, joined a group, left town) and every 30 seconds after that. Not while mounted;
- its action button glows, and its tooltip says "Not on".

Cast it, in a fight too, and it all stops at once. Not solo, not in town or on a flight, not in a battleground or arena. `/aura fury` turns it off; `/aura furysound` turns off only the sound.

## Blessings

- **Hover a party member** (or yourself): under their tooltip, in grey, your blessing on them and its time left ("Might 4 min"), or "No blessing". Nothing on someone who has another paladin's blessing and none of yours.
- **Out of a fight, in a group**, a blessing you gave that ran out, or is about to (under a minute left, or a tenth of a long Greater Blessing), glows on its action button, and its tooltip says "Recast" and who needs it. Only people you blessed before count: the advisor doesn't choose blessings for you. Nobody who has that blessing from another paladin, is dead, offline or out of sight. The normal blessing glows when it's on your bars, else the Greater one.
- **The minimap button's tooltip** says "Blessed 3/5" when someone is missing yours.
- Buffs can only be read out of a fight (the game hides them in one); in a fight the last look stands. Not in town or on a flight. `/aura bless` turns it all off.

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
| `/aura glow` / `banner` / `chat` / `between` | Switch the glow, the line on screen, the chat line, or the between-fights suggestion on or off |
| `/aura fury` / `furysound` / `bless` | Switch the Righteous Fury reminder, its sound, or the blessing tracking, on or off |
| `/aura test fire\|frost\|shadow\|melee\|push\|off` | A pretend fight |
| `/aura minimap` / `reset` / `debug` | The rest (`debug` also lists every aura's points) |

## Notes

- **What the game lets an addon see.** WoW Forever hides the combat log from addons and hides damage numbers in fights. The damage school of each hit on you and your party is still shown, and so are pushed-back casts; those are what the advice mostly rests on. Enemy spell names are often hidden too: such a cast counts for no aura, only the hits it lands do. `/aura debug` shows how much of each the game let through.
- **Only the game's own bars.** The glow goes on the stance bar and the game's action bars. Bars from other addons (Bartender, Dominos and the like) don't get it; the tooltip line and the line on screen still work there.
- **In a raid** only your own party (your raid group of five) counts, as it does for an aura.
- **Dead or a ghost?** It says nothing until you're back on your feet.
- **Hidden stance bar?** Then the glow shows only on action bar buttons that hold the aura.
- This version has been checked with an offline test only, not yet in the game.
