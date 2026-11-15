# Changelog

## 1.3.3

- The options window and the minimap button are redrawn by the shared kit our addons use: the options now look like the game's own Options rows, and the minimap button is the game's round one.
- Two option names were too long and wrapped onto a second line. They are now "Show in every group" and "Click a name to trade a stone"; the rest of each sentence is in that option's tip.

## 1.3.2

- Fixed: other players' healthstones and soulstones may never have arrived. The server names the sender of an addon message with its own spelling of the realm ("CAMWOWUS1Realm9RPPvP" where the game says "RPPvP"), so the addon did not recognise anyone in the group and dropped every message without a word. It now finds the sender among the group by name and uses the realm only to tell two players of the same name apart. Names with a space ("First Last") work everywhere: the list, trades, soulstone messages.
- `/hst status` says how many addon messages came in and went out, and lists messages it ignored, from whom and why (not in the group, hidden by the game).
- The last 40 addon messages in and out are kept in the saved settings, to see afterwards what really happened.

## 1.3.1

- The window is now built like the game's own tooltip, part for part: the game's tooltip-style panel, a white title in the tooltip's heading font, tooltip-sized text and 12 px icons, the same spacing, and as wide as its longest line instead of cutting names off.
- Taken out because a tooltip has none of them: the icon before the title, the line between healthstones and soulstones (now a blank line), the highlight under the mouse, and the "1 up" / "none up" count beside "Soulstones".
- Fewer colours. Values are white, anything not usable right now or not known is grey, and only a missing stone ("none", "no stone") is red. Icons of stones a player lacks are greyed, no longer also faded.

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
