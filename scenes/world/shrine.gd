extends StaticBody3D

## The wayshrine at the heart of the Thorned Field. It is dark and quiet until
## the story sends the hero to wake it; lighting it drives the briars back and
## stirs the Briar Warden. The HUD owns the quest state, so the shrine simply
## reports the interaction and plays the lighting.

@export var shrine_name := "Wayshrine of the Reach"

var lit := false
var _time := 0.0
var _glow_material: StandardMaterial3D
var _crystal: MeshInstance3D
var _light: OmniLight3D
var _rune_ring: MeshInstance3D
var _motes: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("shrine")
	_build()

func _build() -> void:
	var stone := _material(Color(0.3, 0.32, 0.29), 0.98)
	var stone_dark := _material(Color(0.19, 0.21, 0.19), 1.0)
	var moss := _material(Color(0.24, 0.36, 0.2), 0.98)
	var iron := _material(Color(0.2, 0.19, 0.17), 0.6, 0.55)
	_glow_material = _material(Color(0.46, 0.85, 0.58), 0.3, 0.0, 1.4)
	_glow_material.emission_enabled = false

	# A stepped plinth, ringed with old runes.
	_mesh("cylinder", Vector3(0.0, 0.14, 0.0), Vector3(2.2, 2.6, 0.28), stone)
	_mesh("cylinder", Vector3(0.0, 0.34, 0.0), Vector3(1.6, 2.0, 0.34), stone_dark)
	_rune_ring = _mesh("cylinder", Vector3(0.0, 0.52, 0.0), Vector3(1.45, 1.5, 0.06), moss)
	_rune_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Four leaning standing stones around a central pillar.
	for i in 4:
		var angle := float(i) * TAU / 4.0 + 0.4
		var offset := Vector3(cos(angle) * 1.25, 0.0, sin(angle) * 1.25)
		var stone_node := _mesh("prism", offset + Vector3(0.0, 1.15, 0.0), Vector3(0.42, 1.5, 0.34), stone)
		stone_node.rotation.y = -angle
		stone_node.rotation.z = cos(angle) * 0.1
		stone_node.rotation.x = sin(angle) * 0.1
		_mesh("sphere", offset + Vector3(0.0, 1.95, 0.0), Vector3(0.12, 0.12, 0.12), moss)

	_mesh("cylinder", Vector3(0.0, 1.12, 0.0), Vector3(0.44, 0.62, 1.3), stone_dark)
	_mesh("cylinder", Vector3(0.0, 1.82, 0.0), Vector3(0.72, 0.4, 0.26), iron)
	# An iron basket cradling the shrine's heart.
	for i in 6:
		var angle := float(i) * TAU / 6.0
		var prong := _mesh("box", Vector3(cos(angle) * 0.52, 2.06, sin(angle) * 0.52), Vector3(0.06, 0.7, 0.06), iron)
		prong.rotation.z = -cos(angle) * 0.22
		prong.rotation.x = sin(angle) * 0.22
	_crystal = _mesh("sphere", Vector3(0.0, 2.26, 0.0), Vector3(0.26, 0.42, 0.26), _glow_material)
	_crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	for i in 3:
		var angle := float(i) * TAU / 3.0
		var mote := _mesh("sphere", Vector3(cos(angle) * 0.7, 2.0 + 0.16 * float(i), sin(angle) * 0.7), Vector3(0.045, 0.045, 0.045), _glow_material)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_motes.append(mote)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.95, 0.66)
	_light.light_energy = 0.0
	_light.omni_range = 9.0
	_light.position = Vector3(0.0, 2.3, 0.0)
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta
	if _crystal != null:
		_crystal.rotation.y += delta * (0.7 if lit else 0.15)
		_crystal.position.y = 2.26 + sin(_time * (2.2 if lit else 0.9)) * (0.05 if lit else 0.015)
	for i in _motes.size():
		var mote := _motes[i]
		var angle := _time * (0.8 if lit else 0.2) + float(i) * TAU / 3.0
		var radius := 0.7 + 0.1 * float(i)
		mote.position = Vector3(cos(angle) * radius, 2.0 + 0.18 * float(i) + sin(_time * 1.4 + float(i)) * 0.09, sin(angle) * radius)
	if _light != null:
		if lit:
			_light.light_energy = 2.1 + sin(_time * 4.1) * 0.18 + sin(_time * 9.3) * 0.07
		else:
			_light.light_energy = 0.18 + sin(_time * 1.3) * 0.05
	if _rune_ring != null:
		_rune_ring.rotation.y = _time * (0.35 if lit else 0.05)

func get_interaction_prompt() -> String:
	if lit:
		return "[ E ]     Touch the wayshrine"
	return "[ E ]     Light the wayshrine"

func can_interact() -> bool:
	return true

func interact(_player: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("on_shrine_interact"):
		hud.call("on_shrine_interact", self)

func light_up() -> void:
	if lit:
		return
	lit = true
	_glow_material.emission_enabled = true
	_glow_material.emission = Color(0.5, 1.0, 0.66)
	_glow_material.emission_energy_multiplier = 2.4
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_light, "light_energy", 2.2, 1.2)
	tween.tween_property(_light, "omni_range", 14.0, 1.2)
	_spawn_pulse()

func is_lit() -> bool:
	return lit

func _spawn_pulse() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in 14:
		var mote := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.12
		mesh.radial_segments = 5
		mesh.rings = 3
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.58, 1.0, 0.7)
		material.emission_enabled = true
		material.emission = Color(0.55, 1.0, 0.7)
		material.emission_energy_multiplier = 2.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = material
		mote.mesh = mesh
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mote)
		mote.global_position = global_position + Vector3(0.0, 2.3, 0.0)
		var angle := randf() * TAU
		var reach := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(2.0, 5.0)
		var tween := mote.create_tween()
		tween.set_parallel(true)
		tween.tween_property(mote, "global_position", mote.global_position + reach + Vector3(0.0, randf_range(1.5, 3.5), 0.0), 1.2)
		tween.tween_property(material, "albedo_color:a", 0.0, 1.2)
		tween.chain().tween_callback(mote.queue_free)

func _material(color: Color, roughness: float, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _mesh(shape: String, position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	match shape:
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x
			cylinder.bottom_radius = size.y
			cylinder.height = size.z
			cylinder.radial_segments = 9
			mesh = cylinder
		"prism":
			var prism := PrismMesh.new()
			prism.size = size
			mesh = prism
		"box":
			var box := BoxMesh.new()
			box.size = size
			mesh = box
		_:
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.y * 2.0
			sphere.radial_segments = 12
			sphere.rings = 6
			mesh = sphere
	mesh.material = material
	node.mesh = mesh
	node.position = position
	add_child(node)
	return node
