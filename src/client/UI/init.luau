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
local Input = require(script.Parent.Input)
local WorldState = require(script.Parent.WorldState)

local UI = {}
UI.HUD = HUD
UI.Menu = Menu
UI.Settings = Settings
UI.Shop = Shop

-- The Shop (left of the card) and Hiscores (right) are open whenever the menu is
-- up, and closed while playing/spectating - no buttons.
local function syncMenuPanels()
	local inMenu = WorldState.status == "menu" or WorldState.status == "dead"
	Shop.setOpen(inMenu)
	Hiscores.setOpen(inMenu)
end

function UI.init(playerGui: PlayerGui)
	local gui = Instance.new("ScreenGui")
	gui.Name = "AgarUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	Menu.init(gui, Settings.toggle) -- overlay + card (drawn under the HUD)
	HUD.init(gui)
	Minimap.init(gui)
	AbilityDock.init(gui)
	Pause.init(gui, Settings.toggle) -- ☰ top-left -> Resume / Respawn / Settings / Leave
	Settings.init(gui)
	Hiscores.init(gui) -- right of the card, open in the menu
	Shop.init(gui) -- left of the card, open in the menu

	Input.onMenuToggle = Settings.toggle -- the M keybind mirrors the settings panel

	WorldState.onPlayerState = function(_event)
		Menu.refresh()
		syncMenuPanels()
	end

	gui.Parent = playerGui
	syncMenuPanels() -- start in the menu with both panels open
end

function UI.update(dt: number)
	HUD.update(dt)
	AbilityDock.update(dt)
	Pause.update(dt)
	Menu.update(dt)
	Minimap.update(dt)
	Hiscores.update(dt)
	-- keep the menu panels tracking status even for transitions that don't fire
	-- onPlayerState (e.g. the Spectate button sets status directly); setOpen
	-- early-returns when already in the right state, so this is ~free
	syncMenuPanels()
end

return UI
