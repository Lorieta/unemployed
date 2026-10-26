extends Camera3D

## Smoothly keeps the character centered in a fixed 3/4 view.

@export var target_path: NodePath
@export var offset := Vector3(0.0, 2.6, 4.8)
@export var look_height := 1.0
@export var follow_smoothing := 7.0
## Optional offset in the direction of travel. Kept at 0 so the character
## stays exactly at the center of the view.
@export var look_ahead := 0.0

var _target: Node3D
var _last_target_position := Vector3.ZERO

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("FollowCamera: target_path does not point to a Node3D.")
		return

	global_position = _target.global_position + offset
	_last_target_position = _target.global_position
	_look_at_focus()

func _process(delta: float) -> void:
	if _target == null:
		return

	var target_position := _target.global_position
	var target_velocity := (target_position - _last_target_position) / maxf(delta, 0.0001)
	_last_target_position = target_position

	var desired_position := target_position + offset
	global_position = global_position.lerp(desired_position, 1.0 - exp(-follow_smoothing * delta))
	_look_at_focus(target_velocity)

func _look_at_focus(target_velocity := Vector3.ZERO) -> void:
	if _target == null:
		return
	var focus := _target.global_position + Vector3(0.0, look_height, 0.0)
	focus += target_velocity.limit_length(6.0) * look_ahead
	look_at(focus, Vector3.UP)
