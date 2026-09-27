extends Node3D

@export var speed: float = 0.25

const TEX_DIR := "res://assets/uploads/textures/"
const CLEAN_JSON := "res://assets/uploads/materials_clean.json"
const MASTER_SHADER := preload("res://shaders/ue_master.gdshader")

var _materials := {}
var _cache := {}
var _wheel: Node3D
var _cabins: Array[Node3D] = []
var _debug := 0
var _tiling := 1.0
var _label: Label
const TILINGS := [1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 0.5, 0.25, 0.125, 0.0625]


func _ready() -> void:
	_load_materials()
	_apply_master(self)
	_build_ui()
	_wheel = find_child("1_SM_Ferris_Circle_Engine_03_StaticMeshComponent0", true, false) as Node3D
	if _wheel == null:
		return
	for child in _wheel.get_children():
		if child is Node3D:
			_cabins.append(child)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(24, 24)
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	add_child(layer)
	_update_label()


func _process(delta: float) -> void:
	if _wheel == null:
		return
	var angle := speed * delta
	_wheel.rotate_z(angle)
	for cabin in _cabins:
		cabin.rotate_z(-angle)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		_debug = (_debug + 1) % 7
		_apply_debug()
		print("ferris debug_mode = ", _debug)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_N:
		var idx := TILINGS.find(_tiling)
		idx = (idx + 1) % TILINGS.size()
		_tiling = TILINGS[idx]
		_apply_debug()
		print("ferris mask_tiling = ", _tiling)


func _apply_debug() -> void:
	for key in _cache:
		var m := _cache[key] as ShaderMaterial
		m.set_shader_parameter("debug_mode", _debug)
		m.set_shader_parameter("mask_tiling", _tiling)
	_update_label()


func _update_label() -> void:
	if _label != null:
		_label.text = "debug_mode = %d    mask_tiling = %s" % [_debug, str(_tiling)]


func _load_materials() -> void:
	if not FileAccess.file_exists(CLEAN_JSON):
		return
	var file := FileAccess.open(CLEAN_JSON, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_materials = parsed


func _tex(name) -> Texture2D:
	if name == null or String(name) == "":
		return null
	var path := TEX_DIR + String(name) + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _vec3(value, fallback: Vector3 = Vector3(1, 1, 1)) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback


func _f(value, fallback: float = 1.0) -> float:
	if value is float or value is int:
		return float(value)
	return fallback


func _is_white(v: Vector3) -> bool:
	return absf(v.x - 1.0) < 0.01 and absf(v.y - 1.0) < 0.01 and absf(v.z - 1.0) < 0.01


func _apply_master(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				if mat == null:
					continue
				var key := String(mat.resource_name)
				if key == "" or not _materials.has(key):
					continue
				var entry: Dictionary = _materials[key]
				if entry.get("main") == null:
					continue
				if not _cache.has(key):
					_cache[key] = _build_material(entry)
				mesh.surface_set_material(i, _cache[key])
	for child in node.get_children():
		_apply_master(child)


func _build_material(entry: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MASTER_SHADER

	var main_tex := _tex(entry.get("main"))
	if main_tex != null:
		mat.set_shader_parameter("main_albedo", main_tex)
	mat.set_shader_parameter("main_tint", _vec3(entry.get("main_tint"), Vector3(1, 1, 1)))

	var normal_tex := _tex(entry.get("normal"))
	mat.set_shader_parameter("has_normal", normal_tex != null)
	if normal_tex != null:
		mat.set_shader_parameter("main_normal", normal_tex)

	var orm_tex := _tex(entry.get("orm"))
	mat.set_shader_parameter("has_orm", orm_tex != null)
	if orm_tex != null:
		mat.set_shader_parameter("main_orm", orm_tex)

	var mask1 := _tex(entry.get("m1"))
	if mask1 == null:
		mask1 = _tex("T_Mask_Black")
	if mask1 != null:
		mat.set_shader_parameter("mask1", mask1)
	mat.set_shader_parameter("tint_r1", _vec3(entry.get("r1")))
	mat.set_shader_parameter("tint_g1", _vec3(entry.get("g1")))
	mat.set_shader_parameter("tint_b1", _vec3(entry.get("b1")))
	mat.set_shader_parameter("inten1", Vector3(_f(entry.get("ri1")), _f(entry.get("gi1")), _f(entry.get("bi1"))))

	var mask2 := _tex(entry.get("m2"))
	if mask2 == null:
		mask2 = _tex("T_Mask_Black")
	if mask2 != null:
		mat.set_shader_parameter("mask2", mask2)
	mat.set_shader_parameter("tint_r2", _vec3(entry.get("r2")))
	mat.set_shader_parameter("tint_g2", _vec3(entry.get("g2")))
	mat.set_shader_parameter("tint_b2", _vec3(entry.get("b2")))
	mat.set_shader_parameter("inten2", Vector3(_f(entry.get("ri2")), _f(entry.get("gi2")), _f(entry.get("bi2"))))

	var tm1 := _tex(entry.get("tm1"))
	if tm1 == null:
		tm1 = _tex("T_Mask_Black")
	if tm1 != null:
		mat.set_shader_parameter("tm1", tm1)
	mat.set_shader_parameter("tmask_r1", _vec3(entry.get("tr1")))
	mat.set_shader_parameter("tmask_g1", _vec3(entry.get("tg1")))
	mat.set_shader_parameter("tmask_b1", _vec3(entry.get("tb1")))
	if _is_white(_vec3(entry.get("tr1"))) and _is_white(_vec3(entry.get("tg1"))) and _is_white(_vec3(entry.get("tb1"))):
		mat.set_shader_parameter("tintmask_inten1", 0.0)
	else:
		mat.set_shader_parameter("tintmask_inten1", _f(entry.get("ti1")))

	var tm2 := _tex(entry.get("tm2"))
	if tm2 == null:
		tm2 = _tex("T_Mask_Black")
	if tm2 != null:
		mat.set_shader_parameter("tm2", tm2)
	mat.set_shader_parameter("tmask_r2", _vec3(entry.get("tr2")))
	mat.set_shader_parameter("tmask_g2", _vec3(entry.get("tg2")))
	mat.set_shader_parameter("tmask_b2", _vec3(entry.get("tb2")))
	if _is_white(_vec3(entry.get("tr2"))) and _is_white(_vec3(entry.get("tg2"))) and _is_white(_vec3(entry.get("tb2"))):
		mat.set_shader_parameter("tintmask_inten2", 0.0)
	else:
		mat.set_shader_parameter("tintmask_inten2", _f(entry.get("ti2")))

	return mat
