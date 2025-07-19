extends Node2D

@onready var player_spawn_point_initial: Marker2D = $Marker2D # For camera during cutscene
@onready var player_spawn_point_junkyard: Marker2D = $Room_AerendaleJunkyard/Marker2D # Player's actual spawn after the cutscene

# IMPORTANT: Reference the player that is ALREADY IN THE SCENE TREE
@onready var player_instance: Node2D = $Player # Adjust this path if your Player node is not directly named "Player" or is a child of something else. E.g., "$Characters/Player"

@onready var cutscene_manager: Node = $CutsceneManager # Path to your CutsceneManager node

@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

@onready var canvas_modulate: CanvasModulate = $CanvasModulate # Adjust path if different

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("menu"):
		if not get_tree().paused: # Only open if game is not already paused
			print("World: 'menu' pressed, opening pause menu.")
			var pause_menu_instance = pause_menu_scene.instantiate()
			add_child(pause_menu_instance)
			get_tree().paused = true # Pause the game when menu opens
			get_viewport().set_input_as_handled() # <--- THIS IS THE KEY LINE!
		#else: # This block is for if you press "menu" again while paused
			# If the pause menu is already open, it will handle closing itself
			# You generally don't want to close it from here if PauseMenu.gd has _unhandled_input

func _ready():
	print("World: _ready() called. Global.play_intro_cutscene = ", Global.play_intro_cutscene)
	
	Global.set_current_game_scene_path(self.scene_file_path)
	print("World: Scene path set in Global: " + Global.current_scene_path)

	Global.brightness_changed.connect(_on_global_brightness_changed)
	_on_global_brightness_changed(Global.brightness)
	
	if not player_spawn_point_junkyard:
		print("❌ World: player_spawn_point_junkyard not found! Check node path: $Room_AerendaleJunkyard/Marker2D")
		return
	
	if player_instance and is_instance_valid(player_instance):
		Global.playerBody = player_instance
		print("✅ World: Pre-existing player assigned to Global.playerBody.")
	else:
		print("❌ World: Pre-existing player node not found or invalid! Check @onready var player_instance path.")
		return

	if not cutscene_manager:
		print("❌ World: cutscene_manager not found! Check node path: $CutsceneManager")
		if Global.play_intro_cutscene:
			print("World: No cutscene manager, treating as new game without cutscene.")
			teleport_player_and_enable(true)
		else:
			print("World: No cutscene manager, treating as loaded game.")
			teleport_player_and_enable(false)
		return

	# Determine if this is a NEW GAME start or a LOADED GAME/SCENE CHANGE
	var is_loaded_game = not Global.current_loaded_player_data.is_empty()

	# --- IMPORTANT: Clear any active Dialogic dialog on scene load/start ---
	# Use end_timeline() as it's the official public method to stop and clear the dialog.
	# It internally handles hiding the layout node.
	
	# We should check if a timeline is actually running to avoid unnecessary calls
	# The DialogicGameHandler has 'current_timeline' property.
	if Dialogic.current_timeline != null:
		print("World: Active Dialogic timeline detected. Calling Dialogic.end_timeline().")
		Dialogic.end_timeline()
	else:
		print("World: No active Dialogic timeline on scene load/start.")
	
	# If you also want to completely reset Dialogic's internal state (e.g., clear variables)
	# even if no timeline was running, you can call clear() here.
	# Be mindful if you want variables to persist across scene loads.
	# If Dialogic.clear() is needed, ensure it's called after end_timeline() if a timeline was active.
	# Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	# print("World: Also called Dialogic.clear(FULL_CLEAR) to reset full Dialogic state.")
	# ---------------------------------------------------------------------

	if is_loaded_game:
		# LOADED GAME/SCENE CHANGE LOGIC
		print("World: Loaded game or scene transition. Player.gd will apply loaded position.")
		teleport_player_and_enable(false) # Player.gd handles position
		print("✅ World: Player setup completed for loaded game.")
		
		# Dialogic resume logic temporarily commented out as per your request.
		# ... (your commented out Dialogic resume code) ...

	else:
		# NEW GAME LOGIC (or scene changes NOT from a load)
		if Global.play_intro_cutscene:
			print("World: Starting intro cutscene for new game...")
			setup_intro_cutscene()
		else:
			print("World: Not a new game. Player will be placed at default spawn.")
			teleport_player_and_enable(true)
			print("✅ World: Player setup completed for non-cutscene new game.")

	print("Main Scene _ready() finished.")


