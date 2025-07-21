# res://scripts/globals/Global.gd
extends Node

# ... (other variables) ...

# If you need to store completed events by dialogue_id, declare it like this:
var completed_events: Dictionary = {}

# Your existing Global.gd code with `current_scene_path` changes:
var gameStarted: bool
var autosave_timer: Timer = Timer.new()
var autosave_interval_seconds: float = 60.0

var is_dialog_open := false
var attacking := false

# ADD THIS LINE:
var is_cutscene_active := false # <--- NEW: Flag to indicate if a cutscene is active

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
var playerBody: CharacterBody2D # This is the variable the ProfileScene is looking for
var selected_form_index: int

# --- MODIFIED: current_form property with setter and signal (Godot 4.x syntax) ---
# Use a private backing variable for the actual value.
var current_form: String = "Normal" # Initialize with default value for the backing variable

# Declare the signal
signal current_form_changed(new_form_id: String)

# Public setter function that emits the signal
func set_player_form(value: String):
	if current_form != value:
		current_form = value
		current_form_changed.emit(current_form)
		print("Global: Player form changed to: " + current_form)

# Public getter function
func get_player_form() -> String:
	return current_form
# --- END MODIFIED ---

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

var kills: int = 0 # Initialize kills
var affinity: int = 0 # Initialize affinity
var player_status: String = "Normal" # NEW: Player status

var active_quests := []
var completed_quests := []
var dialog_timeline := ""
var dialog_current_index := 0
var dialogic_variables: Dictionary = {}

var fullscreen_on = false
var vsync_on = false
var brightness: float = 1.0
var pixel_smoothing: bool = false
var fps_limit: int = 60
var master_vol = -10.0
var bgm_vol = -10.0
var sfx_vol = -10.0
var voice_vol = -10.0


# Add to graphics variables

var resolution_index: int = 2 # Default to 1280x720 (index 2)
var base_resolution = Vector2(320, 180)
var available_resolutions = [
	base_resolution * 2, # 0: 640x360
	base_resolution * 3, # 1: 960x540
	base_resolution * 4, # 2: 1280x720
	base_resolution * 6  # 3: 1920x1080
]


var current_scene_path: String = "" 

var current_loaded_player_data: Dictionary = {}
var current_game_state_data: Dictionary = {}

var cutscene_name: String = ""
var cutscene_playback_position: float = 0.0

signal brightness_changed(new_brightness_value)

var player_position_before_dialog: Vector2 = Vector2.ZERO # Use Vector2 for position
var scene_path_before_dialog: String = ""


func _init():
	# Set initial default values for settings here
	fullscreen_on = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	brightness = 1.0
	pixel_smoothing = false
	fps_limit = 60
	master_vol = 0.0
	bgm_vol = -10.0
	sfx_vol = -10.0
	voice_vol = -10.0
	
	# Initialize profile data defaults
	kills = 0
	affinity = 0
	player_status = "Normal"
	current_form = "Normal" # Initialize the backing variable
	
func set_current_game_scene_path(path: String):
	current_scene_path = path
	print("Global: Current game scene path set to: " + current_scene_path)

func get_save_data() -> Dictionary:
	
	var data = {
		"gameStarted": gameStarted,
		"current_scene_path": current_scene_path,
		"play_intro_cutscene": play_intro_cutscene,
		
		"fullscreen_on": fullscreen_on,
		"vsync_on": vsync_on,
		"brightness": brightness,
		"fps_limit": fps_limit,
		"master_vol": master_vol,
		"bgm_vol": bgm_vol,
		"sfx_vol": sfx_vol,
		"voice_vol": voice_vol,
		"resolution_index": resolution_index,

		"selected_form_index": selected_form_index,
		"current_form": get_player_form(), # Use the getter for saving
		"playerAlive": playerAlive,

		"kills": kills, # Save kills
		"affinity": affinity, # Save affinity
		"player_status": player_status, # NEW: Save player status
		
		"completed_events": completed_events,
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		
		"player_position_before_dialog": {
			"x": player_position_before_dialog.x,
			"y": player_position_before_dialog.y
		},
		"scene_path_before_dialog": scene_path_before_dialog,
		"is_cutscene_active": is_cutscene_active, # NEW: Save cutscene active state
		"cutscene_name": cutscene_name,
		"cutscene_playback_position": cutscene_playback_position
		
	}
	print("Global: Gathering full save data.")
	return data

