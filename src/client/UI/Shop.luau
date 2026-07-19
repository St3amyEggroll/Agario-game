--[[
	Shop - the customize panel, split into four tabs:
	  AVATAR - your Roblox avatar (headshot) as a cell skin.
	  COLOR  - one big HSV picker: drag to set your plain-cell colour (clears any skin).
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
local currentTab = "custom" -- Color | Skins | Avatar | Level | Accessory
local cards: {
	{ frame: Frame, lname: string, category: string, level: number, equipButton: TextButton, matchKind: string, matchId: any }
} = {}
local built = false
local abilityById = {} -- id -> Config.Abilities def (price/name/color lookup)
for _, a in Config.Abilities do
	abilityById[a.id] = a
end
local colorPanel: Frame -- the COLOR tab's inline picker (shown instead of the card grid)
local colorWidget -- ColorPicker widget inside colorPanel
local updateColorPreview: (Color3) -> () -- refresh the picker's preview swatch + hex
local randomColorEnabled = false
local randomColorButton: TextButton? = nil
local shopCoinLabel: TextLabel? = nil

local function commas(n: number): string
	local out = tostring(math.max(0, math.floor(n + 0.5))):reverse():gsub("(%d%d%d)", "%1,")
	return (out:reverse():gsub("^,", ""))
end

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

local function ownedAbilityCount(): number
	local n = 0
	for _ in WorldState.abilities.owned do
		n += 1
	end
	return n
end

-- "6000" -> "6,000" for Gold prices
local function commaNum(n: number): string
	local out = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,")
	return (out:reverse():gsub("^,", ""))
end

-- Is this card the look currently equipped? Colour counts only when no skin is on;
-- overlays (accessories/avatar) count if the id is in the worn set (None never does).
local function isActive(card): boolean
	if card.matchKind == "ability" then
		return WorldState.ownsAbility(card.matchId)
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

local function equipAccessory(id: number)
	Remotes.Action:FireServer("setaccessory", id)
	Sounds.play("equip")
end

local function buyAbility(id: string)
	Remotes.Action:FireServer("buyability", id)
	Sounds.play("click")
end

local function setRandomColor(enabled: boolean)
	randomColorEnabled = enabled
	Remotes.Action:FireServer("setrandomcolor", enabled)
	if randomColorButton then
		randomColorButton.Text = "Random Cell Color: " .. (enabled and "On" or "Off")
		randomColorButton.TextColor3 = enabled and Theme.Green or Theme.MutedText
	end
end

-- Build one card. opts: category, name, thumb (string?), swatchColor (Color3?),
-- reqLevel, matchKind ("skin"|"color"), matchId, onEquip.
local function makeCard(opts)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(8, 15, 25)
	card.BackgroundTransparency = 0.02
	card.BorderSizePixel = 0
	card.Visible = false
	Theme.round(card, 14)
	local cardEdge = Theme.stroke(card, Color3.fromRGB(63, 84, 112), 0.5)
	cardEdge.Thickness = 1.2
	card.Parent = scroll

	local img = Instance.new("ImageLabel")
	img.AnchorPoint = Vector2.new(0.5, 0)
	img.Position = UDim2.fromScale(0.5, 0.04)
	img.Size = UDim2.fromScale(0.68, 0.54)
	img.SizeConstraint = Enum.SizeConstraint.RelativeYY
	img.BorderSizePixel = 0
	-- Skins/avatar fill the circular mask edge-to-edge so pale square source
	-- corners cannot show over the card. Transparent accessories keep Fit.
	img.ScaleType = opts.category == "accessory" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
	img.ClipsDescendants = true
	img.Image = opts.thumb or ""
	img.BackgroundColor3 = opts.swatchColor or Color3.fromRGB(35, 40, 54)
	local circle = Instance.new("UICorner")
	circle.CornerRadius = UDim.new(0.5, 0)
	circle.Parent = img
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.DominantAxis = Enum.DominantAxis.Height
	aspect.Parent = img
	local ring = Instance.new("UIStroke")
	ring.Color = Theme.Purple
	ring.Thickness = 2
	ring.Transparency = 0.12
	ring.Parent = img
	img.Parent = card
	-- Hide genuinely broken free/catalog thumbnails, but never hide Level
	-- rewards. Roblox thumbnail loading can be delayed in Studio; the old global
	-- timeout incorrectly made every Level skin disappear after ten seconds.
	if opts.thumb and opts.category == "custom" then
		task.delay(10, function()
			if card.Parent and not img.IsLoaded then
				card:SetAttribute("BrokenThumbnail", true)
				card.Visible = false
			end
		end)
	end
	if opts.iconText then
		local icon = Theme.label(img, opts.iconText, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1))
		icon.TextXAlignment = Enum.TextXAlignment.Center
		icon.TextColor3 = Theme.Danger
		icon.TextScaled = true
		Theme.capText(icon, 44)
	end

	local nameLabel = Theme.label(card, opts.name, UDim2.fromScale(0.05, 0.60), UDim2.fromScale(0.9, 0.12))
	nameLabel.TextScaled = false
	nameLabel.TextSize = 13
	nameLabel.TextWrapped = false
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	Theme.capText(nameLabel, 13)

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

	local equipButton = Theme.button(card, "Equip", UDim2.fromScale(0.5, 0.97), UDim2.fromScale(0.86, 0.17), function()
		if reqLevel > 0 and currentLevel() < reqLevel then
			return -- locked
		end
		if opts.matchKind == "skin" and currentSkin() == opts.matchId then
			equipSkin(0) -- custom and level skins can both be unequipped
		else
			opts.onEquip()
		end
	end)
	equipButton.AnchorPoint = Vector2.new(0.5, 1)
	equipButton.BackgroundColor3 = Color3.fromRGB(18, 28, 44)
	Theme.capText(equipButton, 14)

	table.insert(cards, {
		frame = card,
		lname = opts.name:lower(),
		category = opts.category,
		level = reqLevel,
		equipButton = equipButton,
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

	-- AVATAR: a reliable live headshot generated from the local player's real
	-- Roblox account. The server derives the UserId itself, so it cannot be spoofed.
	local avatarOverlayId = -Players.LocalPlayer.UserId
	makeCard({
		category = "avatar",
		name = "Roblox Avatar",
		thumb = Skins.thumb(avatarOverlayId),
		matchKind = "overlay",
		matchId = avatarOverlayId,
		onEquip = equipAvatar,
	})

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

	-- ACCESSORIES: "Remove All" clears every worn layer; the remaining cards
	-- toggle individually (up to Config.MaxOverlays).
	makeCard({
		category = "accessory",
		name = "Remove All",
		swatchColor = Theme.Panel2Color,
		iconText = "X",
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

	-- ABILITIES: bought with Gold. Owned ones show "Owned" and appear in the dock.
	for _, ab in Config.Abilities do
		makeCard({
			category = "abilities",
			name = ab.name,
			swatchColor = ab.color,
			matchKind = "ability",
			matchId = ab.id,
			onEquip = function()
				buyAbility(ab.id)
			end,
		})
	end

	Shop.refreshButtons()
end

-- Set each card's button to reflect state. Active cosmetics use a distinct
-- rose-red Remove treatment instead of the old green-looking Unequip button.
function Shop.refreshButtons()
	if not built then
		return
	end
	local lvl = currentLevel()
	for _, card in cards do
		local btn = card.equipButton
		local locked = card.level > 0 and lvl < card.level
		local active = not locked and isActive(card)
		local txt: string
		local textColor: Color3
		local background: Color3
		local edgeColor: Color3
		if card.matchKind == "ability" then
			-- abilities are BOUGHT with Gold, then permanently "Owned" (no equip)
			if WorldState.ownsAbility(card.matchId) then
				txt = "Owned"
				textColor = Theme.TextColor
				background = Color3.fromRGB(18, 44, 28)
				edgeColor = Theme.Green
			else
				local def = abilityById[card.matchId]
				local price = def and def.price or 0
				local afford = (WorldState.coins or 0) >= price
				txt = "Buy " .. commaNum(price)
				textColor = afford and Theme.TextColor or Theme.MutedText
				background = Color3.fromRGB(18, 28, 44)
				edgeColor = afford and Theme.AccentColor or Color3.fromRGB(69, 91, 121)
			end
		elseif locked then
			txt = "\u{1F512} Lv " .. card.level
			textColor = Theme.MutedText
			background = Color3.fromRGB(15, 23, 36)
			edgeColor = Color3.fromRGB(64, 78, 102)
		elseif active then
			txt = "Remove"
			textColor = Color3.fromRGB(255, 164, 178)
			background = Color3.fromRGB(73, 18, 34)
			edgeColor = Color3.fromRGB(255, 75, 112)
		else
			txt = "Equip"
			textColor = Theme.TextColor
			background = Color3.fromRGB(18, 28, 44)
			edgeColor = Color3.fromRGB(69, 91, 121)
		end
		btn.Text = txt
		btn.TextColor3 = textColor
		btn.BackgroundColor3 = background
		for _, child in btn:GetChildren() do
			if child:IsA("UIStroke") then
				child.Color = edgeColor
				child.Transparency = active and 0.18 or 0.5
				child.Thickness = active and 1.5 or 1
			end
		end
	end
end

-- Show only the current tab's cards that also match the search box.
local function applyFilter()
	local query = search.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
	for _, card in cards do
		local match = not card.frame:GetAttribute("BrokenThumbnail")
			and card.category == currentTab
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
		btn.TextColor3 = active and Color3.fromRGB(250, 247, 255) or Theme.MutedText
		btn.BackgroundColor3 = active and Color3.fromRGB(63, 28, 102) or Color3.fromRGB(9, 17, 28)
		btn.BackgroundTransparency = active and 0.05 or 0.12
		for _, child in btn:GetChildren() do
			if child:IsA("UIStroke") then
				child.Color = active and Theme.Purple or Color3.fromRGB(61, 79, 104)
				child.Transparency = active and 0.08 or 0.55
				child.Thickness = active and 1.8 or 1
			end
		end
	end
	-- the Colour tab swaps the card grid for the inline picker
	if colorPanel then
		colorPanel.Visible = tab == "color"
		scroll.Visible = tab ~= "color"
	end
	if tab == "color" and colorWidget then
		local packed = currentColor()
		local c = (typeof(packed) == "number" and packed > 0) and Util.unpackColor(packed) or Color3.new(1, 1, 1)
		colorWidget.setColor(c)
		updateColorPreview(c)
	end
	-- search applies to Custom + Level; the paste-id box is Custom-only
	search.Visible = tab == "custom" or tab == "level"
	idBox.Visible = tab == "custom"
	search.Text = "" -- reset the filter so each tab opens showing everything
	applyFilter()
	Shop.refreshButtons()
end

function Shop.init(parent: Instance)
	-- A centered, proportionally scaled modal. Keeping a fixed design ratio
	-- prevents the catalog from stretching on ultrawide screens.
	panel = Theme.panel(parent, UDim2.fromScale(0.5, 0.52), UDim2.fromOffset(680, 620), Vector2.new(0.5, 0.5))
	Theme.responsiveSize(panel, Vector2.new(680, 620), Vector2.new(20, 20))
	Theme.sidePopout(panel, "left", 0.56)
	Theme.decoratePanel(panel)
	panel.Visible = false

	local title = Theme.label(panel, 'CUSTOMIZE <font color="#5BDCB6">CELL</font>', UDim2.fromScale(0.04, 0.025), UDim2.fromScale(0.62, 0.06))
	title.RichText = true
	title.TextColor3 = Theme.TextColor
	title.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(title, 26)

	Theme.closeButton(panel, UDim2.fromScale(0.91, 0.02), UDim2.fromScale(0.065, 0.065), function()
		panel.Visible = false
	end)

	-- Six tabs: the redesign's five cosmetic tabs plus an Abilities tab.
	local tabDefs = {
		{ "color", "Color" },
		{ "custom", "Skins" },
		{ "avatar", "Avatar" },
		{ "level", "Level" },
		{ "accessory", "Access." },
		{ "abilities", "Ability" },
	}
	for i, def in tabDefs do
		local x = 0.02 + (i - 1) * 0.163
		local btn = Theme.button(panel, string.upper(def[2]), UDim2.fromScale(x, 0.105), UDim2.fromScale(0.155, 0.072), function()
			selectTab(def[1])
		end)
		Theme.capText(btn, 12)
		tabButtons[def[1]] = btn
	end

	-- search box (Custom + Level)
	search = Instance.new("TextBox")
	search.Position = UDim2.fromScale(0.035, 0.195)
	search.Size = UDim2.fromScale(0.58, 0.072)
	search.BackgroundColor3 = Color3.fromRGB(7, 14, 24)
	search.BorderSizePixel = 0
	search.Font = Theme.Font
	search.PlaceholderText = "Search skins..."
	search.Text = ""
	search.TextColor3 = Theme.TextColor
	search.PlaceholderColor3 = Theme.MutedText
	search.TextScaled = false
	search.TextSize = 16
	search.ClearTextOnFocus = false
	Theme.round(search, 11)
	Theme.stroke(search, Color3.fromRGB(64, 83, 110), 0.4)
	Theme.capText(search, 18)
	search.Parent = panel
	search:GetPropertyChangedSignal("Text"):Connect(applyFilter)

	-- paste-any-id box (Custom): equip any image/decal not in the catalog
	idBox = Instance.new("TextBox")
	idBox.Position = UDim2.fromScale(0.63, 0.195)
	idBox.Size = UDim2.fromScale(0.335, 0.072)
	idBox.BackgroundColor3 = Color3.fromRGB(7, 14, 24)
	idBox.BorderSizePixel = 0
	idBox.Font = Theme.Font
	idBox.PlaceholderText = "Paste image ID..."
	idBox.Text = ""
	idBox.TextColor3 = Theme.TextColor
	idBox.PlaceholderColor3 = Theme.MutedText
	idBox.TextScaled = false
	idBox.TextSize = 14
	idBox.ClearTextOnFocus = false
	Theme.round(idBox, 11)
	Theme.stroke(idBox, Color3.fromRGB(64, 83, 110), 0.4)
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
	scroll.Position = UDim2.fromScale(0.035, 0.285)
	scroll.Size = UDim2.fromScale(0.93, 0.57)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellPadding = UDim2.fromOffset(12, 12)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local function resizeCells()
		local w = scroll.AbsoluteSize.X
		if w <= 0 then
			return
		end
		local cell = math.floor((w - 12 * 3 - 8) / 4)
		grid.CellSize = UDim2.fromOffset(cell, math.floor(cell * 1.36))
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(resizeCells)
	Shop._resizeCells = resizeCells

	-- Bottom-left wallet from reference #3: live balance, plus action, divider,
	-- and the generated coin-stack artwork.
	local wallet = Theme.panel(panel, UDim2.fromScale(0.5, 0.88), UDim2.fromScale(0.78, 0.095), Vector2.new(0.5, 0))
	wallet.BackgroundColor3 = Color3.fromRGB(3, 8, 15)
	wallet.BackgroundTransparency = 0.01

	local walletCoin = Instance.new("ImageLabel")
	walletCoin.Position = UDim2.fromOffset(55, 8)
	walletCoin.Size = UDim2.fromOffset(42, 42)
	walletCoin.BackgroundTransparency = 1
	walletCoin.Image = "rbxassetid://90476441150192"
	walletCoin.ScaleType = Enum.ScaleType.Fit
	walletCoin.Parent = wallet

	shopCoinLabel = Theme.label(wallet, "0", UDim2.fromOffset(107, 5), UDim2.fromOffset(140, 46))
	shopCoinLabel.Font = Enum.Font.GothamBold
	shopCoinLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(shopCoinLabel, 24)

	local walletPlus = Theme.button(wallet, "+", UDim2.fromOffset(265, 11), UDim2.fromOffset(36, 36), function() end)
	walletPlus.BackgroundColor3 = Color3.fromRGB(54, 211, 151)
	walletPlus.BackgroundTransparency = 0
	walletPlus.TextColor3 = Color3.fromRGB(5, 45, 35)
	Theme.capText(walletPlus, 22)

	local walletDivider = Instance.new("Frame")
	walletDivider.Position = UDim2.fromOffset(325, 10)
	walletDivider.Size = UDim2.fromOffset(1, 38)
	walletDivider.BackgroundColor3 = Color3.fromRGB(66, 82, 106)
	walletDivider.BackgroundTransparency = 0.5
	walletDivider.BorderSizePixel = 0
	walletDivider.Parent = wallet

	local coinStack = Instance.new("ImageLabel")
	coinStack.Position = UDim2.fromOffset(345, 1)
	coinStack.Size = UDim2.fromOffset(92, 56)
	coinStack.BackgroundTransparency = 1
	coinStack.Image = "rbxassetid://120596015617796"
	coinStack.ScaleType = Enum.ScaleType.Fit
	coinStack.Parent = wallet

	-- COLOR tab: one big inline HSV picker (fills the grid area). No palette
	-- options - drag to pick any colour and it applies to your cell live.
	colorPanel = Instance.new("Frame")
	colorPanel.Position = scroll.Position
	colorPanel.Size = scroll.Size
	colorPanel.BackgroundTransparency = 1
	colorPanel.Visible = false
	colorPanel.Parent = panel

	local pickerRegion = Instance.new("Frame")
	pickerRegion.Position = UDim2.fromScale(0.02, 0)
	pickerRegion.Size = UDim2.fromScale(0.96, 0.8)
	pickerRegion.BackgroundTransparency = 1
	pickerRegion.Parent = colorPanel

	local preview = Instance.new("Frame")
	preview.Position = UDim2.fromScale(0.02, 0.85)
	preview.Size = UDim2.fromScale(0.14, 0.14)
	preview.BackgroundColor3 = Color3.new(1, 1, 1)
	preview.BorderSizePixel = 0
	local par = Instance.new("UIAspectRatioConstraint")
	par.AspectRatio = 1
	par.Parent = preview
	Theme.round(preview, 999)
	Theme.stroke(preview, Color3.new(1, 1, 1), 0.5)
	preview.Parent = colorPanel

	local hexLabel = Theme.label(colorPanel, "#FFFFFF", UDim2.fromScale(0.2, 0.86), UDim2.fromScale(0.3, 0.12))
	hexLabel.TextXAlignment = Enum.TextXAlignment.Left
	Theme.capText(hexLabel, 22)

	randomColorButton = Theme.button(
		colorPanel,
		"Random Cell Color: Off",
		UDim2.fromScale(0.53, 0.85),
		UDim2.fromScale(0.44, 0.14),
		function()
			setRandomColor(not randomColorEnabled)
			Sounds.play("click")
		end
	)
	randomColorButton.TextColor3 = Theme.MutedText
	Theme.capText(randomColorButton, 16)

	updateColorPreview = function(c: Color3)
		preview.BackgroundColor3 = c
		hexLabel.Text = string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end

	local lastColorSend = 0
	local colorCommitSeq = 0
	local function sendColor(c: Color3)
		if randomColorEnabled then
			setRandomColor(false) -- choosing a specific color disables random spawn colors
		end
		Remotes.Action:FireServer("setcolor", Util.packColor(c))
	end
	colorWidget = ColorPicker.newWidget(pickerRegion, {
		onChange = function(c)
			updateColorPreview(c)
			local now = os.clock()
			if now - lastColorSend >= 0.15 then -- throttle live sends (server cools at 0.2s)
				lastColorSend = now
				sendColor(c)
			end
		end,
		onCommit = function(c)
			updateColorPreview(c)
			Sounds.play("equip")
			sendColor(c)
			lastColorSend = os.clock()
			-- guarantee the FINAL colour lands even if this commit fell inside the
			-- server's setcolor cooldown (which silently drops the extra)
			colorCommitSeq += 1
			local seq = colorCommitSeq
			task.delay(0.25, function()
				if seq == colorCommitSeq then
					sendColor(c)
				end
			end)
		end,
	})
end

function Shop.isVisible(): boolean
	return panel ~= nil and panel.Visible
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
local lastCoins, lastOwned = -1, -1
function Shop.update(_dt: number)
	if not panel.Visible or not built then
		return
	end
	if shopCoinLabel then
		shopCoinLabel.Text = commas(WorldState.coins or 0)
	end
	local lvl, skin, color, okey = currentLevel(), currentSkin(), currentColor(), overlayKey()
	-- coins + owned-ability count drive the Abilities tab's Buy/Owned states
	local coins, owned = WorldState.coins or 0, ownedAbilityCount()
	if
		lvl ~= lastLevel
		or skin ~= lastSkin
		or color ~= lastColor
		or okey ~= lastOKey
		or coins ~= lastCoins
		or owned ~= lastOwned
	then
		lastLevel, lastSkin, lastColor, lastOKey = lvl, skin, color, okey
		lastCoins, lastOwned = coins, owned
		Shop.refreshButtons()
	end
end

return Shop
