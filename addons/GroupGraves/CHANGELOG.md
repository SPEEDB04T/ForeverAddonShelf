# Changelog

## 1.3.4

- When the options window or the minimap button is missing (the addon was copied in while the game ran), the chat line now says a `/reload` brings them, not a game restart: on WoW Forever a `/reload` loads new files. The setup steps in the README say the same.

## 1.3.3

- Fixed: no message from anyone was taken, not even your own coming back, so positions were never shared. On WoW Forever the game gives an addon a member's first name and their surname apart ("Bunglfart", "Dunglode"), while a message arrives from "Bunglfart Dunglode", and the addon compared the first name alone. A member is now known by both together, the sender is matched against that first and the first name only when no one else shares it.
- Names show as "First Last" in the tooltip, under the marker, in the chat line and in `/graves list`.

## 1.3.2

- The map markers and their tooltip are listed for LookShots, the developer's screenshot helper, so they can be checked against the game's own look. Without LookShots installed nothing changes.

## 1.3.1

- The options window and the minimap button are redrawn by the shared kit: they now copy the game's own Options rows and its round minimap button.
- Two option labels are shorter, so every row stays one line: "Battlegrounds and arenas too" and "Show test markers". The rest of each sentence is in the row's tip.

## 1.3.0

- Fixed: who sent a message is now found in the group by the whole name ("First Last", with the space). The realm part of a sender, which the server spells unlike your client (`CAMWOWUS1Realm9RPPvP` against `RPPvP`), only decides between two members with the same name. Before, your own messages coming back to you were taken for someone else's, and you could get a marker on your own corpse.
- Names inside passed-on positions are found the same way.
- `/graves status` and `/graves debug` count messages that were not taken, and why: the sender is not in the group, the game hid who sent them, or the game hid the group's names at the time.
- The last 40 messages out and in are saved in `GroupGravesDB.commLog` (time, out or in, channel, sender, the group member it was found to be, what the game said to a send, the start of the message), to find out afterwards what happened in a session.

## 1.2.0

- A marker is now exactly the game's own corpse marker: the same size, and nothing added to it. The class-coloured dot at its corner and the glow under the mouse are gone. Whose corpse it is shows in the tooltip (name in the class colour), or under the marker with "Names under the markers".
- Names under the markers use the game's outlined small font.

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
