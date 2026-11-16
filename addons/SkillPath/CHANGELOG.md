## 1.3.0
- Trainer steps. A recipe you don't know is no longer left out: the path says "Trainer at skill 97: learn Copper Modulator" and goes on with the steps after it. Recipes taught by a recipe item become a "buy and learn" step when the item has a price.
- Open a profession's trainer once and the addon reads its list: the real skill each recipe is taught at, and its fee. Fees are then part of the cost. Until then a trainer recipe is taken to be learnable at its yellow skill (the latest it can be), with no fee in the cost, and the path says how many recipes that is.
- No guessed steps. Where nothing you can learn for sure gives skill, the path stops there and names the trainer recipe that may go on.
- At your rank's cap with no target set, the path goes on through the next rank, the trainer first. Skill 300 is the top.
- Each profession has its own target.
- Plans for other players. "Plan for someone" on the professions tab, or `/skillpath for engineering 75 225`, builds the path for any profession and any skill range from current prices, whatever you know yourself: what to buy, what it costs, every trainer visit, every craft, what to sell and where. "Copy guide" (`/skillpath guide`) opens the written plan to copy. `/skillpath send <player>` whispers it, `/skillpath send party` posts it to your party. "My path" goes back to your own.
- Recipes that come with a profession are known from the client's table, so a plan for someone else starts with what every beginner has.
- Each step shows what it costs. A craft step shows what its reagents cost and what its result is worth; a trainer step shows its fees.
- The sell step says where each leftover goes: auction house (price after the cut, cheapest listing, how many sell a day), vendor, or no sale, with the reason (a vendor pays as much, none sold, fewer sell than you'd have, nobody buys it).
- Auction house sales now count unless you turn them off. Only as many as were seen to sell count at the auction price.
- A reagent the path can make itself is made, when that is cheaper than buying it ("Make first").
- A reagent that isn't on the auction house no longer blocks the path: another recipe is used, and listed reagents are used for as many crafts as there are.
- The shopping list adds spare reagents that cover an unlucky run 9 times in 10, with their cost apart.
- A plan with item names the game hasn't loaded yet isn't whispered at the first ask.

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
