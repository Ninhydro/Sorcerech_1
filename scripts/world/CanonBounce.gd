# bouncespot.gd
extends StaticBody2D

@export var bounce_angle_degrees: float # Angle in degrees for the bounce direction.
												# -90 degrees is straight up.
												# 0 degrees is right.
												# 90 degrees is straight down.
												# 180 degrees is left.
@export var bounce_power: float = 1.0

func _ready():
	# This surface is on collision layer 2.
	collision_layer = 2
	# It will detect (mask) objects on collision layer 1.
	# Assuming your player (CharacterBody2D) is on collision layer 1 (its default).
	collision_mask = 1

func get_bounce_data() -> Dictionary:
	"""
	Returns a dictionary containing the bounce normal (derived from angle) and power.
	This function is called by the player when it collides with this bounce spot.
	"""
	# Convert the angle in degrees to a normalized Vector2 for the bounce normal
	var calculated_bounce_normal = Vector2.RIGHT.rotated(deg_to_rad(bounce_angle_degrees))
	return {
		"normal": calculated_bounce_normal,
		"power": bounce_power
	}
