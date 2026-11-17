# Changelog

## 1.2.0

- You can see the mana coming back: when a hit gives you mana, blue sparks fly from the piñata into the mana bar on your player frame, and the bar lights up with a sparkle where they land. The hit preview shows it too. Turn it off with "Mana flies to your mana bar" in the options or `/pinata flow`.

## 1.1.1

- The coin sound is off to start with: it could ring every few seconds. It is switched off once for everyone who had 1.1.0; turn it back on with "Coin sound when it pays mana" in the options or `/pinata sound`.

## 1.1.0

- Hit it: every hit on a piñata enemy knocks the piñata aside with a squash and bounce, and a mana-blue sparkle bursts out of it. Critical and crushing blows land harder, glancing blows softer, a miss only makes it sway.
- The hit that gives you mana bursts biggest and plays the game's coin-loot sound.
- `/pinata preview` (or "Preview hits" in the options): a stand-in nameplate in mid-screen takes a string of blows, so you can see it without a paladin.
- New options under "Hits": bounce and sparkle on / off (`/pinata juice`), coin sound on / off (`/pinata sound`).
- LookShots now lists the hit preview instead of frames on nameplates, which the game hides from screenshot helpers.

## 1.0.5

- If the options window's files are missing after an update, the chat line now says a /reload brings them, not a game restart.

## 1.0.4

- Lists the first piñata and the first blue health bar on screen for LookShots, so they can be checked in a screenshot. Does nothing without LookShots.

## 1.0.3

- The options window and minimap button are redrawn by the shared kit: they now copy the game's own Options rows and its round minimap button.
- Shorter option labels, so every row fits on one line; the rest of each sentence is in the row's tooltip.

## 1.0.2

- The game's own marks on the health bar stay on top of the blue: the target border, the darkening on enemies you have not targeted, the mouse-over highlight and the health text. Before, a blue enemy you had not targeted looked like your target.

## 1.0.1

- The blue health bar uses the game's own mana-bar blue, so it looks like a mana bar.
- The options window and minimap button follow the game's own look.

## 1.0.0

First version.

- A swinging piñata over the nameplate of every enemy with Judgement of Wisdom, from any paladin. Works in fights.
- That enemy's health bar turns mana blue for as long as the debuff lasts (`/pinata bar` turns this off).
- `/pinata test` shows a test piñata on every nameplate for sizing and placing it.
- Options window (`/pinata config`, the minimap button, or Options > AddOns): on / off, blue health bar, size, position, swing.
