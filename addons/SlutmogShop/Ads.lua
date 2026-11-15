-- Slutmog Shop: the ready-made ads. Generated; edit the generator, not this file.
-- ns.AD_POOLS: ads shared by pieces with the same look, armor type, slot or level range.
-- ns.ITEM_ADS[id]: the piece's own ads, then pools = the pools it draws on, color = its colour words.
-- {item}, {price} and {shop} are filled in when the ad goes out, {level} too; {color} when the list is built.
-- ns.AD_TAILS: the ending an ad gets, by where the ware is (your bags or the auction house).
local _, ns = ...

ns.AD_TAILS = {
    bags = { " {item}, {price} at {shop}.", " {shop} has {item} for {price}.", " ~ {shop} ~ {item}, {price}." },
    ah = { " {item} is on the auction house for {price}. ~ {shop} ~", " {shop} has {item} up on the auction house, {price} buyout.", " {item}, {price} on the AH. {shop}" },
}

-- A set (a top and a bottom sold together): {item} is the top, {pair} the bottom, {price} both together.
ns.SET_TAILS = {
    bags = { " {item} + {pair}, {price} for both. {shop}", " {shop}: {item} + {pair}, {price} the pair.", " {item} + {pair}, {price} for both." },
    ah = { " {item} + {pair} on the AH, {price} for both. {shop}", " {shop}: {item} + {pair}, both on the AH, {price}.", " {item} + {pair} on the AH, {price} for both." },
}

ns.AD_POOLS = {
    general = {
        "Warlock's succubus keeps drawing all your group's attention? Take it back.",
        "You didn't roll a female character for the casting animations.",
        "Keep getting ganked, never getting camped? Give them a reason to stay.",
        "Gets you inspected. Then whispered.",
        "The kind of mog that gets you free portals.",
        "For Goldshire regulars. You know who you are.",
        "Too much for Stormwind. About right for Goldshire.",
        "You picked a night elf for a reason. It wasn't Shadowmeld.",
        "Roleplayers will find you. You've been warned.",
        "The kind of mog that gets your lockboxes opened for free.",
        "Fair warning: it sits at eye level for every gnome in Ironforge.",
        "They'll ask if you're a girl IRL. They'll tip either way.",
        "Going to dance on the Ironforge mailbox anyway? Dress for it.",
        "The Goldshire inn has an upstairs. Now you're dressed for it.",
        "Sold one yesterday. The buyer hasn't left Goldshire since.",
        "It won't help you win the roll. It might help the master looter decide.",
        "She has had the same underwear since character creation. Treat her.",
        "Gets you resurrected first.",
        "Makes strangers generous.",
        "Free water, free healthstones, free summons. Nobody says why.",
        "Enchanters stop asking for a tip.",
        "Does more for your loot priority than showing up on time.",
        "You'll be asked to leave Stormwind and begged to stay in Goldshire.",
        "Hearthstone set to Goldshire? Thought so.",
        "Paladins will waste Blessing of Protection on you.",
        "Gets you a summon while the tank is still running.",
        "Sold two this week. Both buyers have a new guild and a free mount.",
        "Bought one for his girlfriend's character. She's very popular in guild now.",
        "Going to sit on the Stormwind fountain all night anyway? Dress for it.",
        "Last buyer hasn't paid for a portal since.",
        "Last buyer hasn't walked to an instance since.",
        "Last buyer hasn't bought her own water since.",
        "Booty Bay was named for a reason. Remind them.",
        "Gnomes will pretend they were just walking past.",
        "Don't be shy, show some thigh.",
        "Put the booty back in Booty Bay.",
        "This look will outlast your guild.",
        "Nefarian drops better stats. He doesn't drop a better look.",
        "Tier 2 covers too much anyway.",
        "Your gear gets replaced every raid. This look doesn't.",
        "The price goes up when the raiders find out. They always find out.",
        "Cheap now. Wait till the raiders have gold.",
        "Buy it before someone with an epic mount does.",
    },
    plate = {
        "Hit your 40s and the gentlemen don't stare like they used to? ~ {shop} ~ NOW OPEN for all your mogging needs! {item} only {price}.",
        "Hit 40 and finally allowed to wear plate? Here's hardly any.",
        "Protects almost nothing. That's what the healer is for.",
    },
    legs = {
        "You look at your character from behind all day. Give yourself a view.",
        "Don't wear a robe over it. That's the good part.",
        "Take your cloak off. It's covering the good part.",
    },
    chest = {
        "Take your tabard off. It's covering the good part.",
        "You'll replace that chest ten times by Naxx. It'll look like this every time.",
    },
    shop_smuttanie = {
        "Long night of grinding with the boys? Smuttanie keeps you ready!",
        "Boys wiping at 3am again? Smuttanie keeps them coming back!",
        "Nobody wants to run you through Deadmines? Smuttanie changes their mind!",
        "Tired of tipping the mage? Smuttanie has him tipping you!",
        "Big night in Goldshire? Smuttanie has you uncovered!",
        "Looking for more? Smuttanie has less!",
        "Half of Goldshire shops at Smuttanie's. The other half is watching.",
        "Can't find a tank? Smuttanie makes them come to you!",
        "Less is more and more's a bore. Smuttanie's has less in store!",
        "From Goldshire to Booty Bay, Smuttanie's gives them a reason to stay.",
        "From Darnassus down to Booty Bay, Smuttanie's takes your top away.",
        "Goldshire by night, Stormwind by day, Smuttanie's makes them look your way.",
        "Can't find a healer? Smuttanie makes them come running!",
        "{shop}, for all your proclivities. {item}, {price}.",
        "{shop}, for your Goldshire activities. {item}, {price}.",
        "Worried it won't last till endgame? Smuttanie goes all the way!",
        "From Ragnaros to Kel'Thuzad, Smuttanie's keeps you barely clad.",
        "Smuttanie's cheap and Smuttanie's easy. One of those won't last.",
    },
    sets = {
        "A top, a bottom and nothing in between.",
        "The full set. It still isn't much.",
        "Goldshire formal wear, both halves.",
    },
    sets_smuttanie = {
        "Top and bottom, Smuttanie's got 'em.",
    },
}

