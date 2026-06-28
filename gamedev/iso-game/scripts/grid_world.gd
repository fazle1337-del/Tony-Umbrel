class_name GridWorld
extends RefCounted
## Grid state + pathfinding. Pure logic (no nodes, no rendering) so it stays
## unit-testable — see tests/test_pathfinding.gd. The grid is a square from
## -radius..radius on both axes; cells can be marked blocked (walls/obstacles).
##
## Movement is 4-directional (no diagonals) which keeps paths corner-cut-free
## and easy to reason about for a tactics-style game.

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var radius: int
var _blocked := {}  # Set of Vector2i -> true


func _init(grid_radius: int) -> void:
	radius = grid_radius


func is_in_bounds(cell: Vector2i) -> bool:
	return abs(cell.x) <= radius and abs(cell.y) <= radius


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func set_blocked(cell: Vector2i, blocked := true) -> void:
	if blocked:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)


## In-bounds, non-blocked neighbours of a cell.
func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in DIRECTIONS:
		var n := cell + dir
		if is_in_bounds(n) and not is_blocked(n):
			result.append(n)
	return result


## True if no blocked cell lies strictly between a and b (Bresenham line).
## Endpoints are ignored. Used for enemy vision (walls break line of sight).
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - x)
	var dy := absi(b.y - y)
	var sx := 1 if x < b.x else -1
	var sy := 1 if y < b.y else -1
	var err := dx - dy
	while true:
		var c := Vector2i(x, y)
		if c != a and c != b and is_blocked(c):
			return false
		if x == b.x and y == b.y:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return true


## A* shortest path from start to goal, inclusive of both ends.
## Returns [] if start/goal are invalid or no path exists; [start] if equal.
func find_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(start) or not is_in_bounds(goal):
		return []
	if is_blocked(start) or is_blocked(goal):
		return []
	if start == goal:
		return [start]

	var open: Array[Vector2i] = [start]
	var came_from := {}
	var g := {start: 0}
	var f := {start: _heuristic(start, goal)}

	while not open.is_empty():
		var current := _lowest_f(open, f)
		if current == goal:
			return _reconstruct(came_from, current)
		open.erase(current)
		for n in neighbors(current):
			var tentative: int = g[current] + 1
			if not g.has(n) or tentative < g[n]:
				came_from[n] = current
				g[n] = tentative
				f[n] = tentative + _heuristic(n, goal)
				if not open.has(n):
					open.append(n)
	return []


func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)  # Manhattan (matches 4-dir movement)


func _lowest_f(open: Array[Vector2i], f: Dictionary) -> Vector2i:
	# Linear scan: the grid is small, and insertion-order tie-breaking keeps
	# results deterministic (important for the screenshot/test harness).
	var best: Vector2i = open[0]
	for cell in open:
		if f[cell] < f[best]:
			best = cell
	return best


func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
