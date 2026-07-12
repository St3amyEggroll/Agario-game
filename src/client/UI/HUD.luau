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

local smoothedDt = 1 / 60
local pingMs = -1
local lastMassText, lastPingText, lastFpsText = "", "", ""
local uiAccumulator = 0

function HUD.init(parent: Instance)
	local panel = Theme.panel(parent, UDim2.fromScale(0.01, 0.075), UDim2.fromScale(0.11, 0.115))
	massLabel = Theme.label(panel, "Mass: 0", UDim2.fromScale(0.06, 0.04), UDim2.fromScale(0.88, 0.28))
	pingLabel = Theme.label(panel, "Ping: --", UDim2.fromScale(0.06, 0.36), UDim2.fromScale(0.88, 0.28))
	fpsLabel = Theme.label(panel, "FPS: --", UDim2.fromScale(0.06, 0.68), UDim2.fromScale(0.88, 0.28))
	for _, l in { massLabel, pingLabel, fpsLabel } do
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
