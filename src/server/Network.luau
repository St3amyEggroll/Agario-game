--[[
	Network - server-side remote handlers + player lifecycle.

	Trust nothing from the client: aim coordinates are type-checked, NaN-guarded
	and clamped to the map; actions pass a whitelist + per-action rate limit
	before they're queued for the simulation; skin indexes are range-checked.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)
local Simulation = require(script.Parent.Simulation)
local Snapshots = require(script.Parent.Snapshots)
local Keybinds = require(script.Parent.Keybinds)

local Network = {}

-- minimum seconds between accepted uses, per action
local ACTION_COOLDOWN: { [string]: number } = {
	split = Config.SplitCooldown,
	multisplit = Config.MultiSplitCooldown,
	triplesplit = Config.MultiSplitCooldown,
	feed = Config.FeedCooldown,
	freeze = 0.1,
	respawn = 1,
	play = 0.5,
	spectate = 0.25,
	setskin = 0.2,
}

local function isFiniteNumber(v): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

local function onAim(player, x, y)
	local info = World.players[player]
	if not info or not isFiniteNumber(x) or not isFiniteNumber(y) then
		return
	end
	info.aimX = math.clamp(x, 0, Config.MapWidth)
	info.aimY = math.clamp(y, 0, Config.MapHeight)
end

local function onAction(player, action, arg)
	local info = World.players[player]
	if not info or typeof(action) ~= "string" then
		return
	end
	local cooldown = ACTION_COOLDOWN[action]
	if not cooldown then
		return -- not a real action
	end
	local now = os.clock()
	local last = info.lastAction[action]
	if last and now - last < cooldown then
		return
	end
	info.lastAction[action] = now

	if action == "setskin" then
		if not isFiniteNumber(arg) then
			return
		end
		arg = math.floor(arg)
		if arg < 1 or arg > #Config.Palette then
			return
		end
	end
	Simulation.enqueue(player, action, arg)
end

local function sendFullRoster(player)
	-- slot keys are sent as strings: sparse numeric keys don't survive remote
	-- serialization reliably
	local roster = {}
	for slot, info in World.slotToInfo do
		roster[tostring(slot)] = { n = info.name, c = info.colorIdx }
	end
	local myInfo = World.players[player]
	Remotes.Roster:FireClient(player, "full", roster, myInfo.slot)
end

local function onPlayerAdded(player)
	-- no 3D avatar in a 2D game; nuke any character that slipped through
	if player.Character then
		player.Character:Destroy()
	end
	local info = World.addPlayer(player)
	sendFullRoster(player)
	World.broadcastRosterUpdate(info)
	Snapshots.sendFullOrbs(player)
	Keybinds.onPlayerAdded(player)
end

local function onPlayerRemoving(player)
	local info = World.players[player]
	Keybinds.onPlayerRemoving(player)
	World.removePlayer(player)
	if info then
		Remotes.Roster:FireAllClients("remove", info.slot)
	end
end

function Network.init()
	Remotes.Aim.OnServerEvent:Connect(onAim)
	Remotes.Action.OnServerEvent:Connect(onAction)
	Remotes.Ping.OnServerEvent:Connect(function(player, t)
		-- pure echo; the client computes RTT from its own clock
		Remotes.Ping:FireClient(player, t)
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- players who joined before this script ran (fast Studio starts)
	for _, player in Players:GetPlayers() do
		if not World.players[player] then
			task.spawn(onPlayerAdded, player)
		end
	end
end

return Network
