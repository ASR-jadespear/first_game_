extends Node2D
#@onready var hud: CanvasLayer = $HUD
@onready var hud = $HUD
var level: int = 1
var current_level_root : Node  = null


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	current_level_root = get_node_or_null("LevelRoot")
	if has_node("PauseMenu"):
		$PauseMenu.restart_level.connect(_on_restart_level)
	_load_level(level)

func _on_restart_level() -> void:
	PlayerStats.reset()
	_load_level(level)


#-------------------------------------------------------------
# LEVEL MANAGEMENT
#-------------------------------------------------------------
 
func _load_level(level_number: int) -> void:
	var level_path = "res://scns/levels/level_%s.tscn" % level_number
	if not ResourceLoader.exists(level_path):
		# If no more levels exist, loop back or restart
		level = 1
		level_path = "res://scns/levels/level_1.tscn"

	if current_level_root:
		current_level_root.queue_free()
		
	# Change level
	current_level_root = load(level_path).instantiate()
	add_child(current_level_root)
	current_level_root.name = "levelRoot"
	
	# Connect the exit signal for the newly loaded level!
	_setup_level(current_level_root)
	

func _setup_level(level_root : Node) -> void:
# Connect Player
	var player = level_root.get_node("Player")
	$HUD.set_player(player)
	player.died.connect(_on_player_died)
	#Connect Exit
	var exit = current_level_root.get_node_or_null("Exit")
	if exit:
		exit.body_entered.connect(_on_exit_body_entered)

#-------------------------------------------------------------
#SIGNAL HANDLERS
#---------------------------------------------------------------
func _on_exit_body_entered(body : Node2D) -> void:
	if body.name == "Player":
		level += 1
		call_deferred("_load_level",(level))
		
func _on_player_died() -> void:
# Pause for 1 second before resetting everything
	await get_tree().create_timer(1.0).timeout
	await hud.fade(1.0)
	level = 1
	PlayerStats.reset()
	_load_level(level)
	await hud.fade(0.0)
