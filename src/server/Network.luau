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
local Levels = require(script.Parent.Levels)
local Records = require(script.Parent.Records)
local Abilities = require(script.Parent.Abilities)
local Skins = require(Shared.Skins)
local LevelCurve = require(Shared.Levels)

local Network = {}

-- minimum seconds between accepted uses, per action
local ACTION_COOLDOWN: { [string]: number } = {
	split = Config.SplitCooldown,
	multisplit = Config.MultiSplitCooldown,
	triplesplit = Config.MultiSplitCooldown,
	feed = Config.FeedCooldown,
	freeze = 0.1,
	respawn = 0.5,
	tomenu = 0.5,
	play = 0.5,
	spectate = 0.25,
	setskin = 0.2,
	setavatar = 0.2,
	setcolor = 0.2,
	setaccessory = 0.2,
	setname = 0.5,
	setautorespawn = 0.2,
	buyability = 0.3,
	useability = 0.1, -- the REAL gate is the per-ability cooldown in Abilities
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
		-- smaller cells split faster; even big cells get a slight speed-up (cap
		-- at 0.85 instead of 1.0) so splitting stays snappy at big sizes
		cooldown = cooldown * math.clamp(maxMass / Config.StartMass, 0.65, 0.85)
	elseif action == "feed" then
		local maxMass = 0
		for _, cell in info.cells do
			if cell.m > maxMass then
				maxMass = cell.m
			end
		end
		-- the smaller you are, the FASTER you feed (so small cells shoot viruses
		-- quicker); big cells feed a bit slower
		cooldown = cooldown * math.clamp(maxMass / Config.StartMass, 0.4, 1.6)
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
		-- cap high enough for modern asset ids (level-skin ids are ~1e14)
		if arg < 0 or arg > 1e16 then
			return
		end
		-- level-locked skins: reject if the player hasn't reached the unlock level
		-- (custom pasted ids and free catalog skins have requiredLevel 0)
		local reqLevel = Skins.requiredLevel(arg)
		if reqLevel > 0 and LevelCurve.levelForXp(info.xp) < reqLevel then
			return
		end
		Names.saveSkin(player, arg) -- persist the equipped skin across sessions
	elseif action == "setavatar" then
		-- toggle your avatar as an OVERLAY layer (over the skin). Encoded as
		-- -UserId so any client renders this player's headshot; server-set from the
		-- real UserId so it can't be spoofed.
		Simulation.enqueue(player, "setaccessory", -player.UserId)
		Names.saveOverlays(player)
		return
	elseif action == "setcolor" then
		-- pick your cell colour: a packed 0xRRGGBB int (from the HSV picker or a
		-- palette swatch). Clears any skin so the plain coloured cell shows.
		-- Persisted like the skin.
		if not isFiniteNumber(arg) then
			return
		end
		arg = math.floor(arg)
		if arg < 0 or arg > 0xFFFFFF then
			return
		end
		Names.saveColor(player, arg)
		Names.saveSkin(player, 0)
		Simulation.enqueue(player, "setcolor", arg)
		return
	elseif action == "setaccessory" then
		-- toggle an accessory overlay id (0 clears ALL overlays). Positive id.
		if not isFiniteNumber(arg) then
			return
		end
		arg = math.floor(arg)
		if arg < 0 or arg > 1e16 then
			return
		end
		Simulation.enqueue(player, "setaccessory", arg)
		Names.saveOverlays(player)
		return
	elseif action == "setautorespawn" then
		-- Settings toggle: on death, instantly respawn instead of the death menu.
		-- Boolean only; the instant respawn itself happens in Simulation.deathCheck.
		info.autoRespawn = arg == true
		return
	elseif action == "buyability" then
		-- purchase an ability with Gold (validated in Abilities.buy). arg = id.
		if typeof(arg) ~= "string" then
			return
		end
		Abilities.buy(player, arg)
		return
	elseif action == "useability" then
		-- fire an owned ability. arg = id. Cooldown + ownership are enforced here;
		-- the EFFECT of a "self" ability runs in the simulation. "place"/"target"
		-- abilities aren't wired yet, so we just tell the client (no cooldown spent).
		if typeof(arg) ~= "string" or not info.alive then
			return
		end
		if not Abilities.canUse(info, arg) then
			return
		end
		local def = Abilities.byId[arg]
		if not def then
			return
		end
		if def.kind == "self" then
			Abilities.startCooldown(player, info, arg)
			Simulation.enqueue(player, "ability", arg)
		else
			Remotes.Feedback:FireClient(player, "soon", def.name)
		end
		return
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
		roster[tostring(slot)] = { n = info.name, c = info.color, k = info.skinId, a = World.overlaysArray(info) }
	end
	-- include lingering ghost slots so a late joiner renders them faded too
	for slot, entry in World.ghostRoster do
		roster[tostring(slot)] = entry
	end
	local myInfo = World.players[player]
	Remotes.Roster:FireClient(player, "full", roster, myInfo.slot)
end

-- Filter a chat message and broadcast (slot, text) to every client, which drives
-- both the chat log and the cell chat bubbles. Rate-limited per player.
local chatLast: { [Player]: number } = {}
local function sendChat(player, message)
	if typeof(message) ~= "string" then
		return
	end
	local now = os.clock()
	if chatLast[player] and now - chatLast[player] < Config.ChatCooldown then
		return
	end
	chatLast[player] = now
	task.spawn(function()
		local pinfo = World.players[player]
		if not pinfo then
			return
		end
		local text = message:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, Config.MaxChatLength)
		if #text == 0 then
			return
		end
		local ok, filtered = pcall(function()
			local obj = TextService:FilterStringAsync(text, player.UserId)
			return obj:GetNonChatStringForBroadcastAsync()
		end)
		Remotes.Chat:FireAllClients(pinfo.slot, (ok and filtered) or text)
	end)
