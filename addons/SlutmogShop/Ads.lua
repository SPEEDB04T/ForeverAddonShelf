-- Slutmog Shop: the ready-made ads. Generated; edit the generator, not this file.
-- ns.AD_POOLS: ads shared by pieces with the same look, armor type, slot or level range.
-- ns.ITEM_ADS[id]: the piece's own ads, then pools = the pools it draws on, color = its colour words.
-- {item}, {price} and {shop} are filled in when the ad goes out, {level} too; {color} when the list is built.
local _, ns = ...

ns.AD_POOLS = {
    general = {
        "Warlock's succubus keeps drawing all your group's attention? Take it back. {item}, {price} at {shop}.",
        "Tired of being respected for your personality? {shop} has {item} for {price}.",
        "Refunds if nobody looks. We have never paid one. ~ {shop} ~ {item}, {price}.",
        "For the woman who has everything and would like people to see it. {item}, {price} at {shop}.",
        "Keep getting ganked, never getting camped? Give them a reason to stay. {shop} has {item} for {price}.",
        "Are people still making eye contact with you? We can fix that. ~ {shop} ~ {item}, {price}.",
        "Barely worn. That's how it's worn. {item}, {price} at {shop}.",
        "You're not paying for the material. Obviously. {shop} has {item} for {price}.",
        "He says he likes you for your mind. Test that. ~ {shop} ~ {item}, {price}.",
        "Ask your healer if {item} is right for you. {price} at {shop}.",
        "Selling for a friend. The friend is me. {shop} has {item} for {price}.",
        "Side effects include whispers, gifts and one very awkward guild meeting. ~ {shop} ~ {item}, {price}.",
        "Not what you'd wear to meet his mother. What you'd wear to meet his father. {item}, {price} at {shop}.",
        "You've tried a personality. Try this. {shop} has {item} for {price}.",
        "Priced by the inch. Very affordable. ~ {shop} ~ {item}, {price}.",
        "Previous owner got two proposals and a guild kick. Like new. {item}, {price} at {shop}.",
        "The guards asked us to take it out of the window. {shop} has {item} for {price}.",
        "Dress for the job you want. We don't ask what job. ~ {shop} ~ {item}, {price}.",
        "Why be the hero when you can be the reason he's late to the raid? {item}, {price} at {shop}.",
        "It won't save your life. It'll make it more interesting. {shop} has {item} for {price}.",
        "Nine out of ten paladins recommend looking away. None of them did. ~ {shop} ~ {item}, {price}.",
        "We both know there's a guy behind that night elf. You'll look anyway. {item}, {price} at {shop}.",
        "Tested on our staff. Productivity has not recovered. {shop} has {item} for {price}.",
        "Nobody ever wrote a song about sensible armor. ~ {shop} ~ {item}, {price}.",
        "No lowballers. I know what I have, and so will everyone else. {item}, {price} at {shop}.",
        "Perfect for weddings. Not yours. {shop} has {item} for {price}.",
        "His wife thinks he logs on for the raid. ~ {shop} ~ {item}, {price}.",
        "Covers the essentials. We decided what was essential. {item}, {price} at {shop}.",
        "Our seamstress went home early that day. {shop} has {item} for {price}.",
        "Not allowed in the Cathedral. We asked. ~ {shop} ~ {item}, {price}.",
        "Two officers will gquit over you by Friday. {item}, {price} at {shop}.",
        "Has it been a while since anyone walked into a wall on your account? {shop} has {item} for {price}.",
        "Suitable for every occasion you wouldn't tell your mother about. ~ {shop} ~ {item}, {price}.",
        "The man who made it blushed. He's a dwarf who's been through two wars. {item}, {price} at {shop}.",
        "Modesty is a virtue. We don't stock it. {shop} has {item} for {price}.",
        "Why learn the fights? In {item} you get carried. {price} at {shop}.",
        "Satisfaction guaranteed. Yours, theirs, we're not fussy. {item}, {price} at {shop}.",
    },
    plate = {
        "Hit 40 and finally allowed to wear plate? Congratulations. Here's hardly any. {shop} has {item} for {price}.",
        "It will stop a sword, provided the sword is aimed at one of four places. ~ {shop} ~ {item}, {price}.",
        "Heavy armor for people who'd rather not be heavily armored. {item}, {price} at {shop}.",
        "The smith says it's structurally sound. He said it without looking up. {shop} has {item} for {price}.",
    },
    mail = {
        "Every link forged by hand. There are about forty. ~ {shop} ~ {item}, {price}.",
        "Chainmail. Cold in the morning, memorable by the afternoon. {item}, {price} at {shop}.",
        "Yes, it has an armor value. No, that's not why anyone buys it. {shop} has {item} for {price}.",
    },
    mail_low = {
        "Can't afford plate yet? Make that everyone else's problem. {item}, {price} at {shop}.",
        "Starter armor, if what you're starting is rumours. {shop} has {item} for {price}.",
    },
    mail_high = {
        "Hunters: your pet is about to be the second most watched thing in the party. {shop} has {item} for {price}.",
        "Shamans: finally something the elements can get at. ~ {shop} ~ {item}, {price}.",
    },
    leather = {
        "Leather. Tight, creaks, wipes clean. ~ {shop} ~ {item}, {price}.",
        "Smells like a new saddle. Rides about the same. {item}, {price} at {shop}.",
        "Our tanner asks that you not tell his wife what he's been making. {shop} has {item} for {price}.",
        "Rogues: if you're going to be seen at all, be seen like this. ~ {shop} ~ {item}, {price}.",
    },
    cloth = {
        "It's cloth. It comes off with one hand. {item}, {price} at {shop}.",
        "Technically a robe, the way a napkin is technically a tablecloth. {shop} has {item} for {price}.",
        "The seamstress used the offcuts. This is the offcuts. ~ {shop} ~ {item}, {price}.",
        "One strong breeze from disaster. Check the weather, or don't. {item}, {price} at {shop}.",
    },
    legs = {
        "The back view sells it. The front view closes the deal. {shop} has {item} for {price}.",
        "You'll never sit on a cold bench the same way again. ~ {shop} ~ {item}, {price}.",
        "Not recommended for riding. Highly recommended for being watched riding. {item}, {price} at {shop}.",
        "Bend at the knees. Or don't, we're a shop, not your mother. {shop} has {item} for {price}.",
        "At 40 everyone gets a mount. In {item} you might be one. {price} at {shop}.",
    },
    chest = {
        "Offers no support, morally or otherwise. ~ {shop} ~ {item}, {price}.",
        "Two reasons to look. Neither is the stats. {item}, {price} at {shop}.",
        "'Eyes up here,' you'll say. You won't mean it. {shop} has {item} for {price}.",
        "Raid leader inspects your gear before every boss. Let him take his time. ~ {shop} ~ {item}, {price}.",
    },
    lvl_low = {
        "Requires level {level}. Requires nerve at any level. {item}, {price} at {shop}.",
        "Level {level} req. Your bank alt is about to be the most popular toon at the mailbox. {item}, {price} at {shop}.",
    },
    lvl_high = {
        "Level 60. You've saved the world. You've earned an outfit your mother would hate. {shop} has {item} for {price}.",
        "Raid gear says you show up on Tuesdays. This says what you do the other six nights. {item}, {price} at {shop}.",
        "You spent sixty levels getting stronger. Spend {price} getting noticed. {item} at {shop}.",
    },
    look_bikini = {
        "Your character's underwear covers more than this. We checked. ~ {shop} ~ {item}, {price}.",
        "A strip of {color} round the hips. That's the whole item. {item}, {price} at {shop}.",
        "The tooltip says legs. It covers the hips and stops there. {shop} has {item} for {price}.",
        "One /dance on the mailbox and the whole realm is a witness. ~ {shop} ~ {item}, {price}.",
        "Sold by weight it would be free. {item}, {price} at {shop}.",
    },
    look_fur_halter = {
        "A {color} fur top, open all the way down the front. No buttons, we looked. {item}, {price} at {shop}.",
        "A fur vest that only closes if you hold it shut. You won't. {shop} has {item} for {price}.",
        "Fur vest, no buttons. Mount up carefully, or don't. ~ {shop} ~ {item}, {price}.",
    },
    look_one_shoulder = {
        "A {color} wrap over one shoulder. The other shoulder is out, and so is that side. {shop} has {item} for {price}.",
        "One shoulder covered, one bare, and an armband for decoration. ~ {shop} ~ {item}, {price}.",
        "Built to slip off one shoulder. Nobody built it to stop there. {item}, {price} at {shop}.",
    },
    look_zigzag_robe = {
        "A robe with a neckline that stops at the navel. Casters get to have fun too. ~ {shop} ~ {item}, {price}.",
        "Technically a robe. The V down the front goes deeper than your talent tree. {item}, {price} at {shop}.",
        "Bend over to loot in this and the whole party stops pulling. {shop} has {item} for {price}.",
    },
    look_net_robe = {
        "A {color} robe with see-through net sleeves and silver leaves over exactly two places. {item}, {price} at {shop}.",
        "Floor-length, so it sounds decent. Then you notice the sleeves are see-through netting. {item}, {price} at {shop}.",
        "For casters who want to be watched for the whole cast bar. ~ {shop} ~ {item}, {price}.",
    },
    look_web_robe = {
        "The sleeves are spider web. See-through, sticky-looking, and you're the one doing the catching. {item}, {price} at {shop}.",
        "A teal robe with web for sleeves and silver leaves over exactly two places. ~ {shop} ~ {item}, {price}.",
        "Web sleeves. Half of trade chat is about to get stuck on you. {item}, {price} at {shop}.",
    },
    look_hip_window = {
        "Long trousers with both hips cut out. Ankles covered, hips bare. ~ {shop} ~ {item}, {price}.",
        "Covers the ankles, which nobody asked for, and bares the hips, which they did. {item}, {price} at {shop}.",
        "For people who were told to put some pants on and found a loophole. {shop} has {item} for {price}.",
    },
    look_strap_harness = {
        "Two {color} leather straps and a belt. The tooltip calls that a chest piece. {item}, {price} at {shop}.",
        "We're not sure which way up it goes. Nobody has complained either way. {shop} has {item} for {price}.",
        "Straps crossed over the chest and nothing at all between them. ~ {shop} ~ {item}, {price}.",
        "We'd describe it, but there isn't much to describe. {item}, {price} at {shop}.",
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
        "It lifts and doesn't cover. No complaints from the guild so far. ~ {shop} ~ {item}, {price}.",
        "All the leather sits underneath. What sits on top of it is yours. {item}, {price} at {shop}.",
    },
    look_loincloth = {
        "A {color} flap front and back on a studded belt, open at the sides. Careful on the gryphon. {item}, {price} at {shop}.",
        "Covers you from the front and from behind. From the side, not so much. {item}, {price} at {shop}.",
        "It's a loincloth. Don't /sit facing the group. Or do. {shop} has {item} for {price}.",
        "A studded belt, a strip of cloth and a lot of thigh. ~ {shop} ~ {item}, {price}.",
    },
    look_loincloth_mail = {
        "{color} scale flaps front and back, open sides. One gust on the gryphon and it's a show. {item}, {price} at {shop}.",
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
        "Tight scales on top, bare stomach under them. Dressed better than the 60s in full tier. {item}, {price} at {shop}.",
        "Scales where they have to be and stomach everywhere else. {item}, {price} at {shop}.",
    },
    look_padded_scoop = {
        "Looks like normal padded armor until you see how low the front scoops. ~ {shop} ~ {item}, {price}.",
        "Healers will stand a lot closer than they need to. {item}, {price} at {shop}.",
        "From behind it passes for Stormwind guard issue. Then you turn round. {shop} has {item} for {price}.",
    },
    look_dragon_top = {
        "A {color} scale sash over one shoulder and the rest left out in the open. {item}, {price} at {shop}.",
        "One shoulder gets dragon scale. The other side gets fresh air. {shop} has {item} for {price}.",
    },
    look_dragon_legs = {
        "Tight {color} scale leggings. Nothing left to guess, plenty to look at. {shop} has {item} for {price}.",
        "Walk away from the auction house in these and count the whispers. ~ {shop} ~ {item}, {price}.",
    },
    look_garter = {
        "A steel hip plate, some chain tassels and one garter buckled round the thigh. Just the one. {item}, {price} at {shop}.",
        "There's a garter on it. On mail leggings. Somebody at the forge knew what they were doing. {item}, {price} at {shop}.",
        "One garter. The other leg is open to suggestions. {shop} has {item} for {price}.",
    },
    look_chain_cups = {
        "Two {color} steel cups hanging from chains. If the chains hold, it's a chest piece. {item}, {price} at {shop}.",
        "Steel cups on chains. Don't wear it to Winterspring. Wear it everywhere else. {shop} has {item} for {price}.",
        "Hangs off two chains. Don't sneeze in front of the guild. ~ {shop} ~ {item}, {price}.",
    },
    look_scale_bikini = {
        "A {color} scale bikini top on leather straps. Yes it's mail. Yes it has armor. No, not much. {item}, {price} at {shop}.",
        "Bikini armor, the real thing, the reason half of us rolled a female character. ~ {shop} ~ {item}, {price}.",
        "Two patches of scale and some straps. The armor value is a rumour. {item}, {price} at {shop}.",
    },
    look_scale_bikini_legs = {
        "{color} scale bikini bottoms, in mail. Wear with boots and no shame. ~ {shop} ~ {item}, {price}.",
        "Bikini armor, the real thing, the reason half of us rolled a female character. {item}, {price} at {shop}.",
        "Mail bottoms. The repair bill is about the only thing covered. {shop} has {item} for {price}.",
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
        "We ran out of metal halfway. Customers have been very understanding. {item}, {price} at {shop}.",
        "{color}, lopsided on purpose, and the bare side is the one they'll stand on. {shop} has {item} for {price}.",
    },
    look_chastity = {
        "Steel bottoms with a lock on the front. Key sold separately, for a lot more. {item}, {price} at {shop}.",
        "Looks like someone locked you into it for a reason. Guildies will ask what you did. {item}, {price} at {shop}.",
        "A locked steel belt and bare legs under it. Tell them who holds the key or let them guess. {item}, {price} at {shop}.",
        "There's a lock on the front. Every rogue in Ironforge will offer to level lockpicking on it. {item}, {price} at {shop}.",
    },
    look_plate_bikini = {
        "Bikini armor, the real thing, the reason half of us rolled a female character. {shop} has {item} for {price}.",
        "Two {color} cups and some cord. That's the breastplate. ~ {shop} ~ {item}, {price}.",
        "The smith charged full price for a third of the metal. So do we, and you'll still pay. {item}, {price} at {shop}.",
        "Fancy trim on the cups so they know it cost gold, bare belly so they forget to ask how much. {item}, {price} at {shop}.",
        "The most expensive way to wear almost nothing. ~ {shop} ~ {item}, {price}.",
    },
    look_barred_window = {
        "Full plate, barred window over the cleavage. Visiting hours are whenever. ~ {shop} ~ {item}, {price}.",
        "Solid {color} plate except for one window with bars across it, right where you'd guess. {item}, {price} at {shop}.",
        "From the back of the raid it looks like proper armor. Then you turn around. {shop} has {item} for {price}.",
    },
    look_high_cut = {
        "Hip plates cut so high on the thigh that the leg just keeps going. {item}, {price} at {shop}.",
        "{color} plate over the hips, slits up both sides, bare thigh from there to the boot. {item}, {price} at {shop}.",
        "Legplates that stop right where the fun starts. ~ {shop} ~ {item}, {price}.",
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
        "A brown bra top with a slit down it. Level 6 req, so your bank alt can wear it. ~ {shop} ~ {item}, {price}.",
        "Your bank alt stands at the mailbox all day anyway. Give people a reason to stop. {item}, {price} at {shop}.",
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
        "Blue steel, laced tight. Somebody is going to have to help you out of it. {shop} has {item} for {price}.",
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
        "Makes men apologise. They won't know what for. ~ {shop} ~ {item}, {price}.",
        "For when 'please' should be coming from the other direction. {item}, {price} at {shop}.",
        pools = { "look_high_cut", "plate", "legs", "general" },
        color = "Bronze",
    },
    -- Tyrant's Chestpiece (plate chest, level 43)
    [14835] = {
        "Spiked collar, red trim, bare sides. Dress like the one who decides when they may stand up. {item}, {price} at {shop}.",
        "Nobody leaves the group until you say so. {shop} has {item} for {price}.",
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
