class_name Player
extends CharacterBody2D

# — Player constants and exported properties —
@export var move_speed = 300.0   # Walking speed in pixels/sec
@export var jump_force = 250.0   # Jump impulse force (vertical velocity for jump)
var gravity  = 1000.0     # Gravity strength (pixels/sec^2)

@export var allow_camouflage: bool = false
@export var allow_time_freeze: bool = false
@export var telekinesis_enabled : bool = false
@export var current_magic_spot: MagusSpot = null
@export var canon_enabled : bool = false # Flag to indicate if player is in cannon mode
@onready var telekinesis_controller = $TelekinesisController
@export var UI_telekinesis : bool = false

var is_in_cannon = false   # True when inside a cannon (before launch)
var is_aiming = false      # True when aiming the cannon
var is_launched = false    # True when launched from a cannon and in flight
var launch_direction = Vector2.ZERO # Direction of cannon launch
var launch_speed = 500.0 # Adjust as needed for cannon launch velocity
var aim_angle_deg = -90 # Default straight up for cannon aim

var facing_direction := 1 # 1 for right, -1 for left

var states = {}
var current_state: BaseState = null
var state_order = [ "UltimateMagus", "Magus","Normal", "Cyber", "UltimateCyber"]
#0=ultmagus,1=magus,2=normal,3=cyber,4=ultcyber
var current_state_index = 2
var unlocked_states: Array[String] = ["Normal"]  # Start with only Normal state unlocked
# Maintain a separate dictionary to track unlocked status
var unlocked_flags = {
	"UltimateMagus": false,
	"Magus": false,
	"Normal": true,
	"Cyber": false,
	"UltimateCyber": false
}

var combat_fsm

@onready var anim_tree: AnimationTree = $AnimationTree
@onready var anim_state: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var can_switch_form := true
var can_attack := true
var can_skill := true
var still_animation := false

@onready var form_cooldown_timer: Timer = $FormCooldownTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var skill_cooldown_timer: Timer = $SkillCooldownTimer
@onready var sprite = $Sprite2D
@onready var NormalColl = $CollisionShape2D

@onready var AreaAttack = $AttackArea
@onready var AreaAttackColl = $AttackArea/CollisionShape2D
@export var health = 100
@export var health_max = 100
@export var health_min = 0

@export var money = 0

@onready var Hitbox = $Hitbox
var can_take_damage: bool
var dead: bool
var player_hit: bool = false

var knockback_velocity := Vector2.ZERO
var knockback_duration := 0.2
var knockback_timer := 0.0

var is_grappling := false
var grapple_joint := Vector2.ZERO
var grapple_length := 0.0

var is_grappling_active := false # Flag to tell player.gd when grapple is active

@onready var grapple_hand_point: Marker2D = $GrappleHandPoint
@onready var grapple_line: Line2D = $GrappleLine

const FLOOR_NORMAL: Vector2 = Vector2(0, -1) # Standard for side-scrolling 2D

var wall_jump_just_happened = false
var wall_jump_timer := 0.5
const WALL_JUMP_DURATION := 0.3

@export var fireball_scene: PackedScene =  preload("res://scenes/objects/Fireball.tscn") # Will hold the preloaded Fireball.tscn
@onready var fireball_spawn_point = $FireballSpawnPoint

@export var rocket_scene: PackedScene = preload("res://scenes/objects/Rocket.tscn") # Will hold the preloaded Rocket.tscn

@onready var combo_timer = $ComboTimer
var combo_timer_flag = true

var bounced_protection_timer := 0.0
const BOUNCE_GRACE := 0.2 # How long to ignore new bounce collisions after a bounce

var inventory = []

# --- NEW FLAG FOR DEFERRED POSITION APPLICATION ---
var _should_apply_loaded_position: bool = false 
# --- END NEW FLAG ---

signal health_changed(health, health_max)
signal form_changed(new_form_name)

@onready var LedgeRightLower = $Raycast/LedgeGrab/LedgeRightLower
@onready var LedgeRightUpper = $Raycast/LedgeGrab/LedgeRightUpper
@onready var LedgeLeftLower = $Raycast/LedgeGrab/LedgeLeftLower
@onready var LedgeLeftUpper = $Raycast/LedgeGrab/LedgeLeftUpper

var LedgeLeftON = false
var LedgeRightON = false
var is_grabbing_ledge = false
var LedgePosition: Vector2 = Vector2.ZERO # The position where the player should hang
var LedgeDirection: Vector2 = Vector2.ZERO # The direction of the ledge (+1 for right, -1 for left)

@onready var camera = $CameraPivot/Camera2D

#@export var CollisionMap: TileMapLayer
var cannon_form_switched: bool = false
var previous_form: String = ""

# Method to disable player input
func disable_input():
	print("Player: Input disabled.")
	set_physics_process(false) # Stop _physics_process from running normal movement
	set_process(false) # Stop _process if you have non-physics input in it
	# You might also set Global.is_cutscene_active = true from the Cutscene Area2D directly,
	# and have your player's input check this global variable.

