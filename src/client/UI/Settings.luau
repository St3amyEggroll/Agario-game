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

local function refreshLabels()
	for action, button in keyButtons do
		button.Text = Input.binds[action] or "?"
	end
end

function Settings.init(parent: Instance)
	panel = Theme.panel(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.32, 0.62), Vector2.new(0.5, 0.5))
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

	local closeButton = Theme.button(panel, "Close", UDim2.fromScale(0.5, 0.97), UDim2.fromScale(0.3, 0.07), function()
		Settings.setVisible(false)
	end)
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	Theme.capText(closeButton, 18)

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
