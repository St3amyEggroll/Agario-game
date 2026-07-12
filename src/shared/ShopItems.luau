--[[
	ShopItems - placeholder cosmetic catalog for the Shop stub.

	Extension point: give items a real `productId` and gate `isOwned` behind
	MarketplaceService:UserOwnsGamePassAsync / receipt processing. The client
	Shop UI and the server "setskin" action already flow through here, so wiring
	real purchases only touches this module + one server check.
]]

local ShopItems = {}

-- colorIdx refers to Config.Palette entries.
ShopItems.Items = {
	{ id = "skin_crimson", name = "Crimson", price = 0, colorIdx = 1, desc = "Classic red." },
	{ id = "skin_ocean", name = "Ocean", price = 0, colorIdx = 6, desc = "Cool blue." },
	{ id = "skin_toxic", name = "Toxic", price = 99, colorIdx = 4, desc = "Radioactive green." },
	{ id = "skin_royal", name = "Royal", price = 199, colorIdx = 8, desc = "Purple like royalty." },
	{ id = "skin_bubblegum", name = "Bubblegum", price = 299, colorIdx = 9, desc = "Sweet pink." },
}

-- STUB: everything is owned for now so skins are previewable. Replace with a
-- real ownership check (game passes / dev products / DataStore inventory).
function ShopItems.isOwned(_player, _itemId): boolean
	return true
end

function ShopItems.byId(itemId: string)
	for _, item in ShopItems.Items do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

return ShopItems