# Method to enable player input
func enable_input():
	print("Player: Input enabled.")
	set_process_input(true)
	set_physics_process(true)
	set_process(true)


func _ready():
	enable_input()
	Global.playerBody = self
	Global.playerAlive = true
	print(Global.playerBody)
	dead = false
	can_take_damage = true
	health_changed.emit(health, health_max) # Initial emit

	
	AreaAttack.monitoring = false
	AreaAttackColl.disabled = true
	
	combat_fsm = CombatFSM.new(self)
	add_child(combat_fsm)
	
	anim_tree.active = true
	sprite.modulate = Color(1,1,1,1)
	
	states["Normal"] = NormalState.new(self)
	states["Magus"] = MagusState.new(self)
	states["Cyber"] = CyberState.new(self)
	states["UltimateMagus"] = UltimateMagusState.new(self)
	states["UltimateCyber"] = UltimateCyberState.new(self)
	
	set_collision_mask_value(2, true)
	
	unlock_state("Magus")
	unlock_state("UltimateMagus")
	unlock_state("Cyber")
	unlock_state("UltimateCyber")
	
	# --- MODIFIED _ready() LOGIC FOR SAVE/LOAD ---
	# Check if there's loaded data from Global
	if Global.current_loaded_player_data != null and not Global.current_loaded_player_data.is_empty():
		print("Player._ready: Loaded data detected. Setting flag for deferred application.")
		# Set the flag to apply position in _physics_process
		_should_apply_loaded_position = true
		# Don't call apply_load_data here. It will be called in _physics_process
		
		# Immediately apply non-position data here if it's safe and needed before physics_process
		# Example: Health, forms, inventory can be set now.
		health = Global.current_loaded_player_data.get("health", 100)
		var loaded_unlocked_states = Global.current_loaded_player_data.get("unlocked_states", ["Normal"])
		unlocked_flags = {
			"UltimateMagus": false, "Magus": false, "Normal": false,
			"Cyber": false, "UltimateCyber": false
		}
		unlocked_states.clear()
		for state_name in loaded_unlocked_states:
			unlock_state(state_name)
	
		if not unlocked_flags["Normal"]:
			unlock_state("Normal")
		
		
		inventory = Global.current_loaded_player_data.get("inventory", [])
		#money = Global.current_loaded_player_data.get("money", 0)

		var loaded_state_name = Global.current_loaded_player_data.get("current_state_name", "Normal")
		switch_state(loaded_state_name)
		current_state_index = unlocked_states.find(loaded_state_name)
		if current_state_index == -1: current_state_index = 0
		Global.selected_form_index = Global.current_loaded_player_data.get("selected_form_index", current_state_index)
		combat_fsm.change_state(IdleState.new(self)) # Reset FSM state

	else:
		# Original logic for initial setup if no save data is loaded (New Game)
		print("Player._ready: No loaded data. Setting initial default state.")
		current_state_index = unlocked_states.find("Normal")
		if current_state_index == -1:
			current_state_index = 0
		Global.selected_form_index = current_state_index
		
		switch_state("Normal") # Ensure Normal state is active for new game
		combat_fsm.change_state(IdleState.new(self))
	
	

	#switch_state("Normal")
	# --- END MODIFIED _ready() LOGIC ---

