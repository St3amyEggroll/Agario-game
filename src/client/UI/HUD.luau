--[[
	HUD - live Mass / Ping / FPS readout (top-left, under the menu button).
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

-- level bar (bottom-center)
local levelBar: Frame
local levelBadge: TextLabel
local xpFill: Frame
local xpText: TextLabel

local XP_COLOR = Color3.fromRGB(95, 205, 255)

local smoothedDt = 1 / 60
local pingMs = -1
local lastMassText, lastPingText, lastFpsText, lastCoinText = "", "", "", ""
local lastLevelText, lastXpText, lastFill = "", "", -1
local uiAccumulator = 0

function HUD.init(parent: Instance)
	local panel = Theme.panel(parent, UDim2.fromScale(0.01, 0.075), UDim2.fromScale(0.12, 0.15))
	massLabel = Theme.label(panel, "Mass: 0", UDim2.fromScale(0.06, 0.03), UDim2.fromScale(0.88, 0.2))
	coinLabel = Theme.label(panel, "Coins: 0", UDim2.fromScale(0.06, 0.27), UDim2.fromScale(0.88, 0.2))
	coinLabel.TextColor3 = Color3.fromRGB(255, 205, 55)
	pingLabel = Theme.label(panel, "Ping: --", UDim2.fromScale(0.06, 0.51), UDim2.fromScale(0.88, 0.2))
	fpsLabel = Theme.label(panel, "FPS: --", UDim2.fromScale(0.06, 0.75), UDim2.fromScale(0.88, 0.2))
	for _, l in { massLabel, coinLabel, pingLabel, fpsLabel } do
		l.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(l, 18)
	end

	HUD.initLevelBar(parent)
end

-- XP / level bar, bottom-center: a "Lv N" badge + a progress track whose fill
-- width is the fraction into the current level (derived from raw XP via the
-- shared level curve, so it matches the server with no extra networking).
function HUD.initLevelBar(parent: Instance)
	local bar = Theme.panel(parent, UDim2.fromScale(0.5, 0.955), UDim2.fromScale(0.26, 0.045), Vector2.new(0.5, 0.5))
	levelBar = bar

	levelBadge = Theme.label(bar, "Lv 1", UDim2.fromScale(0.02, 0.15), UDim2.fromScale(0.17, 0.7))
	levelBadge.TextColor3 = XP_COLOR
	levelBadge.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(levelBadge, 20)

	local track = Instance.new("Frame")
	track.Position = UDim2.fromScale(0.21, 0.28)
	track.Size = UDim2.fromScale(0.76, 0.44)
	track.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
	track.BorderSizePixel = 0
	Theme.round(track, 6)
	track.Parent = bar

	xpFill = Instance.new("Frame")
	xpFill.Position = UDim2.fromScale(0, 0)
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = XP_COLOR
	xpFill.BorderSizePixel = 0
	Theme.round(xpFill, 6)
	xpFill.Parent = track

	xpText = Theme.label(track, "0 / 0", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
	xpText.ZIndex = 2
	Theme.capText(xpText, 14)
end

function HUD.setPing(ms: number)
	pingMs = ms
end

function HUD.update(dt: number)
	smoothedDt += (dt - smoothedDt) * 0.05

	-- refresh the text a few times a second; writing TextLabel.Text at 60 Hz
	-- forces pointless re-layout
	uiAccumulator += dt
	if uiAccumulator < 0.2 then
		return
	end
	uiAccumulator = 0

	local massText = "Mass: " .. math.floor(WorldState.own.mass + 0.5)
	if massText ~= lastMassText then
		lastMassText = massText
		massLabel.Text = massText
	end
	local coinText = "Coins: " .. (WorldState.coins or 0)
	if coinText ~= lastCoinText then
		lastCoinText = coinText
		coinLabel.Text = coinText
	end
	local pingText = pingMs >= 0 and ("Ping: " .. math.floor(pingMs + 0.5) .. " ms") or "Ping: --"
	if pingText ~= lastPingText then
		lastPingText = pingText
		pingLabel.Text = pingText
	end
	local fpsText = "FPS: " .. math.floor(1 / smoothedDt + 0.5)
	if fpsText ~= lastFpsText then
		lastFpsText = fpsText
		fpsLabel.Text = fpsText
	end

	-- level bar: hidden behind the play menu (it overlaps the bottom bar there),
	-- shown while playing or spectating
	local status = WorldState.status
	local showBar = status == "alive" or status == "spectate"
	if levelBar.Visible ~= showBar then
		levelBar.Visible = showBar
	end
	if not showBar then
		return
	end

	-- derive level + progress from raw XP (shared curve)
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
