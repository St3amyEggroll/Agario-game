--[[
	Theme - tiny UI construction helpers so the UI modules stay readable.
	Everything is Scale-based UDim2 + TextScaled so the interface holds up on
	any screen size (no fixed pixel offsets for layout).
]]

local Theme = {
	PanelColor = Color3.fromRGB(24, 27, 35),
	PanelTransparency = 0.15,
	AccentColor = Color3.fromRGB(80, 175, 240),
	TextColor = Color3.fromRGB(235, 238, 245),
	MutedText = Color3.fromRGB(150, 158, 175),
	ButtonColor = Color3.fromRGB(45, 50, 64),
	ButtonHover = Color3.fromRGB(60, 67, 85),
	Font = Enum.Font.GothamBold,
}

function Theme.round(instance: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = instance
	return instance
end

function Theme.panel(parent: Instance, pos: UDim2, size: UDim2, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Position = pos
	f.Size = size
	f.AnchorPoint = anchor or Vector2.zero
	f.BackgroundColor3 = Theme.PanelColor
	f.BackgroundTransparency = Theme.PanelTransparency
	f.BorderSizePixel = 0
	Theme.round(f, 10)
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

-- keeps button/label text from becoming comically large on huge monitors
function Theme.capText(l: GuiObject, maxSize: number)
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
end

return Theme