# This is your main physics processing loop
func _physics_process(delta):
	# --- APPLY LOADED POSITION (ONE-TIME) ---
	# Assign self to Global.playerBody here ensures it's always up-to-date
	# This should ideally be done once at load/spawn, not every physics frame.
	# But if you move Global.playerBody assignment to _ready,
	# make sure it happens *before* any other scripts try to access it.
	#print(velocity)
	
	Global.playerBody = self
	Dialogic.VAR.set_variable("player_current_form", get_current_form_id())

	Global.set_player_form(get_current_form_id())
	Global.current_form = get_current_form_id()
	

	#print(global_position)
	#camera_pivot.position = camera_pivot.position.lerp(Vector2.ZERO, 0.1) # Adjust speed

	if _should_apply_loaded_position:
		print("Player._physics_process: Applying loaded position (one-time).")
		global_position = Vector2(Global.current_loaded_player_data.get("position_x"), Global.current_loaded_player_data.get("position_y"))
		velocity = Vector2.ZERO # Crucial to prevent residual movement after loading
		_should_apply_loaded_position = false # Set flag to false so it only runs once
		Global.current_loaded_player_data = {} # Clear the temporary data from Global after use
		print("Player.gd: Position set to loaded: ", global_position)
	# --- END APPLY LOADED POSITION ---

	# --- CUTSCENE OVERRIDE ---
	# If a cutscene is active, player's direct input is ignored.
	# Movement and animations are handled by external calls (AnimationPlayer methods).
	if Global.is_cutscene_active:
		velocity = Vector2.ZERO # Ensure no residual input-based movement
		# Do NOT return here. We still need gravity, knockback, and move_and_slide().
		# External calls will set velocity or global_position directly.
	# --- END CUTSCENE OVERRIDE ---

	# Your existing FSM updates
	if combat_fsm:
		combat_fsm.update_physics(delta)
	if current_state:
		current_state.physics_process(delta)

	Global.playerDamageZone = AreaAttack # Assuming AreaAttack is your damage area node
	Global.playerHitbox = Hitbox # Assuming Hitbox is your hitbox node

	# Telekinesis UI state management
	if telekinesis_controller and telekinesis_controller.is_ui_open:
		UI_telekinesis = true
	else:
		UI_telekinesis = false
	#print(wall_jump_just_happened)
	# --- Player Input and Movement (Only if NOT in a cutscene and NOT dead) ---
	if not dead and not Global.is_cutscene_active: # <-- IMPORTANT: Add Global.is_cutscene_active check here
		var input_dir = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

		# Facing direction based on input
		if Input.is_action_pressed("move_right") and not wall_jump_just_happened and not Global.is_dialog_open:
			facing_direction = 1
		elif Input.is_action_pressed("move_left") and not wall_jump_just_happened and not Global.is_dialog_open:
			facing_direction = -1

		# Wall jump timer decrement
		if wall_jump_timer > 0:
			wall_jump_timer -= delta
			if wall_jump_timer <= 0:
				wall_jump_just_happened = false

		# Knockback (applied even during cutscene if set externally)
		if knockback_timer > 0:
			velocity = knockback_velocity
			knockback_timer -= delta
		# Special states where player input is overridden
		elif canon_enabled and not is_launched:
				
			scale = Vector2(0.5, 0.5)
			velocity = Vector2.ZERO
			
			# Only switch form once when entering cannon mode
			if get_current_form_id() != "Normal":
		# Find the index of "Normal" in unlocked_states
				var normal_index = unlocked_states.find("Normal")
				if normal_index != -1:  # Make sure Normal form is actually unlocked
					current_state_index = normal_index
					switch_state("Normal")
					combat_fsm.change_state(IdleState.new(self))
					# Note: We don't set can_switch_form = false or start timer for cannon mode
					print("Cannon mode: Switched to Normal form")
			
			# Prevent form switching while in cannon mode
			# This ensures the player stays in Normal form during cannon mode
			can_switch_form = false
			
		elif telekinesis_enabled:
			velocity = Vector2.ZERO
		elif Global.dashing:
		# Apply gravity during dash
			velocity.y += gravity * delta
			
			# Move with the dash velocity
			move_and_slide()
			
			# Gradually reduce dash velocity
			velocity.x = lerp(velocity.x, 0.0, delta * 5)
		
		# End dash when velocity becomes small
			if abs(velocity.x) < 50:
				Global.dashing = false

		else: # Normal movement and input processing
			if facing_direction == -1: # No need for !dead check here, already done above
				sprite.flip_h = true
				AreaAttackColl.position = Vector2(-16,-8.75)
				grapple_hand_point.position = Vector2(-abs(grapple_hand_point.position.x), grapple_hand_point.position.y)

			else:
				sprite.flip_h = false
				AreaAttackColl.position = Vector2(16,-8.75)
				grapple_hand_point.position = Vector2(abs(grapple_hand_point.position.x), grapple_hand_point.position.y)


			# Apply horizontal movement based on input (only if not wall-jumping, dialog, or attacking)
			if not wall_jump_just_happened and not Global.is_dialog_open and not Global.attacking and not is_grabbing_ledge:
				#print("movinggggggggg")
				velocity.x = input_dir * move_speed # Use 'speed' here for normal movement
			elif wall_jump_just_happened: #or current_form = cyber form,
				pass
			elif is_grabbing_ledge:
				velocity.x = 0
			else:
				velocity.x = 0 # Stop horizontal movement if dialog is open or attacking

			# Jumping (only if on floor, no dialog, no attacking)
			if is_on_floor() and Input.is_action_just_pressed("jump") and not Global.is_dialog_open and not Global.attacking and not is_grabbing_ledge:
				velocity.y = -jump_force
			elif is_grabbing_ledge:
				velocity.y += gravity+delta
		
		if is_launched and cannon_form_switched:
	# Restore previous form after launch
			if previous_form != "" and previous_form != "Normal":
				switch_state(previous_form)
				Global.selected_form_index = unlocked_states.find(previous_form)
			cannon_form_switched = false
			previous_form = ""
		
		if not canon_enabled and not can_switch_form:
			can_switch_form = true
			print("Exited cannon mode: Form switching re-enabled")
	
		# Attack input (only if not dialog open)
		if Input.is_action_just_pressed("yes") and can_attack and not Global.is_dialog_open:
			var current_form = get_current_form_id()
			var attack_started = false
			if current_form == "Cyber":
				attack_cooldown_timer.start(2.0)
				attack_started = true
			elif current_form == "Magus":
				attack_cooldown_timer.start(2.0)
				attack_started = true
			elif current_form == "UltimateCyber":
				attack_cooldown_timer.start(5.0)
				attack_started = true
			elif current_form == "UltimateMagus" and combo_timer_flag:
				combo_timer_flag = false
				combo_timer.start(0.5)
				attack_started = true
			
			if attack_started:
				can_attack = false
				# Add your attack logic here (e.g., combat_fsm.change_state(AttackState.new(self)))

		# Skill input (only if not dialog open)
		if Input.is_action_just_pressed("no") and can_skill and not Global.is_dialog_open:
			var current_form = get_current_form_id()
			var skill_started = false
			if current_form == "UltimateMagus": # Check for UltimateMagus first
				skill_cooldown_timer.start(2.0)
				skill_started = true
			elif current_form == "Cyber":
				skill_cooldown_timer.start(0.1)
				skill_started = true
			elif current_form == "Magus":
				skill_cooldown_timer.start(10.0)
				skill_started = true
			elif current_form == "UltimateCyber": # Assuming this is different from "UltimateCyber"
				skill_cooldown_timer.start(15.0)
				skill_started = true
			
			if skill_started:
				can_skill = false
				# Add your skill logic here (e.g., combat_fsm.change_state(SkillState.new(self)))

		check_hitbox() # Call your hitbox update logic

	# --- Dead state ---
	if dead:
		velocity = Vector2.ZERO # Stop all movement if dead

	# --- CANNON AIMING AND LAUNCHING LOGIC (Can override cutscene if desired, or add Global.is_cutscene_active here too) ---
	# For simplicity, assuming cannon can still be controlled during a cutscene if desired.
	# If cutscene should disable cannon input, add 'and not Global.is_cutscene_active' to these Input checks.
	if is_aiming:
		if Input.is_action_pressed("move_left"):
			aim_angle_deg = clamp(aim_angle_deg - 1, -170, -10) # restrict angle
		elif Input.is_action_pressed("move_right"):
			aim_angle_deg = clamp(aim_angle_deg + 1, -170, -10)
		update_aim_ui(aim_angle_deg)

	if is_in_cannon and is_aiming and Input.is_action_just_pressed("yes"):
		print("FIRE!")
		launch_direction = Vector2.RIGHT.rotated(deg_to_rad(aim_angle_deg)) # Calculate launch direction from aim angle
		is_aiming = false
		is_launched = true # Player is now launched
		is_in_cannon = false # No longer in the cannon
		show_aim_ui(false)
		#animation_player.play("flying") # Play player's own flying animation
		
	if is_launched:
		# Apply the current launch velocity
		velocity = launch_direction * launch_speed

		var bounced_this_frame = false # Flag to track if a bounce occurred this physics frame

		# Decrement the bounce protection timer
		if bounced_protection_timer > 0:
			bounced_protection_timer -= delta
			if bounced_protection_timer < 0:
				bounced_protection_timer = 0 # Ensure it doesn't go negative

		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()

			if collider and collider.has_method("get_bounce_data"):
				var bounce_data = collider.get_bounce_data()
				var bounce_normal = bounce_data.normal
				var bounce_power = bounce_data.power

				if bounce_normal.length() > 0.01:
					bounce_normal = bounce_normal.normalized()
					launch_direction = velocity.bounce(bounce_normal).normalized()
					velocity = launch_direction * launch_speed * bounce_power
					print("BOUNCED! New direction: ", launch_direction, " New velocity: ", velocity)
					bounced_this_frame = true
					bounced_recently()
					break
				else:
					print("Invalid bounce normal: ", bounce_normal)

		# Apply gravity if launched and not on floor (for ballistic trajectory)
		if not is_on_floor():
			velocity.y += gravity * delta

		if (is_on_floor() or is_on_ceiling() or is_on_wall()) and bounced_protection_timer <= 0:
			is_launched = false
			#velocity = Vector2.ZERO # Stop movement
			canon_enabled = false # Exit cannon mode
			scale = Vector2(1,1)
			set_physics_process(true)
			set_process(true)
			can_switch_form = true
			can_attack = true
			can_skill = true
			print("Player stopped on a non-bounce surface or came to rest.")
	else:
		# This else block handles normal gravity application when not launched, not in cannon, not telekinesis
		if not is_on_floor() and not is_in_cannon and not telekinesis_enabled and not Global.is_cutscene_active: # <-- Add cutscene check
			velocity.y += gravity * delta

	# IMPORTANT: Only one move_and_slide() call per _physics_process frame.
	# This should be at the very end of _physics_process after all velocity calculations.
	handle_ledge_grab()
	move_and_slide()

	# --- FORM ROTATION (Only if NOT in a cutscene) ---
	if not Global.is_cutscene_active: # <-- IMPORTANT: Add Global.is_cutscene_active check here
		if Input.is_action_just_pressed("form_next"):
			Global.selected_form_index = (Global.selected_form_index + 1) % unlocked_states.size()
			print("Selected form: " + unlocked_states[Global.selected_form_index])

		if Input.is_action_just_pressed("form_prev"):
			Global.selected_form_index = (Global.selected_form_index - 1 + unlocked_states.size()) % unlocked_states.size()
			print("Selected form: " + unlocked_states[Global.selected_form_index])

		if Input.is_action_just_pressed("form_apply") and not dead and not Global.is_dialog_open:
			if not canon_enabled:
				if Global.selected_form_index != current_state_index:
					current_state_index = Global.selected_form_index
					switch_state(unlocked_states[current_state_index])
					combat_fsm.change_state(IdleState.new(self))
					can_switch_form = false
					form_cooldown_timer.start(3)

	
