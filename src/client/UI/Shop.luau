--[[
	Shop - searchable skin picker.

	Every entry in Shared/Skins is shown as a card (thumbnail + name + Equip).
	A search box filters cards by name; a "paste image id" box equips ANY Roblox
	image/decal id, so you're not limited to the catalog. Equipping fires the
	"setskin" action; the server stores the id on your roster slot and the
	renderer draws it on your cell.

	PERF: the ~100+ thumbnail ImageLabels are built ONCE, on a deferred task the
	first time the menu opens (not synchronously on the load frame). Filtering
	just toggles card.Visible - the UIGridLayout skips invisible children, so no
	rebuild and no gaps. rbxthumb thumbnails stream in on demand (and the grid
	clips off-screen cards, so their images only load when scrolled into view).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Skins)
local LevelCurve = require(Shared.Levels)
local Theme = require(script.Parent.Theme)
local WorldState = require(script.Parent.Parent.WorldState)

local Shop = {}

local panel: Frame
local scroll: ScrollingFrame
local cards: { { frame: Frame, lname: string, level: number, equipButton: TextButton } } = {}
local built = false

local function currentLevel(): number
	return LevelCurve.levelForXp(WorldState.xp)
end

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

		local reqLevel = skin.level or 0

		-- level-locked skins get a corner badge showing the unlock level
		if reqLevel > 0 then
			local badge = Theme.label(card, "Lv " .. reqLevel, UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.5, 0.12))
			badge.BackgroundColor3 = Theme.AccentColor
			badge.BackgroundTransparency = 0.15
			badge.TextColor3 = Color3.new(1, 1, 1)
			badge.TextXAlignment = Enum.TextXAlignment.Center
			Theme.round(badge, 6)
			Theme.capText(badge, 12)
		end

		local equipButton = Theme.button(
			card,
			"Equip",
			UDim2.fromScale(0.5, 0.97),
			UDim2.fromScale(0.86, 0.2),
			function()
				-- locked level skins do nothing on click (the server would reject it anyway)
				if reqLevel > 0 and currentLevel() < reqLevel then
					return
				end
				equip(skin.id)
			end
		)
		equipButton.AnchorPoint = Vector2.new(0.5, 1)
		Theme.capText(equipButton, 14)

		table.insert(cards, { frame = card, lname = skin.name:lower(), level = reqLevel, equipButton = equipButton })
	end
	Shop.refreshLocks()
end

-- Update every level-skin's Equip button to reflect the player's current level:
-- unlocked shows "Equip", locked shows a lock + the required level.
function Shop.refreshLocks()
	if not built then
		return
	end
	local lvl = currentLevel()
	for _, card in cards do
		if card.level > 0 then
			local locked = lvl < card.level
			local txt = locked and ("\u{1F512} Lv " .. card.level) or "Equip"
			if card.equipButton.Text ~= txt then
				card.equipButton.Text = txt
			end
			local col = locked and Theme.MutedText or Theme.TextColor
			if card.equipButton.TextColor3 ~= col then
				card.equipButton.TextColor3 = col
			end
		end
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
	-- sits just LEFT of the center play card (its right edge ~0.36), pops in
	panel = Theme.panel(parent, UDim2.fromScale(0.36, 0.54), UDim2.fromScale(0.3, 0.56), Vector2.new(1, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Shop - Skins", UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.5, 0.07))
	title.TextColor3 = Theme.AccentColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 24)

	local closeBtn = Theme.button(panel, "\u{2715}", UDim2.fromScale(0.9, 0.02), UDim2.fromScale(0.08, 0.06), function()
		panel.Visible = false
	end)
	Theme.capText(closeBtn, 16)

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
end

function Shop.close()
	if panel.Visible then
		panel.Visible = false
	end
end

-- Opened from the play-card Shop button. Pops the panel in and builds the card
-- grid ONCE, on a deferred task so the ~100 thumbnail frames aren't created on
-- the click frame itself.
function Shop.toggle()
	if panel.Visible then
		panel.Visible = false
		return
	end
	panel.Visible = true
	Theme.popIn(panel)
	task.defer(function()
		if not panel.Visible then
			return -- closed again before the deferred build ran
		end
		build() -- guarded by `built`: only creates the cards the first time
		Shop.refreshLocks() -- reflect the current level on the level-skin buttons
		if Shop._resizeCells then
			Shop._resizeCells() -- AbsoluteSize is valid now the panel is shown
		end
	end)
end

-- Keep the level-skin locks live while the shop is open: refresh only when the
-- player's level actually changes (cheap - no per-frame work otherwise).
local lastShownLevel = -1
function Shop.update(_dt: number)
	if not panel.Visible or not built then
		return
	end
	local lvl = currentLevel()
	if lvl ~= lastShownLevel then
		lastShownLevel = lvl
		Shop.refreshLocks()
	end
end

return Shop
