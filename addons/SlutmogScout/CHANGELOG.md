# Changelog

## 1.21.0

- **Looks you can get elsewhere are off the Market list.** A piece is left out when another item
  of its slot and armor type has its look and is crafted, white or grey, a dungeon drop, or a
  quest reward for your side: 24 of 148 pieces on Alliance, 22 on Horde (Saltstone Surcoat,
  Mercurial Breastplate, Martyr's Chain). Filter > Show looks had elsewhere or `/smog easy` shows
  them. A look whose other source is a raid, PvP, or an item new in Forever stays, with the icon.
- **Rarity is the look's, not the item's.** Where several BoE items share a look, their drops are
  added up for "common", Farm is the fastest of them, and Listed and Seen count every piece with
  the look. The tooltip says how many of the look are listed.
- **Same-look fixes.** A belt no longer counts as the twin of a leg piece. An item of another armor
  type is named with its armor and no longer warns. Quest rewards are named as such.

## 1.20.0

- **Undercut on each Sell row.** A bag piece that others list has an Undercut button beside its
  Post button, the same as the one in the sell box: it posts 1 silver under the lowest other
  listing.
- **More same-look warnings.** The list missed 88 items that share a look with a listed piece
  (Season of Discovery and PvP items), e.g. Electromantic Chainmail for Lambent Scale Breastplate.
  62 pieces carry the warning now, 32 before. An item new in Forever that the data can't name is
  counted ("1 other item").
- **Old prices look old.** Once your last scan is over 3 hours old, prices are grey, the tooltip
  says their age, and nothing is marked new or cheaper.
- The item tooltip calls the worth an estimate. The Models view shows the same-look mark.

## 1.19.0

- **Undercut button on the Sell tab.** While others list the piece in the sell box, an Undercut
  button shows beside Post. It posts 1 silver under the lowest other listing, whatever the price
  box says.
- **Same-look warning.** A piece whose look another item also has now names that item and where it
  comes from in its tooltip, listed or not, for example "Same look: Carapace of Anub'shiah (drops
  in Blackrock Depths)" on Saltstone Surcoat. The Market list puts a warning icon after such a
  piece's name when the other item is crafted, sold by a vendor or bind on pickup.

## 1.18.0

- **The Market tab is the list again.** The models are still there under Filter > View > Models.
- **Click a piece to preview it.** A small window opens beside Scout with the piece on your body.
  Drag to turn, wheel to zoom, right-drag to move up and down; Reset undoes that. Click the piece
  again to close it.
- The farm guide, which a click used to open, is the preview's **Farm guide** button.
- The List button beside the level range is gone.

## 1.17.1

Fixes the Market tab's models, which 1.17.0 shipped unusable.

- **Fixed: models showed a patch of neck, or nothing.** Each model is now framed on its piece by the
  game's own camera for it, as in the Appearances window: a chest piece on the torso, a leg piece on
  the hips and legs.
- **Each tile says what it is.** Under the model: the piece's name, its lowest price in full (no more
  cut-off prices) with Buy beside it, and its worth. Your rating is in the top-right corner, "new" or
  "cheaper" in the top-left. The tiles are bigger, 14 to a page.
- **A List button** beside the level range switches between the models and the list (it reads Models
  while the list shows). Filter > View still does the same.
- Ctrl-wheel zooms the models and Alt-wheel moves them up and down; Filter > Reset zoom undoes it.
  The wheel alone still turns the page.

## 1.17.0

- **The Market tab shows models.** Each piece is a model on your body in a grid like the
  Appearances window's, 27 to a page, with its lowest price under it. Turn the pages with the
  arrows or the mouse wheel.
- **Click, hover and Buy work as on the list.** Hover for the tooltip, click for the farm guide,
  right-click to search the auction house, ctrl-click for the dressing room. Buy shows under a
  listed piece while the auction house is open.
