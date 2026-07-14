--[[
	Hiscores - a right-side pop-up panel (Agma-style) showing your stats (Level,
	Coins) and the top players across three boards: Mass, Playtime and Kills
	(sub-tabs). Each board prefers the persisted ALL-TIME records the server
	broadcasts, and falls back to the LIVE players (sorted by the same metric) when
	there are no records yet (fresh universe / Studio without API access), so the
	panel is never blank. Toggled from the play card; pops in with a bounce.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelCurve = require(Shared.Levels)
local Util = require(Shared.Util)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Hiscores = {}

local ROWS = 10
-- metric key on each entry -> tab label + how to format the value column
local METRICS = {
	{ key = "m", label = "Mass" },
	{ key = "p", label = "Playtime" },
	{ key = "k", label = "Kills" },
}

local panel: Frame
local statLine: TextLabel
local hdr: TextLabel
local rows = {}
local tabButtons = {}
local currentMetric = "m"
local acc = 0

-- seconds -> "1h 23m" / "12m 30s" / "45s"
local function fmtTime(sec: number): string
	sec = math.floor(sec)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then
		return string.format("%dh %dm", h, m)
	elseif m > 0 then
		return string.format("%dm %ds", m, s)
	end
	return string.format("%ds", s)
end

local function fmtValue(entry): string
	if currentMetric == "p" then
		return fmtTime(entry.p or 0)
	elseif currentMetric == "k" then
		return tostring(math.floor(entry.k or 0))
	end
	return Util.abbrevMass(entry.m or 0)
end

local function selectMetric(key: string)
	currentMetric = key
	for _, t in tabButtons do
		local active = t.key == key
		t.btn.TextColor3 = active and Theme.AccentColor or Theme.MutedText
		t.btn.BackgroundTransparency = active and 0.15 or 0.55
	end
	Hiscores.refresh()
end

function Hiscores.init(parent: Instance)
	-- sits just RIGHT of the center play card (its left edge ~0.64), pops in
	panel = Theme.panel(parent, UDim2.fromScale(0.64, 0.54), UDim2.fromScale(0.3, 0.56), Vector2.new(0, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Hiscores", UDim2.fromScale(0.06, 0.02), UDim2.fromScale(0.7, 0.06))
	title.TextColor3 = Theme.AccentColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 22)

	Theme.closeButton(panel, UDim2.fromScale(0.88, 0.02), UDim2.fromScale(0.09, 0.05), function()
		panel.Visible = false
	end)

	-- your stats
	statLine = Theme.mono(panel, "Lv 1   -   0 Gold", UDim2.fromScale(0.06, 0.095), UDim2.fromScale(0.88, 0.045))
	statLine.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(statLine, 14)

	-- Mass | Playtime | Kills sub-tabs
	for i, m in METRICS do
		local x = 0.06 + (i - 1) * 0.305
		local btn = Theme.button(panel, m.label, UDim2.fromScale(x, 0.15), UDim2.fromScale(0.29, 0.05), function()
			selectMetric(m.key)
		end)
		Theme.capText(btn, 13)
		tabButtons[i] = { key = m.key, btn = btn }
	end

	hdr = Theme.caption(panel, "All-time records", UDim2.fromScale(0.06, 0.215), UDim2.fromScale(0.88, 0.035))
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(hdr, 11)

	for i = 1, ROWS do
		local y = 0.26 + (i - 1) * 0.068
		local rank = Theme.mono(panel, i .. ".", UDim2.fromScale(0.06, y), UDim2.fromScale(0.12, 0.06))
		rank.TextColor3 = Theme.MutedText
		rank.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(rank, 13)
		local name = Theme.label(panel, "-", UDim2.fromScale(0.2, y), UDim2.fromScale(0.48, 0.06))
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		Theme.capText(name, 13)
		local value = Theme.mono(panel, "", UDim2.fromScale(0.58, y), UDim2.fromScale(0.36, 0.06))
		value.TextColor3 = Theme.MutedText
		value.TextXAlignment = Enum.TextXAlignment.Right
		Theme.capText(value, 12)
		rows[i] = { rank = rank, name = name, value = value }
	end

	selectMetric("m")
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
	statLine.Text = ("Lv %d   -   %s Gold"):format(level, Util.abbrevMass(WorldState.coins or 0))

	-- Prefer the persisted ALL-TIME records; fall back to the LIVE players when
	-- there are none yet. Sort the chosen board by the selected metric (records
	-- arrive unsorted for a given metric; the live board is mass-sorted).
	local source = WorldState.records or {}
	if #source == 0 then
		source = WorldState.leaderboard or {}
		hdr.Text = string.upper("Top players now")
	else
		hdr.Text = string.upper("All-time records")
	end
	local board = table.clone(source)
	local metric = currentMetric
	table.sort(board, function(a, b)
		return (a[metric] or 0) > (b[metric] or 0)
	end)

	local myEntry = WorldState.roster[WorldState.mySlot or -1]
	local myName = myEntry and myEntry.n
	for i = 1, ROWS do
		local row = rows[i]
		local entry = board[i]
		if entry then
			local mine = myName ~= nil and entry.n == myName
			row.name.Text = entry.n or "?"
			row.value.Text = fmtValue(entry)
			row.name.TextColor3 = mine and Theme.AccentColor or Theme.TextColor
			row.rank.TextColor3 = mine and Theme.AccentColor or Theme.MutedText
			row.value.TextColor3 = mine and Theme.AccentColor or Theme.MutedText
		else
			row.name.Text = "-"
			row.value.Text = ""
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
