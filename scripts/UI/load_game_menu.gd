# res://scripts/ui/load_game_menu.gd
extends CanvasLayer

@onready var slot_buttons_container = $Panel/VBoxContainer/Slots
@onready var back_button = $Panel/VBoxContainer/BackButton

var slot_buttons: Array[Button] = []

signal closed # NEW: Signal to indicate the menu is closing


func _ready():
	
	print("LoadGameMenu _ready() called! Current paused state: ", get_tree().paused)
	back_button.pressed.connect(_on_back_button_pressed)
	_populate_save_slots()
	set_process_unhandled_input(true)
	
	if !slot_buttons.is_empty():
		slot_buttons[0].grab_focus()

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("menu") or event.is_action_pressed("no"):
		print("LoadGameMenu: ESC pressed. Current paused state: ", get_tree().paused)
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()

func _populate_save_slots():
	for child in slot_buttons_container.get_children():
		child.queue_free()
	slot_buttons.clear()

	_add_slot_button("Autosave", "")
	for i in range(1, SaveLoadManager.NUM_MANUAL_SAVE_SLOTS + 1):
		var slot_name = SaveLoadManager.MANUAL_SAVE_SLOT_PREFIX + str(i)
		_add_slot_button("Save Slot " + str(i), slot_name)

	if !slot_buttons.is_empty():
		slot_buttons[0].grab_focus()

func _add_slot_button(button_text: String, slot_name_to_load: String):
	var button = Button.new()
	button.text = button_text
	button.flat = false
	
	# --- MODIFIED: Set custom minimum size and size flags for smaller buttons ---
	# For a 320px wide window, 180px width is more reasonable.
	# Height of 40-50px should accommodate two lines of text with a small font.
	button.set_custom_minimum_size(Vector2(240, 10)) # Adjusted size for 4 buttons
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER # Center horizontally
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER # Center vertically
	# --- END MODIFIED ---

	# --- MODIFIED: Create a custom theme for the button to control font size ---
	var button_theme = Theme.new()
	var font_size = 10 # Adjust this value (e.g., 8, 10, 12) for desired text size
	
	# Try to get the default font from the project or a parent theme
	var default_font: Font = slot_buttons_container.get_theme_font("font") 
	if default_font == null:
		default_font = ProjectSettings.get_setting("gui/theme/default_font") # Fallback to project default
	
	if default_font:
		# Set the font for the "Button" type within this custom theme
		button_theme.set_font("font", "Button", default_font)
		# Set the font size for the "Button" type within this custom theme
		button_theme.set_font_size("font_size", "Button", font_size) # Directly set font size on theme
		print("LoadGameMenu: Applied custom font size " + str(font_size) + " to button: " + button_text)
	else:
		printerr("LoadGameMenu: No default font found. Button font size might not change.")
		# As a fallback for SystemFont or missing FontFile, you can try setting a dynamic font
		# if you have one preloaded or available. However, direct size control on SystemFont is limited.
	
	button.theme = button_theme
	# --- END MODIFIED ---
	
	var slot_info = SaveLoadManager.get_save_slot_info(slot_name_to_load)
	var timestamp_text = "Empty"
	
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
		button.disabled = false
	else:
		button.disabled = true

	button.text += "\n(" + timestamp_text + ")"
	button.pressed.connect(Callable(self, "_on_save_slot_button_pressed").bind(slot_name_to_load))
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
	if date_parts.size() < 3 or time_parts.size() < 3:
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
	print("LoadGameMenu: Loading game from slot: %s" % (slot_name if not slot_name.is_empty() else "Autosave"))
	var loaded_data = SaveLoadManager.load_game(slot_name)
	
	if not loaded_data.is_empty():
		var saved_scene_path = Global.current_scene_path
		
		if ResourceLoader.exists(saved_scene_path, "PackedScene"):
			print("LoadGameMenu: Game loaded. Unpausing and changing scene to: %s" % saved_scene_path)
			get_tree().paused = false # Unpause the game BEFORE changing scene
			
			# --- CRITICAL FIX START ---
			# Defer the scene change to avoid trying to access parent after scene tree is gone.
			get_tree().change_scene_to_file.call_deferred(saved_scene_path)
			
			# Queue free THIS menu instance immediately. It has done its job.
			# DO NOT attempt to interact with any old scene nodes (like parent_node) after this point,
			# as they will be freed when the new scene loads.
			queue_free()
			print("LoadGameMenu: Self-freed after initiating deferred scene change.")
			# --- CRITICAL FIX END ---

		else:
			printerr("LoadGameMenu: Error: Target scene path for loaded slot is invalid or does not exist: %s" % saved_scene_path)
			# If load fails due to invalid path, clear loaded data from Global
			Global.current_loaded_player_data = {}
			Global.current_game_state_data = {}
			Global.current_scene_path = ""
			# Do NOT queue_free here if loading failed, let user try again.
	else:
		print("LoadGameMenu: Failed to load game from slot: %s" % (slot_name if not slot_name.is_empty() else "Autosave"))
		# If load fails, clear loaded data from Global
		Global.current_loaded_player_data = {}
		Global.current_game_state_data = {}
		Global.current_scene_path = ""
		# Do NOT queue_free here if loading failed, let user try again.

func _on_back_button_pressed():
	print("LoadGameMenu: Closing Load Game Menu pop-up.")
	
	var parent_node = get_parent()
	
	if is_instance_valid(parent_node):
		if parent_node.has_method("show_pause_menu"):
			print("LoadGameMenu: Parent is PauseMenu. Telling it to show.")
			parent_node.show_pause_menu()
		elif parent_node.has_method("_set_main_menu_buttons_enabled"):
			print("LoadGameMenu: Parent is MainMenu. Re-enabling its buttons.")
			parent_node._set_main_menu_buttons_enabled(true)
		#else:
		#	printerr("LoadGameMenu: Unknown parent type when closing. Cannot notify parent.")
	else:
		print("LoadGameMenu: Parent node is no longer valid. Cannot notify.")
	
	emit_signal("closed") # Emit the signal
	
	queue_free()
