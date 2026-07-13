--[[
	UI - assembles the interface ScreenGui: HUD, bottom menu, settings (keybinds),
	shop, the ability dock, and the top-left control row. World rendering lives in
	a separate, lower ScreenGui (Renderer); this one sits on top.

	Layout (minimal / classic-agar): top-left = control row (Settings / Menu /
	Respawn) with the tiny stat block under it; bottom-left = Mass; bottom-center
	= level bar; bottom-right = ability dock. Leaderboard is the Roblox player
	list (top-right, native).
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

	Menu.init(gui, Shop.toggle) -- overlay first so panels draw above it
	HUD.init(gui)
	AbilityDock.init(gui) -- bottom-right on-screen action buttons (also touch controls)
	Settings.init(gui)
	Shop.init(gui)

	-- top-left control row: Settings (M key mirrors it) / Menu / Respawn
	local settingsBtn = Theme.button(gui, "Settings", UDim2.fromScale(0.012, 0.014), UDim2.fromScale(0.072, 0.045), function()
		Settings.toggle()
	end)
	Theme.capText(settingsBtn, 15)
	Input.onMenuToggle = Settings.toggle

	local toMenuBtn = Theme.button(gui, "Menu", UDim2.fromScale(0.09, 0.014), UDim2.fromScale(0.052, 0.045), function()
		Remotes.Action:FireServer("tomenu")
	end)
	Theme.capText(toMenuBtn, 15)

	local respawnBtn = Theme.outlineButton(gui, "Respawn", UDim2.fromScale(0.148, 0.014), UDim2.fromScale(0.078, 0.045), Theme.Green, function()
		Remotes.Action:FireServer("respawn")
	end)
	Theme.capText(respawnBtn, 15)

	-- debug testing buttons (below the stat block); gated by Config.Debug - the
	-- server also refuses these when it's off
	if Config.Debug then
		local pctLabel = ("%d%%"):format(Config.DebugMassPercent)
		local addMass = Theme.outlineButton(gui, "+" .. pctLabel, UDim2.fromScale(0.012, 0.2), UDim2.fromScale(0.055, 0.04), Theme.Green, function()
			Remotes.Action:FireServer("debugmass", 1)
		end)
		Theme.capText(addMass, 14)
		local subMass = Theme.outlineButton(gui, "-" .. pctLabel, UDim2.fromScale(0.072, 0.2), UDim2.fromScale(0.055, 0.04), Theme.Danger, function()
			Remotes.Action:FireServer("debugmass", -1)
		end)
		Theme.capText(subMass, 14)
	end

	-- server state -> UI
	WorldState.onPlayerState = function(_event)
		Menu.refresh()
	end
	-- WorldState.leaderboard is still kept (from the Leaderboard remote) so the
	-- spectate/menu camera can follow the leader - it just isn't drawn anymore.

	gui.Parent = playerGui
end

function UI.update(dt: number)
	HUD.update(dt)
	AbilityDock.update(dt)
end

return UI