func setup_intro_cutscene():
	# Position camera for cutscene if spawn point exists
	if player_spawn_point_initial:
		var camera = get_viewport().get_camera_2d()
		if camera:
			camera.global_position = player_spawn_point_initial.global_position
			camera.zoom = Vector2(1, 1) # Reset zoom for cutscene if needed
			print("World: Camera positioned for cutscene")
		else:
			print("❌ World: No camera found in viewport for cutscene setup.")
	
	# Hide player and disable input during cutscene
	if player_instance and is_instance_valid(player_instance):
		player_instance.visible = false
		# Assuming Player.gd has a method to control its input processing
		if player_instance.has_method("set_input_enabled"):
			player_instance.set_input_enabled(false)
		else:
			player_instance.set_physics_process(false)
			player_instance.set_process(false)
		print("World: Player hidden and input disabled for cutscene.")

	# Connect to cutscene finished signal
	if cutscene_manager.has_signal("cutscene_finished"):
		# Disconnect any old connections to prevent duplicate calls
		if cutscene_manager.cutscene_finished.is_connected(_on_cutscene_manager_finished):
			cutscene_manager.cutscene_finished.disconnect(_on_cutscene_manager_finished)
		
		cutscene_manager.cutscene_finished.connect(_on_cutscene_manager_finished)
		print("World: Connected to cutscene_finished signal.")
		
		if cutscene_manager.has_method("start_cutscene"):
			cutscene_manager.start_cutscene()
			print("World: Cutscene started.")
		else:
			print("❌ World: CutsceneManager missing 'start_cutscene' method. Proceeding without cutscene.")
			# If cutscene manager exists but can't start cutscene, treat as finished
			_on_cutscene_manager_finished() # Manually call finished logic
	else:
		print("❌ World: CutsceneManager missing 'cutscene_finished' signal. Proceeding without cutscene.")
		_on_cutscene_manager_finished() # Manually call finished logic


func _on_cutscene_manager_finished():
	print("✅ World: Cutscene finished signal received!")
	
	Global.play_intro_cutscene = false # Set this to false after intro cutscene finishes
	print("World: Global.play_intro_cutscene set to false.")
	
	# Now, teleport and enable the *existing* player to its default starting position
	teleport_player_and_enable(true) # Pass 'true' to force default position for new game
	print("✅ World: Player setup completed successfully after cutscene!")


# This function now handles teleporting and enabling the EXISTING player.
# 'position_player' argument determines if the player's position should be set by this function.
func teleport_player_and_enable(position_player: bool = true):
	print("World: teleport_player_and_enable() called with position_player_arg: " + str(position_player))

	
	if not player_instance or not is_instance_valid(player_instance):
		print("❌ World: Cannot teleport player - player_instance is null or invalid!")
		return

	if not player_spawn_point_junkyard:
		print("❌ World: Cannot teleport player - junkyard spawn point not found!")
		return
	
	# --- Conditional Player Positioning ---
	if position_player:
		player_instance.global_position = player_spawn_point_junkyard.global_position
		print("✅ World: Player positioned at default spawn point: ", player_instance.global_position)
	else:
		# If not positioning, assume Player.gd's _ready() has already applied loaded data.
		print("✅ World: Player's position assumed to be set by Player.gd load: ", player_instance.global_position)
	# --- End Conditional Player Positioning ---
	
	# Ensure player is visible and enabled
	player_instance.visible = true
	player_instance.set_process_mode(Node.PROCESS_MODE_INHERIT) # Ensure processing is inherited
	
	# Enable player input
	if player_instance.has_method("enable_input"): # If your Player script has a custom enable_input method
		player_instance.enable_input()
	elif player_instance.has_method("set_input_enabled"): # If it has a set_input_enabled method
		player_instance.set_input_enabled(true)
	else:
		# Fallback for generic Node2D if no specific input enabling method
		player_instance.set_process(true)
		player_instance.set_physics_process(true)
	
	
	# Make sure the camera follows the player
	setup_camera_following()
	
	
	print("✅ World: Player visibility, input, and camera setup completed.")


func setup_camera_following():
	var camera = get_viewport().get_camera_2d()
	if camera and player_instance:
		if camera.has_method("set_target"): # If your custom camera script has set_target
			camera.set_target(player_instance)
			print("World: Camera set_target to player.")
		else:
			# Fallback: Directly position camera. This might be jerky if player moves.
			camera.global_position = player_instance.global_position
			print("World: Camera positioned directly to player (fallback).")
	else:
		print("❌ World: Camera or player_instance not found for camera setup.")
	#Global.playerBody = player_instance

func _on_global_brightness_changed(new_brightness_value: float):
	# Ensure the value is within a reasonable range (e.g., 0.0 to 2.0 or so)
	# Godot's Color values are typically 0.0 to 1.0, but for brightness,
	# you might want to allow going above 1.0 for "super bright" effects.
	# For a simple brightness control, clamping between 0 and 1 is usually fine.
	var clamped_brightness = clampi(new_brightness_value, 0.0, 2.0) # Adjust max as needed

	# Set the color of the CanvasModulate node
	canvas_modulate.color = Color(clamped_brightness, clamped_brightness, clamped_brightness, 1.0)
	print("World: CanvasModulate brightness updated to: ", clamped_brightness)
	
