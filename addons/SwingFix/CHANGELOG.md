# Changelog

## 1.0.0

- First version. The game's own Main Hand and Off Hand swing timer bars no longer start over when you begin casting a spell. The bar keeps counting the swing that was running, and starts a full swing when the cast goes off.
- A cast you stop, or that is interrupted, leaves the bar alone.
- Instant spells and the Ranged bar are not changed.
- `/swingfix` shows what it is doing, `/swingfix off` gives the bars back as the game draws them.
- Keeps a short log of swings and casts in its saved file (`/swingfix log` switches it off).
- New addon: restart the game once after installing it.
