extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var game := get_tree().get_first_node_in_group("game")
	if game:
		game.enter_hideout()


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var game := get_tree().get_first_node_in_group("game")
	if game:
		game.exit_hideout()