end

local function onPlayerAdded(player)
	-- no 3D avatar in a 2D game; nuke any character that slipped through
	if player.Character then
		player.Character:Destroy()
	end
	-- Roblox native player list: Mass + Level columns (updated each leaderboard
	-- tick in Snapshots.sendLeaderboard). The native list sorts players by the
	-- FIRST numeric leaderstat, so Mass is added first (and kept an IntValue) to
	-- rank everyone by current size - biggest on top.
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local mass = Instance.new("IntValue")
	mass.Name = "Mass"
	mass.Value = 0
	mass.Parent = ls
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = ls
	ls.Parent = player

	local info = World.addPlayer(player)
	sendFullRoster(player)
	World.broadcastRosterUpdate(info)
	Snapshots.sendFullOrbs(player)
	Keybinds.onPlayerAdded(player)
	Names.onPlayerAdded(player) -- async: loads saved name, then prefills the client box
	Levels.onPlayerAdded(player) -- async: loads saved XP, then sends it so the HUD shows the right level
	Abilities.onPlayerAdded(player) -- async: loads owned abilities, then syncs the dock

	-- also accept the in-game chat box (Roblox chat may be disabled client-side)
	player.Chatted:Connect(function(message)
		sendChat(player, message)
	end)
end

local function onPlayerRemoving(player)
	local info = World.players[player]
	if info then
		-- final all-time record: best mass + this session's kills + playtime
		Records.submit(player.UserId, info.name, info.bestMass or 0, info.kills or 0, info.playSeconds or 0)
	end
	Keybinds.onPlayerRemoving(player)
	Names.onPlayerRemoving(player)
	Levels.onPlayerRemoving(player) -- final XP save
	Abilities.onPlayerRemoving(player) -- final owned-abilities save
	chatLast[player] = nil
	-- leaves the player's cells behind as ghost cells and keeps the slot's roster
	-- entry alive until they're eaten; only broadcasts the roster "remove" once no
	-- ghosts remain (handled inside removePlayer)
	World.removePlayer(player)
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
