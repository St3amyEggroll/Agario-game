--[[
	Chat - bottom-left chat box (Agma-style): a small message log + an input that
	sends through the server (Remotes.Chat client->server), which filters and
	broadcasts to everyone (driving both this log and the cell chat bubbles).
	Press Enter to focus the box. Public tab works; Party/Private are stubs for a
	future party system.
]]

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Chat = {}

local MAX_MESSAGES = 6
local logFrame: Frame
local input: TextBox
local messages = {} -- queue of message label frames
local nextOrder = 0 -- monotonic so UIListLayout keeps chronological order

local function hex(c: Color3): string
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function addMessage(slot: number, text: string)
	local color = WorldState.colorForSlot(slot)
	-- escape RichText metachars in both name and message
	local function esc(s: string): string
		return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
	end
	local name = esc(WorldState.nameForSlot(slot))
	text = esc(text)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.Font = Theme.Font
	label.RichText = true
	label.Text = ('<font color="%s"><b>%s</b></font>  %s'):format(hex(color), name, text)
	label.TextColor3 = Theme.TextColor
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.5
	nextOrder += 1
	label.LayoutOrder = nextOrder
	label.Parent = logFrame

	table.insert(messages, label)
	if #messages > MAX_MESSAGES then
		local old = table.remove(messages, 1)
		if old then
			old:Destroy()
		end
	end
end

function Chat.init(parent: Instance)
	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0, 1)
	container.Position = UDim2.fromScale(0.008, 0.985)
	container.Size = UDim2.fromScale(0.25, 0.24)
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- message log (fills the top, messages stack from the bottom)
	logFrame = Instance.new("Frame")
	logFrame.Position = UDim2.fromScale(0, 0)
	logFrame.Size = UDim2.fromScale(1, 0.66)
	logFrame.BackgroundTransparency = 1
	logFrame.Parent = container
	local ll = Instance.new("UIListLayout")
	ll.VerticalAlignment = Enum.VerticalAlignment.Bottom
	ll.HorizontalAlignment = Enum.HorizontalAlignment.Left
	ll.Padding = UDim.new(0, 2)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = logFrame

	-- connection status
	local conn = Theme.label(container, "\u{25CF} Connected", UDim2.fromScale(0, 0.68), UDim2.fromScale(0.6, 0.09))
	conn.TextColor3 = Theme.Green
	conn.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(conn, 12)

	-- tabs (Public works; the others are stubs)
	local tabNames = { "Public", "Party", "Private" }
	for i, tabName in tabNames do
		local t = Theme.label(container, tabName, UDim2.fromScale((i - 1) * 0.2, 0.78), UDim2.fromScale(0.2, 0.09))
		t.TextColor3 = i == 1 and Theme.Green or Theme.MutedText
		t.TextXAlignment = Enum.TextXAlignment.Left
		Theme.capText(t, 12)
	end

	-- input box
	input = Instance.new("TextBox")
	input.Position = UDim2.fromScale(0, 0.89)
	input.Size = UDim2.fromScale(1, 0.11)
	input.BackgroundColor3 = Theme.Field
	input.BackgroundTransparency = 0.15
	input.BorderSizePixel = 0
	input.Font = Theme.Font
	input.PlaceholderText = "Press Enter to chat..."
	input.Text = ""
	input.TextColor3 = Theme.TextColor
	input.PlaceholderColor3 = Theme.MutedText
	input.TextScaled = false
	input.TextSize = 14
	input.ClearTextOnFocus = false
	input.TextXAlignment = Enum.TextXAlignment.Left
	Theme.round(input, 7)
	Theme.stroke(input)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = input
	Theme.capText(input, 15)
	input.Parent = container

	input.FocusLost:Connect(function(enter)
		local text = input.Text:gsub("^%s+", ""):gsub("%s+$", "")
		input.Text = ""
		if enter and #text > 0 then
			Remotes.Chat:FireServer(text:sub(1, Config.MaxChatLength))
		end
	end)

	-- Enter focuses the box (when not already typing somewhere)
	UserInputService.InputBegan:Connect(function(inp, gameProcessed)
		if gameProcessed then
			return
		end
		if inp.KeyCode == Enum.KeyCode.Return or inp.KeyCode == Enum.KeyCode.KeypadEnter then
			input:CaptureFocus()
		end
	end)

	-- incoming messages -> log
	Remotes.Chat.OnClientEvent:Connect(function(slot, text)
		if typeof(slot) == "number" and typeof(text) == "string" then
			addMessage(slot, text)
		end
	end)
end

return Chat
