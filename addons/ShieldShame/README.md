# Shield Shame

For shamans on WoW Forever. Counts the damage and mana you throw away by fighting without
Lightning Shield or Water Shield up, and mocks you for it. Asked for as: "addon to shame me
about how much damage and mana ive lost not maintaining shaman shields". Since 1.3.0 it also
counts the mana Mana Spring Totem would have restored in the fight time you spent without it
("add mana spring totem to the water shield addon to check how much mana is being wasted by
not using it").

Everything is per fight.

- **After a fight that hurt, one line in chat.** A fight hurt when it took your mana (Water
  Shield) or health (Lightning Shield) below 50% (a setting) while a shield was missing. The
  line says how low you went, what the shield would have given you, and for mana where you
  would have bottomed out with it up. Every other fight says nothing.
- A greyed-out shield icon while no shield is up (out of fights, and in fights the moment
  your orbs run out). Under it, where a buff shows its time left, what going without cost you
  in this fight (or the last one). Its tooltip has a jab, what that fight cost, how long your
  shield was up in it, how low it took you, and how many recent fights hurt.
- `/shame` prints the last fight and how many of your recent fights hurt, and what those cost.
- **Mana Spring Totem.** `/shame` also says how much of the fighting in your logged fights had
  a Mana Spring on you, and how much mana the rest left in the ground, next to what a totem
  costs. A fight that took your mana below the line without it gets the chat line too, once
  the totem would have paid for itself in that fight.
- The minimap button's tooltip shows the same.
- "Confess to my group" (off by default): after a fight that hurt, says it in party or raid
  chat as well, at most once a minute.
- `/shame log`: the last 25 fights, hit by hit, to check the counts against the game.

The addon does nothing on other classes: no icon, no minimap button, no events.

## Slash command

`/shame` (or `/shieldshame`): what you lost. `/shame options`, `/shame on` / `off`,
`/shame lightning` / `water` / `auto` (what to count against), `/shame spring` (Mana Spring
Totem counted or not), `/shame lock` / `unlock`,
`/shame test` (show the icon to place it), `/shame log` (the last fights, hit by hit),
`/shame reset` (clears the fight log), `/shame status` (what the addon read: ranks, values,
where each came from).

## The shields on this client

Read from talentsforever.com's export of the WoW Forever beta client (build 1.60.1.70755,
2026-11-13). Not yet checked in the live game.

| Shield | On WoW Forever |
|---|---|
| Lightning Shield | Trainer spell, 7 ranks (learned at 8, 16, 24, 32, 40, 48, 56). 3 orbs. "When a spell, melee or ranged attack hits the caster, the attacker will be struck for X Nature damage. ... Only one ball will fire every few seconds. Lasts 10 min." X = 13, 24, 40, 64, 96, 134, 178 by rank, plus 26.7% of spell power. Talent Improved Lightning Shield: +5/10/15% orb damage. |
| Water Shield | A Restoration talent, one rank. 3 orbs. "When a spell, melee, or ranged attack hits the caster or when one of the caster's spells gets a critical result, 2% of maximum mana is restored ... Only one globe will activate every few seconds. Lasts 10 min." No passive regeneration in its text. Shown with no mana cost. |
| Earth Shield | Not a shaman spell on WoW Forever. If an Earth Shield you cast is ever on you, it counts as "a shield is up". |

Only one of Lightning Shield and Water Shield can be up at a time.

## Mana Spring Totem on this client

Read from the client's own tables on wago.tools (product wowf: SpellEffect, SpellPower,
SpellMisc, SpellDuration; 2026-11-18). Not yet checked in the live game.

| Rank | Spell | Level | Mana every 2 sec | Costs | Over its 5 minutes |
|---|---|---|---|---|---|
| 1 | 5675 | 26 | 4 | 40 | 600 |
| 2 | 10495 | 36 | 6 | 60 | 900 |
| 3 | 10496 | 46 | 8 | 80 | 1,200 |
| 4 | 10497 | 56 | 10 | 100 | 1,500 |

"Summons a Mana Spring Totem with 5 health at the feet of the caster for 5 min that restores
X mana every 2 seconds to group members within 30 yards." It stands for 5 minutes here, not
Classic's 1, so one drop gives back 15 times what it costs and has paid for itself after 20
seconds. Everyone in range gets the "Mana Spring" buff (5677, 10491, 10493, 10494).

## How each number is worked out

**When a gap counts.** Only in a fight (from the moment the game puts you in combat until it
lets you out), only while you are alive and not on a flight path, and only once you know a
shield. Out of a fight nothing is counted: nothing hits you there, and the reminder icon
does the nagging instead. Resting and mounted don't change the count (you are rarely hit
there); they only hide the icon outside fights.

**Is a shield up?** Read from your buffs when the game lets the addon read them. In a fight
the game can hide auras from addons; then the shield you had when the fight started stands
in. The addon spends its orbs itself (one per hit, at most one per orb cooldown, as the game
does), lets it run out after 10 minutes, and puts it back with 3 orbs when you cast a shield
(your own casts stay readable in a fight). Dying removes it.

**A lost orb.** Each hit you take in a fight with no shield up is one orb the shield would
have fired, but at most one per orb cooldown, the way the real shield works. A hit is what
the game reports to addons as a hit on you (`UNIT_COMBAT`: wounds, blocked hits and absorbed
hits; not misses, dodges, parries, resists, immunes or heals). The shield is assumed to be
recast whenever its 3 orbs are spent, which is what "maintaining" it means.

**Damage (Lightning Shield).** Lost orbs x the damage one orb of your best known rank does,
read from that rank's tooltip. When the tooltip can't be read, the rank's base damage from
the table above plus 26.7% of your Nature spell power is used, and `/shame status` says
"estimated".

