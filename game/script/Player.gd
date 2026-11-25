extends CharacterBody2D

@export_group("Movement")
@export var walk_speed: float = 100.0
@export var run_speed: float = 500.0
@export var acceleration: float = 2000.0
@export var friction: float = 2500.0
@export var air_control: float = 0.6

@export_group("Jump")
@export var jump_velocity: float = -450.0
@export var double_jump_velocity: float = -450.0
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1200.0
@export var variable_jump_cut: float = 0.5
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.12
@export var jump_vfx_offset: Vector2 = Vector2(0, 16)

@export_group("Combat")
@export var slash_cooldown: float = 0.4
@export var slash_hitbox_time: float = 0.15
@export var invincible_time: float = 1.0

@export_group("Respawn")
@export var fall_distance: float = 800.0
@export var drop_through_time: float = 0.25

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var slash_hitbox: Area2D = get_node_or_null("SlashHitbox")
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var shoot_place: Node2D = $shoot_place
const BULLET_SCENE: PackedScene = preload("res://game/Scene/bullet.tscn")

var start_position: Vector2
var fall_limit_y: float
var is_attacking: bool = false
var is_shooting: bool = false
var shoot_cooldown: float = 0.3
var _shoot_cooldown_timer: float = 0.0
var is_invincible: bool = false

var jumps_left: int = 2
var _jump_held_last: bool = false
var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _drop_held_last: bool = false
var _dropping_through: bool = false
var _slash_cooldown_timer: float = 0.0
var _last_move_dir: float = 1.0
var _tired_timer: float = 0.0

var _was_on_floor_last_frame: bool = false

func _ready() -> void:
	start_position = global_position
	fall_limit_y = start_position.y + fall_distance
	if slash_hitbox:
		slash_hitbox.monitoring = false
	print("READY OK - start=", start_position)

func _physics_process(delta: float) -> void:
	_slash_cooldown_timer = max(_slash_cooldown_timer - delta, 0.0)
	_tired_timer = max(_tired_timer - delta, 0.0)
	_shoot_cooldown_timer = max(_shoot_cooldown_timer - delta, 0.0)

	move_and_slide()

	if is_on_floor() and not _was_on_floor_last_frame:
		play_land_VFX(Vector2(0, 16))

	_was_on_floor_last_frame = is_on_floor()

	var direction := _get_move_direction()
	if direction != 0.0:
		_last_move_dir = direction

	var running := _is_run_pressed() and direction != 0.0
	var jump_just := _jump_pressed_this_frame()
	var jump_held := _is_jump_held()
	var drop_just := _drop_pressed_this_frame()

	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

	var target_speed := (run_speed if running else walk_speed) * direction
	var accel := acceleration if direction != 0.0 else friction
	if not is_on_floor():
		accel *= air_control
	velocity.x = move_toward(velocity.x, target_speed, accel * delta)

	if is_on_floor():
		_coyote_timer = coyote_time
		jumps_left = 2
	else:
		_coyote_timer = max(_coyote_timer - delta, 0.0)

	if jump_just:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0:
		if is_on_floor() or _coyote_timer > 0.0:
			velocity.y = jump_velocity
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
			jumps_left = 1
		elif jumps_left > 0:
			velocity.y = double_jump_velocity
			_jump_buffer_timer = 0.0
			jumps_left -= 1

	if not jump_held and velocity.y < 0.0:
		velocity.y *= variable_jump_cut
		if velocity.y < -50.0:
			velocity.y = max(velocity.y, -50.0)

	if drop_just and is_on_floor() and not _dropping_through:
		_drop_through_platform()

	if _is_attack_pressed() and not is_attacking and _slash_cooldown_timer <= 0.0:
		perform_slash()

	if Input.is_action_just_pressed("shoot"):
		if not is_shooting and not is_attacking and _shoot_cooldown_timer <= 0.0:
			perform_shoot()

	move_and_slide()

	if global_position.y > fall_limit_y:
		respawn()

	_jump_held_last = jump_held
	_drop_held_last = _is_drop_held()

func _process(_delta: float) -> void:
	if sprite == null or is_attacking or is_shooting:
		return

	var direction := _get_move_direction()
	var running := _is_run_pressed() and direction != 0.0

	if not is_on_floor():
		if velocity.y < 0:
			_play_if_exists("Jump")
		else:
			_play_if_exists("Fall")
		if direction != 0.0:
			sprite.flip_h = direction < 0
	elif direction != 0.0:
		sprite.flip_h = direction < 0
		if running and _has_anim("Run"):
			_play_if_exists("Run")
		else:
			_play_if_exists("Run")
		_tired_timer = 0.0
	else:
		if _tired_timer > 0.0:
			_play_if_exists("Tired")
		else:
			_play_if_exists("Idle")

func _get_move_direction() -> float:
	var dir := 0.0
	if InputMap.has_action("Left") and Input.is_action_pressed("Left"):
		dir -= 1.0
	if InputMap.has_action("Right") and Input.is_action_pressed("Right"):
		dir += 1.0
	if dir == 0.0:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir += 1.0
	return dir

