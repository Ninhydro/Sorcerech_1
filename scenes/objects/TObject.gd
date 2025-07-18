class_name TelekinesisObject
extends RigidBody2D

@export var object_id: String   # Use "A", "B", "C", etc.

@onready var sprite = $Sprite2D
var is_controlled := false
var offset := Vector2.ZERO
@export var can_teleport_switch := true

func _ready():
	add_to_group("TelekinesisObject")
	sprite.material = null 

func start_levitation(player_pos: Vector2):
	is_controlled = true
	offset = position - player_pos

func update_levitation(player_pos: Vector2):
	if Input.is_action_pressed("move_right"):
		linear_velocity.x += 1
	if Input.is_action_pressed("move_left"):
		linear_velocity.x -= 1
	if Input.is_action_pressed("move_up"):
		linear_velocity.y -= 1
	if Input.is_action_pressed("move_down"):
		linear_velocity.y += 1

func stop_levitation():
	is_controlled = false
