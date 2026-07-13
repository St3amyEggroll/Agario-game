--[[
	World - authoritative game state. Pure data: no Instances, no physics.

	Entity shapes (plain tables):
	  cell   = {id, kind="cell",  player, slot, x, y, m, r, ix, iy, mergeAt, dead}
	           ix/iy = decaying impulse velocity from splits / virus pops
	  orb    = {id, x, y, m, r, color, respawns}
	  virus  = {id, kind="virus"|"exp", kindId=1|2, x, y, m, r, feeds, vx, vy, dead}
	  pellet = {id, kind="pellet", slot, x, y, m, r, vx, vy, born, dead}

	Ids are u16 wrap-around counters (orbs and dynamic entities use separate
	counters + separate client maps, so cross-type collisions are impossible;
	65k live-at-once per space is far above anything we spawn).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local SpatialHash = require(Shared.SpatialHash)
local Remotes = require(Shared.Remotes)

local World = {
	now = 0, -- server-relative time, set every tick by Simulation
	players = {}, -- [Player] = info (see addPlayer)
	slotToInfo = {}, -- [slot] = info
	orbs = {}, -- [id] = orb
	extraOrbCount = 0,
	viruses = {}, -- array
	pellets = {}, -- array (insertion-ish order; used to recycle oldest at cap)
	cells = {}, -- array of ALL live cells across players
	orbHash = SpatialHash.new(Config.SpatialCellSize),
	dynHash = SpatialHash.new(Config.SpatialCellSize),
	-- orb changes accumulated between snapshot sends, flushed as delta events
	pendingOrbRemovals = {},
	pendingOrbSpawns = {},
}

-- SEPARATE id counters per entity type. Client stores cells/viruses/pellets in
-- separate id-keyed maps, so their id spaces are independent - and keeping them
-- separate matters: pellets churn fast (feeding), and a shared counter would
-- wrap the 16-bit id space quickly, letting a fresh cell reuse a live cell's
-- id. That reuse makes the interpolator lerp between two DIFFERENT cells - the
-- "phantom cell streaks onto me then vanishes" bug. Per-type counters make cell
-- id reuse require 65536 *cell* spawns, which effectively never happens.
local nextCellIdCounter = 0
local nextVirusIdCounter = 0
local nextPelletIdCounter = 0
local nextOrbIdCounter = 0

local function nextCellId(): number
	nextCellIdCounter = (nextCellIdCounter + 1) % 65536
	return nextCellIdCounter
end

local function nextVirusId(): number
	nextVirusIdCounter = (nextVirusIdCounter + 1) % 65536
	return nextVirusIdCounter
end

local function nextPelletId(): number
	nextPelletIdCounter = (nextPelletIdCounter + 1) % 65536
	return nextPelletIdCounter
end

local function nextOrbId(): number
	nextOrbIdCounter = (nextOrbIdCounter + 1) % 65536
	return nextOrbIdCounter
end

function World.randomPos(margin: number): (number, number)
	return margin + math.random() * (Config.MapWidth - 2 * margin),
		margin + math.random() * (Config.MapHeight - 2 * margin)
end

-- Recompute cached radius after any mass change.
function World.setMass(entity, mass: number)
	entity.m = mass
	entity.r = Util.radiusFromMass(mass)
end

--------------------------------------------------------------------- orbs

function World.spawnOrb(x: number?, y: number?, respawns: boolean)
	if not x then
		x, y = World.randomPos(20)
	end
	local orb = {
		id = nextOrbId(),
		x = x,
		y = y :: any,
		m = Config.OrbMass,
		r = Util.radiusFromMass(Config.OrbMass),
		color = math.random(#Config.Palette),
		respawns = respawns,
	}
	World.orbs[orb.id] = orb
	World.orbHash:insert(orb)
	table.insert(World.pendingOrbSpawns, orb)
	return orb
end

-- Coins are just orbs with isCoin + a sentinel color + bigger radius, so they
-- reuse the entire orb sync path (no codec/network changes).
function World.spawnCoin(x: number?, y: number?)
	if not x then
		x, y = World.randomPos(80)
	end
	local coin = {
		id = nextOrbId(),
		x = x,
		y = y :: any,
		m = Config.CoinMass,
		r = Util.radiusFromMass(Config.CoinMass),
		color = Config.CoinColorIndex,
		respawns = true,
		isCoin = true,
	}
	World.orbs[coin.id] = coin
	World.orbHash:insert(coin)
	table.insert(World.pendingOrbSpawns, coin)
	return coin
end

function World.removeOrb(orb)
	World.orbs[orb.id] = nil
	World.orbHash:remove(orb)
	-- if this orb spawned within the same snapshot interval, cancel its queued
	-- spawn delta too - otherwise clients would apply remove-then-spawn (deltas
	-- always encode removals first) and be left with a ghost orb forever
	Util.arrayRemove(World.pendingOrbSpawns, orb)
	table.insert(World.pendingOrbRemovals, orb.id)
	if orb.isCoin then
		World.spawnCoin() -- keep the rare coin population stable
	elseif orb.respawns then
		-- keep the baseline population stable: eaten orbs pop up elsewhere
		World.spawnOrb(nil, nil, true)
	else
		World.extraOrbCount -= 1
	end
end

--------------------------------------------------------------------- cells

function World.spawnCell(player, x: number, y: number, mass: number)
	local info = World.players[player]
	local cell = {
		id = nextCellId(),
		kind = "cell",
		player = player,
		slot = info.slot,
		x = x,
		y = y,
		m = 0,
		r = 0,
		ix = 0,
		iy = 0,
		mergeAt = World.now + Util.mergeDelay(mass),
		born = World.now, -- cells created THIS tick don't move yet, so a split piece first
		-- appears AT the parent and launches next tick (no pop-in offset)
		dead = false,
	}
	World.setMass(cell, mass)
	table.insert(World.cells, cell)
	table.insert(info.cells, cell)
	return cell
end

function World.removeCell(cell)
	cell.dead = true
	Util.arrayRemove(World.cells, cell)
	local info = World.players[cell.player]
	if info then
		Util.arrayRemove(info.cells, cell)
	end
end

--------------------------------------------------------------------- viruses

function World.spawnVirus(kind: string, x: number?, y: number?)
	if not x then
		x, y = World.randomPos(120)
	end
	local virus = {
		id = nextVirusId(),
		kind = kind, -- "virus" | "exp"
		kindId = kind == "exp" and 2 or 1,
		x = x,
		y = y :: any,
		m = 0,
		r = 0,
		feeds = 0,
		vx = 0,
		vy = 0,
		dead = false,
	}
	World.setMass(virus, Config.VirusMass)
	table.insert(World.viruses, virus)
	return virus
end

-- Consumed viruses respawn elsewhere (same kind) to keep the map populated.
function World.removeVirus(virus, respawn: boolean)
	virus.dead = true
	Util.arrayRemove(World.viruses, virus)
	if respawn then
		World.spawnVirus(virus.kind)
	end
end

--------------------------------------------------------------------- pellets

function World.spawnPellet(slot: number, x: number, y: number, vx: number, vy: number)
	-- Hard cap: recycle the entry at index 1 (approximately the oldest; exact
	-- age ordering isn't worth maintaining for a visual-only cap).
	if #World.pellets >= Config.MaxPellets then
		local old = table.remove(World.pellets, 1)
		if old then
			old.dead = true
		end
	end
	local pellet = {
		id = nextPelletId(),
		kind = "pellet",
		slot = slot,
		x = math.clamp(x, 0, Config.MapWidth),
		y = math.clamp(y, 0, Config.MapHeight),
		m = Config.EjectPelletMass,
		r = Util.radiusFromMass(Config.EjectPelletMass),
		vx = vx,
		vy = vy,
		born = World.now,
		dead = false,
	}
	table.insert(World.pellets, pellet)
	return pellet
end

function World.removePellet(pellet)
	pellet.dead = true
	Util.arrayRemove(World.pellets, pellet)
end

--------------------------------------------------------------------- players

local function findFreeSlot(): number
	for slot = 1, 255 do
		if not World.slotToInfo[slot] then
			return slot
		end
	end
	return 255
end

function World.addPlayer(player)
	local info = {
		player = player,
		slot = findFreeSlot(),
		name = player.DisplayName,
		colorIdx = math.random(#Config.Palette),
		skinId = 0, -- 0 = no skin (plain colored circle); else an image/decal asset id
		coins = 0, -- currency collected from gold coins
		pullUntil = 0, -- Pull Together ability active until this server time
		speedUntil = 0, -- Speed ability active until this server time
		cells = {},
		aimX = Config.MapWidth / 2,
		aimY = Config.MapHeight / 2,
		frozen = false,
		alive = false,
		spectating = false,
		lastAction = {}, -- [actionName] = os.clock() of last accepted use
	}
	World.players[player] = info
	World.slotToInfo[info.slot] = info
	return info
end

function World.removePlayer(player)
	local info = World.players[player]
	if not info then
		return
	end
	-- copy: removeCell mutates info.cells
	for _, cell in table.clone(info.cells) do
		World.removeCell(cell)
	end
	World.slotToInfo[info.slot] = nil
	World.players[player] = nil
end

function World.totalMass(info): number
	local total = 0
	for _, cell in info.cells do
		total += cell.m
	end
	return total
end

-- Spawn point that avoids parking a new player inside something that can
-- instantly eat them. Brute scan is fine: cell counts are small.
function World.safeSpawnPos(): (number, number)
	local threshold = Config.StartMass * Config.EatMassRatio
	for _ = 1, 12 do
		local x, y = World.randomPos(150)
		local safe = true
		for _, cell in World.cells do
			if cell.m >= threshold and Util.dist2(x, y, cell.x, cell.y) < 400 * 400 then
				safe = false
				break
			end
		end
		if safe then
			return x, y
		end
	end
	return World.randomPos(150)
end

function World.broadcastRosterUpdate(info)
	Remotes.Roster:FireAllClients("update", info.slot, { n = info.name, c = info.colorIdx, k = info.skinId })
end

function World.init()
	for _ = 1, Config.OrbCount do
		World.spawnOrb(nil, nil, true)
	end
	for _ = 1, Config.CoinCount do
		World.spawnCoin()
	end
	for _ = 1, Config.VirusCount do
		World.spawnVirus("virus")
	end
	for _ = 1, Config.ExperimentalCount do
		World.spawnVirus("exp")
	end
	-- the initial burst of spawnOrb calls queued deltas nobody needs; clients
	-- joining later get a full sync anyway
	table.clear(World.pendingOrbSpawns)
	table.clear(World.pendingOrbRemovals)
end

return World
