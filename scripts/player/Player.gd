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

const FLOOR_NORMAL: Vector2 = Vector2(0, -1) # Standard for side-scrolling 2D

var wall_jump_just_happened = false
var wall_jump_timer := 0.0
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

func _ready():
	Global.playerBody = self
	Global.playerAlive = true
	
	dead = false
	can_take_damage = true
	
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
		money = Global.current_loaded_player_data.get("money", 0)

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
	# --- END MODIFIED _ready() LOGIC ---

func _physics_process(delta):
	# --- APPLY LOADED POSITION (ONE-TIME) ---
	
	#unlock_state("Cyber")
	#unlock_state("Magus")
	
	Global.current_form = get_current_form_id()
	
	if _should_apply_loaded_position:
		print("Player._physics_process: Applying loaded position (one-time).")
		global_position = Vector2(Global.current_loaded_player_data.get("position_x"), Global.current_loaded_player_data.get("position_y"))
		velocity = Vector2.ZERO # Crucial to prevent residual movement after loading
		_should_apply_loaded_position = false # Set flag to false so it only runs once
		Global.current_loaded_player_data = {} # Clear the temporary data from Global after use
		print("Player.gd: Position set to loaded: ", global_position)
	# --- END APPLY LOADED POSITION ---

	if combat_fsm:
		combat_fsm.update_physics(delta)
	
	if current_state:
		current_state.physics_process(delta)
		
	Global.playerDamageZone = AreaAttack
	Global.playerHitbox = Hitbox
	
	if telekinesis_controller.is_ui_open == true:
		UI_telekinesis = true
	elif telekinesis_controller.is_ui_open == false:
		UI_telekinesis = false
		
	var input_dir = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if Input.is_action_pressed("move_right") and not wall_jump_just_happened and Global.is_dialog_open == false:
		facing_direction = 1
	elif Input.is_action_pressed("move_left") and not wall_jump_just_happened and Global.is_dialog_open == false:
		facing_direction = -1
		
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
		if wall_jump_timer <= 0:
			wall_jump_just_happened = false
	
	if !dead:
		if knockback_timer > 0:
			velocity = knockback_velocity
			knockback_timer -= delta
		elif canon_enabled == true && !is_launched: # Only stop movement if in cannon mode and NOT launched yet
			scale = Vector2(0.5,0.5)
			velocity = Vector2.ZERO
		elif telekinesis_enabled == true :
			velocity = Vector2.ZERO
		else: # Normal movement
			if facing_direction == -1 and !dead:
				sprite.flip_h = true
			else:
				sprite.flip_h = false
				
			if not wall_jump_just_happened and Global.is_dialog_open == false and Global.attacking == false:
				velocity.x = input_dir * move_speed
			elif Global.is_dialog_open == true:
				velocity.x = 0
			if is_on_floor() and Input.is_action_just_pressed("move_up") and Global.is_dialog_open == false and Global.attacking == false:
				velocity.y = -jump_force
	
		if Input.is_action_just_pressed("yes") and can_attack and get_current_form_id() != "Normal" and get_current_form_id() != "UltimateMagus" and get_current_form_id() != "UltimateCyber" and Global.is_dialog_open == false:
			can_attack = false
			attack_cooldown_timer.start(2.0)
			#print("start cooldonw 2")
		elif Input.is_action_just_pressed("yes") and can_attack and get_current_form_id() != "Normal" and get_current_form_id() != "UltimateMagus" and get_current_form_id() == "UltimateCyber" and Global.is_dialog_open == false:
			can_attack = false
			attack_cooldown_timer.start(5.0)
			#print("start cooldonw 5")
		elif get_current_form_id() == "UltimateMagus" and can_attack and Input.is_action_just_pressed("yes") and get_current_form_id() != "Normal" and get_current_form_id() != "UltimateCyber"  and combo_timer_flag == true and Global.is_dialog_open == false:
			combo_timer_flag = false
			combo_timer.start(0.5)
			#print("start cooldonw 0.5")
		
		#print(get_current_form_id())
		if Input.is_action_just_pressed("no") and can_skill and get_current_form_id() != "Normal" and get_current_form_id() != "Cyber" and get_current_form_id() != "Magus" and get_current_form_id() != "UltimateCyberState" and Global.is_dialog_open == false:
			can_skill = false
			skill_cooldown_timer.start(2.0)
		
		elif Input.is_action_just_pressed("no") and can_skill and  get_current_form_id() != "Normal"  and get_current_form_id() == "Cyber" and get_current_form_id() != "Magus" and get_current_form_id() != "UltimateCyberState" and Global.is_dialog_open == false:
			can_skill = false
			skill_cooldown_timer.start(0.1)
			
			
		elif Input.is_action_just_pressed("no") and can_skill and  get_current_form_id() != "Normal"  and get_current_form_id() != "Cyber" and get_current_form_id() == "Magus" and get_current_form_id() != "UltimateCyberState" and Global.is_dialog_open == false:
			can_skill = false
			skill_cooldown_timer.start(10.0)
			
		elif Input.is_action_just_pressed("no") and can_skill and  get_current_form_id() != "Normal"  and get_current_form_id() != "Cyber" and get_current_form_id() == "UltimateCyberState" and get_current_form_id() != "Magus" and Global.is_dialog_open == false:
			can_skill = false
			skill_cooldown_timer.start(15.0)
		
		
		check_hitbox()
	elif dead:
		velocity = Vector2.ZERO # Stop all movement if dead
	
	# --- CANNON AIMING AND LAUNCHING LOGIC ---
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
		# sprite.play("flying") # TODO: change to appropriate flying sprite animation
		
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

			# Always process bounce if it's a bounce spot, regardless of protection timer
			# The timer is now only for preventing premature stopping.
			if collider and collider.has_method("get_bounce_data"):
				var bounce_data = collider.get_bounce_data()
				var bounce_normal = bounce_data.normal
				var bounce_power = bounce_data.power

				# Only bounce if the normal is valid and not zero
				if bounce_normal.length() > 0.01:
					bounce_normal = bounce_normal.normalized()
					# Reflect the current velocity based on the bounce normal
					launch_direction = velocity.bounce(bounce_normal).normalized()
					velocity = launch_direction * launch_speed * bounce_power # Apply new velocity
					print("BOUNCED! New direction: ", launch_direction, " New velocity: ", velocity)
					bounced_this_frame = true # Set flag that a bounce occurred
					bounced_recently() # Activate bounce protection (to prevent immediate stopping)
					break # Stop checking after the first bounceable collision
				else:
					print("Invalid bounce normal: ", bounce_normal)

		# Apply gravity if launched and not on floor (for ballistic trajectory)
		if not is_on_floor():
			velocity.y += gravity * delta

		# Stopping condition:
		# Stop if we are on a solid surface (floor, ceiling, or wall)
		# AND we have NOT bounced recently (bounced_protection_timer is 0 or less).
		# This allows the player to continue moving after a bounce, even if they briefly touch a non-bounce surface.
		if (is_on_floor() or is_on_ceiling() or is_on_wall()) and bounced_protection_timer <= 0:
			is_launched = false
			velocity = Vector2.ZERO # Stop movement
			canon_enabled = false # Exit cannon mode
			print("Player stopped on a non-bounce surface or came to rest.")
	else:
		# This else block handles normal gravity application when not launched
		if not is_on_floor() and !is_in_cannon && !telekinesis_enabled:
			velocity.y += gravity * delta	
			
	# IMPORTANT: Only one move_and_slide() call per _physics_process frame.
	# This should be at the very end of _physics_process after all velocity calculations.
	move_and_slide()
	
	# --- FORM ROTATION ---
	if Input.is_action_just_pressed("form_next"):
		Global.selected_form_index = (Global.selected_form_index + 1) % unlocked_states.size()
		print("Selected form: " + unlocked_states[Global.selected_form_index])

	if Input.is_action_just_pressed("form_prev"):
		Global.selected_form_index = (Global.selected_form_index - 1 + unlocked_states.size()) % unlocked_states.size()
		print("Selected form: " + unlocked_states[Global.selected_form_index])

	if Input.is_action_just_pressed("form_apply") and !dead and Global.is_dialog_open == false:
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
			take_damage_cooldown(1.0)
		await get_tree().create_timer(0.5).timeout
		player_hit = false
			
func take_damage_cooldown(time):
	print("cooldown")
	can_take_damage = false
	await get_tree().create_timer(time).timeout
	can_take_damage = true
	
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
