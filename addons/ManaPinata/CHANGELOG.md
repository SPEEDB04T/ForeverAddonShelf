# Changelog

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
