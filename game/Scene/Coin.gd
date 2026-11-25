extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var collected: bool = false


func _ready() -> void:
	sprite.play("Idle")


func _on_body_entered(body: Node2D) -> void:
	print("COIN COLLISION: ", body.name)
	print("IS PLAYER: ", body.is_in_group("player"))

	if body.is_in_group("player"):
		collected = true

		set_deferred("monitoring", false)
		set_deferred("monitorable", false)

		sprite.play("Collected")

		await sprite.animation_finished
		queue_free()
