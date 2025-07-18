# res://scripts/globals/Global.gd
extends Node

# ... (other variables) ...

# If you need to store completed events by dialogue_id, declare it like this:
var completed_events: Dictionary = {}

# ... (rest of your Global.gd code) ...

# Your existing Global.gd code with `current_scene_path` changes:
var gameStarted: bool
var autosave_timer: Timer = Timer.new()
var autosave_interval_seconds: float = 60.0
var is_dialog_open := false
var attacking := false

func _ready():
	Dialogic.connect("dialog_started", Callable(self, "_on_dialog_started"))
	Dialogic.connect("dialog_ended", Callable(self, "_on_dialog_ended"))
	
	add_child(autosave_timer)
	autosave_timer.wait_time = autosave_interval_seconds
	autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	autosave_timer.start()
	print("Autosave timer started with interval: %s seconds" % autosave_interval_seconds)

func _on_dialog_started():
	is_dialog_open = true

func _on_dialog_ended():
	is_dialog_open = false
	
var play_intro_cutscene := false
var playerBody: CharacterBody2D
var selected_form_index: int
var playerAlive :bool
var playerDamageZone: Area2D
var playerDamageAmount: int
var playerHitbox: Area2D
var telekinesis_mode := false
var camouflage := false
var time_freeze := false
var enemyADamageZone: Area2D
var enemyADamageAmount: int
var enemyAdealing: bool
var enemyAknockback := Vector2.ZERO

var fullscreen_on = false
var vsync_on = false
var master_vol = -10.0
var bgm_vol = -10.0
var sfx_vol = -10.0

var current_scene_path: String = "" 

var current_loaded_player_data: Dictionary = {}
var current_game_state_data: Dictionary = {}

func set_current_game_scene_path(path: String):
	current_scene_path = path
	print("Global: Current game scene path set to: " + current_scene_path)

func get_save_data() -> Dictionary:
	var data = {
		"game_time_elapsed": Time.get_ticks_msec() / 1000.0,
		"example_global_variable": "some_value",
		"fullscreen_on": fullscreen_on,
		"vsync_on": vsync_on,
		"master_vol": master_vol,
		"bgm_vol": bgm_vol,
		"sfx_vol": sfx_vol,
		"completed_events": completed_events # If you added the `var completed_events: Dictionary` above
	}
	print("Global: Gathering save data.")
	return data

func apply_load_data(data: Dictionary):
	current_scene_path = data.get("current_scene_path", "") # Keep this line to load scene path from Global
	print("Global: Applied loaded current_scene_path: ", current_scene_path) # Debug print for clarity
	
	gameStarted = data.get("gameStarted", false)
	
	fullscreen_on = data.get("fullscreen_on", false)
	vsync_on = data.get("vsync_on", false)
	master_vol = data.get("master_vol", -10.0)
	bgm_vol = data.get("bgm_vol", -10.0)
	sfx_vol = data.get("sfx_vol", -10.0)

	# If you have completed_events, apply it here
	completed_events = data.get("completed_events", {})
	
	print("Global: Applied loaded global state data.")

func reset_to_defaults():
	print("Global: Resetting essential game state to defaults.")
	current_scene_path = ""
	current_loaded_player_data = {}
	current_game_state_data = {}
	
	gameStarted = false
	is_dialog_open = false
	attacking = false
	play_intro_cutscene = false
	selected_form_index = 0
	playerAlive = true
	telekinesis_mode = false
	camouflage = false
	time_freeze = false
	
	fullscreen_on = false
	vsync_on = false
	master_vol = -10.0
	bgm_vol = -10.0
	sfx_vol = -10.0
	completed_events = {} # Reset completed events
	
	if autosave_timer.is_running():
		autosave_timer.stop()
	autosave_timer.start()

func _on_autosave_timer_timeout():
	print("Autosave timer triggered!")
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		if Global.current_scene_path.is_empty():
			printerr("Autosave: Global.current_scene_path is empty! Cannot autosave reliably.")
			return
			
		SaveLoadManager.save_game(player_node, "")
		print("Game autosaved by timer.")
	else:
		print("No player node found for timer-based autosave!")
