extends BaseState


class_name UltimateMagusState

var teleport_select_mode := false
var selected_index := 0
var available_objects := []
var current_object: TelekinesisObject = null

var hold_time := 0.0
var hold_threshold := 1
var is_holding := false

var _object_original_materials: Dictionary = {} 
var _current_highlight_material: ShaderMaterial

const CombatFSM = preload("res://scripts/player/combat/CombatFSM.gd")
var combat_fsm: CombatFSM

var is_attacking := false
var attack_timer := 0.0
const ATTACK_DURATION := 0.2  # seconds

var teleport_reset_timer: float = 0.0
var teleport_reset_delay: float = 0.8  # Match this to your animation length
var skill_just_used: bool = false



func _init(_player):
	player = _player
	combat_fsm = CombatFSM.new(player)
	add_child(combat_fsm)

func enter():
	#_previous_material = player.sprite.material
	
	# CREATE the highlight material using Global's shader
	_current_highlight_material = Global.create_highlight_material()
	#_current_highlight_material.shader = Global.highlight_shader
	# Set any parameters you need
	#_current_highlight_material.set_shader_parameter("highlight_color", Color(1, 0, 0, 1))
	
	# Apply it
	#player.sprite.material = _current_highlight_material
	print("Using global highlight material in UltimateMagusState")
	
	teleport_select_mode = false
	player.telekinesis_enabled = false
	is_holding = false
	hold_time = 0.0
	Global.playerDamageAmount = 50
	var collision = player.get_node_or_null("CollisionShape2D")
	if collision:
		collision.position = Vector2(1,-10)
		collision.scale = Vector2(1,3)
	
	print("Entered Ultimate Magus State")
	

	# e.g. change player color or animation

func exit():
	teleport_select_mode = false
	player.telekinesis_enabled = false
	is_holding = false
	hold_time = 0.0
	#clear_highlights()
	
	clear_highlights(true) # Pass true to indicate full cleanup
	
	# Clean up references
	_current_highlight_material = null
	
	# Start cooldown timers
	if player and is_instance_valid(player):
		player.skill_cooldown_timer.start(0.1)
		player.attack_cooldown_timer.start(0.1)
	
	print("UltimateMagusState: Cleanup completed")
	
	
		

		

func physics_process(delta):
	#print(player.can_skill)
	combat_fsm.physics_update(delta)
	#print(teleport_select_mode)
	
			
	if player.canon_enabled == true:
		player.velocity = Vector2.ZERO
	else:
		#player.scale = Vector2(1.2,1.2)
		#if Input.is_action_just_pressed("no"):
			#perform_teleport_switch()
		if Input.is_action_just_pressed("yes") and player.can_attack == true and Global.playerAlive and Global.telekinesis_mode == false and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause and player.not_busy:
			#is_attacking = true
			#attack_timer = ATTACK_DURATION
			player.AreaAttack.monitoring = true
			#player.AreaAttackColl.disabled = false
			print("Ult Magus attacking")
		
		if is_holding == true:
			hold_time += delta
		if Input.is_action_pressed("no") and player.can_skill == true and Global.playerAlive and Global.telekinesis_mode == false and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause and not Global.ignore_player_input_after_unpause and player.not_busy:
			#hold_time += delta # Add time while holding
			#print("teleporting")
			
			if !teleport_select_mode:
				Global.teleporting = true
				teleport_select_mode = true
				player.telekinesis_enabled = true
				available_objects = player.get_nearby_telekinesis_objects()
				print("Found objects: ", available_objects)
				if available_objects.size() > 0:
					selected_index = 0
					update_highlight()  # Highlight immediately
				else:
					print("No objects available for teleport")
				print(player.get_nearby_telekinesis_objects())
				print("teleport mode")
				selected_index = 0
				update_highlight()
				is_holding = true
				hold_time = 0.0
			# Allow left/right selection while holding
	
		elif Input.is_action_just_released("no") and teleport_select_mode and Global.telekinesis_mode == false and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause:
			if available_objects.size() > 0 and hold_time >= hold_threshold:
				current_object = available_objects[selected_index]
				switch_with_object(current_object)
				print("Swapped with:", current_object.name, " Now at:", current_object.global_position)
				teleport_select_mode = false
				
			else:
				Global.dashing = true
				do_dash()
				teleport_select_mode = false
				
			clear_highlights(true)
			#Global.teleporting = false
			#teleport_select_mode = false
			player.telekinesis_enabled = false
			is_holding = false
			hold_time = 0.0
			
			Global.teleporting = false
			
		if teleport_select_mode and available_objects.size() > 0 and  hold_time >= hold_threshold and Global.telekinesis_mode == false:
			update_highlight()
			#print("highlight")
			if Input.is_action_just_pressed("move_right"):
				selected_index = (selected_index + 1) % available_objects.size()
				print("right")
				update_highlight()
			elif Input.is_action_just_pressed("move_left"):
				selected_index = (selected_index - 1 + available_objects.size()) % available_objects.size()
				print("left")
				update_highlight()
			

							
