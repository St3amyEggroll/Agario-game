--[[
	ColorPicker - a reusable HSV colour picker.

	`ColorPicker.newWidget(parent, opts)` builds a picker (saturation/value square
	+ hue bar) that FILLS `parent` and returns { setColor, getColor }. It fires
	opts.onChange(Color3) live while dragging and opts.onCommit(Color3) once when
	the drag is released. Used inline (the Shop "Color" tab is one big picker) and
	inside the shared modal below.

	`ColorPicker.init(parent)` builds one shared MODAL (title + Apply + close);
	`ColorPicker.open(title, initial, onApply)` shows it and onApply(Color3) fires
	on Apply. Used for the map-background picker in Settings.

	The SV square is a hue-coloured frame with a white gradient (left, saturation)
	and a black gradient (bottom, value) over it; an invisible "catcher" frame on
	top captures drag input so the gradients don't eat the clicks.
]]

local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.Theme)

local ColorPicker = {}

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function fracIn(frame: Frame, x: number, y: number): (number, number)
	local ap, as = frame.AbsolutePosition, frame.AbsoluteSize
	return (x - ap.X) / math.max(as.X, 1), (y - ap.Y) / math.max(as.Y, 1)
end

-- Build a picker widget (SV square + hue bar) that fills `parent`.
function ColorPicker.newWidget(parent: Instance, opts)
	opts = opts or {}
	local w = { h = 0, s = 1, v = 1 }
	local dragging: string? = nil -- "sv" | "hue" | nil

	-- SV square: hue bg + white (left) + black (bottom) gradients
	local svHueBg = Instance.new("Frame")
	svHueBg.Position = UDim2.fromScale(0, 0)
	svHueBg.Size = UDim2.fromScale(0.8, 1)
	svHueBg.BackgroundColor3 = Color3.fromHSV(0, 1, 1)
	svHueBg.BorderSizePixel = 0
	Theme.round(svHueBg, 6)
	svHueBg.Parent = parent

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
	local bgr = Instance.new("UIGradient")
	bgr.Rotation = 90
	bgr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	bgr.Parent = black
	black.Parent = svHueBg

	local svCursor = Instance.new("Frame")
	svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	svCursor.Size = UDim2.fromOffset(14, 14)
	svCursor.BackgroundTransparency = 1
	svCursor.ZIndex = 4
	local scc = Instance.new("UICorner")
	scc.CornerRadius = UDim.new(0.5, 0)
	scc.Parent = svCursor
	Theme.stroke(svCursor, Color3.new(1, 1, 1), 0).Thickness = 2
	svCursor.Parent = svHueBg

	local svCatch = Instance.new("Frame")
	svCatch.Size = UDim2.fromScale(1, 1)
	svCatch.BackgroundTransparency = 1
	svCatch.Active = true
	svCatch.ZIndex = 6
	svCatch.Parent = svHueBg

	-- hue bar
	local hueBar = Instance.new("Frame")
	hueBar.Position = UDim2.fromScale(0.86, 0)
	hueBar.Size = UDim2.fromScale(0.11, 1)
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
	hueBar.Parent = parent

	local hueCursor = Instance.new("Frame")
	hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	hueCursor.Size = UDim2.new(1.3, 0, 0, 4)
	hueCursor.Position = UDim2.fromScale(0.5, 0)
	hueCursor.BackgroundColor3 = Color3.new(1, 1, 1)
	hueCursor.BorderSizePixel = 0
	hueCursor.ZIndex = 4
	Theme.stroke(hueCursor, Color3.new(0, 0, 0), 0.2)
	hueCursor.Parent = hueBar

	local hueCatch = Instance.new("Frame")
	hueCatch.Size = UDim2.fromScale(1, 1)
	hueCatch.BackgroundTransparency = 1
	hueCatch.Active = true
	hueCatch.ZIndex = 6
	hueCatch.Parent = hueBar

	local function currentColor(): Color3
		return Color3.fromHSV(w.h, w.s, w.v)
	end

	local function refresh(fireChange: boolean)
		svHueBg.BackgroundColor3 = Color3.fromHSV(w.h, 1, 1)
		svCursor.Position = UDim2.fromScale(w.s, 1 - w.v)
		hueCursor.Position = UDim2.fromScale(0.5, w.h)
		if fireChange and opts.onChange then
			opts.onChange(currentColor())
		end
	end

	local function applyDrag(input: InputObject)
		if dragging == "sv" then
			local fx, fy = fracIn(svHueBg, input.Position.X, input.Position.Y)
			w.s, w.v = math.clamp(fx, 0, 1), 1 - math.clamp(fy, 0, 1)
			refresh(true)
		elseif dragging == "hue" then
			local _, fy = fracIn(hueBar, input.Position.X, input.Position.Y)
			w.h = math.clamp(fy, 0, 1)
			refresh(true)
		end
	end

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
		if not dragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			applyDrag(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				dragging = nil
				if opts.onCommit then
					opts.onCommit(currentColor())
				end
			end
		end
	end)

	function w.setColor(c: Color3)
		w.h, w.s, w.v = c:ToHSV()
		refresh(false)
	end
	function w.getColor(): Color3
		return currentColor()
	end

	refresh(false)
	return w
end

------------------------------------------------------------------ shared modal

local modalPanel: Frame
local modalTitle: TextLabel
local modalApply: TextButton
local modalWidget
local modalApplyCb: ((Color3) -> ())? = nil

function ColorPicker.init(parent: Instance)
	modalPanel = Theme.panel(parent, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.34, 0.52), Vector2.new(0.5, 0.5))
	modalPanel.Visible = false
	modalPanel.ZIndex = 60 -- above the side panels / settings

	modalTitle = Theme.label(modalPanel, "Color", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.6, 0.1))
	modalTitle.TextColor3 = Theme.AccentColor
	modalTitle.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(modalTitle, 22)
	Theme.closeButton(modalPanel, UDim2.fromScale(0.9, 0.03), UDim2.fromScale(0.08, 0.08), function()
		modalPanel.Visible = false
	end)

	local body = Instance.new("Frame")
	body.Position = UDim2.fromScale(0.05, 0.18)
	body.Size = UDim2.fromScale(0.9, 0.62)
	body.BackgroundTransparency = 1
	body.Parent = modalPanel

	modalWidget = ColorPicker.newWidget(body, {
		onChange = function(c)
			modalApply.Text = "Apply " .. hex(c)
		end,
	})

	modalApply = Theme.button(modalPanel, "Apply", UDim2.fromScale(0.5, 0.98), UDim2.fromScale(0.9, 0.12), function()
		if modalApplyCb then
			modalApplyCb(modalWidget.getColor())
		end
		modalPanel.Visible = false
	end)
	modalApply.AnchorPoint = Vector2.new(0.5, 1)
	Theme.capText(modalApply, 18)
end

-- Open the modal seeded with `initial`; onApply(Color3) fires on Apply.
function ColorPicker.open(title: string, initial: Color3?, onApply: (Color3) -> ())
	modalTitle.Text = title
	modalWidget.setColor(initial or Color3.new(1, 1, 1))
	modalApply.Text = "Apply " .. hex(modalWidget.getColor())
	modalApplyCb = onApply
	modalPanel.Visible = true
	Theme.popIn(modalPanel)
end

return ColorPicker
