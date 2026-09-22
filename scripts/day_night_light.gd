extends DirectionalLight3D

@export var day_energy: float = 1.2
@export var night_energy: float = 0.08
@export var day_color: Color = Color(1, 1, 1)
@export var night_color: Color = Color(0.35, 0.4, 0.65)
@export var fade_speed: float = 2.0

var _game: Node
var _target_energy: float
var _target_color: Color


func _ready() -> void:
	_target_energy = day_energy
	_target_color = day_color
	light_energy = day_energy
	light_color = day_color
	_game = get_tree().get_first_node_in_group("game")
	if _game:
		_game.night_started.connect(_on_night)
		_game.day_started.connect(_on_day)


func _on_night() -> void:
	_target_energy = night_energy
	_target_color = night_color


func _on_day() -> void:
	_target_energy = day_energy
	_target_color = day_color


func _process(delta: float) -> void:
	light_energy = move_toward(light_energy, _target_energy, fade_speed * delta)
	light_color = light_color.lerp(_target_color, clampf(fade_speed * delta, 0.0, 1.0))
