--[[
	AbilityDock - bottom-center row of on-screen action buttons (Split, Double
	Split, Feed, Freeze). Each button fires the SAME action as its keybind via
	Input.trigger, so it doubles as touch/mobile controls and a live keybind
	reference. The key badge tracks the current (remappable) bind.

	Icons are colored circle Frames, not glyph characters, so they always render
	regardless of the font's unicode coverage. Freeze shows an active highlight
	while toggled on (tracked locally - the server owns the real toggle, but this
	is just feedback and resets whenever you leave the alive state).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)
local Input = require(script.Parent.Parent.Input)

local _ = Shared

local AbilityDock = {}

-- action = the bind name (Input.binds key); label + icon color for the button
local ENTRIES = {
	{ action = "Split", label = "Split", color = Theme.AccentColor },
	{ action = "MultiSplit", label = "Double", color = Theme.AccentColor },
	{ action = "Feed", label = "Feed", color = Theme.Gold },
	{ action = "Freeze", label = "Freeze", color = Color3.fromRGB(140, 170, 255) },
}

local container: Frame
local buttons = {}
local frozenActive = false
local pollAccumulator = 0

local function makeButton(entry)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(0.23, 1)
	btn.BackgroundColor3 = Theme.PanelColor
	btn.BackgroundTransparency = Theme.PanelTransparency
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	Theme.round(btn, 12)
	local stroke = Theme.stroke(btn)
	btn.Parent = container

	-- icon: a colored disc
	local icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0.14)
	icon.Size = UDim2.fromScale(0.42, 0.42)
	icon.BackgroundColor3 = entry.color
	icon.BorderSizePixel = 0
	Theme.round(icon, 999)
	icon.Parent = btn

	-- name
	local name = Theme.caption(btn, entry.label, UDim2.fromScale(0.05, 0.6), UDim2.fromScale(0.9, 0.22))
	name.TextXAlignment = Enum.TextXAlignment.Center
	Theme.capText(name, 12)

	-- key badge (top-right)
	local key = Theme.mono(btn, "?", UDim2.fromScale(0.52, 0.05), UDim2.fromScale(0.43, 0.2))
	key.TextColor3 = Theme.MutedText
	key.TextXAlignment = Enum.TextXAlignment.Right
	Theme.capText(key, 11)

	-- press feedback + fire
	btn.Activated:Connect(function()
		Input.trigger(entry.action)
		if entry.action == "Freeze" then
			frozenActive = not frozenActive
		end
	end)
	btn.MouseButton1Down:Connect(function()
		btn.BackgroundColor3 = Theme.ButtonHover
	end)
	btn.MouseButton1Up:Connect(function()
		btn.BackgroundColor3 = Theme.PanelColor
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Theme.PanelColor
	end)

	table.insert(buttons, { btn = btn, key = key, icon = icon, entry = entry, lastKey = "", stroke = stroke })
end

function AbilityDock.init(parent: Instance)
	container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 1)
	container.Position = UDim2.fromScale(0.5, 0.925)
	container.Size = UDim2.fromScale(0.32, 0.085)
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

function AbilityDock.update(_dt: number)
	local alive = WorldState.status == "alive"
	if container.Visible ~= alive then
		container.Visible = alive
	end
	if not alive then
		frozenActive = false
	end
	if not alive then
		return
	end

	-- refresh key badges + freeze highlight a few times a second
	pollAccumulator += _dt
	if pollAccumulator < 0.25 then
		return
	end
	pollAccumulator = 0

	for _, b in buttons do
		local keyName = Input.binds[b.entry.action] or "?"
		if keyName ~= b.lastKey then
			b.lastKey = keyName
			b.key.Text = keyName
		end
		if b.entry.action == "Freeze" then
			local want = frozenActive and Color3.fromRGB(140, 170, 255) or Theme.Border
			if b.stroke.Color ~= want then
				b.stroke.Color = want
			end
			b.stroke.Thickness = frozenActive and 2 or 1
		end
	end
end

return AbilityDock
