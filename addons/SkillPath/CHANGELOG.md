## 1.0.0
- New addon: a point-by-point leveling guide for your profession, worked out from your own recipe list and real reagent prices. `/skillpath` opens it; it also opens beside the professions window.
- For every skill point: which recipe to craft, the chance a craft gives the point, the expected number of crafts and what they cost. Orange always gives a point; yellow and green use the game's chance (grey level minus skill, over grey minus yellow).
- Recipe colours come from the game, and the yellow and grey levels from the client's own recipe table. A recipe whose levels don't match the colours the game shows is used only while the game shows it orange.
- Reagent prices: what you hold (bags and bank) is free, then the cheapest auction listings (whole lots for items that sell in lots), then the vendor price. Items an earlier step makes are used by later steps.
- Scans reagent prices at the auction house, one search at a time and only when the game allows the next; Slutmog Scout's and Slutmog Shop's searches go first. Says plainly when a reagent has no price or its price is older than 3 hours (adjustable).
- Recipes you don't know appear apart from the guide, with where the game says they are learned.
- A shopping list, the trainer rank to buy, and the guide recomputed when your skill goes up or a new price arrives.
- Options window and minimap button.
