# Mailbox Slutting

For dancing on top of a city mailbox for tips, classic WoW style. You dance; the addon emotes back at whoever looks at you, emotes at you or whispers you, keeps a tip jar going, takes tips with one click and thanks for them, and counts it all.

It works on its own. With **Slutmog Shop** installed too, the counter also shows the shop's next ad with a Post button, and you can whisper a ware's price to an admirer.

It was part of Slutmog Shop until that addon's 1.18.0. If you used it there, your tips, tippers, numbers and the counter's place are copied over the first time you log in with both.

## Commands

| | |
|---|---|
| `/mailslut` | the counter up or away |
| `/mailslut open` (or `close`) | start or stop dancing |
| `/mailslut stats` | today's and all-time tips |
| `/mailslut sound` | the alert sounds on or off |

`/mailboxslutting` works the same. With Slutmog Shop installed, `/slutshop mailbox`, `/slutshop counter` and `/smog mailbox` work too.

## The counter

The window that stays on screen while you stand at the mailbox, up from login:

- **The ad** (with Slutmog Shop installed): the shop's next ad with its item (hover it for the tooltip), a big **Post ad** button and **Reroll**. While you have to wait the button counts down ("Next ad in 3:40"); when the next ad is due it lights up.
- **The mailbox panel** (below).
- **The numbers**: today's tips and their gold, visitors and time open (and ads posted, with the shop). Hover for the last 7 days and all time.
- **Open shop / Close shop**, and with Slutmog Shop **Wares** (the shop window) and **Options**.

It gets out of the way in a fight and comes back after. Its close button puts it away and closes the shop; `/mailslut counter` brings it back.

## On the mailbox

**Open shop** on the counter (or `/mailslut open`) starts you dancing and answering; **Close shop** stops it. Whoever is waiting for an answer is on the big button: it emotes at them (Wink at Bob, Smile at Bob...), and Other emote picks a different one. With Slutmog Shop installed, Whisper price whispers them your ware and its price.

Replies go out in /e with the game's own words ("winks slyly at Bob."), because the game's emotes play an animation that stops your dance. If the game does not let a line out, the real emote goes instead.

- **Emotes back by itself.** Somebody winks, whistles, kisses, flirts, dances or waves at you and the fitting emote goes back (a kiss gets a blush, a whistle a curtsey). Rude emotes get a sad one back (cry, pout, frown, sigh) and no pitch. Somebody who targets you gets one wink. At most one emote per person in two minutes and one in six seconds overall, then you go back to dancing.
- **On top of the mailbox.** The lines are written for dancing on the mailbox. Every 7 to 13 minutes, while people are around, one line at nobody ("does a little spin on the mailbox."). Somebody who keeps you targeted for half a minute gets one "glances at the tip jar, then down at Bob.". A tipper gets "dances for Bob." after the thank-you. The common replies take turns between a few wordings.
- **The list** shows who emoted at you, who whispered you (with what they said) and who has you targeted (this needs nameplates shown). Nothing is saved; the list is gone when you log out.
- **One-click replies.** Each row has the emote as a button. With Slutmog Shop installed there is also **Whisper** for people who emoted at you or whispered you first: one whisper in the shop owner's voice with the ware whose turn it is and its price ("Staring is free. [item] is 10 gold pieces."). Once per person in ten minutes. The shop never whispers or speaks without your click, and never pitches somebody who only looked.
- If the game refuses emotes from addons, the window says so and the emote buttons do the same with a click.
- It reads emotes in English.

## Tips

When somebody opens a trade and gives you gold while you give nothing, an "Accept tip" button shows under the trade window. One click (or the "Accept a tip" key binding, under Key Bindings > AddOns) takes it, and the addon thanks them with that same click in an emote everybody around sees, with the amount, and a bigger gesture for a bigger tip ("Smuttanie thanks Bob for the tip of 2 gold pieces.", "Smuttanie blows Bob a kiss for the tip of 10 gold pieces."). A few seconds later they get a little whisper too ("thank you <3"). The game does not let an addon accept a trade without a click or a key press, so it can't be fully automatic.

## The tip jar, welcome backs and AFK

- **The tip jar.** Every 20 to 30 minutes, while people are around, one line about the tip jar ("jingles the tip jar."), and the Tip jar button says one with a click. Every third one counts the jar out loud.
- **Welcome back.** Somebody who tipped you before and comes by again gets one "welcomes Bob back.".
- **AFK.** When the game marks you AFK a warning with a sound comes up, so the dance does not end unnoticed.
