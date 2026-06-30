class_name EnemyTypes
extends RefCounted
## Stat presets for the spawnable enemy types — pure data. main applies a preset
## to an Enemy's @export fields when spawning. Differentiated by stats and body
## size so types read at a glance: fast is small, tank is big. `xp` is the value
## of the gem each type drops on death (tougher = worth more).

const PRESETS := {
	&"grunt": {"health": 30, "chase": 3.2, "patrol": 1.6, "damage": 10, "detect": 5, "size": 1.0,  "xp": 1},
	&"fast":  {"health": 18, "chase": 4.6, "patrol": 2.4, "damage": 8,  "detect": 6, "size": 0.78, "xp": 2},
	&"tank":  {"health": 80, "chase": 1.9, "patrol": 1.1, "damage": 22, "detect": 5, "size": 1.45, "xp": 5},
}
