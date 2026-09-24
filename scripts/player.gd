extends CharacterBody3D

## Minimal FPS controller — works headless export, no GPU needed on server.
## Browser: click to capture mouse, WASD move, Shift sprint, Space jump, ESC to release.

@export var mouse_sensitivity: float = 0.0025
@export var normal_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var scratch_damage: float = 0.6
@export var stamina_max: float = 100.0
@export var sprint_stamina_seconds: float = 30.0
@export var head_bob_amplitude: float = 0.045
@export var head_bob_frequency: float = 8.0
@export var sprint_fov_kick: float = 8.0
@export var shake_decay: float = 1.8
@export var shake_max_offset: float = 0.09
@export var shake_max_roll: float = 0.035

var yaw: float = 0.0
var pitch: float = 0.0
var coins: int = 0
var input_locked: bool = false
var stamina: float = 100.0
const PITCH_LIMIT := deg_to_rad(88)

@onready var cam: Camera3D = $Camera3D
var _hud: Node
var _prompt_owner: Object = null
var _game: Node
var _cam_base_pos := Vector3.ZERO
var _base_fov := 70.0
var _bob_phase := 0.0
var _trauma := 0.0
var _land_dip := 0.0
var _was_on_floor := true
var _shake_time := 0.0
var _shake_noise := FastNoiseLite.new()

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# start looking slightly down the corridor
	yaw = rotation.y
	pitch = cam.rotation.x
	_hud = get_tree().get_first_node_in_group("hud")
	_game = get_tree().get_first_node_in_group("game")
	_cam_base_pos = cam.position
	_base_fov = cam.fov
	_shake_noise.frequency = 0.6
	if _game and _game.has_signal("player_died"):
		_game.player_died.connect(_on_player_died)
	stamina = stamina_max
	_update_coins_label()
	if _game and _game.has_method("load_if_pending"):
		_game.load_if_pending()


func restore_stamina(amount: float) -> void:
	stamina = clampf(stamina + amount, 0.0, stamina_max)


func set_coins(value: int) -> void:
	coins = value
	_update_coins_label()


func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, stamina_max)


func current_noise_radius() -> float:
	if input_locked:
		return 0.0
	if Vector2(velocity.x, velocity.z).length() <= 0.5:
		return 0.0
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	var sprinting := Input.is_action_pressed("sprint") and stamina > 0.0
	if _game:
		return float(_game.noise_sprint_radius) if sprinting else float(_game.noise_walk_radius)
	return 12.0 if sprinting else 4.0

func set_input_locked(value: bool) -> void:
	input_locked = value
	if value:
		velocity = Vector3.ZERO
		show_prompt("")

func show_prompt(text: String, owner: Object = null) -> void:
	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud")
	if _hud == null:
		return
	if text == "":
		if owner == null or owner == _prompt_owner:
			_hud.set_prompt("")
			_prompt_owner = null
		return
	_prompt_owner = owner
	_hud.set_prompt(text)

func add_coins(amount: int) -> void:
	coins += amount
	_update_coins_label()

func _update_coins_label() -> void:
	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud")
	if _hud and _hud.has_method("set_coins"):
		_hud.set_coins(coins)

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT)
		rotation.y = yaw
		cam.rotation.x = pitch

	if event is InputEventMouseButton and event.pressed:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			get_viewport().set_input_as_handled()

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("use_gadget"):
		_use_gadget()


func _use_gadget() -> void:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	if _game:
		_game.use_active_gadget()


func _move_speed_multiplier() -> float:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	if _game and _game.has_method("move_speed_multiplier"):
		return float(_game.move_speed_multiplier())
	return 1.0

func _physics_process(delta: float) -> void:
	_update_shake(delta)
	if input_locked:
		if not is_on_floor():
			velocity.y -= gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# movement: Input.get_vector("left","right","forward","back") => y=-1 when forward
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis.x * input_dir.x + transform.basis.z * input_dir.y)
	direction.y = 0
	if direction.length() > 0:
		direction = direction.normalized()

	var moving := direction != Vector3.ZERO
	var sprinting := moving and Input.is_action_pressed("sprint") and stamina > 0.0
	if sprinting:
		stamina = maxf(0.0, stamina - (stamina_max / maxf(0.001, sprint_stamina_seconds)) * delta)

	var speed := (sprint_speed if sprinting else normal_speed) * _move_speed_multiplier()

	if moving:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 6.0)

	move_and_slide()
	_update_camera(delta, moving, sprinting)


func _update_camera(delta: float, moving: bool, sprinting: bool) -> void:
	var on_floor := is_on_floor()
	var bob := Vector3.ZERO
	if _head_bob_enabled():
		if on_floor and not _was_on_floor:
			_land_dip = 0.06
		_land_dip = lerpf(_land_dip, 0.0, clampf(delta * 9.0, 0.0, 1.0))
		if moving and on_floor:
			var speed_scale := 1.5 if sprinting else 1.0
			_bob_phase += delta * head_bob_frequency * speed_scale
			var amp := head_bob_amplitude * speed_scale
			bob.y = sin(_bob_phase * TAU) * amp
			bob.x = cos(_bob_phase * TAU * 0.5) * amp * 0.5
		else:
			_bob_phase = 0.0
		bob.y -= _land_dip
	else:
		_bob_phase = 0.0
		_land_dip = 0.0
	_was_on_floor = on_floor
	cam.position = cam.position.lerp(_cam_base_pos + bob, clampf(delta * 14.0, 0.0, 1.0))

	var target_fov := _base_fov + (sprint_fov_kick if sprinting else 0.0)
	cam.fov = lerpf(cam.fov, target_fov, clampf(delta * 6.0, 0.0, 1.0))


func _head_bob_enabled() -> bool:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	if _game and _game.has_method("head_bob_enabled"):
		return bool(_game.head_bob_enabled())
	return true


func _screen_shake_enabled() -> bool:
	if _game == null:
		_game = get_tree().get_first_node_in_group("game")
	if _game and _game.has_method("screen_shake_enabled"):
		return bool(_game.screen_shake_enabled())
	return true


func add_shake(amount: float) -> void:
	if not _screen_shake_enabled():
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _update_shake(delta: float) -> void:
	if not _screen_shake_enabled():
		if _trauma > 0.0 or cam.h_offset != 0.0 or cam.v_offset != 0.0 or cam.rotation.z != 0.0:
			_trauma = 0.0
			cam.h_offset = 0.0
			cam.v_offset = 0.0
			cam.rotation.z = 0.0
		return
	if _trauma <= 0.0:
		return
	_shake_time += delta
	var t := _trauma * _trauma
	var s := _shake_time * 34.0
	cam.h_offset = _shake_noise.get_noise_2d(s, 0.0) * shake_max_offset * t
	cam.v_offset = _shake_noise.get_noise_2d(0.0, s) * shake_max_offset * t
	cam.rotation.z = _shake_noise.get_noise_2d(s, 100.0) * shake_max_roll * t
	_trauma = maxf(0.0, _trauma - shake_decay * delta)
	if _trauma <= 0.0:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		cam.rotation.z = 0.0


func _on_player_died() -> void:
	add_shake(1.0)
