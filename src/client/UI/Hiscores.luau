--[[
	Hiscores - a right-side pop-up panel (Agma-style) showing your stats (Level,
	Coins) and the current top-10 players by mass, from the leaderboard the server
	already broadcasts. Toggled from the play card; pops in with a bounce.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCurve = require(Shared.Levels)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Hiscores = {}

local ROWS = 10
local panel: Frame
local statLine: TextLabel
local rows = {}
local acc = 0

local function commaMass(m: number): string
	local out = tostring(m):reverse():gsub("(%d%d%d)", "%1,")
	return (out:reverse():gsub("^,", ""))
end

function Hiscores.init(parent: Instance)
	-- sits just RIGHT of the center play card (its left edge ~0.64), pops in
	panel = Theme.panel(parent, UDim2.fromScale(0.64, 0.54), UDim2.fromScale(0.3, 0.56), Vector2.new(0, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Hiscores", UDim2.fromScale(0.06, 0.02), UDim2.fromScale(0.7, 0.06))
	title.TextColor3 = Theme.AccentColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 22)

	local closeBtn = Theme.button(panel, "\u{2715}", UDim2.fromScale(0.88, 0.02), UDim2.fromScale(0.09, 0.05), function()
		panel.Visible = false
	end)
	Theme.capText(closeBtn, 16)

	-- your stats
	statLine = Theme.mono(panel, "Lv 1   -   0 coins", UDim2.fromScale(0.06, 0.09), UDim2.fromScale(0.88, 0.05))
	statLine.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(statLine, 14)

	local hdr = Theme.caption(panel, "Top players", UDim2.fromScale(0.06, 0.15), UDim2.fromScale(0.88, 0.04))
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(hdr, 11)

	for i = 1, ROWS do
		local y = 0.2 + (i - 1) * 0.075
		local rank = Theme.mono(panel, i .. ".", UDim2.fromScale(0.06, y), UDim2.fromScale(0.12, 0.065))
		rank.TextColor3 = Theme.MutedText
		rank.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(rank, 13)
		local name = Theme.label(panel, "-", UDim2.fromScale(0.2, y), UDim2.fromScale(0.5, 0.065))
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		Theme.capText(name, 13)
		local mass = Theme.mono(panel, "", UDim2.fromScale(0.6, y), UDim2.fromScale(0.34, 0.065))
		mass.TextColor3 = Theme.MutedText
		mass.TextXAlignment = Enum.TextXAlignment.Right
		Theme.capText(mass, 12)
		rows[i] = { rank = rank, name = name, mass = mass }
	end
end

function Hiscores.close()
	if panel.Visible then
		panel.Visible = false
	end
end

-- Opened from the play-card Scores button.
function Hiscores.toggle()
	if panel.Visible then
		panel.Visible = false
		return
	end
	panel.Visible = true
	Hiscores.refresh()
	Theme.popIn(panel)
end

function Hiscores.refresh()
	local level = LevelCurve.levelForXp(WorldState.xp or 0)
	statLine.Text = ("Lv %d   -   %d coins"):format(level, WorldState.coins or 0)

	local board = WorldState.leaderboard or {}
	local mySlot = WorldState.mySlot
	for i = 1, ROWS do
		local row = rows[i]
		local entry = board[i]
		if entry then
			local mine = entry.s == mySlot
			row.name.Text = entry.n or "?"
			row.mass.Text = commaMass(entry.m or 0)
			row.name.TextColor3 = mine and Theme.AccentColor or Theme.TextColor
			row.rank.TextColor3 = mine and Theme.AccentColor or Theme.MutedText
			row.mass.TextColor3 = mine and Theme.AccentColor or Theme.MutedText
		else
			row.name.Text = "-"
			row.mass.Text = ""
			row.name.TextColor3 = Theme.MutedText
		end
	end
end

function Hiscores.update(dt: number)
	if not panel.Visible then
		return
	end
	acc += dt
	if acc < 0.5 then
		return
	end
	acc = 0
	Hiscores.refresh()
end

return Hiscores
