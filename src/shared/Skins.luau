--[[
	Skins - the skin catalog. Each entry is { name, id } where `id` is a Roblox
	image/decal asset id. The cell renders it via rbxthumb:// (see below), which
	reliably displays DECAL ids in a GUI - plain ImageLabel.Image often refuses
	to render decals, only true image assets.

	To add more skins: paste more { name = "...", id = <number> } lines. There's
	no practical limit; the shop is searchable and virtualized, so 1000+ is fine.
	Players can also paste ANY image id in the shop's box without it being here.
]]

local Skins = {}

-- Build the content string the renderer/shop feed to ImageLabel.Image.
-- rbxthumb renders decals AND images as a square thumbnail (perfect for a
-- circular cell - we just clip it round). A NEGATIVE id is the "your avatar"
-- skin: it encodes -UserId and renders that player's Roblox avatar headshot.
function Skins.thumb(id: number): string
	if id < 0 then
		return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(-id)
	end
	return ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(id)
end

-- id 0 is reserved: "no skin" (plain colored circle).
Skins.List = {
	{ name = "Giga Chad", id = 10590477450 },
	{ name = "Rickroll", id = 6403436082 },
	{ name = "Shocked Guy Meme", id = 11818627075 },
	{ name = "Among Us Man Face", id = 9180622670 },
	{ name = "Cat Gun", id = 5205790826 },
	{ name = "Man Shocked at Banana", id = 9605261863 },
	{ name = "Straw Hat Pirates", id = 9478562327 },
	{ name = "The Rock", id = 8425069728 },
	{ name = "Cat Standing Meme", id = 9142678957 },
	{ name = "The Meme Dog", id = 9835676498 },
	{ name = "Luffy", id = 10511856020 },
	{ name = "One Piece x Luffy", id = 8964489645 },
	{ name = "Banana Cat", id = 5009915812 },
	{ name = "Dragones de Kanna", id = 8332960925 },
	{ name = "Sonic Meme", id = 10491133376 },
	{ name = "Skeleton Meme", id = 10180536602 },
	{ name = "Sigma", id = 11600511955 },
	{ name = "Sad Spongebob", id = 10729455663 },
	{ name = "Megamind Meme", id = 10180628714 },
	{ name = "Bing Chilling", id = 9895184382 },
	{ name = "Gengar Crosshair", id = 11759293347 },
	{ name = "Dragon Ball Crosshair", id = 11759193017 },
	{ name = "Cat in Milk", id = 7220505725 },
	{ name = "Peter Griffin", id = 4632517063 },
	{ name = "Among Us Red Imposter", id = 5747127696 },
	{ name = "Sus Dog Meme", id = 11648237431 },
	{ name = "Cheems Minecraft", id = 9676276958 },
	{ name = "Makima", id = 11902680347 },
	{ name = "Ghost MW2", id = 11623459250 },
	{ name = "Pop Cat", id = 10800748312 },
	{ name = "Rock Eating Pancakes", id = 7554420585 },
	{ name = "Meme Hamster", id = 8450601370 },
	{ name = "Drip Goku", id = 7683701966 },
	{ name = "Spy TF2", id = 11100293066 },
	{ name = "Pyro TF2 Cook", id = 10085901665 },
	{ name = "Anime Aesthetic", id = 6675147490 },
	{ name = "Anime Aesthetic 2", id = 5252447904 },
	{ name = "Hu Tao", id = 6942501530 },
	{ name = "Xiao", id = 10100073890 },
	{ name = "Ganyu", id = 6409799531 },
	{ name = "Itto", id = 7903533369 },
	{ name = "Ei / Baal", id = 7903531752 },
	{ name = "Biggest Bird", id = 12077086097 },
	{ name = "Saul Goodman", id = 10776847027 },
	{ name = "MC Grass Side", id = 9267155990 },
	{ name = "MC Grass Top", id = 9267183944 },
	{ name = "MC Dirt", id = 9267089525 },
	{ name = "MC Red Bed", id = 9267599783 },
	{ name = "MC Oak Log", id = 9359131816 },
	{ name = "MC Sand", id = 9277770684 },
	{ name = "Sans", id = 915326045 },
	{ name = "Gojo Satoru", id = 9242918232 },
	{ name = "Walter White", id = 10118413175 },
	{ name = "Assassin's Creed", id = 11622626925 },
	{ name = "Red Omega", id = 11489880386 },
	{ name = "Kawaii Anime Girl", id = 11696745268 },
	{ name = "Doge", id = 631727250 },
	{ name = "Goku Ultra Instinct", id = 7625033282 },
	{ name = "Zorhadur", id = 9454288009 },
	{ name = "Wednesday", id = 11702769325 },
	{ name = "Cat With Gun", id = 78969295 },
	{ name = "Cat Holding Food", id = 11089513965 },
	{ name = "Dog", id = 10919793581 },
	{ name = "Kokomi", id = 11761637789 },
	{ name = "Potato Pirates", id = 11005456141 },
	{ name = "Cheems Samurai", id = 7995653636 },
	{ name = "Hatsune Miku", id = 11696689831 },
	{ name = "Venti", id = 11761735237 },
	{ name = "Childe", id = 11761733202 },
	{ name = "Nilou", id = 11761723782 },
	{ name = "Lisa", id = 11761719248 },
	{ name = "Dragon Ball Goku", id = 7607741448 },
	{ name = "Starbucks", id = 11968834680 },
	{ name = "Sonic Scary", id = 9795319439 },
	{ name = "Ronaldo Nextbot", id = 10487246132 },
	{ name = "Cute Anime", id = 8227110001 },
	{ name = "Capybara", id = 7600505808 },
	{ name = "Sailor Moon", id = 8678122759 },
	{ name = "Mario", id = 11168363548 },
	{ name = "NO", id = 6807257275 },
	{ name = "Nezuko", id = 11426233172 },
	{ name = "Los Pollos Hermanos", id = 9670994907 },
	{ name = "Saul Goodman Ad", id = 10586142459 },
	{ name = "Moai", id = 11990831699 },
	{ name = "Mike Bruh Face", id = 6090344677 },
	{ name = "Baby Duck", id = 6277787457 },
	{ name = "Frog in Car", id = 7790518252 },
	{ name = "Samos Empire", id = 102348382 },
	{ name = "Anya Forger", id = 10694360254 },
	{ name = "Epic Duck", id = 92401568 },
	{ name = "YouTube", id = 1275974022 },
	{ name = "Messi", id = 11992703858 },
	{ name = "Crosshair", id = 11988231187 },
	{ name = "Anime Decal", id = 8598068650 },
	{ name = "Sonic", id = 12052385551 },
	{ name = "Tails", id = 12052378352 },
	{ name = "Amy", id = 12052395301 },
	{ name = "Elmo Fire", id = 10901055606 },
	{ name = "Gamer Controller", id = 10322933810 },
	{ name = "Kirby", id = 11041446595 },
	-- ---- extra shop skins ----
	{ name = "Beluga", id = 7129155278 },
	{ name = "Touge Out Cat", id = 11176073582 },
	{ name = "Adventure Time", id = 8373881918 },
	{ name = "Demon Slayer", id = 5444301611 },
	{ name = "PJ Monkey", id = 4535856663 },
	{ name = "Spooky Skeleton", id = 348864556 },
	{ name = "Bread", id = 2163500151 },
	{ name = "Mr Incredible", id = 8423240984 },
	{ name = "Kaido One Piece", id = 7553025629 },
	{ name = "Minecraft Died", id = 3601030967 },
	{ name = "Invisible", id = 2483186 },
	{ name = "Aesthetic Anime", id = 5191098772 },
	{ name = "Cursed Image", id = 1847902752 },
	{ name = "Funny Cat Moment", id = 7205866972 },
	{ name = "Summer Chill Out", id = 3290453459 },
	{ name = "Aesthetic", id = 1049060234 },
	{ name = "Kawaii", id = 5206932266 },
	{ name = "Roblox Meme 1", id = 7279137105 },
	{ name = "Birthday", id = 935443517 },
	{ name = "Miku Plush", id = 5530807649 },
	{ name = "Himiko Magic Girl", id = 4560862750 },
	{ name = "Miku Blue Pixel", id = 11696751303 },
}

