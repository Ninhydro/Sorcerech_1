extends BaseState


class_name UltimateMagusState

var teleport_select_mode := false
var selected_index := 0
var available_objects := []
var current_object: TelekinesisObject = null

var hold_time := 0.0
var hold_threshold := 1
var is_holding := false

@onready var outline_material = preload("res://shaders/OutlineMaterial.tres")
const CombatFSM = preload("res://scripts/player/combat/CombatFSM.gd")
var combat_fsm: CombatFSM

var is_attacking := false
var attack_timer := 0.0
const ATTACK_DURATION := 0.2  # seconds


	
func _init(_player):
	player = _player
	combat_fsm = CombatFSM.new(player)
	add_child(combat_fsm)

func enter():
	teleport_select_mode = false
	player.telekinesis_enabled = false
	is_holding = false
	hold_time = 0.0
	Global.playerDamageAmount = 50
	print("Entered Ultimate Magus State")

	# e.g. change player color or animation

func exit():
	teleport_select_mode = false
	player.telekinesis_enabled = false
	is_holding = false
	hold_time = 0.0
	clear_highlights()
	
	player.skill_cooldown_timer.start(0.1)
	player.attack_cooldown_timer.start(0.1)

func physics_process(delta):
	#print(player.can_skill)
	combat_fsm.physics_update(delta)
	#print(teleport_select_mode)
	
	
	if player.canon_enabled == true:
		player.velocity = Vector2.ZERO
	else:
		player.scale = Vector2(1.2,1.2)
		#if Input.is_action_just_pressed("no"):
			#perform_teleport_switch()
		if Input.is_action_just_pressed("yes") and player.can_attack == true and Global.playerAlive and Global.telekinesis_mode == false:
			#is_attacking = true
			#attack_timer = ATTACK_DURATION
			player.AreaAttack.monitoring = true
			#player.AreaAttackColl.disabled = false
			print("Ult Magus attacking")
		
		if is_holding == true:
			hold_time += delta
		if Input.is_action_pressed("no") and player.can_skill == true and Global.playerAlive and Global.telekinesis_mode == false:
			#hold_time += delta # Add time while holding
			#print("teleporting")
			
			if !teleport_select_mode:
				teleport_select_mode = true
				player.telekinesis_enabled = true
				available_objects = player.get_nearby_telekinesis_objects()
				print(player.get_nearby_telekinesis_objects())
				print("teleport mode")
				selected_index = 0
				#update_highlight()
				is_holding = true
				hold_time = 0.0
			# Allow left/right selection while holding
	
		elif Input.is_action_just_released("no") and teleport_select_mode and Global.telekinesis_mode == false:
			if available_objects.size() > 0 and hold_time >= hold_threshold:
				current_object = available_objects[selected_index]
				switch_with_object(current_object)
				print("Swapped with:", current_object.name, " Now at:", current_object.global_position)
			else:
				do_dash()
			clear_highlights()
			teleport_select_mode = false
			player.telekinesis_enabled = false
			is_holding = false
			hold_time = 0.0
		
		if teleport_select_mode and available_objects.size() > 0 and  hold_time >= hold_threshold and Global.telekinesis_mode == false:
			update_highlight()
			print("highlight")
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
	# Do a small dash forward in facing direction
	var dash_distance = 50
	var dir = Vector2.RIGHT if player.facing_direction > 0 else Vector2.LEFT
	var dash_speed = 10
	var dash_vector = Vector2(dash_speed * player.facing_direction, 0)
	var collision = player.move_and_collide(dash_vector.normalized() * dash_distance)

	if collision:
		# Adjust to stop before wall
		player.global_position = collision.get_position() - dash_vector.normalized() * 4
	else:
		player.global_position += dash_vector.normalized() * dash_distance
	#player.global_position += dir * dash_distance

func update_highlight():
	player.telekinesis_controller.highlight_object_list(available_objects, selected_index)

	#for i in range(available_objects.size()):
	#	var obj = available_objects[i]
	#	var sprite = obj.get_node_or_null("Sprite2D")  # or "Sprite"
	#	if sprite:
	#		sprite.material = outline_material if i == selected_index else null

func clear_highlights():
	for obj in available_objects:
		var sprite = obj.get_node_or_null("Sprite2D")
		if sprite:
			sprite.material = null
	available_objects.clear()
	selected_index = 0
