# Changelog

## 1.5.0

What to buy: each listed piece gets a buy score that weighs supply, how easy it is to farm and other items
with the same look. Being underpriced is now one reason among several.

- **Worth buying.** A piece is worth buying when reselling it earns at least 1 gold after the 5% cut and the
  deposit, also once its risks are counted, and its price leaves 30% of the resale for risk. Filter > Worth
  buying (it replaces "Underpriced only") lists these pieces, best first, with what to pay at most, how many
  are listed under that price, and a risk of low, medium or high.
- **Resale.** The resale price is the fair value, or less when a piece with the same look and armor type is
  listed for less. The tooltip names that piece ("Same look, cheaper").
- **Never worth buying:** a piece without a fair value, or one whose look a crafted item or a white or grey
  item also has, since anyone can have that made or buy it from a vendor.
- **What lowers the score:**
  - supply: more copies listed, a wall of other listings under 60% of the fair value, more listed than in
    your earlier scans, other pieces with the same look listed, or the piece listed in nearly every scan;
  - easy farming: low-level mobs, many farm spots, few other drops at that level, or drops you have
    measured yourself;
  - other items with the same look: other BoE items, and bind-on-pickup items players get themselves;
  - a fair value that rests on little data.
  None of these can raise the score. The tooltip lists every reason for and against in full.
- Pieces that are easy to farm say "cheaper to farm: level X-Y mobs" in the Market list.
- The chat line after a scan names the top three buys. The extra searches after a scan now look at any
  listed piece that might be worth buying, not only rare ones.
- The item list now knows, for each look, how many other items in the game have it and how they are had
  (crafted, white or grey, bind on pickup, BoE), and how many other drops share its level.

## 1.4.1

Leg detection fixed: bare thighs count again.

- 1.4.0 read the lower half of the upper leg as "the knee" and barely counted it, so hot pants,
  briefs and loincloths that leave the thigh bare dropped off the list, while long mail leggings with a
  little skin at the hip stayed on.
- Now the bare thigh counts fully. The pelvis counts a quarter, because bare skin there mostly shows the
  body's own underwear. The strip at the knee counts a little, and the shins still don't count.
- Back on the list (26): Bandit Pants, Mail Combat and Captain's Leggings, Warden's Woolies, Sentinel
  Trousers, Peerless Leggings, the Pridelord group, War Paint, Outrunner's, Grunt's, Spiked Chain,
  Bloodspattered Loincloth, Burnt Leather Breeches, Bard's Trousers, Tracker's, Sentry's, Steadfast,
  Abyssal Leather and Insignia Leggings.
- Off the list (11), all covering the thigh: Myrmidon's, Mercurial, Ebonhold, Crusader's, Jazeraint,
  Revenant, Templar, Chief Brigadier, Engraved, Masterwork and Ornate.
- Seafarer's Pantaloons stays off. The list now has 166 pieces.

## 1.4.0

Better detection, and rare pieces listed under their worth.

**Detection.** Where the skin is bare now counts, not only how much of it.
- Legs: the upper thigh and crotch count most, the hip strip under a tunic and the knees count little,
  and the shins don't count at all. Plain trousers with bare shins (Seafarer's Pantaloons and 49 others)
  are off the list. Thigh-high cut-outs (Elegant Leggings, Revenant, Templar, Glimmering) are on it.
- Chest: the bust and belly count more than the neck and shoulders. A robe needs a bare top to be listed.
- The list now has 151 pieces. Saved prices for pieces that left it are kept but no longer shown.

**Fair value and underpriced pieces.** A piece is no longer judged by its own lowest price.
- Each piece has a fair value. It comes from the piece's earlier scans (the current one left out), or
  from its other listings right now. Failing those, it comes from pieces with the same look, then similar
  pieces, then Auctionator or TradeSkillMaster. The tooltip says where it came from and how sure it is.
- After a scan, up to 8 rare pieces that might be underpriced get one extra search each, to read their
  other listings.
- A piece counts as underpriced when it is listed at half its fair value or less, reselling it would earn
  at least 1 gold after the cut, and it is rare. Rare means: blue or epic, dungeon-only, listed in 30% of
  your scans or fewer, or a look no other item in the game has. Being one of only one or two listed is
  not enough on its own.
- The Market list's value column is now "Fair value". Underpriced pieces show how far under they are,
  and Filter > Underpriced only lists them alone, deepest first. Their tooltip says why they count as rare.
- One chat line after a scan names the underpriced pieces.
- The farm guide values pieces at their fair value.

## 1.3.3

- Lists the window's tabs and the auction house button for LookShots, a local screenshot helper, so they can be
  checked in screenshots. Without LookShots this does nothing.

## 1.3.2

- The options window and the minimap button are redrawn by the shared kit: they now copy the game's own
  Options rows and its round minimap button.
- The auto-scan option is now called "Scan at the auction house", so it fits on one line; the rest of the
  sentence is in its tooltip.

## 1.3.1

The window is now built like the auction house itself, piece by piece, not only with its art.

- The window is the game's portrait window (the auction house's frame), with the list areas in the game's inset.
- The armor type and "Listed now only" filters moved into the game's Filter dropdown, next to the Scan button,
  where the auction house has its Filter and Search buttons. A reset cross shows while a filter is set.
- The Market list copies the auction house browse list: price column first, the same cell font, padding,
  20 px rows, icon size and border, 19 px column headers and the thin scroll bar in the same place.
- One piece's farm spots open like the auction house's item page: a Back button and the piece's name above the list.
- Farm guide and Measured rows are laid out like the group finder's result rows. The rank numbers and the
  explanation paragraphs above the lists are gone; the farm estimate note is now in each spot's tooltip.
- Empty lists say so where the auction house says "No results".
- The bottom tabs sit where the auction house's tabs sit.

## 1.3.0

The window now looks like the game's own auction house list.

- Rows use the auction house's striped row background and its row highlight, instead of flat colour.
- Item icons have the auction house's small icon border.
- Column headers are the game's column header tabs, with the auction house's sort arrow.
- Market, Farm guide and Measured are the game's tabs along the bottom of the window.
- Prices are written with the gold, silver and copper coin icons (coin letters in colourblind mode).
- Text uses the game's colours: gold titles and labels, white values, grey hints, and the game's item quality colours.

## 1.2.0

Options window and minimap button.

- New options window: `/smog config`, a right-click on the minimap button, or Options > AddOns > Slutmog Scout.
  It has the ticks for scanning when the auction house opens and for the tooltip line, and buttons to scan now,
  check the item list, bring back removed pieces, and clear saved prices or measured farms.
- New minimap button: left-click opens the window, right-click opens the options, drag moves it.
  `/smog minimap` hides or shows it.
- The addon is also in the list of addons next to the minimap.
- After updating, restart the game once: a `/reload` does not load the new files, so the options window and
  the minimap button only appear after a restart.
