# SkillPath

A point-by-point leveling guide for your profession, worked out from your own recipe list and real reagent prices. Open a profession once and the guide appears beside the professions window; `/skillpath` opens it any time.

- **Steps:** "Bolt of Linen Cloth" with "1-34  34.9 crafts  6s 98c" under it. The recipe name is in its colour at your skill. Click a step to show the recipe in the professions window; shift-click links it.
- **Every point:** under each step, one line per skill point: the chance a craft gives it and the expected crafts. Hover for the cost and the reagents.
- **Expected cost:** the total at the top, the cheapest the addon can find. When a reagent has no price, the guide says so and doesn't count it.
- **Shopping list:** what to buy, after what you already hold and what earlier steps make.
- **Recipes you could learn:** recipes you don't know yet that would take the guide further or make it cheaper, with where the game says they are learned and the skill they need. They are never part of the guide itself.
- **Trainer:** a line where the guide reaches your rank's cap and you need the next rank.

## Where the numbers come from

- **Recipes, colours and reagents** come from the game's trade skill window, read each time you open the profession. Nothing comes from a written guide.
- **The yellow and grey levels** come from the client's own recipe table (`Data.lua`, built from the game files of build 1.60.1.70938). Each time you open the profession the addon checks them against the colours the game shows. A recipe that doesn't match is used only at your current skill and only while the game shows it orange, and the guide says how many didn't match.
- **The chance** a craft gives a point: orange always; yellow and green (grey level - skill) / (grey level - yellow level); grey never.
- **Prices:** what you hold is free (bank too, unless you turn that off). Then the cheapest auction listings: per unit for reagents sold by the unit, the cheapest set of whole lots for the rest. Then the vendor price: the one you saw at a vendor, or the item's vendor price from the game's data. Your own auctions are left out. Items bound on pickup have no price: you farm or make them.
- **Old prices:** an auction price older than 3 hours (adjustable) is still used, but the step and the total say it is old.

## Auction scan

When you open the auction house, the addon reads the price of every reagent the guide might use, a few seconds later and one search at a time, only when the game allows the next search. When another addon (Slutmog Scout, Slutmog Shop) is searching, it waits until they have been quiet for a few seconds. Reagents a vendor sells, bound reagents and prices from the last half hour are skipped. `/skillpath scan` scans everything now.

## Commands

| Command | Does |
|---|---|
| `/skillpath` or `/spath` | Show or hide the guide. |
| `/skillpath print` | The guide in chat. |
| `/skillpath scan` | Scan every reagent's price (at the auction house). |
| `/skillpath target <skill>` | Where the guide stops; 0 is your rank's cap. |
| `/skillpath forget` | Forget every auction and vendor price. |
| `/skillpath config` | Options. |
| `/skillpath minimap` | Show or hide the minimap button. |
| `/skillpath reset` | Settings back to how they started. |
| `/skillpath debug` | What the addon read and checked. |

## Tests

`python tests/SkillPath/run.py` (needs `pip install lupa==2.4`).
