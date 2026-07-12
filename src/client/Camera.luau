--[[
	Camera - 2D view transform (position + zoom). Not the Roblox 3D camera:
	the world is drawn entirely in a ScreenGui; this just decides which slice.

	scale = screen pixels per world unit. Zoom follows your largest cell
	(bigger = see more) with exponential smoothing so growth doesn't snap.
	When dead / in the menu / spectating, the camera follows the current
	leaderboard leader (the server anchors interest there too).
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
}

function Camera.update(dt: number)
	local targetX, targetY = Camera.x, Camera.y
	local targetViewHeight

	if WorldState.status == "alive" and WorldState.own.count > 0 then
		targetX, targetY = WorldState.own.x, WorldState.own.y
		targetViewHeight = math.clamp(
			Config.ViewHeightBase + WorldState.own.maxR * Config.ViewHeightPerRadius,
			Config.ViewHeightMin,
			Config.ViewHeightMax
		)
	else
		-- menu / dead / spectate: follow the leader if we can see them
		targetViewHeight = Config.SpectateViewHeight
		local top = WorldState.leaderboard[1]
		if top then
			local cx, cy = WorldState.slotCentroid(top.s)
			if cx then
				targetX, targetY = cx, cy :: any
			end
		end
	end

	-- exponential smoothing (frame-rate independent)
	local posAlpha = 1 - math.exp(-Config.CameraSmoothing * dt)
	local zoomAlpha = 1 - math.exp(-Config.ZoomSmoothing * dt)
	Camera.x += (targetX - Camera.x) * posAlpha
	Camera.y += (targetY - Camera.y) * posAlpha
	Camera.viewHeight += (targetViewHeight - Camera.viewHeight) * zoomAlpha

	local viewport = Workspace.CurrentCamera.ViewportSize
	Camera.scale = viewport.Y / Camera.viewHeight
end

-- screen pixel -> world position (used for aiming)
function Camera.screenToWorld(sx: number, sy: number): (number, number)
	local viewport = Workspace.CurrentCamera.ViewportSize
	return Camera.x + (sx - viewport.X / 2) / Camera.scale, Camera.y + (sy - viewport.Y / 2) / Camera.scale
end

return Camera
