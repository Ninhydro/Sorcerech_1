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
	#Global.kills = 1
	#Global.affinity = 0
	#print(Global.affinity)
	

	# This line tells the Global singleton which scene the player is currently in.
	Global.set_current_game_scene_path(self.scene_file_path)
	print("World: Scene path set in Global: " + Global.current_scene_path)


	# Connect to the Global signal when the scene is ready
	Global.brightness_changed.connect(_on_global_brightness_changed)
	# Apply initial brightness setting from Global when scene loads
	_on_global_brightness_changed(Global.brightness)
	

	print("Main Scene _ready() finished. Global.playerBody should be set now: ", Global.playerBody)
	


	# Validate essential nodes exist
	if not player_spawn_point_junkyard:
		print("❌ World: player_spawn_point_junkyard not found! Check node path: $Room_AerendaleJunkyard/Marker2D")
		# Consider a fallback or error handling if a critical node is missing
		return
	
	# IMPORTANT: Assign the pre-existing player to Global.playerBody immediately
	if player_instance and is_instance_valid(player_instance):
		Global.playerBody = player_instance
		print("✅ World: Pre-existing player assigned to Global.playerBody.")
		#player_instance.unlock_state("Magus")
		#player_instance.unlock_state("Cyber")
		#player_instance.unlock_state("UltimateMagus")
		#player_instance.unlock_state("UltimateCyber")
	else:
		print("❌ World: Pre-existing player node not found or invalid! Check @onready var player_instance path.")
		# Handle this as a fatal error or spawn a new player as fallback
		return # Cannot proceed without a player instance

	if not cutscene_manager:
		print("❌ World: cutscene_manager not found! Check node path: $CutsceneManager")
		# If no cutscene manager, proceed as if cutscene finished
		# In this scenario, it's either a new game without cutscene or a loaded game.
		# We'll rely on Global.play_intro_cutscene to differentiate.
		if Global.play_intro_cutscene:
			# If it's supposed to be a new game with intro, but cutscene manager is missing,
			# then directly set player to default start position.
			print("World: No cutscene manager, treating as new game without cutscene.")
			teleport_player_and_enable(true) # Force default position for new game
		else:
			# If no cutscene manager and not new game, it's a loaded game.
			print("World: No cutscene manager, treating as loaded game.")
			teleport_player_and_enable(false) # Don't force position, Player.gd handles it
		return # Exit _ready as we've handled the missing manager

	# --- Logic for New Game vs. Loaded Game ---
	if Global.play_intro_cutscene:
		print("World: Starting intro cutscene for new game...")
		setup_intro_cutscene()
	else:
		print("World: Not a new game (loaded game or scene transition). Player.gd will apply loaded position.")
		# For loaded games, Player.gd's _ready() will apply the saved position.
		# This function just ensures player is visible, enabled, and camera follows.
		teleport_player_and_enable(false) # Pass 'false' to NOT force a default position
		print("✅ World: Player setup completed for loaded game.")

	#Global.playerBody = player_instance
	#print(Global.playerBody)
	#print("Main Scene _ready() finished. Global.playerBody should be set now: ", Global.playerBody)
	
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
	
