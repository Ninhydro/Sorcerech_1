extends BaseState
class_name CyberState

#var grapple_line = player.grapple_line # Line2D node for drawing the grapple rope

# Grapple point stores the global position where the grapple latched on
var grapple_point: Vector2 = Vector2.ZERO
var is_grappling = false # Flag to indicate if grappling is active

var is_swinging = false # Flag to indicate if player is in swing mode (pendulum physics)
var original_rope_length = 0.0 # Stores the initial distance to the grapple point when swing starts
var initial_grapple_rope_length = 0.0 # Store the initial length when grapple starts

# Preload the Combat FSM for player combat logic
const CombatFSM = preload("res://scripts/player/combat/CombatFSM.gd")
var combat_fsm: CombatFSM
var attack_timer := 0.0 # Timer for managing attack duration (if any)

# === Grapple Mechanics Constants ===

const PULL_SPEED = 200.0         # Base speed at which player is pulled toward grapple point (when not swinging)
const PULL_ACCELERATION = 2000.0 # How quickly the player accelerates toward the grapple point

const MAX_GRAPPLE_DISTANCE = 70.0 # Max distance to detect and attach to a grapple target
const SWING_MODE_DISTANCE = 80.0 # When distance is less than this, switch from pull to swing mode
const SWING_ROPE_LENGTH = 70.0
# === Swing Mechanics (Pendulum Physics) ===

var angular_velocity = 0.0      # Speed of swing (angular), increases with input torque
var swing_velocity = Vector2.ZERO # Actual velocity used during swing motion, preserved on release

const SWING_FORCE = 800.0         # Force applied when moving left/right during grapple (useful for control while pulling)
const PENDULUM_GRAVITY = 1200.0 # Simulated gravity force used in swing calculations. Matches global GRAVITY.
var swing_angle = 0.0             # Radians, angle from the grapple point (relative to Y-axis)
const SWING_TORQUE = 10.0         # How much input affects angular velocity
const ANGULAR_DAMPING = 0.99    # Damping to prevent perpetual motion in the swing

# NEW CONSTANTS FOR SMOOTHER SWING
const MAX_ANGULAR_VELOCITY = 15.0 # Max speed the swing can achieve (radians/sec)
const ANGLE_EFFECTIVENESS_FACTOR = 1.5 # How much to boost input torque near the bottom of the swing
const ANGLE_EFFECTIVENESS_WINDOW = deg_to_rad(60) # Angle (total) around the bottom where input is most effective (e.g., +/- 30 degrees)


# === NEW GRAPPLE BOOST CONSTANTS ===
const HORIZONTAL_BOOST_FACTOR = 2.5  # Multiplier for horizontal velocity on release at peak
const VERTICAL_BOOST_ADDITION = -200.0 # Fixed upward impulse (-ve for upward)
const GRAPPLE_BOOST_ANGLE_WINDOW = deg_to_rad(45) # Angle window (e.g., +/- 45 degrees around PI/2 or -PI/2)

const GRAVITY = 1200.0          # Global gravity constant, used for consistency

# === Combat Constants ===

const ATTACK_DURATION := 0.2

var wall_jump_force = 300


# Constructor for the state
func _init(_player):
	player = _player
	combat_fsm = CombatFSM.new(player)
	add_child(combat_fsm)

# Called when entering this state
func enter():
	player.grapple_line = player.get_node("GrappleLine")
	Global.playerDamageAmount = 30
	print("Entered Cyber State")
	
	# Set player's grappling flag to false on state entry
	player.is_grappling_active = false 
	
	var collision = player.get_node_or_null("CollisionShape2D")
	if collision:
		collision.position = Vector2(1,-10)
		collision.scale = Vector2(1,3)
	
	print("DEBUG_CYBERSTATE_ENTER: Entered Cyber State.")
	#var sprite = player.get_node_or_null("Sprite2D")
	
	#if sprite and sprite.material and (sprite.material is ShaderMaterial):
	#	print("DEBUG_CYBERSTATE_ENTER: Shader Alpha Override: ", sprite.material.get_shader_parameter("camouflage_alpha_override"))
	#elif sprite:
	#	print("DEBUG_CYBERSTATE_ENTER: Sprite2D does not have a ShaderMaterial or material is null.")
	#else:
	#	print("DEBUG_CYBERSTATE_ENTER: Sprite2D node not found.")

