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
var _options: Dictionary = {}
var _pierce := 0
var _explode_radius := 0.0
var _explode_damage := 0.0
var _slow_factor := 0.0
var _slow_duration := 0.0
var _hit_nodes := {}
var _exploded := false

func configure(kind: String, direction: Vector3, target: Node3D, damage: float, color: Color, options := {}) -> void:
	_kind = kind
	_target = target
	_damage = damage
	_color = color
	_options = options
	_pierce = maxi(0, int(options.get("pierce", 0)))
	_explode_radius = float(options.get("explode_radius", 0.0))
	_explode_damage = float(options.get("explode_damage", 0.0))
	_slow_factor = float(options.get("slow", 0.0))
	_slow_duration = float(options.get("slow_duration", 0.0))
	var dir := direction.normalized()
	match kind:
		"arrow":
			_velocity = dir * 26.0
			_gravity = 2.4
			_life = 3.0
			_hit_radius = 0.95
			_build_arrow(dir)
		"rain_arrow":
			_velocity = dir * 20.0
			_gravity = 16.0
			_life = 3.0
			_hit_radius = 0.9
			_build_arrow(dir)
		"dagger":
			_velocity = dir * 22.0
			_gravity = 1.4
			_life = 2.2
			_hit_radius = 0.8
			_build_dagger(dir)
		"wave":
			_velocity = dir * 21.0
			_life = 2.4
			_hit_radius = 1.0
			_pierce = maxi(_pierce, 999)
			_build_wave(dir)
		"bolt":
			_velocity = dir * 23.0
			_life = 2.6
			_hit_radius = 0.9
			_build_orb(0.13, 1.0, true)
			_face(dir)
		"fireball":
			_velocity = dir * 16.0
			_life = 3.4
			_hit_radius = 1.05
			_build_orb(0.22, 1.45, true)
			_face(dir)
		"ice_lance":
			_velocity = dir * 22.0
			_life = 3.0
			_hit_radius = 0.95
			_build_ice_lance(dir)
		_:
			_velocity = dir * 9.5
			_life = 4.0
			_hit_radius = 0.8
			_turn_rate = 8.5
			_build_wisp()

func _face(direction: Vector3) -> void:
	if direction.length_squared() > 0.001:
		look_at(global_position + direction.normalized() * 4.0, Vector3.UP)


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

func _build_dagger(direction: Vector3) -> void:
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.045, 0.012, 0.34)
	blade.mesh = blade_mesh
	blade.material_override = _make_emissive(_color, 1.2)
	blade.position = Vector3(0.0, 0.0, -0.12)
	add_child(blade)

	var tip := MeshInstance3D.new()
	var tip_mesh := PrismMesh.new()
	tip_mesh.size = Vector3(0.05, 0.05, 0.10)
	tip.mesh = tip_mesh
	tip.material_override = _make_emissive(_color.lightened(0.25), 1.8)
	tip.rotation.x = -PI * 0.5
	tip.position = Vector3(0.0, 0.0, -0.34)
	add_child(tip)

	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.05, 0.05, 0.10)
	grip.mesh = grip_mesh
	grip.material_override = _make_emissive(Color(0.24, 0.16, 0.12, 1.0), 0.0)
	grip.position = Vector3(0.0, 0.0, 0.08)
	add_child(grip)

	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 0.5
	light.omni_range = 1.5
	light.shadow_enabled = false
	add_child(light)
	_face(direction)

func _build_wave(direction: Vector3) -> void:
	var crescent := MeshInstance3D.new()
	var crescent_mesh := BoxMesh.new()
	crescent_mesh.size = Vector3(1.15, 0.55, 0.09)
	crescent.mesh = crescent_mesh
	crescent.material_override = _make_emissive(_color, 2.4)
	crescent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crescent)

	var core := MeshInstance3D.new()
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.72, 0.24, 0.12)
	core.mesh = core_mesh
	core.material_override = _make_glow(_color.lightened(0.25))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 1.3
	light.omni_range = 2.8
	light.shadow_enabled = false
	add_child(light)
	_face(direction)

func _build_orb(radius: float, energy: float, with_tail: bool) -> void:
	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = radius
	orb_mesh.height = radius * 2.0
	orb_mesh.radial_segments = 10
	orb_mesh.rings = 6
	orb.mesh = orb_mesh
	orb.material_override = _make_emissive(_color, energy * 2.2)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)

	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = radius * 1.8
	halo_mesh.height = radius * 3.6
	halo_mesh.radial_segments = 10
	halo_mesh.rings = 6
	halo.mesh = halo_mesh
	halo.material_override = _make_glow(_color)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

	if with_tail:
		var tail := MeshInstance3D.new()
		var tail_mesh := CylinderMesh.new()
		tail_mesh.top_radius = 0.004
		tail_mesh.bottom_radius = radius * 0.65
		tail_mesh.height = radius * 3.2
		tail_mesh.radial_segments = 6
		tail.mesh = tail_mesh
		tail.material_override = _make_glow(_color)
		tail.rotation.x = -PI * 0.5
		tail.position = Vector3(0.0, 0.0, radius * 1.9)
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tail)

	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 1.2 * energy
	light.omni_range = 2.6 * energy
	light.shadow_enabled = false
	add_child(light)

