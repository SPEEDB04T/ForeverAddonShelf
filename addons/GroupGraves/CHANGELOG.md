# Changelog

## 1.1.0

- The markers look like the game's own map pins: the game's corpse tombstone at full size, with the class-coloured dot the map uses for group members at its corner, in place of the coloured ring and the dark disc. They brighten under the mouse.
- The tooltip uses the game's text colours (white for what happened, grey for where the position came from and the click hint) and opens away from the middle of the map, like the game's corpse tooltip.

## 1.0.1

- Fixed: positions were not shared with the group on ordinary realms. The addon read a realm setting ("this realm blocks addon messages") that has nothing to do with messages inside a group, and sent nothing. It now sends.

## 1.0.0

First version.

- A tombstone in the member's class colour on the world map where each group member died. It stays after they release and goes away when they are alive again.
- Positions are shared between everyone in the group who has the addon. Members without it are marked from where their dot was while they lay dead.
- Someone who joins later is told the positions by the group.
- Tooltip with who, when and where; click a marker for a waypoint to the corpse.
- `/graves test` shows three test markers around you.
- Options window (`/graves config`, the minimap button, or Options > AddOns): on / off, mark from the moment of death, size, names, battlegrounds, chat line.
