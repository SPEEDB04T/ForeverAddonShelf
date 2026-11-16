# SkillPath

Levels a profession the cheapest way, worked out from your own recipes and real reagent prices. It has no window of its own: it is a tab in the professions window and a tab in the auction house.

## The order

The path is one numbered list, the same on both tabs and in chat:

1. **Buy reagents.** What to buy and how many, after what you already hold.
2. **Craft.** "35 x Bolt of Linen Cloth, skill 1 to 34", one step per recipe. "About" means some crafts may not give a point, so the count is the expected one.
3. **Trainer** steps, where the path needs them: "Trainer at skill 97: learn Copper Modulator", with the fee, and the next rank where your cap is in the way. A recipe taught by a recipe item is a "buy and learn" step.
4. **Sell what's left.** What the path makes and no later step uses, where each goes (auction house, vendor, or no sale and why) and what it brings.

Every step shows what it costs.

## In the professions window

A SkillPath tab sits with the profession tabs on the right edge. Open it for the steps on the left and the picked step on the right.

- **A craft step** shows its reagents, how many you hold, and (if you leave it on) each skill point's chance and cost. "Show recipe" opens the recipe on the game's page with the number of crafts filled in.
- **Buy** and **Sell** list every item with its price and where the price comes from. Shift-click an item to link it.
- **A trainer step** lists what to learn, from which skill and for how much.
- **Recipes worth learning** are recipes the path couldn't use (a recipe item with no price, something the trainer won't teach you yet) that would take it further or make it cheaper.
- The top line is the cost, what the leftovers sell for and the net.
- **Plan for someone**, **Copy guide** and **My path** are at the top: see "Plans for other players".

## The trainer

The game doesn't say at which skill a trainer teaches a recipe until you stand at the trainer. Open each profession's trainer once: the addon reads the whole list (for a moment it switches on the recipes the window hides, then puts the filter back) and keeps each recipe's skill and fee.

Until then, a recipe you don't know and no recipe item teaches is taken to be a trainer recipe, learnable at its yellow skill. That is the latest it can be, so the path is possible but may cost more than it has to, and fees aren't in the cost. The path says how many recipes that is. Where nothing known gives skill and only such a recipe could go on, the path stops there and names it, never guessing.

Rank training fees (Journeyman, Expert, Artisan) aren't in the cost.

## Plans for other players

"Plan for someone" (or `/skillpath for engineering 75 225`) builds the path for any profession and skill range, not only your own: the shopping list with costs, every trainer visit, every craft and what to sell and where, from the prices you have now. It assumes the other player holds no reagents and knows only what comes with the profession. Scan at the auction house with the plan up: the scan then reads that profession's reagents too.

- **Copy guide** (`/skillpath guide`) opens the plan as text to copy.
- `/skillpath send <player>` whispers it line by line, one a second; `/skillpath send party` posts it to your party; `/skillpath send stop` ends it. The notes about your own addon (what isn't read yet) stay out of what is sent.
- **My path** (`/skillpath for me`) goes back to your own profession.

## At the auction house

A SkillPath tab sits after the game's tabs. It shows step 1 (what to buy) and the sell step side by side. Click an item to search for it on the Buy tab. "Scan prices" reads every reagent's price now.

The addon also scans when you open the auction house: a few seconds later, one search at a time, only when the game allows the next search. When another addon (Slutmog Scout, Slutmog Shop) is searching, it waits until they have been quiet for a few seconds. Reagents a vendor sells, bound reagents and prices from the last half hour are skipped.

## Where the numbers come from

- **Recipes, colours and reagents** come from the game's professions window, read each time you open the profession. Nothing comes from a written guide.
- **The yellow and grey levels** come from the client's own recipe table (`Data.lua`, built from the game files of build 1.60.1.70938). Each time you open the profession the addon checks them against the colours the game shows. A recipe that doesn't match is used only at your current skill and only while the game shows it orange, and the path says how many didn't match.
- **The chance** a craft gives a point: orange always; yellow and green (grey level - skill) / (grey level - yellow level); grey never.
- **Prices:** what you hold is free (bank too, unless you turn that off). Then the cheapest auction listings: per unit for reagents sold by the unit, the cheapest set of whole lots for the rest. Then the vendor price: the one you saw at a vendor, or the item's vendor price from the game's data. Your own auctions are left out. Items bound on pickup have no price: you farm or make them.
- **Old prices:** an auction price older than 3 hours (adjustable) is still used, and the step says it is old.
- **No price:** a reagent with no price isn't in the cost, and the path says which and why.
- **Made reagents:** a reagent the path can craft itself is crafted when that is cheaper than buying it, and the step says "Make first".
- **Not on the auction house:** a recipe whose reagent has no price is used only where nothing priced gives the point, and listed reagents are used for as many crafts as there are.
- **Spare reagents:** crafts that may give no point make the count an expected one. The shopping list adds the spare units that cover an unlucky run 9 times in 10, with their cost apart from the total.
- **Recipes that come with a profession** are marked in the client's recipe table, so a plan for someone else knows what a beginner has.
- **Selling what is left:** leftovers count at their vendor sell price, so the path can pick a recipe whose result sells back for more.
- **Auction house resale (on unless you turn it off):** leftovers can count at the cheapest auction price after the 5% cut, but only as many as were seen to sell. The auction house shows listings, never sales, so the addon compares scans of the item: units listed at one scan and gone at the next were bought, cancelled or ran out, which is the most that can have sold. That rate per day, times "Days of sales to count" (3), is how many count at the auction price; the rest count at the vendor price. Until an item has 4 hours of scans behind it (kept for a week), it counts at the vendor price. With the option on, the scan also reads what your recipes make.

## Commands

| Command | Does |
|---|---|
| `/skillpath` or `/spath` | Open the SkillPath tab in whichever of the two windows is open. With neither open, the path in chat. |
| `/skillpath print` | The path in chat. |
| `/skillpath scan` | Scan every reagent's price (at the auction house). |
| `/skillpath target <skill>` | Where the open profession's path stops, up to 300; 0 is your rank's cap, or the next rank's once you are at it. |
| `/skillpath for <profession> <from> <to>` | A plan for someone else, like `/skillpath for engineering 75 225`. `/skillpath for me` goes back. |
| `/skillpath guide` | The written plan in a window, to copy. |
| `/skillpath send <player>` | Whisper the plan. `send party` posts it to your party, `send stop` ends it. |
| `/skillpath forget` | Forget every auction and vendor price. |
| `/skillpath config` | Options. |
| `/skillpath minimap` | Show or hide the minimap button. |
| `/skillpath reset` | Settings back to how they started. |
| `/skillpath debug` | What the addon read and checked. |

## Works with

- **ForeverCore:** the tab joins its column of profession tabs. Without it, SkillPath adds its own tab under the game's.
- **Auctionator** (or any addon that carries LibAHTab): the auction house tab lines up with theirs. Without it, SkillPath adds its own tab after the game's.

## Tests

`python tests/SkillPath/run.py` (needs `pip install lupa==2.4`).
