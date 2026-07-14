--[[
	Levels (server) - award XP + coins, persist both, and push them to clients.

	XP is lifetime-cumulative on info.xp (client derives level + bar from it via
	Shared.Levels). Coins (info.coins) are the spendable currency from gold-coin
	pickups. Both persist across sessions under separate DataStore keys (numbers,
	so there's no format migration).

	- award(info, foodMass): XP from eaten food; marks the player dirty to save.
	- addCoins(info, n): grant coins, push the new total to the client, mark dirty.
	- pushChanged(): 1 Hz, sends XP only to players whose total changed.
	- load/save mirror Names: pcall'd DataStore, quiet no-op in Studio without API
	  access so it's still testable locally (just not persisted).
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
		warn("[Agar] DataStore unavailable, progress will not persist:", result)
	end
end

local savePending = {} -- [Player] = true while a debounced save is scheduled

local function saveNow(player, xp: number, coins: number)
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("xp_" .. player.UserId, xp)
		store:SetAsync("coins_" .. player.UserId, coins)
	end)
	if not ok then
		warn("[Agar] progress save failed:", err)
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
				saveNow(player, info.xp, info.coins)
			end
		end
	end)
end

function Levels.onPlayerAdded(player)
	task.spawn(function()
		local savedXp, savedCoins = nil, nil
		if store then
			local ok, result = pcall(function()
				return store:GetAsync("xp_" .. player.UserId)
			end)
			if ok and typeof(result) == "number" then
				savedXp = result
			end
			local ok2, result2 = pcall(function()
				return store:GetAsync("coins_" .. player.UserId)
			end)
			if ok2 and typeof(result2) == "number" then
				savedCoins = result2
			end
		end
		local info = World.players[player]
		if not info then
			return -- left before the async load finished
		end
		if savedXp and savedXp > 0 then
			info.xp = savedXp
		end
		if savedCoins and savedCoins > 0 then
			info.coins = savedCoins
		end
		-- send starting XP + coins so the HUD is correct immediately
		info.xpSent = info.xp
		Remotes.Level:FireClient(player, info.xp)
		Remotes.PlayerState:FireClient(player, "coins", info.coins)
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

-- Grant coins (gold-coin pickups), push the new total to the owner, persist.
function Levels.addCoins(info, n: number)
	if not info or n == 0 then
		return
	end
	info.coins += n
	Remotes.PlayerState:FireClient(info.player, "coins", info.coins)
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
			saveNow(player, info.xp, info.coins)
		end
	end
end

return Levels
