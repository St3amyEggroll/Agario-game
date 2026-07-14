--[[
	Shop - the customize panel, split into four tabs:
	  AVATAR - your Roblox avatar (headshot) as a cell skin.
	  COLOR  - pick your plain-cell colour from the palette (clears any skin).
	  CUSTOM - the whole meme/skin catalog + a "paste any image id" box.
	  LEVEL  - the level-locked progression skins (locked until you hit the level).

	The card you currently have on reads "Equipped"; the rest read "Equip".
	Equipping fires "setskin" / "setavatar" / "setcolor"; the server stores it on
	your roster slot and the renderer draws it on your cell.

	PERF: every card is built ONCE, on a deferred task the first time the panel
	opens. Switching tabs / searching just toggles card.Visible.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)
local Skins = require(Shared.Skins)
local Accessories = require(Shared.Accessories)
local LevelCurve = require(Shared.Levels)
local Theme = require(script.Parent.Theme)
local ColorPicker = require(script.Parent.ColorPicker)
local WorldState = require(script.Parent.Parent.WorldState)
local Sounds = require(script.Parent.Parent.Sounds)

local Shop = {}

local panel: Frame
local scroll: ScrollingFrame
local search: TextBox
local idBox: TextBox
local tabButtons: { [string]: TextButton } = {}
local currentTab = "custom"
local cards: {
	{ frame: Frame, lname: string, category: string, level: number, equipButton: TextButton, img: ImageLabel, matchKind: string, matchId: number }
} = {}
local built = false
local colorPickCard -- the COLOR tab's custom-picker card (its swatch tracks your live colour)

local function currentLevel(): number
	return LevelCurve.levelForXp(WorldState.xp)
end

local function currentSkin(): number
	return WorldState.skinForSlot(WorldState.mySlot or -1)
end

local function currentColor(): number
	local entry = WorldState.roster[WorldState.mySlot or -1]
	return entry and entry.c or 0
end

local function overlayKey(): string
	return table.concat(WorldState.overlaysForSlot(WorldState.mySlot or -1), ",")
end

-- Is this card the look currently equipped? Colour counts only when no skin is on;
-- overlays (accessories/avatar) count if the id is in the worn set (None never does).
local function isActive(card): boolean
	if card.matchKind == "colorpick" then
		return false
	elseif card.matchKind == "color" then
		return currentSkin() == 0 and currentColor() == card.matchId
	elseif card.matchKind == "overlay" then
		if card.matchId == 0 then
			return false
		end
		for _, id in WorldState.overlaysForSlot(WorldState.mySlot or -1) do
			if id == card.matchId then
				return true
			end
		end
		return false
	end
	return currentSkin() == card.matchId
end

local function equipSkin(id: number)
	Remotes.Action:FireServer("setskin", id)
	Sounds.play("equip")
end

local function equipAvatar()
	Remotes.Action:FireServer("setavatar")
	Sounds.play("equip")
end

local function equipColor(packed: number)
	Remotes.Action:FireServer("setcolor", packed)
	Sounds.play("equip")
end

local function equipAccessory(id: number)
	Remotes.Action:FireServer("setaccessory", id)
	Sounds.play("equip")
end

-- Build one card. opts: category, name, thumb (string?), swatchColor (Color3?),
-- reqLevel, matchKind ("skin"|"color"), matchId, onEquip.
local function makeCard(opts)
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
	img.BorderSizePixel = 0
	img.ScaleType = Enum.ScaleType.Fit
	if opts.swatchColor then
		img.Image = ""
		img.BackgroundColor3 = opts.swatchColor
		local rc = Instance.new("UICorner") -- round swatch: reads as a cell
		rc.CornerRadius = UDim.new(0.5, 0)
		rc.Parent = img
	else
		img.Image = opts.thumb or ""
		img.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
		Theme.round(img, 6)
	end
	img.Parent = card

	local nameLabel = Theme.label(card, opts.name, UDim2.fromScale(0.03, 0.66), UDim2.fromScale(0.94, 0.16))
	nameLabel.TextScaled = false
	nameLabel.TextSize = 13
	nameLabel.TextWrapped = true
	Theme.capText(nameLabel, 14)

	local reqLevel = opts.reqLevel or 0
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
		if reqLevel > 0 and currentLevel() < reqLevel then
			return -- locked
		end
		opts.onEquip()
	end)
	equipButton.AnchorPoint = Vector2.new(0.5, 1)
	Theme.capText(equipButton, 14)

	table.insert(cards, {
		frame = card,
		lname = opts.name:lower(),
		category = opts.category,
		level = reqLevel,
		equipButton = equipButton,
		img = img,
		matchKind = opts.matchKind,
		matchId = opts.matchId,
	})
