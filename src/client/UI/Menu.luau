--[[
	Menu - the bottom Play / Spectate / Shop bar plus the dim overlay shown
	while you're in the menu or dead. Play asks the server to spawn you; the
	overlay hides when the server confirms with a "spawned" PlayerState event.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Menu = {}

local overlay: Frame
local bar: Frame
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local onShopToggle: (() -> ())? = nil

function Menu.init(parent: Instance, shopToggle: () -> ())
	onShopToggle = shopToggle

	overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Parent = parent

	titleLabel = Theme.label(overlay, "AGARIO 2D", UDim2.fromScale(0.5, 0.3), UDim2.fromScale(0.6, 0.1))
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.capText(titleLabel, 64)
	subtitleLabel = Theme.label(
		overlay,
		"Eat orbs, avoid bigger cells, pop nothing green.",
		UDim2.fromScale(0.5, 0.39),
		UDim2.fromScale(0.6, 0.04)
	)
	subtitleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitleLabel.TextColor3 = Theme.MutedText
	Theme.capText(subtitleLabel, 22)

	bar = Theme.panel(parent, UDim2.fromScale(0.5, 0.985), UDim2.fromScale(0.34, 0.075), Vector2.new(0.5, 1))
	local play = Theme.button(bar, "Play", UDim2.fromScale(0.03, 0.14), UDim2.fromScale(0.29, 0.72), function()
		Remotes.Action:FireServer("play")
	end)
	play.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
	play.MouseLeave:Connect(function()
		play.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
	end)
	Theme.button(bar, "Spectate", UDim2.fromScale(0.355, 0.14), UDim2.fromScale(0.29, 0.72), function()
		Remotes.Action:FireServer("spectate")
		WorldState.status = "spectate"
		Menu.refresh()
	end)
	Theme.button(bar, "Shop", UDim2.fromScale(0.68, 0.14), UDim2.fromScale(0.29, 0.72), function()
		if onShopToggle then
			onShopToggle()
		end
	end)
	for _, b in bar:GetChildren() do
		if b:IsA("TextButton") then
			Theme.capText(b, 26)
		end
	end

	Menu.refresh()
end

-- Sync visibility with WorldState.status (called on every PlayerState event).
function Menu.refresh()
	local status = WorldState.status
	if status == "alive" then
		overlay.Visible = false
		bar.Visible = false
	elseif status == "spectate" then
		overlay.Visible = false
		bar.Visible = true
	else
		overlay.Visible = true
		bar.Visible = true
		if status == "dead" then
			titleLabel.Text = "You were eaten!"
			subtitleLabel.Text = "Press Play to try again."
		end
	end
end

return Menu