func get_current_form_id() -> String:
	if current_state_index >= 0 and current_state_index < unlocked_states.size():
		return unlocked_states[current_state_index]
	else:
		return "Normal"

func _input(event):
	if current_state:
		current_state.handle_input(event)
		
func switch_state(state_name: String) -> void:
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter()
	
	#anim_state.travel(state_name.to_lower() + "_idle") 
	
	form_changed.emit(state_name) # Emit signal after form changes

	Dialogic.VAR.set_variable("player_current_form", state_name)
	print("Player.gd: Switched to form: ", state_name, ". Dialogic variable updated.")



func unlock_state(state_name: String) -> void:
	if unlocked_flags.has(state_name):
		unlocked_flags[state_name] = true
		unlocked_states = []
		for state in state_order:
			if unlocked_flags[state]:
				unlocked_states.append(state)
		
func lock_state(state_name: String) -> void:
	if unlocked_states.has(state_name) and state_name != "Normal":
		unlocked_states.erase(state_name)
		print("Locked state:" + state_name)
		
func enter_cannon():
	is_in_cannon = true
	is_aiming = true
	velocity = Vector2.ZERO # Stop player movement when entering cannon
	show_aim_ui(true)
	cannon_form_switched = false  # Reset flag when entering cannon
	print("Entered cannon and aiming.")
	# Optionally disable animations or switch to a "cannon idle" sprite
	
