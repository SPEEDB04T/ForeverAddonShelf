# Changelog

## 1.3.0

The window now looks like the game's own auction house list.

- Rows use the auction house's striped row background and its row highlight, instead of flat colour.
- Item icons have the auction house's small icon border.
- Column headers are the game's column header tabs, with the auction house's sort arrow.
- Market, Farm guide and Measured are the game's tabs along the bottom of the window.
- Prices are written with the gold, silver and copper coin icons (coin letters in colourblind mode).
- Text uses the game's colours: gold titles and labels, white values, grey hints, and the game's item quality colours.

## 1.2.0

Options window and minimap button.

- New options window: `/smog config`, a right-click on the minimap button, or Options > AddOns > Slutmog Scout.
  It has the ticks for scanning when the auction house opens and for the tooltip line, and buttons to scan now,
  check the item list, bring back removed pieces, and clear saved prices or measured farms.
- New minimap button: left-click opens the window, right-click opens the options, drag moves it.
  `/smog minimap` hides or shows it.
- The addon is also in the list of addons next to the minimap.
- After updating, restart the game once: a `/reload` does not load the new files, so the options window and
  the minimap button only appear after a restart.
