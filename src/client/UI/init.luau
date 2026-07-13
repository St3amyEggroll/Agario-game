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
local Menu = require(script.Menu)
local Settings = require(script.Settings)
local Shop = require(script.Shop)
local AbilityDock = require(script.AbilityDock)
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

	Menu.init(gui, Shop.toggle) -- overlay first so panels draw above it
	HUD.init(gui)
	AbilityDock.init(gui) -- bottom-center on-screen action buttons (also touch controls)
	Minimap.init(gui) -- bottom-right corner map
	-- (custom leaderboard panel removed - the Roblox player list is the
	-- leaderboard now, driven by leaderstats/Mass)
	Settings.init(gui)
	Shop.init(gui)

	-- top-left settings button; the Menu keybind (M) mirrors it
	local menuButton = Theme.button(gui, "\u{2630} Settings", UDim2.fromScale(0.01, 0.015), UDim2.fromScale(0.075, 0.05), function()
		Settings.toggle()
	end)
	Theme.capText(menuButton, 18)
	Input.onMenuToggle = Settings.toggle

	-- instant Respawn (also the B key) + back-to-Menu (also the N key), top-center
	local respawnButton = Theme.button(gui, "Respawn", UDim2.fromScale(0.4, 0.015), UDim2.fromScale(0.09, 0.05), function()
		Remotes.Action:FireServer("respawn")
	end)
	respawnButton.BackgroundColor3 = Color3.fromRGB(60, 150, 90)
	Theme.capText(respawnButton, 17)
	local toMenuButton = Theme.button(gui, "Menu", UDim2.fromScale(0.505, 0.015), UDim2.fromScale(0.09, 0.05), function()
		Remotes.Action:FireServer("tomenu")
	end)
	Theme.capText(toMenuButton, 17)

	-- debug testing buttons (below the HUD panel); remove by setting
	-- Config.Debug = false - the server also refuses these when it's off
	if Config.Debug then
		local pctLabel = ("%d%%"):format(Config.DebugMassPercent)
		local addMass = Theme.button(gui, "+ " .. pctLabel, UDim2.fromScale(0.01, 0.24), UDim2.fromScale(0.075, 0.045), function()
			Remotes.Action:FireServer("debugmass", 1)
		end)
		addMass.BackgroundColor3 = Color3.fromRGB(55, 110, 70)
		Theme.capText(addMass, 16)
		local subMass = Theme.button(gui, "- " .. pctLabel, UDim2.fromScale(0.01, 0.29), UDim2.fromScale(0.075, 0.045), function()
			Remotes.Action:FireServer("debugmass", -1)
		end)
		subMass.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
		Theme.capText(subMass, 16)
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
	Minimap.update(dt)
end

return UI
