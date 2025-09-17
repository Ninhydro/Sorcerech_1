# res://scripts/ui/pause_menu.gd
extends CanvasLayer

@onready var background_dimmer = $BackgroundDimmer
@onready var menu_panel = $MenuPanel
@onready var profile_button = $MenuPanel/ButtonContainer/ProfileButton
@onready var save_button = $MenuPanel/ButtonContainer/SaveButton
@onready var load_button = $MenuPanel/ButtonContainer/LoadButton
@onready var option_button = $MenuPanel/ButtonContainer/OptionButton
@onready var back_to_title_button = $MenuPanel/ButtonContainer/BackTitleButton

@onready var confirmation_dialog_back_to_title = $ConfirmationDialog # Reference to the dialog

@export var save_game_menu_scene: PackedScene
@export var load_game_menu_scene: PackedScene
@export var option_menu_scene: PackedScene
@export var profile_scene: PackedScene 

var is_closing: bool = false

func _ready():
	print("PauseMenu _ready() called! Current paused state on entry: ", get_tree().paused)

	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	option_button.pressed.connect(_on_option_button_pressed)
	back_to_title_button.pressed.connect(_on_back_to_title_button_pressed)
	profile_button.pressed.connect(_on_profile_button_pressed)

	# Connect signals for the confirmation dialog.
	# We will connect 'canceled' with Callable.bind() to make sure it only
	# reacts AFTER the dialog has been purposefully shown.
	confirmation_dialog_back_to_title.confirmed.connect(_on_confirmation_dialog_back_to_title_confirmed)
	# Important: Do NOT connect 'canceled' here if it's causing an immediate trigger.
	# We will connect it dynamically when popup_centered() is called.
	
	profile_button.grab_focus()

	get_tree().paused = true
	print("PauseMenu: Game paused. Paused state now: ", get_tree().paused)
	# The input event that opened the menu should be handled by the *instantiating* script (e.g., World.gd)
	# If it's not, you'll still have the issue of _unhandled_input being called immediately.
	# So, ensure `get_viewport().set_input_as_handled()` is in the script that opens PauseMenu.

func _unhandled_input(event: InputEvent):
	if is_closing:
		return
		
	if event.is_action_pressed("menu"):
		print("PauseMenu: 'menu' action pressed")
		if confirmation_dialog_back_to_title.visible:
			confirmation_dialog_back_to_title.hide()
			if confirmation_dialog_back_to_title.canceled.is_connected(_on_confirmation_dialog_back_to_title_canceled):
				confirmation_dialog_back_to_title.canceled.disconnect(_on_confirmation_dialog_back_to_title_canceled)
			back_to_title_button.grab_focus()
		else:
			_close_menu()
		get_viewport().set_input_as_handled()
	
	elif event.is_action_pressed("no"):
		print("PauseMenu: 'no' action pressed")
		
		# CONSUME THE INPUT FIRST
		get_viewport().set_input_as_handled()
		
		# Set global flag BEFORE processing to prevent ability activation
		Global.ignore_player_input_after_unpause = true
		Global.unpause_cooldown_timer = Global.UNPAUSE_COOLDOWN_DURATION
		
		if confirmation_dialog_back_to_title.visible:
			confirmation_dialog_back_to_title.hide()
			if confirmation_dialog_back_to_title.canceled.is_connected(_on_confirmation_dialog_back_to_title_canceled):
				confirmation_dialog_back_to_title.canceled.disconnect(_on_confirmation_dialog_back_to_title_canceled)
			back_to_title_button.grab_focus()
		else:
			_close_menu()

