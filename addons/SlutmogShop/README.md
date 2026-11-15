# Slutmog Shop

Advertise your slutmog wares with one click. Each ad names your shop and the next piece from your stock as a real item link with its price:

> Hit your 40s and the gentlemen don't stare like they used to? ~ Smuttanie's Necessities ~ NOW OPEN for all your mogging needs! [Tyrant's Legplates] only 10 gold pieces.

## Ready-made ads

Every piece on the slutmog list (the 166 items Slutmog Scout knows) comes with five ads of its own, written for that piece: its name, its cut, where it comes from, with in-world jokes for an RP server. Cheeky, never explicit. For example:

> Tyrants demand much of their subjects and very little of their trousers. [Tyrant's Legplates], 10 gold pieces ~ Smuttanie's Necessities

> Spiders lure their prey with silk. Results in Stormwind are similar. [Arachnidian Robes], 4 gold pieces at Smuttanie's Necessities.

A piece's ads take turns, each used once before any repeats. Wares that are not on the list use your own openers and ad lines (below). `/slutshop ads [item]` shows a piece's ads filled in; **Options > Which ads** picks ready-made ads only (the default), ready-made and your own by turns, or only your own.

## Posting an ad

Any of these posts the next ad:

- left-click the minimap button,
- the **Post ad** button in the shop window,
- a key you set under Key Bindings > AddOns > Slutmog Shop,
- `/slutshop post` (also from a macro on your action bar).

The game only lets an addon send a line to Trade or General from a click or a key press, so Slutmog Shop never posts by itself. After an ad it can remind you in your own chat when it is time for the next one (5 minutes to start with; change it in the options).

## The shop window

`/slutshop`, or right-click the minimap button.

- **Wares**: drop an item on the slot, or shift-click one in your bags (or the auction house) while the window is open. Type a price and press Enter or click Add. Click a ware to change its price; right-click it to advertise it next, move it or remove it. A ware you no longer have in your bags or bank is greyed out and left out of the ads.
- **Lines**: your shop's name, the openers (one per line) and the ad lines (one per line), for wares without ready-made ads (or for all of them, see Which ads). Ad lines use fill-ins:
  - `{opener}`: one of the openers
  - `{shop}`: the shop's name
  - `{item}`: the next ware as an item link
  - `{price}`: its price ("10 gold pieces", or "10g" if you pick short prices)
  - `{items}`: as many wares with prices as fit ("[A] 10g, [B] 25g")
  - `{level}`: the ware's required level (openers can use it too)
- **Post to**: Trade, General, any channel you have joined, Say, Yell or Guild. Trade only works in a capital city.
- At the bottom: the next ad exactly as people will read it, and its length (a chat line holds 255; an item link counts about 60 more than its name). **Skip** picks another one.

Openers and ad lines take turns, each used once before any repeats. If an ad is too long for one chat message, a shorter opener is used, or none.

## Commands

| Command | |
|---|---|
| `/slutshop` | open or close the shop window |
| `/slutshop post` | post the next ad |
| `/slutshop skip` | pick another ad without posting |
| `/slutshop preview` | show the next ad in your own chat |
| `/slutshop add [item] 10g` | add a ware or change its price (shift-click the item into the line) |
| `/slutshop remove [item]` | stop selling it |
| `/slutshop list` | your wares |
| `/slutshop ads [item]` | a piece's ready-made ads (without an item: which wares have them) |
| `/slutshop channel Trade` | where ads go |
| `/slutshop options` | the options |
| `/slutshop status` | what the shop is set to |

`/mogshop` works the same.

## Options

Shortest gap between ads (60 seconds), the reminder and its sound, which ads (ready-made, by turns with yours, or only yours), whether only wares you still have go in, the order of wares, how prices read, and the minimap button.
