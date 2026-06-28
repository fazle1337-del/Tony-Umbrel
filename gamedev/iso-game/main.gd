extends Node3D
## Isometric scene + click-to-move pathfinding + the screenshot harness hook.
##
## Builds the whole world in code (deterministic, no hand-authored 3D
## transforms to drift): orthographic iso camera, checkerboard ground, walls,
## a directional light and a click-to-move player that A*-routes around walls.
##
## Run normally:        godot --path iso-game   (left-click a tile to move)
## Deterministic shot:  godot --path iso-game -- --screenshot
##   -> renders a fixed frame and writes res://screenshots/latest.png, then quits.

const IsoGrid := preload("res://scripts/iso_grid.gd")
const GridWorld := preload("res://scripts/grid_world.gd")

const GRID_RADIUS := 6          # grid spans -RADIUS..RADIUS on both axes
const MOVE_SPEED := 4.0         # world units / second
const PLAYER_Y := 0.0           # player rig origin is at the feet, on the ground
const PLAYER_MODEL := "res://assets/RobotExpressive.glb"  # CC0, see assets/CREDITS.md
const PLAYER_SCALE := 0.24      # tuned so the model is ~1 cell tall
const SEED := 12345             # fixed so runs are reproducible
const SCREENSHOT_FRAMES := 20   # frames to settle before capturing
const SCREENSHOT_PATH := "res://screenshots/latest.png"

var _world: GridWorld
var _player: Node3D
var _player_cell := Vector2i(0, 0)
var _path: Array[Vector2i] = []
var _path_index := 0
var _markers: Node3D
var _screenshot_mode := false


func _ready() -> void:
	seed(SEED)
	_screenshot_mode = "--screenshot" in OS.get_cmdline_user_args()

	_world = GridWorld.new(GRID_RADIUS)
	_build_camera()
	_build_light()
	_build_ground()
	_build_obstacles()
	_markers = Node3D.new()
	add_child(_markers)
	_build_player()

	if _screenshot_mode:
		# Start in a corner and route to the far side so the shot shows the
		# player detouring around the wall, with the path marked out.
		_set_player_cell(Vector2i(-3, 0))
		_move_to_cell(Vector2i(3, 0))
		_capture_after_settle()


func _process(delta: float) -> void:
	if _path_index >= _path.size():
		return
	var target := _cell_to_player_pos(_path[_path_index])
	_face_toward(target)
	_player.position = _player.position.move_toward(target, MOVE_SPEED * delta)
	if _player.position.distance_to(target) < 0.01:
		_player_cell = _path[_path_index]
		_path_index += 1
		if _path_index >= _path.size():
			_clear_markers()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell = _mouse_to_cell(event.position)  # may be null; can't infer type
		if cell != null:
			_move_to_cell(cell)


## Plans an A* route from the player's current cell and starts walking it.
func _move_to_cell(goal: Vector2i) -> void:
	var path := _world.find_path(_player_cell, goal)
	if path.is_empty():
		return  # unreachable or blocked goal — ignore the click
	_path = path
	_path_index = 1  # index 0 is the current cell; head for the next waypoint
	_show_path_markers()


## Casts a click onto the ground plane (y=0); returns the grid cell or null.
func _mouse_to_cell(screen_pos: Vector2):
	var cam := get_viewport().get_camera_3d()
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(
			cam.project_ray_origin(screen_pos),
			cam.project_ray_normal(screen_pos))
	if hit == null:
		return null
	var cell := IsoGrid.world_to_grid(hit)
	if not _world.is_in_bounds(cell):
		return null
	return cell


func _cell_to_player_pos(cell: Vector2i) -> Vector3:
	return IsoGrid.grid_to_world(cell) + Vector3.UP * PLAYER_Y


func _set_player_cell(cell: Vector2i) -> void:
	_player_cell = cell
	_player.position = _cell_to_player_pos(cell)


# --- world construction ------------------------------------------------------