func switch_with_object(obj: TelekinesisObject):
	var player_pos = player.global_position
	var object_pos = obj.global_position

	# Freeze object briefly
	obj.linear_velocity = Vector2.ZERO
	obj.angular_velocity = 0
	obj.sleeping = true
	obj.freeze = true
	
	await obj.get_tree().create_timer(0.05).timeout
	
	# Optional: offset player slightly to avoid clipping (adjust as needed)
	var offset = Vector2(0, -10)

	# Swap positions
	obj.global_position = player_pos + Vector2(0, -8)
	player.global_position = object_pos + offset + Vector2(0, -8)

	# Allow physics to resume safely after 0.2 sec
	await obj.get_tree().create_timer(0.2).timeout
	obj.sleeping = false
	obj.freeze = false

func do_dash():
	# Do a dash forward in facing direction using velocity
	var dash_power = 500  # Adjust this value to control dash speed
	var dash_direction = Vector2.RIGHT if player.facing_direction > 0 else Vector2.LEFT
	
	# Apply dash velocity instead of changing position directly
	player.velocity = dash_direction * dash_power
	player.velocity.y -= 100
	
	# Debug output
	print("Dash activated! Velocity set to: ", player.velocity)
	print("Facing direction: ", player.facing_direction)
	print("Dash power: ", dash_power)
	# Set dashing state
	Global.dashing = true

func update_highlight():
	# Filter out any invalid objects
	# Filter out any invalid objects
	debug_object_states() 
	available_objects = available_objects.filter(func(obj): return is_instance_valid(obj))
	
	if available_objects.size() == 0:
		print("No valid objects to highlight")
		return
		
	print("Updating highlight for ", available_objects.size(), " objects, selected index: ", selected_index)
	
	# Use the fixed outline material
	for i in range(available_objects.size()):
		var obj = available_objects[i]
		if is_instance_valid(obj):
			var sprite = obj.get_node_or_null("Sprite2D")
			if sprite:
				# Store the object's original material if we haven't already
				if not _object_original_materials.has(obj):
					_object_original_materials[obj] = sprite.material
				
				if i == selected_index:
					sprite.material = _current_highlight_material
					print("Applied outline material to object ", i)
				else:
					# Restore original material for non-selected objects
					sprite.material = _object_original_materials[obj]
					
func debug_object_states():
	print("=== OBJECT DEBUG ===")
	print("Available objects count: ", available_objects.size())
	print("Selected index: ", selected_index)
	print("Teleport select mode: ", teleport_select_mode)
	
	for i in range(available_objects.size()):
		var obj = available_objects[i]
		if is_instance_valid(obj):
			var sprite = obj.get_node_or_null("Sprite2D")
			print("Object ", i, ": ", obj.name, " - Valid: ", true, " - Has Sprite: ", sprite != null)
			if sprite:
				print("  Material: ", sprite.material)
		else:
			print("Object ", i, ": INVALID")
	print("===================")
	

func force_cleanup():
	"""Emergency cleanup for when game exits forcefully"""
	print("UltimateMagusState: EMERGENCY FORCE CLEANUP")
	
	# Emergency reset of ALL object materials to prevent shader errors
	for obj in _object_original_materials:
		if is_instance_valid(obj):
			var sprite = obj.get_node_or_null("Sprite2D")
			if sprite and is_instance_valid(sprite):
				# Emergency reset - set to null to prevent shader errors
				sprite.material = null
				print("UltimateMagusState: Emergency material reset for object")
	
	# Clear all collections
	_object_original_materials.clear()
	available_objects.clear()
	
	# Null references
	_current_highlight_material = null
	current_object = null

func clear_highlights(full_cleanup: bool = false):
	"""Clear highlights from all objects and optionally clean up materials"""
	print("UltimateMagusState: Clearing highlights from ", _object_original_materials.size(), " objects")
	
	# Restore original materials to ALL objects
	for obj in _object_original_materials:
		if is_instance_valid(obj):
			var sprite = obj.get_node_or_null("Sprite2D")
			if sprite and is_instance_valid(sprite):
				# Restore the original material
				sprite.material = _object_original_materials[obj]
				print("UltimateMagusState: Restored original material for object")
	
	_object_original_materials.clear()
	available_objects.clear()
	selected_index = 0
	
	if full_cleanup:
		_current_highlight_material = null
	
	print("UltimateMagusState: Highlights cleared")
	#if full_cleanup:
	#	RenderingServer.call_deferred("free_rids")
