class_name SpawnSchedule
extends RefCounted
## Pure spawn-difficulty curve for the survivors-like director — no nodes, seeded
## by the caller — so the escalation is deterministic and unit-tested
## (tests/test_spawn_schedule.gd). SpawnDirector just times itself off
## spawn_interval() and rolls pick_type() with its RNG.

const START_INTERVAL := 2.0    # seconds between spawns at t=0
const MIN_INTERVAL := 0.35     # floor (fastest spawning)
const RAMP := 0.0125           # interval shed per second (floor reached ~132s)


## Seconds until the next spawn at elapsed time `t` — shrinks linearly to a floor.
static func spawn_interval(t: float) -> float:
	return maxf(START_INTERVAL - RAMP * t, MIN_INTERVAL)


## Enemy type for a spawn at time `t`, chosen from `roll` in [0,1). Weights shift
## from all-grunt early toward fast/tank over time; deterministic per (t, roll).
static func pick_type(t: float, roll: float) -> StringName:
	var fast_w := clampf(t / 120.0, 0.0, 0.5)          # 0 -> 0.5 over 2 min
	var tank_w := clampf((t - 30.0) / 200.0, 0.0, 0.35)  # starts at 30s, up to 0.35
	var grunt_w := maxf(1.0 - fast_w - tank_w, 0.0)
	if roll < grunt_w:
		return &"grunt"
	if roll < grunt_w + fast_w:
		return &"fast"
	return &"tank"
