--[[
	Shop - searchable skin picker.

	Every entry in Shared/Skins is shown as a card (thumbnail + name + Equip).
	A search box filters cards by name; a "paste image id" box equips ANY Roblox
	image/decal id, so you're not limited to the catalog. Equipping fires the
	"setskin" action; the server stores the id on your roster slot and the
	renderer draws it on your cell.

	PERF: the ~100+ thumbnail ImageLabels are built lazily on first open (not at
	game start), and filtering just toggles card.Visible - the UIGridLayout
	skips invisible children, so no rebuild and no gaps. rbxthumb thumbnails
	stream in on demand.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Skins)
local Theme = require(script.Parent.Theme)

local Shop = {}

local panel: Frame
local scroll: ScrollingFrame
local cards: { { frame: Frame, name: string, lname: string } } = {}
local built = false

local function equip(id: number)
	Remotes.Action:FireServer("setskin", id)
end

-- Create every skin card once, on first open.
local function build()
	if built then
		return
	end
	built = true
	for _, skin in Skins.List do
		local card = Instance.new("Frame")
		card.BackgroundColor3 = Theme.Panel2Color
		card.BorderSizePixel = 0
		Theme.round(card, 8)
		card.Parent = scroll

		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.fromScale(0.5, 0.06)
		img.Size = UDim2.fromScale(0.72, 0.58)
		img.SizeConstraint = Enum.SizeConstraint.RelativeYY
		img.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
		img.BorderSizePixel = 0
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = Skins.thumb(skin.id)
		Theme.round(img, 6)
		img.Parent = card

		local nameLabel = Theme.label(card, skin.name, UDim2.fromScale(0.03, 0.66), UDim2.fromScale(0.94, 0.16))
		nameLabel.TextScaled = false
		nameLabel.TextSize = 13
		nameLabel.TextWrapped = true
		Theme.capText(nameLabel, 14)

		local equipButton = Theme.button(
			card,
			"Equip",
			UDim2.fromScale(0.5, 0.97),
			UDim2.fromScale(0.86, 0.2),
			function()
				equip(skin.id)
			end
		)
		equipButton.AnchorPoint = Vector2.new(0.5, 1)
		Theme.capText(equipButton, 14)

		table.insert(cards, { frame = card, name = skin.name, lname = skin.name:lower() })
	end
end

local function applyFilter(query: string)
	query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
	for _, card in cards do
		local match = query == "" or string.find(card.lname, query, 1, true) ~= nil
		if card.frame.Visible ~= match then
			card.frame.Visible = match
		end
	end
end

function Shop.init(parent: Instance)
	-- left-side panel (Agma-style), pops in when opened
	panel = Theme.panel(parent, UDim2.fromScale(0.015, 0.5), UDim2.fromScale(0.44, 0.84), Vector2.new(0, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Shop - Skins", UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.5, 0.07))
	title.TextColor3 = Theme.AccentColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 24)

	-- search box
	local search = Instance.new("TextBox")
	search.Position = UDim2.fromScale(0.03, 0.1)
	search.Size = UDim2.fromScale(0.58, 0.07)
	search.BackgroundColor3 = Color3.fromRGB(45, 50, 64)
	search.BorderSizePixel = 0
	search.Font = Theme.Font
	search.PlaceholderText = "Search skins..."
	search.Text = ""
	search.TextColor3 = Theme.TextColor
	search.PlaceholderColor3 = Theme.MutedText
	search.TextScaled = false
	search.TextSize = 16
	search.ClearTextOnFocus = false
	Theme.round(search, 8)
	Theme.capText(search, 18)
	search.Parent = panel
	search:GetPropertyChangedSignal("Text"):Connect(function()
		applyFilter(search.Text)
	end)

	-- "None" clears the skin
	local noneButton = Theme.button(panel, "None", UDim2.fromScale(0.63, 0.1), UDim2.fromScale(0.16, 0.07), function()
		equip(0)
	end)
	Theme.capText(noneButton, 16)

	-- paste-any-id box + Apply (equip any image not in the catalog)
	local idBox = Instance.new("TextBox")
	idBox.Position = UDim2.fromScale(0.63, 0.02)
	idBox.Size = UDim2.fromScale(0.34, 0.07)
	idBox.BackgroundColor3 = Color3.fromRGB(45, 50, 64)
	idBox.BorderSizePixel = 0
	idBox.Font = Theme.Font
	idBox.PlaceholderText = "Paste image ID..."
	idBox.Text = ""
	idBox.TextColor3 = Theme.TextColor
	idBox.PlaceholderColor3 = Theme.MutedText
	idBox.TextScaled = false
	idBox.TextSize = 14
	idBox.ClearTextOnFocus = false
	Theme.round(idBox, 8)
	Theme.capText(idBox, 16)
	idBox.Parent = panel
	local applyId = function()
		-- accept a raw id or a full rbxassetid://<id> paste
		local id = tonumber((idBox.Text:gsub("%D", "")))
		if id and id > 0 then
			equip(id)
		end
	end
	idBox.FocusLost:Connect(function(enter)
		if enter then
			applyId()
		end
	end)

	-- scrolling grid of cards (5 columns, cards ~1.5x taller than wide)
	scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromScale(0.03, 0.19)
	scroll.Size = UDim2.fromScale(0.94, 0.72)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(8, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	-- recompute pixel cell size from the scroll width so the grid is
	-- responsive without per-card aspect constraints
	local function resizeCells()
		local w = scroll.AbsoluteSize.X
		if w <= 0 then
			return
		end
		local cell = math.floor((w - 8 * 4 - 8) / 5)
		grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.5))
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCells)
	Shop._resizeCells = resizeCells

	local closeButton = Theme.button(panel, "Close", UDim2.fromScale(0.5, 0.99), UDim2.fromScale(0.2, 0.06), function()
		panel.Visible = false
	end)
	closeButton.AnchorPoint = Vector2.new(0.5, 1)
	Theme.capText(closeButton, 18)
end

function Shop.close()
	panel.Visible = false
end

function Shop.toggle()
	if not panel.Visible then
		build() -- lazy: only load thumbnails when the shop is first opened
		panel.Visible = true
		if Shop._resizeCells then
			Shop._resizeCells() -- AbsoluteSize is valid now the panel is shown
		end
		Theme.popIn(panel)
	else
		panel.Visible = false
	end
end

return Shop
