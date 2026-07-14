--[[
	UI - assembles the interface (Agma-style layout, minimal look):
	  top-left   = stats bar (Lv/XP, Mass, Coins, FPS/Ping/Cells) + ☰ pause
	  top-right  = custom leaderboard
	  center     = play card (menu)
	  bottom-left  = chat
	  bottom-center = ability dock (in-game)
	  bottom-right = minimap
	World rendering lives in a separate, lower ScreenGui (Renderer).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Theme)
local HUD = require(script.HUD)
local Menu = require(script.Menu)
local Settings = require(script.Settings)
local Shop = require(script.Shop)
local AbilityDock = require(script.AbilityDock)
local Pause = require(script.Pause)
local Minimap = require(script.Minimap)
local Input = require(script.Parent.Input)
local WorldState = require(script.Parent.WorldState)

local UI = {}
UI.HUD = HUD
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

	Menu.init(gui, Shop.toggle, Settings.toggle) -- overlay + card (drawn under the HUD)
	HUD.init(gui)
	Minimap.init(gui)
	AbilityDock.init(gui)
	Pause.init(gui, Settings.toggle) -- ☰ top-left -> Resume / Respawn / Settings / Leave
	Settings.init(gui)
	Shop.init(gui) -- modal on top

	Input.onMenuToggle = Settings.toggle -- the M keybind mirrors the settings panel

	-- debug testing buttons (bottom-left); gated by Config.Debug
	if Config.Debug then
		local pctLabel = ("%d%%"):format(Config.DebugMassPercent)
		local addMass = Theme.outlineButton(gui, "+" .. pctLabel, UDim2.fromScale(0.012, 0.9), UDim2.fromScale(0.055, 0.04), Theme.Green, function()
			Remotes.Action:FireServer("debugmass", 1)
		end)
		Theme.capText(addMass, 14)
		local subMass = Theme.outlineButton(gui, "-" .. pctLabel, UDim2.fromScale(0.072, 0.9), UDim2.fromScale(0.055, 0.04), Theme.Danger, function()
			Remotes.Action:FireServer("debugmass", -1)
		end)
		Theme.capText(subMass, 14)
	end

	WorldState.onPlayerState = function(_event)
		Menu.refresh()
	end

	gui.Parent = playerGui
end

function UI.update(dt: number)
	HUD.update(dt)
	AbilityDock.update(dt)
	Pause.update(dt)
	Menu.update(dt)
	Minimap.update(dt)
end

return UI
