extends Area2D


# (Alternatively, get_node("/root/TransitionManager") if autoloaded, or a NodePath to a TransitionManager node in scene.)

var player_in_range = null

@export var player_path: NodePath



   
	
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
	if player_in_range:
		if Input.is_action_just_pressed("no"):
			#player_in_range.cannon_enabled  = true
			print("enter canon1")
			player_in_range.canon_enabled = true
			player_in_range.enter_cannon()

