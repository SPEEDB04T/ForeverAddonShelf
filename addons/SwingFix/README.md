# Swing Fix

Corrects the game's own swing timer bars around spell casts, so you can fit swings between casts.

The built-in Main Hand and Off Hand bars start over the moment you begin a cast. With Swing Fix:

- while you cast, the bar keeps counting the swing that was already running;
- when the cast goes off, the bar starts a full swing from that moment;
- a cast you stop, or that is interrupted, changes nothing.

Wait for the bar to fill after a cast, let the swing land, then cast again.

It draws nothing of its own. The game's swing timer has to be switched on in the game options. Instant spells and the Ranged bar are left alone.

## Commands

- `/swingfix`: what it is doing, and how many bar restarts it corrected this session
- `/swingfix on` / `/swingfix off`: correct the bars, or leave them as the game draws them
- `/swingfix log`: keep a short log of swings and casts in the saved file (on by default)

## Install

Copy the `SwingFix` folder into `Interface\AddOns` and restart the game once.
