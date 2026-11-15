# Changelog

## 1.3.0

- The window now looks like one of the game's tooltips: tooltip border and background instead of the flat dark box, a gold title, the quest log's highlight under the line the mouse is on, and the tooltip divider above the soulstones.
- All text uses the game's own colours (green, red, orange, yellow, grey, gold, white, light blue) instead of picked ones, in the window, its tooltips and the error line in chat.

## 1.2.1

- Fixed: healthstone and soulstone states were not shared with the group on ordinary realms. The addon read a realm setting ("this realm blocks addon messages") that has nothing to do with messages inside a group, and sent nothing. It now sends, and `/hst status` shows the game's answer if a message is ever refused.

## 1.2.0

Options window and minimap button.

- Options window: `/hst config`, a right-click on the minimap button, or Options > AddOns. Every setting is a tick, a choice or a slider there.
- Minimap button: left-click shows or hides the window, right-click opens the options, drag moves it. `/hst minimap` hides it.
- The addon is in the addon list next to the minimap.

## 1.1.0

Soulstones.

- New part under the list: who carries a soulstone and how long it lasts, and each warlock's own stone (ready, on cooldown, none in the bags).
- Read from everyone's buffs, so it works for players without the addon. A dead player with a soulstone shows `can res`.
- `/hst announce` adds a line about the soulstone; `/hst soul` hides the new part.
- Works alongside 1.0.0: players still on it show their healthstone as before, and a warlock on 1.0.0 shows `?` for their soulstone until they are seen using it.

## 1.0.0

First version.

- Window listing everyone in the party or raid with their healthstone: which one, none, or on cooldown.
- Players with the addon share their own bags with the group. Players without it are marked from trades and uses seen.
- Warlocks: click a name to open a trade with the stone in it; `/hst announce` posts who still needs one.
- `/hst demo` previews the window while solo.
