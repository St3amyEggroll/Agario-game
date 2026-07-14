--[[
	Util - shared math helpers (mass <-> radius <-> speed formulas).
]]

local Config = require(script.Parent.Config)

local Util = {}

function Util.radiusFromMass(mass: number): number
	return math.sqrt(mass) * Config.RadiusPerSqrtMass
end

function Util.massFromRadius(radius: number): number
	local s = radius / Config.RadiusPerSqrtMass
	return s * s
end

-- Standard agar-style speed curve: heavier cells move slower.
function Util.speedFromMass(mass: number): number
	return Config.SpeedBase * mass ^ Config.SpeedExponent
end

-- How long a freshly-split cell must wait before it can merge back.
function Util.mergeDelay(mass: number): number
	-- scales from MergeTimeBase (little) up with mass, capped at MergeTimeMax (big)
	return math.min(Config.MergeTimeBase + mass * Config.MergeTimePerMass, Config.MergeTimeMax)
end

function Util.dist2(ax: number, ay: number, bx: number, by: number): number
	local dx, dy = bx - ax, by - ay
	return dx * dx + dy * dy
end

-- Swap-remove a value from an array (O(n) find, O(1) remove; order not preserved).
function Util.arrayRemove(arr: { any }, value: any): boolean
	local i = table.find(arr, value)
	if i then
		arr[i] = arr[#arr]
		arr[#arr] = nil
		return true
	end
	return false
end

-- Abbreviate a mass/score for display: 532 -> "532", 1500 -> "1.5K",
-- 15000 -> "15K", 2_340_000 -> "2.34M". Trailing zeros are trimmed.
function Util.abbrevMass(n: number): string
	n = math.floor(n + 0.5)
	if n < 1000 then
		return tostring(n)
	elseif n < 1e6 then
		return (string.format("%.1f", n / 1000):gsub("%.0$", "")) .. "K"
	else
		return (string.format("%.2f", n / 1e6):gsub("%.?0+$", "")) .. "M"
	end
end

-- Returns a unit vector (dx, dy) or (1, 0) when the input is degenerate.
function Util.unit(dx: number, dy: number): (number, number)
	local d = math.sqrt(dx * dx + dy * dy)
	if d < 1e-4 then
		return 1, 0
	end
	return dx / d, dy / d
end

return Util
