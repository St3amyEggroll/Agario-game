--[[
	Menu - the play screen (shown while in the menu / dead / spectating).

	Renovated, minimal: a centered column - logo, your live SKIN preview with a
	big Skins button (skins are one tap from the front screen), name field, PLAY,
	and a Spectate link. Level + XP + coins sit top-right; Settings gear top-left.
	Play asks the server to spawn; the overlay hides on the "spawned" event.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local LevelCurve = require(Shared.Levels)
local Skins = require(Shared.Skins)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Menu = {}

local overlay: Frame
local nameBox: TextBox
local skinPreview: Frame
local skinImage: ImageLabel
local lvLabel: TextLabel
local xpFill: Frame
local coinLabel: TextLabel
local onShopToggle: (() -> ())? = nil
local onSettings: (() -> ())? = nil
local lastSkin, lastLv, lastCoins = -1, "", ""

local function submitName()
	local text = nameBox and nameBox.Text or ""
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text > 0 then
		Remotes.Action:FireServer("setname", text)
	end
end

function Menu.init(parent: Instance, shopToggle: () -> (), settingsToggle: () -> ())
	onShopToggle = shopToggle
	onSettings = settingsToggle

	overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Parent = parent

	-- settings gear, top-left
	local gear = Theme.button(overlay, "\u{2699}", UDim2.fromScale(0.02, 0.03), UDim2.fromScale(0.05, 0.055), function()
		if onSettings then
			onSettings()
		end
	end)
	Theme.capText(gear, 22)

	-- profile, top-right: Lv N + XP bar + coins
	local prof = Instance.new("Frame")
	prof.AnchorPoint = Vector2.new(1, 0)
	prof.Position = UDim2.fromScale(0.98, 0.035)
	prof.Size = UDim2.fromScale(0.22, 0.05)
	prof.BackgroundTransparency = 1
	prof.Parent = overlay
	lvLabel = Theme.mono(prof, "Lv 1", UDim2.fromScale(0, 0), UDim2.fromScale(0.28, 1))
	lvLabel.TextColor3 = Theme.AccentColor
	lvLabel.TextXAlignment = Enum.TextXAlignment.Right
	Theme.capText(lvLabel, 16)
	local xpTrack = Instance.new("Frame")
	xpTrack.AnchorPoint = Vector2.new(0, 0.5)
	xpTrack.Position = UDim2.fromScale(0.31, 0.5)
	xpTrack.Size = UDim2.fromScale(0.4, 0.3)
	xpTrack.BackgroundColor3 = Theme.Field
	xpTrack.BorderSizePixel = 0
	Theme.round(xpTrack, 5)
	Theme.stroke(xpTrack)
	xpTrack.Parent = prof
	xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Theme.AccentColor
	xpFill.BorderSizePixel = 0
	Theme.round(xpFill, 5)
	xpFill.Parent = xpTrack
	coinLabel = Theme.mono(prof, "0", UDim2.fromScale(0.74, 0), UDim2.fromScale(0.26, 1))
	coinLabel.TextColor3 = Theme.Gold
	coinLabel.TextXAlignment = Enum.TextXAlignment.Right
	Theme.capText(coinLabel, 16)

	-- logo
	local logo = Theme.label(overlay, "AGARIO 2D", UDim2.fromScale(0.5, 0.15), UDim2.fromScale(0.6, 0.1))
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.capText(logo, 60)

	-- SKIN preview (centerpiece) + Skins button
	skinPreview = Instance.new("Frame")
	skinPreview.AnchorPoint = Vector2.new(0.5, 0.5)
	skinPreview.Position = UDim2.fromScale(0.5, 0.35)
	skinPreview.Size = UDim2.fromScale(0.14, 0.14)
	skinPreview.BackgroundColor3 = Theme.AccentColor
	skinPreview.BorderSizePixel = 0
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = skinPreview
	Theme.round(skinPreview, 999)
	Theme.stroke(skinPreview, Color3.new(1, 1, 1), 0.7)
	skinPreview.Parent = overlay
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

	local skinsBtn = Theme.button(overlay, "\u{1F3A8} Skins", UDim2.fromScale(0.5, 0.49), UDim2.fromScale(0.2, 0.06), function()
		if onShopToggle then
			onShopToggle()
		end
	end)
	skinsBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.capText(skinsBtn, 18)

	-- name entry (prefilled from the server via the Name remote)
	nameBox = Instance.new("TextBox")
	nameBox.AnchorPoint = Vector2.new(0.5, 0.5)
	nameBox.Position = UDim2.fromScale(0.5, 0.59)
	nameBox.Size = UDim2.fromScale(0.26, 0.06)
	nameBox.BackgroundColor3 = Theme.Field
	nameBox.BackgroundTransparency = 0.15
	nameBox.BorderSizePixel = 0
	nameBox.Font = Theme.Font
	nameBox.PlaceholderText = "Enter a name..."
	nameBox.Text = ""
	nameBox.TextColor3 = Theme.TextColor
	nameBox.PlaceholderColor3 = Theme.MutedText
	nameBox.TextScaled = false
	nameBox.TextSize = 20
	nameBox.ClearTextOnFocus = false
	Theme.round(nameBox, 9)
	Theme.stroke(nameBox)
	Theme.capText(nameBox, 22)
	nameBox.Parent = overlay
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

	-- PLAY
	local play = Theme.outlineButton(overlay, "PLAY", UDim2.fromScale(0.5, 0.7), UDim2.fromScale(0.26, 0.08), Theme.Green, function()
		submitName()
		Remotes.Action:FireServer("play")
	end)
	play.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.capText(play, 30)

	-- Spectate (secondary)
	local spectate = Theme.button(overlay, "Spectate a leader", UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.2, 0.05), function()
		Remotes.Action:FireServer("spectate")
		WorldState.status = "spectate"
		Menu.refresh()
	end)
	spectate.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.capText(spectate, 16)

	Menu.refresh()
end

-- Sync overlay visibility with WorldState.status (called on every PlayerState
-- event). Shown in the menu / after death; hidden while alive OR spectating (in
-- spectate you watch the leader and use the ☰ pause menu to get back).
function Menu.refresh()
	local status = WorldState.status
	overlay.Visible = status == "menu" or status == "dead"
end

-- Live-refresh the skin preview + level + coins while the menu is showing.
function Menu.update(_dt: number)
	if not overlay.Visible then
		return
	end
	local skinId = WorldState.skinForSlot(WorldState.mySlot or -1)
	if skinId ~= lastSkin then
		lastSkin = skinId
		if skinId > 0 then
			skinImage.Image = Skins.thumb(skinId)
			skinImage.Visible = true
		else
			skinImage.Visible = false
			skinPreview.BackgroundColor3 = WorldState.colorForSlot(WorldState.mySlot or -1)
		end
	end
	local level, into, need = LevelCurve.progress(WorldState.xp or 0)
	local lvText = "Lv " .. level
	if lvText ~= lastLv then
		lastLv = lvText
		lvLabel.Text = lvText
		xpFill.Size = UDim2.fromScale(need > 0 and math.clamp(into / need, 0, 1) or 1, 1)
	end
	local coinText = tostring(WorldState.coins or 0)
	if coinText ~= lastCoins then
		lastCoins = coinText
		coinLabel.Text = coinText
	end
end

return Menu
