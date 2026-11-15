# Changelog

## 1.3.4

- The ads are plain now. Three hostile reviews went over every line (does it fit how the game really works, does it read as trying too hard, would a buyer care) and most of the jokes did not survive. What is left says what the piece shows ("Long trousers with both hips cut out. Ankles covered, hips bare.") or talks straight to the player who wants it ("Want your character to look hot instead of well geared?", "Your tier set is ugly. Mog over it.").
- Gone: lines that got the game wrong (character creation, the login screen, benches, armor that swings), the made-up shop staff, and the tacked-on punchlines. Each piece has 11 to 16 ads.

## 1.3.3

- New ads that talk to the person who buys this, the player behind the character: "You'll be looking at her from behind for 300 hours. Choose the view.", "You didn't roll a female character for the casting animations.", "If you're still reading this, you're the customer.", "'It's for the collection.' Of course it is." Fifteen of them, mixed in with the rest; seven weaker lines are gone.
- The ads follow Slutmog Scout's current list: the 19 pieces it took off have no ads any more, and the 16 it added have them (the shared ones for now). 148 pieces, 16 to 23 ads each.

## 1.3.2

- The shared ads are rewritten once more, this time in the shop's own voice: a shameless boutique owner writing straight-faced ad copy. No forced game puns. "Tired of being respected for your personality?", "Refunds if nobody looks. We have never paid one.", "Barely worn. That's how it's worn.", "Not what you'd wear to meet his mother. What you'd wear to meet his father."
- The game only comes in where it fits by itself. Each piece now has 16 to 24 ads.

## 1.3.1

- The shared ads (the ones for any piece, for each armor type, for legs and chests and for level ranges) are rewritten again, after a hostile review of every line. Each one now turns on an everyday word with a dirty second meaning: "Only thing that's gone down on you all week is the server?", "Cleared every instance in the game and nobody's been in yours?", "At 40 everyone gets a mount. In [piece] you might be one.", "Bind on Equip. Bring rope."
- Gone: the /follow line, lines built on terms nobody says, spell-name references with nothing dirty in them, and lines that only described the piece where a dirtier one fits.
- No line plays a low level as a young age; the level 6 vest is now sold for your bank alt.
- Votes from 1.3.0 stay. A line that was reworded counts as a new line.

## 1.3.0

- Yes and No buttons next to Post ad, in place of Skip. Yes keeps the line shown and moves to the next one. No drops that ready-made line from your ads for good, for every piece that shares it. Post ad posts it as before, and the addon counts how often each line went out. Your votes are saved, so the good and bad lines can be told apart and the next rewrite can follow them.
- `/slutshop yes` and `/slutshop no` do the same from chat. `/slutshop votes` lists the lines you voted on, `/slutshop votes reset` (or Options > "Forget my votes") brings every line back. One of your own lines on the Lines tab is only skipped by No: those are yours to edit.
- Ads: every line that didn't rest on something in the game is gone or rewritten. The mount line is now "Ride out of Ironforge in [piece] and count how many people /follow you." New ones use the hunter dead zone, warlock summons, /follow and /drool, lockpicking, the breath bar, the Stockade, Goldshire, durability and Slow Fall.
- Fixed: when the lines left in a round could not be used, the same ad could come up again and again.

## 1.2.1

- The chat lines that told you to restart the game now say /reload, which is all this client needs. 1.2.0's download went out a moment before that fix; everything else is the same as 1.2.0.

## 1.2.0

- All ready-made ads are new. They no longer pun on the item's name. They describe how the piece looks (written from its textures: the strap harnesses, the plate bikinis, the chastity-belt legguards, the spider-web sleeves) or speak to the buyer as a player: plate at 40, repair bills, the healer watching your health bar, getting inspected at the mailbox, "Keep getting ganked, never getting camped?". Transmog as a way to show off gold is in there too. Suggestive, never explicit.
- Each piece now has 17 to 28 ads instead of five: its own, the ones for its look, its armor type, its slot and its level range, and a share of the ads that fit any piece. Each is used once before any repeats. Your request's ad stays first in the Tyrant's Legplates' list.
- Bag scan: every piece from the slutmog list in your bags goes on the shelf by itself, at login and whenever your bags change. It has no price yet ("No price yet" in red) and stays out of the ads until you click it and give it one. A piece you take off the shelf stays off; `/slutshop scan` looks again and takes those back too. Options > "Put pieces from my bags on the shelf" turns it off.
- "N in stock" now also counts the copies seen in your bags, so two of the same piece read "2 in stock" even if the game's own count says one.

## 1.1.1

- Updating from 1.0.0 adds a new file (Ads.lua): type /reload once after updating. Until then the ready-made ads stay away and your own ad lines are used.

## 1.1.0

- Ready-made ads: every piece on the slutmog list (all 166 items Slutmog Scout knows) has five ads written for it, about its name, its cut and where it comes from, with jokes that fit an RP server. Cheeky, never explicit. Your request's ad stays in the Tyrant's Legplates' turns.
- A piece's ads take turns, each used once before any repeats. Wares that are not on the list use your own openers and ad lines, as before.
- New option, Options > Which ads: ready-made only (the default), ready-made and your own lines by turns, or only your own.
- `/slutshop ads [item]` shows a piece's ready-made ads, filled in; without an item it says which of your wares have them. The ware's tooltip in the shop window counts them too.
- New default openers and ad lines, without "Whisper me". If you never changed yours, they are swapped for the new ones; lines you edited stay as they are.
- Item links in the colour format the game client writes (`|cnIQ2:`) now work in `/slutshop add`, `price` and `remove`.

## 1.0.0

- First version. One click posts a shop ad for your slutmog wares: an opener, your shop's name and the next ware as a real item link with its price, for example "Hit your 40s and the gentlemen don't stare like they used to? ~ Smuttanie's Necessities ~ NOW OPEN for all your mogging needs! [Tyrant's Legplates] only 10 gold pieces."
- Post from the minimap button (left-click), the shop window's Post button, a key (Key Bindings > AddOns) or `/slutshop post` (macros work too). The game only lets Trade and General lines go out from a click or a key press, so the addon never posts by itself; a reminder in your own chat says when it is time for the next ad.
- Shop window (`/slutshop`, or right-click the minimap button): drop or shift-click items onto the slot, give each a price, and edit the shop name, openers and ad lines. The next ad is shown exactly as it will read, with its length out of 255.
- Openers and ad lines take turns, each used once before any repeats; wares go in list order or at random. An ad that would not fit in one chat message gets a shorter opener, or none.
- Sold out: wares that are in neither your bags nor your bank drop out of the ads by themselves (can be turned off).
- Posts to Trade, General, any channel you have joined, Say, Yell or Guild. Waits at least a minute between ads (can be changed), and tells you if your ad did not come back in chat.
