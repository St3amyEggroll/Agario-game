--[[
	SpatialHash - uniform grid over the map for O(nearby) collision/interest queries.

	Entities are any tables with .x / .y fields. Each entity lives in exactly one
	bucket (keyed by its center); queries expand their AABB by the searcher's
	radius, so as long as the query rect covers every center you care about,
	nothing is missed. The map is all positive coordinates, so bucket keys can be
	the simple perfect hash  cx * 100000 + cy  (no collisions for cx < ~21k).

	Two hashes are used server-side:
	  - a persistent one for orbs (insert once, remove on eat),
	  - a rebuilt-every-tick one for cells/pellets/viruses (clear + reinsert is
	    cheaper and simpler than incremental updates for a few hundred movers).

	IMPORTANT: do not insert/remove entities from inside forEachInAABB - collect
	hits into a scratch list and mutate afterwards (callers do this).
]]

local SpatialHash = {}
SpatialHash.__index = SpatialHash

function SpatialHash.new(cellSize: number)
	return setmetatable({
		cellSize = cellSize,
		buckets = {},
	}, SpatialHash)
end

local function key(cx: number, cy: number): number
	return cx * 100000 + cy
end

function SpatialHash:clear()
	table.clear(self.buckets)
end

function SpatialHash:insert(entity)
	local cs = self.cellSize
	local k = key(math.floor(entity.x / cs), math.floor(entity.y / cs))
	local bucket = self.buckets[k]
	if not bucket then
		bucket = {}
		self.buckets[k] = bucket
	end
	bucket[#bucket + 1] = entity
	entity._bucket = k -- remembered so remove() doesn't have to re-derive it
end

function SpatialHash:remove(entity)
	local bucket = self.buckets[entity._bucket]
	if not bucket then
		return
	end
	local i = table.find(bucket, entity)
	if i then
		bucket[i] = bucket[#bucket]
		bucket[#bucket] = nil
	end
end

-- Calls fn(entity) for every entity whose bucket intersects the AABB.
-- Callers still do the precise circle test; this only narrows candidates.
function SpatialHash:forEachInAABB(minX: number, minY: number, maxX: number, maxY: number, fn)
	local cs = self.cellSize
	local buckets = self.buckets
	for cx = math.floor(minX / cs), math.floor(maxX / cs) do
		for cy = math.floor(minY / cs), math.floor(maxY / cs) do
			local bucket = buckets[key(cx, cy)]
			if bucket then
				for i = 1, #bucket do
					fn(bucket[i])
				end
			end
		end
	end
end

return SpatialHash
