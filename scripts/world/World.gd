extends Node2D

@onready var player_spawn_point_initial: Marker2D = $Marker2D # For camera during cutscene
@onready var player_spawn_point_junkyard: Marker2D = $Room_AerendaleJunkyard/Marker2D # Player's actual spawn after the cutscene

# IMPORTANT: Reference the player that is ALREADY IN THE SCENE TREE
@onready var player_root_node: Node2D = $Player # Adjust this path if your Player node is not directly named "Player" or is a child of something else. E.g., "$Characters/Player"

@onready var cutscene_manager: Node = $CutsceneIntro# Path to your CutsceneManager node

@export var pause_menu_scene: PackedScene = preload("res://scenes/ui/pause_menu.tscn")

@onready var canvas_modulate: CanvasModulate = $CanvasModulate # Adjust path if different

@onready var _player_camera: Camera2D = null # This will be assigned in _ready when player_instance is valid

# Removed the @onready var cutscene_camera_node as we're using the player's camera
var actual_player_body: Player = null # <--- CHANGE this type hint

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("menu"):
		if not get_tree().paused: # Only open if game is not already paused
			print("World: 'menu' pressed, opening pause menu.")
			var pause_menu_instance = pause_menu_scene.instantiate()
			add_child(pause_menu_instance)
			#get_tree().paused = true # Pause the game when menu opens
			get_viewport().set_input_as_handled() # <--- THIS IS THE KEY LINE!

