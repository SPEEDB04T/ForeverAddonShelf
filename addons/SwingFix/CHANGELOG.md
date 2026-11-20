# Changelog

## 1.1.0

- Parry: when you parry an attack, your next swing comes sooner. The bar now jumps forward by the same amount instead of running late.
- Attack speed: when your attack speed changes in the middle of a swing (Flurry starting or ending, a haste effect), the bar follows it. Before, it kept counting the old swing time.
- Casting: the bar starts a full swing when a spell with a cast time goes off, as before. The first version also tried to undo a bar restart at the start of a cast; the game does not do that, so that part is gone.
- `/swingfix` shows how many cast, parry and attack speed corrections were made this session.

## 1.0.1

- The log now notes how long after each cast your next main hand swing came, next to the weapon's swing time, and what happened to attacks on you (a parry, a dodge, a hit). Nothing changes on the bars.

## 1.0.0

- First version. The game's own Main Hand and Off Hand swing timer bars no longer start over when you begin casting a spell. The bar keeps counting the swing that was running, and starts a full swing when the cast goes off.
- A cast you stop, or that is interrupted, leaves the bar alone.
- Instant spells and the Ranged bar are not changed.
- `/swingfix` shows what it is doing, `/swingfix off` gives the bars back as the game draws them.
- Keeps a short log of swings and casts in its saved file (`/swingfix log` switches it off).
- New addon: restart the game once after installing it.
