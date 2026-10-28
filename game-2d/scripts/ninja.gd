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

# Obstacle steering bias: positive = favour right/CW side, negative = left/CCW
var _steer_bias: float = 0.0

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
	call_deferred("_init_overlapping_targets")

func _init_overlapping_targets() -> void:
	if not is_alive:
		return
	if sight:
		for body in sight.get_overlapping_bodies():
			if body.is_in_group("player") or body.name.begins_with("Player"):
				if body not in targets_in_sight:
					targets_in_sight.append(body)
		_update_ninja_target()
	if attack_range:
		for body in attack_range.get_overlapping_bodies():
			if body.is_in_group("player") or body.name.begins_with("Player"):
				if body not in targets_in_attack_range:
					targets_in_attack_range.append(body)
		player_in_attack_range = not targets_in_attack_range.is_empty()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if has_node("/root/DialogueManager") and DialogueManager.is_active:
		velocity = Vector2.ZERO
		if animated_sprite_2d and animated_sprite_2d.animation != "die":
			play_animation("idle", last_direction)
		return

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
		if not is_instance_valid(target) or target.get("alive") == false:
			target = null
			velocity = Vector2.ZERO
			play_animation("idle", last_direction)
			return

		var to_target = target.global_position - global_position
		var dist = to_target.length()
		var dir = to_target / dist if dist > 0.0 else Vector2.ZERO

		_update_direction_towards(dir)
		_update_hitbox_position()

		# Attack only when in attack range AND no wall is between ninja and player
		if player_in_attack_range and not _has_wall_between_us(dir, dist):
			_steer_bias = move_toward(_steer_bias, 0.0, delta * 4.0)
			velocity = Vector2.ZERO
			if attack_timer.is_stopped():
				_start_attack()
			else:
				play_animation("idle", last_direction)
			return

		# Navigate toward the player, steering around any obstacles
		var nav_dir = _get_nav_direction(dir, dist, delta)
		if nav_dir != Vector2.ZERO:
			velocity = nav_dir * SPEED
			move_and_slide()
			play_animation("walk", last_direction)
		else:
			# Truly cornered — stand idle, will retry next frame
			velocity = Vector2.ZERO
			play_animation("idle", last_direction)
	else:
		_steer_bias = 0.0
		velocity = Vector2.ZERO
		play_animation("idle", last_direction)


# Returns the best movement direction toward the player, going around walls.
# Returns Vector2.ZERO only when every candidate is fully blocked.
# NOTE: does NOT touch last_direction — facing is driven by dir_to_player only.
func _get_nav_direction(dir_to_target: Vector2, dist: float, delta: float) -> Vector2:
	var origin = global_position + Vector2(0, 14)
	var probe_len = min(52.0, dist)

	# 1. Direct path — use it if clear
	if not _ray_hits_wall(origin, dir_to_target, probe_len):
		_steer_bias = move_toward(_steer_bias, 0.0, delta * 3.0)
		return dir_to_target

	# 2. Direct path blocked: fan out angled candidates on both sides.
	#    _steer_bias commits to one lateral side to prevent frame-to-frame
	#    oscillation. We do NOT call _update_direction_towards here — facing
	#    is determined by the direction-to-player in the main loop, keeping
	#    the animation stable while the body steers around the obstacle.
	var test_angles = [20.0, 40.0, 60.0, 80.0, 100.0]
	var signs: Array = [1.0, -1.0] if _steer_bias >= 0.0 else [-1.0, 1.0]

	for angle in test_angles:
		for s in signs:
			var candidate = dir_to_target.rotated(deg_to_rad(angle * s))
			if not _ray_hits_wall(origin, candidate, probe_len):
				_steer_bias = move_toward(_steer_bias, s, delta * 5.0)
				return candidate

	# 3. All angled forward paths blocked — try pure perpendicular slides (wall-hug)
	var perp_cw  = Vector2(-dir_to_target.y,  dir_to_target.x)
	var perp_ccw = Vector2( dir_to_target.y, -dir_to_target.x)
	var perp_order: Array = [perp_cw, perp_ccw] if _steer_bias >= 0.0 else [perp_ccw, perp_cw]

	for perp in perp_order:
		if not _ray_hits_wall(origin, perp, probe_len):
			var side = 1.0 if perp == perp_cw else -1.0
			_steer_bias = move_toward(_steer_bias, side, delta * 5.0)
			return perp

	# 4. Completely surrounded — caller will play idle for this frame
	return Vector2.ZERO


