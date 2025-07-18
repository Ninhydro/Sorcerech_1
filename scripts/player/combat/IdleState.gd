extends CombatState
class_name IdleState

func enter():
	#player.play_anim("idle")
	#print("idle")
	var form = player.get_current_form_id()
	match form:
		"Magus":
			#player.anim_sprite.play("magus_attack")
			# You could also spawn a fireball or magic effect here
			print("Magus idle")
			player.anim_state.travel("idle_magus")
		"Cyber":
			#player.anim_sprite.play("cyber_slash")
			# Maybe activate grapple or combo effects
			print("Cyber idle")
			player.anim_state.travel("idle_cyber")
		"UltimateMagus":
			#player.anim_sprite.play("ultimate_magus_blast")
			# Big AoE logic here
			print("Ultimate Magus idle")
			player.anim_state.travel("idle_ult_magus")
		"UltimateCyber":
			#player.anim_sprite.play("ultimate_cyber_strike")
			# Laser or time freeze here
			print("Ultimate Cyber idle")
			player.anim_state.travel("idle_ult_cyber")
		"Normal":
			#player.anim_sprite.play("normal_attack")
			print("Normal idle")
			player.anim_state.travel("idle_normal")

func physics_update(delta):
	if player.player_hit == false:
		if (Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")) and player.telekinesis_enabled == false and Global.is_dialog_open == false:
			#print("IdleState: Detected movement input → switching to RunState")
			get_parent().change_state(RunState.new(player))
		elif (Input.is_action_just_pressed("move_up")) and player.telekinesis_enabled == false and Global.is_dialog_open == false:
			#print("IdleState: Detected movement input → switching to JumpState")
			get_parent().change_state(JumpState.new(player))
		elif Input.is_action_just_pressed("yes") and player.can_attack == true:
			#print("IdleState: Detected movement input → switching to AttackState")
			get_parent().change_state(AttackState.new(player))
		elif Input.is_action_just_pressed("no") and player.can_skill == true:
			#print("IdleState: Detected movement input → switching to SkillState")
			get_parent().change_state(SkillState.new(player))
	elif player.player_hit == true:
		#print("IdleState: Detected movement input → switching to HurtState")
		get_parent().change_state(HurtState.new(player))

	#elif Input.is_action_pressed("no"): #hurt hp loss this is later
	#	print("IdleState: Detected movement input → switching to HurtState")
	#	get_parent().change_state(HurtState.new(player))
