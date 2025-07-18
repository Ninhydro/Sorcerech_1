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
var current_form:String

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

# Added default save values for common gameplay elements
#var player_experience := 0
#var player_level := 1
#var player_skills := []

var kills: int
var affinity: int

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


var current_scene_path: String = "" 

var current_loaded_player_data: Dictionary = {}
var current_game_state_data: Dictionary = {}

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

		"selected_form_index": selected_form_index,
		"current_form": current_form,
		"playerAlive": playerAlive,

		
		"kills": kills,
		"affinity": affinity,
		
		"completed_events": completed_events,
		"active_quests": active_quests,
		"completed_quests": completed_quests,

		"dialog_timeline": dialog_timeline,
		"dialog_current_index": dialog_current_index,
		"dialogic_variables": dialogic_variables
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
	
	selected_form_index = data.get("selected_form_index", 0)
	current_form = data.get("current_form", "")
	playerAlive = data.get("playerAlive", true)

	
	kills = data.get("kills", 0)
	affinity = data.get("affinity", 0)
	
	completed_events = data.get("completed_events", {})
	active_quests = data.get("active_quests", [])
	completed_quests = data.get("completed_quests", [])

	dialog_timeline = data.get("dialog_timeline", "")
	dialog_current_index = data.get("dialog_current_index", 0)
	dialogic_variables = data.get("dialogic_variables", {})

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
	
	kills = 0
	affinity = 0
	
	completed_events = {}

	
	active_quests = []
	completed_quests = []
	dialog_timeline = ""
	dialog_current_index = 0
	dialogic_variables = {}

	if autosave_timer.is_running():
		autosave_timer.stop()
	autosave_timer.start()


func apply_graphics_settings():
	# Fullscreen
	if fullscreen_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# V-Sync
	DisplayServer.window_set_vsync_mode(vsync_on)

	# Brightness (Requires a CanvasModulate node in your main scene)
	# You would typically have a CanvasModulate node in your main scene (e.g., world.tscn)
	# and control its 'color' property.
	# Example in world.gd: $CanvasModulate.color = Color(brightness, brightness, brightness, 1.0)
	print("Global: Applied graphics settings: Fullscreen=" + str(fullscreen_on) + 
		  ", VSync=" + str(vsync_on) + ", Brightness (value stored)=" + str(brightness))
	
	# Pixel Smoothing (Texture Filter)
	# This usually affects how textures are rendered (e.g., sharp for pixel art, linear for smooth).
	# It's a Project Setting and often requires a restart or scene reload to fully apply globally.
	# For dynamic changes, you might need a custom viewport setup.
	if pixel_smoothing:
		ProjectSettings.set_setting("rendering/textures/default_filters/texture_filter", 1)  # 1 = Linear
		print("Global: Pixel Smoothing set to LINEAR (smooth).")
	else:
		ProjectSettings.set_setting("rendering/textures/default_filters/texture_filter", 0)  # 0 = Nearest
		ProjectSettings.save() # Save project settings so it persists across runs
	
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