func show_aim_ui(visible: bool):
	# Ensure you have a Node2D named "AimUI" as a child of your player
	# This node should represent your aiming indicator.
	if has_node("AimUI"):
		$AimUI.visible = visible

func update_aim_ui(angle):
	# Update the rotation of your AimUI node
	if has_node("AimUI"):
		$AimUI.rotation_degrees = angle
	
func get_nearby_telekinesis_objects() -> Array[TelekinesisObject]:
	var results: Array[TelekinesisObject] = []
	var radius = 150

	var all = get_tree().get_nodes_in_group("TelekinesisObject")
	print("Found in group:" + str(all.size()))

	for obj in all:
		print("Checking:" + obj.name)
		var dist = obj.global_position.distance_to(global_position)
		print("Distance to player:" + str(dist))
		if dist < radius:
			results.append(obj)

	print("Final results:" + str(results))
	return results
	
func _on_form_cooldown_timer_timeout():
	can_switch_form = true

func _on_attack_cooldown_timer_timeout():
	can_attack = true
	combo_timer_flag = true
	AreaAttack.monitoring = false

func _on_skill_cooldown_timer_timeout():
	can_skill = true
	print("can skill again")

func _on_animation_tree_animation_finished(anim_name):
	still_animation = false
	print("animation end")

	
func _on_animation_player_animation_finished(anim_name):
	#still_animation = false
	#print("animation end")
	pass

func check_hitbox():
	var hitbox_areas = $Hitbox.get_overlapping_areas()
	var damage: int = 0 # Initialize damage to 0
	if hitbox_areas:
		var hitbox = hitbox_areas.front()
		if hitbox.get_parent() is EnemyA:
			damage = Global.enemyADamageAmount
		
	if can_take_damage:
		if Global.enemyAdealing == true:
			take_damage(damage)
			
func take_damage(damage):
	if damage != 0:
		apply_knockback(Global.enemyAknockback)
		player_hit = true
		if health > 0:
			health -= damage
			print("player health" + str(health))
			if health <= 0:
				health = 0
				dead = true
				Global.playerAlive = false
				print("PLAYER DEAD")
				load_game_over_scene()
			take_damage_cooldown(1.0)
		health_changed.emit(health, health_max) # Emit signal after health changes
		await get_tree().create_timer(0.5).timeout
		player_hit = false
			
func take_damage_cooldown(time):
	print("cooldown")
	can_take_damage = false
	await get_tree().create_timer(time).timeout
	can_take_damage = true

