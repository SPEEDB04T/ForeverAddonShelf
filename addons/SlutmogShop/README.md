# Slutmog Shop

Advertise your slutmog wares with one click. Each ad names your shop and the next piece from your stock as a real item link with its price:

> Hit your 40s and the gentlemen don't stare like they used to? ~ Smuttanie's Necessities ~ NOW OPEN for all your mogging needs! [Tyrant's Legplates] only 10 gold pieces.

## Ready-made ads

Every piece on the slutmog list (the 148 items Slutmog Scout lists) comes with about 85 ready-made ads that wink at the player who wants their character to look hot. A ware in your bags and a ware on the auction house get different endings: open the auction house once and the shop knows which of your wares are up for sale, and at what buyout. With Slutmog Scout installed, a ware you have been undercut on is left out until you are the cheapest again. Suggestive, never explicit. For example:

> Keep getting ganked, never getting camped? Give them a reason to stay. [Tyrant's Legplates], 10 gold pieces at Smuttanie's Necessities.

> Gets you inspected. Then whispered. [Tyrant's Legplates], 10 gold pieces at Smuttanie's Necessities.

> The Goldshire inn has an upstairs. Now you're dressed for it. [Lord's Legguards] is on the auction house for 15 gold pieces. ~ Smuttanie's Necessities ~

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

- **Wares**: drop an item on the slot, or shift-click one in your bags (or the auction house) while the window is open. Type a price and press Enter or click Add. Click a ware to change its price; right-click it to advertise it next, sell it as a set with another ware (a top and a bottom: one ad links both, at the two prices added up), move it or remove it. A ware you no longer have in your bags or bank is greyed out and left out of the ads. A piece from the slutmog list that turns up in your bags is put on the list by itself, marked "No price yet", and stays out of the ads until you give it a price.
- **Lines**: your shop's name, the openers (one per line) and the ad lines (one per line), for wares without ready-made ads (or for all of them, see Which ads). Ad lines use fill-ins:
  - `{opener}`: one of the openers
  - `{shop}`: the shop's name
  - `{item}`: the next ware as an item link
  - `{price}`: its price ("10 gold pieces", or "10g" if you pick short prices)
  - `{items}`: as many wares with prices as fit ("[A] 10g, [B] 25g")
  - `{level}`: the ware's required level (openers can use it too)
- **Post to**: Trade, General, any channel you have joined, Say, Yell or Guild. Trade only works in a capital city.
- At the bottom: the next ad exactly as people will read it, and its length (a chat line holds 255; an item link counts about 60 more than its name). **Post ad** posts it. **Yes** and **No** move on to the next one without posting and save what you thought of the line; No drops a ready-made line from your ads for good.

Openers and ad lines take turns, each used once before any repeats. If an ad is too long for one chat message, a shorter opener is used, or none.

## Commands

| Command | |
|---|---|
| `/slutshop` | open or close the shop window |
| `/slutshop post` | post the next ad |
| `/slutshop skip` | pick another ad without posting |
| `/slutshop yes`, `/slutshop no` | say whether the next ad is a good line; no drops it from your ads for good |
| `/slutshop votes` | the lines you voted on; `/slutshop votes reset` forgets them |
| `/slutshop preview` | show the next ad in your own chat |
| `/slutshop add [item] 10g` | add a ware or change its price (shift-click the item into the line) |
| `/slutshop remove [item]` | stop selling it |
| `/slutshop list` | your wares |
| `/slutshop scan` | look through your bags for pieces from the slutmog list and put them on the shelf |
| `/slutshop reroll` | another ad for the same ware |
| `/slutshop prompt` | the Post button in the middle of the screen, now |
| `/slutshop mailbox` or `/smog mailbox` | mailbox mode on or off (below) |
| `/slutshop set [top] [bottom]` | sell two of your wares as a set, one ad for both (`/slutshop unset [item]` undoes it) |
| `/slutshop ads [item]` | a piece's ready-made ads (without an item: which wares have them) |
| `/slutshop channel Trade` | where ads go |
| `/slutshop options` | the options |
| `/slutshop status` | what the shop is set to |

`/mogshop` works the same.

## Options

Shortest gap between ads (60 seconds), the reminder and its sound, which ads (ready-made, by turns with yours, or only yours), whether pieces from your bags go on the shelf by themselves, whether only wares you still have go in, the order of wares, how prices read, and the minimap button.

## Mailbox mode

For standing around a city mailbox in your wares. `/slutshop mailbox` opens a small window and starts you dancing; closing the window turns the mode off.

- **Emotes back by itself.** Somebody winks, whistles, kisses, flirts, dances or waves at you and the fitting emote goes back (a kiss gets a blush, a whistle a curtsey). Rude emotes get nothing. Somebody who targets you gets one wink. At most one emote per person in two minutes and one in six seconds overall, then you go back to dancing.
- **The list** shows who emoted at you, who whispered you (with what they said) and who has you targeted (this needs nameplates shown). Nothing is saved; the list is gone when you log out.
- **One-click replies.** Each row has the emote as a button, and **Pitch** for people who emoted at you or whispered you first: one whisper in the shop owner's voice with the ware whose turn it is and its price ("Staring is free. [item] is 10 gold pieces."). Once per person in ten minutes. The shop never whispers or speaks without your click, and never pitches somebody who only looked.
- If the game refuses emotes from addons, the window says so and the emote buttons do the same with a click.
- It reads emotes in English.
