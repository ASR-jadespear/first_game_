class_name Player
extends CharacterBody2D

signal health_changed(new_health: int)
signal died
signal handover_triggered(new_leader: Node2D, follower: Node2D)
signal power_unleashed

enum ControlMode {
	LEADER,     # Controlled by keyboard/gamepad (WASD/arrows, SPACE to attack)
	FOLLOWER,   # Follows the leader closely behind
	WAITING     # Stands idle waiting for the other player to arrive
}

@export var control_mode: ControlMode = ControlMode.LEADER
@export var follow_target: Node2D = null

const SPEED = 600.0
var last_direction: Vector2 = Vector2.DOWN
var is_attacking: bool = false
var hit_enemies_this_attack: Array[Node2D] = []
var hitbox_offset: Vector2 = Vector2(64, 27)
var max_health: int = 100
var alive: bool = true
var health: int = 100
var strength: int = 20
var can_move: bool = true
var in_cutscene: bool = false
var is_immortal: bool = false
var can_unleash_power: bool = false
var _invincible_tween: Tween = null
var _stuck_timer: float = 0.0
var _last_stuck_pos: Vector2 = Vector2.ZERO

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var take_damage_sound: AudioStreamPlayer2D = get_node_or_null("TakeDamage")
@onready var swing_sword_sound: AudioStreamPlayer2D = get_node_or_null("SwingSword")
@onready var hit_box: Area2D = get_node_or_null("HitBox")
@onready var damage_cool_down: Timer = get_node_or_null("DamageCoolDown")
@onready var camera_2d: Camera2D = get_node_or_null("Camera2D")
@onready var interaction_area: Area2D = get_node_or_null("InteractionArea")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")


func _ready() -> void:
	health = PlayerStats.health
	max_health = PlayerStats.max_health
	if hit_box:
		hitbox_offset = hit_box.position
		hit_box.monitoring = false
		update_hitbox_offset()
		if not hit_box.area_entered.is_connected(_on_hit_box_area_entered):
			hit_box.area_entered.connect(_on_hit_box_area_entered)

	add_to_group("player")
	call_deferred("_setup_player_collision_exceptions")

	if has_node("/root/DialogueManager"):
		DialogueManager.dialogue_started.connect(func(): can_move = false)
		DialogueManager.dialogue_ended.connect(func():
			if not in_cutscene and control_mode != ControlMode.WAITING:
				can_move = true
		)

	if interaction_area:
		if not interaction_area.body_entered.is_connected(_on_interaction_area_body_entered):
			interaction_area.body_entered.connect(_on_interaction_area_body_entered)

	if prompt_label:
		prompt_label.visible = (control_mode == ControlMode.WAITING)

	_apply_control_mode()


func set_as_leader() -> void:
	control_mode = ControlMode.LEADER
	follow_target = null
	can_move = true
	_apply_control_mode()
	_setup_player_collision_exceptions()


func set_as_follower(leader: Node2D) -> void:
	control_mode = ControlMode.FOLLOWER
	follow_target = leader
	can_move = true
	_apply_control_mode()
	_setup_player_collision_exceptions()


func _setup_player_collision_exceptions() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p != self and p is CollisionObject2D:
			add_collision_exception_with(p)
			p.add_collision_exception_with(self)


func set_as_waiting() -> void:
	control_mode = ControlMode.WAITING
	follow_target = null
	can_move = false
	_apply_control_mode()


func _apply_control_mode() -> void:
	if camera_2d:
		camera_2d.enabled = (control_mode == ControlMode.LEADER)
		if control_mode == ControlMode.LEADER:
			camera_2d.make_current()

	if prompt_label:
		prompt_label.visible = (control_mode == ControlMode.WAITING)


