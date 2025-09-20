# CombatFSM.gd# CombatFSM.gd
extends Node
class_name CombatFSM

const IdleState = preload("res://scripts/player/combat/IdleState.gd")
const HurtState = preload("res://scripts/player/combat/HurtState.gd")


var player
var current_state: CombatState

func _init(_player):
	player = _player
	#print("CombatFSM: _init")

func _ready():
	#change_state(IdleState.new(player))
	var state = IdleState.new(player)
	#print("Created state:", state)
	change_state(state)
	
	#player.health.damaged.connect(_on_damaged)

func change_state(new_state: CombatState):
	#print("CombatFSM: change_state start")
	if current_state:
		current_state.exit()
		if current_state.get_parent():
			current_state.get_parent().remove_child(current_state)
			current_state.queue_free()  # or free() depending on your architecture

	#print("CombatFSM: Switching to", new_state)
	current_state = new_state
	add_child(current_state)
	current_state.enter()
	#print("CombatFSM: change_state end")

func update_physics(delta):
	if current_state:
		current_state.physics_update(delta)
		
func physics_update(delta):
	# Your state's per-frame logic goes here
	pass
	
#func _on_damaged(amount):
	#animation_player.play("hurt")
#	change_state(HurtState.new(player))
#	print("Player is hurt")

