--[[
	ChatBubbles - floats a small text bubble above a player's cell when they
	chat. One bubble per player (their largest cell), even if they're split into
	many. Bubbles are pooled and positioned in screen space each frame from the
	interpolated cell view.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local WorldState = require(script.Parent.WorldState)

local ChatBubbles = {}

local gui: ScreenGui
local bubbles = {} -- [slot] = { text, expireAt }
local pool = {} -- reusable bubble wrappers
local activeWrappers = {} -- [slot] = wrapper currently shown
-- a monotonic client clock; os.clock is fine here (display timing only)
local function clockNow()
	return os.clock()
end

local function makeBubble()
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = frame
	local sizeMax = Instance.new("UISizeConstraint")
	sizeMax.MaxSize = Vector2.new(320, 80)
	sizeMax.Parent = frame
	local label = Instance.new("TextLabel")
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextWrapped = true
	label.TextColor3 = Color3.fromRGB(240, 242, 248)
	label.Size = UDim2.fromOffset(0, 0)
	label.Parent = frame
	frame.Parent = gui
	return { frame = frame, label = label, lastText = "" }
end

local function acquire()
	local w = table.remove(pool) or makeBubble()
	w.frame.Visible = true
	return w
end

local function release(w)
	w.frame.Visible = false
	pool[#pool + 1] = w
end

function ChatBubbles.init(playerGui: PlayerGui)
	gui = Instance.new("ScreenGui")
	gui.Name = "AgarChat"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6 -- above the world (1), below the HUD (10)
	gui.Parent = playerGui

	Remotes.Chat.OnClientEvent:Connect(function(slot, text)
		if typeof(slot) == "number" and typeof(text) == "string" then
			bubbles[slot] = { text = text, expireAt = clockNow() + Config.ChatBubbleTime }
		end
	end)
end

-- cam is the Camera module (has .x, .y, .scale). Called each render frame.
function ChatBubbles.render(cam)
	local now = clockNow()
	local viewport = Workspace.CurrentCamera.ViewportSize
	local scale = cam.scale
	local ox = viewport.X / 2 - cam.x * scale
	local oy = viewport.Y / 2 - cam.y * scale

	-- find the largest visible cell per slot that currently has a bubble
	local best = {} -- [slot] = { x, y, r }
	for _, cell in WorldState.view.cells do
		local b = bubbles[cell.slot]
		if b and now < b.expireAt then
			local cur = best[cell.slot]
			if not cur or cell.r > cur.r then
				best[cell.slot] = { x = cell.x, y = cell.y, r = cell.r }
			end
		end
	end

	-- expire old bubbles
	for slot, b in bubbles do
		if now >= b.expireAt then
			bubbles[slot] = nil
			local w = activeWrappers[slot]
			if w then
				release(w)
				activeWrappers[slot] = nil
			end
		end
	end

	-- place / update a bubble for each slot that has one and a visible cell
	for slot, b in bubbles do
		local cellPos = best[slot]
		if cellPos then
			local w = activeWrappers[slot]
			if not w then
				w = acquire()
				activeWrappers[slot] = w
			end
			if w.lastText ~= b.text then
				w.lastText = b.text
				w.label.Text = b.text
			end
			local sx = ox + cellPos.x * scale
			local sy = oy + cellPos.y * scale - cellPos.r * scale - 8
			w.frame.Position = UDim2.fromOffset(math.floor(sx), math.floor(sy))
		elseif activeWrappers[slot] then
			-- bubble owner has no visible cell right now: hide it
			release(activeWrappers[slot])
			activeWrappers[slot] = nil
		end
	end
end

return ChatBubbles
