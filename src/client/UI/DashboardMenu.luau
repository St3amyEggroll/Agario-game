-- DashboardMenu - main menu rebuilt from the user-provided Agar.io dashboard reference.
-- Every displayed icon comes from a transparent crop of that screenshot.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Skins)
local Accessories = require(Shared.Accessories)
local LevelCurve = require(Shared.Levels)
local Assets = require(script.Parent.DashboardAssets)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)
local Sounds = require(script.Parent.Parent.Sounds)

local Menu = {}

local overlay: Frame
local dashboard: Frame
local profilePanel: Frame
local playButton: TextButton
local playLabel: TextLabel
local spectateButton: TextButton
local nameBox: TextBox
local skinPreview: Frame
local skinImage: ImageLabel
local previewOverlays: { ImageLabel } = {}
local levelLabel: TextLabel
local xpText: TextLabel
local xpFill: Frame
local coinsLabel: TextLabel
local profileScoreLabel: TextLabel
local highScoreLabel: TextLabel
local forceOpen = false
local panelOpen = false
local onShopToggle: (() -> ())? = nil
local onSettingsToggle: (() -> ())? = nil
local onScoresToggle: (() -> ())? = nil
local lastSkin = math.huge
local lastColor: Color3? = nil
local lastOverlayKey = ""

local NAVY = Color3.fromRGB(5, 13, 22)
local PANEL = Color3.fromRGB(14, 24, 36)
local PANEL_2 = Color3.fromRGB(18, 29, 43)
local BORDER = Color3.fromRGB(40, 54, 70)
local TEXT = Color3.fromRGB(244, 246, 250)
local MUTED = Color3.fromRGB(184, 191, 204)
local PURPLE = Color3.fromRGB(120, 66, 246)
local PURPLE_LIGHT = Color3.fromRGB(164, 100, 255)

local function commas(value: number): string
	local number = math.max(0, math.floor(value + 0.5))
	local out = tostring(number):reverse():gsub("(%d%d%d)", "%1,")
	return (out:reverse():gsub("^,", ""))
end

local function round(object: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = object
end

local function outline(object: GuiObject, color: Color3?, transparency: number?): UIStroke
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = color or BORDER
	edge.Thickness = 1
	edge.Transparency = transparency or 0.08
	edge.Parent = object
	return edge
end

local function gradient(object: GuiObject, colors: { Color3 }, rotation: number?): UIGradient
	local points = {}
	for index, color in colors do
		points[index] = ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color)
	end
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(points)
	fill.Rotation = rotation or 0
	fill.Parent = object
	return fill
end

local function panel(parent: Instance, position: UDim2, size: UDim2, radius: number?): Frame
	local frame = Instance.new("Frame")
	frame.Position = position
	frame.Size = size
	frame.BackgroundColor3 = PANEL
	frame.BorderSizePixel = 0
	round(frame, radius or 18)
	outline(frame)
	gradient(frame, {
		Color3.fromRGB(24, 34, 47),
		Color3.fromRGB(10, 19, 31),
	}, 115)
	frame.Parent = parent
	return frame
end

local function textLabel(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3?, alignment: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = text
	label.TextColor3 = color or TEXT
	label.TextSize = textSize
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function image(parent: Instance, imageId: string, position: UDim2, size: UDim2): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Position = position
	icon.Size = size
	icon.BackgroundTransparency = 1
	icon.Image = imageId
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Active = false
	icon.Parent = parent
	return icon
end

local function clickButton(parent: Instance, name: string, position: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = PANEL_2
	button.BackgroundTransparency = 0.12
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	round(button, 12)
	local edge = outline(button)
	button.Parent = parent
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.14), {
			BackgroundTransparency = 0,
			BackgroundColor3 = Color3.fromRGB(22, 32, 47),
		}):Play()
		TweenService:Create(edge, TweenInfo.new(0.14), {
			Color = Color3.fromRGB(91, 67, 145),
			Transparency = 0,
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.14), {
			BackgroundTransparency = 0.12,
			BackgroundColor3 = PANEL_2,
		}):Play()
		TweenService:Create(edge, TweenInfo.new(0.14), {
			Color = BORDER,
			Transparency = 0.08,
		}):Play()
	end)
	button.Activated:Connect(function()
		Sounds.play("click")
		onClick()
	end)
	return button
