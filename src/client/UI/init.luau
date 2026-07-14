--[[
	UI - assembles the interface (minimal look):
	  top-left   = stats bar (Lv/XP, Mass, Coins, FPS/Ping/Cells) + ☰ pause
	  center     = play card (menu); Shop pops in to its LEFT, Hiscores to its RIGHT
	  bottom-center = ability dock (in-game)
	  bottom-right  = minimap
	Roblox's native player list (leaderboard) and chat are left on.
	World rendering lives in a separate, lower ScreenGui (Renderer).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Shared").Remotes)
local LevelCurve = require(ReplicatedStorage.Shared.Levels)

local HUD = require(script.HUD)
local Menu = require(script.Menu)
local Settings = require(script.Settings)
local Shop = require(script.Shop)
local AbilityDock = require(script.AbilityDock)
local Pause = require(script.Pause)
local Minimap = require(script.Minimap)
local Hiscores = require(script.Hiscores)
local Spectate = require(script.Spectate)
local Notifications = require(script.Notifications)
local Input = require(script.Parent.Input)
local WorldState = require(script.Parent.WorldState)
local Sounds = require(script.Parent.Sounds)
local Theme = require(script.Theme)

local UI = {}
UI.HUD = HUD
UI.Menu = Menu
UI.Settings = Settings
UI.Shop = Shop

function UI.init(playerGui: PlayerGui)
	Sounds.init() -- build the reusable SFX (click, equip, ...) before any button exists

	local gui = Instance.new("ScreenGui")
	gui.Name = "AgarUI"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- The three side panels (Shop left, Hiscores + Settings right) are mutually
	-- exclusive: opening one closes the others so they never overlap or cover the
	-- play card. Each wrapper closes the OTHER two, then toggles itself.
	local function shopToggle()
		Settings.setVisible(false)
		Hiscores.close()
		Shop.toggle()
	end
	local function hiscoresToggle()
		Settings.setVisible(false)
		Shop.close()
		Hiscores.toggle()
	end
	local function settingsToggle()
		Shop.close()
		Hiscores.close()
		Settings.toggle()
	end

	Menu.init(gui, shopToggle, settingsToggle, hiscoresToggle) -- overlay + card
	HUD.init(gui)
	Minimap.init(gui)
	AbilityDock.init(gui)
	Pause.init(gui, settingsToggle, shopToggle, hiscoresToggle) -- ☰ full in-game menu
	Hiscores.init(gui) -- pops in right of the card
	Shop.init(gui) -- pops in left of the card
	Spectate.init(gui) -- top-center Prev/Next/Play bar while spectating
	Settings.init(gui) -- also right side; exclusivity keeps it from overlapping Hiscores
	Notifications.init(gui) -- top-center toasts (level-ups, kills)

	Input.onMenuToggle = settingsToggle -- the M keybind mirrors the settings panel

	WorldState.onPlayerState = function(event)
		Menu.refresh()
		if event == "spawned" then
			-- spawn clean; the pop-ups are reachable in-game via the ☰ pause menu
			Shop.close()
			Hiscores.close()
		end
	end

	-- server SFX/notification cues: a kill (with the victim's name) or a merge
	local lastMergeSound = 0
	Remotes.Feedback.OnClientEvent:Connect(function(kind, arg)
		if kind == "kill" then
			Sounds.play("kill")
			Notifications.show("You killed " .. tostring(arg), Theme.Danger)
		elseif kind == "merge" then
			-- a big stack recombines over several ticks; throttle so it's one cue
			local t = os.clock()
			if t - lastMergeSound > 0.15 then
				lastMergeSound = t
				Sounds.play("merge")
			end
		end
	end)

	-- level-up: the FIRST XP sync (your saved total on join) just sets the
	-- baseline; any later sync that raises your level plays the SFX + a toast.
	local lastLevel = nil
	Remotes.Level.OnClientEvent:Connect(function(xp)
		if typeof(xp) ~= "number" then
			return
		end
		local level = LevelCurve.levelForXp(xp)
		if lastLevel and level > lastLevel then
			Sounds.play("levelup")
			Notifications.show("Level Up!   Lv " .. level, Theme.AccentColor)
		end
		lastLevel = level
	end)

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
