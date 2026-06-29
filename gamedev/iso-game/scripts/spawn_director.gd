class_name SpawnDirector
extends Node
## Times enemy spawns off the pure SpawnSchedule curve and emits `spawn(type)`;
## main decides placement and honors the concurrent cap. Seeded RNG -> the wave
## is reproducible. Disabled in screenshot mode (main stages a fixed crowd
## instead), since this advances on real-time `delta`.

const SpawnSchedule := preload("res://scripts/spawn_schedule.gd")

signal spawn(type: StringName)

var _elapsed := 0.0
var _next_in := 0.0
var _rng := RandomNumberGenerator.new()


func _init(rng_seed := 0) -> void:
	_rng.seed = rng_seed
	_next_in = SpawnSchedule.spawn_interval(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	_next_in -= delta
	# `while` so a long frame can emit any spawns it skipped past.
	while _next_in <= 0.0:
		spawn.emit(SpawnSchedule.pick_type(_elapsed, _rng.randf()))
		_next_in += SpawnSchedule.spawn_interval(_elapsed)
