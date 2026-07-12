--[[
	HUD - live Mass / Ping / FPS readout (top-left, under the menu button).
	FPS is an exponential moving average of frame time; ping is set by the
	round-trip loop in the client bootstrap.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local _ = Shared -- (kept for symmetry with other modules)

local HUD = {}

local massLabel: TextLabel
local pingLabel: TextLabel
local fpsLabel: TextLabel
local coinLabel: TextLabel

local smoothedDt = 1 / 60
local pingMs = -1
local lastMassText, lastPingText, lastFpsText, lastCoinText = "", "", "", ""
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
end

return HUD
