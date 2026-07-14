--[[
	Settings - keybind remapping panel (opened with the top-left menu button or
	the Menu key). Click a key button, press any key, done: Input.captureNext
	intercepts the next keypress, rebinds, persists via DataStore, and the
	onBindsChanged callback refreshes the labels here.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(script.Parent.Theme)
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
	{ "ToMenu", "Back to Menu" },
	{ "FixedMouse", "Fixed Mouse (toggle)" },
	{ "Menu", "Settings panel" },
}

local Settings = {}

local panel: Frame
local keyButtons: { [string]: TextButton } = {}
local currentBg = BG_PRESETS[1] -- last-applied map background (world + minimap); seeds the picker

local function refreshLabels()
	for action, button in keyButtons do
		button.Text = Input.binds[action] or "?"
	end
end

function Settings.init(parent: Instance)
	-- sits on the RIGHT side (like Hiscores) instead of overlaying the play card
	panel = Theme.panel(parent, UDim2.fromScale(0.64, 0.5), UDim2.fromScale(0.31, 0.66), Vector2.new(0, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Settings - Keybinds", UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.9, 0.08))
	title.TextColor3 = Theme.AccentColor
	Theme.capText(title, 24)

	local hint = Theme.label(
		panel,
		"Click a key, then press the new key.",
		UDim2.fromScale(0.05, 0.1),
		UDim2.fromScale(0.9, 0.04)
	)
	hint.TextColor3 = Theme.MutedText
	Theme.capText(hint, 15)

	for i, row in ROWS do
		local action, display = row[1], row[2]
		local y = 0.135 + (i - 1) * 0.062
		local nameLabel = Theme.label(panel, display, UDim2.fromScale(0.05, y), UDim2.fromScale(0.55, 0.05))
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(nameLabel, 16)
		local keyButton = Theme.button(panel, "?", UDim2.fromScale(0.64, y), UDim2.fromScale(0.31, 0.052), function()
			keyButtons[action].Text = "press key..."
			Input.captureNext(action)
		end)
		Theme.capText(keyButton, 17)
		keyButtons[action] = keyButton
	end

	Theme.closeButton(panel, UDim2.fromScale(0.9, 0.02), UDim2.fromScale(0.08, 0.06), function()
		Settings.setVisible(false)
	end)

	-- Sound Effects on/off toggle (below the keybind rows)
	local sfxLabel = Theme.label(panel, "Sound Effects", UDim2.fromScale(0.05, 0.8), UDim2.fromScale(0.5, 0.05))
	sfxLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(sfxLabel, 16)
	local sfxBtn
	sfxBtn = Theme.button(panel, "On", UDim2.fromScale(0.64, 0.8), UDim2.fromScale(0.31, 0.052), function()
		Sounds.setEnabled(not Sounds.isEnabled())
		local on = Sounds.isEnabled()
		sfxBtn.Text = on and "On" or "Off"
		sfxBtn.TextColor3 = on and Theme.Green or Theme.MutedText
	end)
	local on = Sounds.isEnabled()
	sfxBtn.Text = on and "On" or "Off"
	sfxBtn.TextColor3 = on and Theme.Green or Theme.MutedText
	Theme.capText(sfxBtn, 16)

	-- Map Background: a "Pick" HSV picker + a row of quick preset swatches. Both
	-- apply to the world background AND the minimap surface (a local visual).
	local function applyBg(color: Color3)
		currentBg = color
		Renderer.setBackground(color)
		Minimap.setBackground(color)
	end
	local bgLabel = Theme.label(panel, "Map Background", UDim2.fromScale(0.05, 0.86), UDim2.fromScale(0.45, 0.045))
	bgLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(bgLabel, 16)
	local pickBtn = Theme.button(panel, "\u{1F3A8} Pick", UDim2.fromScale(0.64, 0.855), UDim2.fromScale(0.31, 0.05), function()
		ColorPicker.open("Map background", currentBg, applyBg)
	end)
	Theme.capText(pickBtn, 15)
	for i, color in BG_PRESETS do
		local sw = Instance.new("TextButton")
		sw.Position = UDim2.fromScale(0.05 + (i - 1) * 0.117, 0.915)
		sw.Size = UDim2.fromScale(0.1, 0.05)
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
