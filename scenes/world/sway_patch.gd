extends Node3D

## A patch of reeds or tall grass that sways in a slow wind. Every blade leans
## on its own phase and resting tilt, so the patch ripples instead of marching
## in step. Used along the wet hollows between the road and the wayshrine.

@export var blade_count := 12
@export var spread := 1.5
@export var height := 0.95
@export var tint := Color(0.32, 0.44, 0.24)
## Tan seed heads turn a grass patch into proper reeds.
@export var seed_heads := true
@export var sway := 0.17
@export var sway_speed := 1.25

var _time := 0.0
var _blades: Array[Node3D] = []
var _seeds: Array[float] = []
var _leans: Array[Vector2] = []


func _ready() -> void:
	var blade_material := StandardMaterial3D.new()
	blade_material.albedo_color = tint
	blade_material.roughness = 1.0
	blade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color(0.55, 0.45, 0.26)
	head_material.roughness = 1.0

	for i in maxi(1, blade_count):
		var blade := Node3D.new()
		var angle := randf() * TAU
		var distance := sqrt(randf()) * spread
		blade.position = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		add_child(blade)

		var h := height * randf_range(0.7, 1.2)
		var stem := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.012
		mesh.bottom_radius = 0.03
		mesh.height = h
		mesh.radial_segments = 5
		stem.mesh = mesh
		stem.material_override = blade_material
		stem.position = Vector3(0.0, h * 0.5, 0.0)
		stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blade.add_child(stem)

		if seed_heads and randf() > 0.35:
			var head := MeshInstance3D.new()
			var head_mesh := SphereMesh.new()
			head_mesh.radius = 0.045
			head_mesh.height = 0.2
			head_mesh.radial_segments = 6
			head_mesh.rings = 3
			head.mesh = head_mesh
			head.material_override = head_material
			head.position = Vector3(0.0, h + 0.06, 0.0)
			head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			blade.add_child(head)

		_blades.append(blade)
		_seeds.append(randf() * TAU)
		_leans.append(Vector2(randf_range(-0.12, 0.12), randf_range(-0.1, 0.1)))


func _process(delta: float) -> void:
	_time += delta
	for i in _blades.size():
		var seed_value := _seeds[i]
		var lean := _leans[i]
		_blades[i].rotation.z = lean.x + sin(_time * sway_speed + seed_value) * sway
		_blades[i].rotation.x = lean.y + cos(_time * sway_speed * 0.83 + seed_value * 1.4) * sway * 0.6
