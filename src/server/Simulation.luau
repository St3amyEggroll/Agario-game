--[[
	Simulation - the authoritative fixed-tick game loop (movement, eating,
	splitting, merging, viruses). Runs at Config.TickRate, decoupled from both
	rendering and snapshot sending. Clients only ever *ask* for actions; every
	rule is enforced here, so a modified client can't eat what it shouldn't.

	Tick order matters:
	  1. drain queued player actions (split/feed/... applied at tick start so
	     the whole tick sees a consistent world)
	  2. integrate movement (cells toward aim, pellets/viruses under friction)
	  3. rebuild the dynamic spatial hash
	  4. same-player cell separation & merging
	  5. eat pass (big cells first) - orbs, pellets, enemy cells, virus pops
	  6. pellet -> virus feeding
	  7. death check
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)
local Levels = require(script.Parent.Levels)

local Simulation = {
	queue = {}, -- {player, action, arg} pushed by Network, drained each tick
}

function Simulation.enqueue(player, action: string, arg)
	table.insert(Simulation.queue, { player = player, action = action, arg = arg })
end

--------------------------------------------------------------------- actions

-- One split pass: every eligible cell halves and launches a new half toward
-- the aim point. MultiSplit/TripleSplit are just 2/3 passes back-to-back
-- (the common "double/triple split" macro), each pass respecting MaxCells.
local function splitPass(info, now: number)
	local sorted = table.clone(info.cells)
	table.sort(sorted, function(a, b)
		return a.m > b.m
	end)
	for _, cell in sorted do
		if #info.cells >= Config.MaxCells then
			break
		end
		if cell.m >= Config.SplitMinMass then
			local dx, dy = Util.unit(info.aimX - cell.x, info.aimY - cell.y)
			local half = cell.m / 2
			World.setMass(cell, half)
			cell.mergeAt = now + Util.mergeDelay(half)
			-- the split piece spawns basically AT the parent (small offset just
			-- to define the launch direction) and holds there for one tick, then
			-- launches out toward the aim via its impulse - so it emerges from
			-- the parent instead of popping in offset.
			local piece = World.spawnCell(cell.player, cell.x + dx * cell.r * 0.15, cell.y + dy * cell.r * 0.15, half)
			-- launch faster the bigger the cell, so big halves clear each other quickly
			local impulse = math.max(Config.SplitImpulse, cell.r * Config.SplitImpulsePerRadius)
			piece.ix = dx * impulse
			piece.iy = dy * impulse
		end
	end
end

local function feed(info, now: number)
	for _, cell in table.clone(info.cells) do
		if cell.m >= Config.EjectMinMass then
			local dx, dy = Util.unit(info.aimX - cell.x, info.aimY - cell.y)
			-- optionally free: when EjectCostsMass is off, the pellet is spawned
			-- without shrinking the firing cell
			if Config.EjectCostsMass then
				World.setMass(cell, cell.m - Config.EjectMassLoss)
			end
			-- small angular jitter so streams of pellets fan out slightly
			local jitter = (math.random() - 0.5) * 0.14
			local cosj, sinj = math.cos(jitter), math.sin(jitter)
			local jx, jy = dx * cosj - dy * sinj, dx * sinj + dy * cosj
			local pr = Util.radiusFromMass(Config.EjectPelletMass)
			World.spawnPellet(
				info.slot,
				cell.x + jx * (cell.r + pr + 2),
				cell.y + jy * (cell.r + pr + 2),
				jx * Config.PelletSpeed,
				jy * Config.PelletSpeed
			)
		end
	end
	local _ = now
end

local function spawnPlayer(info)
	local x, y = World.safeSpawnPos()
	World.spawnCell(info.player, x, y, Config.StartMass)
	info.alive = true
	info.spectating = false
	info.frozen = false
	Remotes.PlayerState:FireClient(info.player, "spawned")
end

local function drainActions(now: number)
	for _, cmd in Simulation.queue do
		local info = World.players[cmd.player]
		if not info then
			continue
		end
		local action = cmd.action
		if action == "play" then
			if not info.alive then
				spawnPlayer(info)
			end
		elseif action == "spectate" then
			if not info.alive then
				info.spectating = true
			end
		elseif action == "respawn" then
			-- INSTANT respawn: drop everything and start fresh from any state
			-- (alive or dead), no trip through the menu
			for _, cell in table.clone(info.cells) do
				World.removeCell(cell)
			end
			spawnPlayer(info)
		elseif action == "tomenu" then
			-- leave the game and go back to the menu (play screen)
			for _, cell in table.clone(info.cells) do
				World.removeCell(cell)
			end
			info.alive = false
			info.spectating = false
			Remotes.PlayerState:FireClient(info.player, "menu")
		elseif action == "split" then
			if info.alive then
				splitPass(info, now)
			end
		elseif action == "multisplit" then
			if info.alive then
				splitPass(info, now)
				splitPass(info, now)
			end
		elseif action == "triplesplit" then
			if info.alive then
				splitPass(info, now)
				splitPass(info, now)
				splitPass(info, now)
			end
		elseif action == "feed" then
			if info.alive then
				feed(info, now)
			end
		elseif action == "freeze" then
			-- Freeze is a toggle (spec allows toggle or hold; toggle chosen so
			-- it works the same on any input device)
			if info.alive then
				info.frozen = not info.frozen
			end
		elseif action == "setskin" then
			info.skinId = cmd.arg -- image/decal asset id (0 = none), validated in Network
			World.broadcastRosterUpdate(info)
		elseif action == "debugmass" then
			-- testing helper (gated by Config.Debug in Network): +/- a percentage
			-- of the largest cell's current mass (arg is +1 or -1)
			if Config.Debug and info.alive then
				local biggest
				for _, cell in info.cells do
					if not biggest or cell.m > biggest.m then
						biggest = cell
					end
				end
				if biggest then
					local factor = 1 + cmd.arg * Config.DebugMassPercent / 100
					World.setMass(biggest, math.max(biggest.m * factor, Config.MinCellMass))
				end
			end
		end
	end
	table.clear(Simulation.queue)
end

--------------------------------------------------------------------- movement

local function moveCells(dt: number)
	for _, cell in World.cells do
		-- a cell born THIS tick (a fresh split piece) holds at its spawn point
		-- for one tick, so it first appears AT the parent and launches next
		-- tick - no pop-in offset / teleport on the client
		if cell.born == World.now then
			continue
		end
		local info = World.players[cell.player]
		local vx, vy = 0, 0
		if info then
			local dx = info.aimX - cell.x
			local dy = info.aimY - cell.y
			local d = math.sqrt(dx * dx + dy * dy)
			if d > 1 then
				-- speed falls off with mass; also scales down as the cursor
				-- gets inside the cell so you can hover to stop (agar feel)
				local speed = Util.speedFromMass(cell.m) * math.clamp(d / cell.r, 0, 1)
				-- freeze only SLOWS you (you can still kinda move)
				if info.frozen then
					speed *= Config.FreezeMoveFactor
				end
				vx = dx / d * speed
				vy = dy / d * speed
			end
		end
		cell.x = math.clamp(cell.x + (vx + cell.ix) * dt, 0, Config.MapWidth)
		cell.y = math.clamp(cell.y + (vy + cell.iy) * dt, 0, Config.MapHeight)
		-- split/pop impulses decay exponentially
		local damp = math.exp(-Config.ImpulseDamping * dt)
		cell.ix *= damp
		cell.iy *= damp
		-- big cells slowly bleed mass
		if cell.m > Config.MassDecayMin then
			World.setMass(cell, cell.m - cell.m * Config.MassDecayRate * dt)
		end
	end
end

local pelletExpireScratch = {}

local function movePellets(dt: number)
	local damp = math.exp(-Config.PelletFriction * dt)
	local now = World.now
	local lifetime = Config.PelletLifetime
	table.clear(pelletExpireScratch)
	for _, p in World.pellets do
		if now - p.born > lifetime then
			-- server deletes old pellets so they can't pile up and lag things
			pelletExpireScratch[#pelletExpireScratch + 1] = p
		elseif p.vx * p.vx + p.vy * p.vy > 4 then
			p.x = math.clamp(p.x + p.vx * dt, 0, Config.MapWidth)
			p.y = math.clamp(p.y + p.vy * dt, 0, Config.MapHeight)
			p.vx *= damp
			p.vy *= damp
		else
			p.vx, p.vy = 0, 0
		end
	end
	-- remove after iterating (removePellet mutates the array)
	for _, p in pelletExpireScratch do
		World.removePellet(p)
	end
end

local function moveViruses(dt: number)
	local damp = math.exp(-Config.VirusFriction * dt)
	for _, v in World.viruses do
		if v.vx * v.vx + v.vy * v.vy > 4 then
			v.x = math.clamp(v.x + v.vx * dt, 0, Config.MapWidth)
			v.y = math.clamp(v.y + v.vy * dt, 0, Config.MapHeight)
			v.vx *= damp
			v.vy *= damp
		else
			v.vx, v.vy = 0, 0
		end
	end
end

local function rebuildDynHash()
	local hash = World.dynHash
	hash:clear()
	for _, cell in World.cells do
		hash:insert(cell)
	end
	for _, v in World.viruses do
		hash:insert(v)
	end
	for _, p in World.pellets do
		hash:insert(p)
	end
end

--------------------------------------------------- same-player collide/merge

-- Split halves stay separate until a merge timer expires, then glide toward a
-- shared meeting point (their midpoint, leaned toward the mouse) and combine
-- THERE - they merge into each other rather than one absorbing the other in
-- place. While un-mergeable, overlapping cells are softly pushed apart.
local function resolveOwnCells(now: number, dt: number)
	for _, info in World.players do
		local cells = info.cells
		local n = #cells
		if n < 2 then
			continue
		end

		-- reset per-cell separation accumulators (see below)
		for _, c in cells do
			c._sx = 0
			c._sy = 0
		end

		local merged = nil -- collect merges, apply after the pair loop
		for i = 1, n - 1 do
			local a = cells[i]
			for j = i + 1, n do
				local b = cells[j]
				if a.dead or b.dead then
					continue
				end
				-- freshly-split pieces hold at the parent for one tick (see
				-- moveCells): don't separate/merge them yet
				if a.born == now or b.born == now then
					continue
				end
				local dx, dy = b.x - a.x, b.y - a.y
				local d = math.sqrt(dx * dx + dy * dy)
				local sum = a.r + b.r
				-- BOTH cells must have finished their merge timer to combine; you
				-- always steer them together yourself (no auto-pull).
				local mergeable = now >= a.mergeAt and now >= b.mergeAt
				if mergeable then
					local big = a.m >= b.m and a or b
					local small = big == a and b or a
					-- merge once the SMALLER cell has entered halfway into the
					-- bigger one. NO auto-movement anywhere - the player must move
					-- the cells together to merge them.
					if d < big.r * Config.MergeOverlap then
						merged = merged or {}
						table.insert(merged, { big = big, small = small }) -- big keeps its spot
					end
				elseif d >= sum * (1 - Config.SeparationSlop) then
					-- not overlapping (beyond the small slop dead-zone) and not
					-- mergeable: nothing to resolve. The dead-zone lets packed
					-- cells settle instead of jittering.
					continue
				elseif not info.frozen then
					-- SOLID collision: ACCUMULATE each cell's desired push here;
					-- it's applied (capped per CELL) after the pair loop. Capping
					-- per pair was the bug - a cell stacked with many others (a
					-- multi-split) got shoved by every pair at once = a huge
					-- one-tick jump/teleport.
					local ux, uy = Util.unit(dx, dy)
					if d < 1e-3 then
						ux, uy = math.random() - 0.5, math.random() - 0.5
						ux, uy = Util.unit(ux, uy)
					end
					local overlap = (sum - d) * Config.SeparationSoftness
					local wa = b.m / (a.m + b.m) -- lighter cell (a) -> larger share of the push
					a._sx -= ux * overlap * wa
					a._sy -= uy * overlap * wa
					b._sx += ux * overlap * (1 - wa)
					b._sy += uy * overlap * (1 - wa)
				end
			end
		end

		-- apply each cell's TOTAL accumulated push this tick, capped to a max
		-- speed so it's always a smooth slide, never a teleport. The capped push
		-- is then LOW-PASS smoothed against the previous tick's applied push
		-- (c._px/_py persist between ticks): a cell wedged in a dense pack gets a
		-- net push whose direction flips frame-to-frame, and averaging that toward
		-- zero stops the middle-of-the-pack jitter; a cell being genuinely squeezed
		-- out has a consistent push direction, so the blend still slides it free.
		local maxStep = Config.SeparationMaxSpeed * dt
		local smooth = Config.SeparationSmoothing
		for _, c in cells do
			local sx, sy = c._sx, c._sy
			local mag = math.sqrt(sx * sx + sy * sy)
			local tx, ty = 0, 0
			if mag > 1e-4 then
				local step = math.min(mag, maxStep)
				tx, ty = sx / mag * step, sy / mag * step
			end
			-- blend toward this tick's target push (target is 0 when not overlapping,
			-- so a settled cell's smoothed push decays to nothing)
			local px = (c._px or 0) + (tx - (c._px or 0)) * smooth
			local py = (c._py or 0) + (ty - (c._py or 0)) * smooth
			c._px, c._py = px, py
			if px * px + py * py > 1e-6 then
				c.x = math.clamp(c.x + px, 0, Config.MapWidth)
				c.y = math.clamp(c.y + py, 0, Config.MapHeight)
			end
		end

		if merged then
			for _, pair in merged do
				if not pair.big.dead and not pair.small.dead then
					-- the bigger cell absorbs the smaller IN PLACE (it never moved
					-- for the merge), so there's no snap/jump
					World.setMass(pair.big, pair.big.m + pair.small.m)
					World.removeCell(pair.small)
				end
			end
		end
	end
end

--------------------------------------------------------------------- eating

local scratchHits = {} -- reused: never mutate the hash while iterating it

-- A big cell overlapping a virus pops: it absorbs the virus mass but shatters
-- into pieces (unless already at MaxCells, in which case it eats it safely -
-- the classic "16 pieces makes viruses food" rule).
local function popCell(cell, virus, now: number)
	World.setMass(cell, cell.m + virus.m)
	World.removeVirus(virus, true)
	local info = World.players[cell.player]
	local avail = Config.MaxCells - #info.cells
	if avail <= 0 then
		return
	end
	local pieces = math.min(Config.VirusPopPieces, avail)
	-- keep every resulting piece >= MinCellMass: reduce the piece count if the
	-- cell isn't big enough to shatter that many and stay above the floor
	pieces = math.min(pieces, math.max(0, math.floor(cell.m / Config.MinCellMass) - 1))
	if pieces <= 0 then
		return -- not enough mass to split without going under the floor; just absorb
	end
	local chunk = cell.m / (pieces + 1)
	World.setMass(cell, chunk)
	cell.mergeAt = now + Util.mergeDelay(chunk)
	for _ = 1, pieces do
		local angle = math.random() * math.pi * 2
		local dx, dy = math.cos(angle), math.sin(angle)
		local piece = World.spawnCell(cell.player, cell.x + dx * cell.r * 0.15, cell.y + dy * cell.r * 0.15, chunk)
		-- scale the pop kick by cell radius too, so big cells scatter their pieces
		-- fast enough to clear their (larger) radius instead of sitting in a blob
		local kick = math.max(Config.SplitImpulse, cell.r * Config.SplitImpulsePerRadius) * (0.6 + math.random() * 0.4)
		piece.ix = dx * kick
		piece.iy = dy * kick
	end
end

local function eatPass(now: number)
	-- biggest first so simultaneous overlaps resolve deterministically in
	-- favor of the larger cell
	local sorted = table.clone(World.cells)
	table.sort(sorted, function(a, b)
		return a.m > b.m
	end)

	for _, cell in sorted do
		if cell.dead then
			continue
		end
		local r = cell.r
		local minX, minY = cell.x - r, cell.y - r
		local maxX, maxY = cell.x + r, cell.y + r
		local grew = false
		local xpGain = 0 -- real food mass eaten this pass (orbs + enemy cells + enemy pellets)

		-- orbs (persistent hash; collect then remove so we never mutate a
		-- bucket mid-iteration)
		table.clear(scratchHits)
		World.orbHash:forEachInAABB(minX, minY, maxX, maxY, function(orb)
			local reach = r - orb.r * Config.EatDepth
			if reach > 0 and Util.dist2(cell.x, cell.y, orb.x, orb.y) < reach * reach then
				table.insert(scratchHits, orb)
			end
		end)
		for _, orb in scratchHits do
			if orb.isCoin then
				local owner = World.players[cell.player]
				if owner then
					owner.coins += 1
					Remotes.PlayerState:FireClient(cell.player, "coins", owner.coins)
				end
				if Config.CoinBonusMass > 0 then
					cell.m += Config.CoinBonusMass
					grew = true
				end
			else
				cell.m += orb.m
				xpGain += orb.m
				grew = true
			end
			World.removeOrb(orb)
		end

		-- dynamic entities: enemy cells, pellets, viruses
		table.clear(scratchHits)
		World.dynHash:forEachInAABB(minX, minY, maxX, maxY, function(e)
			if e.dead or e == cell then
				return
			end
			local reach = r - e.r * Config.EatDepth
			if reach <= 0 or Util.dist2(cell.x, cell.y, e.x, e.y) >= reach * reach then
				return
			end
			if e.kind == "cell" then
				if e.player ~= cell.player and cell.m >= e.m * Config.EatMassRatio then
					table.insert(scratchHits, e)
				end
			elseif e.kind == "pellet" then
				-- own pellets only become edible after a short delay so a
				-- feed stream doesn't get re-swallowed instantly
				if e.slot ~= cell.slot or now - e.born > Config.PelletSelfEatDelay then
					table.insert(scratchHits, e)
				end
			else -- virus / exp
				if cell.m > e.m * Config.VirusEatRatio then
					table.insert(scratchHits, e)
				end
			end
		end)
		for _, e in scratchHits do
			if e.dead then
				continue
			end
			if e.kind == "cell" then
				cell.m += e.m
				xpGain += e.m -- eating another player is the big XP source
				grew = true
				World.removeCell(e)
			elseif e.kind == "pellet" then
				-- your OWN pellets give less mass back (self-feed is inefficient)
				if e.slot == cell.slot then
					cell.m += e.m * Config.SelfFeedMassFactor
				else
					cell.m += e.m
					xpGain += e.m -- only ENEMY pellets earn XP (no farming your own)
				end
				grew = true
				World.removePellet(e)
			else
				World.setMass(cell, cell.m) -- flush any pending growth before popping
				popCell(cell, e, now)
				grew = false
				break -- cell just shattered; stop processing hits for it
			end
		end
		if grew then
			World.setMass(cell, cell.m)
		end
		if xpGain > 0 then
			Levels.award(World.players[cell.player], xpGain)
		end
	end
end

------------------------------------------------------------- virus feeding

local function feedViruses(now: number)
	for _, virus in table.clone(World.viruses) do
		if virus.dead then
			continue
		end
		local reach = virus.r + 20
		table.clear(scratchHits)
		World.dynHash:forEachInAABB(virus.x - reach, virus.y - reach, virus.x + reach, virus.y + reach, function(e)
			if e.kind == "pellet" and not e.dead then
				local hit = virus.r + e.r * 0.5
				if Util.dist2(virus.x, virus.y, e.x, e.y) < hit * hit then
					table.insert(scratchHits, e)
				end
			end
		end)
		for _, pellet in scratchHits do
			-- feed direction: pellet's travel direction, or radially if it
			-- was already at rest against the virus
			local dx, dy
			if pellet.vx * pellet.vx + pellet.vy * pellet.vy > 100 then
				dx, dy = Util.unit(pellet.vx, pellet.vy)
			else
				dx, dy = Util.unit(virus.x - pellet.x, virus.y - pellet.y)
			end
			World.setMass(virus, virus.m + pellet.m)
			virus.feeds += 1
			virus.vx = dx * Config.VirusPushSpeed
			virus.vy = dy * Config.VirusPushSpeed
			World.removePellet(pellet)

			-- Experimentals reward feeders with bonus orbs sprayed nearby
			if virus.kind == "exp" and World.extraOrbCount < Config.MaxExtraOrbs then
				for _ = 1, Config.ExperimentalOrbsPerFeed do
					local angle = math.random() * math.pi * 2
					local dist = virus.r + 20 + math.random() * 60
					World.spawnOrb(
						math.clamp(virus.x + math.cos(angle) * dist, 10, Config.MapWidth - 10),
						math.clamp(virus.y + math.sin(angle) * dist, 10, Config.MapHeight - 10),
						false
					)
					World.extraOrbCount += 1
				end
			end

			if virus.feeds >= Config.VirusFeedsToSplit then
				virus.feeds = 0
				World.setMass(virus, Config.VirusMass)
				if #World.viruses < Config.MaxViruses then
					-- shoot a child virus in the feed direction
					local child = World.spawnVirus(virus.kind, virus.x + dx * (virus.r * 2 + 10), virus.y + dy * (virus.r * 2 + 10))
					child.vx = dx * Config.VirusSplitImpulse
					child.vy = dy * Config.VirusSplitImpulse
				end
			end
		end
	end
	local _ = now
end

--------------------------------------------------------------------- deaths

local function deathCheck()
	for player, info in World.players do
		if info.alive and #info.cells == 0 then
			info.alive = false
			Remotes.PlayerState:FireClient(player, "died")
		end
	end
end

--------------------------------------------------------------------- step

function Simulation.step(dt: number, now: number)
	World.now = now
	drainActions(now)
	moveCells(dt)
	movePellets(dt)
	moveViruses(dt)
	rebuildDynHash()
	resolveOwnCells(now, dt)
	eatPass(now)
	feedViruses(now)
	deathCheck()
end

return Simulation
