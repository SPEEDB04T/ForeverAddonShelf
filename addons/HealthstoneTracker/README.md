# Healthstone Tracker

A small window that shows, for everyone in your party or raid, whether they carry a healthstone, and who has a soulstone.

- **Players with the addon** report their own bags: which stone, and how long until they can use one again.
- **Players without it** are worked out from what can be seen: a warlock with the addon trading them a stone marks them *given*, and using one marks them *used*. Until one of those happens they show as `?`.
- **Warlocks** can click a name to open a trade with their healthstone already in it, and `/hst announce` posts who still needs one in group chat.

- **Soulstones** are listed under that: who carries one and for how long, and whether each warlock can use theirs.

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

## Soulstones

Under the list, the `Soulstones` part shows:

| Line | Meaning |
| --- | --- |
| `Soulstones  1 up` | how many players carry a soulstone right now (`none up` in red when nobody does) |
| player, `24:10` | carries a soulstone that lasts that long (yellow under five minutes) |
| player, `can res` | is dead and can use their soulstone |
| warlock, `ready` | has a soulstone in the bags and can use it |
| warlock, `cd 12:30` | used one; can use the next in that long |
| warlock, `no stone` | off cooldown, but none in the bags |
| warlock, `?` | no addon (or version 1.0.0) and not seen using one |

Who carries a soulstone is read from the buffs of everyone in the group, so it works for players without the addon. A warlock's own stone needs the addon on that warlock; without it, the cooldown is still counted from the moment they are seen using one.

## Commands

- `/hst` shows or hides the window
- `/hst config` opens the options window (also: right-click the minimap button, or Options > AddOns)
- `/hst minimap` shows or hides the minimap button
- `/hst all`, `/hst missing`, `/hst auto` choose who is listed (right-clicking the title switches too)
- `/hst announce` posts who still needs a healthstone, and who has the soulstone, in party or raid chat
- `/hst soul` shows or hides the soulstone part
- `/hst always` shows the window in groups without a warlock too
- `/hst trade` turns click-to-trade on or off (warlocks)
- `/hst min` minimizes the window to its title line and the count, or restores it (`min on`, `min off`). The small minus/plus button at the right of the title does the same
- `/hst lock`, `/hst unlock`, `/hst scale 1.2`
- `/hst demo` adds six pretend players so you can see the window while solo
- `/hst status`, `/hst reset`

## Install

Copy the `HealthstoneTracker` folder into `World of Warcraft\_forever_\Interface\AddOns` and restart the game (a new addon folder is not picked up by `/reload`).
