extends Area2D
class_name Fireball

@export var speed = 150.0 # How fast the fireball travels
@export var damage = 20   # How much damage the fireball deals
@export var lifetime = 0.5 # How long the fireball exists before despawning (seconds)

var direction = Vector2.RIGHT # Initial direction, will be set by the player

func _ready():
	# Connect the body_entered signal to handle collisions
	body_entered.connect(_on_body_entered)

	# Set up the lifetime timer
	$Timer.wait_time = lifetime
	$Timer.one_shot = true # The timer will only run once
	$Timer.start() # Start the timer
	$Timer.timeout.connect(_on_lifetime_timeout) # Connect the timeout signal

	# Optionally, flip the sprite if the initial direction is left
	# This assumes your fireball sprite is oriented to the right by default
	if direction.x < 0:
		$Sprite2D.flip_h = true

func _physics_process(delta):
	# Move the fireball in its set direction
	position += direction * speed * delta

func _on_body_entered(body: Node2D):
	# Check if the collided body has a "take_damage" method (e.g., an enemy)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	# Destroy the fireball upon hitting anything to prevent multiple hits
	queue_free()

func _on_lifetime_timeout():
	# Destroy the fireball if its lifetime expires without hitting anything
	queue_free()

func set_direction(dir: Vector2):
	# Set the direction for the fireball
	direction = dir.normalized() # Ensure it's a unit vector
	# Adjust sprite orientation if needed (e.g., if you have a directional sprite)
	if direction.x < 0:
		$Sprite2D.flip_h = true
	else:
		$Sprite2D.flip_h = false
