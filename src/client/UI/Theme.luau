--[[
	Theme - UI construction helpers + design tokens.

	MINIMAL direction: chrome stays out of the way. In-game readouts float on the
	field (mono numbers with a text stroke, no heavy card); buttons are frosted -
	a barely-there translucent fill with a thin light hairline - and the cyan
	accent is spent sparingly (XP fill, the Play outline). Modal panels (shop,
	settings, the menu overlay) are more solid so their text stays readable.

	Everything is Scale-based UDim2 + TextScaled so it holds up on any screen.
]]

local Theme = {
	-- surfaces
	PanelColor = Color3.fromRGB(18, 21, 29),
	Panel2Color = Color3.fromRGB(30, 35, 48),
	PanelTransparency = 0.12, -- modal panels: solid enough to read on
	Border = Color3.fromRGB(255, 255, 255), -- hairlines are faint WHITE (see stroke transparency)
	BorderTransparency = 0.86,
	Field = Color3.fromRGB(12, 14, 20),

	-- ink
	TextColor = Color3.fromRGB(233, 237, 246),
	MutedText = Color3.fromRGB(150, 160, 184),

	-- accents / semantics (used sparingly in minimal)
	AccentColor = Color3.fromRGB(95, 200, 255),
	AccentInk = Color3.fromRGB(6, 34, 47),
	Gold = Color3.fromRGB(255, 207, 58),
	Green = Color3.fromRGB(84, 201, 138),
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
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.93
	b.BorderSizePixel = 0
	b.Font = Theme.Font
	b.Text = text
	b.TextColor3 = Theme.TextColor
	b.TextScaled = true
	b.AutoButtonColor = false
	Theme.round(b)
	Theme.stroke(b)
	b.MouseEnter:Connect(function()
		b.BackgroundTransparency = 0.82
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundTransparency = 0.93
	end)
	b.Parent = parent
	b.Activated:Connect(onClick)
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
	b.Activated:Connect(onClick)
	return b
end

-- keeps button/label text from becoming comically large on huge monitors
function Theme.capText(l: GuiObject, maxSize: number)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
end

return Theme
