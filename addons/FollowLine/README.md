# Follow Line

Puts your party or raid into a follow line: one player leads, and everyone else follows the player directly ahead of them. One player orders the line and calls it; everyone sees who is on the line and who dropped off.

- **The caller** opens the window with `/line`, puts the players in order (the first one leads) and presses **Call line**.
- **Everyone else with the addon** gets a **Follow** button naming the player ahead of them. A click on it, or the key you give it, starts the follow. The player who leads gets no button (they have nobody to follow), and players without the addon get none either: chat tells the caller who got one. To see the button on your own, try `/line demo`.
- **The window** shows each player's state, so the caller can see at a glance who is not following, and **Regroup** nudges exactly those players.
- **Players without the addon** can still be put in the line: `/line announce` posts the order in group chat and they type `/follow` themselves.

## Why a button and not automatic

The game starts a follow only from the player's own click or key press, so the addon gives you one button and one key for it instead of doing it for you. Set the key under **Key Bindings > AddOns > Follow Line**.

There is an option, "Follow without a click, where the game allows it" (`/line auto`), for clients that do let addons start a follow. It is off to begin with, and if the game refuses it turns itself off again.

During a fight the game does not let an addon change the Follow button. If the line changes then, chat tells you who to `/follow`, and the button catches up when the fight ends.

## What the window says

| Text | Meaning |
| --- | --- |
| `leads` | first in the line |
| `following` | following the player ahead of them |
| `off the line` | has the line, but is not following right now |
| `not got it yet` | has the addon, but has not received this line yet |
| `no addon` | no Follow Line seen: the addon can't tell whether they follow |
| `offline` | offline |

The arrow buttons move a player one place, minus takes them out, and plus puts a player from "Not in the line" back at the end. A changed order is only sent when you press **Call line** again.

If a player leaves the group, the line closes up by itself: whoever was behind them follows the player who was ahead of them.

## Commands

`/line` (also `/followline`, `/fline`)

| Command | Does |
| --- | --- |
| `/line` | show or hide the window |
| `/line call` | send the order to the group and start the line |
| `/line stop` | end the line for everyone |
| `/line regroup` | nudge everyone who is off the line |
| `/line order Ann Bob Cid` | put these players first, in this order |
| `/line head Ann` | make this player the leader |
| `/line add Ann`, `/line remove Ann` | put a player in, or take them out |
| `/line reverse` | turn the order around |
| `/line distance` | keep the leader, order the rest by who stands nearest |
| `/line announce` | post the order in group chat |
| `/line status` | list the line and everyone's state in chat |
| `/line who auto`, `leader`, `anyone` | whose line calls you take |
| `/line auto` | follow without a click, where the game allows it |
| `/line sound`, `/line alerts` | sounds, and chat lines when someone drops off |
| `/line config` | the options window |
| `/line minimap` | show or hide the minimap button |
| `/line lock`, `/line scale 1.2` | lock the window and button in place, set their size |
| `/line demo` | four pretend players, to see how it looks without a group |
| `/line reset` | every setting back to how it started |

A name's first letters are enough wherever a player is named.

## Whose calls you take

- **Auto** (the default): anyone in a party; only the leader and the assistants in a raid.
- **Leader**: only the group's leader (and a raid's assistants).
- **Anyone**: anyone in the group, in a raid too.

## Limits

- A follow breaks when the player moves by themselves, and the game drops it when the player ahead gets too far away or out of sight. The addon tells you and the caller when that happens; it cannot hold the follow for you.
- The player ahead has to be within follow range (about 28 yards) for a follow to start. The button says when they are too far.
- Up to 40 players in a line.
