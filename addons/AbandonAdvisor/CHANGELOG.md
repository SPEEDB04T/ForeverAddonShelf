## 1.3.0
- Drop rates count: with Questie installed, a quest whose items rarely drop scores higher for abandoning, by how many kills the items you still need should take. Hover a quest to see the item, its drop rate and the kills left. `/abandon drops` or the options turn it off.
- Group: when a group member abandons a quest you also have, you are asked whether to abandon it too, and the quest scores higher. Your own abandons are sent to your group the same way (an addon message, nothing in chat). Both sides need Abandon Advisor. `/abandon group` and `/abandon share`, or the options, turn each half off.
- Looks like the game: the Abandon Advisor window is now the game's own framed window (book portrait, title bar, inset list on the quest log's parchment, buttons along the bottom) instead of a dark box. Each quest shows the game's ready-check tick, cross or question mark (or the turn-in mark) instead of a coloured stripe, the quest log's own highlight under the mouse, and the game's red, yellow, green and blue text colours. Tooltips use the game's gold labels, white values and grey hints.

## 1.2.0
- Options window: `/abandon config`, a right-click on the minimap button, or Options > AddOns. Every setting is a tick, a choice or a slider there.
- Minimap button: left-click opens or closes the window, right-click opens the options, drag moves it. `/abandon minimap` hides it.
- In the addon list next to the minimap, a right-click now opens the options.

## 1.1.0
- The advice now lives in the game's quest log: with ForeverCore installed, Abandon Advisor is a side tab of the quest log (world map), with the same list, Abandon buttons, pins and free-slot target as the window.
- Without ForeverCore, the quest log gets a side button that opens the window.
- /abandon log opens the quest log on the Abandon Advisor tab.
- Fixed the window's row layout: rows and their text were pinned in a way that let the game stretch them.

## 1.0.0
- First release for WoW Forever (Interface 16001).
- Rates every quest in the log: Hand in, Abandon, Maybe or Keep, with the reasons on hover.
- Marks the best quests to drop to reach a free-slot target.
- Abandon button per quest (always confirms), pin quests as keep, opens when the quest log is full.
- /abandon, /abandon list, /abandon free, /abandon auto, /abandon debug.
