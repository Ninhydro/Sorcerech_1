extends Area2D

@export var accepted_id := "A"  # Set this to the ID you want to detect ("A", "B", etc.)

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body):
	if body is TelekinesisObject:
		print("something entered bucket/lock")
		if body.object_id == accepted_id:
			print("Object A is inside the bucket!")
		else:
			print("Wrong object entered: ", body.object_id)

func _on_body_exited(body):
	if body is TelekinesisObject and body.object_id == accepted_id:
		print("Object A was removed from the bucket.")
