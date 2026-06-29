class_name Enemy
extends Node3D
## An enemy that runs the EnemyBrain FSM each physics frame and executes the
## current state: PATROL wanders, CHASE A*-routes to the player, ATTACK stops and
## faces the player, RETURN A*-routes home. The body is tinted by state so the
## screenshot harness can verify behavior at a glance (grey=patrol, orange=chase,
## red=attack, blue=return). Spawn via `Enemy.new()` then `setup(...)`.

const IsoGrid := preload("res://scripts/iso_grid.gd")
const GridWorld := preload("res://scripts/grid_world.gd")
const EnemyBrain := preload("res://scripts/enemy_brain.gd")

# Per-enemy tunables (set before setup(), or in the inspector if used in a scene).
@export var detect_range := 5     # cells: start chasing within this range (needs LOS)
@export var lose_range := 8       # cells: give up the chase beyond this
@export var attack_range := 1     # cells: attack within this (1 = adjacent)
@export var chase_speed := 3.2    # world units/s while chasing (player is 4.0)
@export var patrol_speed := 1.6   # world units/s while patrolling
@export var attack_damage := 10   # HP dealt per hit while in ATTACK
@export var attack_interval := 1.0  # seconds between hits
@export var max_health := 30       # HP; the player's swing deals ~15 (2 hits)

signal hit_player(damage: int)
signal died(enemy: Enemy)         # emitted once when HP reaches 0

const ARRIVE := 0.05         # distance at which a step is "reached"
const BODY_Y := 0.5          # half body height; sits the capsule on the ground
const BAR_Y := 0.95          # health-bar height above the body origin
const BAR_W := 0.8           # health-bar width (world units)
const BAR_H := 0.12          # health-bar height (world units)

var _world: GridWorld
var _player: Node3D
var _home: Vector2i
var _brain: EnemyBrain
var _state: EnemyBrain.State = EnemyBrain.State.PATROL
var _cell: Vector2i
var _wander_target: Vector2i
var _route: Array[Vector2i] = []   # patrol waypoints; empty = random wander
var _route_index := 0
var _route_dir := 1                # ping-pong direction along the route
var _attack_cd := 0.0              # seconds until the next hit lands
var _health: int
var _mesh: MeshInstance3D
var _bar: Node3D                   # health-bar container (faces the fixed camera)
var _bar_pivot: Node3D            # left-anchored; scale.x = health fraction
var _bar_fill: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func setup(world: GridWorld, player: Node3D, home: Vector2i,
		route: Array[Vector2i], rng_seed: int) -> void:
	_world = world
	_player = player
	_home = home
	_route = route
	_brain = EnemyBrain.new(detect_range, lose_range, attack_range)
	_health = max_health
	_cell = home
	_wander_target = home
	_rng.seed = rng_seed
	_build_mesh()
	_build_health_bar()
	position = _cell_pos(_cell)
	_apply_state_color()


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	var pcell := IsoGrid.world_to_grid(_player.position)
	var can_see := _world.has_line_of_sight(_cell, pcell)
	var reachable := not _world.find_path(_cell, pcell).is_empty()
	var new_state := _brain.next_state(_state, _cell, pcell, _home, can_see, reachable)
	if new_state != _state:
		_state = new_state
		if _state == EnemyBrain.State.ATTACK:
			_attack_cd = 0.0          # first hit lands immediately on entering ATTACK
		_apply_state_color()

	match _state:
		EnemyBrain.State.CHASE:
			_step_toward(pcell, chase_speed, delta)
		EnemyBrain.State.RETURN:
			_step_toward(_home, chase_speed, delta)
		EnemyBrain.State.ATTACK:
			_attack(delta)
		EnemyBrain.State.PATROL:
			_patrol(delta)

	_orient_health_bar()


## Advances one A* step toward `goal`, updating _cell on arrival at the next cell.
func _step_toward(goal: Vector2i, speed: float, delta: float) -> void:
	var path := _world.find_path(_cell, goal)
	if path.size() < 2:
		return  # already there / no route
	var tpos := _cell_pos(path[1])
	position = position.move_toward(tpos, speed * delta)
	_face(tpos)
	if position.distance_to(tpos) < ARRIVE:
		_cell = path[1]


## PATROL: follow the assigned route (A*-routing between waypoints, ping-pong at
## the ends), or wander randomly if no route was given.
func _patrol(delta: float) -> void:
	if _route.is_empty():
		_wander(delta)
		return
	if _cell == _route[_route_index]:
		_advance_route()
	_step_toward(_route[_route_index], patrol_speed, delta)


func _advance_route() -> void:
	if _route.size() <= 1:
		return
	if _route_index + _route_dir >= _route.size() or _route_index + _route_dir < 0:
		_route_dir = -_route_dir
	_route_index += _route_dir


