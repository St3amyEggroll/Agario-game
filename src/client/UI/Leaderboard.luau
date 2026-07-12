--[[
	Leaderboard - top-right "PlayerName: Mass" list, updated at 1 Hz from the
	server broadcast. Rows are pre-built once; updates only rewrite Text.
]]

local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local ROWS = 10

local Leaderboard = {}

local rowLabels: { TextLabel } = {}

function Leaderboard.init(parent: Instance)
	local panel = Theme.panel(parent, UDim2.fromScale(0.99, 0.015), UDim2.fromScale(0.16, 0.32), Vector2.new(1, 0))
	local title = Theme.label(panel, "Leaderboard", UDim2.fromScale(0.05, 0.01), UDim2.fromScale(0.9, 0.11))
	title.TextColor3 = Theme.AccentColor
	Theme.capText(title, 20)
	for i = 1, ROWS do
		local row = Theme.label(
			panel,
			"",
			UDim2.fromScale(0.06, 0.12 + (i - 1) * 0.085),
			UDim2.fromScale(0.88, 0.075)
		)
		row.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(row, 16)
		rowLabels[i] = row
	end
end

function Leaderboard.update(entries)
	for i = 1, ROWS do
		local row = rowLabels[i]
		local entry = entries[i]
		if entry then
			row.Text = i .. ". " .. entry.n .. ": " .. entry.m
			-- highlight yourself
			row.TextColor3 = entry.s == WorldState.mySlot and Color3.fromRGB(245, 205, 70) or Theme.TextColor
		elseif row.Text ~= "" then
			row.Text = ""
		end
	end
end

return Leaderboard
