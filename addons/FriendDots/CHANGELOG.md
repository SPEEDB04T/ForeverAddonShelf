# Changelog

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
