# Raid Frame Center

Improves the game's own raid frames and party frames:

- **Always centered.** The frames grow out from the middle of the box you placed in Edit Mode, the same amount to each side, whoever joins or leaves, also in combat. Choose whether they grow down, up, or up and down from that middle.
- **Size by group size.** A size for a party, and for raids up to 10, 20, 25 and 40 players, in percent of the Edit Mode size (50% to 200%).

Move the frames in Edit Mode as usual. While Edit Mode is open they sit on Edit Mode's own anchor, so dragging and saving work as before; the middle of the box you see there is remembered for that Edit Mode layout.

## Commands

- `/rfc` — options (also Options > AddOns, and the minimap button)
- `/rfc status` — what it is doing now
- `/rfc on`, `/rfc off`
- `/rfc forget` — take the middle again from where Edit Mode puts the frames now

## Limits

- The size per group is a scale on the whole set of frames: width and height keep the shape set in Edit Mode. The game resets each raid frame's width and height on every roster change, and only its own code may lay the frames out again without tainting them.
- An addon may not move or scale the raid frames during a fight. A new size or a changed option waits for the fight to end; the centering itself keeps working in combat because the game resizes the frames around their middle.
