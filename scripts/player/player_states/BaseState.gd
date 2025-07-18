extends Node
class_name BaseState

var player: CharacterBody2D  # Or use your Player.gd class_name if you declared one

func _init(p):
	player = p

func enter() -> void:
	# Called when this state becomes active
	pass

func exit() -> void:
	# Called when this state is exited
	pass

func physics_process(_delta: float) -> void:
	# Called every frame from Player.gd
	pass

func handle_input(_event: InputEvent) -> void:
	# Called when player receives input
	pass
