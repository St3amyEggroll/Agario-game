--[[
	Notifications - transient toast messages (level-ups, kills). Toasts stack at
	the top-center and fade out after a short hold. Toasts are created on demand
	(rare events, never per-frame) and Destroy themselves after fading.
]]

local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.Theme)

local Notifications = {}

local container: Frame
local order = 0

function Notifications.init(parent: Instance)
	container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0)
	container.Position = UDim2.fromScale(0.5, 0.16)
	container.Size = UDim2.fromScale(0.5, 0.4)
	container.BackgroundTransparency = 1
	container.Parent = parent
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = container
end

function Notifications.show(text: string, color: Color3?)
	if not container then
		return
	end
	order += 1
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromScale(0.72, 0.055)
	toast.BackgroundColor3 = Theme.PanelColor
	toast.BackgroundTransparency = 0.2
	toast.BorderSizePixel = 0
	toast.Font = Theme.Font
	toast.Text = text
	toast.TextColor3 = color or Theme.TextColor
	toast.TextScaled = true
	toast.LayoutOrder = order
	Theme.round(toast, 8)
	Theme.stroke(toast)
	Theme.capText(toast, 20)
	toast.Parent = container

	task.delay(2.2, function()
		local tw = TweenService:Create(
			toast,
			TweenInfo.new(0.5),
			{ TextTransparency = 1, BackgroundTransparency = 1, TextStrokeTransparency = 1 }
		)
		tw:Play()
		tw.Completed:Connect(function()
			toast:Destroy()
		end)
	end)
end

return Notifications
