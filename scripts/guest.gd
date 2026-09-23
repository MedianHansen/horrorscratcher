extends CharacterBody3D

@export var guest_type: GuestType

const GRAVITY := 9.8
const REACH := 0.8
const LOSE_TIME := 4.0
const SEARCH_TIME := 3.0
const PAUSE_TIME := 1.5
const TURN_SPEED := 8.0

enum State { UNAWARE, SUSPICIOUS, CHASING, CAUGHT }

var _state: int = State.UNAWARE
var _player: Node3D
var _game: Node
var _target := Vector3.ZERO
var _pause := 0.0
var _lose_timer := 0.0
var _search_timer := 0.0
var _stun_timer := 0.0
var _current_color := Color(0, 0, 0, 0)
var _rng := RandomNumberGenerator.new()
var _debug_sight: MeshInstance3D
var _debug_hear: MeshInstance3D

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _nose: MeshInstance3D = $Nose


func _ready() -> void:
	_rng.randomize()
	add_to_group("guest")
	_player = get_tree().get_first_node_in_group("player")
	_game = get_tree().get_first_node_in_group("game")
	_apply_color()
	_build_debug_senses()
	_pick_target()


func _apply_color() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _base_color()
	_mesh.material_override = mat
	_current_color = _base_color()
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.08, 0.08, 0.1)
	_nose.material_override = nose_mat


func _base_color() -> Color:
	return guest_type.color if guest_type else Color(0.6, 0.6, 0.7)


func _state_color() -> Color:
	if _stun_timer > 0.0:
		return Color(0.92, 0.86, 0.42)
	match _state:
		State.CHASING:
			return Color(0.92, 0.16, 0.12)
		State.SUSPICIOUS:
			return Color(0.96, 0.72, 0.16)
		_:
			return _base_color()


func _refresh_visual() -> void:
	var color := _state_color()
	if color != _current_color and _mesh.material_override is StandardMaterial3D:
		(_mesh.material_override as StandardMaterial3D).albedo_color = color
		_current_color = color


func awareness() -> int:
	return _state


func stun(duration: float) -> void:
	if _state == State.CAUGHT:
		return
	_stun_timer = maxf(_stun_timer, duration)
	velocity = Vector3.ZERO
	_refresh_visual()


func _physics_process(delta: float) -> void:
	_update_debug_senses()
	if _state == State.CAUGHT:
		return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	_refresh_visual()

	if _stun_timer > 0.0:
		_stun_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _stun_timer <= 0.0:
			_state = State.UNAWARE
			_pick_target()
			_refresh_visual()
		return

	_sense(delta)

	if _state == State.UNAWARE and _pause > 0.0:
		_pause -= delta
		var decel := _speed() * delta * 4.0
		velocity.x = move_toward(velocity.x, 0.0, decel)
		velocity.z = move_toward(velocity.z, 0.0, decel)
	else:
		_move_towards(_target, _speed(), delta)

	move_and_slide()
	_try_capture()
	_refresh_visual()


