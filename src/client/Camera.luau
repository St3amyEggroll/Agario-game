--[[
	Camera - 2D view transform (position + zoom). Not the Roblox 3D camera:
	the world is drawn entirely in a ScreenGui; this just decides which slice.

	scale = screen pixels per world unit. Zoom = auto (follows your largest
	cell, bigger = see more) * manual zoomFactor (mouse wheel), smoothed
	exponentially. When dead / in the menu / spectating, the camera follows the
	current leaderboard leader (the server anchors interest there too).

	PERF: position/zoom SNAP to their targets once close enough. Without the
	snap the lerp never quite settles, which would keep dirtying every rendered
	frame's Position forever even in a still scene.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local WorldState = require(script.Parent.WorldState)

local Camera = {
	x = Config.MapWidth / 2,
	y = Config.MapHeight / 2,
	scale = 0.3,
	viewHeight = Config.SpectateViewHeight,
	zoomFactor = 1, -- manual mouse-wheel zoom; >1 = zoomed out
}

-- called by Input on mouse wheel
function Camera.zoomBy(mult: number)
	Camera.zoomFactor = math.clamp(Camera.zoomFactor * mult, Config.ManualZoomMin, Config.ManualZoomMax)
end

function Camera.update(dt: number)
	local targetX, targetY = Camera.x, Camera.y
	local autoViewHeight

	if WorldState.status == "alive" and WorldState.own.count > 0 then
		targetX, targetY = WorldState.own.x, WorldState.own.y
		-- zoom is based on TOTAL mass, not the largest cell - total mass is
		-- conserved when you split/merge, so the camera doesn't zoom in/out on
		-- split or merge (only when you actually gain/lose mass)
		local effR = math.sqrt(math.max(WorldState.own.mass, 1)) * Config.RadiusPerSqrtMass
		autoViewHeight = Config.ViewHeightBase + effR * Config.ViewHeightPerRadius
	else
		-- menu / dead / spectate: follow the leader if we can see them
		autoViewHeight = Config.SpectateViewHeight
		local top = WorldState.leaderboard[1]
		if top then
			local cx, cy = WorldState.slotCentroid(top.s)
			if cx then
				targetX, targetY = cx, cy :: any
			end
		end
	end
	local targetViewHeight =
		math.clamp(autoViewHeight * Camera.zoomFactor, Config.ViewHeightMin, Config.ViewHeightMax)

	-- exponential smoothing (frame-rate independent), snapping when settled
	local posAlpha = 1 - math.exp(-Config.CameraSmoothing * dt)
	local zoomAlpha = 1 - math.exp(-Config.ZoomSmoothing * dt)
	local dx, dy = targetX - Camera.x, targetY - Camera.y
	Camera.x = math.abs(dx) < 0.5 and targetX or Camera.x + dx * posAlpha
	Camera.y = math.abs(dy) < 0.5 and targetY or Camera.y + dy * posAlpha
	local dv = targetViewHeight - Camera.viewHeight
	Camera.viewHeight = math.abs(dv) < 1 and targetViewHeight or Camera.viewHeight + dv * zoomAlpha

	local viewport = Workspace.CurrentCamera.ViewportSize
	Camera.scale = viewport.Y / Camera.viewHeight
end

-- screen pixel -> world position (used for aiming)
function Camera.screenToWorld(sx: number, sy: number): (number, number)
	local viewport = Workspace.CurrentCamera.ViewportSize
	return Camera.x + (sx - viewport.X / 2) / Camera.scale, Camera.y + (sy - viewport.Y / 2) / Camera.scale
end

return Camera
