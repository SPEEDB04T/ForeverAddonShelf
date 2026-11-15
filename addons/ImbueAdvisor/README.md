# Imbue Advisor

A WoW Forever addon (Interface 16001) that works out the best Shaman weapon imbue for each hand from your gear, spec, role and the imbue tooltips, and gives you click-to-cast buttons for them.

## Install

1. Download `ImbueAdvisor-x.y.z.zip` from https://github.com/SPEEDB04T/ForeverAddonShelf/releases.
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns`, so you end up with `AddOns\ImbueAdvisor\ImbueAdvisor.toc`.
3. Restart the game or type `/reload`.

Or use the installer on the Forever Addon Shelf (https://github.com/SPEEDB04T/ForeverAddonShelf/releases/latest): it installs and updates every addon on the shelf.

## Using another imbue

The buttons cast the imbue the advisor works out. When you want a different one, point at the frame: a list of every imbue you know opens under it, best first, one column per hand. Click one and it goes on that hand, and that hand's button keeps using it (it glows in the list). The first one in the list is the advisor's pick; click it to go back.

## Commands

`/imbue` or `/ia`: `config` (options window), `minimap` (minimap button on or off), `report`, `others hover|always|off` (the list of other imbues), `pick mh|oh <imbue>` (use your own choice on a hand), `advisor` (back to the advisor's picks), `mode auto|melee|tank|caster|heal|pvp`, `target <level diff>`, `lock`, `unlock`, `scale <n>`, `warn`, `debug`, `reset`.
