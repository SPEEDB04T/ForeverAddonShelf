# Changelog

## 1.0.1

- Fixed: calling a line failed with "can't send the line: this realm blocks addon messages" on ordinary realms. The addon read a realm setting that has nothing to do with messages inside a group. It now sends, and the status line shows the game's answer if a message is ever refused.

## 1.0.0

First version.

- Order a party or raid into a follow line and call it: the first player leads, everyone else follows the player ahead of them.
- A Follow button (and a key, under Key Bindings > AddOns > Follow Line) for each player in the line.
- A window showing who is following, who is off the line and who has no addon; Regroup nudges those off the line.
- The line closes up by itself when a player leaves the group.
- `/line announce` posts the order in group chat for players without the addon.
- Options window, minimap button and `/line demo`.