# Called when exiting this state
func exit():
	print("DEBUG_CYBERSTATE_EXIT: Exited Cyber State.")
	release_grapple() # Ensure the grapple is released when leaving the CyberState
	
	player.skill_cooldown_timer.start(0.1)
	player.attack_cooldown_timer.start(0.1)

# Main physics update loop for the state
func physics_process(delta):
	# Removed wall jump logic if it's supposed to happen OUTSIDE grapple
	# If wall jump should release grapple:LedgeLeftON = true

	if player.is_on_wall() and Input.is_action_just_pressed("jump") and not is_grappling and (player.LedgeLeftON or player.LedgeRightON):
		print("wall jump")
		player.wall_jump_just_happened = true
		player.wall_jump_timer = player.WALL_JUMP_DURATION
		
		if player.facing_direction == 1:
			player.velocity.x += -wall_jump_force
			player.facing_direction = -1
			print("move to right, knock to left")
		elif player.facing_direction == -1:
			player.velocity.x += wall_jump_force
			player.facing_direction = 1
			print("move to left, knock to right")
		
		player.velocity.y = -300
		
	combat_fsm.physics_update(delta)

	if player.canon_enabled == true or player.telekinesis_enabled == true:
		player.velocity = Vector2.ZERO # Stop player movement if these abilities are active
	else:
		#player.scale = Vector2(1,1) # Reset player scale

		if Input.is_action_just_pressed("yes") and player.can_attack == true and Global.playerAlive and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause and player.not_busy:
			player.AreaAttack.monitoring = true
			print("Cyber attacking")

		if Input.is_action_just_pressed("no") and player.can_skill == true and Global.playerAlive and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause:
			perform_grapple()

	# Handle grapple movement if currently grappling - COMPLETELY override regular movement
	if is_grappling:
		handle_grapple_movement(delta)
	else:
		# Only process regular movement if not grappling
		# Add your regular movement code here if needed
		pass

	# Release grapple if "move_up" (jump) is pressed while grappling
	if (Input.is_action_just_pressed("move_up") or  Input.is_action_just_pressed("jump") )and is_grappling:
		release_grapple()

func handle_input(event):
	pass

# Initiates the grapple attempt
func perform_grapple():
	var space_state = player.get_world_2d().direct_space_state
	var closest_target: Node2D = null
	var closest_distance := MAX_GRAPPLE_DISTANCE

	var ray_origin = player.grapple_hand_point.global_position
	
	for target in player.get_tree().get_nodes_in_group("grapple_targets"):
		if not target.has_method("get_global_position"):
			continue

		var to_target = target.global_position - ray_origin
		var distance = to_target.length()

		if distance > MAX_GRAPPLE_DISTANCE:
			continue

		var query = PhysicsRayQueryParameters2D.create(ray_origin, target.global_position)
		query.exclude = [player]
		var result = space_state.intersect_ray(query)

		if result.is_empty() or result.collider == target:
			if distance < closest_distance:
				closest_target = target
				closest_distance = distance
		else:
			print("Blocked by: ", result.collider.name)

	if closest_target:
		grapple_point = closest_target.global_position
		is_grappling = true
		player.is_grappling_active = true # Inform player.gd that grappling is active
		player.still_animation = true # <--- ADD THIS LINE: Keep skill animation playing
		
		player.grapple_line.clear_points() # Clear any existing points
		player.grapple_line.add_point(player.grapple_hand_point.position) # Add point 0 (player's local origin)
		player.grapple_line.add_point(player.to_local(grapple_point)) # Add point 1 (grapple point in player's local space)
		
		# Store the initial rope length when the grapple begins
		initial_grapple_rope_length = (grapple_point - player.global_position).length()
		original_rope_length = initial_grapple_rope_length

		print("Grappling to ", grapple_point, " Rope length: ", initial_grapple_rope_length)
	else:
		print("No visible grapple targets found")
		is_grappling = false
		player.is_grappling_active = false # Reset if grapple fails
		player.still_animation = false # <--- ADD THIS LINE: Reset if grapple fails to start
		player.grapple_line.clear_points() # Clear the line if grapple is not successful

