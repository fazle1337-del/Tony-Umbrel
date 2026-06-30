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
const Enemy := preload("res://scripts/enemy.gd")
const Laser := preload("res://scripts/laser.gd")
const Bullet := preload("res://scripts/bullet.gd")
const PlayerStats := preload("res://scripts/player_stats.gd")
const Weapon := preload("res://scripts/weapon.gd")
const SpawnDirector := preload("res://scripts/spawn_director.gd")
const EnemyTypes := preload("res://scripts/enemy_types.gd")
const Pickup := preload("res://scripts/pickup.gd")
const Progression := preload("res://scripts/progression.gd")
const Upgrades := preload("res://scripts/upgrades.gd")
const Drops := preload("res://scripts/drops.gd")
const RunSummary := preload("res://scripts/run_summary.gd")

const GRID_RADIUS := 6          # grid spans -RADIUS..RADIUS on both axes
const PLAYER_Y := 0.0           # player rig origin is at the feet, on the ground
const PLAYER_MODEL := "res://assets/explorer.glb"  # CC0/original, see assets/CREDITS.md
const PLAYER_SCALE := 0.5       # tuned so the model is ~1 cell tall
const SEED := 12345             # fixed so runs are reproducible
const SCREENSHOT_FRAMES := 20   # frames to settle before capturing
const SCREENSHOT_PATH := "res://screenshots/latest.png"
const MAX_ENEMIES := 40            # concurrent enemy cap (perf + readability)
# Gun stats live on the Weapon (range/damage/cooldown/...); these are visual-only.
const LASER_WIDTH := 0.02          # beam thickness
const LASER_Y := 0.55              # emit height (roughly chest level)
const GUN_OFFSET := 0.22           # muzzle offset to the player's right
const XP_BAR_WIDTH := 200.0        # HUD XP-bar width in pixels
const XP_BAR_HEIGHT := 12.0

var _world: GridWorld
var _player: Node3D
var _laser: MeshInstance3D            # laser-sight beam (child of the player rig)
var _laser_mesh: BoxMesh             # its mesh; we resize length each frame
var _player_cell := Vector2i(0, 0)   # spawn cell (placement anchor)
var _screenshot_mode := false
var _anim: AnimationPlayer   # the model's animation player (Walk/Idle/...)
var _walk_anim := ""
var _idle_anim := ""
var _enemies: Array[Enemy] = []
var _pickups: Array[Pickup] = []                 # XP gems on the floor
var _xp := 0                                     # cumulative XP this run
var _level := 1
var _owned := {}                                 # upgrade id -> times taken (retires maxed cards)
var _card_rng := RandomNumberGenerator.new()     # card rolls (separate from spawning, so neither desyncs the other)
var _card_layer: CanvasLayer                     # the level-up overlay while it's open
var _spawn_rng := RandomNumberGenerator.new()   # enemy placement (separate from the director's)
var _spawn_seq := 0                              # per-enemy seed counter
var _drop_rng := RandomNumberGenerator.new()    # heart drop rolls (its own stream)
var _kills := 0                                  # enemies slain this run
var _run_time := 0.0                             # seconds survived this run
var _stats := PlayerStats.new()
var _weapon := Weapon.new()   # default = pistol
var _health: int
var _attack_cd := 0.0
var _special_cd := 0.0
var _dead := false
var _hp_label: Label
var _info_label: Label                            # top-right time + kills readout
var _flash: ColorRect
var _level_label: Label
var _xp_fill: ColorRect
var _death_layer: CanvasLayer                      # the run-summary overlay on death


func _ready() -> void:
	seed(SEED)
	_card_rng.seed = SEED + 9999      # distinct stream from spawning
	_drop_rng.seed = SEED + 4242      # distinct stream for heart drops
	_screenshot_mode = "--screenshot" in OS.get_cmdline_user_args()
	_health = _stats.max_health

	_world = GridWorld.new(GRID_RADIUS)
	_build_camera()
	_build_light()
	_build_ground()
	_build_obstacles()
	_build_player()
	_build_laser()
	_build_enemies()
	_build_hud()

	if _screenshot_mode:
		# Stand a few cells from the grunt (at -3,1) in the open and shoot it; the
		# staged crowd (grunt/fast/tank) also shows the per-type size variety.
		_set_player_cell(Vector2i(-3, 4))
		_face_toward(IsoGrid.grid_to_world(Vector2i(-3, 1)))  # down the open column
		_try_attack()
		_update_laser()
		_stage_pickups()                  # gems + a heart + a partway XP bar
		_stage_death_screen()             # the run-summary overlay over the dimmed scene
		_capture_after_settle()


