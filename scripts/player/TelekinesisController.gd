### TelekinesisController.gd (Godot 4 compatible) ###

extends Node2D

#var telekinesis_enabled = false
#var selector_open = false
#var held_object: RigidBody2D = null
#var nearby_objects: Array = []

#var current_selection_index = -1
#var selection_method = "radial"  # "ui", "direct", or "radial"

#@onready var telekinesis_ui  = $TelekinesisUI  # Path to your ItemList UI

@onready var player: Player = get_parent() as Player 
#var current_highlighted_object: TelekinesisObject = null
#var current_magic_spot: MagusSpot = null
var available_objects: Array = []
var selected_index := 0
@export var is_ui_open := false
var current_object: TelekinesisObject = null
#@onready var magic_spot: Area2D = get_node("../MagicSpot")
@onready var telekinesis_ui: =  $TelekinesisUI #magic_spot.get_node("UI_TelekinesisSelector")
#@onready var magic_spot: Area2D = get_node("../MagucSpot")
var once = false
var lock_object = false

var _object_original_materials: Dictionary = {} 
var _current_highlight_material: ShaderMaterial


func _ready():
	# Load the shader from your .gdshader file and assign it to the material
	#_current_highlight_material = ShaderMaterial.new()
	#_current_highlight_material.shader = Global.highlight_shader
	#outline_material = Global.highlight_material
	_current_highlight_material = Global.create_highlight_material()
	#_current_highlight_material.shader = Global.highlight_shader
	print("Using global highlight material")

func _process(delta):
	if player.telekinesis_enabled == true and once == false and not Global.teleporting:
		print("magus spot?")
		if not is_ui_open :
			open_telekinesis_ui()
			once = true
		elif is_ui_open:
			close_telekinesis_ui()
	elif player.telekinesis_enabled == false:
		close_telekinesis_ui()


	if is_ui_open:
		update_selection()
		handle_ui_navigation()
		#print("open UI")
		#print(current_object)
		if Input.is_action_pressed("yes") and current_object:
			lock_object = true
			current_object.update_levitation(global_position)
			print("Telekinesis1")

	#if Input.is_action_just_pressed("yes") and is_ui_open:
	#	print("Telekinesis2")
	#	if available_objects.size() > 0:
	#		print("Telekinesis3")
	#		current_object = available_objects[selected_index]
	#		current_object.start_levitation(global_position)

		if Input.is_action_just_released("yes") and current_object:
			lock_object = false
			print("Telekinesis4")
			if current_object:
				current_object.stop_levitation()
				current_object = null
			#current_object.stop_levitation()
			#current_object = null
			close_telekinesis_ui()
			Global.telekinesis_mode = false
			

#func is_inside_magic_spot() -> bool:
#	return magic_spot.overlaps_body(self)

func open_telekinesis_ui():
	if player.current_magic_spot:
		available_objects = player.current_magic_spot.get_nearby_telekinesis_objects() 
		print("Found objects: ", available_objects)
		if available_objects.size() == 0: return
		is_ui_open = true
		selected_index = 0
		
		# CREATE the material here, when we actually need it
		if not _current_highlight_material:
			_current_highlight_material = ShaderMaterial.new()
			_current_highlight_material.shader = Global.highlight_shader
			print("Telekinesis: Highlight material created")
		
		update_ui_highlight()
		print("open ui")


func close_telekinesis_ui():
	# First, remove the highlight material from ALL objects
	 # Restore original materials to all objects
	for obj in _object_original_materials:
		if is_instance_valid(obj):
			var sprite = obj.get_node_or_null("Sprite2D")
			if sprite and sprite.material == _current_highlight_material:
				sprite.material = _object_original_materials[obj]
	
	_object_original_materials.clear()
	available_objects.clear()
	selected_index = 0
	
	# DON'T free the material - keep it in memory for next use
	# The material will be automatically freed when this node is destroyed
	
	is_ui_open = false
	once = false
	player.telekinesis_enabled = false
	Global.telekinesis_mode = false
	#print("Telekinesis UI closed, material kept in memory")

func handle_ui_navigation():
	if Input.is_action_just_pressed("move_right") && lock_object == false:
		selected_index = (selected_index + 1) % available_objects.size()
		update_ui_highlight()
	elif Input.is_action_just_pressed("move_left") && lock_object == false:
		selected_index = (selected_index - 1 + available_objects.size()) % available_objects.size()
		update_ui_highlight()

func update_ui_highlight():
	#print("=== DEBUGGING OUTLINE MATERIAL ===")
	
	# Now apply the material
	for i in range(available_objects.size()):
		var obj = available_objects[i]
		if not is_instance_valid(obj):
			continue
			
		var sprite = obj.get_node("Sprite2D")
		if sprite:
				# Store the object's original material if we haven't already
				if not _object_original_materials.has(obj):
					_object_original_materials[obj] = sprite.material
				
				if i == selected_index:
					sprite.material = _current_highlight_material
					print("Applied outline material to object ", i)
				else:
					# Restore original material for non-selected objects
					sprite.material = _object_original_materials[obj]



	
func update_selection():
	if available_objects.size() == 0:
		current_object = null
		return

	# Clamp index if needed
	selected_index = clamp(selected_index, 0, available_objects.size() - 1)
	current_object = available_objects[selected_index]
	#print("Current object set to: ", current_object)

func create_test_material() -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	void fragment() {
		COLOR = vec4(1.0, 0.0, 0.0, 1.0); // Solid red
	}
	"""
	var material = ShaderMaterial.new()
	material.shader = shader
	return material