end

local function navButton(labelText: string, iconId: string, y: number, active: boolean, callback: () -> ())
	local button = clickButton(dashboard, "Nav" .. labelText:gsub("%s+", ""), UDim2.fromOffset(28, y), UDim2.fromOffset(174, 66), callback)
	button.BackgroundTransparency = active and 0 or 1
	button.BackgroundColor3 = active and Color3.new(1, 1, 1) or NAVY
	local edge = button:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = active and Color3.fromRGB(120, 65, 250) or NAVY
		edge.Transparency = active and 0 or 1
	end
	if active then
		gradient(button, {
			Color3.fromRGB(132, 73, 255),
			Color3.fromRGB(74, 31, 214),
		}, 10)
	end
	image(button, iconId, UDim2.fromOffset(18, 17), UDim2.fromOffset(32, 32))
	local navTextSize = labelText == "Leaderboards" and 15 or 18
	local label = textLabel(button, labelText, UDim2.fromOffset(62, 0), UDim2.new(1, -72, 1, 0), navTextSize)
	label.Font = Enum.Font.GothamMedium
	if not active then
		button.MouseEnter:Connect(function()
			TweenService:Create(label, TweenInfo.new(0.14), { Position = UDim2.fromOffset(66, 0) }):Play()
		end)
		button.MouseLeave:Connect(function()
			TweenService:Create(label, TweenInfo.new(0.14), { Position = UDim2.fromOffset(62, 0) }):Play()
			TweenService:Create(button, TweenInfo.new(0.14), { BackgroundTransparency = 1, BackgroundColor3 = NAVY }):Play()
			if edge then
				TweenService:Create(edge, TweenInfo.new(0.14), { Transparency = 1, Color = NAVY }):Play()
			end
		end)
	end
	return button
end

