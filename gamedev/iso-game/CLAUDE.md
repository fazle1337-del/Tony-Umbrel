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
├── scripts/enemy.gd         # Enemy node: runs the FSM + executes each state; HP
├── scripts/combat.gd        # pure melee targeting (player swing), tested
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
  **pure function** of the enemy/player cells + line-of-sight + A*-reachability
  (unit tested in `tests/test_enemy_brain.gd`); `scripts/enemy.gd` executes the
  current state. Tinted by state for at-a-glance verification: **grey** patrol,
  **orange** chase, **red** attack, **blue** return. Spawned via a per-enemy
  config table in `main.gd` `_build_enemies`. Concept adapted from the kidscancode
  "changing behaviors" recipe. Features:
  - **Line of sight:** detection needs a clear line (`GridWorld.has_line_of_sight`,
    Bresenham — walls block vision); a started chase persists around corners via
    A* until the player is out of range/unreachable.
  - **Tunable per enemy:** `@export` `detect_range`/`lose_range`/`attack_range`/
    `chase_speed`/`patrol_speed` (set in the spawn table or the inspector).
  - **Patrol routes:** a waypoint list cycled ping-pong (A*-routed between
    waypoints); falls back to random wander if no route is given.
- **Combat / health.** Enemies in ATTACK deal `attack_damage` every
  `attack_interval`s via the `hit_player` signal. `main.gd` tracks player HP
  (HUD label + red hit-flash); at 0 HP it shows "YOU DIED" and `_respawn()`
  resets the player to `PLAYER_START` and sends every enemy home (`Enemy.reset`).
- **Player combat (two-sided).** Press **Space** to swing: `main.gd` `_try_attack`
  (cooldown-gated) calls `Combat.targets_in_range` — a **pure**, unit-tested
  cleave-targeting function (`scripts/combat.gd`, tested in
  `tests/test_combat.gd`) — and deals `PLAYER_ATTACK_DAMAGE` to every enemy
  within `PLAYER_ATTACK_RANGE` cells. Enemies have HP (`max_health`,
  `Enemy.take_damage`): a white emission flash on each hit, and at 0 HP they emit
  `died`, which `main.gd` `_on_enemy_died` despawns. A translucent ring
  (`_show_swing`) marks each swing. Killed enemies stay dead through a respawn
  (seed for a future "clear all enemies" objective).
  - **Enemy health bars:** a floating bar above each enemy (`Enemy._build_health_bar`)
    — dark backing + a left-anchored fill scaled by the HP fraction, coloured
    green→red as it drains. Shown only when damaged (hidden at full HP). The fixed
    iso camera means it faces the viewer by copying the camera's rotation each
    frame (`_orient_health_bar`) rather than billboarding.

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
- **Space** → swing at adjacent enemies (melee cleave).

## Conventions

- GDScript uses **tabs** (Godot default).
- Target Godot 4.7 API.
- New tests: `extends SceneTree`, do checks in `_initialize()`, `quit(0|1)`.
