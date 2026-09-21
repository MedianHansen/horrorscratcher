extends CharacterBody3D

## Minimal FPS controller — works headless export, no GPU needed on server.
## Browser: click to capture mouse, WASD move, Shift sprint, Space jump, ESC to release.

@export var mouse_sensitivity: float = 0.0025
@export var normal_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8
@export var scratch_damage: float = 2.0

var yaw: float = 0.0
var pitch: float = 0.0
var coins: int = 0
var input_locked: bool = false
const PITCH_LIMIT := deg_to_rad(88)

@onready var cam: Camera3D = $Camera3D
var _coins_label: Label
var _prompt_label: Label

func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# start looking slightly down the corridor
	yaw = rotation.y
	pitch = cam.rotation.x
	_coins_label = get_node_or_null("../UI/Coins")
	_prompt_label = get_node_or_null("../UI/Prompt")
	_update_coins_label()

func set_input_locked(value: bool) -> void:
	input_locked = value
	if value:
		velocity = Vector3.ZERO
		show_prompt("")

func show_prompt(text: String) -> void:
	if _prompt_label:
		_prompt_label.text = text

func add_coins(amount: int) -> void:
	coins += amount
	_update_coins_label()

func _update_coins_label() -> void:
	if _coins_label:
		_coins_label.text = "Coins: %d" % coins

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

func _physics_process(delta: float) -> void:
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

	var speed := sprint_speed if Input.is_action_pressed("sprint") else normal_speed

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta * 6.0)
		velocity.z = move_toward(velocity.z, 0, speed * delta * 6.0)

	move_and_slide()
