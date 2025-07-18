extends CanvasLayer
# Assume this CanvasLayer has a ColorRect child named "FadeRect" covering the screen, initially invisible or alpha 0.

@onready var fade_rect := $FadeRect

func _ready():
	if fade_rect == null:
		push_error("FadeRect not found! Check your TransitionManager scene!")

func travel_to(player: Node2D, target_room_name: String, target_spawn_name: String) -> void:
	# 1. Fade out
	fade_rect.visible = true
	var tween_out = get_tree().create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.5)  # fade to black over 0.5s
	await tween_out.finished  # wait until fade-out is complete&#8203;:contentReference[oaicite:6]{index=6}

	# 2. Teleport player to target room & spawn
	var world = get_tree().get_current_scene()             # the main World scene
	var target_room = world.get_node(target_room_name)     # find the target room node by name
	var spawn_points = target_room.get_node("SpawnPoints") # the container of spawn markers in that room
	var spawn_marker = spawn_points.get_node(target_spawn_name) as Marker2D
	player.global_position = spawn_marker.global_position  # move player to the spawn point&#8203;:contentReference[oaicite:7]{index=7}

	# Optionally, adjust camera limits or position here if using Camera2D so that the new room is centered.

	# 3. Fade back in
	var tween_in = get_tree().create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.5)  # fade from black to transparent
	await tween_in.finished  # wait for fade-in to complete
	fade_rect.visible = false