- **New and cheaper pieces come first, tagged NEW or CHEAPER.**
- **Filter > View > List** brings back the auction house list; your choice is kept. While the grid
  shows, Filter > Sort by sorts it.

## 1.16.1

- **Slutmog Shop can see when you're undercut.** Other addons can now read the lowest price other
  sellers ask for a piece (`SlutmogScoutAPI.MarketLow`). Your own auctions are left out, and the
  reading is kept across a /reload.

## 1.16.0

- **New Sell tab.** It lists your list pieces in the bags and your auctions, with the lowest other
  listing for each. The Slutmog sell button above the auction house (or `/smog sell`) opens it.
- **One copy per piece.** A piece you already list shows Listed and can't be posted again.
- **Undercut check.** Your auctions show Undercut, Lowest or Sold, and each has a Cancel button.
- **Post box.** It starts at your Slutmog Shop price, or else 1 silver under the lowest listing.
  Press Enter or Post to list the piece for 2 hours.
- **Scans leave your own auctions out**, so prices and counts are other sellers' only.
- **New or cheaper pieces get their own section** at the top of the Market list.
- **Shorter text** in chat, tooltips and the status line.

## 1.15.1

- **Slutmog post uses your Slutmog Shop prices.** A piece you priced in Slutmog Shop now opens at that
  price. Pieces without a shop price still start 1 silver under the lowest other listing. The window
  still shows the other listings, so you can compare.

## 1.15.0

Post your slutmog pieces from your bags without setting each one up in the Sell tab.

- **Slutmog post.** A new button above the auction house, next to Slutmog scan (or `/smog post`), goes
  through the pieces on the list in your bags one at a time. Pieces bound to you are left out.
- **One window per piece.** Each window shows the other listings (the lowest and how many), your own
  listing, what you asked last time, the vendor price, the slutmog worth estimate and the deposit.
- **Prefilled price.** The price box starts at the game's own default: 1 silver under the lowest
  listing by someone else. If only you list the piece, it starts at your own price. If nobody lists it,
  it starts at what you asked last time, or else at 1.5x the vendor price. Change it if you like.
- **Enter or Post lists it** for the shortest time, the cheapest deposit. Skip leaves the piece in your
  bags and Stop ends the run. A second copy of a piece starts at the price you just gave the first.
- The game lets an addon post only on a click or a key press, so each auction takes one. When the
  game asks you to confirm a post, the addon shows that confirmation itself, because the game's own
  window wouldn't confirm an addon's post.

## 1.14.0

The Market list gives you the facts to judge a piece by and stops telling you what to buy.

- **No more buy calls.** "Buy up to", "worth buying", "not worth buying" and the for/against lists are
  gone from the list, the tooltips, the chat and the buy popup. The Worth buying filter is gone too.
- **New columns.** "x Vendor" shows the lowest price as a multiple of the vendor price (near 1x, little
  can be lost). "Stock" shows how many are listed, with the usual number from your earlier scans in grey.
  "Farm" shows about how long one copy takes to farm alone. The Look text and Mob lvl columns moved into
  the tooltip, which gives the item name more room.
- **New and cheaper.** A piece listed that wasn't listed in the scan before is marked "new"; one whose
  price dropped is marked "cheaper". Filter > New or cheaper shows only those. After a scan, one chat line
  names them.
- **When to scan.** The line at the bottom says how old your prices are: green when fresh, with the minutes
  until the next scan is worth it, gold when a scan is due, red when the prices are over 3 hours old.
  Hover over Scan or Slutmog scan for the same. Opening the auction house with old prices reminds you once in chat
  (it scans by itself instead if Options > Scan at the auction house is on).
- **Shorter tooltip.** One block each for the look, the auction house (lowest, stock, the next listings,
  your price range), the worth and vendor price, items with the same look, and where it drops.

## 1.13.1

