# Group Graves

When someone in your group dies and releases, the game moves their dot on the map to the graveyard and nobody can see where the body is any more. Group Graves keeps the game's corpse tombstone on your world map where each group member died, with a dot in their class colour, until they are alive again.

Everyone in the group who has the addon shares the positions, so it also works for a death you were not around for.

For WoW Forever (Interface 16001).

## Setup

1. Copy the `GroupGraves` folder into `World of Warcraft\_forever_\Interface\AddOns`, so that the file ends up at `AddOns\GroupGraves\GroupGraves.toc` (not `AddOns\GroupGraves\GroupGraves\...`).
2. Restart the game. A new addon needs a full restart; after an update `/reload` is enough.
3. `/graves test` puts three test markers around you on the world map, so you can see what they look like without anyone dying.

## Where the positions come from

- **Members with the addon** tell the group where they died, and once they have released, where the game says their corpse is.
- **Members without the addon** are marked too, as long as you were in the group when they died: your addon notes where their dot was while they lay dead.
- **If you join later** (or log in), your addon asks the group. Dead members with the addon answer for themselves, and someone who saw the others die passes those on.

Point at a marker to see whose corpse it is, how long ago they died and where the position came from. Several corpses on one spot show in one tooltip. Click a marker to put a waypoint on the corpse; click it again to remove the waypoint.

A marker goes away when the member is alive again, leaves the group, or you leave the group.

## Commands

| Command | What it does |
| --- | --- |
| `/graves` | Current settings and the command list |
| `/graves config` | The options window (also: left-click the minimap button, or Options > AddOns) |
| `/graves list` | The marked corpses in chat. Also a right-click on the minimap button |
| `/graves test` | Three test markers around you, on / off |
| `/graves early` | Mark from the moment of death instead of from the release |
| `/graves names` | Names under the markers, on / off |
| `/graves size <12-40>` | How big the markers are (22 by default) |
| `/graves chat off` / `party` / `always` | The chat line when someone releases (`party`: not in raids) |
| `/graves pvp` | Also in battlegrounds and arenas, on / off |
| `/graves clear` | Forget every marker |
| `/graves minimap` | Minimap button on / off |
| `/graves on` / `off` / `reset` / `debug` | Enable, disable, defaults, bug-report info |

## Notes

- **Dungeons and raids.** The game gives addons no positions inside an instance, so a death in there has no spot of its own. Once a member with the addon releases, the marker shows where the game puts their corpse: at the way in.
- **A member without the addon who releases at once**, or who died before you joined and nobody with the addon saw it, has no marker.
- **Markers appear at the release** by default, because until then the member's own dot is on the body. `/graves early` shows them from the moment of death (slightly faded until the release).
- **Battlegrounds and arenas** are left alone unless you turn them on.
- **The world map only.** There are no markers on the minimap.
- Your own corpse is not marked: the game already does that.
- This version has been checked with an offline test only, not yet in the game.
