extends Node3D

signal panel_revealed(index: int)
signal ticket_completed(result: Dictionary)
signal stowed(data)
signal finished(data)

@export var ticket_type: TicketType
@export_range(1.0, 1000.0, 1.0) var scratch_hardness: float = 60.0
@export_range(0.5, 64.0, 0.5) var brush_radius_cells: float = 21.0
@export_range(0.1, 1.0, 0.01) var reveal_threshold: float = 0.85
@export var interact_range: float = 4.0
@export var hold_offset: Vector3 = Vector3(0.14, -0.12, -0.42)
@export var hold_rotation_deg: Vector3 = Vector3(-6.0, -14.0, 0.0)
@export_range(0.1, 1.0, 0.05) var grid_scale: float = 0.5

const VIEWPORT_SIZE := Vector2i(900, 320)
const MARGIN := 18.0
const GAP := 18.0
const FINISH_DELAY := 1.8
const FOIL_COLOR := Color(0.74, 0.76, 0.80)

enum Mode { GROUND, HELD }

var _mode: int = Mode.GROUND
var _data: TicketData = null
var _scratching := false
var _generated := false
var _finished := false
var _interact_cooldown := 0.0
var _initial_frames := 10
var _last_hit := Vector2(-1.0, -1.0)
var _last_panel := -1

var _ticket_size := Vector2(0.42, 0.16)
var _panel_count := 3
var _panels: Array = []
var _prize_labels: Array = []
var _panel_bgs: Array = []
var _hold_transform := Transform3D()

var _cam: Camera3D
var _player: Node
var _game: Node

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _body: Area3D = $Body
@onready var _shape: CollisionShape3D = $Body/CollisionShape3D
@onready var _sub: SubViewport = $SubViewport


func _ready() -> void:
	var quad := _mesh.mesh as QuadMesh
	if quad:
		_ticket_size = quad.size
	if ticket_type:
		_panel_count = maxi(1, ticket_type.tile_count)
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
	_player = get_tree().get_first_node_in_group("player")
	add_to_group("ground_ticket")
	_game = get_tree().get_first_node_in_group("game")
	if _game:
		_game.day_started.connect(_on_day_started)


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

	var paper_color := Color(0.93, 0.91, 0.84)
	if ticket_type:
		paper_color = ticket_type.paper_color
	var paper := ColorRect.new()
	paper.color = paper_color
	paper.size = Vector2(VIEWPORT_SIZE)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(paper)

	var panel_w := (float(VIEWPORT_SIZE.x) - MARGIN * 2.0 - GAP * float(_panel_count - 1)) / float(_panel_count)
	var panel_h := float(VIEWPORT_SIZE.y) - MARGIN * 2.0

	for i in range(_panel_count):
		var rect := Rect2(Vector2(MARGIN + float(i) * (panel_w + GAP), MARGIN), Vector2(panel_w, panel_h))

		var bg := ColorRect.new()
		bg.color = Color(0.99, 0.98, 0.95)
		bg.position = rect.position
		bg.size = rect.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
		_panel_bgs.append(bg)

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
			"icon": null,
		})


func hold(data: TicketData) -> void:
	if data == null:
		return
	if data.type:
		ticket_type = data.type
	_data = data
	_mode = Mode.HELD
	_load_data(data)
	_cam = get_viewport().get_camera_3d()
	_shape.disabled = true
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_follow_camera()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(true)
	if _player and _player.has_method("show_prompt"):
		_player.show_prompt("Hold left mouse and scrub - E or ESC to stow", self)


func _load_data(data: TicketData) -> void:
	for i in range(_panels.size()):
		if i >= data.panels.size():
			break
		var src: Dictionary = data.panels[i]
		var p: Dictionary = _panels[i]
		p["icon"] = src.get("icon")
		var src_health: PackedFloat32Array = src.get("health", PackedFloat32Array())
		if src_health.size() == int(p["grid_w"]) * int(p["grid_h"]):
			p["health"] = src_health
		p["damage"] = float(src.get("damage", 0.0))
		p["revealed"] = bool(src.get("revealed", false))
		_apply_icon_visual(i, p["icon"])
		_refresh_panel_image(i)
	_generated = true


