# Destroy Advisor

Lists the items in your bags that are safe to get rid of, and says why for each one. `/destroy` opens the list.

- **The list:** one row per item, with the reason under its name ("Starts a quest you have done: The Defias Brotherhood"). The top right of a row says what the item sells for. Items worth nothing come first.
- **Click** a row to destroy the item. The addon picks it up and the game shows its own "Do you want to destroy ...?" confirmation, the same one as dragging the item out of your bag; nothing is destroyed until you say yes there. Rare and better items need DELETE typed, as usual.
- **At a merchant** a click sells the item instead.
- **Right-click** for Sell, Destroy, or Keep. A kept item is never suggested again (`/destroy unkeep <item>` undoes it).
- **Shift-click** links the item in chat. Drag a row to pick the item up.
- **Bags full:** when the last bag slot fills up, or the game says your inventory is full, chat names up to three items that are safe to destroy. The list can open then too (off at first).
- **Tooltips:** the tooltip of a bag item that can go says so, with the reason.
- **Baganator:** registers a junk plugin called "Destroy Advisor". Pick it in Baganator's junk setting to have Baganator grey out the same items.
- **Options:** `/destroy config`, or right-click the minimap button.

## What it suggests

| Rule | Suggested when |
|---|---|
| Grey items | Poor quality. |
| Quest starters | The item starts a quest you have handed in, or one this character can't take (another race or class, or you did the quest it excludes). Needs Questie for the race and class part. |
| Quest leftovers | A quest item whose quests, by Questie's data, are all handed in or not for this character. Without Questie quest items are never suggested. |
| Bound gear | Bound to you, and your class can never use it at any level: plate for a mage, a wand for a warrior, a "Classes: Paladin" item for anyone else. The tooltip must show it red too, so the game agrees. |
| Already known | A bound recipe, pet, mount or toy whose tooltip says "Already known". |
| Useless here | Arrows and bullets for a class that can't shoot; drinks and mana potions for warriors and rogues. |

Each rule can be turned off in the options.

## What it never suggests

- Anything a quest in your log asks for: its name is in a quest objective, or Questie lists it for a quest you are on.
- An item used by a quest you can still take, even a grey one.
- An item that starts a quest you haven't done and can take.
- Your hearthstone, anything you can open (lockboxes, clams, bags of loot), and gear in an equipment set.
- Gear and recipes that aren't bound yet: they can still be sold at the auction house or given away.
- Anything you chose to keep.

When it isn't sure, it keeps the item. `/destroy debug` prints every item in your bags with what the addon thinks of it.

## Commands

`/destroy` (also `/destroyadvisor`): `list` (print the list), `full` (say what to destroy now), `keep <item>`, `unkeep <item>`, `forget` (forget kept items), `config`, `minimap`, `scale <n>`, `reset`, `debug`.

## How it looks: the game's widgets it copies

Sources are Blizzard's UI on the `forever` branch of Gethe/wow-ui-source.

| Element | Copies | Differences, and why |
|---|---|---|
| List window | The loot window, `LootFrame` (`Blizzard_UIPanels_Game/Mainline/LootFrame.xml`): it inherits the same `ScrollingFlatPanelTemplate` (`Blizzard_UIPanels_Game/Mainline/ScrollingFlatPanel.xml`), same list view, padding 6, gap 2, same scroll shadows. | 300 wide instead of 220, so the reason fits on one line; at most 410 high instead of 290, so a bag full of junk needs less scrolling. Draggable, and its place is saved. Escape closes it. |
| Row | `LootFrameItemElementTemplate` (`LootFrame.xml`), rebuilt in Lua with its sizes, anchors and layers: 46 high, 37 px item button at 5,-4 whose click area spans the row, `looting_itemcard_bg` tinted in the quality colour, `looting_itemcard_stroke_normal`, `looting_itemcard_stroke_clickstate` for hover (alpha 0.7) and press, the quest bang or border over the icon, `looting_raritytag_frame` stripe at the top right with `GameFontWhiteTiny2`. | The name is one line (`GameFontNormal`, quality colour) with the reason under it (`GameFontHighlightSmall`, `QUEST_OBJECTIVE_FONT_COLOR`); the loot window has a two-line name there. The name starts at -9 instead of -8 so the two lines sit centred on the icon. The stripe shows the sell price ("No sell price" for none) instead of the quality, since the quality is already the name's colour. Rows don't fade in. |
| Row tooltip | `GameTooltip:SetBagItem`, the bag's own item tooltip. | Two grey hint lines under it (what a click and a right-click do) and the reason in white. |
| Right-click menu | The game's context menu, `MenuUtil.CreateContextMenu`. | None. |
| Destroy confirmation | The game's own `DELETE_ITEM`, `DELETE_GOOD_ITEM`, `DELETE_QUEST_ITEM` and `DELETE_GOOD_QUEST_ITEM` dialogs (`Blizzard_StaticPopup_Game/GameDialogDefs.lua` and `Mainline/GameDialogDefs.lua`). | None: they are the game's. |
| Tooltip line | One `GameTooltip` line in `ORANGE_FONT_COLOR`. | No counterpart in the game; one line, like other addons' tooltip notes. |
| Options and minimap button | The shared kit (`Kit.lua`). | See the kit. |

On a client without the loot window's template the window falls back to `BasicFrameTemplateWithInset` with `UIPanelScrollFrameTemplate`, with the same rows.

Not yet seen in the game.
