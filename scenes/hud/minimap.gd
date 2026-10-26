extends Control

## Keeps a top-down camera over the player and shares the main world so the
## little framed minimap is a real live view rather than a drawn fake.

@export var target_path: NodePath
@export var camera_height := 30.0
@export var map_size := 28.0

@onready var _viewport: SubViewport = $MapViewport/SubViewport
@onready var _camera: Camera3D = $MapViewport/SubViewport/MapCamera

var _target: Node3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target = _resolve_target()
	_viewport.world_3d = get_viewport().world_3d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = map_size
	_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_camera.current = true
	_update_camera()

func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = _resolve_target()
	_update_camera()

func _resolve_target() -> Node3D:
	if not target_path.is_empty():
		var node := get_node_or_null(target_path)
		if node is Node3D:
			return node
	return get_tree().get_first_node_in_group("player") as Node3D

func _update_camera() -> void:
	if _target == null:
		return
	_camera.global_position = Vector3(_target.global_position.x, camera_height, _target.global_position.z)
