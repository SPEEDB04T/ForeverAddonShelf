# Changelog

## 1.1.4

- The line window and the Follow button are listed for the LookShots screenshot helper, so they can be checked in the game. Nothing changes for players without it.

## 1.1.3

- The options window and the minimap button were redrawn by the shared kit: they now copy the game's own Options rows and its round minimap button.
- Four option names are shorter, so each fits on one line and the rows stay evenly spaced: "Follow without a click", "Sound on call and drop-off", "Say when others drop off", "Lock window and Follow button". The rest of each sentence is in its tooltip.

## 1.1.2

- Fixed: players' copies of the addon probably never heard each other, so a called line never arrived and nobody got a Follow button. The server writes the realm in a message's sender differently from how the game names it ("First Last-CAMWOWUS1Realm9RPPvP" against "RPPvP"), and every message whose sender didn't match was thrown away without a word. Players are now found by their name as the group shows it, space included; the realm only decides between two players with the same name.
- Names inside a called line are matched the same way when they arrive.
- Messages from someone the addon can't find in the group are counted: the window says how many, and `/line status` says from whom and why.
- The last 40 messages in and out are kept in the saved settings, to see afterwards what really happened.
- `/line order` takes full names: `/line order Ann Lee, Bob Ray` (first names alone still work).

## 1.1.1

- Calling a line now says what it did: the one who leads gets no Follow button (the players behind them do), how many players got one, and which players have no Follow Line and need **Announce**.
- `/line demo` on your own puts you second, so the demo shows your Follow button.
- The Follow button keeps to the action bars' own looks: checked while you follow (instead of dimmed), the key turns red when the player ahead is too far (a dot stands in when there is no key), and no more pulsing red.
- The row buttons are all one size, the game's 16 px, with one gap.
- No more "Unrecognized XML" warnings at login (Bindings.xml was listed in the file list; the game reads it by itself).
- Names from other realms with a space or dash in the realm now match the addon messages.

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
