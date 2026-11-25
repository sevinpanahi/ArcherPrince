
extends CharacterBody2D

@export_group("Movement")
@export var walk_speed: float = 30.0
@export var chase_speed: float = 80.0
@export var patrol_distance: float = 60.0

@export_group("Gravity")
@export var gravity: float = 980.0

@export_group("Detection")
@export var attack_distance: float = 100.0
@export var attack_height_range: float = 100.0

@export_group("Health")
@export var max_health: int = 175

@export_group("Combat")
@export var attack_interval: float = 1.2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var current_health: int
var start_position: Vector2

var moving_right: bool = true
var is_chasing: bool = false
var is_attacking: bool = false
var is_dead: bool = false

var player_ref: Node2D = null
var attack_timer: float = 0.0


func _ready() -> void:
	start_position = global_position
	current_health = max_health

	# DetectionArea settings
	detection_area.monitoring = true
	detection_area.collision_mask = 2

	sprite.flip_h = false
	_play_animation("Walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	_check_detection()

	is_attacking = false

	if is_chasing and is_instance_valid(player_ref):
		_chase_player(delta)
	else:
		_patrol(delta)

	move_and_slide()
	_update_animation()


func _check_detection() -> void:
	var found_player: Node2D = null

	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			found_player = body as Node2D
			break

	if found_player != null:
		if not is_chasing:
			print("Player detected!")

		player_ref = found_player
		is_chasing = true
	else:
		if is_chasing:
			print("Player left detection area!")

		player_ref = null
		is_chasing = false


func _patrol(delta: float) -> void:
	var left_limit := start_position.x - patrol_distance
	var right_limit := start_position.x + patrol_distance

	if global_position.x >= right_limit:
		moving_right = false
	elif global_position.x <= left_limit:
		moving_right = true

	var direction := 1.0 if moving_right else -1.0

	velocity.x = direction * walk_speed

	sprite.flip_h = moving_right


func _chase_player(delta: float) -> void:
	if not is_instance_valid(player_ref):
		velocity.x = 0.0
		return

	var left_limit := start_position.x - patrol_distance
	var right_limit := start_position.x + patrol_distance

	var player_x := player_ref.global_position.x
	var enemy_x := global_position.x

	var distance_x := absf(player_x - enemy_x)
	var distance_y := absf(
		player_ref.global_position.y - global_position.y
	)

	# Face the player
	sprite.flip_h = player_x > enemy_x

	# Attack
	if distance_x <= attack_distance and distance_y <= attack_height_range:
		velocity.x = 0.0
		is_attacking = true
		_attack_player(delta)
		return

	# Never leave patrol boundaries
	var target_x := clampf(player_x, left_limit, right_limit)
	var difference := target_x - enemy_x

	var movement := minf(chase_speed * delta, absf(difference))

	velocity.x = signf(difference) * movement / maxf(delta, 0.001)


func _attack_player(delta: float) -> void:
	attack_timer -= delta

	if attack_timer <= 0.0:
		if is_instance_valid(player_ref):
			if player_ref.has_method("respawn"):
				player_ref.respawn()

		attack_timer = attack_interval


func take_damage(amount: int) -> void:
	if is_dead:
		return

	current_health -= amount
	print("Enemy Health: ", current_health)

	if current_health <= 0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)

	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)

	if _has_anim("Die"):
		sprite.play("Die")
		await sprite.animation_finished

	queue_free()


func _update_animation() -> void:
	if is_dead:
		return

	if is_attacking:
		_play_animation("Attack")
	else:
		_play_animation("Walk")


func _has_anim(anim_name: String) -> bool:
	return (
		sprite.sprite_frames != null
		and sprite.sprite_frames.has_animation(anim_name)
	)


func _play_animation(anim_name: String) -> void:
	if not _has_anim(anim_name):
		return

	if sprite.animation != anim_name or not sprite.is_playing():
		sprite.play(anim_name)


func _on_detection_area_body_entered(body: Node2D) -> void:
	pass


func _on_detection_area_body_exited(body: Node2D) -> void:
	pass
