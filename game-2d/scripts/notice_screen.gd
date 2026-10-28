class_name NoticeScreen
extends CanvasLayer

signal notice_finished

@onready var root: Control = $Root
@onready var notice_label: Label = %NoticeLabel
@onready var prompt_label: Label = %PromptLabel

var _can_skip: bool = false
var _is_dismissed: bool = false
var _prompt_tween: Tween = null
var _auto_timer: SceneTreeTimer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root.modulate.a = 0.0
	if notice_label:
		notice_label.text = "This game is best played with 2 players, each playing one level.\n\nFeel free to enjoy the story as well"

func show_notice() -> void:
	_is_dismissed = false
	_can_skip = false
	visible = true
	root.modulate.a = 0.0

	_animate_prompt_pulse()

	var tween = create_tween()
	tween.tween_property(root, "modulate:a", 1.0, 0.45)
	await tween.finished

	# Brief grace period before accepting input to prevent accidental click-through
	await get_tree().create_timer(0.4).timeout
	_can_skip = true

	# Auto-continue after 6.5s if player doesn't press anything
	_auto_timer = get_tree().create_timer(6.5)
	_auto_timer.timeout.connect(_on_auto_timeout)

	await notice_finished

func _animate_prompt_pulse() -> void:
	if not prompt_label:
		return
	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()
	prompt_label.modulate.a = 0.35
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_prompt_tween.tween_property(prompt_label, "modulate:a", 0.35, 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_auto_timeout() -> void:
	if _can_skip and not _is_dismissed:
		_dismiss()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _can_skip or _is_dismissed:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or \
	   (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventJoypadButton and event.pressed):
		_dismiss()
		get_viewport().set_input_as_handled()

func _on_gui_input(event: InputEvent) -> void:
	if not visible or not _can_skip or _is_dismissed:
		return
	if event is InputEventMouseButton and event.pressed:
		_dismiss()
		get_viewport().set_input_as_handled()

func _dismiss() -> void:
	if _is_dismissed:
		return
	_is_dismissed = true
	_can_skip = false

	if _prompt_tween and _prompt_tween.is_valid():
		_prompt_tween.kill()

	var tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.35)
	await tween.finished

	visible = false
	notice_finished.emit()
