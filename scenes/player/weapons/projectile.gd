class_name Projectile
extends Node3D

## Arrows and foxfire wisps. Arrows fly straight, wisps curve after their target.
## Both report a hit back to the caster so quests and damage numbers stay in sync.

signal hit_target(target: Node, amount: float)

var _kind := "arrow"
var _velocity := Vector3.ZERO
var _target: Node3D
var _damage := 10.0
var _color := Color(0.9, 0.85, 0.6, 1.0)
var _life := 3.0
var _hit_radius := 0.85
var _gravity := 0.0
var _turn_rate := 7.0
var _impacted := false

func configure(kind: String, direction: Vector3, target: Node3D, damage: float, color: Color) -> void:
	_kind = kind
	_target = target
	_damage = damage
	_color = color
	var dir := direction.normalized()
	if kind == "arrow":
		_velocity = dir * 26.0
		_gravity = 2.4
		_life = 3.0
		_hit_radius = 0.95
		_build_arrow(dir)
	else:
		_velocity = dir * 9.5
		_life = 4.0
		_hit_radius = 0.8
		_turn_rate = 8.5
		_build_wisp()

func _build_arrow(direction: Vector3) -> void:
	var shaft_material := StandardMaterial3D.new()
	shaft_material.albedo_color = Color(0.62, 0.46, 0.26, 1.0)
	shaft_material.roughness = 0.8

	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.012
	shaft_mesh.bottom_radius = 0.012
	shaft_mesh.height = 0.72
	shaft_mesh.radial_segments = 5
	shaft.mesh = shaft_mesh
	shaft.material_override = shaft_material
	shaft.rotation.x = PI * 0.5
	add_child(shaft)

	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.024
	tip_mesh.height = 0.12
	tip_mesh.radial_segments = 4
	tip.mesh = tip_mesh
	tip.material_override = _make_emissive(Color(0.72, 0.78, 0.88, 1.0), 0.25)
	tip.rotation.x = -PI * 0.5
	tip.position = Vector3(0.0, 0.0, -0.4)
	add_child(tip)

	for i in 2:
		var fletch := MeshInstance3D.new()
		var fletch_mesh := BoxMesh.new()
		fletch_mesh.size = Vector3(0.012, 0.07, 0.12)
		fletch.mesh = fletch_mesh
		fletch.material_override = _make_emissive(_color.darkened(0.15), 0.0)
		fletch.position = Vector3(0.0, 0.0, 0.29)
		fletch.rotation.z = float(i) * PI * 0.5 + 0.4
		add_child(fletch)

	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 0.25
	light.omni_range = 1.2
	light.shadow_enabled = false
	add_child(light)

	global_position = global_position - direction * 0.0
	look_at(global_position + direction * 4.0, Vector3.UP)

func _build_wisp() -> void:
	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.11
	orb_mesh.height = 0.22
	orb_mesh.radial_segments = 8
	orb_mesh.rings = 5
	orb.mesh = orb_mesh
	orb.material_override = _make_emissive(_color, 2.8)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)

	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.2
	halo_mesh.height = 0.4
	halo_mesh.radial_segments = 8
	halo_mesh.rings = 5
	halo.mesh = halo_mesh
	halo.material_override = _make_glow(_color)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

	var tail := MeshInstance3D.new()
	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.004
	tail_mesh.bottom_radius = 0.075
	tail_mesh.height = 0.42
	tail_mesh.radial_segments = 6
	tail.mesh = tail_mesh
	tail.material_override = _make_glow(_color)
	tail.rotation.x = -PI * 0.5
	tail.position = Vector3(0.0, 0.0, 0.26)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tail)

	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 1.1
	light.omni_range = 2.4
	light.shadow_enabled = false
	add_child(light)

func _make_emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.25
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
	return material

func _make_glow(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(color.r, color.g, color.b, 0.6)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.4
	return material

func _physics_process(delta: float) -> void:
	if _impacted:
		return
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return

	if _kind != "arrow" and _target != null and is_instance_valid(_target):
		var goal := _target.global_position + Vector3(0.0, 0.85, 0.0)
		var desired := (goal - global_position).normalized() * _velocity.length()
		_velocity = _velocity.lerp(desired, clampf(_turn_rate * delta, 0.0, 1.0))

	if _kind == "arrow":
		_velocity.y -= _gravity * delta
		look_at(global_position + _velocity.normalized() * 2.0, Vector3.UP)
	else:
		scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08)

	global_position += _velocity * delta

	if _kind == "arrow" and global_position.y < 0.12:
		_impact(null)
		return

	for candidate in _damageable_targets():
		if not is_instance_valid(candidate):
			continue
		if not candidate.has_method("take_damage"):
			continue
		if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
			continue
		var center: Vector3 = candidate.global_position + Vector3(0.0, 0.9, 0.0)
		if global_position.distance_to(center) <= _hit_radius:
			_impact(candidate)
			return

	# A wisp that reaches its target still connects even if the target moved a
	# little at the last moment.
	if _kind != "arrow" and _target != null and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position + Vector3(0.0, 0.85, 0.0)) < 1.0:
			_impact(_target)

func _impact(target: Node) -> void:
	if _impacted:
		return
	_impacted = true
	if target != null and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(_damage, global_position)
		hit_target.emit(target, _damage)
	_spawn_flash()
	queue_free()

## Both the practice yard and the field answer to the same arrows and foxfire.
## Targets are de-duplicated so a node carrying both groups is only hit once.
func _damageable_targets() -> Array:
	var result := []
	for group in ["training_dummy", "enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			if not result.has(node):
				result.append(node)
	return result

func _spawn_flash() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var flash := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 8
	mesh.rings = 5
	flash.mesh = mesh
	var material := _make_glow(_color)
	flash.material_override = material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.global_position = global_position
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.8, 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.22)
	tween.chain().tween_callback(flash.queue_free)
