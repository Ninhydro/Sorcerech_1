extends Area2D
class_name Rocket

@export var speed = 150.0          # How fast the rocket travels
@export var rotation_speed = 50.0   # How quickly the rocket turns towards its target
@export var damage = 30            # How much damage the rocket deals
@export var lifetime = 2.0         # How long the rocket exists before despawning (seconds)
@export var initial_move_duration = 0.3 # Duration (seconds) for initial broad movement before full homing

var target: Node2D = null          # The enemy the rocket is trying to hit
var initial_direction_vector = Vector2.ZERO # The broad direction given at spawn
var is_homing_active = false       # Flag to control homing behavior

func _ready():
	body_entered.connect(_on_body_entered)

	$Timer.wait_time = lifetime
	$Timer.one_shot = true
	$Timer.start()
	$Timer.timeout.connect(_on_lifetime_timeout)

	# Start a separate timer for the initial movement phase
	var initial_move_timer = Timer.new()
	add_child(initial_move_timer)
	initial_move_timer.wait_time = initial_move_duration
	initial_move_timer.one_shot = true
	initial_move_timer.timeout.connect(func(): is_homing_active = true) # Activate homing after duration
	initial_move_timer.start()

	# Immediately set the rocket's rotation to its initial_direction_vector
	#if initial_direction_vector != Vector2.ZERO:
	#	rotation = initial_direction_vector.angle()

	# Optional: Initial target search on ready if not already set by player
	if not is_instance_valid(target):
		target = find_closest_enemy()

func _physics_process(delta):
	# Find target only if needed
	if not is_instance_valid(target):
		target = find_closest_enemy()

	var current_target_angle: float # This variable will hold the angle we want the rocket to point towards

	if target and is_homing_active:
		# If homing is active and there's a target, aim towards the target
		var direction_to_target = (target.global_position - global_position).normalized()
		current_target_angle = direction_to_target.angle()
	else: # Homing is not active OR no target found
		# During the initial phase, or if no target ever appears, aim towards the initial_direction_vector
		if initial_direction_vector != Vector2.ZERO:
			current_target_angle = initial_direction_vector.angle()
		else:
			# Fallback: if no initial direction and no target, just keep current rotation
			current_target_angle = rotation

	# Smoothly rotate the rocket towards the determined target angle
	# This ensures the rocket's orientation (and thus its transform.x)
	# always aligns with its current intended direction.
	rotation = lerp_angle(rotation, current_target_angle, delta * rotation_speed)

	# Move the rocket forward in its current rotated direction
	# transform.x is a vector that points in the local X-axis direction of the node,
	# and its direction changes with the node's rotation.
	global_position += transform.x * speed * delta


func find_closest_enemy() -> Node2D:
	var closest_enemy: Node2D = null
	var min_distance_sq = INF

	var enemies = get_tree().get_nodes_in_group("Enemies")

	for enemy in enemies:
		if is_instance_valid(enemy) and not (enemy is Player):
			var distance_sq = global_position.distance_squared_to(enemy.global_position)
			if distance_sq < min_distance_sq:
				min_distance_sq = distance_sq
				closest_enemy = enemy
	return closest_enemy

# NEW: Function to set initial properties from the player
func set_initial_properties(initial_dir: Vector2, target_node: Node2D = null):
	initial_direction_vector = initial_dir.normalized()
	if target_node:
		target = target_node
	# Immediately set the rotation to the initial direction upon creation, for visual consistency.
	# This line ensures the rocket points the right way from the very first frame.
	# We add 90 degrees if your sprite is drawn "up" by default (e.g., if (0,-1) is its forward).
	# If your sprite's forward is naturally (1,0) (pointing right), then just use initial_direction_vector.angle().
	rotation = initial_direction_vector.angle()


func _on_body_entered(body: Node2D):
	if body is Player:
		return # Do nothing if the rocket collides with the player

	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("Rocket hit enemy and dealt ", damage, " damage.")
	elif body.is_in_group("Platforms"):
		print("Rocket hit a platform.")
	else:
		print("Rocket hit something else: ", body.name)

	queue_free()

func _on_lifetime_timeout():
	print("Rocket lifetime expired.")
	queue_free()
