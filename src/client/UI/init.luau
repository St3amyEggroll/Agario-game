--[[
	UI - assembles the interface (minimal look):
	  top-left   = stats bar (Lv/XP, Mass, Coins, FPS/Ping/Cells) + ☰ pause
	  center     = play card (menu); Shop pops in to its LEFT, Hiscores to its RIGHT
	  bottom-center = ability dock (in-game)
	  bottom-right  = minimap
	Roblox's native player list (leaderboard) and chat are left on.
	World rendering lives in a separate, lower ScreenGui (Renderer).
]]

local HUD = require(script.HUD)
local Menu = require(script.Menu)
local Settings = require(script.Settings)
local Shop = require(script.Shop)
local AbilityDock = require(script.AbilityDock)
local Pause = require(script.Pause)
local Minimap = require(script.Minimap)
local Hiscores = require(script.Hiscores)
local Spectate = require(script.Spectate)
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

	Menu.init(gui, Shop.toggle, Settings.toggle, Hiscores.toggle) -- overlay + card
	HUD.init(gui)
	Minimap.init(gui)
	AbilityDock.init(gui)
	Pause.init(gui, Settings.toggle, Shop.toggle, Hiscores.toggle) -- ☰ full in-game menu
	Hiscores.init(gui) -- pops in right of the card
	Shop.init(gui) -- pops in left of the card
	Spectate.init(gui) -- top-center Prev/Next/Play bar while spectating
	Settings.init(gui) -- last, so the settings modal draws over the side panels

	Input.onMenuToggle = Settings.toggle -- the M keybind mirrors the settings panel

	WorldState.onPlayerState = function(event)
		Menu.refresh()
		if event == "spawned" then
			-- spawn clean; the pop-ups are reachable in-game via the ☰ pause menu
			Shop.close()
			Hiscores.close()
		end
	end

	gui.Parent = playerGui
end

function UI.update(dt: number)
	HUD.update(dt)
	AbilityDock.update(dt)
	Pause.update(dt)
	Menu.update(dt)
	Minimap.update(dt)
	Hiscores.update(dt)
	Spectate.update(dt)
	Shop.update(dt)
end

return UI
