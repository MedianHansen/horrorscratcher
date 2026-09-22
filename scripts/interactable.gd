class_name Interactable
extends Area3D

signal activated(player: Node)

@export var prompt: String = "Press E"
@export var require_look: bool = true
@export var use_range: float = 3.5
@export var enabled: bool = true

var _player: Node
var _showing: bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _process(_delta: float) -> void:
	if not enabled or _input_locked() or not _player_can_use():
		_clear_prompt()
		return
	_show_prompt()
	if Input.is_action_just_pressed("interact"):
		activated.emit(_player)


func _input_locked() -> bool:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	return _player != null and bool(_player.get("input_locked"))


func _player_can_use() -> bool:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return false
	if _player is Node3D and global_position.distance_to((_player as Node3D).global_position) > use_range * 1.5:
		return false
	if not require_look:
		return true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * use_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collision_mask = collision_layer
	if _player is CollisionObject3D:
		query.exclude = [(_player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	return hit.has("collider") and hit["collider"] == self


func _show_prompt() -> void:
	if _player and _player.has_method("show_prompt"):
		_player.show_prompt(prompt, self)
	_showing = true


func _clear_prompt() -> void:
	if _showing and _player and _player.has_method("show_prompt"):
		_player.show_prompt("", self)
	_showing = false
