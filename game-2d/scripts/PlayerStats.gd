extends Node

var health: int = 100
var max_health: int  = 100

func reset() -> void:
	health = max_health
