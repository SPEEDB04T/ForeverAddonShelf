-- Slutmog Shop: the ready-made ads. Generated; edit the generator, not this file.
-- ns.AD_POOLS: ads shared by pieces with the same look, armor type, slot or level range.
-- ns.ITEM_ADS[id]: the piece's own ads, then pools = the pools it draws on, color = its colour words.
-- {item}, {price} and {shop} are filled in when the ad goes out, {level} too; {color} when the list is built.
local _, ns = ...

ns.AD_POOLS = {
    general = {
        "Warlock's succubus keeps drawing all your group's attention? Take it back. {item}, {price} at {shop}.",
        "Want your character to look hot instead of well geared? {shop} has {item} for {price}.",
        "Selling slutmog. ~ {shop} ~ {item}, {price}.",
        "You didn't roll a female character for the casting animations. {item}, {price} at {shop}.",
        "Tired of your female character being covered from neck to ankle? {shop} has {item} for {price}.",
        "It's not an upgrade. It just looks hot. ~ {shop} ~ {item}, {price}.",
        "Keep getting ganked, never getting camped? Give them a reason to stay. {item}, {price} at {shop}.",
        "Your tier set is ugly. Mog over it. {shop} has {item} for {price}.",
        "You already zoom the camera in. Give it something to look at. ~ {shop} ~ {item}, {price}.",
        "Shows a lot of skin. That's the whole point. {item}, {price} at {shop}.",
        "For players who rolled a female character and want to actually see her. {shop} has {item} for {price}.",
        "Ctrl-click {item} and see for yourself. {price} at {shop}.",
        "Your main stays respectable. This is for the alt the guild doesn't know about. {item}, {price} at {shop}.",
        "Some of the most revealing gear in the game. {shop} has {item} for {price}.",
        "Gets you inspected. Then whispered. ~ {shop} ~ {item}, {price}.",
        "Collecting sexy mogs? You probably don't have this one. {item}, {price} at {shop}.",
        "Make your alt the best looking character in Goldshire. {shop} has {item} for {price}.",
        "The kind of mog that gets you free portals. ~ {shop} ~ {item}, {price}.",
        "For Goldshire regulars. You know who you are. {item}, {price} at {shop}.",
    },
    plate = {
        "Hit 40 and finally allowed to wear plate? Here's hardly any. {shop} has {item} for {price}.",
        "Plate that shows skin. There isn't much of it in the game. ~ {shop} ~ {item}, {price}.",
        "Warriors and paladins: sick of looking like a walking fridge? {item}, {price} at {shop}.",
    },
    mail = {
        "Revealing mail is hard to find. Here's some. ~ {shop} ~ {item}, {price}.",
        "Mail that shows skin. {item}, {price} at {shop}.",
    },
    mail_low = {
        "Revealing mail you can wear before 40. {item}, {price} at {shop}.",
        "Warriors and paladins under 40: stop wearing whatever the last quest gave you. {shop} has {item} for {price}.",
    },
    mail_high = {
        "Hunters and shamans: show some skin for once. {shop} has {item} for {price}.",
        "Sexy mail for hunters and shamans. ~ {shop} ~ {item}, {price}.",
    },
    leather = {
        "Rogues and druids: tight leather, lots of skin. ~ {shop} ~ {item}, {price}.",
        "Tight leather, and not much of it. {item}, {price} at {shop}.",
    },
    cloth = {
        "Casters can show skin too. {item}, {price} at {shop}.",
        "Mages, priests, warlocks: stop dressing like a curtain. {shop} has {item} for {price}.",
    },
    legs = {
        "You look at your character from behind all day. Give yourself a view. {shop} has {item} for {price}.",
        "Shows off her legs. ~ {shop} ~ {item}, {price}.",
    },
    chest = {
        "Shows off her chest. ~ {shop} ~ {item}, {price}.",
        "A top that actually shows something. {item}, {price} at {shop}.",
    },
    lvl_low = {
        "Only needs level {level}. Good for bank alts and twinks. {item}, {price} at {shop}.",
        "Wearable at level {level}, so your bank alt can stand at the mailbox in it. {shop} has {item} for {price}.",
    },
    lvl_high = {
        "Level 60 and bored? Play dress-up. {shop} has {item} for {price}.",
        "Raid gear is for raids. This is for standing around in town. ~ {shop} ~ {item}, {price}.",
    },
    look_bikini = {
        "A strip of {color} round the hips. That's the whole item. ~ {shop} ~ {item}, {price}.",
        "The tooltip says legs. It covers the hips and stops there. {item}, {price} at {shop}.",
        "Your character's underwear covers more than this. {shop} has {item} for {price}.",
    },
    look_fur_halter = {
        "A {color} fur top, open all the way down the front. {item}, {price} at {shop}.",
    },
    look_one_shoulder = {
        "One shoulder covered, one bare, and an armband for decoration. {shop} has {item} for {price}.",
    },
    look_zigzag_robe = {
        "A robe with a neckline that stops at the navel. ~ {shop} ~ {item}, {price}.",
    },
    look_net_robe = {
        "A {color} robe with see-through net sleeves and silver leaves over exactly two places. {item}, {price} at {shop}.",
    },
    look_web_robe = {
        "A teal robe with web for sleeves and silver leaves over exactly two places. {shop} has {item} for {price}.",
    },
    look_hip_window = {
        "Long trousers with both hips cut out. Ankles covered, hips bare. ~ {shop} ~ {item}, {price}.",
    },
    look_cod_leather = {
        "A studded leather panel on two straps. Front only. {item}, {price} at {shop}.",
    },
    look_stud_top = {
        "Tight {color} leather with buckles down the front. {shop} has {item} for {price}.",
    },
    look_underbust = {
        "Leather straps that go under and around and nowhere near over. ~ {shop} ~ {item}, {price}.",
    },
    look_loincloth = {
        "A {color} flap front and back on a studded belt, open at the sides. {item}, {price} at {shop}.",
        "A studded belt, a strip of cloth and a lot of thigh. {shop} has {item} for {price}.",
    },
    look_loincloth_mail = {
        "{color} scale flaps front and back, open at the sides. {shop} has {item} for {price}.",
        "A studded belt, a strip of scales and a lot of thigh. ~ {shop} ~ {item}, {price}.",
    },
    look_black_harness = {
        "A black studded leather harness with {color} trim. ~ {shop} ~ {item}, {price}.",
    },
    look_chain_bra = {
        "A chainmail bra with a diamond cut out of the middle. {item}, {price} at {shop}.",
    },
    look_fringe_top = {
        "Leather over one side, nothing over the other, and a chain fringe hanging off the bottom. {item}, {price} at {shop}.",
    },
    look_scale_top = {
        "A short {color} scale top that stops well above the belt. ~ {shop} ~ {item}, {price}.",
    },
    look_padded_scoop = {
        "Looks like normal padded armor until you see how low the front scoops. {item}, {price} at {shop}.",
    },
    look_dragon_top = {
        "A {color} scale sash over one shoulder and the rest left out in the open. {shop} has {item} for {price}.",
    },
    look_dragon_legs = {
        "Skin-tight {color} scale leggings. ~ {shop} ~ {item}, {price}.",
    },
    look_garter = {
        "A steel hip plate, chain tassels and a garter buckled round one thigh. {item}, {price} at {shop}.",
    },
    look_chain_cups = {
        "Two {color} steel cups hanging from chains. {shop} has {item} for {price}.",
    },
    look_scale_bikini = {
        "Bikini armor, the real thing, the reason half of us rolled a female character. ~ {shop} ~ {item}, {price}.",
        "A {color} scale bikini top on leather straps. {item}, {price} at {shop}.",
    },
    look_scale_bikini_legs = {
        "Bikini armor, the real thing, the reason half of us rolled a female character. {item}, {price} at {shop}.",
        "{color} scale bikini bottoms, in mail. {shop} has {item} for {price}.",
    },
    look_band_cup = {
        "A band of scales across the chest and one steel cup. {shop} has {item} for {price}.",
    },
    look_shell = {
        "A breastplate shaped like two seashells. You know the ones. ~ {shop} ~ {item}, {price}.",
    },
    look_ribs = {
        "Bands across the chest like ribs, with a gap between every one. {item}, {price} at {shop}.",
    },
    look_tiles = {
        "Leather tiles laced together with red cord and hung roughly where they're needed. {shop} has {item} for {price}.",
    },
    look_plate_thong = {
        "It's a metal thong. Both legs are bare from hip to boot. ~ {shop} ~ {item}, {price}.",
    },
    look_single_cup = {
        "One cup held on by metal rods. The other side is bare. {item}, {price} at {shop}.",
    },
    look_chastity = {
        "Steel bottoms with a lock on the front. {shop} has {item} for {price}.",
        "There's a lock on the front. Every rogue in Ironforge will offer to level lockpicking on it. {item}, {price} at {shop}.",
    },
    look_plate_bikini = {
        "Bikini armor, the real thing, the reason half of us rolled a female character. ~ {shop} ~ {item}, {price}.",
        "Two {color} cups and some cord. That's the breastplate. {item}, {price} at {shop}.",
    },
    look_barred_window = {
        "Full plate with a barred window over the cleavage. {item}, {price} at {shop}.",
    },
    look_high_cut = {
        "{color} plate over the hips, slits up both sides, bare thigh from there to the boot. {item}, {price} at {shop}.",
    },
    look_collar_strip = {
        "A spiked collar and one strip of plate down the middle. The sides are bare from armpit to hip. {item}, {price} at {shop}.",
    },
    look_navel_plate = {
        "Proper plate with a hole cut in the belly. {item}, {price} at {shop}.",
    },
    look_batwing = {
        "Spiked plate like bat wings across the chest, and bare skin under them. {shop} has {item} for {price}.",
    },
}