func _process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_special_cd = maxf(_special_cd - delta, 0.0)
	if _dead:
		_laser.visible = false
		_update_anim(false)
		return
	if _screenshot_mode:                  # screenshot stages its own pose in _ready
		_update_anim(false)
		return
	_run_time += delta
	_aim_at_mouse()                       # face the cursor (independent of motion)
	var dir := _move_input()
	if dir != Vector3.ZERO:
		_move_player(dir, delta)
	_collect_pickups()                    # vacuum up nearby gems / hearts
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_attack()                     # automatic: hold to fire (cooldown-paced)
	_update_laser()
	_update_info()
	_update_anim(dir != Vector3.ZERO)


## Plays Walk while moving, Idle when stopped (no-op if the model has no anims).
func _update_anim(moving: bool) -> void:
	if _anim == null:
		return
	var want := _walk_anim if moving else _idle_anim
	if want != "" and _anim.current_animation != want:
		_anim.play(want)


func _unhandled_input(event: InputEvent) -> void:
	# Left-click is automatic fire, polled in _process; only the special is discrete.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		_try_special()


## Movement direction from the arrow keys, mapped to the screen via the camera so
## "up" travels into the screen regardless of the iso yaw. Combining keys gives
## the 8 diagonals (a wider arc than the old 4-direction grid routing). Returns a
## flattened unit vector, or ZERO when no key is held.
func _move_input() -> Vector3:
	var x := Input.get_axis("ui_left", "ui_right")
	var y := Input.get_axis("ui_down", "ui_up")
	if x == 0.0 and y == 0.0:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var right := _flatten(cam.global_transform.basis.x)   # screen-right on the ground
	var fwd := _flatten(-cam.global_transform.basis.z)     # screen-up on the ground
	return (right * x + fwd * y).normalized()


## Projects a vector onto the ground plane (drops Y) and normalizes it.
func _flatten(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z).normalized()


## Moves the player along `dir`, sliding along walls/bounds by resolving each axis
## independently (so grazing a wall doesn't stop all motion).
func _move_player(dir: Vector3, delta: float) -> void:
	var step := dir * _stats.move_speed * delta
	var pos := _player.position
	var try_x := pos + Vector3(step.x, 0, 0)
	if _is_walkable(try_x):
		pos = try_x
	var try_z := pos + Vector3(0, 0, step.z)
	if _is_walkable(try_z):
		pos = try_z
	_player.position = pos


## A world position is walkable if its cell is in bounds and not a wall.
func _is_walkable(pos: Vector3) -> bool:
	var cell := IsoGrid.world_to_grid(pos)
	return _world.is_in_bounds(cell) and not _world.is_blocked(cell)


## Builds the laser-sight beam as a child of the player rig so it inherits the
## mouse-aim rotation; a thin box along the rig's local -Z (the "forward" that
## _face_toward aims). We only resize its length each frame (_update_laser).
func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	_laser_mesh = BoxMesh.new()
	_laser_mesh.size = Vector3(LASER_WIDTH, LASER_WIDTH, 0.01)
	_laser.mesh = _laser_mesh
	var mat := _flat_material(Color(1.0, 0.15, 0.15, 0.4))   # thin, semi-transparent
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # reads the same in any light
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser.material_override = mat
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_player.add_child(_laser)


## Casts the beam from the player along its aim and stretches the box to the hit
## distance (stops at walls/arena edge/enemies — see Laser.cast_distance).
func _update_laser() -> void:
	var dir := _aim_dir()
	if dir == Vector2.ZERO:
		_laser.visible = false
		return
	var dist := Laser.cast_distance(_world, _enemy_positions(), _muzzle(), dir, _weapon.max_range)
	_laser.visible = true
	_laser_mesh.size = Vector3(LASER_WIDTH, LASER_WIDTH, dist)
	# Offset right (the muzzle) and centered along the rig's local -Z (forward).
	_laser.position = Vector3(GUN_OFFSET, LASER_Y, -dist * 0.5)


