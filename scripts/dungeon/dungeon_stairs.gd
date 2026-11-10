extends StaticBody3D

## The stairwell built from primitives that appears in dungeon rooms: the
## descend stair in the boss room once a floor's warden falls, or an ascent
## stair in each floor's entrance. Stands in the "interactable" group so the
## hero can walk up and talk to it, and reports the interaction to the dungeon
## manager through the `used` signal.

signal used

@export var ascent := false

var unlocked := false
var _runes: Array[StandardMaterial3D] = []
var _time := 0.0

func _ready() -> void:
	add_to_group("interactable")
	var stone := _mat(Color(0.27, 0.27, 0.28), 0.92)
	var iron := _mat(Color(0.3, 0.28, 0.25), 0.5, 0.5)
	add_to_group("dungeon_stairs")
	for i in 12:
		var angle := float(i) * 0.55
		var step_center := Vector3(cos(angle) * 1.5, 0.12 + float(i) * 0.26, sin(angle) * 1.5)
		var step_size := Vector3(1.7, 0.24, 0.9)
		_add_step(self, _yaw_rotate(step_center, -angle), _yaw_rotated_size(step_size, -angle), stone, -angle)
	var base := _add_mesh_cylinder(self, Vector3(0.0, -0.2, 0.0), 2.4, 0.4, iron)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.62) if ascent else Color(0.8, 0.85, 1.0)
	light.light_energy = 0.35
	light.omni_range = 4.5
	light.position = Vector3(0.0, 2.4, 0.0)
	add_child(light)

func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 1.04, 0.4)
	tween.tween_property(self, "scale", Vector3.ONE, 0.3)
	for material in _runes:
		material.emission_enabled = true
		material.emission = Color(0.55, 0.75, 1.0)
		material.emission_energy_multiplier = 1.4

func can_interact() -> bool:
	return unlocked

func get_interaction_prompt() -> String:
	if unlocked:
		return "[ E ]     Ascend through the dungeon" if ascent else "[ E ]     Descend to the next depth"
	return "The stairwell is sealed.  Something watches."

func interact(_player: Node) -> void:
	if not unlocked:
		return
	used.emit()

func _process(delta: float) -> void:
	_time += delta
	if not unlocked:
		return
	for i in _runes.size():
		_runes[i].emission_energy_multiplier = 1.3 + sin(_time * 2.4 + float(i)) * 0.35

func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_runes.append(material)
	return material

func _yaw_rotate(offset: Vector3, angle: float) -> Vector3:
	var cos_value := cos(angle)
	var sin_value := sin(angle)
	return Vector3(offset.x * cos_value - offset.z * sin_value, offset.y, offset.x * sin_value + offset.z * cos_value)

## Boxes rotate around their own origin, so each step's center is orbit-rotated
## while its footprint stays square to the stair core.
func _yaw_rotated_size(size: Vector3, _angle: float) -> Vector3:
	return size

func _add_step(parent: Node3D, position: Vector3, size: Vector3, material: StandardMaterial3D, angle: float) -> void:
	var step := Node3D.new()
	step.position = position
	step.rotation.y = angle
	parent.add_child(step)
	var step_body := StaticBody3D.new()
	step.add_child(step_body)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	step_body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	step_body.add_child(mesh_instance)

func _add_mesh_cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 12
	cylinder.rings = 2
	cylinder.material = material
	node.mesh = cylinder
	node.position = position
	parent.add_child(node)
	return node
