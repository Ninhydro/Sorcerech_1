extends BaseState

class_name MagusState

var combat_fsm: CombatFSM

const CombatFSM = preload("res://scripts/player/combat/CombatFSM.gd")

var is_attacking := false
var attack_timer := 0.0
const ATTACK_DURATION := 0.2  # seconds

var _camouflage_target_alpha: float = 1.0 # Default to opaque (1.0)
var _sprite_node: Sprite2D = null
var _animation_player_node: AnimationPlayer = null

var _original_sprite_material: Material = null
var _camouflage_shader_material: ShaderMaterial = null

# Flag to track if camouflage is currently active (e.g., during the 5-second duration)
var _is_camouflage_active_timed := false

var _previous_material: Material

func _init(_player):
	player = _player
	combat_fsm = CombatFSM.new(player)
	add_child(combat_fsm)

func enter():
	Global.playerDamageAmount = 20
	
	var collision = player.get_node_or_null("CollisionShape2D")
	if collision:
		collision.position = Vector2(1,-10)
		collision.scale = Vector2(1,3)
	
	_sprite_node = player.get_node_or_null("Sprite2D")
	
	if not _sprite_node:
		push_warning("MagusState: 'Sprite2D' child node not found on player. Camouflage won't work.")
		return # Exit early if sprite is essential

	# Store the Sprite2D's current material before applying our shader.
	_original_sprite_material = _sprite_node.material
	
	
	# Clean up any existing shader material first
	if _camouflage_shader_material and is_instance_valid(_camouflage_shader_material):
		_camouflage_shader_material.free()
		_camouflage_shader_material = null

	# Create a new instance of our ShaderMaterial
	_camouflage_shader_material = Global.create_camouflage_material()
	if not _camouflage_shader_material:
		push_error("MagusState: Failed to create camouflage material. Camouflage will not work.")
		_sprite_node.material = _original_sprite_material
		return

		#_camouflage_shader_material = ShaderMaterial.new()
		#_camouflage_shader_material.shader = shader_resource

	# Apply our ShaderMaterial to the Sprite2D.
	_sprite_node.material = _camouflage_shader_material

	# Check if the Sprite2D now has our ShaderMaterial applied.
	#if not (_sprite_node.material is ShaderMaterial):
	#	push_error("MagusState: Failed to apply ShaderMaterial to Sprite2D! Camouflage will not work.")
	#	return

	_animation_player_node = player.get_node_or_null("AnimationPlayer")
	if not _animation_player_node:
		_animation_player_node = _sprite_node.get_node_or_null("AnimationPlayer")
	if not _animation_player_node:
		push_warning("MagusState: 'AnimationPlayer' node not found. Debugging might be less insightful.")

	# IMPORTANT: When entering, assume camouflage is OFF unless explicitly turned ON.
	# If player.allow_camouflage was TRUE from a previous session (e.g., after the 5s timer
	# finished but before exiting the state), we should reset it here.
	#if Global.camouflage and not _is_camouflage_active_timed:
		# This condition handles cases where player.allow_camouflage might be true
		# but the timed camouflage is not active. We want to ensure a clean start.
		#player.allow_camouflage = false 
	#	Global.camouflage = false


	# Set the shader uniform directly on enter
	# The default is 1.0 (opaque). We only change it if camouflage is specifically active.
	# Reset camouflage state
	_camouflage_target_alpha = 1.0
	Global.camouflage = false
	_is_camouflage_active_timed = false

	if _sprite_node.material:
		_sprite_node.material.set_shader_parameter("camouflage_alpha_override", _camouflage_target_alpha)
	
	print("Entered Magus State. ShaderMaterial applied.")
	#print("DEBUG_ENTER: player.allow_camouflage initial state: ", player.allow_camouflage)


