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
local Util = require(Shared.Util)
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

local savePending = {} -- [Player] = true while a debounced NAME save is scheduled
local skinSavePending = {} -- [Player] = true while a debounced SKIN save is scheduled
local colorSavePending = {} -- [Player] = true while a debounced COLOR save is scheduled
local overlaysSavePending = {} -- [Player] = true while a debounced OVERLAYS save is scheduled

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

local function saveSkinNow(player, skinId: number)
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("skin_" .. player.UserId, skinId)
	end)
	if not ok then
		warn("[Agar] skin save failed:", err)
	end
end

local function saveColorNow(player, packed: number)
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("color_" .. player.UserId, packed)
	end)
	if not ok then
		warn("[Agar] color save failed:", err)
	end
end

local function saveOverlaysNow(player, overlays: { number })
	if not store then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("overlays_" .. player.UserId, overlays)
	end)
	if not ok then
		warn("[Agar] overlays save failed:", err)
	end
end

function Names.onPlayerAdded(player)
	task.spawn(function()
		local savedName, savedSkin, savedColor, savedOverlays = nil, nil, nil, nil
		if store then
			local ok, result = pcall(function()
				return store:GetAsync("name_" .. player.UserId)
			end)
			if ok and typeof(result) == "string" then
				savedName = result
			end
			local ok2, result2 = pcall(function()
				return store:GetAsync("skin_" .. player.UserId)
			end)
			if ok2 and typeof(result2) == "number" then
				savedSkin = result2
			end
			local ok3, result3 = pcall(function()
				return store:GetAsync("color_" .. player.UserId)
			end)
			if ok3 and typeof(result3) == "number" then
				savedColor = result3
			end
			local ok4, result4 = pcall(function()
				return store:GetAsync("overlays_" .. player.UserId)
			end)
			if ok4 and typeof(result4) == "table" then
				savedOverlays = result4
			end
		end
		local info = World.players[player]
		if not info then
			return -- left before the async load finished
		end
		local changed = false
		if savedName and #savedName > 0 then
			info.name = savedName
			changed = true
		end
		if savedSkin and savedSkin > 0 then
			info.skinId = savedSkin -- restore the BASE skin (positive only; avatar is an overlay now)
			changed = true
		end
		if savedColor and savedColor >= 0 and savedColor <= 0xFFFFFF then
			-- legacy saves stored a palette INDEX (1..#Palette); newer saves store a
			-- packed 0xRRGGBB colour. Remap an index-looking value so old players keep
			-- a real colour instead of a near-black one.
			if savedColor >= 1 and savedColor <= #Config.Palette then
				info.color = Util.packColor(Config.Palette[savedColor])
			else
				info.color = savedColor -- restore the chosen cell colour
			end
			changed = true
		end
		if savedOverlays then
			for _, id in savedOverlays do
				if typeof(id) == "number" then
					info.overlays[id] = true -- restore worn layers (accessories + avatar)
				end
			end
			changed = true
		end
		if changed then
			World.broadcastRosterUpdate(info)
		end
		-- prefill the client's menu box with whatever name is now in effect
		Remotes.Name:FireClient(player, info.name)
	end)
end

-- Persist the equipped skin (debounced). Called from Network on a valid setskin.
function Names.saveSkin(player, skinId: number)
	if not store or skinSavePending[player] then
		return
	end
	skinSavePending[player] = true
	task.delay(SAVE_DEBOUNCE, function()
		if skinSavePending[player] then
			skinSavePending[player] = nil
			local info = World.players[player]
			if info then
				saveSkinNow(player, info.skinId)
			end
		end
	end)
end

-- Persist the chosen cell colour (debounced). Called from Network on setcolor.
function Names.saveColor(player, packed: number)
	if not store or colorSavePending[player] then
		return
	end
	colorSavePending[player] = true
	task.delay(SAVE_DEBOUNCE, function()
		if colorSavePending[player] then
			colorSavePending[player] = nil
			local info = World.players[player]
			if info then
				saveColorNow(player, info.color)
			end
		end
	end)
end

-- Persist the worn overlay set (debounced). Called from Network on set(accessory|avatar).
function Names.saveOverlays(player)
	if not store or overlaysSavePending[player] then
		return
	end
	overlaysSavePending[player] = true
	task.delay(SAVE_DEBOUNCE, function()
		if overlaysSavePending[player] then
			overlaysSavePending[player] = nil
			local info = World.players[player]
			if info then
				saveOverlaysNow(player, World.overlaysArray(info))
			end
		end
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
	local info = World.players[player]
	if savePending[player] then
		savePending[player] = nil
		if info then
			saveNow(player, info.name)
		end
	end
	if skinSavePending[player] then
		skinSavePending[player] = nil
		if info then
			saveSkinNow(player, info.skinId)
		end
	end
	if colorSavePending[player] then
		colorSavePending[player] = nil
		if info then
			saveColorNow(player, info.color)
		end
	end
	if overlaysSavePending[player] then
		overlaysSavePending[player] = nil
		if info then
			saveOverlaysNow(player, World.overlaysArray(info))
		end
	end
end

return Names
