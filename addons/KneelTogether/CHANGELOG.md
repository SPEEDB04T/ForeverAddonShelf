# Changelog

## 1.0.1

- Fixed: every call ended with "could not call it: this realm blocks addon messages". The addon read a realm setting that is on for ordinary realms and has nothing to do with messages inside a group. It now just sends, and only reports a problem when the game really refuses the message.

## 1.0.0

First version.

- `/kneelall`: everyone in the group who has the addon sees a countdown and kneels at the same moment. Each player's ping is taken off their countdown.
- `/kneelall me` or a targeted player: everyone kneels before that player. `/kneelall rise` stands everyone up.
- `/kneelall cancel`, `/kneelall check` (who has the addon), and a line for the caller after each call: who knelt and who did not.
- Options window (`/kneelall config`, right-click the minimap button, or Options > AddOns): countdown, before whom, a group chat line for people without the addon, whose calls you kneel for, dismounting, sound.
