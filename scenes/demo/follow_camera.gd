extends Camera3D

## Third-person RPG camera with mouse-locked center control.
## Mouse movement rotates the camera; character faces camera direction.
## WASD movement is relative to camera.

@export var target_path: NodePath
@export var camera_distance := 4.8
@export var camera_height := 2.6
@export var look_height := 1.0
@export var follow_smoothing := 10.0
@export var mouse_sensitivity := 0.003
@export var vertical_sensitivity := 0.002
@export var min_pitch := -60.0
@export var max_pitch := 45.0
@export var lock_mouse := true
@export var look_ahead := 0.0

var _target: Node3D
var _yaw := 0.0
var _pitch := -25.0
var _camera_offset := Vector3.ZERO

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("FollowCamera: target_path does not point to a Node3D.")
		return
	if lock_mouse and not _ui_active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Initialize yaw from target
	if _target != null:
		_yaw = _target.rotation.y

## The HUD owns cursor capture: while any interactive panel is open the pointer
## belongs to the UI, so the camera must neither read it nor grab it back.
func _ui_active() -> bool:
	var hud := get_tree().get_first_node_in_group("hud")
	return hud != null and hud.is_node_ready() and hud.has_method("is_ui_active") and bool(hud.call("is_ui_active"))

func _input(event: InputEvent) -> void:
	if _ui_active():
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * vertical_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera_distance = max(2.0, camera_distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera_distance = max(2.0, camera_distance + 0.3)

func _process(delta: float) -> void:
	if _target == null:
		return

	var target_pos := _target.global_position

	# Calculate camera position based on yaw and pitch
	var cam_x := target_pos.x + camera_distance * sin(_yaw) * cos(_pitch)
	var cam_y := target_pos.y + camera_height + camera_distance * sin(_pitch)
	var cam_z := target_pos.z + camera_distance * cos(_yaw) * cos(_pitch)
	var desired_pos := Vector3(cam_x, cam_y, cam_z)

	global_position = global_position.lerp(desired_pos, 1.0 - exp(-follow_smoothing * delta))

	# Look at target
	var look_target := target_pos + Vector3(0, look_height, 0)
	look_at(look_target, Vector3.UP)

	# Make character face the camera's horizontal direction
	if _target.has_method("set_camera_yaw"):
		_target.call("set_camera_yaw", _yaw)
	elif _target is Node3D:
		# Face in the direction camera is looking (horizontal)
		var camera_forward := -global_transform.basis.z
		camera_forward.y = 0
		if camera_forward.length_squared() > 0.001:
			_target.rotation.y = atan2(camera_forward.x, camera_forward.z)

func _look_at_focus(target_velocity := Vector3.ZERO) -> void:
	if _target == null:
		return
	var focus := _target.global_position + Vector3(0.0, look_height, 0.0)
	focus += target_velocity.limit_length(6.0) * look_ahead
	look_at(focus, Vector3.UP)
