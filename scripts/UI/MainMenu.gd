extends CanvasLayer 

@onready var new_game_button = $UIContainer/ButtonContainer/NewGameButton
@onready var load_game_button = $UIContainer/ButtonContainer/ContinueButton 
@onready var option_button = $UIContainer/ButtonContainer/OptionButton 
@onready var exit_button = $UIContainer/ButtonContainer/ExitButton 

#@onready var background_dimmer = $BackgroundDimmer # NEW: Reference to the dimmer

@export var main_game_scene: PackedScene = preload("res://scenes/world/World.tscn")
@export var cutscene_scene: PackedScene = preload("res://scenes/world/cutscene_intro.tscn")
@export var load_game_menu_scene: PackedScene = preload("res://scenes/ui/load_game_menu.tscn") # Make sure this path is correct!
@export var option_menu_scene: PackedScene = preload("res://scenes/ui/option_menu.tscn") #

@onready var confirmation_dialog_exit_game = $ConfirmationDialog # Adjust path if it's nested

#Object needed in world/room
#1. player, npcs, enemies
#2. cyber canon spot & bounce wall
#3. magus teleport/telekinesis spot & lock check
#4. grappling hook spot
#5. cutscene, etc

func _ready():
	get_viewport().gui_embed_subwindows = false
	await get_tree().process_frame
	#get_viewport().window.grab_focus()
	
	set_process_input(true)
	set_process_unhandled_input(true)
	
	new_game_button.pressed.connect(_on_new_game_button_pressed)
	load_game_button.pressed.connect(_on_continue_button_pressed) 
	option_button.pressed.connect(_on_option_button_pressed) 
	exit_button.pressed.connect(_on_exit_button_pressed) 
	
	 # --- Connect the Confirmation Dialog's signals ---
	confirmation_dialog_exit_game.confirmed.connect(_on_confirmation_dialog_exit_game_confirmed)
	confirmation_dialog_exit_game.canceled.connect(_on_confirmation_dialog_exit_game_canceled) # Optional


	_set_main_menu_buttons_enabled(true) # Ensure buttons are enabled on start
	print("grabbing.......................")

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
func _set_main_menu_buttons_enabled(enabled: bool):
	# Implement this to enable/disable your MainMenu buttons
	# Example:
	# $VBoxContainer/NewGameButton.disabled = not enabled
	# $VBoxContainer/LoadGameButton.disabled = not enabled
	# $VBoxContainer/OptionsButton.disabled = not enabled
	# $VBoxContainer/ExitButton.disabled = not enabled
	print("MainMenu: Buttons enabled state set to: " + str(enabled))


func _on_option_button_pressed():
	print("MainMenu: Opening Options Menu...")
	var options_menu_instance = option_menu_scene.instantiate()
	get_tree().root.add_child(options_menu_instance) # Add to root so it's on top
	# --- THIS IS THE CRITICAL LINE TO CHECK ---
	options_menu_instance.set_parent_menu_reference(self) # Pass reference to MainMenu itself
	# --- END CRITICAL LINE ---
	_set_main_menu_buttons_enabled(false) # Disable MainMenu buttons while Options is open



func _on_new_game_button_gui_input(event: InputEvent):
	#print("GUI INPUT RECEIVED ON NEW GAME BUTTON: ", event)
	if event is InputEventMouseButton:
		print("DEBUG: Mouse Button event on NewGameButton: ", event)
		if event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
			print("DEBUG: Left mouse button PRESSED on NewGameButton!")
		elif event.button_index == MOUSE_BUTTON_LEFT and event.is_released():
			print("DEBUG: Left mouse button RELEASED on NewGameButton!")
	elif event is InputEventMouseMotion:
		pass
		
		
# --- NEW: Callback for when the Exit Button is pressed ---
func _on_exit_button_pressed():
	print("MainMenu: Exit button pressed. Showing exit confirmation dialog.")
	confirmation_dialog_exit_game.popup_centered()


# --- NEW: Callback for when the Exit Confirmation Dialog is CONFIRMED ---
func _on_confirmation_dialog_exit_game_confirmed():
	print("MainMenu: Player confirmed exit. Quitting game.")
	get_tree().quit() # This is the action to exit the game


# --- NEW: Callback for when the Exit Confirmation Dialog is CANCELED (Optional) ---
func _on_confirmation_dialog_exit_game_canceled():
	print("MainMenu: Player canceled exit.")
	exit_button.grab_focus() # Good UX: refocus the exit button
	
func show_pause_menu():
	#print("MainMenu: show_pause_menu() called. Game should still be paused: ", get_tree().paused)
	new_game_button.grab_focus()
	
