# Enemy.gd
extends CharacterBody2D

class_name EnemyA
 
@export var speed := 20
@export var attack_range := 30
@export var attack_damage := 10
@export var attack_cooldown := 1.5

#@onready var player := get_node("/root/World/Player/Player") # Adjust path
@onready var animation_player := $AnimationPlayer
#@onready var attack_timer := $AttackTimer
@onready var direction_timer := $DirectionTimer
@onready var hitbox := $Hitbox
@onready var sprite := $Sprite2D

var player: CharacterBody2D
var player_in_area = false

const gravity  = 1000.0 

var is_enemy_chase: bool = true

var health = 100
var health_max = 100
var health_min = 0

var dead: bool = false
var taking_damage: bool = false 
var damage_to_deal = 20
var is_dealing_damage: bool = false

var dir: Vector2
var knockback_force = -20
var is_roaming: bool = true

@onready var attackcoll  :=  $DealAttackArea/CollisionShape2D
#@export var health := 3
#@onready var hitbox_area := $HitboxArea  # your Area2D node to detect being hit
#signal attack_frame 

# NEW: Add these variables
var attack_target: Node2D = null
var attack_timer: Timer
var attack_active := false

var range = false

func _ready():
	#attack_area.connect("body_entered", Callable(self, "_on_attack_area_body_entered"))
	#health.damaged.connect(_on_damaged)
	#health.died.connect(_on_died)
	#animation_player.connect("animation_finished", self, "_on_animation_finished")
	#animation_player.connect("frame_changed", self, "_on_frame_changed")
	attack_timer = Timer.new()
	attack_timer.wait_time = 0.5  # Check every 0.5 seconds
	attack_timer.one_shot = false
	add_child(attack_timer)
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	
func _process(delta):
	#if player == null or health.current_hp <= 0:
	#	return
	#print(Global.playerDamageZone.monitoring)
	#var distance = global_position.distance_to(player.global_position)
	
	if !is_on_floor():
		velocity.y += gravity*delta
		velocity.x = 0
	
	Global.enemyADamageAmount = damage_to_deal
	Global.enemyADamageZone = $DealAttackArea
	player = Global.playerBody
	
	#print(is_enemy_chase)
	if Global.playerAlive and not Global.camouflage and range:
		is_enemy_chase = true
	else:
		is_enemy_chase = false
	
	#print(is_enemy_chase)
	move(delta)
	handle_animation()
	move_and_slide()
	
	#if distance > attack_range:
	#	var direction = (player.global_position - global_position).normalized()
	#	velocity.x = direction.x * speed
	#	velocity.y += gravity * delta
	#	move_and_slide()
	#else:
	#	velocity = Vector2.ZERO
	#	if not attack_timer.is_stopped():
	#		attack()

func move(delta):
	if dead:
		velocity.x = 0
		return
	
	# Prioritize states: dead, taking_damage, is_dealing_damage, then chase/roam
	if taking_damage:
		# Apply knockback
		var knockback_dir = (global_position - player.global_position).normalized() # Knockback away from player
		velocity.x = knockback_dir.x * abs(knockback_force) # Use abs to ensure positive force
		is_roaming = false # Not roaming when taking damage
		return
		
	if is_dealing_damage:
		velocity.x = 0 # Stop movement during attack animation
		is_roaming = false # Not roaming when attacking
		return
		
	if is_enemy_chase:
		is_roaming = false # <-- SET TO FALSE WHEN CHASING
		var dir_to_player = (player.global_position - global_position).normalized()
		velocity.x = dir_to_player.x * speed
		dir.x = sign(velocity.x) # Update dir for facing animation
	else:
		is_roaming = true # <-- SET TO TRUE WHEN ROAMING
		# Use 'dir' from _on_direction_timer_timeout
		velocity.x = dir.x * speed # Directly set velocity.x for roaming
		# If roaming and standing still, might need to prevent velocity accumulation
		if velocity.x == 0 and dir.x != 0: # This means direction timer might have set a new dir, but velocity is zero
			velocity.x = dir.x * speed # Ensure movement starts if dir changes while velocity was zero

		#print("dead")
		
			

