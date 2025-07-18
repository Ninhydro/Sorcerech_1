# res://scripts/globals/SaveLoadManager.gd
extends Node


const SAVE_DIR = "user://saves/" # This should be consistent
const AUTOSAVE_SLOT_NAME = "autosave"
const MANUAL_SAVE_SLOT_PREFIX = "manual_save_"
const NUM_MANUAL_SAVE_SLOTS = 3

func _ready():
	# Make sure this creates the directory correctly.
	var dir = DirAccess.open("user://")
	if !dir.dir_exists("saves"): # Check for 'saves' subdir
		dir.make_dir("saves")
		print("SaveLoadManager: Created 'user://saves/' directory.")
	else:
		print("SaveLoadManager: 'user://saves/' directory already exists.")

func _get_save_file_path(slot_name: String) -> String:
	var actual_slot_name = slot_name if not slot_name.is_empty() else AUTOSAVE_SLOT_NAME
	return SAVE_DIR + actual_slot_name + ".json"

func save_game(player_node: Player, slot_name: String = "") -> bool:
	var path = _get_save_file_path(slot_name)
	
	# Add more detailed logging before opening the file
	print("SaveLoadManager: Attempting to save to path: {path}")

	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		# Explicitly print the error code if opening fails
		printerr("SaveLoadManager: Failed to open save file for writing at '{path}'. Error: {FileAccess.get_open_error()}")
		return false

	var save_data = {}
	
	var scene_path_to_save = Global.current_scene_path
	
	if scene_path_to_save.is_empty() or not ResourceLoader.exists(scene_path_to_save, "PackedScene"):
		printerr("SaveLoadManager: ERROR: Global.current_scene_path '{scene_path_to_save}' is invalid or empty during save.")
		printerr("SaveLoadManager: Cannot save game with an invalid scene path.")
		file.close()
		return false

	save_data["current_scene_path"] = scene_path_to_save

	var player_data = player_node.get_save_data()
	save_data["player"] = player_data

	save_data["global_game_state"] = Global.get_save_data()
	
	save_data["timestamp"] = Time.get_datetime_string_from_system()

	var json_string = JSON.stringify(save_data, "\t")
	
	# Add debug print for the JSON string content
	print("SaveLoadManager: JSON string to save: \n{json_string}")

	file.store_string(json_string)
	file.close()
	
	print("Game saved successfully to: ", path)
	return true
	
func get_save_slot_info(slot_name: String = "") -> Dictionary:
	var path = _get_save_file_path(slot_name)
	var file_exists = FileAccess.file_exists(path)
	
	# More verbose logging
	if not file_exists:
		print("SaveLoadManager: get_save_slot_info: No file found at '{path}'.")
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("SaveLoadManager: get_save_slot_info: Failed to open file '{path}' for reading. Error: {FileAccess.get_open_error()}")
		return {}
	
	var content = file.get_as_text()
	file.close()
	
	# Add debug print for file content
	print("SaveLoadManager: get_save_slot_info: Content of '{path}':\n{content}")

	var json_parse_result = JSON.parse_string(content)
	if json_parse_result is Dictionary:
		return json_parse_result
	else:
		# Add specific error message from JSON parser
		printerr("SaveLoadManager: Failed to parse JSON from save file: '{path}'. JSON Error: {JSON.get_last_error_message()}")
		return {}

func any_save_exists() -> bool:
	var autosave_path = _get_save_file_path(AUTOSAVE_SLOT_NAME)
	if FileAccess.file_exists(autosave_path):
		return true
	
	for i in range(1, NUM_MANUAL_SAVE_SLOTS + 1):
		var manual_slot_path = _get_save_file_path(MANUAL_SAVE_SLOT_PREFIX + str(i))
		if FileAccess.file_exists(manual_slot_path):
			return true
			
	return false
	
func load_game(slot_name: String = "") -> Dictionary:
	var loaded_data = {}
	var file_path = _get_save_file_path(slot_name)

	if not FileAccess.file_exists(file_path):
		print("No save game found at: ", file_path)
		return loaded_data

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var parse_result = JSON.parse_string(json_string)
		if parse_result is Dictionary:
			loaded_data = parse_result
			print("Game loaded successfully from: ", file_path)

			var global_state_data = loaded_data.get("global_game_state", {})
			Global.apply_load_data(global_state_data)
			
			Global.current_loaded_player_data = loaded_data.get("player", {})
			Global.current_scene_path = loaded_data.get("current_scene_path", "")
			
			return loaded_data
		else:
			print("Error parsing save file: Invalid JSON in '", file_path, "'.")
			return {}
	else:
		print("Error loading game: Could not open file '", file_path, "' for reading.")
		return {}

func delete_save_game():
	printerr("SaveLoadManager: 'delete_save_game()' is deprecated. Use 'delete_save_slot()' instead.")
	return false

func delete_save_slot(slot_name: String = "") -> bool:
	var file_path = _get_save_file_path(slot_name)

	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open(SAVE_DIR)
		if dir:
			dir.remove(file_path)
			print("Deleted save file: ", file_path)
			return true
		else:
			printerr("Error deleting save file: Could not open directory '", SAVE_DIR, "'.")
			return false
	else:
		print("No save file to delete at: ", file_path)
		return false
