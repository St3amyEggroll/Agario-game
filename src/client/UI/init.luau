--[[
	UI - assembles the interface ScreenGui: the play menu, HUD, ability dock,
	the in-game pause menu, settings (keybinds) and the shop. World rendering
	lives in a separate, lower ScreenGui (Renderer); this one sits on top.

	Layout (minimal / classic-agar): bottom-left = Mass, top-left = tiny stats +
	the ☰ pause button, bottom-center = level bar, bottom-right = ability dock.
	Leaderboard is the Roblox player list (top-right, native). Menu / Respawn /
	Settings live in the ☰ pause popup; Spectate lives on the play menu.
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

	Menu.init(gui, Shop.toggle, Settings.toggle) -- overlay first so panels draw above it
	HUD.init(gui)
	AbilityDock.init(gui) -- bottom-right on-screen action buttons (also touch controls)
	Pause.init(gui, Settings.toggle) -- ☰ top-left -> Resume / Respawn / Settings / Leave
	Settings.init(gui)
	Shop.init(gui)

	Input.onMenuToggle = Settings.toggle -- the M keybind mirrors the settings panel

	-- debug testing buttons (below the stat block); gated by Config.Debug - the
	-- server also refuses these when it's off
	if Config.Debug then
		local pctLabel = ("%d%%"):format(Config.DebugMassPercent)
		local addMass = Theme.outlineButton(gui, "+" .. pctLabel, UDim2.fromScale(0.012, 0.35), UDim2.fromScale(0.055, 0.04), Theme.Green, function()
			Remotes.Action:FireServer("debugmass", 1)
		end)
		Theme.capText(addMass, 14)
		local subMass = Theme.outlineButton(gui, "-" .. pctLabel, UDim2.fromScale(0.072, 0.35), UDim2.fromScale(0.055, 0.04), Theme.Danger, function()
			Remotes.Action:FireServer("debugmass", -1)
		end)
		Theme.capText(subMass, 14)
	end

	-- server state -> UI
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
end

return UI
