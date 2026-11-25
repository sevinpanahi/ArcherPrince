extends Node

var player: Node2D = null
var player_original_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")
	if player:
		player_original_pos = player.global_position
		print("GameManager: player found at ", player_original_pos)
	else:
		print("GameManager: player NOT found. Add player to group 'player'.")

func PlayerEnteredResetArea() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			push_warning("GameManager: player is null, cannot reset.")
			return

	if player.has_method("respawn"):
		player.respawn()
	else:
		player.global_position = player_original_pos
		if "velocity" in player:
			player.velocity = Vector2.ZERO


func SpawnVFX(scene: PackedScene, spawn_position: Vector2) -> Node2D:
	var instance = scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = spawn_position
	return instance
