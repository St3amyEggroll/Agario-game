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
	coins = 0, -- currency collected (from gold coins)
	xp = 0, -- lifetime XP (server-authoritative); HUD derives level + bar via Shared.Levels
	status = "menu", -- "menu" | "alive" | "dead" | "spectate"
	leaderboard = {}, -- array of {s, n, m}
	snaps = {}, -- ascending by t
	-- interpolated sample, rebuilt every frame (renderer reads these)
	view = { cells = {}, viruses = {}, pellets = {} },
	-- aggregates about MY cells, from the interpolated view (smooth camera)
	own = { x = Config.MapWidth / 2, y = Config.MapHeight / 2, mass = 0, maxR = 0, count = 0, peakMass = 0 },
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

Remotes.Level.OnClientEvent:Connect(function(xp)
	if typeof(xp) == "number" then
		WorldState.xp = xp
	end
end)

Remotes.Leaderboard.OnClientEvent:Connect(function(entries)
	WorldState.leaderboard = entries
	if WorldState.onLeaderboard then
		WorldState.onLeaderboard(entries)
	end
end)

Remotes.PlayerState.OnClientEvent:Connect(function(event, arg)
	if event == "spawned" then
		WorldState.status = "alive"
		WorldState.own.peakMass = 0 -- fresh life: reset the peak for the death summary
	elseif event == "died" then
		WorldState.status = "dead"
	elseif event == "menu" then
		WorldState.status = "menu"
	elseif event == "coins" then
		WorldState.coins = arg
		return -- coins is a lightweight update; no menu/status refresh needed
	end
	if WorldState.onPlayerState then
		WorldState.onPlayerState(event)
	end
end)

--------------------------------------------------------------------- sampling

-- Fill `out` with entities interpolated between maps m1 (older) and m2 (newer).
-- Entities only in the newer snapshot snap in at their new position (they just
-- entered interest range); entities only in the older one are gone (eaten or
-- left range) and simply aren't rendered.
-- PERF: `out` tables are reused across frames (update-in-place + remove stale
-- ids) instead of reallocated - this runs per entity per frame, and fresh
-- tables every frame would be constant GC churn.
local MAX_JUMP2 = Config.MaxInterpJump * Config.MaxInterpJump

local function sampleMap(m1, m2, alpha: number, out, allowNew: boolean)
	for id in out do
		if not m2[id] then
			out[id] = nil
		end
	end
	for id, e2 in m2 do
		local e1 = m1 and m1[id]
		if e1 then
			local t = out[id]
			if not t then
				t = {}
				out[id] = t
			end
			local dx, dy = e2.x - e1.x, e2.y - e1.y
			if dx * dx + dy * dy > MAX_JUMP2 then
				-- an implausibly large jump between two adjacent snapshots means
				-- this id is NOT the same physical entity (id reuse) or it
				-- teleported (respawn). Snap to the new value instead of
				-- lerping, so no phantom streaks across the map.
				t.x, t.y, t.r = e2.x, e2.y, e2.r
			else
				t.x = e1.x + dx * alpha
				t.y = e1.y + dy * alpha
				t.r = e1.r + (e2.r - e1.r) * alpha
			end
			t.slot = e2.slot
			t.kind = e2.kind
		elseif allowNew then
			-- no history yet (just joined / long stall): show newest as-is
			local t = out[id]
			if not t then
				t = {}
				out[id] = t
			end
			t.x, t.y, t.r = e2.x, e2.y, e2.r
			t.slot = e2.slot
			t.kind = e2.kind
		else
			-- This id is in the NEWER snapshot but not the OLDER one, so it spawned
			-- between them (full-world snapshots => "missing from older" can only
			-- mean "just spawned"). It doesn't exist yet at renderTime, which is
			-- ~InterpolationDelay behind newest. Do NOT snap it to its current
			-- position - that pops it in ahead of the delayed world, then it snaps
			-- back a frame later once it has a bracketing pair. That pop IS the
			-- split-piece / new-pellet glitch. Skip it; it appears smoothly once
			-- renderTime advances to its first snapshot.
			if out[id] then
				out[id] = nil
			end
		end
	end
end

local renderClock: number? = nil

-- Called once per render frame, before the camera and renderer read anything.
-- dt advances a LOCAL render clock: rendering must progress smoothly every
-- frame, NOT in 50 ms steps whenever a packet happens to arrive (deriving the
-- render time straight from the newest snapshot does exactly that and looks
-- like shuddering). The local clock is gently pulled toward
-- (newest snapshot time - InterpolationDelay) to absorb network jitter and
-- clock drift; only a big desync (join, long stall) hard-snaps it.
function WorldState.sample(dt: number)
	local snaps = WorldState.snaps
	local n = #snaps
	if n == 0 then
		return
	end

	local target = snaps[n].t - Config.InterpolationDelay
	local clock = renderClock or target
	clock += dt
	local err = target - clock
	if math.abs(err) > 0.3 then
		clock = target
	else
		clock += err * math.min(0.15, dt * 3)
	end
	renderClock = clock
	-- never sample past the newest data (extrapolating = overshoot artifacts)
	local renderTime = math.min(clock, snaps[n].t)

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
		sampleMap(nil, newer.cells, 0, view.cells, true)
		sampleMap(nil, newer.viruses, 0, view.viruses, true)
		sampleMap(nil, newer.pellets, 0, view.pellets, true)
	else
		local span = newer.t - older.t
		local alpha = span > 1e-4 and math.clamp((renderTime - older.t) / span, 0, 1) or 1
		sampleMap(older.cells, newer.cells, alpha, view.cells, false)
		sampleMap(older.viruses, newer.viruses, alpha, view.viruses, false)
		sampleMap(older.pellets, newer.pellets, alpha, view.pellets, false)
	end

	-- Camera follow: centroid from the INTERPOLATED view, so the camera tracks a
	-- smooth 60 fps target.
	local own = WorldState.own
	local mySlot = WorldState.mySlot
	local viewMass, cx, cy, maxR, count = 0, 0, 0, 0, 0
	for _, cell in view.cells do
		if cell.slot == mySlot then
			local m = Util.massFromRadius(cell.r)
			viewMass += m
			cx += cell.x * m
			cy += cell.y * m
			maxR = math.max(maxR, cell.r)
			count += 1
		end
	end
	own.count = count
	own.maxR = maxR
	if count > 0 and viewMass > 0 then
		own.x = cx / viewMass
		own.y = cy / viewMass
	end
	-- Zoom + HUD mass: sum from the NEWEST snapshot, not the delayed view. A
	-- freshly-split piece is held out of the view for ~InterpolationDelay (so it
	-- doesn't pop, see sampleMap); if the zoom read mass from the view it would
	-- see the total briefly halve and pulse the zoom on every split - exactly the
	-- split-zoom we don't want. The newest snapshot always has the full set.
	local newestMass = 0
	for _, cell in snaps[n].cells do
		if cell.slot == mySlot then
			newestMass += Util.massFromRadius(cell.r)
		end
	end
	own.mass = newestMass
	if WorldState.status == "alive" and newestMass > own.peakMass then
		own.peakMass = newestMass -- track the run's best mass for the death summary
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

-- Skin image asset id for a slot (0 / nil = no skin).
function WorldState.skinForSlot(slot: number): number
	local entry = WorldState.roster[slot]
	return (entry and entry.k) or 0
end

return WorldState
