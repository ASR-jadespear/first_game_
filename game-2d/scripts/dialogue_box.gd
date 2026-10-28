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
var portrait_cache: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	root_control.modulate.a = 0.0

	# Setup atlas textures for 32x32 front idle portraits (fallback)
	atlas_player1 = AtlasTexture.new()
	atlas_player1.atlas = TEXTURE_PLAYER1
	atlas_player1.region = Rect2(0, 0, 32, 32)

	atlas_player2 = AtlasTexture.new()
	atlas_player2.atlas = TEXTURE_PLAYER2
	atlas_player2.region = Rect2(0, 0, 32, 32)

	if portrait_texture:
		portrait_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	_preload_portraits()

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
	var portrait_key = line.get("portrait", line.get("potrait", ""))
	var tex = _resolve_portrait_texture(line.get("speaker", ""), str(portrait_key))
	if tex:
		portrait_texture.texture = tex
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


func _preload_portraits() -> void:
	var folders = ["the boy", "####"]
	for folder in folders:
		var dir_path = "res://assets/images/portrait/%s" % folder
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".png"):
					var full_path = "%s/%s" % [dir_path, file_name]
					_get_cached_texture(full_path)
				file_name = dir.get_next()
			dir.list_dir_end()


func _get_cached_texture(path: String) -> Texture2D:
	if portrait_cache.has(path):
		return portrait_cache[path]
	if ResourceLoader.exists(path):
		var tex = load(path) as Texture2D
		portrait_cache[path] = tex
		return tex
	return null


func _resolve_portrait_texture(speaker_raw: String, portrait_raw: String) -> Texture2D:
	var speaker = speaker_raw.strip_edges()
	var port = portrait_raw.strip_edges()
	var speaker_lower = speaker.to_lower()
	var port_lower = port.to_lower()

	# 1. Direct resource path
	if port.begins_with("res://"):
		return _get_cached_texture(port)

	# 2. Determine character folder
	var character_folder = ""
	if port_lower.begins_with("the boy/") or port_lower.begins_with("the boy\\"):
		character_folder = "the boy"
		port = port.substr(8)
	elif port_lower.begins_with("####/") or port_lower.begins_with("####\\"):
		character_folder = "####"
		port = port.substr(5)
	elif speaker_lower in ["the boy", "p1", "player1", "player 1", "boy"]:
		character_folder = "the boy"
	elif speaker_lower in ["####", "p2", "player2", "player 2", "hero", "the wanderer", "wanderer"]:
		character_folder = "####"
	elif port_lower in ["the boy", "p1", "player1", "player 1", "boy"]:
		character_folder = "the boy"
	elif port_lower in ["####", "p2", "player2", "player 2", "hero", "the wanderer", "wanderer"]:
		character_folder = "####"

	# 3. Determine filename
	var file_name = port.strip_edges()
	if file_name.is_empty() or file_name.to_lower() in ["the boy", "####", "player", "player1", "player2", "p1", "p2", "hero", "wanderer", "npc"]:
		file_name = "00.png"
	elif file_name.is_valid_int() and file_name.length() == 1:
		file_name = "%02d.png" % file_name.to_int()
	elif not file_name.ends_with(".png"):
		file_name += ".png"

	# 4. Try loading from portrait folder
	if not character_folder.is_empty():
		var path = "res://assets/images/portrait/%s/%s" % [character_folder, file_name]
		var tex = _get_cached_texture(path)
		if tex:
			return tex
		if character_folder == "####":
			var alt_path = "res://assets/images/portrait/Hero/%s" % file_name
			tex = _get_cached_texture(alt_path)
			if tex:
				return tex
		# Fallback to 00.png if specific image not found
		var fallback_path = "res://assets/images/portrait/%s/00.png" % character_folder
		tex = _get_cached_texture(fallback_path)
		if tex:
			return tex

	# 5. Legacy atlas fallback
	if character_folder == "the boy":
		return atlas_player1
	elif character_folder == "####":
		return atlas_player2

	return null