- **Rating column in the Market list.** Click its header to rank pieces by how good they look. It shows
  your own rating (or SuccuDev's) in colour, or the list's estimate in grey (~7). Click again to put the
  lowest first.

## 1.13.0

The list now knows how often each piece drops and how good each one looks.

- **Drop data.** Every piece's tooltip names the best mob to farm it, with its level and zone, the odds
  per kill and about how long one copy takes, for example "Drops from Twilight Lord Everun (level 60,
  rare spawn, Silithus): 1 in 244 kills, about 241 hours a copy farming alone". The farm guide's header
  for a piece says the same. The numbers are estimates from the CMaNGOS Classic loot tables (the open
  Classic server database) and an assumed kill rate: how many players are around each level, quest
  targets, elites, rares and dungeons. Forever's real loot can differ.
- **Hide the most common pieces.** Easy, common gear is now the share of the list that the whole realm
  loots most often, not every green up to level 30. The new "Hide the most common" slider in the options
  window sets the share, 25% by default, 0 to 60% (`/smog common 40` does the same). Filter > Show easy,
  common pieces still shows them. Buy advice and the farm scores use the same data.
- **Every piece rated for its look.** Each BoE chest and leg piece was rated 1-10 by eye from a render on
  a female body, with matching outfits (Lofty, Vanguard, Jade and others) and pieces that player
  transmog guides praise rated a little higher. These are estimates; your own rating in the Review tab
  always wins. The worth uses the estimate until you rate a piece, and the Review grid shows it in grey
  (~7/10).
- **19 pieces off the list, 1 on.** Tribal and crude looks (fur loincloths, wooden strap harnesses, ogre
  and gnoll gear) rated 3/10 or less are left off; the Review tab says why. Chief Brigadier Leggings,
  rated 7/10, joins the list. Knight's Breastplate now counts as skimpy, not cropped.

## 1.12.1

- **Fixed: blank models in the Review grid.** Going to another tab and back (or closing and opening the
  window) left the grid's models empty, because a hidden model forgets what it wore. Each model is now
  dressed again when it shows, and the piece and the up-close framing are put on again once the body
  has finished loading.
- `/smog common` and its help line no longer name a rule about cheap pieces that the addon dropped in
  1.11.0 (it printed a "-" where a price should be).

## 1.12.0

The Review grid shows the piece up close, and the whole window can be made bigger.

- **Up close.** Each model in the Review grid is framed on what its piece covers: a chest piece on the
  torso, a leg piece on the hips and thighs. Filter > View > The whole body shows all of it again.
- **Zoom and move the view.** The mouse wheel over the grid zooms the pieces of the type under the
  pointer (every chest piece, or every leg piece, so they stay easy to compare). Drag with the right
  button to move the view up or down; drag with the left button still turns the model. Your framing is
  saved; Filter > Reset zoom and position puts it back.
- **Paging** moved to Shift-wheel, the page arrows and the Page Up and Page Down keys (with the pointer
  over the grid).
- **Window size.** Drag the size grabber in the window's bottom-right corner to make the whole window
  bigger or smaller, from 60% to 200%. Also `/smog scale 150` (`reset` for 100%) and a Window size slider
  in the options window. The top-left corner stays where it is, and the size is saved.

## 1.11.1

