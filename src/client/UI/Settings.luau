--[[
	Settings - keybind remapping panel (opened with the top-left menu button or
	the Menu key). Click a key button, press any key, done: Input.captureNext
	intercepts the next keypress, rebinds, persists via DataStore, and the
	onBindsChanged callback refreshes the labels here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.IconAssets)
local Input = require(script.Parent.Parent.Input)
local Sounds = require(script.Parent.Parent.Sounds)
local Renderer = require(script.Parent.Parent.Renderer)
local Minimap = require(script.Parent.Minimap)
local ColorPicker = require(script.Parent.ColorPicker)

-- map background presets (first is the default blackish)
local BG_PRESETS = {
	Color3.fromRGB(18, 20, 26), -- default
	Color3.fromRGB(6, 7, 10), -- near black
	Color3.fromRGB(12, 18, 34), -- navy
	Color3.fromRGB(12, 26, 20), -- forest
	Color3.fromRGB(26, 15, 30), -- plum
	Color3.fromRGB(30, 18, 18), -- maroon
	Color3.fromRGB(20, 24, 30), -- slate
	Color3.fromRGB(44, 48, 56), -- light gray
}

-- fixed display order + friendly names
local ROWS = {
	{ "Split", "Split" },
	{ "MultiSplit", "Double Split" },
	{ "TripleSplit", "Triple Split" },
	{ "Feed", "Feed (eject mass)" },
	{ "Freeze", "Freeze cells (toggle)" },
	{ "Respawn", "Respawn (instant)" },
	{ "ToMenu", "Leave to menu" },
	{ "FixedMouse", "Fixed Mouse (toggle)" },
	{ "Menu", "Open menu" },
}

local Settings = {}

local panel: Frame
local keyButtons: { [string]: TextButton } = {}
local currentBg = BG_PRESETS[1] -- last-applied map background (world + minimap); seeds the picker

local function refreshLabels()
	for action, button in keyButtons do
		local key = Input.binds[action]
		button.Text = key and key ~= "" and key or "Unbound"
	end
end

local function settingIcon(parent: Instance, imageId: string, y: number): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0.055, y + 0.023)
	icon.Size = UDim2.fromScale(0.04, 0.04)
	icon.BackgroundTransparency = 1
	icon.Image = imageId
	icon.ImageColor3 = Color3.fromRGB(244, 245, 249)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 3
	icon.Parent = parent
	return icon
end

