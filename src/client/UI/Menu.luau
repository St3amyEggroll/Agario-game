--[[
	Menu - the center play card (Agma-style). A dim overlay grays the game; the
	HUD, leaderboard, minimap and chat stay visible around a centered card:
	logo, your skin preview + a Skins button, nickname, PLAY + spectate (eye),
	and Shop + Settings. Play asks the server to spawn; the overlay hides on the
	"spawned" event. While spectating the overlay is hidden (the pause ☰ is how
	you get back).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Skins)
local Accessories = require(Shared.Accessories)
local LevelCurve = require(Shared.Levels)
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.IconAssets)
local WorldState = require(script.Parent.Parent.WorldState)

local Menu = {}

-- Consistent icon treatment for the main actions. The icon gently lifts,
-- scales, and rotates on hover while the button keeps handling the click.
local function animatedIcon(button: TextButton, imageId: string, position: UDim2, size: UDim2, hoverRotation: number): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "AnimatedIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = position
	icon.Size = size
	icon.BackgroundTransparency = 1
	icon.Image = imageId
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = button.ZIndex + 1
	icon.Parent = button
	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = icon

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.16 }):Play()
		TweenService:Create(icon, TweenInfo.new(0.16, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Rotation = hoverRotation,
			Position = UDim2.new(position.X.Scale, position.X.Offset, position.Y.Scale, position.Y.Offset - 2),
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(icon, TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Rotation = 0,
			Position = position,
		}):Play()
	end)
	return icon
end

local function liquidCartIcon(button: TextButton): Frame
	local lavender = Color3.fromRGB(234, 211, 255)
	local pink = Color3.fromRGB(246, 75, 218)
	local hotPink = Color3.fromRGB(255, 39, 174)

	local icon = Instance.new("Frame")
	icon.Name = "LiquidCartIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.17, 0.5)
	icon.Size = UDim2.fromScale(0.23, 0.72)
	icon.BackgroundTransparency = 1
	icon.Active = false
	icon.ZIndex = button.ZIndex + 2
	icon.Parent = button

	local iconScale = Instance.new("UIScale")
	iconScale.Scale = 1
	iconScale.Parent = icon

	local function line(name: string, position: UDim2, size: UDim2, rotation: number): Frame
		local glow = Instance.new("Frame")
		glow.Name = name .. "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = position
		glow.Size = UDim2.new(size.X.Scale, size.X.Offset + 4, size.Y.Scale, size.Y.Offset + 4)
		glow.BackgroundColor3 = Color3.fromRGB(186, 76, 255)
		glow.BackgroundTransparency = 0.72
		glow.BorderSizePixel = 0
		glow.Rotation = rotation
		glow.Active = false
		glow.ZIndex = icon.ZIndex
		Theme.round(glow, 999)
		glow.Parent = icon

		local core = Instance.new("Frame")
		core.Name = name
		core.AnchorPoint = Vector2.new(0.5, 0.5)
		core.Position = position
		core.Size = size
		core.BackgroundColor3 = lavender
		core.BorderSizePixel = 0
		core.Rotation = rotation
		core.Active = false
		core.ZIndex = icon.ZIndex + 2
		Theme.round(core, 999)
		core.Parent = icon
		return core
	end

	-- The clipped liquid sits behind the cart outline.
	local liquidMask = Instance.new("Frame")
	liquidMask.Name = "LiquidMask"
	liquidMask.Position = UDim2.fromScale(0.31, 0.4)
	liquidMask.Size = UDim2.fromScale(0.45, 0.3)
	liquidMask.BackgroundTransparency = 1
	liquidMask.BorderSizePixel = 0
	liquidMask.ClipsDescendants = true
	liquidMask.Active = false
	liquidMask.ZIndex = icon.ZIndex + 1
	Theme.round(liquidMask, 4)
	liquidMask.Parent = icon

	local liquid = Instance.new("Frame")
	liquid.Name = "PinkLiquid"
	liquid.AnchorPoint = Vector2.new(0.5, 0.5)
	liquid.Position = UDim2.fromScale(0.5, 0.72)
	liquid.Size = UDim2.fromScale(1.38, 0.68)
	liquid.BackgroundColor3 = pink
	liquid.BorderSizePixel = 0
	liquid.Rotation = -6
	liquid.Active = false
	liquid.ZIndex = liquidMask.ZIndex
	Theme.round(liquid, 999)
	local liquidGradient = Instance.new("UIGradient")
	liquidGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(191, 53, 255)),
		ColorSequenceKeypoint.new(0.5, hotPink),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 105, 221)),
	})
	liquidGradient.Parent = liquid
	liquid.Parent = liquidMask

	local shine = Instance.new("Frame")
	shine.Name = "LiquidShine"
	shine.Position = UDim2.fromScale(0.14, 0.12)
	shine.Size = UDim2.fromScale(0.44, 0.12)
	shine.BackgroundColor3 = Color3.fromRGB(255, 221, 249)
	shine.BackgroundTransparency = 0.25
	shine.BorderSizePixel = 0
	shine.Active = false
	shine.ZIndex = liquid.ZIndex + 1
	Theme.round(shine, 999)
	shine.Parent = liquid

	line("Handle", UDim2.fromScale(0.19, 0.23), UDim2.fromScale(0.24, 0.075), 0)
	line("HandleStem", UDim2.fromScale(0.29, 0.36), UDim2.fromScale(0.075, 0.31), -18)
	line("BasketTop", UDim2.fromScale(0.53, 0.39), UDim2.fromScale(0.53, 0.075), 0)
	line("BasketLeft", UDim2.fromScale(0.32, 0.55), UDim2.fromScale(0.075, 0.36), -11)
	line("BasketRight", UDim2.fromScale(0.74, 0.55), UDim2.fromScale(0.075, 0.36), 11)
	line("BasketBase", UDim2.fromScale(0.53, 0.71), UDim2.fromScale(0.46, 0.075), 0)

	local function wheel(x: number): Frame
		local wheelGlow = Instance.new("Frame")
		wheelGlow.AnchorPoint = Vector2.new(0.5, 0.5)
		wheelGlow.Position = UDim2.fromScale(x, 0.87)
		wheelGlow.Size = UDim2.fromScale(0.16, 0.16)
		wheelGlow.BackgroundColor3 = Color3.fromRGB(192, 72, 255)
		wheelGlow.BackgroundTransparency = 0.68
		wheelGlow.BorderSizePixel = 0
		wheelGlow.Active = false
		wheelGlow.ZIndex = icon.ZIndex
		Theme.round(wheelGlow, 999)
		wheelGlow.Parent = icon

		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(x, 0.87)
		dot.Size = UDim2.fromScale(0.105, 0.105)
		dot.BackgroundColor3 = lavender
		dot.BorderSizePixel = 0
		dot.Active = false
		dot.ZIndex = icon.ZIndex + 2
		Theme.round(dot, 999)
		dot.Parent = icon
		return dot
	end
	wheel(0.39)
	wheel(0.68)

	local drops = {}
	for i, x in { 0.43, 0.61 } do
		local drop = Instance.new("Frame")
		drop.Name = "SplashDrop" .. i
		drop.AnchorPoint = Vector2.new(0.5, 0.5)
		drop.Position = UDim2.fromScale(x, 0.43)
		drop.Size = UDim2.fromScale(i == 1 and 0.07 or 0.05, i == 1 and 0.07 or 0.05)
		drop.BackgroundColor3 = i == 1 and pink or hotPink
		drop.BackgroundTransparency = 1
		drop.BorderSizePixel = 0
		drop.Active = false
		drop.ZIndex = icon.ZIndex + 1
		Theme.round(drop, 999)
		drop.Parent = icon
		drops[i] = drop
	end

	-- Gentle perpetual slosh; the liquid stays clipped inside the basket.
	task.spawn(function()
		while icon.Parent do
			local right = TweenService:Create(liquid, TweenInfo.new(0.78, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.55, 0.7),
				Rotation = 7,
			})
			right:Play()
			right.Completed:Wait()
			if not icon.Parent then break end
			local left = TweenService:Create(liquid, TweenInfo.new(0.78, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.45, 0.74),
				Rotation = -7,
			})
			left:Play()
			left.Completed:Wait()
		end
	end)

	for i, drop in drops do
		task.spawn(function()
			task.wait(0.25 * i)
			while icon.Parent do
				drop.Position = UDim2.fromScale(i == 1 and 0.43 or 0.61, 0.49)
				drop.BackgroundTransparency = 0.05
				local splash = TweenService:Create(drop, TweenInfo.new(0.46, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = UDim2.fromScale(i == 1 and 0.37 or 0.68, i == 1 and 0.27 or 0.31),
					BackgroundTransparency = 1,
				})
				splash:Play()
				splash.Completed:Wait()
				task.wait(0.75)
			end
		end)
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(iconScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
		TweenService:Create(icon, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.17, 0.46),
			Rotation = -4,
		}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(iconScale, TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(icon, TweenInfo.new(0.14, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.17, 0.5),
			Rotation = 0,
		}):Play()
	end)
	return icon