ns.ITEM_ADS = {
    -- Simple Blouse (cloth chest, level 10)
    [9749] = {
        pools = { "chest", "general" },
    },
    -- Barbaric Cloth Vest (cloth chest, level 13)
    [3310] = {
        pools = { "chest", "general" },
    },
    -- Barbaric Cloth Robe (cloth chest, level 13)
    [6531] = {
        pools = { "chest", "general" },
    },
    -- Willow Vest (cloth chest, level 14)
    [6536] = {
        pools = { "chest", "general" },
    },
    -- Aboriginal Robe (cloth chest, level 15)
    [14120] = {
        pools = { "chest", "general" },
    },
    -- Buccaneer's Vest (cloth chest, level 18)
    [14175] = {
        pools = { "chest", "general" },
    },
    -- Ritual Shroud (cloth chest, level 19)
    [14127] = {
        pools = { "chest", "general" },
    },
    -- Robes of Insight (cloth chest, level 42)
    [940] = {
        pools = { "chest", "general" },
    },
    -- Hibernal Robe (cloth chest, level 46)
    [8113] = {
        pools = { "chest", "general" },
    },
    -- Chan's Imperial Robes (cloth chest, level 47)
    [17050] = {
        pools = { "chest", "general" },
    },
    -- Venomshroud Silk Robes (cloth chest, level 49)
    [14445] = {
        pools = { "chest", "general" },
    },
    -- Arachnidian Robes (cloth chest, level 52)
    [14297] = {
        pools = { "chest", "general" },
    },
    -- Elegant Leggings (cloth legs, level 56)
    [10217] = {
        pools = { "legs", "general" },
    },
    -- Elegant Robes (cloth chest, level 57)
    [10215] = {
        pools = { "chest", "general" },
    },
    -- Abyssal Cloth Pants (cloth legs, level 57)
    [20674] = {
        pools = { "legs", "general" },
    },
    -- Burnt Leather Breeches (leather legs, level 5)
    [2962] = {
        pools = { "legs", "general" },
    },
    -- Grizzly Jerkin (leather chest, level 11)
    [15304] = {
        pools = { "chest", "general" },
    },
    -- Ceremonial Leather Loincloth (leather legs, level 12)
    [3315] = {
        pools = { "legs", "general" },
    },
    -- Bard's Trousers (leather legs, level 13)
    [6553] = {
        pools = { "legs", "general" },
    },
    -- Bandit Pants (leather legs, level 17)
    [9781] = {
        pools = { "legs", "general" },
    },
    -- Insignia Leggings (leather legs, level 30)
    [4054] = {
        pools = { "legs", "general" },
    },
    -- Insignia Chestguard (leather chest, level 31)
    [4057] = {
        pools = { "chest", "general" },
    },
    -- Sentinel Trousers (leather legs, level 34)
    [7440] = {
        pools = { "legs", "general" },
    },
    -- Sentinel Breastplate (leather chest, level 35)
    [7439] = {
        pools = { "chest", "general" },
    },
    -- Huntsman's Armor (leather chest, level 38)
    [9887] = {
        pools = { "chest", "general" },
    },
    -- Warden's Woolies (leather legs, level 38)
    [14605] = {
        pools = { "legs", "general" },
    },
    -- Warden's Wraps (leather chest, level 39)
    [14601] = {
        pools = { "chest", "general" },
    },
    -- Scorpashi Leggings (leather legs, level 42)
    [14659] = {
        pools = { "legs", "general" },
    },
    -- Cabalist Leggings (leather legs, level 43)
    [7528] = {
        pools = { "legs", "general" },
    },
    -- Scorpashi Breastplate (leather chest, level 44)
    [14655] = {
        pools = { "chest", "general" },
    },
    -- Rageclaw Leggings (leather legs, level 44)
    [15385] = {
        pools = { "legs", "general" },
    },
    -- Cabalist Chestpiece (leather chest, level 45)
    [7527] = {
        pools = { "chest", "general" },
    },
    -- Chieftain's Leggings (leather legs, level 46)
    [9954] = {
        pools = { "legs", "general" },
    },
    -- Rageclaw Chestguard (leather chest, level 46)
    [15381] = {
        pools = { "chest", "general" },
    },
    -- Keeper's Woolies (leather legs, level 47)
    [14668] = {
        pools = { "legs", "general" },
    },
    -- Chieftain's Breastplate (leather chest, level 48)
    [9950] = {
        pools = { "chest", "general" },
    },
    -- Keeper's Armor (leather chest, level 49)
    [14664] = {
        pools = { "chest", "general" },
    },
    -- Jadefire Pants (leather legs, level 49)
    [15394] = {
        pools = { "legs", "general" },
    },
    -- Praetorian Leggings (leather legs, level 50)
    [15186] = {
        pools = { "legs", "general" },
    },
    -- Jadefire Chestguard (leather chest, level 51)
    [15390] = {
        pools = { "chest", "general" },
    },
    -- Praetorian Padded Armor (leather chest, level 52)
    [15179] = {
        pools = { "chest", "general" },
    },
    -- Pridelord Pants (leather legs, level 53)
    [14677] = {
        pools = { "legs", "general" },
    },
    -- Pridelord Armor (leather chest, level 54)
    [14670] = {
        pools = { "chest", "general" },
    },
    -- Peerless Leggings (leather legs, level 54)
    [15431] = {
        pools = { "legs", "general" },
    },
    -- Peerless Armor (leather chest, level 56)
    [15433] = {
        pools = { "chest", "general" },
    },
    -- Abyssal Leather Leggings (leather legs, level 57)
    [20665] = {
        pools = { "legs", "general" },
    },
    -- Nightshade Tunic (leather chest, level 58)
    [10220] = {
        pools = { "chest", "general" },
    },
    -- Warrior's Tunic (mail chest, level 6)
    [2965] = {
        pools = { "chest", "general" },
    },
    -- Dargol's Hauberk (mail chest, level 8)
    [3330] = {
        pools = { "chest", "general" },
    },
    -- Infantry Tunic (mail chest, level 8)
    [6336] = {
        pools = { "chest", "general" },
    },
    -- Slarkskin (mail chest, level 10)
    [6180] = {
        pools = { "chest", "general" },
    },
    -- Wax-polished Armor (mail chest, level 10)
    [6195] = {
        pools = { "chest", "general" },
    },
    -- Cadet Vest (mail chest, level 10)
    [9765] = {
        pools = { "chest", "general" },
    },
    -- Veteran Armor (mail chest, level 11)
    [2977] = {
        pools = { "chest", "general" },
    },
    -- Soldier's Armor (mail chest, level 13)
    [6545] = {
        pools = { "chest", "general" },
    },
    -- Bloodspattered Loincloth (mail legs, level 13)
    [15493] = {
        pools = { "legs", "general" },
    },
    -- War Paint Legguards (mail legs, level 14)
    [14727] = {
        pools = { "legs", "general" },
    },
    -- Raider's Chestpiece (mail chest, level 15)
    [9783] = {
        pools = { "chest", "general" },
    },
    -- Burnished Tunic (mail chest, level 16)
    [2989] = {
        pools = { "chest", "general" },
    },
    -- Bloodspattered Surcoat (mail chest, level 16)
    [15488] = {
        pools = { "chest", "general" },
    },
    -- Outrunner's Legguards (mail legs, level 17)
    [15503] = {
        pools = { "legs", "general" },
    },
    -- Defender Tunic (mail chest, level 18)
    [6580] = {
        pools = { "chest", "general" },
    },
    -- War Paint Chestpiece (mail chest, level 18)
    [14730] = {
        pools = { "chest", "general" },
    },
    -- Outrunner's Chestguard (mail chest, level 19)
    [15500] = {
        pools = { "chest", "general" },
    },
    -- Grunt's Legguards (mail legs, level 19)
    [15511] = {
        pools = { "legs", "general" },
    },
    -- Fortified Chain (mail chest, level 20)
    [9818] = {
        pools = { "chest", "general" },
    },
    -- Dusty Chain Armor (mail chest, level 21)
    [2016] = {
        pools = { "chest", "general" },
    },
    -- Martyr's Chain (mail chest, level 21)
    [3416] = {
        pools = { "chest", "general" },
    },
    -- Grunt's Chestpiece (mail chest, level 21)
    [15514] = {
        pools = { "chest", "general" },
    },
    -- Lambent Scale Breastplate (mail chest, level 22)
    [3049] = {
        pools = { "chest", "general" },
    },
    -- Spiked Chain Leggings (mail legs, level 22)
    [15521] = {
        pools = { "legs", "general" },
    },
    -- Humbert's Chestpiece (mail chest, level 23)
    [3053] = {
        pools = { "chest", "general" },
    },
    -- Battleforge Legguards (mail legs, level 23)
    [6596] = {
        pools = { "legs", "general" },
    },
    -- Battleforge Armor (mail chest, level 24)
    [6592] = {
        pools = { "chest", "general" },
    },
    -- Sentry's Leggings (mail legs, level 24)
    [15529] = {
        pools = { "legs", "general" },
    },
    -- Double Link Tunic (mail chest, level 25)
    [1717] = {
        pools = { "chest", "general" },
    },
    -- Glimmering Mail Legguards (mail legs, level 25)
    [6386] = {
        pools = { "legs", "general" },
    },
    -- Spiked Chain Breastplate (mail chest, level 25)
    [15518] = {
        pools = { "chest", "general" },
    },
    -- Avenger's Armor (mail chest, level 26)
    [1488] = {
        pools = { "chest", "general" },
    },
    -- Glimmering Mail Breastplate (mail chest, level 26)
    [4071] = {
        pools = { "chest", "general" },
    },
    -- Sentry's Surcoat (mail chest, level 26)
    [15524] = {
        pools = { "chest", "general" },
    },
    -- Mail Combat Armor (mail chest, level 31)
    [4074] = {
        pools = { "chest", "general" },
    },
    -- Mail Combat Leggings (mail legs, level 31)
    [6402] = {
        pools = { "legs", "general" },
    },
    -- Knight's Breastplate (mail chest, level 34)
    [7454] = {
        pools = { "chest", "general" },
    },
    -- Firemane Leggings (mail legs, level 34)
    [13129] = {
        pools = { "legs", "general" },
    },
    -- Enduring Breastplate (mail chest, level 34)
    [14760] = {
        pools = { "chest", "general" },
    },
    -- Chief Brigadier Leggings (mail legs, level 35)
    [4079] = {
        pools = { "legs", "general" },
    },
    -- Marauder's Tunic (mail chest, level 35)
    [15567] = {
        pools = { "chest", "general" },
    },
    -- Chief Brigadier Armor (mail chest, level 36)
    [6411] = {
        pools = { "chest", "general" },
    },
    -- Sparkleshell Breastplate (mail chest, level 36)
    [15578] = {
        pools = { "chest", "general" },
    },
    -- Steadfast Legplates (mail legs, level 36)
    [15596] = {
        pools = { "legs", "general" },
    },
    -- Jazeraint Chestguard (mail chest, level 37)
    [9897] = {
        pools = { "chest", "general" },
    },
    -- Captain's Leggings (mail legs, level 38)
    [7487] = {
        pools = { "legs", "general" },
    },
    -- Steadfast Breastplate (mail chest, level 38)
    [15591] = {
        pools = { "chest", "general" },
    },
    -- Captain's Breastplate (mail chest, level 39)
    [7486] = {
        pools = { "chest", "general" },
    },
    -- Ravager's Armor (mail chest, level 39)
    [14768] = {
        pools = { "chest", "general" },
    },
    -- Brigade Breastplate (mail chest, level 40)
    [9928] = {
        pools = { "chest", "general" },
    },
    -- Ancient Chestpiece (mail chest, level 41)
    [15601] = {
        pools = { "chest", "general" },
    },
    -- Bonelink Armor (mail chest, level 42)
    [15609] = {
        pools = { "chest", "general" },
    },
    -- Warmonger's Chestpiece (mail chest, level 45)
    [9957] = {
        pools = { "chest", "general" },
    },
    -- Myrmidon's Breastplate (mail chest, level 46)
    [8126] = {
        pools = { "chest", "general" },
    },
    -- Lord's Legguards (mail legs, level 47)
    [10084] = {
        pools = { "legs", "general" },
    },
    -- Lord's Breastplate (mail chest, level 48)
    [10077] = {
        pools = { "chest", "general" },
    },
    -- Protector Legguards (mail legs, level 48)
    [14796] = {
        pools = { "legs", "general" },
    },
    -- Protector Breastplate (mail chest, level 49)
    [14789] = {
        pools = { "chest", "general" },
    },
    -- Crusader's Armor (mail chest, level 50)
    [10193] = {
        pools = { "chest", "general" },
    },
    -- Ebonhold Armor (mail chest, level 51)
    [8265] = {
        pools = { "chest", "general" },
    },
    -- Merciless Legguards (mail legs, level 51)
    [15655] = {
        pools = { "legs", "general" },
    },
    -- Ornate Breastplate (mail chest, level 53)
    [10118] = {
        pools = { "chest", "general" },
    },
    -- Engraved Breastplate (mail chest, level 55)
    [10230] = {
        pools = { "chest", "general" },
    },
    -- Hero's Leggings (mail legs, level 56)
    [8309] = {
        pools = { "legs", "general" },
    },
    -- Bonebrace Hauberk (mail chest, level 56)
    [14536] = {
        pools = { "chest", "general" },
    },
    -- Hero's Breastplate (mail chest, level 57)
    [8303] = {
        pools = { "chest", "general" },
    },
    -- Magnificent Breastplate (mail chest, level 57)
    [15669] = {
        pools = { "chest", "general" },
    },
    -- Mercurial Breastplate (mail chest, level 59)
    [10157] = {
        pools = { "chest", "general" },
    },
    -- Masterwork Breastplate (mail chest, level 60)
    [10266] = {
        pools = { "chest", "general" },
    },
    -- Triumphant Chestpiece (mail chest, level 60)
    [15680] = {
        pools = { "chest", "general" },
    },
    -- Jouster's Chestplate (plate chest, level 40)
    [8157] = {
        pools = { "plate", "chest", "general" },
    },
    -- Field Plate Armor (plate chest, level 40)
    [9286] = {
        pools = { "plate", "chest", "general" },
    },
    -- Embossed Plate Armor (plate chest, level 40)
    [9966] = {
        pools = { "plate", "chest", "general" },
    },
    -- Saltstone Surcoat (plate chest, level 40)
    [14895] = {
        pools = { "plate", "chest", "general" },
    },
    -- Saltstone Legplates (plate legs, level 40)
    [14900] = {
        pools = { "plate", "legs", "general" },
    },
    -- Chromite Chestplate (plate chest, level 42)
    [8138] = {
        pools = { "plate", "chest", "general" },
    },
    -- Tyrant's Legplates (plate legs, level 42)
    [14840] = {
        pools = { "plate", "legs", "general" },
    },
    -- Tyrant's Chestpiece (plate chest, level 43)
    [14835] = {
        pools = { "plate", "chest", "general" },
    },
    -- Gothic Plate Armor (plate chest, level 44)
    [10086] = {
        pools = { "plate", "chest", "general" },
    },
    -- Brutish Breastplate (plate chest, level 45)
    [14904] = {
        pools = { "plate", "chest", "general" },
    },
    -- Valorous Chestguard (plate chest, level 46)
    [8274] = {
        pools = { "plate", "chest", "general" },
    },
    -- Jade Legplates (plate legs, level 46)
    [14920] = {
        pools = { "plate", "legs", "general" },
    },
    -- Jade Breastplate (plate chest, level 48)
    [14915] = {
        pools = { "plate", "chest", "general" },
    },
    -- Revenant Chestplate (plate chest, level 49)
    [10128] = {
        pools = { "plate", "chest", "general" },
    },
    -- Hydralick Armor (plate chest, level 49)
    [13067] = {
        pools = { "plate", "chest", "general" },
    },
    -- Heavy Lamellar Chestpiece (plate chest, level 50)
    [10240] = {
        pools = { "plate", "chest", "general" },
    },
    -- Lofty Legguards (plate legs, level 50)
    [14928] = {
        pools = { "plate", "legs", "general" },
    },
    -- Alabaster Breastplate (plate chest, level 52)
    [8312] = {
        pools = { "plate", "chest", "general" },
    },
    -- Vanguard Legplates (plate legs, level 52)
    [14859] = {
        pools = { "plate", "legs", "general" },
    },
    -- Lofty Breastplate (plate chest, level 52)
    [14924] = {
        pools = { "plate", "chest", "general" },
    },
    -- Templar Chestplate (plate chest, level 53)
    [10164] = {
        pools = { "plate", "chest", "general" },
    },
    -- Glorious Legplates (plate legs, level 53)
    [14970] = {
        pools = { "plate", "legs", "general" },
    },
    -- Vanguard Breastplate (plate chest, level 54)
    [14854] = {
        pools = { "plate", "chest", "general" },
    },
    -- Emerald Breastplate (plate chest, level 55)
    [10275] = {
        pools = { "plate", "chest", "general" },
    },
    -- Glorious Breastplate (plate chest, level 56)
    [14966] = {
        pools = { "plate", "chest", "general" },
    },
    -- Imbued Plate Armor (plate chest, level 57)
    [10368] = {
        pools = { "plate", "chest", "general" },
    },
    -- Cloudkeeper Legplates (plate legs, level 57)
    [14554] = {
        pools = { "plate", "legs", "general" },
    },
    -- Commander's Armor (plate chest, level 58)
    [10378] = {
        pools = { "plate", "chest", "general" },
    },
    -- Warleader's Breastplate (plate chest, level 58)
    [14862] = {
        pools = { "plate", "chest", "general" },
    },
    -- Hyperion Armor (plate chest, level 60)
    [10384] = {
        pools = { "plate", "chest", "general" },
    },
    -- Exalted Harness (plate chest, level 60)
    [14975] = {
        pools = { "plate", "chest", "general" },
    },
}
