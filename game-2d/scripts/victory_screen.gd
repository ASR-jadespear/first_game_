class_name VictoryScreen
extends CanvasLayer

signal restart_game
signal exit_game

@onready var root: Control = $Root
@onready var restart_btn: Button = %RestartBtn
@onready var exit_btn: Button = %ExitBtn
@onready var ui_sound: AudioStreamPlayer = $UISound

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root.modulate.a = 0.0

	restart_btn.pressed.connect(_on_restart_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)

	for btn in [restart_btn, exit_btn]:
		btn.mouse_entered.connect(_play_ui_hover)
		btn.focus_entered.connect(_play_ui_hover)
		btn.pressed.connect(_play_ui_select)


func open() -> void:
	visible = true
	get_tree().paused = true
	restart_btn.grab_focus()

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 1.0, 0.35)


func close() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 0.0, 0.15)
	await tween.finished
	visible = false
	get_tree().paused = false


func _on_restart_pressed() -> void:
	close()
	restart_game.emit()


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

