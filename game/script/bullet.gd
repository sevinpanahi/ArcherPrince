
extends Area2D

@onready var bullet: Sprite2D = $Bullet

const SPEED: float = 500.0
const DAMAGE: int = 35

var direction: int = 1
var has_hit: bool = false

func _physics_process(delta: float) -> void:
	if direction == -1:
		bullet.flip_h = true
	else:
		bullet.flip_h = false

	position.x += SPEED * direction * delta


func _on_body_entered(body: Node2D) -> void:
	print("BULLET COLLISION: ", body.name)
	if has_hit:
		return

	var target: Node = body

	while target != null and not target.has_method("take_damage"):
		target = target.get_parent()

	if target == null:
		return

	has_hit = true

	target.take_damage(DAMAGE)

	print("Bullet hit: ", target.name)

	var vfx_scene = preload("res://game/Scene/vfx_Land.tscn")
	var vfx_instance = GameManager.SpawnVFX(vfx_scene, global_position)

	if direction == -1:
		vfx_instance.scale.x = -1

	queue_free()
