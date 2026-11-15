# Changelog

## 1.4.2

- Lists one dot of each kind (plain, party, target, class icon, NPC) for the author's screenshot helper, so the look can be checked from game screenshots. Nothing changes in game without that helper.

## 1.4.1

- The options window and the minimap button are redrawn by the shared kit: they now copy the game's own Options rows and its round minimap button.
- Shorter option names, so every row fits on one line: "Health line at full health", "Click through hidden plates", "Friendly player nameplates", "Friendly plates only in combat". The rest of each sentence is in the row's tooltip.

## 1.4.0

The dots are built like the game's own nameplate.

- One border: the nameplate's thin black border, which turns white on your target, as the game's plate does. The separate white ring and its dark edge are gone.
- Your own party: a bigger dot (by the ratio the world map uses for party members, so 12 px becomes 16 px), drawn on top. The gold ring is gone; the game marks no one with a coloured ring.
- Health line: the nameplate's own health bar art, in the player's class colour as friendly nameplates show it. It no longer turns red at low health; the game's plate doesn't either.
- Names: the nameplate's own outlined name font, 4 px above the dot.
- Class icons: no class-coloured rim, the same thin border as the dots.
- Raid markers: the game's 22 px, 10 px above the name when names are shown, as on a plate that shows only a name.

## 1.3.0

Friendly nameplates only in fights, and colours that match the game.

- New option "Friendly nameplates only in combat" (`/fdots combat`, off by default): friendly player nameplates, and so the dots, come on as a fight starts and go off when it ends. Turning it off puts your own nameplate setting back.
- The health line uses the game's own status bar texture and health-bar green.
- Colours come from the game: party ring in the game's gold, target ring in its white, friendly NPC dots in its friendly green, unknown players in its grey, low health in its red.

## 1.2.1

Your own party is easier to see.

- The gold ring is twice as wide and has a dark edge, so it shows on bright ground and next to yellow classes.
- Party members' dots are a quarter bigger and are drawn on top of other dots (your target still goes above everything).
- The target ring, the name and the raid marker move out to make room for the gold ring.

## 1.2.0

Options window and minimap button.

- Options window: `/fdots config`, a left-click on the minimap button, or Options > AddOns. Every setting is a tick, a choice or a slider there, with separate sliders for the dot and the icon size.
- Minimap button: left-click opens the options, right-click turns the dots on or off, drag moves it. `/fdots minimap` hides it.
- The addon is in the addon list next to the minimap.

## 1.1.0

Changes from a review with PvP use in mind.

- A dot now needs the game to confirm the player is friendly. When the game hides that in a fight, a dot that is already up stays, a new plate keeps its normal look, and everything is checked again when the fight ends. Before, dots could drop back to full plates mid-fight, and a player who merely couldn't be attacked could get a dot.
- Raid target markers stay visible and sit above the dot.
- Gold ring on members of your own party (`/fdots group`).
- Your target's dot is drawn on top of its neighbours, and the white target ring has a dark edge so it shows on snow and bright spell effects.
- Dead players are dimmed even when the game hides that from addons; offline players are dimmed too.
- `/fdots where pvp`: dots only inside battlegrounds and arenas.
- Click-through: Friend Dots puts its setting back when another addon (BetterBlizzPlates) changes the friendly click area, and gives the other addon's setting back when click-through is turned off. `/fdots click on` / `off`; a change made in combat is announced and applied after combat.
- The hidden Blizzard plate gets back the transparency it had, not always full.
- A dot keeps its class colour if the game hides the class mid-fight.
- Fill mode: the drained part of the dot is no longer near black for dark classes. Names have an outline.
- The health indicator only switches itself off after three errors in a row, and `/fdots hp bar` switches it back on.
- A one-line message on first login points to `/fdots`.

## 1.0.0

- Friendly player nameplates become class-coloured dots or round class icons.
- Health line under the dot (only when hurt, red below 35%), or the dot itself draining, or off.
- White ring on your target, optional names, optional dots for friendly NPCs and pets.
- Friendly nameplates click-through by default.
