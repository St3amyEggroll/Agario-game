--[[
	SnapshotCodec - packs world state into tight binary buffers and back.

	Why buffers: a naive table of {id=, x=, y=, ...} costs ~10x the bytes on the
	wire. UnreliableRemoteEvents drop anything over ~900 bytes, so every byte of
	a snapshot matters.

	Quantization:
	  - positions   -> u16 across the map (8000 units / 65535 ~= 0.12 units of
	                   resolution: invisible at any zoom level)
	  - cell radius -> u16, fixed point *8  (0.125 resolution, max 8191)
	  - small radii -> u8,  fixed point *4  (orbs/pellets, max 63.75)
	  - time        -> u32 milliseconds since server start (f32 would lose
	                   precision after a few hours of uptime and jitter the
	                   interpolation; u32 ms wraps after ~49 days)

	Wire formats (offsets in bytes):
	  Snapshot: [t_ms u32][nCells u8][nViruses u8][nPellets u8]
	            cells:   id u16 | slot u8 | x u16 | y u16 | r u16   (9 B)
	            viruses: id u16 | x u16 | y u16 | r u16 | kind u8   (9 B)
	            pellets: id u16 | slot u8 | x u16 | y u16 | r u8    (8 B)
	  OrbsFull: [count u16] then per orb: id u16 | x u16 | y u16 | color u8 | r u8 (8 B)
	  OrbDelta: [nRemoved u8][nSpawned u8] removed ids u16... then spawned orbs (8 B each)
]]

local Config = require(script.Parent.Config)

local Codec = {}

local QX = 65535 / Config.MapWidth
local QY = 65535 / Config.MapHeight

local function qx(x: number): number
	return math.clamp(math.floor(x * QX + 0.5), 0, 65535)
end

local function qy(y: number): number
	return math.clamp(math.floor(y * QY + 0.5), 0, 65535)
end

local function qr16(r: number): number
	return math.clamp(math.floor(r * 8 + 0.5), 0, 65535)
end

local function qr8(r: number): number
	return math.clamp(math.floor(r * 4 + 0.5), 0, 255)
end

Codec.CELL_BYTES = 9
Codec.VIRUS_BYTES = 9
Codec.PELLET_BYTES = 8
Codec.HEADER_BYTES = 10 -- t u32 + three u16 counts (u16 so a full-map send can exceed 255 of a type)

--------------------------------------------------------------------- snapshot

