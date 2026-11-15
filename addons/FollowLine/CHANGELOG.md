# Changelog

## 1.1.0

Looks like part of the game's own UI.

- The Follow button is an action button now (the action bars' slot, frame, highlight and pressed art), with your key in its corner, and it flashes red the way an action button does while you are off the line. Who to follow is written beside it in the game's gold.
- The line window is the game's standard window: stone frame, title bar, close button (Escape closes it too) and marble inset, with the game's red buttons for the six commands. "Call line" lights up while there is an order to send.
- In the list, the game's arrow buttons move a player, minus takes them out and plus puts them back; rows light up like the quest log's.
- Text and states use the game's colours: gold, white, green for following, red for off the line, grey for no addon or offline.

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