## The flat (XZ) aim direction the rig faces, normalized — or ZERO if degenerate.
func _aim_dir() -> Vector2:
	var fwd := -_player.global_transform.basis.z   # rig forward = aim direction
	var dir := Vector2(fwd.x, fwd.z)
	return dir.normalized() if dir.length() > 0.001 else Vector2.ZERO


## World XZ of the muzzle: the player's position offset to its right by GUN_OFFSET.
func _muzzle() -> Vector2:
	var right := _player.global_transform.basis.x
	var pos := _player.position + right * GUN_OFFSET
	return Vector2(pos.x, pos.z)


func _enemy_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for enemy in _enemies:
		out.append(Vector2(enemy.position.x, enemy.position.z))
	return out


## Faces the player toward the ground point under the mouse cursor.
func _aim_at_mouse() -> void:
	var ground = _mouse_to_ground()  # Variant: Vector3 or null — can't infer type
	if ground != null:
		_face_toward(ground)


## Casts the mouse ray onto the ground plane (y=0); returns the world point or null.
func _mouse_to_ground():
	var cam := get_viewport().get_camera_3d()
	var screen_pos := get_viewport().get_mouse_position()
	return Plane(Vector3.UP, 0.0).intersects_ray(
			cam.project_ray_origin(screen_pos),
			cam.project_ray_normal(screen_pos))


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


## Loads the player model (PLAYER_MODEL; see assets/CREDITS.md). The glb
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
	_setup_animation(model)


## Live: a SpawnDirector streams escalating enemies from the arena edges.
## Screenshot: a fixed deterministic crowd (one of each type) so the frame is
## reproducible and shows the size variety.
func _build_enemies() -> void:
	_spawn_rng.seed = SEED
	if _screenshot_mode:
		_spawn_enemy(&"grunt", Vector2i(-3, 1))
		_spawn_enemy(&"fast", Vector2i(2, -3))
		_spawn_enemy(&"tank", Vector2i(4, 3))
		return
	var spawner := SpawnDirector.new(SEED)
	spawner.spawn.connect(_on_spawn)
	add_child(spawner)


## Director asked for an enemy: place it at a free arena-edge cell, honoring the cap.
func _on_spawn(type: StringName) -> void:
	if _enemies.size() >= MAX_ENEMIES:
		return
	_spawn_enemy(type, _random_edge_cell())


## Builds one enemy of `type` at `home`, wired to the HP/death signals.
func _spawn_enemy(type: StringName, home: Vector2i) -> void:
	var preset: Dictionary = EnemyTypes.PRESETS[type]
	var enemy := Enemy.new()
	enemy.max_health = preset["health"]
	enemy.chase_speed = preset["chase"]
	enemy.patrol_speed = preset["patrol"]
	enemy.attack_damage = preset["damage"]
	enemy.detect_range = preset["detect"]
	enemy.size = preset["size"]
	enemy.body_radius = preset["radius"]
	enemy.body_height = preset["height"]
	enemy.set_meta(&"xp", preset["xp"])   # gem value dropped on death
	enemy.hit_player.connect(_on_player_hit)
	enemy.died.connect(_on_enemy_died)
	add_child(enemy)
	# No patrol route -> spawned enemies wander until they detect the player.
	enemy.setup(_world, _player, home, [] as Array[Vector2i], SEED + _spawn_seq)
	_spawn_seq += 1
	_enemies.append(enemy)


## A random non-blocked cell on the arena border (where enemies stream in from).
func _random_edge_cell() -> Vector2i:
	for _attempt in 20:
		var along := _spawn_rng.randi_range(-GRID_RADIUS, GRID_RADIUS)
		var edge := GRID_RADIUS if _spawn_rng.randf() < 0.5 else -GRID_RADIUS
		var cell := Vector2i(along, edge) if _spawn_rng.randf() < 0.5 else Vector2i(edge, along)
		if not _world.is_blocked(cell):
			return cell
	return Vector2i(GRID_RADIUS, GRID_RADIUS)


