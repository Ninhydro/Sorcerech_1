extends Area2D

@export var target_scene_path: String = ""
@export var target_position_in_scene: Vector2 = Vector2.ZERO
@export var cutscene_animation_name_to_play: String = "cutscene1"
@export var cutscene_animation_name_after_dialog: String = "cutscene2" # New export for the second animation
@export var play_only_once: bool = true

@onready var animation_player: AnimationPlayer = $AnimationPlayer # This is the AnimationPlayer on the Cutscene Area2D
@onready var cutscene_camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal cutscene_finished(cutscene_name: String)

var _dialogic_active_in_cutscene := false
var _paused_animation_position: float = 0.0
var _animation_to_resume: String = ""
var _has_been_triggered: bool = false
var _dialog_triggered_for_this_cutscene: bool = false
var _waiting_for_dialogic_to_end: bool = false
var _waiting_for_cutscene2_to_end: bool = false

var _player_animation_player: AnimationPlayer = null # Reference to the player's AnimationPlayer

const CUTSCENE_DIALOG_TIMELINE_NAME = "timeline2"
var player_node_ref: Player  = null

func _ready():
	print("Cutscene Area2D: Debug: @onready animation_player resolved to: ", animation_player)
	print("Cutscene Area2D: Debug: @onready cutscene_camera resolved to: ", cutscene_camera)
	if not cutscene_camera:
		printerr("Cutscene Area2D: ERROR: @onready cutscene_camera is null! Check Cutscene_Intro.tscn for Camera2D node directly under its root (named 'Camera2D').")
	print("Cutscene Area2D: Debug: @onready collision_shape resolved to: ", collision_shape)
	if not collision_shape:
		printerr("Cutscene Area2D: ERROR: @onready collision_shape is null! Check Cutscene_Intro.tscn for CollisionShape2D node directly under its root (named 'CollisionShape2D').")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if animation_player:
		animation_player.animation_finished.connect(_on_animation_finished)
	else:
		printerr("Cutscene Area2D: ERROR: AnimationPlayer is null! Animation related features will not work.")

	#if not Dialogic.dialog_started.is_connected(Callable(self, "_on_dialogic_started_in_cutscene")):
#		Dialogic.dialog_started.connect(Callable(self, "_on_dialogic_started_in_cutscene"))
#	if not Dialogic.dialog_ended.is_connected(Callable(self, "_on_dialogic_ended_in_cutscene")):
#		Dialogic.dialog_ended.connect(Callable(self, "_on_dialogic_ended_in_cutscene"))

	# REMOVE THESE LINES:
	# if cutscene_camera and is_instance_valid(cutscene_camera):
	# 	cutscene_camera.enabled = false
	# 	cutscene_camera.set_process_mode(Node.PROCESS_MODE_DISABLED)
	# 	print("Cutscene Area2D: Cutscene camera explicitly set to not current and disabled in _ready.")

	# NEW: Instead of disabling it, ensure it's not current if it somehow became current in editor
	if cutscene_camera and is_instance_valid(cutscene_camera) and cutscene_camera.is_current():
		cutscene_camera.set_current(false)
		print("Cutscene Area2D: Cutscene camera explicitly set to not current in _ready.")


	print("Cutscene Area2D is ready. Waiting for player interaction.")

func _on_body_entered(body: Node2D):
	print("Player position: ",player_node_ref.global_position)
	if (body.is_in_group("player") and not _has_been_triggered) and Global.cutscene_finished1 == false:
		print("Player entered cutscene trigger area. Starting cutscene.")

		if collision_shape:
			collision_shape.set_deferred("disabled", true)
		else:
			printerr("Cutscene Area2D: WARNING: CollisionShape2D is null, cannot disable it. Using Area2D monitoring instead.")
			set_deferred("monitorable", false)
			set_deferred("monitoring", false)

		start_cutscene(cutscene_animation_name_to_play, 0.0)

		if play_only_once:
			_has_been_triggered = true

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		print("Player exited cutscene trigger area.")

