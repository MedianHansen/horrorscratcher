extends Node3D

@export var speed: float = 0.25
@export var normal_tiling: float = 10.0
@export var chase_enabled: bool = true
@export var chase_letter_seconds: float = 0.25
@export var chase_hold_seconds: float = 1.5
@export var chase_dark_seconds: float = 0.6
@export var chase_energy: float = 2.5

const TEX_DIR := "res://assets/uploads/textures/"
const CLEAN_JSON := "res://assets/uploads/materials_clean.json"
const MASTER_SHADER := preload("res://shaders/ue_master.gdshader")
const TEXT_MATERIAL := "MI_FerrisWheel_TextBG"
const TEXT_LETTERS := 11
const TEXT_UV0 := 0.031
const TEXT_UV_STEP := 0.0936

var _materials := {}
var _cache := {}
var _wheel: Node3D
var _cabins: Array[Node3D] = []
var _chase_materials: Array[ShaderMaterial] = []
var _chase_index := -1
var _chase_timer := 0.0
var _chase_phase := 0


func _ready() -> void:
	_load_materials()
	_apply_master(self)
	_wheel = find_child("1_SM_Ferris_Circle_Engine_03_StaticMeshComponent0", true, false) as Node3D
	if _wheel == null:
		return
	for child in _wheel.get_children():
		if child is Node3D:
			_cabins.append(child)


func _process(delta: float) -> void:
	_update_chase(delta)
	if _wheel == null:
		return
	var angle := speed * delta
	_wheel.rotate_z(angle)
	for cabin in _cabins:
		cabin.rotate_z(-angle)


func _update_chase(delta: float) -> void:
	if _chase_materials.is_empty():
		return
	if not chase_enabled:
		_set_chase_index(TEXT_LETTERS - 1)
		return
	_chase_timer -= delta
	if _chase_timer > 0.0:
		return
	match _chase_phase:
		0:
			_chase_index += 1
			_set_chase_index(_chase_index)
			if _chase_index >= TEXT_LETTERS - 1:
				_chase_phase = 1
				_chase_timer = chase_hold_seconds
			else:
				_chase_timer = chase_letter_seconds
		1:
			_chase_phase = 2
			_chase_timer = chase_dark_seconds
			_chase_index = -1
			_set_chase_index(_chase_index)
		2:
			_chase_phase = 0
			_chase_timer = chase_letter_seconds


func _set_chase_index(value: int) -> void:
	for mat in _chase_materials:
		mat.set_shader_parameter("chase_index", float(value))


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
				if key == TEXT_MATERIAL:
					if not _cache.has(key):
						_cache[key] = _build_chase_material(mat)
					mesh.surface_set_material(i, _cache[key])
					continue
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


func _build_chase_material(base: Material) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = MASTER_SHADER

	var base_mat := base as BaseMaterial3D
	if base_mat != null:
		if base_mat.albedo_texture != null:
			mat.set_shader_parameter("main_albedo", base_mat.albedo_texture)
		mat.set_shader_parameter("main_tint", base_mat.albedo_color)
		if base_mat.normal_texture != null:
			mat.set_shader_parameter("has_normal", true)
			mat.set_shader_parameter("main_normal", base_mat.normal_texture)

	mat.set_shader_parameter("tintmask_inten1", 0.0)
	mat.set_shader_parameter("tintmask_inten2", 0.0)
	mat.set_shader_parameter("inten1", Vector3.ZERO)
	mat.set_shader_parameter("inten2", Vector3.ZERO)
	mat.set_shader_parameter("chase_enabled", chase_enabled)
	mat.set_shader_parameter("chase_u0", TEXT_UV0)
	mat.set_shader_parameter("chase_du", TEXT_UV_STEP)
	mat.set_shader_parameter("chase_index", -1.0)
	mat.set_shader_parameter("emissive_energy", chase_energy)
	_chase_materials.append(mat)
	return mat


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
		mat.set_shader_parameter("normal_tiling", normal_tiling)

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
