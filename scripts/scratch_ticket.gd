extends Node3D

signal panel_revealed(index: int, prize: Dictionary)

@export_range(1.0, 1000.0, 1.0) var scratch_hardness: float = 60.0
@export_range(0.5, 64.0, 0.5) var brush_radius_cells: float = 21.0
@export_range(0.1, 1.0, 0.01) var reveal_threshold: float = 0.85
@export var interact_range: float = 4.0
@export var hold_offset: Vector3 = Vector3(0.14, -0.12, -0.42)
@export var hold_rotation_deg: Vector3 = Vector3(-6.0, -14.0, 0.0)
@export_range(0.0, 1.0, 0.01) var coin_chance: float = 0.5
@export_range(0.1, 1.0, 0.05) var grid_scale: float = 0.5

const VIEWPORT_SIZE := Vector2i(900, 320)
const PANEL_COUNT := 3
const MARGIN := 18.0
const GAP := 18.0
const DROP_DISTANCE := 1.1
const FLOOR_Y := 0.02
const FOIL_COLOR := Color(0.74, 0.76, 0.80)
const COIN_AMOUNTS := [5, 10, 15, 25]

var _held := false
var _scratching := false
var _interact_cooldown := 0.0
var _initial_frames := 10
var _last_hit := Vector2(-1.0, -1.0)
var _last_panel := -1

var _ticket_size := Vector2(0.42, 0.16)
var _panels: Array = []
var _prize_labels: Array = []
var _ground_basis := Basis()
var _hold_transform := Transform3D()

var _cam: Camera3D
var _player: Node

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _body: Area3D = $Body
@onready var _shape: CollisionShape3D = $Body/CollisionShape3D
@onready var _sub: SubViewport = $SubViewport


func _ready() -> void:
	randomize()
	var quad := _mesh.mesh as QuadMesh
	if quad:
		_ticket_size = quad.size
	_ground_basis = Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0))
	_hold_transform = Transform3D(
		Basis.from_euler(Vector3(
			deg_to_rad(hold_rotation_deg.x),
			deg_to_rad(hold_rotation_deg.y),
			deg_to_rad(hold_rotation_deg.z)
		)),
		hold_offset
	)
	_sub.size = VIEWPORT_SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_ONCE
	_build_viewport_ui()
	_setup_material()
	_roll_prizes()
	_player = get_tree().get_first_node_in_group("player")


func _setup_material() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _sub.get_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_mesh.material_override = mat


func _build_viewport_ui() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(root)

	var paper := ColorRect.new()
	paper.color = Color(0.93, 0.91, 0.84)
	paper.size = Vector2(VIEWPORT_SIZE)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paper)

	var panel_w := (float(VIEWPORT_SIZE.x) - MARGIN * 2.0 - GAP * float(PANEL_COUNT - 1)) / float(PANEL_COUNT)
	var panel_h := float(VIEWPORT_SIZE.y) - MARGIN * 2.0

	for i in range(PANEL_COUNT):
		var rect := Rect2(Vector2(MARGIN + float(i) * (panel_w + GAP), MARGIN), Vector2(panel_w, panel_h))

		var bg := ColorRect.new()
		bg.color = Color(0.99, 0.98, 0.95)
		bg.position = rect.position
		bg.size = rect.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)

		var label := Label.new()
		label.position = rect.position
		label.size = rect.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 44)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(label)
		_prize_labels.append(label)

		var grid_w := maxi(1, int(rect.size.x * grid_scale))
		var grid_h := maxi(1, int(rect.size.y * grid_scale))
		var img := Image.create_empty(grid_w, grid_h, false, Image.FORMAT_RGBA8)
		img.fill(Color(FOIL_COLOR.r, FOIL_COLOR.g, FOIL_COLOR.b, 1.0))
		var tex := ImageTexture.create_from_image(img)
		var foil := TextureRect.new()
		foil.texture = tex
		foil.position = rect.position
		foil.size = rect.size
		foil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		foil.stretch_mode = TextureRect.STRETCH_SCALE
		foil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		foil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(foil)

		var health := PackedFloat32Array()
		health.resize(grid_w * grid_h)
		health.fill(scratch_hardness)

		_panels.append({
			"rect": rect,
			"grid_w": grid_w,
			"grid_h": grid_h,
			"health": health,
			"image": img,
			"texture": tex,
			"damage": 0.0,
			"health_total": float(grid_w * grid_h) * scratch_hardness,
			"revealed": false,
			"dirty": false,
			"dirty_indices": PackedInt32Array(),
			"prize": {},
		})


