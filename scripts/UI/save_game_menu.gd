# res://scripts/ui/save_game_menu.gd
extends CanvasLayer

@onready var slot_buttons_container = $Panel/VBoxContainer/Slots
@onready var back_button = $Panel/VBoxContainer/BackButton

var slot_buttons: Array[Button] = []

# --- NEW: Flag to control manual saving to autosave slot ---
const ALLOW_MANUAL_SAVE_TO_AUTOSAVE_SLOT = false # Set to 'true' if you want to allow it
# --- END NEW ---

func _ready():
	print("SaveGameMenu _ready() called! Current paused state: ", get_tree().paused)
	back_button.pressed.connect(_on_back_button_pressed)
	_populate_save_slots()

	set_process_unhandled_input(true)
	
	if !slot_buttons.is_empty():
		slot_buttons[0].grab_focus()
	else:
		back_button.grab_focus()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		print("SaveGameMenu: ESC pressed. Current paused state: ", get_tree().paused)
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

func _populate_save_slots():
	for child in slot_buttons_container.get_children():
		child.queue_free()
	slot_buttons.clear()

	# When calling for Autosave, slot_name_to_save is "" (empty string)
	_add_slot_button("Autosave", "") 

	for i in range(1, SaveLoadManager.NUM_MANUAL_SAVE_SLOTS + 1):
		var slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + str(i)
		_add_slot_button("Save Slot " + str(i), slot_name)

	if !slot_buttons.is_empty():
		slot_buttons[0].grab_focus()


func _add_slot_button(button_text: String, slot_name_to_save: String):
	var button = Button.new()
	button.text = button_text
	button.flat = false

	var slot_info = SaveLoadManager.get_save_slot_info(slot_name_to_save)
	var timestamp_text = "Empty Slot"
	
	if not slot_info.is_empty():
		var timestamp_string = slot_info.get("timestamp", "")
		if not timestamp_string.is_empty():
			var datetime = _parse_timestamp(timestamp_string)
			
			if datetime != null:
				timestamp_text = "%02d/%02d/%d %02d:%02d" % [datetime["month"], datetime["day"], datetime["year"], datetime["hour"], datetime["minute"]]
			else:
				timestamp_text = "Invalid Date Format"
		else:
			timestamp_text = "No Timestamp Saved"
	
	# --- MODIFIED: Disable autosave button for manual saving ---
	if slot_name_to_save == "" and not ALLOW_MANUAL_SAVE_TO_AUTOSAVE_SLOT: # It's the autosave slot and we don't allow manual saving to it
		button.disabled = true
		button.text = "Autosave" # Clear text for disabled state
		# Optional: Add the timestamp info below the disabled text if desired
		button.text += "\n(" + timestamp_text + ")"
		# Optional: Gray out the button more visually
		# button.modulate = Color(0.7, 0.7, 0.7, 1.0)
	else:
		# For all other slots (or if autosave manual saving is allowed)
		button.disabled = false # Ensure manual slots are enabled by default if they have data
		button.text += "\n(" + timestamp_text + ")"
	# --- END MODIFIED ---
	
	button.pressed.connect(Callable(self, "_on_save_slot_button_pressed").bind(slot_name_to_save))
	
	slot_buttons_container.add_child(button)
	slot_buttons.append(button)

func _parse_timestamp(timestamp: String) -> Dictionary:
	var parts = timestamp.split("T")
	if parts.size() != 2:
		parts = timestamp.split(" ")
		if parts.size() != 2:
			return {}
	var date_parts = parts[0].split("-")
	var time_parts = parts[1].split(":")
	if time_parts.size() < 3: # Handle cases where seconds might be missing or optional
		time_parts.append("00") # Add a default for seconds if missing
	if date_parts.size() < 3 or time_parts.size() < 2: # Check for at least hour and minute
		return {}
	return {
		"year": date_parts[0].to_int(),
		"month": date_parts[1].to_int(),
		"day": date_parts[2].to_int(),
		"hour": time_parts[0].to_int(),
		"minute": time_parts[1].to_int(),
		"second": time_parts[2].to_int()
	}

func _on_save_slot_button_pressed(slot_name: String):
	# --- NEW: Safety check to prevent saving to autosave slot manually ---
	if slot_name == "" and not ALLOW_MANUAL_SAVE_TO_AUTOSAVE_SLOT:
		print("SaveGameMenu: Attempted to manually save to the disabled Autosave slot. Operation blocked.")
		return # Block the save operation
	# --- END NEW ---

	print("SaveGameMenu: Attempting to save game to slot: ", slot_name if not slot_name.is_empty() else "Autosave")
	
	# Get a reference to the Player node.
	# Assuming your Player node is in the "player" group:
	var player_node = get_tree().get_first_node_in_group("player")
	
	if player_node == null:
		printerr("SaveGameMenu: ERROR: Player node not found in 'player' group. Cannot save game.")
		# You might want to show a message to the user here
		return # Stop the function if player is not found

	var save_successful = SaveLoadManager.save_game(player_node, slot_name) # Pass player_node as the first argument
	
	if save_successful:
		print("SaveGameMenu: Game successfully saved to ", slot_name if not slot_name.is_empty() else "Autosave")
		_populate_save_slots() # Refresh the list to show new timestamp
		back_button.grab_focus()
	else:
		printerr("SaveGameMenu: Failed to save game to ", slot_name if not slot_name.is_empty() else "Autosave")


func _on_back_button_pressed():
	print("SaveGameMenu: Closing Save Game Menu pop-up. Telling parent PauseMenu to show.")
	
	var parent_node = get_parent()
	
	if parent_node and parent_node.has_method("show_pause_menu"):
		parent_node.show_pause_menu()
	else:
		printerr("SaveGameMenu: Parent is not PauseMenu or lacks show_pause_menu method.")
		
	queue_free()
