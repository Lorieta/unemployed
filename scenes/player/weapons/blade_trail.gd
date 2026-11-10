class_name BladeTrail
extends MeshInstance3D

## A short-lived ribbon that follows a weapon's tip during a swing. Vertices are
## written in world space, so the trail can be a child of the character without
## inheriting the fast limb rotations.

@export var lifetime := 0.2
@export var ribbon_width := 0.045
@export var points_per_frame := 1

var _tip: Node3D
var _tip_offset := Vector3.ZERO
var _color := Color(1.0, 0.9, 0.65, 0.7)
var _active := false
var _trail_time := 0.0
var _points: Array[Dictionary] = []
var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	material_override = _material
	visible = false

func set_tip(node: Node3D, offset: Vector3) -> void:
	_tip = node
	_tip_offset = offset

func begin(color: Color, duration := 0.0) -> void:
	_color = color
	_active = true
	_trail_time = duration
	_points.clear()
	visible = true

func end_trail() -> void:
	_active = false

func _process(delta: float) -> void:
	if _active and _tip != null and is_instance_valid(_tip):
		var sample := _tip.global_transform * _tip_offset
		_points.append({"position": sample, "time": 0.0})
		if _trail_time > 0.0:
			_trail_time -= delta
			if _trail_time <= 0.0:
				_active = false

	for point in _points:
		point["time"] = float(point["time"]) + delta
	while not _points.is_empty() and float(_points[0]["time"]) > lifetime:
		_points.pop_front()

	if _points.size() < 2:
		if not _active:
			visible = false
			_mesh.clear_surfaces()
		return

	_rebuild_mesh()

func _rebuild_mesh() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var count := _points.size()
	for i in count:
		var point: Dictionary = _points[i]
		var position: Vector3 = point["position"]
		var age := float(point["time"]) / maxf(lifetime, 0.001)
		var fade := clampf(1.0 - age, 0.0, 1.0)
		var tangent := Vector3.FORWARD
		if i < count - 1:
			tangent = (Vector3(_points[i + 1]["position"]) - position).normalized()
		elif i > 0:
			tangent = (position - Vector3(_points[i - 1]["position"])).normalized()
		var side := tangent.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		else:
			side = side.normalized()
		side = side * ribbon_width * (0.25 + fade * 0.75)
		var color := Color(_color.r, _color.g, _color.b, _color.a * fade)
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(position - side)
		_mesh.surface_set_color(Color(_color.r, _color.g, _color.b, color.a * 0.25))
		_mesh.surface_add_vertex(position + side + Vector3.UP * ribbon_width * 0.35)
	_mesh.surface_end()