end

local function tintActionButton(button: TextButton, color: Color3)
	button.BackgroundColor3 = Color3.fromRGB(5, 9, 16)
	button.BackgroundTransparency = 0.02
	for _, child in button:GetChildren() do
		if child:IsA("UIStroke") then
			child.Color = color
			child.Thickness = 1.5
			child.Transparency = 0.22
		end
	end
end

local function makeFlatLabel(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextScaled = false
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Active = false
	label.ZIndex = 4
	label.Parent = parent
	return label
end

local function flatLiquidCartIcon(tile: Frame)
	local ink = Color3.fromRGB(235, 214, 255)
	local pink = Color3.fromRGB(248, 67, 205)
	local root = Instance.new("Frame")
	root.Name = "FlatLiquidCart"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Active = false
	root.ZIndex = tile.ZIndex + 1
	root.Parent = tile

	local function line(name: string, position: UDim2, size: UDim2, rotation: number)
		local part = Instance.new("Frame")
		part.Name = name
		part.AnchorPoint = Vector2.new(0.5, 0.5)
		part.Position = position
		part.Size = size
		part.BackgroundColor3 = ink
		part.BorderSizePixel = 0
		part.Rotation = rotation
		part.Active = false
		part.ZIndex = root.ZIndex + 3
		Theme.round(part, 999)
		part.Parent = root
	end

	line("Handle", UDim2.fromScale(0.17, 0.25), UDim2.fromScale(0.2, 0.06), 0)
	line("Stem", UDim2.fromScale(0.28, 0.38), UDim2.fromScale(0.06, 0.29), -18)

	-- The basket itself owns an inset clipping mask. The liquid cannot cross its
	-- outline even while rotating because every animated pixel is clipped here.
	local basket = Instance.new("Frame")
	basket.Name = "Basket"
	basket.Position = UDim2.fromScale(0.3, 0.38)
	basket.Size = UDim2.fromScale(0.49, 0.34)
	basket.BackgroundTransparency = 1
	basket.BorderSizePixel = 0
	basket.Active = false
	basket.ZIndex = root.ZIndex + 3
	Theme.round(basket, 5)
	local basketStroke = Instance.new("UIStroke")
	basketStroke.Color = ink
	basketStroke.Thickness = 2
	basketStroke.Transparency = 0
	basketStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	basketStroke.Parent = basket
	basket.Parent = root

	local mask = Instance.new("Frame")
	mask.Name = "BasketLiquidMask"
	mask.Position = UDim2.fromOffset(2, 2)
	mask.Size = UDim2.new(1, -4, 1, -4)
	mask.BackgroundTransparency = 1
	mask.BorderSizePixel = 0
	mask.ClipsDescendants = true
	mask.Active = false
	mask.ZIndex = basket.ZIndex
	Theme.round(mask, 3)
	mask.Parent = basket

	local liquid = Instance.new("Frame")
	liquid.Name = "FlatPinkLiquid"
	liquid.AnchorPoint = Vector2.new(0.5, 1)
	liquid.Position = UDim2.fromScale(0.48, 1.08)
	liquid.Size = UDim2.new(1.6, 0, 0.72, 0)
	liquid.BackgroundColor3 = pink
	liquid.BorderSizePixel = 0
	liquid.Rotation = -5
	liquid.Active = false
	liquid.ZIndex = mask.ZIndex
	Theme.round(liquid, 999)
	liquid.Parent = mask

	for _, x in { 0.41, 0.68 } do
		local wheel = Instance.new("Frame")
		wheel.AnchorPoint = Vector2.new(0.5, 0.5)
		wheel.Position = UDim2.fromScale(x, 0.83)
		wheel.Size = UDim2.fromScale(0.1, 0.1)
		wheel.BackgroundColor3 = ink
		wheel.BorderSizePixel = 0
		wheel.Active = false
		wheel.ZIndex = root.ZIndex + 3
		Theme.round(wheel, 999)
		wheel.Parent = root
	end

	task.spawn(function()
		while root.Parent do
			local right = TweenService:Create(liquid, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.57, 1.03),
				Rotation = 7,
			})
			right:Play()
			right.Completed:Wait()
			if not root.Parent then break end
			local left = TweenService:Create(liquid, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.fromScale(0.43, 1.08),
				Rotation = -7,
			})
			left:Play()
			left.Completed:Wait()
		end
	end)
