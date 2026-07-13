--[[
	Levels - shared XP/level curve. Server and client BOTH require this so they
	agree on the mapping from lifetime XP -> (level, progress) with zero extra
	networking: the server only ever syncs a player's raw lifetime XP, and each
	side derives the level + bar fill from it here.

	Curve: the XP needed to go from level L to L+1 grows geometrically
	(LevelBaseXp * LevelGrowth^(L-1)), so early levels come quick and later ones
	stretch out - the usual "use game for example" feel where a big kill can jump
	you several levels but max levels are a real grind.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local Levels = {}

-- XP required to advance FROM `level` to `level + 1`.
function Levels.xpToNext(level: number): number
	return math.floor(Config.LevelBaseXp * Config.LevelGrowth ^ (level - 1) + 0.5)
end

-- Break a lifetime XP total into (level, xpIntoThisLevel, xpForThisLevel).
-- The loop runs at most `level` times (a handful for normal play) and stops at
-- MaxLevel so a maxed player can't spin it forever.
function Levels.progress(totalXp: number): (number, number, number)
	local level = 1
	local remaining = math.max(0, totalXp)
	while level < Config.MaxLevel do
		local need = Levels.xpToNext(level)
		if remaining < need then
			return level, remaining, need
		end
		remaining -= need
		level += 1
	end
	return Config.MaxLevel, 0, 1 -- capped: bar shown full
end

function Levels.levelForXp(totalXp: number): number
	local level = Levels.progress(totalXp)
	return level
end

return Levels
