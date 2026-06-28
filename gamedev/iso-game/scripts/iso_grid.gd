class_name IsoGrid
extends RefCounted
## Pure grid<->world coordinate math for the isometric world.
##
## The world is real 3D: a grid cell (x, y) maps to the XZ plane at world
## (x, 0, z). The "isometric" look comes purely from the orthographic camera
## angle (see main.gd) — the simulation itself is plain 3D on a square grid.
##
## This class holds no state on purpose: it is the most test-critical piece of
## the game, so it is kept pure and covered by tests/test_iso_grid.gd.

const CELL_SIZE := 1.0


## Center-of-cell world position for a grid coordinate.
static func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)


## Nearest grid cell for an arbitrary world position (snaps to cell centers).
static func world_to_grid(world: Vector3) -> Vector2i:
	return Vector2i(roundi(world.x / CELL_SIZE), roundi(world.z / CELL_SIZE))
