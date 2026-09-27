extends DirectionalLight3D

@export var day_energy: float = 1.2
@export var night_energy: float = 0.08
@export var day_color: Color = Color(1, 1, 1)
@export var night_color: Color = Color(0.35, 0.4, 0.65)
@export var fade_speed: float = 2.0
@export var debug_energy: float = 2.5

var _game: Node
var _env: Environment
var _target_energy: float
var _target_color: Color
var _debug := false
var _base_ambient_energy: float
var _base_ambient_color: Color
var _base_background_mode: int
var _base_background_color: Color
var _base_fog: bool


func _ready() -> void:
	_target_energy = day_energy
	_target_color = day_color
	light_energy = day_energy
	light_color = day_color
	_game = get_tree().get_first_node_in_group("game")
	if _game:
		_game.night_started.connect(_on_night)
		_game.day_started.connect(_on_day)
	var world_env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env != null:
		_env = world_env.environment.duplicate()
		world_env.environment = _env
		_base_ambient_energy = _env.ambient_light_energy
		_base_ambient_color = _env.ambient_light_color
		_base_background_mode = _env.background_mode
		_base_background_color = _env.background_color
		_base_fog = _env.fog_enabled


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_B:
		_toggle_debug()


func _toggle_debug() -> void:
	_debug = not _debug
	if _env == null:
		return
	if _debug:
		_env.ambient_light_energy = 1.0
		_env.ambient_light_color = Color(1, 1, 1)
		_env.background_mode = Environment.BG_COLOR
		_env.background_color = Color(0.5, 0.5, 0.55)
		_env.fog_enabled = false
	else:
		_env.ambient_light_energy = _base_ambient_energy
		_env.ambient_light_color = _base_ambient_color
		_env.background_mode = _base_background_mode
		_env.background_color = _base_background_color
		_env.fog_enabled = _base_fog


func _on_night() -> void:
	_target_energy = night_energy
	_target_color = night_color


func _on_day() -> void:
	_target_energy = day_energy
	_target_color = day_color


func _process(delta: float) -> void:
	if _debug:
		light_energy = debug_energy
		light_color = Color(1, 1, 1)
		return
	light_energy = move_toward(light_energy, _target_energy, fade_speed * delta)
	light_color = light_color.lerp(_target_color, clampf(fade_speed * delta, 0.0, 1.0))
