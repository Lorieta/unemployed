extends StaticBody3D

## The sunken stone ring beside the wayshrine that leads down into the
## Under-Reach. It stays inert until the wayshrine is lit, then offers the hero
## a way down into the dungeon running embedded under the Reach. The actual
## building is delegated to the dungeon manager node found in the
## "dungeon_manager" group; this node only sells the entry.

@export var entrance_name := "the Under-Reach"

var _lit_fx := false
var _glow_materials: Array[StandardMaterial3D] = []
var _flames: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _time := 0.0
var _check_timer := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("dungeon_entrance")
	_build()

func can_interact() -> bool:
	var manager := _find_manager()
	if manager == null or bool(manager.call("is_inside_dungeon")):
		return false
	return _shrine_lit()

func get_interaction_prompt() -> String:
	return "[ E ]     Descend into %s" % entrance_name

func interact(_player: Node) -> void:
	var manager := _find_manager()
	if manager == null or bool(manager.call("is_inside_dungeon")):
		return
	manager.call("enter_dungeon")

func _process(delta: float) -> void:
	_time += delta
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.5
		_ignite(_shrine_lit())
	for i in _flames.size():
		_flames[i].scale = Vector3(0.9, 1.15 + sin(_time * 5.0 + float(i) * 1.9) * 0.18, 0.9)
	if _lit_fx and not _lights.is_empty():
		_lights[0].light_energy = 1.6 + sin(_time * 3.1) * 0.25

func _build() -> void:
	var stone := _material(Color(0.24, 0.23, 0.21), 0.95)
	var stone_dark := _material(Color(0.16, 0.156, 0.145), 1.0)
	var gold := _material(Color(0.72, 0.56, 0.26), 0.35, 0.8)

	_mesh("cylinder", Vector3(0.0, 0.02, 0.0), Vector3(4.6, 5.4, 0.12), stone_dark)
	_mesh("cylinder", Vector3(0.0, 0.06, 0.0), Vector3(3.0, 3.2, 0.14), stone)
	_mesh("cylinder", Vector3(0.0, 0.1, 0.0), Vector3(2.2, 2.4, 0.15), gold)

	for i in 10:
		var angle := float(i) * TAU / 10.0
		var offset := Vector3(cos(angle) * 2.55, 0.0, sin(angle) * 2.55)
		var stone_node := _mesh("prism", offset + Vector3(0.0, 0.62, 0.0), Vector3(0.5, 1.3, 0.34), stone)
		stone_node.rotation.y = -angle
		stone_node.rotation.z = cos(angle) * 0.09
		stone_node.rotation.x = sin(angle) * 0.09

	# Sunken steps at the ring's heart, reading as a stair into the dark.
	for i in 4:
		var sink := 0.11 - float(i) * 0.1
		_mesh("cylinder", Vector3(0.0, sink, 0.0), Vector3(2.0 - float(i) * 0.42, 2.2 - float(i) * 0.42, 0.14), stone_dark)

	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var offset := Vector3(side * 1.9, 0.0, 1.35)
		var pedestal := _mesh("cylinder", offset + Vector3(0.0, 0.45, 0.0), Vector3(0.18, 0.26, 0.9), _material(Color(0.2, 0.19, 0.17), 0.6, 0.6))
		pedestal.rotation.z = 0.0
		var flame := _mesh("sphere", offset + Vector3(0.0, 1.05, 0.0), Vector3(0.14, 0.14, 0.14), _material(Color(1.0, 0.72, 0.3), 0.3, 0.0, 1.8))
		_flames.append(flame)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.5)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.position = Vector3(0.0, 1.7, 0.0)
	add_child(light)
	_lights.append(light)

func _ignite(on: bool) -> void:
	if on == _lit_fx:
		return
	_lit_fx = on
	for material in _glow_materials:
		material.emission_energy_multiplier = 2.2 if on else 1.8
	for light in _lights:
		var tween := create_tween()
		tween.tween_property(light, "light_energy", 1.6 if on else 0.0, 1.0)

func _shrine_lit() -> bool:
	var shrine := get_tree().get_first_node_in_group("shrine")
	if shrine == null or not shrine.has_method("is_lit"):
		return false
	return bool(shrine.call("is_lit"))

func _find_manager() -> Node:
	var candidates := get_tree().get_nodes_in_group("dungeon_manager")
	for candidate in candidates:
		if candidate.has_method("enter_dungeon"):
			return candidate
	return null

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
		_glow_materials.append(material)
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
