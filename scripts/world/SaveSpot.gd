extends Area2D
class_name SaveSpot # Changed from TeleportPole to SaveSpot

@onready var interaction_label = $Label # Make sure you have a Label child named 'Label'
var player_in_range = false # Tracks if the player is currently within the spot's interaction area

# Optional: If this spot also teleports you to another scene after saving
# You can set these in the Inspector for each SaveSpot instance
@export var target_scene_path: String = "" # Path to the scene to load, e.g., "res://scenes/world/world_level_2.tscn"
@export var target_position_in_scene: Vector2 = Vector2.ZERO # Where the player should appear in the target scene

func _ready():
	# Connect the Area2D signals to detect when a body enters or exits its area
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Hide the interaction label initially
	interaction_label.visible = false
	
	print("SaveSpot is ready. Waiting for player interaction.") # Updated print statement

func _process(delta):
	# --- DEBUGGING: Print every frame to see if _process is running and player_in_range is true ---
	# This will spam the console, but it's crucial for diagnosing if input is even being checked.
	# Uncomment the line below if you want constant feedback:
	# print("SaveSpot _process: player_in_range = %s, Input.is_action_pressed('interact') = %s" % [player_in_range, Input.is_action_pressed("interact")])

	# Check if the player is in range and presses the "interact" action
	# (Make sure "interact" is set up in Project Settings -> Input Map, e.g., to 'E' key)
	# Using Input.is_action_just_pressed ensures it only triggers once per press.
	if player_in_range and Input.is_action_just_pressed("yes"):
		print("Interact button pressed while player in range. Initiating save/teleport.") # Debug print
		handle_interaction()


func handle_interaction():
	# --- ENHANCED FIX: Cast the retrieved node to Player type with more checks ---
	var found_node = get_tree().get_first_node_in_group("player")
	var player_node: Player = null # Initialize as null

	if found_node:
		player_node = found_node as Player
		if player_node == null:
			printerr("Error: Found node in 'player' group but it could not be cast to Player type. Is it really your player?")
	else:
		printerr("Error: No node found in 'player' group. Is your Player node added to the 'player' group?")

	if player_node:
		# --- SAVE GAME LOGIC ---
		# Before saving, update the current_scene_path in Global.gd
		# This ensures we save which scene the player was in.
		# This is CRUCIAL for loading the correct scene later.
		Global.current_scene_path = get_tree().current_scene.scene_file_path
		
		# Call the save_game function from your SaveLoadManager Autoload.
		# For SaveSpot, we'll assume it's a manual save point, so we'll save to a specific slot.
		# For now, let's make it save to manual_save_1. You'd later connect this to a UI
		# to choose the slot.
		var manual_save_slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + "1" # Example: Save to slot 1
		if SaveLoadManager.save_game(player_node, manual_save_slot_name): # Pass the player node and slot name
			print("Game saved successfully at SaveSpot to manual slot 1!") # Updated print statement
			# Optionally, display a temporary "Game Saved!" message on the screen
		else:
			printerr("Failed to save game at SaveSpot (SaveLoadManager returned false).") # Updated print statement
			# Optionally, display an error message

		# --- TELEPORT/LOAD POINT LOGIC (if applicable) ---
		# If this spot also serves as a portal to another level, implement that here.
		# This example assumes for now it's primarily a save point.
		
		# If you set target_scene_path, you could implement a teleport here:
		# if target_scene_path != "":
		#     if ResourceLoader.exists(target_scene_path, "PackedScene"):
		#         var target_scene_packed = load(target_scene_path) as PackedScene
		#         get_tree().change_scene_to_packed(target_scene_packed)
		#         await get_tree().physics_frame # Wait for scene change to complete
		#         await get_tree().physics_frame # Wait another frame for safety
		#         var loaded_player = get_tree().get_first_node_in_group("player")
		#         if loaded_player:
		#             loaded_player.global_position = target_position_in_scene
		#             print("Teleported player to new scene at: ", target_position_in_scene)
		#         else:
		#             printerr("Error: Player not found in new scene after teleport.")
		#     else:
		#         printerr("Error: Target scene path for teleport is invalid: ", target_scene_path)
	else:
		# This message will now be more specific about why player_node is null
		printerr("Player node (or valid Player instance) not found for interaction. Check group and class_name.")


# Called when a body (e.g., player) enters the Area2D
func _on_body_entered(body: Node2D):
	# Check if the entering body is the player by checking its group
	if body.is_in_group("player"):
		player_in_range = true
		interaction_label.visible = true # Show the "Press E to Save" label
		print("Player entered SaveSpot area.") # Updated print statement
		# --- DEBUGGING: Confirm collision layers/masks ---
		print("SaveSpot: Body '%s' entered. Player layers: %s, SaveSpot collision mask: %s" % [body.name, body.get_collision_layer(), get_collision_mask()])
		# --- DEBUGGING: Further check on the 'body' that entered ---
		if body is Player:
			print("SaveSpot: The entering body IS of type Player.")
		else:
			print("SaveSpot: The entering body is NOT of type Player, but is in group 'player'. Type: ", body.get_class())


# Called when a body (e.g., player) exits the Area2D
func _on_body_exited(body: Node2D):
	# Check if the exiting body is the player
	if body.is_in_group("player"):
		player_in_range = false
		interaction_label.visible = false # Hide the label
		print("Player exited SaveSpot area.") # Updated print statement
