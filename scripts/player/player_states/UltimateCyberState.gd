extends BaseState

class_name UltimateCyberState

var combat_fsm: CombatFSM

const CombatFSM = preload("res://scripts/player/combat/CombatFSM.gd")

var is_attacking := false
var attack_timer := 0.0
const ATTACK_DURATION := 0.2  # seconds

#@export var jump_force = 250.0   # Jump impulse force (vertical velocity for jump)
#var gravity  = 1000.0     # Gravity strength (pixels/sec^2)

# Variable jump properties
var is_jump_held := false
var jump_hold_time := 0.0
const MAX_JUMP_HOLD_TIME := 0.3  # Maximum time jump can be held for maximum height
const MIN_JUMP_FORCE := 200.0    # Minimum jump force (quick tap)
const MAX_JUMP_FORCE := 450.0    # Maximum jump force (full hold)
var jump_force_multiplier := 1.0 # Current jump multiplier

func _init(_player):
	player = _player
	combat_fsm = CombatFSM.new(player)
	add_child(combat_fsm)

func enter():
	Global.playerDamageAmount = 30
	print("Entered Ultimate Cyber State")
	
	var collision = player.get_node_or_null("CollisionShape2D")
	if collision:
		collision.position = Vector2(1,-10)
		collision.scale = Vector2(1,3)
	
	# Reset jump variables
	is_jump_held = false
	jump_hold_time = 0.0
	jump_force_multiplier = 1.0
	
	# e.g. change player color or animation
	

func exit():
	#reset time freeze
	player.jump_force = 250
	player.gravity = 1000
	#player.allow_time_freeze = false
	Engine.time_scale = 1
	Global.normal_time()
	Global.time_freeze = false
	
	player.skill_cooldown_timer.start(0.1)
	player.attack_cooldown_timer.start(0.1)

func physics_process(delta):
	combat_fsm.physics_update(delta)
	
	handle_variable_jump(delta)
	
	if player.canon_enabled == true or player.telekinesis_enabled == true:
		player.velocity = Vector2.ZERO
	else:
		player.jump_force = 450
		player.gravity = 1000
		#player.scale = Vector2(1.2,1.2)
		
		# --- Rocket shooting for "yes" action ---
		if Input.is_action_just_pressed("yes") and player.can_attack == true and Global.playerAlive and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause and player.not_busy:
			player.shoot_rocket() # Call the new function to shoot a rocket
			#player.can_attack = false # Apply attack cooldown
			# Use the attack_cooldown_timer's current wait_time, e.g., 1.0 from player.gd
			#player.attack_cooldown_timer.start(player.attack_cooldown_timer.wait_time)
			print("Ultimate Cyber shooting rocket!")
					
		if Input.is_action_just_pressed("no") and player.can_skill == true and Global.playerAlive and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause and player.not_busy:
			perform_time_freeze()
	

func handle_variable_jump(delta):
	# Check if jump button is just pressed
	if Input.is_action_just_pressed("jump") and player.is_on_floor() and not Global.is_dialog_open and not Global.attacking and not player.is_grabbing_ledge and not player.is_grappling_active:
		is_jump_held = true
		jump_hold_time = 0.0
		# Start with minimum jump force
		player.velocity.y = -MIN_JUMP_FORCE
		print("Jump started - minimum force applied")
	
	# Check if jump button is being held
	if is_jump_held and Input.is_action_pressed("jump"):
		jump_hold_time += delta
		
		# Calculate jump force multiplier based on hold time
		var hold_ratio = min(jump_hold_time / MAX_JUMP_HOLD_TIME, 1.0)
		jump_force_multiplier = lerp(1.0, MAX_JUMP_FORCE / MIN_JUMP_FORCE, hold_ratio)
		
		# Apply variable jump force (continuously while holding)
		if jump_hold_time <= MAX_JUMP_HOLD_TIME:
			player.velocity.y = -MIN_JUMP_FORCE * jump_force_multiplier
			print("Jump force: ", MIN_JUMP_FORCE * jump_force_multiplier, " (hold ratio: ", hold_ratio, ")")
	
	# Check if jump button is released
	if is_jump_held and Input.is_action_just_released("jump"):
		is_jump_held = false
		print("Jump released - final force: ", MIN_JUMP_FORCE * jump_force_multiplier)
	
	# Stop jump if maximum hold time reached
	if is_jump_held and jump_hold_time >= MAX_JUMP_HOLD_TIME:
		is_jump_held = false
		print("Maximum jump hold time reached")
		
func perform_time_freeze():
	# Slow down time
	#Engine.time_scale = 0.1  # (Engine.time_scale docs: lower values slow the game):contentReference[oaicite:8]{index=8}
	# After a timer, reset Engine.time_scale = 1.0
	#pass
	Global.time_freeze = true
	if Global.time_freeze == true:
		print("Time Frozen - enemies paused")
		Global.time_freeze = true
		Global.slow_time()
		Engine.time_scale = 0.8
		#get_tree().paused = !get_tree().paused
		#if player.animation_player:
		#	player.animation_player.speed_scale = 1.0
		# In a real game, you might set Engine.time_scale = 0 or pause enemy nodes.
	#else:
		await player.get_tree().create_timer(10.0, true, false, true).timeout
		print("Time Resumed - enemies active")
		Engine.time_scale = 1
		Global.normal_time()
		Global.time_freeze = false
		# * Global.global_time_scale
		#Global.time_freeze = !Global.time_freeze
		#get_tree().paused = !get_tree().paused
		#if player.animation_player:
		#	player.animation_player.speed_scale = 1.0
			
			# Reset time_scale or unpause enemies.
	


func handle_input(event):
	pass
