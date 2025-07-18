extends Area2D

class_name MagusSpot
# (Alternatively, get_node("/root/TransitionManager") if autoloaded, or a NodePath to a TransitionManager node in scene.)
@export var telekinesis_radius: float = 160.0
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
		player_in_range.telekinesis_enabled = false
		player_in_range.current_magic_spot = null
		player_in_range = null

func _process(delta):
	if player_in_range:
		if Input.is_action_just_pressed("no") and player_in_range.telekinesis_enabled == false:
			Global.telekinesis_mode= true
			player_in_range.telekinesis_enabled = true
			player_in_range.current_magic_spot = self
			print("enter telekinesis")
		elif Input.is_action_just_pressed("no") and player_in_range.telekinesis_enabled == true:
			Global.telekinesis_mode= false
			player_in_range.telekinesis_enabled = false
			player_in_range.current_magic_spot = null
			print("exit telekinesis")

func get_nearby_telekinesis_objects() -> Array:
	var objects: Array = []
	for obj in get_tree().get_nodes_in_group("TelekinesisObject"):
		if global_position.distance_to(obj.global_position) <= telekinesis_radius:
			objects.append(obj)
	return objects