func start_cutscene(cutscene_animation_name: String, start_position: float):
	print("Cutscene Area2D: Starting cutscene '%s' from position %s" % [cutscene_animation_name, start_position])

	Global.is_cutscene_active = true
	Global.cutscene_name = cutscene_animation_name
	Global.cutscene_playback_position = start_position

	if Global.playerBody and is_instance_valid(Global.playerBody):
		_player_animation_player = Global.playerBody.get_node_or_null("AnimationPlayer")
		if _player_animation_player and is_instance_valid(_player_animation_player):
			print("Cutscene Area2D: Found player's AnimationPlayer.")
			if _player_animation_player.has_animation("idle"):
				_player_animation_player.play("idle")
				print("Cutscene Area2D: Player set to 'idle' animation.")
		else:
			printerr("Cutscene Area2D: WARNING: Player's AnimationPlayer not found or invalid! Cannot control player animations.")
	else:
		printerr("Cutscene Area2D: WARNING: Global.playerBody is null or invalid! Cannot control player animations.")

	_dialog_triggered_for_this_cutscene = false
	_waiting_for_dialogic_to_end = false
	_waiting_for_cutscene2_to_end = false

	if get_tree().current_scene.has_method("switch_to_cutscene_camera"):
		if cutscene_camera and is_instance_valid(cutscene_camera):
			# Use is_current() to check the status
			print("Cutscene Area2D: Debug: cutscene_camera is_current() BEFORE switch: ", cutscene_camera.is_current())
			print("Cutscene Area2D: Debug: cutscene_camera enabled BEFORE switch: ", cutscene_camera.enabled)
			print("Cutscene Area2D: Debug: cutscene_camera process_mode BEFORE switch: ", cutscene_camera.get_process_mode())
			# Call the World.gd function which now uses make_current()
			get_tree().current_scene.switch_to_cutscene_camera(cutscene_camera)
		else:
			printerr("Cutscene Area2D: WARNING: cutscene_camera is null or invalid when attempting to switch to it.")
	else:
		printerr("Cutscene Area2D: WARNING: World scene does not have 'switch_to_cutscene_camera' method for camera control.")

	if animation_player:
		animation_player.play(cutscene_animation_name)
		animation_player.seek(start_position, true)
		print("Cutscene Area2D: Animation '%s' started playing." % cutscene_animation_name)
	else:
		printerr("Cutscene Area2D: ERROR: AnimationPlayer is null! Cannot play cutscene animation.")
		end_cutscene(cutscene_animation_name)

func _start_dialogic_from_animation():
	print("Cutscene Area2D: AnimationPlayer called _start_dialogic_from_animation. Preparing Dialogic.")

	if _dialog_triggered_for_this_cutscene:
		print("Cutscene Area2D: Dialog already triggered for this cutscene. Ignoring re-trigger from animation.")
		return

	if animation_player and animation_player.current_animation:
		_paused_animation_position = animation_player.current_animation_position
		_animation_to_resume = animation_player.current_animation
		animation_player.pause()
		print("Cutscene Area2D: Animation paused at _start_dialogic_from_animation call, position: %s" % _paused_animation_position)
		print("Cutscene Area2D: Stored animation to resume: '%s'" % _animation_to_resume)
	else:
		printerr("WARNING: AnimationPlayer or current_animation is null. Cannot pause animation.")
		_paused_animation_position = 0.0
		_animation_to_resume = ""

	Dialogic.start(CUTSCENE_DIALOG_TIMELINE_NAME, false)
	_dialog_triggered_for_this_cutscene = true
	_waiting_for_dialogic_to_end = true
	#Dialogic.Portraits.change_portrait("Player", "Normal_Sad")