end

-- Create every card once, on first open.
local function build()
	if built then
		return
	end
	built = true

	-- AVATAR: an overlay layer (over the skin) of your Roblox avatar. None clears
	-- ALL worn layers. Toggle on/off (multiple layers allowed).
	makeCard({
		category = "avatar",
		name = "None",
		swatchColor = Theme.Panel2Color,
		matchKind = "overlay",
		matchId = 0,
		onEquip = function()
			equipAccessory(0)
		end,
	})
	makeCard({
		category = "avatar",
		name = "My Avatar",
		thumb = Skins.thumb(-Players.LocalPlayer.UserId),
		matchKind = "overlay",
		matchId = -Players.LocalPlayer.UserId,
		onEquip = equipAvatar,
	})

	-- COLOR: a custom HSV picker card + one swatch per palette preset. Equipping
	-- any colour clears the skin so the plain coloured cell shows. Colours ride
	-- as a packed 0xRRGGBB int now (arbitrary colours, not a palette index).
	makeCard({
		category = "color",
		name = "Custom",
		swatchColor = Color3.new(1, 1, 1),
		matchKind = "colorpick",
		matchId = 0,
		onEquip = function()
			local packed = currentColor()
			local seed = (currentSkin() == 0 and typeof(packed) == "number") and Util.unpackColor(packed)
				or Color3.new(1, 1, 1)
			ColorPicker.open("Skin color", seed, function(c)
				equipColor(Util.packColor(c))
			end)
		end,
	})
	colorPickCard = cards[#cards]
	for i, col in Config.Palette do
		local packed = Util.packColor(col)
		makeCard({
			category = "color",
			name = "Color " .. i,
			swatchColor = col,
			matchKind = "color",
			matchId = packed,
			onEquip = function()
				equipColor(packed)
			end,
		})
	end

	-- CUSTOM (free catalog) + LEVEL (level-locked). Skins.List holds both.
	for _, skin in Skins.List do
		local reqLevel = skin.level or 0
		makeCard({
			category = reqLevel > 0 and "level" or "custom",
			name = skin.name,
			thumb = Skins.thumb(skin.id),
			reqLevel = reqLevel,
			matchKind = "skin",
			matchId = skin.id,
			onEquip = function()
				equipSkin(skin.id)
			end,
		})
	end

	-- ACCESSORIES: a "None" (clears all layers) + one per catalog accessory. Each
	-- toggles on/off; you can wear several at once (up to Config.MaxOverlays).
	makeCard({
		category = "accessory",
		name = "None",
		swatchColor = Theme.Panel2Color,
		matchKind = "overlay",
		matchId = 0,
		onEquip = function()
			equipAccessory(0)
		end,
	})
	for _, acc in Accessories.List do
		makeCard({
			category = "accessory",
			name = acc.name,
			thumb = Accessories.thumb(acc.id),
			matchKind = "overlay",
			matchId = acc.id,
			onEquip = function()
				equipAccessory(acc.id)
			end,
		})
	end

	Shop.refreshButtons()
end

-- Set each card's button to reflect state: locked level skins show a lock, the
-- currently-worn look shows "Equipped" (green), everything else shows "Equip".
function Shop.refreshButtons()
	if not built then
		return
	end
	local lvl = currentLevel()
	for _, card in cards do
		local btn = card.equipButton
		local txt, col
		if card.matchKind == "colorpick" then
			txt, col = "\u{1F3A8} Pick", Theme.AccentColor
		elseif card.level > 0 and lvl < card.level then
			txt, col = "\u{1F512} Lv " .. card.level, Theme.MutedText
		elseif isActive(card) then
			-- overlays toggle, so an active one shows "Unequip"; base looks show "Equipped"
			if card.matchKind == "overlay" then
				txt, col = "Unequip", Theme.Danger
			else
				txt, col = "Equipped", Theme.Green
			end
		else
			txt, col = "Equip", Theme.TextColor
		end
		if btn.Text ~= txt then
			btn.Text = txt
		end
		if btn.TextColor3 ~= col then
			btn.TextColor3 = col
		end
	end
	-- keep the custom-picker swatch showing your current cell colour
	if colorPickCard and colorPickCard.img then
		local packed = currentColor()
		if typeof(packed) == "number" then
			colorPickCard.img.BackgroundColor3 = Util.unpackColor(packed)
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
	-- search applies to Custom + Level; the paste-id box is Custom-only
	search.Visible = tab == "custom" or tab == "level"
	idBox.Visible = tab == "custom"
	search.Text = "" -- reset the filter so each tab opens showing everything
	applyFilter()
	Shop.refreshButtons()
end

function Shop.init(parent: Instance)
	-- sits just LEFT of the center play card (its right edge ~0.36), pops in
	panel = Theme.panel(parent, UDim2.fromScale(0.36, 0.54), UDim2.fromScale(0.3, 0.56), Vector2.new(1, 0.5))
	panel.Visible = false

	local title = Theme.label(panel, "Customize", UDim2.fromScale(0.03, 0.01), UDim2.fromScale(0.5, 0.055))
	title.TextColor3 = Theme.AccentColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 24)

	Theme.closeButton(panel, UDim2.fromScale(0.9, 0.01), UDim2.fromScale(0.08, 0.055), function()
		panel.Visible = false
	end)

	-- tab bar: Avatar | Color | Skins | Level | Accessory
	local tabDefs =
		{ { "avatar", "Avatar" }, { "color", "Color" }, { "custom", "Skins" }, { "level", "Level" }, { "accessory", "Accessory" } }
	for i, def in tabDefs do
		local x = 0.02 + (i - 1) * 0.196
		local btn = Theme.button(panel, def[2], UDim2.fromScale(x, 0.075), UDim2.fromScale(0.185, 0.058), function()
			selectTab(def[1])
		end)
		Theme.capText(btn, 13)
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
		local id = tonumber((idBox.Text:gsub("%D", "")))
		if id and id > 0 then
			equipSkin(id)
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

function Shop.toggle()
	if panel.Visible then
		panel.Visible = false
		return
	end
	panel.Visible = true
	Theme.popIn(panel)
	task.defer(function()
		if not panel.Visible then
			return
		end
		build() -- guarded by `built`: only creates the cards the first time
		selectTab(currentTab) -- apply the active tab's filter + button states
		if Shop._resizeCells then
			Shop._resizeCells()
		end
	end)
end

-- Keep buttons live while open: refresh only when the level / equipped look
-- actually changes (cheap - no per-frame work otherwise).
local lastLevel, lastSkin, lastColor, lastOKey = -1, math.huge, -1, "\0"
function Shop.update(_dt: number)
	if not panel.Visible or not built then
		return
	end
	local lvl, skin, color, okey = currentLevel(), currentSkin(), currentColor(), overlayKey()
	if lvl ~= lastLevel or skin ~= lastSkin or color ~= lastColor or okey ~= lastOKey then
		lastLevel, lastSkin, lastColor, lastOKey = lvl, skin, color, okey
		Shop.refreshButtons()
	end
end

return Shop
