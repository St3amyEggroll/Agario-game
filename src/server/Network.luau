--[[
	Network - server-side remote handlers + player lifecycle.

	Trust nothing from the client: aim coordinates are type-checked, NaN-guarded
	and clamped to the map; actions pass a whitelist + per-action rate limit
	before they're queued for the simulation; skin indexes are range-checked.
]]

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)
local Simulation = require(script.Parent.Simulation)
local Snapshots = require(script.Parent.Snapshots)
local Keybinds = require(script.Parent.Keybinds)
local Names = require(script.Parent.Names)

local Network = {}

-- minimum seconds between accepted uses, per action
local ACTION_COOLDOWN: { [string]: number } = {
	split = Config.SplitCooldown,
	multisplit = Config.MultiSplitCooldown,
	triplesplit = Config.MultiSplitCooldown,
	feed = Config.FeedCooldown,
	freeze = 0.1,
	pulltogether = Config.PullCooldown,
	speedboost = Config.SpeedBoostCooldown,
	respawn = 0.5,
	tomenu = 0.5,
	play = 0.5,
	spectate = 0.25,
	setskin = 0.2,
	setname = 0.5,
	debugmass = 0.05,
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
	-- smaller cells split slightly faster: scale the split cooldown by your
	-- largest cell's mass (small = shorter cooldown)
	if action == "split" or action == "multisplit" or action == "triplesplit" then
		local maxMass = 0
		for _, cell in info.cells do
			if cell.m > maxMass then
				maxMass = cell.m
			end
		end
		cooldown = cooldown * math.clamp(maxMass / Config.StartMass, 0.7, 1.0)
	end
	local now = os.clock()
	local last = info.lastAction[action]
	if last and now - last < cooldown then
		return
	end
	info.lastAction[action] = now

	if action == "setskin" then
		-- arg is an image/decal asset id (0 clears the skin). Any non-negative
		-- integer is allowed so players can paste custom ids, not only catalog
		-- entries; a bad id just renders as a blank image, never a crash.
		if not isFiniteNumber(arg) then
			return
		end
		arg = math.floor(arg)
		if arg < 0 or arg > 1e12 then
			return
		end
		Names.saveSkin(player, arg) -- persist the equipped skin across sessions
	elseif action == "debugmass" then
		-- testing helper: only a direction is accepted (the server owns the
		-- step size), and only while Config.Debug is on
		if not Config.Debug or not isFiniteNumber(arg) then
			return
		end
		arg = arg >= 0 and 1 or -1
	elseif action == "setname" then
		-- names are filtered + persisted asynchronously, not run through the
		-- simulation queue
		Names.setName(player, arg)
		return
	end
	Simulation.enqueue(player, action, arg)
end

local function sendFullRoster(player)
	-- slot keys are sent as strings: sparse numeric keys don't survive remote
	-- serialization reliably
	local roster = {}
	for slot, info in World.slotToInfo do
		roster[tostring(slot)] = { n = info.name, c = info.colorIdx, k = info.skinId }
	end
	local myInfo = World.players[player]
	Remotes.Roster:FireClient(player, "full", roster, myInfo.slot)
end

local function onPlayerAdded(player)
	-- no 3D avatar in a 2D game; nuke any character that slipped through
	if player.Character then
		player.Character:Destroy()
	end
	-- Roblox native leaderboard: a leaderstats/Mass value shown in the player
	-- list (updated each leaderboard tick in Snapshots.sendLeaderboard)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local mass = Instance.new("IntValue")
	mass.Name = "Mass"
	mass.Parent = ls
	ls.Parent = player

	local info = World.addPlayer(player)
	sendFullRoster(player)
	World.broadcastRosterUpdate(info)
	Snapshots.sendFullOrbs(player)
	Keybinds.onPlayerAdded(player)
	Names.onPlayerAdded(player) -- async: loads saved name, then prefills the client box

	-- chat bubbles: when a player chats, filter it and broadcast (slot, text)
	-- so every client can float a bubble above that player's cell
	player.Chatted:Connect(function(message)
		task.spawn(function()
			local pinfo = World.players[player]
			if not pinfo or typeof(message) ~= "string" then
				return
			end
			local text = message:gsub("[%c]", ""):sub(1, Config.MaxChatLength)
			if #text == 0 then
				return
			end
			local ok, filtered = pcall(function()
				local obj = TextService:FilterStringAsync(text, player.UserId)
				return obj:GetNonChatStringForBroadcastAsync()
			end)
			Remotes.Chat:FireAllClients(pinfo.slot, (ok and filtered) or text)
		end)
	end)
end

local function onPlayerRemoving(player)
	local info = World.players[player]
	Keybinds.onPlayerRemoving(player)
	Names.onPlayerRemoving(player)
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
