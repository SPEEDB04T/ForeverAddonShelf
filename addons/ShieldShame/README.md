# Shield Shame

For shamans on WoW Forever. Counts the damage and mana you throw away by fighting without
Lightning Shield or Water Shield up, and mocks you for it. Asked for as: "addon to shame me
about how much damage and mana ive lost not maintaining shaman shields".

- A greyed-out shield icon while no shield is up (out of fights, and in fights the moment
  your orbs run out). Under it, where a buff shows its time left, what going without has
  cost you this session ("-1,240", "-34k"). Its tooltip has a jab, what you lost this fight,
  this session and all time, and your shield uptime.
- **Shield uptime**: the share of your fight time with a shield up. The verdict goes by it.
- `/shame` prints the last fight, this session and all time on this character.
- The minimap button's tooltip shows the session and all-time totals.
- **No chat unless you ask.** Nothing is written to chat on its own. Opt-in: "Roast me in
  chat too" (one mocking line for the fights since the last one, once they add up to a whole
  shield's 3 orbs or 5% of your max mana, at most once every 5 minutes, fights in between
  rolled into it) and "Confess to my group" (the roast in party or raid chat as well).
- `/shame log`: the last 25 fights, hit by hit, to check the counts against the game.

The addon does nothing on other classes: no icon, no minimap button, no events.

## Slash command

`/shame` (or `/shieldshame`): what you lost. `/shame options`, `/shame on` / `off`,
`/shame lightning` / `water` / `auto` (what to count against), `/shame lock` / `unlock`,
`/shame test` (show the icon to place it), `/shame reset session`, `/shame reset all`,
`/shame log` (the last fights, hit by hit), `/shame status` (what the addon read: ranks,
values, where each came from).

## The shields on this client

Read from talentsforever.com's export of the WoW Forever beta client (build 1.60.1.70755,
2026-11-13). Not yet checked in the live game.

| Shield | On WoW Forever |
|---|---|
| Lightning Shield | Trainer spell, 7 ranks (learned at 8, 16, 24, 32, 40, 48, 56). 3 orbs. "When a spell, melee or ranged attack hits the caster, the attacker will be struck for X Nature damage. ... Only one ball will fire every few seconds. Lasts 10 min." X = 13, 24, 40, 64, 96, 134, 178 by rank, plus 26.7% of spell power. Talent Improved Lightning Shield: +5/10/15% orb damage. |
| Water Shield | A Restoration talent, one rank. 3 orbs. "When a spell, melee, or ranged attack hits the caster or when one of the caster's spells gets a critical result, 2% of maximum mana is restored ... Only one globe will activate every few seconds. Lasts 10 min." No passive regeneration in its text. Shown with no mana cost. |
| Earth Shield | Not a shaman spell on WoW Forever. If an Earth Shield you cast is ever on you, it counts as "a shield is up". |

Only one of Lightning Shield and Water Shield can be up at a time.

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

**Which shield a gap is counted against.** One, never both (they can't be up together).
Default "the shield I used last": the one you last cast or had on you. Before you have
used either: Water Shield if you have the talent, else Lightning Shield. Options or
`/shame lightning` / `water` pin one. A shield you don't know is never counted against.

**Totals.** This fight, this session (since login or `/shame reset session`) and all time on
this character (saved per character, `ShieldShameCharDB`). Each keeps damage, mana, orbs
missed, seconds fought with no shield, fights that cost you something, and (from 1.1.0)
seconds fought, for the uptime. Settings are account-wide (`ShieldShameDB`).

**Uptime.** Seconds fought with a shield up / seconds fought, counted the same way as the
gaps (in a fight, alive, not on a flight path, a shield known). The all-time uptime only
covers fights from 1.1.0 on.

**The fight log.** For each of the last 25 fights on the character (`ShieldShameCharDB.log`):
when, how long, the shield at the start (and whether that came from your buffs or, with
auras hidden, from the addon's own record), whether the game showed your auras during the
fight, the hits seen and what each became (shielded, lost, inside the orb cooldown), shields
cast, seconds with no shield, and what was lost. If the totals look too high, this shows
whether the hits were really taken with no shield up.

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

## Not yet seen in the game

Whether `UNIT_COMBAT` reaches addons for the player on this client with a readable hit type,
whether auras on yourself are hidden in a fight, the real orb cooldown, and how the icon
looks. `/shame status` shows what it reads.

## Files

`Core.lua` (spells, counting, slash command), `UI.lua` (the reminder icon), `Kit.lua` (the
shared options window and minimap button, a copy of `shared/Kit.lua`), `Options.lua`.
Tests: `python tests/ShieldShame/run.py`.
