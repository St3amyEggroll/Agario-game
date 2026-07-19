--[[
	AbilityDock (minimal / bottom-right) - a row of frosted buttons for Split /
	Double / Feed / Freeze. Each fires the SAME action as its keybind via
	Input.trigger, so it doubles as touch controls and a live keybind reference:
	the big mono glyph is the current (remappable) key, the small caption is the
	action. Freeze tints to accent while toggled on (local feedback only).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)
local Input = require(script.Parent.Parent.Input)

local AbilityDock = {}

local ENTRIES = {
	{ action = "Split", label = "Split" },
	{ action = "MultiSplit", label = "Double" },
	{ action = "Feed", label = "Feed" },
	{ action = "Freeze", label = "Freeze" },
}

local container: Frame
local buttons = {}
local frozenActive = false
local pollAccumulator = 0
local tutorialRemaining = 0
local tutorialConsumed = false

-- long bind names would overflow a small button; keep the common ones short
local function shortKey(k: string): string
	if k == "Space" then
		return "SPC"
	end
	return k
end

local function makeButton(entry)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(0.235, 1)
	btn.BackgroundColor3 = Color3.new(1, 1, 1)
	btn.BackgroundTransparency = 0.93
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	Theme.round(btn, 10)
	local stroke = Theme.stroke(btn)
	btn.Parent = container

	local key = Theme.readout(btn, "?", UDim2.fromScale(0.05, 0.1), UDim2.fromScale(0.9, 0.5))
	Theme.capText(key, 20)

	local name = Theme.caption(btn, entry.label, UDim2.fromScale(0.05, 0.62), UDim2.fromScale(0.9, 0.26))
	name.TextStrokeColor3 = Color3.new(0, 0, 0)
	name.TextStrokeTransparency = 0.5
	Theme.capText(name, 11)

	btn.Activated:Connect(function()
		Input.trigger(entry.action)
		if entry.action == "Freeze" then
			frozenActive = not frozenActive
		end
	end)
	btn.MouseButton1Down:Connect(function()
		btn.BackgroundTransparency = 0.8
	end)
	btn.MouseButton1Up:Connect(function()
		btn.BackgroundTransparency = 0.93
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundTransparency = 0.93
	end)

	table.insert(buttons, { btn = btn, key = key, name = name, entry = entry, lastKey = "", stroke = stroke })
end

function AbilityDock.init(parent: Instance)
	container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.fromScale(0.5, 0.985)
	container.Size = UDim2.fromOffset(360, 62)
	Theme.responsiveSize(container, Vector2.new(360, 62), Vector2.new(16, 16))
	container.BackgroundTransparency = 1
	container.Visible = false
	container.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	for i, entry in ENTRIES do
		makeButton(entry)
		buttons[i].btn.LayoutOrder = i
	end
end

function AbilityDock.update(dt: number)
	local alive = WorldState.status == "alive"
	if alive and WorldState.showAbilityTutorial and not tutorialConsumed then
		tutorialRemaining = Config.AbilityTutorialDuration
		tutorialConsumed = true
	end
	if alive and tutorialRemaining > 0 then
		tutorialRemaining = math.max(0, tutorialRemaining - dt)
	end
	local show = alive and tutorialRemaining > 0
	if container.Visible ~= show then
		container.Visible = show
	end
	if not alive then
		frozenActive = false
		return
	end

	pollAccumulator += dt
	if pollAccumulator < 0.25 then
		return
	end
	pollAccumulator = 0

	for _, b in buttons do
		local keyName = shortKey(Input.binds[b.entry.action] or "?")
		if keyName ~= b.lastKey then
			b.lastKey = keyName
			b.key.Text = keyName
		end
		if b.entry.action == "Freeze" then
			if frozenActive then
				b.key.TextColor3 = Theme.AccentColor
				b.stroke.Color = Theme.AccentColor
				b.stroke.Transparency = 0.3
			else
				b.key.TextColor3 = Theme.TextColor
				b.stroke.Color = Theme.Border
				b.stroke.Transparency = Theme.BorderTransparency
			end
		end
	end
end

return AbilityDock
