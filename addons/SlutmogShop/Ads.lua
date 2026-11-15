-- Slutmog Shop: the ready-made ads. Generated; edit the generator, not this file.
-- ns.AD_POOLS: ads shared by pieces with the same look, armor type, slot or level range.
-- ns.ITEM_ADS[id]: the piece's own ads, then pools = the pools it draws on, color = its colour words.
-- {item}, {price} and {shop} are filled in when the ad goes out, {level} too; {color} when the list is built.
local _, ns = ...

ns.AD_POOLS = {
    general = {
        "Warlock's succubus keeps drawing all your group's attention? Take it back. {item}, {price} at {shop}.",
        "Keep getting ganked, never getting camped? Give them a reason to stay. {shop} has {item} for {price}.",
        "Healer let you die again? Give him a reason to watch your health bar. ~ {shop} ~ {item}, {price}.",
        "Tank keeps losing aggro to you and you haven't cast anything yet? That'll be the {item}. {price} at {shop}.",
        "Nobody inspects you at the mailbox anymore? {shop} has {item} for {price}.",
        "Got your epic mount and they still only look at the horse? ~ {shop} ~ {item}, {price}.",
        "Anyone can farm an epic. Getting inspected by everyone at the Ironforge bank takes {item}. {price} at {shop}.",
        "Any fresh 60 has a full set by now. How many have the nerve to wear {item}? {price} at {shop}.",
        "Wearing whatever dropped? People can tell. Wear something you picked on purpose: {item}, {price} at {shop}.",
        "Anyone can buy an epic mount. Paying {price} to wear this little is how they know you're rich. {item} at {shop}.",
        "Poor people wear armor. {shop} has {item} for {price}.",
        "Your guild knows you're geared. Do they know you can afford to wear none of it? ~ {shop} ~ {item}, {price}.",
        "If you have to ask why this little costs {price}, it isn't for you. {item} at {shop}.",
        "Want strangers to open trade and just put gold in? {shop} has {item} for {price}.",
        "Duel requests outside Stormwind dried up? They come back when there's something to see. {item}, {price} at {shop}.",
        "Goldshire regulars walking straight past you? {shop} fixes that. {item}, {price}.",
        "Group disbanded and nobody added you as a friend? They will next time. {shop} has {item} for {price}.",
        "Want the rogue to drop stealth just to get a better look? ~ {shop} ~ {item}, {price}.",
        "Hunter's pet gets more /love than you do? {item}, {price} at {shop}.",
        "When did someone last whisper 'nice gear' and mean it that way? {shop} has {item} for {price}.",
        "Sick of being kicked for low dps? Nobody kicks the one wearing {item}. {price} at {shop}.",
        "Guildies ask for screenshots of your damage meter and never of you? {item}, {price} at {shop}.",
        "Tired of rolling need on attention and losing? {shop} has {item} for {price}.",
        "Die a lot? At least leave a good-looking corpse. ~ {shop} ~ {item}, {price}.",
        "The other faction can't talk to you. In {item} they'll /kneel anyway. {price} at {shop}.",
        "Get followed around Ironforge for once. {shop} has {item} for {price}.",
        "Only whispers you get are 'LF healer'? {item} from {shop} gets you the other kind. {price}.",
        "Always the last one summoned? In {item} the warlock clicks your name first. {price} at {shop}.",
        "Standing on the Ironforge bridge in full tier and nobody stops? Try less. {shop} has {item} for {price}.",
        "Whole raid buffed and nobody looks at you twice? Mark of the Wild doesn't fix that. {item}, {price} at {shop}.",
        "Somebody will ctrl-click this link to see it on. Then they'll want to see it on you. {item}, {price} at {shop}.",
    },
    plate = {
        "Spent 39 levels in mail waiting to show some skin? Plate training finally pays off: {item}, {price} at {shop}.",
        "Trained plate at 40 and it covers even more than the mail did? This one doesn't. ~ {shop} ~ {item}, {price}.",
        "Level 40 gets you a mount and plate. Nobody said the plate had to cover much. {item}, {price} at {shop}.",
        "Paladins, the Light already sees everything. Let the rest of the raid catch up. {shop} has {item} for {price}.",
        "Taunt on cooldown? In {item} you won't need it. {price} at {shop}.",
        "Plate with a tiny repair bill, because there's hardly any plate. {item}, {price} at {shop}.",
        "All that armor and nobody wants to get close? Trade some of it in. {shop} has {item} for {price}.",
        "Warriors: rage comes from getting hit. Leave them more places to aim. ~ {shop} ~ {item}, {price}.",
    },
    mail = {
        "Yes, it has an armor value. No, that's not why anyone buys it. ~ {shop} ~ {item}, {price}.",
        "Durability 100 out of 100. Coverage, maybe 15. {item}, {price} at {shop}.",
        "You'll get a /drool before you get a buff. {shop} has {item} for {price}.",
        "Lowest repair bill you'll ever pay. Count the links, it won't take long. ~ {shop} ~ {item}, {price}.",
    },
    mail_low = {
        "Warriors under 40: plate is a long way off and nobody is looking at your quest greens. {item}, {price} at {shop}.",
        "Paladin levelling takes forever. At least be nice to look at while you auto-attack. {item}, {price} at {shop}.",
        "Level {level} tank and the dps won't wait for you to pull? In {item} they'll stay behind you. {price} at {shop}.",
    },
    mail_high = {
        "Hunters: you learned mail at 40 and the first thing you want is less of it? Good instinct. {item}, {price} at {shop}.",
        "Shamans: 40 levels in leather, and now mail that shows more than the leather did. ~ {shop} ~ {item}, {price}.",
        "Hunters have a dead zone. In {item} everyone wants to stand in yours. {price} at {shop}.",
        "Every item is a hunter item. This one really should be. {shop} has {item} for {price}.",
    },
    leather = {
        "Rogues, you spend half your life invisible. Make the other half count. ~ {shop} ~ {item}, {price}.",
        "Druids: in cat form all day and nobody sees your gear? Make them ask you to shift out. {item}, {price} at {shop}.",
        "Cheap Shot stuns for four seconds. {item} does it for longer. {price} at {shop}.",
        "Pickpocketing is easier when they're looking at you and not at their bags. ~ {shop} ~ {item}, {price}.",
        "The leatherworker ran out of leather about a third of the way in and sold it anyway. {item}, {price} at {shop}.",
    },
    cloth = {
        "Mages: tired of every whisper being 'water pls'? In {item} they open with something else. {price} at {shop}.",
        "Priests, they only whisper you for heals? {item} gets you a different kind of whisper. {price} at {shop}.",
        "Warlocks: your succubus gets all the looks and she works for you. Dress to compete. {item}, {price} at {shop}.",
        "It's cloth, it was never going to stop a sword. So why is yours covering so much? {item}, {price} at {shop}.",
        "You pull aggro and die first every fight. At least die looking like that. {shop} has {item} for {price}.",
    },
    legs = {
        "Riding skill cost you a fortune. Show off what's doing the riding. {shop} has {item} for {price}.",
        "Ride out of Ironforge in {item} and count how many people /follow you. {price} at {shop}.",
        "Nobody ever inspects your legs slot? Give them a reason. {item}, {price} at {shop}.",
        "Sitting down to drink after every pull? In {item} the group won't mind the wait. {price} at {shop}.",
        "For the ones who dance on the mailbox and mean it. ~ {shop} ~ {item}, {price}.",
        "Everyone runs behind the tank anyway. Give them a view. {item}, {price} at {shop}.",
        "You jump everywhere like the rest of us. In {item} people will thank you for it. {price} at {shop}.",
    },
    chest = {
        "Epic shoulders and nobody ever looks any lower? ~ {shop} ~ {item}, {price}.",
        "Guild tabard doing nothing for you? Take it off and show what was under it. {item}, {price} at {shop}.",
        "For when you want the /hug emotes to go on a bit too long. {shop} has {item} for {price}.",
        "Gets you more /whistle than /wave. ~ {shop} ~ {item}, {price}.",
    },
    lvl_low = {
        "Wearable at level {level}. Why wait until 60 to get stared at? {item}, {price} at {shop}.",
        "Level {level} and already bored of looking like a quest reward? {shop} has {item} for {price}.",
        "Only needs level {level}. Twinks get inspected more than anyone. Give them a reason. {item}, {price} at {shop}.",
    },
    lvl_high = {
        "Level 60 and nothing left to do but stand around Ironforge? Stand there properly. {shop} has {item} for {price}.",
        "Nothing left to farm at 60? Farm stares. ~ {shop} ~ {item}, {price}.",
        "Raid gear says you show up on Tuesdays. Wear this the other six days. {item}, {price} at {shop}.",
    },
    look_bikini = {
        "Your character's underwear covers more than this. We checked. ~ {shop} ~ {item}, {price}.",
        "A strip of {color} round the hips. That's the whole item. {item}, {price} at {shop}.",
        "The tooltip says legs. It covers the hips and stops there. {shop} has {item} for {price}.",
        "Counts as pants as far as the guards are concerned. Barely. ~ {shop} ~ {item}, {price}.",
        "Stranglethorn is hot. Dress like you've noticed. {item}, {price} at {shop}.",
    },
    look_fur_halter = {
        "A {color} fur top, open all the way down the front. No buttons, we looked. {item}, {price} at {shop}.",
        "A fur vest that only closes if you hold it shut. You won't. {shop} has {item} for {price}.",
        "Bare from the collarbone to the belt, with fur either side so it counts as dressed. {item}, {price} at {shop}.",
    },
    look_one_shoulder = {
        "A {color} wrap over one shoulder. The other shoulder is out, and so is that side. {shop} has {item} for {price}.",
        "One shoulder covered, one bare, and an armband for decoration. ~ {shop} ~ {item}, {price}.",
        "It's meant to slip off one shoulder. It also slips a bit further than that. {item}, {price} at {shop}.",
    },
    look_zigzag_robe = {
        "A robe with a neckline that stops at the navel. Casters get to have fun too. ~ {shop} ~ {item}, {price}.",
        "Technically a robe. The V down the front goes deeper than your talent tree. {item}, {price} at {shop}.",
        "Robes are supposed to be modest. Whoever cut this one never heard. {shop} has {item} for {price}.",
    },
    look_net_robe = {
        "A {color} robe with see-through net sleeves and silver leaves over exactly two places. {item}, {price} at {shop}.",
        "Floor-length, so it sounds decent. Then you notice the sleeves are see-through netting. {item}, {price} at {shop}.",
        "For casters who want to be watched for the whole cast bar. ~ {shop} ~ {item}, {price}.",
    },
    look_web_robe = {
        "The sleeves are spider web. See-through, sticky-looking, and you're the one doing the catching. {item}, {price} at {shop}.",
        "A teal robe with web for sleeves and silver leaves over exactly two places. ~ {shop} ~ {item}, {price}.",
        "Every spider in Duskwood has webbed you at some point. Your turn. {item}, {price} at {shop}.",
    },
    look_hip_window = {
        "Long trousers with both hips cut out. Ankles covered, hips bare. ~ {shop} ~ {item}, {price}.",
        "Covers the ankles, which nobody asked for, and bares the hips, which they did. {item}, {price} at {shop}.",
        "For people who were told to put some pants on and found a loophole. {shop} has {item} for {price}.",
    },
    look_strap_harness = {
        "Two {color} leather straps and a belt. The tooltip calls that a chest piece. {item}, {price} at {shop}.",
        "It's a harness. Someone will ask what it's a harness for. Let them wonder. {shop} has {item} for {price}.",
        "Straps crossed over the chest and nothing at all between them. ~ {shop} ~ {item}, {price}.",
        "What you wear on top when you'd honestly rather not wear anything. {item}, {price} at {shop}.",
    },
    look_suspenders = {
        "Two straps down the front, a studded belt and some rings. That's the chest piece. {shop} has {item} for {price}.",
        "It has rings on the front. What gets clipped to them is between you and your group. {item}, {price} at {shop}.",
        "Straps placed just barely where they have to be. Don't sprint. {item}, {price} at {shop}.",
    },
    look_cod_leather = {
        "A studded leather panel on two straps. Front only. Think before you turn around. ~ {shop} ~ {item}, {price}.",
        "These are leggings the way a belt buckle is leggings. {item}, {price} at {shop}.",
        "One {color} panel with studs on it, and your legs as you made them at character creation. {item}, {price} at {shop}.",
    },
    look_stud_top = {
        "A leather top with buckles down the front. They undo. {item}, {price} at {shop}.",
        "Buckles, studs and a flap that covers most of it, most of the time. {shop} has {item} for {price}.",
        "{color} leather, tight, with more buckles than it needs. People will count them. ~ {shop} ~ {item}, {price}.",
    },
    look_underbust = {
        "Leather straps that go under and around and nowhere near over. {shop} has {item} for {price}.",
        "A harness that lifts and doesn't cover. ~ {shop} ~ {item}, {price}.",
        "All the leather sits underneath. What sits on top of it is yours. {item}, {price} at {shop}.",
    },
    look_loincloth = {
        "A {color} flap front and back on a studded belt, open at the sides. Careful on the gryphon. {item}, {price} at {shop}.",
        "Covers you from the front and from behind. From the side, not so much. {item}, {price} at {shop}.",
        "It's a loincloth. Don't /sit facing the group. Or do. {shop} has {item} for {price}.",
        "A studded belt, a strip of cloth and a lot of thigh. ~ {shop} ~ {item}, {price}.",
    },
    look_loincloth_mail = {
        "{color} scale flaps front and back on a studded belt. Don't ask a mage for Slow Fall. {item}, {price} at {shop}.",
        "Covers you from the front and from behind. From the side, not so much. {shop} has {item} for {price}.",
        "It's a loincloth made of chain. Don't /sit facing the group. Or do. ~ {shop} ~ {item}, {price}.",
        "A studded belt, a strip of scales and a lot of thigh. {item}, {price} at {shop}.",
    },
    look_black_harness = {
        "Black studded straps, wide belt, {color} trim. Looks like you work nights in Goldshire. {item}, {price} at {shop}.",
        "Black leather and pyramid studs. The warlock's succubus asked where you got it. ~ {shop} ~ {item}, {price}.",
        "A studded harness. People will assume things about your weekends, and they'll be right. {item}, {price} at {shop}.",
        "The sort of outfit where the guards say 'move along' and then don't move. {shop} has {item} for {price}.",
    },
    look_chain_bra = {
        "A chainmail bra with a diamond cut out of the middle, in case the bra was too subtle. {item}, {price} at {shop}.",
        "There's a window right at the cleavage. A duller smith would have put more chain there. {item}, {price} at {shop}.",
        "Mobs hit the chain, players look at the gap. {shop} has {item} for {price}.",
    },
    look_fringe_top = {
        "Leather over one side, nothing over the other, and a chain fringe hanging off the bottom. {item}, {price} at {shop}.",
        "Half a top with a fringe of chain. The other half was never made. {shop} has {item} for {price}.",
        "The chain fringe swings when you run. People will ask you to run. ~ {shop} ~ {item}, {price}.",
    },
    look_scale_top = {
        "A short {color} scale top that stops well above the belt. {shop} has {item} for {price}.",
        "Tight scales on top, bare stomach under them. Level {level} and already dressed better than the 60s. {item}, {price} at {shop}.",
        "About as many scales as a murloc loses in one fight. {item}, {price} at {shop}.",
    },
    look_padded_scoop = {
        "Looks like normal padded armor until you see how low the front scoops. ~ {shop} ~ {item}, {price}.",
        "Standard-issue armor with a neckline no quartermaster signed off on. {item}, {price} at {shop}.",
        "From behind it passes for Stormwind guard issue. Then you turn round. {shop} has {item} for {price}.",
    },
    look_dragon_top = {
        "A {color} scale sash over one shoulder and the rest left out in the open. {item}, {price} at {shop}.",
        "One shoulder gets dragon scale. The other side gets fresh air. {shop} has {item} for {price}.",
    },
    look_dragon_legs = {
        "Tight {color} scale leggings. Nothing left to guess, plenty to look at. {shop} has {item} for {price}.",
        "Scaled, skin-tight, and they shine when you walk. ~ {shop} ~ {item}, {price}.",
    },
    look_garter = {
        "A steel hip plate, some chain tassels and one garter buckled round the thigh. Just the one. {item}, {price} at {shop}.",
        "There's a garter on it. On mail leggings. Somebody at the forge knew what they were doing. {item}, {price} at {shop}.",
        "Chain tassels at the hip, a strap round one thigh, and legs otherwise as you rolled them. {item}, {price} at {shop}.",
    },
    look_chain_cups = {
        "Two {color} steel cups hanging from chains. If the chains hold, it's a chest piece. {item}, {price} at {shop}.",
        "Steel cups on chains. Don't wear it to Winterspring. Wear it everywhere else. {shop} has {item} for {price}.",
        "The whole thing hangs off two chains round the neck. Nobody stands behind you for the loot. {item}, {price} at {shop}.",
    },
    look_scale_bikini = {
        "A {color} scale bikini top on leather straps. Yes it's mail. Yes it has armor. No, not much. {item}, {price} at {shop}.",
        "Bikini armor, the real thing, the reason half of us rolled a female character. ~ {shop} ~ {item}, {price}.",
        "Two patches of scale and some straps. The armor value is a rumour. {item}, {price} at {shop}.",
    },
    look_scale_bikini_legs = {
        "{color} scale bikini bottoms, in mail. Wear with boots and no shame. ~ {shop} ~ {item}, {price}.",
        "Bikini armor, the real thing, the reason half of us rolled a female character. {item}, {price} at {shop}.",
        "A patch of scale front and back and two straps over the hips. {shop} has {item} for {price}.",
    },
    look_band_cup = {
        "A band of scales across the chest and one steel cup. The other side gets good luck. {item}, {price} at {shop}.",
        "The smith only had steel for one cup. Nobody has complained. {shop} has {item} for {price}.",
        "One side armored, one side nearly not. People check both. ~ {shop} ~ {item}, {price}.",
    },
    look_shell = {
        "A breastplate shaped like two seashells. You know the ones. {shop} has {item} for {price}.",
        "Two {color} spiral shells and not much holding them together. Naga wear more. ~ {shop} ~ {item}, {price}.",
    },
    look_ribs = {
        "Bands across the chest like ribs, with a gap between every one. ~ {shop} ~ {item}, {price}.",
        "It's mostly gaps. The bars between the gaps are the armor. {item}, {price} at {shop}.",
        "Looks like a cage that was built a size too small on purpose. {shop} has {item} for {price}.",
    },
    look_tiles = {
        "Leather tiles laced together with red cord and hung roughly where they're needed. {item}, {price} at {shop}.",
        "It's held together with red cord. Everyone who sees it thinks about the knot. {shop} has {item} for {price}.",
    },
    look_plate_thong = {
        "It's a metal thong. We can call it legplates if the guards ask. {shop} has {item} for {price}.",
        "A {color} codpiece on chains. That's the legs slot filled. ~ {shop} ~ {item}, {price}.",
        "Armor for exactly one spot. Both legs are out from hip to boot. {item}, {price} at {shop}.",
        "Costs about four copper to repair, because look at it. {shop} has {item} for {price}.",
    },
    look_single_cup = {
        "One cup held on by metal rods and one side left to chance. ~ {shop} ~ {item}, {price}.",
        "Covers one side properly. The other side is between you and the weather. {item}, {price} at {shop}.",
        "{color}, lopsided on purpose, and the bare side is the one they'll stand on. {shop} has {item} for {price}.",
    },
    look_chastity = {
        "Steel bottoms with a lock ring on the front, like a chastity belt. Key not included. {item}, {price} at {shop}.",
        "Looks like someone locked you into it for a reason. Guildies will ask what you did. {item}, {price} at {shop}.",
        "A locked steel belt and bare legs under it. Tell them who holds the key or let them guess. {item}, {price} at {shop}.",
        "There's a lock on the front. Every rogue in Ironforge will offer to level lockpicking on it. {item}, {price} at {shop}.",
    },
    look_plate_bikini = {
        "Bikini armor, the real thing, the reason half of us rolled a female character. {shop} has {item} for {price}.",
        "Two {color} cups and some cord. That's the breastplate. ~ {shop} ~ {item}, {price}.",
        "The smith charged full price for a third of the metal. So do we, and you'll still pay. {item}, {price} at {shop}.",
        "Fancy trim on the cups so they know it cost gold, bare belly so they forget to ask how much. {item}, {price} at {shop}.",
        "The most expensive way to wear almost nothing at level {level}. ~ {shop} ~ {item}, {price}.",
    },
    look_barred_window = {
        "Full plate, barred window over the cleavage. Same bars as the Stockade, better view. {item}, {price} at {shop}.",
        "Solid {color} plate except for one window with bars across it, right where you'd guess. {item}, {price} at {shop}.",
        "From the back of the raid it looks like proper armor. Then you turn around. {shop} has {item} for {price}.",
    },
    look_high_cut = {
        "Hip plates cut so high on the thigh that the leg just keeps going. {item}, {price} at {shop}.",
        "{color} plate over the hips, slits up both sides, bare thigh from there to the boot. {item}, {price} at {shop}.",
        "Legplates with barely any leg plate. All of it sits on the hips. ~ {shop} ~ {item}, {price}.",
    },
    look_collar_strip = {
        "A spiked collar and one strip of plate down the middle. The sides are bare from armpit to hip. {item}, {price} at {shop}.",
        "It comes with a spiked collar. Who holds the leash is your business. ~ {shop} ~ {item}, {price}.",
        "Plate down the centre only. From the side it's all you. {item}, {price} at {shop}.",
    },
    look_navel_plate = {
        "Riveted plate, leather straps and a cutout at the navel that goes lower than it needs to. {item}, {price} at {shop}.",
        "Proper plate with a hole cut in the belly. The smith called it ventilation. {item}, {price} at {shop}.",
        "{color} plate held together by straps, and the straps aren't trying hard. {shop} has {item} for {price}.",
    },
    look_batwing = {
        "Spiked plate like bat wings across the chest, and skin where the rest of the bat would be. {item}, {price} at {shop}.",
        "Spikes on the outside, not much on the inside. It's what a dreadlord's girlfriend wears. {item}, {price} at {shop}.",
        "Looks evil, covers little. People who like being scared of you will pay attention. ~ {shop} ~ {item}, {price}.",
    },
}

