extends StaticBody2D

signal opened

@export var drop_scene: PackedScene = preload("res://scns/health_pickup.tscn")
@export var drop_count: int = 2
@export var can_drop_items: bool = true

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel
@onready var open_sound: AudioStreamPlayer2D = $OpenSound

var is_open: bool = false
var player_in_range: bool = false

func _ready() -> void:
	add_to_group("chests")
	if prompt_label:
		prompt_label.visible = false
	if animated_sprite_2d:
		animated_sprite_2d.play("closed")
		
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_body_entered)
		interaction_area.body_exited.connect(_on_interaction_area_body_exited)

func _on_interaction_area_body_entered(body: Node2D) -> void:
	if is_open:
		return
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = true
		if prompt_label:
			prompt_label.visible = true

func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not is_open:
		if event.is_action_pressed("ui_accept") or (
			event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
		):
			open()
			get_viewport().set_input_as_handled()

func take_damage(_damage: int = 0, _attacker_position: Vector2 = Vector2.ZERO) -> void:
	if not is_open:
		open()

func open() -> void:
	if is_open:
		return
	is_open = true
	player_in_range = false
	
	if prompt_label:
		prompt_label.visible = false
		
	if animated_sprite_2d:
		animated_sprite_2d.play("open_chest")
		
	if open_sound:
		open_sound.pitch_scale = randf_range(0.85, 0.95)
		open_sound.play()
		
	opened.emit()
	if can_drop_items and drop_count > 0:
		_spawn_drops()

func _find_items_container() -> Node:
	var current: Node = self
	while current != null and current != get_tree().root:
		if current.has_node("items"):
			return current.get_node("items")
		current = current.get_parent()
	if owner:
		return owner
	if get_parent():
		return get_parent()
	return get_tree().current_scene

func _spawn_drops() -> void:
	if not drop_scene:
		return
		
	var spawn_parent: Node = _find_items_container()
	if not spawn_parent:
		return
		
	for i in range(drop_count):
		var drop = drop_scene.instantiate()
		var offset_x = (i - (drop_count - 1.0) / 2.0) * 50.0
		var target_pos = global_position + Vector2(offset_x, 60.0)
		drop.position = global_position
		spawn_parent.call_deferred("add_child", drop)
		_animate_drop_deferred(drop, target_pos)

func _animate_drop_deferred(drop: Node2D, target_pos: Vector2) -> void:
	await get_tree().process_frame
	if not is_instance_valid(drop):
		return
	
	var col: CollisionShape2D = drop.get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
		
	drop.global_position = global_position + Vector2(0, -10)
	var tween = create_tween()
	var mid_y = global_position.y - 40.0
	tween.tween_property(drop, "global_position", Vector2(target_pos.x, mid_y), 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(drop, "global_position", target_pos, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	await tween.finished
	
	if is_instance_valid(col):
		col.set_deferred("disabled", false)