end

local function flatPlayIcon(tile: Frame, accent: Color3)
	local play = Instance.new("TextLabel")
	play.Size = UDim2.fromScale(1, 1)
	play.BackgroundTransparency = 1
	play.Font = Enum.Font.GothamBold
	play.Text = "\u{25B6}"
	play.TextColor3 = accent
	play.TextSize = 23
	play.Active = false
	play.ZIndex = tile.ZIndex + 1
	play.Parent = tile
end

local function flatEyeIcon(tile: Frame, accent: Color3)
	local root = Instance.new("Frame")
	root.Name = "LineEye"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Active = false
	root.ZIndex = tile.ZIndex + 1
	root.Parent = tile
	local segments = {
		{ UDim2.fromScale(0.37, 0.4), -22 },
		{ UDim2.fromScale(0.63, 0.4), 22 },
		{ UDim2.fromScale(0.37, 0.6), 22 },
		{ UDim2.fromScale(0.63, 0.6), -22 },
	}
	for _, info in segments do
		local segment = Instance.new("Frame")
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.Position = info[1]
		segment.Size = UDim2.fromScale(0.34, 0.065)
		segment.BackgroundColor3 = accent
		segment.BorderSizePixel = 0
		segment.Rotation = info[2]
		segment.ZIndex = root.ZIndex
		Theme.round(segment, 999)
		segment.Parent = root
	end
	local pupil = Instance.new("Frame")
	pupil.AnchorPoint = Vector2.new(0.5, 0.5)
	pupil.Position = UDim2.fromScale(0.5, 0.5)
	pupil.Size = UDim2.fromScale(0.17, 0.17)
	pupil.BackgroundColor3 = accent
	pupil.BorderSizePixel = 0
	pupil.ZIndex = root.ZIndex + 1
	Theme.round(pupil, 999)
	pupil.Parent = root
end

local function flatGearIcon(tile: Frame, accent: Color3)
	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(0.72, 0.72)
	root.BackgroundTransparency = 1
	root.Active = false
	root.ZIndex = tile.ZIndex + 1
	root.Parent = tile
	for _, angle in { 0, 45, 90, 135 } do
		local tooth = Instance.new("Frame")
		tooth.AnchorPoint = Vector2.new(0.5, 0.5)
		tooth.Position = UDim2.fromScale(0.5, 0.5)
		tooth.Size = UDim2.fromScale(0.18, 0.92)
		tooth.BackgroundColor3 = accent
		tooth.BorderSizePixel = 0
		tooth.Rotation = angle
		tooth.ZIndex = root.ZIndex
		Theme.round(tooth, 2)
		tooth.Parent = root
	end
	local hub = Instance.new("Frame")
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(0.68, 0.68)
	hub.BackgroundColor3 = accent
	hub.BorderSizePixel = 0
	hub.ZIndex = root.ZIndex + 1
	Theme.round(hub, 999)
	hub.Parent = root
	local hole = Instance.new("Frame")
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.Size = UDim2.fromScale(0.29, 0.29)
	hole.BackgroundColor3 = tile.BackgroundColor3
	hole.BorderSizePixel = 0
	hole.ZIndex = hub.ZIndex + 1
	Theme.round(hole, 999)
	hole.Parent = root
end

local function flatScoresIcon(tile: Frame, accent: Color3)
	local root = Instance.new("Frame")
	root.Name = "LeaderboardBars"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Active = false
	root.ZIndex = tile.ZIndex + 1
	root.Parent = tile
	local bars = {
		{ 0.28, 0.34 },
		{ 0.5, 0.58 },
		{ 0.72, 0.78 },
	}
	for _, info in bars do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 1)
		bar.Position = UDim2.fromScale(info[1], 0.78)
		bar.Size = UDim2.fromScale(0.13, info[2])
		bar.BackgroundColor3 = accent
		bar.BorderSizePixel = 0
		bar.ZIndex = root.ZIndex
		Theme.round(bar, 3)
		bar.Parent = root
	end
	local baseline = Instance.new("Frame")
	baseline.AnchorPoint = Vector2.new(0.5, 0.5)
	baseline.Position = UDim2.fromScale(0.5, 0.82)
	baseline.Size = UDim2.fromScale(0.62, 0.065)
	baseline.BackgroundColor3 = accent
	baseline.BorderSizePixel = 0
	baseline.ZIndex = root.ZIndex
	Theme.round(baseline, 999)
	baseline.Parent = root