-- Level-locked skins: a progression reward. Only equippable once you reach the
-- required level (enforced server-side in Network.setskin; the shop shows a lock
-- with the required level until then). They also live in Skins.List (appended
-- below) so they appear in the shop grid alongside the free skins.
Skins.LevelSkins = {
	{ name = "Fly", id = 123184203462937, level = 5 },
	{ name = "Spider", id = 136246504733085, level = 10 },
	{ name = "Wasp", id = 89421765434538, level = 15 },
	{ name = "Lizard", id = 131498499712183, level = 20 },
	{ name = "Bat", id = 133850690603961, level = 25 },
	{ name = "Snake", id = 83813680359486, level = 30 },
	{ name = "Fox", id = 135966158378567, level = 35 },
	{ name = "Coyote", id = 115304738072653, level = 40 },
	{ name = "Hunter", id = 106909526202766, level = 45 },
	{ name = "Sumo", id = 80096571188996, level = 50 },
	{ name = "Bear", id = 122066180752950, level = 55 },
	{ name = "Cougar", id = 88168990057844, level = 60 },
	{ name = "Panther", id = 72746715010536, level = 65 },
	{ name = "Lion", id = 77852246856007, level = 70 },
	{ name = "Crocodile", id = 71841427184637, level = 75 },
	{ name = "Shark", id = 124671757253954, level = 80 },
	{ name = "Mammoth", id = 92940263650897, level = 85 },
	{ name = "Raptor", id = 121327620427191, level = 90 },
	{ name = "T-Rex", id = 93342400772415, level = 95 },
	{ name = "Kraken", id = 136266440086993, level = 100 },
	{ name = "Tiny Fairy", id = 81553136576404, level = 105 },
	{ name = "Small Goblin", id = 124070492740278, level = 110 },
	{ name = "Young Elf", id = 97701702636034, level = 115 },
	{ name = "Grove Spirit", id = 103866438790783, level = 120 },
	{ name = "Mystical Dwarf", id = 102542102042632, level = 125 },
	{ name = "Brave Halfling", id = 115415384048734, level = 130 },
	{ name = "Wild Werewolf", id = 92934725261858, level = 135 },
	{ name = "Powerful Sorcerer", id = 110570118950675, level = 140 },
	{ name = "Stealthy Assassin", id = 87813738178173, level = 145 },
	{ name = "Valiant Knight", id = 92903783395298, level = 150 },
}

-- append level skins so they show in the shop grid too (after the free skins)
for _, s in Skins.LevelSkins do
	table.insert(Skins.List, s)
end

-- id -> entry (for validating "is this a real catalog skin" + its unlock level)
Skins.ById = {}
for _, s in Skins.List do
	Skins.ById[s.id] = s
end

-- Level required to equip a skin (0 = free / not level-locked).
function Skins.requiredLevel(id: number): number
	local e = Skins.ById[id]
	return (e and e.level) or 0
end

return Skins
