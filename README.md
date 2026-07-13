# Agario 2D (Roblox)

A polished, low-latency 2D Agar.io-style game for Roblox, built performance-first:
**no physics, no 3D parts, no per-frame Instance creation** — the entire game is
server-side data simulated on a fixed tick, streamed as compact binary snapshots,
and rendered client-side with pooled, culled GUI frames.

## Syncing with Rojo

```bash
# install rojo 7+ (https://rojo.space), then from this folder:
rojo serve
```

In Studio: install the Rojo plugin → **Connect** → the `src/` tree syncs into the
right services automatically (`default.project.json` defines the mapping).
`rojo build -o Agario2D.rbxlx` also works for a one-shot place file.

### Manual placement (no Rojo)

| Folder | Where it goes in the Explorer |
|---|---|
| `src/shared/*` | `ReplicatedStorage/Shared` (folder of ModuleScripts) |
| `src/server/init.server.luau` | `ServerScriptService/Server` (a **Script**; the other `src/server/*.luau` files become ModuleScripts **inside** it) |
| `src/client/init.client.luau` | `StarterPlayer/StarterPlayerScripts/Client` (a **LocalScript**; the other `src/client/*.luau` files become ModuleScripts inside it, and `src/client/UI/` a ModuleScript named `UI` whose children are the UI modules) |

## The performance model (why it's not laggy)

1. **No physics, ever.** Cells, orbs, viruses and pellets are plain Luau tables
   (`x, y, mass, radius, id`). The server integrates movement and resolves
   collisions manually in a fixed 30 Hz tick (`Simulation.luau`). Roblox physics
   never runs; there is nothing for it to simulate.
2. **Server-authoritative.** All eat/split/merge/pop decisions happen on the
   server. Clients only send an aim point and rate-limited action requests
   (`Network.luau` validates everything), so modified clients can't cheat and
   there's nothing to desync.