func _unhandled_input(event: InputEvent) -> void:
	if control_mode == ControlMode.LEADER and alive and can_move and not in_cutscene:
		if can_unleash_power and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
			can_unleash_power = false
			power_unleashed.emit()
			get_viewport().set_input_as_handled()
			return

		if event.is_action_pressed("attack") and not event.is_echo():
			if not is_attacking:
				attack()
				get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	if not alive:
		return

	if is_attacking:
		if hit_box:
			hit_box.monitoring = true
			_check_hitbox_targets()
		if animated_sprite_2d and not animated_sprite_2d.animation.begins_with("attack"):
			is_attacking = false
			if hit_box:
				hit_box.monitoring = false
			hit_enemies_this_attack.clear()

	if not can_move and control_mode != ControlMode.WAITING:
		velocity = Vector2.ZERO
		play_animation("idle", last_direction)
		return

	match control_mode:
		ControlMode.LEADER:
			_process_leader()
		ControlMode.FOLLOWER:
			_process_follower(_delta)
		ControlMode.WAITING:
			velocity = Vector2.ZERO
			play_animation("idle", last_direction)


func _process_leader() -> void:
	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	if is_attacking:
		velocity = Vector2.ZERO
		return

	process_movement()
	move_and_slide()
	process_animation()


func _process_follower(delta: float) -> void:
	if not is_instance_valid(follow_target):
		velocity = Vector2.ZERO
		play_animation("idle", last_direction)
		return

	var to_target = follow_target.global_position - global_position
	var dist = to_target.length()

	var STOP_DIST = 110.0
	var SPRINT_DIST = 260.0
	var CATCHUP_DIST = 750.0

	if dist > CATCHUP_DIST:
		# If follower gets separated or trapped behind scenery, catch up close behind leader
		var dir = to_target.normalized()
		global_position = follow_target.global_position - dir * 130.0
		velocity = Vector2.ZERO
		_stuck_timer = 0.0
		_last_stuck_pos = global_position
		return

	if dist > STOP_DIST:
		# If trying to move but blocked by an obstacle/wall for > 1.2s, catch up
		if global_position.distance_squared_to(_last_stuck_pos) < 25.0:
			_stuck_timer += delta
			if _stuck_timer > 1.2:
				_stuck_timer = 0.0
				var dir = to_target.normalized()
				global_position = follow_target.global_position - dir * 130.0
				velocity = Vector2.ZERO
				_last_stuck_pos = global_position
				return
		else:
			_stuck_timer = 0.0
			_last_stuck_pos = global_position

		var dir = to_target.normalized()
		var move_speed = SPEED * 0.95
		if dist > SPRINT_DIST:
			move_speed = SPEED * 1.25

		velocity = dir * move_speed
		last_direction = dir
		update_hitbox_offset()
		move_and_slide()
		play_animation("run", last_direction)
	else:
		_stuck_timer = 0.0
		_last_stuck_pos = global_position
		velocity = Vector2.ZERO
		play_animation("idle", last_direction)


func process_movement() -> void:
	var direction := Input.get_vector("left", "right", "up", "down")
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


func play_animation(prefix: String, dir: Vector2) -> void:
	if not animated_sprite_2d:
		return
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_right")
	elif dir.y < 0:
		animated_sprite_2d.play(prefix + "_up")
	elif dir.y > 0:
		animated_sprite_2d.play(prefix + "_down")
	else:
		animated_sprite_2d.play(prefix + "_down")


func attack() -> void:
	if is_attacking or not alive:
		return
	is_attacking = true
	hit_enemies_this_attack.clear()
	update_hitbox_offset()
	if hit_box:
		hit_box.monitoring = true
	if swing_sword_sound:
		swing_sword_sound.pitch_scale = randf_range(0.92, 1.08)
		swing_sword_sound.play()
	play_animation("attack", last_direction)
	_check_hitbox_targets()


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		if hit_box:
			hit_box.monitoring = false
		hit_enemies_this_attack.clear()


func update_hitbox_offset() -> void:
	if not hit_box:
		return
	var reach: float = 65.0
	if absf(last_direction.x) >= absf(last_direction.y):
		if last_direction.x < 0.0:
			hit_box.position = Vector2(-reach, 14.0)
		else:
			hit_box.position = Vector2(reach, 14.0)
	else:
		if last_direction.y < 0.0:
			hit_box.position = Vector2(0.0, -reach)
		else:
			hit_box.position = Vector2(0.0, reach)


