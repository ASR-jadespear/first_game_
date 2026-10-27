extends CharacterBody2D

signal health_changed(new_health: int)
signal died

const SPEED = 600.0
var last_direction: Vector2 = Vector2.RIGHT
var is_attacking: bool = false
var hitbox_offset: Vector2
var max_health: int = 100
var alive: bool = true
var health: int = 100
var strength: int = 20
var can_move: bool = true

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var take_damage_sound: AudioStreamPlayer2D = $TakeDamage
@onready var swing_sword_sound: AudioStreamPlayer2D = $SwingSword
@onready var hit_box: Area2D = $HitBox
@onready var damage_cool_down: Timer = $DamageCoolDown

func _ready() -> void:	
	# load health from simpleton
	health = PlayerStats.health
	max_health = PlayerStats.max_health
	# initialization hitbox offset
	hitbox_offset = hit_box.position
	
	add_to_group("player")
	
	if has_node("/root/DialogueManager"):
		DialogueManager.dialogue_started.connect(func(): can_move = false)
		DialogueManager.dialogue_ended.connect(func(): can_move = true)
	
func _physics_process(_dddelta: float) -> void:
	# disabled an attack unless an attack is triggered
	hit_box.monitoring = false
	
	if !can_move:
		velocity = Vector2.ZERO
		play_animation("idle", last_direction)
		return
		
	if alive:
		if Input.is_action_just_pressed("attack") and not is_attacking:
			attack()

		#Skip Movement
		if is_attacking:
			velocity = Vector2.ZERO
			return
		process_movement()
		move_and_slide()
		process_animation()



	#------------------------------------------------------------
	#MOVEMENT_ANIMATION
	#_____________________________________________________________
	
func process_movement() -> void:
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_vector("left", "right", "up","down")
	
	#the player is moving
	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		last_direction = direction
		update_hitbox_offset()
	else:
		velocity = Vector2.ZERO


func process_animation() -> void:
	if is_attacking:
		return
	if velocity != Vector2.ZERO:
		play_animation("run", last_direction)
	else:
		play_animation("idle", last_direction)
		
func play_animation(prefix: String, dir : Vector2) -> void:
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_right")
	elif dir.y < 0:
		animated_sprite_2d.play(prefix + "_up") 
	elif dir.y >0:
		animated_sprite_2d.play(prefix + "_down")
				
#------------------------------------------------------------
	# ATTACKING
#_____________________________________________________________
func attack() ->void:
	is_attacking = true
	hit_box.monitoring = true
	swing_sword_sound.pitch_scale = randf_range(0.92, 1.08)
	swing_sword_sound.play()	
	play_animation("attack",last_direction)


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false


#------------------------------------------------------------
	# HitBox
#_____________________________________________________________
func update_hitbox_offset() -> void:
	var x = hitbox_offset.x
	var y = hitbox_offset.y
	
	match last_direction:
		Vector2.LEFT:
			hit_box.position = Vector2(-x,y)
		Vector2.RIGHT:
			hit_box.position = Vector2(x,y)
		Vector2.UP:
			hit_box.position = Vector2(y,-x)
		Vector2.DOWN:
			hit_box.position = Vector2(y,x)


func _on_hit_box_body_entered(body: Node2D) -> void:
	if is_attacking and body.name.begins_with("Slime"):
		body.take_damage(strength, position) 
		

func heal(amount : int) -> void:
	health += amount
	if health > max_health:
		health = max_health
	PlayerStats.health = health
	emit_signal("health_changed",health)

func take_damage(amount : int) -> void:
	if damage_cool_down.time_left > 0:
		return 
	if alive:	
		take_damage_sound.pitch_scale = randf_range(0.95, 1.05)
		take_damage_sound.play()
		
		# Visual hit flash
		var flash = create_tween()
		flash.tween_property(animated_sprite_2d, "modulate", Color(1.5, 0.3, 0.3, 1), 0.08)
		flash.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.08)
		
		# Subtle screen shake
		_shake_camera(8.0, 0.2)
		
		health -= amount
		PlayerStats.health = health
		emit_signal("health_changed",health)
		if health <= 0:
			die()
		# Make Player invincible for a short time
		damage_cool_down.start()

func _shake_camera(intensity: float, duration: float) -> void:
	var cam = get_node_or_null("Camera2D")
	if not cam:
		return
	var tween = create_tween()
	var step_time = duration / 4.0
	for i in range(4):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cam, "offset", offset, step_time)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)

	
func die() -> void:
	animated_sprite_2d.play("dying")
	alive = false
	await animated_sprite_2d.animation_finished
	died.emit()
