--[[
	Menu - the center play card (Agma-style). A dim overlay grays the game; the
	HUD, leaderboard, minimap and chat stay visible around a centered card:
	logo, your skin preview + a Skins button, nickname, PLAY + spectate (eye),
	and Shop + Settings. Play asks the server to spawn; the overlay hides on the
	"spawned" event. While spectating the overlay is hidden (the pause ☰ is how
	you get back).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Skins)
local Accessories = require(Shared.Accessories)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Menu = {}

local overlay: Frame
local nameBox: TextBox
local skinPreview: Frame
local skinImage: ImageLabel
local previewAccessory: ImageLabel
local previewName: TextLabel
local deathLabel: TextLabel
local onShopToggle: (() -> ())? = nil
local onSettings: (() -> ())? = nil
local onHiscores: (() -> ())? = nil
local lastSkin = -1
local lastColor: Color3? = nil
local lastAccessory = -1

local function commas(n: number): string
	local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,")
	return (out:reverse():gsub("^,", ""))
end

local function submitName()
	local text = nameBox and nameBox.Text or ""
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text > 0 then
		Remotes.Action:FireServer("setname", text)
	end
end

function Menu.init(parent: Instance, shopToggle: () -> (), settingsToggle: () -> (), hiscoresToggle: () -> ())
	onShopToggle = shopToggle
	onSettings = settingsToggle
	onHiscores = hiscoresToggle

	overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = parent

	-- logo above the card
	local logo = Theme.label(overlay, "VIRUS IO", UDim2.fromScale(0.5, 0.17), UDim2.fromScale(0.5, 0.09))
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.capText(logo, 52)

	-- death summary (shown only after you were eaten)
	deathLabel = Theme.label(overlay, "", UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.6, 0.035))
	deathLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	deathLabel.TextColor3 = Theme.Danger
	deathLabel.Visible = false
	Theme.capText(deathLabel, 20)

	-- the card
	local card = Theme.panel(overlay, UDim2.fromScale(0.5, 0.54), UDim2.fromScale(0.26, 0.52), Vector2.new(0.5, 0.5))

	-- skin preview
	skinPreview = Instance.new("Frame")
	skinPreview.AnchorPoint = Vector2.new(0.5, 0)
	skinPreview.Position = UDim2.fromScale(0.5, 0.05)
	skinPreview.Size = UDim2.fromScale(0.32, 0.24)
	skinPreview.BackgroundColor3 = Theme.AccentColor
	skinPreview.BorderSizePixel = 0
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = skinPreview
	Theme.round(skinPreview, 999)
	Theme.stroke(skinPreview, Color3.new(1, 1, 1), 0.6)
	skinPreview.Parent = card
	skinImage = Instance.new("ImageLabel")
	skinImage.AnchorPoint = Vector2.new(0.5, 0.5)
	skinImage.Position = UDim2.fromScale(0.5, 0.5)
	skinImage.Size = UDim2.fromScale(1, 1)
	skinImage.BackgroundTransparency = 1
	skinImage.ScaleType = Enum.ScaleType.Crop
	skinImage.Visible = false
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0.5, 0)
	sc.Parent = skinImage
	skinImage.Parent = skinPreview

	-- your name shown ON the preview, live as you type (like your cell in-game)
	previewName = Instance.new("TextLabel")
	previewName.AnchorPoint = Vector2.new(0.5, 0.5)
	previewName.Position = UDim2.fromScale(0.5, 0.5)
	previewName.Size = UDim2.fromScale(1.5, 0.32)
	previewName.BackgroundTransparency = 1
	previewName.Font = Theme.Font
	previewName.Text = ""
	previewName.TextColor3 = Color3.new(1, 1, 1)
	previewName.TextScaled = true
	previewName.TextStrokeTransparency = 0.35
	previewName.ZIndex = 5
	Theme.capText(previewName, 22)
	previewName.Parent = skinPreview

	-- accessory layered over the skin in the preview (matches your in-game cell)
	previewAccessory = Instance.new("ImageLabel")
	previewAccessory.AnchorPoint = Vector2.new(0.5, 0.5)
	previewAccessory.Position = UDim2.fromScale(0.5, 0.5)
	previewAccessory.Size = UDim2.fromScale(1.5, 1.5)
	previewAccessory.BackgroundTransparency = 1
	previewAccessory.ScaleType = Enum.ScaleType.Fit
	previewAccessory.Visible = false
	previewAccessory.ZIndex = 4
	previewAccessory.Parent = skinPreview

	-- nickname
	nameBox = Instance.new("TextBox")
	nameBox.AnchorPoint = Vector2.new(0.5, 0)
	nameBox.Position = UDim2.fromScale(0.5, 0.42)
	nameBox.Size = UDim2.fromScale(0.86, 0.12)
	nameBox.BackgroundColor3 = Theme.Field
	nameBox.BackgroundTransparency = 0.1
	nameBox.BorderSizePixel = 0
	nameBox.Font = Theme.Font
	nameBox.PlaceholderText = "Nickname..."
	nameBox.Text = ""
	nameBox.TextColor3 = Theme.TextColor
	nameBox.PlaceholderColor3 = Theme.MutedText
	nameBox.TextScaled = false
	nameBox.TextSize = 20
	nameBox.ClearTextOnFocus = false
	Theme.round(nameBox, 8)
	Theme.stroke(nameBox)
	Theme.capText(nameBox, 22)
	nameBox.Parent = card
	nameBox.FocusLost:Connect(function(enter)
		if enter then
			submitName()
		end
	end)
	Remotes.Name.OnClientEvent:Connect(function(name)
		if typeof(name) == "string" and not nameBox:IsFocused() then
			nameBox.Text = name
		end
	end)
	-- mirror the nickname onto the preview circle in real time as you type
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		previewName.Text = nameBox.Text
	end)

	-- PLAY + spectate (eye)
	local play = Theme.outlineButton(card, "PLAY", UDim2.fromScale(0.04, 0.58), UDim2.fromScale(0.62, 0.13), Theme.Green, function()
		submitName()
		Remotes.Action:FireServer("play")
	end)
	Theme.capText(play, 26)
	local eye = Theme.button(card, "\u{1F441}", UDim2.fromScale(0.72, 0.58), UDim2.fromScale(0.24, 0.13), function()
		Remotes.Action:FireServer("spectate")
		WorldState.spectateSlot = nil -- start on the leader; the bar cycles from there
		WorldState.status = "spectate"
		Menu.refresh()
	end)
	Theme.capText(eye, 20)

	-- Shop | Settings | Scores (Shop pops in left of the card, Scores right)
	local shop = Theme.button(card, "\u{1F6D2} Shop", UDim2.fromScale(0.04, 0.76), UDim2.fromScale(0.29, 0.1), function()
		if onShopToggle then
			onShopToggle()
		end
	end)
	Theme.capText(shop, 14)
	local settings = Theme.button(card, "\u{2699}", UDim2.fromScale(0.355, 0.76), UDim2.fromScale(0.29, 0.1), function()
		if onSettings then
			onSettings()
		end
	end)
	Theme.capText(settings, 16)
	local scores = Theme.button(card, "\u{1F3C6} Scores", UDim2.fromScale(0.67, 0.76), UDim2.fromScale(0.29, 0.1), function()
		if onHiscores then
			onHiscores()
		end
	end)
	Theme.capText(scores, 14)

	-- ? help (below the card)
	local help = Theme.button(card, "?  Controls: Space split - W feed - F freeze", UDim2.fromScale(0.5, 0.9), UDim2.fromScale(0.94, 0.08), function() end)
	help.AnchorPoint = Vector2.new(0.5, 0)
	help.TextColor3 = Theme.MutedText
	Theme.capText(help, 12)

	Menu.refresh()
