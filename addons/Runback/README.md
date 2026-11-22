# Runback

How far the nearest graveyard is from where you stand, and how long the run back from it takes: for you, and for an enemy player who dies here. When you or your group kill a player, a timer bar counts down to the moment they can be back at their body.

For WoW Forever (Interface 16001).

## What you see

- **The readout**, a small tooltip at the top of the screen: the graveyard's name, then a line for you and one for enemy players with the distance and the run back (`412 yd    0:49`). If the other faction uses a different graveyard, it is named above their line.
- **Timer bars** under it, the same bars the game uses for breath and fatigue:
  - **Enemy players** who die near you. While their body lies there the bar says "not released"; when they release it counts down, and at the end it says "can be back" with a sound and a chat line.
  - **Group members** who release: counted from where their ghost really is on the way back.
  - **You**, once you release: counted from where you are to your corpse, including the wait the game puts on your corpse.

The small button at the right of the readout (the same minus/plus button as on the quest tracker) minimizes everything: the bars hide and the readout becomes one line with the soonest countdown. Click it again, or use `/runback min`, to bring it all back.

Point at a bar for the graveyard, the distance and what the countdown is counted from. Right-click a bar to dismiss it. Drag the readout or a bar to move them.

## Setup

1. Copy the `Runback` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\Runback\Runback.toc`.
2. Type `/reload` in the game (or log in).
3. `/runback test` shows three test bars.

## How the numbers are made

- **The graveyard** is the nearest one tied to your zone for the faction, from a list of the original game's graveyards. The first time you release somewhere and land at a graveyard the list does not have (Forever's new zones, or a moved graveyard), the addon notes it and uses it from then on.
- **The run** is the straight line from the graveyard to the body, less the 39 yards from which a corpse can be taken, plus 15% for the path (change it in the options), at ghost speed. Ghost speed is measured on your own ghost the first time you run back; until then it is the classic 125% of running speed (150% for a Night Elf wisp).
- **A second death within five minutes** makes the corpse wait before it can be taken: 30 seconds, then 60, then 120. The bar ends at whichever is later, the run or the wait.

## What it cannot know

- **The combat log is closed to addons on this client.** A kill is noticed when the addon saw the player alive and then dead (on your target, focus, mouse, a nameplate or a group member's target), or from the honor line in chat. A kill that gives no honor and that you never had in view gets no bar.
- **The release** is only seen for a body on your target or focus: the game clears it when they release. Clearing it yourself looks the same. A body you only saw under the mouse or as a nameplate is counted from when it was last seen, and a kill known only from the honor line from the kill itself: in both cases the bar shows the earliest they can be back. The bar's tooltip says which.
- **Where an enemy died** is taken to be where you stand when you see it.
- A resurrection by another player, a soulstone or the spirit healer is not seen. If the player shows up alive, the bar goes.
- **Dungeons and raids**: the game gives no position inside, so everything is counted to the way in, where the corpse is put.
- **Battlegrounds and arenas** are left alone: nobody runs back there.

## Commands

| Command | What it does |
| --- | --- |
| `/runback` (or `/rb`) | Settings, the nearest graveyard in words, and the command list |
| `/runback config` | The options window (also: left-click the minimap button, or Options > AddOns) |
| `/runback test` | Three test bars, on / off |
| `/runback readout always` / `pvp` / `never` | When the readout shows (`pvp`: only while flagged for PvP, or dead) |
| `/runback enemy` / `group` / `own` | Each kind of timer on / off |
| `/runback allowance <0-60>` | Percent added to the straight line for the path |
| `/runback sound` / `chat` | The sound and the chat lines for enemy timers |
| `/runback min` | Minimize / restore the readout and bars (`min on`, `min off` also work) |
| `/runback lock` / `move` | Lock in place / back to the middle |
| `/runback forget` | Forget learned graveyards and the measured ghost speed |
| `/runback on` / `off` / `reset` / `minimap` / `debug` | Enable, disable, defaults, minimap button, bug-report info |

This version has been checked with an offline test only, not yet in the game.
