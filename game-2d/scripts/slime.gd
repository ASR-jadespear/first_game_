extends CharacterBody2D

signal defeated

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var take_damage_sound: AudioStreamPlayer2D = $TakeDamage
@onready var health_bar: Node2D = $HealthBar
@onready var attack_timer: Timer = $AttackTimer

const SPEED: float = 100.0
const KNOCKBACK_FORCE: float = 380.0
@export var can_drop_item: bool = true
@export var drop_chance: float = 1.0

var is_alive: bool = true
var health: int = 100
var target = null
var strength: int = 10
var target_in_range: bool = false

var knockback_velocity: Vector2 = Vector2.ZERO
var avoid_bias: float = 0.0

var health_pickup_scene = preload("res://scns/health_pickup.tscn")

func _ready() -> void:
	add_to_group("enemies")
	if animated_sprite_2d:
		animated_sprite_2d.animation_finished.connect(_on_animation_finished)

var targets_in_sight: Array[Node2D] = []
var targets_in_hitbox: Array[Node2D] = []

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if has_node("/root/DialogueManager") and DialogueManager.is_active:
		velocity = Vector2.ZERO
		if animated_sprite_2d and animated_sprite_2d.animation != "die":
			animated_sprite_2d.play("idle")
		return

	if targets_in_sight.size() > 1:
		_update_closest_target()

	# Handle physics-based knockback
	if knockback_velocity.length_squared() > 10.0:
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 1200.0 * delta)
		return

	if target:
		if target_in_range:
			velocity = Vector2.ZERO
			animated_sprite_2d.play("attack")
		else:
			var nav_dir = _get_nav_direction(target.global_position, 120.0)
			velocity = nav_dir * SPEED
			move_and_slide()
			animated_sprite_2d.play("attack")
			if velocity.x != 0:
				animated_sprite_2d.flip_h = velocity.x < 0
	else:
		velocity = Vector2.ZERO
		animated_sprite_2d.play("idle")

func _get_nav_direction(target_pos: Vector2, lookahead: float = 120.0) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var to_target = target_pos - global_position
	var dist = to_target.length()
	if dist < 5.0:
		return Vector2.ZERO
	var direct_dir = to_target / dist

	# 1. Test direct path towards target on Layer 1 (decorations, buildings, walls)
	var check_dist = min(lookahead, dist)
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + direct_dir * check_dist, 1)
	query.exclude = [get_rid()]
	var hit = space_state.intersect_ray(query)

	if hit.is_empty() or (target != null and hit.collider == target):
		avoid_bias = move_toward(avoid_bias, 0.0, 0.1)
		return direct_dir

	# 2. Path is blocked: probe whisker angles around the direct direction
	var test_angles = [25.0, 50.0, 75.0, 100.0, 125.0, 150.0]
	var best_dir = Vector2.ZERO
	var best_score = -99999.0
	var sign_order = [1.0, -1.0] if avoid_bias >= 0.0 else [-1.0, 1.0]

	for angle in test_angles:
		for s in sign_order:
			var candidate_dir = direct_dir.rotated(deg_to_rad(angle * s))
			var ray_query = PhysicsRayQueryParameters2D.create(
				global_position,
				global_position + candidate_dir * check_dist,
				1
			)
			ray_query.exclude = [get_rid()]
			var ray_hit = space_state.intersect_ray(ray_query)

			if ray_hit.is_empty() or (target != null and ray_hit.collider == target):
				var bias_bonus = 0.4 if (s == sign(avoid_bias) and avoid_bias != 0.0) else 0.0
				var score = candidate_dir.dot(direct_dir) + bias_bonus
				if score > best_score:
					best_score = score
					best_dir = candidate_dir
					avoid_bias = s
		if best_dir != Vector2.ZERO:
			break

	if best_dir != Vector2.ZERO:
		if is_on_wall():
			var wall_n = get_wall_normal()
			if best_dir.dot(wall_n) < 0:
				best_dir = (best_dir - wall_n * best_dir.dot(wall_n) + wall_n * 0.1).normalized()
		return best_dir

	# 3. If all whiskers hit, slide along wall normal
	var wall_normal = get_wall_normal() if is_on_wall() else (hit.normal if hit.has("normal") else Vector2.ZERO)
	if wall_normal != Vector2.ZERO:
		var t1 = Vector2(-wall_normal.y, wall_normal.x)
		var t2 = -t1
		var dot1 = t1.dot(direct_dir) + (0.2 if avoid_bias > 0 else 0.0)
		var dot2 = t2.dot(direct_dir) + (0.2 if avoid_bias < 0 else 0.0)
		if dot1 >= dot2:
			avoid_bias = 1.0
			return (t1 + wall_normal * 0.1).normalized()
		else:
			avoid_bias = -1.0
			return (t2 + wall_normal * 0.1).normalized()

	return direct_dir

func take_damage(damage: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not is_alive:
		return
	health -= damage
	if health_bar and is_instance_valid(health_bar):
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
		# Knockback via physics (respects collision with walls/obstacles)
		var knockback_direction: Vector2 = Vector2.ZERO
		if attacker_position != Vector2.ZERO:
			knockback_direction = (global_position - attacker_position).normalized()
		elif target:
			knockback_direction = (global_position - target.global_position).normalized()
		else:
			knockback_direction = Vector2.DOWN
		if knockback_direction == Vector2.ZERO:
			knockback_direction = Vector2.DOWN
		knockback_velocity = knockback_direction * KNOCKBACK_FORCE

func _die() -> void:
	is_alive = false
	target_in_range = false
	target = null
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	if attack_timer:
		attack_timer.stop()
	
	if health_bar and is_instance_valid(health_bar):
		health_bar.visible = false
	
	animated_sprite_2d.play("die")
	
	take_damage_sound.pitch_scale = 0.5
	take_damage_sound.play()
	
	$CollisionShape2D.set_deferred("disabled", true)
	$Sight/CollisionShape2D.set_deferred("disabled", true)
	$HitBox/CollisionShape2D.set_deferred("disabled", true)
	# Drop health pickup
	if can_drop_item and randf() <= drop_chance:
		drop_item()
	defeated.emit()

func _on_animation_finished() -> void:
	if animated_sprite_2d and animated_sprite_2d.animation == "die":
		var tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_property(self, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)

func _on_sight_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		if body not in targets_in_sight:
			targets_in_sight.append(body)
		_update_closest_target()

func _on_sight_body_exited(body: Node2D) -> void:
	if body in targets_in_sight:
		targets_in_sight.erase(body)
	_update_closest_target()

func _update_closest_target() -> void:
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
	if not target:
		velocity = Vector2.ZERO
		animated_sprite_2d.play("idle")

func _on_hit_box_body_entered(body: Node2D) -> void:
	if has_node("/root/DialogueManager") and DialogueManager.is_active:
		return
	if body.is_in_group("player") or body.name.begins_with("Player"):
		if body not in targets_in_hitbox:
			targets_in_hitbox.append(body)
		target_in_range = true
		if body.has_method("take_damage"):
			body.take_damage(strength)
		if attack_timer.is_stopped():
			attack_timer.start()

func _on_hit_box_body_exited(body: Node2D) -> void:
	if body in targets_in_hitbox:
		targets_in_hitbox.erase(body)
	target_in_range = not targets_in_hitbox.is_empty()
	if not target_in_range:
		attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if has_node("/root/DialogueManager") and DialogueManager.is_active:
		return
	if is_alive and target_in_range:
		for body in targets_in_hitbox:
			if is_instance_valid(body) and body.has_method("take_damage") and body.get("alive") != false:
				body.take_damage(strength)
				break

func drop_item():
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
