extends CombatState
class_name AttackState

# Called when the node enters the scene tree for the first time.
func enter():
	var form = player.get_current_form_id()
	
	match form:
		"Magus":
			#player.anim_sprite.play("magus_attack")
			# You could also spawn a fireball or magic effect here
			#print("Magus attack")
			player.still_animation = true
			player.anim_state.travel("attack_magus")
			Global.attacking = true
			player.velocity.x = 0
		"Cyber":
			#player.anim_sprite.play("cyber_slash")
			# Maybe activate grapple or combo effects
			#print("Cyber attack")
			player.still_animation = true
			player.anim_state.travel("attack_cyber")
			Global.attacking = true
			player.velocity.x = 0
		"UltimateMagus":
			#player.anim_sprite.play("ultimate_magus_blast")
			# Big AoE logic here
			#print("Ultimate Magus attack")
			player.still_animation = true
			player.anim_state.travel("attack_ult_magus_1")
			Global.attacking = true
			player.velocity.x = 0
		"UltimateCyber":
			#player.anim_sprite.play("ultimate_cyber_strike")
			# Laser or time freeze here
			#print("Ultimate Cyber attack")
			player.still_animation = true
			player.anim_state.travel("attack_ult_cyber")
			Global.attacking = true
			player.velocity.x = 0
		"Normal":
			#player.anim_sprite.play("normal_attack")
			#print("Normal attack")
			pass
			#player.still_animation = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func physics_update(delta):
	if  player.get_current_form_id() == "UltimateMagus" and Input.is_action_just_pressed("yes"): 
		get_parent().change_state(AttackState2.new(player))
	
	if !(Input.is_action_just_pressed("yes")) and player.still_animation == false:
		Global.attacking = false
		if player.is_on_floor():
			if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right"):
				#print("IdleState: Detected movement input → switching to RunState")
				get_parent().change_state(RunState.new(player))
			else:
				#print("IdleState: Detected movement input → switching to IdleState")
				get_parent().change_state(IdleState.new(player))

		else:
			#print("IdleState: Detected movement input → switching to JumpState")
			get_parent().change_state(JumpState.new(player))