func apply_load_data(data: Dictionary):
	current_scene_path = data.get("current_scene_path", "")
	gameStarted = data.get("gameStarted", false)
	play_intro_cutscene = data.get("play_intro_cutscene", false)
	
	fullscreen_on = data.get("fullscreen_on", false)
	vsync_on = data.get("vsync_on", false)
	brightness = data.get("brightness", 1.0)
	fps_limit = data.get("fps_limit", 60)
	master_vol = data.get("master_vol", -10.0)
	bgm_vol = data.get("bgm_vol", -10.0)
	sfx_vol = data.get("sfx_vol", -10.0)
	voice_vol = data.get("voice_vol", -10.0)
	resolution_index = data.get("resolution_index", 2) 

	
	selected_form_index = data.get("selected_form_index", 0)
	# This assignment will now correctly call the set_player_form setter, emitting the signal
	set_player_form(data.get("current_form", "Normal")) 
	playerAlive = data.get("playerAlive", true)

	kills = data.get("kills", 0) # Load kills
	affinity = data.get("affinity", 0) # Load affinity
	player_status = data.get("player_status", "Normal") # NEW: Load player status
	
	completed_events = data.get("completed_events", {})
	active_quests = data.get("active_quests", [])
	completed_quests = data.get("completed_quests", [])
	
	is_cutscene_active = data.get("is_cutscene_active", false)
	cutscene_name = data.get("cutscene_name", "")
	cutscene_playback_position = data.get("cutscene_playback_position", 0.0)

	var loaded_pos_dict = data.get("player_position_before_dialog", {"x": 0.0, "y": 0.0})
	player_position_before_dialog = Vector2(loaded_pos_dict.x, loaded_pos_dict.y)
	scene_path_before_dialog = data.get("scene_path_before_dialog", "")

	
	print("Global: All saved data applied successfully.")

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
	brightness = 1.0
	fps_limit = 60
	master_vol = -10.0
	bgm_vol = -10.0
	sfx_vol = -10.0
	voice_vol = -10
	resolution_index = 2 # Reset to default index
	
	kills = 0 # Reset kills
	affinity = 0 # Reset affinity
	player_status = "Normal" # NEW: Reset player status
	# Reset the form using the setter
	set_player_form("Normal") 
	
	completed_events = {}

	
	active_quests = []
	completed_quests = []
	dialog_timeline = ""
	dialog_current_index = 0
	dialogic_variables = {}
	is_cutscene_active = false # NEW: Reset cutscene active state
	

	cutscene_name = ""
	cutscene_playback_position = 0.0

	if autosave_timer.is_running():
		autosave_timer.stop()
	autosave_timer.start()


func apply_graphics_settings():
	var current_resolution = available_resolutions[resolution_index]
	
	# Fullscreen
	if fullscreen_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(current_resolution)

		
	# V-Sync
	DisplayServer.window_set_vsync_mode(vsync_on)

	# Brightness (Requires a CanvasModulate node in your main scene)
	brightness_changed.emit(brightness) # Emit the signal here

	# You would typically have a CanvasModulate node in your main scene (e.g., world.tscn)
	# and control its 'color' property.
	# Example in world.gd: $CanvasModulate.color = Color(brightness, brightness, brightness, 1.0)
	print("Global: Applied graphics settings: Fullscreen=" + str(fullscreen_on) + 
		  ", VSync=" + str(vsync_on) + ", Brightness (value stored)=" + str(brightness))
	
	# FPS Limit
	Engine.set_max_fps(fps_limit)
	print("Global: FPS Limit set to: " + str(fps_limit))


func apply_audio_settings():
	var master_bus_idx = AudioServer.get_bus_index("Master")
	var bgm_bus_idx = AudioServer.get_bus_index("BGM")
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	var voice_bus_idx = AudioServer.get_bus_index("Voice") # NEW: Voice bus index

	if master_bus_idx != -1:
		AudioServer.set_bus_volume_db(master_bus_idx, master_vol)
	if bgm_bus_idx != -1:
		AudioServer.set_bus_volume_db(bgm_bus_idx, bgm_vol)
	if sfx_bus_idx != -1:
		AudioServer.set_bus_volume_db(sfx_bus_idx, sfx_vol)
	if voice_bus_idx != -1: # NEW: Apply voice volume
		AudioServer.set_bus_volume_db(voice_bus_idx, voice_vol)
	
	print("Global: Applied audio settings: Master=" + str(master_vol) + 
		  ", BGM=" + str(bgm_vol) + ", SFX=" + str(sfx_vol) + 
		  ", Voice=" + str(voice_vol))


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
