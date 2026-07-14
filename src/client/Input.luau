--[[
	Input - keybinds, mouse aim, and action dispatch.

	Aiming: every 1/Config.AimSendRate seconds the mouse position is unprojected
	to world space and fired to the server over the unreliable Aim channel
	(losing one is harmless; the next overwrites it). "Fixed Mouse" (C) locks
	the current aim DIRECTION relative to your centroid, so your cells keep
	heading the same way while you move the mouse freely (e.g. to hover UI).

	Feed (W) auto-repeats while held. Freeze (F) is a server-side toggle.
	Binds are remappable at runtime (Settings UI calls captureNext / setBind)
	and persist via the server's DataStore.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local WorldState = require(script.Parent.WorldState)
local Camera = require(script.Parent.Camera)
local Sounds = require(script.Parent.Sounds)

local FEED_REPEAT = 0.09

local Input = {
	binds = table.clone(Config.DefaultKeybinds), -- [action] = KeyCode.Name
	fixedMouse = false,
	onMenuToggle = nil, -- assigned by UI
	onBindsChanged = nil, -- assigned by UI (settings refresh)
}

local keyToAction: { [Enum.KeyCode]: string } = {}
local feeding = false
local lastFeed = 0
local aimAccumulator = 0
local fixedDirX, fixedDirY = 1, 0
local captureCallback: ((keyName: string) -> ())? = nil

local function rebuildKeyMap()
	table.clear(keyToAction)
	for action, keyName in Input.binds do
		local ok, keyCode = pcall(function()
			return (Enum.KeyCode :: any)[keyName]
		end)
		if ok and keyCode then
			keyToAction[keyCode] = action
		end
	end
end

--------------------------------------------------------------------- binds

function Input.setBind(action: string, keyName: string)
	if Config.DefaultKeybinds[action] == nil then
		return
	end
	Input.binds[action] = keyName
	rebuildKeyMap()
	Remotes.Keybinds:FireServer(Input.binds) -- persist (server debounces the DataStore write)
	if Input.onBindsChanged then
		Input.onBindsChanged()
	end
end

-- Settings UI: the next key pressed becomes the new bind for `action`.
function Input.captureNext(action: string)
	captureCallback = function(keyName)
		Input.setBind(action, keyName)
	end
end

function Input.isCapturing(): boolean
	return captureCallback ~= nil
end

--------------------------------------------------------------------- actions

local function fireAction(action: string, arg)
	Remotes.Action:FireServer(action, arg)
end

local function splitSfx()
	if WorldState.status == "alive" then
		Sounds.play("split")
	end
end

local function dispatch(action: string)
	if action == "Split" then
		fireAction("split")
		splitSfx()
	elseif action == "MultiSplit" then
		fireAction("multisplit")
		splitSfx()
	elseif action == "TripleSplit" then
		fireAction("triplesplit")
		splitSfx()
	elseif action == "Feed" then
		feeding = true
		lastFeed = 0 -- fire immediately on next tick
	elseif action == "Freeze" then
		fireAction("freeze")
	elseif action == "Respawn" then
		fireAction("respawn")
	elseif action == "ToMenu" then
		fireAction("tomenu")
	elseif action == "FixedMouse" then
		Input.fixedMouse = not Input.fixedMouse
		if Input.fixedMouse then
			-- lock the direction the cursor currently points at
			local mouse = UserInputService:GetMouseLocation()
			local wx, wy = Camera.screenToWorld(mouse.X, mouse.Y)
			fixedDirX, fixedDirY = Util.unit(wx - WorldState.own.x, wy - WorldState.own.y)
		end
	elseif action == "Menu" then
		if Input.onMenuToggle then
			Input.onMenuToggle()
		end
	end
end

-- Public: fire an action by its bind name (e.g. "Split", "Feed"), exactly as if
-- the key were pressed. Used by the on-screen ability dock (and mobile taps).
function Input.trigger(action: string)
	dispatch(action)
end

--------------------------------------------------------------------- wiring

function Input.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		-- rebind capture takes priority over everything (and works while a
		-- text box focus would otherwise mark input as processed)
		if captureCallback then
			local cb = captureCallback
			captureCallback = nil
			cb(input.KeyCode.Name)
			return
		end
		if gameProcessed then
			return
		end
		local action = keyToAction[input.KeyCode]
		if action then
			dispatch(action)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and keyToAction[input.KeyCode] == "Feed" then
			feeding = false
		end
	end)

	-- mouse wheel: manual zoom (wheel up = in, wheel down = out)
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
			if input.Position.Z > 0 then
				Camera.zoomBy(1 / Config.ZoomWheelStep)
			elseif input.Position.Z < 0 then
				Camera.zoomBy(Config.ZoomWheelStep)
			end
		end
	end)

	Remotes.Keybinds.OnClientEvent:Connect(function(saved)
		if typeof(saved) == "table" then
			for action in Config.DefaultKeybinds do
				if typeof(saved[action]) == "string" then
					Input.binds[action] = saved[action]
				end
			end
			rebuildKeyMap()
			if Input.onBindsChanged then
				Input.onBindsChanged()
			end
		end
	end)

	rebuildKeyMap()
end

-- Called every frame from the client bootstrap.
function Input.tick(dt: number, now: number)
	-- held-feed auto repeat; smaller you are, the faster it repeats (matches the
	-- server's size-scaled feed cooldown, so small cells shoot viruses quicker)
	if feeding and WorldState.status == "alive" then
		local interval = FEED_REPEAT * math.clamp(WorldState.own.mass / Config.StartMass, 0.4, 1.6)
		if now - lastFeed >= interval then
			lastFeed = now
			fireAction("feed")
		end
	end

	-- throttled aim updates
	aimAccumulator += dt
	if aimAccumulator < 1 / Config.AimSendRate then
		return
	end
	aimAccumulator = 0

	local wx, wy
	if Input.fixedMouse then
		-- aim stays a fixed offset ahead of the centroid: constant direction
		wx = WorldState.own.x + fixedDirX * 600
		wy = WorldState.own.y + fixedDirY * 600
	else
		local mouse = UserInputService:GetMouseLocation()
		wx, wy = Camera.screenToWorld(mouse.X, mouse.Y)
	end
	Remotes.Aim:FireServer(math.clamp(wx, 0, Config.MapWidth), math.clamp(wy, 0, Config.MapHeight))
end

return Input
