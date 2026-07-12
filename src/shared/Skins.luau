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
-- circular cell - we just clip it round).
function Skins.thumb(id: number): string
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
}

-- id -> entry (for validating "is this a real catalog skin")
Skins.ById = {}
for _, s in Skins.List do
	Skins.ById[s.id] = s
end

return Skins
