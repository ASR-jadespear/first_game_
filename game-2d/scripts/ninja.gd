extends CharacterBody2D

signal defeated

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var take_damage_sound: AudioStreamPlayer2D = $TakeDamage
@onready var attack_sound: AudioStreamPlayer2D = $AttackSound
@onready var health_bar: Node2D = $HealthBar
@onready var attack_timer: Timer = $AttackTimer
@onready var hit_box: Area2D = $HitBox
@onready var sight: Area2D = $Sight
@onready var attack_range: Area2D = $AttackRange

const SPEED: float = 340.0
const LUNGE_SPEED: float = 160.0
const KNOCKBACK_FORCE: float = 400.0
@export var can_drop_item: bool = true
@export var drop_chance: float = 1.0

var is_alive: bool = true
var is_attacking: bool = false
var has_hit_in_current_attack: bool = false
var health: int = 100
var strength: int = 15
var target: Node2D = null
var player_in_attack_range: bool = false
var last_direction: Vector2 = Vector2.DOWN
var targets_in_sight: Array[Node2D] = []
var targets_in_attack_range: Array[Node2D] = []

var knockback_velocity: Vector2 = Vector2.ZERO

var health_pickup_scene: PackedScene = preload("res://scns/health_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	hit_box.monitoring = false
	animated_sprite_2d.animation_finished.connect(_on_animation_finished)
	animated_sprite_2d.frame_changed.connect(_on_frame_changed)
	sight.body_entered.connect(_on_sight_body_entered)
	sight.body_exited.connect(_on_sight_body_exited)
	attack_range.body_entered.connect(_on_attack_range_body_entered)
	attack_range.body_exited.connect(_on_attack_range_body_exited)
	hit_box.body_entered.connect(_on_hit_box_body_entered)
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if has_node("/root/DialogueManager") and DialogueManager.is_active:
		velocity = Vector2.ZERO
		if animated_sprite_2d and animated_sprite_2d.animation != "die":
			play_animation("idle", last_direction)
		return

	if targets_in_sight.size() > 1:
		_update_ninja_target()

	# Handle physics-based knockback
	if knockback_velocity.length_squared() > 10.0:
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1500.0 * delta)
		return
		
	if is_attacking:
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
		move_and_slide()
		return
		
	if target:
		var to_target = target.global_position - global_position
		var dist = to_target.length()
		var dir = to_target / dist if dist > 0.0 else Vector2.ZERO
		
		_update_direction(dir)
		_update_hitbox_position()
		
		if _is_facing_obstacle(dir):
			# Facing an obstacle: stop and go to idle state in last direction
			velocity = Vector2.ZERO
			play_animation("idle", last_direction)
		elif player_in_attack_range:
			velocity = Vector2.ZERO
			if attack_timer.is_stopped():
				_start_attack()
			else:
				play_animation("idle", last_direction)
		else:
			velocity = dir * SPEED
			move_and_slide()
			play_animation("walk", last_direction)
	else:
		velocity = Vector2.ZERO
		play_animation("idle", last_direction)

func _is_facing_obstacle(dir: Vector2) -> bool:
	# 1. If currently colliding with a wall/obstacle (excluding the player)
	if is_on_wall():
		for i in get_slide_collision_count():
			var col = get_slide_collision(i)
			var collider = col.get_collider()
			if collider != null and collider != target and not collider.is_in_group("player"):
				var wall_n = col.get_normal()
				if dir.dot(wall_n) < 0.1 or last_direction.dot(wall_n) < 0.1:
					return true

	# 2. Check directly in front of the ninja in last_direction and towards target
	var space_state = get_world_2d().direct_space_state
	var center = global_position + Vector2(0, 14)
	var check_dist = 55.0

	var check_dirs = [last_direction]
	if dir != Vector2.ZERO and dir != last_direction:
		check_dirs.append(dir)

	var perp = Vector2(-last_direction.y, last_direction.x) * 18.0
	var origins = [center, center + perp, center - perp]

	for o in origins:
		for d in check_dirs:
			var query = PhysicsRayQueryParameters2D.create(o, o + d * check_dist, 1)
			query.exclude = [get_rid()]
			var hit = space_state.intersect_ray(query)
			if not hit.is_empty():
				var collider = hit.collider
				if collider == target or (collider != null and collider.is_in_group("player")):
					continue
				return true

	return false

