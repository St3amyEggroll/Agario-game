--[[
	Snapshots - interest management + snapshot packing + leaderboard.

	Per client, per send (Config.SnapshotRate Hz):
	  1. pick a view center: own mass-weighted centroid when alive, otherwise
	     the top player's centroid (menu/spectate camera follows the leader)
	  2. query the dynamic spatial hash around it (interest radius grows with
	     the player's largest cell so zoomed-out giants still see their prey)
	  3. sort candidates by distance and pack closest-first into a buffer,
	     stopping at Config.SnapshotByteBudget - UnreliableRemoteEvents drop
	     payloads over ~900 bytes, so the budget IS the interest cap. Own cells
	     are always packed first and always fit (16 * 9 bytes max).

	Orbs are NOT in snapshots: they never move, so they're synced reliably as
	eat/respawn deltas (flushed here at snapshot cadence, broadcast to all).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Codec = require(Shared.SnapshotCodec)
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)

local Snapshots = {}

-- reused scratch (server is single-threaded; no reentrancy)
local candCells = {}
local candViruses = {}
local candPellets = {}

local function byDist(a, b)
	return a._d2 < b._d2
end

local function centroidOf(info): (number, number, number)
	local totalM, cx, cy, maxR = 0, 0, 0, 0
	for _, cell in info.cells do
		totalM += cell.m
		cx += cell.x * cell.m
		cy += cell.y * cell.m
		maxR = math.max(maxR, cell.r)
	end
	if totalM > 0 then
		return cx / totalM, cy / totalM, maxR
	end
	return Config.MapWidth / 2, Config.MapHeight / 2, 0
end

local function topAliveInfo()
	local best, bestMass = nil, -1
	for _, info in World.players do
		if info.alive and #info.cells > 0 then
			local m = World.totalMass(info)
			if m > bestMass then
				best, bestMass = info, m
			end
		end
	end
	return best
end

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

	local top = topAliveInfo()
	local topX, topY = Config.MapWidth / 2, Config.MapHeight / 2
	if top then
		topX, topY = centroidOf(top)
	end

	for _, player in Players:GetPlayers() do
		local info = World.players[player]
		if not info then
			continue
		end

		local viewX, viewY, interest
		if info.alive and #info.cells > 0 then
			local maxR
			viewX, viewY, maxR = centroidOf(info)
			interest = math.min(Config.InterestBase + maxR * Config.InterestPerRadius, Config.InterestMax)
		else
			viewX, viewY = topX, topY
			interest = Config.SpectatorInterest
		end

		-- gather candidates near the view center
		table.clear(candCells)
		table.clear(candViruses)
		table.clear(candPellets)
		World.dynHash:forEachInAABB(viewX - interest, viewY - interest, viewX + interest, viewY + interest, function(e)
			if e.dead then
				return
			end
			e._d2 = Util.dist2(viewX, viewY, e.x, e.y)
			if e.kind == "cell" then
				if e.player ~= player then -- own cells added unconditionally below
					table.insert(candCells, e)
				end
			elseif e.kind == "pellet" then
				table.insert(candPellets, e)
			else
				table.insert(candViruses, e)
			end
		end)
		table.sort(candCells, byDist)
		table.sort(candViruses, byDist)
		table.sort(candPellets, byDist)

		-- pack closest-first under the byte budget, priority: own cells >
		-- enemy cells > viruses > pellets
		local budget = Config.SnapshotByteBudget - Codec.HEADER_BYTES
		local cells, viruses, pellets = {}, {}, {}
		for _, cell in info.cells do
			table.insert(cells, cell)
			budget -= Codec.CELL_BYTES
		end
		-- keep room for at least a few viruses (they're gameplay-critical:
		-- an invisible virus you pop on feels like a cheat)
		local virusReserve = math.min(#candViruses, 8) * Codec.VIRUS_BYTES
		for _, e in candCells do
			if budget - virusReserve < Codec.CELL_BYTES or #cells >= 255 then
				break
			end
			table.insert(cells, e)
			budget -= Codec.CELL_BYTES
		end
		for _, e in candViruses do
			if budget < Codec.VIRUS_BYTES or #viruses >= 255 then
				break
			end
			table.insert(viruses, e)
			budget -= Codec.VIRUS_BYTES
		end
		for _, e in candPellets do
			if budget < Codec.PELLET_BYTES or #pellets >= 255 then
				break
			end
			table.insert(pellets, e)
			budget -= Codec.PELLET_BYTES
		end

		-- timestamp with the SIMULATION clock (time of the tick that produced
		-- these positions), not send-time: 30 Hz ticks vs 20 Hz sends alias by
		-- up to 33 ms, and stamping send-time makes interpolation wobble
		Remotes.Snapshot:FireClient(player, Codec.packSnapshot(World.now, cells, viruses, pellets))
	end
end

--------------------------------------------------------------------- leaderboard

function Snapshots.sendLeaderboard()
	local entries = {}
	for _, info in World.players do
		if info.alive then
			table.insert(entries, { s = info.slot, n = info.name, m = math.floor(World.totalMass(info) + 0.5) })
		end
	end
	table.sort(entries, function(a, b)
		return a.m > b.m
	end)
	for i = #entries, 11, -1 do
		entries[i] = nil
	end
	Remotes.Leaderboard:FireAllClients(entries)
end

return Snapshots
