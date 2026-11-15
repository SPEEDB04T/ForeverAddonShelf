# Changelog

## 1.1.1

- Updating from 1.0.0 adds a new file (Ads.lua), so restart the game once: quit and start it again, because /reload is not enough. Until then the ready-made ads stay away and your own ad lines are used.

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
