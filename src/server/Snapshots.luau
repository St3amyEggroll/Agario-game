--[[
	Snapshots - full-world snapshot broadcast + leaderboard.

	The map is small, so there is NO interest culling: every client receives
	EVERY dynamic entity (cells, viruses, pellets) in one shared buffer over a
	RELIABLE RemoteEvent. Reliable delivery + a stable full entity set is what
	removes the flicker/phantom-blink that interest+byte-budget culling caused
	(entities near the packing cutoff blinked in and out between snapshots).

	One buffer is built per tick and FireAllClients'd - cheaper than the old
	per-player packing, too. Bandwidth is bounded by MaxPellets + cell/virus
	counts; for a much larger map this would move to chunked unreliable sends.

	Orbs are still separate: they never move, so they sync reliably as
	eat/respawn deltas (flushed here at snapshot cadence, broadcast to all).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Codec = require(Shared.SnapshotCodec)
local Remotes = require(Shared.Remotes)
local LevelCurve = require(Shared.Levels)
local World = require(script.Parent.World)
local Levels = require(script.Parent.Levels)

local Snapshots = {}

--------------------------------------------------------------------- orbs

local function flushOrbDeltas()
	local removals = World.pendingOrbRemovals
	local spawns = World.pendingOrbSpawns
	if #removals == 0 and #spawns == 0 then
		return
	end
	-- delta records hold u8 counts -> chunk at 255 (only matters in mass-eat bursts)
	while #removals > 0 or #spawns > 0 do
		local remChunk, spawnChunk = {}, {}
		for _ = 1, math.min(255, #removals) do
			table.insert(remChunk, table.remove(removals))
		end
		for _ = 1, math.min(255, #spawns) do
			table.insert(spawnChunk, table.remove(spawns))
		end
		Remotes.OrbSync:FireAllClients("delta", Codec.packOrbDelta(remChunk, spawnChunk))
	end
end

function Snapshots.sendFullOrbs(player)
	local arr = {}
	for _, orb in World.orbs do
		table.insert(arr, orb)
	end
	Remotes.OrbSync:FireClient(player, "full", Codec.packOrbsFull(arr))
end

--------------------------------------------------------------------- send

function Snapshots.send()
	flushOrbDeltas()

	-- One buffer, the whole world, to everyone. World.cells / .viruses / .pellets
	-- are already the live arrays with exactly the fields the codec needs.
	-- Timestamp is the SIMULATION clock (time of the tick that produced these
	-- positions), so client interpolation stays aligned with server motion.
	local buf = Codec.packSnapshot(World.now, World.cells, World.viruses, World.pellets)
	Remotes.Snapshot:FireAllClients(buf)
end

--------------------------------------------------------------------- leaderboard

function Snapshots.sendLeaderboard()
	-- push any changed XP totals to their owners (drives the client level bar)
	Levels.pushChanged()

	local entries = {}
	for player, info in World.players do
		local mass = info.alive and math.floor(World.totalMass(info) + 0.5) or 0
		if mass > (info.bestMass or 0) then
			info.bestMass = mass -- session peak, fed to the all-time Records board
		end
		-- Roblox native player-list columns: Level (always) + Mass (in-game)
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local massValue = ls:FindFirstChild("Mass")
			if massValue then
				massValue.Value = mass -- raw number: the native list sorts by this (biggest on top)
			end
			local levelValue = ls:FindFirstChild("Level")
			if levelValue then
				levelValue.Value = LevelCurve.levelForXp(info.xp)
			end
		end
		if info.alive then
			table.insert(entries, { s = info.slot, n = info.name, m = mass })
		end
	end
	-- still broadcast the top list: the client uses it to pick the spectate/menu
	-- camera's leader (the custom UI panel is gone)
	table.sort(entries, function(a, b)
		return a.m > b.m
	end)
	for i = #entries, 11, -1 do
		entries[i] = nil
	end
	Remotes.Leaderboard:FireAllClients(entries)
end

return Snapshots