func _move_towards(target: Vector3, speed: float, delta: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if dir.length() > REACH:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		var yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, yaw, TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		if _state == State.UNAWARE:
			_pause = PAUSE_TIME
			_pick_target()


func _sense(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	if _game and bool(_game.player_in_hideout):
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if _can_see(to_player, dist):
		_state = State.CHASING
		_lose_timer = 0.0
		_target = _player.global_position
		return

	if _hears(dist):
		if _state != State.CHASING:
			_state = State.SUSPICIOUS
			_search_timer = SEARCH_TIME
		_target = _player.global_position
		return

	if _state == State.CHASING:
		_lose_timer += delta
		if _lose_timer >= LOSE_TIME:
			_state = State.SUSPICIOUS
			_search_timer = SEARCH_TIME
	elif _state == State.SUSPICIOUS:
		_search_timer -= delta
		if _search_timer <= 0.0:
			_state = State.UNAWARE
			_pick_target()


func _can_see(to_player: Vector3, dist: float) -> bool:
	if guest_type == null or not guest_type.can_see:
		return false
	if dist > guest_type.sight_range:
		return false
	var forward := -global_transform.basis.z
	var dir := to_player.normalized()
	if forward.dot(dir) < cos(deg_to_rad(guest_type.sight_angle_deg * 0.5)):
		return false
	var space := get_world_3d().direct_space_state
	var to: Vector3 = _player.global_position + Vector3.UP * 0.6
	var cam := _player.get_node_or_null("Camera3D")
	if cam is Node3D:
		to = (cam as Node3D).global_position
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, to)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	return hit.has("collider") and hit["collider"] == _player


func _hears(dist: float) -> bool:
	if guest_type == null or guest_type.hear_radius <= 0.0:
		return false
	if not _player.has_method("current_noise_radius"):
		return false
	var noise := float(_player.current_noise_radius())
	return noise > 0.0 and dist <= minf(noise, guest_type.hear_radius)


func _speed() -> float:
	if guest_type == null:
		return 2.0
	if _state == State.CHASING or _state == State.SUSPICIOUS:
		return guest_type.chase_speed
	return guest_type.speed


func _try_capture() -> void:
	if _player == null or _state == State.CAUGHT or _stun_timer > 0.0:
		return
	var range := guest_type.capture_range if guest_type else 1.2
	var delta := _player.global_position - global_position
	delta.y = 0.0
	if delta.length() <= range:
		_state = State.CAUGHT
		velocity = Vector3.ZERO
		_refresh_visual()
		if _game and _game.has_method("on_caught"):
			_game.on_caught()


func _pick_target() -> void:
	var space := get_world_3d().direct_space_state
	for i in range(30):
		var x := _rng.randf_range(-56.0, 56.0)
		var z := _rng.randf_range(-56.0, 56.0)
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 6.0, z), Vector3(x, -1.0, z))
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		if hit.has("collider") and (hit["position"] as Vector3).y <= 0.5:
			_target = hit["position"]
			return
	_target = global_position


func _build_debug_senses() -> void:
	_debug_sight = _make_debug_mesh(Color(1.0, 0.35, 0.2, 0.22), 0.04)
	_debug_hear = _make_debug_mesh(Color(0.25, 0.7, 1.0, 0.18), 0.02)
	if guest_type == null:
		return
	if guest_type.can_see:
		_debug_sight.mesh = _make_cone_mesh(guest_type.sight_range, guest_type.sight_angle_deg)
	if guest_type.hear_radius > 0.0:
		_debug_hear.mesh = _make_disk_mesh(guest_type.hear_radius)


func _make_debug_mesh(color: Color, y: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.disable_receive_shadows = true
	var node := MeshInstance3D.new()
	node.material_override = mat
	node.position = Vector3(0.0, y, 0.0)
	node.visible = false
	add_child(node)
	return node


func _make_cone_mesh(radius: float, angle_deg: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(angle_deg * 0.5)
	var segments := 32
	for i in range(segments):
		var a0 := -half + 2.0 * half * float(i) / float(segments)
		var a1 := -half + 2.0 * half * float(i + 1) / float(segments)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(sin(a0), 0.0, -cos(a0)) * radius)
		mesh.surface_add_vertex(Vector3(sin(a1), 0.0, -cos(a1)) * radius)
	mesh.surface_end()
	return mesh


func _make_disk_mesh(radius: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 48
	for i in range(segments):
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3(sin(a0), 0.0, -cos(a0)) * radius)
		mesh.surface_add_vertex(Vector3(sin(a1), 0.0, -cos(a1)) * radius)
	mesh.surface_end()
	return mesh


func _update_debug_senses() -> void:
	var enabled := _game != null and bool(_game.get("debug_senses"))
	_debug_sight.visible = enabled
	_debug_hear.visible = enabled
