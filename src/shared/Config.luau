--[[
	Config - every tunable in one place.
	All distances are in abstract "world units" (the game is pure 2D data; nothing
	maps to studs or physics). All times are in seconds, all rates in Hz.
]]

local Config = {
	------------------------------------------------------------------ Map
	MapWidth = 16000,
	MapHeight = 16000, -- keep square: the renderer assumes a square map so circles stay circular
	GridStep = 250, -- background grid spacing (world units)

	------------------------------------------------------------------ Server timing
	TickRate = 30, -- fixed simulation timestep (Hz). Decoupled from rendering & snapshots.
	-- 30 Hz snapshots (one per tick): lower = less bandwidth but more input
	-- delay, since InterpolationDelay must cover ~2 snapshot intervals.
	-- Snapshots are now reliable + full-world, so this rate directly drives
	-- bandwidth (rate * total entities). 24 Hz is a good latency/bandwidth
	-- balance on a small map.
	SnapshotRate = 24,
	LeaderboardRate = 1, -- leaderboard broadcasts per second (reliable)

	------------------------------------------------------------------ Orbs (static food)
	OrbCount = 1800, -- baseline orb population; eaten orbs respawn elsewhere to keep this stable
	OrbMass = 1.2,
	MaxExtraOrbs = 300, -- cap on bonus (non-respawning) orbs spat out by Experimentals

	------------------------------------------------------------------ Coins (rare currency pickups)
	CoinCount = 12, -- how many coins exist at once (keep low - they're rare)
	CoinMass = 6, -- only sets the coin's visual radius; coins give currency, not mass
	CoinBonusMass = 0, -- extra mass granted on pickup (0 = pure currency)
	-- coins ride the orb sync channel: an orb whose color == CoinColorIndex is
	-- drawn gold by the client and gives a coin on the server
	CoinColorIndex = 255,
	CoinColor = Color3.fromRGB(255, 205, 55),

	------------------------------------------------------------------ Mass / size / speed
	RadiusPerSqrtMass = 4, -- radius = sqrt(mass) * this
	StartMass = 1000,
	-- speed = SpeedBase * mass ^ SpeedExponent. Agar's falloff is ~radius^-0.44
	-- and radius ~ sqrt(mass), so the MASS exponent is ~-0.22 (the old -0.44
	-- punished size twice as hard as agar and made everything feel slow):
	-- small cells dart around, big cells crawl but stay playable
	SpeedBase = 1344, -- 1.2x faster overall pace (also speeds up manual merging, which is movement-driven)
	SpeedExponent = -0.22,
	MassDecayRate = 0.002, -- fraction of mass lost per second, only above MassDecayMin
	MassDecayMin = 1100, -- above the 1000 spawn mass so fresh spawns don't immediately bleed
	EatMassRatio = 1.25, -- eater must be at least this many times the prey's mass
	EatDepth = 0.33, -- prey center must be inside eater radius minus prey radius * this

	------------------------------------------------------------------ Split / merge
	MaxCells = 32, -- max simultaneous cells per player
	MinCellMass = 100, -- a cell can never be smaller than this (split/pop keep every piece >= this)
	SplitMinMass = 200, -- a cell needs at least this much mass to split (so both halves stay >= MinCellMass)
	SplitImpulse = 936, -- launch speed of the new half (1.2x faster split)
	ImpulseDamping = 4, -- exponential damping rate for split/pop impulses
	-- merge timer scales with cell mass: little cells ~MergeTimeBase, growing
	-- with mass, capped at MergeTimeMax. (base 4s, +0.006/mass, cap 10s => a
	-- ~60-mass sliver ~4s, a ~1000-mass cell 10s.)
	MergeTimeBase = 4,
	MergeTimePerMass = 0.006,
	MergeTimeMax = 10,
	-- Merge once the SMALLER cell's center crosses INTO the bigger cell
	-- (d < big.r * this). 1.0 = the moment the small cell's center is inside the
	-- big one's edge, so it merges as soon as it's overlapping - it does NOT have
	-- to travel deep to the big cell's center (which happened at big sizes with a
	-- smaller fraction).
	MergeOverlap = 1.0,

	------------------------------------------------------------------ Abilities
	-- Pull Together: force all your cells mergeable and glide them into one.
	PullDuration = 1.4, -- seconds the forced-merge glide stays active
	-- (Pull Together no longer auto-moves cells - it only makes them mergeable
	-- early; you still steer them together. PullEaseMult kept for reference.)
	PullEaseMult = 5,
	PullCooldown = 5, -- min seconds between uses (server-enforced)
	-- Speed: temporary movement boost.
	SpeedBoostMult = 1.7, -- movement speed multiplier while active
	SpeedBoostDuration = 3, -- seconds
	SpeedBoostCooldown = 7, -- min seconds between uses (server-enforced)
	-- Freeze fully locks your aim movement (0 = can't steer while frozen). Split
	-- impulses still apply, so freeze-split pieces still launch out and settle.
	FreezeMoveFactor = 0,
	SeparationSoftness = 1.0, -- how solid same-player cells are before they can merge (1 = fully solid, never overlap)
	-- Cap how fast cells push apart (units/s). Without this, a deep overlap (a
	-- fresh split, or cells piling up) resolves in ONE tick = a big instant jump
	-- that reads as a teleport/blink. Capping makes separation a smooth push
	-- over a few ticks while still keeping cells solid. High enough that fast
	-- small cells can't overlap through it.
	SeparationMaxSpeed = 1000,
	SplitCooldown = 0.1, -- server-side rate limit on split actions (1.2x faster)
	MultiSplitCooldown = 0.21,

	------------------------------------------------------------------ Feed / ejected pellets
	EjectMinMass = 1, -- cell must have at least this much mass to eject (1 = W works at any size)
	EjectCostsMass = false, -- if false, feeding/ejecting does NOT shrink your own cell (free pellets)
	EjectMassLoss = 13, -- mass the cell loses per eject (only applied when EjectCostsMass)
	EjectPelletMass = 10, -- mass the pellet actually carries (difference is "wasted", like agar)
	PelletSpeed = 640,
	PelletFriction = 3.2, -- exponential slowdown rate; pellets come to rest
	PelletSelfEatDelay = 0.2, -- seconds before you can re-eat your own pellet (self-feed to grow, any size)
	FeedCooldown = 0.06, -- server-side rate limit on feed actions
	MaxPellets = 110, -- hard cap on live pellets (oldest recycled); bounds render/snapshot cost
	PelletLifetime = 12, -- seconds before an un-eaten pellet despawns (server deletes to stay light)

	------------------------------------------------------------------ Viruses / Experimentals
	VirusCount = 28,
	ExperimentalCount = 8,
	VirusMass = 110,
	VirusEatRatio = 1.15, -- a cell this many times the virus mass pops when overlapping it
	VirusPopPieces = 8, -- max extra pieces a popped cell shatters into (limited by MaxCells)
	VirusFeedsToSplit = 7, -- pellets required to make a virus shoot a child virus
	VirusSplitImpulse = 820,
	VirusPushSpeed = 110, -- how fast a fed virus drifts in the feed direction
	VirusFriction = 2.5,
	MaxViruses = 50, -- global cap so fed viruses can't overrun the map
	ExperimentalOrbsPerFeed = 2, -- bonus orbs an Experimental spits out per pellet fed

	------------------------------------------------------------------ Networking
	SpatialCellSize = 400, -- uniform grid bucket size for the spatial hash (server collision only)
	AimSendRate = 60, -- client -> server aim updates per second (tiny unreliable packets)
	-- Snapshots send the ENTIRE world to every client (no interest culling - the
	-- map is small). MaxInterpJump guards the interpolator: a per-snapshot
	-- position jump larger than this (world units) is treated as id-reuse /
	-- teleport and snapped instead of lerped, so no phantom entity streaks in.
	MaxInterpJump = 900,
	-- (Interest/byte-budget constants below are unused now that snapshots are
	-- full-world + reliable; kept only for reference / a future large-map mode.)

	------------------------------------------------------------------ Client rendering
	-- render this far behind the newest snapshot. Keep >= 2 snapshot intervals
	-- (2 / SnapshotRate): lower feels snappier but stutters on network jitter.
	InterpolationDelay = 0.11,
	ViewHeightBase = 1200, -- world units visible vertically at minimum size...
	ViewHeightPerRadius = 9, -- ...plus this per unit of your largest cell's radius (zoom out as you grow)
	ViewHeightMin = 1000,
	ViewHeightMax = 13000, -- allow zooming out to survey a big chunk of the (now 16k) map
	SpectateViewHeight = 2800,
	-- manual zoom (mouse wheel): multiplies the auto view height. >1 = zoomed out.
	-- The whole world is sent to every client, so ALL entities are visible at
	-- any zoom (no render distance).
	ManualZoomMin = 0.5,
	ManualZoomMax = 7.0,
	ZoomWheelStep = 1.15, -- zoom multiplier per wheel notch
	ZoomSmoothing = 4, -- exponential smoothing rate for zoom changes
	CameraSmoothing = 10, -- exponential smoothing rate for camera position
	LabelMinPixels = 26, -- hide name/mass labels on cells smaller than this on screen
	CullMargin = 300, -- extra world units around the view rect before culling (bigger = less edge pop when zoomed out)
	-- Skip drawing anything smaller than this many pixels on screen. When
	-- zoomed out, orbs/pellets become sub-pixel dots that cost draw calls for
	-- nothing; skipping them keeps far-zoom smooth. Kept low (1.5) + a wide
	-- hysteresis band (see Renderer) so entities don't blink near the cutoff.
	MinRenderPixels = 1.0, -- only orbs use this now (sub-pixel = invisible); pellets/viruses/cells always render

	------------------------------------------------------------------ Colors
	Palette = {
		Color3.fromRGB(237, 85, 85),
		Color3.fromRGB(240, 145, 60),
		Color3.fromRGB(245, 205, 70),
		Color3.fromRGB(130, 220, 90),
		Color3.fromRGB(70, 200, 160),
		Color3.fromRGB(80, 175, 240),
		Color3.fromRGB(110, 120, 245),
		Color3.fromRGB(175, 100, 240),
		Color3.fromRGB(240, 100, 200),
		Color3.fromRGB(245, 140, 160),
		Color3.fromRGB(160, 210, 235),
		Color3.fromRGB(200, 235, 130),
	},
	VirusColor = Color3.fromRGB(70, 200, 80),
	ExperimentalColor = Color3.fromRGB(70, 190, 170),
	VirusImageId = "rbxassetid://105917001657812", -- virus sprite (ImageLabel)

	------------------------------------------------------------------ Debug / testing
	Debug = true, -- shows testing helpers (+/- mass buttons) and lets the server accept them. Turn OFF for release!
	DebugMassPercent = 10, -- percent of current mass added/removed per debug button click

	------------------------------------------------------------------ Names / Chat
	MaxNameLength = 16, -- custom names are clamped to this many characters
	MaxChatLength = 60, -- chat messages are clamped to this many characters
	ChatBubbleTime = 5, -- seconds a chat bubble stays above a cell

	------------------------------------------------------------------ Default keybinds (remappable in Settings)
	DefaultKeybinds = {
		Split = "Space",
		MultiSplit = "D", -- performs 2 splits back-to-back
		TripleSplit = "R", -- performs 3 splits back-to-back
		Feed = "W",
		Freeze = "F", -- implemented as a toggle (hold-mode would just be InputBegan/Ended around the same remote)
		PullTogether = "T", -- ability: yank all your cells into one
		Speed = "E", -- ability: temporary speed boost
		Respawn = "B", -- instant respawn (drop everything, start fresh)
		ToMenu = "N", -- leave the game, back to the play menu
		FixedMouse = "C",
		Menu = "M", -- opens the settings panel
	},
}

return Config