func _build_ice_lance(direction: Vector3) -> void:
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.06
	shaft_mesh.bottom_radius = 0.015
	shaft_mesh.height = 1.0
	shaft_mesh.radial_segments = 6
	shaft.mesh = shaft_mesh
	shaft.material_override = _make_emissive(_color, 2.0)
	shaft.rotation.x = -PI * 0.5
	shaft.position = Vector3(0.0, 0.0, -0.18)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shaft)

	var halo := MeshInstance3D.new()
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 0.20
	halo_mesh.height = 0.40
	halo_mesh.radial_segments = 8
	halo_mesh.rings = 5
	halo.mesh = halo_mesh
	halo.material_override = _make_glow(_color)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)

	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 1.0
	light.omni_range = 2.2
	light.shadow_enabled = false
	add_child(light)
	_face(direction)

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

	if _kind == "wisp" and _target != null and is_instance_valid(_target):
		var goal := _target.global_position + Vector3(0.0, 0.85, 0.0)
		var desired := (goal - global_position).normalized() * _velocity.length()
		_velocity = _velocity.lerp(desired, clampf(_turn_rate * delta, 0.0, 1.0))

	var falling := _kind == "arrow" or _kind == "rain_arrow" or _kind == "dagger"
	if falling:
		_velocity.y -= _gravity * delta
		look_at(global_position + _velocity.normalized() * 2.0, Vector3.UP)
	elif _kind == "wisp":
		scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08)

	global_position += _velocity * delta

	if falling and global_position.y < 0.12:
		_impact(null)
		return

	for candidate in _damageable_targets():
		if not is_instance_valid(candidate):
			continue
		if not candidate.has_method("take_damage"):
			continue
		if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
			continue
		if _hit_nodes.has(candidate):
			continue
		var center: Vector3 = candidate.global_position + Vector3(0.0, 0.9, 0.0)
		if global_position.distance_to(center) <= _hit_radius:
			if _pierce > 0:
				_register_hit(candidate)
				if _explode_radius > 0.0:
					_detonate(candidate)
				_pierce -= 1
				_spawn_flash()
				continue
			_impact(candidate)
			return

	# A wisp that reaches its target still connects even if the target moved a
	# little at the last moment.
	if _kind == "wisp" and _target != null and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position + Vector3(0.0, 0.85, 0.0)) < 1.0:
			_impact(_target)

func _impact(target: Node) -> void:
	if _impacted:
		return
	_impacted = true
	if target != null and is_instance_valid(target):
		_register_hit(target)
	if _explode_radius > 0.0:
		_detonate(target)
	_spawn_flash()
	queue_free()

func _register_hit(target: Node) -> void:
	if target == null or not is_instance_valid(target) or _hit_nodes.has(target):
		return
	_hit_nodes[target] = true
	if target.has_method("take_damage"):
		target.take_damage(_damage, global_position)
		hit_target.emit(target, _damage)
	if _slow_factor > 0.0 and target.has_method("apply_slow"):
		target.call("apply_slow", _slow_factor, _slow_duration)

## Explosive arrows and fireballs hurt everything near the impact. The direct
## target already took the projectile's own damage, so it is skipped here.
func _detonate(direct: Node) -> void:
	if _exploded:
		return
	_exploded = true
	for candidate in _damageable_targets():
		if candidate == direct or not is_instance_valid(candidate):
			continue
		if not candidate.has_method("take_damage"):
			continue
		if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
			continue
		var center: Vector3 = candidate.global_position + Vector3(0.0, 0.75, 0.0)
		if global_position.distance_to(center) <= _explode_radius + 0.35:
			candidate.take_damage(_explode_damage, global_position)
			hit_target.emit(candidate, _explode_damage)
	_spawn_burst(_explode_radius)


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

func _spawn_burst(radius: float) -> void:
	if radius <= 0.0:
		return
	var parent := get_parent()
	if parent == null:
		return
	var burst := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	mesh.radial_segments = 12
	mesh.rings = 6
	burst.mesh = mesh
	var material := _make_glow(_color)
	burst.material_override = material
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(burst)
	burst.global_position = global_position
	burst.scale = Vector3.ONE * 0.4
	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * (radius * 1.7), 0.26).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.30)
	tween.chain().tween_callback(burst.queue_free)
