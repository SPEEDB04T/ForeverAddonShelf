# Totem Council

A WoW Forever addon (Interface 16001) for Shamans: a small, quiet totem bar with the time left on each totem, a warning when a totem you want up is missing, and a shared group plan that spots two shamans dropping the same totem and lets them settle it together.

## What you get

**The bar.** Four totem buttons, earth, fire, water, air, drawn like the game's own totem bar. Each shows the totem that is down, with its time left underneath the way a buff shows it. Out of combat the bar is faded while everything is fine; in combat it is fully visible. It shows state quietly, the way the game does:

| You see | It means |
| --- | --- |
| A grey icon | The totem you planned is not down (the bar lights up and pings in combat; `/totems warn` also warns out of combat) |
| The icon fading in and out | In combat, a totem you keep up (not a temporary one, and lasting longer than 15 seconds) runs out within 10 seconds, like a buff that is running out. The time turns white under a minute, as on buffs |
| A small red dot in the corner | A clash: another shaman in your party has the same totem down right now, or plans the same one as you. Hover for who |

A different totem down than the one you planned is only told in the icon's tooltip.

- Right-click an icon to pick the totem you want kept up for that element. That is your plan.
- Left-click an icon to drop the planned totem (on by default; `/totems click` turns it off).
- Drag an icon to move the bar (it starts unlocked), then `/totems lock`.
- An empty plan slot adopts the first totem you drop in it, so the bar sets itself up as you play. The temporary ones (Fire Nova, Magma, Stoneclaw, Earthbind, Mana Tide, Grounding, Sentry) are never adopted; pick them by right-click if you want them planned. Other Totem Council users in your group see your plan, and the bar warns in combat when a planned totem is missing. `/totems adopt` turns adopting off.

**The group plan.** `/totems plan`, a left-click on the minimap button, or "Group plan..." at the bottom of an icon's right-click menu. One row per shaman, one column per element, each totem drawn as a totem-bar button (grey when it is not down).

- Shamans who have Totem Council share their plan automatically.
- Shamans without it still show up: the addon lists what they are seen dropping, and treats that as fixed.
- **Temporary totems** are the ones you drop for a moment, not keep up. Dropping one over your planned totem is left alone (no yellow border, no pulse); the missing-totem warning comes back when it is gone. A shaman without the addon who throws one in between still counts as dropping their usual totem.
- A totem planned twice in the same party gets the red dot. Totems where two are not a waste (Searing, Magma, Fire Nova, Healing Stream, Mana Tide, Tremor, Earthbind, Stoneclaw, Grounding, Sentry) never count.
- Click your own totem to change it. Click another addon user's totem to suggest one: they get an Accept / Decline box like the game's own pop-ups.
- **Sort it out** works out a plan with no doubles and sends it to everyone. Each shaman accepts or declines their own change, the proposed totems are highlighted, and the window shows who has answered. Shamans without the addon keep their totems; between two addon users, the one earlier in the alphabet keeps theirs and the other moves to their next free totem (never a temporary one).
- **Announce** posts the plan in party or raid chat, one line per shaman, for shamans without the addon.

In a raid, conflicts are checked per party, since totems only reach your own party.

**Tremor Totem pulses.** A Tremor Totem breaks fear, charm and sleep once every 4 seconds, counted from the moment it was dropped. Two shamans whose totems pulse together leave a fear running for up to 4 seconds; half a period apart it is 2. While a Tremor Totem is down in your party, a small cast bar appears under the totem bar:

- The bar fills up to the next pulse of your Tremor Totem (or of the oldest one, when you have none down).
- Each tall blue peg on it is another shaman's pulse.
- The green stretch with the orange arrow over it is the moment to drop yours: press while the spark is in the green, best right under the arrow. It already allows for your delay to the server.
- The line under the bar says what to do: "Drop Tremor in the green", "Re-drop in the green", "Bo to re-drop" when the other shaman is the one to move, or "Longest wait 2.0 s" once the pulses are spread out. Of two bunched-up totems the one dropped later moves, so you don't both re-drop.
- Hover the bar for each totem's next pulse.

Shamans with Totem Council 1.4.0 or newer tell each other the exact moment of the drop. Anyone else is timed from their cast when the game reports it; when it doesn't, the tooltip lists their totem as not known. `/totems tremor` turns the bar off.

## Try it alone

`/totems demo` adds two pretend shamans (one with the addon, one without) so you can see conflicts, suggestions and Sort it out without a group. The one with the addon keeps a Tremor Totem down, so the pulse bar shows too. `/totems demo` again removes them.

## Install

1. Download the newest `TotemCouncil-x.y.z.zip` from the [releases page](https://github.com/SPEEDB04T/ForeverAddonShelf/releases) (it is listed under Assets of the newest "Totem Council" release).
2. Unzip it into `World of Warcraft\_forever_\Interface\AddOns`, so you end up with `AddOns\TotemCouncil\TotemCouncil.toc`.
3. Type `/reload` in the game.

## Commands

`/totems` shows or hides the bar. Also: `config` (the options window; also a right-click on the minimap button, or Options > AddOns), `minimap` (minimap button on or off), `plan`, `demo`, `status`, `lock`, `unlock`, `scale <0.5-2>`, `fade <0.1-1>`, `click`, `mouse`, `sound`, `warn`, `adopt`, `tremor` (the pulse bar on or off), `clear`, `reset`, `debug`, `help`. `/totems help` says what each one does.

Non-shamans can use `/totems plan` to see and sort out the group's totems (handy for a raid leader).

## Good to know

- WoW Forever can hide your totem slots from addons in combat. When that happens the timers run from your own casts and the totem's known duration, so a totem that gets killed early can keep counting until the game reports the change.
- Shamans with Totem Council 1.0.2 or newer tell each other which totems they have down, so the red dot for a doubled-up totem between them is exact.
- Shamans without it (or on an older version) are seen from their casts, which the game only reports when they are near you and may not report at all. `/totems status` says when it is hiding them. A totem of theirs that gets killed early still counts until it would have run out, so a dot can linger.
- A doubled-up totem is not marked when the game says that shaman is far away from you.
- If something in a group does not work, `/totems debug` records what the game reports; type it again to stop, then `/reload`. `/totems status` also counts addon messages that could not be matched to anyone in the group, and the last 40 messages sent and received are kept in the saved variables.
- Accept / Decline boxes: a request nobody answers counts as declined after 45 seconds, and at most six wait their turn.
- Plans only sync inside a party or raid, and not while the game is blocking addon messages; the group plan window tells you when that is the case.
