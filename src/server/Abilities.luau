--[[
	Abilities (server) - the Gold economy + cooldowns behind the ability dock.

	Ownership is a SET on info.abilities ({[id] = true}); persisted per player under
	a DataStore key (pcall'd, so it no-ops in Studio without API access). Buying
	deducts Gold (info.coins via Levels.addCoins). Using is validated here (owned +
	off cooldown); the EFFECT runs in Simulation. Cooldowns live on
	info.abilityCooldowns[id] as an os.clock() end time and are mirrored to the
	owner so the dock can draw the countdown.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)
local Levels = require(script.Parent.Levels)

local SAVE_DEBOUNCE = 3

local Abilities = {}

-- id -> catalog def
local BY_ID = {}
for _, a in Config.Abilities do
	BY_ID[a.id] = a
end
Abilities.byId = BY_ID

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("AgarAbilities_v1")
	end)
	if ok then
		store = result
	else
		warn("[Agar] abilities DataStore unavailable:", result)
	end
end

local savePending = {} -- [Player] = true while a debounced save is scheduled

local function ownedArray(info): { string }
	local out = {}
	for id in info.abilities do
		table.insert(out, id)
	end
	return out
end

-- Remaining cooldown (seconds) per owned ability, for the client's dock.
local function cooldownMap(info): { [string]: number }
	local now = os.clock()
	local out = {}
	for id in info.abilities do
		local endAt = info.abilityCooldowns[id]
		out[id] = (endAt and endAt > now) and (endAt - now) or 0
	end
	return out
end

-- Full owned + cooldown state (sent on join / after a load).
function Abilities.sync(player)
	local info = World.players[player]
	if not info then
		return
	end
	Remotes.Abilities:FireClient(player, "full", ownedArray(info), cooldownMap(info))
end

local function saveNow(player, owned)
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("abilities_" .. player.UserId, owned)
	end)
	if not ok then
		warn("[Agar] abilities save failed:", err)
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
				saveNow(player, ownedArray(info))
			end
		end
	end)
end

function Abilities.onPlayerAdded(player)
	task.spawn(function()
		local owned
		if store then
			local ok, result = pcall(function()
				return store:GetAsync("abilities_" .. player.UserId)
			end)
			if ok and type(result) == "table" then
				owned = result
			end
		end
		local info = World.players[player]
		if not info then
			return -- left before the async load finished
		end
		if owned then
			for _, id in owned do
				if BY_ID[id] then
					info.abilities[id] = true
				end
			end
		end
		Abilities.sync(player)
	end)
end

function Abilities.onPlayerRemoving(player)
	if savePending[player] then
		savePending[player] = nil
		local info = World.players[player]
		if info then
			saveNow(player, ownedArray(info))
		end
	end
end

-- Buy an ability with Gold. Validates the id, that it isn't already owned, and
-- that the player can afford it; then deducts and grants.
function Abilities.buy(player, id)
	local info = World.players[player]
	if not info then
		return
	end
	local def = BY_ID[id]
	if not def or info.abilities[id] then
		return
	end
	if (info.coins or 0) < def.price then
		Remotes.Feedback:FireClient(player, "broke", def.name)
		return
	end
	Levels.addCoins(info, -def.price) -- deduct + push the new total to the client
	info.abilities[id] = true
	Remotes.Abilities:FireClient(player, "owned", id)
	scheduleSave(player)
end

-- Can this player use ability id right now? (owned + off cooldown)
function Abilities.canUse(info, id): boolean
	if not info or not info.abilities[id] then
		return false
	end
	local endAt = info.abilityCooldowns[id]
	return not endAt or os.clock() >= endAt
end

-- Start ability id's cooldown and mirror it to the owner's dock.
function Abilities.startCooldown(player, info, id)
	local def = BY_ID[id]
	if not def then
		return
	end
	info.abilityCooldowns[id] = os.clock() + def.cooldown
	Remotes.Abilities:FireClient(player, "cooldown", id, def.cooldown)
end

return Abilities
