--[[
	Theme - UI construction helpers + design tokens.

	MINIMAL direction: chrome stays out of the way. In-game readouts float on the
	field (mono numbers with a text stroke, no heavy card); buttons are frosted -
	a barely-there translucent fill with a thin light hairline - and the cyan
	accent is spent sparingly (XP fill, the Play outline). Modal panels (shop,
	settings, the menu overlay) are more solid so their text stays readable.

	Everything is Scale-based UDim2 + TextScaled so it holds up on any screen.
]]

local Sounds = require(script.Parent.Parent.Sounds)

local Theme = {
	-- surfaces
	PanelColor = Color3.fromRGB(15, 17, 24),
	Panel2Color = Color3.fromRGB(24, 26, 36),
	PanelTransparency = 0.01,
	Border = Color3.fromRGB(58, 63, 73),
	BorderTransparency = 0.16,
	Field = Color3.fromRGB(3, 8, 15),

	-- ink
	TextColor = Color3.fromRGB(233, 237, 246),
	MutedText = Color3.fromRGB(150, 160, 184),

	-- accents / semantics (used sparingly in minimal)
	AccentColor = Color3.fromRGB(91, 220, 182),
	AccentInk = Color3.fromRGB(4, 42, 34),
	Purple = Color3.fromRGB(158, 79, 255),
	PurpleLight = Color3.fromRGB(208, 151, 255),
	Gold = Color3.fromRGB(255, 205, 46),
	Green = Color3.fromRGB(70, 232, 145),
	GreenInk = Color3.fromRGB(6, 48, 28),
	Danger = Color3.fromRGB(255, 107, 100),

	Font = Enum.Font.GothamBold,
	MonoFont = Enum.Font.RobotoMono, -- data readouts
}

function Theme.round(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
	return instance
end

-- faint hairline border (light, mostly transparent) - the minimal edge
function Theme.stroke(instance: GuiObject, color: Color3?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Border
	s.Thickness = 1
	s.Transparency = transparency or Theme.BorderTransparency
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

-- modal panel (shop / settings / menu overlay) - solid enough to read on
function Theme.panel(parent: Instance, pos: UDim2, size: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = Theme.PanelTransparency
	f.BorderSizePixel = 0
	Theme.round(f, 18)
	local surfaceGradient = Instance.new("UIGradient")
	surfaceGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(37, 39, 50)),
		ColorSequenceKeypoint.new(0.48, Color3.fromRGB(24, 25, 34)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 16, 23)),
	})
	surfaceGradient.Rotation = 135
	surfaceGradient.Parent = f
	local edge = Theme.stroke(f)
	edge.Color = Color3.fromRGB(77, 81, 94)
	edge.Thickness = 1.3
	edge.Transparency = 0.08
	f.Parent = parent
	return f
end

function Theme.decoratePanel(_panel: GuiObject)
	-- Panels now use only Theme.panel's clean black/navy UIGradient.
	-- Intentionally no image texture or patterned background.
end

function Theme.label(parent: Instance, text: string, pos: UDim2, size: UDim2): TextLabel
	local l = Instance.new("TextLabel")
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = Theme.Font
	l.Text = text
	l.TextColor3 = Theme.TextColor
	l.TextScaled = true
	l.Parent = parent
	return l
end

function Theme.mono(parent: Instance, text: string, pos: UDim2, size: UDim2): TextLabel
	local l = Theme.label(parent, text, pos, size)
	l.Font = Theme.MonoFont
	return l
end

-- small uppercase muted caption
function Theme.caption(parent: Instance, text: string, pos: UDim2, size: UDim2): TextLabel
	local l = Theme.label(parent, string.upper(text), pos, size)
	l.TextColor3 = Theme.MutedText
	return l
end

-- floating readout text: no background, a dark stroke so it stays legible over
-- any cell color. Used for the big Mass number.
function Theme.readout(parent: Instance, text: string, pos: UDim2, size: UDim2): TextLabel
	local l = Theme.mono(parent, text, pos, size)
	l.TextStrokeColor3 = Color3.new(0, 0, 0)
	l.TextStrokeTransparency = 0.35
	return l
end

-- frosted minimal button: barely-there translucent fill + faint hairline
function Theme.button(parent: Instance, text: string, pos: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = Color3.fromRGB(14, 24, 38)
	b.BackgroundTransparency = 0.02
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.Text = text
	b.TextColor3 = Theme.TextColor
	b.TextScaled = true
	b.AutoButtonColor = false
	Theme.round(b, 11)
	local edge = Theme.stroke(b)
	edge.Color = Color3.fromRGB(58, 63, 73)
	edge.Transparency = 0.14
	b.MouseEnter:Connect(function()
		-- Remember each button's actual resting style. Several modern controls
		-- (wallet +, play, toggles) deliberately recolor the shared button.
		b:SetAttribute("HoverBaseColor", b.BackgroundColor3)
		b:SetAttribute("HoverBaseTransparency", b.BackgroundTransparency)
		b:SetAttribute("HoverBaseEdgeTransparency", edge.Transparency)
		b.BackgroundColor3 = b.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.08)
		edge.Transparency = math.max(0, edge.Transparency - 0.25)
	end)
	b.MouseLeave:Connect(function()
		local baseColor = b:GetAttribute("HoverBaseColor")
		local baseTransparency = b:GetAttribute("HoverBaseTransparency")
		local baseEdgeTransparency = b:GetAttribute("HoverBaseEdgeTransparency")
		if typeof(baseColor) == "Color3" then
			b.BackgroundColor3 = baseColor
		end
		if typeof(baseTransparency) == "number" then
			b.BackgroundTransparency = baseTransparency
		end
		if typeof(baseEdgeTransparency) == "number" then
			edge.Transparency = baseEdgeTransparency
		end
	end)
	b.Parent = parent
	b.Activated:Connect(function()
		Sounds.play("click")
		onClick()
	end)
	return b
