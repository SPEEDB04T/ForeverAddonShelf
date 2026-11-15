# Changelog

## 1.1.1 (2026-11-14)

- The options window and minimap button were redrawn by the shared kit: they now copy the game's own Options rows and its round minimap button.
- Shorter option labels, so each fits on one line in the new window ("Fade when nothing to say", "Suggest default after a fight", "Show a line on screen"); the rest of each sentence is in the row's tooltip. The "Frame" section is now called "Bar".

## 1.1.0 (2026-11-14)

- The frame is now a second stance bar: the game's own small action buttons at their own 30 px, 2 px apart, with no panel, heading or reason line behind or under them.
- The aura that is on is checked, as on the stance bar; the global cooldown sweeps after a switch; an aura you can't cast right now is dimmed the way the stance bar dims it.
- The tooltip is the stance bar's own aura tooltip, with the reason for the suggestion under it.
- "Faded when it has nothing to say" now starts at 100% (solid, like the stance bar).

## 1.0.0 (2026-11-14)

- First version: suggests the Paladin aura that fits the fight, from the damage schools hitting you and your party, pushed-back casts, enemy casters and enemy player classes, elites and bosses, and how many enemies are in the fight.
- One click-to-cast button per aura you know, drawn with the game's action button art; the suggestion gets the game's spell-alert glow, with the reason under it; the panel has the game's tooltip border. Sound and a line on screen when a switch is suggested in a fight.
- Knows about auras other paladins in your party already have up.
- Play style from your group role or Righteous Fury, or set by hand; your own aura between fights; three sensitivity levels.
- Options window, minimap button, `/aura test` for a pretend fight, `/aura debug`.
