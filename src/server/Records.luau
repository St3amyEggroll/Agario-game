--[[
	Records - the persistent ALL-TIME hiscores. A single DataStore key holds
	per-user entries {u = userId, n = name, m = best mass, k = most kills,
	p = longest playtime (seconds)}; each field keeps the max across the user's
	sessions (merged via UpdateAsync). The cached set is broadcast to clients for
	the Hiscores panel, which sorts it by the chosen board (Mass / Playtime /
	Kills). Every DataStore call is pcall'd, so it no-ops safely in Studio without
	API access (records are just empty then, and the panel shows live players).
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)

local Records = {}

local KEY = "top"
local REFRESH_INTERVAL = 30 -- seconds between periodic online-player submits + refresh

local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("AgarRecords_v1")
	end)
	if ok then
		store = result
	else
		warn("[Agar] records DataStore unavailable:", result)
	end
end

local cache = {} -- array of {u, n, m}, sorted desc (the current top-N)

local function broadcast()
	local out = {}
	for _, e in cache do
		table.insert(out, { n = e.n, m = e.m or 0, k = e.k or 0, p = e.p or 0 })
	end
	Remotes.Records:FireAllClients(out)
end

-- Keep the top KEEP_EACH entries by EACH metric (their union), so a kills or
-- playtime leader isn't dropped just because their mass is low.
local KEEP_EACH = 15
local function capUnion(list)
	if #list <= KEEP_EACH then
		return list
	end
	local keep = {}
	for _, metric in { "m", "k", "p" } do
		local sorted = table.clone(list)
		table.sort(sorted, function(a, b)
			return (a[metric] or 0) > (b[metric] or 0)
		end)
		for i = 1, math.min(KEEP_EACH, #sorted) do
			keep[sorted[i]] = true
		end
	end
	local out = {}
	for _, e in list do
		if keep[e] then
			table.insert(out, e)
		end
	end
	return out
end

function Records.refresh()
	if not store then
		return
	end
	task.spawn(function()
		local ok, data = pcall(function()
			return store:GetAsync(KEY)
		end)
		if ok and type(data) == "table" then
			cache = data
			broadcast()
		end
	end)
end

-- Merge a session's (mass, kills, playtime) into the persistent hiscores, keeping
-- the max of each per user. kills/playtime are optional (nil -> 0) so older
-- 3-arg callers still work.
function Records.submit(userId: number, name: string, mass: number, kills: number?, playtime: number?)
	if not store then
		return
	end
	mass = math.max(0, math.floor(mass or 0))
	kills = math.max(0, math.floor(kills or 0))
	playtime = math.max(0, math.floor(playtime or 0))
	if mass <= 0 and kills <= 0 and playtime <= 0 then
		return
	end
	task.spawn(function()
		local ok = pcall(function()
			store:UpdateAsync(KEY, function(old)
				old = old or {}
				local found
				for _, e in old do
					if e.u == userId then
						found = e
						break
					end
				end
				if found then
					found.n = name
					found.m = math.max(found.m or 0, mass)
					found.k = math.max(found.k or 0, kills)
					found.p = math.max(found.p or 0, playtime)
				else
					table.insert(old, { u = userId, n = name, m = mass, k = kills, p = playtime })
				end
				return capUnion(old)
			end)
		end)
		if ok then
			Records.refresh()
		end
	end)
end

function Records.init()
	Records.refresh()
	task.spawn(function()
		while true do
			task.wait(REFRESH_INTERVAL)
			for _, info in World.players do
				local best = info.bestMass or 0
				-- submit whenever a session's best mass improves; the merge also folds
				-- in current kills + playtime (each kept as a max per user)
				if best > (info.recordsSubmitted or 0) then
					info.recordsSubmitted = best
					Records.submit(info.player.UserId, info.name, best, info.kills, info.playSeconds)
				end
			end
			Records.refresh()
		end
	end)
end

return Records
