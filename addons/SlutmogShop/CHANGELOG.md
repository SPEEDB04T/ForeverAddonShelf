# Changelog

## 1.12.4

- The tip thank-you is an emote everybody around sees, with the amount ("Smuttanie thanks Bob for the tip of 5 gold pieces."). The plain thank emote only if the game refuses it.
- A few seconds later, at a random moment, a little whisper to the tipper ("thank you <3" and a few others) instead of the amount whisper.
- Mailbox mode dances less like a bot: never two dances by itself within 15 seconds, it waits a random 3 to 7 seconds before dancing again after a wink, tries at most twice, and does not dance back at somebody while you are dancing already.

## 1.12.3

- A tip that goes through gets a whisper with the amount ("Thank you for the 5g tip!") next to the thank emote.

## 1.12.2

- Emotes at you no longer make a sound, only the taskbar icon flashes. Tips still play the coin sound.

## 1.12.1

- Fixed: the shop no longer gets your /tm raid marking and /invite blocked. It used to set the game's whole slash command list on load, which made the game treat every slash command as touched by an addon; now it only adds its own commands.
- The shop's alerts (somebody at the mailbox, a tip, the ad reminder) play on the Master channel and reach you with the game in the background: the first one turns on Sound in Background if it was off, and says so. Tips also flash the game's taskbar icon.

## 1.12.0

- Tips: when somebody opens a trade and puts in gold while you put in nothing, an "Accept tip" button shows under the trade window, with a coin sound. One click takes it; it lights up once they have accepted. There is also an "Accept a tip" key binding (Key Bindings, AddOns).
- It never accepts a trade where you give gold or any item, or where the shop can't tell.
- When it goes through the shop thanks them with /thank and keeps count: "Bob tipped you 5g. Tips so far: 23g."
- Fully automatic is not possible: the game takes a trade only on a click or a key press.

## 1.11.3

- Mailbox mode dances again more reliably after its winks and smiles: if the game will not take the dance from the shop's timer, it tries again on the next line of chat that comes in (city chat is never quiet for long), until the game shows the dance or 20 seconds have passed.
- The shop keeps a short log of the emotes it tried and what the game said, saved with your settings, so problems like this can be looked into.

## 1.11.2

- Mailbox mode keeps you dancing: any wink or smile from the shop (by itself or on your click) stops the dance in the game, so it now dances again two seconds later instead of five, and after clicked replies too.
- If you stop dancing yourself (/sit, your own emote), the shop leaves it that way until you dance again.

## 1.11.1

- Mailbox mode emotes back by itself every time now, not just once. The shop misread the game's answer to its first emote as a refusal and went buttons-only for the rest of the session.
- It checks the game's echo ("You wink at Bob.") instead: only three emotes in a row that never show up make it stop. If an emote goes out without their name in it, it aims the next one the other way (by nameplate or by name).
- The limits are unchanged: one emote back per person every two minutes, one every six seconds at most.

## 1.11.0

- Mailbox replies are the game's own emotes again, done at the person: Wink, Smile, Giggle, Shy, Wave, Blush, Curtsey and the like. No more custom emote text.
- The button says what it does ("Wink at Bob"); Other emote picks a different one. Somebody who only targeted you gets only the slight ones (wink, smile, giggle, shy, wave).

## 1.10.5

- Mailbox mode no longer lists your own emotes (/hello and the like) as visitors. It now knows them by the game's "You ..." wording and by your character, not only by name.
- Button labels fit their buttons: each button is as wide as its text, and the big Send emote button shortens to "Send emote" when a long name would push it out of the window.
- The emote preview can take two lines instead of running off the window; the help line at the bottom wraps too.

## 1.10.4

- Mailbox: somebody who only targets you can be answered only in the first ten seconds, and only while they still have you targeted. After that their Emote button is greyed out and they leave the big button. If they target you again, the ten seconds start over.

## 1.10.3

- Mailbox: somebody who only targets you gets a little tease now, the way a girl plays with someone looking at her on the street: "catches Bob looking and smiles.", "glances back at Bob over a shoulder.", "pretends not to see Bob, then winks.", "glances back at Bob. Twice." No sales talk, nothing more than that.

## 1.10.2

- Mailbox: somebody who only targets you gets friendly shop talk now ("catches Bob window shopping.", "nods at Bob. Yes, it's for sale."), never the flirty lines. Those stay for people who kiss, wink, flirt or whisper first.