local function toggle(parent: Instance, y: number, initial: boolean, changed: (boolean) -> ())
	local on = initial
	local track = Instance.new("TextButton")
	track.Position = UDim2.fromOffset(624, y)
	track.Size = UDim2.fromOffset(58, 30)
	track.BackgroundColor3 = Color3.fromRGB(31, 43, 59)
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
	round(track, 999)
	track.Parent = parent
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(22, 22)
	knob.BackgroundColor3 = Color3.fromRGB(248, 249, 252)
	knob.BorderSizePixel = 0
	round(knob, 999)
	knob.Parent = track
	local function render(animated: boolean)
		local info = TweenInfo.new(animated and 0.16 or 0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(track, info, { BackgroundColor3 = on and PURPLE or Color3.fromRGB(31, 43, 59) }):Play()
		TweenService:Create(knob, info, { Position = UDim2.new(on and 1 or 0, on and -16 or 16, 0.5, 0) }):Play()
	end
	render(false)
	track.Activated:Connect(function()
		on = not on
		Sounds.play("click")
		render(true)
		changed(on)
	end)
end

local function modeCard(parent: Instance, x: number, titleText: string, subtitle: string, iconId: string, selected: boolean)
	local button = clickButton(parent, "Mode" .. titleText, UDim2.fromOffset(x, 70), UDim2.fromOffset(150, 176), function() end)
	button.BackgroundColor3 = Color3.fromRGB(13, 24, 37)
	button.BackgroundTransparency = 0.05
	local edge = button:FindFirstChildOfClass("UIStroke")
	if edge then
		edge.Color = selected and PURPLE_LIGHT or BORDER
		edge.Thickness = selected and 2 or 1
		edge.Transparency = selected and 0 or 0.08
	end
	image(button, iconId, UDim2.fromOffset(38, 18), UDim2.fromOffset(74, 74))
	local title = textLabel(button, titleText, UDim2.fromOffset(8, 103), UDim2.new(1, -16, 0, 30), 21, TEXT, Enum.TextXAlignment.Center)
	title.Font = Enum.Font.GothamBold
	textLabel(button, subtitle, UDim2.fromOffset(8, 137), UDim2.new(1, -16, 0, 23), 14, MUTED, Enum.TextXAlignment.Center)
end

local function statCard(parent: Instance, x: number, iconId: string, value: string, caption: string): TextLabel
	local card = panel(parent, UDim2.fromOffset(x, 78), UDim2.fromOffset(150, 132), 12)
	card.BackgroundColor3 = Color3.fromRGB(13, 23, 35)
	image(card, iconId, UDim2.fromOffset(56, 14), UDim2.fromOffset(38, 38))
	local valueLabel = textLabel(card, value, UDim2.fromOffset(8, 53), UDim2.new(1, -16, 0, 36), 30, TEXT, Enum.TextXAlignment.Center)
	valueLabel.Font = Enum.Font.GothamBold
	textLabel(card, caption, UDim2.fromOffset(6, 93), UDim2.new(1, -12, 0, 24), 14, MUTED, Enum.TextXAlignment.Center)
	return valueLabel
end

local function submitName()
	if not nameBox then
		return
	end
	local value = nameBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
	if #value > 0 then
		Remotes.Action:FireServer("setname", value)
	end
end

function Menu.init(parent: Instance, shopToggle: () -> (), settingsToggle: () -> (), scoresToggle: () -> ())
	onShopToggle = shopToggle
	onSettingsToggle = settingsToggle
	onScoresToggle = scoresToggle

	overlay = Instance.new("Frame")
	overlay.Name = "ReferenceDashboardOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(1, 1, 1)
	overlay.BorderSizePixel = 0
	gradient(overlay, {
		Color3.fromRGB(2, 10, 18),
		Color3.fromRGB(4, 12, 21),
		Color3.fromRGB(1, 7, 13),
	}, 20)
	overlay.Parent = parent

	dashboard = Instance.new("Frame")
	dashboard.Name = "ReferenceDashboard"
	dashboard.AnchorPoint = Vector2.new(0.5, 0.5)
	dashboard.Position = UDim2.fromScale(0.5, 0.5)
	dashboard.BackgroundTransparency = 1
	dashboard.BorderSizePixel = 0
	dashboard.Parent = overlay
	Theme.responsiveSize(dashboard, Vector2.new(1500, 920), Vector2.new(18, 18))

	local sidebar = Instance.new("Frame")
	sidebar.Size = UDim2.fromOffset(220, 920)
	sidebar.BackgroundColor3 = Color3.fromRGB(4, 13, 22)
	sidebar.BackgroundTransparency = 0.05
	sidebar.BorderSizePixel = 0
	sidebar.Parent = dashboard
	local sideLine = Instance.new("Frame")
	sideLine.Position = UDim2.new(1, -1, 0, 0)
	sideLine.Size = UDim2.fromOffset(1, 920)
	sideLine.BackgroundColor3 = Color3.fromRGB(27, 40, 55)
	sideLine.BorderSizePixel = 0
	sideLine.Parent = sidebar

	local logo = textLabel(sidebar, "Agar.io", UDim2.fromOffset(32, 24), UDim2.fromOffset(160, 58), 41)
	logo.Font = Enum.Font.GothamBold
	local logoDot = Instance.new("Frame")
	logoDot.Position = UDim2.fromOffset(174, 35)
	logoDot.Size = UDim2.fromOffset(8, 8)
	logoDot.BackgroundColor3 = PURPLE_LIGHT
	logoDot.BorderSizePixel = 0
	round(logoDot, 999)
	logoDot.Parent = sidebar

	navButton("Home", Assets.NavHome, 110, true, function() end)
	navButton("Shop", Assets.NavShop, 190, false, function()
		if onShopToggle then onShopToggle() end
	end)
	navButton("Skins", Assets.NavSkins, 270, false, function()
		if onShopToggle then onShopToggle() end
	end)
	navButton("Stats", Assets.NavStats, 350, false, function()
		if onScoresToggle then onScoresToggle() end
	end)
	navButton("Leaderboards", Assets.NavScores, 430, false, function()
		if onScoresToggle then onScoresToggle() end
	end)
	navButton("Friends", Assets.NavFriends, 510, false, function() end)
	navButton("Settings", Assets.NavSettings, 590, false, function()
		if onSettingsToggle then onSettingsToggle() end
	end)

	local signOut = clickButton(dashboard, "SignOutButton", UDim2.fromOffset(28, 828), UDim2.fromOffset(174, 58), function()
		if WorldState.status == "alive" then
			Remotes.Action:FireServer("tomenu")
		end
	end)
	image(signOut, Assets.NavExit, UDim2.fromOffset(18, 14), UDim2.fromOffset(30, 30))
	local signOutText = textLabel(signOut, "Sign Out", UDim2.fromOffset(60, 0), UDim2.new(1, -70, 1, 0), 17)
	signOutText.Font = Enum.Font.GothamMedium
	textLabel(dashboard, "© Agar.io 2025   •   All Rights Reserved", UDim2.fromOffset(28, 892), UDim2.fromOffset(190, 20), 11, Color3.fromRGB(122, 132, 148))

	profilePanel = panel(dashboard, UDim2.fromOffset(250, 80), UDim2.fromOffset(480, 820), 20)

	skinPreview = Instance.new("Frame")
	skinPreview.Position = UDim2.fromOffset(115, 30)
	skinPreview.Size = UDim2.fromOffset(250, 250)
	skinPreview.BackgroundColor3 = Color3.fromRGB(65, 187, 111)
	skinPreview.BorderSizePixel = 0
	round(skinPreview, 999)
	local skinEdge = outline(skinPreview, PURPLE_LIGHT, 0)
	skinEdge.Thickness = 2
	skinPreview.Parent = profilePanel

	skinImage = image(skinPreview, "", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	skinImage.ScaleType = Enum.ScaleType.Crop
	skinImage.Visible = false
	round(skinImage, 999)

	for _ = 1, Config.MaxOverlays do
		local layer = image(skinPreview, "", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1.5, 1.5))
		layer.AnchorPoint = Vector2.new(0.5, 0.5)
		layer.Visible = false
		layer.ZIndex = 4
		previewOverlays[#previewOverlays + 1] = layer
	end

	local levelLineLeft = Instance.new("Frame")
	levelLineLeft.Position = UDim2.fromOffset(145, 304)
	levelLineLeft.Size = UDim2.fromOffset(55, 2)
	levelLineLeft.BackgroundColor3 = Color3.fromRGB(57, 70, 87)
	levelLineLeft.BorderSizePixel = 0
	levelLineLeft.Parent = profilePanel
	local levelLineRight = levelLineLeft:Clone()
	levelLineRight.Position = UDim2.fromOffset(280, 304)
	levelLineRight.Parent = profilePanel
	local levelBadge = Instance.new("Frame")
	levelBadge.Position = UDim2.fromOffset(212, 282)
	levelBadge.Size = UDim2.fromOffset(56, 48)
	levelBadge.BackgroundColor3 = Color3.fromRGB(12, 18, 31)
	levelBadge.BorderSizePixel = 0
	round(levelBadge, 9)
	local levelEdge = outline(levelBadge, PURPLE_LIGHT, 0)
	levelEdge.Thickness = 2
	levelBadge.Parent = profilePanel
	levelLabel = textLabel(levelBadge, "1", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 28, TEXT, Enum.TextXAlignment.Center)
	levelLabel.Font = Enum.Font.GothamMedium

	nameBox = Instance.new("TextBox")
	nameBox.Position = UDim2.fromOffset(85, 345)
	nameBox.Size = UDim2.fromOffset(310, 56)
	nameBox.BackgroundTransparency = 1
	nameBox.BorderSizePixel = 0
	nameBox.Font = Enum.Font.GothamBold
	nameBox.Text = Players.LocalPlayer.DisplayName
	nameBox.PlaceholderText = "Player"
	nameBox.TextColor3 = TEXT
	nameBox.TextSize = 32
	nameBox.ClearTextOnFocus = false
	nameBox.TextXAlignment = Enum.TextXAlignment.Center
	nameBox.Parent = profilePanel
	image(nameBox, Assets.Edit, UDim2.new(1, -47, 0.5, -18), UDim2.fromOffset(36, 36))
	nameBox.FocusLost:Connect(function(enter)
		if enter then submitName() end
	end)
	Remotes.Name.OnClientEvent:Connect(function(value)
		if typeof(value) == "string" and not nameBox:IsFocused() then
			nameBox.Text = value
		end
	end)

	local scorePill = panel(profilePanel, UDim2.fromOffset(165, 410), UDim2.fromOffset(150, 54), 10)
	profileScoreLabel = textLabel(scorePill, "#0", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 23, TEXT, Enum.TextXAlignment.Center)
	profileScoreLabel.Font = Enum.Font.GothamBold

	local xpTrack = Instance.new("Frame")
	xpTrack.Position = UDim2.fromOffset(45, 486)
	xpTrack.Size = UDim2.fromOffset(390, 20)
	xpTrack.BackgroundColor3 = Color3.fromRGB(4, 10, 17)
	xpTrack.BorderSizePixel = 0
	xpTrack.ClipsDescendants = true
	round(xpTrack, 999)
	outline(xpTrack)
	xpTrack.Parent = profilePanel
	xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = PURPLE
	xpFill.BorderSizePixel = 0
	round(xpFill, 999)
	gradient(xpFill, { PURPLE_LIGHT, Color3.fromRGB(91, 42, 225) }, 0)
	xpFill.Parent = xpTrack
	xpText = textLabel(profilePanel, "0 / 1,000 XP", UDim2.fromOffset(45, 513), UDim2.fromOffset(390, 28), 15, MUTED, Enum.TextXAlignment.Center)

	playButton = clickButton(profilePanel, "PlayButton", UDim2.fromOffset(35, 565), UDim2.fromOffset(410, 90), function()
		if WorldState.status == "alive" then
			forceOpen = false
			Menu.refresh()
		else
			submitName()
			Remotes.Action:FireServer("play")
		end
	end)
	playButton.BackgroundColor3 = Color3.new(1, 1, 1)
	playButton.BackgroundTransparency = 0
	local playGradient = gradient(playButton, {
		Color3.fromRGB(149, 88, 255),
		Color3.fromRGB(82, 35, 225),
	}, 8)
	local playEdge = playButton:FindFirstChildOfClass("UIStroke")
	if playEdge then
		playEdge.Color = PURPLE_LIGHT
		playEdge.Transparency = 0
	end
	playLabel = textLabel(playButton, "Play", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 32, TEXT, Enum.TextXAlignment.Center)
	playLabel.Font = Enum.Font.GothamMedium
	playButton.MouseEnter:Connect(function()
		TweenService:Create(playGradient, TweenInfo.new(0.18), { Rotation = -8 }):Play()
	end)
	playButton.MouseLeave:Connect(function()
		TweenService:Create(playGradient, TweenInfo.new(0.18), { Rotation = 8 }):Play()
	end)

	spectateButton = clickButton(profilePanel, "SpectateButton", UDim2.fromOffset(35, 675), UDim2.fromOffset(410, 70), function()
		Remotes.Action:FireServer("spectate")
		WorldState.spectateSlot = nil
		WorldState.status = "spectate"
		Menu.refresh()
	end)
	local spectateEdge = spectateButton:FindFirstChildOfClass("UIStroke")
	if spectateEdge then
		spectateEdge.Color = PURPLE_LIGHT
		spectateEdge.Thickness = 2
		spectateEdge.Transparency = 0
	end
	image(spectateButton, Assets.ActionEye, UDim2.fromOffset(125, 18), UDim2.fromOffset(34, 34))
	local spectateText = textLabel(spectateButton, "Spectate", UDim2.fromOffset(165, 0), UDim2.fromOffset(150, 70), 22)
	spectateText.Font = Enum.Font.GothamMedium

	local privateButton = clickButton(profilePanel, "PrivatePartyButton", UDim2.fromOffset(35, 760), UDim2.fromOffset(410, 60), function() end)
	image(privateButton, Assets.ActionParty, UDim2.fromOffset(118, 15), UDim2.fromOffset(30, 30))
	local privateText = textLabel(privateButton, "Private Party", UDim2.fromOffset(158, 0), UDim2.fromOffset(190, 60), 20)
	privateText.Font = Enum.Font.GothamMedium

	local wallet = panel(dashboard, UDim2.fromOffset(1080, 18), UDim2.fromOffset(190, 58), 13)
	image(wallet, Assets.Coin, UDim2.fromOffset(14, 10), UDim2.fromOffset(38, 38))
	coinsLabel = textLabel(wallet, "0", UDim2.fromOffset(61, 0), UDim2.fromOffset(75, 58), 20)
	coinsLabel.Font = Enum.Font.GothamBold
	image(wallet, Assets.Plus, UDim2.fromOffset(145, 14), UDim2.fromOffset(30, 30))
	local rankBadge = panel(dashboard, UDim2.fromOffset(1285, 18), UDim2.fromOffset(190, 58), 13)
	image(rankBadge, Assets.Rank, UDim2.fromOffset(14, 9), UDim2.fromOffset(40, 40))
	local rankText = textLabel(rankBadge, "Diamond I", UDim2.fromOffset(61, 0), UDim2.fromOffset(115, 58), 19)
	rankText.Font = Enum.Font.GothamMedium

	local modesPanel = panel(dashboard, UDim2.fromOffset(755, 80), UDim2.fromOffset(720, 300), 18)
	local modesTitle = textLabel(modesPanel, "Game Modes", UDim2.fromOffset(24, 16), UDim2.fromOffset(300, 38), 24)
	modesTitle.Font = Enum.Font.GothamBold
	modeCard(modesPanel, 20, "FFA", "Free for All", Assets.ModeFFA, true)
	modeCard(modesPanel, 190, "Teams", "Team Play", Assets.ModeTeams, false)
	modeCard(modesPanel, 360, "Experimental", "Try New Things", Assets.ModeExperimental, false)
	modeCard(modesPanel, 530, "Party", "Play with Friends", Assets.ModeParty, false)
	textLabel(modesPanel, "Grow your cell, eat others, and become the biggest!", UDim2.fromOffset(20, 256), UDim2.fromOffset(680, 28), 15, MUTED, Enum.TextXAlignment.Center)

	local statsPanel = panel(dashboard, UDim2.fromOffset(755, 400), UDim2.fromOffset(720, 240), 18)
	local statsTitle = textLabel(statsPanel, "Stats Overview", UDim2.fromOffset(24, 16), UDim2.fromOffset(300, 38), 24)
	statsTitle.Font = Enum.Font.GothamBold
	local viewAll = clickButton(statsPanel, "ViewAllScores", UDim2.fromOffset(592, 14), UDim2.fromOffset(104, 38), function()
		if onScoresToggle then onScoresToggle() end
	end)
	viewAll.BackgroundTransparency = 1
	viewAll.Text = "View All  →"
	viewAll.TextColor3 = TEXT
	viewAll.Font = Enum.Font.Gotham
	viewAll.TextSize = 14
	highScoreLabel = statCard(statsPanel, 20, Assets.StatCrown, "0", "High Score")
	statCard(statsPanel, 190, Assets.StatStar, "0", "Games Played")
	statCard(statsPanel, 360, Assets.StatTarget, "0%", "Win Rate")
	statCard(statsPanel, 530, Assets.StatFire, "0", "Top 3 Finishes")

	local quickPanel = panel(dashboard, UDim2.fromOffset(755, 660), UDim2.fromOffset(720, 240), 18)
	local quickTitle = textLabel(quickPanel, "Quick Settings", UDim2.fromOffset(24, 15), UDim2.fromOffset(300, 40), 24)
	quickTitle.Font = Enum.Font.GothamBold
	local function quickRow(iconId: string, titleText: string, y: number)
		image(quickPanel, iconId, UDim2.fromOffset(24, y), UDim2.fromOffset(30, 30))
		local rowLabel = textLabel(quickPanel, titleText, UDim2.fromOffset(66, y - 1), UDim2.fromOffset(420, 32), 17)
		rowLabel.Font = Enum.Font.Gotham
	end
	quickRow(Assets.QuickSound, "Sound Effects", 61)
	quickRow(Assets.QuickMusic, "Background Music", 105)
	quickRow(Assets.QuickMass, "Show Mass", 149)
	quickRow(Assets.QuickTheme, "Dark Theme", 193)
	toggle(quickPanel, 61, Sounds.isEnabled(), function(on)
		Sounds.setEnabled(on)
	end)
	toggle(quickPanel, 105, false, function() end)
	toggle(quickPanel, 149, false, function() end)
	local themeSelect = clickButton(quickPanel, "ThemeSelect", UDim2.fromOffset(548, 188), UDim2.fromOffset(134, 38), function() end)
	themeSelect.Text = "On     ⌄"
	themeSelect.TextColor3 = TEXT
	themeSelect.Font = Enum.Font.Gotham
	themeSelect.TextSize = 16

	Menu.refresh()
end

function Menu.openInGame()
	forceOpen = true
	Menu.refresh()
end

function Menu.toggleInGame()
	if WorldState.status ~= "alive" then
		return
	end
	forceOpen = not forceOpen
	Menu.refresh()
end

function Menu.isVisible(): boolean
	return overlay ~= nil and overlay.Visible
end

function Menu.setPanelOpen(open: boolean)
	if panelOpen ~= open then
		panelOpen = open
		Menu.refresh()
	end
end

function Menu.refresh()
	if not overlay then
		return
	end
	local status = WorldState.status
	if status ~= "alive" then
		forceOpen = false
	end
	overlay.Visible = status == "menu" or status == "dead" or forceOpen or panelOpen
	dashboard.Visible = overlay.Visible and not panelOpen
	if playLabel then
		playLabel.Text = status == "alive" and "Resume" or "Play"
	end
	if spectateButton then
		spectateButton.Visible = status ~= "alive"
	end
end

function Menu.update(_dt: number)
	if not overlay or not overlay.Visible then
		return
	end
	local level, into, need = LevelCurve.progress(WorldState.xp or 0)
	local progress = need > 0 and math.clamp(into / need, 0, 1) or 1
	levelLabel.Text = tostring(level)
	xpFill.Size = UDim2.fromScale(progress, 1)
	xpText.Text = "#" .. commas(into) .. " / " .. commas(need) .. " XP"
	coinsLabel.Text = commas(WorldState.coins or 0)
	local best = math.floor((WorldState.own.peakMass or 0) + 0.5)
	profileScoreLabel.Text = "#" .. commas(best)
	highScoreLabel.Text = commas(best)

	local slot = WorldState.mySlot or -1
	local skinId = WorldState.skinForSlot(slot)
	local overlays = WorldState.overlaysForSlot(slot)
	local avatarId: number? = nil
	for _, id in overlays do
		if id < 0 then
			avatarId = id
			break
		end
	end
	local visualSkin = avatarId or skinId
	if visualSkin ~= lastSkin then
		lastSkin = visualSkin
		skinImage.Visible = visualSkin ~= 0
		if visualSkin ~= 0 then
			skinImage.Image = Skins.thumb(visualSkin)
			skinImage.ScaleType = Enum.ScaleType.Crop
		end
	end
	if skinId == 0 and not avatarId then
		local color = WorldState.colorForSlot(slot)
		if color ~= lastColor then
			lastColor = color
			skinPreview.BackgroundColor3 = color
		end
	end

	local overlayKey = table.concat(overlays, ",")
	if overlayKey ~= lastOverlayKey then
		lastOverlayKey = overlayKey
		local accessoryIds = {}
		for _, id in overlays do
			if id > 0 then
				table.insert(accessoryIds, id)
			end
		end
		table.sort(accessoryIds)
		for index, layer in previewOverlays do
			local id = accessoryIds[index]
			if id then
				layer.Image = Accessories.thumb(id)
				local x, y, scale = Accessories.placement(id)
				layer.Position = UDim2.fromScale(x, y)
				layer.Size = UDim2.fromScale(scale, scale)
				layer.Visible = true
			else
				layer.Visible = false
			end
		end
	end
end

return Menu
