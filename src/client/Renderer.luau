--[[
	Renderer - draws the whole game as flat frames in one ScreenGui.
	Zero Parts, zero physics, zero per-frame Instance creation.

	Key trick: everything is parented to ONE "map frame" whose children use
	Scale-based UDim2s (world position / map size). The camera then only moves
	and resizes that single frame; every child follows for free. Static things
	(orbs, grid lines) therefore cost NOTHING per frame beyond their existence -
	their properties are written once, on (re)assignment.

	Pooling: each entity class has a pool of pre-built frame "wrappers". Frames
	are acquired when an entity enters the view rect and released when it
	leaves - never Destroy()ed, never created mid-frame after warmup.

	Culling: an explicit world-space view rect test decides which entities get
	a frame at all. A player in a corner pays nothing for the far side of the
	map (the engine additionally clips, but we don't even touch the properties).
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local WorldState = require(script.Parent.WorldState)

local MAP_W = Config.MapWidth
local MAP_H = Config.MapHeight

local Renderer = {}

local gui: ScreenGui
local backdrop: Frame
local mapFrame: Frame

--------------------------------------------------------------------- pools

-- Generic pool of wrapper tables. `create` builds the (invisible) template
-- once; acquire/release toggle Visible only. Pools grow on demand but only
-- during load spikes - steady state reuses.
local function newPool(create)
	local free = {}
	return {
		acquire = function()
			local w = table.remove(free)
			if not w then
				w = create()
			end
			w.frame.Visible = true
			return w
		end,
		release = function(w)
			w.frame.Visible = false
			free[#free + 1] = w
		end,
	}
end

local function circleFrame(zindex: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = zindex
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = mapFrame
	return f
end

local orbPool, pelletPool, virusPool, cellPool

local function buildPools()
	orbPool = newPool(function()
		return { frame = circleFrame(2) }
	end)

	pelletPool = newPool(function()
		return { frame = circleFrame(3) }
	end)

	virusPool = newPool(function()
		local f = circleFrame(200)
		-- cheap "spiky" look: two rotated rounded squares behind the disc.
		-- Real spike geometry would need ImageLabels or many frames; this is
		-- the flat-frame tradeoff (swap for an ImageLabel sprite if desired).
		for i, rot in { 15, 30 } do
			local spike = Instance.new("Frame")
			spike.AnchorPoint = Vector2.new(0.5, 0.5)
			spike.Position = UDim2.fromScale(0.5, 0.5)
			spike.Size = UDim2.fromScale(1.06, 1.06)
			spike.Rotation = rot
			spike.BorderSizePixel = 0
			spike.ZIndex = 199
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.32, 0)
			corner.Parent = spike
			spike.Name = "Spike" .. i
			spike.Parent = f
		end
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = f
		return { frame = f, spikes = { f.Spike1, f.Spike2 }, stroke = stroke, kind = 0 }
	end)

	cellPool = newPool(function()
		local f = circleFrame(10)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = f
		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLabel.Position = UDim2.fromScale(0.5, 0.4)
		nameLabel.Size = UDim2.fromScale(1.5, 0.3)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextStrokeTransparency = 0.4
		nameLabel.ZIndex = 250
		nameLabel.Parent = f
		local massLabel = nameLabel:Clone()
		massLabel.Position = UDim2.fromScale(0.5, 0.66)
		massLabel.Size = UDim2.fromScale(1.2, 0.22)
		massLabel.Parent = f
		return {
			frame = f,
			stroke = stroke,
			nameLabel = nameLabel,
			massLabel = massLabel,
			lastName = "",
			lastMass = -1,
			slot = -1,
		}
	end)
end

--------------------------------------------------------------------- setup

function Renderer.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "AgarWorld"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- out-of-map background (also clips the world to the screen)
	backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	backdrop.BorderSizePixel = 0
	backdrop.ClipsDescendants = true
	backdrop.Parent = gui

	mapFrame = Instance.new("Frame")
	mapFrame.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
	mapFrame.BorderSizePixel = 0
	mapFrame.ZIndex = 1
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(90, 100, 130)
	edge.Thickness = 3
	edge.Parent = mapFrame
	mapFrame.Parent = backdrop

	-- Static grid: built ONCE, positions in scale-space, zero per-frame cost.
	-- ~66 thin frames; the engine clips whatever is off screen.
	local gridColor = Color3.fromRGB(42, 46, 58)
	for i = 0, MAP_W / Config.GridStep do
		local v = Instance.new("Frame")
		v.BackgroundColor3 = gridColor
		v.BorderSizePixel = 0
		v.Size = UDim2.new(0, 1, 1, 0)
		v.Position = UDim2.fromScale(i * Config.GridStep / MAP_W, 0)
		v.ZIndex = 1
		v.Parent = mapFrame
	end
	for i = 0, MAP_H / Config.GridStep do
		local h = Instance.new("Frame")
		h.BackgroundColor3 = gridColor
		h.BorderSizePixel = 0
		h.Size = UDim2.new(1, 0, 0, 1)
		h.Position = UDim2.fromScale(0, i * Config.GridStep / MAP_H)
		h.ZIndex = 1
		h.Parent = mapFrame
	end

	buildPools()
	gui.Parent = playerGui
end

--------------------------------------------------------------------- helpers

local function place(frame: Frame, x: number, y: number, r: number)
	frame.Position = UDim2.fromScale(x / MAP_W, y / MAP_H)
	frame.Size = UDim2.fromScale(r * 2 / MAP_W, r * 2 / MAP_H)
end

local function darker(c: Color3): Color3
	return Color3.new(c.R * 0.72, c.G * 0.72, c.B * 0.72)
end

-- active[id] = wrapper for every entity currently holding a frame
local activeOrbs = {}
local activeCells = {}
local activeViruses = {}
local activePellets = {}
local generation = 0 -- frame stamp used to release wrappers whose entity left

local visibleCellList = {} -- reused scratch for z-sorting

--------------------------------------------------------------------- render

function Renderer.render(cam)
	local viewport = Workspace.CurrentCamera.ViewportSize
	local scale = cam.scale

	-- one transform moves the whole world
	mapFrame.Position = UDim2.fromOffset(viewport.X / 2 - cam.x * scale, viewport.Y / 2 - cam.y * scale)
	mapFrame.Size = UDim2.fromOffset(MAP_W * scale, MAP_H * scale)

	-- world-space view rect (+margin) used for explicit culling
	local halfW = viewport.X / 2 / scale + Config.CullMargin
	local halfH = viewport.Y / 2 / scale + Config.CullMargin
	local minX, maxX = cam.x - halfW, cam.x + halfW
	local minY, maxY = cam.y - halfH, cam.y + halfH

	generation += 1
	local gen = generation

	-- ORBS: static; properties are written once when the orb first enters the
	-- view, then never touched again while it stays visible.
	for id, orb in WorldState.orbs do
		if orb.x >= minX and orb.x <= maxX and orb.y >= minY and orb.y <= maxY then
			local w = activeOrbs[id]
			if not w then
				w = orbPool.acquire()
				place(w.frame, orb.x, orb.y, orb.r)
				w.frame.BackgroundColor3 = Config.Palette[orb.color] or Config.Palette[1]
				activeOrbs[id] = w
			end
			w.gen = gen
		end
	end
	for id, w in activeOrbs do
		if w.gen ~= gen then
			orbPool.release(w)
			activeOrbs[id] = nil
		end
	end

	-- PELLETS
	for id, p in WorldState.view.pellets do
		if p.x >= minX and p.x <= maxX and p.y >= minY and p.y <= maxY then
			local w = activePellets[id]
			if not w then
				w = pelletPool.acquire()
				w.frame.BackgroundColor3 = WorldState.colorForSlot(p.slot)
				activePellets[id] = w
			end
			place(w.frame, p.x, p.y, p.r)
			w.gen = gen
		end
	end
	for id, w in activePellets do
		if w.gen ~= gen then
			pelletPool.release(w)
			activePellets[id] = nil
		end
	end

	-- VIRUSES
	for id, v in WorldState.view.viruses do
		if v.x >= minX and v.x <= maxX and v.y >= minY and v.y <= maxY then
			local w = activeViruses[id]
			if not w then
				w = virusPool.acquire()
				activeViruses[id] = w
				w.kind = -1
			end
			if w.kind ~= v.kind then
				w.kind = v.kind
				local color = v.kind == 2 and Config.ExperimentalColor or Config.VirusColor
				w.frame.BackgroundColor3 = color
				w.spikes[1].BackgroundColor3 = darker(color)
				w.spikes[2].BackgroundColor3 = darker(color)
				w.stroke.Color = darker(color)
			end
			place(w.frame, v.x, v.y, v.r)
			w.gen = gen
		end
	end
	for id, w in activeViruses do
		if w.gen ~= gen then
			virusPool.release(w)
			activeViruses[id] = nil
		end
	end

	-- CELLS (with name/mass labels + smaller-under-bigger z ordering)
	table.clear(visibleCellList)
	for id, c in WorldState.view.cells do
		if c.x >= minX and c.x <= maxX and c.y >= minY and c.y <= maxY then
			local w = activeCells[id]
			if not w then
				w = cellPool.acquire()
				w.slot = -1
				activeCells[id] = w
			end
			if w.slot ~= c.slot then
				w.slot = c.slot
				local color = WorldState.colorForSlot(c.slot)
				w.frame.BackgroundColor3 = color
				w.stroke.Color = darker(color)
				w.lastName = ""
			end
			place(w.frame, c.x, c.y, c.r)

			-- labels only when the cell is big enough on screen to read
			local pixels = c.r * 2 * scale
			local showLabels = pixels >= Config.LabelMinPixels
			if showLabels then
				local name = WorldState.nameForSlot(c.slot)
				if w.lastName ~= name then
					w.lastName = name
					w.nameLabel.Text = name
				end
				local mass = math.floor(Util.massFromRadius(c.r) + 0.5)
				if w.lastMass ~= mass then
					w.lastMass = mass
					w.massLabel.Text = tostring(mass)
				end
			end
			if w.nameLabel.Visible ~= showLabels then
				w.nameLabel.Visible = showLabels
				w.massLabel.Visible = showLabels
			end

			w.gen = gen
			w.r = c.r
			table.insert(visibleCellList, w)
		end
	end
	for id, w in activeCells do
		if w.gen ~= gen then
			cellPool.release(w)
			activeCells[id] = nil
		end
	end
	-- bigger cells draw over smaller ones (classic agar reading); viruses sit
	-- at Z=200, above any cell small enough to hide inside them
	table.sort(visibleCellList, function(a, b)
		return a.r < b.r
	end)
	for i, w in visibleCellList do
		w.frame.ZIndex = math.min(10 + i, 198)
	end
end

return Renderer
