class_name Bullet
extends Node3D
## A visible gun projectile: a glowing yellow sphere that carries its own light so
## it lights the world as it travels. Purely cosmetic — the hits are decided up
## front by the hitscan (Laser.cast_pierce) and damage is applied at fire time;
## the bullet just travels to where the shot ended (wall / last enemy / range).
## Independent of the laser sight (its own node) so firing never disturbs the beam.

const RADIUS := 0.09

var _dir: Vector3            # unit travel direction (flat)
var _remaining: float        # world units left before it arrives
var _speed: float            # travel speed (from the weapon)
var _moving := true


## `from` muzzle position, `dir` unit aim, `distance` to the end of the shot,
## `speed` world units/s. When `moving` is false the bullet sits at `from` (the
## deterministic screenshot).
func setup(from: Vector3, dir: Vector3, distance: float, moving: bool, speed: float) -> void:
	position = from
	_dir = dir
	_remaining = distance
	_moving = moving
	_speed = speed
	_build()


func _build() -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.1)
	mat.emission_energy_multiplier = 3.5     # glow
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

	var light := OmniLight3D.new()           # the travelling glow
	light.light_color = Color(1.0, 0.8, 0.35)
	light.light_energy = 2.2
	light.omni_range = 2.6
	add_child(light)


func _process(delta: float) -> void:
	if not _moving:
		return
	var step := _speed * delta
	if step >= _remaining:
		position += _dir * _remaining
		queue_free()
		return
	position += _dir * step
	_remaining -= step
