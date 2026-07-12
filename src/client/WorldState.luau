--[[
	WorldState - the client's mirror of the world + snapshot interpolation.

	Snapshots arrive over an UNRELIABLE channel: they can be lost, duplicated
	or reordered. We keep a small time-sorted buffer, ignore anything not newer
	than what we have, and every render frame sample the world at
	  renderTime = newestSnapshot.t - Config.InterpolationDelay
	Lerping between the two snapshots that bracket renderTime gives perfectly
	smooth motion at any FPS from ~20 Hz network data - the whole reason the
	game feels lag-free.

	Orbs live outside snapshots: a full reliable sync on join, then tiny
	eat/respawn deltas keep a complete map-wide orb table locally (a few
	hundred static entries; the renderer culls them to the viewport).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Codec = require(Shared.SnapshotCodec)
local Remotes = require(Shared.Remotes)

local MAX_SNAPSHOTS = 30

local WorldState = {
	orbs = {}, -- [id] = {x, y, color, r}
	roster = {}, -- [slot] = {n = name, c = colorIdx}
	mySlot = nil,
	status = "menu", -- "menu" | "alive" | "dead" | "spectate"
	leaderboard = {}, -- array of {s, n, m}
	snaps = {}, -- ascending by t
	-- interpolated sample, rebuilt every frame (renderer reads these)
	view = { cells = {}, viruses = {}, pellets = {} },
	-- aggregates about MY cells, from the interpolated view (smooth camera)
	own = { x = Config.MapWidth / 2, y = Config.MapHeight / 2, mass = 0, maxR = 0, count = 0 },
	-- optional callbacks assigned by init.client
	onPlayerState = nil, -- fn("spawned" | "died")
	onLeaderboard = nil, -- fn(entries)
}

--------------------------------------------------------------------- remotes

Remotes.Snapshot.OnClientEvent:Connect(function(buf)
	local snap = Codec.unpackSnapshot(buf)
	local snaps = WorldState.snaps
	local newest = snaps[#snaps]
	if newest and snap.t <= newest.t then
		return -- stale / duplicate / reordered packet: drop it
	end
	snaps[#snaps + 1] = snap
	if #snaps > MAX_SNAPSHOTS then
		table.remove(snaps, 1)
	end
end)

Remotes.OrbSync.OnClientEvent:Connect(function(kind, buf)
	if kind == "full" then
		table.clear(WorldState.orbs)
		Codec.unpackOrbsFull(buf, WorldState.orbs)
	else
		Codec.applyOrbDelta(buf, WorldState.orbs)
	end
end)

Remotes.Roster.OnClientEvent:Connect(function(msg, a, b)
	if msg == "full" then
		table.clear(WorldState.roster)
		for slotStr, entry in a do
			WorldState.roster[tonumber(slotStr)] = entry
		end
		WorldState.mySlot = b
	elseif msg == "update" then
		WorldState.roster[a] = b
	elseif msg == "remove" then
		WorldState.roster[a] = nil
	end
end)

Remotes.Leaderboard.OnClientEvent:Connect(function(entries)
	WorldState.leaderboard = entries
	if WorldState.onLeaderboard then
		WorldState.onLeaderboard(entries)
	end
end)

Remotes.PlayerState.OnClientEvent:Connect(function(event)
	if event == "spawned" then
		WorldState.status = "alive"
	elseif event == "died" then
		WorldState.status = "dead"
	end
	if WorldState.onPlayerState then
		WorldState.onPlayerState(event)
	end
end)

--------------------------------------------------------------------- sampling

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Fill `out` with entities interpolated between maps m1 (older) and m2 (newer).
-- Entities only in the newer snapshot snap in at their new position (they just
-- entered interest range); entities only in the older one are gone (eaten or
-- left range) and simply aren't rendered.
local function sampleMap(m1, m2, alpha: number, out)
	table.clear(out)
	for id, e2 in m2 do
		local e1 = m1 and m1[id]
		if e1 then
			out[id] = {
				x = lerp(e1.x, e2.x, alpha),
				y = lerp(e1.y, e2.y, alpha),
				r = lerp(e1.r, e2.r, alpha),
				slot = e2.slot,
				kind = e2.kind,
			}
		else
			out[id] = e2
		end
	end
end

-- Called once per render frame, before the camera and renderer read anything.
function WorldState.sample()
	local snaps = WorldState.snaps
	local n = #snaps
	if n == 0 then
		return
	end

	local renderTime = snaps[n].t - Config.InterpolationDelay
	-- find the pair bracketing renderTime, scanning from the newest end
	local older, newer = nil, snaps[n]
	for i = n - 1, 1, -1 do
		if snaps[i].t <= renderTime then
			older = snaps[i]
			newer = snaps[i + 1]
			break
		end
		newer = snaps[i]
	end

	local view = WorldState.view
	if not older then
		-- not enough history yet (just joined / long stall): show newest as-is
		sampleMap(nil, newer.cells, 0, view.cells)
		sampleMap(nil, newer.viruses, 0, view.viruses)
		sampleMap(nil, newer.pellets, 0, view.pellets)
	else
		local span = newer.t - older.t
		local alpha = span > 1e-4 and math.clamp((renderTime - older.t) / span, 0, 1) or 1
		sampleMap(older.cells, newer.cells, alpha, view.cells)
		sampleMap(older.viruses, newer.viruses, alpha, view.viruses)
		sampleMap(older.pellets, newer.pellets, alpha, view.pellets)
	end

	-- aggregate my own cells from the interpolated view so camera + HUD are smooth
	local own = WorldState.own
	local mySlot = WorldState.mySlot
	local totalMass, cx, cy, maxR, count = 0, 0, 0, 0, 0
	for _, cell in view.cells do
		if cell.slot == mySlot then
			local m = Util.massFromRadius(cell.r)
			totalMass += m
			cx += cell.x * m
			cy += cell.y * m
			maxR = math.max(maxR, cell.r)
			count += 1
		end
	end
	own.count = count
	own.mass = totalMass
	own.maxR = maxR
	if count > 0 and totalMass > 0 then
		own.x = cx / totalMass
		own.y = cy / totalMass
	end
end

-- Centroid of some other player's cells in the current view (spectate camera).
-- Returns nil when that player isn't in our interest range.
function WorldState.slotCentroid(slot: number): (number?, number?)
	local totalM, cx, cy = 0, 0, 0
	for _, cell in WorldState.view.cells do
		if cell.slot == slot then
			local m = Util.massFromRadius(cell.r)
			totalM += m
			cx += cell.x * m
			cy += cell.y * m
		end
	end
	if totalM > 0 then
		return cx / totalM, cy / totalM
	end
	return nil, nil
end

function WorldState.colorForSlot(slot: number): Color3
	local entry = WorldState.roster[slot]
	local idx = entry and entry.c or 1
	return Config.Palette[idx] or Config.Palette[1]
end

function WorldState.nameForSlot(slot: number): string
	local entry = WorldState.roster[slot]
	return entry and entry.n or "?"
end

return WorldState