end

local function styleActionCard(button: TextButton, titleText: string, _subtitleText: string, accent: Color3, iconKind: string, compact: boolean?): TextLabel
	button.Text = ""
	button.BackgroundColor3 = Color3.fromRGB(9, 11, 18)
	button.BackgroundTransparency = 0.01
	button.TextTransparency = 1
	button.ClipsDescendants = true
	local edge: UIStroke? = nil
	for _, child in button:GetChildren() do
		if child:IsA("UICorner") then
			child.CornerRadius = UDim.new(0, 12)
		elseif child:IsA("UIStroke") then
			edge = child
			child.Color = Color3.fromRGB(62, 66, 76)
			child.Thickness = 1.25
			child.Transparency = 0.12
		end
	end

	local neonGlow = Instance.new("UIStroke")
	neonGlow.Name = "NeonHoverGlow"
	neonGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	neonGlow.Color = accent
	neonGlow.Thickness = 5
	neonGlow.Transparency = 0.88
	neonGlow.Parent = button

	local tile = Instance.new("Frame")
	tile.Name = "IconTile"
	tile.AnchorPoint = Vector2.new(0, 0.5)
	tile.Position = UDim2.new(0, compact and 7 or 9, 0.5, 0)
	tile.Size = UDim2.fromOffset(compact and 42 or 46, compact and 42 or 46)
	tile.BackgroundTransparency = 1
	tile.BorderSizePixel = 0
	tile.Active = false
	tile.ZIndex = button.ZIndex + 2
	tile.Parent = button

	local imageMap = {
		shop = Icons.Shop,
		spectate = Icons.Spectate,
		settings = Icons.Settings,
		scores = Icons.Trophy,
	}
	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "CustomIcon"
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.Position = UDim2.fromScale(0.5, 0.5)
	iconImage.Size = UDim2.fromScale(1, 1)
	iconImage.BackgroundTransparency = 1
	iconImage.Image = imageMap[iconKind] or Icons.Play
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.Active = false
	iconImage.ZIndex = tile.ZIndex + 1
	iconImage.Parent = tile

	local titleX = compact and 53 or 64
	local title = makeFlatLabel(button, titleText, UDim2.new(0, titleX, 0, 0), UDim2.new(1, -(titleX + 8), 1, 0), compact and 11 or 14, Color3.fromRGB(247, 248, 252))
	title.Font = Enum.Font.GothamBold

	local underline = Instance.new("Frame")
	underline.Name = "NeonUnderline"
	underline.Position = UDim2.new(0, titleX, 1, -8)
	underline.Size = UDim2.fromOffset(0, 2)
	underline.BackgroundColor3 = accent
	underline.BackgroundTransparency = 0.1
	underline.BorderSizePixel = 0
	underline.ZIndex = title.ZIndex + 1
	Theme.round(underline, 999)
	underline.Parent = button

	local tileScale = Instance.new("UIScale")
	tileScale.Scale = 1
	tileScale.Parent = tile
	button.MouseEnter:Connect(function()
		TweenService:Create(tileScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.13 }):Play()
		TweenService:Create(iconImage, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = iconKind == "settings" and 12 or -5 }):Play()
		TweenService:Create(button, TweenInfo.new(0.18), { BackgroundColor3 = accent:Lerp(Color3.fromRGB(8, 10, 17), 0.86) }):Play()
		TweenService:Create(neonGlow, TweenInfo.new(0.18), { Transparency = 0.5, Thickness = 7 }):Play()
		TweenService:Create(underline, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(compact and 36 or 54, 2) }):Play()
		if edge then
			TweenService:Create(edge, TweenInfo.new(0.18), { Color = accent, Transparency = 0.18 }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(tileScale, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(iconImage, TweenInfo.new(0.15), { Rotation = 0 }):Play()
		TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(9, 11, 18) }):Play()
		TweenService:Create(neonGlow, TweenInfo.new(0.15), { Transparency = 0.88, Thickness = 5 }):Play()
		TweenService:Create(underline, TweenInfo.new(0.15), { Size = UDim2.fromOffset(0, 2) }):Play()
		if edge then
			TweenService:Create(edge, TweenInfo.new(0.15), { Color = Color3.fromRGB(62, 66, 76), Transparency = 0.12 }):Play()
		end
	end)
	return title
end

local function stylePlayButton(button: TextButton, titleText: string): TextLabel
	button.Text = ""
	button.BackgroundColor3 = Color3.fromRGB(126, 72, 255)
	button.BackgroundTransparency = 0
	button.ClipsDescendants = true
	for _, child in button:GetChildren() do
		if child:IsA("UICorner") then
			child.CornerRadius = UDim.new(0, 12)
		elseif child:IsA("UIStroke") then
			child.Color = Color3.fromRGB(194, 153, 255)
			child.Thickness = 1.5
			child.Transparency = 0.06
		end
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 104, 255)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(124, 67, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(77, 37, 211)),
	})
	gradient.Rotation = 8
	gradient.Parent = button
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.fromRGB(175, 102, 255)
	glow.Thickness = 6
	glow.Transparency = 0.68
	glow.Parent = button

	local title = makeFlatLabel(button, titleText, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 24, Color3.new(1, 1, 1))
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.GothamBold
	title.ZIndex = button.ZIndex + 2
	button.MouseEnter:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.18), { Transparency = 0.35, Thickness = 9 }):Play()
		TweenService:Create(gradient, TweenInfo.new(0.22), { Rotation = -10 }):Play()
		TweenService:Create(title, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextSize = 27 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(glow, TweenInfo.new(0.15), { Transparency = 0.68, Thickness = 6 }):Play()
		TweenService:Create(gradient, TweenInfo.new(0.2), { Rotation = 8 }):Play()
		TweenService:Create(title, TweenInfo.new(0.15), { TextSize = 24 }):Play()
	end)
	return title
