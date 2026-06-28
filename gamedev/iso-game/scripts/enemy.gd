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

const CHASE_SPEED := 3.2     # a touch slower than the player (4.0) so it's fair
const PATROL_SPEED := 1.6
const ARRIVE := 0.05         # distance at which a step is "reached"
const BODY_Y := 0.5          # half body height; sits the capsule on the ground

var _world: GridWorld
var _player: Node3D
var _home: Vector2i
var _brain: EnemyBrain
var _state: EnemyBrain.State = EnemyBrain.State.PATROL
var _cell: Vector2i
var _wander_target: Vector2i
var _mesh: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func setup(world: GridWorld, player: Node3D, home: Vector2i, brain: EnemyBrain,
		rng_seed: int) -> void:
	_world = world
	_player = player
	_home = home
	_brain = brain
	_cell = home
	_wander_target = home
	_rng.seed = rng_seed
	_build_mesh()
	position = _cell_pos(_cell)
	_apply_state_color()


func _physics_process(delta: float) -> void:
	if _world == null:
		return
	var pcell := IsoGrid.world_to_grid(_player.position)
	var reachable := not _world.find_path(_cell, pcell).is_empty()
	var new_state := _brain.next_state(_state, _cell, pcell, _home, reachable)
	if new_state != _state:
		_state = new_state
		_apply_state_color()

	match _state:
		EnemyBrain.State.CHASE:
			_step_toward(pcell, CHASE_SPEED, delta)
		EnemyBrain.State.RETURN:
			_step_toward(_home, CHASE_SPEED, delta)
		EnemyBrain.State.ATTACK:
			_face(_player.position)
		EnemyBrain.State.PATROL:
			_patrol(delta)


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


## Drifts between random adjacent free cells.
func _patrol(delta: float) -> void:
	var tpos := _cell_pos(_wander_target)
	position = position.move_toward(tpos, PATROL_SPEED * delta)
	if _wander_target != _cell:
		_face(tpos)
	if position.distance_to(tpos) < ARRIVE:
		_cell = _wander_target
		var ns := _world.neighbors(_cell)
		if not ns.is_empty():
			_wander_target = ns[_rng.randi() % ns.size()]


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
	_mesh.material_override = StandardMaterial3D.new()
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
