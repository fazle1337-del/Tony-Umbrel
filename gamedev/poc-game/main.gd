extends Node2D
## POC "Catch the falling blocks" game.
## Built entirely in code so it doubles as a toolchain smoke test:
## exercises input actions, the _process loop, Area2D collision + signals,
## runtime node instancing, custom _draw rendering and a UI label.

const VIEW_SIZE := Vector2(480, 640)
const PLAYER_SIZE := Vector2(80, 16)
const PLAYER_SPEED := 420.0
const BLOCK_SIZE := Vector2(28, 28)
const SPAWN_INTERVAL := 0.7
const FALL_SPEED := 220.0

# When true the game runs one logic step then quits — used by the headless
# smoke test (godot --headless) so CI gets a deterministic pass/fail.
@export var self_test := false

var _player: Area2D
var _score_label: Label
var _score := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if "--self-test" in OS.get_cmdline_user_args():
		self_test = true
	_rng.randomize()
	_build_player()
	_build_ui()

	var spawn_timer := Timer.new()
	spawn_timer.wait_time = SPAWN_INTERVAL
	spawn_timer.timeout.connect(_spawn_block)
	add_child(spawn_timer)
	spawn_timer.start()

	if self_test:
		_run_self_test()


func _process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	var pos := _player.position
	pos.x = clampf(pos.x + dir * PLAYER_SPEED * delta,
			PLAYER_SIZE.x * 0.5, VIEW_SIZE.x - PLAYER_SIZE.x * 0.5)
	_player.position = pos


func _build_player() -> void:
	_player = _make_box(PLAYER_SIZE, Color(0.3, 0.8, 1.0))
	_player.position = Vector2(VIEW_SIZE.x * 0.5, VIEW_SIZE.y - 48)
	add_child(_player)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	_score_label = Label.new()
	_score_label.position = Vector2(12, 8)
	_score_label.add_theme_font_size_override("font_size", 24)
	canvas.add_child(_score_label)
	_update_score(0)


func _spawn_block() -> void:
	var block := _make_box(BLOCK_SIZE, Color(1.0, 0.7, 0.2))
	var half := BLOCK_SIZE.x * 0.5
	block.position = Vector2(_rng.randf_range(half, VIEW_SIZE.x - half), -half)
	block.set_meta("falling", true)
	block.area_entered.connect(_on_block_caught.bind(block))
	add_child(block)


func _physics_process(delta: float) -> void:
	for child in get_children():
		if child is Area2D and child.has_meta("falling"):
			child.position.y += FALL_SPEED * delta
			if child.position.y > VIEW_SIZE.y + BLOCK_SIZE.y:
				child.queue_free()


func _on_block_caught(other: Area2D, block: Area2D) -> void:
	if other == _player:
		_update_score(_score + 1)
		block.queue_free()


func _update_score(value: int) -> void:
	_score = value
	_score_label.text = "Score: %d" % _score


## Creates an Area2D with a rectangle collision shape and a child that draws it.
func _make_box(size: Vector2, color: Color) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	area.add_child(shape)
	area.add_child(_BoxVisual.new(size, color))
	return area


func _run_self_test() -> void:
	# Drive one spawn + a forced catch, then assert the score moved and quit.
	_spawn_block()
	var block: Area2D = null
	for child in get_children():
		if child is Area2D and child.has_meta("falling"):
			block = child
			break
	assert(block != null, "block failed to spawn")
	_on_block_caught(_player, block)
	assert(_score == 1, "score did not increment on catch")
	print("POC self-test OK: spawn + catch + score all working")
	get_tree().quit()


## Tiny helper node that renders a centered rectangle via the _draw API.
class _BoxVisual extends Node2D:
	var _size: Vector2
	var _color: Color

	func _init(size: Vector2, color: Color) -> void:
		_size = size
		_color = color

	func _draw() -> void:
		draw_rect(Rect2(-_size * 0.5, _size), _color)
