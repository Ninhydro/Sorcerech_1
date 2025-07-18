# Health.gd
extends Node

signal died
signal damaged(amount)

@export var max_hp: int = 100
@export var current_hp: int

func _ready():
	current_hp = max_hp

func take_damage(amount: int):
	current_hp -= amount
	emit_signal("damaged", amount)
	if current_hp <= 0:
		current_hp = 0
		emit_signal("died")
