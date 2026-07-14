--[[
	Minimap - bottom-right corner map (Agma-style), showing every player's cells
	and viruses as dots over a faint sector grid. Snapshots are full-world, so the
	client already holds every cell; you are drawn bigger, in the accent, on top.

	PERF: dots are a reused pool indexed per frame (never Destroy'd); the whole
	thing refreshes ~10x/second, not every frame.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local MAP_W, MAP_H = Config.MapWidth, Config.MapHeight
local SECTORS = 5 -- 5x5 grid like Agma

local Minimap = {}

local root: Frame
local field: Frame
local dots: { Frame } = {}
local acc = 0

local function getDot(i: number): Frame
	local d = dots[i]
	if not d then
		d = Instance.new("Frame")
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.BorderSizePixel = 0
		d.ZIndex = 3
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = d
		d.Parent = field
		dots[i] = d
	end
	return d
end

function Minimap.init(parent: Instance)
	root = Theme.panel(parent, UDim2.fromScale(0.988, 0.965), UDim2.fromScale(0.13, 0.13), Vector2.new(1, 1))
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = root

	field = Instance.new("Frame")
	field.AnchorPoint = Vector2.new(0.5, 0.5)
	field.Position = UDim2.fromScale(0.5, 0.5)
	field.Size = UDim2.fromScale(0.92, 0.92)
	field.BackgroundColor3 = Theme.Field
	field.BorderSizePixel = 0
	field.ClipsDescendants = true
	Theme.round(field, 8)
	field.Parent = root

	-- faint sector grid lines (5x5)
	for i = 1, SECTORS - 1 do
		local frac = i / SECTORS
		local v = Instance.new("Frame")
		v.Size = UDim2.new(0, 1, 1, 0)
		v.Position = UDim2.fromScale(frac, 0)
		v.BackgroundColor3 = Color3.new(1, 1, 1)
		v.BackgroundTransparency = 0.9
		v.BorderSizePixel = 0
		v.ZIndex = 2
		v.Parent = field
		local h = Instance.new("Frame")
		h.Size = UDim2.new(1, 0, 0, 1)
		h.Position = UDim2.fromScale(0, frac)
		h.BackgroundColor3 = Color3.new(1, 1, 1)
		h.BackgroundTransparency = 0.9
		h.BorderSizePixel = 0
		h.ZIndex = 2
		h.Parent = field
	end
end

-- Match the minimap surface to the chosen map background.
function Minimap.setBackground(base: Color3)
	if field then
		field.BackgroundColor3 = base
	end
end

function Minimap.update(dt: number)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0

	local mySlot = WorldState.mySlot
	local i = 0

	for _, v in WorldState.view.viruses do
		i += 1
		local d = getDot(i)
		d.Position = UDim2.fromScale(v.x / MAP_W, v.y / MAP_H)
		d.Size = UDim2.fromOffset(5, 5)
		d.BackgroundColor3 = Theme.Green
		d.ZIndex = 3
		d.Visible = true
	end

	for _, cell in WorldState.view.cells do
		i += 1
		local d = getDot(i)
		local mine = cell.slot == mySlot
		d.Position = UDim2.fromScale(cell.x / MAP_W, cell.y / MAP_H)
		if mine then
			d.Size = UDim2.fromOffset(9, 9)
			d.BackgroundColor3 = Theme.AccentColor
			d.ZIndex = 6
		else
			d.Size = UDim2.fromOffset(6, 6)
			d.BackgroundColor3 = WorldState.colorForSlot(cell.slot)
			d.ZIndex = 4
		end
		d.Visible = true
	end

	for k = i + 1, #dots do
		if dots[k].Visible then
			dots[k].Visible = false
		end
	end
end

return Minimap