end

local overlay: Frame
local logo: TextLabel
local card: Frame
local playBtn: TextButton
local playTitle: TextLabel
local eyeBtn: TextButton
local forceOpen = false -- show the play card OVER the game (in-game customize), even while alive
local panelOpen = false -- Shop / Settings / Scores replace the card instead of overlapping it
local nameBox: TextBox
local skinPreview: Frame
local skinImage: ImageLabel
local previewOverlays: { ImageLabel } = {}
local previewName: TextLabel
local deathLabel: TextLabel
local menuLevelLabel: TextLabel
local menuXpLabel: TextLabel
local menuXpDetailLabel: TextLabel
local menuXpFill: Frame
-- Gold is shown only in the top-right wallet, not repeated in the profile stats.
local menuPlaytimeLabel: TextLabel
local menuRankLabel: TextLabel
local sessionStartedAt = os.clock()
local onShopToggle: (() -> ())? = nil
local onSettings: (() -> ())? = nil
local onHiscores: (() -> ())? = nil
local lastSkin = -1
local lastColor: Color3? = nil
local lastOverlayKey = ""

local function commas(n: number): string
	n = math.max(0, math.floor(n + 0.5))
	local out = tostring(n):reverse():gsub("(%d%d%d)", "%1,")
	return (out:reverse():gsub("^,", ""))
end