func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 14.0          # ortho view height in world units
	cam.near = 0.1
	cam.far = 100.0
	# Game isometric: 45° yaw, 30° pitch down. Orthographic, so distance only
	# affects clipping — pull back 30 units along the view axis.
	cam.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	# Camera looks down its local -Z, so sit on the +Z side to face the origin.
	cam.position = cam.transform.basis.z * 30.0
	add_child(cam)


func _build_light() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -40.0, 0.0)
	light.light_energy = 1.2
	add_child(light)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.13, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.4, 0.5)
	e.ambient_light_energy = 0.6
	env.environment = e
	add_child(env)


func _build_ground() -> void:
	var tile := PlaneMesh.new()
	tile.size = Vector2(IsoGrid.CELL_SIZE, IsoGrid.CELL_SIZE) * 0.96
	var light_mat := _flat_material(Color(0.55, 0.6, 0.65))
	var dark_mat := _flat_material(Color(0.4, 0.45, 0.5))
	for x in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for y in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var cell := MeshInstance3D.new()
			cell.mesh = tile
			cell.material_override = dark_mat if (x + y) % 2 == 0 else light_mat
			cell.position = IsoGrid.grid_to_world(Vector2i(x, y))
			add_child(cell)


## A wall at x=1 spanning y=-4..3, leaving a gap near the top to route through.
func _build_obstacles() -> void:
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(0.9, 1.4, 0.9)
	var wall_mat := _flat_material(Color(0.25, 0.27, 0.32))
	for y in range(-4, 4):
		var cell := Vector2i(1, y)
		_world.set_blocked(cell)
		var wall := MeshInstance3D.new()
		wall.mesh = wall_mesh
		wall.material_override = wall_mat
		wall.position = IsoGrid.grid_to_world(cell) + Vector3.UP * 0.7
		add_child(wall)


## Loads the CC0 RobotExpressive character (see assets/CREDITS.md). The glb
## faces +Z by default, so the model child is turned 180° to align with the
## rig's local -Z "front" that _face_toward aims down the movement direction.
## The rig (which we move/rotate) keeps its origin at the feet, on the ground.
func _build_player() -> void:
	var rig := Node3D.new()
	var model = load(PLAYER_MODEL).instantiate()
	model.scale = Vector3.ONE * PLAYER_SCALE
	model.rotation.y = PI
	rig.add_child(model)
	_player = rig
	add_child(_player)
	_set_player_cell(_player_cell)


## Rotates the rig (about Y only) so its front faces the move target.
func _face_toward(target: Vector3) -> void:
	var flat := Vector3(target.x, _player.position.y, target.z)
	if _player.position.distance_to(flat) > 0.001:
		_player.look_at(flat, Vector3.UP)  # aims local -Z at the target


# --- path visualisation ------------------------------------------------------

func _show_path_markers() -> void:
	_clear_markers()
	var marker_mesh := PlaneMesh.new()
	marker_mesh.size = Vector2(0.35, 0.35)
	var marker_mat := _flat_material(Color(0.95, 0.85, 0.2))
	# Skip index 0 (the cell the player is already on); mark the route ahead.
	for i in range(1, _path.size()):
		var marker := MeshInstance3D.new()
		marker.mesh = marker_mesh
		marker.material_override = marker_mat
		marker.position = IsoGrid.grid_to_world(_path[i]) + Vector3.UP * 0.03
		_markers.add_child(marker)


func _clear_markers() -> void:
	for child in _markers.get_children():
		child.queue_free()


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


# --- screenshot harness ------------------------------------------------------

func _capture_after_settle() -> void:
	for _i in SCREENSHOT_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path("res://screenshots"))
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(SCREENSHOT_PATH)
	if err == OK:
		print("screenshot saved: ", SCREENSHOT_PATH)
	else:
		printerr("screenshot failed: ", err)
	get_tree().quit(0 if err == OK else 1)
