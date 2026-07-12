--[[
	Keybinds - DataStore persistence for remapped controls.
	Saves are debounced (one write at most every few seconds per player) and
	every DataStore call is pcall'd: in Studio without API access the game
	silently falls back to defaults / in-session persistence.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local SAVE_DEBOUNCE = 3

local Keybinds = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("AgarSettings_v1")
	end)
	if ok then
		store = result
	else
		warn("[Agar] DataStore unavailable, keybinds will not persist:", result)
	end
end

local cache = {} -- [Player] = binds table (also the in-session fallback)
local savePending = {} -- [Player] = true while a debounced save is scheduled

local function validBinds(tbl): { [string]: string }?
	if typeof(tbl) ~= "table" then
		return nil
	end
	local out = {}
	for action in Config.DefaultKeybinds do
		local v = tbl[action]
		if typeof(v) == "string" and #v <= 24 then
			out[action] = v
		end
	end
	return out
end

local function saveNow(player)
	local binds = cache[player]
	if not store or not binds then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("kb_" .. player.UserId, binds)
	end)
	if not ok then
		warn("[Agar] keybind save failed:", err)
	end
end

function Keybinds.onPlayerAdded(player)
	task.spawn(function()
		local loaded = nil
		if store then
			local ok, result = pcall(function()
				return store:GetAsync("kb_" .. player.UserId)
			end)
			if ok then
				loaded = validBinds(result)
			end
		end
		if loaded then
			cache[player] = loaded
		end
		-- nil tells the client "use your defaults"
		Remotes.Keybinds:FireClient(player, loaded)
	end)
end

function Keybinds.onPlayerRemoving(player)
	if savePending[player] then
		savePending[player] = nil
		saveNow(player)
	end
	cache[player] = nil
end

Remotes.Keybinds.OnServerEvent:Connect(function(player, tbl)
	local binds = validBinds(tbl)
	if not binds then
		return
	end
	cache[player] = binds
	if not savePending[player] then
		savePending[player] = true
		task.delay(SAVE_DEBOUNCE, function()
			if savePending[player] then
				savePending[player] = nil
				saveNow(player)
			end
		end)
	end
end)

return Keybinds
