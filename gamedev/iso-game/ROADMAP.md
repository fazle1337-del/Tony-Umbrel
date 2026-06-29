# Iso Game — survivors-like roadmap

Turning the twin-stick shooter into an **endless survival** game with
**pick-a-card** level-ups. Each step is one commit and stays in the autonomy
loop (pure logic + headless tests, visuals via `tools/screenshot.sh`).

**Principles**
- New gameplay logic lives in pure, **seeded, unit-tested** functions in
  `scripts/`; nodes only execute it. Hardcoded constants become **data**.
- One `RandomNumberGenerator` per system, each seeded from `SEED`, so runs stay
  reproducible (spawning, card rolls).
- After every step: `tools/run_tests.sh` green **and** a fresh deterministic
  screenshot that still reads correctly.

---

## Step 1 — `PlayerStats` (keystone refactor, no behavior change)

Central, mutable stats the player/gun read from, so upgrades have one place to
land.

- **New `scripts/player_stats.gd`** (RefCounted). Base fields + accumulators:
  `move_speed`, `max_health`, `damage_mult`, `fire_rate_mult`, `pickup_radius`.
  Derived getters: `damage(base)`, `cooldown(base)` (cooldown = base /
  fire_rate_mult). Method `apply(kind: StringName, value: float)` bumps the right
  accumulator.
- **Changed `main.gd`**: replace `MOVE_SPEED` / `MAX_HEALTH` /
  `PLAYER_ATTACK_DAMAGE` / `PLAYER_ATTACK_COOLDOWN` reads with `_stats.*`. Seed
  `_stats` with the current constants → identical behavior.
- **New `tests/test_player_stats.gd`**: applying `damage_mult +0.5` twice yields
  ×2.0; `fire_rate_mult` shortens cooldown; `move_speed` adds.
- **Verify**: tests pass; screenshot byte-for-similar (no visible change).

## Step 2 — `Weapon` data + fire patterns

Turn the gun into swappable data; get multishot/spread/pierce for free.

- **New `scripts/weapon.gd`** (data): `damage`, `cooldown`, `proj_speed`,
  `range`, `pellets`, `spread_deg`, `pierce`. A `pistol()` preset = today's
  values.
- **Pure `Weapon.fire_pattern(aim: Vector2, weapon) -> Array[Vector2]`**: returns
  `pellets` directions fanned symmetrically across `spread_deg` (evenly spaced,
  no RNG → deterministic). 1 pellet, 0 spread = straight shot (parity).
- **`scripts/laser.gd`**: add `cast_pierce(... , max_hits) -> Array` returning the
  ordered enemies along the ray until a wall or `max_hits` reached (pierce).
- **Changed `main.gd` `_try_attack`**: loop `fire_pattern`, cast per direction
  (pierce-aware), spawn a `Bullet` per direction; damage each hit enemy.
- **`scripts/bullet.gd`**: `proj_speed` from the weapon (replaces the const).
- **New `tests/test_weapon.gd`**: `fire_pattern` count + symmetric angles;
  `cast_pierce` returns N enemies in order, stops at a wall.
- **Verify**: pistol parity screenshot; a temporary shotgun preset screenshot to
  eyeball the spread, then revert.

## Step 3 — `SpawnDirector` (the spawn rates)

Replace the fixed 2-enemy table with an escalating stream.

- **New `scripts/spawn_schedule.gd`** (pure): `spawn_interval(t) -> float`
  (decreasing curve, clamped to a floor) and `pick_type(t, roll: float) ->
  StringName` (weighted table that shifts toward tougher types over time).
- **Enemy type presets** (data table in `main.gd` or `scripts/enemy_types.gd`):
  `grunt` (hp30, spd3.2), `fast` (hp18, spd4.5), `tank` (hp80, spd1.8, dmg20) —
  reuse Enemy's `@export`s; tag color/scale for legibility.
- **New `scripts/spawn_director.gd`** (node): accumulates time, spawns at
  `spawn_interval(t)` from a random arena-edge cell away from the player, picks a
  type via `pick_type`, caps concurrent enemies.
- **Changed `main.gd`**: drop the static `_build_enemies` table; add the director.
- **Perf note**: Enemy currently runs `find_path` every physics frame — fine for
  2, costly for dozens. Before/at this step, **throttle enemy pathfinding**
  (recompute every ~0.25s or N frames, cache the next step) or switch chase to
  cheap steering. Decide here.
- **New `tests/test_spawn_schedule.gd`**: interval shrinks with t and respects the
  floor; type weights shift; `pick_type` deterministic per roll.
- **Verify**: screenshot at a fixed elapsed time shows a known seeded crowd.

## Step 4 — XP & levels

- **New `scripts/pickup.gd`** (node): a small XP-gem mesh; collected when within
  `_stats.pickup_radius` of the player.
- Drop a gem at each death (`_on_enemy_died`), gem value by enemy type.
- **Pure `scripts/progression.gd`**: `xp_for_level(n)`, `level_for_total(total)`,
  `xp_into_level(total)` / `xp_span(level)` for the bar fill.
- **Changed `main.gd`**: track `_xp`/`_level`; pickup adds XP; crossing a level
  boundary triggers the level-up (Step 5). HUD: XP bar + level label by the HP.
- **New `tests/test_progression.gd`**: curve values; level boundaries
  (total just below/at/above a threshold).
- **Verify**: screenshot with the XP bar partway + a couple of gems on the floor.

## Step 5 — Pick-a-card upgrades

- **Pure `scripts/upgrades.gd`**: a `POOL` of defs `{id, title, kind, value}`;
  `roll_choices(pool, rng, n, owned) -> Array` (n distinct, respects
  one-time/maxed cards); `apply(stats, weapon, upgrade)` mutating
  `PlayerStats`/`Weapon` (e.g. `multishot` → `weapon.pellets += 1`, `pierce`,
  `damage`, `fire_rate`, `move_speed`, `max_hp`, `gain_weapon:X`).
- **Changed `main.gd`**: on level-up `get_tree().paused = true`, show a
  `CanvasLayer` with 3 cards (seeded `roll_choices`); click → `apply`, unpause.
  Player/enemies/bullets respect `process_mode` so pause actually pauses.
- **New `tests/test_upgrades.gd`**: `roll_choices` returns N distinct valid
  (excludes maxed); `apply` produces the expected stat/weapon deltas.
- **Verify**: screenshot of the (paused) card screen with 3 known seeded cards.

## Step 6 — Polish / run loop

- Health pickups (heart), drop-rate tuned.
- **Run summary on death** (level reached, time survived, kills) replacing the
  bare respawn; a key restarts a fresh seeded run.
- Enemy type visuals pass; HUD tidy.

---

## Cross-cutting / decisions to make as we go
- **Pause plumbing** (Step 5): set `process_mode` on gameplay nodes so the card
  screen halts the world but the UI still runs.
- **RNG ownership**: separate seeded generators for spawning vs card rolls so one
  doesn't desync the other.
- **Enemy pathfinding cost** (Step 3): throttle or simplify before the crowd
  grows — the single biggest perf risk.
- **Screenshot staging**: each step extends the `--screenshot` pose to showcase
  the new system deterministically (crowd / XP bar / card screen).
