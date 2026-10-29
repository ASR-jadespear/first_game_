extends Node2D

@onready var hud = $HUD
var level: int = 1
var current_level_root: Node = null
var _is_transitioning: bool = false

var player1: Node2D = null
var player2: Node2D = null

var level1_intro_played: bool = false
var first_enemy_prompt_shown: bool = false
var is_cutscene_running: bool = false
var level1_first_slime_dialogue_shown: bool = false
var level1_all_defeated_dialogue_shown: bool = false
var level_two_hearts_dialogue_shown: bool = false
var level_one_heart_dialogue_shown: bool = false
var first_chest_opened_in_game: bool = false
var level2_chest2_dialogue_shown: bool = false
var level2_intro_dialogue_shown: bool = false
var level2_one_heart_unleash_prompt_shown: bool = false
var is_ending_cutscene_running: bool = false
var flower_pot_dialogue_shown: bool = false
var _exit_warning_active: bool = false
var _is_dying: bool = false
var _previous_health: int = 100
var _ending_bg_layer: CanvasLayer = null
var _cutscene_token: int = 0


func _ready() -> void:
	current_level_root = get_node_or_null("LevelRoot")
	if has_node("PauseMenu"):
		$PauseMenu.restart_level.connect(_on_restart_level)
		$PauseMenu.return_to_main_menu.connect(_on_return_to_main_menu)
	if has_node("VictoryScreen"):
		$VictoryScreen.restart_game.connect(_on_restart_game)
	if has_node("StartScreen"):
		$StartScreen.start_game.connect(_on_start_game)
		if has_node("PauseMenu"):
			$PauseMenu.can_pause = false
		if hud:
			hud.visible = false
		if current_level_root:
			current_level_root.visible = false
		$StartScreen.open()
	else:
		_load_level(level)


func _on_start_game() -> void:
	if has_node("NoticeScreen"):
		await $NoticeScreen.show_notice()
	if hud:
		hud.visible = true
	if has_node("PauseMenu"):
		$PauseMenu.can_pause = true
	_load_level(level)


func _on_restart_level() -> void:
	_cutscene_token += 1
	is_cutscene_running = false
	is_ending_cutscene_running = false
	if has_node("/root/DialogueManager"):
		DialogueManager.stop_dialogue()
	PlayerStats.reset()
	_previous_health = PlayerStats.health
	_is_dying = false
	level_two_hearts_dialogue_shown = false
	level_one_heart_dialogue_shown = false
	flower_pot_dialogue_shown = false
	_exit_warning_active = false
	if level == 1:
		level1_first_slime_dialogue_shown = false
		level1_all_defeated_dialogue_shown = false
	elif level == 2:
		level2_one_heart_unleash_prompt_shown = false
	if is_instance_valid(_ending_bg_layer):
		_ending_bg_layer.queue_free()
		_ending_bg_layer = null
	_load_level(level)


func _on_restart_game() -> void:
	_cutscene_token += 1
	is_cutscene_running = false
	is_ending_cutscene_running = false
	if has_node("/root/DialogueManager"):
		DialogueManager.stop_dialogue()
	PlayerStats.reset()
	_previous_health = PlayerStats.health
	_is_dying = false
	level1_intro_played = false
	first_enemy_prompt_shown = false
	level1_first_slime_dialogue_shown = false
	level1_all_defeated_dialogue_shown = false
	flower_pot_dialogue_shown = false
	_exit_warning_active = false
	level_two_hearts_dialogue_shown = false
	level_one_heart_dialogue_shown = false
	first_chest_opened_in_game = false
	level2_chest2_dialogue_shown = false
	level2_intro_dialogue_shown = false
	level2_one_heart_unleash_prompt_shown = false
	if is_instance_valid(_ending_bg_layer):
		_ending_bg_layer.queue_free()
		_ending_bg_layer = null
	level = 1
	if has_node("StartScreen"):
		if current_level_root:
			current_level_root.queue_free()
			current_level_root = null
		if hud:
			hud.visible = false
		if has_node("PauseMenu"):
			$PauseMenu.can_pause = false
		$StartScreen.open()
	else:
		_load_level(level)


func _on_return_to_main_menu() -> void:
	_on_restart_game()


func _process(_delta: float) -> void:
	# Combat tutorial dialogue when the first enemy is spotted close in Level 1
	if level == 1 and level1_intro_played and not first_enemy_prompt_shown and not is_cutscene_running:
		if is_instance_valid(player2):
			_check_first_enemy_proximity()


func _check_first_enemy_proximity() -> void:
	if not current_level_root:
		return
	var enemies_node = current_level_root.get_node_or_null("Enemies")
	if not enemies_node:
		return

	for enemy in enemies_node.get_children():
		if enemy.name.begins_with("Cutscene"):
			continue
		if enemy.get("is_alive") == true:
			if player2.global_position.distance_to(enemy.global_position) < 520.0:
				first_enemy_prompt_shown = true
				_show_combat_tutorial_dialogue()
				break


func _show_combat_tutorial_dialogue() -> void:
	DialogueManager.start_dialogue([
		{
			"speaker": "####",
			"portrait": "30",
			"text": "Press SPACE to attack enemies, we can proceed to the next dimension once we cleared all enemies here"
		}
	])