func _is_run_pressed() -> bool:
	if InputMap.has_action("Run") and Input.is_action_pressed("Run"):
		return true
	return Input.is_key_pressed(KEY_SHIFT)

func _is_jump_held() -> bool:
	if InputMap.has_action("Jump") and Input.is_action_pressed("Jump"):
		return true
	return Input.is_key_pressed(KEY_SPACE)

func _jump_pressed_this_frame() -> bool:
	if InputMap.has_action("Jump") and Input.is_action_just_pressed("Jump"):
		play_vfx()
		play_vfx(jump_vfx_offset)
		return true
	var now := _is_jump_held()
	return now and not _jump_held_last

func _is_drop_held() -> bool:
	if InputMap.has_action("Down") and Input.is_action_pressed("Down"):
		return true
	return Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)

func _drop_pressed_this_frame() -> bool:
	if InputMap.has_action("Down") and Input.is_action_just_pressed("Down"):
		return true
	var now := _is_drop_held()
	return now and not _drop_held_last

func _is_attack_pressed() -> bool:
	if InputMap.has_action("Attack") and Input.is_action_just_pressed("Attack"):
		return true
	if Input.is_key_pressed(KEY_F):
		return true
	return false

func _drop_through_platform() -> void:
	_dropping_through = true
	set_collision_mask_value(1, false)
	position.y += 2
	await get_tree().create_timer(drop_through_time).timeout
	set_collision_mask_value(1, true)
	_dropping_through = false

func _has_anim(anim_name: String) -> bool:
	return sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name)

func _play_if_exists(anim_name: String) -> void:
	if _has_anim(anim_name):
		sprite.play(anim_name)

func perform_slash() -> void:
	is_attacking = true
	_slash_cooldown_timer = slash_cooldown

	var facing_right := _last_move_dir >= 0.0
	if sprite:
		sprite.flip_h = not facing_right

	if slash_hitbox:
		slash_hitbox.position.x = abs(slash_hitbox.position.x) * (1.0 if facing_right else -1.0)
		slash_hitbox.monitoring = true
		await get_tree().create_timer(slash_hitbox_time).timeout
		slash_hitbox.monitoring = false

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("Slash"):
		sprite.play("Slash")
		if not sprite.animation_finished.is_connected(_on_slash_finished):
			sprite.animation_finished.connect(_on_slash_finished)
	else:
		await get_tree().create_timer(0.3).timeout
		is_attacking = false

func _on_slash_finished() -> void:
	is_attacking = false

func respawn() -> void:
	if is_invincible:
		return
	global_position = start_position
	velocity = Vector2.ZERO
	jumps_left = 2
	is_attacking = false
	_dropping_through = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_slash_cooldown_timer = 0.0
	_tired_timer = 0.0
	if sprite:
		sprite.flip_h = false
		_play_if_exists("Idle")
	if camera:
		camera.reset_smoothing()
		camera.force_update_scroll()
	_apply_invincibility()

func _apply_invincibility() -> void:
	is_invincible = true
	if sprite:
		var tween := create_tween()
		tween.set_loops(int(invincible_time / 0.1))
		tween.tween_property(sprite, "modulate:a", 0.3, 0.05)
		tween.tween_property(sprite, "modulate:a", 1.0, 0.05)
		await tween.finished
		sprite.modulate.a = 1.0
	is_invincible = false

func _on_kill_zone_body_entered(body: Node2D) -> void:
	if body == self:
		respawn()

@export var vfx_scene: PackedScene

func play_vfx(offset: Vector2 = Vector2.ZERO) -> void:
	var vfx_instance = load("res://game/Scene/vfx_jump_up.tscn").instantiate()
	get_tree().current_scene.add_child(vfx_instance)
	vfx_instance.global_position = global_position + offset

func play_land_VFX(offset: Vector2 = Vector2.ZERO) -> void:
	var vfx_instance = load("res://game/Scene/vfx_Land.tscn").instantiate()
	get_tree().current_scene.add_child(vfx_instance)
	vfx_instance.global_position = global_position + offset

func perform_shoot() -> void:
	var shoot_animation: String

	if not is_on_floor():
		shoot_animation = "shoot_jump"
	elif _get_move_direction() != 0.0:
		shoot_animation = "shoot_run"
	else:
		shoot_animation = "Shoot_stand"

	if not _has_anim(shoot_animation):
		push_warning("Missing animation: " + shoot_animation)
		return

	is_shooting = true
	_shoot_cooldown_timer = shoot_cooldown

	sprite.play(shoot_animation)

	var bullet_instance = BULLET_SCENE.instantiate()
	var bullet_direction := -1 if sprite.flip_h else 1

	bullet_instance.set("direction", bullet_direction)

	get_tree().current_scene.add_child(bullet_instance)

	var spawn_position = shoot_place.global_position
	spawn_position.y -= 50.0
	bullet_instance.global_position = spawn_position

	bullet_instance.global_position = spawn_position

	await sprite.animation_finished

	is_shooting = false