func load_game_over_scene():
	# Preload the game over scene for efficiency
	var game_over_scene_res = preload("res://scenes/ui/game_over_ui.tscn") # Adjust path if different
	
	# Create an instance of the game over scene
	var game_over_instance = game_over_scene_res.instantiate()
	
	# Add it to the current scene's root (Viewport)
	get_tree().current_scene.add_child(game_over_instance)
	
	# Optionally, you might want to disable player input/physics completely
	# after loading the game over scene, as the game over scene handles pausing.
	# For example, by setting Global.playerAlive to false your _physics_process
	# already handles stopping movement. You could also hide the player character.
	# visible = false 
	
func apply_knockback(vector: Vector2):
	knockback_velocity = vector
	knockback_timer = knockback_duration
	
func shoot_fireball():
	if not fireball_scene:
		print("ERROR: Fireball scene not assigned in Player.gd's Inspector!")
		return

	var fireball_instance = fireball_scene.instantiate()
	get_tree().current_scene.add_child(fireball_instance)

	var fb_direction = Vector2(facing_direction, 0)

	var spawn_offset_x = fireball_spawn_point.position.x * facing_direction
	var spawn_offset_y = fireball_spawn_point.position.y

	fireball_instance.global_position = global_position + Vector2(spawn_offset_x, spawn_offset_y)
	fireball_instance.set_direction(fb_direction)

	print("Player in Magus mode shot a fireball!")

func shoot_rocket():
	if not rocket_scene:
		print("ERROR: Rocket scene not assigned in Player.gd's Inspector!")
		return

	var target_enemy = find_closest_enemy_for_rockets()

	var base_spawn_offset_x = fireball_spawn_point.position.x * facing_direction
	var base_spawn_offset_y = fireball_spawn_point.position.y
	var base_spawn_position = global_position + Vector2(base_spawn_offset_x, base_spawn_offset_y)

	var rocket1 = rocket_scene.instantiate()
	get_tree().current_scene.add_child(rocket1)
	rocket1.global_position = base_spawn_position + Vector2(0, -5)
	rocket1.set_initial_properties(Vector2(-0.2, -0.1).normalized(), target_enemy)

	var rocket2 = rocket_scene.instantiate()
	get_tree().current_scene.add_child(rocket2)
	rocket2.global_position = base_spawn_position + Vector2(0, 5)
	rocket2.set_initial_properties(Vector2(0.2, -0.1).normalized(), target_enemy)

	print("Player in Ultimate Cyber mode shot two homing rockets!")

func find_closest_enemy_for_rockets() -> Node2D:
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

func _on_combo_timer_timeout():
	can_attack = false
	attack_cooldown_timer.start(2.0)
	print("combo,timer attack start")

#var next_ledge_position
func handle_ledge_grab():
	# Only check for ledges when in the air and not currently grabbing one
	var current_form = get_current_form_id()
	
	if LedgeLeftLower.is_colliding():
		LedgeLeftON = true
	else:
		LedgeLeftON = false
	if LedgeRightLower.is_colliding():
		LedgeRightON = true
	else:
		LedgeRightON = false
	if not is_on_floor() and not is_grabbing_ledge and current_form != "Normal" and not is_grappling_active and not Global.dashing and not Global.teleporting and not is_launched:
		# Check for a ledge on the right side
		if LedgeRightLower.is_colliding() and not LedgeRightUpper.is_colliding():
			is_grabbing_ledge = true
			LedgeDirection = Vector2.RIGHT
			# Calculate the grab position relative to the lower raycast's collision point
			var collision_point = LedgeRightLower.get_collision_point()
			# Snap the player's position to hang on the ledge
			LedgePosition = Vector2(collision_point.x +6, collision_point.y - 14)
			print("Player grabbed a ledge on the right!")
			return true
			#NormalColl.disabled = true
		# Check for a ledge on the left side
		elif LedgeLeftLower.is_colliding() and not LedgeLeftUpper.is_colliding():
			is_grabbing_ledge = true
			LedgeDirection = Vector2.LEFT
			var collision_point = LedgeLeftLower.get_collision_point()
			LedgePosition = Vector2(collision_point.x -6 , collision_point.y - 14)
			print("Player grabbed a ledge on the left!")
			#NormalColl.disabled = true
			return true
		return false	
	# If the player is grabbing a ledge, handle inputs for climbing or dropping
	if is_grabbing_ledge and (current_form != "Normal"):
		#velocity.x = 0# Stop all movement
		#next_ledge_position = LedgePosition
		camera.position_smoothing_enabled = true
		global_position = LedgePosition # Snap to the hanging position
		#velocity = Vector2.ZERO
		#NormalColl.disabled = true
		#global_position = global_position.lerp(LedgePosition, 0.5) # Adjust the interpolation speed (0.2 is a good starting point)


		
		
		# Return true to signal that no further movement logic should be processed
		return true

	return false # Return false if not grabbing a ledge
	