# --- HUD + player health -----------------------------------------------------

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)

	_flash = ColorRect.new()                       # full-screen red hit flash
	_flash.color = Color(1, 0, 0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_flash)

	_hp_label = Label.new()
	_hp_label.position = Vector2(16, 12)
	_hp_label.add_theme_font_size_override("font_size", 22)
	hud.add_child(_hp_label)

	_info_label = Label.new()                      # time + kills, top-right
	_info_label.anchor_left = 1.0
	_info_label.anchor_right = 1.0
	_info_label.offset_left = -260
	_info_label.offset_right = -16
	_info_label.offset_top = 12
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_label.add_theme_font_size_override("font_size", 18)
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_info_label)

	var xp_bg := ColorRect.new()                   # XP-bar backing
	xp_bg.color = Color(0.1, 0.12, 0.16, 0.9)
	xp_bg.position = Vector2(16, 44)
	xp_bg.size = Vector2(XP_BAR_WIDTH, XP_BAR_HEIGHT)
	xp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(xp_bg)

	_xp_fill = ColorRect.new()                     # XP-bar fill (left-anchored)
	_xp_fill.color = Color(0.25, 0.85, 0.75, 0.95)
	_xp_fill.position = Vector2(16, 44)
	_xp_fill.size = Vector2(0, XP_BAR_HEIGHT)
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_xp_fill)

	_level_label = Label.new()                     # level readout by the bar
	_level_label.position = Vector2(16 + XP_BAR_WIDTH + 10, 38)
	_level_label.add_theme_font_size_override("font_size", 18)
	hud.add_child(_level_label)

	var hint := Label.new()                        # controls reminder
	hint.text = "Arrows: move    Mouse: aim    L-click: shoot    R-click: special"
	hint.position = Vector2(16, 64)
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(1, 1, 1, 0.7)
	hud.add_child(hint)

	_update_hp()
	_update_xp_bar()
	_update_info()


func _update_hp() -> void:
	_hp_label.text = "HP %d / %d" % [maxi(_health, 0), _stats.max_health]


## Refreshes the top-right time + kills readout.
func _update_info() -> void:
	_info_label.text = "Time %s   Kills %d" % [RunSummary.format_time(_run_time), _kills]


## Refills the XP bar to the fraction into the current level and updates the label.
func _update_xp_bar() -> void:
	var span := Progression.xp_span(_level)
	var into := Progression.xp_into_level(_xp)
	var frac := clampf(float(into) / float(span), 0.0, 1.0) if span > 0 else 0.0
	_xp_fill.size = Vector2(XP_BAR_WIDTH * frac, XP_BAR_HEIGHT)
	_level_label.text = "Lv %d" % _level


## Called when an enemy lands a hit (Enemy.hit_player signal).
func _on_player_hit(damage: int) -> void:
	if _dead:
		return
	_health -= damage
	_update_hp()
	_flash_red()
	if _health <= 0:
		_die()


## Left-click: fire the equipped weapon. Each pellet of the fire pattern is its
## own hitscan (Laser.cast_pierce — walls block it, pierce passes through enemies),
## damage applied now, then a glowing bullet travels out to where the shot ended.
func _try_attack() -> void:
	if _dead or _attack_cd > 0.0:
		return
	var aim := _aim_dir()
	if aim == Vector2.ZERO:
		return
	_attack_cd = _stats.cooldown_for(_weapon.cooldown)
	var muzzle_xz := _muzzle()
	var from := Vector3(muzzle_xz.x, LASER_Y, muzzle_xz.y)
	var dmg := _stats.damage_for(_weapon.damage)
	_show_muzzle_flash(from)
	for pellet in _weapon.fire_pattern(aim):
		_fire_pellet(from, muzzle_xz, pellet, dmg)


## One pellet: hitscan along `dir`, damage every enemy it hits (up to pierce+1),
## then spawn the cosmetic bullet out to the shot's end distance.
func _fire_pellet(from: Vector3, muzzle_xz: Vector2, dir: Vector2, dmg: int) -> void:
	var hit := Laser.cast_pierce(_world, _enemy_positions(), muzzle_xz, dir,
			_weapon.max_range, _weapon.pierce + 1)
	for i in hit["enemies"]:
		_enemies[i].take_damage(dmg)
	var dir3 := Vector3(dir.x, 0.0, dir.y)
	_spawn_bullet(from, dir3, hit["distance"])


