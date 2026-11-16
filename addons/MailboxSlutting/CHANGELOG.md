# Changelog

## 1.4.0

- The lines at nobody are rewritten to tease instead of wait: somebody who knows they are being watched ("dances a little slower for whoever is watching.", "catches somebody staring and smiles.", "makes checking the mail take longer than it should."). Gone are the flat ones (keeps dancing, hums a tune) and the needy ones (looks around for an audience).
- Far less about the tip jar: a line every 8 to 12 minutes instead of every 2 to 3, the first after 3 to 5 minutes, and the four that are left do not look at the jar or hope for anything.

## 1.3.3

- Somebody who only targets you gets the game's wink by itself again, as before 1.3.2.
- The dance resumes right away after any emote by itself: about a second later instead of 3 to 7, and if it does not take it is tried again every 2.5 seconds, up to 8 times. The 15 seconds that used to be kept between two dances no longer hold the comeback back.

## 1.3.2

- The dance holds better. Somebody who only targets you no longer gets the game's own wink, which stopped your dance each time: the wink goes in /e on your next key press or click (the dance goes on), and is dropped after 10 seconds without one.
- After an emote that does stop the dance (an answer to somebody who emoted at you), the dance is tried again every 4 seconds, up to 6 times, instead of once more after 15 seconds. A try that does not take shows nothing, so this does not spam.
- A key press or click also brings the dance back when it is down.
- A dance that did not take no longer counts toward "the game does not let an addon emote here".

## 1.3.1

- The lines at nobody are rewritten for what people actually see: somebody dancing nonstop on a mailbox. No more poses, spins, bows, waves, hops or stretches that the character does not do; the 22 lines are looks, smiles, humming and the dance going on ("looks over the crowd without missing a step.").
- The tip jar lines likewise: a glance, a nod or a toe, no holding the jar out, counting coins or polishing it.

## 1.3.0

- New big button **Say a line**: one click says the next line at nobody, right away. It is the big button while nobody is waiting for an answer, and sits small at the right of the row when somebody is. It lights up while a line is waiting for your key press or click.

## 1.2.2

- The game lets a /e line from an addon out only on your own key press or click, and says "action failed because of an addon" otherwise. So the lines by itself (at nobody, the tip jar, the glance at the tip jar, the dance for a tipper) now wait for your next key press or click in the world and go out on that. Any key counts: a step, a jump, a modifier.
- Nothing is sent in /e from a timer or from somebody's chat line any more, so that message should not come up again. Answers by itself use the game's own emotes (wink, smile), which are allowed; your clicks still use the /e wording.
- One line waits at a time, so a burst of keys does not send a burst of lines. Not at the keyboard, no lines.

## 1.2.1

- The lines by itself (at nobody, the tip jar, the glance at the tip jar, the dance for a tipper) did not go out: the game drops a /e line sent from a timer. They now wait for the next chat line or emote from anybody around and go out on that. In a city that is a few seconds at most. With no chat at all for 15 seconds the line is tried from the timer anyway.
- A line at nobody that still did not show is sent once more on the next chat line.

## 1.2.0

- Much louder when the crowd does nothing: while people are around and nobody is emoting at you, whispering or tipping, a line at nobody goes out every 10 to 30 seconds (it was every 7 to 13 minutes), and a tip jar line every 2 to 3 minutes (it was every 20 to 30).
- 24 lines at nobody instead of 5, and 12 tip jar lines instead of 7, so they do not come round too soon.
- When somebody does emote at you, whisper or tip, these lines wait 45 seconds, so the answer to them is what people read.

## 1.1.0

- Nothing of Slutmog Shop is in the window any more, with or without the shop installed: no ad row, no Post ad or Reroll, no Wares or Options button, no Whisper price, and its name on top is Mailbox Slutting. The shop reminds you of its ads in its own window again.
- The button reads Start dancing / Stop dancing, and the texts no longer talk about a shop.
- The numbers no longer count ads.
- A whisperer on the big button is answered with an emote, like everybody else.

## 1.0.0

- New addon, split off from Slutmog Shop 1.18.0: dancing on the mailbox with the emotes back, the idle and tip jar lines, the welcome back for tippers, the Accept tip button with its thank-you, the counter window and its numbers. Nothing about how they work has changed.
- Works without Slutmog Shop: the counter then has no ad part, no Wares or Options button, and no Whisper price.
- With Slutmog Shop 1.19.0 or newer the counter is as before: the shop's next ad, Post ad, Reroll, Wares, Options and Whisper price.
- Your tips, tippers, numbers, the tip jar count and the counter's place are copied from Slutmog Shop's saved data once.
- New command `/mailslut` (counter), `/mailslut open`, `/mailslut stats`, `/mailslut sound`. `/slutshop mailbox`, `/slutshop counter` and `/smog mailbox` keep working with the shop installed.
- Key bindings of its own: Accept a tip, and Start or stop dancing. The Accept tip key bound under Slutmog Shop keeps working.
- This is a new addon folder: the game needs one full restart to see it, a /reload is not enough.
