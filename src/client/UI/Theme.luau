--[[
	Theme - UI construction helpers + the single source of design tokens.

	The overhaul palette: one cyan "cell-glow" accent, gold for currency, green
	for ready/owned, red only for danger. Panels are near-solid dark blue-grey
	with a hairline border so every overlay reads the same. Display text is
	GothamBold; anything that COUNTS (mass, ping, fps, coins, XP) is set in a
	mono face so the HUD reads like an instrument, not a menu.

	Everything is Scale-based UDim2 + TextScaled so the interface holds up on any
	screen size (no fixed pixel offsets for layout).
]]

local Theme = {
	-- surfaces
	PanelColor = Color3.fromRGB(27, 31, 42),
	Panel2Color = Color3.fromRGB(35, 42, 58),
	PanelTransparency = 0.06,
	Border = Color3.fromRGB(45, 52, 72),
	Field = Color3.fromRGB(14, 16, 23), -- the play-field dark (also the deepest inset)

	-- ink
	TextColor = Color3.fromRGB(233, 237, 246),
	MutedText = Color3.fromRGB(152, 162, 186),

	-- accents / semantics
	AccentColor = Color3.fromRGB(95, 200, 255),
	AccentInk = Color3.fromRGB(6, 34, 47), -- readable text ON the accent
	Gold = Color3.fromRGB(255, 207, 58),
	Green = Color3.fromRGB(84, 201, 138),
	GreenInk = Color3.fromRGB(6, 48, 28),
	Danger = Color3.fromRGB(255, 107, 100),

	-- buttons
	ButtonColor = Color3.fromRGB(35, 42, 58),
	ButtonHover = Color3.fromRGB(48, 57, 78),

	Font = Enum.Font.GothamBold,
	MonoFont = Enum.Font.RobotoMono, -- data readouts (tabular-ish)
}

function Theme.round(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
	return instance
end

-- hairline border, the crisp edge that ties every panel together
function Theme.stroke(instance: GuiObject, color: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Border
	s.Thickness = thickness or 1
	s.Transparency = 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = instance
	return s
end

function Theme.panel(parent: Instance, pos: UDim2, size: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = Theme.PanelColor
	f.BackgroundTransparency = Theme.PanelTransparency
	f.BorderSizePixel = 0
	Theme.round(f, 12)
	Theme.stroke(f)
	f.Parent = parent
	return f
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

-- a mono data label (for numbers that should line up / read as a readout)
function Theme.mono(parent: Instance, text: string, pos: UDim2, size: UDim2): TextLabel
	local l = Theme.label(parent, text, pos, size)
	l.Font = Theme.MonoFont
	return l
end

-- a small uppercase caption, letter-spaced feel via GothamBold + muted color
function Theme.caption(parent: Instance, text: string, pos: UDim2, size: UDim2): TextLabel
	local l = Theme.label(parent, string.upper(text), pos, size)
	l.TextColor3 = Theme.MutedText
	return l
end

function Theme.button(parent: Instance, text: string, pos: UDim2, size: UDim2, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = Theme.ButtonColor
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.Text = text
	b.TextColor3 = Theme.TextColor
	b.TextScaled = true
	b.AutoButtonColor = false
	Theme.round(b)
	Theme.stroke(b)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = Theme.ButtonHover
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = Theme.ButtonColor
	end)
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

-- a filled "primary" button (colored background, dark ink) - Play, Equip, etc.
function Theme.primaryButton(
	parent: Instance,
	text: string,
	pos: UDim2,
	size: UDim2,
	fill: Color3,
	ink: Color3,
	onClick: () -> ()
): TextButton
	local b = Theme.button(parent, text, pos, size, onClick)
	b.BackgroundColor3 = fill
	b.TextColor3 = ink
	local hover = fill:Lerp(Color3.new(1, 1, 1), 0.12)
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = hover
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = fill
	end)
	return b
end

-- keeps button/label text from becoming comically large on huge monitors
function Theme.capText(l: GuiObject, maxSize: number)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
end

return Theme
