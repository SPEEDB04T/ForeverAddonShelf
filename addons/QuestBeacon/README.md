# Quest Beacon

You pick up a quest that can't be shared while you are in a group. Quest Beacon tells the group which quest it is and where to get it, in one line of group chat:

> [The Missing Diplomat] can't be shared - pick it up from Brother Thomas, Cathedral Square, Stormwind City (52.6, 44.1) [Map Pin Location]

The link at the end is the game's own map pin link. Anyone can click it to get a pin on that spot, with or without the addon.

Group members who also have Quest Beacon and don't have the quest get that pin by themselves, with the game's arrow pointing at it. The pin goes away when they pick the quest up.

For WoW Forever (Interface 16001).

## Setup

1. Copy the `QuestBeacon` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\QuestBeacon\QuestBeacon.toc` (not `AddOns\QuestBeacon\QuestBeacon\...`).
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.

Only the player who picks the quest up needs the addon. The others need it only for the automatic pin.

## When it speaks

- Only for quests the game says can't be shared, and only while you are in a party (raids too if you switch that on).
- Not when everyone in the group already has the quest.
- Not when a group member called the same quest out in the last ten minutes, and not twice for the same quest in ten minutes.
- If the game does not pass the map pin link on, the line is sent again without it, and the rest of the session goes without the link.
- If chat is locked (a boss fight in an instance), the line waits until it opens again.

## What the line holds

- The quest giver's name. For a quest that starts from an item it says "I picked it up in ..." instead.
- The area and the zone, and the coordinates where you stood.
- The map pin link, where the game allows a pin. Inside a building or cave with its own map, the spot is given on the zone's map. Inside dungeons the game gives no position, so the line has the giver and the zone only.
- A line that would be too long for chat loses the area first, then the written zone and coordinates (the pin carries them), then the end of the quest's name.

## The pin for group members

- You get it only for a quest you don't have, and only while you have no map pin of your own. A pin you set or moved yourself is never replaced or removed.
- The addon cannot tell whether you finished that quest long ago. If you did, click the pin on the map to remove it.
- In the options you can have the pin without the arrow, or nothing.

## Commands

| Command | What it does |
| --- | --- |
| `/beacon` | The options window (also under Options > AddOns and in the addon list next to the minimap) |
| `/beacon on` / `off` | Tell the group, or don't. Pins for other members' calls still work when it is off |
| `/beacon raid` | Raids too, or parties only |
| `/beacon links` | The map pin link in the line, on or off (`links on` also tries it again after the game refused it) |
| `/beacon follow off` / `pin` / `track` | What you get when a group member calls a quest out: nothing, a map pin, or a map pin and the arrow |
| `/beacon test` | Shows in your own chat what the line would be for a quest picked up where you stand. Nothing is sent |
| `/beacon status` / `reset` / `help` | Current settings and the last lines sent and received, defaults, the command list |

## Notes

- Everything travels in the chat line. There are no hidden addon messages, so it works whoever in the group has the addon.
- Two members with the addon who pick the same quest up within the same second can both call it out.
- The last 30 lines sent, received and skipped are kept in the saved settings (`QuestBeaconDB.log`).
