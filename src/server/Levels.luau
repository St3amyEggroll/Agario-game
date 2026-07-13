--[[
	Levels (server) - award XP, persist it, and push it to clients.

	XP is lifetime-cumulative on info.xp. The client derives level + progress bar
	from the raw XP via Shared.Levels, so all we ever sync is the number.

	- award(info, foodMass): called from the simulation whenever a cell eats real
	  food. Marks the player dirty for a debounced save.
	- pushChanged(): called each leaderboard tick (1 Hz) - sends XP only to players
	  whose total changed since the last push (info.xpSent), so idle players cost
	  nothing.
	- load/save mirror Names: pcall'd DataStore, quiet no-op in Studio without API
	  access so levels are still testable locally (just not persisted).
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)

local SAVE_DEBOUNCE = 5

local Levels = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("AgarLevels_v1")
	end)
	if ok then
		store = result
	else
		warn("[Agar] DataStore unavailable, levels will not persist:", result)
	end
end

local savePending = {} -- [Player] = true while a debounced XP save is scheduled

local function saveNow(player, xp: number)
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("xp_" .. player.UserId, xp)
	end)
	if not ok then
		warn("[Agar] xp save failed:", err)
	end
end

local function scheduleSave(player)
	if not store or savePending[player] then
		return
	end
	savePending[player] = true
	task.delay(SAVE_DEBOUNCE, function()
		if savePending[player] then
			savePending[player] = nil
			local info = World.players[player]
			if info then
				saveNow(player, info.xp)
			end
		end
	end)
end

function Levels.onPlayerAdded(player)
	task.spawn(function()
		local savedXp = nil
		if store then
			local ok, result = pcall(function()
				return store:GetAsync("xp_" .. player.UserId)
			end)
			if ok and typeof(result) == "number" then
				savedXp = result
			end
		end
		local info = World.players[player]
		if not info then
			return -- left before the async load finished
		end
		if savedXp and savedXp > 0 then
			info.xp = savedXp
		end
		-- send the starting XP so the HUD shows the right level immediately
		info.xpSent = info.xp
		Remotes.Level:FireClient(player, info.xp)
	end)
end

-- Called from the simulation's eat pass. `foodMass` is the mass of real food
-- consumed this eat (orbs / enemy cells / enemy pellets - NOT your own pellets).
function Levels.award(info, foodMass: number)
	if not info or foodMass <= 0 then
		return
	end
	info.xp += foodMass * Config.XpPerMass
	scheduleSave(info.player)
end

-- 1 Hz: push XP to any player whose total changed since the last push.
function Levels.pushChanged()
	for player, info in World.players do
		if info.xp ~= info.xpSent then
			info.xpSent = info.xp
			Remotes.Level:FireClient(player, math.floor(info.xp))
		end
	end
end

function Levels.onPlayerRemoving(player)
	if savePending[player] then
		savePending[player] = nil
		local info = World.players[player]
		if info then
			saveNow(player, info.xp)
		end
	end
end

return Levels
