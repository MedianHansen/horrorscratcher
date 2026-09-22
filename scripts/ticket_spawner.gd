extends Node3D

@export var ticket_type: TicketType

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
	_spawn_many(int(_game.tickets_per_night))


func _spawn_many(count: int) -> void:
	var placed: Array = []
	var attempts := 0
	var max_attempts := count * 60
	while placed.size() < count and attempts < max_attempts:
		attempts += 1
		var point = _sample_point()
		if point == null:
			continue
		if not _far_enough(point, placed):
			continue
		placed.append(point)
		_spawn_one(point)


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


func _spawn_one(point: Vector3) -> void:
	var scene: PackedScene = load(TICKET_SCENE_PATH)
	if scene == null:
		return
	var ticket := scene.instantiate()
	if ticket_type:
		ticket.ticket_type = ticket_type
	var yaw := _rng.randf_range(0.0, TAU)
	var basis := Basis(Vector3.UP, yaw) * Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
	ticket.transform = Transform3D(basis, point + Vector3(0.0, 0.02, 0.0))
	add_child(ticket)