func _roll_prizes() -> void:
	for i in range(_panels.size()):
		var prize: Dictionary
		if randf() < coin_chance:
			prize = {"type": "coins", "amount": COIN_AMOUNTS[randi() % COIN_AMOUNTS.size()]}
		else:
			prize = {"type": "nothing", "amount": 0}
		_panels[i]["prize"] = prize


func _process(delta: float) -> void:
	if _interact_cooldown > 0.0:
		_interact_cooldown -= delta

	_flush_dirty()

	if _held:
		_follow_camera()
		return

	if _initial_frames > 0:
		_initial_frames -= 1
		_sub.render_target_update_mode = SubViewport.UPDATE_ONCE

	if _player == null:
		_player = get_tree().get_first_node_in_group("player")

	var looking := _is_looking_at_ticket()
	var prompt := "Press E to pick up the ticket" if looking else ""
	if _player and _player.has_method("show_prompt"):
		_player.show_prompt(prompt)
	if looking and _interact_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		_pick_up()


func _flush_dirty() -> void:
	for i in range(_panels.size()):
		var p: Dictionary = _panels[i]
		if not p["dirty"]:
			continue
		var img: Image = p["image"]
		var health: PackedFloat32Array = p["health"]
		var grid_w: int = p["grid_w"]
		for idx in p["dirty_indices"]:
			var ratio := clampf(health[idx] / scratch_hardness, 0.0, 1.0)
			var a := pow(ratio, 1.5)
			img.set_pixel(idx % grid_w, idx / grid_w, Color(FOIL_COLOR.r, FOIL_COLOR.g, FOIL_COLOR.b, a))
		p["texture"].update(img)
		p["dirty"] = false
		p["dirty_indices"] = PackedInt32Array()


