# Mana Piñata

A blue piñata swings over the nameplate of every enemy that has Judgement of Wisdom on it, and that enemy's health bar turns mana blue. Hit that enemy and you get mana back, so now you can see which one it is without reading debuff icons.

Any paladin's Judgement of Wisdom counts, not only your own. The piñata drops in when the debuff lands; when it runs out the piñata goes away and the health bar gets its own colour back.

For WoW Forever (Interface 16001).

## Setup

1. Copy the `ManaPinata` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\ManaPinata\ManaPinata.toc` (not `AddOns\ManaPinata\ManaPinata\...`).
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.
3. Enemy nameplates must be on (V).
4. `/pinata test` puts a test piñata on every nameplate, so you can size and place it without a paladin around.

## Commands

| Command | What it does |
| --- | --- |
| `/pinata` | Current settings and the command list |
| `/pinata config` | The options window (also: left-click the minimap button, or Options > AddOns) |
| `/pinata test` | A test piñata on every nameplate, on / off. Also a right-click on the minimap button |
| `/pinata size <16-96>` | How big the piñata is (44 by default) |
| `/pinata y <n>` / `/pinata x <n>` | Move it up or down / left or right |
| `/pinata swing` | Swinging on / off |
| `/pinata bar` | Blue health bar on / off |
| `/pinata minimap` | Minimap button on / off |
| `/pinata on` / `off` / `reset` / `debug` | Enable, disable, defaults, bug-report info |

## Notes

- **Works in fights.** During fights the game hides debuffs from addons. The piñata is drawn on one of the game's own aura slots, which the game shows and hides itself, so the addon never has to read the debuff.
- **Other nameplate addons** (BetterBlizzPlates and the like) keep working. If their debuff icons sit where the piñata hangs, move it with the two sliders or `/pinata y` and `/pinata x`.
- **The blue health bar** is a blue copy of the bar's fill laid over it, so the bar's real colour (threat, class, whatever another addon set) is untouched underneath and comes back by itself. It shrinks with the enemy's health like the bar does. Text that another addon draws directly on the health bar can end up under the blue; if that bothers you, `/pinata bar` turns it off.
- **Test piñatas** hide the real ones while they are up, and end by themselves when a fight starts.
- **Swing** changes made in the middle of a fight reach piñatas that are already up when the fight ends.
- **Friendly targets** never get one: the game only allows this kind of check for debuffs on enemies.
- If a Judgement of Wisdom doesn't get a piñata, target that enemy outside a fight and type `/pinata debug`: it prints the spell IDs the addon looks for and the one on your target. The addon also picks up a new ID by itself the first time it sees the debuff outside a fight.
- This version has been checked with an offline test only, not yet in the game.
