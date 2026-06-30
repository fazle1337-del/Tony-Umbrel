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
├── scripts/laser.gd         # pure ray-march: laser-sight length + gun hitscan, tested
├── scripts/bullet.gd        # glowing projectile node (cosmetic travel)
├── scripts/player_stats.gd  # central player stats (upgrades land here), tested
├── scripts/weapon.gd        # weapon data + pure fire_pattern (multishot/spread), tested
├── scripts/spawn_schedule.gd# pure spawn interval + type curve, tested
├── scripts/spawn_director.gd# node: streams enemies off the schedule
├── scripts/enemy_types.gd   # enemy stat/size/xp presets (grunt/fast/tank)
├── scripts/progression.gd   # pure XP curve: level<->total<->bar fill, tested
├── scripts/pickup.gd        # XP-gem node (cosmetic; main does the collection)
├── tests/test_*.gd          # headless SceneTree tests, exit 0/1
├── tools/run_tests.sh       # run all tests
├── tools/screenshot.sh      # deterministic frame capture
└── screenshots/latest.png   # generated; not the source of truth
```

## Mechanics

- **Player movement (twin-stick).** Arrow keys move the player freely (continuous,
  screen-relative via the camera basis, so diagonals give a full 8-way arc); the
  player slides along walls/arena bounds by resolving each axis independently
  (`main.gd` `_move_player`/`_is_walkable`, against `GridWorld` blocked cells).
  The player **aims at the mouse** every frame (`_aim_at_mouse`), independent of
  movement direction. (A* is no longer used for the player — only enemies path.)
  Obstacle layout is built in `main.gd` `_build_obstacles`.

- **Gun + laser sight.** A thin, semi-transparent red **laser** emits from the
  muzzle (offset to the player's right, `GUN_OFFSET`) showing the aim line;
  its length comes from `Laser.cast_distance` — a **pure ray-march**
  (`scripts/laser.gd`, tested in `tests/test_laser.gd`) that stops at walls, the
  arena edge, or an enemy. **Hold left-click for automatic fire** (polled in
  `_process`, paced by `PLAYER_ATTACK_COOLDOWN`): `_try_attack` runs the same
  `Laser.cast` **hitscan** to pick the first enemy hit, then spawns a glowing
  **bullet** (`scripts/bullet.gd` — emissive sphere + travelling `OmniLight3D`)
  that flies to the point and applies `PLAYER_ATTACK_DAMAGE` on arrival, plus a
  muzzle-flash glow (`_show_muzzle_flash`). Right-click is a **reserved special**
  (`_try_special`, cooldown wired, no effect yet). The laser is a separate node,
  so firing never disturbs it.

- **Enemy AI (finite state machine).** Enemies run an enum FSM
  (`scripts/enemy_brain.gd`, PATROL → CHASE → ATTACK → RETURN). Transitions are a
  **pure function** of the enemy/player cells + line-of-sight + A*-reachability
  (unit tested in `tests/test_enemy_brain.gd`); `scripts/enemy.gd` executes the
  current state. Tinted by state for at-a-glance verification: **grey** patrol,
  **orange** chase, **red** attack, **blue** return. Concept adapted from the
  kidscancode "changing behaviors" recipe. Features:
  - **Line of sight:** detection needs a clear line (`GridWorld.has_line_of_sight`,
    Bresenham — walls block vision); a started chase persists around corners via
    A* until the player is out of range/unreachable.
  - **Tunable per enemy:** `@export` `detect_range`/`lose_range`/`attack_range`/
    `chase_speed`/`patrol_speed`/`max_health`/`size` (set per type or the inspector).
  - **Throttled pathfinding:** the FSM inputs and A* route are recomputed every
    `THINK_INTERVAL` (~0.2s, staggered per enemy) and cached; movement runs every
    frame along the cached route. Keeps a crowd cheap (was A* twice per frame).
  - **Patrol routes:** a waypoint list cycled ping-pong (A*-routed between
    waypoints); falls back to random wander if no route is given (spawned enemies
    get no route → wander until they detect the player).
- **Spawning (survivors-like).** A `SpawnDirector` (`scripts/spawn_director.gd`)
  streams enemies from the arena edges on an escalating curve — `SpawnSchedule`
  (`scripts/spawn_schedule.gd`, pure + tested) gives the spawn interval and a
  time-weighted enemy type. Types are stat/size presets (`scripts/enemy_types.gd`:
  grunt / fast / tank). `main.gd` `_spawn_enemy`/`_on_spawn` place them (free edge
  cell, `MAX_ENEMIES` cap). Seeded RNG → reproducible. In screenshot mode the
  director is skipped and a fixed crowd is staged instead.
- **XP & levels (survivors-like).** Each enemy drops an XP **gem** where it dies
  (`scripts/pickup.gd`; value by type — `EnemyTypes.PRESETS[*].xp`, tougher worth
  more). The player **vacuums** gems within `_stats.pickup_radius`
  (`main.gd` `_collect_pickups`), accruing `_xp`. The level curve is pure +
  tested (`scripts/progression.gd`, `tests/test_progression.gd`): `xp_span(level)`
  is the bar's width, `level_for_total`/`xp_into_level` drive the HUD XP bar +
  "Lv N" label by the HP. Crossing a boundary calls `_on_level_up` — a hook that
  Step 5 (pick-a-card) will fill in. In screenshot mode a couple of gems and a
  partway bar are staged deterministically.
- **Combat / health.** Enemies in ATTACK deal `attack_damage` every
  `attack_interval`s via the `hit_player` signal. `main.gd` tracks player HP
  (HUD label + red hit-flash); at 0 HP it shows "YOU DIED" and `_respawn()`
  resets the player to `PLAYER_START` and sends every enemy home (`Enemy.reset`).
- **Enemy HP / death.** Enemies have HP (`max_health`, `Enemy.take_damage`): a
  white emission flash on each hit, and at 0 HP they emit `died`, which `main.gd`
  `_on_enemy_died` despawns. Killed enemies stay dead through a respawn (seed for
  a future "clear all enemies" objective).
  - **Enemy health bars:** a floating bar above each enemy (`Enemy._build_health_bar`)
    — dark backing + a left-anchored fill scaled by the HP fraction, coloured
    green→red as it drains. Shown only when damaged (hidden at full HP). The fixed
    iso camera means it faces the viewer by copying the camera's rotation each
    frame (`_orient_health_bar`) rather than billboarding.

## Character

- The player is **`assets/explorer.glb`** — a procedural low-poly explorer
  (CC0; see `assets/CREDITS.md`). Loaded in `main.gd` `_build_player` and turned
  to face the mouse cursor (`_face_toward`). Tune size with `PLAYER_SCALE`;
  swap models via `PLAYER_MODEL`. Asset workflow: `../BLENDER_MCP.md`.
- It's a **static mesh** (not rigged) — placeholder until the game is further
  along. The animation hook is already wired: `_setup_animation` finds the
  model's `AnimationPlayer` and `_update_anim` plays **Walk** while moving /
  **Idle** when stopped — a no-op now, automatically active once `PLAYER_MODEL`
  points at a model that ships Walk/Idle clips.

## Controls

- **Arrow keys** → move (free 8-way, screen-relative; slides along walls).
- **Mouse** → aim; the player and laser sight follow the cursor.
- **Left-click (hold)** → automatic gun fire down the aim line.
- **Right-click** → special attack (reserved; no effect yet).

## Conventions

- GDScript uses **tabs** (Godot default).
- Target Godot 4.7 API.
- New tests: `extends SceneTree`, do checks in `_initialize()`, `quit(0|1)`.
