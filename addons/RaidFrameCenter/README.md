# Raid Frame Center

Improves the game's own raid frames and party frames:

- **Always centered.** The frames grow out from the middle of the box you placed in Edit Mode, the same amount to each side, whoever joins or leaves, also in combat. Choose whether they grow down, up, or up and down from that middle.
- **Every group takes a 40-man's space.** Smaller groups are scaled up to fill the raid box you see in Edit Mode (set the raid frames' View Raid Size to 40 there once). The layout keeps its proportions, so it fills the box's width or its height, whichever comes first; "Largest fill" (default 300%) caps it.
- **Size by group size.** On top of the fill, a percent for a party and for raids up to 10, 20, 25 and 40 players. "Percent only" turns the fill off.

Move the frames in Edit Mode as usual. While Edit Mode is open they sit on Edit Mode's own anchor, so dragging and saving work as before; the middle of the box you see there is remembered for that Edit Mode layout.

## Setting it up

1. Open Edit Mode, click the raid frames, set View Raid Size to 40 and place the box where the raid should be. Frame Width (up to 144) and Frame Height (up to 72) set the frames' shape.
2. Close Edit Mode. Any smaller group now grows from the middle of that box to fill it.

## Commands

- `/rfc` — options (also Options > AddOns, and the minimap button)
- `/rfc status` — what it is doing now
- `/rfc on`, `/rfc off`
- `/rfc forget` — take the middle again from where Edit Mode puts the frames now

## Limits

- The size per group is a scale on the whole set of frames: width and height keep the shape set in Edit Mode. The game resets each raid frame's width and height on every roster change, and only its own code may lay the frames out again without tainting them.
- An addon may not move or scale the raid frames during a fight. A new size or a changed option waits for the fight to end; the centering itself keeps working in combat because the game resizes the frames around their middle.
