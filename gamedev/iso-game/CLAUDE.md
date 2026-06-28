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
├── assets/                  # .glb models (CC0; see assets/CREDITS.md)
├── scripts/iso_grid.gd      # pure grid<->world math (test-critical)
├── scripts/grid_world.gd    # grid state (blocked cells) + A* pathfinding (pure)
├── scripts/enemy_brain.gd   # pure enemy FSM (PATROL/CHASE/ATTACK/RETURN), tested
├── scripts/enemy.gd         # Enemy node: runs the FSM + executes each state
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

- **Enemy AI (finite state machine).** Enemies run an enum FSM
  (`scripts/enemy_brain.gd`, PATROL → CHASE → ATTACK → RETURN). Transitions are a
  **pure function** of the enemy/player cells + A*-reachability (so it's unit
  tested in `tests/test_enemy_brain.gd`); `scripts/enemy.gd` executes the current
  state (wander / A*-chase / stop-and-face / walk home). Enemies are tinted by
  state for at-a-glance verification: **grey** patrol, **orange** chase, **red**
  attack, **blue** return. Spawned in `main.gd` `_build_enemies`. Concept adapted
  from the kidscancode "changing behaviors" recipe.

## Character

- The player is **`assets/explorer.glb`** — a procedural low-poly explorer
  (CC0; see `assets/CREDITS.md`). Loaded in `main.gd` `_build_player` and turned
  to face its movement direction (`_face_toward`). Tune size with `PLAYER_SCALE`;
  swap models via `PLAYER_MODEL`. Asset workflow: `../BLENDER_MCP.md`.
- It's a **static mesh** (not rigged) — placeholder until the game is further
  along. The animation hook is already wired: `_setup_animation` finds the
  model's `AnimationPlayer` and `_update_anim` plays **Walk** while moving /
  **Idle** when stopped — a no-op now, automatically active once `PLAYER_MODEL`
  points at a model that ships Walk/Idle clips.

## Controls

- **Left click** a ground tile → player routes there around any walls.

## Conventions

- GDScript uses **tabs** (Godot default).
- Target Godot 4.7 API.
- New tests: `extends SceneTree`, do checks in `_initialize()`, `quit(0|1)`.
