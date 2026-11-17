# Mailbox Slutting

For dancing for tips, classic WoW style, anywhere people walk by. The name is from where the habit started; the addon never looks for a mailbox, needs one or mentions one in anything it sends. You dance; the addon emotes back at whoever looks at you, emotes at you or whispers you, keeps a tip jar going, takes tips with one click and thanks for them, and counts it all.

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

The window that stays on screen while you dance, up from login:

- **The dancing panel** (below).
- **The numbers**: today's tips and their gold, visitors and time dancing. Hover for the last 7 days and all time.
- **Start dancing / Stop dancing**.

It gets out of the way in a fight and comes back after. Its close button puts it away and stops the dancing; `/mailslut counter` brings it back.

## Dancing

**Start dancing** on the counter (or `/mailslut open`) starts you dancing and answering; **Stop dancing** stops it. Whoever is waiting for an answer is on the big button: it emotes at them (Wink at Bob, Smile at Bob...), and Other emote picks a different one.

While you are dancing the dance is sent again every 30 to 60 seconds, at a random moment each time. Somebody who comes into view after you started would otherwise see you standing still. It waits while you walk, fight or are AFK. If you do another emote yourself (/sit, say), it leaves you alone until you dance again.

Replies go out in /e with the game's own words ("winks slyly at Bob."), because the game's emotes play an animation that stops your dance. If the game does not let a line out, the real emote goes instead.

- **Emotes back by itself.** Somebody winks, whistles, kisses, flirts, dances or waves at you and the fitting emote goes back: a kiss gets a kiss, a whistle a sly smirk, a lick or a purr a purr, "sexy" a flirt, a cheer a grin, a hug a giggle, a bow or applause a curtsey. A rude emote gets a pout (Sigh and Cry are on the button). Somebody who keeps you targeted for three seconds gets one wink. The answer comes 2 to 5 seconds after their emote, at a random moment each time, the way a person's would; the wink at a looker half a second to 2.5 seconds after the three. If you answered with a click in the meantime, went AFK or stopped dancing, nothing goes out, and a looker who looked away is not winked after. At most one emote per person in two minutes and one in six seconds overall, then you go back to dancing.
- **Lines at nobody.** They go out only when you click **Say a line** on the counter. No key press and no click in the world sets one off, so walking, jumping, typing or clicking back into the game's window says nothing. The lines fit wherever you dance, and none of them says where you stand. There are 14, each a different idea, taking turns ("dances a little slower for whoever is watching.", "catches somebody staring and winks.", "starts dancing a little dirtier."). None of them claims a move you are not making: you are dancing, so they are looks, smiles and how the dance is danced, as a tease and never as asking for anything. While people are around and nobody is emoting at you, whispering or tipping, a line comes due every 30 to 60 seconds and the button lights up; one that is not clicked within a minute is dropped. The common replies take turns between a few wordings.
- **The list** shows who emoted at you, who whispered you (with what they said) and who has you targeted (this needs nameplates shown). Nothing is saved; the list is gone when you log out.
- **One-click replies.** Each row has the emote as a button. Nothing is ever whispered or said without your click.
- If the game refuses emotes from addons, the window says so and the emote buttons do the same with a click.
- It reads emotes in English.

## Tips

When somebody opens a trade and gives you gold while you give nothing, an "Accept tip" button shows under the trade window. One click (or the "Accept a tip" key binding, under Key Bindings > AddOns) takes it, and the addon thanks them with that same click in an emote everybody around sees, with the amount, and a bigger gesture for a bigger tip ("Smuttanie gives Bob a wink for the tip of 2 gold pieces.", "Smuttanie blows Bob a kiss for the tip of 10 gold pieces."). A few seconds later they get a little whisper too ("thank you <3"). The game does not let an addon accept a trade without a click or a key press, so it can't be fully automatic.

## The tip jar, welcome backs and AFK

- **The tip jar.** The Tip jar button says one line about the tip jar with a click ("dances a little slower beside the tip jar.", "winks at whoever tipped today."). Every 8 to 12 minutes, while people are around and nobody is engaging, one comes due and Say a line says it. Every third one counts the jar out loud.
- **Welcome back.** Somebody who tipped you before and comes by again is put on the big button, and its click says one of "welcomes Bob back.", "gives Bob a wink for coming back." or "smiles to see Bob back.".
- **AFK.** When the game marks you AFK a warning with a sound comes up, so the dance does not end unnoticed.
