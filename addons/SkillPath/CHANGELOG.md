## 1.2.0
- SkillPath no longer has a window of its own. It is a tab in the professions window, with the profession tabs on the right edge, and a tab in the auction house.
- The path is one numbered list in the order you do it: 1. buy reagents, 2. craft (one step per recipe, with how many), train or learn where needed, and last, sell what's left. The same numbers appear on both tabs and in `/skillpath print`.
- Professions tab: pick a step to see its reagents and how many you hold. "Show recipe" opens the recipe on the game's page with the number of crafts filled in. Each point's chance and cost is now inside its craft step, not in the main list.
- Auction house tab: what to buy and what to sell, side by side. Click an item to search for it. "Scan prices" is a button there.
- Shorter wording everywhere: steps, notes, tooltips, options and chat.
- Fixed: the note that the recipe table is from another build showed on every path.
- New: a recipe learned while the professions window is closed is noted until the profession is opened again.
- The window options (scale, place, open beside the professions window) are gone; "Open on the SkillPath tab" replaces them and is off at first.

## 1.1.0
- What the guide crafts and no later step uses now counts at its vendor sell price, so a recipe whose result sells back for more can be the cheaper way up. The top shows the net cost, and a new "Left over to sell" list says what each leftover is worth.
- Optional (off at first): leftovers can count at the cheapest auction price after the 5% cut, but only as many as were seen to sell. The auction house doesn't show sales, so the addon compares scans: units listed at one scan and gone at the next were bought (or cancelled, or ran out), which is the most that can have sold. Until an item has 4 hours of scans behind it, it counts at the vendor price, and the guide says so. "Days of sales to count" (3 at first) sets how many days of those sales count at the auction price; the rest go to a vendor.
- A made item a later step uses up isn't counted as sold too.

## 1.0.0
- New addon: a point-by-point leveling guide for your profession, worked out from your own recipe list and real reagent prices. `/skillpath` opens it; it also opens beside the professions window.
- For every skill point: which recipe to craft, the chance a craft gives the point, the expected number of crafts and what they cost. Orange always gives a point; yellow and green use the game's chance (grey level minus skill, over grey minus yellow).
- Recipe colours come from the game, and the yellow and grey levels from the client's own recipe table. A recipe whose levels don't match the colours the game shows is used only while the game shows it orange.
- Reagent prices: what you hold (bags and bank) is free, then the cheapest auction listings (whole lots for items that sell in lots), then the vendor price. Items an earlier step makes are used by later steps.
- Scans reagent prices at the auction house, one search at a time and only when the game allows the next; Slutmog Scout's and Slutmog Shop's searches go first. Says plainly when a reagent has no price or its price is older than 3 hours (adjustable).
- Recipes you don't know appear apart from the guide, with where the game says they are learned.
- A shopping list, the trainer rank to buy, and the guide recomputed when your skill goes up or a new price arrives.
- Options window and minimap button.