func _close_menu():
	if is_closing:
		return
	is_closing = true
	
	print("PauseMenu: _close_menu() called. Unpausing game.")
	
	# Set global flag BEFORE unpausing to catch the input
	Global.ignore_player_input_after_unpause = true
	Global.unpause_cooldown_timer = Global.UNPAUSE_COOLDOWN_DURATION
	print("Global: Unpause cooldown started for ", Global.UNPAUSE_COOLDOWN_DURATION, " seconds")
	
	get_tree().paused = false
	print("PauseMenu: Game unpaused. Paused state now: ", get_tree().paused)

	var parent_node = get_parent()
	if parent_node and parent_node.has_method("_set_main_menu_buttons_enabled"):
		parent_node._set_main_menu_buttons_enabled(true)

	queue_free()
	print("PauseMenu: Queue_free() called.")

func _on_save_button_pressed():
	print("PauseMenu: Opening Save Menu...")
	var save_menu_instance = save_game_menu_scene.instantiate()
	add_child(save_menu_instance)
	menu_panel.hide()
	background_dimmer.hide()
	print("PauseMenu: Save Menu opened. Game should still be paused: ", get_tree().paused)

func _on_load_button_pressed():
	print("PauseMenu: Opening Load Menu...")
	var load_menu_instance = load_game_menu_scene.instantiate()
	add_child(load_menu_instance)
	menu_panel.hide()
	background_dimmer.hide()
	print("PauseMenu: Load Menu opened. Game should still be paused: ", get_tree().paused)


func _on_option_button_pressed():
	print("PauseMenu: Opening Option Menu")
	var option_menu_instance = option_menu_scene.instantiate()
	add_child(option_menu_instance)
	menu_panel.hide()
	background_dimmer.hide()
	print("PauseMenu: Option Menu opened. Game should still be paused: ", get_tree().paused)


func _on_back_to_title_button_pressed():
	print("PauseMenu: 'Back to Title' button pressed. Showing confirmation dialog...")
	# Ensure the canceled signal is connected ONLY when we are about to show the dialog
	if not confirmation_dialog_back_to_title.canceled.is_connected(_on_confirmation_dialog_back_to_title_canceled):
		confirmation_dialog_back_to_title.canceled.connect(_on_confirmation_dialog_back_to_title_canceled)
	confirmation_dialog_back_to_title.popup_centered()


func _on_confirmation_dialog_back_to_title_confirmed():
	print("PauseMenu: Player confirmed returning to title.")
	Dialogic.clear()
	Global.camouflage = false
	Global.time_freeze = false
	get_tree().paused = false
	print("PauseMenu: Game unpaused. Paused state now: ", get_tree().paused)

	var main_menu_scene_path = "res://scenes/ui/MainMenu.tscn"
	var main_menu_packed_scene = load(main_menu_scene_path)

	if main_menu_packed_scene:
		get_tree().change_scene_to_packed(main_menu_packed_scene)
		queue_free()
		print("PauseMenu: Scene change initiated to MainMenu, self-freed.")
	else:
		printerr("ERROR: Failed to load Main Menu scene at path: ", main_menu_scene_path)

func _on_confirmation_dialog_back_to_title_canceled():
	print("PauseMenu: Player canceled returning to title.")
	back_to_title_button.grab_focus()
	# Disconnect the signal again after it's handled to prevent re-triggers
	if confirmation_dialog_back_to_title.canceled.is_connected(_on_confirmation_dialog_back_to_title_canceled):
		confirmation_dialog_back_to_title.canceled.disconnect(_on_confirmation_dialog_back_to_title_canceled)


func _on_profile_button_pressed():
	print("PauseMenu: Opening Profile Menu...")
	var profile_scene_instance = profile_scene.instantiate()
	add_child(profile_scene_instance)
	profile_scene_instance.set_parent_menu_reference(self) # Pass reference to self
	menu_panel.hide()
	background_dimmer.hide()
	print("PauseMenu: Profile Menu opened. Game should still be paused: ", get_tree().paused)



func show_pause_menu():
	print("PauseMenu: show_pause_menu() called. Game should still be paused: ", get_tree().paused)
	menu_panel.show()
	background_dimmer.show()
	save_button.grab_focus()