## Fallback when no route: drift between random adjacent free cells.
func _wander(delta: float) -> void:
	var tpos := _cell_pos(_wander_target)
	position = position.move_toward(tpos, patrol_speed * delta)
	if _wander_target != _cell:
		_face(tpos)
	if position.distance_to(tpos) < ARRIVE:
		_cell = _wander_target
		var ns := _world.neighbors(_cell)
		if not ns.is_empty():
			_wander_target = ns[_rng.randi() % ns.size()]


## ATTACK: stand, face the player, and land a hit every attack_interval seconds.
func _attack(delta: float) -> void:
	_face(_player.position)
	_attack_cd -= delta
	if _attack_cd <= 0.0:
		_attack_cd = attack_interval
		hit_player.emit(attack_damage)


## Applies a player hit. Flashes white; emits `died` (once) at 0 HP so main.gd
## can despawn it. No-op once already dead.
func take_damage(amount: int) -> void:
	if _health <= 0:
		return
	_health = maxi(_health - amount, 0)
	_flash_hit()
	_refresh_health_bar()
	if _health == 0:
		died.emit(self)


## Brief white emission pulse on a hit — independent of the state albedo tint.
func _flash_hit() -> void:
	var m := _mesh.material_override as StandardMaterial3D
	m.emission_energy_multiplier = 1.6
	create_tween().tween_property(m, "emission_energy_multiplier", 0.0, 0.3)


## A floating bar above the head: dark backing + a left-anchored fill we scale by
## the health fraction. Hidden at full HP to keep patrols uncluttered; the fixed
## iso camera lets us face it by copying the camera's rotation each frame
## (_orient_health_bar) rather than billboarding.
func _build_health_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3.UP * BAR_Y
	_bar.visible = false
	add_child(_bar)

	var back := MeshInstance3D.new()
	var back_quad := QuadMesh.new()
	back_quad.size = Vector2(BAR_W, BAR_H)
	back.mesh = back_quad
	back.material_override = _bar_material(Color(0.1, 0.1, 0.12))
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(back)

	# Pivot sits at the bar's left edge so scaling x shrinks the fill rightward.
	_bar_pivot = Node3D.new()
	_bar_pivot.position = Vector3(-BAR_W * 0.5, 0, 0.01)  # +z: just in front of backing
	_bar.add_child(_bar_pivot)

	_bar_fill = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(BAR_W, BAR_H)
	_bar_fill.mesh = fill_quad
	_bar_fill.position = Vector3(BAR_W * 0.5, 0, 0)      # left edge at the pivot
	_bar_fill.material_override = _bar_material(Color(0.2, 0.85, 0.2))
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_pivot.add_child(_bar_fill)


## Unshaded, double-sided, shadowless material so bar colors stay crisp.
func _bar_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Resizes/recolors the fill and toggles visibility (shown only when damaged).
func _refresh_health_bar() -> void:
	if _bar == null:
		return
	var frac := float(_health) / float(max_health) if max_health > 0 else 0.0
	frac = clampf(frac, 0.0, 1.0)
	_bar.visible = _health > 0 and frac < 1.0
	_bar_pivot.scale.x = frac
	# green when full -> red when low
	_bar_fill.material_override.albedo_color = Color(1.0 - frac, 0.2 + 0.65 * frac, 0.15)


## Keep the bar facing the fixed iso camera (its rotation never changes at runtime).
func _orient_health_bar() -> void:
	if _bar == null or not _bar.visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_bar.global_rotation = cam.global_rotation


## Returns the enemy to its home cell + PATROL state (used on player respawn).
func reset() -> void:
	_cell = _home
	_wander_target = _home
	_route_index = 0
	_route_dir = 1
	_attack_cd = 0.0
	_health = max_health
	_state = EnemyBrain.State.PATROL
	position = _cell_pos(_cell)
	_apply_state_color()
	_refresh_health_bar()


func _face(world_pos: Vector3) -> void:
	var flat := Vector3(world_pos.x, position.y, world_pos.z)
	if position.distance_to(flat) > 0.001:
		look_at(flat, Vector3.UP)


func _cell_pos(cell: Vector2i) -> Vector3:
	return IsoGrid.grid_to_world(cell) + Vector3.UP * BODY_Y


func _build_mesh() -> void:
	_mesh = MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.28
	body.height = 1.0
	_mesh.mesh = body
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true              # white hit-flash overlays the tint
	mat.emission = Color(1, 1, 1)
	mat.emission_energy_multiplier = 0.0
	_mesh.material_override = mat
	add_child(_mesh)


func _apply_state_color() -> void:
	var c := Color(0.5, 0.5, 0.55)            # PATROL — grey
	match _state:
		EnemyBrain.State.CHASE:
			c = Color(0.95, 0.45, 0.15)       # orange
		EnemyBrain.State.ATTACK:
			c = Color(0.95, 0.1, 0.1)         # red
		EnemyBrain.State.RETURN:
			c = Color(0.3, 0.5, 0.9)          # blue
	_mesh.material_override.albedo_color = c
