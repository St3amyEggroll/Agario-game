--[[
	HUD (minimal / classic-agar layout):
	  - MASS: a big mono number floating bottom-left (no card, just a text stroke
	    so it reads over any cell), with a small "MASS" caption above it.
	  - Ping / FPS / Coins: tiny mono lines tucked top-left, under the menu row.
	  - Level bar: a thin XP bar floating bottom-center.

	FPS is an exponential moving average of frame time; ping is set by the
	round-trip loop in the client bootstrap.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(script.Parent.Theme)
local LevelCurve = require(Shared.Levels)
local WorldState = require(script.Parent.Parent.WorldState)

local HUD = {}

local massLabel: TextLabel
local pingLabel: TextLabel
local fpsLabel: TextLabel
local coinLabel: TextLabel

local levelBar: Frame
local levelBadge: TextLabel
local xpFill: Frame
local xpText: TextLabel

local smoothedDt = 1 / 60
local pingMs = -1
local lastMassText, lastPingText, lastFpsText, lastCoinText = "", "", "", ""
local lastLevelText, lastXpText, lastFill = "", "", -1
local uiAccumulator = 0

-- one tiny top-left stat line ("PING 42ms"): muted caption + mono value, floating
local function statLine(parent: Instance, y: number, caption: string, valueColor: Color3): TextLabel
	local cap = Theme.caption(parent, caption, UDim2.fromScale(0, y), UDim2.fromScale(0.5, 0.3))
	cap.TextXAlignment = Enum.TextXAlignment.Left
	cap.TextStrokeColor3 = Color3.new(0, 0, 0)
	cap.TextStrokeTransparency = 0.5
	Theme.capText(cap, 12)

	local val = Theme.readout(parent, "--", UDim2.fromScale(0.5, y), UDim2.fromScale(0.5, 0.3))
	val.TextColor3 = valueColor
	val.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(val, 13)
	return val
end

function HUD.init(parent: Instance)
	-- tiny stat block, top-left (sits below the menu-button row placed by UI.init)
	local stats = Instance.new("Frame")
	stats.Position = UDim2.fromScale(0.012, 0.075)
	stats.Size = UDim2.fromScale(0.13, 0.11)
	stats.BackgroundTransparency = 1
	stats.Parent = parent
	pingLabel = statLine(stats, 0.02, "Ping", Theme.TextColor)
	fpsLabel = statLine(stats, 0.36, "FPS", Theme.TextColor)
	coinLabel = statLine(stats, 0.70, "Coins", Theme.Gold)

	-- MASS: big floating readout, bottom-left
	local massBox = Instance.new("Frame")
	massBox.AnchorPoint = Vector2.new(0, 1)
	massBox.Position = UDim2.fromScale(0.014, 0.965)
	massBox.Size = UDim2.fromScale(0.26, 0.13)
	massBox.BackgroundTransparency = 1
	massBox.Parent = parent
	local massCap = Theme.caption(massBox, "Mass", UDim2.fromScale(0.01, 0), UDim2.fromScale(0.6, 0.26))
	massCap.TextXAlignment = Enum.TextXAlignment.Left
	massCap.TextStrokeColor3 = Color3.new(0, 0, 0)
	massCap.TextStrokeTransparency = 0.5
	Theme.capText(massCap, 14)
	massLabel = Theme.readout(massBox, "0", UDim2.fromScale(0, 0.26), UDim2.fromScale(1, 0.74))
	massLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(massLabel, 44)

	HUD.initLevelBar(parent)
end

-- thin XP bar, bottom-center: "Lv N" + a progress track (fraction from raw XP
-- via the shared curve, so it matches the server with no extra networking).
function HUD.initLevelBar(parent: Instance)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.fromScale(0.5, 0.985)
	bar.Size = UDim2.fromScale(0.3, 0.035)
	bar.BackgroundTransparency = 1
	bar.Parent = parent
	levelBar = bar

	levelBadge = Theme.readout(bar, "Lv 1", UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1))
	levelBadge.TextColor3 = Theme.AccentColor
	levelBadge.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(levelBadge, 16)

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.fromScale(0.19, 0.5)
	track.Size = UDim2.fromScale(0.81, 0.5)
	track.BackgroundColor3 = Theme.Field
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	Theme.round(track, 6)
	Theme.stroke(track)
	track.Parent = bar

	xpFill = Instance.new("Frame")
	xpFill.Position = UDim2.fromScale(0, 0)
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Theme.AccentColor
	xpFill.BorderSizePixel = 0
	Theme.round(xpFill, 6)
	xpFill.Parent = track

	xpText = Theme.mono(track, "0 / 0", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	xpText.ZIndex = 2
	xpText.TextStrokeColor3 = Color3.new(0, 0, 0)
	xpText.TextStrokeTransparency = 0.4
	Theme.capText(xpText, 12)
end

function HUD.setPing(ms: number)
	pingMs = ms
end

function HUD.update(dt: number)
	smoothedDt += (dt - smoothedDt) * 0.05

	uiAccumulator += dt
	if uiAccumulator < 0.2 then
		return
	end
	uiAccumulator = 0

	local massText = tostring(math.floor(WorldState.own.mass + 0.5))
	if massText ~= lastMassText then
		lastMassText = massText
		massLabel.Text = massText
	end
	local coinText = tostring(WorldState.coins or 0)
	if coinText ~= lastCoinText then
		lastCoinText = coinText
		coinLabel.Text = coinText
	end
	local pingText = pingMs >= 0 and (math.floor(pingMs + 0.5) .. "ms") or "--"
	if pingText ~= lastPingText then
		lastPingText = pingText
		pingLabel.Text = pingText
	end
	local fpsText = tostring(math.floor(1 / smoothedDt + 0.5))
	if fpsText ~= lastFpsText then
		lastFpsText = fpsText
		fpsLabel.Text = fpsText
	end

	-- level bar: shown only while actually playing (in menu/spectate the bottom
	-- menu bar occupies the same lane)
	local showBar = WorldState.status == "alive"
	if levelBar.Visible ~= showBar then
		levelBar.Visible = showBar
	end
	if not showBar then
		return
	end

	local level, into, need = LevelCurve.progress(WorldState.xp or 0)
	local levelText = "Lv " .. level
	if levelText ~= lastLevelText then
		lastLevelText = levelText
		levelBadge.Text = levelText
	end
	local fill = need > 0 and math.clamp(into / need, 0, 1) or 1
	if math.abs(fill - lastFill) > 0.005 then
		lastFill = fill
		xpFill.Size = UDim2.fromScale(fill, 1)
	end
	local xpStr = math.floor(into) .. " / " .. need
	if xpStr ~= lastXpText then
		lastXpText = xpStr
		xpText.Text = xpStr
	end
end

return HUD
