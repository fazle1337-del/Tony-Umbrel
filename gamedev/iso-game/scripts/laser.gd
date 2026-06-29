class_name Laser
extends RefCounted
## Pure ray-march for the player's laser sight — no nodes, no physics bodies — so
## the "how far does the beam reach" logic is unit-testable (tests/test_laser.gd)
## and stays consistent with the grid model the rest of the game uses. The world
## has no collision shapes (walls are just blocked grid cells, enemies are
## Node3Ds), so we march the ray ourselves in the XZ plane and stop at the first
## wall cell, out-of-bounds edge, or enemy disc.

const STEP := 0.06          # march resolution (world units); fine enough to look solid
const ENEMY_RADIUS := 0.35  # enemy hit disc (matches the capsule's ~0.28 body + margin)


## Marches a ray from `origin` along unit `dir` (both 2D, XZ) to the first
## obstruction — a blocked/out-of-bounds cell or an enemy disc — capped at
## `max_range`. `enemies` are enemy XZ positions. Returns
## {distance, enemy}: `enemy` is the hit enemy's index, or -1 for a wall / the
## arena edge / nothing in range. This is what the gun fires along, and what the
## laser sight draws (distance only).
static func cast(world: GridWorld, enemies: Array[Vector2],
		origin: Vector2, dir: Vector2, max_range: float) -> Dictionary:
	var t := STEP
	while t <= max_range:
		var p := origin + dir * t
		var cell := IsoGrid.world_to_grid(Vector3(p.x, 0.0, p.y))
		if not world.is_in_bounds(cell) or world.is_blocked(cell):
			return {"distance": t, "enemy": -1}
		for i in enemies.size():
			if p.distance_to(enemies[i]) <= ENEMY_RADIUS:
				return {"distance": t, "enemy": i}
		t += STEP
	return {"distance": max_range, "enemy": -1}


## Beam length only (for drawing the laser sight). See cast().
static func cast_distance(world: GridWorld, enemies: Array[Vector2],
		origin: Vector2, dir: Vector2, max_range: float) -> float:
	return cast(world, enemies, origin, dir, max_range)["distance"]


## Like cast(), but for a piercing shot: collects up to `max_hits` enemies (in
## order along the ray, each counted once) before stopping. Stops early at a wall
## or the arena edge. Returns {distance, enemies}: `distance` is where the bullet
## ends (the wall, the last enemy it could hit, or max_range), `enemies` the list
## of hit indices. `max_hits` = weapon.pierce + 1.
static func cast_pierce(world: GridWorld, enemies: Array[Vector2],
		origin: Vector2, dir: Vector2, max_range: float, max_hits: int) -> Dictionary:
	var hits: Array[int] = []
	var seen := {}
	var t := STEP
	while t <= max_range:
		var p := origin + dir * t
		var cell := IsoGrid.world_to_grid(Vector3(p.x, 0.0, p.y))
		if not world.is_in_bounds(cell) or world.is_blocked(cell):
			return {"distance": t, "enemies": hits}
		for i in enemies.size():
			if not seen.has(i) and p.distance_to(enemies[i]) <= ENEMY_RADIUS:
				seen[i] = true
				hits.append(i)
				if hits.size() >= max_hits:
					return {"distance": t, "enemies": hits}
		t += STEP
	return {"distance": max_range, "enemies": hits}
