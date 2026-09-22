extends StaticBody3D

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _shape: CollisionShape3D = $CollisionShape3D

var _game: Node


func _ready() -> void:
	_game = get_tree().get_first_node_in_group("game")
	_apply(false)
	if _game:
		_game.night_started.connect(_on_night)
		_game.day_started.connect(_on_day)


func _on_night() -> void:
	_apply(true)


func _on_day() -> void:
	_apply(false)


func _apply(open: bool) -> void:
	if _shape:
		_shape.set_deferred("disabled", open)
	if _mesh:
		_mesh.visible = not open