local function toggleSwitch(parent: Instance, y: number, initial: boolean, changed: (boolean) -> ()): TextButton
	local on = initial
	local track = Instance.new("TextButton")
	track.Name = "ToggleSwitch"
	track.Position = UDim2.fromScale(0.83, y)
	track.Size = UDim2.fromScale(0.12, 0.046)
	track.BackgroundColor3 = Color3.fromRGB(47, 50, 60)
	track.BorderSizePixel = 0
	track.Text = ""
	track.AutoButtonColor = false
	track.ZIndex = 3
	Theme.round(track, 999)
	local edge = Theme.stroke(track, Color3.fromRGB(85, 89, 102), 0.08)
	edge.Thickness = 1.1
	track.Parent = parent

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(on and 0.74 or 0.26, 0.5)
	knob.Size = UDim2.fromScale(0.32, 0.72)
	knob.BackgroundColor3 = Color3.fromRGB(250, 250, 253)
	knob.BorderSizePixel = 0
	knob.ZIndex = track.ZIndex + 1
	Theme.round(knob, 999)
	knob.Parent = track

	local glow = Instance.new("UIStroke")
	glow.Color = Color3.fromRGB(178, 104, 255)
	glow.Thickness = 3
	glow.Transparency = 1
	glow.Parent = track

	local function render(animated: boolean)
		local info = TweenInfo.new(animated and 0.18 or 0, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(track, info, { BackgroundColor3 = on and Color3.fromRGB(119, 66, 238) or Color3.fromRGB(47, 50, 60) }):Play()
		TweenService:Create(knob, info, { Position = UDim2.fromScale(on and 0.74 or 0.26, 0.5) }):Play()
		TweenService:Create(glow, info, { Transparency = on and 0.55 or 1 }):Play()
	end
	render(false)
	track.Activated:Connect(function()
		on = not on
		Sounds.play("click")
		render(true)
		changed(on)
	end)
	return track
end

function Settings.init(parent: Instance)
	-- Centered modal with one stable aspect ratio; it scales down as a whole
	-- instead of becoming stretched or colliding with the menu.
	panel = Theme.panel(parent, UDim2.fromScale(0.5, 0.51), UDim2.fromOffset(620, 600), Vector2.new(0.5, 0.5))
	Theme.responsiveSize(panel, Vector2.new(620, 600), Vector2.new(20, 20))
	Theme.sidePopout(panel, "right", 0.56)
	Theme.decoratePanel(panel)
	local settingsGlow = Instance.new("UIStroke")
	settingsGlow.Color = Color3.fromRGB(83, 209, 255)
	settingsGlow.Thickness = 2
	settingsGlow.Transparency = 0.28
	settingsGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	settingsGlow.Parent = panel
	panel.Visible = false

	local title = Theme.label(panel, "Settings - Keybinds", UDim2.fromScale(0.12, 0.02), UDim2.fromScale(0.72, 0.065))
	title.TextColor3 = Color3.new(1, 1, 1)
	Theme.capText(title, 24)
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new(Color3.fromRGB(90, 222, 255), Color3.fromRGB(214, 104, 255))
	titleGradient.Parent = title
	local headerIcon = settingIcon(panel, Icons.Keybind, 0.022)
	headerIcon.Position = UDim2.fromScale(0.048, 0.025)
	headerIcon.Size = UDim2.fromScale(0.052, 0.052)

	local headerLine = Instance.new("Frame")
	headerLine.Position = UDim2.fromScale(0.04, 0.094)
	headerLine.Size = UDim2.fromScale(0.92, 0.003)
	headerLine.BackgroundColor3 = Color3.new(1, 1, 1)
	headerLine.BorderSizePixel = 0
	local headerGradient = Instance.new("UIGradient")
	headerGradient.Color = ColorSequence.new(Color3.fromRGB(45, 211, 255), Color3.fromRGB(212, 71, 255))
	headerGradient.Parent = headerLine
	headerLine.Parent = panel

	local hint = Theme.label(
		panel,
		"Click a key, then press the new key.",
		UDim2.fromScale(0.12, 0.10),
		UDim2.fromScale(0.72, 0.03)
	)
	hint.TextColor3 = Theme.MutedText
	Theme.capText(hint, 15)

	for i, row in ROWS do
		local action, display = row[1], row[2]
		local y = 0.14 + (i - 1) * 0.058
		local nameLabel = Theme.label(panel, display, UDim2.fromScale(0.05, y), UDim2.fromScale(0.55, 0.046))
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		Theme.capText(nameLabel, 15)
		local keyButton = Theme.button(panel, "?", UDim2.fromScale(0.64, y), UDim2.fromScale(0.22, 0.046), function()
			keyButtons[action].Text = "press key..."
			Input.captureNext(action)
		end)
		Theme.capText(keyButton, 15)
		local keyEdge = keyButton:FindFirstChildOfClass("UIStroke")
		if keyEdge then
			keyEdge.Color = Color3.fromRGB(69, 181, 255)
			keyEdge.Transparency = 0.48
		end
		keyButtons[action] = keyButton
		local clearButton = Theme.button(panel, "X", UDim2.fromScale(0.88, y), UDim2.fromScale(0.07, 0.046), function()
			Input.setBind(action, "")
		end)
		clearButton.TextColor3 = Theme.Danger
		Theme.capText(clearButton, 15)
	end

	local resetBinds = Theme.button(panel, "Reset keybinds to default", UDim2.fromScale(0.64, 0.665), UDim2.fromScale(0.31, 0.046), function()
		Input.resetBinds()
		Sounds.play("click")
	end)
	resetBinds.TextColor3 = Color3.fromRGB(198, 137, 255)
	Theme.capText(resetBinds, 14)
	local resetIcon = Instance.new("ImageLabel")
	resetIcon.AnchorPoint = Vector2.new(0, 0.5)
	resetIcon.Position = UDim2.new(0, 8, 0.5, 0)
	resetIcon.Size = UDim2.fromOffset(16, 16)
	resetIcon.BackgroundTransparency = 1
	resetIcon.Image = Icons.Reset
	resetIcon.ImageColor3 = Color3.fromRGB(245, 245, 249)
	resetIcon.ScaleType = Enum.ScaleType.Fit
	resetIcon.Active = false
	resetIcon.ZIndex = resetBinds.ZIndex + 1
	resetIcon.Parent = resetBinds

	local closeButton = Theme.closeButton(panel, UDim2.fromScale(0.9, 0.02), UDim2.fromScale(0.08, 0.06), function()
		Settings.setVisible(false)
	end)
	closeButton.BackgroundColor3 = Color3.fromRGB(236, 31, 103)
	local closeEdge = closeButton:FindFirstChildOfClass("UIStroke")
	if closeEdge then
		closeEdge.Color = Color3.fromRGB(255, 108, 177)
		closeEdge.Transparency = 0
		closeEdge.Thickness = 1.5
	end
	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(236, 31, 103)
		if closeEdge then
			closeEdge.Color = Color3.fromRGB(255, 108, 177)
			closeEdge.Transparency = 0
		end
	end)

	-- Auto Respawn uses a reactive switch instead of text-only On / Off.
	settingIcon(panel, Icons.Reset, 0.725)
	local arLabel = Theme.label(panel, "Auto Respawn", UDim2.fromScale(0.105, 0.725), UDim2.fromScale(0.66, 0.046))
	arLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(arLabel, 16)
	toggleSwitch(panel, 0.725, true, function(on)
		Remotes.Action:FireServer("setautorespawn", on)
	end)

	-- Sound Effects uses the same animated switch language.
	settingIcon(panel, Icons.Sound, 0.785)
	local sfxLabel = Theme.label(panel, "Sound Effects", UDim2.fromScale(0.105, 0.785), UDim2.fromScale(0.66, 0.046))
	sfxLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(sfxLabel, 16)
	toggleSwitch(panel, 0.785, Sounds.isEnabled(), function(on)
		Sounds.setEnabled(on)
	end)

	-- Map Background: a "Pick" HSV picker + a row of quick preset swatches. Both
	-- apply to the world background AND the minimap surface (a local visual).
	local function applyBg(color: Color3)
		currentBg = color
		Renderer.setBackground(color)
		Minimap.setBackground(color)
	end
	settingIcon(panel, Icons.Palette, 0.845)
	local bgLabel = Theme.label(panel, "Map Background", UDim2.fromScale(0.105, 0.845), UDim2.fromScale(0.48, 0.042))
	bgLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(bgLabel, 16)
	local pickBtn = Theme.button(panel, "Choose Color", UDim2.fromScale(0.64, 0.84), UDim2.fromScale(0.31, 0.046), function()
		ColorPicker.open("Map background", currentBg, applyBg)
	end)
	Theme.capText(pickBtn, 15)
	for i, color in BG_PRESETS do
		local sw = Instance.new("TextButton")
		sw.Position = UDim2.fromScale(0.05 + (i - 1) * 0.117, 0.915)
		sw.Size = UDim2.fromScale(0.1, 0.052)
		sw.BackgroundColor3 = color
		sw.BorderSizePixel = 0
		sw.Text = ""
		sw.AutoButtonColor = true
		Theme.round(sw, 6)
		Theme.stroke(sw)
		sw.Parent = panel
		sw.Activated:Connect(function()
			Sounds.play("click")
			applyBg(color)
		end)
	end

	-- reserved-for-future note: defaults come from Config.DefaultKeybinds
	local _ = Config

	Input.onBindsChanged = refreshLabels
	refreshLabels()
end

function Settings.isVisible(): boolean
	return panel ~= nil and panel.Visible
end

function Settings.setVisible(visible: boolean)
	panel.Visible = visible
end

function Settings.toggle()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refreshLabels()
		Theme.popIn(panel)
	end
end

return Settings