func _on_dialogic_started_in_cutscene(dialog_timeline_name_passed: String = ""):
	print("Cutscene Area2D: _on_dialogic_started_in_cutscene called!")
	print("Cutscene Area2D: Debug: dialog_timeline_name_passed = '%s' (expected '%s')" % [dialog_timeline_name_passed, CUTSCENE_DIALOG_TIMELINE_NAME])
	print("Cutscene Area2D: Debug: Global.is_cutscene_active = %s" % Global.is_cutscene_active)

	if Global.is_cutscene_active and (dialog_timeline_name_passed == CUTSCENE_DIALOG_TIMELINE_NAME or dialog_timeline_name_passed == ""):
		print("Cutscene Area2D: Specific cutscene Dialogic started. Confirming animation is paused.")
		_dialogic_active_in_cutscene = true

		if animation_player and not animation_player.is_playing():
			print("Cutscene Area2D: AnimationPlayer is correctly paused for dialog.")
		else:
			printerr("WARNING: AnimationPlayer was not paused when Dialogic started (or was already playing)! Current playing state: %s" % (animation_player.is_playing() if animation_player else "N/A"))
			if animation_player:
				printerr("WARNING: Current animation: %s" % animation_player.current_animation)
	else:
		print("Cutscene Area2D: Dialogic started for a different timeline or not in cutscene. Ignoring. Reason:")
		print("  - Global.is_cutscene_active is false OR dialog_timeline_name_passed mismatch.")


func _on_dialogic_ended_in_cutscene(dialog_timeline_name_passed: String = ""):
	print("Cutscene Area2D: _on_dialogic_ended_in_cutscene called!")
	
	if Global.is_cutscene_active and _waiting_for_dialogic_to_end:
		print("Cutscene Area2D: Specific cutscene Dialogic ended. Cleaning up...")
		_dialogic_active_in_cutscene = false
		_waiting_for_dialogic_to_end = false
		
		# PROPER CLEANUP - Add this line
		Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
		
	print("Cutscene Area2D: _on_dialogic_ended_in_cutscene called!")
	print("Cutscene Area2D: Debug: dialog_timeline_name_passed = '%s' (expected '%s')" % [dialog_timeline_name_passed, CUTSCENE_DIALOG_TIMELINE_NAME])
	print("Cutscene Area2D: Debug: Global.is_cutscene_active = %s" % Global.is_cutscene_active)

	if Global.is_cutscene_active and _waiting_for_dialogic_to_end and (dialog_timeline_name_passed == CUTSCENE_DIALOG_TIMELINE_NAME or dialog_timeline_name_passed == ""):
		print("Cutscene Area2D: Specific cutscene Dialogic ended. Attempting to resume animation or play next.")
		_dialogic_active_in_cutscene = false
		_waiting_for_dialogic_to_end = false

		if animation_player and not cutscene_animation_name_after_dialog.is_empty():
			animation_player.play(cutscene_animation_name_after_dialog)
			print("Cutscene Area2D: Playing second cutscene animation: '%s'" % cutscene_animation_name_after_dialog)
			_waiting_for_cutscene2_to_end = true
		elif animation_player and not _animation_to_resume.is_empty():
			animation_player.seek(_paused_animation_position, true)
			animation_player.play(_animation_to_resume)
			print("Cutscene Area2D: Animation resumed successfully from position: %s using animation '%s'" % [_paused_animation_position, _animation_to_resume])
			_animation_to_resume = ""
		else:
			printerr("WARNING: _on_dialogic_ended_in_cutscene: No second animation to play and no animation stored to resume. Ending cutscene.")
			end_cutscene(Global.cutscene_name)
	else:
		print("Cutscene Area2D: Dialogic ended for a different timeline or not in cutscene/not waiting. Ignoring. Reason:")
		if not Global.is_cutscene_active:
			print("  - Global.is_cutscene_active is false.")
		if not _waiting_for_dialogic_to_end:
			print("  - Not waiting for dialog to end (_waiting_for_dialogic_to_end is false).")
		if dialog_timeline_name_passed != CUTSCENE_DIALOG_TIMELINE_NAME and dialog_timeline_name_passed != "":
			print("  - Dialog timeline mismatch: '%s' vs expected '%s'." % [dialog_timeline_name_passed, CUTSCENE_DIALOG_TIMELINE_NAME])