# Handles player movement during grappling (pulling or swinging)
func handle_grapple_movement(delta):
	if not is_grappling:
		return

	var to_grapple = grapple_point - player.global_position
	var distance = to_grapple.length()
	var direction = to_grapple.normalized()

	if distance < SWING_MODE_DISTANCE and not is_swinging:
		if player.velocity.length() < 300:
			enter_swing_mode(distance)

	if is_swinging:
		handle_swing_movement(delta) # This handles lateral movement during swing
	else:
		# PULL MODE: Simple direct pull toward grapple point
		var pull_direction = (grapple_point - player.global_position).normalized()
		player.velocity = pull_direction * PULL_SPEED
		
		# Add a small check to transition to swing mode when close
		if distance < 15.0:
			enter_swing_mode(distance)

	# Update the visual representation of the grapple rope
	player.grapple_line.set_point_position(0, player.grapple_hand_point.position)
	player.grapple_line.set_point_position(1, player.to_local(grapple_point))
	
# Enters the swinging (pendulum) mode
func enter_swing_mode(distance):
	is_swinging = true
	# original_rope_length is already set in perform_grapple, 
	# or can be explicitly set here to distance for consistency.
	#original_rope_length = distance 
	original_rope_length = SWING_ROPE_LENGTH
	
	var to_player = player.global_position - grapple_point
	swing_angle = atan2(to_player.x, to_player.y)
	angular_velocity = 0.0
	
	var initial_tangent = Vector2(-to_player.y, to_player.x).normalized()
	angular_velocity = player.velocity.dot(initial_tangent) / original_rope_length

# Handles player movement during swinging (pendulum physics)
func handle_swing_movement(delta):
	if grapple_point == null:
		return

	# --- Calculate force and angular momentum ---
	#var gravity_torque = -sin(swing_angle) * PENDULUM_GRAVITY / original_rope_length
	#angular_velocity += gravity_torque * delta
	
	var gravity_direction = Vector2.UP
	var to_player_vector = player.global_position - grapple_point
	var perpendicular = Vector2(-to_player_vector.y, to_player_vector.x).normalized()
	var gravity_torque = gravity_direction.dot(perpendicular) * PENDULUM_GRAVITY / original_rope_length
	angular_velocity += gravity_torque * delta

	# --- Input torque from player movement ---
	var input_dir = 0.0
	if Input.is_action_pressed("move_left"):
		input_dir = -1.0
		player.facing_direction = 1
	elif Input.is_action_pressed("move_right"):
		input_dir = 1.0
		player.facing_direction = -1

	var effective_torque = 0.0

	# Apply torque only if the input direction aligns with gaining speed or changing direction
	# Calculate tangential velocity direction to compare with input
	var current_tangential_direction = sign(angular_velocity) # -1 for left, 1 for right, 0 for still

	if input_dir != 0:
		# Angle factor: input is most effective near the bottom of the swing (swing_angle ~ 0 or PI)
		# A `cos` function works well here, peaking at 0 and PI, and 0 at PI/2 and -PI/2.
		# But careful with angle definition. Assuming swing_angle is 0 at the bottom.
		var angle_from_bottom = abs(fmod(swing_angle, PI)) # Distance from 0 or PI
		var angle_factor = 1.0 - (angle_from_bottom / (PI / 2.0)) # 1 at bottom, 0 at horizontal
		angle_factor = pow(clamp(angle_factor, 0.0, 1.0), 2.0) # Smooth curve, more effective near bottom
		
		# If the player is trying to accelerate in the same direction as the current swing,
		# or if they're trying to reverse direction.
		if sign(input_dir) == current_tangential_direction or current_tangential_direction == 0:
			effective_torque = SWING_TORQUE * angle_factor * input_dir
			
		elif sign(input_dir) != current_tangential_direction:
			# Apply more torque if trying to reverse direction, but less effective if already fast
			effective_torque = SWING_TORQUE * angle_factor * input_dir * (1.0 - abs(angular_velocity) / MAX_ANGULAR_VELOCITY)
			effective_torque = clamp(effective_torque, -SWING_TORQUE, SWING_TORQUE) # Clamp to base torque

	angular_velocity += effective_torque * delta

	# --- Clamp angular velocity to a maximum ---
	angular_velocity = clamp(angular_velocity, -MAX_ANGULAR_VELOCITY, MAX_ANGULAR_VELOCITY)

	# --- Apply damping to avoid infinite swing ---
	angular_velocity *= ANGULAR_DAMPING

	# --- Update swing angle ---
	swing_angle += angular_velocity * delta

	# --- Clamp angle within -PI to PI ---
	swing_angle = fmod(swing_angle + PI, TAU) - PI

	# --- Calculate desired position on the circle (pendulum arc) ---
	var offset = Vector2(
		sin(swing_angle), # X component from angle relative to Y-axis
		cos(swing_angle)  # Y component from angle relative to Y-axis
	) * original_rope_length

	var desired_position = grapple_point + offset # The theoretical position on the pendulum arc

	# --- Calculate the movement vector needed to reach the desired position ---
	var motion_to_desired = desired_position - player.global_position

	# --- Use move_and_collide to attempt to move to desired_position ---
	# This will stop the player at the collision point if a wall is hit.
	var collision = player.move_and_collide(motion_to_desired)

	if collision:
		print("Grapple Swing Collision Detected with: ", collision.get_collider().name)
		# When a collision occurs:
		# 1. Stop the angular swing.
		angular_velocity = 0.0
		# 2. Set player velocity to zero to prevent sliding/jitter from remaining forces.
		player.velocity = Vector2.ZERO
		# 3. The player's global_position is already at the collision point due to move_and_collide.
		# 4. Crucially, DO NOT change original_rope_length. The rope remains its original length
		#    but the player is simply blocked from moving further. This creates tension.
		
	else:
		# If no collision, player moved directly to desired_position by move_and_collide.
		# Now, re-enforce the original rope length precisely.
		var current_to_grapple = grapple_point - player.global_position
		var current_distance = current_to_grapple.length()

		# Snap player back to original_rope_length to counteract floating point errors
		if current_distance > 0.01 and abs(current_distance - original_rope_length) > 0.1:
			player.global_position = grapple_point + current_to_grapple.normalized() * original_rope_length
		elif current_distance <= 0.01:
			player.global_position = grapple_point # Avoid division by zero if too close


	# --- Store tangent velocity for post-release momentum ---
	# This should reflect the actual velocity of the player *before* being stopped by a wall.
	# If angular_velocity is 0 due to collision, swing_velocity will also be 0, which is correct.
	var tangent_direction = Vector2(cos(swing_angle), -sin(swing_angle))
	swing_velocity = tangent_direction * angular_velocity * original_rope_length

	# Set player.velocity for consistency; move_and_slide() will use this on release
	player.velocity = swing_velocity