end

function Menu.refresh()
	local status = WorldState.status
	overlay.Visible = status == "menu" or status == "dead"
	if deathLabel then
		if status == "dead" then
			deathLabel.Text = "You were eaten!   Best mass: " .. commas(math.floor(WorldState.own.peakMass + 0.5))
			deathLabel.Visible = true
		else
			deathLabel.Visible = false
		end
	end
end

-- live-refresh the skin preview while the menu shows
function Menu.update(_dt: number)
	if not overlay.Visible then
		return
	end
	local mySlot = WorldState.mySlot or -1
	local skinId = WorldState.skinForSlot(mySlot)
	if skinId ~= lastSkin then
		lastSkin = skinId
		skinImage.Visible = skinId ~= 0 -- 0 = no skin; negative = the player Roblox avatar
		if skinId ~= 0 then
			skinImage.Image = Skins.thumb(skinId)
		end
	end
	-- keep the plain-cell colour live: the Color tab changes it with no skin change
	if skinId == 0 then
		local color = WorldState.colorForSlot(mySlot)
		if color ~= lastColor then
			lastColor = color
			skinPreview.BackgroundColor3 = color
		end
	end
	-- accessory layered over the preview (live when you equip one)
	local accId = WorldState.accessoryForSlot(mySlot)
	if accId ~= lastAccessory then
		lastAccessory = accId
		previewAccessory.Visible = accId ~= 0
		if accId ~= 0 then
			previewAccessory.Image = Accessories.thumb(accId)
			local ay, ascale = Accessories.placement(accId)
			previewAccessory.Position = UDim2.fromScale(0.5, ay)
			previewAccessory.Size = UDim2.fromScale(ascale, ascale)
		end
	end
end

return Menu
