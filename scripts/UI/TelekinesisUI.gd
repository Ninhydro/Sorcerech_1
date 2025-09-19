extends CanvasLayer

#No need for this
@onready var object_list = $Control/ObjectList
@onready var preview_sprite = $Control/PreviewSprite
@onready var object_name_label = $Control/ObjectName

var telekinesis_objects: Array = []
var selected_object: TelekinesisObject = null

func _ready():
	visible = false
	# Connect item selection signal
	object_list.item_selected.connect(_on_item_selected)

func show_selector(objects: Array):
	telekinesis_objects = objects
	visible = true
	object_list.clear()
	
	# Populate list with valid objects
	for obj in objects:
		if is_instance_valid(obj) and obj is TelekinesisObject:
			object_list.add_item(obj.get_object_name())
			object_list.set_item_metadata(object_list.get_item_count()-1, obj)
	
	# Select first item if available
	if object_list.get_item_count() > 0:
		object_list.select(0)
		_on_item_selected(0)

func hide_selector():
	visible = false
	if selected_object and is_instance_valid(selected_object):
		selected_object.is_highlighted = false
	selected_object = null

func _on_item_selected(index: int):
	# Remove highlight from previous object
	if selected_object and is_instance_valid(selected_object):
		selected_object.is_highlighted = false
	
	# Get new selected object
	if index < telekinesis_objects.size():
		var obj = telekinesis_objects[index]
		if obj is TelekinesisObject:
			selected_object = obj
			selected_object.is_highlighted = true
			
			# Update UI preview
			preview_sprite.texture = obj.get_object_texture()
			object_name_label.text = obj.get_object_name()

func get_selected_object() -> TelekinesisObject:
	return selected_object
