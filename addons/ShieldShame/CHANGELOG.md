# Changelog

## 1.3.0 (2026-11-18)

- Mana Spring Totem (SuccuDev: "add mana spring totem to the water shield addon to check how
  much mana is being wasted by not using it"). Every second of a fight with no Mana Spring on
  you counts as the mana the totem would have restored (your best rank: 4, 6, 8 or 10 mana
  every 2 seconds), while your mana is not full. Another shaman's Mana Spring on you counts
  as having one. Another water totem of yours down (Healing Stream, a cleansing totem, Mana
  Tide, a resistance totem) is a choice, not a gap: those seconds are not judged.
- `/shame` adds it up over your logged fights: "Mana Spring Totem: on you for 35% of the
  fighting in your last 12 fights (8m 20s). Going without left 1,840 mana in the ground; a
  totem costs 60." The same line is in the icon's tooltip and the minimap button's.
- After a fight that took your mana below the line (50%) with no Mana Spring down, the chat
  line says what it would have given you and where you would have bottomed out with it down.
  It only speaks up once the totem would have given back more than it costs to drop (about
  20 seconds without it). With Water Shield missing too, one line names both.
- `/shame log` and `/shame status` show what the addon read: the water totem at the start of
  the fight, seconds with no Mana Spring, totems dropped, the rank's numbers and its cost.
- New option "Count Mana Spring Totem too" (on), or `/shame spring`. A `/reload` is enough.

## 1.2.2 (2026-11-15)

- Fix: ShieldShame no longer stops `/tm` raid marking and `/invite` from working. It used to
  reassign the game's slash command table, and the game blocked those commands in its name.
  It now only adds its own `/shame` command. A `/reload` is enough.

## 1.2.1 (2026-11-15)

- When the options window or minimap button is missing after an update, the message now says
  a `/reload` brings them (on WoW Forever a reload loads new files), not a game restart.

## 1.2.0 (2026-11-15)

- Per fight, not all time (SuccuDev: "theres no point to all time it should be per fight,
  when a fight got me under 50% mana or something"). The session and all-time counts are
  gone, and the old all-time count is removed from the saved data.
- One line in chat after a fight that hurt: a fight that took your mana (Water Shield) or
  health (Lightning Shield) below 50% while a shield was missing. It says how low you went,
  what the shield would have given you, and, for mana, where you would have bottomed out
  with it up ("That fight took you down to 20% mana, and you fought it without Water Shield:
  120 mana (6% of your bar) you never got. With it up you'd have bottomed out at 26%.").
  Every other fight says nothing. Options: "Tell me after a fight that hurt" (on) and
  "A fight hurt below" (10-90%, default 50%). This replaces 1.1.0's roast and its settings.
- The icon shows this fight's loss (or the last fight's), the tooltip this fight's uptime and
  how low it took you, `/shame` the last fight and how many of the logged fights hurt.
- `/shame reset` now clears the fight log; the session and all-time resets are gone.

## 1.1.0 (2026-11-15)

- No chat by default (SuccuDev: "still annoying in chat, overall needs improvement"). The
  roast after costly fights is now opt-in ("Roast me in chat too") and has been turned off
  once for everyone who had it on; turn it back on and it stays on. The addon now only
  writes to chat when you ask (`/shame`, the minimap button, the options).
- The shaming moved onto the icon: what going without a shield has cost you this session
  sits under the missing-shield icon, where a buff shows its time left ("-1,240", "-34k").
- Shield uptime: the share of your fight time with a shield up, in the icon's tooltip, the
  minimap tooltip and `/shame`. The verdict now goes by it. Counted from this version on.
- `/shame` is shorter: one line each for the last fight, the session and all time, leaving
  out a currency you lost none of.
- A fight log: the last 25 fights on each character, hit by hit (shield at the start,
  whether the game showed your auras, hits shielded, lost and inside the orb cooldown,
  shields cast). `/shame log` or the "Print the fight log" button. It is there to check
  the counts against what really happened in the game.

## 1.0.1 (2026-11-14)

- Much less chat (SuccuDev: "water shield addon is annoying in chat"). The line after every
  costly fight is now an occasional roast: it waits until the fights since the last one add
  up to a whole shield's 3 orbs or 5% of your max mana, comes at most once every 5 minutes
  (new setting, 1 to 30), and rolls the fights in between into one line ("Last 4 fights:
  ..."). Every fight is still counted in full; `/shame` prints the whole summary any time.
- The option is now called "A roast in chat now and then". "Confess to my group" now goes
  with the roast.

## 1.0.0 (2026-11-14)

- First version. Counts the damage (Lightning Shield) and mana (Water Shield) lost to hits
  you took in fights with no shield up: one orb per hit, at most one per orb cooldown, valued
  from the shield's own tooltip. Totals for this fight, this session and all time per
  character.
- A greyed-out buff icon while no shield is up, a mocking chat line after a costly fight,
  `/shame` for the totals, totals in the minimap button's tooltip. Optional confession to
  party or raid (off by default).
- Shamans only.
