--[[
	Accessories - the accessory catalog. Each entry is { name, id } where `id` is
	a Roblox image/decal asset id. An accessory renders as an extra image layer
	CENTERED on your cell and sized a bit larger than it (see Renderer), drawn over
	the skin - so a mostly-transparent PNG (ears, crown, glasses...) sits where its
	art is. Same idea as skins; equipping syncs via the roster's `a` field.

	To add accessories: paste { name = "...", id = <number> } lines below. Ideally
	these are transparent PNGs shaped like a hat/ears/etc. (The starter entries are
	PLACEHOLDERS reusing catalog art so the layer is visible - replace with real
	accessory art ids.)
]]

local Accessories = {}

function Accessories.thumb(id: number): string
	return ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(id)
end

-- id 0 is reserved: "no accessory". `price` is the Gold cost in the Buy tab
-- (0 = free); prices are placeholders until the buy/own economy lands.
-- Per-item `x`, `y`, and `scale` account for transparent padding inside
-- each source image. This keeps the visible artwork attached to the cell rim.
Accessories.List = {
	{ name = "Chicken Hat", id = 115574111485918, price = 500000, x = 0.50, y = 0.30, scale = 1.48 },
	{ name = "Egg Hat", id = 88334382966718, price = 500000, x = 0.50, y = 0.29, scale = 1.55 },
	{ name = "Heart Hat", id = 109962142302629, price = 500000, x = 0.50, y = 0.29, scale = 1.48 },
	{ name = "Swords", id = 133050467164576, price = 500000, x = 0.50, y = 0.50, scale = 1.38 },
	{ name = "Katanas", id = 134132948842841, price = 500000, x = 0.85, y = 0.62, scale = 1.90 },
	{ name = "Chief Hat", id = 107465494658903, price = 500000, x = 0.50, y = 0.24, scale = 1.20 },
	{ name = "Tail", id = 106092508678839, price = 500000, x = 0.72, y = 0.58, scale = 2.10 },
	{ name = "Basket", id = 85998134979799, price = 500000, x = 0.70, y = 0.68, scale = 1.80 },
	{ name = "Chel", id = 92322759647923, price = 500000, x = 0.35, y = 0.22, scale = 3.00 },
	{ name = "Donkey Ears", id = 135464791581011, price = 500000, x = 0.50, y = 0.25, scale = 1.25 },
	{ name = "Spikes", id = 112881927043260, price = 500000, x = 0.50, y = 0.50, scale = 1.12 },
	{ name = "Captain Hat", id = 96202978415135, price = 500000, x = 0.50, y = 0.24, scale = 1.20 },
}

Accessories.ById = {}
for _, a in Accessories.List do
	Accessories.ById[a.id] = a
end

-- Where/how big to draw an accessory: normalized center X/Y plus size vs cell.
function Accessories.placement(id: number): (number, number, number)
	local a = Accessories.ById[id]
	return (a and a.x) or 0.5, (a and a.y) or 0.5, (a and a.scale) or 1.2
end

-- Legacy helper retained for callers outside the current renderer. Avatar
-- headshots now replace the base skin and fill the complete circular cell.
function Accessories.avatarPlacement(): (number, number, number)
	return 0.5, 0.5, 1
end

return Accessories