ns.ITEM_ADS = {
    -- Foreman Vest (cloth chest, level 6)
    [10553] = {
        "A brown bra top with a slit down it, wearable at level 6. Start early. ~ {shop} ~ {item}, {price}.",
        "First dungeon is still ten levels off and you're already the best-dressed one in Elwynn. {item}, {price} at {shop}.",
        pools = { "cloth", "chest", "lvl_low", "general" },
    },
    -- Ancestral Woollies (cloth legs, level 8)
    [3291] = {
        pools = { "look_bikini", "cloth", "legs", "lvl_low", "general" },
        color = "grey-green fur",
    },
    -- Ancestral Tunic (cloth chest, level 8)
    [3292] = {
        pools = { "look_fur_halter", "cloth", "chest", "lvl_low", "general" },
        color = "grey-green",
    },
    -- Simple Blouse (cloth chest, level 10)
    [9749] = {
        pools = { "look_one_shoulder", "cloth", "chest", "lvl_low", "general" },
        color = "dark red",
    },
    -- Barbaric Loincloth (cloth legs, level 11)
    [3309] = {
        pools = { "look_bikini", "cloth", "legs", "lvl_low", "general" },
        color = "dark fur",
    },
    -- Aboriginal Loincloth (cloth legs, level 12)
    [14119] = {
        pools = { "look_bikini", "cloth", "legs", "lvl_low", "general" },
        color = "red-brown fur",
    },
    -- Barbaric Cloth Vest (cloth chest, level 13)
    [3310] = {
        pools = { "look_fur_halter", "cloth", "chest", "lvl_low", "general" },
        color = "dark purple",
    },
    -- Barbaric Cloth Robe (cloth chest, level 13)
    [6531] = {
        pools = { "look_zigzag_robe", "cloth", "chest", "lvl_low", "general" },
        color = "pink and blue",
    },
    -- Willow Vest (cloth chest, level 14)
    [6536] = {
        pools = { "look_one_shoulder", "cloth", "chest", "lvl_low", "general" },
        color = "green",
    },
    -- Aboriginal Robe (cloth chest, level 15)
    [14120] = {
        pools = { "look_zigzag_robe", "cloth", "chest", "lvl_low", "general" },
        color = "coral",
    },
    -- Aboriginal Vest (cloth chest, level 15)
    [14121] = {
        pools = { "look_fur_halter", "cloth", "chest", "lvl_low", "general" },
        color = "rust red",
    },
    -- Buccaneer's Vest (cloth chest, level 18)
    [14175] = {
        "A white satin shirt, open and tied up so the belly's out. Pirate on her day off. {item}, {price} at {shop}.",
        "Booty Bay dress code: shirt optional, and this barely counts as one. {shop} has {item} for {price}.",
        pools = { "cloth", "chest", "lvl_low", "general" },
    },
    -- Ritual Shroud (cloth chest, level 19)
    [14127] = {
        "A red cloth triangle held on by chains, open at both sides. Your tabard covers more. {item}, {price} at {shop}.",
        "The chains do all the work. Trust them or don't, people will watch either way. {shop} has {item} for {price}.",
        pools = { "cloth", "chest", "lvl_low", "general" },
    },
    -- Robes of Insight (cloth chest, level 42)
    [940] = {
        "An epic robe cut open to the waist. The purple gets you inspected and so does everything under it. {item}, {price} at {shop}.",
        "Epic, and the neckline ends at the belt. The whole bank learns you're rich and what you look like. {item}, {price} at {shop}.",
        pools = { "cloth", "chest", "general" },
    },
    -- Hibernal Robe (cloth chest, level 46)
    [8113] = {
        pools = { "look_net_robe", "cloth", "chest", "general" },
        color = "bright green",
    },
    -- Chan's Imperial Robes (cloth chest, level 47)
    [17050] = {
        pools = { "look_net_robe", "cloth", "chest", "general" },
        color = "yellow",
    },
    -- Venomshroud Silk Robes (cloth chest, level 49)
    [14445] = {
        pools = { "look_net_robe", "cloth", "chest", "general" },
        color = "green",
    },
    -- Arachnidian Robes (cloth chest, level 52)
    [14297] = {
        pools = { "look_web_robe", "cloth", "chest", "general" },
        color = "teal",
    },
    -- Elegant Leggings (cloth legs, level 56)
    [10217] = {
        pools = { "look_hip_window", "cloth", "legs", "lvl_high", "general" },
        color = "gold satin",
    },
    -- Elegant Robes (cloth chest, level 57)
    [10215] = {
        "Gold shell cups set with turquoise, on a robe. Looks expensive because it is. {item}, {price} at {shop}.",
        "A robe with a jewelled gold bra built in. Casters, you've waited 57 levels for this. {item}, {price} at {shop}.",
        pools = { "cloth", "chest", "lvl_high", "general" },
    },
    -- Abyssal Cloth Pants (cloth legs, level 57)
    [20674] = {
        pools = { "look_hip_window", "cloth", "legs", "lvl_high", "general" },
        color = "black",
    },
    -- Burnt Leather Breeches (leather legs, level 5)
    [2962] = {
        pools = { "look_bikini", "leather", "legs", "lvl_low", "general" },
        color = "dark red leather",
    },
    -- Primal Wraps (leather chest, level 6)
    [15010] = {
        pools = { "look_strap_harness", "leather", "chest", "lvl_low", "general" },
        color = "olive",
    },
    -- Gnoll War Harness (leather chest, level 10)
    [1211] = {
        pools = { "look_strap_harness", "leather", "chest", "lvl_low", "general" },
        color = "olive",
    },
    -- Grizzly Jerkin (leather chest, level 11)
    [15304] = {
        pools = { "look_underbust", "leather", "chest", "lvl_low", "general" },
        color = "brown",
    },
    -- Ceremonial Leather Loincloth (leather legs, level 12)
    [3315] = {
        "Black fur, a gold chain for a belt and a garter on one thigh. {item}, {price} at {shop}.",
        "The gold chain sits low on the hips. Eyes follow the chain. {shop} has {item} for {price}.",
        pools = { "leather", "legs", "lvl_low", "general" },
    },
    -- Ceremonial Leather Harness (leather chest, level 13)
    [3313] = {
        pools = { "look_strap_harness", "leather", "chest", "lvl_low", "general" },
        color = "brown",
    },
    -- Bard's Trousers (leather legs, level 13)
    [6553] = {
        "Crimson hot pants. Bare thigh down to the knee, then boots. {shop} has {item} for {price}.",
        "Shorts this short have no business having stats. They have stats. ~ {shop} ~ {item}, {price}.",
        pools = { "leather", "legs", "lvl_low", "general" },
    },
    -- Bandit Pants (leather legs, level 17)
    [9781] = {
        pools = { "look_bikini", "leather", "legs", "lvl_low", "general" },
        color = "black leather",
    },
    -- Feral Harness (leather chest, level 17)
    [15311] = {
        pools = { "look_strap_harness", "leather", "chest", "lvl_low", "general" },
        color = "red",
    },
    -- Cutthroat's Vest (leather chest, level 29)
    [15130] = {
        pools = { "look_suspenders", "leather", "chest", "lvl_low", "general" },
        color = "golden brown",
    },
    -- Insignia Leggings (leather legs, level 30)
    [4054] = {
        pools = { "look_cod_leather", "leather", "legs", "lvl_low", "general" },
        color = "brown",
    },
    -- Spirewind Fetter (leather chest, level 30)
    [9406] = {
        pools = { "look_suspenders", "leather", "chest", "lvl_low", "general" },
        color = "olive",
    },
    -- Insignia Chestguard (leather chest, level 31)
    [4057] = {
        pools = { "look_stud_top", "leather", "chest", "lvl_low", "general" },
        color = "Brown",
    },
    -- Wolffear Harness (leather chest, level 31)
    [13110] = {
        pools = { "look_strap_harness", "leather", "chest", "lvl_low", "general" },
        color = "red",
    },
    -- Headhunter's Armor (leather chest, level 31)
    [15356] = {
        pools = { "look_suspenders", "leather", "chest", "lvl_low", "general" },
        color = "olive",
    },
    -- Sentinel Trousers (leather legs, level 34)
    [7440] = {
        pools = { "look_bikini", "leather", "legs", "lvl_low", "general" },
        color = "olive fur",
    },
    -- Quillward Harness (leather chest, level 34)
    [10583] = {
        pools = { "look_suspenders", "leather", "chest", "lvl_low", "general" },
        color = "golden brown",
    },
    -- Sentinel Breastplate (leather chest, level 35)
    [7439] = {
        pools = { "look_underbust", "leather", "chest", "lvl_low", "general" },
        color = "tan",
    },
    -- Huntsman's Armor (leather chest, level 38)
    [9887] = {
        pools = { "look_stud_top", "leather", "chest", "lvl_low", "general" },
        color = "Olive",
    },
    -- Warden's Woolies (leather legs, level 38)
    [14605] = {
        pools = { "look_bikini", "leather", "legs", "lvl_low", "general" },
        color = "olive fur",
    },
    -- Warden's Wraps (leather chest, level 39)
    [14601] = {
        pools = { "look_underbust", "leather", "chest", "lvl_low", "general" },
        color = "tan",
    },
    -- Tracker's Leggings (leather legs, level 41)
    [9922] = {
        "Green leggings with ring cutouts down the side, strapped shut where it matters. {shop} has {item} for {price}.",
        "Skin shows through the rings all the way down the leg. People count them. ~ {shop} ~ {item}, {price}.",
        pools = { "leather", "legs", "general" },
    },
    -- Scorpashi Leggings (leather legs, level 42)
    [14659] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "gold",
    },
    -- Cabalist Leggings (leather legs, level 43)
    [7528] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "red",
    },
    -- Scorpashi Breastplate (leather chest, level 44)
    [14655] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "gold",
    },
    -- Rageclaw Leggings (leather legs, level 44)
    [15385] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "red",
    },
    -- Cabalist Chestpiece (leather chest, level 45)
    [7527] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "red",
    },
    -- Chieftain's Leggings (leather legs, level 46)
    [9954] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "gold",
    },
    -- Rageclaw Chestguard (leather chest, level 46)
    [15381] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "red",
    },
    -- Keeper's Woolies (leather legs, level 47)
    [14668] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "green",
    },
    -- Chieftain's Breastplate (leather chest, level 48)
    [9950] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "gold",
    },
    -- Keeper's Armor (leather chest, level 49)
    [14664] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "green",
    },
    -- Jadefire Pants (leather legs, level 49)
    [15394] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "green",
    },
    -- Praetorian Leggings (leather legs, level 50)
    [15186] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "red",
    },
    -- Jadefire Chestguard (leather chest, level 51)
    [15390] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "green",
    },
    -- Praetorian Padded Armor (leather chest, level 52)
    [15179] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "red",
    },
    -- Pridelord Pants (leather legs, level 53)
    [14677] = {
        pools = { "look_loincloth", "leather", "legs", "general" },
        color = "gold",
    },
    -- Pridelord Armor (leather chest, level 54)
    [14670] = {
        pools = { "look_black_harness", "leather", "chest", "general" },
        color = "gold",
    },
    -- Peerless Leggings (leather legs, level 54)
    [15431] = {
        pools = { "look_bikini", "leather", "legs", "general" },
        color = "green fur",
    },
    -- Peerless Armor (leather chest, level 56)
    [15433] = {
        pools = { "look_underbust", "leather", "chest", "lvl_high", "general" },
        color = "tan",
    },
    -- Abyssal Leather Leggings (leather legs, level 57)
    [20665] = {
        pools = { "look_cod_leather", "leather", "legs", "lvl_high", "general" },
        color = "black",
    },
    -- Nightshade Tunic (leather chest, level 58)
    [10220] = {
        "A black studded corset laced open down the front. The collar ring is for what you think it is. {item}, {price} at {shop}.",
        "Black leather, laced, with a collar ring. The warlock's succubus keeps trying to trade you for it. {item}, {price} at {shop}.",
        pools = { "leather", "chest", "lvl_high", "general" },
    },
    -- Warrior's Tunic (mail chest, level 6)
    [2965] = {
        pools = { "look_chain_bra", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "purple",
    },
    -- Dargol's Hauberk (mail chest, level 8)
    [3330] = {
        pools = { "look_fringe_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "tan",
    },
    -- Infantry Tunic (mail chest, level 8)
    [6336] = {
        pools = { "look_chain_bra", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "silver",
    },
    -- Slarkskin (mail chest, level 10)
    [6180] = {
        pools = { "look_scale_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "white",
    },
    -- Wax-polished Armor (mail chest, level 10)
    [6195] = {
        pools = { "look_padded_scoop", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "blue",
    },
    -- Cadet Vest (mail chest, level 10)
    [9765] = {
        pools = { "look_scale_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "pale green",
    },
    -- Veteran Armor (mail chest, level 11)
    [2977] = {
        pools = { "look_padded_scoop", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "brown",
    },
    -- Soldier's Armor (mail chest, level 13)
    [6545] = {
        pools = { "look_padded_scoop", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "green",
    },
    -- Bloodspattered Loincloth (mail legs, level 13)
    [15493] = {
        pools = { "look_loincloth_mail", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "silver",
    },
    -- War Paint Legguards (mail legs, level 14)
    [14727] = {
        pools = { "look_loincloth_mail", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "green",
    },
    -- Raider's Chestpiece (mail chest, level 15)
    [9783] = {
        pools = { "look_fringe_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "tan",
    },
    -- Burnished Tunic (mail chest, level 16)
    [2989] = {
        pools = { "look_scale_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "gold",
    },
    -- Bloodspattered Surcoat (mail chest, level 16)
    [15488] = {
        pools = { "look_black_harness", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "silver",
    },
    -- Outrunner's Legguards (mail legs, level 17)
    [15503] = {
        pools = { "look_loincloth_mail", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "purple",
    },
    -- Defender Tunic (mail chest, level 18)
    [6580] = {
        pools = { "look_scale_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "silver-teal",
    },
    -- War Paint Chestpiece (mail chest, level 18)
    [14730] = {
        pools = { "look_black_harness", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "red and green",
    },
    -- Outrunner's Chestguard (mail chest, level 19)
    [15500] = {
        pools = { "look_black_harness", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "teal",
    },
    -- Grunt's Legguards (mail legs, level 19)
    [15511] = {
        pools = { "look_loincloth_mail", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "gold",
    },
    -- Fortified Chain (mail chest, level 20)
    [9818] = {
        pools = { "look_fringe_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "tan",
    },
    -- Dusty Chain Armor (mail chest, level 21)
    [2016] = {
        pools = { "look_padded_scoop", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "brown",
    },
    -- Martyr's Chain (mail chest, level 21)
    [3416] = {
        pools = { "look_fringe_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "orange",
    },
    -- Grunt's Chestpiece (mail chest, level 21)
    [15514] = {
        pools = { "look_black_harness", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "gold",
    },
    -- Lambent Scale Breastplate (mail chest, level 22)
    [3049] = {
        pools = { "look_scale_bikini", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "gold",
    },
    -- Spiked Chain Leggings (mail legs, level 22)
    [15521] = {
        pools = { "look_loincloth_mail", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "silver-blue",
    },
    -- Humbert's Chestpiece (mail chest, level 23)
    [3053] = {
        pools = { "look_chain_bra", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "silver",
    },
    -- Battleforge Legguards (mail legs, level 23)
    [6596] = {
        pools = { "look_dragon_legs", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "black and gold",
    },
    -- Battleforge Armor (mail chest, level 24)
    [6592] = {
        pools = { "look_dragon_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "red-orange",
    },
    -- Sentry's Leggings (mail legs, level 24)
    [15529] = {
        pools = { "look_garter", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "grey",
    },
    -- Large Ogre Chain Armor (mail chest, level 25)
    [914] = {
        pools = { "look_padded_scoop", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "brown",
    },
    -- Double Link Tunic (mail chest, level 25)
    [1717] = {
        pools = { "look_fringe_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "grey",
    },
    -- Glimmering Mail Legguards (mail legs, level 25)
    [6386] = {
        pools = { "look_dragon_legs", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "red and gold",
    },
    -- Spiked Chain Breastplate (mail chest, level 25)
    [15518] = {
        pools = { "look_black_harness", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "silver",
    },
    -- Avenger's Armor (mail chest, level 26)
    [1488] = {
        pools = { "look_fringe_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "grey",
    },
    -- Glimmering Mail Breastplate (mail chest, level 26)
    [4071] = {
        pools = { "look_dragon_top", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "gold",
    },
    -- Sentry's Surcoat (mail chest, level 26)
    [15524] = {
        pools = { "look_chain_cups", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "grey",
    },
    -- Mail Combat Armor (mail chest, level 31)
    [4074] = {
        pools = { "look_scale_bikini", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "silver",
    },
    -- Mail Combat Leggings (mail legs, level 31)
    [6402] = {
        pools = { "look_scale_bikini_legs", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "Silver",
    },
    -- Knight's Breastplate (mail chest, level 34)
    [7454] = {
        "Pale steel cups on buckled straps. The buckles are right there in front. ~ {shop} ~ {item}, {price}.",
        "Two cups, four buckles. It comes off faster than any armor should. {item}, {price} at {shop}.",
        pools = { "mail", "chest", "mail_low", "lvl_low", "general" },
    },
    -- Firemane Leggings (mail legs, level 34)
    [13129] = {
        "Glossy red lacquered hip plates. Red, shiny and very little of it. {shop} has {item} for {price}.",
        "You can see them shine from across the auction house, and then you see everything else. {item}, {price} at {shop}.",
        pools = { "mail", "legs", "mail_low", "lvl_low", "general" },
    },
    -- Enduring Breastplate (mail chest, level 34)
    [14760] = {
        "A banded steel corset with a keyhole cut over the cleavage. People look through keyholes. {item}, {price} at {shop}.",
        "Blue steel, laced so tight your breath bar starts ticking on dry land. {shop} has {item} for {price}.",
        pools = { "mail", "chest", "mail_low", "lvl_low", "general" },
    },
    -- Marauder's Tunic (mail chest, level 35)
    [15567] = {
        "Red and grey plates linked by rings, with a gap between every plate. {item}, {price} at {shop}.",
        "Rings hold the plates together and nothing fills the gaps. {shop} has {item} for {price}.",
        pools = { "mail", "chest", "mail_low", "lvl_low", "general" },
    },
    -- Chief Brigadier Armor (mail chest, level 36)
    [6411] = {
        "Black cups with red flames on them. The tooltip says mail. Everyone else says lingerie. {item}, {price} at {shop}.",
        "Black lingerie with an armor value. Wear it to the raid and see who can still do a rotation. {item}, {price} at {shop}.",
        pools = { "mail", "chest", "mail_low", "lvl_low", "general" },
    },
    -- Sparkleshell Breastplate (mail chest, level 36)
    [15578] = {
        pools = { "look_shell", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "gold",
    },
    -- Steadfast Legplates (mail legs, level 36)
    [15596] = {
        pools = { "look_garter", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "purple",
    },
    -- Jazeraint Chestguard (mail chest, level 37)
    [9897] = {
        pools = { "look_band_cup", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "silver",
    },
    -- Captain's Leggings (mail legs, level 38)
    [7487] = {
        pools = { "look_scale_bikini_legs", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "Gold",
    },
    -- Ravager's Woolies (mail legs, level 38)
    [14775] = {
        pools = { "look_tiles", "mail", "legs", "mail_low", "lvl_low", "general" },
        color = "brown",
    },
    -- Steadfast Breastplate (mail chest, level 38)
    [15591] = {
        pools = { "look_chain_cups", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "purple",
    },
    -- Captain's Breastplate (mail chest, level 39)
    [7486] = {
        pools = { "look_scale_bikini", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "gold",
    },
    -- Ravager's Armor (mail chest, level 39)
    [14768] = {
        pools = { "look_tiles", "mail", "chest", "mail_low", "lvl_low", "general" },
        color = "brown",
    },
    -- Brigade Breastplate (mail chest, level 40)
    [9928] = {
        pools = { "look_single_cup", "mail", "chest", "mail_high", "general" },
        color = "Dark red",
    },
    -- Ancient Chestpiece (mail chest, level 41)
    [15601] = {
        pools = { "look_shell", "mail", "chest", "mail_high", "general" },
        color = "jade",
    },
    -- Bonelink Armor (mail chest, level 42)
    [15609] = {
        pools = { "look_ribs", "mail", "chest", "mail_high", "general" },
        color = "white",
    },
    -- Warmonger's Chestpiece (mail chest, level 45)
    [9957] = {
        "Slatted red, black and gold lacquer with most of the slats left off. {item}, {price} at {shop}.",
        "Red and gold slats with skin showing between them when you move. Move a lot. {shop} has {item} for {price}.",
        pools = { "mail", "chest", "mail_high", "general" },
    },
    -- Myrmidon's Breastplate (mail chest, level 46)
    [8126] = {
        pools = { "look_band_cup", "mail", "chest", "mail_high", "general" },
        color = "white",
    },
    -- Lord's Legguards (mail legs, level 47)
    [10084] = {
        pools = { "look_plate_thong", "mail", "legs", "mail_high", "general" },
        color = "steel and gold",
    },
    -- Lord's Breastplate (mail chest, level 48)
    [10077] = {
        pools = { "look_single_cup", "mail", "chest", "mail_high", "general" },
        color = "Gold",
    },
    -- Protector Legguards (mail legs, level 48)
    [14796] = {
        "Green-bronze plates in a grid over the hips, and legs from there down. {item}, {price} at {shop}.",
        pools = { "mail", "legs", "mail_high", "general" },
    },
    -- Protector Breastplate (mail chest, level 49)
    [14789] = {
        "Green-bronze plates in a grid, cut low at the front and short at the waist. ~ {shop} ~ {item}, {price}.",
        pools = { "mail", "chest", "mail_high", "general" },
    },
    -- Crusader's Armor (mail chest, level 50)
    [10193] = {
        pools = { "look_band_cup", "mail", "chest", "mail_high", "general" },
        color = "blue",
    },
    -- Ebonhold Armor (mail chest, level 51)
    [8265] = {
        pools = { "look_band_cup", "mail", "chest", "mail_high", "general" },
        color = "black",
    },
    -- Merciless Legguards (mail legs, level 51)
    [15655] = {
        pools = { "look_chastity", "mail", "legs", "mail_high", "general" },
        color = "bronze",
    },
    -- Ornate Breastplate (mail chest, level 53)
    [10118] = {
        pools = { "look_plate_bikini", "mail", "chest", "mail_high", "general" },
        color = "steel-blue",
    },
    -- Engraved Breastplate (mail chest, level 55)
    [10230] = {
        pools = { "look_plate_bikini", "mail", "chest", "mail_high", "lvl_high", "general" },
        color = "bronze",
    },
    -- Impenetrable Legguards (mail legs, level 55)
    [15665] = {
        "They say nothing gets through it. Guildies will ask to test that. ~ {shop} ~ {item}, {price}.",
        pools = { "look_chastity", "mail", "legs", "mail_high", "lvl_high", "general" },
        color = "steel",
    },
    -- Hero's Leggings (mail legs, level 56)
    [8309] = {
        pools = { "look_plate_thong", "mail", "legs", "mail_high", "lvl_high", "general" },
        color = "navy and red",
    },
    -- Bonebrace Hauberk (mail chest, level 56)
    [14536] = {
        pools = { "look_band_cup", "mail", "chest", "mail_high", "lvl_high", "general" },
        color = "silver",
    },
    -- Hero's Breastplate (mail chest, level 57)
    [8303] = {
        pools = { "look_single_cup", "mail", "chest", "mail_high", "lvl_high", "general" },
        color = "Navy and red",
    },
    -- Magnificent Breastplate (mail chest, level 57)
    [15669] = {
        pools = { "look_ribs", "mail", "chest", "mail_high", "lvl_high", "general" },
        color = "red and gold",
    },
    -- Mercurial Breastplate (mail chest, level 59)
    [10157] = {
        pools = { "look_band_cup", "mail", "chest", "mail_high", "lvl_high", "general" },
        color = "white",
    },
    -- Masterwork Breastplate (mail chest, level 60)
    [10266] = {
        pools = { "look_plate_bikini", "mail", "chest", "mail_high", "lvl_high", "general" },
        color = "gold",
    },
    -- Triumphant Chestpiece (mail chest, level 60)
    [15680] = {
        pools = { "look_ribs", "mail", "chest", "mail_high", "lvl_high", "general" },
        color = "red and gold",
    },
    -- Jouster's Chestplate (plate chest, level 40)
    [8157] = {
        pools = { "look_barred_window", "plate", "chest", "general" },
        color = "blue steel",
    },
    -- Field Plate Armor (plate chest, level 40)
    [9286] = {
        pools = { "look_barred_window", "plate", "chest", "general" },
        color = "silver",
    },
    -- Embossed Plate Armor (plate chest, level 40)
    [9966] = {
        pools = { "look_barred_window", "plate", "chest", "general" },
        color = "copper",
    },
    -- Saltstone Surcoat (plate chest, level 40)
    [14895] = {
        pools = { "look_collar_strip", "plate", "chest", "general" },
        color = "grey-green",
    },
    -- Saltstone Legplates (plate legs, level 40)
    [14900] = {
        pools = { "look_high_cut", "plate", "legs", "general" },
        color = "Dark grey",
    },
    -- Chromite Chestplate (plate chest, level 42)
    [8138] = {
        pools = { "look_barred_window", "plate", "chest", "general" },
        color = "purple",
    },
    -- Tyrant's Legplates (plate legs, level 42)
    [14840] = {
        "Hit your 40s and the gentlemen don't stare like they used to? ~ {shop} ~ NOW OPEN for all your mogging needs! {item} only {price}.",
        "Some of your guild want to be ordered around by a woman in plate and boots. Be her. {item}, {price} at {shop}.",
        "Wear it, point at the floor and see who kneels. {shop} has {item} for {price}.",
        "Looks like you give the orders and they say thank you afterwards. ~ {shop} ~ {item}, {price}.",
        "For players who like their /kneel emotes answered. {item}, {price} at {shop}.",
        pools = { "look_high_cut", "plate", "legs", "general" },
        color = "Bronze",
    },
    -- Tyrant's Chestpiece (plate chest, level 43)
    [14835] = {
        "Spiked collar, red trim, bare sides. Dress like the one who decides when they may stand up. {item}, {price} at {shop}.",
        "Some of your guild want to be ordered around by a woman in plate and boots. Be her. {item}, {price} at {shop}.",
        "The raid leader gives orders in voice chat. You'll give them without saying a word. {item}, {price} at {shop}.",
        pools = { "look_collar_strip", "plate", "chest", "general" },
        color = "olive and red",
    },
    -- Gothic Plate Armor (plate chest, level 44)
    [10086] = {
        pools = { "look_navel_plate", "plate", "chest", "general" },
        color = "Orange",
    },
    -- Brutish Breastplate (plate chest, level 45)
    [14904] = {
        pools = { "look_batwing", "plate", "chest", "general" },
        color = "dark brown",
    },
    -- Valorous Chestguard (plate chest, level 46)
    [8274] = {
        pools = { "look_navel_plate", "plate", "chest", "general" },
        color = "Gold",
    },
    -- Jade Legplates (plate legs, level 46)
    [14920] = {
        pools = { "look_high_cut", "plate", "legs", "general" },
        color = "Jade",
    },
    -- Jade Breastplate (plate chest, level 48)
    [14915] = {
        pools = { "look_collar_strip", "plate", "chest", "general" },
        color = "jade",
    },
    -- Revenant Chestplate (plate chest, level 49)
    [10128] = {
        pools = { "look_plate_bikini", "plate", "chest", "general" },
        color = "dark purple",
    },
    -- Hydralick Armor (plate chest, level 49)
    [13067] = {
        pools = { "look_single_cup", "plate", "chest", "general" },
        color = "Navy",
    },
    -- Heavy Lamellar Chestpiece (plate chest, level 50)
    [10240] = {
        pools = { "look_navel_plate", "plate", "chest", "general" },
        color = "Olive",
    },
    -- Lofty Legguards (plate legs, level 50)
    [14928] = {
        pools = { "look_plate_thong", "plate", "legs", "general" },
        color = "blue and gold",
    },
    -- Alabaster Breastplate (plate chest, level 52)
    [8312] = {
        pools = { "look_navel_plate", "plate", "chest", "general" },
        color = "White",
    },
    -- Vanguard Legplates (plate legs, level 52)
    [14859] = {
        pools = { "look_plate_thong", "plate", "legs", "general" },
        color = "blue and gold",
    },
    -- Lofty Breastplate (plate chest, level 52)
    [14924] = {
        pools = { "look_plate_bikini", "plate", "chest", "general" },
        color = "blue",
    },
    -- Templar Chestplate (plate chest, level 53)
    [10164] = {
        pools = { "look_plate_bikini", "plate", "chest", "general" },
        color = "gold and blue",
    },
    -- Glorious Legplates (plate legs, level 53)
    [14970] = {
        pools = { "look_plate_thong", "plate", "legs", "general" },
        color = "gold",
    },
    -- Vanguard Breastplate (plate chest, level 54)
    [14854] = {
        pools = { "look_plate_bikini", "plate", "chest", "general" },
        color = "blue",
    },
    -- Emerald Breastplate (plate chest, level 55)
    [10275] = {
        pools = { "look_plate_bikini", "plate", "chest", "lvl_high", "general" },
        color = "dark green",
    },
    -- Glorious Breastplate (plate chest, level 56)
    [14966] = {
        pools = { "look_plate_bikini", "plate", "chest", "lvl_high", "general" },
        color = "gold",
    },
    -- Imbued Plate Armor (plate chest, level 57)
    [10368] = {
        pools = { "look_plate_bikini", "plate", "chest", "lvl_high", "general" },
        color = "silver",
    },
    -- Cloudkeeper Legplates (plate legs, level 57)
    [14554] = {
        pools = { "look_plate_thong", "plate", "legs", "lvl_high", "general" },
        color = "silver-blue",
    },
    -- Commander's Armor (plate chest, level 58)
    [10378] = {
        pools = { "look_plate_bikini", "plate", "chest", "lvl_high", "general" },
        color = "rose bronze",
    },
    -- Warleader's Breastplate (plate chest, level 58)
    [14862] = {
        pools = { "look_batwing", "plate", "chest", "lvl_high", "general" },
        color = "dark teal",
    },
    -- Hyperion Armor (plate chest, level 60)
    [10384] = {
        pools = { "look_plate_bikini", "plate", "chest", "lvl_high", "general" },
        color = "gold",
    },
    -- Exalted Harness (plate chest, level 60)
    [14975] = {
        pools = { "look_batwing", "plate", "chest", "lvl_high", "general" },
        color = "black and gold",
    },
}
