--[[
	UI - assembles the interface ScreenGui: HUD, leaderboard, bottom menu,
	settings (keybinds) and the shop stub. World rendering lives in a separate,
	lower ScreenGui (Renderer); this one sits on top.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Theme)
local HUD = require(script.HUD)
local Leaderboard = require(script.Leaderboard)
local Menu = require(script.Menu)
local Settings = require(script.Settings)
local Shop = require(script.Shop)
local Input = require(script.Parent.Input)
local WorldState = require(script.Parent.WorldState)

local UI = {}
UI.HUD = HUD
UI.Leaderboard = Leaderboard
UI.Menu = Menu
UI.Settings = Settings
UI.Shop = Shop

function UI.init(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AgarUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	Menu.init(gui, Shop.toggle) -- overlay first so panels draw above it
	HUD.init(gui)
	Leaderboard.init(gui)
	Settings.init(gui)
	Shop.init(gui)

	-- top-left menu (settings) button; the Menu keybind mirrors it
	local menuButton = Theme.button(gui, "\u{2630} Menu", UDim2.fromScale(0.01, 0.015), UDim2.fromScale(0.075, 0.05), function()
		Settings.toggle()
	end)
	Theme.capText(menuButton, 18)
	Input.onMenuToggle = Settings.toggle

	-- debug testing buttons (below the HUD panel); remove by setting
	-- Config.Debug = false - the server also refuses these when it's off
	if Config.Debug then
		local addMass = Theme.button(gui, "+ Mass", UDim2.fromScale(0.01, 0.2), UDim2.fromScale(0.075, 0.045), function()
			Remotes.Action:FireServer("debugmass", 1)
		end)
		addMass.BackgroundColor3 = Color3.fromRGB(55, 110, 70)
		Theme.capText(addMass, 16)
		local subMass = Theme.button(gui, "- Mass", UDim2.fromScale(0.01, 0.25), UDim2.fromScale(0.075, 0.045), function()
			Remotes.Action:FireServer("debugmass", -1)
		end)
		subMass.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
		Theme.capText(subMass, 16)
	end

	-- server state -> UI
	WorldState.onPlayerState = function(_event)
		Menu.refresh()
	end
	WorldState.onLeaderboard = function(entries)
		Leaderboard.update(entries)
	end

	gui.Parent = playerGui
end

function UI.update(dt: number)
	HUD.update(dt)
end

return UI
