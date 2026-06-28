# Iso Game

Isometric game built on Godot 4.7. The world is **real 3D**; the isometric look
comes from an orthographic camera at a fixed 45°/30° angle (`main.gd`
`_build_camera`). This keeps the door open to leaning more 2D (billboards) or
more 3D (models) later without a rewrite.

## The autonomy loop (use this every change)

Two harness tools make changes self-verifiable:

```bash
tools/run_tests.sh     # headless logic tests; exits non-zero on failure
tools/screenshot.sh    # renders one deterministic frame -> screenshots/latest.png
```

After any logic change, run `run_tests.sh`. After any visual change, run
`screenshot.sh` and look at `screenshots/latest.png`. Both are deterministic
(fixed `SEED`, fixed camera, fixed frame count) so results are comparable run to
run.

`screenshot.sh` needs a display (rendering can't run under `--headless`); it
defaults to `DISPLAY=:1`.

## Determinism rules (don't break these)

- Seed RNG from `SEED` in `main.gd`. No unseeded `randi()`/`randf()`.
- Keep gameplay-affecting logic out of `_process` time deltas where a test needs
  to assert on it — prefer pure functions (see `scripts/iso_grid.gd`).
- Coordinate/grid math lives in `scripts/iso_grid.gd` as **static, stateless**
  functions so it stays unit-testable. Add a test in `tests/` for any new math.

## Layout

```
iso-game/
├── main.tscn / main.gd      # world built in code; --screenshot hook
├── scripts/iso_grid.gd      # pure grid<->world math (test-critical)
├── scripts/grid_world.gd    # grid state (blocked cells) + A* pathfinding (pure)
├── tests/test_*.gd          # headless SceneTree tests, exit 0/1
├── tools/run_tests.sh       # run all tests
├── tools/screenshot.sh      # deterministic frame capture
└── screenshots/latest.png   # generated; not the source of truth
```

## Mechanics

- **Click-to-move pathfinding.** Left-click a ground tile → `GridWorld.find_path`
  runs A* (4-directional) from the player's cell and the player walks the route,
  detouring around walls. Yellow markers show the planned path. Clicking a
  blocked cell (a wall) is ignored. Obstacle layout is built in
  `main.gd` `_build_obstacles`.

## Controls

- **Left click** a ground tile → player routes there around any walls.

## Conventions

- GDScript uses **tabs** (Godot default).
- Target Godot 4.7 API.
- New tests: `extends SceneTree`, do checks in `_initialize()`, `quit(0|1)`.
