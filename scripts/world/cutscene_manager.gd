extends Node
#Cutscene intro, this is CGs
@onready var black_overlay = $BlackOverlay
@onready var timer = $Timer # This timer is used for holding the black screen, if needed.

signal cutscene_finished

# Removed junkyard_spawn_path from here, as World.gd handles player spawning now.

func _ready():
	# Ensure the black overlay is fully transparent at start of scene, ready for activation.
	# Its visibility will be handled by start_cutscene().
	black_overlay.modulate.a = 0.0
	black_overlay.visible = false # Ensure it's hidden initially

	# No need for await get_tree().process_frame here, as start_cutscene handles visibility.

func start_cutscene():
	print("CutsceneManager: Cutscene started. Setting overlay to opaque.")
	# Make sure it's visible and fully opaque for the start of the cutscene.
	# This should cover the screen before any dialog appears.
	black_overlay.modulate.a = 1.0
	black_overlay.visible = true

	# Connect signal BEFORE starting timeline to ensure it's ready.
	# It's good practice to disconnect/reconnect if you call start_cutscene multiple times
	# to prevent multiple connections.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)
	Dialogic.timeline_ended.connect(_on_dialogic_finished)

	# Start your dialog timeline.
	Dialogic.start("timeline1", false)


func _on_dialogic_finished(_timeline_name = ""):
	print("CutsceneManager: Dialogic timeline finished. Initiating fade out.")
	# Dialog is done. Now, fade out the black screen.

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(black_overlay, "modulate:a", 0.0, 0.1) # Fade out in 1 second
	tween.tween_callback(Callable(self, "_on_cutscene_end"))
	
	Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
	
	# Disconnect the signal to prevent unintended calls.
	if Dialogic.timeline_ended.is_connected(_on_dialogic_finished):
		Dialogic.timeline_ended.disconnect(_on_dialogic_finished)


func _on_cutscene_end():
	print("CutsceneManager: All cutscene visuals finished. Emitting signal.")
	black_overlay.visible = false # Ensure it's hidden after fade out

	# Emit the signal that the entire cutscene (dialog + fades) is complete.
	emit_signal("cutscene_finished")
