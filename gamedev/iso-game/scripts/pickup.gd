class_name Pickup
extends Node3D
## An XP gem dropped where an enemy dies. Cosmetic: a faceted, emissive cyan gem
## hovering above the floor that slowly spins so it reads against the tiles. main
## (_collect_pickups) does the proximity check against the player's pickup_radius
## and collects it for `value` XP. The spin is skipped in screenshot mode so the
## deterministic frame is stable.

const SIZE := 0.16
const HOVER_Y := 0.35     # rests above the floor so it reads against the tiles
const SPIN_SPEED := 2.0   # radians / second

var value := 1
var _animate := true


## `at` is the ground position, `xp` the value, `animate` false for the static
## screenshot frame.
func setup(at: Vector3, xp: int, animate: bool) -> void:
	position = Vector3(at.x, HOVER_Y, at.z)
	value = xp
	_animate = animate
	_build()


func _build() -> void:
	var mesh := MeshInstance3D.new()
	var gem := SphereMesh.new()
	gem.radius = SIZE
	gem.height = SIZE * 2.0
	gem.radial_segments = 6      # low segment count -> faceted, gem-like
	gem.rings = 3
	mesh.mesh = gem
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.8)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 0.85)
	mat.emission_energy_multiplier = 2.5     # glow
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

	var light := OmniLight3D.new()           # a soft cyan glow on the floor
	light.light_color = Color(0.3, 1.0, 0.85)
	light.light_energy = 1.2
	light.omni_range = 1.5
	add_child(light)


func _process(delta: float) -> void:
	if _animate:
		rotate_y(SPIN_SPEED * delta)
