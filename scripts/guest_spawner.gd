extends Node3D

@export var drifter_type: GuestType
@export var listener_type: GuestType
@export var drifters: int = 2
@export var listeners: int = 1

const GUEST_SCENE_PATH := "res://scenes/guest.tscn"

var _game: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_game = get_tree().get_first_node_in_group("game")
	if _game:
		_game.night_started.connect(_on_night_started)


func _on_night_started() -> void:
	var types: Array = []
	for i in range(drifters):
		types.append(drifter_type)
	for i in range(listeners):
		types.append(listener_type)
	_spawn(types)


func _spawn(types: Array) -> void:
	var markers := get_tree().get_nodes_in_group("guest_spawn")
	if markers.is_empty():
		return
	var points: Array = []
	for marker in markers:
		points.append((marker as Node3D).global_position)
	_shuffle(points)
	for i in range(types.size()):
		var type: GuestType = types[i]
		if type == null:
			continue
		_spawn_one(type, points[i % points.size()])


func _spawn_one(type: GuestType, point: Vector3) -> void:
	var scene: PackedScene = load(GUEST_SCENE_PATH)
	if scene == null:
		return
	var guest := scene.instantiate()
	guest.guest_type = type
	add_child(guest)
	(guest as Node3D).global_position = point


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
