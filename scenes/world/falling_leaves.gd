extends Node3D

## Leaves that let go near the town trees: each one tumbles down with a sway,
## settles on the grass for a breath, and quietly starts over from the top.

@export var leaf_count := 9
@export var radius := 4.5
@export var drop_height := 5.5
@export var fall_speed := 0.85

const PALETTE := [
	Color(0.6, 0.42, 0.2),
	Color(0.72, 0.5, 0.24),
	Color(0.5, 0.5, 0.24),
	Color(0.78, 0.62, 0.3),
]

var _time := 0.0
var _leaves: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []
var _fall: Array[float] = []
var _seeds: Array[float] = []
var _spots: Array[Vector2] = []
var _spins: Array[float] = []


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.15, 0.012, 0.1)
	for color in PALETTE:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_materials.append(material)
	for i in maxi(1, leaf_count):
		var leaf := MeshInstance3D.new()
		leaf.mesh = mesh
		leaf.material_override = _materials[i % _materials.size()]
		leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(leaf)
		_leaves.append(leaf)
		_seeds.append(randf() * TAU)
		_spins.append(randf_range(1.2, 3.0) * (1.0 if randf() > 0.5 else -1.0))
		_respawn(i, true)


## Drop a leaf in at a fresh height and spot. The first fill staggers heights so
## the swarm doesn't all land and reset on the same beat.
func _respawn(index: int, initial := false) -> void:
	var angle := randf() * TAU
	var distance := sqrt(randf()) * radius
	var spot := Vector2(cos(angle) * distance, sin(angle) * distance)
	var start_height := randf_range(0.25, 1.0) * drop_height if initial else drop_height
	var seed_value := randf() * TAU
	# First fill appends; later respawns overwrite in place.
	if index >= _spots.size():
		_spots.append(spot)
		_fall.append(start_height)
		_seeds.append(seed_value)
	else:
		_spots[index] = spot
		_fall[index] = start_height
		_seeds[index] = seed_value


func _process(delta: float) -> void:
	_time += delta
	for i in _leaves.size():
		_fall[i] -= fall_speed * (0.7 + 0.5 * sin(_seeds[i])) * delta
		if _fall[i] <= 0.04:
			_respawn(i)
			continue
		var spot := _spots[i]
		var leaf := _leaves[i]
		leaf.position = Vector3(
			spot.x + sin(_time * 1.1 + _seeds[i]) * 0.5,
			_fall[i],
			spot.y + cos(_time * 0.9 + _seeds[i] * 1.6) * 0.4
		)
		leaf.rotation.x += _spins[i] * delta
		leaf.rotation.z += _spins[i] * 0.6 * delta
