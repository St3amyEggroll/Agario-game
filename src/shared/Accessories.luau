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

-- id 0 is reserved: "no accessory".
Accessories.List = {
	-- PLACEHOLDERS - replace with real transparent accessory art:
	{ name = "Crosshair", id = 11988231187 },
	{ name = "Gengar", id = 11759293347 },
	{ name = "Dragon Ball", id = 11759193017 },
}

Accessories.ById = {}
for _, a in Accessories.List do
	Accessories.ById[a.id] = a
end

return Accessories
