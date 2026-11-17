# Changelog

## 1.1.2 (2026-11-16)

- Fix: estimated deposits were three times too high (30s where the game took 10s). Estimates
  now use WoW Forever's own deposit table: 5% of the vendor price for 12 hours, 10% for 24,
  20% for 48. Auctions already tracked are corrected the next time you open the auction house.
- Each auction now shows how long it was listed for (12, 24 or 48 hours) in its tooltip, in
  the buyback list and in `/deposits list`. For an auction posted without the addon it is
  judged from the time left and marked with "?"; it no longer shrinks as the time runs down.
- The deposit rate learned from your posts is kept per listing time. `/deposits rates` shows
  the three.
- The "This post" line at the auction house says how long the post is listed for.
- Guildmates and alts share the listing time too; older versions still work alongside.

## 1.1.1 (2026-11-16)

- Fix: deposits came out wrong.
  - The deposit is now the number the auction house showed when you posted. Before, it was
    worked out after the item had already left your bag, which could give 0 or another item's
    deposit.
  - Posting several copies of an item at once makes one auction per copy; each now gets its
    share of the deposit and its own price. Before, the first auction got all of it.
  - When part of a stack sells, only the rest's deposit counts as at risk.
  - An auction matched to the wrong post (one the addon missed) is caught at the first read
    and estimated instead.
  - Estimates use how long the auction was posted for, judged from its time left.
  - Deposit rates learned from the bad reads are dropped once.
  - Your guildmates and alts see the corrected numbers the next time your list is shared.

## 1.1.0 (2026-11-16)

- Mail a bought-back item to its seller with Cash on Delivery. The addon remembers who
  sold each item you buy back and what you paid. At a mailbox a "Send back" list next to the
  mail window takes the item out of the auction house's letter in one click and fills in
  the Send Mail form in the next: the seller, the item, Cash on Delivery for the price, a
  subject. You press Send. `/deposits mail` lists them in chat.
- New file: a `/reload` loads it.

## 1.0.0 (2026-11-16)

- First version. Tracks the auctions of your guild, your group, friends and your alts, and
  works out for each one whether buying it back before it expires saves more deposit than
  the auction house cut costs.
- A raid warning, sound, chat line and a Find it dialog in the last 15 minutes, every 5
  minutes, held until a fight ends.
- A buyback list next to the auction house, with what your current post would lose.
- New addon: a `/reload` loads it.
