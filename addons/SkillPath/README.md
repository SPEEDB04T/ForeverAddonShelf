# SkillPath

Levels a profession the cheapest way, worked out from your own recipes and real reagent prices. It has no window of its own: it is a tab in the professions window and a tab in the auction house.

## The order

The path is one numbered list, the same on both tabs and in chat:

1. **Buy reagents.** What to buy and how many, after what you already hold.
2. **Craft.** "35 x Bolt of Linen Cloth, skill 1 to 34", one step per recipe. "About" means some crafts may not give a point, so the count is the expected one.
3. **Trainer** steps, where the path needs them: "Trainer at skill 97: learn Copper Modulator", with the fee, and "train Journeyman (cap 150, 5s)" where your rank's cap is in the way. A recipe taught by a recipe item is a "buy and learn" step.
4. **Tools.** "Tool: Runed Copper Rod, at skill 1", where a recipe needs something in your bags that crafting doesn't use up (a rod, a hammer, a spanner). Bought or made right before its first craft, kept after.
5. **Sell what's left.** What the path makes and no later step uses, where each goes (auction house, vendor, or no sale and why) and what it brings.

Every step shows what it costs. What you already hold costs no gold, but the path counts it at what buying it again would cost, so buying the list doesn't change the path. Unless you set a target of your own (`/skillpath target`), the path goes as far as the profession goes, 300: at each rank's cap a trainer step says where to train the next rank and what it costs, and the steps after it show what that rank needs.

## In the professions window

A SkillPath tab sits with the profession tabs on the right edge. Open it for the steps on the left and the picked step on the right.

- **A craft step** shows its reagents, how many you hold, and (if you leave it on) each skill point's chance and cost. "Show recipe" opens the recipe on the game's page with the number of crafts filled in; "Create 35" crafts them right there, as many as your bags have reagents for (not for enchants, which go on an item you pick).
- **Buy** and **Sell** list every item with its price and where the price comes from. Shift-click an item to link it.
- **A trainer step** lists what to learn, from which skill and for how much, and the rank to train with its fee and the level it asks for.
- **Recipes worth learning** are recipes the path couldn't use (a recipe item with no price, something the trainer won't teach you yet) that would take it further or make it cheaper.
- The top line is the cost, what the leftovers sell for and the net.
- **Plan for someone**, **Copy guide** and **My path** are at the top: see "Plans for other players".

## The trainer

The game's files don't say at which skill a trainer teaches a recipe or what it costs; the game shows that only in the trainer's window. So the addon carries its own table for Forever: every recipe a profession trainer teaches (468), from which skill, the fee, and each rank (Journeyman, Expert, Artisan) with its fee, skill and level. Cooking, First Aid and Fishing get Expert from a book a vendor sells and Artisan from a quest; the path says that and counts the book's price.

A path has its trainer steps and fees from the start, for you and for anyone you plan for. Fees are the base ones, before a reputation discount.

When you open a profession's trainer, the addon reads the list in the window (for a moment it switches on the recipes the window hides, then puts the filter back). What the trainer shows wins over the table: your own fee with its discount, and anything this server changed. A recipe the table has that a trainer's list doesn't show is left out of your path. `/skillpath debug` lists every row a trainer showed differently from the table.

Where nothing you can learn gives skill, the path stops there and says so, never guessing.

The table comes from the Forever recipe tables of the addon What's Training? by Sveng (MIT licence), kept only where the game client has that recipe on that profession, and compared row by row with a 1.12 trainer table. `tests/SkillPath/make_trainers.py` builds it and says where each column comes from.

## Plans for other players

"Plan for someone" (or `/skillpath for engineering 75 225`) builds the path for any profession and skill range, not only your own: the shopping list with costs, every trainer visit, every craft and what to sell and where, from the prices you have now. It assumes the other player holds no reagents and knows only what comes with the profession. Scan at the auction house with the plan up: the scan then reads that profession's reagents too.

