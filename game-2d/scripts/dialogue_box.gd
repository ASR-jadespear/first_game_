extends CanvasLayer

signal dialogue_completed

const TEXTURE_PLAYER1 = preload("res://assets/images/player/Player.png")
const TEXTURE_PLAYER2 = preload("res://assets/images/player/Player2.png")

@onready var root_control: Control = $Root
@onready var box_container: Control = $Root/BoxContainer
@onready var portrait_texture: TextureRect = %PortraitTexture
@onready var speaker_label: Label = %SpeakerNameLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var next_button: TextureButton = %NextButton
@onready var next_hint_label: Label = %NextHintLabel
@onready var click_area: Control = $Root/ClickArea
@onready var type_sound: AudioStreamPlayer = $TypeSound
@onready var select_sound: AudioStreamPlayer = $SelectSound

var dialogue_queue: Array = []
var current_index: int = 0
var is_active: bool = false
var is_typing: bool = false

var typing_tween: Tween = null
var bounce_tween: Tween = null
var base_next_y: float = 0.0

var atlas_player1: AtlasTexture
var atlas_player2: AtlasTexture

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root_control.modulate.a = 0.0

	# Setup atlas textures for 32x32 front idle portraits
	atlas_player1 = AtlasTexture.new()
	atlas_player1.atlas = TEXTURE_PLAYER1
	atlas_player1.region = Rect2(0, 0, 32, 32)

	atlas_player2 = AtlasTexture.new()
	atlas_player2.atlas = TEXTURE_PLAYER2
	atlas_player2.region = Rect2(0, 0, 32, 32)

	base_next_y = next_button.position.y
	next_button.pressed.connect(_on_next_pressed)
	click_area.gui_input.connect(_on_click_area_gui_input)

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Handle Left Click anywhere
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		get_viewport().set_input_as_handled()
	# Handle Space, Enter, or E
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			advance()
			get_viewport().set_input_as_handled()

func _on_click_area_gui_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		advance()
		get_viewport().set_input_as_handled()

func start(lines: Array) -> void:
	dialogue_queue = lines
	current_index = 0
	is_active = true
	visible = true

	# Fade & slide in animation
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	root_control.modulate.a = 0.0
	box_container.position.y = (720 - 238 - 22) + 20
	tween.tween_property(root_control, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(box_container, "position:y", 720 - 238 - 22, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_show_line(0)

func _show_line(idx: int) -> void:
	if idx >= dialogue_queue.size():
		_close_dialogue()
		return

	var line: Dictionary = dialogue_queue[idx]

	# Update Speaker Name
	speaker_label.text = line.get("speaker", "???")

	# Update Portrait
	var speaker_name: String = str(line.get("speaker", "")).to_lower()
	var portrait_key: String = str(line.get("portrait", "")).to_lower()
	if portrait_key in ["player", "player1", "hero", "the boy", "p1"] or speaker_name in ["the boy", "hero", "player 1", "p1"]:
		portrait_texture.texture = atlas_player1
		portrait_texture.visible = true
	elif portrait_key in ["player2", "npc", "wanderer", "####", "p2"] or speaker_name in ["####", "player 2", "p2", "wanderer"]:
		portrait_texture.texture = atlas_player2
		portrait_texture.visible = true
	else:
		portrait_texture.visible = false

	# Setup Dialogue Text
	dialogue_label.text = line.get("text", "")
	dialogue_label.visible_ratio = 0.0

	# Hide next indicator while typing
	next_button.visible = false
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()

	is_typing = true
	var char_count = dialogue_label.text.length()
	var duration = clampf(char_count * 0.025, 0.4, 2.5)

	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()

	typing_tween = create_tween()
	typing_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	typing_tween.tween_property(dialogue_label, "visible_ratio", 1.0, duration)
	typing_tween.finished.connect(_on_typing_finished)

	_play_typing_audio(duration)

func _play_typing_audio(duration: float) -> void:
	var step: float = 0.07
	var count: int = int(duration / step)
	for i in range(mini(count, 15)):
		get_tree().create_timer(i * step).timeout.connect(func():
			if is_typing and is_active:
				type_sound.pitch_scale = randf_range(2.2, 2.6)
				type_sound.play()
		)

func _on_typing_finished() -> void:
	is_typing = false
	dialogue_label.visible_ratio = 1.0
	next_button.visible = true
	_start_next_bounce()

func _start_next_bounce() -> void:
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
	bounce_tween = create_tween().set_loops()
	bounce_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	bounce_tween.tween_property(next_button, "position:y", base_next_y + 4.0, 0.4).set_trans(Tween.TRANS_SINE)
	bounce_tween.tween_property(next_button, "position:y", base_next_y - 4.0, 0.4).set_trans(Tween.TRANS_SINE)

func advance() -> void:
	if not is_active:
		return

	if is_typing:
		# Fast-forward text
		if typing_tween and typing_tween.is_valid():
			typing_tween.kill()
		_on_typing_finished()
		select_sound.pitch_scale = 1.8
		select_sound.play()
	else:
		# Advance to next line
		select_sound.pitch_scale = 1.4
		select_sound.play()
		current_index += 1
		_show_line(current_index)

func _on_next_pressed() -> void:
	advance()

func _close_dialogue() -> void:
	is_active = false
	is_typing = false
	if bounce_tween and bounce_tween.is_valid():
		bounce_tween.kill()
	if typing_tween and typing_tween.is_valid():
		typing_tween.kill()

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root_control, "modulate:a", 0.0, 0.15)
	await tween.finished
	visible = false
	dialogue_completed.emit()
