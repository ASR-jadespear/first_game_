extends Node

signal health_changed(new_health: int)

var max_health: int = 100
var health: int = 100:
	set(val):
		var clamped_val = clampi(val, 0, max_health)
		if health != clamped_val:
			health = clamped_val
			health_changed.emit(health)
		else:
			health = clamped_val

func reset() -> void:
	health = max_health
	health_changed.emit(health)

func apply_damage(amount: int) -> int:
	health = health - amount
	return health

func apply_heal(amount: int) -> int:
	health = health + amount
	return health
