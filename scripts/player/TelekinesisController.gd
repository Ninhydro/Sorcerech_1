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
@onready var outline_material = ShaderMaterial.new()  # Create empty material


func _ready():
	# Load the shader from your .gdshader file and assign it to the material
	outline_material = Global.highlight_material
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
			current_object.stop_levitation()
			current_object = null
			close_telekinesis_ui()
			Global.telekinesis_mode = false
			

#func is_inside_magic_spot() -> bool:
#	return magic_spot.overlaps_body(self)

func open_telekinesis_ui():
	if player.current_magic_spot:
		#available_objects = player.current_magic_spot.get_nearby_telekinesis_objects()
		print("Magic spot: ", player.current_magic_spot)
		available_objects = player.current_magic_spot.get_nearby_telekinesis_objects() 
		print("Found objects: ", available_objects)
		if available_objects.size() == 0: return
		is_ui_open = true
		selected_index = 0
		update_ui_highlight()
		#telekinesis_ui.visible = true
		print("open ui")


func close_telekinesis_ui():
	for obj in available_objects:
		if is_instance_valid(obj):
			var sprite = obj.get_node("Sprite2D")
			if sprite:
				# Just remove material reference, don't modify the shader
				sprite.material = null
	
	selected_index = 0
	current_object = null
	available_objects.clear()
	is_ui_open = false
	player.telekinesis_enabled = false
	once = false
	
	update_ui_highlight()
	#print("close ui")

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
		if not sprite:
			continue
			
		if i == selected_index:
			sprite.material = outline_material
			print("Applied outline material to object ", i)
		else:
			sprite.material = null



	
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




