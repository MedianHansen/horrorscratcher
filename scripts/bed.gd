extends Interactable


func _ready() -> void:
	super()
	activated.connect(_on_activated)


func _on_activated(_player: Node) -> void:
	var game := get_tree().get_first_node_in_group("game")
	if game and not game.is_night():
		game.start_night()
