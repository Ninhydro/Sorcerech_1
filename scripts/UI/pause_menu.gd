# res://scripts/ui/pause_menu.gd
extends CanvasLayer

@onready var background_dimmer = $BackgroundDimmer
@onready var menu_panel = $MenuPanel
@onready var save_button = $MenuPanel/ButtonContainer/SaveButton
@onready var load_button = $MenuPanel/ButtonContainer/LoadButton
@onready var option_button = $MenuPanel/ButtonContainer/OptionButton
@onready var back_to_title_button = $MenuPanel/ButtonContainer/BackTitleButton
@onready var exit_button = $MenuPanel/ButtonContainer/ExitButton

@export var save_game_menu_scene: PackedScene
@export var load_game_menu_scene: PackedScene = preload("res://scenes/ui/load_game_menu.tscn")

# Remove this line: var _active_dialogic_node_on_pause: Node = null # Not needed in this reverted version

func _ready():
	print("PauseMenu _ready() called! Current paused state on entry: ", get_tree().paused)
	#Dialogic.Text.hide_textbox()
	# Removed Dialogic handling here. Will re-add after save/load is stable.

	save_button.pressed.connect(_on_save_button_pressed)
	load_button.pressed.connect(_on_load_button_pressed)
	option_button.pressed.connect(_on_option_button_pressed)
	back_to_title_button.pressed.connect(_on_back_to_title_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

	save_button.grab_focus()

	get_tree().paused = true
	print("PauseMenu: Game paused. Paused state now: ", get_tree().paused)


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		print("PauseMenu: ESC pressed. Current paused state: ", get_tree().paused)
		_close_menu()
		get_viewport().set_input_as_handled()

func _close_menu():
	print("PauseMenu: _close_menu() called. Unpausing game.")
	get_tree().paused = false
	print("PauseMenu: Game unpaused. Paused state now: ", get_tree().paused)
	
	var parent_node = get_parent()
	if parent_node and parent_node.has_method("_set_main_menu_buttons_enabled"):
		parent_node._set_main_menu_buttons_enabled(true)

	queue_free()
	print("PauseMenu: Queue_free() called.")
	#Dialogic.Text.show_textbox()

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
	print("PauseMenu: Opening Option Menu (Placeholder)...")


func _on_back_to_title_button_pressed():
	print("PauseMenu: Returning to Title Screen via load()...")
	
	# Removed Dialogic handling here. Will re-add after save/load is stable.
	Dialogic.clear()
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

func _on_exit_button_pressed():
	print("PauseMenu: Exiting Game...")
	get_tree().quit()

func show_pause_menu():
	print("PauseMenu: show_pause_menu() called. Game should still be paused: ", get_tree().paused)
	menu_panel.show()
	background_dimmer.show()
	save_button.grab_focus()