**Mana (Water Shield).** Lost orbs x the mana one globe gives: 2% of your maximum mana on
WoW Forever, read from the tooltip (a tooltip that gives a flat number is used as it is). Max
mana is read when it can be; in a fight where it is hidden, the last value read is used.
If the tooltip ever names a passive regeneration ("X mana every 5 sec"), X / 5 per second
fought without a shield is added. WoW Forever's text has none, so this part is 0 today.

**Mana (Mana Spring Totem).** Counted next to the shield, not instead of it (a totem and a
shield can both be up). For every second of a fight that counts (above) and in which no Mana
Spring is on you, the fight gets the totem's mana per second: your best known rank's pulse
divided by the seconds between pulses, read from the tooltip (the table above when it can't be
read). Seconds with your mana bar full add no mana: the totem would have had nothing to give.
If the game hides your mana in a fight, they are counted.

*Is a Mana Spring on you?* Yes if the game's water totem slot (`GetTotemInfo(3)`) shows your
Mana Spring Totem, or if a "Mana Spring" buff is on you, whoever's totem it comes from. If the
slot shows another water totem of yours, those seconds are not judged at all: you put
something else there on purpose. If the game hides the slot in a fight, your own casts stand
in: a Mana Spring Totem cast counts for the totem's 5 minutes, another water totem or Totemic
Recall replaces it, and dying removes it. If the game hides your buffs in a fight, the last
readable answer about the buff stands.

*The cost* is read from the game (`C_Spell.GetSpellPowerCost`), else the table above. It is
not taken off the count: the count is what the totem would have restored to you. The cost
decides when the chat line speaks (only once the fight's count is at least one totem's cost)
and is printed next to the total so you can judge it.

**Which shield a gap is counted against.** One, never both (they can't be up together).
Default "the shield I used last": the one you last cast or had on you. Before you have
used either: Water Shield if you have the talent, else Lightning Shield. Options or
`/shame lightning` / `water` pin one. A shield you don't know is never counted against.

**Per fight.** Each fight keeps damage, mana, orbs missed, seconds fought and seconds of
those with no shield. Uptime is seconds with a shield up / seconds fought, counted the same
way as the gaps (in a fight, alive, not on a flight path, a shield known). There is no
session or all-time count. Settings are account-wide (`ShieldShameDB`); the fight log is
per character (`ShieldShameCharDB`).

**A fight that hurt.** While a fight is on, your mana and health are read twice a second and
the lowest of each is kept. The fight hurt if it lost mana and your lowest mana was below the
line (50% by default), or lost damage and your lowest health was below it. "Where you would
have bottomed out" is your lowest mana plus the mana the missing shield had cost you by that
moment (globes lost after the low point would not have lifted it). If the game hides your
mana or health from addons in a fight, a loss of a whole shield's 3 orbs (or 5% of your max
mana) stands in, and the line says only what was lost.

**The fight log.** For each of the last 25 fights on the character (`ShieldShameCharDB.log`):
when, how long, the shield at the start (and whether that came from your buffs or, with
auras hidden, from the addon's own record), whether the game showed your auras during the
fight, the hits seen and what each became (shielded, lost, inside the orb cooldown), shields
cast, seconds with no shield, what was lost, your lowest mana and health, and whether it
hurt. If the numbers look too high, this shows whether the hits were really taken with no
shield up.

## What is an estimate

- **The orb cooldown.** The text says "every few seconds". The addon uses 3 seconds (the
  setting "Time between orbs"). If a tooltip ever gives a number, that one is used.
- **Hits.** The game tells addons that you were hit and by which school, not whether a hit
  was a damage-over-time tick. With "Hits by spells count too" on (default, as the text says
  spells trigger it), a DoT tick can stand in for an orb; the cooldown limits how many.
  Untick it to count only physical hits.
- **Water Shield on your crits.** The real shield also fires when your spells crit. Addons
  can't see your crits on this client (no combat log), so those globes are not counted:
  the mana figure is a low estimate for a caster.
- **Improved Lightning Shield.** The addon trusts the tooltip number. If the game's tooltip
  leaves the talent out, the damage count is up to 15% low. The fallback estimate leaves it
  out as well.
- **Lightning Shield's mana cost** for the recasts is not taken off. These are what you
  lost, not net of what keeping the shield up would have cost.
- **Hidden auras.** While the game hides auras in a fight, the shield's state is the addon's
  model (above), not the game's.
- **Mana Spring: only you.** The count is your own mana. In a group every mana user in range
  would have got the same again; that is not added.
- **Mana Spring: range and a dead totem.** Your own totem standing counts as "on you" even
  when you have walked more than 30 yards away from it, so that gap is not counted. A totem
  that was killed is noticed when the game shows the slot; with the slot hidden, the addon's
  record keeps it for its 5 minutes.
- **Mana Spring: pulses.** Mana is counted evenly per second, not in 2-second pulses, and a
  bar that is a few mana short of full is counted as a whole second's worth.
- **Mana Spring: talents.** The addon trusts the tooltip number. If a talent raises the
  totem's mana and the tooltip leaves it out, the count is that much low.

## Not yet seen in the game

Whether `UNIT_COMBAT` reaches addons for the player on this client with a readable hit type,
whether auras on yourself are hidden in a fight, the real orb cooldown, and how the icon
looks. For Mana Spring Totem: whether the water totem slot is readable in a fight, whether
the "Mana Spring" buff shows among your buffs, and that the totem's numbers in the game match
the client tables. `/shame status` shows what it reads.

## Files

`Core.lua` (spells, counting, slash command), `UI.lua` (the reminder icon), `Kit.lua` (the
shared options window and minimap button, a copy of `shared/Kit.lua`), `Options.lua`.
Tests: `python tests/ShieldShame/run.py`.
