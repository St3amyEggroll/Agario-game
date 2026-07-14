--[[
	Leaderboard - custom top-right top-10 panel (replaces the Roblox player list).
	Reads WorldState.leaderboard (server sends the sorted top entries ~1 Hz as
	{s = slot, n = name, m = mass}). Your own row is highlighted. Shown always
	(menu + in-game), like Agma.
]]

local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Leaderboard = {}

local ROWS = 10
local rows = {}
local acc = 0

local function commaMass(m: number): string
	local s = tostring(m)
	local out, n = s:reverse():gsub("(%d%d%d)", "%1,")
	out = out:reverse()
	return (out:gsub("^,", ""))
end

function Leaderboard.init(parent: Instance)
	local panel = Theme.panel(parent, UDim2.fromScale(0.988, 0.02), UDim2.fromScale(0.155, 0.44), Vector2.new(1, 0))

	local title = Theme.label(panel, "Leaderboard", UDim2.fromScale(0.08, 0.02), UDim2.fromScale(0.84, 0.08))
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 18)

	for i = 1, ROWS do
		local y = 0.12 + (i - 1) * 0.084
		local rank = Theme.mono(panel, tostring(i) .. ".", UDim2.fromScale(0.06, y), UDim2.fromScale(0.14, 0.075))
		rank.TextColor3 = Theme.MutedText
		rank.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(rank, 13)
		local name = Theme.label(panel, "-", UDim2.fromScale(0.21, y), UDim2.fromScale(0.5, 0.075))
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		Theme.capText(name, 13)
		local mass = Theme.mono(panel, "", UDim2.fromScale(0.62, y), UDim2.fromScale(0.33, 0.075))
		mass.TextColor3 = Theme.MutedText
		mass.TextXAlignment = Enum.TextXAlignment.Right
		Theme.capText(mass, 12)
		rows[i] = { rank = rank, name = name, mass = mass }
	end
end

function Leaderboard.update(dt: number)
	acc += dt
	if acc < 0.4 then
		return
	end
	acc = 0

	local board = WorldState.leaderboard or {}
	local mySlot = WorldState.mySlot
	for i = 1, ROWS do
		local row = rows[i]
		local entry = board[i]
		if entry then
			local mine = entry.s == mySlot
			row.name.Text = entry.n or "?"
			row.mass.Text = commaMass(entry.m or 0)
			local col = mine and Theme.AccentColor or Theme.TextColor
			row.name.TextColor3 = col
			row.rank.TextColor3 = mine and Theme.AccentColor or Theme.MutedText
			row.mass.TextColor3 = mine and Theme.AccentColor or Theme.MutedText
		else
			row.name.Text = "-"
			row.mass.Text = ""
			row.name.TextColor3 = Theme.MutedText
		end
	end
end

return Leaderboard