# Raycast helper: returns true if a non-player wall blocks the path.
func _ray_hits_wall(origin: Vector2, dir: Vector2, length: float) -> bool:
	if dir == Vector2.ZERO or length <= 4.0:
		return false
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(origin, origin + dir * length, 1)
	query.exclude = [get_rid()]
	var hit = space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider = hit.collider
	# Player bodies are not walls
	if collider == target or (collider != null and collider.is_in_group("player")):
		return false
	return true


# Used only for the attack gate: is there a wall between the ninja and the player?
func _has_wall_between_us(dir: Vector2, dist: float) -> bool:
	return _ray_hits_wall(global_position + Vector2(0, 14), dir, min(dist, 80.0))


func _update_direction_towards(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return

	# Hysteresis prevents rapid flipping between cardinal directions
	var current_is_horizontal = (last_direction == Vector2.LEFT or last_direction == Vector2.RIGHT)
	var HYSTERESIS: float = 0.22

	if current_is_horizontal:
		if absf(dir.y) > absf(dir.x) + HYSTERESIS:
			last_direction = Vector2.DOWN if dir.y > 0.0 else Vector2.UP
		else:
			if last_direction == Vector2.RIGHT and dir.x < -0.15:
				last_direction = Vector2.LEFT
			elif last_direction == Vector2.LEFT and dir.x > 0.15:
				last_direction = Vector2.RIGHT
	else:
		if absf(dir.x) > absf(dir.y) + HYSTERESIS:
			last_direction = Vector2.RIGHT if dir.x > 0.0 else Vector2.LEFT
		else:
			if last_direction == Vector2.DOWN and dir.y < -0.15:
				last_direction = Vector2.UP
			elif last_direction == Vector2.UP and dir.y > 0.15:
				last_direction = Vector2.DOWN

func _update_hitbox_position() -> void:
	hit_box.position = last_direction * 75.0

func play_animation(prefix: String, dir: Vector2) -> void:
	var anim_name = prefix + "_down"
	match dir:
		Vector2.DOWN:
			anim_name = prefix + "_down"
		Vector2.UP:
			anim_name = prefix + "_up"
		Vector2.LEFT:
			anim_name = prefix + "_left"
		Vector2.RIGHT:
			anim_name = prefix + "_right"
		_:
			anim_name = prefix + "_down"

	if animated_sprite_2d.animation != anim_name:
		animated_sprite_2d.play(anim_name)
	elif not animated_sprite_2d.is_playing():
		animated_sprite_2d.play()

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
	var valid_targets: Array[Node2D] = []
	for p in targets_in_sight:
		if is_instance_valid(p) and p.get("alive") != false:
			valid_targets.append(p)
			var d = global_position.distance_squared_to(p.global_position)
			if d < min_dist:
				min_dist = d
				closest = p
	targets_in_sight = valid_targets
	target = closest

func _on_attack_range_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		if body not in targets_in_attack_range:
			targets_in_attack_range.append(body)
		player_in_attack_range = true

func _on_attack_range_body_exited(body: Node2D) -> void:
	if body in targets_in_attack_range:
		targets_in_attack_range.erase(body)
	var valid_targets: Array[Node2D] = []
	for b in targets_in_attack_range:
		if is_instance_valid(b) and b.get("alive") != false:
			valid_targets.append(b)
	targets_in_attack_range = valid_targets
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
