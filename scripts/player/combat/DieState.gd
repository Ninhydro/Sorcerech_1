extends CombatState
class_name DieState

# Called when the node enters the scene tree for the first time.
func enter():
	#print("die")
	var form = player.get_current_form_id()
	
	match form:
		"Magus":
			#player.anim_sprite.play("magus_attack")
			# You could also spawn a fireball or magic effect here
			#print("Magus die")
			player.anim_state.travel("die_magus")
		"Cyber":
			#player.anim_sprite.play("cyber_slash")
			# Maybe activate grapple or combo effects
			#print("Cyber die")
			player.anim_state.travel("die_cyber")
		"UltimateMagus":
			#player.anim_sprite.play("ultimate_magus_blast")
			# Big AoE logic here
			#print("Ultimate Magus die")
			player.anim_state.travel("die_ult_magus")
		"UltimateCyber":
			#player.anim_sprite.play("ultimate_cyber_strike")
			# Laser or time freeze here
			#print("Ultimate Cyber die")
			player.anim_state.travel("die_ult_cyber")
		"Normal":
			#player.anim_sprite.play("normal_attack")
			#print("Normal die")
			player.anim_state.travel("die_normal")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func physics_update(delta):
	pass
