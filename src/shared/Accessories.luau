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
-- (0 = free). Names/prices below match the reference; the ids are PLACEHOLDERS
-- (reused catalog art so the layer is visible) - send real accessory art ids and
-- I'll swap them in.
Accessories.List = {
	{ name = "Bread", id = 11988231187, price = 400000 },
	{ name = "Leafy Hat", id = 11759293347, price = 750000 },
	{ name = "Angel Halo", id = 11759193017, price = 1000000 },
	{ name = "Cap", id = 11988231187, price = 1000000 },
	{ name = "Cat Ears", id = 11759293347, price = 1000000 },
	{ name = "Cat Ears 2", id = 11759193017, price = 1000000 },
	{ name = "Cat Whiskers", id = 11988231187, price = 1000000 },
	{ name = "Circle Saw", id = 11759293347, price = 1000000 },
	{ name = "Evil Horns", id = 11759193017, price = 1000000 },
	{ name = "Flame", id = 11988231187, price = 1000000 },
}

Accessories.ById = {}
for _, a in Accessories.List do
	Accessories.ById[a.id] = a
end

return Accessories