## 1.10.1

- Mailbox buttons say what they do: the line on top reads "Your emote: Smuttanie ...", and the buttons are "Send emote to Bob", "Other line" and "Whisper price". In the list they are "Emote" and "Whisper".

## 1.10.0

- Mailbox replies are custom emotes now, with their name in it: "Smuttanie gives Bob a look that costs extra." They need no target, so they always reach the right person (the 1.9.0 click-to-target did not work in the game).
- The big button shows the line exactly as it will read in chat, in the emote colour. Reply sends it, Another picks a different line. 19 lines, by what they did to you: looked, kissed, winked, flirted, whistled or cheered, hugged, waved, danced, or anything else.
- The row buttons say Reply and send that person's line. The next reply to the same person is a different line.
- Nothing is sent without your click; one reply every two seconds at most, against double clicks.

## 1.9.0

Mailbox mode, reworked.

- Fixed: the Wink button did not wink at the person. A reply button now targets that person and then does the emote, in one click ("You wink at Bob."). They stay your target, so you see who it went to.
- A big button at the top for whoever is waiting for an answer, with what they did above it ("Bob blows you a kiss." / "Wink at Bob"). It pulses, and moves on to the next person once you click. Whoever has waited longest comes first.
- A sound, and the game's taskbar icon flashes, when somebody new looks at you, emotes at you or whispers you.
- Answered people get a tick and their row dims. Rows fade as they get old; lookers leave the list after ten minutes, emoters and whisperers after thirty. Each row shows how long ago it was.
- Somebody who only targets you is listed as "is looking at you" while they do, and "looked at you" after.
- The game showing your own emote going at somebody ("You wink at Bob.") counts as their answer, however you did it.

## 1.8.1

- Fixed: the "run you through Deadmines" line came up for high-level pieces. Lines about a level or a place people outgrow now only come up for pieces of about that level: Deadmines for pieces up to level 25, "Mog it at 20" up to 20, "Hit 40 and finally allowed to wear plate" for level 40 to 49 plate.
- Fixed: `/smog mailbox` did nothing, because `/smog` belongs to Slutmog Scout and the mailbox command was only `/slutshop mailbox`. `/smog mailbox` now turns mailbox mode on, and `/smog shop` opens the shop (`/smog shop post`, `/smog shop mailbox` and the rest work the same way). `/smogshop` is a third name for `/slutshop`.

## 1.8.0

- **Mailbox mode** (`/slutshop mailbox`): for standing around a city mailbox in your wares. The shop starts you dancing and emotes back by itself at whoever emotes at you (a kiss gets a blush, a whistle a curtsey, rude ones get nothing), and winks once at whoever targets you. A small window lists who emoted, whispered and looked, each with the emote as a button and **Pitch**: one whisper with the next ware and its price, only for people who emoted at you or whispered you first. Nothing is whispered or said without your click. Closing the window turns the mode off.

## 1.7.1

- Fixed: "Don't be shy, show some thigh." and "Put the booty back in Booty Bay." could come up for a chest piece. They are legs-only now, and no ad that names a body area can come up for a piece it does not fit.
- A set is one top and one bottom: two tops or two bottoms can no longer be paired, and the right-click menu only offers the other kind.

## 1.7.0

- When it is time for another ad (the reminder), a small window opens in the middle of the screen: the next ad as it will read, the ware's icon (click to try it on), a big **Post ad** button and **Reroll**. **Not now** closes it and asks again after the reminder time. It waits for the end of a fight and stays away while the shop window is open. Options > "Show a Post button with the reminder" turns it off; `/slutshop prompt` shows it now.
- 35 new ad lines and new set lines; the lines voted No on the review page are gone.

## 1.6.2

- Every ready-made ad now says the piece is for transmog: the ending reads "[item] for transmog, 10g at Shop" or "Transmog: [item], 10g on the AH", and set ads say "Mog set: [top] + [bottom]".

## 1.6.1

- Eleven new ad lines on two selling points: the look is bought once and stays on through every gear upgrade up to Naxxramas, and it is cheap now, before the raiders with gold want it.

## 1.6.0

