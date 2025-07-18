extends Area2D



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

	
	print("SaveSpot is ready. Waiting for player interaction.") # Updated print statement

func _process(delta):
	# --- DEBUGGING: Print every frame to see if _process is running and player_in_range is true ---
	# This will spam the console, but it's crucial for diagnosing if input is even being checked.
	# Uncomment the line below if you want constant feedback:
	# print("SaveSpot _process: player_in_range = %s, Input.is_action_pressed('interact') = %s" % [player_in_range, Input.is_action_pressed("interact")])

	# Check if the player is in range and presses the "interact" action
	# (Make sure "interact" is set up in Project Settings -> Input Map, e.g., to 'E' key)
	# Using Input.is_action_just_pressed ensures it only triggers once per press.
	#if player_in_range and Input.is_action_just_pressed("yes"):
	#	print("Interact button pressed while player in range. Initiating save/teleport.") # Debug print
	#	handle_interaction()
	pass


func _on_body_entered(body: Node2D):
	# Check if the entering body is the player by checking its group
	if body.is_in_group("player"):
		player_in_range = true

		Dialogic.start("timeline2", false)

# Called when a body (e.g., player) exits the Area2D
func _on_body_exited(body: Node2D):
	# Check if the exiting body is the player
	if body.is_in_group("player"):
		player_in_range = false
