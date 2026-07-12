# Project notes for Claude

- Roblox 2D Agar.io-style game, Luau + Rojo. Source of truth is `src/` on disk;
  `default.project.json` maps it into Studio. See README.md for the
  architecture (server-authoritative, no physics, snapshot networking).
- **After finishing any change, ALWAYS give the user the exact Rojo commands
  to update their game** (git pull + `rojo serve` / `rojo build`), every time.
- Performance is the #1 constraint: no physics, no per-frame Instance
  creation, never move/resize GUI containers with many children, keep
  unreliable snapshot payloads under ~900 bytes. All tunables go in
  `src/shared/Config.luau`.
