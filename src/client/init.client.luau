--[[
	Client bootstrap.

	Per-frame order (RenderStepped) matters:
	  1. WorldState.sample()  - interpolate the two bracketing snapshots
	  2. Camera.update()      - follow the (interpolated) centroid
	  3. Renderer.render()    - cull + draw pooled frames
	  4. Input.tick()         - throttled aim send, feed auto-repeat
	  5. UI.update()          - HUD counters
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local WorldState = require(script.WorldState)
local Camera = require(script.Camera)
local Renderer = require(script.Renderer)
local Input = require(script.Input)
local UI = require(script.UI)
local ChatBubbles = require(script.ChatBubbles)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- the game is 100% ScreenGui: park the 3D camera and hide the core UI that
-- assumes a character. The Roblox PlayerList (our leaderboard, via leaderstats)
-- and Chat are kept ON.
Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
for _, coreGui in { Enum.CoreGuiType.Backpack, Enum.CoreGuiType.Health, Enum.CoreGuiType.EmotesMenu } do
	pcall(function()
		StarterGui:SetCoreGuiEnabled(coreGui, false)
	end)
end

Renderer.init(playerGui)
Input.init()
UI.init(playerGui)
ChatBubbles.init(playerGui)

RunService.RenderStepped:Connect(function(dt)
	WorldState.sample(dt)
	Camera.update(dt)
	Renderer.render(Camera)
	ChatBubbles.render(Camera)
	Input.tick(dt, os.clock())
	UI.update(dt)
end)

-- ping loop: server echoes our clock back; RTT = now - sent
Remotes.Ping.OnClientEvent:Connect(function(sentAt)
	UI.HUD.setPing((os.clock() - sentAt) * 1000)
end)
task.spawn(function()
	while true do
		Remotes.Ping:FireServer(os.clock())
		task.wait(1)
	end
end)
