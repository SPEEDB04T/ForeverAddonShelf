## 1.4.0
- The two hand buttons are now drawn like the game's own weapon-enchant icons next to your buffs: the icon with its enchant border and the time left in small text under it. Nothing is written on the icon any more.
- What is on the weapon shows in that text: gold (white in the last 90 seconds) when the imbue is on, yellow when a different one is, "None" in red with a grey icon when the weapon has nothing. In the last 30 seconds the icon fades in and out, as the game does.
- The list of other imbues is drawn like the game's spell flyout: the same buttons, the same size, the same gap, each column straight under its hand. No panel, title or coloured edges; the advisor's pick is first in the list and the tooltip says so, and your own pick has the game's checked glow.

## 1.3.0
- Looks like part of the game: the frame and the list of other imbues have the game's tooltip look, and the buttons are drawn like the game's own action buttons.
- The edge round a button is the game's action-button border: green when the imbue is on, yellow when a different one is, red when the weapon has none.
- An imbue you picked yourself glows like an active action button (it was a small blue corner). The advisor's pick in the list keeps its green edge.
- Tooltips, chat and the missing-imbue warning use the game's own colours.

## 1.2.0
- Other imbues: point at the frame and a list of every imbue you know opens under it, best first, one column per hand. Click one to put it on that hand. The hand keeps using it (its button shows it, with a small blue corner) until you click the green one in the list, which is the advisor's pick.
- The off hand is worked out for what the main hand really uses, so it follows your own pick.
- The list can stay open all the time or be turned off: `/imbue others hover|always|off`, or "Other imbues" in the options.
- `/imbue pick mh|oh <imbue>` picks without the list (`/imbue pick oh ft`), and `/imbue advisor` goes back to the advisor's picks. Picks are kept per character.
- The missing-imbue warning and `/imbue report` name your pick.

## 1.1.0
- Options window: `/imbue config`, a right-click on the minimap button, or Options > AddOns > Imbue Advisor. Every setting is there, including the ones that had no command before (off-hand Windfury procs, shared Windfury cooldown, Rockbiter threat as a tank, Frostbrand's slow in PvP).
- Minimap button: left-click shows or hides the frame, right-click opens the options, drag moves it. `/imbue minimap` hides it.
- The addon is in the addon list next to the minimap.

## 1.0.0
- First release for WoW Forever (Interface 16001).
- Recommends an imbue per weapon hand from your gear, spec, role and the imbue tooltips.
- Click-to-cast buttons, timers, missing-imbue warning when combat starts.
- /imbue report, /imbue mode, /imbue target, /imbue debug.
