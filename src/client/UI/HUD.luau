--[[
	HUD - top-left stat block + bottom-center level bar.

	Hierarchy (the overhaul): MASS is the hero readout (big mono number); Ping,
	FPS and Coins drop to small mono chips beneath it, so the number you care
	about while playing dominates and the diagnostics stay glanceable. FPS is an
	exponential moving average of frame time; ping is set by the round-trip loop
	in the client bootstrap.
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

local smoothedDt = 1 / 60
local pingMs = -1
local lastMassText, lastPingText, lastFpsText, lastCoinText = "", "", "", ""
local lastLevelText, lastXpText, lastFill = "", "", -1
local uiAccumulator = 0

-- one small stat chip: an uppercase caption over a mono value. Returns the value
-- label so the update loop can write to it.
local function makeChip(parent: Instance, x: number, w: number, caption: string, valueColor: Color3): TextLabel
	local chip = Instance.new("Frame")
	chip.Position = UDim2.fromScale(x, 0.6)
	chip.Size = UDim2.fromScale(w, 0.34)
	chip.BackgroundColor3 = Theme.Panel2Color
	chip.BackgroundTransparency = 0.15
	chip.BorderSizePixel = 0
	Theme.round(chip, 8)
	chip.Parent = parent

	local cap = Theme.caption(chip, caption, UDim2.fromScale(0.12, 0.14), UDim2.fromScale(0.76, 0.34))
	cap.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(cap, 11)

	local val = Theme.mono(chip, "--", UDim2.fromScale(0.12, 0.48), UDim2.fromScale(0.76, 0.4))
	val.TextColor3 = valueColor
	val.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(val, 16)
	return val
end

function HUD.init(parent: Instance)
	local panel = Theme.panel(parent, UDim2.fromScale(0.01, 0.075), UDim2.fromScale(0.16, 0.155))

	local cap = Theme.caption(panel, "Mass", UDim2.fromScale(0.06, 0.07), UDim2.fromScale(0.6, 0.16))
	cap.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(cap, 13)

	massLabel = Theme.mono(panel, "0", UDim2.fromScale(0.055, 0.2), UDim2.fromScale(0.9, 0.34))
	massLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(massLabel, 34)

	pingLabel = makeChip(panel, 0.05, 0.29, "Ping", Theme.TextColor)
	fpsLabel = makeChip(panel, 0.355, 0.29, "FPS", Theme.TextColor)
	coinLabel = makeChip(panel, 0.66, 0.29, "Coins", Theme.Gold)

	HUD.initLevelBar(parent)
end

-- XP / level bar, bottom-center: a "Lv N" badge + a progress track whose fill
-- width is the fraction into the current level (derived from raw XP via the
-- shared level curve, so it matches the server with no extra networking).
function HUD.initLevelBar(parent: Instance)
	local bar = Theme.panel(parent, UDim2.fromScale(0.5, 0.955), UDim2.fromScale(0.28, 0.045), Vector2.new(0.5, 0.5))
	levelBar = bar

	levelBadge = Theme.mono(bar, "Lv 1", UDim2.fromScale(0.03, 0.2), UDim2.fromScale(0.16, 0.6))
	levelBadge.TextColor3 = Theme.AccentColor
	levelBadge.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(levelBadge, 18)

	local track = Instance.new("Frame")
	track.Position = UDim2.fromScale(0.21, 0.28)
	track.Size = UDim2.fromScale(0.76, 0.44)
	track.BackgroundColor3 = Theme.Field
	track.BorderSizePixel = 0
	Theme.round(track, 6)
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
	Theme.capText(xpText, 13)
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
