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
-- Optional `y` = vertical CENTER of the accessory on the cell (0 = top, 0.5 =
-- middle [default], 1 = bottom). Hats/ears use a low y so they sit up top. `scale`
-- (default 1.5) is the accessory size relative to the cell.
Accessories.List = {
	{ name = "Chicken Hat", id = 76661227221519, price = 500000, y = 0.18 },
	{ name = "Egg Hat", id = 88334382966718, price = 500000, y = 0.18 },
	{ name = "Heart Hat", id = 109962142302629, price = 500000, y = 0.18 },
	{ name = "Swords", id = 133050467164576, price = 500000 },
	{ name = "Katanas", id = 134132948842841, price = 500000 },
	{ name = "Chief Hat", id = 107465494658903, price = 500000, y = 0.18 },
	{ name = "Tail", id = 106092508678839, price = 500000 },
	{ name = "Basket", id = 85998134979799, price = 500000 },
	{ name = "Chel", id = 92322759647923, price = 500000 },
	{ name = "Donkey Ears", id = 135464791581011, price = 500000, y = 0.15 },
	{ name = "Spikes", id = 112881927043260, price = 500000 },
	{ name = "Captain Hat", id = 96202978415135, price = 500000, y = 0.18 },
}

Accessories.ById = {}
for _, a in Accessories.List do
	Accessories.ById[a.id] = a
end

-- Where/how big to draw the accessory on a cell: returns (y, scale). y is the
-- vertical CENTER on the cell (0 top .. 1 bottom), scale is size vs the cell.
function Accessories.placement(id: number): (number, number)
	local a = Accessories.ById[id]
	return (a and a.y) or 0.5, (a and a.scale) or 1.5
end

return Accessories