## Spawns the cosmetic projectile travelling `dist` at the weapon's speed. In
## screenshot mode it's placed static mid-flight for the deterministic frame.
func _spawn_bullet(from: Vector3, dir3: Vector3, dist: float) -> void:
	var bullet := Bullet.new()
	add_child(bullet)
	if _screenshot_mode:
		bullet.setup(from + dir3 * dist * 0.6, dir3, 0.0, false, _weapon.proj_speed)
	else:
		bullet.setup(from, dir3, dist, true, _weapon.proj_speed)


## A brief yellow muzzle-flash glow at the gun, fading out (static for the shot).
func _show_muzzle_flash(at: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.8, 0.3)
	flash.light_energy = 4.0
	flash.omni_range = 3.0
	flash.position = at
	add_child(flash)
	if _screenshot_mode:
		return  # leave it lit for the deterministic frame
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)


## Right-click: special attack — reserved. Wired to its own cooldown so the slot
## is ready; the effect lands in a later pass.
func _try_special() -> void:
	if _dead or _special_cd > 0.0:
		return
	# TODO: special attack (e.g. charged/area shot aimed at the cursor).
	pass


## Enemy reached 0 HP (Enemy.died signal): tally the kill, drop an XP gem (and
## maybe a heart) where it fell, then drop it from the roster and despawn.
func _on_enemy_died(enemy) -> void:
	_kills += 1
	var at := Vector3(enemy.position.x, 0.0, enemy.position.z)
	_spawn_gem(at, int(enemy.get_meta(&"xp", 1)))
	if Drops.drops_heart(_drop_rng.randf()):
		_spawn_pickup(at + Vector3(0.35, 0, 0.35), Drops.HEART_HEAL, &"heal")
	_enemies.erase(enemy)
	enemy.queue_free()


## Spawns an XP gem worth `xp` at the ground position `at`.
func _spawn_gem(at: Vector3, xp: int) -> void:
	_spawn_pickup(at, xp, &"xp")


## Spawns a pickup of `kind` ("xp" / "heal") worth `amount` at `at`.
func _spawn_pickup(at: Vector3, amount: int, kind: StringName) -> void:
	var pickup := Pickup.new()
	add_child(pickup)
	pickup.setup(at, amount, not _screenshot_mode, kind)
	_pickups.append(pickup)


## Collects every pickup within the player's pickup_radius: gems grant XP, hearts
## restore HP.
func _collect_pickups() -> void:
	if _pickups.is_empty():
		return
	var p := Vector2(_player.position.x, _player.position.z)
	var kept: Array[Pickup] = []
	for pickup in _pickups:
		if p.distance_to(Vector2(pickup.position.x, pickup.position.z)) <= _stats.pickup_radius:
			if pickup.kind == &"heal":
				_heal(pickup.value)
			else:
				_gain_xp(pickup.value)
			pickup.queue_free()
		else:
			kept.append(pickup)
	_pickups = kept


## Restores HP up to the player's max.
func _heal(amount: int) -> void:
	_health = mini(_health + amount, _stats.max_health)
	_update_hp()


## Adds XP, advancing the level (and firing the level-up hook) on a boundary cross.
func _gain_xp(amount: int) -> void:
	_xp += amount
	var lvl := Progression.level_for_total(_xp)
	if lvl > _level:
		_level = lvl
		_on_level_up()
	_update_xp_bar()


## Crossed a level boundary: pause the world and show the pick-a-card screen.
## (Screenshot mode stages its own card overlay, so it skips the live trigger.)
func _on_level_up() -> void:
	if _screenshot_mode:
		return
	_show_card_screen()


## Rolls 3 seeded upgrade cards, pauses the game, and shows the overlay. No-op if
## the pool is exhausted (every card maxed) so play never freezes with no choice.
func _show_card_screen() -> void:
	var choices := Upgrades.roll_choices(Upgrades.POOL, _card_rng, 3, _owned)
	if choices.is_empty():
		return
	get_tree().paused = true
	_build_card_ui(choices)


## Builds the level-up overlay: a dimmer + a row of card buttons. The layer runs
## while the tree is paused (PROCESS_MODE_WHEN_PAUSED) so its buttons stay live.
func _build_card_ui(choices: Array) -> void:
	_card_layer = CanvasLayer.new()
	_card_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(_card_layer)

	var dim := ColorRect.new()                     # dims + swallows clicks to the game
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_layer.add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 24)
	_card_layer.add_child(root)

	var title := Label.new()
	title.text = "LEVEL %d — choose an upgrade" % _level
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	root.add_child(row)
	for choice in choices:
		row.add_child(_make_card_button(choice))


