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
			-- the split piece always LAUNCHES out toward the aim. When frozen
			-- the parent stays put (frozen) while the piece flies off and then
			-- settles/re-freezes - the classic freeze-split.
			local piece = World.spawnCell(cell.player, cell.x + dx * cell.r * 0.4, cell.y + dy * cell.r * 0.4, half)
			piece.ix = dx * Config.SplitImpulse
			piece.iy = dy * Config.SplitImpulse
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
			-- suicide-respawn: drop everything and start fresh
			if info.alive then
				for _, cell in table.clone(info.cells) do
					World.removeCell(cell)
				end
				spawnPlayer(info)
			end
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
		elseif action == "pulltogether" then
			-- ability: force all cells mergeable + strong glide for a moment,
			-- yanking them into one (see resolveOwnCells)
			if info.alive then
				info.pullUntil = now + Config.PullDuration
			end
		elseif action == "speedboost" then
			-- ability: temporary movement speed multiplier (see moveCells)
			if info.alive then
				info.speedUntil = now + Config.SpeedBoostDuration
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
					World.setMass(biggest, math.max(biggest.m * factor, 10))
				end
			end
		end
	end
	table.clear(Simulation.queue)
end

--------------------------------------------------------------------- movement

local function moveCells(dt: number)
	for _, cell in World.cells do
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
				-- freeze now only SLOWS you (you can still kinda move), and the
				-- Speed ability temporarily boosts you
				if info.frozen then
					speed *= Config.FreezeMoveFactor
				end
				if info.speedUntil and World.now < info.speedUntil then
					speed *= Config.SpeedBoostMult
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

-- Move a cell toward (tx, ty) by at most maxStep units this tick (never overshoot).
local function moveToward(cell, tx: number, ty: number, maxStep: number)
	local dx, dy = tx - cell.x, ty - cell.y
	local d = math.sqrt(dx * dx + dy * dy)
	if d > 1e-4 then
		local step = math.min(maxStep, d)
		cell.x = math.clamp(cell.x + dx / d * step, 0, Config.MapWidth)
		cell.y = math.clamp(cell.y + dy / d * step, 0, Config.MapHeight)
	end
end

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
		-- The "Pull Together" ability: while active, ALL cells are forced
		-- mergeable and actively yanked together (regroup on demand). Normal
		-- merging has NO artificial pull - see below.
		local pulling = info.pullUntil and now < info.pullUntil

		local merged = nil -- collect merges, apply after the pair loop
		for i = 1, n - 1 do
			local a = cells[i]
			for j = i + 1, n do
				local b = cells[j]
				if a.dead or b.dead then
					continue
				end
				local dx, dy = b.x - a.x, b.y - a.y
				local d = math.sqrt(dx * dx + dy * dy)
				local sum = a.r + b.r
				-- BOTH cells must have finished their merge timer (or the Pull
				-- ability is active).
				local mergeable = pulling or (now >= a.mergeAt and now >= b.mergeAt)
				if mergeable then
					local big = a.m >= b.m and a or b
					local small = big == a and b or a
					-- merge once the SMALLER cell is basically on top of the
					-- bigger's center (MergeOverlap is small, so no snap-from-afar
					-- at big sizes)
					if d < big.r * Config.MergeOverlap then
						merged = merged or {}
						table.insert(merged, { big = big, small = small }) -- big keeps its spot
					elseif d > 1e-3 and (pulling or not info.frozen) then
						-- glide ONLY the smaller cell into the bigger one, at the
						-- smaller cell's own normal move speed (the Pull ability
						-- speeds it up). The BIGGER cell is NOT pulled - it stays
						-- put (only your steering moves it), so the small slides in.
						local mult = pulling and Config.PullEaseMult or 1
						moveToward(small, big.x, big.y, Util.speedFromMass(small.m) * mult * dt)
					end
				elseif d >= sum then
					-- not overlapping and not mergeable: nothing to resolve
					continue
				elseif not info.frozen then
					-- soft positional correction: fraction of the overlap per
					-- tick, so fresh split impulses can still carry pieces
					-- out. Skipped entirely while frozen so stacked
					-- freeze-splits STAY stacked.
					local ux, uy = Util.unit(dx, dy)
					if d < 1e-3 then
						ux, uy = math.random() - 0.5, math.random() - 0.5
						ux, uy = Util.unit(ux, uy)
					end
					local push = (sum - d) * 0.5 * Config.SeparationSoftness
					a.x = math.clamp(a.x - ux * push, 0, Config.MapWidth)
					a.y = math.clamp(a.y - uy * push, 0, Config.MapHeight)
					b.x = math.clamp(b.x + ux * push, 0, Config.MapWidth)
					b.y = math.clamp(b.y + uy * push, 0, Config.MapHeight)
				end
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
	local chunk = cell.m / (pieces + 1)
	World.setMass(cell, chunk)
	cell.mergeAt = now + Util.mergeDelay(chunk)
	for _ = 1, pieces do
		local angle = math.random() * math.pi * 2
		local dx, dy = math.cos(angle), math.sin(angle)
		local piece = World.spawnCell(cell.player, cell.x + dx * cell.r * 0.4, cell.y + dy * cell.r * 0.4, chunk)
		local kick = Config.SplitImpulse * (0.6 + math.random() * 0.4)
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
				grew = true
				World.removeCell(e)
			elseif e.kind == "pellet" then
				cell.m += e.m
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