func _update_direction(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	if abs(dir.x) > abs(dir.y):
		last_direction = Vector2.RIGHT if dir.x > 0 else Vector2.LEFT
	else:
		last_direction = Vector2.DOWN if dir.y > 0 else Vector2.UP

func _update_hitbox_position() -> void:
	hit_box.position = last_direction * 75.0

func play_animation(prefix: String, dir: Vector2) -> void:
	match dir:
		Vector2.DOWN:
			animated_sprite_2d.play(prefix + "_down")
		Vector2.UP:
			animated_sprite_2d.play(prefix + "_up")
		Vector2.LEFT:
			animated_sprite_2d.play(prefix + "_left")
		Vector2.RIGHT:
			animated_sprite_2d.play(prefix + "_right")
		_:
			animated_sprite_2d.play(prefix + "_down")

func _start_attack() -> void:
	is_attacking = true
	has_hit_in_current_attack = false
	hit_box.monitoring = false
	attack_timer.start()
	
	velocity = last_direction * LUNGE_SPEED
	play_animation("attack", last_direction)

func _on_frame_changed() -> void:
	if not is_alive or not is_attacking:
		return
		
	if animated_sprite_2d.animation.begins_with("attack"):
		# Activate hit on the middle frame (frame 2 of 5: windup -> slash -> recovery)
		if animated_sprite_2d.frame == 2:
			hit_box.monitoring = true
			attack_sound.pitch_scale = randf_range(1.15, 1.3)
			attack_sound.play()
			for body in hit_box.get_overlapping_bodies():
				_try_hit_target(body)
		elif animated_sprite_2d.frame >= 4:
			hit_box.monitoring = false

func _try_hit_target(body: Node2D) -> void:
	if is_attacking and is_alive and not has_hit_in_current_attack:
		if body.is_in_group("player") or body.name.begins_with("Player"):
			has_hit_in_current_attack = true
			if body.has_method("take_damage"):
				body.take_damage(strength)

func _on_animation_finished() -> void:
	if animated_sprite_2d.animation.begins_with("attack"):
		is_attacking = false
		hit_box.monitoring = false
		velocity = Vector2.ZERO
		if is_alive:
			play_animation("idle", last_direction)
	elif animated_sprite_2d.animation == "die":
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)

func _on_attack_timer_timeout() -> void:
	if has_node("/root/DialogueManager") and DialogueManager.is_active:
		return
	if is_alive and player_in_attack_range and not is_attacking:
		_start_attack()

func _on_sight_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		if body not in targets_in_sight:
			targets_in_sight.append(body)
		_update_ninja_target()

func _on_sight_body_exited(body: Node2D) -> void:
	if body in targets_in_sight:
		targets_in_sight.erase(body)
	_update_ninja_target()

func _update_ninja_target() -> void:
	if not is_alive:
		target = null
		return
	var closest: Node2D = null
	var min_dist: float = INF
	for p in targets_in_sight:
		if is_instance_valid(p) and p.get("alive") != false:
			var d = global_position.distance_squared_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p
	target = closest

func _on_attack_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		if body not in targets_in_attack_range:
			targets_in_attack_range.append(body)
		player_in_attack_range = true

func _on_attack_range_body_exited(body: Node2D) -> void:
	if body in targets_in_attack_range:
		targets_in_attack_range.erase(body)
	player_in_attack_range = not targets_in_attack_range.is_empty()

func _on_hit_box_body_entered(body: Node2D) -> void:
	if has_node("/root/DialogueManager") and DialogueManager.is_active:
		return
	_try_hit_target(body)

func take_damage(damage: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	health -= damage
	health_bar.update_health(health)
	
	# Damage flash
	var flash = create_tween()
	flash.tween_property(animated_sprite_2d, "modulate", Color(2.0, 0.4, 0.4, 1), 0.08)
	flash.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.08)
	
	if health <= 0:
		_die()
	else:
		take_damage_sound.pitch_scale = randf_range(0.9, 1.1)
		take_damage_sound.play()
		
		# Knockback via physics (respects collision with walls/obstacles)
		var knockback_dir: Vector2 = Vector2.ZERO
		if attacker_position != Vector2.ZERO:
			knockback_dir = (global_position - attacker_position).normalized()
		elif target:
			knockback_dir = (global_position - target.global_position).normalized()
		else:
			knockback_dir = -last_direction
		if knockback_dir == Vector2.ZERO:
			knockback_dir = Vector2.DOWN
		knockback_velocity = knockback_dir * KNOCKBACK_FORCE
		if is_attacking:
			is_attacking = false
			hit_box.monitoring = false

func _die() -> void:
	is_alive = false
	is_attacking = false
	player_in_attack_range = false
	target = null
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	if attack_timer:
		attack_timer.stop()
	if health_bar:
		health_bar.visible = false
	
	animated_sprite_2d.play("die")
	
	take_damage_sound.pitch_scale = 0.6
	take_damage_sound.play()
	
	$CollisionShape2D.set_deferred("disabled", true)
	$Sight/CollisionShape2D.set_deferred("disabled", true)
	$AttackRange/CollisionShape2D.set_deferred("disabled", true)
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	
	if can_drop_item and randf() <= drop_chance:
		drop_item()
	defeated.emit()

func drop_item() -> void:
	if not health_pickup_scene:
		return
	var drop = health_pickup_scene.instantiate()
	var spawn_pos = global_position
	drop.position = spawn_pos
	
	var spawn_parent: Node = null
	var current: Node = self
	while current != null and current != get_tree().root:
		if current.has_node("items"):
			spawn_parent = current.get_node("items")
			break
		current = current.get_parent()
		
	if not spawn_parent:
		spawn_parent = owner if owner else get_parent()
	if not spawn_parent:
		spawn_parent = get_tree().current_scene
		
	if spawn_parent:
		spawn_parent.call_deferred("add_child", drop)
		drop.set_deferred("global_position", spawn_pos)
