extends StaticBody3D

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shape: CollisionShape3D = $CollisionShape3D

var _game: Node


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")
	if _game:
		_game.upgrades_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var owned: bool = _game != null and bool(_game.has_trashcan())
	if _mesh:
		_mesh.visible = owned
	if _shape:
		_shape.set_deferred("disabled", not owned)
