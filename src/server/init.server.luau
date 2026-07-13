--[[
	Server bootstrap.

	The simulation runs on a FIXED timestep (Config.TickRate) accumulated off
	Heartbeat: rendering rate, network rate and simulation rate are all fully
	decoupled. Snapshots go out at Config.SnapshotRate, the leaderboard at
	Config.LeaderboardRate.

	No physics, no characters: CharacterAutoLoads is off and the entire game is
	data in ModuleScripts (see World/Simulation).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

Players.CharacterAutoLoads = false

-- requiring Remotes on the server creates all RemoteEvents before any client
-- can start waiting on them
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Remotes)

local World = require(script.World)
local Simulation = require(script.Simulation)
local Snapshots = require(script.Snapshots)
local Network = require(script.Network)

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

World.init()
Network.init()

local TICK = 1 / Config.TickRate
local SNAP_INTERVAL = 1 / Config.SnapshotRate
local LB_INTERVAL = 1 / Config.LeaderboardRate

-- simClock advances by EXACTLY one TICK per simulation step. Snapshots are
-- stamped with it (via World.now), so the timestamp on a snapshot matches the
-- fixed-step time its positions were computed at. Stamping with real wall-clock
-- time instead (which drifts against the fixed step) made the client
-- interpolation stutter.
local simClock = 0
local simAccumulator = 0
local snapAccumulator = 0
local lbAccumulator = 0

RunService.Heartbeat:Connect(function(dt)
	-- fixed-step simulation with a spiral-of-death guard: if the server ever
	-- stalls longer than 5 ticks, drop the excess time instead of trying to
	-- catch up forever
	simAccumulator += dt
	local steps = 0
	while simAccumulator >= TICK and steps < 5 do
		simClock += TICK
		Simulation.step(TICK, simClock)
		simAccumulator -= TICK
		steps += 1
	end
	if simAccumulator > TICK * 5 then
		simAccumulator = 0
	end

	snapAccumulator += dt
	if snapAccumulator >= SNAP_INTERVAL then
		snapAccumulator %= SNAP_INTERVAL
		Snapshots.send()
	end

	lbAccumulator += dt
	if lbAccumulator >= LB_INTERVAL then
		lbAccumulator %= LB_INTERVAL
		Snapshots.sendLeaderboard()
	end
end)

print(("[Agar] server up: %dx%d map, %d orbs, %d viruses, tick %d Hz, snapshots %d Hz"):format(
	Config.MapWidth,
	Config.MapHeight,
	Config.OrbCount,
	Config.VirusCount + Config.ExperimentalCount,
	Config.TickRate,
	Config.SnapshotRate
))
