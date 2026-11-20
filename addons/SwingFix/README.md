# Swing Fix

Keeps the game's own swing timer bars right, so you can fit swings between casts.

The built-in Main Hand and Off Hand bars only start when a swing happens and then count the swing time they were given. Anything that moves your next swing after that is ignored. With Swing Fix:

- **Casting:** a spell with a cast time starts your swing over when it goes off. The bar starts a full swing at that moment. A cast you stop, or that is interrupted, changes nothing.
- **Parry:** when you parry, your next swing comes sooner. The bar jumps forward by the same amount.
- **Attack speed:** when your attack speed changes in the middle of a swing (Flurry, a haste effect ending), the bar follows.

Wait for the bar to fill after a cast, let the swing land, then cast again.

It draws nothing of its own. The game's swing timer has to be switched on in the game options. Instant spells and the Ranged bar are left alone.

## Commands

- `/swingfix`: what it is doing, and how many corrections it made this session
- `/swingfix on` / `/swingfix off`: correct the bars, or leave them as the game draws them
- `/swingfix log`: keep a short log of swings and casts in the saved file (on by default)

## Install

Copy the `SwingFix` folder into `Interface\AddOns` and restart the game once.
