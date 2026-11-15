# Changelog

## 1.1.2 (2026-11-14)

- Lists the reminder icons for LookShots, the author's screenshot helper, so they can be checked against the game's buff icons. Does nothing without it.

## 1.1.1 (2026-11-14)

- Option labels shortened to fit on one line; the rest of each sentence moved into its tip.
- The options window and the minimap button were redrawn by the shared kit: they now copy the game's own Options rows and its round minimap button.

## 1.1.0 (2026-11-14)

- The reminder icons are now the game's own buff icon (AuraButtonArtTemplate: 30 px, 5 px apart, buff frame strata), greyed out for a missing buff. Gone: the resized action-button frame, its highlight and pushed art, the "1/3" printed on the icon (the bag shows its stack count only from 2, as the buff does) and the "Lost this session" line under the row (it is in the tooltip, the minimap tooltip and /cozy).
- Option "Show what I lost under the icons" removed with that line.

## 1.0.0 (2026-11-14)

- First version: reminder icons for Well Fed, Well-Rested (Cozy Sleeping Bag) and the Camp Tent's rest at a campfire, shown only out of a fight and off at max level or with XP gain off.
- Counts the XP lost to each missing buff, per session and all-time per character; tooltip, chat summary (`/cozy`), minimap tooltip and a line at every level-up.
- Learns the food and bag percents from the buff tooltips; every value is editable in the options.