func _save_to_data() -> void:
	if _data == null:
		return
	for i in range(_panels.size()):
		if i >= _data.panels.size():
			break
		var p: Dictionary = _panels[i]
		_data.panels[i]["health"] = p["health"]
		_data.panels[i]["damage"] = p["damage"]
		_data.panels[i]["revealed"] = p["revealed"]


func _make_data() -> TicketData:
	var data := TicketData.new()
	data.type = ticket_type
	for p in _panels:
		var icon: TicketIcon = p["icon"]
		data.panels.append({
			"icon": icon,
			"health": p["health"],
			"damage": p["damage"],
			"revealed": p["revealed"],
		})
	return data


func _refresh_panel_image(index: int) -> void:
	var p: Dictionary = _panels[index]
	var img: Image = p["image"]
	var health: PackedFloat32Array = p["health"]
	var grid_w: int = p["grid_w"]
	if p["revealed"]:
		img.fill(Color(FOIL_COLOR.r, FOIL_COLOR.g, FOIL_COLOR.b, 0.0))
	else:
		for idx in range(health.size()):
			var ratio := clampf(health[idx] / scratch_hardness, 0.0, 1.0)
			var a := pow(ratio, 1.5)
			img.set_pixel(idx % grid_w, idx / grid_w, Color(FOIL_COLOR.r, FOIL_COLOR.g, FOIL_COLOR.b, a))
	p["texture"].update(img)
	p["dirty"] = false
	p["dirty_indices"] = PackedInt32Array()


func _generate() -> void:
	_generated = true
	if ticket_type == null or ticket_type.icons.is_empty():
		return
	Progression.ensure_seeded()
	var ids := []
	for i in range(_panels.size()):
		var icon := _roll_icon()
		_panels[i]["icon"] = icon
		_apply_icon_visual(i, icon)
		ids.append(String(icon.id) if icon else "-")
	print("[%s] rolled %s" % [ticket_type.type_name, str(ids)])


func _roll_icon() -> TicketIcon:
	var total := 0.0
	for icon in ticket_type.icons:
		total += Progression.icon_weight(ticket_type, icon.id)
	if total <= 0.0:
		return null
	var roll := randf() * total
	var acc := 0.0
	for icon in ticket_type.icons:
		acc += Progression.icon_weight(ticket_type, icon.id)
		if roll <= acc:
			return icon
	return ticket_type.icons[ticket_type.icons.size() - 1]


func _apply_icon_visual(index: int, icon: TicketIcon) -> void:
	var bg: ColorRect = _panel_bgs[index]
	var label: Label = _prize_labels[index]
	if icon == null:
		bg.color = Color(0.99, 0.98, 0.95)
		label.text = ""
		return
	bg.color = icon.color
	label.text = icon.label
	var lum := 0.2126 * icon.color.r + 0.7152 * icon.color.g + 0.0722 * icon.color.b
	if lum > 0.6:
		label.add_theme_color_override("font_color", Color(0.06, 0.06, 0.06))
	else:
		label.add_theme_color_override("font_color", Color(0.97, 0.97, 0.97))


func _process(delta: float) -> void:
	if _interact_cooldown > 0.0:
		_interact_cooldown -= delta

	_flush_dirty()

	if _mode == Mode.HELD:
		_follow_camera()
		return

	_resolve_player()
	if _player and bool(_player.get("input_locked")):
		return

	if _initial_frames > 0:
		_initial_frames -= 1
		_sub.render_target_update_mode = SubViewport.UPDATE_ONCE

	var looking := _is_looking_at_ticket()
	var prompt := "Press E to pocket the ticket" if looking else ""
	if _player and _player.has_method("show_prompt"):
		_player.show_prompt(prompt, self)
	if looking and _interact_cooldown <= 0.0 and Input.is_action_just_pressed("interact"):
		_pocket()


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


