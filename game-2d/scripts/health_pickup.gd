extends Area2D

@onready var collect_sound: AudioStreamPlayer2D = $CollectSound
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

const HEALTH_EFFECT: int = 20
var _is_collected: bool = false
var _last_full_msg_time: float = -10.0

func _ready() -> void:
	z_index = 2
	if has_node("Sprite2D"):
		$Sprite2D.z_index = 2

func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if not (body.is_in_group("player") or body.name.begins_with("Player")):
		return

	if PlayerStats.health >= PlayerStats.max_health:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - _last_full_msg_time > 1.2:
			_last_full_msg_time = current_time
			var hud = get_tree().get_first_node_in_group("hud")
			if not hud:
				hud = get_tree().root.find_child("HUD", true, false)
			if hud and hud.has_method("show_message"):
				hud.show_message("Health already full", 1.8)
		return

	_is_collected = true
	if body.has_method("heal"):
		body.heal(HEALTH_EFFECT)
	visible = false
	collision_shape_2d.set_deferred("disabled", true)
	collect_sound.play()
	await collect_sound.finished
	queue_free()

func _physics_process(_delta: float) -> void:
	if _is_collected:
		return
	# If player is overlapping and health is not full, collect it
	if PlayerStats.health < PlayerStats.max_health:
		for body in get_overlapping_bodies():
			if body.is_in_group("player") or body.name.begins_with("Player"):
				_on_body_entered(body)
				break
