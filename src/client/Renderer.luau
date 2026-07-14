--[[
	Renderer - draws the whole game as flat frames in one ScreenGui.
	Zero Parts, zero physics, zero per-frame Instance creation.

	PERFORMANCE MODEL (learned the hard way): never animate a container with
	many children. Resizing/moving a parent frame forces Roblox to re-layout
	every descendant (and re-fit TextScaled text, re-tessellate UICorners),
	which collapses FPS. So instead:

	  - every entity is an independent LEAF frame positioned in SCREEN SPACE
	    (offset UDim2s). Writing Position/Size on a leaf is cheap and cascades
	    to nothing.
	  - writes are skipped when nothing changed: positions/sizes are quantized
	    to whole pixels and cached per wrapper, so an idle scene costs zero
	    property writes.
	  - labels use manual TextSize (NOT TextScaled - TextScaled re-fits text on
	    every resize, which is exactly the per-frame cost we must avoid).

	Pooling: each entity class has a pool of pre-built frame "wrappers",
	acquired when an entity enters the view rect and released when it leaves -
	never Destroy()ed, never created mid-frame after warmup.

	Culling: an explicit world-space view-rect test decides which entities get
	a frame at all. A player in a corner pays nothing for the far side of the
	map. Grid lines are likewise a small pool covering only the visible rows
	and columns.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Skins = require(Shared.Skins)
local WorldState = require(script.Parent.WorldState)

local MAP_W = Config.MapWidth
local MAP_H = Config.MapHeight
local GRID_COLOR = Color3.fromRGB(42, 46, 58)

local Renderer = {}

local gui: ScreenGui
local backdrop: Frame
local mapRect: Frame -- map background; the ONLY thing sized to the map, and it has no scale-children except grid lines

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
	f.Parent = backdrop
	return f
end

local orbPool, pelletPool, virusPool, cellPool

-- NOTE: must be declared before buildPools - the pool creators close over it,
-- and a local declared later in the file would silently resolve to nil there
local function darker(c: Color3): Color3
	return Color3.new(c.R * 0.72, c.G * 0.72, c.B * 0.72)
end

local function buildPools()
	orbPool = newPool(function()
		return { frame = circleFrame(3) }
	end)

	pelletPool = newPool(function()
		return { frame = circleFrame(4) }
	end)

	virusPool = newPool(function()
		-- layered virus: a solid green disc UNDER the sprite. If the image
		-- asset fails to load (bad/decal id, no asset permissions, offline
		-- Studio), viruses still render as clear green circles instead of
		-- becoming invisible insta-pop hazards. When the sprite loads, it
		-- covers the disc (sized slightly larger so spiky edges overhang).
		local f = circleFrame(200)
		f.BackgroundColor3 = Config.VirusColor
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = darker(Config.VirusColor)
		stroke.Parent = f
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(1.18, 1.18)
		img.BackgroundTransparency = 1
		img.Image = Config.VirusImageId
		img.ZIndex = 201
		img.Parent = f
		return { frame = f, image = img, disc = f, stroke = stroke, kind = 0 }
	end)

	cellPool = newPool(function()
		local f = circleFrame(10)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = f
		-- skin image fills the circle, clipped round by its own UICorner.
		-- ScaleType.Crop so non-square art fills without distortion. Hidden
		-- until the player actually has a skin.
		local skin = Instance.new("ImageLabel")
		skin.AnchorPoint = Vector2.new(0.5, 0.5)
		skin.Position = UDim2.fromScale(0.5, 0.5)
		skin.Size = UDim2.fromScale(1, 1)
		skin.BackgroundTransparency = 1
		skin.ScaleType = Enum.ScaleType.Crop
		skin.Visible = false
		skin.ZIndex = 10
		local skinCorner = Instance.new("UICorner")
		skinCorner.CornerRadius = UDim.new(0.5, 0)
		skinCorner.Parent = skin
		skin.Parent = f
		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLabel.Position = UDim2.fromScale(0.5, 0.4)
		nameLabel.Size = UDim2.fromScale(1.5, 0.3)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextScaled = false -- manual TextSize: TextScaled re-fits on every resize (slow)
		nameLabel.TextWrapped = false
		nameLabel.TextSize = 14
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
			skin = skin,
			stroke = stroke,
			nameLabel = nameLabel,
			massLabel = massLabel,
			lastName = "",
			lastMass = -1,
			lastNameSize = -1,
			lastMassSize = -1,
			lastSkin = -1,
			lastZ = -1,
			lastGhost = false,
			slot = -1,
		}
	end)
end

--------------------------------------------------------------------- grid

-- Pooled grid lines, parented to mapRect so they clip to the map bounds.
-- Only the visible rows/columns get a line (a few dozen frames, no corners,
-- no strokes, no text - the cheapest instances there are).
local gridV: { Frame } = {}
local gridH: { Frame } = {}

local function newGridLine(vertical: boolean): Frame
	local line = Instance.new("Frame")
	line.BackgroundColor3 = GRID_COLOR
	line.BorderSizePixel = 0
	line.ZIndex = 2
	line.Visible = false
	line.Size = vertical and UDim2.new(0, 1, 1, 0) or UDim2.new(1, 0, 0, 1)
	line.Parent = mapRect
	return line
end

local function updateGrid(scale: number, minX: number, maxX: number, minY: number, maxY: number)
	local step = Config.GridStep
	-- when zoomed out so far that grid lines are only a few pixels apart, hide
	-- the whole grid: it's just noise + overdraw at that point
	if step * scale < 6 then
		for k = 1, #gridV do
			if gridV[k].Visible then
				gridV[k].Visible = false
			end
		end
		for k = 1, #gridH do
			if gridH[k].Visible then
				gridH[k].Visible = false
			end
		end
		return
	end
	local usedV = 0
	for i = math.max(0, math.ceil(minX / step)), math.min(MAP_W / step, math.floor(maxX / step)) do
		usedV += 1
		local line = gridV[usedV]
		if not line then
			line = newGridLine(true)
			gridV[usedV] = line
		end
		line.Position = UDim2.fromOffset(math.floor(i * step * scale + 0.5), 0)
		if not line.Visible then
			line.Visible = true
		end
	end
	for k = usedV + 1, #gridV do
		if gridV[k].Visible then
			gridV[k].Visible = false
		end
	end
	local usedH = 0
	for i = math.max(0, math.ceil(minY / step)), math.min(MAP_H / step, math.floor(maxY / step)) do
		usedH += 1
		local line = gridH[usedH]
		if not line then
			line = newGridLine(false)
			gridH[usedH] = line
		end
		line.Position = UDim2.fromOffset(0, math.floor(i * step * scale + 0.5))
		if not line.Visible then
			line.Visible = true
		end
	end
	for k = usedH + 1, #gridH do
		if gridH[k].Visible then
			gridH[k].Visible = false
		end
	end
end

--------------------------------------------------------------------- setup

function Renderer.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "AgarWorld"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- static full-screen background (never moves, never resizes)
	backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	backdrop.BorderSizePixel = 0
	backdrop.ClipsDescendants = true
	backdrop.Parent = gui

	mapRect = Instance.new("Frame")
	mapRect.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
	mapRect.BorderSizePixel = 0
	mapRect.ZIndex = 1
	mapRect.ClipsDescendants = true -- grid lines clip to the map edge
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(90, 100, 130)
	edge.Thickness = 3
	edge.Parent = mapRect
	mapRect.Parent = backdrop

	buildPools()
	gui.Parent = playerGui
end

--------------------------------------------------------------------- helpers

-- Quantize positions to quarter-pixels (fine enough that motion stays smooth,
-- coarse enough to dedupe writes) and sizes to whole pixels; skip the write
-- when nothing changed so an idle scene costs zero property sets.
local function place(w, sx: number, sy: number, d: number)
	sx = math.floor(sx * 4 + 0.5) * 0.25
	sy = math.floor(sy * 4 + 0.5) * 0.25
	d = math.floor(d + 0.5)
	if w.lx ~= sx or w.ly ~= sy then
		w.lx, w.ly = sx, sy
		w.frame.Position = UDim2.fromOffset(sx, sy)
	end
	if w.ld ~= d then
		w.ld = d
		w.frame.Size = UDim2.fromOffset(d, d)
	end
end

-- active[id] = wrapper for every entity currently holding a frame
local activeOrbs = {}
local activeCells = {}
local activeViruses = {}
local activePellets = {}
local generation = 0 -- frame stamp used to release wrappers whose entity left

local visibleCellList = {} -- reused scratch for z-sorting

local lastMapScale = -1
local lastMapOx, lastMapOy = math.huge, math.huge

--------------------------------------------------------------------- render

function Renderer.render(cam)
	local viewport = Workspace.CurrentCamera.ViewportSize
	local scale = cam.scale
	-- screen position of world origin: screenX = ox + worldX * scale
	local ox = viewport.X / 2 - cam.x * scale
	local oy = viewport.Y / 2 - cam.y * scale

	-- map background: cached so it's only touched while the camera moves/zooms
	if scale ~= lastMapScale then
		lastMapScale = scale
		mapRect.Size = UDim2.fromOffset(MAP_W * scale, MAP_H * scale)
	end
	if ox ~= lastMapOx or oy ~= lastMapOy then
		lastMapOx, lastMapOy = ox, oy
		mapRect.Position = UDim2.fromOffset(ox, oy)
	end

	-- world-space view rect (+margin) used for explicit culling
	local halfW = viewport.X / 2 / scale + Config.CullMargin
	local halfH = viewport.Y / 2 / scale + Config.CullMargin
	local minX, maxX = cam.x - halfW, cam.x + halfW
	local minY, maxY = cam.y - halfH, cam.y + halfH

	updateGrid(scale, minX, maxX, minY, maxY)

	-- On-screen pixel-size cull with HYSTERESIS: an entity starts being drawn
	-- at minPx, but keeps being drawn until it shrinks past minPxLow. Without
	-- the two thresholds, anything hovering right at minPx flickers in and out
	-- frame-to-frame while zooming - the "glitch". An already-drawn entity
	-- (its id is in the active map) uses the lower threshold.
	local minPx = Config.MinRenderPixels
	local minPxLow = minPx * 0.3 -- wide hysteresis: once shown, keep drawing well below the show threshold so nothing blinks near the cutoff

	generation += 1
	local gen = generation

	-- ORBS (static in world, so only camera motion causes writes - and those
	-- are pixel-quantized leaf writes on the few dozen visible ones)
	for id, orb in WorldState.orbs do
		local px = orb.r * 2 * scale
		local w = activeOrbs[id]
		if px >= (w and minPxLow or minPx) and orb.x >= minX and orb.x <= maxX and orb.y >= minY and orb.y <= maxY then
			if not w then
				w = orbPool.acquire()
				-- the coin sentinel color renders gold; everything else is a
				-- normal palette orb
				if orb.color == Config.CoinColorIndex then
					w.frame.BackgroundColor3 = Config.CoinColor
				else
					w.frame.BackgroundColor3 = Config.Palette[orb.color] or Config.Palette[1]
				end
				activeOrbs[id] = w
			end
			place(w, ox + orb.x * scale, oy + orb.y * scale, px)
			w.gen = gen
		end
	end
	for id, w in activeOrbs do
		if w.gen ~= gen then
			orbPool.release(w)
			activeOrbs[id] = nil
		end
	end

	-- PELLETS - no pixel-size cull (they're few and bounded by MaxPellets, so
	-- always render when on-screen; the pixel cull is only for the ~1800 orbs).
	-- This is what stopped pellets from blinking/vanishing when zoomed out.
	for id, p in WorldState.view.pellets do
		local w = activePellets[id]
		if p.x >= minX and p.x <= maxX and p.y >= minY and p.y <= maxY then
			if not w then
				w = pelletPool.acquire()
				w.frame.BackgroundColor3 = WorldState.colorForSlot(p.slot)
				activePellets[id] = w
			end
			place(w, ox + p.x * scale, oy + p.y * scale, p.r * 2 * scale)
			w.gen = gen
		end
	end
	for id, w in activePellets do
		if w.gen ~= gen then
			pelletPool.release(w)
			activePellets[id] = nil
		end
	end

	-- VIRUSES and CELLS share one z-ordered list (sorted by size below):
	-- small cells hide UNDER a virus, but a cell big enough to eat the virus
	-- renders OVER it, like agar
	table.clear(visibleCellList)

	-- VIRUSES - no pixel-size cull either (few of them; always render on-screen)
	for id, v in WorldState.view.viruses do
		local px = v.r * 2 * scale
		local w = activeViruses[id]
		if v.x >= minX and v.x <= maxX and v.y >= minY and v.y <= maxY then
			if not w then
				w = virusPool.acquire()
				activeViruses[id] = w
				w.kind = -1
			end
			if w.kind ~= v.kind then
				w.kind = v.kind
				-- experimentals (mothercells) use their own sprite over a pink disc;
				-- regular viruses use the green virus sprite over a green disc. The
				-- disc shows through / behind as a fallback if the sprite can't load.
				local isExp = v.kind == 2
				w.image.Visible = true
				w.image.Image = isExp and Config.ExperimentalImageId or Config.VirusImageId
				local discColor = isExp and Config.ExperimentalColor or Config.VirusColor
				w.disc.BackgroundColor3 = discColor
				w.stroke.Color = darker(discColor)
				w.stroke.Thickness = isExp and 4 or 2
			end
			place(w, ox + v.x * scale, oy + v.y * scale, px)
			w.r = v.r
			w.zid = 100000 + id -- stable z tiebreaker (viruses sit above equal-size cells)
			table.insert(visibleCellList, w)
			w.gen = gen
		end
	end
	for id, w in activeViruses do
		if w.gen ~= gen then
			virusPool.release(w)
			activeViruses[id] = nil
		end
	end

	-- CELLS (with name/mass labels) - no pixel-size cull; always render on-screen
	for id, c in WorldState.view.cells do
		local pixels = c.r * 2 * scale
		local w = activeCells[id]
		if c.x >= minX and c.x <= maxX and c.y >= minY and c.y <= maxY then
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
				w.lastSkin = -1 -- force a skin refresh for the new occupant
			end
			-- skin image (rbxthumb renders decals reliably); cached so the
			-- Image string is only written when the skin actually changes
			local skinId = WorldState.skinForSlot(c.slot)
			if w.lastSkin ~= skinId then
				w.lastSkin = skinId
				if skinId ~= 0 then -- 0 = no skin; negative = the player's Roblox avatar
					w.skin.Image = Skins.thumb(skinId)
					w.skin.Visible = true
				else
					w.skin.Visible = false
				end
			end
			place(w, ox + c.x * scale, oy + c.y * scale, pixels)

			-- dead (ghost) cells render GRAY + faded with NO labels (their skin is
			-- already gone - the roster entry has k=0). Cached so these writes only
			-- fire when a wrapper's ghost state flips (incl. recycling onto a live cell).
			local isGhost = WorldState.isGhostSlot(c.slot)
			if w.lastGhost ~= isGhost then
				w.lastGhost = isGhost
				if isGhost then
					w.frame.BackgroundColor3 = Config.GhostColor
					w.frame.BackgroundTransparency = Config.GhostTransparency
					w.stroke.Color = darker(Config.GhostColor)
					w.stroke.Transparency = Config.GhostTransparency
				else
					-- recycled onto a live cell: restore its real colour + opacity
					local color = WorldState.colorForSlot(c.slot)
					w.frame.BackgroundColor3 = color
					w.frame.BackgroundTransparency = 0
					w.stroke.Color = darker(color)
					w.stroke.Transparency = 0
				end
			end

			-- labels only when big enough on screen AND not a dead cell (dead cells
			-- carry no name/mass); text size is manual + cached (no text re-fit)
			local showLabels = pixels >= Config.LabelMinPixels and not isGhost
			if showLabels then
				local name = WorldState.nameForSlot(c.slot)
				if w.lastName ~= name then
					w.lastName = name
					w.nameLabel.Text = name
				end
				local mass = math.floor(Util.massFromRadius(c.r) + 0.5)
				if w.lastMass ~= mass then
					w.lastMass = mass
					w.massLabel.Text = Util.abbrevMass(mass)
				end
				local nameSize = math.min(math.floor(pixels * 0.16 + 4), 40)
				if w.lastNameSize ~= nameSize then
					w.lastNameSize = nameSize
					w.nameLabel.TextSize = nameSize
				end
				local massSize = math.min(math.floor(pixels * 0.11 + 3), 28)
				if w.lastMassSize ~= massSize then
					w.lastMassSize = massSize
					w.massLabel.TextSize = massSize
				end
			end
			if w.nameLabel.Visible ~= showLabels then
				w.nameLabel.Visible = showLabels
				w.massLabel.Visible = showLabels
			end

			w.gen = gen
			w.r = c.r
			w.zid = id -- stable z tiebreaker so equal-size overlapping cells don't flip order (flicker)
			table.insert(visibleCellList, w)
		end
	end
	for id, w in activeCells do
		if w.gen ~= gen then
			cellPool.release(w)
			activeCells[id] = nil
		end
	end
	-- bigger draws over smaller, cells and viruses together: you can hide
	-- under a bigger virus, and you cover a virus you're big enough to eat.
	-- Tiebreak equal radii by a stable id so the draw order can't flip
	-- frame-to-frame. Radii here are INTERPOLATED floats, so two cells that are
	-- physically the same size (the two halves right after a split) almost
	-- never compare exactly equal - their epsilon difference flips sign each
	-- frame and swaps their draw order = the flicker on a big split. Quantize
	-- to whole world units so equal-size cells fall in one bucket and the
	-- stable zid tiebreaker actually engages.
	table.sort(visibleCellList, function(a, b)
		local ra, rb = math.floor(a.r), math.floor(b.r)
		if ra == rb then
			return a.zid < b.zid
		end
		return ra < rb
	end)
	for i, w in visibleCellList do
		-- z = sort position. The old low cap (240) made every cell past index ~230
		-- share the SAME top z in a crowd (many players split into packs), so the
		-- biggest cells z-fought and flickered - the multiplayer split "flashing".
		-- i is bounded by the on-screen entity count, so a high cap never ties in
		-- practice. (World and UI are separate ScreenGuis, so this can't collide
		-- with the interface z range.)
		local z = math.min(10 + i, 1000000)
		if w.frame.ZIndex ~= z then
			w.frame.ZIndex = z
		end
		-- Children (a cell's SKIN or a virus's SPRITE, and the cell's name/mass
		-- labels) MUST track the body's z under global Sibling z-order, or they
		-- render at their fixed creation layer while the body moves through the
		-- stack (flicker). Labels tracking z also stops overlapping labels from all
		-- sharing z=250 and z-fighting, and correctly hides a covered cell's name.
		if w.lastZ ~= z then
			w.lastZ = z
			local overlay = w.skin or w.image
			if overlay then
				overlay.ZIndex = z
			end
			if w.nameLabel then
				w.nameLabel.ZIndex = z
				w.massLabel.ZIndex = z
			end
		end
	end
end

return Renderer
