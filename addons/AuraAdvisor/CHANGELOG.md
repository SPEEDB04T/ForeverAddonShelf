# Changelog

## 1.2.3 (2026-11-15)

- A warlock's own Hellfire no longer counts as Fire damage, so it doesn't suggest Fire Resistance Aura. The burn a party warlock takes from their own Hellfire, and the health Life Tap costs, are left out. Fire and Shadow hits from enemies, on them or anyone else, still count.
- Less wordy: the line on screen, the chat line and the tooltip line are two words at most, such as "Fire Resistance", "Switch now" or "Already up". The reasons are still in /aura and the options window.

## 1.2.2 (2026-11-15)

- Quiet while you're dead or a ghost: no glow, sound, line on screen, chat line or tooltip line. Your aura is gone and nothing can be cast, so it waits until you're back on your feet; then it quietly suggests an aura to put back on (with a sound only if you're back in a fight). The hits from the fight you died in are forgotten.

## 1.2.1 (2026-11-15)

- If the options window or minimap button isn't there yet right after an update, the message now says a /reload brings it (it used to say to restart the game).

## 1.2.0 (2026-11-15)

- No bar of its own any more. The aura to switch to now glows on the game's own stance bar, and on any action bar button that holds it, with the game's proc glow.
- In a fight the suggestion stays up until you switch, another aura takes over or the fight ends. Before, it went away as soon as the hits paused.
- Hover an aura on the stance bar or an action bar: the game's tooltip now has the advice under it.
- New option "Glow the aura to switch to" (`/aura glow`). The bar's settings (show, lock, size, fade) are gone, with their slash commands.

## 1.1.2 (2026-11-14)

- Lists the aura bar for LookShots, the developer's screenshot helper, so the bar can be checked in the game. Does nothing for anyone without that helper.

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