# Releases the grapple
func release_grapple():
	if is_grappling:
		player.velocity = swing_velocity # Preserve the swing velocity

		# Apply boost only if player was swinging and is near horizontal extremes
		# Now, the boost only happens if angular_velocity was NOT zeroed by a wall collision.
		# If angular_velocity is 0, swing_velocity will be 0, so no boost is implicitly applied.
		if is_swinging: # The is_swinging check is enough, as swing_velocity will be zero if blocked.
			var boost_applied = false
			
			if abs(swing_angle - PI/2) < GRAPPLE_BOOST_ANGLE_WINDOW:
				player.velocity.x *= HORIZONTAL_BOOST_FACTOR
				player.velocity.y += VERTICAL_BOOST_ADDITION
				boost_applied = true
				print("DEBUG: Grapple released near right peak, applying boost.")
			
			elif abs(swing_angle - (-PI/2)) < GRAPPLE_BOOST_ANGLE_WINDOW:
				player.velocity.x *= HORIZONTAL_BOOST_FACTOR
				player.velocity.y += VERTICAL_BOOST_ADDITION
				boost_applied = true
				print("DEBUG: Grapple released near left peak, applying boost.")
			
			if not boost_applied:
				print("DEBUG: Grapple released, no peak boost applied.")

		is_grappling = false
		is_swinging = false
		player.is_grappling = false # Custom player flag (if used elsewhere)
		player.is_grappling_active = false # <-- Reset the flag for player.gd's gravity
		player.grapple_line.clear_points()
		player.still_animation = false # <--- ADD THIS LINE: Reset still_animation on release

		print("Grapple released. Final Player velocity:", player.velocity)
