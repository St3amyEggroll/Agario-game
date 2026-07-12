--[[
	Config - every tunable in one place.
	All distances are in abstract "world units" (the game is pure 2D data; nothing
	maps to studs or physics). All times are in seconds, all rates in Hz.
]]

local Config = {
	------------------------------------------------------------------ Map
	MapWidth = 8000,
	MapHeight = 8000, -- keep square: the renderer assumes a square map so circles stay circular
	GridStep = 250, -- background grid spacing (world units)

	------------------------------------------------------------------ Server timing
	TickRate = 30, -- fixed simulation timestep (Hz). Decoupled from rendering & snapshots.
	SnapshotRate = 20, -- world snapshots per second per client (UnreliableRemoteEvent)
	LeaderboardRate = 1, -- leaderboard broadcasts per second (reliable)

	------------------------------------------------------------------ Orbs (static food)
	OrbCount = 600, -- baseline orb population; eaten orbs respawn elsewhere to keep this stable
	OrbMass = 1.2,
	MaxExtraOrbs = 200, -- cap on bonus (non-respawning) orbs spat out by Experimentals

	------------------------------------------------------------------ Mass / size / speed
	RadiusPerSqrtMass = 4, -- radius = sqrt(mass) * this
	StartMass = 25,
	SpeedBase = 760, -- speed = SpeedBase * mass ^ SpeedExponent (standard agar-style falloff)
	SpeedExponent = -0.44,
	MassDecayRate = 0.002, -- fraction of mass lost per second, only above MassDecayMin
	MassDecayMin = 120,
	EatMassRatio = 1.25, -- eater must be at least this many times the prey's mass
	EatDepth = 0.33, -- prey center must be inside eater radius minus prey radius * this

	------------------------------------------------------------------ Split / merge
	MaxCells = 16, -- max simultaneous cells per player
	SplitMinMass = 36, -- a cell needs at least this much mass to split
	SplitImpulse = 780, -- launch speed of the new half
	ImpulseDamping = 4, -- exponential damping rate for split/pop impulses
	MergeTimeBase = 10, -- seconds before split halves may re-merge...
	MergeTimePerMass = 0.02, -- ...plus this many seconds per point of mass
	MergeOverlap = 1.0, -- merge when centers are closer than max(r1, r2) * this
	SeparationSoftness = 0.45, -- how hard same-player cells push apart pre-merge (0..1)
	SplitCooldown = 0.12, -- server-side rate limit on split actions
	MultiSplitCooldown = 0.25,

	------------------------------------------------------------------ Feed / ejected pellets
	EjectMinMass = 36, -- cell must have at least this much mass to eject
	EjectMassLoss = 13, -- mass the cell loses per eject
	EjectPelletMass = 10, -- mass the pellet actually carries (difference is "wasted", like agar)
	PelletSpeed = 640,
	PelletFriction = 3.2, -- exponential slowdown rate; pellets come to rest
	PelletSelfEatDelay = 0.35, -- seconds before you can re-eat your own pellet
	FeedCooldown = 0.06, -- server-side rate limit on feed actions
	MaxPellets = 400, -- hard cap on live pellets (oldest are recycled)

	------------------------------------------------------------------ Viruses / Experimentals
	VirusCount = 14,
	ExperimentalCount = 4,
	VirusMass = 110,
	VirusEatRatio = 1.15, -- a cell this many times the virus mass pops when overlapping it
	VirusPopPieces = 8, -- max extra pieces a popped cell shatters into (limited by MaxCells)
	VirusFeedsToSplit = 7, -- pellets required to make a virus shoot a child virus
	VirusSplitImpulse = 820,
	VirusPushSpeed = 110, -- how fast a fed virus drifts in the feed direction
	VirusFriction = 2.5,
	MaxViruses = 26, -- global cap so fed viruses can't overrun the map
	ExperimentalOrbsPerFeed = 2, -- bonus orbs an Experimental spits out per pellet fed

	------------------------------------------------------------------ Networking
	SpatialCellSize = 250, -- uniform grid bucket size for the spatial hash
	InterestBase = 1600, -- interest radius = base + (largest own cell radius) * per-radius
	InterestPerRadius = 8,
	InterestMax = 3600,
	SpectatorInterest = 2400,
	-- UnreliableRemoteEvents drop payloads over ~900 bytes, so snapshots are packed
	-- against this byte budget (closest entities win; the rest are culled server-side).
	SnapshotByteBudget = 850,
	AimSendRate = 20, -- client -> server aim updates per second

	------------------------------------------------------------------ Client rendering
	InterpolationDelay = 0.1, -- render this far behind the newest snapshot (~2 snapshot intervals)
	ViewHeightBase = 1200, -- world units visible vertically at minimum size...
	ViewHeightPerRadius = 9, -- ...plus this per unit of your largest cell's radius (zoom out as you grow)
	ViewHeightMin = 1000,
	ViewHeightMax = 4200,
	SpectateViewHeight = 2800,
	ZoomSmoothing = 4, -- exponential smoothing rate for zoom changes
	CameraSmoothing = 10, -- exponential smoothing rate for camera position
	LabelMinPixels = 26, -- hide name/mass labels on cells smaller than this on screen
	CullMargin = 120, -- extra world units around the view rect before culling

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

	------------------------------------------------------------------ Default keybinds (remappable in Settings)
	DefaultKeybinds = {
		Split = "Space",
		MultiSplit = "D", -- performs 2 splits back-to-back
		TripleSplit = "R", -- performs 3 splits back-to-back
		Feed = "W",
		Freeze = "F", -- implemented as a toggle (hold-mode would just be InputBegan/Ended around the same remote)
		Respawn = "B",
		FixedMouse = "C",
		Menu = "M",
	},
}

return Config