ns.ITEM_ADS = {
    -- Simple Blouse (cloth chest, level 10)
    [9749] = {
        pools = { "look_one_shoulder", "cloth", "chest", "lvl_low", "general" },
        color = "dark red",
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
    -- Buccaneer's Vest (cloth chest, level 18)
    [14175] = {
        "A white satin shirt, open and tied up so the belly's out. Pirate on her day off. {item}, {price} at {shop}.",
        pools = { "cloth", "chest", "lvl_low", "general" },
    },
    -- Ritual Shroud (cloth chest, level 19)
    [14127] = {
        "A red cloth triangle held on by chains, open at both sides. {item}, {price} at {shop}.",
        pools = { "cloth", "chest", "lvl_low", "general" },
    },
    -- Robes of Insight (cloth chest, level 42)
    [940] = {
        "An epic robe cut open to the waist. {shop} has {item} for {price}.",
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
        "Gold shell cups set with turquoise, on a robe. {item}, {price} at {shop}.",
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
    -- Grizzly Jerkin (leather chest, level 11)
    [15304] = {
        pools = { "look_underbust", "leather", "chest", "lvl_low", "general" },
        color = "brown",
    },
    -- Ceremonial Leather Loincloth (leather legs, level 12)
    [3315] = {
        "Black fur, a gold chain for a belt and a garter on one thigh. {item}, {price} at {shop}.",
        pools = { "leather", "legs", "lvl_low", "general" },
    },
    -- Bard's Trousers (leather legs, level 13)
    [6553] = {
        "Crimson hot pants. Bare thigh down to the knee, then boots. {shop} has {item} for {price}.",
        pools = { "leather", "legs", "lvl_low", "general" },
    },
    -- Bandit Pants (leather legs, level 17)
    [9781] = {
        pools = { "look_bikini", "leather", "legs", "lvl_low", "general" },
        color = "black leather",
    },
    -- Insignia Leggings (leather legs, level 30)
    [4054] = {
        pools = { "look_cod_leather", "leather", "legs", "lvl_low", "general" },
        color = "brown",
    },
    -- Insignia Chestguard (leather chest, level 31)
    [4057] = {
        pools = { "look_stud_top", "leather", "chest", "lvl_low", "general" },
        color = "Brown",
    },
    -- Sentinel Trousers (leather legs, level 34)
    [7440] = {
        pools = { "look_bikini", "leather", "legs", "lvl_low", "general" },
        color = "olive fur",
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
        "A black studded corset laced open down the front, with a collar ring. ~ {shop} ~ {item}, {price}.",
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
        "Pale steel cups on buckled straps. ~ {shop} ~ {item}, {price}.",
        pools = { "mail", "chest", "mail_low", "lvl_low", "general" },
    },
    -- Firemane Leggings (mail legs, level 34)
    [13129] = {
        "Glossy red hip plates, and very little of them. {shop} has {item} for {price}.",
        pools = { "mail", "legs", "mail_low", "lvl_low", "general" },
    },
    -- Enduring Breastplate (mail chest, level 34)
    [14760] = {
        "A banded steel corset with a keyhole cut over the cleavage. {item}, {price} at {shop}.",
        pools = { "mail", "chest", "mail_low", "lvl_low", "general" },
    },
    -- Chief Brigadier Leggings (mail legs, level 35)
    [4079] = {
        pools = { "mail", "legs", "mail_low", "lvl_low", "general" },
    },
    -- Marauder's Tunic (mail chest, level 35)
    [15567] = {
        "Red and grey plates linked by rings, with a gap between every plate. {item}, {price} at {shop}.",
        pools = { "mail", "chest", "mail_low", "lvl_low", "general" },
    },
    -- Chief Brigadier Armor (mail chest, level 36)
    [6411] = {
        "Black cups with red flames on them. It's lingerie with an armor value. {item}, {price} at {shop}.",
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
        "Red, black and gold slats with skin showing between them. {item}, {price} at {shop}.",
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
        pools = { "look_high_cut", "plate", "legs", "general" },
        color = "Bronze",
    },
    -- Tyrant's Chestpiece (plate chest, level 43)
    [14835] = {
        "Spiked collar, red trim, bare sides. {item}, {price} at {shop}.",
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