func _on_animation_finished(anim_name: String):
	print("Cutscene Area2D: Animation '%s' finished." % anim_name)

	if not Global.is_cutscene_active:
		print("Cutscene Area2D: Animation finished, but Global.is_cutscene_active is false. Ignoring.")
		return

	if anim_name == cutscene_animation_name_to_play:
		if _dialogic_active_in_cutscene:
			print("Cutscene Area2D: WARNING: Animation '%s' finished while Dialogic was active. Forcing Dialogic end." % anim_name)
			Dialogic.end_timeline()
			Dialogic.clear(Dialogic.ClearFlags.FULL_CLEAR)
			_dialogic_active_in_cutscene = false
		else:
			if not _waiting_for_dialogic_to_end and not cutscene_animation_name_after_dialog.is_empty():
				animation_player.play(cutscene_animation_name_after_dialog)
				print("Cutscene Area2D: Playing second cutscene animation '%s' after first animation finished." % cutscene_animation_name_after_dialog)
				_waiting_for_cutscene2_to_end = true
			elif not _waiting_for_dialogic_to_end:
				print("Cutscene Area2D: First animation finished, no dialog, no second animation. Ending cutscene.")
				end_cutscene(anim_name)

	elif anim_name == cutscene_animation_name_after_dialog:
		if _waiting_for_cutscene2_to_end:
			print("Cutscene Area2D: Second animation '%s' finished. Ending cutscene." % anim_name)
			_waiting_for_cutscene2_to_end = false
			end_cutscene(anim_name)
		else:
			print("Cutscene Area2D: Second animation '%s' finished, but not waiting for it. Ignoring." % anim_name)


func end_cutscene(cutscene_name_finished: String):
	print("Cutscene Area2D: Ending cutscene '%s'." % cutscene_name_finished)

	if get_tree().current_scene.has_method("switch_to_player_camera"):
		get_tree().current_scene.switch_to_player_camera() # This will call make_current()
	else:
		printerr("Cutscene Area2D: WARNING: World scene does not have 'switch_to_player_camera' method for camera control.")

	Global.is_cutscene_active = false
	Global.cutscene_name = ""
	Global.cutscene_playback_position = 0.0
	_dialog_triggered_for_this_cutscene = false
	_waiting_for_dialogic_to_end = false
	_waiting_for_cutscene2_to_end = false

	if Dialogic.dialog_started.is_connected(Callable(self, "_on_dialogic_started_in_cutscene")):
		Dialogic.dialog_started.disconnect(Callable(self, "_on_dialogic_started_in_cutscene"))
	if Dialogic.dialog_ended.is_connected(Callable(self, "_on_dialogic_ended_in_cutscene")):
		Dialogic.dialog_ended.disconnect(Callable(self, "_on_dialogic_ended_in_cutscene"))

	cutscene_finished.emit(cutscene_name_finished)
	# NEW: Call proxy to enable player input
	proxy_enable_player_input_after_cutscene()
	
	if Global.playerBody and is_instance_valid(Global.playerBody):
		Global.playerBody.visible = true
		if Global.playerBody.has_method("enable_input"):
			Global.playerBody.enable_input()
		elif Global.playerBody.has_method("set_input_enabled"):
			Global.playerBody.set_input_enabled(true)
		else:
			Global.playerBody.set_process(true)
			Global.playerBody.set_physics_process(true)

		if _player_animation_player and is_instance_valid(_player_animation_player):
			if _player_animation_player.has_animation("idle"):
				_player_animation_player.play("idle")
				print("Cutscene Area2D: Player animation reset to 'idle'.")

	if collision_shape:
		collision_shape.set_deferred("disabled", false)

	if not play_only_once:
		set_deferred("monitorable", true)
		set_deferred("monitoring", true)
	else:
		set_deferred("monitorable", false)
		set_deferred("monitoring", false)

	if not target_scene_path.is_empty():
		print("Cutscene Area2D: Teleporting player to %s at %s" % [target_scene_path, target_position_in_scene])
		Global.playerBody.global_position = target_position_in_scene
	
	Global.cutscene_finished1 = true