func handle_animation():
	if !dead and !taking_damage and  !is_dealing_damage:
		animation_player.play("run")
		if dir.x == -1:
			sprite.flip_h = true
		elif dir.x == 1:
			sprite.flip_h = false
		#attackcoll.disabled = true
		Global.enemyAdealing = false
	elif !dead and taking_damage and !is_dealing_damage:
		animation_player.play("hurt")
		await get_tree().create_timer(0.5).timeout
		taking_damage = false
		#attackcoll.disabled = true
		Global.enemyAdealing = false
	elif dead and is_roaming:
		is_roaming = false
		animation_player.play("death")
		await get_tree().create_timer(1.0).timeout
		handle_death()
		#attackcoll.disabled = true
		Global.enemyAdealing = false
	elif !dead and is_dealing_damage:
		#attackcoll.disabled = false
		animation_player.play("attack")
		
		#Global.camouflage == false
		

	#attack_timer.start(attack_cooldown)


#func apply_damage(amount):
#	health.take_damage(amount)
#	print("apply damage")
	
#func _on_damaged(amount):
#	animation_player.play("hurt")
#	print("on damaged")

func handle_death():
	self.queue_free()


#func _on_attack_area_body_entered(body):
	#if animation_player.current_animation == "attack" and body.has_method("apply_damage"):
	#	body.apply_damage(attack_damage)
#	if body.name == "Player":
#		print(">> Enemy was touched by player:", body.name)
#		body.apply_damage(10)
		# Optional: you could use this for player contact damage
		# But ideally only AttackArea triggers damage		
	
func choose(array):
	array.shuffle()
	return array.front()


func _on_direction_timer_timeout():
	direction_timer.wait_time = choose([1.5,2.0,2.5])
	if !is_enemy_chase:
		dir = choose([Vector2.RIGHT, Vector2.LEFT])
		velocity.x = 0


func _on_hitbox_area_entered(area):
	var damage = Global.playerDamageAmount
	#print(Global.playerDamageZone.monitoring)
	#print(Global.playerDamageZone)
	#if Global.playerDamageZone.monitoring == true:
		#print("1!!!!!!!!!!!!!!!")
	if area == Global.playerDamageZone:
		#if Global.playerDamageZone.monitoring == true:
			#print(Global.playerDamageZone.monitoring)
			#print("damage")
			take_damage(damage)

func take_damage(damage):
	health -= damage
	taking_damage = true
	if health <= health_min:
		health = health_min
		dead = true
	print(str(self), "current health:", health)
		

		

#func _on_deal_attack_area_area_entered(area):
	#if area == Global.playerHitbox:  # Replace with function body.
	#	is_dealing_damage = true
	#	await get_tree().create_timer(1.0).timeout
	#	is_dealing_damage = false
#	if area == Global.playerHitbox: #and animation_player.current_animation == "attack":
#		is_dealing_damage = true
		#Global.playerBody.take_damage(damage_to_deal)
#		await get_tree().create_timer(1.0).timeout
#		is_dealing_damage = false



func _on_animation_player_animation_finished(anim_name):
	pass # Replace with function body.
	
func attack_frame():
	Global.enemyAdealing = true
	var knockback_dir = (Global.playerBody.global_position - global_position).normalized()
	Global.enemyAknockback = knockback_dir * 100.0  # You can adjust force here
	
func _on_deal_attack_area_area_entered(area):
	if area == Global.playerHitbox and attack_target == null and Global.camouflage == false:
		attack_target = area.get_parent()
		print("Player entered attack range")
		attack_active = true
		attack_timer.start()  # Start checking for attacks

func _on_deal_attack_area_area_exited(area):
	if area == Global.playerHitbox and attack_target != null and Global.camouflage == false:
		print("Player left attack range")
		attack_target = null
		attack_active = false
		attack_timer.stop()   # Stop attack checks

func _on_attack_timer_timeout():
	if attack_active and attack_target != null and Global.playerAlive:
		# Calculate distance to player
		var distance = global_position.distance_to(attack_target.global_position)
		
		# Only attack if player is within range
		if distance <= attack_range:
			is_dealing_damage = true
			print("Attacking player")
			await get_tree().create_timer(0.3).timeout  # Attack animation delay
			attack_frame()  # Trigger damage
			await get_tree().create_timer(0.2).timeout
			is_dealing_damage = false
		else:
			# Player moved out of range
			attack_active = false
			attack_target = null



func _on_range_chase_body_entered(body):
	if body.name == "Player":
		range = true


func _on_range_chase_body_exited(body):
	if body.name == "Player":
		range = false
