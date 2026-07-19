--[[
	HUD - bottom-left stats bar (minimal): Level + XP, Mass, Coins, and
	FPS / Ping / Cells, all in one bar. Shown always (the menu panels float over
	the dimmed game), so mass/cells read 0 while you're in the menu.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Theme = require(script.Parent.Theme)
local LevelCurve = require(Shared.Levels)
local WorldState = require(script.Parent.Parent.WorldState)

local HUD = {}

local statsBar: Frame
local lvLabel: TextLabel
local xpFill: Frame
local massLabel: TextLabel
local coinLabel: TextLabel
local goldTopLabel: TextLabel
local fpsLabel: TextLabel
local pingLabel: TextLabel
local cellsLabel: TextLabel

local smoothedDt = 1 / 60
local pingMs = -1
local last = {}
local uiAccumulator = 0

local function commas(n: number): string
	local out = tostring(math.floor(n + 0.5)):reverse():gsub("(%d%d%d)", "%1,")
	return (out:reverse():gsub("^,", ""))
end

local function divider(parent: Instance, x: number)
	local d = Instance.new("Frame")
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(x, 0.5)
	d.Size = UDim2.new(0, 1, 0.6, 0)
	d.BackgroundColor3 = Color3.new(1, 1, 1)
	d.BackgroundTransparency = 0.85
	d.BorderSizePixel = 0
	d.Parent = parent
end

function HUD.init(parent: Instance, onGoldClick: (() -> ())?)
	-- bottom-left stats bar (Level/XP, Mass, Coins, FPS/Ping/Cells)
	local bar = Theme.panel(parent, UDim2.fromScale(0.008, 0.985), UDim2.fromOffset(520, 50), Vector2.new(0, 1))
	statsBar = bar
	Theme.responsiveSize(bar, Vector2.new(520, 50), Vector2.new(12, 12))

	-- Level + XP
	lvLabel = Theme.mono(bar, "Lv 1", UDim2.fromScale(0.015, 0.14), UDim2.fromScale(0.11, 0.42))
	lvLabel.TextColor3 = Theme.AccentColor
	lvLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(lvLabel, 15)
	local xpTrack = Instance.new("Frame")
	xpTrack.Position = UDim2.fromScale(0.015, 0.64)
	xpTrack.Size = UDim2.fromScale(0.11, 0.2)
	xpTrack.BackgroundColor3 = Theme.Field
	xpTrack.BorderSizePixel = 0
	Theme.round(xpTrack, 4)
	xpTrack.Parent = bar
	xpFill = Instance.new("Frame")
	xpFill.Size = UDim2.fromScale(0, 1)
	xpFill.BackgroundColor3 = Theme.AccentColor
	xpFill.BorderSizePixel = 0
	Theme.round(xpFill, 4)
	xpFill.Parent = xpTrack
	divider(bar, 0.15)

	-- Mass (hero)
	local massCap = Theme.caption(bar, "Mass", UDim2.fromScale(0.17, 0.13), UDim2.fromScale(0.2, 0.28))
	massCap.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(massCap, 11)
	massLabel = Theme.mono(bar, "0", UDim2.fromScale(0.17, 0.4), UDim2.fromScale(0.22, 0.52))
	massLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(massLabel, 26)
	divider(bar, 0.41)

	-- Gold (the shop currency; earned from gold pickups)
	local coinCap = Theme.caption(bar, "Gold", UDim2.fromScale(0.43, 0.13), UDim2.fromScale(0.17, 0.28))
	coinCap.TextColor3 = Theme.Gold
	coinCap.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(coinCap, 11)
	coinLabel = Theme.mono(bar, "0", UDim2.fromScale(0.43, 0.4), UDim2.fromScale(0.17, 0.52))
	coinLabel.TextColor3 = Theme.Gold
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(coinLabel, 22)
	divider(bar, 0.62)

	-- FPS / Ping / Cells
	fpsLabel = Theme.mono(bar, "FPS --", UDim2.fromScale(0.64, 0.1), UDim2.fromScale(0.35, 0.28))
	pingLabel = Theme.mono(bar, "PING --", UDim2.fromScale(0.64, 0.39), UDim2.fromScale(0.35, 0.28))
	cellsLabel = Theme.mono(bar, "CELLS 0", UDim2.fromScale(0.64, 0.68), UDim2.fromScale(0.35, 0.28))
	for _, l in { fpsLabel, pingLabel, cellsLabel } do
		l.TextColor3 = Theme.MutedText
		l.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(l, 12)
	end

	-- Compact top-right currency pill (reference #4 sizing).
	local goldPill = Theme.panel(parent, UDim2.fromScale(0.99, 0.018), UDim2.fromOffset(160, 48), Vector2.new(1, 0))
	Theme.responsiveSize(goldPill, Vector2.new(160, 48), Vector2.new(12, 12))
	goldPill.BackgroundColor3 = Color3.fromRGB(3, 7, 13)
	goldPill.BackgroundTransparency = 0.01

	local coin = Instance.new("ImageLabel")
	coin.Position = UDim2.fromOffset(7, 7)
	coin.Size = UDim2.fromOffset(34, 34)
	coin.BackgroundTransparency = 1
	coin.Image = "rbxassetid://90476441150192"
	coin.ScaleType = Enum.ScaleType.Fit
	coin.Parent = goldPill

	goldTopLabel = Theme.label(goldPill, "0", UDim2.fromOffset(47, 5), UDim2.fromOffset(70, 38))
	goldTopLabel.Font = Enum.Font.GothamBold
	goldTopLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldTopLabel.TextColor3 = Color3.fromRGB(244, 247, 252)
	Theme.capText(goldTopLabel, 21)

	local plus = Theme.button(goldPill, "+", UDim2.fromOffset(123, 9), UDim2.fromOffset(30, 30), function()
		if onGoldClick then
			onGoldClick()
		end
	end)
	plus.BackgroundColor3 = Color3.fromRGB(54, 211, 151)
	plus.BackgroundTransparency = 0
	plus.TextColor3 = Color3.fromRGB(5, 45, 35)
	Theme.capText(plus, 20)
end

function HUD.setGameplayVisible(visible: boolean)
	if statsBar then
		statsBar.Visible = visible
	end
end

function HUD.setPing(ms: number)
	pingMs = ms
end

local function setText(label: TextLabel, key: string, text: string)
	if last[key] ~= text then
		last[key] = text
		label.Text = text
	end
end

function HUD.update(dt: number)
	smoothedDt += (dt - smoothedDt) * 0.05

	uiAccumulator += dt
	if uiAccumulator < 0.2 then
		return
	end
	uiAccumulator = 0

	setText(massLabel, "mass", Util.abbrevMass(WorldState.own.mass))
	setText(coinLabel, "coins", tostring(WorldState.coins or 0))
	setText(goldTopLabel, "goldTop", commas(WorldState.coins or 0))
	setText(fpsLabel, "fps", "FPS " .. math.floor(1 / smoothedDt + 0.5))
	setText(pingLabel, "ping", pingMs >= 0 and ("PING " .. math.floor(pingMs + 0.5)) or "PING --")
	setText(cellsLabel, "cells", "CELLS " .. (WorldState.own.count or 0) .. " / " .. Config.MaxCells)

	local level, into, need = LevelCurve.progress(WorldState.xp or 0)
	setText(lvLabel, "lv", "Lv " .. level)
	local fill = need > 0 and math.clamp(into / need, 0, 1) or 1
	if last.fill ~= fill then
		last.fill = fill
		xpFill.Size = UDim2.fromScale(fill, 1)
	end
end

return HUD
