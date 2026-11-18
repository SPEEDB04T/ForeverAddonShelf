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

- **Emotes back by itself.** Somebody winks, whistles, kisses, flirts or waves at you and the fitting emote goes back: a kiss gets a kiss, a whistle a sly smirk, a lick or a purr a purr, "sexy" a flirt, a cheer a grin, a hug a giggle, a bow or applause a curtsey. Somebody who dances at you gets a smile or a grin (you are dancing already). The fitting emote goes back most of the time and another slight one of the same kind in between (a wink is answered with a wink, now and then a smirk, a grin or a giggle), the same person never gets the same one twice running, and the same emote does not go out three times in a row. The answer comes 2 to 5 seconds after their emote, at a random moment each time, the way a person's would. If you answered with a click in the meantime, went AFK or stopped dancing, nothing goes out. At most one emote per person in two minutes and one in six seconds overall, then you go back to dancing.
- **Lookers.** Somebody who keeps you targeted gets one wink, smile or smirk, after 3 to 7 seconds of looking (picked anew for every look) and half a second to 2.5 seconds on top. About one look in four gets nothing, so it is not the same thing at the same moment for everybody. A looker who looked away is not winked after.
- **Rude emotes.** The first one gets a pout (Sigh and Cry are on the button). Somebody who was rude twice gets nothing more until you log out: they are still listed, without a button, and whatever they do after it is not answered.
- **Lines at nobody.** They go out only when you click **Say a line** on the counter. No key press and no click in the world sets one off, so walking, jumping, typing or clicking back into the game's window says nothing. The counter shows the line that is up next under "Next line", and Say a line says exactly that; **Skip** passes on it and brings up another, without saying anything. The lines fit wherever you dance, and none of them says where you stand. Thirteen are about nobody: the mood, the face and how the dance is danced, each a different idea, taking turns ("puts a little more hip into it.", "tries to look innocent.", "gives up on being subtle.", "regrets nothing.", "has no plans to behave."). None of them invents an onlooker (no "somebody", "whoever" or "the crowd"), and none claims a move you are not making. They are a tease and never ask for anything. While people are around and nobody is emoting at you, whispering or tipping, a line comes due every 30 to 60 seconds and the button lights up; one that is not clicked within a minute is dropped. The common replies take turns between a few wordings.
- **Lines about people, only when they are true.** The addon counts who is in view and who has you targeted (this needs nameplates shown; without them it knows nothing and says only the lines about nobody). Seven lines are about people, and each waits until it is true: "catches somebody staring and winks.", "stares right back at somebody." and "knows exactly who is watching." need somebody who has you targeted right now; "gives the crowd something to look at." needs three people in view as well; "makes sure everybody gets a good look." two lookers among them; "lets everybody stare." three lookers; "smirks at somebody who has been staring a while." somebody who has for half a minute. Even with a crowd staring, at most every fourth line is one of these; the three in between are about nobody. If the lookers leave while such a line is shown, another takes its place.
- **The list** shows who emoted at you, who whispered you (with what they said) and who has you targeted (this needs nameplates shown), with how long they have looked ("is looking at you, 45s"). Of those looking right now, whoever has looked longest is on top. Nothing is saved; the list is gone when you log out.
- **One-click replies.** Each row has the emote as a button. A whisperer's row has **Reply**: it opens a small menu with four quick whispers ("hey <3", "glad you like it <3", "dancing for tips <3", "keep watching <3") and the emote. Nothing is ever whispered or said without your click.
- If the game refuses emotes from addons, the window says so and the emote buttons do the same with a click.
- It reads emotes in English.

## Tips

When somebody opens a trade and gives you gold while you give nothing, an "Accept tip" button shows under the trade window. One click (or the "Accept a tip" key binding, under Key Bindings > AddOns) takes it, and the addon thanks them with that same click in an emote everybody around sees, with the amount, and a bigger gesture for a bigger tip ("Smuttanie gives Bob a wink for the tip of 2 gold pieces.", "Smuttanie blows Bob a kiss for the tip of 10 gold pieces."). A few seconds later they get a little whisper too ("thank you <3"). The game does not let an addon accept a trade without a click or a key press, so it can't be fully automatic.

## The tip jar, welcome backs and AFK

- **The tip jar.** The Tip jar button says one line about the tip jar with a click ("dances a little slower beside the tip jar.", "gives the tip jar a wink."). Every 8 to 12 minutes, while people are around and nobody is engaging, one comes due and Say a line says it (Skip drops it). Every third one counts the jar out loud, and names today's biggest tip when that was a gold or more ("counts the tip jar: 9 tips today. The biggest was 20 gold pieces.").
- **Welcome back.** Somebody who tipped you before and comes by again is put on the big button, and its click says one of "welcomes Bob back.", "gives Bob a wink for coming back." or "smiles to see Bob back.".
- **AFK.** When the game marks you AFK a warning with a sound comes up, so the dance does not end unnoticed.
