--[[
	Shop - clean stub wired to the extendable ShopItems framework.
	"Buying"/equipping currently just sets your skin color server-side (the
	"setskin" action). To monetize: give ShopItems real productIds, implement
	ShopItems.isOwned, and gate the Equip button behind a purchase prompt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ShopItems = require(Shared.ShopItems)
local Theme = require(script.Parent.Theme)

local Shop = {}

local panel: Frame

function Shop.init(parent: Instance)
	panel = Theme.panel(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.42, 0.6), Vector2.new(0.5, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Shop - Skins", UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.9, 0.09))
	title.TextColor3 = Theme.AccentColor
	Theme.capText(title, 26)

	local grid = Instance.new("Frame")
	grid.Position = UDim2.fromScale(0.03, 0.14)
	grid.Size = UDim2.fromScale(0.94, 0.74)
	grid.BackgroundTransparency = 1
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromScale(0.31, 0.46)
	layout.CellPadding = UDim2.fromScale(0.028, 0.05)
	layout.Parent = grid

	local localPlayer = Players.LocalPlayer
	for _, item in ShopItems.Items do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Theme.ButtonColor
		card.BorderSizePixel = 0
		Theme.round(card, 10)
		card.Parent = grid

		local swatch = Instance.new("Frame")
		swatch.AnchorPoint = Vector2.new(0.5, 0)
		swatch.Position = UDim2.fromScale(0.5, 0.08)
		swatch.Size = UDim2.fromScale(0.36, 0.36)
		swatch.SizeConstraint = Enum.SizeConstraint.RelativeYY
		swatch.BackgroundColor3 = Config.Palette[item.colorIdx]
		swatch.BorderSizePixel = 0
		Theme.round(swatch, 999)
		swatch.Parent = card

		local nameLabel = Theme.label(card, item.name, UDim2.fromScale(0.05, 0.48), UDim2.fromScale(0.9, 0.14))
		Theme.capText(nameLabel, 18)
		local priceText = item.price > 0 and ("R$ " .. item.price .. " (stub)") or "Free"
		local priceLabel = Theme.label(card, priceText, UDim2.fromScale(0.05, 0.62), UDim2.fromScale(0.9, 0.1))
		priceLabel.TextColor3 = Theme.MutedText
		Theme.capText(priceLabel, 14)

		local owned = ShopItems.isOwned(localPlayer, item.id)
		local equipButton = Theme.button(
			card,
			owned and "Equip" or "Buy",
			UDim2.fromScale(0.5, 0.95),
			UDim2.fromScale(0.8, 0.18),
			function()
				-- purchase flow stub: everything is owned, so just equip
				Remotes.Action:FireServer("setskin", item.colorIdx)
			end
		)
		equipButton.AnchorPoint = Vector2.new(0.5, 1)
		Theme.capText(equipButton, 16)
	end

	local closeButton = Theme.button(panel, "Close", UDim2.fromScale(0.5, 0.97), UDim2.fromScale(0.24, 0.07), function()
		panel.Visible = false
	end)
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	Theme.capText(closeButton, 18)
end

function Shop.toggle()
	panel.Visible = not panel.Visible
end

return Shop
