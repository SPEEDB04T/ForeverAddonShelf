# Turn-in Route

Plans the trip that hands in your finished quests. It doesn't just go nearest-by-yards: it goes zone by zone and town by town, using your flight paths, hearthstone, boats, zeppelins and the Deeprun Tram. The trip is split into numbered legs:

```
1. Hearth to Goldshire (3), 2 min
2. Fly to Sentinel Hill (2), 4 min
3. Take the boat to Auberdine, then ride to Darkshore (1), 7 min
```

- **Window:** `/turnin`. Each leg is a quest log header with its quests under it. Click a leg to point the game's quest arrow at it. Two lists sit under the route: group, dungeon and raid quests (hand those in with your group), and quests nobody knows the turn-in place for.
- **Follow the route:** the Follow route button, or `/turnin next`, super tracks the first stop. Once you hand it in, the arrow moves to the next stop. Tracking anything else ends this.
- **Quest log:** with ForeverCore installed, the route is a side tab of the quest log. Without it, the quest log gets a side button that opens the window.
- **Options:** `/turnin config`, or right-click the minimap button.

## What it knows about your travel

- **Flight paths:** learned per character each time you open a flight master's map. Until then the route walks or rides.
- **Hearthstone:** the inn comes from the game (`GetBindLocation`). The spot is learned when you bind there, when you arrive by hearth, or roughly when you pass through that town. The hearth is used at most once per route, only if it will be ready by then.
- **Boats, zeppelins, tram:** the ones your faction can ride, plus the neutral Booty Bay to Ratchet boat. Each counts as about 4 minutes including the wait (the tram 2.5).
- **Speed:** your mount's speed once you have ridden it, otherwise running speed.

Times are estimates. Flights count as straight lines × 1.25 at the taxi speed plus 25 s, and each hand-in adds 8 s.

## How the order is chosen

1. Quests handed in within 15 yards of each other are one stop (one NPC).
2. Stops in one zone within 250 yards of each other, chained, are one place: a town or a camp. Each place is one leg. A place is named after the flight path, inn or dock beside it, or else its part of the zone ("north-east Westfall").
3. The places are put in the order that takes the least time. Up to 9 places this is exact; above that it uses nearest-first, then 2-opt. Going back to a zone the route already left costs an extra 10 minutes, so each zone is finished in one go.
4. Inside a place, the stops are walked nearest-first from where you arrive, then straightened with 2-opt.

Turn-in places come from the game's own quest pins (the world map). With Questie installed, Questie fills in the ones the game has no pin for.

## Commands

`/turnin` (also `/turnins`, `/turninroute`): `list`, `next`, `stop`, `log`, `config`, `hearth`, `flights`, `boats` (each turns that part of the planning on or off), `forget`, `scale <n>`, `minimap`, `reset`, `debug`.