func _ready():
	print("World: _ready() called. Global.play_intro_cutscene = ", Global.play_intro_cutscene)
	
	# --- Player Node and Camera Setup (Existing Logic) ---
	# This section ensures the player node and its camera are correctly referenced.
	print("World: Debug: @onready player_root_node resolved to: ", player_root_node)
	if not is_instance_valid(player_root_node):
		printerr("World: WARNING: @onready player_root_node is NULL or INVALID in initial _ready. Attempting to find it again dynamically.")
		player_root_node = get_node_or_null("Player")
		if not is_instance_valid(player_root_node):
			player_root_node = find_child("Player", true)
			if not is_instance_valid(player_root_node):
				printerr("World: CRITICAL ERROR: Could not find 'Player' Node2D dynamically either. Scene setup for player will be skipped in this _ready call.")
				print("World: Debug: EXITING _ready() - player_root_node not found.")
				return
			else:
				print("World: Debug: Successfully found player_root_node dynamically after initial null: ", player_root_node)
		else:
			print("World: Debug: Successfully re-obtained player_root_node via get_node_or_null after initial null: ", player_root_node)

	var actual_player_body: CharacterBody2D = null
	if player_root_node:
		actual_player_body = player_root_node.get_node_or_null("Player") as Player

	if not is_instance_valid(actual_player_body) or not (actual_player_body is Player):
		printerr("World: CRITICAL ERROR: Could not find or cast CharacterBody2D named 'Player' under PlayerRoot_Node2D! Check your player scene structure.")
		print("World: Debug: EXITING _ready() - actual_player_body not found or invalid.")
		return

	print("World: Debug: About to assign actual_player_body to Global.playerBody: ", actual_player_body)
	Global.playerBody = actual_player_body
	print("World: Debug: Finished assignment. Global.playerBody now (should be): ", Global.playerBody)

	# --- Safely assign _player_camera ---
	if Global.playerBody and is_instance_valid(Global.playerBody):
		_player_camera = Global.playerBody.get_node_or_null("CameraPivot/Camera2D")
		if not _player_camera:
			printerr("World: ERROR: Player's Camera2D not found at 'Camera2D' under playerBody!")
	else:
		printerr("World: ERROR: Global.playerBody is null or invalid, cannot assign _player_camera!")

	if not is_instance_valid(Global.playerBody):
		printerr("World: CRITICAL ERROR: Global.playerBody is NULL or INVALID IMMEDIATELY AFTER ASSIGNMENT in World.gd! Something cleared it.")
		print("World: Debug: EXITING _ready() - Global.playerBody invalid after assignment.")
		return

	Global.set_current_game_scene_path(self.scene_file_path)
	print("World: Scene path set in Global: " + Global.current_scene_path)

	Global.brightness_changed.connect(_on_global_brightness_changed)
	_on_global_brightness_changed(Global.brightness)

	if not player_spawn_point_junkyard or not is_instance_valid(player_spawn_point_junkyard):
		printerr("❌ World: player_spawn_point_junkyard not found or invalid! Check node path: $Room_AerendaleJunkyard/Marker2D")
		return

	var is_loaded_game = not Global.current_loaded_player_data.is_empty()

	# --- Cutscene / Game Start Logic ---
	if not is_loaded_game: # This is a new game (or a scene change within a new game session)
		if Global.play_intro_cutscene:
			print("World: New Game detected. Initiating intro cutscene.")
			# Ensure cutscene manager is valid
			if not is_instance_valid(cutscene_manager):
				printerr("❌ World: CutsceneManager node not found or invalid! Path: $CutsceneManager")
				# Fallback: if cutscene manager is missing, just spawn player
				teleport_player_and_enable(true)
				Global.play_intro_cutscene = false # Reset the flag
				return

			# Connect the cutscene_finished signal from the CutsceneManager
			if not cutscene_manager.cutscene_finished.is_connected(Callable(self, "_on_cutscene_finished")):
				cutscene_manager.cutscene_finished.connect(Callable(self, "_on_cutscene_finished"))

			# Disable player input and hide player until cutscene finishes
			if Global.playerBody.has_method("disable_input"):
				Global.playerBody.disable_input()
			elif Global.playerBody.has_method("set_input_enabled"):
				Global.playerBody.set_input_enabled(false)
			else:
				Global.playerBody.set_process(false)
				Global.playerBody.set_physics_process(false)
			Global.playerBody.visible = false
			print("World: Player disabled and hidden for cutscene.")

			# Use the player's camera for the cutscene, temporarily moving it
			if is_instance_valid(_player_camera):
				_player_camera.global_position = player_spawn_point_initial.global_position
				_player_camera.make_current()
				print("World: Player camera moved to initial spawn point for cutscene.")
			else:
				printerr("World: No valid player camera found for cutscene!")

			# Start the cutscene using the CutsceneManager
			cutscene_manager.start_cutscene()
			print("World: CutsceneManager.start_cutscene() called.")

			# Reset the global flag immediately. This prevents the cutscene from playing
			# again if you change scenes within the same "new game" session.
			Global.play_intro_cutscene = false
			print("World: Global.play_intro_cutscene reset to false.")

		else: # This branch is for new games that are NOT the initial intro cutscene (e.g., scene changes within a new game session)
			if Dialogic.current_timeline != null:
				print("World: New game/Scene change. Active Dialogic timeline detected. Calling Dialogic.end_timeline().")
				Dialogic.end_timeline()
			else:
				print("World: New game/Scene change. No active Dialogic timeline. Proceeding.")
			teleport_player_and_enable(true) # Place player at default spawn
			print("✅ World: Player setup completed for non-intro new game (scene change).")

	else: # This branch is for loaded games
		print("World: Loaded game. Player.gd will apply loaded position.")
		teleport_player_and_enable(false) # Player position will be handled by load data
		print("✅ World: Player setup completed for loaded game.")

	print("Main Scene _ready() finished.")

# NEW: Function to handle when the cutscene finishes
func _on_cutscene_finished():
	print("World: _on_cutscene_finished() called. Enabling player and switching camera.")
	# Now that the cutscene is over, position the player, enable their input, and switch to their camera.
	teleport_player_and_enable(true) # This will position player at junkyard, enable input, and switch to player camera
	print("✅ World: Player enabled and camera switched after cutscene.")
	#switch_to_player_camera()

