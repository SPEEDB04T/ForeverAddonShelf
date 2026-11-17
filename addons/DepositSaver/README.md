# Deposit Saver

For WoW Forever. Tells you when an auction from your guild, your group, a friend or one of
your own alts is about to expire with a deposit worth saving, so someone can buy it back
instead. Asked for as: "track when its worth it to buy one of our groups items (or one of my
alt accounts items) to save on deposit cost (ie, deposit loss is greater than 5%)".

## The trick

When an auction expires, the deposit is gone. When it sells, the deposit comes back and the
auction house keeps a cut (5% at the faction auction houses). So when an auction is about to
run out, a guildmate or an alt on another account can buy it for its buyout, hand the item
back, and the seller only loses the cut instead of the deposit. It is worth it when

    deposit > cut% x buyout

The saving is the difference. Deposit Saver tracks every auction it knows about, works this
out for each one, and warns when it's time.

## What it does

- **A loud warning in the last 15 minutes.** A raid warning in the middle of the screen with
  the raid warning sound, a chat line with the item link, and the game's dialog with
  **Find it** (opens the item at the auction house, or as soon as you open it), **Later** and
  **Stop for this one**. It says whose auction it is, the item, the buyout and what buying it
  back saves. It repeats every 5 minutes and never shows in a fight: a warning that comes due
  in combat waits until the fight ends.
- **Your own auctions too.** You can't buy your own, so the warning tells you to have an alt
  or a guildmate buy it (turn this off in the options).
- **A buyback list next to the auction house.** Every tracked auction with its time left, the
  deposit lost if it expires, the cut a buyback costs and whether it's worth it. Left click
  finds the item, right click stops warnings for it. At the top, while you post: what this
  post would lose if it expires, and how much a buyback would save.
- **Sharing.** Each character shares the auctions of every character on its account (as last
  seen) with the guild and the party or raid. For characters on your other accounts or
  friends outside the guild: `/deposits add First Last`. Lists are remembered, so warnings
  still come when the seller is offline.

## Where the numbers come from

- **Deposit:** read when you post (the game's own deposit for that post). For auctions posted
  before the addon was installed, or by someone else without it, an estimate from the item's
  vendor price, marked "about".
- **Time left:** the game's own time left when the auction house gives it; otherwise the
  start of its time-left band, marked "about".
- **Commodities** (stackable goods) can't be bought back one seller at a time: the cheapest
  units sell first. They are listed and flagged but the buyback may hit someone else's.

## Slash command

`/deposits` (or `/depositsaver`): options. `/deposits list` (every tracked auction),
`/deposits test` (a sample warning), `/deposits sync` (ask everyone again),
`/deposits add First Last` / `remove First Last` (share by whisper), `/deposits who` (the
whisper list), `/deposits panel` (show or hide the buyback list), `/deposits status` (what the
addon read and sent), `/deposits clear` (forget other people's auctions).

## Not yet seen in the live game

Built against the WoW Forever client's interface code and tested offline. Not yet checked in
game: the time left the auction house reports for your own auctions, the deposit rates and
auction lengths, the post hook, the Find it search, whispers to characters on other accounts,
and how the list looks next to the auction house.
