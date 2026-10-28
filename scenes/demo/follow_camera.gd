extends Camera3D

## Smoothly keeps the character centered in a fixed 3/4 view.
## Right-click drag to orbit, scroll wheel to zoom.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 2.6, 4.8)
@export var look_height := 1.0
@export var follow_smoothing := 7.0
## Optional offset in the direction of travel. Kept at 0 so the character
## stays exactly at the center of the view.
@export var look_ahead := 0.0

@export var orbit_sensitivity := 0.1
@export var orbit_distance := 4.8
@export var orbit_pitch_min := -89.0
@export var orbit_pitch_max := 89.0

## When enabled, the camera eases behind the player's facing direction while
## they move. Right-click orbit acts as a manual override and pauses the
## auto-follow for `resume_delay` seconds after release.
@export var auto_follow := true
@export var follow_speed := 3.0
@export var resume_delay := 1.5

var _target: Node3D
var _last_target_position := Vector3.ZERO
var _orbit_rotation := Vector2.ZERO  # stored in radians
var _orbit_enabled := false
var _orbit_distance := 4.8
var _elapsed := 0.0
var _manual_orbit_time := -100.0

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("FollowCamera: target_path does not point to a Node3D.")
		return

	global_position = _target.global_position + offset
	_last_target_position = _target.global_position
	# Start the orbit so the first frame matches the designed offset view
	# instead of snapping to the raw orbit formula at yaw 0.
	_orbit_distance = offset.length()
	_orbit_rotation.y = atan2(offset.z, offset.x)
	_orbit_rotation.x = -asin(clampf(offset.y / _orbit_distance, -1.0, 1.0))
	_look_at_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _orbit_enabled:
		_orbit_rotation += Vector2(-event.relative.y, event.relative.x) * orbit_sensitivity * 0.01
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_orbit_enabled = event.pressed
			_manual_orbit_time = _elapsed
		elif event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_orbit_distance = max(1.0, _orbit_distance - 0.5)
				MOUSE_BUTTON_WHEEL_DOWN:
					_orbit_distance = max(1.0, _orbit_distance + 0.5)

func _process(delta: float) -> void:
	if _target == null:
		return

	var target_position := _target.global_position
	var target_velocity := (target_position - _last_target_position) / maxf(delta, 0.0001)
	_last_target_position = target_position
	_elapsed += delta

	if auto_follow and _elapsed - _manual_orbit_time > resume_delay and not _orbit_enabled:
		var horizontal_speed := Vector2(target_velocity.x, target_velocity.z).length()
		if horizontal_speed > 0.4:
			# Sit behind the character: the rig's +Z is its back, so the
			# orbit offset should point along global_basis.z.
			var behind := _target.global_basis.z
			behind.y = 0.0
			if behind.length_squared() > 0.0001:
				var target_yaw := atan2(behind.z, behind.x)
				_orbit_rotation.y = lerp_angle(
					_orbit_rotation.y, target_yaw, 1.0 - exp(-follow_speed * delta)
				)

	var desired_position := target_position + offset
	global_position = global_position.lerp(desired_position, 1.0 - exp(-follow_smoothing * delta))

	## Orbit calculation - _orbit_rotation is in radians
	var pitch_clamped: float = clamp(_orbit_rotation.x, deg_to_rad(orbit_pitch_min), deg_to_rad(orbit_pitch_max))
	var pitch: float = -pitch_clamped
	var yaw := _orbit_rotation.y
	var cos_pitch := cos(pitch)
	var sin_pitch := sin(pitch)
	var cos_yaw := cos(yaw)
	var sin_yaw := sin(yaw)

	var orbit_offset := Vector3(
		cos_yaw * cos_pitch * _orbit_distance,
		sin_pitch * _orbit_distance,
		sin_yaw * cos_pitch * _orbit_distance
	)

	global_position = target_position + orbit_offset
	_look_at_focus(target_velocity)

func _look_at_focus(target_velocity := Vector3.ZERO) -> void:
	if _target == null:
		return
	var focus := _target.global_position + Vector3(0.0, look_height, 0.0)
	focus += target_velocity.limit_length(6.0) * look_ahead
	look_at(focus, Vector3.UP)