func add_item_to_inventory(item_id: String):
	if not inventory.has(item_id):
		inventory.append(item_id)
		print("Added '" + item_id + "' to inventory. Current inventory: " + str(inventory))
	else:
		print("Item '" + item_id + "' already in inventory.")

func has_item_in_inventory(item_id: String) -> bool:
	return inventory.has(item_id)

func remove_item_from_inventory(item_id: String):
	if inventory.has(item_id):
		inventory.erase(item_id)
		print("Removed '" + item_id + "' from inventory. Current inventory: " + str(inventory))
		return true
	print("Item '" + item_id + "' not found in inventory.")
	return false
	
#No mana, use puzzles/special enemy to overcome overpower character

func get_save_data() -> Dictionary:
	var player_data = {
		"position_x": global_position.x,
		"position_y": global_position.y,
		"health": health,
		"current_state_name": get_current_form_id(),
		"unlocked_states": unlocked_states,
		"selected_form_index": Global.selected_form_index,
		"inventory": inventory # Directly save inventory
		
	}
	return player_data

#Not used currently
func apply_load_data(data: Dictionary):
	# This function is now ONLY for applying data AFTER the deferred position.
	# Position is applied directly in _physics_process on the first frame.
	print("Player.apply_load_data: Function called to apply data (non-positional).")
	
	# health, unlocked_states, current_state, inventory, money
	# These are now set in _ready or will be updated from global data

	print("Player loaded health: " + str(health)) # Health should already be set in _ready()

	# Unlocked states are set in _ready(), but ensure the `unlocked_states` array is correct
	# based on the `unlocked_flags` after the initial setup.
	unlocked_states.clear()
	for state in state_order:
		if unlocked_flags[state]:
			unlocked_states.append(state)
	print("Player loaded unlocked states: " + str(unlocked_states))

	# current_state_index and Global.selected_form_index are set in _ready()
	# The switch_state should have already happened in _ready() too
	print("Player loaded form: " + get_current_form_id()) # Use get_current_form_id as state is set in _ready

	# No need to await physics_frame here, as position is handled in _physics_process
	# velocity = Vector2.ZERO is handled in _physics_process after position is applied.
	
	# Re-enable input and visibility
	visible = true
	# --- REMOVED NON-EXISTENT FUNCTION CALLS ---
	# Your input logic is already handled in _physics_process based on Global.is_dialog_open.
	# Ensure Global.is_dialog_open is false when no dialog is present.
	set_physics_process(true) # Ensure physics processing is enabled
	set_process(true) # Ensure regular processing is enabled
	# --- END REMOVED ---



func bounced_recently():
	bounced_protection_timer = BOUNCE_GRACE
	
	
# This function will be called by the AnimationPlayer to make the player move
func move_during_cutscene(target_position: Vector2, duration: float):
	print("Player: move_during_cutscene called. Target: ", target_position, ", Duration: ", duration)
	# Use a Tween for smooth movement during a cutscene
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_position, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Connect to the tween's finished signal if you need to do something after this specific move
	# tween.finished.connect(Callable(self, "_on_cutscene_move_finished"))

# This function could be called to play an animation (e.g., 'walk', 'run', 'idle')
func play_player_animation(anim_name: String):
	if $AnimationPlayer and $AnimationPlayer.has_animation(anim_name):
		$AnimationPlayer.play(anim_name)
		print("Player: Playing animation: ", anim_name)
	else:
		printerr("Player: AnimationPlayer not found or animation '", anim_name, "' does not exist!")

# This function could be called to make the player face a certain direction
func set_player_direction(direction_vector: Vector2):
	# Assuming your player's sprite is flipped based on direction
	if direction_vector.x < 0:
		$Sprite2D.flip_h = true
		AreaAttackColl.position = Vector2(16,-8.75)
	elif direction_vector.x > 0:
		$Sprite2D.flip_h = false
		AreaAttackColl.position = Vector2(-16,-8.75)
	print("Player: Facing direction: ", direction_vector)

# NEW: Call this from your Cutscene Animation (Call Method Track via Test_dialog proxy)
# to make the player move to a specific global position using a Tween
func move_player_to_position(target_pos: Vector2, duration: float, ease_type: Tween.EaseType = Tween.EASE_IN_OUT, trans_type: Tween.TransitionType = Tween.TRANS_SINE):
	if not is_instance_valid(self): return # Safety check
	if not Global.is_cutscene_active:
		printerr("Player: Attempted cutscene movement but Global.is_cutscene_active is false!")
		return

	print("Player: Moving to ", target_pos, " over ", duration, " seconds.")
	var tween = create_tween()
	# NO EXPLICIT CASTING HERE. The parameters 'ease_type' and 'trans_type' are already
	# the correct enum types because of the type hints in the function signature,
	# assuming the values passed into this function were valid integers that Godot converted.
	tween.tween_property(self, "global_position", target_pos, duration)\
		.set_ease(ease_type).set_trans(trans_type)
  
	# Connect to a signal if you need to know when this specific move finishes
	# tween.finished.connect(Callable(self, "_on_cutscene_move_finished_specific"))

