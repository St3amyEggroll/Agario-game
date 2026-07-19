--[[
	AbilityDock (bottom center) - two rows:
	  * ability row (top): one square button per OWNED ability (bought in the Shop).
	    Tap to use; a dim overlay + countdown covers it while on cooldown. Ready
	    abilities glow in their catalog colour.
	  * control row (bottom): Split / Double / Feed / Freeze, each firing the SAME
	    action as its keybind via Input.trigger, so it doubles as touch controls and
	    a live keybind reference (big glyph = current key, caption = action).

	Both rows show only while alive. The ability row rebuilds when your owned set
	changes (cheap - a handful of pooled buttons).
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
local abilityRow: Frame
local buttons = {}
local abilityButtons = {} -- [id] = { btn, overlay, cdText }
local frozenActive = false
local pollAccumulator = 0
local lastOwnedCount = -1
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

-- One square button per catalog ability (hidden until owned).
local function makeAbilityButton(ab)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 0, 1, 0) -- width comes from the 1:1 aspect ratio below
	btn.BackgroundColor3 = ab.color
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Visible = false
	Theme.round(btn, 10)
	Theme.stroke(btn)
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = btn
	btn.Parent = abilityRow

	local name = Theme.caption(btn, ab.name, UDim2.fromScale(0.04, 0.64), UDim2.fromScale(0.92, 0.3))
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeColor3 = Color3.new(0, 0, 0)
	name.TextStrokeTransparency = 0.4
	Theme.capText(name, 11)

	-- cooldown overlay: dims the button and shows the seconds left
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Visible = false
	overlay.ZIndex = 3
	Theme.round(overlay, 10)
	overlay.Parent = btn
	local cdText = Theme.readout(overlay, "", UDim2.fromScale(0.05, 0.22), UDim2.fromScale(0.9, 0.56))
	cdText.ZIndex = 4
	Theme.capText(cdText, 22)

	btn.Activated:Connect(function()
		if WorldState.abilityCooldown(ab.id) > 0 then
			return -- still cooling down
		end
		if ab.kind == "place" or ab.kind == "target" then
			Input.armPlace(ab.id) -- next click drops it (place) / picks a target (target)
		else
			Input.useAbility(ab.id) -- "self" fires now
		end
	end)

	abilityButtons[ab.id] = { btn = btn, overlay = overlay, cdText = cdText }
end

-- Show only owned abilities (UIListLayout collapses hidden ones).
local function rebuildAbilityVisibility()
	for id, b in abilityButtons do
		local owned = WorldState.ownsAbility(id)
		if b.btn.Visible ~= owned then
			b.btn.Visible = owned
		end
	end
end

local function updateAbilityCooldowns()
	for id, b in abilityButtons do
		if b.btn.Visible then
			local remaining = WorldState.abilityCooldown(id)
			if remaining > 0 then
				if not b.overlay.Visible then
					b.overlay.Visible = true
				end
				b.cdText.Text = tostring(math.ceil(remaining))
			elseif b.overlay.Visible then
				b.overlay.Visible = false
			end
		end
	end
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

	-- ability row sits just above the control row
	abilityRow = Instance.new("Frame")
	abilityRow.AnchorPoint = Vector2.new(0.5, 1)
	abilityRow.Position = UDim2.fromScale(0.5, 0.9)
	abilityRow.Size = UDim2.fromScale(0.7, 0.075)
	abilityRow.BackgroundTransparency = 1
	abilityRow.Visible = false
	abilityRow.Parent = parent

	local arow = Instance.new("UIListLayout")
	arow.FillDirection = Enum.FillDirection.Horizontal
	arow.HorizontalAlignment = Enum.HorizontalAlignment.Center
	arow.VerticalAlignment = Enum.VerticalAlignment.Center
	arow.Padding = UDim.new(0.012, 0)
	arow.SortOrder = Enum.SortOrder.LayoutOrder
	arow.Parent = abilityRow

	for i, ab in Config.Abilities do
		makeAbilityButton(ab)
		abilityButtons[ab.id].btn.LayoutOrder = i
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
	if abilityRow.Visible ~= alive then
		abilityRow.Visible = alive
	end
	if not alive then
		frozenActive = false
		return
	end

	-- owned set changed? rebuild which ability buttons show
	local owned = 0
	for _ in WorldState.abilities.owned do
		owned += 1
	end
	if owned ~= lastOwnedCount then
		lastOwnedCount = owned
		rebuildAbilityVisibility()
	end
	updateAbilityCooldowns() -- cheap (a few buttons); every frame so the countdown is smooth

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