end

-- red close (X) button: solid red fill, white X. Used for panel close buttons.
function Theme.closeButton(parent: Instance, pos: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = Color3.fromRGB(12, 21, 34)
	b.BackgroundTransparency = 0
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.Text = "X" -- plain ASCII: the ✕ glyph (U+2715) tofus (renders as a box) in Gotham
	b.TextColor3 = Color3.fromRGB(207, 217, 235)
	b.TextScaled = true
	b.AutoButtonColor = false
	Theme.round(b, 11)
	local closeEdge = Theme.stroke(b, Color3.fromRGB(84, 104, 134), 0.42)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = Color3.fromRGB(32, 20, 38)
		closeEdge.Color = Theme.Danger
		closeEdge.Transparency = 0.15
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = Color3.fromRGB(12, 21, 34)
		closeEdge.Color = Color3.fromRGB(84, 104, 134)
		closeEdge.Transparency = 0.42
	end)
	b.Parent = parent
	b.Activated:Connect(function()
		Sounds.play("click")
		onClick()
	end)
	return b
end

-- outlined accent button (transparent fill, colored hairline + colored text) -
-- the minimal "primary" (Play, Equip). `color` defaults to the cyan accent.
function Theme.outlineButton(
	parent: Instance,
	text: string,
	pos: UDim2,
	size: UDim2,
	color: Color3?,
	onClick: () -> ()
): TextButton
	local c = color or Theme.AccentColor
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = c
	b.BackgroundTransparency = 0.9
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.Text = text
	b.TextColor3 = c
	b.TextScaled = true
	b.AutoButtonColor = false
	Theme.round(b)
	local s = Theme.stroke(b, c, 0.15)
	s.Thickness = 1.5
	b.MouseEnter:Connect(function()
		b.BackgroundTransparency = 0.78
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundTransparency = 0.9
	end)
	b.Parent = parent
	b.Activated:Connect(function()
		Sounds.play("click")
		onClick()
	end)
	return b
end

-- Keep a UI surface at a deliberate design size, then scale the whole surface
-- down proportionally when the viewport is smaller. This prevents percentage-sized
-- panels from becoming wide/flat on ultrawide monitors or tall/narrow on phones.
function Theme.responsiveSize(obj: GuiObject, baseSize: Vector2, margin: Vector2?): UIScale
	obj.Size = UDim2.fromOffset(baseSize.X, baseSize.Y)
	local viewportMargin = margin or Vector2.new(24, 24)
	local scale = Instance.new("UIScale")
	scale.Name = "ResponsiveScale"
	scale.Parent = obj

	local function refresh()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local availableX = math.max(1, viewport.X - viewportMargin.X * 2)
		local availableY = math.max(1, viewport.Y - viewportMargin.Y * 2)
		local value = math.clamp(math.min(1, availableX / baseSize.X, availableY / baseSize.Y), 0.32, 1)
		obj:SetAttribute("ResponsiveScale", value)
		scale.Scale = value
	end

	refresh()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
	return scale
end

-- keeps button/label text from becoming comically large on huge monitors
function Theme.capText(l: GuiObject, maxSize: number)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
end

-- Pop a panel in: a quick scale-up (with a little overshoot) via a UIScale, so
-- panels appear with a bounce like Agma. Reuses one UIScale per panel.
local TweenService = game:GetService("TweenService")
function Theme.sidePopout(obj: GuiObject, side: string, yScale: number?)
	obj:SetAttribute("PopoutSide", side)
	local function refresh()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		local wide = viewport.X >= 2000 and viewport.Y >= 650
		obj:SetAttribute("SideLayoutWide", wide)
		if wide then
			local left = side == "left"
			obj.AnchorPoint = left and Vector2.new(1, 0.5) or Vector2.new(0, 0.5)
			obj.Position = UDim2.new(0.5, left and -380 or 380, yScale or 0.56, 0)
		else
			obj.AnchorPoint = Vector2.new(0.5, 0.5)
			obj.Position = UDim2.fromScale(0.5, 0.52)
		end
	end
	refresh()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end
end

function Theme.popIn(obj: GuiObject)
	local scale = obj:FindFirstChild("ResponsiveScale") or obj:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "PopScale"
		scale.Parent = obj
	end
	local target = obj:GetAttribute("ResponsiveScale") or 1
	scale.Scale = target * 0.92
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()

	local side = obj:GetAttribute("PopoutSide")
	if side and obj:GetAttribute("SideLayoutWide") then
		local finalPosition = obj.Position
		local nudge = side == "left" and 34 or -34
		obj.Position = UDim2.new(finalPosition.X.Scale, finalPosition.X.Offset + nudge, finalPosition.Y.Scale, finalPosition.Y.Offset)
		TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Position = finalPosition }):Play()
	end
end

return Theme
