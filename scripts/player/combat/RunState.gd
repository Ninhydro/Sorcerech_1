extends CombatState
class_name RunState

func enter():
	#player.play_anim("run")
	#print("run")
	var form = player.get_current_form_id()
	
	match form:
		"Magus":
			#player.anim_sprite.play("magus_attack")
			# You could also spawn a fireball or magic effect here
			#print("Magus run")
			player.anim_state.travel("run_magus")
		"Cyber":
			#player.anim_sprite.play("cyber_slash")
			# Maybe activate grapple or combo effects
			#print("Cyber run")
			player.anim_state.travel("run_cyber")
		"UltimateMagus":
			#player.anim_sprite.play("ultimate_magus_blast")
			# Big AoE logic here
			#print("Ultimate Magus run")
			player.anim_state.travel("run_ult_magus")
		"UltimateCyber":
			#player.anim_sprite.play("ultimate_cyber_strike")
			# Laser or time freeze here
			#print("Ultimate Cyber run")
			player.anim_state.travel("run_ult_cyber")
		"Normal":
			#player.anim_sprite.play("normal_attack")
			#print("Normal run")
			player.anim_state.travel("run_normal")
			
func physics_update(delta):
	if player.player_hit == false:
		if player.is_on_floor():
			if !(Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")):
				#print("IdleState: Detected movement input → switching to IdleState")
				get_parent().change_state(IdleState.new(player))
			elif Input.is_action_just_pressed("jump"):
				#print("IdleState: Detected movement input → switching to JumpState")
				get_parent().change_state(JumpState.new(player))
			elif player.is_grabbing_ledge:
				get_parent().change_state(LedgeState.new(player))
			elif Input.is_action_just_pressed("yes") and player.can_attack == true and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause:
				#print("IdleState: Detected movement input → switching to AttackState")
				get_parent().change_state(AttackState.new(player))
			elif Input.is_action_just_pressed("no") and player.can_skill == true and not Global.is_dialog_open and not Global.ignore_player_input_after_unpause:
				#print("IdleState: Detected movement input → switching to SkillState")
				get_parent().change_state(SkillState.new(player))
		else:
			#print("IdleState: Detected movement input → switching to JumpState")
			get_parent().change_state(JumpState.new(player))
	elif player.player_hit == true:
		#print("IdleState: Detected movement input → switching to HurtState")
		get_parent().change_state(HurtState.new(player))
	#elif Input.is_action_pressed("no"): #hurt hp loss this is later
	#	print("IdleState: Detected movement input → switching to HurtState")
	#	get_parent().change_state(HurtState.new(player))