func exit():
	
	Global.camouflage = false
	_is_camouflage_active_timed = false # Reset this flag as well
	
	if _sprite_node and is_instance_valid(_sprite_node):
		# Reset the shader uniform to fully opaque before removing the shader
		if _sprite_node.material and (_sprite_node.material is ShaderMaterial):
			_sprite_node.material.set_shader_parameter("camouflage_alpha_override", 1.0)

		# Restore the original material
		_sprite_node.material = _original_sprite_material
	
	# Clean up the shader material
	cleanup_shader_materials()
	
	# Start cooldown timers
	if player and is_instance_valid(player):
		player.skill_cooldown_timer.start(0.1)
		player.attack_cooldown_timer.start(0.1)
	
	print("Exited Magus State. Cleanup completed.")
	
	

func cleanup_shader_materials():
	# Only clean up if we have a valid shader material
	#if _sprite_node and is_instance_valid(_sprite_node):
	#	if _sprite_node.material != _original_sprite_material:
	#		_sprite_node.material = _original_sprite_material
	
	# Don't manually free - let Godot handle the cleanup
	#_camouflage_shader_material = null
	_camouflage_shader_material = null
	_original_sprite_material = null
	_sprite_node = null
	
	print("MagusState: Camouflage material cleaned up")

func force_cleanup():
	"""Ultra-safe cleanup for emergency situations"""
	print("MagusState: EMERGENCY FORCE CLEANUP")
	
	# Only try to reset the sprite material if everything is still valid
	if _sprite_node and is_instance_valid(_sprite_node):
		# Emergency reset - just set to null to prevent shader errors
		_sprite_node.material = null
		print("MagusState: Emergency sprite material reset to null")
	
	# Always null references
	_camouflage_shader_material = null
	_original_sprite_material = null
	_sprite_node = null
	
func physics_process(delta):
	combat_fsm.physics_update(delta)
	
	if player.canon_enabled == true or player.telekinesis_enabled == true:
		player.velocity = Vector2.ZERO
	else:
		#player.scale = Vector2(1,1)
		
		if Input.is_action_just_pressed("yes") and player.can_attack == true and Global.playerAlive and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause and player.not_busy:
			player.shoot_fireball()
			print("Magus shooting fireball!")
			
		if Input.is_action_just_pressed("no") and player.can_skill == true and Global.playerAlive and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause and player.not_busy:
			# Only toggle if timed camouflage is not already active
			if not _is_camouflage_active_timed:
				toggle_camouflage()
	
	if not _sprite_node or not _sprite_node.material or not (_sprite_node.material is ShaderMaterial):
		return # Exit early if our shader is not active.

	# Update the shader uniform based on player.allow_camouflage
	# _camouflage_target_alpha will be 0.5 if camouflage is ON, else 1.0
	_sprite_node.material.set_shader_parameter("camouflage_alpha_override", _camouflage_target_alpha)


func handle_input(event):
	pass

func toggle_camouflage():
	# If camouflage is already active, prevent re-activating it.
	if _is_camouflage_active_timed:
		print("Camouflage is already active or on cooldown.")
		return

	#player.allow_camouflage = true # Explicitly set to true when activating
	Global.camouflage = true
	_camouflage_target_alpha = 0.5 # Semi-transparent
	_is_camouflage_active_timed = true # Mark timed camouflage as active

	# Immediately apply the transparency
	if _sprite_node and _sprite_node.material and (_sprite_node.material is ShaderMaterial):
		_sprite_node.material.set_shader_parameter("camouflage_alpha_override", _camouflage_target_alpha)
	else:
		push_warning("toggle_camouflage: Sprite2D node, its material, or ShaderMaterial not found/applied during toggle.")
		return

	print("Camouflage ON - enemies ignore the player")

	# Wait for the duration
	await player.get_tree().create_timer(5.0).timeout

	# After timeout, disable camouflage
	_camouflage_target_alpha = 1.0 # Fully opaque
	
	#if _sprite_node and _sprite_node.material and (_sprite_node.material is ShaderMaterial):
	#	_sprite_node.material.set_shader_parameter("camouflage_alpha_override", _camouflage_target_alpha)
	
	#player.allow_camouflage = false # Explicitly set to false after duration
	Global.camouflage = false
	_is_camouflage_active_timed = false # Mark timed camouflage as inactive
	print("Camouflage OFF")
	