- Sets: sell a top and a bottom together. Right-click a ware > Sell as a set with > the other piece (or `/slutshop set [top] [bottom]`). On the top's turn the ad links both pieces and gives one price for the pair, the two prices added up. The posting panel shows both icons; a click tries the whole set on.
- A set is only advertised while both pieces can be had in the same place (both in your bags, or both on the auction house). Otherwise each piece is advertised alone, as before. The bottom still gets its own ads on its own turn.
- Two item links leave little room, so set ads have their own short lines. A set ad that would not fit in one chat message gives way to an ad for the top alone.

## 1.5.1

- An ad for a ware you carry no longer ends "in my bags right now" or "in stock": it just names the piece, the price and the shop. Only a ware on the auction house says where it is.

## 1.5.0

- The posting panel shows the ware the next ad is for: its icon next to the ad. Hover it for the tooltip, click it to try the piece on in the dressing room.
- New Reroll button (and `/slutshop reroll`): another ad for the same ware. The ad shown is not voted on and comes round again later.
- A ware that is only on the auction house and has been undercut is no longer advertised. Its row says "Undercut on the AH". This needs Slutmog Scout 1.16.1 or newer, which reads the prices (its Sell tab); without Scout nothing counts as undercut.

## 1.4.4

- Ads reworked from the fourth round of Yes/No votes: the 28 lines voted No are gone (most of the short slogans and the cruder name lines).
- 8 new lines after the ones voted Yes: rhymes hung on a place or the shop ("Goldshire by night, Stormwind by day, Smuttanie's makes them look your way."), Booty Bay, gnomes, and "Last buyer hasn't ... since."

## 1.4.3

- Fixed: the shop never saw your auctions. It was reading the old auction house, and this client has the new one. Open the auction house (after posting, or any time) and wares that are up for sale show "On the auction house", stay in the rotation and are advertised at their buyout.
- Ads reworked from the third round of Yes/No votes: the 14 lines voted No are gone.
- 13 new general lines, rhymes among them ("Don't be shy, show some thigh.", "Put the booty back in Booty Bay.").
- 15 new lines for a shop with "Smuttanie" in its name: more in the "Smuttanie keeps you ready!" pattern, plus rhymes and slogans ("Smuttanie's legendary goods: for the ones who would.").

## 1.4.2

- Seven more name lines for a shop with "Smuttanie" in its name, in the pattern of "Long night of grinding with the boys? Smuttanie keeps you ready!": a thing players really say that also reads dirty, then Smuttanie to the rescue.

## 1.4.1

- Ads reworked from the second round of Yes/No votes. The 17 lines voted No are gone, the first five Smuttanie name lines among them.
- 21 new general lines in the vein of the ones voted Yes: favours you get for the look, Goldshire, and true things about the player.
- "Hit your 40s and the gentlemen don't stare like they used to?" is now an ad for every plate piece, not only Tyrant's Legplates.
- Three new name lines, tied to Goldshire, for a shop with "Smuttanie" in its name.

## 1.4.0

- Many more ads: 45 that fit any piece, and every piece now gets all of them. The descriptions written for single looks are gone; they never worked as well as the general lines.
- Five lines that play on the name Smuttanie. They only go out while the shop's name has "Smuttanie" in it.
- A ware on the auction house is advertised as such. Open the auction house once and the shop notes which of your wares are up for sale and at what buyout. Such a ware counts as in stock, its ads end with "on the auction house" and its buyout, and its row in the shop window says "On the auction house". A ware in your bags keeps the direct endings.
- A piece from the slutmog list found among your auctions goes on the shelf by itself, at its buyout price.
- The note about an auction is dropped after two days, or the next time you open the auction house and it is no longer there.

## 1.3.6

- Ads reworked from the Yes/No votes on the review page. The 31 lines voted No are gone: the flat "shows skin" lines, the class call-outs and the digs at your current gear.
- The 8 lines voted Yes stay, and every piece now gets all of them that fit it.
- Five new lines in the same vein, each passed by a fact check and a hostile buyer review: Goldshire, night elves, duel requests, free lockboxes and the Ironforge bank.
- Fewer ads per piece (12 to 16), none of them filler.

## 1.3.5

- Mail is sold to hunters and shamans only. The ads no longer pitch it to warriors and paladins below 40, who will outgrow it: nobody buys a look for armor they are about to replace.
- Gone for the same reason: the "good for bank alts and twinks" lines on low level pieces.

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
