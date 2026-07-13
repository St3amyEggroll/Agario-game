--[[
	Minimap - a small corner map (bottom-right) showing every player's cells and
	the viruses as dots. Snapshots are full-world (no interest culling), so the
	client already holds every cell - we just project each to map-normalized
	coordinates. You are drawn bigger, in the accent color, on top.

	PERF: dots are a reused pool indexed per frame (never Destroy'd), and the
	whole thing refreshes ~10x/second, not every frame - a minimap doesn't need
	60 Hz.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local MAP_W, MAP_H = Config.MapWidth, Config.MapHeight

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
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = d
		d.Parent = field
		dots[i] = d
	end
	return d
end

function Minimap.init(parent: Instance)
	root = Theme.panel(parent, UDim2.fromScale(0.988, 0.94), UDim2.fromScale(0.12, 0.12), Vector2.new(1, 1))
	root.Visible = false
	-- keep it square regardless of screen aspect
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = root

	-- inner field (the actual map area, inset from the panel border)
	field = Instance.new("Frame")
	field.AnchorPoint = Vector2.new(0.5, 0.5)
	field.Position = UDim2.fromScale(0.5, 0.5)
	field.Size = UDim2.fromScale(0.9, 0.9)
	field.BackgroundColor3 = Theme.Field
	field.BorderSizePixel = 0
	field.ClipsDescendants = true
	Theme.round(field, 8)
	field.Parent = root
end

function Minimap.update(dt: number)
	local alive = WorldState.status == "alive" or WorldState.status == "spectate"
	if root.Visible ~= alive then
		root.Visible = alive
	end
	if not alive then
		return
	end

	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0

	local mySlot = WorldState.mySlot
	local i = 0

	-- viruses first (drawn under the cells)
	for _, v in WorldState.view.viruses do
		i += 1
		local d = getDot(i)
		d.Position = UDim2.fromScale(v.x / MAP_W, v.y / MAP_H)
		d.Size = UDim2.fromOffset(5, 5)
		d.BackgroundColor3 = Theme.Green
		d.ZIndex = 2
		d.Visible = true
	end

	-- cells (yours last / on top, bigger, accent)
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
			d.ZIndex = 3
		end
		d.Visible = true
	end

	-- hide any leftover dots from a busier previous frame
	for k = i + 1, #dots do
		if dots[k].Visible then
			dots[k].Visible = false
		end
	end
end

return Minimap
