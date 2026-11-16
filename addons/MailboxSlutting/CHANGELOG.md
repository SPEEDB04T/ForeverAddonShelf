# Changelog

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
