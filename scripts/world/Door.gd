extends Area2D

@export var target_room: String     # Name of the destination room (node or scene)
@export var target_spawn: String    # Name of the spawn marker in the target room

@onready var transition_manager = get_node("/root/TransitionManager")
# (Alternatively, get_node("/root/TransitionManager") if autoloaded, or a NodePath to a TransitionManager node in scene.)

var player_in_range = null

func _ready() -> void:
	# Connect the body_entered signal to trigger the transition when player enters the door area
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))
	# (Ensure the collision layer/mask is set so that the player (body) colliding triggers this.)



func _on_body_entered(body):
	if body.name == "Player":
		player_in_range = body

func _on_body_exited(body):
	if body == player_in_range:
		player_in_range = null

func _process(delta):
	#if player_in_range and Input.is_action_just_pressed("move_up"):
	#	transition_manager.travel_to(player_in_range, target_room, target_spawn)
	if player_in_range:
		transition_manager.travel_to(player_in_range, target_room, target_spawn)
