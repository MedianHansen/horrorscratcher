extends Interactable


func _ready() -> void:
	super()
	activated.connect(_on_activated)


func _on_activated(_player: Node) -> void:
	var ui := get_tree().get_first_node_in_group("upgrade_ui")
	if ui and ui.has_method("open"):
		ui.open()