func teleport_player_and_enable(position_player: bool = true):
	print("World: teleport_player_and_enable() called with position_player_arg: " + str(position_player))

	if not Global.playerBody or not is_instance_valid(Global.playerBody):
		printerr("❌ World: Cannot teleport player - Global.playerBody is null or invalid!")
		return

	if not player_spawn_point_junkyard or not is_instance_valid(player_spawn_point_junkyard):
		printerr("❌ World: Cannot teleport player - junkyard spawn point not found or invalid!")
		return

	if position_player:
		Global.playerBody.global_position = player_spawn_point_junkyard.global_position
		print("✅ World: Player positioned at default spawn point: ", Global.playerBody.global_position)
	else:
		print("✅ World: Player's position assumed to be set by Player.gd load: ", Global.playerBody.global_position)

	Global.playerBody.visible = true
	Global.playerBody.set_process_mode(Node.PROCESS_MODE_INHERIT)

	if Global.playerBody.has_method("enable_input"):
		Global.playerBody.enable_input()
	elif Global.playerBody.has_method("set_input_enabled"):
		Global.playerBody.set_input_enabled(true)
	else:
		Global.playerBody.set_process(true)
		Global.playerBody.set_physics_process(true)

	# Always switch to player camera when enabling player
	Callable(self, "switch_to_player_camera").call_deferred()

	print("✅ World: Player visibility, input, and camera setup completed.")


func setup_camera_following():
	print("World: setup_camera_following() called, deferring to switch_to_player_camera.")
	Callable(self, "switch_to_player_camera").call_deferred()

func _on_global_brightness_changed(new_brightness_value: float):
	var clamped_brightness = clampi(new_brightness_value, 0.0, 2.0)
	if canvas_modulate:
		canvas_modulate.color = Color(clamped_brightness, clamped_brightness, clamped_brightness, 1.0)
		print("World: CanvasModulate brightness updated to: ", clamped_brightness)
	else:
		printerr("World: WARNING: canvas_modulate is null, cannot update brightness.")

# This function is no longer needed as we're not switching to a separate cutscene camera.
# The player's camera is simply repositioned.
func switch_to_cutscene_camera(cutscene_cam: Camera2D):
	# In Godot 4, you don't call set_current(false) on the old camera.
	# You just make the new camera current.
	# The 'player_camera.is_current()' check is still useful for debugging or conditional logic,
	# but the actual unsetting is implicit when make_current() is called on another camera.

	if cutscene_cam and is_instance_valid(cutscene_cam):
		# Ensure the cutscene camera is enabled and processing before making it current
		cutscene_cam.enabled = true
		cutscene_cam.set_process_mode(Node.PROCESS_MODE_INHERIT) # Ensure it processes
		cutscene_cam.make_current() # THIS IS THE KEY CHANGE
		print("✅ World.gd: Cutscene camera activated: ", cutscene_cam.name)
	else:
		printerr("World.gd: Failed to switch to cutscene camera: invalid reference.")

func switch_to_player_camera():
	# When switching back to the player camera, we simply make it current.
	# The previously current camera (e.g., cutscene_cam) will automatically become non-current.
	# We can optionally disable the old camera here if it's no longer needed for processing.

	var previous_camera = get_viewport().get_camera_2d() # Get the camera that *was* current

	if _player_camera and is_instance_valid(_player_camera):
		_player_camera.enabled = true
		_player_camera.set_process_mode(Node.PROCESS_MODE_INHERIT) # Ensure it processes
		_player_camera.make_current() # THIS IS THE KEY CHANGE
		print("✅ World.gd: Player camera activated.")

		# Optional: If the previous camera was the cutscene camera, you can disable it here
		# to prevent it from consuming resources if it's not needed.
		if previous_camera and previous_camera != _player_camera and is_instance_valid(previous_camera):
			# You might want to check its name or type if you have multiple types of cutscene cameras
			# For example, if your cutscene camera is always named "Camera2D":
			# if previous_camera.name == "Camera2D":
			previous_camera.enabled = false
			previous_camera.set_process_mode(Node.PROCESS_MODE_DISABLED)
			print("World.gd: Deactivated previous camera (", previous_camera.name, ").")

	else:
		printerr("World.gd: Failed to switch to player camera: player_camera is invalid.")

func _exit_tree():
	# Force cleanup of all shader materials
	Global.cleanup_all_materials()
	
	# Force garbage collection
	#OS.request_rendering_thread_safe_garbage_collection()
	
func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Engine.has_singleton("Dialogic"):
			var dlg = Dialogic
			if dlg:
				dlg.end_all_dialogs()
				dlg.clear() # clears loaded subsystems/resources
		get_tree().quit()
