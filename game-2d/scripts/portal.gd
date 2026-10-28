class_name Portal
extends Area2D

@export var is_fake: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_disappearing: bool = false

func _ready() -> void:
	# Automatically detect if this portal was named 'fake_portal' or similar
	if name == "fake_portal" or name.to_lower().begins_with("fake"):
		is_fake = true

	# Ensure the portal animation is actively playing
	if animated_sprite:
		animated_sprite.play("portal")


func _on_body_entered(body: Node2D) -> void:
	# Only react to the player character
	if not (body.name == "Player" or body.is_in_group("player")):
		return

	if is_fake:
		if has_node("/root/DialogueManager"):
			DialogueManager.start_dialogue([
				{
					"speaker": "The Boy",
					"portrait": "08",
					"text": "Looks like this portal is fake, we can’t go through it…. Damn you developers"
				},
				{
					"speaker": "####",
					"portrait": "21",
					"text": "Calm down’, we'll find the real one, we just have to keep going."
				}
			])
		_disappear()


func _disappear() -> void:
	if _is_disappearing:
		return
	_is_disappearing = true

	# Disable collision immediately so it cannot trigger again
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# Smooth disappearance effect (shrink + fade out), then queue_free
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.25)
	tween.chain().tween_callback(queue_free)