## One upgrade card as a button (title + description); click applies the choice.
func _make_card_button(choice: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(190, 230)
	b.text = "%s\n\n%s" % [choice["title"], choice["desc"]]
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(_choose_card.bind(choice))
	return b


## Applies the picked card, records it as owned, closes the screen, and unpauses.
## A max-HP card also heals by the same amount (so the level-up feels rewarding).
func _choose_card(choice: Dictionary) -> void:
	Upgrades.apply(_stats, _weapon, choice)
	_owned[choice["id"]] = int(_owned.get(choice["id"], 0)) + 1
	if choice["kind"] == &"max_health":
		_health += int(choice["value"])
	_update_hp()
	_card_layer.queue_free()
	_card_layer = null
	get_tree().paused = false


func _flash_red() -> void:
	if _screenshot_mode:
		return  # keep the deterministic frame's colours true (no full-screen wash)
	_flash.color = Color(1, 0, 0, 0.45)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.4)


## Player HP hit 0: end the run — pause the world and show the run summary.
func _die() -> void:
	_dead = true
	get_tree().paused = true
	_build_death_ui()


## Builds the end-of-run overlay: "YOU DIED", the run summary, and a Restart
## button (reachable by Enter via focus). Runs while paused, like the card screen.
func _build_death_ui() -> void:
	_death_layer = CanvasLayer.new()
	_death_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(_death_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_layer.add_child(dim)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 20)
	_death_layer.add_child(root)

	var title := Label.new()
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.modulate = Color(1.0, 0.3, 0.3)
	root.add_child(title)

	var summary := Label.new()
	summary.text = RunSummary.summary(_level, _run_time, _kills)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 24)
	root.add_child(summary)

	var restart := Button.new()
	restart.text = "Restart run"
	restart.custom_minimum_size = Vector2(200, 56)
	restart.add_theme_font_size_override("font_size", 22)
	restart.pressed.connect(_restart_run)
	root.add_child(restart)
	restart.grab_focus()                  # so Enter/Space restarts too


## Reloads the scene for a fresh run (same SEED -> reproducible).
func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Finds the model's AnimationPlayer, resolves Walk/Idle, loops them, plays Idle.
func _setup_animation(model: Node3D) -> void:
	_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim == null:
		return
	_walk_anim = _pick_anim("walk")
	_idle_anim = _pick_anim("idle")
	_set_loop(_walk_anim)
	_set_loop(_idle_anim)
	if _idle_anim != "":
		_anim.play(_idle_anim)


## First animation whose name contains keyword (case-insensitive), or "".
func _pick_anim(keyword: String) -> String:
	for a in _anim.get_animation_list():
		if keyword in a.to_lower():
			return a
	return ""


func _set_loop(anim_name: String) -> void:
	if anim_name == "":
		return
	var a := _anim.get_animation(anim_name)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR


## Rotates the rig (about Y only) so its front faces the move target.
func _face_toward(target: Vector3) -> void:
	var flat := Vector3(target.x, _player.position.y, target.z)
	if _player.position.distance_to(flat) > 0.001:
		_player.look_at(flat, Vector3.UP)  # aims local -Z at the target


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


# --- screenshot harness ------------------------------------------------------

## Stages gems + a heart on the floor and a partway XP bar for the screenshot.
func _stage_pickups() -> void:
	_spawn_gem(IsoGrid.grid_to_world(Vector2i(-2, 3)), 1)
	_spawn_gem(IsoGrid.grid_to_world(Vector2i(-4, 2)), 1)
	_spawn_pickup(IsoGrid.grid_to_world(Vector2i(-4, 4)), Drops.HEART_HEAL, &"heal")
	_xp = 10                                  # level 2, ~55% into the bar (span 9)
	_level = Progression.level_for_total(_xp)
	_update_xp_bar()


## Overlays the run-summary (death) screen for the screenshot. Not paused — the
## static frame just needs it visible over the dimmed scene.
func _stage_death_screen() -> void:
	_kills = 6
	_run_time = 42.0
	_update_info()
	_build_death_ui()


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
