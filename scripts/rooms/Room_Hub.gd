extends Node2D


@onready var player = get_node("/root/World/Player")

func _ready() -> void:
	#print("World ready. Initializing sandbox...")
	#Dialogic.start("timeline1", false)
	#add_child(new_dialog)
	 # Safely enable Camera2D if it exists under the player
	
	pass
	#if player.has_node("Camera2D"):
	#	var cam = $Player.get_node("Camera2D")
	#	if cam is Camera2D:
	#		cam.make_current()
	
	# Optional: Display sandbox label
	#if has_node("Label"):
	#	$Label.text = "Welcome to the Platformer Sandbox!"

	# Enable some test abilities for sandbox
	# Toggle player abilities for testing

	#if has_node("Player"):
	#	$Player.allow_double_jump = true
	#	$Player.allow_dash = true
	#	$Player.allow_wall_climb = true

	# Add a static floor platform if not already present

	
