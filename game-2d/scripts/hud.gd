extends CanvasLayer

const HEART_SIZE : int = 20
var player 

const HEART_FULL = preload("res://assets/images/UI/Heart_full.png")
const HEART_HALF = preload("res://assets/images/UI/heart_half.png")
const HEART_EMPTY = preload("res://assets/images/UI/empty_heart.png")

@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var hearts_container: HBoxContainer = $Heart
@onready var message_label: Label = get_node_or_null("MessageLabel")
@onready var handover_notice: PanelContainer = get_node_or_null("HandoverNotice")
@onready var handover_title: Label = get_node_or_null("HandoverNotice/MarginContainer/VBoxContainer/Title")
@onready var handover_subtitle: Label = get_node_or_null("HandoverNotice/MarginContainer/VBoxContainer/Subtitle")

var _message_tween: Tween = null
var _handover_tween: Tween = null

func _ready() -> void:
	if has_node("/root/PlayerStats"):
		var stats = get_node("/root/PlayerStats")
		if stats.has_signal("health_changed") and not stats.health_changed.is_connected(_update_health):
			stats.health_changed.connect(_update_health)
		_update_health(stats.health)

func show_handover_notice(title_text: String = "Give the controls to your friend!", subtitle_text: String = "Player 2 is now in control!") -> void:
	if not handover_notice:
		show_message(title_text + " - " + subtitle_text, 4.0)
		return
	
	if handover_title:
		handover_title.text = title_text
	if handover_subtitle:
		handover_subtitle.text = subtitle_text
	
	if _handover_tween and _handover_tween.is_valid():
		_handover_tween.kill()
	
	handover_notice.modulate.a = 0.0
	handover_notice.scale = Vector2(0.8, 0.8)
	handover_notice.pivot_offset = handover_notice.size / 2.0
	handover_notice.visible = true
	
	_handover_tween = create_tween().set_parallel(true)
	_handover_tween.tween_property(handover_notice, "modulate:a", 1.0, 0.3)
	_handover_tween.tween_property(handover_notice, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	var chain = create_tween()
	chain.tween_interval(3.8)
	chain.tween_property(handover_notice, "modulate:a", 0.0, 0.4)
	chain.tween_callback(func():
		if is_instance_valid(handover_notice):
			handover_notice.visible = false
	)

func show_message(text: String, duration: float = 2.5) -> void:
	if not message_label:
		return
	message_label.text = text
	if _message_tween and _message_tween.is_valid():
		_message_tween.kill()
	
	message_label.modulate.a = 0.0
	message_label.visible = true
	_message_tween = create_tween()
	_message_tween.tween_property(message_label, "modulate:a", 1.0, 0.25)
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)
	_message_tween.tween_callback(func(): 
		if is_instance_valid(message_label):
			message_label.visible = false
	)

func set_player(p) -> void:
	player = p
	register_player(p)

func register_player(p) -> void:
	if p and p.has_signal("health_changed"):
		if not p.health_changed.is_connected(_update_health):
			p.health_changed.connect(_update_health)
		_update_health(PlayerStats.health)
		
func _update_health(new_health: int) -> void:
	var hearts = hearts_container.get_children()
	var max_hearts = len(hearts)
	var full = int(new_health / HEART_SIZE)
	var half = 1 if(new_health % HEART_SIZE) > 0 else 0
	var empty = max_hearts - (full + half)

# Update full hearts
	for i in full:
		hearts[i].texture = HEART_FULL
	if half:
		hearts[full].texture = HEART_HALF
# Update the empty hearts
	for i in empty:
		hearts[len(hearts) - 1 - i].texture = HEART_EMPTY
	

func fade(to_alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", to_alpha, 0.8)
	await tween.finished


func show_death_message(text: String, duration: float = 2.2) -> void:
	var death_label = fade_overlay.get_node_or_null("DeathLabel")
	if not death_label:
		death_label = Label.new()
		death_label.name = "DeathLabel"
		death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		death_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		death_label.offset_left = 80.0
		death_label.offset_right = -80.0
		death_label.offset_top = 0.0
		death_label.offset_bottom = 0.0
		death_label.add_theme_font_override("font", preload("res://assets/images/font/NormalFont.ttf"))
		death_label.add_theme_font_size_override("font_size", 34)
		death_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1.0))
		death_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		death_label.add_theme_constant_override("outline_size", 6)
		fade_overlay.add_child(death_label)
	death_label.text = text
	death_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(death_label, "modulate:a", 1.0, 0.35)
	await tween.finished
	await get_tree().create_timer(duration).timeout
	var fade_out = create_tween()
	fade_out.tween_property(death_label, "modulate:a", 0.0, 0.25)
	await fade_out.finished


func show_epilogue_message(text: String, duration: float = 3.5) -> void:
	var epilogue_label = fade_overlay.get_node_or_null("EpilogueLabel")
	if not epilogue_label:
		epilogue_label = Label.new()
		epilogue_label.name = "EpilogueLabel"
		epilogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		epilogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		epilogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		epilogue_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		epilogue_label.offset_left = 120.0
		epilogue_label.offset_right = -120.0
		epilogue_label.offset_top = 0.0
		epilogue_label.offset_bottom = 0.0
		epilogue_label.add_theme_font_override("font", preload("res://assets/images/font/NormalFont.ttf"))
		epilogue_label.add_theme_font_size_override("font_size", 32)
		epilogue_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
		epilogue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
		epilogue_label.add_theme_constant_override("outline_size", 5)
		fade_overlay.add_child(epilogue_label)
	epilogue_label.text = text
	epilogue_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(epilogue_label, "modulate:a", 1.0, 0.6)
	await tween.finished
	await get_tree().create_timer(duration).timeout
	var fade_out = create_tween()
	fade_out.tween_property(epilogue_label, "modulate:a", 0.0, 0.5)
	await fade_out.finished
 