# NEW: Function to set player reference (called from World.gd)
func set_player_reference(player: Player):
	if is_instance_valid(player):
		player_node_ref = player
		print("player_node_ref",player_node_ref)
		print("Test_dialog: Player reference received: ", player_node_ref.name)
	else:
		printerr("Test_dialog: Received invalid player reference!")

# NEW: Proxy methods for AnimationPlayer to call methods on the Player node
# These methods are on Test_dialog.gd, and *they* call the actual methods on player_node_ref

func proxy_disable_player_input_for_cutscene():
	if player_node_ref and is_instance_valid(player_node_ref):
		# --- NEW DIAGNOSTIC PRINTS ---
		print(str("DEBUG FROM TEST_DIALOG: player_node_ref actual type: ", player_node_ref.get_class()))
		print(str("DEBUG FROM TEST_DIALOG: player_node_ref script path: ", player_node_ref.get_script().resource_path if player_node_ref.get_script() else "NO SCRIPT ATTACHED!"))
		print(str("DEBUG FROM TEST_DIALOG: player_node_ref has 'Player' class_name: ", player_node_ref is Player))
		print(str("DEBUG FROM TEST_DIALOG: player_node_ref has method 'disable_player_input_for_cutscene': ", player_node_ref.has_method("disable_player_input_for_cutscene")))
		# --- END NEW DIAGNOSTIC PRINTS ---

		player_node_ref.disable_player_input_for_cutscene()
	else:
		printerr("Test_dialog: Cannot disable player input, player_node_ref is invalid!")

func proxy_move_player_to_position(target_pos: Vector2, duration: float, ease_type_int: int, trans_type_int: int):
	if player_node_ref and is_instance_valid(player_node_ref):
		# CORRECTED: Pass the raw integers. The implicit conversion will happen
		# when player_node_ref.move_player_to_position receives them,
		# because that function's signature is now correctly type-hinted with enums.
		player_node_ref.move_player_to_position(target_pos, duration, ease_type_int, trans_type_int)
	else:
		printerr("Test_dialog: Cannot move player, player_node_ref is invalid!")

func proxy_set_player_cutscene_velocity(direction_x: float, direction_y: float, speed_multiplier: float = 1.0):
	if player_node_ref and is_instance_valid(player_node_ref):
		player_node_ref.set_player_cutscene_velocity(Vector2(direction_x, direction_y), speed_multiplier)
	else:
		printerr("Test_dialog: Cannot set player velocity, player_node_ref is invalid!")

func proxy_play_player_visual_animation(anim_name: String):
	if player_node_ref and is_instance_valid(player_node_ref):
		player_node_ref.play_player_visual_animation(anim_name)
	else:
		printerr("Test_dialog: Cannot play player animation, player_node_ref is invalid!")

func proxy_set_player_face_direction(direction: int):
	if player_node_ref and is_instance_valid(player_node_ref):
		player_node_ref.set_player_face_direction(direction)
	else:
		printerr("Test_dialog: Cannot set player face direction, player_node_ref is invalid!")

func proxy_enable_player_input_after_cutscene():
	if player_node_ref and is_instance_valid(player_node_ref):
		player_node_ref.enable_player_input_after_cutscene()
	else:
		printerr("Test_dialog: Cannot enable player input, player_node_ref is invalid!")