# NEW: Call this from your Cutscene Animation (Call Method Track via Test_dialog proxy)
# to set a continuous velocity for a duration (e.g., walking, running)
func set_player_cutscene_velocity(direction_vector: Vector2, speed_multiplier: float = 1.0):
	if not is_instance_valid(self): return
	if not Global.is_cutscene_active:
		printerr("Player: Attempted cutscene velocity but Global.is_cutscene_active is false!")
		return
	
	velocity = direction_vector.normalized() * (move_speed * speed_multiplier) # Use player's base speed
	print("Player: Setting cutscene velocity to: ", velocity)
	
	# Update visual direction if your sprite needs it
	if direction_vector.x < 0:
		sprite.flip_h = true
	elif direction_vector.x > 0:
		sprite.flip_h = false

# NEW: Call this from your Cutscene Animation (Call Method Track via Test_dialog proxy)
# to play a visual animation on the player's own AnimationPlayer
func play_player_visual_animation(anim_name: String):
	if not is_instance_valid(self): return
	
	if combat_fsm and is_instance_valid(combat_fsm):
		# Attempt to find the corresponding state in your FSM
		# You'll need a way for your FSM to transition to a state that plays the desired animation.
		# This might be more complex than a direct state name mapping.
		# Example: If anim_name is "idle", you'd want to go to IdleState.
		# If anim_name is "walk", you'd want to go to WalkState.
		
		# This is a conceptual example. You'll need to adapt it to your FSM's actual state classes.
		match anim_name:
			"idle":
				combat_fsm.change_state(IdleState.new(self))
			"run":
				combat_fsm.change_state(RunState.new(self))
			"jump":
				combat_fsm.change_state(JumpState.new(self))
			"hurt":
				combat_fsm.change_state(HurtState.new(self))
			"die":
				combat_fsm.change_state(DieState.new(self))
			"attack":
				combat_fsm.change_state(AttackState.new(self))
			"skill":
				combat_fsm.change_state(SkillState.new(self))
			# ... add other cases as needed ...
			_:
				printerr("Player: FSM has no direct state for animation '", anim_name, "'. Playing directly.")
				if animation_player and animation_player.has_animation(anim_name):
					animation_player.play(anim_name)
				else:
					printerr("Player: Cannot play visual animation '", anim_name, "'. AnimationPlayer missing or animation not found.")
	else:
		# Fallback: if no FSM or FSM is invalid, play animation directly
		if animation_player and animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
			print("Player: Playing visual animation: ", anim_name)
		else:
			printerr("Player: Cannot play visual animation '", anim_name, "'. AnimationPlayer missing or animation not found.")

# NEW: Call this from your Cutscene Animation (Call Method Track via Test_dialog proxy)
# to make the player face a certain direction instantly
func set_player_face_direction(direction: int): # 1 for right, -1 for left
	if not is_instance_valid(self): return
	facing_direction = direction
	if facing_direction == -1:
		sprite.flip_h = true
	else:
		sprite.flip_h = false
	print("Player: Facing direction set to: ", direction)

# This function is called by the Test_dialog Area2D script
# when a cutscene begins, via its proxy.
func disable_player_input_for_cutscene():
	Global.is_cutscene_active = true # Set the global flag
	print("Player: Input and direct control disabled for cutscene.")
	# Stop normal physics processing (movement, input handling)
	set_physics_process(false)
	set_process(false) # If you have non-physics input in _process
	velocity = Vector2.ZERO # Stop any current player movement
	# You might also want to temporarily hide the player or switch to a cutscene-specific animation.
	# visible = false # Example: if player should disappear
	# animation_player.play("cutscene_idle") # Example: play a special idle during cutscene

# This function is called by the Test_dialog Area2D script's end_cutscene (via proxy)
# or from the final Call Method Track in your Cutscene Animation (via proxy)
func enable_player_input_after_cutscene():
	Global.is_cutscene_active = false # Clear the global flag
	print("Player: Input and direct control enabled after cutscene.")
	# Reset any temporary cutscene velocity
	velocity.x = 0
	
	# Re-enable physics and process
	set_physics_process(true)
	set_process(true)

	# Ensure FSM goes back to idle state
	if combat_fsm and is_instance_valid(combat_fsm):
		combat_fsm.change_state(IdleState.new(self)) # Assuming IdleState is the default after cutscene
	else:
		# Fallback if FSM is not used or not valid
		if animation_player:
			# Note: You had `combat_fsm.change_state(IdleState.new(self))` here again,
			# which would error if combat_fsm is null. Changed to direct animation play.
			animation_player.play("idle")
	
	# visible = true # Example: if player was hidden
	