-- t is seconds since server start; cells/viruses/pellets are arrays of server
-- entities (cells need id/slot/x/y/r, viruses id/x/y/r/kindId, pellets id/slot/x/y/r).
function Codec.packSnapshot(t: number, cells, viruses, pellets): buffer
	local b = buffer.create(10 + #cells * 9 + #viruses * 9 + #pellets * 8)
	buffer.writeu32(b, 0, math.floor(t * 1000) % 4294967296)
	buffer.writeu16(b, 4, #cells)
	buffer.writeu16(b, 6, #viruses)
	buffer.writeu16(b, 8, #pellets)
	local o = 10
	for _, c in cells do
		buffer.writeu16(b, o, c.id)
		buffer.writeu8(b, o + 2, c.slot)
		buffer.writeu16(b, o + 3, qx(c.x))
		buffer.writeu16(b, o + 5, qy(c.y))
		buffer.writeu16(b, o + 7, qr16(c.r))
		o += 9
	end
	for _, v in viruses do
		buffer.writeu16(b, o, v.id)
		buffer.writeu16(b, o + 2, qx(v.x))
		buffer.writeu16(b, o + 4, qy(v.y))
		buffer.writeu16(b, o + 6, qr16(v.r))
		buffer.writeu8(b, o + 8, v.kindId)
		o += 9
	end
	for _, p in pellets do
		buffer.writeu16(b, o, p.id)
		buffer.writeu8(b, o + 2, p.slot)
		buffer.writeu16(b, o + 3, qx(p.x))
		buffer.writeu16(b, o + 5, qy(p.y))
		buffer.writeu8(b, o + 7, qr8(p.r))
		o += 8
	end
	return b
end

-- Returns { t, cells = {[id]={x,y,r,slot}}, viruses = {[id]={x,y,r,kind}},
-- pellets = {[id]={x,y,r,slot}} }. Id-keyed maps so the interpolator can pair
-- entities across two snapshots in O(1).
function Codec.unpackSnapshot(b: buffer)
	local t = buffer.readu32(b, 0) / 1000
	local nCells = buffer.readu16(b, 4)
	local nViruses = buffer.readu16(b, 6)
	local nPellets = buffer.readu16(b, 8)
	local o = 10
	local cells, viruses, pellets = {}, {}, {}
	for _ = 1, nCells do
		cells[buffer.readu16(b, o)] = {
			slot = buffer.readu8(b, o + 2),
			x = buffer.readu16(b, o + 3) / QX,
			y = buffer.readu16(b, o + 5) / QY,
			r = buffer.readu16(b, o + 7) / 8,
		}
		o += 9
	end
	for _ = 1, nViruses do
		viruses[buffer.readu16(b, o)] = {
			x = buffer.readu16(b, o + 2) / QX,
			y = buffer.readu16(b, o + 4) / QY,
			r = buffer.readu16(b, o + 6) / 8,
			kind = buffer.readu8(b, o + 8),
		}
		o += 9
	end
	for _ = 1, nPellets do
		pellets[buffer.readu16(b, o)] = {
			slot = buffer.readu8(b, o + 2),
			x = buffer.readu16(b, o + 3) / QX,
			y = buffer.readu16(b, o + 5) / QY,
			r = buffer.readu8(b, o + 7) / 4,
		}
		o += 8
	end
	return { t = t, cells = cells, viruses = viruses, pellets = pellets }
end

--------------------------------------------------------------------- orbs

-- orbs is an array of {id, x, y, color, r}
function Codec.packOrbsFull(orbs): buffer
	local b = buffer.create(2 + #orbs * 8)
	buffer.writeu16(b, 0, #orbs)
	local o = 2
	for _, orb in orbs do
		buffer.writeu16(b, o, orb.id)
		buffer.writeu16(b, o + 2, qx(orb.x))
		buffer.writeu16(b, o + 4, qy(orb.y))
		buffer.writeu8(b, o + 6, orb.color)
		buffer.writeu8(b, o + 7, qr8(orb.r))
		o += 8
	end
	return b
end

-- Writes decoded orbs into `out` ([id] = {x, y, color, r}) and returns it.
function Codec.unpackOrbsFull(b: buffer, out)
	local count = buffer.readu16(b, 0)
	local o = 2
	for _ = 1, count do
		out[buffer.readu16(b, o)] = {
			x = buffer.readu16(b, o + 2) / QX,
			y = buffer.readu16(b, o + 4) / QY,
			color = buffer.readu8(b, o + 6),
			r = buffer.readu8(b, o + 7) / 4,
		}
		o += 8
	end
	return out
end

-- removedIds: array of orb ids; spawned: array of orb entities. Max 255 each
-- per message (callers chunk).
function Codec.packOrbDelta(removedIds, spawned): buffer
	local b = buffer.create(2 + #removedIds * 2 + #spawned * 8)
	buffer.writeu8(b, 0, #removedIds)
	buffer.writeu8(b, 1, #spawned)
	local o = 2
	for _, id in removedIds do
		buffer.writeu16(b, o, id)
		o += 2
	end
	for _, orb in spawned do
		buffer.writeu16(b, o, orb.id)
		buffer.writeu16(b, o + 2, qx(orb.x))
		buffer.writeu16(b, o + 4, qy(orb.y))
		buffer.writeu8(b, o + 6, orb.color)
		buffer.writeu8(b, o + 7, qr8(orb.r))
		o += 8
	end
	return b
end

-- Applies a delta directly onto the client's orb map.
function Codec.applyOrbDelta(b: buffer, orbMap)
	local nRemoved = buffer.readu8(b, 0)
	local nSpawned = buffer.readu8(b, 1)
	local o = 2
	for _ = 1, nRemoved do
		orbMap[buffer.readu16(b, o)] = nil
		o += 2
	end
	for _ = 1, nSpawned do
		orbMap[buffer.readu16(b, o)] = {
			x = buffer.readu16(b, o + 2) / QX,
			y = buffer.readu16(b, o + 4) / QY,
			color = buffer.readu8(b, o + 6),
			r = buffer.readu8(b, o + 7) / 4,
		}
		o += 8
	end
end

return Codec
