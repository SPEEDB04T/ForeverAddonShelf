# Kneel Together

One call, and everyone in your group who has the addon kneels on the same beat.

Type `/kneelall`. Everyone sees "Kneel in 3 ... 2 ... 1" in the middle of the screen and their character kneels when it runs out, all together. `/kneelall rise` stands everyone up again the same way.

For WoW Forever (Interface 16001).

## Setup

1. Copy the `KneelTogether` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\KneelTogether\KneelTogether.toc` (not `AddOns\KneelTogether\KneelTogether\...`).
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.
3. Everyone who should kneel needs the addon. `/kneelall check` lists who in your group has it.

## Commands

| Command | What it does |
| --- | --- |
| `/kneelall` | Calls the kneel with your usual countdown (3 seconds unless you change it). Put it in a macro for a button |
| `/kneelall 5` / `/kneelall now` | The same with a 5 second countdown / right away |
| `/kneelall me` | Everyone kneels before you, and you stay standing |
| `/kneelall rise` | Everyone stands up again (`rise 5` and `rise now` work too) |
| `/kneelall cancel` | Calls a running countdown off. Your own call: for everyone. Someone else's: you sit it out |
| `/kneelall check` | Who in the group has the addon, and who ignores calls |
| `/kneelall config` | The options window (also: right-click the minimap button, or Options > AddOns) |
| `/kneelall obey anyone` / `lead` / `off` | Whose calls move your character |
| `/kneelall minimap` / `reset` / `status` / `help` | Minimap button on or off, defaults, current settings (plus ignored messages and the last addon messages sent and received), the command list |

A left-click on the minimap button calls the kneel.

## Before whom

- With a player targeted when you call, everyone kneels before that player (the chat line reads "kneels before ..."), you included. The targeted player stays standing.
- `/kneelall me`, or "Kneel before: Me" in the options, makes it you.
- With no player targeted, everyone just kneels.

## Notes

- **Timing.** The call reaches everyone at slightly different moments, so each player's own ping is taken off their countdown. With a countdown of 1 second or more the kneels reach the server together. `/kneelall now` cannot do that, so it is a little looser.
- **Who can call.** Anyone in the group, unless a player picks "Leader and assistants" or "Nobody" under "I kneel for". Nobody outside your group can move your character, and a call can only ever ask for kneeling or standing up.
- **After each call** the caller gets one line: how many knelt, and who did not and why (no addon, was moving, ignores calls).
- **Mounts.** A mounted character does not kneel, so the addon dismounts you just before, never in the air. This can be turned off.
- **Moving** breaks a kneel, as it does when you type `/kneel`.
- **People without the addon.** Turn on "Also say it in group chat" and they get one line ("Kneel in 3!") to do it by hand.
- **Boss fights.** While the game locks chat for addons (some fights), calls cannot go out; the addon says so.
- This version has been checked with an offline test only, not yet in the game.
