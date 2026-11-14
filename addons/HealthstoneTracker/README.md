# Healthstone Tracker

A small window that shows, for everyone in your party or raid, whether they carry a healthstone.

- **Players with the addon** report their own bags: which stone, and how long until they can use one again.
- **Players without it** are worked out from what can be seen: a warlock with the addon trading them a stone marks them *given*, and using one marks them *used*. Until one of those happens they show as `?`.
- **Warlocks** can click a name to open a trade with their healthstone already in it, and `/hst announce` posts who still needs one in group chat.

The window appears when you are in a group with a warlock. In a party it lists everyone; in a raid only the players without a stone.

## What the list says

| Text | Meaning |
| --- | --- |
| `Major`, `Greater`, ... | has that stone (addon) |
| `Major 1:32` | has it, but on cooldown for that long |
| `none` | has no stone (addon) |
| `given` | no addon: a warlock traded them one, not seen used since |
| `used` | no addon: seen using one, so probably has none |
| `?` | no addon, nothing seen yet |

## Commands

- `/hst` shows or hides the window
- `/hst all`, `/hst missing`, `/hst auto` choose who is listed (right-clicking the title switches too)
- `/hst announce` posts who still needs a healthstone in party or raid chat
- `/hst always` shows the window in groups without a warlock too
- `/hst trade` turns click-to-trade on or off (warlocks)
- `/hst lock`, `/hst unlock`, `/hst scale 1.2`
- `/hst demo` adds five pretend players so you can see the window while solo
- `/hst status`, `/hst reset`

## Install

Copy the `HealthstoneTracker` folder into `World of Warcraft\_forever_\Interface\AddOns` and restart the game (a new addon folder is not picked up by `/reload`).
