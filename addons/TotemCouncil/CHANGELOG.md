# Changelog

## 1.1.1

- Fixed: plans and live totems were not shared with other shamans on ordinary realms. The addon read a realm setting ("this realm blocks addon messages") that has nothing to do with messages inside a group, and sent nothing. It now sends, and `/totems status` shows the game's answer if a message is ever refused.

## 1.1.0

- Options window: `/totems config`, a right-click on the minimap button, or Options > AddOns. Every bar, warning and plan setting is there, including when a timer turns yellow, which had no command before.
- Minimap button on shamans: left-click opens the group plan, right-click opens the options, drag moves it. `/totems minimap` hides it.
- The addon is in the addon list next to the minimap.
- Temporary totems (Fire Nova, Magma, Stoneclaw, Earthbind, Mana Tide, Grounding, Sentry) are no longer treated like buffs to keep up:
  - Dropping one over your planned totem shows no yellow border, and it does not pulse when it is about to run out. The red missing-totem warning returns once it is gone.
  - Magma and Sentry are no longer adopted as your plan (the others already were not).
  - A shaman without the addon who throws one in between still counts as dropping their usual totem, so a double with it stays marked.
  - Sort it out never gives someone a temporary totem as the one to keep up.

## 1.0.2

- Totem Council users now tell each other which totems they have down and for how long. The orange `x2` between them no longer depends on the game reporting the other shaman's casts, and it clears as soon as their totem is gone. Both shamans need 1.0.2 for this; with an older version it works as before.
- `/totems status` says when the game is hiding another shaman's casts, which is why their totems can't be seen.
- `/totems debug` records what the game reports about your group, to track down a problem.

## 1.0.1

Fixes from a review of 1.0.0. Works together with 1.0.0 in the same group.

- Group messages are only accepted from people in your party or raid. Before, anyone could send a suggestion or proposal box.
- A made-up totem code in a suggestion can no longer put a non-totem spell on a bar icon.
- Accept / Decline boxes: at most six wait their turn, a box that has only just appeared can't be accepted by a stray double-click, and a proposal that was replaced or ran out is no longer asked about or applied.
- Accepting a proposal changes only the totems the box showed, not ones you changed in the meantime.
- Sort it out: the count no longer waits for shamans who left the group, and you are told when your proposal runs out of time.
- Someone asking for your plan over and over can no longer hold back your replies.
- No missing-totem warning while you are dead, or for a totem slot the game hides before anything has been seen in it.
- Timers are cleared after a loading screen or a death instead of counting on in hidden slots.
- Dropping Fire Nova, Stoneclaw, Mana Tide, Earthbind or Grounding no longer makes it your plan.
- The yellow "about to run out" pulse is only for totems that last longer than 15 seconds.
- The orange `x2` is skipped when the other shaman is far away.
- Low-rank Searing Totem uses its own duration when the game hides the slot.
- The tooltip says what left-click really does when you change the plan in combat (the change applies after combat).
- Right-clicking an icon again closes its menu; the tooltip no longer covers the menu.
- `/totems` says whether the bar is now shown or hidden; the welcome line points to `/totems help`.
- A non-shaman announcing in a raid gets the party number on each line.
- Clearer wording in the README, help and tooltips.

## 1.0.0

First release.

- Totem bar: four small icons (earth, fire, water, air) with the time left on each, faded while nothing needs attention.
- Pick the totem to keep up per element (right-click); left-click drops it.
- Warnings: planned totem missing, totem about to run out, a different totem down than planned.
- Group: warns when another shaman in your party has the same totem down, or plans the same one.
- Group plan window: every shaman's totems, doubles outlined in red, works for shamans without the addon too.
- Suggest a totem to another shaman (Accept / Decline), or "Sort it out" to propose a plan with no doubles that each shaman accepts.
- Announce the plan in party or raid chat.
- `/totems demo` to try the group features alone.