- When the options window or the minimap button is missing right after an update, the chat line now says
  a /reload brings them (on WoW Forever a /reload loads an addon's new files). It said to restart the game.

## 1.11.0

Rate every piece 1-10 in a big grid, and worth from the vendor price instead of auction prices.

- **Ratings 1-10.** The Review tab has ten buttons, 1 to 10, instead of Yes and No. 4 to 10 keeps a piece
  on the list (also a piece the list left out, and a cropped one), 1 to 3 takes it off. With the mouse over
  the grid, press 1-9 (0 for 10) to rate the selected piece and the arrow keys to move. Your Yes and No
  answers from 1.10.0 still count.
- **Review grid.** The tab shows the pieces as a grid of models, 18 to a page, like the game's Appearances
  window. Click a tile to select it, drag it to turn the model, scroll or use the page arrows to page.
  Each tile shows the piece's rating and a check when it is on the list.
- **Slutmog worth.** At a launch, prices climb as players make gold, so what pieces sold for so far says
  little. The addon no longer values a piece by its auction prices (your earlier scans, the other
  listings, pieces with the same look, Auctionator or TSM). A piece's worth is its vendor price times its
  look (its rating, else its grade: 10/10 is 21 times, 8/10 about 14, 6/10 about 8), times 1.3 for blue
  and 1.6 for epic, 1.25 for a dungeon-only drop and 1.15 for a look no other item has. The Market list's
  "Worth" column, the tooltips, the deals and the buys all use it. The tooltip shows how it is made up.
- **The vendor floor counts in the buy score.** A vendor always pays its vendor price, so only what you
  pay above it is at risk: a piece listed near its vendor price scores higher, one at 10 times it or more
  scores lower. The tooltip shows the price as a multiple of the vendor price.
- **Removed:** the rules that rested on auction prices. A cropped piece is no longer shown because its
  prices show demand (rate it 4 or more to show it), a low-level green is common whatever it sells for,
  and "sells like ordinary gear" no longer stops a buy. A piece with the same look listed for less is
  named ("buy that one first") but no longer caps the resale price.
- The item list carries every piece's vendor price, and the generator writes SuccuDev's ratings into it
  for every user (tools/SlutmogScout/import_review.py copies them from the saved variables).

## 1.10.0

Review every piece yourself, a level range, and the Market list starts on what is listed now.

- **Review tab.** It lists every BoE chest and leg piece that no profession makes: the 166 on the list and
  the 460 the list leaves out, each with why (for example "measures 22% bare, under the 24% cut-off", or a
  robe that is only bare below the waist). Click a piece to see it on a model. Drag the model to turn it
  and scroll to zoom. With "Female body" ticked, a male character sees the piece on a female body of his
  race. Then press **Yes** or **No**, and the next piece comes up.
  - A yes puts the piece on the list, also a piece the list left out, and never hides it as cropped.
  - A no takes the piece off the list. Undo forgets your answer.
  - Filter > Show picks what the tab lists: not reviewed yet (the default), left off the list, on the
    list, or all pieces. The barest pieces come first.
  - `/smog review` opens the tab. The bottom line counts how many you have reviewed.
- **Level range.** The two level boxes next to the Filter button, as in the classic auction house, or
  `/smog level 20-40` (`30-` for 30 and up, `-40` for up to 40, `off` to clear). Pieces whose required
  level is outside the range are hidden everywhere: the Market list, the buys and deals, the farm guide,
  the review and the chat lines after a scan. The range is saved.
- **Listed now only is on by default.** The Market list opens on the pieces listed in your last scan.
  Untick Filter > Listed now only to see every piece. The filter's reset button turns it back on.
- The item list's generator applies the review answers. tools/SlutmogScout/import_review.py copies them from
  the saved variables.

## 1.9.0

Buy a piece straight from the list.

- **Buy button.** While the auction house is open, each Market row for a piece listed now has a Buy button
  in its Available cell. It finds the cheapest copy you can buy out (not your own, not bid-only) and opens
  the game's confirm popup with its price, how many copies there are, what the next one costs, and
  whether it is worth buying at that price. Nothing is bought until you press Buy in that popup.
- **`/smog buy <item>`** does the same from chat. Give an item link, ID or name of a piece on the list.
- After a purchase the list counts one copy fewer and the next copy as the cheapest, until the next scan.
- Right-clicking a row still searches for the piece in the auction house itself.

## 1.8.0

Grades fixed: Tyrant's Legplates and other plate pieces people buy for slutmog are no longer hidden as cropped.

- **What players pay beats the grade.** Suppose a piece's own prices put it at 2 times ordinary gear of its
  level or more. Then it is never hidden or ruled out for its grade, and it never counts as easy, common gear.
  The tooltip says "a cropped look, but it sells for X times ordinary gear". Without that evidence, a cropped
  piece stays hidden. When you show it with the filter, its look only lowers the score a little.
- **Better grade rules:**
  - Chest: a fully bare midriff under a partly open top is skimpy (Tyrant's and Jade Breastplate). A bare
    belly under a top that covers the bust is still cropped, like Infantry Tunic.
  - Legs: plate thongs and skirts measure low on the thigh, because the metal is painted over it. A thigh
    and hip that are both mostly bare are now skimpy: Tyrant's, Jade, Saltstone and Vanguard Legplates and
    Lofty Legguards.
  - Of 166 pieces, 58 are now cropped (was 65), 89 skimpy and 19 bikini.
- **Grades set by hand.** The item list now carries a short hand-kept list for pieces checked on the body, or
  judged by a player, with the reason in the tooltip data. Tyrant's Legplates and Chestpiece are on it as
  skimpy.
- **`/smog grade <item> <bikini|skimpy|cropped|auto>`** sets a piece's grade yourself. Give an item link,
  ID or name. Your grade wins over the list's and is saved, and the tooltip says "set by you". `auto` goes
  back to the list's grade.

## 1.7.0

Only pieces worth flipping: gear players get by the dozen is hidden.

- **Easy, common pieces are hidden** from the Market list, the buys, the deals and the farm guide values:
  - a green world drop up to level 30, which everyone levelling there loots, unless its own prices say it
    sells for 2 gold or more;
  - any piece your scans list nearly every time (80% of 5 scans or more) for under 2 gold.
  Blue and epic pieces, dungeon drops and fished pieces never count as common by their level.
- On your own scans this leaves 18 of the 96 pieces you have seen listed: the greens of level 37 and up
  that sell for 1 to 13 gold, plus Wolffear Harness, Quillward Harness, Martyr's Chain and Robes of Insight.
- To see them anyway, use Filter > Show easy, common pieces or `/smog common`. Their tooltip says why they
  are not worth buying.
- The farm guide now prices each piece once per refresh instead of once per farm spot.

## 1.6.0

Only looks people buy for slutmog: each piece is graded, and its price is compared with ordinary gear.

- **Look grade.** Each piece on the list is now bikini, skimpy or cropped. A chest piece is skimpy when the
  upper chest (the cleavage) or most of the bust is bare. It is a bikini when that is bare and the belly too.
  A top that covers the whole bust and is listed only for a bare belly or bare shoulders is cropped, for
  example Infantry Tunic, Sentry's Surcoat or Grizzly Jerkin. Leggings are a bikini when the thigh is bare
  almost fully, skimpy when about half of it is bare, and cropped otherwise. The grade starts the Look
  column and the tooltip line.
- **Cropped pieces are hidden** from the Market list, the buys, the deals and the farm guide values. To see
  them, use Filter > Show cropped pieces or `/smog cropped`. Of 166 pieces, 65 are cropped, 82 skimpy and
  19 bikini. Pieces you add yourself have no grade and always show.
- **Demand.** The scan already reads every chest and leg piece of these armor types. From the pieces that
  are not on the list, the addon keeps the median lowest price per quality and 5-level band, over your
  last 5 scans: what ordinary gear of that level sells for. Suppose your scans have listed a piece 3 times or
  more and its fair value is still under 1.3 times that price. Then nobody pays extra for its look. It is
  never worth buying and does not count in the farm guide. The Market list says "no demand for the look"
  after its name. A piece that sells for far more than ordinary gear scores higher.
- **Pieces the list misses.** Some off-list chest or leg pieces are listed at 3 times ordinary gear of
  their level or more. After a scan, the chat names the top three, with the `/smog add` command for each,
  and `/smog hints` lists up to 10. Crafted pieces are left out.
- A green piece below level 21 no longer counts as rare just because no other item has its look.

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