func _is_looking_at_ticket() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return false
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * interact_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	if _player is CollisionObject3D:
		query.exclude = [(_player as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	return hit.has("collider") and hit["collider"] == _body


func _follow_camera() -> void:
	if _cam == null:
		_cam = get_viewport().get_camera_3d()
	if _cam:
		global_transform = _cam.global_transform * _hold_transform


func _pick_up() -> void:
	if _held:
		return
	_cam = get_viewport().get_camera_3d()
	if _cam == null:
		return
	_held = true
	_scratching = false
	_last_hit = Vector2(-1.0, -1.0)
	_last_panel = -1
	_shape.disabled = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_follow_camera()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)
	if _player and _player.has_method("show_prompt"):
		_player.show_prompt("Hold left mouse and scrub - ESC or E to put down")


func _put_down() -> void:
	if not _held:
		return
	_held = false
	_scratching = false
	_interact_cooldown = 0.25
	_last_panel = -1
	_shape.disabled = false
	_sub.render_target_update_mode = SubViewport.UPDATE_ONCE

	var drop := global_position
	if _cam:
		drop = _cam.global_position - _cam.global_transform.basis.z * DROP_DISTANCE
	drop.y = FLOOR_Y
	global_transform = Transform3D(_ground_basis, drop)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(false)


func _input(event: InputEvent) -> void:
	if not _held:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			_put_down()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_scratching = event.pressed
		_last_hit = Vector2(-1.0, -1.0)
		_last_panel = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _scratching:
		_scratch_at(event.position)
		get_viewport().set_input_as_handled()


func _scratch_at(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var plane := Plane(global_transform.basis.z.normalized(), global_position)
	var hit = plane.intersects_ray(origin, dir)
	if hit == null:
		_last_panel = -1
		_last_hit = Vector2(-1.0, -1.0)
		return

	var local: Vector3 = to_local(hit)
	var uv := Vector2(
		(local.x + _ticket_size.x * 0.5) / _ticket_size.x,
		1.0 - (local.y + _ticket_size.y * 0.5) / _ticket_size.y
	)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return

	var px := uv.x * float(VIEWPORT_SIZE.x)
	var py := uv.y * float(VIEWPORT_SIZE.y)

	for i in range(_panels.size()):
		var p: Dictionary = _panels[i]
		var rect: Rect2 = p["rect"]
		if not rect.has_point(Vector2(px, py)):
			continue
		var grid_w: int = p["grid_w"]
		var grid_h: int = p["grid_h"]
		var cx := clampi(int((px - rect.position.x) / rect.size.x * float(grid_w)), 0, grid_w - 1)
		var cy := clampi(int((py - rect.position.y) / rect.size.y * float(grid_h)), 0, grid_h - 1)
		var cur := Vector2(cx, cy)
		if _last_panel != i or _last_hit.x < 0.0:
			_last_panel = i
			_last_hit = cur
			return
		var distance := (_last_hit - cur).length()
		_last_hit = cur
		if distance <= 0.0 or distance > 64.0:
			return
		_apply_scratch(i, cx, cy, distance)
		return

	_last_panel = -1
	_last_hit = Vector2(-1.0, -1.0)


func _apply_scratch(panel_index: int, cx: int, cy: int, distance: float) -> void:
	var p: Dictionary = _panels[panel_index]
	if p["revealed"]:
		return
	var grid_w: int = p["grid_w"]
	var grid_h: int = p["grid_h"]
	var health: PackedFloat32Array = p["health"]
	var damage := distance * _player_damage()
	var radius := int(ceil(brush_radius_cells))
	var radius_sq := brush_radius_cells * brush_radius_cells
	var changed := false
	var applied := 0.0
	var dirty: PackedInt32Array = p["dirty_indices"]

	for oy in range(-radius, radius + 1):
		for ox in range(-radius, radius + 1):
			var d_sq := float(ox * ox + oy * oy)
			if d_sq > radius_sq:
				continue
			var x := cx + ox
			var y := cy + oy
			if x < 0 or y < 0 or x >= grid_w or y >= grid_h:
				continue
			var idx := y * grid_w + x
			var h := health[idx]
			if h <= 0.0:
				continue
			var falloff := 1.0 - sqrt(d_sq) / brush_radius_cells
			var nh := maxf(0.0, h - damage * falloff)
			if nh != h:
				applied += h - nh
				health[idx] = nh
				changed = true
				dirty.append(idx)

	if not changed:
		return

	p["health"] = health
	p["damage"] = float(p["damage"]) + applied
	p["dirty_indices"] = dirty
	p["dirty"] = true

	if float(p["damage"]) / float(p["health_total"]) >= reveal_threshold:
		_reveal_panel(panel_index)


func _player_damage() -> float:
	if _player and "scratch_damage" in _player:
		return float(_player.scratch_damage)
	return 1.0


func _reveal_panel(panel_index: int) -> void:
	var p: Dictionary = _panels[panel_index]
	if p["revealed"]:
		return
	p["revealed"] = true

	var img: Image = p["image"]
	img.fill(Color(FOIL_COLOR.r, FOIL_COLOR.g, FOIL_COLOR.b, 0.0))
	p["texture"].update(img)
	p["dirty"] = false
	p["dirty_indices"] = PackedInt32Array()

	var prize: Dictionary = p["prize"]
	var label: Label = _prize_labels[panel_index]
	if prize["type"] == "coins":
		label.text = "+%d\nCOINS" % int(prize["amount"])
		label.add_theme_color_override("font_color", Color(0.10, 0.45, 0.12))
		if _player and _player.has_method("add_coins"):
			_player.add_coins(int(prize["amount"]))
	else:
		label.text = "NOTHING"
		label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))

	panel_revealed.emit(panel_index, prize)
