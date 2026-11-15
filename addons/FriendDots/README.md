# Friend Dots

Friendly player nameplates become a small class-coloured dot (or a round class icon) with a hairline health indicator. Enemy nameplates are not touched.

It is meant for busy fights: battlegrounds, arenas and world PvP, where a wall of friendly health bars and names hides the enemies you want to see. A dot still tells you where each teammate is, what class they are and whether they are in trouble.

For WoW Forever (Interface 16001).

## What you see

- **Dot**: 12 px circle in the player's class colour with the nameplate's thin dark border.
- **Health**: a 2 px line under the dot, drawn with the nameplate's own health bar in the player's class colour (friendly nameplates colour health by class). It only appears when the player is missing health. Dead and offline players are dimmed.
- **Target**: the border of your target's dot turns white, as the game's nameplate border does. That dot is also drawn on top of its neighbours.
- **Your party**: members of your own party get a bigger dot (by the same ratio the world map uses for party members) and are drawn on top of other dots, so you can pick them out of the rest of the team.
- **Raid markers** (skull, star...) stay visible and sit above the dot.
- Blizzard's own friendly plate (bar, name, cast bar, buffs) is hidden while the dot is shown and comes back when the addon is off.

## Setup

1. Copy the `FriendDots` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\FriendDots\FriendDots.toc` (not `AddOns\FriendDots\FriendDots\...`).
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.
3. Friendly player nameplates must be on: `/fdots plates` (or Shift+V). Or let Friend Dots turn them on only during fights: `/fdots combat`.

## Commands

| Command | What it does |
| --- | --- |
| `/fdots` | Current settings and the command list |
| `/fdots config` | The options window (also: left-click the minimap button, or Options > AddOns) |
| `/fdots minimap` | Minimap button on / off. Right-clicking the button turns the dots on / off |
| `/fdots style dot` / `icon` | Dots, or round class icons with the same thin border |
| `/fdots size <4-64>` | Size of the current style (dot 12, icon 22 by default) |
| `/fdots hp bar` / `fill` / `off` | Health as a line under the dot, as the dot itself draining, or not at all |
| `/fdots hpfull` | Keep the health line visible at full health |
| `/fdots names off` / `target` / `all` | Name above the dot: never, only your target, or always |
| `/fdots where all` / `pvp` | Dots everywhere, or only inside battlegrounds and arenas |
| `/fdots group` | Highlight on members of your own party (bigger dot, drawn on top) on / off |
| `/fdots npcs` | Also turn friendly NPCs and pets into smaller green dots |
| `/fdots click on` / `off` | Friendly nameplates click-through (on by default). On means you can't click a teammate's plate to target them |
| `/fdots y <n>` | Move the dot up or down |
| `/fdots plates` | Turn friendly player nameplates on / off |
| `/fdots combat` | Friendly player nameplates (and so the dots) only in fights: on as a fight starts, off when it ends |
| `/fdots on` / `off` / `reset` / `debug` | Enable, disable, defaults, bug-report info |
| `/fdots preview` | One dot of each kind (plain, party, target, class icon, NPC) in the middle of the screen for a minute, with your current settings |

## Notes

- **Click-through** is on by default, so the invisible plate doesn't swallow clicks meant for the world or for an enemy standing behind a teammate. The price: you can't click a teammate's nameplate to target them (use the party or raid frames, or a key), and mouseover macros, mouseover healing and the right-click menu don't work on friendly nameplates. This goes for every friendly nameplate, also the ones Friend Dots leaves alone (friendly NPCs).
- **Healers** who target or heal by clicking nameplates: use `/fdots click off`. The whole invisible plate then takes clicks again, not just the dot.
- The click area can only change out of combat. A change made in combat is applied when combat ends, and `/fdots` says so.
- **BetterBlizzPlates** sets the same click area. While click-through is on, Friend Dots puts its own setting back whenever another addon changes it; with click-through off it leaves the other addon's setting alone.
- **Where it works**: wherever friendly nameplates show. `/fdots where pvp` limits it to battlegrounds and arenas. Players you can attack (a duel partner, for example) always keep their normal plate. If the game forbids addons from touching friendly nameplates somewhere, the normal plates show there.
- **Health in fights**: during fights the game hides other players' exact health from addons. The health line still works, because it is drawn by the game's own bar; the addon never reads the numbers.
- **Plates that appear mid-fight**: if the game hides who a new nameplate belongs to, it keeps its normal look until the fight ends, then turns into a dot. A dot that is already up stays up.
- **Crowds**: if dots climb into columns when many players stand together, friendly nameplate stacking is on. Turn it off in the game's nameplate options (or the friendly stacking option of your nameplate addon) so dots overlap on the spot instead.
- **Only in fights** (`/fdots combat`, or the "Friendly plates only in combat" tick in the options): the game's friendly player nameplates come on as a fight starts and go off when it ends, after zone changes and at log-in. This works everywhere, whatever `where` is set to. Shift+V or `/fdots plates` still work, until the next fight or zone change. Turning the option off, or turning the dots off, puts your own nameplate setting back. With **BetterBlizzPlates**, Friend Dots writes its value again after BetterBlizzPlates applies its per-zone nameplate setting.
- **Names**: `names all` is fine for a small group. In a battleground use `names target`.
- **Fill mode** only works with dots: with icons the health line is used instead.
- This version has been checked with an offline test only, not yet in a real battleground or arena. If something looks wrong, `/fdots debug` prints what a bug report needs.