local function clockText(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	return string.format("%dh %02dm", hours, minutes)
end

local function submitName()
	local text = nameBox and nameBox.Text or ""
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if #text > 0 then
		Remotes.Action:FireServer("setname", text)
	end
end

function Menu.init(parent: Instance, shopToggle: () -> (), settingsToggle: () -> (), hiscoresToggle: () -> ())
	onShopToggle = shopToggle
	onSettings = settingsToggle
	onHiscores = hiscoresToggle

	overlay = Instance.new("Frame")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Parent = parent

	-- logo above the card
	logo = Theme.label(overlay, "VIRUS IO", UDim2.fromScale(0.5, 0.17), UDim2.fromScale(0.5, 0.09))
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	Theme.capText(logo, 52)

	-- death summary (shown only after you were eaten)
	deathLabel = Theme.label(overlay, "", UDim2.fromScale(0.5, 0.24), UDim2.fromScale(0.6, 0.035))
	deathLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	deathLabel.TextColor3 = Theme.Danger
	deathLabel.Visible = false
	Theme.capText(deathLabel, 20)

	-- the card
	card = Theme.panel(overlay, UDim2.fromScale(0.5, 0.55), UDim2.fromOffset(620, 520), Vector2.new(0.5, 0.5))
	Theme.responsiveSize(card, Vector2.new(620, 520), Vector2.new(24, 70))
	Theme.decoratePanel(card)

	-- Profile progress: neon level badge, percentage XP bar and compact stat rows.
	local xpPurple = Color3.fromRGB(111, 74, 255)
	local xpPurpleLight = Color3.fromRGB(150, 112, 255)
	local levelBadge = Instance.new("Frame")
	levelBadge.Position = UDim2.fromScale(0.045, 0.045)
	levelBadge.Size = UDim2.fromScale(0.15, 0.185)
	levelBadge.BackgroundColor3 = Color3.fromRGB(56, 35, 135)
	levelBadge.BorderSizePixel = 0
	Theme.round(levelBadge, 12)
	local badgeGradient = Instance.new("UIGradient")
	badgeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(114, 83, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(65, 39, 169)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 20, 73)),
	})
	badgeGradient.Rotation = 90
	badgeGradient.Parent = levelBadge
	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(198, 155, 255)
	badgeStroke.Thickness = 1.8
	badgeStroke.Transparency = 0.04
	badgeStroke.Parent = levelBadge
	local badgeGlow = Instance.new("UIStroke")
	badgeGlow.Color = Color3.fromRGB(151, 77, 255)
	badgeGlow.Thickness = 7
	badgeGlow.Transparency = 0.75
	badgeGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	badgeGlow.Parent = levelBadge
	levelBadge.Parent = card
	TweenService:Create(badgeGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.42,
		Thickness = 10,
	}):Play()

	local levelOrb = Instance.new("ImageLabel")
	levelOrb.Name = "LevelAura"
	levelOrb.AnchorPoint = Vector2.new(0.5, 0.5)
	levelOrb.Position = UDim2.fromScale(0.5, 0.59)
	levelOrb.Size = UDim2.fromScale(0.84, 0.84)
	levelOrb.BackgroundTransparency = 1
	levelOrb.Image = Icons.Level
	levelOrb.ImageTransparency = 0.7
	levelOrb.ScaleType = Enum.ScaleType.Fit
	levelOrb.ZIndex = 2
	levelOrb.Parent = levelBadge

	local levelWord = Theme.caption(levelBadge, "LEVEL", UDim2.fromScale(0.08, 0.05), UDim2.fromScale(0.84, 0.22))
	levelWord.TextColor3 = Color3.fromRGB(235, 226, 255)
	levelWord.TextXAlignment = Enum.TextXAlignment.Center
	levelWord.ZIndex = 4
	Theme.capText(levelWord, 12)
	menuLevelLabel = Theme.readout(levelBadge, "1", UDim2.fromScale(0.08, 0.28), UDim2.fromScale(0.84, 0.64))
	menuLevelLabel.TextColor3 = Color3.fromRGB(250, 248, 255)
	menuLevelLabel.TextXAlignment = Enum.TextXAlignment.Center
	menuLevelLabel.TextScaled = true
	menuLevelLabel.ZIndex = 4
	Theme.capText(menuLevelLabel, 42)

	local xpTitle = Theme.caption(card, "XP PROGRESS", UDim2.fromScale(0.215, 0.065), UDim2.fromScale(0.22, 0.045))
	xpTitle.TextColor3 = Theme.MutedText
	xpTitle.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(xpTitle, 13)

	local xpTrack = Instance.new("Frame")
	xpTrack.Position = UDim2.fromScale(0.215, 0.125)
	xpTrack.Size = UDim2.fromScale(0.22, 0.055)
	xpTrack.BackgroundColor3 = Color3.fromRGB(5, 9, 16)
	xpTrack.BorderSizePixel = 0
	xpTrack.ClipsDescendants = true
	Theme.round(xpTrack, 5)
	Theme.stroke(xpTrack, Color3.fromRGB(49, 57, 82), 0.35)
	xpTrack.Parent = card

	menuXpFill = Instance.new("Frame")
	menuXpFill.Size = UDim2.fromScale(0, 1)
	menuXpFill.BackgroundColor3 = xpPurple
	menuXpFill.BorderSizePixel = 0
	Theme.round(menuXpFill, 5)
	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new(xpPurpleLight, Color3.fromRGB(76, 44, 210))
	fillGradient.Offset = Vector2.new(-1, 0)
	fillGradient.Parent = menuXpFill
	TweenService:Create(fillGradient, TweenInfo.new(1.8, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }):Play()
	menuXpFill.Parent = xpTrack

	menuXpLabel = Theme.mono(xpTrack, "0 / 2,000 XP", UDim2.fromScale(0.04, 0), UDim2.fromScale(0.92, 1))
	menuXpLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	menuXpLabel.TextXAlignment = Enum.TextXAlignment.Left
	menuXpLabel.ZIndex = 3
	Theme.capText(menuXpLabel, 13)

	menuXpDetailLabel = Theme.mono(card, "0% COMPLETE", UDim2.fromScale(0.215, 0.19), UDim2.fromScale(0.22, 0.038))
	menuXpDetailLabel.TextColor3 = Theme.MutedText
	menuXpDetailLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(menuXpDetailLabel, 11)

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromScale(0.045, 0.238)
	divider.Size = UDim2.fromScale(0.39, 0.002)
	divider.BackgroundColor3 = Color3.fromRGB(48, 55, 75)
	divider.BackgroundTransparency = 0.45
	divider.BorderSizePixel = 0
	divider.Parent = card

	local function statCard(x: number, titleText: string, imageId: string, accent: Color3, initialValue: string): TextLabel
		local stat = Instance.new("Frame")
		stat.Position = UDim2.fromScale(x, 0.255)
		stat.Size = UDim2.fromScale(0.19, 0.165)
		stat.BackgroundColor3 = Color3.fromRGB(13, 17, 25)
		stat.BackgroundTransparency = 0.01
		stat.BorderSizePixel = 0
		Theme.round(stat, 11)
		local edge = Theme.stroke(stat, accent, 0.08)
		edge.Thickness = 1.45
		stat.Parent = card

		local statGradient = Instance.new("UIGradient")
		statGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, accent:Lerp(Color3.fromRGB(17, 19, 28), 0.84)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 11, 18)),
		})
		statGradient.Rotation = 110
		statGradient.Parent = stat

		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 5)
		icon.Size = UDim2.fromOffset(38, 38)
		icon.BackgroundTransparency = 1
		icon.Image = imageId
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ZIndex = 3
		icon.Parent = stat

		local iconScale = Instance.new("UIScale")
		iconScale.Scale = 1
		iconScale.Parent = icon
		TweenService:Create(iconScale, TweenInfo.new(1.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.07 }):Play()

		local value = makeFlatLabel(stat, initialValue, UDim2.new(0, 6, 0, 40), UDim2.new(1, -12, 0, 23), 18, Color3.fromRGB(250, 250, 253))
		value.Font = Enum.Font.GothamBold
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.ZIndex = 3
		local title = makeFlatLabel(stat, titleText, UDim2.new(0, 6, 1, -22), UDim2.new(1, -12, 0, 15), 9, Color3.fromRGB(178, 184, 201))
		title.Font = Enum.Font.GothamMedium
		title.TextXAlignment = Enum.TextXAlignment.Center
		title.ZIndex = 3
		return value
	end

	menuPlaytimeLabel = statCard(0.045, "PLAYTIME", Icons.Playtime, Color3.fromRGB(43, 201, 255), "0h 00m")
	menuRankLabel = statCard(0.25, "HIGH SCORE", Icons.HighScore, Color3.fromRGB(210, 91, 255), "0")

	-- Large cell preview on the right.
	-- skin preview
	skinPreview = Instance.new("Frame")
	skinPreview.AnchorPoint = Vector2.new(0.5, 0)
	skinPreview.Position = UDim2.fromScale(0.76, 0.06)
	skinPreview.Size = UDim2.fromScale(0.31, 0.31)
	skinPreview.BackgroundColor3 = Theme.AccentColor
	skinPreview.BorderSizePixel = 0
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1
	ar.Parent = skinPreview
	Theme.round(skinPreview, 999)
	Theme.stroke(skinPreview, Color3.new(1, 1, 1), 0.6)
	skinPreview.Parent = card
	skinImage = Instance.new("ImageLabel")
	skinImage.AnchorPoint = Vector2.new(0.5, 0.5)
	skinImage.Position = UDim2.fromScale(0.5, 0.5)
	skinImage.Size = UDim2.fromScale(1, 1)
	skinImage.BackgroundTransparency = 1
	skinImage.ScaleType = Enum.ScaleType.Crop
	skinImage.Visible = false
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(0.5, 0)
	sc.Parent = skinImage
	skinImage.Parent = skinPreview

	-- your name shown ON the preview, live as you type (like your cell in-game)
	previewName = Instance.new("TextLabel")
	previewName.AnchorPoint = Vector2.new(0.5, 0.5)
	previewName.Position = UDim2.fromScale(0.5, 0.5)
	previewName.Size = UDim2.fromScale(1.5, 0.32)
	previewName.BackgroundTransparency = 1
	previewName.Font = Theme.Font
	previewName.Text = ""
	previewName.TextColor3 = Color3.new(1, 1, 1)
	previewName.TextScaled = true
	previewName.TextStrokeTransparency = 0.35
	previewName.ZIndex = 5
	Theme.capText(previewName, 22)
	previewName.Parent = skinPreview

	-- overlay layers over the skin in the preview (accessories + avatar)
	for _ = 1, Config.MaxOverlays do
		local ov = Instance.new("ImageLabel")
		ov.AnchorPoint = Vector2.new(0.5, 0.5)
		ov.Position = UDim2.fromScale(0.5, 0.5)
		ov.Size = UDim2.fromScale(1.5, 1.5)
		ov.BackgroundTransparency = 1
		ov.ScaleType = Enum.ScaleType.Fit
		ov.Visible = false
		ov.ZIndex = 4
		local oc = Instance.new("UICorner")
		oc.CornerRadius = UDim.new(0.5, 0)
		oc.Parent = ov
		ov.Parent = skinPreview
		previewOverlays[#previewOverlays + 1] = ov
	end

	-- nickname
	nameBox = Instance.new("TextBox")
	nameBox.AnchorPoint = Vector2.new(0.5, 0)
	nameBox.Position = UDim2.fromScale(0.5, 0.465)
	nameBox.Size = UDim2.fromScale(0.9, 0.095)
	nameBox.BackgroundColor3 = Theme.Field
	nameBox.BackgroundTransparency = 0.1
	nameBox.BorderSizePixel = 0
	nameBox.Font = Theme.Font
	nameBox.PlaceholderText = "Nickname..."
	nameBox.Text = ""
	nameBox.TextColor3 = Theme.TextColor
	nameBox.PlaceholderColor3 = Theme.MutedText
	nameBox.TextScaled = false
	nameBox.TextSize = 20
	nameBox.ClearTextOnFocus = false
	Theme.round(nameBox, 12)
	Theme.stroke(nameBox)
	Theme.capText(nameBox, 22)
	nameBox.Parent = card
	local namePadding = Instance.new("UIPadding")
	namePadding.PaddingLeft = UDim.new(0, 16)
	namePadding.PaddingRight = UDim.new(0, 58)
	namePadding.Parent = nameBox
	local editIcon = Instance.new("ImageLabel")
	editIcon.Name = "RenameIcon"
	editIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	-- UIPadding shrinks child coordinates; offset by its right inset so the pen straddles the actual field edge.
	editIcon.Position = UDim2.new(1, 58, 0.5, 0)
	editIcon.Size = UDim2.fromOffset(34, 34)
	editIcon.BackgroundTransparency = 1
	editIcon.Image = Icons.Edit
	editIcon.ScaleType = Enum.ScaleType.Fit
	editIcon.Active = false
	editIcon.ZIndex = nameBox.ZIndex + 2
	editIcon.Parent = nameBox
	local editScale = Instance.new("UIScale")
	editScale.Scale = 1
	editScale.Parent = editIcon
	nameBox.MouseEnter:Connect(function()
		TweenService:Create(editScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
		TweenService:Create(editIcon, TweenInfo.new(0.16), { Rotation = -8 }):Play()
	end)
	nameBox.MouseLeave:Connect(function()
		TweenService:Create(editScale, TweenInfo.new(0.14), { Scale = 1 }):Play()
		TweenService:Create(editIcon, TweenInfo.new(0.14), { Rotation = 0 }):Play()
	end)
	nameBox.FocusLost:Connect(function(enter)
		if enter then
			submitName()
		end
	end)
	Remotes.Name.OnClientEvent:Connect(function(name)
		if typeof(name) == "string" and not nameBox:IsFocused() then
			nameBox.Text = name
		end
	end)
	-- mirror the nickname onto the preview circle in real time as you type
	nameBox:GetPropertyChangedSignal("Text"):Connect(function()
		previewName.Text = nameBox.Text
	end)

	-- Flat 2D action cards: icon tile, clear hierarchy, and subtle hover lift.
	playBtn = Theme.button(card, "", UDim2.fromScale(0.04, 0.59), UDim2.fromScale(0.68, 0.115), function()
		if WorldState.status == "alive" then
			forceOpen = false
			Menu.refresh()
		else
			submitName()
			Remotes.Action:FireServer("play")
		end
	end)
	playBtn.Name = "PlayButton"
	playTitle = stylePlayButton(playBtn, "PLAY")

	eyeBtn = Theme.button(card, "", UDim2.fromScale(0.75, 0.59), UDim2.fromScale(0.21, 0.115), function()
		Remotes.Action:FireServer("spectate")
		WorldState.spectateSlot = nil -- start on the leader; the bar cycles from there
		WorldState.status = "spectate"
		Menu.refresh()
	end)
	eyeBtn.Name = "SpectateButton"
	styleActionCard(eyeBtn, "SPECTATE", "", Color3.fromRGB(61, 190, 255), "spectate", true)

	-- Shop | Settings | Scores use the same clean card language.
	local shop = Theme.button(card, "", UDim2.fromScale(0.04, 0.74), UDim2.fromScale(0.29, 0.105), function()
		if onShopToggle then
			onShopToggle()
		end
	end)
	shop.Name = "ShopButton"
	styleActionCard(shop, "SHOP", "", Color3.fromRGB(190, 91, 255), "shop", false)

	local settings = Theme.button(card, "", UDim2.fromScale(0.355, 0.74), UDim2.fromScale(0.29, 0.105), function()
		if onSettings then
			onSettings()
		end
	end)
	settings.Name = "SettingsButton"
	styleActionCard(settings, "SETTINGS", "", Color3.fromRGB(72, 184, 255), "settings", false)

	local scores = Theme.button(card, "", UDim2.fromScale(0.67, 0.74), UDim2.fromScale(0.29, 0.105), function()
		if onHiscores then
			onHiscores()
		end
	end)
	scores.Name = "ScoresButton"
	styleActionCard(scores, "SCORES", "", Color3.fromRGB(255, 190, 42), "scores", false)

	-- ? help (below the card)
	local help = Theme.button(card, "?   CONTROLS     SPACE  SPLIT    \u{2022}    W  FEED    \u{2022}    F  FREEZE", UDim2.fromScale(0.5, 0.885), UDim2.fromScale(0.92, 0.075), function() end)
	help.AnchorPoint = Vector2.new(0.5, 0)
	help.TextColor3 = Theme.MutedText
	Theme.capText(help, 12)

	Menu.refresh()
end

-- Open the play card OVER the running game (customize / change skin mid-match).
function Menu.openInGame()
	forceOpen = true
	Menu.refresh()
end

-- Toggle the play card over the running game (the M key). Non-destructive: it
-- only shows/hides the overlay while you're alive - it never respawns or leaves
-- the game, so tapping M can't kill you.
function Menu.toggleInGame()
	if WorldState.status ~= "alive" then
		return -- menu/dead already show the card; spectate uses the pause menu
	end
	forceOpen = not forceOpen
	Menu.refresh()
end

function Menu.isVisible(): boolean
	return overlay ~= nil and overlay.Visible
end

function Menu.setPanelOpen(open: boolean)
	if panelOpen ~= open then
		panelOpen = open
		Menu.refresh()
	end
end

function Menu.refresh()
	local status = WorldState.status
	if status ~= "alive" then
		forceOpen = false -- menu/dead/spectate already decide overlay visibility on their own
	end
	overlay.Visible = status == "menu" or status == "dead" or forceOpen or panelOpen
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local sideLayout = viewport.X >= 2000 and viewport.Y >= 650
	if card then
		card.Visible = not panelOpen or sideLayout
	end
	if logo then
		logo.Visible = not panelOpen or sideLayout
	end
	if playBtn then
		playTitle.Text = status == "alive" and "RESUME" or "PLAY" -- in-game: Play closes the menu
	end
	if eyeBtn then
		eyeBtn.Visible = status ~= "alive" -- can't spectate while you're playing
	end
	if deathLabel then
		if status == "dead" then
			deathLabel.Text = "You were eaten!   Best mass: " .. commas(math.floor(WorldState.own.peakMass + 0.5))
			deathLabel.Visible = not panelOpen or sideLayout
		else
			deathLabel.Visible = false
		end
	end
end

-- live-refresh the skin preview while the menu shows
function Menu.update(_dt: number)
	if not overlay.Visible then
		return
	end
	local level, into, need = LevelCurve.progress(WorldState.xp or 0)
	local xpFraction = need > 0 and math.clamp(into / need, 0, 1) or 1
	menuLevelLabel.Text = tostring(level)
	menuXpLabel.Text = commas(into) .. " / " .. commas(need) .. " XP"
	menuXpDetailLabel.Text = math.floor(xpFraction * 100 + 0.5) .. "% COMPLETE"
	menuXpFill.Size = UDim2.fromScale(xpFraction, 1)
	-- Wallet coins are intentionally not duplicated in the center profile stats.
	menuPlaytimeLabel.Text = clockText(os.clock() - sessionStartedAt)
	menuRankLabel.Text = commas(math.floor(WorldState.own.peakMass + 0.5))
	local mySlot = WorldState.mySlot or -1
	local skinId = WorldState.skinForSlot(mySlot)
	local overlayIds = WorldState.overlaysForSlot(mySlot)
	local avatarId: number? = nil
	for _, id in overlayIds do
		if id < 0 then
			avatarId = id
			break
		end
	end

	-- Avatar mode is a real full-cell skin, not a small square laid over the
	-- previously equipped skin. Crop fills the circular preview edge-to-edge.
	local visualSkinId = avatarId or skinId
	if visualSkinId ~= lastSkin then
		lastSkin = visualSkinId
		skinImage.Visible = visualSkinId ~= 0
		if visualSkinId ~= 0 then
			skinImage.Image = Skins.thumb(visualSkinId)
			skinImage.ScaleType = Enum.ScaleType.Crop
			-- AvatarHeadShot thumbnails include a tiny transparent rim. Match it
			-- with a neutral backdrop while keeping the actual cell perfectly round.
			if visualSkinId < 0 then
				skinPreview.BackgroundColor3 = Color3.fromRGB(224, 231, 239)
			end
		end
	end
	-- keep the plain-cell colour live: the Color tab changes it with no skin change
	if skinId == 0 and not avatarId then
		local color = WorldState.colorForSlot(mySlot)
		if color ~= lastColor then
			lastColor = color
			skinPreview.BackgroundColor3 = color
		end
	end

	-- Only accessories remain overlays. The avatar has already replaced the
	-- base skin above, so hats and other accessories sit cleanly on top of it.
	local okey = table.concat(overlayIds, ",")
	if okey ~= lastOverlayKey then
		lastOverlayKey = okey
		local sorted = {}
		for _, id in overlayIds do
			if id > 0 then
				table.insert(sorted, id)
			end
		end
		table.sort(sorted)
		for i, ov in previewOverlays do
			local id = sorted[i]
			if id then
				ov.Image = Accessories.thumb(id)
				ov.ScaleType = Enum.ScaleType.Fit
				local ax, ay, ascale = Accessories.placement(id)
				ov.Position = UDim2.fromScale(ax, ay)
				ov.Size = UDim2.fromScale(ascale, ascale)
				ov.Visible = true
			else
				ov.Visible = false
			end
		end
	end
end

return Menu