func _check_hitbox_targets() -> void:
	if not hit_box or not is_attacking or not alive:
		return
	for body in hit_box.get_overlapping_bodies():
		_deal_damage_to_target(body)
	for area in hit_box.get_overlapping_areas():
		var parent = area.get_parent()
		if parent and parent != self:
			_deal_damage_to_target(parent)


func _deal_damage_to_target(target: Node2D) -> void:
	if not is_attacking or not alive:
		return
	if target == self or target in hit_enemies_this_attack:
		return
	if target.is_in_group("player") or target.name.begins_with("Player"):
		return
	if target.is_in_group("enemies") or target.name.begins_with("Slime") or target.name.begins_with("Ninja") or target.has_method("take_damage"):
		hit_enemies_this_attack.append(target)
		if target.has_method("take_damage"):
			target.take_damage(strength, global_position)


func _on_hit_box_body_entered(body: Node2D) -> void:
	_deal_damage_to_target(body)


func _on_hit_box_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and parent != self:
		_deal_damage_to_target(parent)


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if control_mode == ControlMode.WAITING and (body.name.begins_with("Player") or body.is_in_group("player")):
		if body != self:
			trigger_handover(body)


func trigger_handover(arriving_player: Node2D) -> void:
	if control_mode != ControlMode.WAITING:
		return

	# This player becomes the Leader
	set_as_leader()

	# The arriving player becomes the Follower
	if arriving_player.has_method("set_as_follower"):
		arriving_player.set_as_follower(self)

	handover_triggered.emit(self, arriving_player)


func heal(amount: int) -> void:
	var new_health = PlayerStats.apply_heal(amount)
	health = new_health
	health_changed.emit(health)
	for p in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(p) and p != self:
			p.health = new_health
			if p.has_signal("health_changed"):
				p.health_changed.emit(new_health)


func activate_full_power(duration: float = 5.0) -> void:
	is_immortal = true
	var orig_strength = strength
	strength = orig_strength * 2

	if _invincible_tween and _invincible_tween.is_valid():
		_invincible_tween.kill()

	_invincible_tween = create_tween().set_loops()
	_invincible_tween.tween_property(animated_sprite_2d, "modulate", Color(2.8, 2.2, 0.4, 1.0), 0.15)
	_invincible_tween.tween_property(animated_sprite_2d, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)

	if swing_sword_sound:
		swing_sword_sound.pitch_scale = 1.3
		swing_sword_sound.play()

	await get_tree().create_timer(duration).timeout

	if _invincible_tween and _invincible_tween.is_valid():
		_invincible_tween.kill()
	if animated_sprite_2d:
		animated_sprite_2d.modulate = Color.WHITE

	is_immortal = false
	strength = orig_strength


func take_damage(amount: int) -> void:
	if is_immortal or not alive:
		return
	if damage_cool_down and damage_cool_down.time_left > 0:
		return
	if alive:
		if take_damage_sound:
			take_damage_sound.pitch_scale = randf_range(0.95, 1.05)
			take_damage_sound.play()

		# Visual hit flash
		if animated_sprite_2d:
			var flash = create_tween()
			flash.tween_property(animated_sprite_2d, "modulate", Color(1.8, 0.3, 0.3, 1), 0.08)
			flash.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.08)

		_shake_camera(8.0, 0.2)

		var new_health = PlayerStats.apply_damage(amount)
		health = new_health
		health_changed.emit(health)

		for p in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(p) and p != self:
				p.health = new_health
				if p.has_signal("health_changed"):
					p.health_changed.emit(new_health)

		if health <= 0:
			die()
			for p in get_tree().get_nodes_in_group("player"):
				if is_instance_valid(p) and p != self and p.get("alive") != false:
					p.die()
		elif damage_cool_down:
			damage_cool_down.start()


func _shake_camera(intensity: float, duration: float) -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam:
		cam = camera_2d
	if not cam:
		return
	var tween = create_tween()
	var step_time = duration / 4.0
	for i in range(4):
		var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cam, "offset", offset, step_time)
	tween.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func die() -> void:
	alive = false
	if animated_sprite_2d:
		animated_sprite_2d.play("dying")
		await animated_sprite_2d.animation_finished
	died.emit()
