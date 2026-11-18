-- Mailbox Slutting: the dancing. For dancing for tips wherever you stand (the name is from where it
-- started, on a city mailbox; nothing in here looks for a mailbox, needs one or says one, see SuccuDev,
-- 2026-11-17: "make sure there are no actual references to mailboxes so I can actually do this
-- anywhere"). It keeps a list of who looked at
-- you, emoted at you and whispered you, puts the one who is waiting for an answer on a big button
-- at the top, and gives everybody a one-click reply. /mailslut open turns it on; closing its window
-- turns it off. Nothing here knows about wares or ads: that is Slutmog Shop, another addon
-- (SuccuDev: "I dont think you properly split it, I still see shop stuff in the mailslut window").
--
-- It lives in the counter (Counter.lua), the window that stays up while you stand there; Start
-- dancing turns it on. A reply says what the game's own emote would ("winks slyly at Bob."), in /e: the
-- game's emote stops the dance, a line in /e does not (SuccuDev: "do custom /emotes cancel dance
-- animation? couldnt we replace all of them with the same wording"). If /e from the shop does not
-- go out, the game's own emote is done instead.
-- By itself the addon only dances and tries the game's emote back, and few of those: one per person
-- every two minutes, one every six seconds at most, each a few seconds after what it answers. It never
-- says, emotes text or whispers without a click on one of its own buttons.
local ADDON, ns = ...
local M = {}
ns.Mailbox = M

local ROWS, ROW_H = 6, 26
local PERSON_GAP = 120          -- seconds between two emotes by itself at the same person
local LOOK_GAP = 900            -- ... at somebody who only looked
local GLOBAL_GAP = 6            -- seconds between any two emotes by itself
local KEEP = 20                 -- visitors remembered (this session only; nothing is saved)
local WAIT = 300                -- seconds somebody counts as waiting for an answer
local FADE_FROM, FADE_TO = 60, 300      -- a row fades between these ages...
local FADE_MIN, DONE_ALPHA = 0.35, 0.55 -- ... down to this; an answered row is dimmed to this at once
local LOOK_KEEP, KEEP_FOR = 600, 1800   -- seconds a looker / an emoter or whisperer stays listed
local RELOOK = 120              -- somebody who looks again after this long is new again (with a sound)
local LOOK_WINDOW = 10          -- a looker can be answered this long after they target you...
local STILL = 3                 -- ... and only while they still do: seen on the last look (every 2 s)
local ALERT_GAP = 3             -- seconds between two alert sounds
local TICK = 1                  -- seconds between two looks at the nameplates
local HOLD = 3                  -- seconds somebody must keep you targeted before the shop winks by itself
                                -- (SuccuDev: "lets only wink at players that keep me targeted for at least 3 seconds")
-- A wink after three seconds on the dot, at every single looker, is a clock. So the wait is picked anew
-- for each look, never under the three seconds he asked for, and now and then a looker gets no wink at
-- all, the way a person misses one. Somebody who looks away and back gets a new roll.
M.HOLD = { 3, 7 }               -- seconds a looker must keep you targeted, picked per look; nil: HOLD
M.LOOK_SKIP = 0.25              -- the share of looks that get no wink by itself; 0: every look gets one
local HECKLE = 2                -- rude emotes from one person before they get nothing more this session
local JAR_MIN, JAR_MAX = 480, 720       -- seconds between two tip jar lines, picked at random
local JAR_FIRST_MIN, JAR_FIRST_MAX = 180, 300   -- ... and before the first one
-- The lines by itself (idle and tip jar) are for a crowd that does nothing (SuccuDev: "we can be a lot
-- more intrusive when people arent engaging, like every 10-30s"). Once somebody emotes at you, whispers
-- or tips, the answers do the talking, and these wait this long after the last of it.
local ENGAGE_HOLD = 45
local BACK_AGAIN = 2 * 3600     -- seconds before a tipper is welcomed back again

-- Their emote, by a word in its text: the game's emote that goes back by itself, and which lines
-- the reply comes from. First match wins.
-- Reviewed 2026-11-17 by three hostile readers (SuccuDev: "do an adversarial review on all lines and
-- reactions etc to ensure it's all as enticing as possible"). What they agreed on, and what changed:
-- whoever heats things up gets heat back, not a retreat or a servant's gesture. A kiss gets a kiss
-- (it was a blush), a whistle a sly smirk (a curtsey), a lick and a purr a purr (a giggle, a wink),
-- "sexy" a flirt (a wink), a cheer a grin ("thanks Bob." read like a tip receipt), a hug a giggle
-- (hugging a stranger back was too much by itself; Hug is still on the button).
local REPLIES = {
    { "kiss", "KISS", "kiss" }, { "wink", "WINK", "wink" }, { "flirt", "FLIRT", "flirt" },
    { "whistle", "SMIRK", "wink" }, { "danc", "SMILE", "dance" }, { "wave", "WAVE", "wave" },
    { "greet", "WAVE", "wave" }, { "hello", "WAVE", "wave" }, { "bow", "CURTSEY", "show" },
    { "hug", "GIGGLE", "hug" }, { "cuddle", "GIGGLE", "hug" }, { "drool", "GIGGLE", "look" },
    { "lick", "PURR", "flirt" }, { "cheer", "GRIN", "any" }, { "applaud", "CURTSEY", "show" },
    { "clap", "CURTSEY", "show" }, { "love", "BLUSH", "kiss" }, { "sexy", "FLIRT", "flirt" },
    { "purr", "PURR", "flirt" }, { "stare", "WINK", "look" }, { "gaze", "WINK", "look" },
}
-- These get a sad emote back (SuccuDev: "cry or feel sad when people do bad emotes at me"), and no pitch.
-- By itself that is a pout: all three readers called "cries on Bob's shoulder." the worst line of the
-- lot (a sympathy scene for whoever spat, and the tease turned into a victim). Cry is still on the button.
local RUDE = { "spit", "rude", "slap", "insult", "mock", "taunt", "pity", "puke", "fart", "disgust", "threaten", "angry", "bonk" }
local SAD_REPLY = { nil, "POUT", "sad" }
local DEFAULT_REPLY = { nil, "WINK", "any" }
local LOOK_REPLY = { nil, "WINK", "look" }
local BACK_REPLY = { nil, nil, "hug" }
local WHISPER_REPLY = { nil, "WINK", "whisper" }

-- The replies: the game's own emotes, done at them (SuccuDev: "just make it simple emotes like wink
-- instead of custom, too tryhard otherwise"). Every group but "look" also draws on "any".
M.EMOTES = {
    -- More of the same kind, short and quiet (SuccuDev: "similar emotes to the basic ones like wink,
    -- short and sweet, doesnt stand out"). All of them are in the game's own emote list
    -- (ChatEmoteConstants.lua, Gethe/wow-ui-source branch forever) and old enough for this client.
    -- The 2026-11-17 review took out what does not fit somebody who knows they are being watched:
    -- the shy ones (Bashful: "too bashful to get Bob's attention" reads as a brush-off; Shy), the flat
    -- ones (Nod, Blink, Chuckle, which can read as laughing at them), the shop greeter (Welcome, Greet,
    -- "a hearty hello!"), the servant (Bow, Thank), Cuddle (too much at a stranger), Frown ("with
    -- disappointment" guilt-trips) and Spin (nobody spins in the middle of a dance that never stops).
    look = { "WINK", "SMILE", "GIGGLE", "GRIN", "SMIRK", "WAVE" },   -- only targeted you: slight
    kiss = { "KISS", "BLUSH", "PURR", "FLIRT", "KISSDOWN", "LASHES" },
    wink = { "WINK", "SMIRK", "GRIN", "GIGGLE" },
    flirt = { "FLIRT", "PURR", "TEASE", "SMIRK", "GIGGLE", "LASHES", "BECKON", "FINGER" },
    show = { "CURTSEY", "SMILE" },
    hug = { "GIGGLE", "HUG", "BLUSH" },
    wave = { "WAVE", "SMILE" },
    -- Somebody dances with you. You are dancing already, so a dance back shows nothing; until 1.8.0 that
    -- meant the most common emote at a dancer got no answer at all. Three readers, 2026-11-17: a smile
    -- or a grin (split between the two), never a wink (used everywhere else) or a flirt (too eager).
    dance = { "SMILE", "GRIN", "WINK" },
    whisper = { },
    sad = { "POUT", "SIGH", "CRY" },                          -- after a rude emote, and nothing from "any"
    any = { "WINK", "SMILE", "GIGGLE", "GRIN", "SMIRK" },
}
-- What may go back BY ITSELF, per group. The emote that fits what they did (the one in REPLIES) comes
-- most often; the others here take its place now and then, so that the crowd does not read "winks at
-- A", "winks at B", "winks at C", and nobody gets the same one twice running. All of them are the
-- game's own emotes and all are slight: nothing here goes further than what they did. Not by itself:
-- Hug, Cry, Beckon, Tease and the addon's own ones (those stay on the buttons).
M.AUTO = {
    look = { "WINK", "SMILE", "SMIRK" },
    kiss = { "KISS", "WINK", "BLUSH", "PURR" },
    wink = { "WINK", "SMIRK", "GRIN", "GIGGLE" },
    flirt = { "FLIRT", "PURR", "SMIRK", "WINK", "GIGGLE" },
    show = { "CURTSEY", "SMILE", "GRIN" },
    hug = { "GIGGLE", "BLUSH", "SMILE" },
    wave = { "WAVE", "SMILE", "GRIN" },
    dance = { "SMILE", "GRIN" },
    sad = { "POUT", "SIGH" },
    any = { "WINK", "SMILE", "GRIN", "GIGGLE", "SMIRK" },
}
M.AUTO_MAIN = 3                 -- how much more often the fitting one comes than each of the others
-- What the buttons call them.
M.LABEL = {
    WINK = "Wink", SMILE = "Smile", GIGGLE = "Giggle", WAVE = "Wave", BLUSH = "Blush",
    KISS = "Blow a kiss", FLIRT = "Flirt", CURTSEY = "Curtsey", HUG = "Hug", DANCE = "Dance",
    GRIN = "Grin", SMIRK = "Smirk", TEASE = "Tease", PURR = "Purr", BECKON = "Beckon",
    CRY = "Cry", POUT = "Pout", SIGH = "Sigh",
    WELCOMEBACK = "Welcome back",
    LASHES = "Bat eyelashes", FINGER = "Crook a finger", KISSDOWN = "Blow a slow kiss",
}
-- The addon's own emotes (SuccuDev: "more clever emotes, more enticing emotes"). They only exist as /e
-- lines; when /e does not go out, the game's emote here goes instead. Only for people who flirted,
-- kissed or whistled first.
M.FALLBACK = { LASHES = "FLIRT", FINGER = "BECKON", KISSDOWN = "KISS" }

-- What the game's emote says when aimed at somebody (warcraft.wiki.gg, List of emotes), said in /e
-- instead, so the dance goes on. %s is their name.
M.SAY = {
    WINK = "winks slyly at %s.", SMILE = "smiles at %s.", GIGGLE = "giggles at %s.",
    WAVE = "waves at %s.", GRIN = "grins wickedly at %s.", SMIRK = "smirks slyly at %s.",
    BLUSH = "blushes at %s.", KISS = "blows a kiss to %s.", PURR = "purrs at %s.",
    FLIRT = "flirts with %s.", TEASE = "teases %s.", BECKON = "beckons %s over.", CURTSEY = "curtseys before %s.",
    HUG = "hugs %s.",
    LASHES = "bats eyelashes at %s.", FINGER = "crooks a finger at %s.",
    KISSDOWN = "blows %s a slow kiss.",
    CRY = "cries on %s's shoulder.", POUT = "pouts at %s.", SIGH = "sighs at %s.",
}

-- Other wordings of the common ones, taking turns with the game's own, so the same line does not
-- come every time (SuccuDev: "better variant wordings on common emotes. for example slightly
-- different winks, smiles"). Same style: short, third person, nothing said out loud.
M.VARIANTS = {
    WINK = { "winks at %s.", "gives %s a wink.", "gives %s a slow wink." },
    SMILE = { "gives %s a slow smile.", "gives %s a little smile." },      -- not "warmly": that one was mumsy
    WAVE = { "gives %s a little wave." },
    GIGGLE = { "gives %s a little giggle." },
    GRIN = { "grins at %s.", "gives %s a grin." },
    SMIRK = { "smirks at %s." },
    BLUSH = { "blushes a little at %s." },        -- not "blushes and looks away": that read as a brush-off
    KISS = { "blows %s a kiss." },
    CURTSEY = { "curtseys for %s." },
    PURR = { "gives %s a little purr." },
}
local sayTurn = {}
-- The line for a token this time: the game's wording first, then the others, in turn.
function M.Wording(token)
    local base = M.SAY[token]
    if not base then return nil end
    local more = M.VARIANTS[token]
    if not more then return base end
    sayTurn[token] = (sayTurn[token] or 0) % (#more + 1) + 1
    return sayTurn[token] == 1 and base or more[sayTurn[token] - 1]
end

-- The tip jar: now and then, while somebody is around, one line in /e, so people know you take tips
-- (SuccuDev picked this to get more tips). Short and quiet, in the shop owner's voice.
-- The same for the jar: no hands (holding it out, counting coins, polishing).
-- And the tone (SuccuDev, 2026-11-16: "the passive emotes are really unsexy and beggar like"): the lines
-- are a tease from somebody who knows they are being watched, never somebody waiting, hoping or asking.
-- No looking for an audience, no eyeing the jar. The jar is mentioned seldom and never asked for.
-- 2026-11-17 review: "leaves the tip jar where everybody can reach it." was begging in two of three
-- readings. In its place a wink at the ones who tipped: it says tips are taken and what they get, and
-- asks nobody for anything.
M.JAR = {
    "dances a little slower beside the tip jar.",
    "winks at whoever tipped today.",
}
-- Now and then while somebody is around, at nobody: something to look at.
-- The lines fit wherever you dance (SuccuDev, 2026-11-16: "make it compatible with non mailbox dancing
-- too"): on a mailbox, a fountain edge or the ground. No line says where you stand or that the crowd is
-- below you: no "down at", "below", "looks up", "on the mailbox".
-- What people see is the dance, nonstop, by somebody half away from the keyboard (SuccuDev: "strikes a
-- pose? im obviously semi-afk dancing on a mailbox"). So a line never claims a move the character is not
-- making (a pose, a spin, a bow, a wave, a hop): only eyes, face, voice, and the dance going on.
-- Picture it: the dance animation loops, the body never holds still or turns, the arms are busy. So no
-- line turns the body or uses a hand either (SuccuDev, 2026-11-16: "looks over her shoulder is dumb
-- please visualize what WOW mailbox dancing looks like").
-- And plain (SuccuDev, 2026-11-16: "'licks a lip' is not the kind of phrasing that ever works. you are
-- claudeing this shit up"): short lines the way players type an emote. Nothing writerly, and no body
-- part with "a" or "those" in place of a pronoun (a lip, a toe, those hips).
-- 2026-11-17 review: the 22 lines held about 7 ideas. Nine said "smiles, winks or grins at the crowd",
-- four said "enjoys being watched", two were the same slow dance; read in a row that is a bot on a
-- loop. Now 14 lines, one idea each, and more of them pick out "somebody", so each reader wonders if
-- it is them. Out as stiff: "does not mind the staring at all.", "grins at the ones staring.",
-- "lets the crowd look.", "eyes somebody in the crowd."
M.IDLE = {
    "dances a little slower for whoever is watching.",
    "catches somebody staring and winks.",
    "gives the crowd something to look at.",
    "knows exactly who is watching.",
    "puts a little more hip into it.",
    "stares right back at somebody.",
    "enjoys being watched.",
    "dances just out of reach.",
    "smirks at the crowd.",
    "starts dancing a little dirtier.",
    "checks out somebody in the crowd.",
    "pretends not to notice the staring.",
    "makes sure everybody gets a good look.",
    "grins at whoever is staring.",
    "lets everybody stare.",
    "smirks at somebody who has been staring a while.",
}
-- Lines that fit the crowd (SuccuDev, 2026-11-17: "I like lines that fit the crowd"). The addon knows
-- how many players are in view (near), how many have you targeted right now (look) and for how long the
-- longest of them has (stare), so a line can wait until it is true:
--   near:  it needs this many players in view ("the crowd", "everybody"); with fewer it is not said.
--   look:  made for this many lookers or more: it comes sooner then.
--   stare: made for somebody who has kept you targeted this many seconds.
--   only:  said only when it is made for the moment (the two new ones: with nobody targeting you,
--          "lets everybody stare." would be a lie).
-- A line without an entry fits always. With no nameplate in view the addon knows nothing about the
-- crowd (nameplates may be off), and every line but the "only" ones fits, as before 1.8.0.
-- The two new lines went past three hostile readers with twelve others, 2026-11-17. Dead on arrival:
-- every line for exactly one looker ("dances for the one who is watching.": too much at one person),
-- a wink or a slow smile at whoever keeps staring (too eager at a looker).
M.WHEN = {
    ["catches somebody staring and winks."] = { look = 1 },
    ["stares right back at somebody."] = { look = 1 },
    ["knows exactly who is watching."] = { look = 1 },
    ["grins at whoever is staring."] = { look = 1 },
    ["pretends not to notice the staring."] = { look = 2 },
    ["gives the crowd something to look at."] = { near = 3 },
    ["smirks at the crowd."] = { near = 3 },
    ["checks out somebody in the crowd."] = { near = 3 },
    ["makes sure everybody gets a good look."] = { near = 3, look = 3 },
    ["lets everybody stare."] = { look = 3, only = true },
    ["smirks at somebody who has been staring a while."] = { stare = 30, only = true },
}
-- 0: wrong for this crowd, 1: fine, 2: made for it. c = { near, look, stare }.
function M.Suits(line, c)
    local w = M.WHEN[line]
    if not w then return 1 end
    if w.near and c.near > 0 and c.near < w.near then return 0 end
    if (w.look and c.look >= w.look) or (w.stare and c.stare >= w.stare) then return 2 end
    return w.only and 0 or 1
end
-- The quick answers to a whisper, on the Reply button of a whisperer's row: your click sends one.
-- Private chat, so these are said, in few words. Nine went past the three readers; these four lived
-- ("enjoying the view?" and "like what you see?" fish for a compliment, "come closer" begs).
M.WHISPERS = { "hey <3", "glad you like it <3", "dancing for tips <3", "keep watching <3" }
-- Somebody who has kept you targeted this long gets one look at the tip jar, once an hour at most.
M.NUDGE = "glances at the tip jar, then at %s."
local NUDGE_HOLD, NUDGE_AGAIN = 30, 3600
-- SuccuDev, 2026-11-16: "emotes get too spammy sometimes". A line at nobody every 10 to 30 seconds was
-- too many, and one could land right behind an answer or a click. Now every 30 to 60 seconds, and never
-- within LINE_GAP of any other emote of yours.
local IDLE_MIN, IDLE_MAX = 30, 60               -- seconds between two idle lines, picked at random
local IDLE_FIRST_MIN, IDLE_FIRST_MAX = 20, 40   -- ... and before the first one
local LINE_GAP = 30                             -- seconds after any emote of yours before a line at nobody
-- A tipper gets a dance to their name a few seconds after the thank-you, where everybody sees it.
M.DANCE_FOR = "dances for %s."
-- Somebody who tipped you before comes by again: one of these, in /e (SuccuDev: "just a welcome back emote").
-- Worded like the game's own emotes, nothing said in Smuttanie's voice (SuccuDev: "dont add text as if
-- smuttanie's writing in emotes. it has to be clean, minimalistic, feel similar to ingame emotes").
-- 2026-11-17 review: "waves at Bob again." and "smiles at Bob again." sounded like a counter, and
-- "greets Bob warmly." like a hostess. Somebody who comes back gets a little more than a stranger.
M.WELCOMES = {
    "welcomes {name} back.",
    "gives {name} a wink for coming back.",
    "smiles to see {name} back.",
}

local on = false
local frame, events
-- newest first: { name, kind = "look"|"emote"|"whisper", what, at, seen, reply = { word, token, label }, pitch = bool,
--                 pitchedAt, emotedAt (by itself), doneAt (answered: a click, or the game showed the emote going at them) }
local visitors = {}
local lastAuto = -1e9
local lastOwn = -1e9            -- the game last showed an emote of yours
local lastEngage = -1e9         -- somebody last emoted at you, whispered or tipped
local Queue, Flush
-- The game lets a chat line from an addon out only while it handles the player's own key press or
-- click. From a timer or from somebody's chat line it is blocked ("action failed because of an addon",
-- and in the saved log every "timer /e" and "event /e" has "no echo"). The game's own emotes (/wink)
-- are not blocked. So: nothing in /e from these origins, and a line at nobody waits for a click on the
-- counter's Say a line button (no key press and no click in the world sets one off, see M.Start).
M.HARDWARE_ONLY = true
local NOKEY = { timer = true, event = true, nudge = true, tip = true, back = true, ["?"] = true }
local lastAlert = -1e9
local manual = false            -- the game refused an emote from the addon: buttons only
local Sync

local function Now()
    return type(GetTime) == "function" and GetTime() or 0
end

local function Readable(v)
    if ns.Readable then return ns.Readable(v) end
    return true
end

local function Short(name)
    return (tostring(name):gsub("%-.*$", ""))
end

local function Me()
    if type(UnitName) ~= "function" then return nil end
    local ok, name = pcall(UnitName, "player")
    return ok and Readable(name) and type(name) == "string" and name or nil
end
local function MeFull() return ns.FullName and ns.FullName("player") or Me() end

-- Makes a button wide enough for its label (at least w0, at most wmax). Returns the width.
local function Fit(b, w0, wmax)
    local tw
    if b.GetTextWidth then
        local ok, x = pcall(b.GetTextWidth, b)
        if ok and type(x) == "number" then tw = x end
    end
    local w = w0
    if tw then w = math.max(w0, math.ceil(tw) + 24) end
    if wmax then w = math.min(w, wmax) end
    b:SetWidth(w)
    return w, tw and tw + 24 <= (wmax or math.huge)
end
M.Fit = Fit

local CTA_W = 430 - 28          -- the row of big buttons, inside the window
local SAY_SMALL, SAY_BIG = 96, 190      -- Say a line: small beside a reply, big when nobody is waiting

-- The full name of a unit ("Name Surname", or "Name-Realm"), or nil.
local function NameOf(unit)
    return ns.FullName(unit)
end

-- A unit the game knows this person by right now (your target, or a nameplate in view), or nil.
local function UnitFor(name)
    if type(UnitExists) ~= "function" then return nil end
    local function Is(unit)
        local ok, there = pcall(UnitExists, unit)
        if not (ok and Readable(there) and there) then return false end
        local full = NameOf(unit)
        return full ~= nil and (full == name or Short(full) == name or full == Short(name))
    end
    if Is("target") then return "target" end
    for i = 1, 40 do
        if Is("nameplate" .. i) then return "nameplate" .. i end
    end
    return nil
end

-- Whether an emote really went out is told by the game's echo ("You wink at Bob."), not by what
-- PerformEmote returns: the game's own chat box reads that as "restricted" (ChatFrameEditBox.lua,
-- Gethe/wow-ui-source branch forever), so false means it went out. Reading it the other way round
-- turned the shop to buttons-only after its first emote, which is why it emoted only sometimes.
local ECHO_WAIT = 2              -- seconds to wait for the echo
local MISSES = 3                 -- emotes in a row with no echo before the shop stops emoting by itself
local aimBy = "unit"             -- how an emote is aimed: at their unit (target, nameplate), or by name
local misses = 0
local pend                       -- the emote sent last, until its echo
local Missed                     -- set below, once Sync is known

local function Aim(name)
    if not name then return nil end
    local unit = aimBy == "unit" and UnitFor(name) or nil
    if unit then return unit, "unit" end
    return name, "name"
end

-- Any other emote stops the dance (SuccuDev: "keeps canceling my dance", then "fails to resume"), so
-- the shop dances again a moment after one of its own, unless you stopped dancing yourself. It tries
-- from a timer and again on any chat line that comes in, until the game echoes the dance: an emote
-- from a timer has never been seen to work on this client, one from a chat event has.
-- Never in quick succession, and never at the same beat twice, so it does not look like a bot
-- (SuccuDev: "make sure dance emote doesnt get spammed, add a cooldown to make things feel less bot-like").
-- SuccuDev, 2026-11-16: "just make it resume immediately": the dance comes back about a second after
-- any emote by itself, lookers' winks included, and is tried again until the game shows it.
local REDANCE_MIN, REDANCE_MAX = 1, 1.5 -- seconds after a wink or a smile before dancing again, picked at random
local DANCE_GAP = 15             -- seconds at least between two dances the shop does by itself
-- The first dance after a wink often does not take (in the saved log the try 4 to 6 seconds after it
-- has no echo every time, and the next one, which used to come 15 seconds later, does). A try that does
-- not take shows nothing, so the next one comes soon (SuccuDev: "fails to maintain dance too much").
local RETRY_GAP = 2.5            -- seconds between two tries at the same comeback (the echo is waited for 2)
local TRIES = 8                  -- dances it tries for one comeback, at most
local GIVE_UP = 45               -- seconds after which it stops trying
local dancing = false            -- you are dancing, as far as the shop knows
local due                        -- when the dance should be back, until its echo
local tries = 0
local lastDance = -1e9           -- when the last dance went out
local lastOk = -1e9              -- when the game last showed one of them: two that take stay DANCE_GAP apart
-- Somebody who comes into view after the dance started sees you standing still: the game does not
-- show them a dance that began before they could see you. So the dance is sent again every 30 to 60
-- seconds, picked at random each time (SuccuDev, 2026-11-17: "it needs to refresh the dance emote every
-- 30-60s randomly, because theres a bug where when people see her for the first time they dont see her
-- dancing"). Not while you walk or fight, not while AFK, and not once you stopped dancing yourself.
M.REFRESH = { 30, 60 }           -- seconds from one dance to the next; nil: the dance is not sent again
local nextRefresh                -- when the dance is sent again; nil: picked from the last dance

local function Busy()
    if type(GetUnitSpeed) == "function" then
        local ok, speed = pcall(GetUnitSpeed, "player")
        if ok and Readable(speed) and type(speed) == "number" and speed > 0 then return true end
    end
    if type(UnitAffectingCombat) == "function" then
        local ok, fight = pcall(UnitAffectingCombat, "player")
        if ok and Readable(fight) and fight then return true end
    end
    return false
end

function M.Random(a, b)
    if math and math.random then return a + math.random() * (b - a) end
    return b
end

-- What the shop tried and what came of it, the last 40, saved for looking into problems later.
local function Log(what)
    local db = ns.db
    if type(db) ~= "table" then return end
    db.mailLog = type(db.mailLog) == "table" and db.mailLog or {}
    local log = db.mailLog
    log[#log + 1] = string.format("%.1f %s", Now(), what)
    while #log > 40 do table.remove(log, 1) end
end
M.Log = Log

-- Away from keyboard: the shop does nothing by itself, since shoppers see <AFK> over your head
-- (SuccuDev: "lets make sure emotes dont happen when my character goes afk"). Your clicks still work.
local function Away()
    if type(UnitIsAFK) ~= "function" then return false end
    local ok, afk = pcall(UnitIsAFK, "player")
    return (ok and Readable(afk) and afk) and true or false
end
M.Away = Away

-- One line in /e. Whether it went out is told by the game's echo (CHAT_MSG_EMOTE); without one
-- in time, miss() is called.
local SAY_WAIT = 2
local saying = {}                -- lines sent, until their echo: { text, miss, done }
local function Say(text, from, miss, done)
    if M.HARDWARE_ONLY and NOKEY[from or "?"] then       -- the game would block it: not sent at all
        Log(string.format("%s /e %s: held, no key or click", from or "?", text))
        if miss then miss() end
        return false
    end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok, err = false, "no SendChatMessage"
    if type(send) == "function" then ok, err = pcall(send, text, "EMOTE") end
    Log(string.format("%s /e %s: %s", from or "?", text, ok and "sent" or ("error " .. tostring(err))))
    if not ok then
        if miss then miss() end
        return false
    end
    local mine = { text = text, miss = miss, done = done }
    saying[#saying + 1] = mine
    if C_Timer and C_Timer.After then
        C_Timer.After(SAY_WAIT, function()
            for i, w in ipairs(saying) do
                if w == mine then
                    table.remove(saying, i)
                    Log("no echo for /e")
                    if miss then miss() end
                    return
                end
            end
        end)
    end
    return true
end

local function SaidEcho(text)
    for i, w in ipairs(saying) do
        if w.text == text then
            table.remove(saying, i)
            Log("echo /e")
            if w.done then w.done() end
            return true
        end
    end
    return false
end
local function Stat(key, n) if ns.Stat then ns.Stat(key, n) end end

-- Sends an emote from the addon, at somebody if a name is given. Returns false when the game would not have it.
local Emote, Game, Nudge
local useSay = true              -- replies go in /e; false once /e by itself has twice not gone out
local sayMisses = 0
M.UsesSay = function() return useSay end
M.SetSay = function(yes) useSay, sayMisses = yes and true or false, 0 end
Emote = function(token, name, from)
    local line = useSay and token ~= "DANCE" and name and not (M.HARDWARE_ONLY and NOKEY[from or "?"]) and M.Wording(token)
    if not line then return Game(token, name, from) end
    local who = Short(name)
    line = line:format(who)
    return Say(line, from, function()
        sayMisses = sayMisses + 1
        if sayMisses >= 2 and useSay then
            useSay = false
            Log("/e from the shop does not go out: the game's emotes from now on")
        end
        Game(token, name, from)     -- the game's own emote instead (it stops the dance; the dance comes back)
    end, function()
        sayMisses, misses = 0, 0
        Stat("emotes")
        local hit = false
        for _, v in ipairs(visitors) do
            if Short(v.name) == who and not (v.doneAt and v.doneAt >= v.at) then
                v.doneAt = Now()
                hit = true
            end
        end
        if hit and Sync then Sync() end
    end)
end

Game = function(token, name, from)
    token = M.FALLBACK[token] or token
    local fn = (C_ChatInfo and C_ChatInfo.PerformEmote) or DoEmote
    if type(fn) ~= "function" then return false end
    local at, how = Aim(name)
    local ok, restricted = pcall(fn, token, at, true)
    Log(string.format("%s %s at %s (%s): %s", from or "?", token, tostring(at), how or "-",
        not ok and ("error " .. tostring(restricted)) or (Readable(restricted) and tostring(restricted) or "secret")))
    if not ok or (Readable(restricted) and restricted == true) then return false end
    if token == "DANCE" then
        dancing, lastDance, nextRefresh = true, Now(), nil
    elseif dancing then
        due, tries = Now() + M.Random(REDANCE_MIN, REDANCE_MAX), 0
        local wait = math.max(due, lastDance + RETRY_GAP) - Now()
        if C_Timer and C_Timer.After then
            C_Timer.After(wait + 0.05, function() M.Redance("timer") end)
        end
    end
    local mine = { who = name and Short(name) or nil, how = how, token = token }
    pend = mine
    if C_Timer and C_Timer.After then
        C_Timer.After(ECHO_WAIT, function()
            if pend == mine then
                pend = nil
                Log("no echo for " .. token)
                if Missed and token ~= "DANCE" then Missed() end     -- a dance that did not take is tried again, not counted
            end
        end)
    end
    return true
end

-- Dances again if it is time and the last try was a while ago.
function M.Redance(from)
    if not (on and dancing and due) or Away() then return false end
    local now = Now()
    local ready = math.max(due, lastDance + RETRY_GAP)
    if now < ready then return false end
    if now - ready > GIVE_UP or tries >= TRIES then
        due = nil
        if M.REFRESH then nextRefresh = now + M.Random(M.REFRESH[1], M.REFRESH[2]) end   -- the next go, not at once
        Log("gave up dancing again")
        return false
    end
    local done = Emote("DANCE", nil, from)  -- refused: the next chat line may try straight away
    if done then tries = tries + 1 end
    if C_Timer and C_Timer.After then
        C_Timer.After(RETRY_GAP + 0.05, function() M.Redance("timer") end)
    end
    return done
end

-- Your own emote came back from the game: the last one went out. If it was meant for somebody and
-- does not name them, it went nowhere, so the other way of aiming is tried next time.
local function Echo(text)
    Log("echo " .. text)
    if not pend then
        -- one you did yourself: dancing or not is your call
        dancing = text:lower():find("danc", 1, true) ~= nil
        if dancing then lastDance = Now() lastOk = lastDance end
        due, nextRefresh = nil, nil
        return
    end
    if pend.who and not text:find(pend.who, 1, true) then
        aimBy = pend.how == "unit" and "name" or "unit"
    end
    if pend.token == "DANCE" then due, lastOk = nil, lastDance else Stat("emotes") end
    pend, misses = nil, 0
end
M.AimBy = function() return aimBy end
-- For the rest of the shop (a thank-you for a tip): an emote at somebody, and the dance comes back after.
function M.EmoteAt(token, name) return Emote(token, name, "tip") end

local SEND_GAP = 2               -- seconds between two replies, against a double click

-- The emote a visitor gets next: their group's and the "any" ones, in turn, so the same one does
-- not come up twice in a row.
local turn = {}
local function Pick(v, skip)
    local group = v.reply and v.reply[3] or "any"
    local pool, seen = {}, {}
    local function add(list)
        for _, t in ipairs(list or {}) do
            if not seen[t] then seen[t] = true; pool[#pool + 1] = t end
        end
    end
    add(M.EMOTES[group])
    if group ~= "any" and group ~= "look" and group ~= "sad" then add(M.EMOTES.any) end
    if #pool == 0 then return nil end
    for _ = 1, #pool do
        turn[group] = (turn[group] or 0) % #pool + 1
        local t = pool[turn[group]]
        if t ~= skip or #pool == 1 then return t end
    end
end

-- The button text for a visitor's emote ("Wink"), or nil.
local function Label(v)
    return v and v.token and (M.LABEL[v.token] or v.token) or nil
end
M.Label = Label

local function Find(name)
    for i, v in ipairs(visitors) do
        if v.name == name then return v, i end
    end
end

-- Waiting for an answer: something came from them, a reply fits, and no answer went back since.
-- Somebody who only looked can be answered only in the first seconds, while they still have you
-- targeted (SuccuDev: "should only be able to do it within 10s of people targeting, while still targeted").
local function CanReply(v, now)
    if v.kind ~= "look" then return true end
    return now - v.at <= LOOK_WINDOW and v.seen ~= nil and now - v.seen <= STILL
end
M.CanReply = function(v) return CanReply(v, Now()) end

local function Waiting(v, now)
    return v.reply ~= nil and (not v.doneAt or v.doneAt < v.at) and now - v.at < WAIT and CanReply(v, now)
end
M.Waiting = function(v) return Waiting(v, Now()) end

-- No sound for emotes (SuccuDev: "im getting audio spammed for emotes rather than trades"): only a
-- tip makes a sound. The taskbar icon still flashes.
local function Alert()
    local now = Now()
    if now - lastAlert < ALERT_GAP then return end
    lastAlert = now
    if type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
end

-- Somebody did something: to the top of the list, waiting for an answer again.
local function Visit(name, kind, what, reply, pitch)
    local v, i = Find(name)
    if v then table.remove(visitors, i) else
        v = { name = name }
        Stat("visitors")
    end
    v.kind, v.what, v.at = kind, what, Now()
    if kind == "emote" or kind == "whisper" then lastEngage = v.at end
    if reply ~= nil then v.reply = reply or nil end
    if v.reply and (not v.token or reply) then v.token = Pick(v, v.token) end
    table.insert(visitors, 1, v)
    while #visitors > KEEP do table.remove(visitors) end
    if v.reply then Alert() end
    return v
end

-- Too old to matter: off the list.
local function Prune()
    local now = Now()
    for i = #visitors, 1, -1 do
        local v = visitors[i]
        local last = math.max(v.at, v.seen or 0, v.doneAt or 0)
        if now - last > (v.kind == "look" and LOOK_KEEP or KEEP_FOR) then table.remove(visitors, i) end
    end
end

local function Ago(sec)
    if sec < 10 then return "now" end
    if sec < 60 then return "<1m" end
    return math.floor(sec / 60) .. "m"
end

-- And the text itself is cut to what its box holds, so a long emote ends in "..." whatever the client
-- does with a box. Cuts between characters, never inside one.
local function Clip(s, n)
    if type(s) ~= "string" or #s <= n then return s end
    local i = n - 3
    while i > 0 and s:byte(i + 1) and s:byte(i + 1) >= 128 and s:byte(i + 1) < 192 do i = i - 1 end
    return s:sub(1, i):gsub("%s+$", "") .. "..."
end
M.Clip = Clip
local CTA_CHARS, WHAT_CHARS = 52, 40        -- what the line above the big button and a row hold

-- "45s", "2m 05s": how long somebody has had you targeted.
local function Span(sec)
    sec = math.floor(sec)
    if sec < 60 then return sec .. "s" end
    return ("%dm %02ds"):format(math.floor(sec / 60), sec % 60)
end
local WATCH_SHOWN = 10          -- seconds of looking before the row says how long

local function What(v, now)
    if v.kind == "look" then
        local looking = v.seen and now - v.seen < 5
        local t = v.watched or 0
        if t < WATCH_SHOWN then return looking and "is looking at you" or "looked at you" end
        return looking and ("is looking at you, " .. Span(t)) or ("looked at you for " .. Span(t))
    end
    return v.what
end

-- The rows, top to bottom: the list as it is (newest first), except that those who are looking at you
-- right now are put in the order of who has looked longest, in the rows they hold between them.
local shown = {}
local function Order(now)
    for i = #shown, 1, -1 do shown[i] = nil end
    local slots, lookers = {}, {}
    for i, v in ipairs(visitors) do
        shown[i] = v
        if v.kind == "look" and v.seen and now - v.seen <= TICK + 0.6 then
            slots[#slots + 1] = i
            lookers[#lookers + 1] = v
        end
    end
    if #lookers > 1 then
        table.sort(lookers, function(a, b)
            local wa, wb = a.watched or 0, b.watched or 0
            if wa ~= wb then return wa > wb end
            return a.name < b.name
        end)
        for k, i in ipairs(slots) do shown[i] = lookers[k] end
    end
    return shown
end
M.Order = function() return Order(Now()) end

-- How bright a row is: new ones fade in, answered ones are dimmed, old ones fade out.
local function Alpha(v, now)
    local age = now - v.at
    if Waiting(v, now) then
        return age < 0.4 and math.max(0.2, age / 0.4) or 1
    end
    local a = (v.doneAt and v.doneAt >= v.at) and DONE_ALPHA or 1
    if age > FADE_FROM then
        local t = math.min(1, (age - FADE_FROM) / (FADE_TO - FADE_FROM))
        a = math.min(a, 1 - t * (1 - FADE_MIN))
    end
    return a
end
M.Alpha = function(v) return Alpha(v, Now()) end

-- Puts a visitor (or nobody) on a reply button.
local function SetReply(b, v)
    b.visitor = v
end

-- Who the big button is for: of those waiting, the one waiting longest, so nobody is skipped.
local function Next(now)
    local pick
    for _, v in ipairs(visitors) do
        if Waiting(v, now) then pick = v end
    end
    return pick
end
M.Next = function() return Next(Now()) end

local function Fade()
    if not (frame and frame:IsShown()) then return end
    local now = Now()
    for r = 1, ROWS do
        local v = shown[r]
        if v then frame.rows[r]:SetAlpha(Alpha(v, now)) end
    end
    -- the big button pulses the way the game pulses a button that wants a click: its highlight, on and off
    local b = frame.cta.emote
    local pulse = math.floor(now * 2) % 2 == 0
    if b:IsShown() and b.visitor and pulse then b:LockHighlight() else b:UnlockHighlight() end
    -- and the tip jar button, while its line did not go out
    if M.JarOwed() and pulse then frame.jar:LockHighlight() else frame.jar:UnlockHighlight() end
    -- and Say a line, while a line is due
    local say = frame.cta.say
    if say:IsShown() and M.Queued() > 0 and pulse then say:LockHighlight() else say:UnlockHighlight() end
end

Sync = function()
    if not (frame and frame:IsShown()) then return end
    local now = Now()
    local list = Order(now)
    for r = 1, ROWS do
        local row, v = frame.rows[r], list[r]
        if v then
            row.name:SetText(Short(v.name))
            row.what:SetText(Clip(What(v, now), WHAT_CHARS))
            row.age:SetText(Ago(now - v.at))
            if v.reply then
                -- a whisperer's button opens the quick answers (and the emote); everybody else's does the emote
                row.emote.menu = v.kind == "whisper" and M.CanMenu() or nil
                row.emote:SetText(row.emote.menu and "Reply" or Label(v) or "Emote")
                Fit(row.emote, 62)
                SetReply(row.emote, v)
                row.emote:SetEnabled(CanReply(v, now))
                row.emote:Show()
                row.done:SetShown((v.doneAt and v.doneAt >= v.at) and true or false)
            else
                SetReply(row.emote, nil)
                row.emote:Hide()
                row.done:Hide()
            end
            row:Show()
        else
            SetReply(row.emote, nil)
            row:Hide()
        end
    end
    frame.empty:SetShown(#visitors == 0)

    -- the big button: whoever is waiting
    local cta, v = frame.cta, on and Next(now) or nil
    if v then
        local who = Short(v.name)
        cta.text:SetText(Clip(v.kind == "emote" and v.what or (who .. " " .. What(v, now)), CTA_CHARS))
        cta.text:SetFontObject(GameFontNormalLarge or GameFontNormal)
        cta.again.visitor = v
        cta.again:Show()
        -- the row of big buttons must fit the window: the send button gets what is left
        cta.say.place(false)
        local room = CTA_W - Fit(cta.again, 100) - 6 - SAY_SMALL - 6
        local label = Label(v) or "Emote"
        cta.emote:SetText(label .. " at " .. who)
        local _, fits = Fit(cta.emote, 150, room)
        if not fits then
            cta.emote:SetText(label)
            Fit(cta.emote, 150, room)
        end
        SetReply(cta.emote, v)
        cta.emote:Show()
    else
        cta.text:SetText(not on and "You are not dancing. Start dancing to greet whoever comes by."
            or (#visitors == 0 and "Nobody yet. Stand where they can see you." or "Nobody is waiting for an answer."))
        cta.text:SetFontObject(GameFontDisableLarge or GameFontDisable)
        SetReply(cta.emote, nil)
        cta.emote:Hide()
        cta.again.visitor = nil
        cta.again:Hide()
        cta.say.place(true)
    end
    cta.say:SetShown(on)
    -- what Say a line says next, so the click is not blind
    local line = on and M.Upcoming() or nil
    cta.next:SetText(line and ((NORMAL_FONT_COLOR_CODE or "") .. "Next line:" .. (NORMAL_FONT_COLOR_CODE and "|r" or "") .. " " .. line) or "")
    cta.next:SetShown(line ~= nil)
    cta.skip:SetShown(line ~= nil)
    if Away() then
        frame.status:SetText("You are AFK: nothing goes out by itself until you are back.")
    else
        frame.status:SetText(manual and "No emotes back by itself here: the replies are your click."
            or "The big button does that emote at them.")
    end
    Fade()
end
M.Sync = function() Sync() end

-- They got their answer.
local function Done(v)
    if not v then return end
    v.doneAt = Now()
    Sync()
end

local lastSend = -1e9
-- The reply, on a click: the game's emote, at them. Then the next one is ready for next time.
function M.Reply(v)
    if not (v and v.token) then return false end
    local now = Now()
    if now - lastSend < SEND_GAP or not CanReply(v, now) then return false end
    if v.say then
        if not Say(v.say, "click", nil, function() Stat("welcomes") end) then
            ns.Print("the game refused the emote.")
            return false
        end
        v.say = nil
    elseif not Emote(v.token, v.name, "click") then
        ns.Print("the game refused the emote.")
        return false
    end
    lastSend = now
    v.emotedAt = now
    v.token = Pick(v, v.token)
    Done(v)
    return true
end

-- Another emote for them, without doing it.
function M.Another(v)
    if not (v and v.reply) then return false end
    v.token = Pick(v, v.token)
    Sync()
    return true
end

-- No echo, or the game said no. A few of those in a row: the shop stops emoting by itself.
Missed = function()
    misses = misses + 1
    if misses >= MISSES and on and not manual then
        manual = true
        ns.Print("the game does not let an addon emote by itself here. The buttons in the window do it with a click.")
        Sync()
    end
end

-- An emote by itself, if the limits allow. The dance comes back a few seconds later.
local function MayAuto(v, gap)
    if manual or not v.reply or not v.reply[2] or Away() then return false end
    local now = Now()
    if now - lastAuto < GLOBAL_GAP or (v.emotedAt and now - v.emotedAt < gap) then return false end
    -- a dance back only if you are not dancing already, and not right after the last one
    if v.reply[2] == "DANCE" and (dancing or now - lastDance < DANCE_GAP) then return false end
    return true
end
-- Which emote goes back by itself this time: mostly the one that fits what they did, now and then
-- another of its group (M.AUTO). Never the one this person got last, and never a third of the same in
-- a row to the crowd. Until 1.8.0 it was the fitting one every time, and a wink is the fitting one for
-- most things, so the chat read "winks at A", "winks at B", "winks at C": a bot.
local recent = {}                -- the last two that went out by itself
local function AutoToken(v)
    local main = v.reply[2]
    local pool, has = { main }, { [main] = true }
    for _, t in ipairs(M.AUTO[v.reply[3] or "any"] or {}) do
        if not has[t] then has[t] = true; pool[#pool + 1] = t end
    end
    local function pick(strict)
        local list, total = {}, 0
        for i, t in ipairs(pool) do
            local out = t == v.autoToken or (strict and recent[1] == t and recent[2] == t)
            if not out then
                local w = i == 1 and M.AUTO_MAIN or 1
                list[#list + 1] = { t, w }
                total = total + w
            end
        end
        if #list == 0 then return nil end
        local roll, sum = M.Random(0, total), 0
        for _, e in ipairs(list) do
            sum = sum + e[2]
            if roll < sum then return e[1] end
        end
        return list[#list][1]
    end
    return pick(true) or pick(false) or main
end
M.AutoToken = AutoToken
local function Auto(v, gap)
    if not MayAuto(v, gap) then return false end
    local token = AutoToken(v)
    if not Emote(token, v.name, "event") then
        Missed()
        return false
    end
    lastAuto, v.emotedAt = Now(), Now()
    v.autoToken = token
    recent[2], recent[1] = recent[1], token
    return true
end

-- A person needs a moment to read an emote and answer it. One that comes back in the same instant,
-- every time, is a bot (SuccuDev, 2026-11-17: "make reactions to peoples emotes have a more natural
-- delay too"). So the answer by itself goes out a few seconds later, picked at random each time; a
-- wink at somebody who only looks gets a shorter wait, on top of the HOLD seconds they kept looking.
-- When the wait is over everything is checked again: still dancing, not AFK, not answered by a click
-- in the meantime, the limits, and a looker must still be looking.
M.REACT = { 2, 5 }               -- seconds before an answer to an emote; nil: at once
M.REACT_LOOK = { 0.5, 2.5 }      -- ... before the wink at somebody who only looks
local function Later(v, gap, look)
    if v.answering or not MayAuto(v, gap) then return false end
    local wait
    if look then wait = M.REACT_LOOK else wait = M.REACT end
    if not (wait and C_Timer and C_Timer.After) then return Auto(v, gap) end
    v.answering = true
    C_Timer.After(M.Random(wait[1], wait[2]), function()
        v.answering = nil
        if not on then return end
        if v.doneAt and v.doneAt >= v.at then return end             -- answered with a click meanwhile
        local sent
        if v.kind == "look" then
            -- looked away while it waited: no wink after them (seen on the last look, a second ago at most)
            sent = v.seen ~= nil and Now() - v.seen <= TICK + 0.6 and Auto(v, LOOK_GAP)
        elseif v.kind == "emote" then
            sent = Auto(v, PERSON_GAP)      -- what they did last, if more came while it waited
        end
        if sent and Sync then Sync() end
    end)
    return true
end

-- Who was rude, and how often, since you logged in. Twice, and they are ignored until you log out.
local rude = {}
function M.Ignored(name)
    return name ~= nil and (rude[name] or 0) >= HECKLE
end

local function ReplyFor(text)
    local l = text:lower()
    for _, word in ipairs(RUDE) do
        if l:find(word, 1, true) then return SAD_REPLY end
    end
    for _, r in ipairs(REPLIES) do
        if l:find(r[1], 1, true) then return r end
    end
    return DEFAULT_REPLY
end

-- Was it your own emote? The game shows those to you too ("You greet everyone with a hearty hello!").
-- The name check alone missed them, so the wording and the sender's GUID count as well.
local function Mine(text, sender, guid)
    local me = Me()
    if me and (Short(sender) == me or Short(sender) == MeFull()) then return true end
    if text:match("^You ") then return true end
    if guid ~= nil and Readable(guid) and type(UnitGUID) == "function" then
        local ok, mine = pcall(UnitGUID, "player")
        if ok and Readable(mine) and mine ~= nil and mine == guid then return true end
    end
    return false
end
M.Mine = Mine

local function OnEmote(text, sender, guid)
    if not (Readable(text) and Readable(sender) and type(text) == "string" and type(sender) == "string") then return end
    if sender == "" then return end
    if Mine(text, sender, guid) then
        -- a dance the addon sent is no news: it does not hold the lines at nobody back
        if not (pend and pend.token == "DANCE") then lastOwn = Now() end
        Echo(text)
        -- your own emote, as the game showed it: whoever it names has their answer ("You wink at Bob.")
        local hit = false
        for _, v in ipairs(visitors) do
            if text:find(Short(v.name), 1, true) and not (v.doneAt and v.doneAt >= v.at) then
                v.doneAt = Now()
                hit = true
            end
        end
        if hit then Sync() end
        return
    end
    if not text:lower():find("%f[%a]you%f[%A]") then return end        -- only what is aimed at you
    local reply = ReplyFor(text)
    if reply == SAD_REPLY then rude[sender] = (rude[sender] or 0) + 1 end
    if M.Ignored(sender) then
        -- Their second rude emote, and whatever they do after it: listed, so you see it, and that is all.
        -- No pout, no button, no flash of the taskbar, and the lines at nobody do not wait for them.
        -- A pout every two minutes is what somebody who spits for a reaction came for.
        local engaged = lastEngage
        Visit(sender, "emote", text, false, false)
        lastEngage = engaged
        Sync()
        return
    end
    local v = Visit(sender, "emote", text, reply, reply ~= SAD_REPLY)
    if reply then Later(v, PERSON_GAP) end
    Sync()
end

local function OnWhisper(text, sender)
    if not (Readable(text) and Readable(sender) and type(text) == "string" and type(sender) == "string") or sender == "" then return end
    local seen = Find(sender)
    Visit(sender, "whisper", "whispered: " .. text, (seen and seen.reply) or WHISPER_REPLY, true)
    Sync()
end

-- Who has you targeted: read off the nameplates in view (they must be shown for this to see anybody).
-- Somebody who tipped you before is in view again: welcomed back in /e, once in two hours. If the
-- line does not go out, they wait on the big button, whose click says it.
local welcomeTurn = 0
local function Welcome(name, now)
    local db = ns.db
    local t = type(db) == "table" and type(db.tippers) == "table" and db.tippers[name]
    if type(t) ~= "table" or Away() or now - lastAuto < GLOBAL_GAP then return false end
    local last = math.max(tonumber(t.last) or 0, tonumber(t.welcomed) or 0)
    if time() - last < BACK_AGAIN then return false end
    t.welcomed = time()
    lastAuto = now
    welcomeTurn = welcomeTurn % #M.WELCOMES + 1
    -- the whole name, as the game's own emotes show it (SuccuDev, 2026-11-16: "welcome back isnt giving
    -- the full name only first name")
    local line = (M.WELCOMES[welcomeTurn]:gsub("{name}", function() return Short(name) end))
    Say(line, "back", function()
        local v = Visit(name, "back", "is back. Tipped you before", BACK_REPLY, true)
        v.token, v.say = "WELCOMEBACK", line
        Sync()
    end, function() Stat("welcomes") end)
    return true
end

-- Still looking after half a minute: one glance at the tip jar and at them.
local nudged = {}
Nudge = function(v, now)
    if manual or Away() or not v.since or now - v.since < NUDGE_HOLD or now - lastAuto < GLOBAL_GAP then return false end
    if nudged[v.name] and now - nudged[v.name] < NUDGE_AGAIN then return false end
    nudged[v.name] = now
    lastAuto = now
    local line = M.NUDGE:format(Short(v.name))
    Queue(function(from) Say(line, from or "nudge", nil, function() Stat("nudges") end) end)
    return true
end

-- Who has you targeted: read off the nameplates in view (they must be shown for this to see anybody).
-- Returns how many players are in view.
local function Look()
    if type(UnitExists) ~= "function" or type(UnitIsUnit) ~= "function" then return 0 end
    local now, near = Now(), 0
    for i = 1, 40 do
        local unit = "nameplate" .. i
        local okp, player = pcall(function() return UnitExists(unit) and UnitIsPlayer(unit) end)
        if okp and Readable(player) and player then
            near = near + 1
            local name = NameOf(unit)
            if name then Welcome(name, now) end
            local ok, hit = pcall(UnitIsUnit, unit .. "target", "player")
            if name and ok and Readable(hit) and hit then
                local v = Find(name)
                if not v then
                    v = Visit(name, "look", nil, not M.Ignored(name) and LOOK_REPLY, false)
                elseif v.kind == "look" and now - math.max(v.at, v.seen or 0) > RELOOK then
                    v = Visit(name, "look", nil, nil, false)      -- looked away and came back
                elseif v.kind == "look" and now - (v.seen or v.at) > STILL then
                    v.at = now                                    -- targeted you again: a new ten seconds, quietly
                end
                if not (v.seen and now - v.seen <= TICK + 0.6) then
                    -- a new look starts: how long it must last this time, and whether it gets a wink at all
                    v.since = now
                    v.hold = M.HOLD and M.Random(M.HOLD[1], M.HOLD[2]) or HOLD
                    v.pass = (M.LOOK_SKIP or 0) > 0 and M.Random(0, 1) > 1 - M.LOOK_SKIP
                else
                    v.watched = (v.watched or 0) + (now - v.seen)       -- how long they have had you targeted, all told
                end
                v.seen = now
                if not v.pass and not M.Ignored(name) and now - (v.since or now) >= (v.hold or HOLD) then
                    Later(v, LOOK_GAP, true)
                end
            end
        end
    end
    return near
end

-- A line by itself waits here for a click on the counter's Say a line button, which lights up while
-- one waits, and goes out on that click. Nothing else sets it off: not a key press, not a click in the
-- world (SuccuDev, 2026-11-17: "just leave it on the button not the clicks"). One that waited too long
-- is dropped; the next one that comes due waits in its place.
local QUEUE_KEEP, QUEUE_OLD = 3, 60
local queue = {}
local function Purge()
    local now = Now()
    for i = #queue, 1, -1 do
        if M.HARDWARE_ONLY and now - queue[i].at > (queue[i].old or QUEUE_OLD) then table.remove(queue, i) end
    end
end
Flush = function(from)
    Purge()
    if not (on and queue[1]) or Away() then return false end
    local q = table.remove(queue, 1)
    q.fn(from)
    return true
end
-- line: what it will say, when that is settled already (a tip jar line, a line that is tried again).
-- A line at nobody has none until it goes out: it says whatever is up next then.
Queue = function(fn, old, soft, line)
    queue[#queue + 1] = { fn = fn, at = Now(), old = old, soft = soft, line = line }
    while #queue > QUEUE_KEEP do table.remove(queue, 1) end
    if not M.HARDWARE_ONLY then Flush() end
end
M.Queued = function() return #queue end

local jarTurn, jarOwed, nextJar = 0, nil, nil
-- Every third jar line counts the jar out loud, and the count is seeded like a busker's hat
-- (SuccuDev: "we could lie about this lmao", "people do this kind of shit in roleplay all the time"):
-- today's real tips plus a head start that is picked once a day and only ever grows, so two people
-- who hear it an hour apart never hear it go down.
M.JAR_COUNT = "counts the tip jar: %d tips today."
local COUNT_EVERY = 3
local jarCount = 0
function M.TipCount()
    local db = ns.db
    if type(db) ~= "table" then return 0 end
    local day = type(date) == "function" and date("%Y-%m-%d") or "?"
    local pad = type(db.jarPad) == "table" and db.jarPad.day == day and db.jarPad or { day = day, n = M.Random(3, 6), said = 0 }
    db.jarPad = pad
    local real = ns.Stats and tonumber((ns.Stats(0) or {}).tips) or 0
    local n = math.max(real + pad.n, pad.said or 0)
    pad.n = pad.n + M.Random(0, 1)      -- a little more by the next time
    pad.said = n
    return n
end

-- The count names today's biggest tip when there is one worth naming (SuccuDev, 2026-11-17, picked it
-- from a list of ideas): it tells whoever reads it what people tip, and asks nobody for anything. The
-- amount is real, in whole gold, and under a gold nothing is named: "the biggest was 40 copper" would
-- set the bar on the floor.
M.JAR_BIG = "counts the tip jar: %d tips today. The biggest was %s."
M.JAR_BIG_MIN = 10000           -- copper: the smallest tip worth naming
function M.BiggestTip()
    local big = ns.Stats and tonumber((ns.Stats(0) or {}).tipMax) or 0
    return big >= M.JAR_BIG_MIN and math.floor(big / 10000) * 10000 or nil
end

-- The next tip jar line.
local function JarLine()
    jarCount = jarCount + 1
    if jarCount % COUNT_EVERY == 0 then
        local big = M.BiggestTip()
        if big then return M.JAR_BIG:format(M.TipCount(), ns.PriceText(big, "words")) end
        return M.JAR_COUNT:format(M.TipCount())
    end
    jarTurn = jarTurn % #M.JAR + 1
    return M.JAR[jarTurn]
end

-- Says a tip jar line: the one given (it was shown on the counter), the one still owed, or the next.
function M.Jar(from, line)
    line = line or jarOwed or JarLine()
    jarOwed = nil
    if Sync then Sync() end
    return Say(line, from, function()
        jarOwed = line
        if Sync then Sync() end
    end, function() Stat("jar") end)
end
function M.JarOwed() return jarOwed end
function M.NextJar(t) if t then nextJar = t end return nextJar end

-- The line at nobody that goes out next. It is picked ahead of time, so the counter can show it before
-- the click (a line goes out only on Say a line, and until 1.8.0 that click was blind), and it is picked
-- for the crowd that is there (M.WHEN).
-- Which one: of the lines that fit, the one said longest ago, in the order of the list while none has
-- been said yet. A line that is made for this crowd comes back a few turns sooner than the others, but
-- never straight after itself.
local crowd = { near = 0, look = 0, stare = 0 }
local upcoming                   -- the line that is up next, as the counter shows it
local saidOn, turnNo, lastLine = {}, 0, nil
local MADE_BONUS, MADE_AFTER = 5, 4     -- a line made for the crowd: this many turns sooner, once it is this many turns old
local function PickIdle()
    local best, bestKey
    for _, line in ipairs(M.IDLE) do
        local level = M.Suits(line, crowd)
        if level > 0 and line ~= lastLine then
            local age = turnNo - (saidOn[line] or -1e6)
            local key = age + ((level == 2 and age >= MADE_AFTER) and MADE_BONUS or 0)
            if not bestKey or key > bestKey then best, bestKey = line, key end
        end
    end
    return best or lastLine or M.IDLE[1]
end
-- Keeps the line that is up next right for the crowd: one that no longer fits is swapped, and so is a
-- plain one when a line made for this crowd has come up. Otherwise it stays, so the text on the
-- counter does not change under your cursor.
local function Peek()
    if upcoming then
        local level = M.Suits(upcoming, crowd)
        if level == 2 then return upcoming end
        local best = PickIdle()
        if level == 0 or M.Suits(best, crowd) == 2 then upcoming = best end
        return upcoming
    end
    upcoming = PickIdle()
    return upcoming
end
-- It goes out (or is passed on): to the back of the row.
local function Take(skipped)
    local line = Peek()
    turnNo = turnNo + 1
    saidOn[line] = turnNo
    if not skipped then lastLine = line end
    upcoming = nil
    return line
end
M.Crowd = function(near, look, stare)       -- for the tests: the crowd as the addon sees it
    if near then crowd.near, crowd.look, crowd.stare = near, look or 0, stare or 0 end
    return crowd
end

-- What Say a line would say right now: the line that is waiting, or the line at nobody that is up next.
function M.Upcoming()
    if not on then return nil end
    Purge()
    return (queue[1] and queue[1].line) or Peek()
end

-- An idle line, at nobody.
local nextIdle
function M.Idle(from)
    local function done() Stat("idle") end
    if from ~= "timer" then return Say(Take(), from, nil, done) end
    local tries, line = 0, nil
    local function send(f)
        line = line or Take()
        Say(line, f or "timer", function()
            tries = tries + 1
            if tries < 2 and M.HARDWARE_ONLY then Queue(send, nil, true, line) end     -- once more, on the next click of the button
        end, done)
    end
    Queue(send, nil, true)
    return true
end
function M.NextIdle(t) if t then nextIdle = t end return nextIdle end

-- The Say a line button: the line that was waiting goes out now; with none waiting, the next line at
-- nobody. A click on it is the only thing that lets a line at nobody out.
function M.SayLine()
    if not on then return false end
    local now = Now()
    lastAuto = now
    local sent
    if queue[1] then
        sent = Flush("click")
    else
        nextIdle = now + M.Random(IDLE_MIN, IDLE_MAX)
        sent = M.Idle("click")
    end
    if Sync then Sync() end
    return sent
end

-- The Skip button: the line shown on the counter is passed on, nothing is said, and the next one comes
-- up. A tip jar line that was waiting is dropped (the next comes due in its own time); a line at nobody
-- goes to the back of the row, and one that is due stays due.
function M.SkipLine()
    if not on then return false end
    Purge()
    if queue[1] and queue[1].line then
        table.remove(queue, 1)
    else
        Take(true)
    end
    if Sync then Sync() end
    return true
end

-- The quick answers to a whisper. The game's context menu, when this client has it.
function M.CanMenu()
    return MenuUtil ~= nil and type(MenuUtil.CreateContextMenu) == "function"
end
local lastWhisper = -1e9
-- Whispers one of them to a visitor, on your click.
function M.Whisper(v, line)
    if not (v and v.name and type(line) == "string") then return false end
    local now = Now()
    if now - lastWhisper < SEND_GAP then return false end
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" or not pcall(send, line, "WHISPER", nil, v.name) then
        ns.Print("the game refused the whisper.")
        return false
    end
    Log("click whisper to " .. tostring(v.name) .. ": " .. line)
    lastWhisper = now
    Stat("whispers")
    v.doneAt = now
    Sync()
    return true
end
-- The menu on a whisperer's Reply button: the quick answers, then the emote the button would have done.
function M.ReplyMenu(owner, v)
    if not (v and v.reply and M.CanMenu()) then return false end
    local ok = pcall(MenuUtil.CreateContextMenu, owner, function(_, root)
        root:CreateTitle("Whisper " .. Short(v.name))
        for _, line in ipairs(M.WHISPERS) do
            root:CreateButton(line, function() M.Whisper(v, line) end)
        end
        if v.token then
            root:CreateButton((Label(v) or "Emote") .. " at " .. Short(v.name), function() M.Reply(v) end)
        end
    end)
    return ok
end

-- For a tip: a dance to their name, a few seconds after the thank-you. Only while the shop is open.
function M.DanceFor(name)
    -- SuccuDev, 2026-11-16, of a thank-you, a whisper, "dances for Bob." and a glance at the tip jar all
    -- at one tipper: "bit too intense". A tip gets the thank-you and the whisper, nothing more by itself;
    -- the glance at the tip jar at somebody who keeps looking is gone as well. The lines at nobody wait.
    lastEngage = Now()
    return false
end

-- AFK while the mailbox is on: a big prompt, so you come back (SuccuDev: "I need a big prompt telling
-- me to un-afk"): the game's raid warning text, a dialog with a button that ends it, the taskbar icon.
local wasAway = false
local function AwayPrompt(away)
    if away == wasAway then return end
    wasAway = away
    if away then
        Log("afk: nothing by itself")
        if type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
        if type(RaidNotice_AddMessage) == "function" and RaidWarningFrame then
            pcall(RaidNotice_AddMessage, RaidWarningFrame, "You are AFK. Your emotes are paused.",
                (ChatTypeInfo and ChatTypeInfo.RAID_WARNING) or { r = 1, g = 0.28, b = 0 })
        end
        if ns.db and ns.db.sound ~= false and ns.AlertSound then
            ns.AlertSound(SOUNDKIT and SOUNDKIT.RAID_WARNING, 8959)
        end
        if StaticPopupDialogs and type(StaticPopup_Show) == "function" then
            StaticPopupDialogs.MAILBOXSLUTTING_AFK = StaticPopupDialogs.MAILBOXSLUTTING_AFK or {
                text = "You are AFK.\n\nPeople see <AFK> over your head, and nothing is emoted back until you are back. Move, or click below.",
                button1 = "I'm back",
                OnAccept = function()
                    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
                    if type(send) == "function" then pcall(send, "", "AFK") end   -- the game's /afk: off again
                end,
                timeout = 0, whileDead = true, hideOnEscape = false, showAlert = true, preferredIndex = 3,
            }
            pcall(StaticPopup_Show, "MAILBOXSLUTTING_AFK")
        end
    elseif type(StaticPopup_Hide) == "function" then
        pcall(StaticPopup_Hide, "MAILBOXSLUTTING_AFK")
    end
    if Sync then Sync() end
end
M.AwayPrompt = function() return wasAway end

local function Tick()
    if not on then return end
    local away = Away()
    AwayPrompt(away)
    if not away then Stat("open", TICK) end
    local near = Look()
    local now = Now()
    -- the crowd, for the lines that fit it: who is in view, who has you targeted, and for how long
    local look, stare = 0, 0
    for _, v in ipairs(visitors) do
        if v.seen and now - v.seen <= TICK + 0.6 then
            look = look + 1
            stare = math.max(stare, now - (v.since or now))
        end
    end
    crowd.near, crowd.look, crowd.stare = near, look, stare
    nextJar = nextJar or (now + M.Random(JAR_FIRST_MIN, JAR_FIRST_MAX))
    local quiet = now - lastEngage >= ENGAGE_HOLD
    Purge()
    quiet = quiet and now - lastOwn >= LINE_GAP
    -- the dance again, for whoever came into view since the last one
    if M.REFRESH and dancing and not due and not away then
        nextRefresh = nextRefresh or (lastDance + M.Random(M.REFRESH[1], M.REFRESH[2]))
        if now >= nextRefresh and not Busy() then
            nextRefresh = nil
            due, tries = now, 0
            M.Redance("refresh")
        end
    end
    if now >= nextJar and near > 0 and not away and quiet and not queue[1] and now - lastAuto >= GLOBAL_GAP then
        nextJar = now + M.Random(JAR_MIN, JAR_MAX)
        lastAuto = now
        local line = jarOwed or JarLine()       -- settled now, so the counter can show it before the click
        Queue(function(from) M.Jar(from or "timer", line) end, nil, true, line)
    end
    nextIdle = nextIdle or (now + M.Random(IDLE_FIRST_MIN, IDLE_FIRST_MAX))
    if now >= nextIdle and near > 0 and not away and quiet and not queue[1] and now - lastAuto >= GLOBAL_GAP then
        nextIdle = now + M.Random(IDLE_MIN, IDLE_MAX)
        lastAuto = now
        M.Idle("timer")
    end
    Prune()
    Sync()
    C_Timer.After(TICK, Tick)
end

local function Button(parent, label, w, h)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
    if not (ok and b) then b = CreateFrame("Button", nil, parent) end
    b:SetSize(w, h or 20)
    b:SetText(label)
    return b
end

-- A reply button: the game's panel button. Its click is what lets the emote go out.
local function ReplyButton(parent, label, w, h)
    local b = Button(parent, label, w, h)
    b:SetScript("OnClick", function(self)
        if self.menu and self.visitor and M.ReplyMenu(self, self.visitor) then return end
        M.Reply(self.visitor)
    end)
    return b
end

-- Text never runs over anything. Every text gets a box it
-- cannot leave: a fixed height for its lines on top of the width its anchors give it, no wrapping for
-- one line and a line cap for more. The game draws nothing outside a box with both sizes set.
local LINE_H = { GameFontNormalLarge = 18, GameFontNormal = 14, GameFontDisable = 14 }
local function Text(parent, font, lines)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    if fs.SetFontObject and _G[font] then pcall(fs.SetFontObject, fs, _G[font]) end
    lines = lines or 1
    fs:SetJustifyH("LEFT")
    if fs.SetJustifyV then fs:SetJustifyV(lines > 1 and "TOP" or "MIDDLE") end
    if fs.SetWordWrap then fs:SetWordWrap(lines > 1) end
    if fs.SetMaxLines then fs:SetMaxLines(lines) end
    fs:SetHeight(lines * (LINE_H[font] or 12))
    return fs
end
M.Text = Text

local function ReplyTip(self)
    local v = self.visitor
    if not (GameTooltip and v and v.reply) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.menu then
        GameTooltip:SetText("Reply to " .. Short(v.name))
        GameTooltip:AddLine("Opens the quick answers: pick one and it is whispered to them. The emote is in there too.", 1, 0.82, 0, true)
        GameTooltip:Show()
        return
    end
    GameTooltip:SetText((Label(v) or "Emote") .. " at " .. Short(v.name))
    GameTooltip:AddLine(v.say and ("/e " .. v.say) or ("Does the game's /" .. v.token:lower() .. " at them."), 1, 0.82, 0, true)
    GameTooltip:Show()
end

local function HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

local TOP = 122                 -- title, who is waiting, the big button, the line that is up next

local embedded = false
local DY = 0                    -- how much higher everything sits inside the counter (no title bar)
local function Build(host)
    if frame then return frame end
    local f
    if host then
        embedded, DY = true, 30
        f = CreateFrame("Frame", "MailboxSluttingMailbox", host)
        f:SetSize(430, TOP - DY + ROWS * ROW_H + 40)
    else
        local ok, w = pcall(CreateFrame, "Frame", "MailboxSluttingMailbox", UIParent, "BasicFrameTemplateWithInset")
        f = (ok and w) or CreateFrame("Frame", "MailboxSluttingMailbox", UIParent)
        f:SetSize(430, TOP + ROWS * ROW_H + 46)
        f:SetPoint("RIGHT", UIParent, "RIGHT", -120, 60)
        f:SetClampedToScreen(true)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        if type(f.TitleText) == "table" then f.TitleText:SetText("Dancing for tips") end
        if type(f.CloseButton) ~= "table" then
            local okc, close = pcall(CreateFrame, "Button", nil, f, "UIPanelCloseButton")
            if okc and close then
                close:SetPoint("TOPRIGHT", 0, 0)
                close:SetScript("OnClick", function() f:Hide() end)
            end
        end
    end
    frame = f
    -- hidden: the shop closes, unless the counter only stepped aside for a fight
    f:SetScript("OnHide", function()
        if not (ns.Counter and ns.Counter.Hiding and ns.Counter.Hiding()) then M.Stop(true) end
    end)
    local since = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        since = since + (elapsed or 0)
        if since < 0.1 then return end
        since = 0
        Fade()
    end)

    -- who is waiting, and the one big button for them
    local cta = {}
    f.cta = cta
    cta.text = Text(f, "GameFontNormalLarge")
    cta.text:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -34 + DY)
    cta.text:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    cta.emote = ReplyButton(f, "Wink", 190, 30)
    cta.emote:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -58 + DY)
    cta.emote:SetScript("OnEnter", ReplyTip)
    cta.emote:SetScript("OnLeave", HideTip)
    cta.again = Button(f, "Other emote", 100, 30)
    cta.again:SetPoint("LEFT", cta.emote, "RIGHT", 6, 0)
    cta.again:SetScript("OnClick", function(self) M.Another(self.visitor) end)
    cta.again:Hide()
    cta.emote:Hide()
    cta.say = Button(f, "Say a line", SAY_BIG, 30)
    cta.say.place = function(big)
        if cta.say.big == big then return end
        cta.say.big = big
        cta.say:ClearAllPoints()
        if big then
            cta.say:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -58 + DY)
        else
            cta.say:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -58 + DY)
        end
        cta.say:SetWidth(big and SAY_BIG or SAY_SMALL)
    end
    cta.say.place(true)
    cta.say:SetScript("OnClick", function() M.SayLine() end)
    cta.say:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Say a line")
        GameTooltip:AddLine("Says the line shown under \"Next line\" in /e, right now. Nothing else says one: no key "
            .. "press and no click in the world. The button lights up when a line is due.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    cta.say:SetScript("OnLeave", HideTip)
    cta.say:Hide()
    -- The line Say a line says next, and a way to pass on it. Two lines of small text in a box of their
    -- own, left of the Skip button and clear of the list under it.
    cta.next = Text(f, "GameFontHighlightSmall", 2)
    cta.next:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -93 + DY)
    cta.next:SetPoint("RIGHT", f, "RIGHT", -76, 0)
    cta.next:Hide()
    cta.skip = Button(f, "Skip", 56, 20)
    cta.skip:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -94 + DY)
    cta.skip:SetScript("OnClick", function() M.SkipLine() end)
    cta.skip:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Skip")
        GameTooltip:AddLine("Passes on the line shown and brings up another. Nothing is said.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    cta.skip:SetScript("OnLeave", HideTip)
    cta.skip:Hide()

    f.rows = {}
    for r = 1, ROWS do
        local row = CreateFrame("Frame", nil, f)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -TOP + DY - (r - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -TOP + DY - (r - 1) * ROW_H)
        row.emote = ReplyButton(row, "Emote", 62)
        row.emote:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        row.emote:SetScript("OnEnter", ReplyTip)
        row.emote:SetScript("OnLeave", HideTip)
        row.done = row:CreateTexture(nil, "ARTWORK")        -- the game's ready-check tick: answered
        row.done:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        row.done:SetSize(14, 14)
        row.done:SetPoint("RIGHT", row.emote, "LEFT", -4, 0)
        row.done:Hide()
        row.age = Text(row, "GameFontDisableSmall")
        row.age:SetJustifyH("RIGHT")
        row.age:SetWidth(28)
        row.age:SetPoint("RIGHT", row.done, "LEFT", -4, 0)
        row.name = Text(row, "GameFontNormal")
        row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name:SetWidth(84)
        row.what = Text(row, "GameFontHighlightSmall")
        row.what:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
        row.what:SetPoint("RIGHT", row.age, "LEFT", -6, 0)
        row:Hide()
        f.rows[r] = row
    end
    f.empty = Text(f, "GameFontDisable", 2)
    f.empty:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -TOP + DY - 6)
    f.empty:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    f.empty:SetText("Whoever emotes at you, whispers you or targets you shows up here.")
    f.status = Text(f, "GameFontHighlightSmall", 2)        -- two lines, kept under the last row
    if f.status.SetJustifyV then f.status:SetJustifyV("BOTTOM") end
    f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, embedded and 10 or 16)
    f.status:SetPoint("RIGHT", f, "RIGHT", -170, 0)
    f.dance = Button(f, "Dance", 72)
    f.dance:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, embedded and 6 or 12)
    f.dance:SetScript("OnClick", function() Emote("DANCE", nil, "click") end)
    f.jar = Button(f, "Tip jar", 72)
    f.jar:SetPoint("RIGHT", f.dance, "LEFT", -6, 0)
    f.jar:SetScript("OnClick", function() M.Jar("click") end)
    f.jar:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Tip jar")
        GameTooltip:AddLine("Says a short line about your tip jar in /e. One also comes due every 8 to 12 minutes "
            .. "while somebody is around: Say a line lights up and says it.", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    f.jar:SetScript("OnLeave", HideTip)
    if not embedded then f:Hide() end
    return f
end

-- The counter puts mailbox mode inside itself: the panel, and how tall it is.
function M.Embed(host)
    Build(host)
    return frame, frame:GetHeight()
end

function M.Start()
    if on then return true end
    if not (C_Timer and C_Timer.After) then
        ns.Print("dancing for tips needs the game's timers, and this client has none.")
        return false
    end
    if ns.Counter and ns.Counter.Show then ns.Counter.Show() end
    local ok, err = pcall(Build)
    if not ok then
        ns.Print("the window could not be built: " .. tostring(err))
        return false
    end
    if not events then
        events = CreateFrame("Frame")
        events:SetScript("OnEvent", function(_, event, text, sender, ...)
            if not on then return end
            if event == "CHAT_MSG_TEXT_EMOTE" then OnEmote(text, sender, (select(10, ...)))
            elseif event == "CHAT_MSG_WHISPER" then OnWhisper(text, sender)
            elseif event == "CHAT_MSG_EMOTE" then
                if Readable(text) and type(text) == "string" and Readable(sender) and type(sender) == "string"
                    and Mine(text, sender, (select(10, ...))) then lastOwn = Now() SaidEcho(text) end
            elseif event == "PLAYER_FLAGS_CHANGED" then AwayPrompt(Away()) end
            M.Redance(event)
        end)
    end
    for _, e in ipairs({ "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_WHISPER", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
        "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY", "CHAT_MSG_SYSTEM", "PLAYER_FLAGS_CHANGED" }) do
        pcall(events.RegisterEvent, events, e)
    end
    on, manual, misses, pend, dancing, due = true, false, 0, nil, false, nil
    nextJar, nextIdle, nextRefresh, wasAway, lastEngage, lastOwn = nil, nil, nil, false, -1e9, -1e9
    for i = #queue, 1, -1 do queue[i] = nil end
    crowd.near, crowd.look, crowd.stare = 0, 0, 0
    -- Nothing listens to the keyboard or to clicks in the world: the click that brings the game's window
    -- back to the front set a line off each time (SuccuDev, 2026-11-17: "stop auto emoting when I click
    -- into the window"), and a key press did the same ("just leave it on the button not the clicks").
    frame:Show()
    Emote("DANCE", nil, "start")
    Tick()
    ns.Print("you are dancing, and the big button winks or smiles at whoever is waiting. The dance is sent again every 30 to 60 seconds, so whoever walks up sees it. A line at nobody goes out only when you click Say a line. Stop dancing on the counter ends it.")
    return true
end

function M.Stop(fromHide)
    if not on then return end
    on = false
    if wasAway and type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "MAILBOXSLUTTING_AFK") end
    wasAway = false
    if events then
        pcall(events.UnregisterAllEvents, events)
    end
    if frame and not fromHide and not embedded then
        frame:Hide()
    end
    Sync()
    if ns.Counter and ns.Counter.Sync then ns.Counter.Sync() end
    ns.Print("stopped dancing.")
end

function M.Toggle()
    if on then M.Stop() else M.Start() end
end

function M.IsOn() return on end
function M.Frame() return frame end
function M.Visitors() return visitors end
function M.Manual() return manual end