- **Copy guide** (`/skillpath guide`) opens the plan as text to copy.
- `/skillpath send <player>` whispers it line by line, one a second; `/skillpath send party` posts it to your party; `/skillpath send stop` ends it. The notes about your own addon (what isn't read yet) stay out of what is sent.
- Every line is checked against the game's echo of it. The game can drop chat an addon sends by itself: when a line doesn't come back, the guide window opens with a **Send next** button, and each click sends the next three lines (`/skillpath send next` does the same). The addon remembers that and starts the next plan on clicks. `/skillpath reset` makes it find out again.
- **My path** (`/skillpath for me`) goes back to your own profession.

## At the auction house

A SkillPath tab sits after the game's tabs. It shows the whole path as the professions tab does: every step on the left, the picked step on the right, the buy step first. On the buy and sell steps, click an item to search for it on the Buy tab. "Buy all" on the buy step buys the list one item at a time: the auction house quotes the price for that many, and nothing is bought until you click Buy on it (Skip and Cancel too). Vendor items are left for the vendor, and items sold in whole lots for the Buy tab. "Scan prices" reads the auction house now.

The addon also scans when you open the auction house, a few seconds later:

1. **One read of everything.** A browse search with nothing typed (what the auction house's own search bar sends), in pages, gives every item's cheapest price and how many are listed. An item that isn't in it isn't listed. Opened again within 5 minutes, this read is skipped.
2. **Searches for the path only.** Then it searches what the path buys or sells, one search at a time, only when the game allows the next one, and only items whose cheapest price or count changed since their last search. The path is rebuilt with the new prices and whatever it uses now is searched too (three rounds at most). That is a handful of searches, where the old scan searched every reagent and result of every recipe.

Bound reagents are skipped, and so are reagents a vendor sells unless the read shows them cheaper. When another addon (Slutmog Scout, Slutmog Shop) is searching, it waits until they have been quiet for a few seconds. Searches you or other addons make on the Buy tab are read too. While a scan runs the path is rebuilt at most every 3 seconds, and a rebuild never stops the game: it is worked out a few milliseconds per frame while the tab keeps showing the last path ("Updating the path" next to the prices).

On a client without the browse search, it falls back to searching every reagent one at a time, skipping prices from the last half hour.

## Where the numbers come from

- **Recipes, colours and reagents** come from the game's professions window, read each time you open the profession. Nothing comes from a written guide.
- **The yellow and grey levels** come from the client's own recipe table (`Data.lua`, built from the game files of build 1.60.1.70938). Each time you open the profession the addon checks them against the colours the game shows. A recipe that doesn't match is used only at your current skill and only while the game shows it orange, and the path says how many didn't match.
- **The chance** a craft gives a point: orange always; yellow and green (grey level - skill) / (grey level - yellow level); grey never.
- **Prices:** what you hold is free (bank too, unless you turn that off). Then the cheapest auction listings: per unit for reagents sold by the unit, the cheapest set of whole lots for the rest. Then the vendor price: the one you saw at a vendor, or the item's vendor price from the game's data. Your own auctions are left out. Items bound on pickup have no price: you farm or make them. An item the path doesn't search is priced from the read of the whole auction house, at its cheapest price, and the step says "cheapest only". An item SkillPath has never seen takes Auctionator's last price when Auctionator is installed, and the step says so and how old it is.
- **Old prices:** an auction price older than 3 hours (adjustable) is still used, and the step says it is old.
- **No price:** a reagent with no price isn't in the cost, and the path says which and why.
- **Made reagents:** a reagent the path can craft itself is crafted when that is cheaper than buying it, and the step says "Make first".
- **Not on the auction house:** a recipe whose reagent has no price is used only where nothing priced gives the point, and listed reagents are used for as many crafts as there are.
- **Spare reagents:** a craft that isn't orange can give no point, so every count past orange is an average, and with only the average bought a run often comes up short of something. The shopping list therefore adds spare units to each reagent, sized so that with all of them bought 99 runs in 100 need nothing more. Their cost is shown apart from the total. The size comes from the law of the crafts a point takes (its spread, skew and tail), not from a flat percentage: a few points on a nearly grey recipe need far more spare than many points on a yellow one. What you hold past the average counts as spare already. `tests/SkillPath/spare_check.py` compares the formula with the exact odds, and a test plays 20000 runs of a path against its shopping list.
- **Trainer skills and fees** come from the addon's own table (see "The trainer"), then from each trainer's list once you have opened it.
- **Recipes that come with a profession** are marked in the client's recipe table, so a plan for someone else knows what a beginner has.
- **Cheapest path (off unless you tick it):** the "Cheapest path" box at the top right of both SkillPath tabs (also in the options, and `/skillpath cheapest`) counts every leftover as worth nothing. The path then spends the least gold to level, assumes nothing will re-sell and never picks a recipe for what its result might sell for. The sell step still says where the leftovers can go.
- **Selling what is left:** leftovers count at their vendor sell price, so the path can pick a recipe whose result sells back for more.
- **Auction house resale (on unless you turn it off):** leftovers can count at the cheapest auction price after the 5% cut, but only as many as were seen to sell. The auction house shows listings, never sales, so the addon compares scans of the item: units listed at one scan and gone at the next were bought, cancelled or ran out, which is the most that can have sold. Between two reads of the whole auction house, the drop in how many are listed counts the same way, so results the path doesn't search still learn how fast they sell (not for items sold in lots). That rate per day, times "Days of sales to count" (3), is how many count at the auction price; the rest count at the vendor price. Until an item has 4 hours of scans behind it (kept for a week), it counts at the vendor price. With the option on, the scan also reads what your recipes make.

## Commands

| Command | Does |
|---|---|
| `/skillpath` or `/spath` | Open the SkillPath tab in whichever of the two windows is open. With neither open, the path in chat. |
| `/skillpath print` | The path in chat. |
| `/skillpath scan` | Read the whole auction house, then search what the path uses (at the auction house). |
| `/skillpath target <skill>` | Where the open profession's path stops, up to 300; 0 (the default) is as far as it goes, through every rank still to train. |
| `/skillpath cheapest` | Turn "Cheapest path" on or off (`cheapest on`, `cheapest off`). |
| `/skillpath for <profession> <from> <to>` | A plan for someone else, like `/skillpath for engineering 75 225`. `/skillpath for me` goes back. |
| `/skillpath guide` | The written plan in a window, to copy. |
| `/skillpath send <player>` | Whisper the plan. `send party` posts it to your party, `send next` sends the next lines where the game wants a click, `send stop` ends it. |
| `/skillpath forget` | Forget every auction and vendor price. |
| `/skillpath config` | Options. |
| `/skillpath minimap` | Show or hide the minimap button. |
| `/skillpath reset` | Settings back to how they started. |
| `/skillpath debug` | What the addon read and checked. |

## Works with

- **ForeverCore:** the tab joins its column of profession tabs. Without it, SkillPath adds its own tab under the game's.
- **Auctionator** (or any addon that carries LibAHTab): the auction house tab lines up with theirs. Without it, SkillPath adds its own tab after the game's. Auctionator's last prices also stand in for items SkillPath hasn't seen yet.

## Tests

`python tests/SkillPath/run.py` (needs `pip install lupa==2.4`).
