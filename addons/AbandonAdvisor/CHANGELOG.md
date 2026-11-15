## 1.4.1
- Options window and minimap button redrawn by the shared kit: the options are now the game's own Options rows, and the minimap button is the game's round minimap button.
- Shorter option names so each fits on one line: "Count low drop rates", "Suggest group abandons", "Share my abandons", "Open when the log is full". The rest of each explanation is in its tip.

## 1.4.0
- Hand-in route: your finished quests are listed in the order that makes the shortest trip from where you stand, one stop per quest giver ("Stop 2 of 4: Elwynn Forest, 300 yds"). The summary gives the whole route's length. Turn-in places come from the game's own quest pins; with Questie installed, Questie places the ones the game has no pin for. Stops on another continent come last, in order but without distances. `/abandon route` prints the route in chat.
- Right-click a finished quest and choose Super Track: the game's quest arrow points at that stop, and once you hand it in it moves to the next stop on its own. Tracking anything else ends that; `/abandon route next` starts at the first stop, `/abandon route stop` ends it.
- Looks more like the quest log: every quest is the quest log's own row (gold title in the game's level colour, a grey line under it, the quest log's glow under the mouse). Gone: the Abandon buttons, verdict icons and coloured verdict text, the » marks, the parchment in the window, the hint line and the - / + buttons. Abandoning and pinning are in the right-click menu, as in the quest log (Abandon Quest, Pin as Keep). A quiet "Abandon" or "Pinned" at the end of the title says what is advised. The quests to drop come first and the summary says how many. The free-slot target is in the options and `/abandon free <n>`. The quest log tab is laid out like the game's Map Legend page.
- Group: messages from group members with a two-word name or the realm spelled differently (as on this realm) are now recognised, and your own echo is no longer taken for someone else's abandon. Messages from someone not found in the group are counted in `/abandon debug`, and the last 40 messages in and out are kept in the saved settings.

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
