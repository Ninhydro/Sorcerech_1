extends CanvasLayer 

@onready var new_game_button = $UIContainer/ButtonContainer/NewGameButton
@onready var load_game_button = $UIContainer/ButtonContainer/ContinueButton 
@onready var option_button = $UIContainer/ButtonContainer/OptionButton 
@onready var exit_button = $UIContainer/ButtonContainer/ExitButton 

#@onready var background_dimmer = $BackgroundDimmer # NEW: Reference to the dimmer

@export var main_game_scene: PackedScene = preload("res://scenes/world/World.tscn")
@export var cutscene_scene: PackedScene = preload("res://scenes/world/cutscene_manager.tscn")
@export var load_game_menu_scene: PackedScene = preload("res://scenes/ui/load_game_menu.tscn") # Make sure this path is correct!

func _ready():
	new_game_button.pressed.connect(_on_new_game_button_pressed)
	load_game_button.pressed.connect(_on_continue_button_pressed) 
	option_button.pressed.connect(_on_option_button_pressed) 
	exit_button.pressed.connect(_on_exit_button_pressed) 

	new_game_button.grab_focus()

	new_game_button.gui_input.connect(_on_new_game_button_gui_input)

	# Check if any save game exists to enable/disable the Load Game button
	if SaveLoadManager.any_save_exists(): # Using the helper function from SaveLoadManager
		load_game_button.disabled = false
	else:
		load_game_button.disabled = true
		print("No save files found, 'Load Game' button disabled.")
	
	#background_dimmer.hide()
	
func _on_new_game_button_pressed():
	#SaveLoadManager.delete_save_game() 
	print("Starting a New Game.")
	Global.play_intro_cutscene = true
	get_tree().change_scene_to_packed(main_game_scene)

func _on_continue_button_pressed():
	print("Opening Load Game Menu (as a pop-up).")
	# Instance the new load game menu scene
	#background_dimmer.show()
	var load_menu_instance = load_game_menu_scene.instantiate()
	# Add it as a child to THIS MainMenu scene, making it appear on top
	add_child(load_menu_instance) 
	# Optionally, disable main menu buttons while popup is open to prevent interaction
	_set_main_menu_buttons_enabled(false)


# NEW HELPER FUNCTION: To enable/disable main menu buttons
func _set_main_menu_buttons_enabled(enable: bool):
	new_game_button.disabled = !enable
	load_game_button.disabled = !enable if SaveLoadManager.any_save_exists() else true # Re-check load button state
	option_button.disabled = !enable
	exit_button.disabled = !enable
	new_game_button.grab_focus()


func _on_option_button_pressed():
	print("Opening option menu")

func _on_exit_button_pressed():
	get_tree().quit()

func _on_new_game_button_gui_input(event: InputEvent):
	print("GUI INPUT RECEIVED ON NEW GAME BUTTON: ", event)
	if event is InputEventMouseButton:
		print("DEBUG: Mouse Button event on NewGameButton: ", event)
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			print("DEBUG: Left mouse button PRESSED on NewGameButton!")
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			print("DEBUG: Left mouse button RELEASED on NewGameButton!")
	elif event is InputEventMouseMotion:
		pass
		
		
