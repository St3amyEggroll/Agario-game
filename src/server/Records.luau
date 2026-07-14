--[[
	Records - the persistent ALL-TIME high-mass leaderboard. A single DataStore key
	holds the top-N entries {u = userId, n = name, m = mass}, sorted descending.
	Each player's session-best mass is merged in via UpdateAsync (one entry per
	user, keep the max), and the cached top-N is broadcast to clients for the
	Hiscores panel. Every DataStore call is pcall'd, so it no-ops safely in Studio
	without API access (records are just empty then).
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local World = require(script.Parent.World)

local Records = {}

local TOP_N = 15
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
		table.insert(out, { n = e.n, m = e.m })
	end
	Remotes.Records:FireAllClients(out)
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

-- Merge a (userId, name, mass) into the persistent top-N.
function Records.submit(userId: number, name: string, mass: number)
	if not store or mass <= 0 then
		return
	end
	mass = math.floor(mass)
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
					if mass > found.m then
						found.m, found.n = mass, name
					else
						return nil -- not a new personal best: leave the store unchanged
					end
				else
					table.insert(old, { u = userId, n = name, m = mass })
				end
				table.sort(old, function(a, b)
					return a.m > b.m
				end)
				while #old > TOP_N do
					table.remove(old)
				end
				return old
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
			local minCached = (#cache >= TOP_N and cache[#cache] and cache[#cache].m) or 0
			for _, info in World.players do
				local best = info.bestMass or 0
				-- submit online players whose session best improved AND would rank
				if best > (info.recordsSubmitted or 0) and (best > minCached or #cache < TOP_N) then
					info.recordsSubmitted = best
					Records.submit(info.player.UserId, info.name, best)
				end
			end
			Records.refresh()
		end
	end)
end

return Records
