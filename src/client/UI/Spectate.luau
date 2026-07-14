--[[
	Spectate - the top-center control bar shown only while spectating. Prev / Next
	cycle the watched player (WorldState.cycleSpectate); Play drops you into the
	game. The camera follows WorldState.watchedSlot() (Camera.luau).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Spectate = {}

local bar: Frame
local nameLabel: TextLabel
local lastName = ""

function Spectate.init(parent: Instance)
	bar = Theme.panel(parent, UDim2.fromScale(0.5, 0.065), UDim2.fromScale(0.36, 0.055), Vector2.new(0.5, 0))
	bar.Visible = false

	local prev = Theme.button(bar, "\u{25C0}", UDim2.fromScale(0.02, 0.15), UDim2.fromScale(0.1, 0.7), function()
		WorldState.cycleSpectate(-1)
	end)
	Theme.capText(prev, 16)

	nameLabel = Theme.mono(bar, "Watching...", UDim2.fromScale(0.14, 0.15), UDim2.fromScale(0.44, 0.7))
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	Theme.capText(nameLabel, 15)

	local next_ = Theme.button(bar, "\u{25B6}", UDim2.fromScale(0.6, 0.15), UDim2.fromScale(0.1, 0.7), function()
		WorldState.cycleSpectate(1)
	end)
	Theme.capText(next_, 16)

	local play = Theme.outlineButton(bar, "Play", UDim2.fromScale(0.73, 0.15), UDim2.fromScale(0.25, 0.7), Theme.Green, function()
		Remotes.Action:FireServer("play")
	end)
	Theme.capText(play, 16)
end

function Spectate.update(_dt: number)
	local on = WorldState.status == "spectate"
	if bar.Visible ~= on then
		bar.Visible = on
	end
	if not on then
		return
	end
	local slot = WorldState.watchedSlot()
	local name = slot and ("Watching: " .. WorldState.nameForSlot(slot)) or "No players to watch"
	if name ~= lastName then
		lastName = name
		nameLabel.Text = name
	end
end

return Spectate
