extends BaseState

class_name UltimateCyberState

var combat_fsm: CombatFSM

const CombatFSM = preload("res://scripts/player/combat/CombatFSM.gd")

var is_attacking := false
var attack_timer := 0.0
const ATTACK_DURATION := 0.2  # seconds

func _init(_player):
	player = _player
	combat_fsm = CombatFSM.new(player)
	add_child(combat_fsm)

func enter():
	Global.playerDamageAmount = 30
	print("Entered Ultimate Cyber State")
	# e.g. change player color or animation
	

func exit():
	#reset time freeze
	player.jump_force = 250
	player.gravity = 1000
	player.allow_time_freeze = false
	Engine.time_scale = 1
	Global.time_freeze = false
	
	player.skill_cooldown_timer.start(0.1)
	player.attack_cooldown_timer.start(0.1)

func physics_process(delta):
	combat_fsm.physics_update(delta)
	
	if player.canon_enabled == true or player.telekinesis_enabled == true:
		player.velocity = Vector2.ZERO
	else:
		player.jump_force = 300
		player.gravity = 500
		player.scale = Vector2(1.2,1.2)
		
		# --- Rocket shooting for "yes" action ---
		if Input.is_action_just_pressed("yes") and player.can_attack == true and Global.playerAlive:
			player.shoot_rocket() # Call the new function to shoot a rocket
			#player.can_attack = false # Apply attack cooldown
			# Use the attack_cooldown_timer's current wait_time, e.g., 1.0 from player.gd
			#player.attack_cooldown_timer.start(player.attack_cooldown_timer.wait_time)
			print("Ultimate Cyber shooting rocket!")
					
		if Input.is_action_just_pressed("no") and player.can_skill == true and Global.playerAlive:
			perform_time_freeze()
	


func perform_time_freeze():
	# Slow down time
	#Engine.time_scale = 0.1  # (Engine.time_scale docs: lower values slow the game):contentReference[oaicite:8]{index=8}
	# After a timer, reset Engine.time_scale = 1.0
	#pass
	player.allow_time_freeze = !player.allow_time_freeze
	if player.allow_time_freeze == true:
		print("Time Frozen - enemies paused")
		Global.time_freeze = true
		Engine.time_scale = 0.5
		#get_tree().paused = !get_tree().paused
		#if player.animation_player:
		#	player.animation_player.speed_scale = 1.0
		# In a real game, you might set Engine.time_scale = 0 or pause enemy nodes.
	#else:
		await player.get_tree().create_timer(10.0, true, false, true).timeout
		print("Time Resumed - enemies active")
		Engine.time_scale = 1
		Global.time_freeze = false
		player.allow_time_freeze = !player.allow_time_freeze
		#get_tree().paused = !get_tree().paused
		#if player.animation_player:
		#	player.animation_player.speed_scale = 1.0
			
			# Reset time_scale or unpause enemies.


func handle_input(event):
	pass
