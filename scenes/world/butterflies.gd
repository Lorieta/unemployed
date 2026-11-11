extends Node3D

## A loose swarm of butterflies over the flowers: two flapping wings each,
## wandering on a slow drifting path and always facing the way they travel.
## Cheap meshes, no lights — the swarm exists to make the green feel alive.

@export var butterfly_count := 7
@export var radius := 6.0
@export var height := 1.4
@export var flap_speed := 13.0

const PALETTE := [
	Color(0.95, 0.8, 0.35),
	Color(0.9, 0.55, 0.65),
	Color(0.78, 0.85, 0.97),
	Color(0.94, 0.92, 0.85),
]

var _time := 0.0
var _flies: Array[Node3D] = []
var _left_wings: Array[Node3D] = []
var _right_wings: Array[Node3D] = []
var _seeds: Array[float] = []
var _previous: Array[Vector3] = []
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	for color in PALETTE:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.85
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials.append(material)

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.035, 0.035, 0.15)
	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(0.2, 0.008, 0.13)

	for i in maxi(1, butterfly_count):
		var material: StandardMaterial3D = _materials[i % _materials.size()]
		var fly := Node3D.new()
		add_child(fly)

		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = material
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fly.add_child(body)

		for side in [-1, 1]:
			var hinge := Node3D.new()
			hinge.position = Vector3(0.02 * float(side), 0.0, 0.0)
			fly.add_child(hinge)
			var wing := MeshInstance3D.new()
			wing.mesh = wing_mesh
			wing.material_override = material
			wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wing.position = Vector3(0.11 * float(side), 0.0, 0.0)
			hinge.add_child(wing)
			if side < 0:
				_left_wings.append(hinge)
			else:
				_right_wings.append(hinge)

		var angle := randf() * TAU
		var distance := sqrt(randf()) * radius
		var spot := Vector3(cos(angle) * distance, randf_range(0.5, height), sin(angle) * distance)
		fly.position = spot
		_flies.append(fly)
		_seeds.append(randf() * TAU)
		_previous.append(spot)


func _process(delta: float) -> void:
	_time += delta
	for i in _flies.size():
		var seed_value := _seeds[i]
		var fly := _flies[i]
		var wander := Vector3(
			sin(_time * 0.42 + seed_value) * (radius * 0.6) + sin(_time * 0.9 + seed_value * 2.1) * 0.4,
			height * 0.55 + sin(_time * 1.4 + seed_value * 1.3) * 0.45,
			cos(_time * 0.36 + seed_value * 0.7) * (radius * 0.6) + cos(_time * 0.8 + seed_value) * 0.4
		)
		var next := wander
		var heading := next - _previous[i]
		_previous[i] = next
		fly.position = next
		if Vector2(heading.x, heading.z).length_squared() > 0.0001:
			fly.rotation.y = atan2(-heading.x, -heading.z)
		# The flap: mirrored hinges scissor out of phase around flat glide.
		var flap := sin(_time * flap_speed + seed_value * 3.0) * 0.95
		_left_wings[i].rotation.z = flap * 0.6
		_right_wings[i].rotation.z = -flap
