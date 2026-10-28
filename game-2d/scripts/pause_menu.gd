extends CanvasLayer

signal resume_game
signal restart_level
signal return_to_main_menu

@onready var root: Control = $Root
@onready var resume_btn: Button = %ResumeBtn
@onready var restart_btn: Button = %RestartBtn
@onready var main_menu_btn: Button = %MainMenuBtn
@onready var quit_btn: Button = %QuitBtn
@onready var confirm_dialog: Control = %ConfirmDialog
@onready var confirm_yes_btn: Button = %ConfirmYesBtn
@onready var confirm_no_btn: Button = %ConfirmNoBtn

@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValLabel

@onready var music_slider: HSlider = %MusicSlider
@onready var music_val_label: Label = %MusicValLabel

@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_val_label: Label = %SfxValLabel

@onready var fullscreen_chk: CheckBox = %FullscreenChk
@onready var ui_sound: AudioStreamPlayer = $UISound

var is_paused: bool = false
var can_pause: bool = true
var _audio_ready: bool = false

func _ready() -> void:
	# Keep processing input when tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root.modulate.a = 0.0

	# Connect buttons
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	main_menu_btn.pressed.connect(_on_main_menu_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	confirm_yes_btn.pressed.connect(_on_confirm_yes_pressed)
	confirm_no_btn.pressed.connect(_on_confirm_no_pressed)

	if confirm_dialog:
		confirm_dialog.visible = false

	# Sound on button hover & focus
	for btn in [resume_btn, restart_btn, main_menu_btn, quit_btn, confirm_yes_btn, confirm_no_btn]:
		if btn:
			btn.mouse_entered.connect(_play_ui_hover)
			btn.focus_entered.connect(_play_ui_hover)
			btn.pressed.connect(_play_ui_select)

	# Connect sliders
	master_slider.value_changed.connect(_on_master_slider_changed)
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	fullscreen_chk.toggled.connect(_on_fullscreen_toggled)

	# Initialize audio slider values from audio buses
	_sync_slider("Master", master_slider, master_val_label)
	_sync_slider("Music", music_slider, music_val_label)
	_sync_slider("SFX", sfx_slider, sfx_val_label)
	_audio_ready = true

	# Initialize fullscreen state
	fullscreen_chk.button_pressed = (
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)

func _unhandled_input(event: InputEvent) -> void:
	if not can_pause:
		return
	if event.is_action_pressed("ui_cancel") or (
		event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
	):
		if is_paused and confirm_dialog and confirm_dialog.visible:
			_close_confirm_dialog()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()

func pause() -> void:
	is_paused = true
	get_tree().paused = true
	visible = true
	if confirm_dialog:
		confirm_dialog.visible = false
	resume_btn.grab_focus()

	# Smooth animate menu entrance
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 1.0, 0.15)

func resume() -> void:
	is_paused = false
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 0.0, 0.1)
	await tween.finished
	visible = false
	get_tree().paused = false
	resume_game.emit()

func _on_resume_pressed() -> void:
	resume()

func _on_restart_pressed() -> void:
	is_paused = false
	get_tree().paused = false
	visible = false
	root.modulate.a = 0.0
	restart_level.emit()

func _on_main_menu_pressed() -> void:
	if not confirm_dialog:
		return
	confirm_dialog.modulate.a = 0.0
	confirm_dialog.visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(confirm_dialog, "modulate:a", 1.0, 0.15)
	confirm_no_btn.grab_focus()

func _close_confirm_dialog() -> void:
	if not confirm_dialog:
		return
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(confirm_dialog, "modulate:a", 0.0, 0.1)
	await tween.finished
	confirm_dialog.visible = false
	main_menu_btn.grab_focus()

func _on_confirm_no_pressed() -> void:
	_close_confirm_dialog()

func _on_confirm_yes_pressed() -> void:
	is_paused = false
	get_tree().paused = false
	visible = false
	if confirm_dialog:
		confirm_dialog.visible = false
	root.modulate.a = 0.0
	return_to_main_menu.emit()

func _sync_slider(bus_name: String, slider: HSlider, label: Label) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		var db = AudioServer.get_bus_volume_db(bus_idx)
		var linear = db_to_linear(db)
		slider.value = linear
		label.text = "%d%%" % int(round(linear * 100))

func _set_bus_volume(bus_name: String, value: float, label: Label) -> void:
	label.text = "%d%%" % int(round(value * 100))
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		if value <= 0.01:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value))

func _on_master_slider_changed(value: float) -> void:
	_set_bus_volume("Master", value, master_val_label)

func _on_music_slider_changed(value: float) -> void:
	_set_bus_volume("Music", value, music_val_label)

func _on_sfx_slider_changed(value: float) -> void:
	_set_bus_volume("SFX", value, sfx_val_label)
	# Play test sound so player hears the new SFX volume level
	if _audio_ready and is_paused:
		_play_preview_sound()

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	_play_ui_select()
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()

func _play_ui_hover() -> void:
	if not is_paused or not _audio_ready:
		return
	ui_sound.pitch_scale = randf_range(1.5, 1.7)
	ui_sound.play()

func _play_ui_select() -> void:
	if not _audio_ready:
		return
	ui_sound.pitch_scale = 1.2
	ui_sound.play()

func _play_preview_sound() -> void:
	if ui_sound.playing:
		return
	ui_sound.pitch_scale = 1.0
	ui_sound.play()
