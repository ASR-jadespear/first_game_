class_name StartScreen
extends CanvasLayer

signal start_game
signal exit_game

@onready var root: Control = $Root
@onready var start_btn: Button = %StartBtn
@onready var about_btn: Button = %AboutBtn
@onready var exit_btn: Button = %ExitBtn
@onready var about_dialog: Control = %AboutDialog
@onready var close_about_btn: Button = %CloseAboutBtn
@onready var ui_sound: AudioStreamPlayer = $UISound
@onready var title_label: Label = %Title

var _title_tween: Tween = null
var _is_transitioning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = true
	if about_dialog:
		about_dialog.visible = false
	root.modulate.a = 1.0

	start_btn.pressed.connect(_on_start_pressed)
	about_btn.pressed.connect(_on_about_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	if close_about_btn:
		close_about_btn.pressed.connect(_on_close_about_pressed)

	for btn in [start_btn, about_btn, exit_btn, close_about_btn]:
		if btn:
			btn.mouse_entered.connect(_play_ui_hover)
			btn.focus_entered.connect(_play_ui_hover)
			btn.pressed.connect(_play_ui_select)

	start_btn.grab_focus()
	_animate_title_pulse()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if about_dialog and about_dialog.visible:
		if event.is_action_pressed("ui_cancel") or (
			event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
		):
			_on_close_about_pressed()
			get_viewport().set_input_as_handled()

func _animate_title_pulse() -> void:
	if not title_label:
		return
	if _title_tween and _title_tween.is_valid():
		_title_tween.kill()
	title_label.pivot_offset = title_label.size / 2.0
	_title_tween = create_tween().set_loops()
	_title_tween.tween_property(title_label, "scale", Vector2(1.03, 1.03), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func open() -> void:
	_is_transitioning = false
	visible = true
	if about_dialog:
		about_dialog.visible = false
	root.modulate.a = 1.0
	start_btn.grab_focus()
	_animate_title_pulse()

func close() -> void:
	var tween = create_tween()
	tween.tween_property(root, "modulate:a", 0.0, 0.4)
	await tween.finished
	visible = false

func _on_start_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	close()
	start_game.emit()
	if get_parent() == get_tree().root:
		get_tree().change_scene_to_file("res://scns/main.tscn")

func _on_about_pressed() -> void:
	if not about_dialog:
		return
	about_dialog.modulate.a = 0.0
	about_dialog.visible = true
	var tween = create_tween()
	tween.tween_property(about_dialog, "modulate:a", 1.0, 0.2)
	if close_about_btn:
		close_about_btn.grab_focus()

func _on_close_about_pressed() -> void:
	if not about_dialog:
		return
	var tween = create_tween()
	tween.tween_property(about_dialog, "modulate:a", 0.0, 0.15)
	await tween.finished
	about_dialog.visible = false
	about_btn.grab_focus()

func _on_exit_pressed() -> void:
	exit_game.emit()
	get_tree().quit()

func _play_ui_hover() -> void:
	if ui_sound:
		ui_sound.pitch_scale = randf_range(1.15, 1.3)
		ui_sound.play()

func _play_ui_select() -> void:
	if ui_sound:
		ui_sound.pitch_scale = 0.9
		ui_sound.play()