3. **Spatial hashing.** A uniform grid (`SpatialHash.luau`) makes every
   collision/eat query O(nearby), never O(n²). Orbs live in a persistent hash
   (they don't move); movers are re-bucketed each tick.
4. **Snapshot networking + interpolation.** The server sends 20 Hz snapshots
   over an `UnreliableRemoteEvent`. Clients render ~100 ms in the past,
   interpolating between the two snapshots that bracket the render time
   (`WorldState.luau`) — motion is perfectly smooth at any FPS, and lost
   packets just interpolate to the next snapshot.
5. **Full-world snapshots (small map).** The map is small, so there is no
   interest culling: the server builds ONE snapshot of every dynamic entity per
   tick and `FireAllClients` it over a **reliable** RemoteEvent
   (`Snapshots.luau`). Reliable delivery + a stable full entity set is what
   keeps things flicker-free — an earlier interest/byte-budget scheme made
   entities near the packing cutoff blink in and out. Bandwidth is bounded by
   `MaxPellets` and the cell/virus counts; a much larger map would instead
   chunk across unreliable packets. The interpolator also snaps (never lerps)
   on implausibly large per-snapshot jumps (`MaxInterpJump`) so a reused id can
   never streak a phantom entity across the map.
6. **Orbs are deltas, not snapshots.** Orbs never move, so the high-rate channel
   never carries them: one reliable full sync on join (~5 KB), then tiny
   eat/respawn delta events. This is what keeps snapshots small enough for
   hundreds of orbs to be free.
7. **Compact payloads.** `SnapshotCodec.luau` packs everything into `buffer`s:
   u16 quantized positions (~0.12 world-unit resolution), fixed-point radii,
   u32-ms timestamps. A cell costs 9 bytes on the wire.
8. **Pooled, culled, leaf-only rendering.** One ScreenGui; every entity is a
   frame from a pre-allocated pool, acquired when it enters the view rect and
   released when it leaves — never created/destroyed per frame
   (`Renderer.luau`). Every entity is an independent *leaf* frame positioned
   in screen space: nothing with many children is ever moved or resized
   (parent resizes cascade a re-layout to every descendant and kill FPS).
   Writes are pixel-quantized and cached, so unchanged frames cost zero
   property sets, and labels use manual `TextSize` instead of `TextScaled`
   (which re-fits text on every resize).

### Tradeoffs to know about (and their knobs)

- **Snapshot byte cap**: with dozens of players stacked in one spot, farthest
  pellets/cells are culled first (`SnapshotByteBudget`, per-class priority in
  `Snapshots.luau`). Raise `SnapshotRate` or lower `InterestBase` if you ever
  see pop-in in mega-fights.
- **Viruses** render as a single ImageLabel sprite (`VirusImageId` in Config);
  experimentals are the same sprite with a teal tint.
- **Freeze (F)** is a toggle (works on all input devices); hold-mode would just
  move the remote calls to InputBegan/InputEnded.

## Controls (defaults — all remappable in Settings, persisted via DataStore)

| Key | Action |
|---|---|
| Space | Split all cells |
| D | Double split (2 split passes) |
| R | Triple split (3 split passes) |
| W | Feed — eject a mass pellet (hold to stream; feeds players, viruses, experimentals) |
| F | Freeze (toggle) — you creep slowly; splitting while frozen launches the piece out then it re-freezes |
| T | Pull Together — yank all your cells into one and merge |
| E | Speed — temporary movement boost |
| B | Respawn |
| C | Fixed Mouse (locks aim direction) |
| M | Menu / Settings |
| Mouse wheel | Zoom in/out (`ManualZoomMin/Max`, `ZoomWheelStep`) |

## What to test in Studio (mirrors the build milestones)

1. **Map + orbs**: Play Solo → dark map, grid, ~600 colored orbs, smooth pan.
2. **Movement**: press Play → your cell follows the mouse, slows as it grows,
   camera zooms out with size. Watch HUD FPS/Ping.
3. **Eating**: run over orbs → mass ticks up, orbs respawn elsewhere.
4. **Split/merge**: Space to split (halves launch toward cursor), D/R for
   multi-splits, pieces push apart, then glide back together and merge after
   the cooldown (`MergeTimeBase + mass * MergeTimePerMass`).
5. **Viruses**: feed a green virus 7 pellets (W) → it shoots a child virus.
   Fly a big cell into one → you pop into pieces. Teal **experimentals** also
   spray bonus orbs when fed. At 16 cells, viruses become safe food.
6. **UI**: leaderboard sorts by mass, name+mass render on cells, death screen,
   Spectate follows the leader, Shop equips skins.
7. **Settings**: rebind a key, rejoin → it persisted (needs Studio API access
   for DataStores; falls back to defaults silently otherwise).
8. **Multiplayer**: Studio → Test tab → 2+ players local server. Eat each other;
   check that a corner player receives only nearby entities.

## Every Config knob (`src/shared/Config.luau`)

All tuning lives in one module. Highlights (the file comments every field):

- **Map**: `MapWidth/MapHeight` (keep square), `GridStep`.
- **Rates**: `TickRate` (sim Hz), `SnapshotRate` (net Hz), `LeaderboardRate`.
- **Orbs**: `OrbCount`, `OrbMass`, `MaxExtraOrbs` (experimental bonus orbs).
- **Coins** (rare gold currency pickups): `CoinCount`, `CoinMass` (visual size),
  `CoinBonusMass`, `CoinColorIndex`, `CoinColor`.
- **Growth/speed**: `RadiusPerSqrtMass`, `StartMass`, `SpeedBase`,
  `SpeedExponent` (agar-style `speed = base * mass^exp`), `MassDecayRate`,
  `MassDecayMin`, `EatMassRatio` (1.25× to eat), `EatDepth` (overlap depth).
- **Split/merge**: `MaxCells`, `SplitMinMass`, `SplitImpulse`, `ImpulseDamping`,
  `MergeTimeBase` + `MergeTimePerMass`, `MergeOverlap`, `SeparationSoftness`,
  `SplitCooldown`, `MultiSplitCooldown`.
- **Feeding**: `EjectMinMass`, `EjectCostsMass` (off = feeding doesn't shrink
  your cell), `EjectMassLoss`, `EjectPelletMass`, `PelletSpeed`,
  `PelletFriction`, `PelletSelfEatDelay`, `FeedCooldown`, `MaxPellets`.
- **Viruses**: `VirusCount`, `ExperimentalCount`, `VirusMass`, `VirusEatRatio`,
  `VirusPopPieces`, `VirusFeedsToSplit`, `VirusSplitImpulse`, `VirusPushSpeed`,
  `VirusFriction`, `MaxViruses`, `ExperimentalOrbsPerFeed`.
- **Networking**: `SpatialCellSize`, `InterestBase/PerRadius/Max`,
  `SpectatorInterest`, `SnapshotByteBudget` (keep < 900!), `AimSendRate`.
- **Client feel**: `InterpolationDelay`, `ViewHeightBase/PerRadius/Min/Max`
  (auto zoom curve), `ManualZoomMin/Max` + `ZoomWheelStep` (wheel zoom),
  `SpectateViewHeight`, `ZoomSmoothing`, `CameraSmoothing`, `LabelMinPixels`,
  `CullMargin`, `MinRenderPixels` (skip drawing sub-N-pixel entities — the main
  far-zoom perf lever).
- **Cosmetics**: `Palette`, `VirusColor`, `ExperimentalColor`, `VirusImageId`,
  `DefaultKeybinds`.

## Project layout

```
default.project.json      Rojo mapping
src/
  shared/                 ReplicatedStorage.Shared (client + server)
    Config.luau           every tunable
    Util.luau             mass/radius/speed math
    SpatialHash.luau      uniform-grid broadphase
    SnapshotCodec.luau    binary pack/unpack (buffers, quantization)
    Remotes.luau          RemoteEvent registry (creates on server)
    Skins.luau            searchable image/decal skin catalog
    ShopItems.luau        (legacy, unused) cosmetic catalog stub
  server/                 ServerScriptService.Server
    init.server.luau      fixed-tick loop + bootstrap
    World.luau            authoritative state + spawn/despawn
    Simulation.luau       movement, eat, split/merge, viruses, feeding
    Snapshots.luau        interest management + packing + leaderboard
    Network.luau          remote validation, player lifecycle
    Keybinds.luau         DataStore persistence
  client/                 StarterPlayerScripts.Client
    init.client.luau      render loop + ping
    WorldState.luau       snapshot buffer + interpolation + orb mirror
    Camera.luau           2D pan/zoom (GUI-space, not the 3D camera)
    Renderer.luau         pooled frames, culling, grid, labels
    Input.luau            keybinds, aim, fixed-mouse, feed-hold
    UI/                   HUD, Leaderboard, Menu, Settings, Shop, Theme
```
