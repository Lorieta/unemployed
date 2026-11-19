extends Node3D

## Looping chimney smoke: soft grey puffs that climb from the pot, lean with
## the wind, swell and thin out, then start over. A few meshes, no lights, so
## every cottage in Hearthmere can afford its own lazy column of smoke.

@export var puff_count := 4
@export var rise_height := 2.4
@export var cycle := 3.4
@export var wind := Vector3(0.35, 0.0, 0.22)
@export var tint := Color(0.78, 0.78, 0.8)
## Seconds before the first puff lets go, so chimneys don't puff in lockstep.
@export var start_delay := 0.0

var _time := 0.0
var _puffs: Array[MeshInstance3D] = []
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_time = -absf(start_delay)
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.4
	mesh.radial_segments = 8
	mesh.rings = 4
	for i in maxi(1, puff_count):
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(tint.r, tint.g, tint.b, 0.0)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 1.0
		puff.material_override = material
		add_child(puff)
		_puffs.append(puff)
		_materials.append(material)


func _process(delta: float) -> void:
	_time += delta
	var period := maxf(cycle, 0.4)
	for i in _puffs.size():
		# posmod keeps the loop kind when _time is still negative from the delay.
		var progress := posmod(_time / period + float(i) / float(_puffs.size()), 1.0)
		var puff := _puffs[i]
		var lift := progress * rise_height
		puff.position = Vector3(wind.x * lift, lift, wind.z * lift)
		var swell := 0.45 + progress * 1.15
		puff.scale = Vector3(swell, swell * 0.85, swell)
		var alpha := 0.0
		if progress < 0.18:
			alpha = progress / 0.18 * 0.5
		elif progress > 0.55:
			alpha = (1.0 - (progress - 0.55) / 0.45) * 0.5
		else:
			alpha = 0.5
		_materials[i].albedo_color.a = alpha
