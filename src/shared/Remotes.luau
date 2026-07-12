--[[
	Remotes - single source of truth for every RemoteEvent.
	The server creates them at require-time; clients wait for them.

	Snapshot / Aim are UnreliableRemoteEvents: they carry high-frequency,
	loss-tolerant data (a dropped snapshot just means we interpolate to the next
	one). Everything else is reliable because it is stateful (orb deltas, roster,
	keybinds) and must not be dropped.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFS: { [string]: string } = {
	Snapshot = "UnreliableRemoteEvent", -- server -> client: packed world snapshot (buffer)
	Aim = "UnreliableRemoteEvent", -- client -> server: world-space aim target (x, y)
	Action = "RemoteEvent", -- client -> server: split/feed/freeze/play/... commands
	OrbSync = "RemoteEvent", -- server -> client: full orb table on join + eat/spawn deltas
	Roster = "RemoteEvent", -- server -> client: slot -> {name, color} mapping
	Leaderboard = "RemoteEvent", -- server -> client: top players, 1 Hz
	Ping = "RemoteEvent", -- round-trip echo for the HUD ping display
	Keybinds = "RemoteEvent", -- keybind save (c->s) / load (s->c)
	PlayerState = "RemoteEvent", -- server -> client: "spawned" / "died"
}

local FOLDER_NAME = "AgarRemotes"

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for name, className in DEFS do
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	for name in DEFS do
		Remotes[name] = folder:FindFirstChild(name)
	end
else
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	for name in DEFS do
		Remotes[name] = folder:WaitForChild(name)
	end
end

return Remotes
