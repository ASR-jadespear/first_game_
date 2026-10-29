extends Node

signal dialogue_started
signal dialogue_ended
signal dialogue_line_changed(speaker_name: String, text: String, portrait_key: String)

var dialogue_box_scene: PackedScene = preload("res://scns/dialogue_box.tscn")
var dialogue_box: CanvasLayer = null
var is_active: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_box = dialogue_box_scene.instantiate()
	add_child(dialogue_box)
	dialogue_box.dialogue_completed.connect(_on_dialogue_completed)

func start_dialogue(lines: Array) -> void:
	if lines.is_empty():
		return
	is_active = true
	dialogue_started.emit()
	dialogue_box.start(lines)

func stop_dialogue() -> void:
	if not is_active and (not dialogue_box or not dialogue_box.visible):
		return
	is_active = false
	if is_instance_valid(dialogue_box):
		dialogue_box.force_close()
	dialogue_ended.emit()

func _on_dialogue_completed() -> void:
	is_active = false
	dialogue_ended.emit()
