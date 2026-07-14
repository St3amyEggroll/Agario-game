--[[
	ColorPicker - a reusable HSV colour picker modal (saturation/value square +
	hue bar + Apply). One shared instance; call ColorPicker.open(title, initial,
	onApply) and onApply(Color3) fires when the user hits Apply.

	The SV square is a hue-coloured frame with a white gradient (left, saturation)
	and a black gradient (bottom, value) composited over it; an invisible "catcher"
	frame on top captures drag input so the gradients don't eat the clicks.
]]

local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

local ColorPicker = {}

local panel: Frame
local titleLabel: TextLabel
local svHueBg: Frame
local svCursor: Frame
local hueBar: Frame
local hueCursor: Frame
local applyBtn: TextButton
local h, s, v = 0, 1, 1
local onApplyCb: ((Color3) -> ())? = nil
local dragging: string? = nil -- "sv" | "hue" | nil

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function currentColor(): Color3
	return Color3.fromHSV(h, s, v)
end

local function refresh()
	svHueBg.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
	svCursor.Position = UDim2.fromScale(s, 1 - v)
	hueCursor.Position = UDim2.fromScale(0.5, h)
	applyBtn.Text = "Apply " .. hex(currentColor())
end

local function fracIn(frame: Frame, x: number, y: number): (number, number)
	local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
	return (x - ap.X) / math.max(as.X, 1), (y - ap.Y) / math.max(as.Y, 1)
end

local function applyDrag(input: InputObject)
	if dragging == "sv" then
		local fx, fy = fracIn(svHueBg, input.Position.X, input.Position.Y)
		s, v = math.clamp(fx, 0, 1), 1 - math.clamp(fy, 0, 1)
		refresh()
	elseif dragging == "hue" then
		local _, fy = fracIn(hueBar, input.Position.X, input.Position.Y)
		h = math.clamp(fy, 0, 1)
		refresh()
	end
end

local function catcher(parent: Frame): Frame
	local c = Instance.new("Frame")
	c.Size = UDim2.fromScale(1, 1)
	c.BackgroundTransparency = 1
	c.Active = true
	c.ZIndex = 6
	c.Parent = parent
	return c
end

function ColorPicker.init(parent: Instance)
	panel = Theme.panel(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.34, 0.52), Vector2.new(0.5, 0.5))
	panel.Visible = false
	panel.ZIndex = 60 -- above the side panels / settings

	titleLabel = Theme.label(panel, "Color", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.6, 0.1))
	titleLabel.TextColor3 = Theme.AccentColor
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(titleLabel, 22)
	Theme.closeButton(panel, UDim2.fromScale(0.9, 0.03), UDim2.fromScale(0.08, 0.08), function()
		panel.Visible = false
	end)

	-- SV square (hue bg + white + black gradients)
	svHueBg = Instance.new("Frame")
	svHueBg.Position = UDim2.fromScale(0.05, 0.2)
	svHueBg.Size = UDim2.fromScale(0.66, 0.6)
	svHueBg.BackgroundColor3 = Color3.fromHSV(0, 1, 1)
	svHueBg.BorderSizePixel = 0
	Theme.round(svHueBg, 6)
	svHueBg.Parent = panel
	local white = Instance.new("Frame")
	white.Size = UDim2.fromScale(1, 1)
	white.BackgroundColor3 = Color3.new(1, 1, 1)
	white.BorderSizePixel = 0
	local wg = Instance.new("UIGradient")
	wg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	wg.Parent = white
	white.Parent = svHueBg
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	bg.Parent = black
	black.Parent = svHueBg
	svCursor = Instance.new("Frame")
	svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	svCursor.Size = UDim2.fromOffset(12, 12)
	svCursor.BackgroundTransparency = 1
	svCursor.ZIndex = 4
	local scc = Instance.new("UICorner")
	scc.CornerRadius = UDim.new(0.5, 0)
	scc.Parent = svCursor
	Theme.stroke(svCursor, Color3.new(1, 1, 1), 0).Thickness = 2
	svCursor.Parent = svHueBg
	local svCatch = catcher(svHueBg)

	-- hue bar
	hueBar = Instance.new("Frame")
	hueBar.Position = UDim2.fromScale(0.76, 0.2)
	hueBar.Size = UDim2.fromScale(0.13, 0.6)
	hueBar.BorderSizePixel = 0
	Theme.round(hueBar, 6)
	local hg = Instance.new("UIGradient")
	hg.Rotation = 90
	hg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
		ColorSequenceKeypoint.new(1 / 6, Color3.fromHSV(1 / 6, 1, 1)),
		ColorSequenceKeypoint.new(2 / 6, Color3.fromHSV(2 / 6, 1, 1)),
		ColorSequenceKeypoint.new(3 / 6, Color3.fromHSV(3 / 6, 1, 1)),
		ColorSequenceKeypoint.new(4 / 6, Color3.fromHSV(4 / 6, 1, 1)),
		ColorSequenceKeypoint.new(5 / 6, Color3.fromHSV(5 / 6, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
	})
	hg.Parent = hueBar
	hueBar.Parent = panel
	hueCursor = Instance.new("Frame")
	hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	hueCursor.Size = UDim2.new(1.3, 0, 0, 4)
	hueCursor.Position = UDim2.fromScale(0.5, 0)
	hueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
	hueCursor.BorderSizePixel = 0
	hueCursor.ZIndex = 4
	Theme.stroke(hueCursor, Color3.new(0, 0, 0), 0.2)
	hueCursor.Parent = hueBar
	local hueCatch = catcher(hueBar)

	applyBtn = Theme.button(panel, "Apply", UDim2.fromScale(0.5, 0.98), UDim2.fromScale(0.9, 0.12), function()
		if onApplyCb then
			onApplyCb(currentColor())
		end
		panel.Visible = false
	end)
	applyBtn.AnchorPoint = Vector2.new(0.5, 1)
	Theme.capText(applyBtn, 18)

	-- drag input
	local function beginOn(catch: Frame, which: string)
		catch.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = which
				applyDrag(input)
			end
		end)
	end
	beginOn(svCatch, "sv")
	beginOn(hueCatch, "hue")
	UserInputService.InputChanged:Connect(function(input)
		if not panel.Visible or not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			applyDrag(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
		end
	end)
end

-- Open the picker seeded with `initial`; onApply(Color3) fires on Apply.
function ColorPicker.open(title: string, initial: Color3?, onApply: (Color3) -> ())
	h, s, v = (initial or Color3.new(1, 1, 1)):ToHSV()
	onApplyCb = onApply
	titleLabel.Text = title
	refresh()
	panel.Visible = true
	Theme.popIn(panel)
end

return ColorPicker
