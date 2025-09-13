extends CanvasLayer
# Assume this CanvasLayer has a ColorRect child named "FadeRect" covering the screen, initially invisible or alpha 0.

@onready var fade_rect = $FadeRect

func _ready():
	if fade_rect == null:
		push_error("FadeRect not found! Check your TransitionManager scene!")
	fade_rect.modulate.a = 0.0
	fade_rect.visible = false
	fade_rect.anchors_preset = Control.PRESET_FULL_RECT
	#fade_rect.visible = true
	#fade_rect.color = Color(0,0,0,1)


func travel_to(player: Node2D, target_room_name: String, target_spawn_name: String) -> void:
	# 1. Fade out
	#print("traveling")
	player.set_physics_process(false)
	fade_rect.visible = true
	var tween_out = get_tree().create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT) # Faster fade
	#tween_out.tween_property(fade_rect, "modulate:a", 1.0, 1)  # fade to black over 0.5s
	# This is the corrected line: bind the arguments to the Callable object
	fade_rect.color = Color(0,0,0,1)
	var teleport_callable = Callable(self, "_teleport_and_fade_in").bind(player, target_room_name, target_spawn_name)
	tween_out.tween_callback(teleport_callable)
	
	await tween_out.finished
	#fade_rect.color = Color(0,0,0,1)
	
# This function is called by the tween when the screen is fully black
func _teleport_and_fade_in(player: Node2D, target_room_name: String, target_spawn_name: String):
	
	# 2. Teleport the player
	# The screen is now completely black, so this happens instantly and unseen.
	var world = get_tree().get_current_scene()
	var target_room = world.get_node(target_room_name)
	var spawn_points = target_room.get_node("SpawnPoints")
	var spawn_marker = spawn_points.get_node(target_spawn_name) as Marker2D
	
	player.global_position = spawn_marker.global_position
	
	# Optional: Reset player velocity to prevent momentum from old room
	player.velocity = Vector2.ZERO
	
	# Unpause the player's physics process
	player.set_physics_process(true)

	# 3. Fade back in
	var tween_in = get_tree().create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	await tween_in.finished
	
	# Hide the rect when the fade is complete
	fade_rect.visible = false
	
	player.set_physics_process(true)

