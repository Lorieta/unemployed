extends Node3D

## A drifting swarm of glowing motes — fireflies over the field, pollen over
## the town green. Each mote is a tiny emissive mesh bobbing on its own sine
## drift; none of them carry lights, so a swarm costs almost nothing and reads
## beautifully against the dusk.

@export var motes := 14
@export var radius := 7.0
@export var height := 1.7
@export var color := Color(0.85, 0.95, 0.55, 1.0)
@export var drift := 1.0

var _time := 0.0
var _meshes: Array[MeshInstance3D] = []
var _seeds: Array[float] = []
var _base: Array[Vector3] = []
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 2.6
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3

	for i in motes:
		var mote := MeshInstance3D.new()
		mote.mesh = mesh
		mote.material_override = _material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := randf() * TAU
		var distance := sqrt(randf()) * radius
		var spot := Vector3(cos(angle) * distance, randf_range(0.3, height), sin(angle) * distance)
		mote.position = spot
		add_child(mote)
		_meshes.append(mote)
		_base.append(spot)
		_seeds.append(randf() * TAU)


func _process(delta: float) -> void:
	_time += delta
	for i in _meshes.size():
		var seed_value := _seeds[i]
		var base := _base[i]
		var drift_radius := 0.6 + 0.5 * sin(seed_value)
		var offset := Vector3(
			sin(_time * 0.7 * drift + seed_value) * drift_radius,
			sin(_time * 1.1 * drift + seed_value * 1.7) * 0.3,
			cos(_time * 0.55 * drift + seed_value * 0.9) * drift_radius
		)
		_meshes[i].position = base + offset
		_meshes[i].scale = Vector3.ONE * (0.8 + 0.35 * sin(_time * 2.2 + seed_value))
