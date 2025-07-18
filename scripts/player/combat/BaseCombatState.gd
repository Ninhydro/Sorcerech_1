# BaseCombatState.gd
extends Node
class_name CombatState

var fsm: CombatFSM
var player

func _init(_player):
	player = _player
	#print("CombatState: _init with", player)
	
func enter():
	pass

func exit():
	pass

func physics_update(delta):
	pass