#-------------------------------------------------------------
# LEVEL MANAGEMENT
#-------------------------------------------------------------

func _load_level(level_number: int) -> void:
	_is_transitioning = false
	if is_instance_valid(_ending_bg_layer):
		_ending_bg_layer.queue_free()
		_ending_bg_layer = null
	_previous_health = PlayerStats.health
	level_two_hearts_dialogue_shown = false
	level_one_heart_dialogue_shown = false
	flower_pot_dialogue_shown = false
	_exit_warning_active = false
	if level_number == 1:
		level1_first_slime_dialogue_shown = false
		level1_all_defeated_dialogue_shown = false
	elif level_number == 2:
		level2_one_heart_unleash_prompt_shown = false
	var level_path = "res://scns/levels/level_%s.tscn" % level_number
	if not ResourceLoader.exists(level_path):
		level = 1
		level_path = "res://scns/levels/level_1.tscn"

	if current_level_root:
		current_level_root.queue_free()

	current_level_root = load(level_path).instantiate()
	add_child(current_level_root)
	current_level_root.name = "levelRoot"

	_setup_level(current_level_root)


func _setup_level(level_root: Node) -> void:
	player1 = level_root.get_node_or_null("Player")
	player2 = level_root.get_node_or_null("Player2")

	if player1:
		hud.register_player(player1)
		if not player1.health_changed.is_connected(_on_player_health_changed):
			player1.health_changed.connect(_on_player_health_changed)
		if not player1.power_unleashed.is_connected(_on_p1_power_unleashed):
			player1.power_unleashed.connect(_on_p1_power_unleashed)
	if player2:
		hud.register_player(player2)
		if not player2.health_changed.is_connected(_on_player_health_changed):
			player2.health_changed.connect(_on_player_health_changed)

	if player1 and player2:
		player1.add_collision_exception_with(player2)
		player2.add_collision_exception_with(player1)

	# Connect and configure chests
	var chests = current_level_root.find_children("*Chest*", "StaticBody2D", true, false)
	for chest in chests:
		if level == 2 and chest.name == "Chest2":
			chest.set("drop_count", 0)
			chest.set("can_drop_items", false)
		if not chest.opened.is_connected(_on_chest_opened):
			chest.opened.connect(_on_chest_opened.bind(chest))

	if level == 1:
		if not level1_intro_played:
			# Play the full story cutscene
			_start_level1_cutscene()
		else:
			# Restart after death or retry: skip cutscene, P2 already in control
			_setup_level1_gameplay_immediate()
	else:
		# Level 2 (vice versa):
		# Player 1 is the main player
		# Player 2 follows behind
		if player1:
			player1.set_as_leader()
			hud.set_player(player1)
			if not player1.died.is_connected(_on_player_died):
				player1.died.connect(_on_player_died)
		if player2:
			player2.set_as_follower(player1)
			if not player2.died.is_connected(_on_player_died):
				player2.died.connect(_on_player_died)

		hud.show_message("Level 2: Controls given to Player 1!", 3.0)
		if not level2_intro_dialogue_shown:
			_start_level2_intro()

	# Connect Exit trigger
	var exit = current_level_root.get_node_or_null("Exit")
	if exit:
		exit.body_entered.connect(_on_exit_body_entered)

	# Connect real Exit Portal
	var portal = current_level_root.get_node_or_null("portal")
	if portal and portal.has_signal("body_entered") and not portal.get("is_fake"):
		portal.body_entered.connect(_on_exit_body_entered)

	# Connect FlowerPot trigger
	_connect_flower_pot()

	# Connect all enemies to monitor when they are defeated
	_connect_enemies()

	# Check if enemies must be defeated before exit/portal are accessible
	if not _are_all_enemies_defeated():
		if portal:
			portal.visible = false
			portal.set_deferred("monitoring", false)
			portal.set_deferred("monitorable", false)
		if exit:
			exit.set_deferred("monitoring", true)
			exit.set_deferred("monitorable", true)
	else:
		if portal:
			portal.visible = true
			portal.set_deferred("monitoring", true)
			portal.set_deferred("monitorable", true)
		if exit:
			exit.set_deferred("monitoring", true)
			exit.set_deferred("monitorable", true)


func _setup_level1_gameplay_immediate() -> void:
	if player1:
		player1.in_cutscene = false
		player1.last_direction = Vector2.RIGHT
		if player1.has_method("update_hitbox_offset"):
			player1.update_hitbox_offset()
		if not player1.died.is_connected(_on_player_died):
			player1.died.connect(_on_player_died)

	if player2:
		player2.visible = true
		player2.in_cutscene = false
		player2.last_direction = Vector2.RIGHT
		player2.set_as_leader()
		if player2.has_method("update_hitbox_offset"):
			player2.update_hitbox_offset()
		hud.set_player(player2)
		if not player2.died.is_connected(_on_player_died):
			player2.died.connect(_on_player_died)
		if player2.camera_2d:
			player2.camera_2d.enabled = true
			player2.camera_2d.make_current()

	if player1 and player2:
		player1.add_collision_exception_with(player2)
		player2.add_collision_exception_with(player1)
		player1.set_as_follower(player2)


