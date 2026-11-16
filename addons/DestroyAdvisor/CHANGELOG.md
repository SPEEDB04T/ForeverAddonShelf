## 1.0.1
- Fixed: the addon no longer blocks other slash commands. It used to write the game's slash command list, which made the game refuse raid marking (/tm) and /invite from macros and blame an addon. A /reload is enough.

## 1.0.0
- New addon: lists the items in your bags that are safe to get rid of, each with the reason. `/destroy` opens the list.
- Suggests grey items, items that start a quest you have done or can't take, quest items whose quests are all handed in or not for this character (with Questie), bound gear your class can never use, bound recipes, pets, mounts and toys you already know, ammo for classes that can't shoot, and drinks and mana potions for warriors and rogues.
- Never suggests an item a quest in your log asks for, an item whose quest you can still take, your hearthstone, anything you can open, or gear in an equipment set.
- A click destroys through the game's own confirmation (the same one as dragging the item out of your bag). At a merchant a click sells instead. Right-click keeps an item so it is never suggested again.
- When your bags fill up, chat names up to three items that are safe to destroy. Optional: open the list then too.
- A line in the tooltip of every bag item that can go, and a junk plugin for Baganator.
- Options window and minimap button.
