extends CharacterBody3D

## Minimal FPS controller — works headless export, no GPU needed on server.
## Browser: click to capture mouse, WASD move, Shift sprint, Space jump, ESC to release.

@export var mouse_sensitivity: float = 0.0025
@export var normal_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

var yaw: float = 0.0
var pitch: float = 0.0
const PITCH_LIMIT := deg_to_rad(88)

@onready var cam: Camera3D = $Camera3D

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# start looking slightly down the corridor
	yaw = rotation.y
	pitch = cam.rotation.x

func _unhandled_input(event: InputEvent) -> void:
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