func _resolve_player() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")


func _resolve_game() -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")


func _on_day_started() -> void:
	if _mode != Mode.GROUND or _finished:
		return
	queue_free()


func _is_looking_at_ticket() -> bool:
	_resolve_player()
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


func _pocket() -> void:
	if _mode != Mode.GROUND or _finished:
		return
	_resolve_player()
	_resolve_game()
	if _game == null:
		return
	if _game.backpack.size() >= int(_game.backpack_capacity):
		if _player and _player.has_method("show_prompt"):
			_player.show_prompt("Backpack full", self)
		_interact_cooldown = 0.75
		return
	if not _generated:
		_generate()
	var data := _make_data()
	if _game.pocket(data):
		if _player and _player.has_method("show_prompt"):
			_player.show_prompt("", self)
		queue_free()


func _stow() -> void:
	if _mode != Mode.HELD or _finished:
		return
	_mode = Mode.GROUND
	_scratching = false
	_save_to_data()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _player and _player.has_method("set_input_locked"):
		_player.set_input_locked(false)
	if _player and _player.has_method("show_prompt"):
		_player.show_prompt("", self)
	stowed.emit(_data)
	queue_free()


func _input(event: InputEvent) -> void:
	if _mode != Mode.HELD or _finished:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			_stow()
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

	panel_revealed.emit(panel_index)
	_maybe_finish()


func _maybe_finish() -> void:
	if _finished:
		return
	for p in _panels:
		if not p["revealed"]:
			return
	_finish_ticket()


func _finish_ticket() -> void:
	_finished = true
	var result := _evaluate()
	_award(result)
	finished.emit(_data)
	ticket_completed.emit(result)
	if _player and _player.has_method("show_prompt"):
		_player.show_prompt(_result_text(result), self)
	await get_tree().create_timer(FINISH_DELAY).timeout
	if is_inside_tree():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if _player and _player.has_method("set_input_locked"):
			_player.set_input_locked(false)
		queue_free()


func _evaluate() -> Dictionary:
	var counts := {}
	for p in _panels:
		var icon: TicketIcon = p["icon"]
		if icon == null:
			continue
		counts[icon.id] = int(counts.get(icon.id, 0)) + 1

	var xp := 0
	var coins := 0
	var matches := []
	var paid := {}
	for p in _panels:
		var icon: TicketIcon = p["icon"]
		if icon == null or paid.has(icon.id):
			continue
		if int(counts[icon.id]) >= 2:
			paid[icon.id] = true
			xp += icon.xp
			coins += icon.coins
			matches.append("%s x%d" % [icon.label, int(counts[icon.id])])
	return {"xp": xp, "coins": coins, "matches": matches, "levels_gained": 0, "level": 1}


func _award(result: Dictionary) -> void:
	_resolve_player()
	var mult := 1.0
	if ticket_type != null:
		mult = Progression.prize_multiplier(ticket_type)
	var coins := int(round(float(result["coins"]) * mult))
	var xp := int(round(float(result["xp"]) * mult))
	result["coins"] = coins
	result["xp"] = xp
	if coins > 0 and _player and _player.has_method("add_coins"):
		_player.add_coins(coins)
	if xp > 0 and ticket_type != null:
		var info := Progression.add_xp(ticket_type, xp)
		result["level"] = info["level"]
		result["levels_gained"] = info["levels_gained"]


func _result_text(result: Dictionary) -> String:
	var parts := []
	if int(result["xp"]) > 0:
		parts.append("+%d %s XP" % [int(result["xp"]), ticket_type.type_name])
	if int(result["coins"]) > 0:
		parts.append("+%d coins" % int(result["coins"]))
	var text := "Nothing..." if parts.is_empty() else " | ".join(parts)
	if int(result["levels_gained"]) > 0:
		text += "   LEVEL UP (lvl %d)" % int(result["level"])
	return text