func _start_level1_cutscene() -> void:
	var token = _cutscene_token
	is_cutscene_running = true

	# P1 lands in level 1, P2 is not visible
	if player1:
		player1.in_cutscene = true
		player1.can_move = false
		player1.control_mode = Player.ControlMode.WAITING
		if player1.camera_2d:
			player1.camera_2d.enabled = true
			player1.camera_2d.make_current()
		hud.set_player(player1)
		if not player1.died.is_connected(_on_player_died):
			player1.died.connect(_on_player_died)

	if player2:
		player2.visible = false
		player2.in_cutscene = true
		player2.can_move = false
		player2.control_mode = Player.ControlMode.WAITING
		if not player2.died.is_connected(_on_player_died):
			player2.died.connect(_on_player_died)

	await get_tree().create_timer(0.6).timeout
	if token != _cutscene_token or not is_instance_valid(player1):
		return

	# Segment 1 Part A: The Boy lands in the sunny flowery place
	DialogueManager.start_dialogue([
		{
			"speaker": "The Boy",
			"portrait": "00",
			"text": "Huh…? Where am I…? What's with this sunny flowery place? I am pretty sure I slept in my bed last night after watching that show"
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		return

	# Slime appears right before the player says the approach line
	var intro_slime = _spawn_cutscene_intro_slime()
	await get_tree().create_timer(0.35).timeout
	if token != _cutscene_token:
		if is_instance_valid(intro_slime):
			intro_slime.queue_free()
		return

	# Segment 1 Part B: Slime is approaching line
	DialogueManager.start_dialogue([
		{
			"speaker": "The Boy",
			"portrait": "01",
			"text": "Wait what…? Is that a slime? Oh no….Its charging right at me… !!"
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		if is_instance_valid(intro_slime):
			intro_slime.queue_free()
		return

	# Cutscene Action 1: Slime charges, P2 becomes visible, jumps in and smashes it!
	await _run_cutscene_slime_charge_and_smash(intro_slime, token)
	if token != _cutscene_token:
		return

	# Segment 2: P2 meets The Boy
	DialogueManager.start_dialogue([
		{
			"speaker": "####",
			"portrait": "00",
			"text": "Hey, buddy, whatsup."
		},
		{
			"speaker": "The Boy",
			"portrait": "02",
			"text": "What the!!!! Who are you … Wait!! You are #### from “The Courages”. I was watching your final episode last night."
		},
		{
			"speaker": "####",
			"portrait": "00",
			"text": "Did you like it?"
		},
		{
			"speaker": "The Boy",
			"portrait": "04",
			"text": "It was Amazing!!!!"
		},
		{
			"speaker": "####",
			"portrait": "10",
			"text": "Gracius. Well…I must say.. quite a bizarre imagination you’ve got there.And here I thought you were a horror-and-gore kinda boy."
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		return

	# Cutscene Action 2: Camera zooms out and shows the map within 2 sec, then returns to normal
	await _run_cutscene_camera_map_view(token)
	if token != _cutscene_token:
		return

	# Segment 3: P2 reveals lucid dream, calls to adventure
	DialogueManager.start_dialogue([
		{
			"speaker": "The Boy",
			"portrait": "05",
			"text": "I have no idea what you’re saying buddy."
		},
		{
			"speaker": "####",
			"portrait": "20",
			"text": "You tell me… you created this place, this \"sunny flowery field\"-- this is ur imagination.."
		},
		{
			"speaker": "The Boy",
			"portrait": "06",
			"text": "What do we mean by MY imagination? and if it really is mine then how come you are here, ####"
		},
		{
			"speaker": "####",
			"portrait": "11",
			"text": "what do u think? YOU brought me here."
		},
		{
			"speaker": "The Boy",
			"portrait": "03",
			"text": "Me?? Ho ... .w did i…? Look, I know nothing, I swear.."
		},
		{
			"speaker": "####",
			"portrait": "01",
			"text": "Enough talking… if you want answers then you gotta play along with me, Purge this land from evil and only then can you be free from this lucid dream"
		},
		{
			"speaker": "The Boy",
			"portrait": "03",
			"text": "Fight..I cant fight"
		},
		{
			"speaker": "####",
			"portrait": "30",
			"text": "Dont you remember.. I am the hero from “The Courages” , and you my biggest fan, ….the hell you can do this. Just follow my lead and you’ll be back home in no time."
		},
		{
			"speaker": "The Boy",
			"portrait": "10",
			"text": "(nervous chuckles)"
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		return

	# Cutscene complete!
	level1_intro_played = true
	is_cutscene_running = false

	# Controls switch to P2, and P1 follows him
	if player1:
		player1.in_cutscene = false
		player1.last_direction = Vector2.RIGHT
		if player1.has_method("update_hitbox_offset"):
			player1.update_hitbox_offset()
	if player2:
		player2.in_cutscene = false
		player2.visible = true
		player2.last_direction = Vector2.RIGHT
		player2.set_as_leader()
		if player2.has_method("update_hitbox_offset"):
			player2.update_hitbox_offset()
		if player2.camera_2d:
			player2.camera_2d.enabled = true
			player2.camera_2d.make_current()
		hud.set_player(player2)

	if player1 and player2:
		player1.add_collision_exception_with(player2)
		player2.add_collision_exception_with(player1)
		player1.set_as_follower(player2)


func _spawn_cutscene_intro_slime() -> Node2D:
	var slime_scene = preload("res://scns/slime.tscn")
	var intro_slime = slime_scene.instantiate()
	intro_slime.name = "CutsceneIntroSlime"
	intro_slime.can_drop_item = false
	intro_slime.drop_chance = 0.0
	intro_slime.health_pickup_scene = null
	current_level_root.add_child(intro_slime)
	intro_slime.global_position = Vector2(player1.global_position.x + 360.0, player1.global_position.y)
	intro_slime.set_physics_process(false)

	# Ensure NO health bar appears on this cutscene slime
	if intro_slime.has_node("HealthBar"):
		intro_slime.get_node("HealthBar").queue_free()
	intro_slime.health_bar = null

	var intro_hb = intro_slime.get_node_or_null("HitBox")
	if intro_hb:
		intro_hb.set_deferred("monitoring", false)
		intro_hb.set_deferred("monitorable", false)

	if intro_slime.has_node("AnimatedSprite2D"):
		var s_sprite: AnimatedSprite2D = intro_slime.get_node("AnimatedSprite2D")
		s_sprite.play("idle")
		s_sprite.flip_h = true

	# Smooth pop-in appearance
	intro_slime.scale = Vector2.ZERO
	var pop = create_tween()
	pop.tween_property(intro_slime, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return intro_slime


func _run_cutscene_slime_charge_and_smash(intro_slime: Node2D, token: int = -1) -> void:
	if not is_instance_valid(player1) or not is_instance_valid(player2) or not is_instance_valid(intro_slime):
		return

	# Slime plays attack animation and charges toward P1
	if intro_slime.has_node("AnimatedSprite2D"):
		var s_sprite: AnimatedSprite2D = intro_slime.get_node("AnimatedSprite2D")
		s_sprite.play("attack")
		s_sprite.flip_h = true

	var charge_tween = create_tween()
	charge_tween.tween_property(intro_slime, "global_position:x", player1.global_position.x + 190.0, 0.7)
	await charge_tween.finished
	if token != -1 and token != _cutscene_token:
		if is_instance_valid(intro_slime):
			intro_slime.queue_free()
		return

	# P2 becomes visible and jumps in from above
	player2.visible = true
	player2.global_position = Vector2(player1.global_position.x + 120.0, player1.global_position.y - 240.0)
	var jump_tween = create_tween()
	jump_tween.tween_property(player2, "global_position", Vector2(player1.global_position.x + 120.0, player1.global_position.y), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await jump_tween.finished
	if token != -1 and token != _cutscene_token:
		if is_instance_valid(intro_slime):
			intro_slime.queue_free()
		return

	# P2 attacks right, swinging sword to smash the slime
	player2.play_animation("attack", Vector2.RIGHT)
	if player2.swing_sword_sound:
		player2.swing_sword_sound.pitch_scale = randf_range(0.95, 1.05)
		player2.swing_sword_sound.play()

	await get_tree().create_timer(0.12).timeout
	if token != -1 and token != _cutscene_token:
		if is_instance_valid(intro_slime):
			intro_slime.queue_free()
		return

	# Slime gets hit, flashes, plays damage sound, dies and fades out cleanly
	if is_instance_valid(intro_slime):
		if intro_slime.take_damage_sound:
			intro_slime.take_damage_sound.play()
		if intro_slime.has_node("AnimatedSprite2D"):
			var flash = create_tween()
			flash.tween_property(intro_slime.animated_sprite_2d, "modulate", Color(2.5, 2.5, 2.5, 1), 0.08)
			flash.tween_property(intro_slime.animated_sprite_2d, "modulate", Color.WHITE, 0.08)
		intro_slime.global_position.x += 45.0
		intro_slime._die()
		
		# Clean removal after hit
		var fade = create_tween()
		fade.tween_property(intro_slime, "modulate:a", 0.0, 0.35)
		fade.tween_callback(intro_slime.queue_free)

	await get_tree().create_timer(0.45).timeout
	if token != -1 and token != _cutscene_token:
		return

	# P2 turns to face P1, P1 faces P2
	if is_instance_valid(player2):
		player2.play_animation("idle", Vector2.LEFT)
	if is_instance_valid(player1):
		player1.play_animation("idle", Vector2.RIGHT)


func _run_cutscene_camera_map_view(token: int = -1) -> void:
	var cam: Camera2D = null
	if is_instance_valid(player1) and player1.camera_2d:
		cam = player1.camera_2d
	elif is_instance_valid(player2) and player2.camera_2d:
		cam = player2.camera_2d

	if not cam:
		await get_tree().create_timer(1.0).timeout
		return

	cam.enabled = true
	cam.make_current()

	# Zoom out smoothly over 0.65s to show the map
	var zoom_out = create_tween().set_parallel(true)
	zoom_out.tween_property(cam, "zoom", Vector2(0.2, 0.2), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await zoom_out.finished
	if token != -1 and token != _cutscene_token:
		if is_instance_valid(cam):
			cam.zoom = Vector2(0.5, 0.5)
		return

	# Show the map for ~1.1s (around 2 sec total)
	await get_tree().create_timer(1.1).timeout
	if token != -1 and token != _cutscene_token:
		if is_instance_valid(cam):
			cam.zoom = Vector2(0.5, 0.5)
		return

	# Zoom back in smoothly over 0.65s to normal
	var zoom_in = create_tween().set_parallel(true)
	zoom_in.tween_property(cam, "zoom", Vector2(0.5, 0.5), 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await zoom_in.finished
	if token != -1 and token != _cutscene_token:
		if is_instance_valid(cam):
			cam.zoom = Vector2(0.5, 0.5)
		return


func _connect_enemies() -> void:
	if not current_level_root:
		return
	var enemies_node = current_level_root.get_node_or_null("Enemies")
	if enemies_node:
		for child in enemies_node.get_children():
			if child.name.begins_with("Cutscene"):
				continue
			if child.has_signal("defeated") and not child.defeated.is_connected(_on_enemy_defeated):
				child.defeated.connect(_on_enemy_defeated)
			if not child.tree_exited.is_connected(_on_enemy_defeated):
				child.tree_exited.connect(_on_enemy_defeated)
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.name.begins_with("Cutscene"):
			continue
		if current_level_root.is_ancestor_of(node):
			if node.has_signal("defeated") and not node.defeated.is_connected(_on_enemy_defeated):
				node.defeated.connect(_on_enemy_defeated)
			if not node.tree_exited.is_connected(_on_enemy_defeated):
				node.tree_exited.connect(_on_enemy_defeated)


func _are_all_enemies_defeated() -> bool:
	return _get_alive_enemies_count() == 0


func _get_alive_enemies_count() -> int:
	if not current_level_root:
		return 0
	var count = 0
	var counted = {}
	var enemies_node = current_level_root.get_node_or_null("Enemies")
	if enemies_node:
		for child in enemies_node.get_children():
			if child.name.begins_with("Cutscene"):
				continue
			if child.get("is_alive") == true:
				counted[child] = true
				count += 1
	for node in get_tree().get_nodes_in_group("enemies"):
		if node.name.begins_with("Cutscene"):
			continue
		if current_level_root.is_ancestor_of(node) and node.get("is_alive") == true and not counted.has(node):
			counted[node] = true
			count += 1
	return count


func _on_enemy_defeated() -> void:
	call_deferred("_update_enemies_cleared_status")


func _update_enemies_cleared_status() -> void:
	if not current_level_root:
		return
	var remaining = _get_alive_enemies_count()

	if level == 1:
		if not level1_first_slime_dialogue_shown and remaining <= 3 and remaining > 0:
			level1_first_slime_dialogue_shown = true
			DialogueManager.start_dialogue([
				{
					"speaker": "####",
					"portrait": "01",
					"text": "One down 3 more to go"
				}
			])
		elif not level1_all_defeated_dialogue_shown and remaining == 0:
			level1_all_defeated_dialogue_shown = true
			_trigger_level1_victory_dialogue()
			return

	if remaining == 0:
		_unlock_exit_and_show_portal()
	else:
		hud.show_message("Enemies remaining: %d" % remaining, 1.5)


func _trigger_level1_victory_dialogue() -> void:
	var token = _cutscene_token
	DialogueManager.start_dialogue([
		{
			"speaker": "The Boy",
			"portrait": "07",
			"text": "Yay.... we did it. All enemies down, that means the portal should be open, right?"
		},
		{
			"speaker": "####",
			"portrait": "30",
			"text": "Hell yeah. Now brace yourself for the next Round"
		},
		{
			"speaker":"The Boy",
			"potrait":"02",
			"text":"Wa..it!!! There's moreeeee....."
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		return
	_unlock_exit_and_show_portal()


func _unlock_exit_and_show_portal() -> void:
	if not current_level_root:
		return

	var portal = current_level_root.get_node_or_null("portal")
	if portal and not portal.visible:
		portal.visible = true
		portal.set_deferred("monitoring", true)
		portal.set_deferred("monitorable", true)
		portal.modulate.a = 0.0
		var tween = create_tween().set_parallel(true)
		tween.tween_property(portal, "modulate:a", 1.0, 0.4)
		tween.tween_property(portal, "scale", Vector2.ONE, 0.4).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var exit = current_level_root.get_node_or_null("Exit")
	if exit:
		exit.set_deferred("monitoring", true)
		exit.set_deferred("monitorable", true)

	hud.show_message("All enemies defeated! Portal opened!", 3.0)


func _show_victory_screen() -> void:
	_cutscene_token += 1
	is_cutscene_running = false
	is_ending_cutscene_running = false
	if has_node("/root/DialogueManager"):
		DialogueManager.stop_dialogue()
	if has_node("VictoryScreen"):
		$VictoryScreen.open()
	else:
		level = 1
		call_deferred("_load_level", level)


#-------------------------------------------------------------
# SIGNAL HANDLERS
#-------------------------------------------------------------

func _on_chest_opened(chest: Node2D) -> void:
	if level == 2 and chest.name == "Chest2":
		if not level2_chest2_dialogue_shown:
			level2_chest2_dialogue_shown = true
			DialogueManager.start_dialogue([
				{
					"speaker": "The Boy",
					"portrait": "03",
					"text": "Jackpot! Wait... it’s just a handwritten note."
				},
				{
					"speaker": "####",
					"portrait": "11",
					"text": "What’s it say?"
				},
				{
					"speaker": "The Boy",
					"portrait": "03",
					"text": "'Congrats on finding this. Now please stop trying to break the collision and test the actual quest.'"
				}
			])
		return

	if not first_chest_opened_in_game:
		first_chest_opened_in_game = true
		DialogueManager.start_dialogue([
			{
				"speaker": "The Boy",
				"portrait": "04",
				"text": "Ooh, jackpot! Who leaves a whole treasure chest out here?"
			},
			{
				"speaker": "####",
				"portrait": "10",
				"text": "Your Imagination, clearly. Rewarding you for wandering into dead ends like you knew what you were doing."
			},
			{
				"speaker":"The Boy",
				"potrait":"06",
				"text": "Ughhhh"
			}
		])


func _start_level2_intro() -> void:
	var token = _cutscene_token
	level2_intro_dialogue_shown = true
	if player1:
		player1.can_move = false
	if player2:
		player2.can_move = false

	await get_tree().create_timer(0.4).timeout
	if token != _cutscene_token:
		return
	DialogueManager.start_dialogue([
		{
			"speaker": "####",
			"portrait": "30",
			"text": "now its your turn to shine, FOLLOW MY MOVES and show those slimes what you've got"
		},
		{
			"speaker": "The Boy",
			"portrait": "08",
			"text": "are you saying that I cant defeat the ninjas?"
		},
		{
			"speaker": "####",
			"portrait": "01",
			"text": "No... you can't, you were sweating your shits out a while ago... "
		},
		
		{
			"speaker": "The Boy",
			"portrait": "01",
			"text": "Ugghhhh "
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		return
	if player1 and not player1.in_cutscene:
		player1.can_move = true
	if player2 and not player2.in_cutscene:
		player2.can_move = true


func _on_exit_body_entered(body: Node2D) -> void:
	if (body.name.begins_with("Player") or body.is_in_group("player")) and not _is_transitioning:
		if not _are_all_enemies_defeated():
			if not (has_node("/root/DialogueManager") and DialogueManager.is_active) and not _exit_warning_active:
				var token = _cutscene_token
				_exit_warning_active = true
				hud.show_message("Defeat All enemies to move on to the next Level", 3.0)
				DialogueManager.start_dialogue([
					{
						"speaker": "####",
						"portrait": "01",
						"text": "Lets Go!! We need to go back and kill 'em all"
					}
				])
				await DialogueManager.dialogue_ended
				if token != _cutscene_token:
					_exit_warning_active = false
					return
				await get_tree().create_timer(1.5).timeout
				if token != _cutscene_token:
					_exit_warning_active = false
					return
				_exit_warning_active = false
			return

		_is_transitioning = true
		if level >= 2:
			_run_ending_cutscene()
		else:
			level += 1
			call_deferred("_load_level", level)


func _show_final_bg_screen() -> CanvasLayer:
	if is_instance_valid(_ending_bg_layer):
		_ending_bg_layer.queue_free()

	var canvas = CanvasLayer.new()
	canvas.name = "FinalBGLayer"
	canvas.layer = 85

	var root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 0
	root.offset_top = 0
	root.offset_right = 0
	root.offset_bottom = 0
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var black_bg = ColorRect.new()
	black_bg.name = "BlackBG"
	black_bg.color = Color.BLACK
	black_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_bg.anchor_right = 1.0
	black_bg.anchor_bottom = 1.0
	black_bg.offset_left = 0
	black_bg.offset_top = 0
	black_bg.offset_right = 0
	black_bg.offset_bottom = 0
	black_bg.grow_horizontal = Control.GROW_DIRECTION_BOTH
	black_bg.grow_vertical = Control.GROW_DIRECTION_BOTH
	black_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black_bg)

	var bg_tex = TextureRect.new()
	bg_tex.name = "FinalBGTexture"
	bg_tex.texture = preload("res://assets/images/portrait/final_bg.png")
	bg_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex.anchor_right = 1.0
	bg_tex.anchor_bottom = 1.0
	bg_tex.offset_left = 0
	bg_tex.offset_top = 0
	bg_tex.offset_right = 0
	bg_tex.offset_bottom = 0
	bg_tex.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bg_tex.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg_tex)

	root.modulate.a = 0.0
	add_child(canvas)
	_ending_bg_layer = canvas
	return canvas


func _run_ending_cutscene() -> void:
	var token = _cutscene_token
	is_ending_cutscene_running = true

	# Lock player inputs
	if player1:
		player1.can_move = false
		player1.in_cutscene = true
		player1.velocity = Vector2.ZERO
	if player2:
		player2.can_move = false
		player2.in_cutscene = true
		player2.velocity = Vector2.ZERO

	# Position near the last portal
	var portal = current_level_root.get_node_or_null("portal") if current_level_root else null
	var target_portal_pos = portal.global_position if portal else (player1.global_position if player1 else Vector2.ZERO)

	# Face each other near the portal
	if player1 and player2:
		var p1_pos = target_portal_pos + Vector2(-60, 20)
		var p2_pos = target_portal_pos + Vector2(-140, 20)
		var prep_tween = create_tween().set_parallel(true)
		prep_tween.tween_property(player1, "global_position", p1_pos, 0.4)
		prep_tween.tween_property(player2, "global_position", p2_pos, 0.4)
		await prep_tween.finished
		if token != _cutscene_token:
			return
		player1.play_animation("idle", Vector2.LEFT)
		player2.play_animation("idle", Vector2.RIGHT)

	await get_tree().create_timer(0.3).timeout
	if token != _cutscene_token:
		return

	# Show final background screen behind dialogue
	var ending_bg = _show_final_bg_screen()
	var fade_in = create_tween()
	fade_in.tween_property(ending_bg.get_node("Root"), "modulate:a", 1.0, 0.4)
	await fade_in.finished
	if token != _cutscene_token:
		if is_instance_valid(ending_bg):
			ending_bg.queue_free()
		_ending_bg_layer = null
		return

	await get_tree().create_timer(0.2).timeout
	if token != _cutscene_token:
		if is_instance_valid(ending_bg):
			ending_bg.queue_free()
		_ending_bg_layer = null
		return

	# The Game Ending Dialogues
	DialogueManager.start_dialogue([
	{
		"speaker": "The Boy",
		"portrait": "07",
		"text": "The final portal... We can finally go home. Sorry for dragging you into this."
	},
	{
		"speaker": "####",
		"portrait": "41",
		"text": "Don't sweat it."
	},
	{
		"speaker": "The Boy",
		"portrait": "07",
		"text": "Ready?"
	},
	{
		"speaker": "####",
		"portrait": "21",
		"text": "I can't come with you."
	},
	{
		"speaker": "The Boy",
		"portrait": "02",
		"text": "What?! Why not?"
	},
	{
		"speaker": "####",
		"portrait": "40",
		"text": "Haven't you realized? I'm not real. Just like this place, I only exist in your head."
	},
	{
		"speaker": "The Boy",
		"portrait": "00",
		"text": "B-but... I see you every night before I sleep. You fight off the monsters!"
	},
	{
		"speaker": "####",
		"portrait": "21",
		"text": "You imagined me whenever you were scared. Every battle we fought? That was all you. You're your own hero."
	},
	{
		"speaker": "The Boy",
		"portrait": "03",
		"text": "I... I don't know what to say. Having you around made me feel safe."
	},
	{
		"speaker": "####",
		"portrait": "21",
		"text": "Portal's closing, kid. Time to wake up. Go."
	}
])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		if is_instance_valid(ending_bg):
			ending_bg.queue_free()
		_ending_bg_layer = null
		return

	# Hide final background screen so the characters are shown at the portal
	if is_instance_valid(ending_bg):
		var fade_out = create_tween()
		fade_out.tween_property(ending_bg.get_node("Root"), "modulate:a", 0.0, 0.4)
		await fade_out.finished
		if is_instance_valid(ending_bg):
			ending_bg.queue_free()
		_ending_bg_layer = null

	if token != _cutscene_token:
		return

	await get_tree().create_timer(0.3).timeout
	if token != _cutscene_token:
		return

	# P1 walks into the portal and P2 disappears
	if player1 and portal:
		player1.play_animation("run", Vector2.RIGHT)
		var walk_tween = create_tween().set_parallel(true)
		walk_tween.tween_property(player1, "global_position", portal.global_position, 1.0)
		walk_tween.tween_property(player1, "scale", Vector2.ZERO, 0.6).set_delay(0.5)

	if player2:
		var disappear_tween = create_tween()
		disappear_tween.tween_property(player2, "modulate:a", 0.0, 0.8)

	await get_tree().create_timer(1.2).timeout
	if token != _cutscene_token:
		return

	# Black screen shows epilogue
	await hud.fade(1.0)
	if token != _cutscene_token:
		return
	await hud.show_epilogue_message("You wake up in the real world, no more ninjas and slimes,  But you are not the same anymore", 4.0)
	if token != _cutscene_token:
		return

	_show_victory_screen()


func _on_player_died() -> void:
	if _is_dying:
		return
	_is_dying = true
	_cutscene_token += 1
	is_cutscene_running = false
	is_ending_cutscene_running = false
	if has_node("/root/DialogueManager"):
		DialogueManager.stop_dialogue()
	var death_messages = [
		"Skill issues detected",
		"You can do better you know",
		"Dont go looking into random corners.... there is nothing interesting there.... probably"
	]
	var chosen_msg = death_messages.pick_random()
	var token = _cutscene_token
	await get_tree().create_timer(0.6).timeout
	if token != _cutscene_token:
		_is_dying = false
		return
	await hud.fade(1.0)
	if token != _cutscene_token:
		_is_dying = false
		return
	await hud.show_death_message(chosen_msg, 2.2)
	if token != _cutscene_token:
		_is_dying = false
		return
	PlayerStats.reset()
	_previous_health = PlayerStats.health
	level_two_hearts_dialogue_shown = false
	level_one_heart_dialogue_shown = false
	flower_pot_dialogue_shown = false
	_exit_warning_active = false
	if level == 2:
		level2_one_heart_unleash_prompt_shown = false
	_load_level(level)
	_is_dying = false
	await hud.fade(0.0)


func _on_player_health_changed(new_health: int) -> void:
	var old_health = _previous_health
	_previous_health = new_health

	# ONLY process low-health warnings and emergency mechanics when health is GOING DOWN (taking damage)
	if new_health >= old_health:
		return

	if is_cutscene_running or is_ending_cutscene_running or new_health <= 0 or (has_node("/root/DialogueManager") and DialogueManager.is_active):
		return

	# Level 2 special mechanic: P1 health goes down to one heart or below
	if level == 2 and new_health <= 20 and not level2_one_heart_unleash_prompt_shown:
		level2_one_heart_unleash_prompt_shown = true
		level_one_heart_dialogue_shown = true
		level_two_hearts_dialogue_shown = true
		_start_level2_unleash_prompt_dialogue()
		return

	var follower_speaker = "The Boy"
	if is_instance_valid(player2) and player2.get("control_mode") == Player.ControlMode.FOLLOWER:
		follower_speaker = "####"
	elif is_instance_valid(player1) and player1.get("control_mode") == Player.ControlMode.FOLLOWER:
		follower_speaker = "The Boy"
	elif level == 2:
		follower_speaker = "####"

	# 1 heart left (20 health or below)
	if new_health <= 20 and not level_one_heart_dialogue_shown:
		level_one_heart_dialogue_shown = true
		level_two_hearts_dialogue_shown = true
		DialogueManager.start_dialogue([
			{
				"speaker": follower_speaker,
				"portrait": "01",
				"text": "Watch out, you are on your last life"
			}
		])
	# 2 hearts left (40 health or below)
	elif new_health <= 40 and not level_two_hearts_dialogue_shown:
		level_two_hearts_dialogue_shown = true
		DialogueManager.start_dialogue([
			{
				"speaker": follower_speaker,
				"portrait": "03" if follower_speaker == "The Boy" else "20",
				"text": "You dont look so good"
			}
		])


func _start_level2_unleash_prompt_dialogue() -> void:
	var token = _cutscene_token
	DialogueManager.start_dialogue([
		{
			"speaker": "The Boy",
			"portrait": "01",
			"text": "Ummm, i cant hold back this horrendous monster..i need help"
		},
		{
			"speaker": "####",
			"portrait": "01",
			"text": "Press E to unleash ur full power,"
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		return
	if is_instance_valid(player1):
		player1.can_unleash_power = true
	hud.show_message("Press E to unleash full power!", 4.0)


func _on_p1_power_unleashed() -> void:
	var token = _cutscene_token
	DialogueManager.start_dialogue([
		{
			"speaker": "####",
			"portrait": "01",
			"text": "Now you are invincible for 5 sec, quickly…. kill this goddamn enemy"
		}
	])
	await DialogueManager.dialogue_ended
	if token != _cutscene_token:
		return
	if is_instance_valid(player1):
		player1.activate_full_power(5.0)
	hud.show_message("IMMORTAL & 2x DAMAGE! (5s)", 5.0)


func _connect_flower_pot() -> void:
	var flower_pot = _find_flower_pot()
	if flower_pot and flower_pot.has_signal("body_entered"):
		flower_pot.monitoring = true
		flower_pot.collision_mask = flower_pot.collision_mask | 1
		if not flower_pot.body_entered.is_connected(_on_flower_pot_body_entered):
			flower_pot.body_entered.connect(_on_flower_pot_body_entered)


func _find_flower_pot() -> Area2D:
	if not current_level_root:
		return null
	var pot = current_level_root.get_node_or_null("FlowerPot")
	if pot and pot is Area2D:
		return pot
	pot = current_level_root.get_node_or_null("flowerPot")
	if pot and pot is Area2D:
		return pot
	for child in current_level_root.get_children():
		if child is Area2D and child.name.to_lower() in ["flowerpot", "flower_pot"]:
			return child
	var found = current_level_root.find_child("FlowerPot", true, false)
	if not found:
		found = current_level_root.find_child("flowerPot", true, false)
	if not found:
		found = current_level_root.find_child("*lower*ot*", true, false)
	if found and found is Area2D:
		return found
	return null


func _on_flower_pot_body_entered(body: Node2D) -> void:
	if flower_pot_dialogue_shown or is_cutscene_running or is_ending_cutscene_running:
		return
	if not (body.name.begins_with("Player") or body.is_in_group("player")):
		return
	flower_pot_dialogue_shown = true
	DialogueManager.start_dialogue([
		{
			"speaker": "####",
			"portrait": "11",
			"text": "Shush!!! The Big Dude is near. Follow Me!!!"
		}
	])
