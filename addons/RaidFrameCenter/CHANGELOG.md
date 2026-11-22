# Changelog

## 1.1.0

- Fill the raid box (the new default): every group is scaled up to take the space of the raid box you see in Edit Mode. Set the raid frames' View Raid Size to 40 there once, and a 10-man, a 20-man or a party takes a 40-man's space. It keeps the layout's proportions, so it fills the box's width or height, whichever comes first.
- "Largest fill" (default 300%) keeps a tiny group from covering the screen. The percent sliders still apply on top; "Percent only" gives the old behaviour.
- While Edit Mode is open the frames show Edit Mode's own size, so the box you place there is the real 40-man space.
- `/rfc status` shows the fill in use.

## 1.0.1

- Options: a note on how to get wider frames (Edit Mode's Frame Width and Height for the raid frames, then the size per group here).

## 1.0.0

- First version. The game's raid frames and party frames stay centered on the middle of the box you placed in Edit Mode: they grow to both sides as people join, also in combat. Grow down, up, or up and down from the middle.
- A size for each group size, in percent of the Edit Mode size: party, raid up to 10, 20, 25 and 40. Width and height keep Edit Mode's shape. Changes during a fight wait for it to end.
- `/rfc` options, `/rfc status`, `/rfc on`, `/rfc off`, `/rfc forget`.
