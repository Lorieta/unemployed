class_name Shockwave
extends Node3D

## An expanding ring of light used by the staff slam and heavy impacts.

var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _age := 0.0
var _duration := 0.55
var _max_radius := 3.0
var _start_radius := 0.35
var _light: OmniLight3D

func setup(color: Color, max_radius := 3.0, duration := 0.55) -> void:
	_max_radius = max_radius
	_duration = duration
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = color
	_material.emission_energy_multiplier = 1.8
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var torus := TorusMesh.new()
	torus.inner_radius = 0.86
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 5
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = _material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3.ONE * _start_radius
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 1.8
	_light.omni_range = 3.0
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.4, 0.0)
	add_child(_light)

func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / _duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.4)
	var radius := lerpf(_start_radius, _max_radius, eased)
	_ring.scale = Vector3(radius, 0.7 + eased * 0.4, radius)
	_material.albedo_color.a = (1.0 - t) * 0.75
	_material.emission_energy_multiplier = (1.0 - t) * 2.2
	_light.light_energy = (1.0 - t) * 1.8
	if t >= 1.0:
		queue_free()
