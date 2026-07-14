--[[
	Pause - the in-game control menu. A single "hamburger" button top-left opens
	a small popup with Resume / Respawn / Settings / Leave to menu, so those
	controls live off the play field instead of floating over it. Only shown while
	alive; the play menu handles everything else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Pause = {}

local hamb: TextButton
local popup: Frame

local function close()
	popup.Visible = false
end

function Pause.init(parent: Instance, settingsToggle: () -> ())
	hamb = Theme.button(parent, "\u{2630}", UDim2.fromScale(0.008, 0.058), UDim2.fromScale(0.04, 0.045), function()
		popup.Visible = not popup.Visible
	end)
	hamb.Visible = false
	Theme.capText(hamb, 20)

	popup = Theme.panel(parent, UDim2.fromScale(0.008, 0.11), UDim2.fromScale(0.16, 0.26))
	popup.Visible = false
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.06, 0)
	pad.PaddingBottom = UDim.new(0.06, 0)
	pad.PaddingLeft = UDim.new(0.07, 0)
	pad.PaddingRight = UDim.new(0.07, 0)
	pad.Parent = popup
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0.05, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = popup

	local function item(order: number, text: string, color: Color3?, onClick: () -> ())
		local b
		if color then
			b = Theme.outlineButton(popup, text, UDim2.new(), UDim2.fromScale(1, 0.21), color, onClick)
		else
			b = Theme.button(popup, text, UDim2.new(), UDim2.fromScale(1, 0.21), onClick)
		end
		b.LayoutOrder = order
		Theme.capText(b, 16)
	end

	item(1, "Resume", Theme.AccentColor, close)
	item(2, "Respawn", Theme.Green, function()
		Remotes.Action:FireServer("respawn")
		close()
	end)
	item(3, "Settings", nil, function()
		settingsToggle()
		close()
	end)
	item(4, "Leave to menu", Theme.Danger, function()
		Remotes.Action:FireServer("tomenu")
		close()
	end)
end

function Pause.update(_dt: number)
	-- available while playing AND while spectating (in spectate it's the only way
	-- back to the menu / into the game)
	local show = WorldState.status == "alive" or WorldState.status == "spectate"
	if hamb.Visible ~= show then
		hamb.Visible = show
	end
	if not show and popup.Visible then
		popup.Visible = false
	end
end

return Pause
