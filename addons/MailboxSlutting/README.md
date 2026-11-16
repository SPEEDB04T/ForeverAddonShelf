# Mailbox Slutting

For dancing on top of a city mailbox for tips, classic WoW style. You dance; the addon emotes back at whoever looks at you, emotes at you or whispers you, keeps a tip jar going, takes tips with one click and thanks for them, and counts it all.

It is its own addon: nothing of Slutmog Shop is in its window (no ad, no wares), and neither needs the other.

It was part of Slutmog Shop until that addon's 1.18.0. If you used it there, your tips, tippers, numbers and the counter's place are copied over the first time you log in with both installed.

## Commands

| | |
|---|---|
| `/mailslut` | the counter up or away |
| `/mailslut open` (or `close`) | start or stop dancing |
| `/mailslut stats` | today's and all-time tips |
| `/mailslut sound` | the alert sounds on or off |

`/mailboxslutting` works the same.

## The counter

The window that stays on screen while you stand at the mailbox, up from login:

- **The mailbox panel** (below).
- **The numbers**: today's tips and their gold, visitors and time dancing. Hover for the last 7 days and all time.
- **Start dancing / Stop dancing**.

It gets out of the way in a fight and comes back after. Its close button puts it away and stops the dancing; `/mailslut counter` brings it back.

## On the mailbox

**Start dancing** on the counter (or `/mailslut open`) starts you dancing and answering; **Stop dancing** stops it. Whoever is waiting for an answer is on the big button: it emotes at them (Wink at Bob, Smile at Bob...), and Other emote picks a different one.

Replies go out in /e with the game's own words ("winks slyly at Bob."), because the game's emotes play an animation that stops your dance. If the game does not let a line out, the real emote goes instead.

- **Emotes back by itself.** Somebody winks, whistles, kisses, flirts, dances or waves at you and the fitting emote goes back (a kiss gets a blush, a whistle a curtsey). Rude emotes get a sad one back (cry, pout, frown, sigh). Somebody who targets you gets one wink. At most one emote per person in two minutes and one in six seconds overall, then you go back to dancing.
- **On top of the mailbox.** The lines are written for dancing on the mailbox. While people are around and nobody is emoting at you, whispering or tipping, one line at nobody every 10 to 30 seconds ("does a little spin on the mailbox."), from 24 that take turns. They stop for 45 seconds whenever somebody does engage, so the answers are not buried. Somebody who keeps you targeted for half a minute gets one "glances at the tip jar, then down at Bob.". A tipper gets "dances for Bob." after the thank-you. The common replies take turns between a few wordings.
- **The list** shows who emoted at you, who whispered you (with what they said) and who has you targeted (this needs nameplates shown). Nothing is saved; the list is gone when you log out.
- **One-click replies.** Each row has the emote as a button. Nothing is ever whispered or said without your click.
- If the game refuses emotes from addons, the window says so and the emote buttons do the same with a click.
- It reads emotes in English.

## Tips

When somebody opens a trade and gives you gold while you give nothing, an "Accept tip" button shows under the trade window. One click (or the "Accept a tip" key binding, under Key Bindings > AddOns) takes it, and the addon thanks them with that same click in an emote everybody around sees, with the amount, and a bigger gesture for a bigger tip ("Smuttanie thanks Bob for the tip of 2 gold pieces.", "Smuttanie blows Bob a kiss for the tip of 10 gold pieces."). A few seconds later they get a little whisper too ("thank you <3"). The game does not let an addon accept a trade without a click or a key press, so it can't be fully automatic.

## The tip jar, welcome backs and AFK

- **The tip jar.** Every 2 to 3 minutes, while people are around and nobody is engaging, one line about the tip jar ("jingles the tip jar."), and the Tip jar button says one with a click. Every third one counts the jar out loud.
- **Welcome back.** Somebody who tipped you before and comes by again gets one "welcomes Bob back.".
- **AFK.** When the game marks you AFK a warning with a sound comes up, so the dance does not end unnoticed.
