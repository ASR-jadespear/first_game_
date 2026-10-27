extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var take_damage_sound: AudioStreamPlayer2D = $TakeDamage
@onready var health_bar: Node2D = $HealthBar
@onready var attack_timer: Timer = $AttackTimer

const SPEED: int = 100.0
const KNOCKBACK_FORCE: int = 100
const DROP_CHANCE: float = 1.0

var is_alive: bool = true
var health: int = 100
var target = null
var strength : int = 10
var target_in_range : bool = false

var health_pickup_scene = preload("res://scns/health_pickup.tscn")

func _physics_process(delta: float) -> void:
	if is_alive and target:
		_attack(delta)

#the movement is independent
func _attack(delta: float) ->void:
	var direction = (target.position - position).normalized()
	position += direction * SPEED * delta
	animated_sprite_2d.play("attack")
	

func take_damage(damage: int, attacker_position: Vector2) -> void:
	health -= damage
	health_bar.update_health(health)
	
	# Damage flash
	var flash = create_tween()
	flash.tween_property(animated_sprite_2d, "modulate", Color(2.0, 2.0, 2.0, 1), 0.08)
	flash.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.08)
	
	if health <= 0:
		_die()
	else:
		take_damage_sound.pitch_scale = randf_range(0.9, 1.1)
		take_damage_sound.play()
		#knockBack
		var knockback_direction = (position - attacker_position).normalized()
		var target_position = position + knockback_direction * KNOCKBACK_FORCE
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		
		tween.tween_property(self, "position", target_position, 0.5)
		
func _die() -> void:
	# 1. This must be a single equals sign so the physics process stops
	is_alive = false
	
	animated_sprite_2d.play("die")
	
	take_damage_sound.pitch_scale = 0.5
	take_damage_sound.play()
	
	# 2. Disable collisions so it becomes a harmless background puddle
	$CollisionShape2D.set_deferred("disabled", true)
	$Sight/CollisionShape2D.set_deferred("disabled", true)
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	#drop health pickup
	if randf() <= DROP_CHANCE:
		drop_item()
	
func _on_sight_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		target = body

func _on_sight_body_exited(body: Node2D) -> void:
	if body.name == "Player" and is_alive:
		target = null
		animated_sprite_2d.play("idle")


func _on_hit_box_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		target_in_range = true
		body.take_damage(strength)
		attack_timer.start()

func _on_hit_box_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		target_in_range = false
		attack_timer.stop()
		
		
func _on_attack_timer_timeout() -> void:
	if target and target_in_range:
		target.take_damage(strength)
		
func drop_item():
	var drop = health_pickup_scene.instantiate()
	drop.position = position 
	var level_root = get_parent().get_parent()
	var items_node = level_root.get_node("items")
	items_node.call_deferred("add_child",drop)
	 
