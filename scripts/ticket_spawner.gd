extends Node3D

@export var ticket_types: Array[TicketType] = []

const TICKET_SCENE_PATH := "res://scenes/scratch_ticket.tscn"
const MAP_HALF := 56.0
const FLOOR_TOP := 0.5
const MIN_SPACING := 3.0

var _game: Node
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_game = get_tree().get_first_node_in_group("game")
	if _game:
		_game.night_started.connect(_on_night_started)


func _on_night_started() -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	if _game == null:
		return
	var placed: Array = []
	var night := int(_game.nights_started)
	for type in ticket_types:
		if type == null or night < type.min_night:
			continue
		_spawn_type(type, _roll_count(type.spawn_per_night), placed)


func _roll_count(expected: float) -> int:
	var value := maxf(0.0, expected)
	var count := int(floor(value))
	if _rng.randf() < value - float(count):
		count += 1
	return count


func _spawn_type(type: TicketType, count: int, placed: Array) -> void:
	var attempts := 0
	var max_attempts := count * 60
	var spawned := 0
	while spawned < count and attempts < max_attempts:
		attempts += 1
		var point = _sample_point()
		if point == null:
			continue
		if not _far_enough(point, placed):
			continue
		placed.append(point)
		_spawn_one(point, type)
		spawned += 1


func _sample_point():
	var x := _rng.randf_range(-MAP_HALF, MAP_HALF)
	var z := _rng.randf_range(-MAP_HALF, MAP_HALF)
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 6.0, z), Vector3(x, -1.0, z))
	var player := get_tree().get_first_node_in_group("player")
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if not hit.has("collider"):
		return null
	var pos: Vector3 = hit["position"]
	if pos.y > FLOOR_TOP:
		return null
	return pos


func _far_enough(point: Vector3, placed: Array) -> bool:
	for p in placed:
		if point.distance_to(p) < MIN_SPACING:
			return false
	return true


func _spawn_one(point: Vector3, type: TicketType) -> void:
	var scene: PackedScene = load(TICKET_SCENE_PATH)
	if scene == null:
		return
	var ticket := scene.instantiate()
	if type:
		ticket.ticket_type = type
	var yaw := _rng.randf_range(0.0, TAU)
	var basis := Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
	ticket.transform = Transform3D(basis, point + Vector3(0.0, 0.02, 0.0))
	add_child(ticket)
