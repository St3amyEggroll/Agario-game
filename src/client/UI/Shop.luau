--[[
	Shop - the skin picker, split into three tabs:
	  FREE   - your default look: the plain cell + your Roblox avatar (headshot).
	  CUSTOM - the whole meme/skin catalog + a "paste any image id" box.
	  LEVEL  - the level-locked progression skins (a Lv badge + a locked Equip
	           button until you reach the required level).

	Equipping fires "setskin" (an image/decal id) or "setavatar" (your avatar);
	the server stores it on your roster slot and the renderer draws it on your cell.

	PERF: every card is built ONCE, on a deferred task the first time the shop
	opens (not on the click frame). Switching tabs / searching just toggles
	card.Visible - the UIGridLayout skips invisible children, so no rebuild and no
	gaps. rbxthumb thumbnails stream in on demand as cards scroll into view.
]]

local Players = game:GetService("Players")
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
local search: TextBox
local idBox: TextBox
local tabButtons: { [string]: TextButton } = {}
local currentTab = "custom"
local cards: { { frame: Frame, lname: string, category: string, level: number, equipButton: TextButton } } = {}
local built = false

local function currentLevel(): number
	return LevelCurve.levelForXp(WorldState.xp)
end

local function equip(id: number)
	Remotes.Action:FireServer("setskin", id)
end

-- Build one card into the scroll grid. `thumb` may be "" (blank swatch, used for
-- the "Default" free card). `reqLevel` > 0 adds a Lv badge + lock behaviour.
local function makeCard(category: string, name: string, thumb: string, reqLevel: number, onEquip: () -> ())
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Theme.Panel2Color
	card.BorderSizePixel = 0
	card.Visible = false
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
	img.Image = thumb
	Theme.round(img, 6)
	img.Parent = card

	local nameLabel = Theme.label(card, name, UDim2.fromScale(0.03, 0.66), UDim2.fromScale(0.94, 0.16))
	nameLabel.TextScaled = false
	nameLabel.TextSize = 13
	nameLabel.TextWrapped = true
	Theme.capText(nameLabel, 14)

	if reqLevel > 0 then
		local badge = Theme.label(card, "Lv " .. reqLevel, UDim2.fromScale(0.04, 0.04), UDim2.fromScale(0.5, 0.12))
		badge.BackgroundColor3 = Theme.AccentColor
		badge.BackgroundTransparency = 0.15
		badge.TextColor3 = Color3.new(1, 1, 1)
		badge.TextXAlignment = Enum.TextXAlignment.Center
		Theme.round(badge, 6)
		Theme.capText(badge, 12)
	end

	local equipButton = Theme.button(card, "Equip", UDim2.fromScale(0.5, 0.97), UDim2.fromScale(0.86, 0.2), function()
		-- locked level skins do nothing on click (the server would reject it anyway)
		if reqLevel > 0 and currentLevel() < reqLevel then
			return
		end
		onEquip()
	end)
	equipButton.AnchorPoint = Vector2.new(0.5, 1)
	Theme.capText(equipButton, 14)

	table.insert(cards, { frame = card, lname = name:lower(), category = category, level = reqLevel, equipButton = equipButton })
end

-- Create every card once, on first open.
local function build()
	if built then
		return
	end
	built = true

	-- FREE: the plain default cell + your Roblox avatar
	makeCard("free", "Default", "", 0, function()
		equip(0)
	end)
	makeCard("free", "My Avatar", Skins.thumb(-Players.LocalPlayer.UserId), 0, function()
		Remotes.Action:FireServer("setavatar")
	end)

	-- CUSTOM (free catalog skins) + LEVEL (level-locked). Skins.List holds both;
	-- entries with a `level` go in the Level tab.
	for _, skin in Skins.List do
		local reqLevel = skin.level or 0
		local category = reqLevel > 0 and "level" or "custom"
		makeCard(category, skin.name, Skins.thumb(skin.id), reqLevel, function()
			equip(skin.id)
		end)
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

-- Show only the current tab's cards that also match the search box.
local function applyFilter()
	local query = search.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
	for _, card in cards do
		local match = card.category == currentTab
			and (query == "" or string.find(card.lname, query, 1, true) ~= nil)
		if card.frame.Visible ~= match then
			card.frame.Visible = match
		end
	end
end

local function selectTab(tab: string)
	currentTab = tab
	for name, btn in tabButtons do
		local active = name == tab
		btn.TextColor3 = active and Theme.AccentColor or Theme.MutedText
		btn.BackgroundTransparency = active and 0.15 or 0.55
	end
	-- search applies to Custom + Level; the paste-id box is Custom-only; neither
	-- makes sense on Free (2 fixed cards)
	search.Visible = tab ~= "free"
	idBox.Visible = tab == "custom"
	search.Text = "" -- reset the filter so each tab opens showing everything
	applyFilter()
	if tab == "level" then
		Shop.refreshLocks()
	end
end

function Shop.init(parent: Instance)
	-- sits just LEFT of the center play card (its right edge ~0.36), pops in
	panel = Theme.panel(parent, UDim2.fromScale(0.36, 0.54), UDim2.fromScale(0.3, 0.56), Vector2.new(1, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Skins", UDim2.fromScale(0.03, 0.01), UDim2.fromScale(0.5, 0.055))
	title.TextColor3 = Theme.AccentColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 24)

	local closeBtn = Theme.button(panel, "\u{2715}", UDim2.fromScale(0.9, 0.01), UDim2.fromScale(0.08, 0.055), function()
		panel.Visible = false
	end)
	Theme.capText(closeBtn, 16)

	-- tab bar: Free | Custom | Level
	local tabDefs = { { "free", "Free" }, { "custom", "Custom" }, { "level", "Level" } }
	for i, def in tabDefs do
		local x = 0.03 + (i - 1) * 0.32
		local btn = Theme.button(panel, def[2], UDim2.fromScale(x, 0.075), UDim2.fromScale(0.30, 0.058), function()
			selectTab(def[1])
		end)
		Theme.capText(btn, 16)
		tabButtons[def[1]] = btn
	end

	-- search box (Custom + Level)
	search = Instance.new("TextBox")
	search.Position = UDim2.fromScale(0.03, 0.145)
	search.Size = UDim2.fromScale(0.58, 0.058)
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
	search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	-- paste-any-id box (Custom): equip any image/decal not in the catalog
	idBox = Instance.new("TextBox")
	idBox.Position = UDim2.fromScale(0.63, 0.145)
	idBox.Size = UDim2.fromScale(0.34, 0.058)
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
	idBox.FocusLost:Connect(function(enter)
		if not enter then
			return
		end
		-- accept a raw id or a full rbxassetid://<id> paste
		local id = tonumber((idBox.Text:gsub("%D", "")))
		if id and id > 0 then
			equip(id)
		end
	end)

	-- scrolling grid of cards (5 columns, cards ~1.5x taller than wide)
	scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromScale(0.03, 0.215)
	scroll.Size = UDim2.fromScale(0.94, 0.70)
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

	-- recompute pixel cell size from the scroll width so the grid is responsive
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
-- grid ONCE, on a deferred task so the thumbnail frames aren't created on the
-- click frame itself.
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
		selectTab(currentTab) -- apply the active tab's filter + level locks
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
