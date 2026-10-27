extends CharacterBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel

var player_in_range: bool = false
var has_talked_once: bool = false

func _ready() -> void:
	animated_sprite.play("idle_down")
	if prompt_label:
		prompt_label.visible = false

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = true
		if not has_talked_once:
			has_talked_once = true
			# Trigger dialogue automatically on first approach
			call_deferred("start_dialogue")
		else:
			if prompt_label:
				prompt_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = false
		if prompt_label:
			prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if player_in_range and not DialogueManager.is_active:
		if event.is_action_pressed("ui_accept") or (
			event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E
		):
			start_dialogue()
			get_viewport().set_input_as_handled()

func start_dialogue() -> void:
	if prompt_label:
		prompt_label.visible = false

	var lines: Array = []
	if not has_talked_once or lines.is_empty():
		lines = [
			{
				"speaker": "Wanderer",
				"portrait": "player2",
				"text": "Greetings, traveler! Beware, the forest path ahead is overrun by aggressive green slimes."
			},
			{
				"speaker": "Hero",
				"portrait": "player1",
				"text": "I can handle them. Where does this road lead?"
			},
			{
				"speaker": "Wanderer",
				"portrait": "player2",
				"text": "Follow the cobblestone path east to the exit gate. Slay the slimes and collect heart elixirs to heal your wounds."
			},
			{
				"speaker": "Wanderer",
				"portrait": "player2",
				"text": "Press [SPACE] to swing your sword and [ESC] for the pause menu. May your blade stay sharp!"
			},
			{
				"speaker": "Hero",
				"portrait": "player1",
				"text": "Thank you, friend. I will clear the path!"
			}
		]
	else:
		lines = [
			{
				"speaker": "Wanderer",
				"portrait": "player2",
				"text": "The exit gate lies just down the path to the east. Fight bravely, hero!"
			}
		]

	DialogueManager.start_dialogue(lines)
