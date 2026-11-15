# Changelog

## 1.0.1

- Fixed: your own line could be taken for someone else's. This game gives a character's name in two parts (first name and surname) but spells the sender of a chat line as "First Last". Where the game did not also send the sender's id, the addon then said the line a second time without the map pin link and left the link out for the rest of the session. Both parts of the name are compared now, for you and for every group member.
- A player you have targeted is named in full in `/beacon test`.
- The saved log (`QuestBeaconDB.log`) keeps how the game spelled each sender and which group member it was taken for.

## 1.0.0

- First version. When you pick up a quest that can't be shared while you are in a group, your group is told in group chat which quest it is and where to get it: the quest giver, the area, the coordinates and a map pin link anyone can click.
- Group members who have the addon and don't have the quest get a map pin on that spot, with the game's arrow to it. The pin goes away when they pick the quest up.
- Nothing is said for shareable quests, when everyone in the group already has the quest, or when a group member called the same quest out in the last ten minutes.
- If the game does not pass the map pin link on, the line is sent again without it.
- `/beacon` opens the options. `/beacon test` shows the line without sending it.
