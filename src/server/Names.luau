--[[
	Names - custom display names: filter, apply, and persist across sessions.

	Flow:
	  - on join: load the saved name (DataStore). If none, fall back to the
	    Roblox DisplayName. Set info.name, broadcast the roster, and send the
	    name to the client so the menu box prefills.
	  - on setname (from the menu): clamp length + strip control chars, run it
	    through Roblox text filtering, apply to info.name, broadcast, and save
	    (debounced).

	Robustness: every DataStore / TextService call is pcall'd. In Studio without
	API access, filtering and persistence quietly no-op and the raw (clamped,
	stripped) name is used so names are still testable.
]]

local DataStoreService = game:GetService("DataStoreService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)

local SAVE_DEBOUNCE = 3

local Names = {}

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("AgarNames_v1")
	end)
	if ok then
		store = result
	else
		warn("[Agar] DataStore unavailable, names will not persist:", result)
	end
end

local savePending = {} -- [Player] = true while a debounced save is scheduled

-- Clamp length and strip control characters / leading-trailing spaces. Returns
-- nil for an empty result.
local function sanitize(raw: string): string?
	if typeof(raw) ~= "string" then
		return nil
	end
	raw = raw:gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	raw = raw:sub(1, Config.MaxNameLength)
	if #raw == 0 then
		return nil
	end
	return raw
end

-- Run through Roblox text filtering (broadcast form, since the name is shown to
-- everyone). Falls back to the sanitized raw name if filtering is unavailable.
local function filterForBroadcast(player, name: string): string
	local ok, result = pcall(function()
		local obj = TextService:FilterStringAsync(name, player.UserId)
		return obj:GetNonChatStringForBroadcastAsync()
	end)
	if ok and typeof(result) == "string" and #result > 0 then
		return result
	end
	return name -- Studio / no API access: use the sanitized raw name
end

local function saveNow(player, name: string)
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("name_" .. player.UserId, name)
	end)
	if not ok then
		warn("[Agar] name save failed:", err)
	end
end

function Names.onPlayerAdded(player)
	task.spawn(function()
		local saved = nil
		if store then
			local ok, result = pcall(function()
				return store:GetAsync("name_" .. player.UserId)
			end)
			if ok and typeof(result) == "string" then
				saved = result
			end
		end
		local info = World.players[player]
		if not info then
			return -- left before the async load finished
		end
		if saved and #saved > 0 then
			info.name = saved
			World.broadcastRosterUpdate(info)
		end
		-- prefill the client's menu box with whatever name is now in effect
		Remotes.Name:FireClient(player, info.name)
	end)
end

-- Called from Network on a validated "setname" action (arg is the raw string).
function Names.setName(player, raw)
	local info = World.players[player]
	if not info then
		return
	end
	local clean = sanitize(raw)
	if not clean then
		return
	end
	-- filtering is async; do it off the main thread
	task.spawn(function()
		local filtered = filterForBroadcast(player, clean)
		local current = World.players[player]
		if not current then
			return -- player left mid-filter
		end
		current.name = filtered
		World.broadcastRosterUpdate(current)
		Remotes.Name:FireClient(player, filtered)
		if not savePending[player] then
			savePending[player] = true
			task.delay(SAVE_DEBOUNCE, function()
				if savePending[player] then
					savePending[player] = nil
					saveNow(player, World.players[player] and World.players[player].name or filtered)
				end
			end)
		end
	end)
end

function Names.onPlayerRemoving(player)
	if savePending[player] then
		savePending[player] = nil
		local info = World.players[player]
		if info then
			saveNow(player, info.name)
		end
	end
end

return Names
