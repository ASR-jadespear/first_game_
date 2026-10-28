extends Area2D
@onready var collect_sound: AudioStreamPlayer2D = $CollectSound
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

const HEALTH_EFFECT: int = 20
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player") or body.has_method("heal"):
		if body.has_method("heal"):
			body.heal(HEALTH_EFFECT)
		visible = false
		collision_shape_2d.set_deferred("disabled",true)
		collect_sound.play()
		await collect_sound.finished
		queue_free()
