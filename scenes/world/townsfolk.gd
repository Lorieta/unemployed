extends StaticBody3D

## A single reusable townsperson. The scene is just a body and a collision
## capsule; the silhouette, palette, hands and role prop are assembled here so
## Elder Rowan, Mira, Bran, Tomas and the ambient villagers can all share one
## script while still reading as individuals.

@export var npc_id := "villager"
@export var display_name := "Townsfolk"
@export var role := "villager"
@export var robe_color := Color(0.28, 0.34, 0.24)
@export var trim_color := Color(0.62, 0.48, 0.24)
@export var skin_color := Color(0.76, 0.58, 0.42)
@export var hair_color := Color(0.2, 0.15, 0.1)
@export var accent_color := Color(0.44, 0.3, 0.16)
@export var hat_style := "hood"
@export var has_beard := false
@export var carries_lantern := false

var _visual: Node3D
var _marker: Label3D
var _name_label: Label3D
var _lantern_light: OmniLight3D
var _time := 0.0
var _marker_state := ""

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("npc")
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_build()
	_build_labels()
	_time = randf() * 4.0

func _build() -> void:
	var skin := _material(skin_color, 0.9)
	var robe := _material(robe_color, 0.95)
	var trim := _material(trim_color, 0.6, 0.35)
	var hair := _material(hair_color, 1.0)
	var accent := _material(accent_color, 0.9)
	var boot := _material(Color(0.16, 0.12, 0.08), 0.95)
	var dark := _material(Color(0.06, 0.045, 0.03), 0.7)
	var glow := _material(Color(1.0, 0.72, 0.34), 0.35, 0.0, 1.8)

	for side in [-1, 1]:
		var leg := _mesh(_visual, "CylinderMesh", Vector3(0.105 * side, 0.36, 0.0), robe, Vector3(0.075, 0.085, 0.7))
		leg.rotation.z = 0.03 * side
		_mesh(_visual, "BoxMesh", Vector3(0.105 * side, 0.06, -0.05), boot, Vector3(0.16, 0.12, 0.28))

	var body := _mesh(_visual, "CylinderMesh", Vector3(0.0, 0.85, 0.0), robe, Vector3(0.2, 0.35, 1.02))
	body.rotation.x = 0.02
	_mesh(_visual, "BoxMesh", Vector3(0.0, 0.76, 0.0), accent, Vector3(0.46, 0.07, 0.3))
	_mesh(_visual, "BoxMesh", Vector3(0.0, 0.76, -0.16), trim, Vector3(0.07, 0.06, 0.025))
	# A front panel of trim makes each tunic read at a glance.
	_mesh(_visual, "BoxMesh", Vector3(0.0, 1.04, -0.185), trim, Vector3(0.055, 0.42, 0.02))

	if role == "smith":
		_mesh(_visual, "BoxMesh", Vector3(0.0, 0.86, -0.18), _material(Color(0.32, 0.2, 0.11), 0.95), Vector3(0.34, 0.62, 0.03))
	elif role == "elder":
		_mesh(_visual, "BoxMesh", Vector3(0.0, 1.02, -0.19), trim, Vector3(0.035, 0.5, 0.02))
		_mesh(_visual, "BoxMesh", Vector3(-0.16, 1.18, -0.18), trim, Vector3(0.03, 0.24, 0.02))
		_mesh(_visual, "BoxMesh", Vector3(0.16, 1.18, -0.18), trim, Vector3(0.03, 0.24, 0.02))
	elif role == "merchant":
		_mesh(_visual, "BoxMesh", Vector3(0.0, 0.72, -0.19), _material(Color(0.7, 0.6, 0.36), 0.95), Vector3(0.4, 0.34, 0.03))

	# Arms, angled so the hands sit naturally at the sides.
	_mesh(_visual, "CylinderMesh", Vector3(-0.3, 1.0, -0.01), robe, Vector3(0.065, 0.08, 0.52)).rotation.z = 0.26
	_mesh(_visual, "CylinderMesh", Vector3(0.3, 1.0, -0.01), robe, Vector3(0.065, 0.08, 0.52)).rotation.z = -0.26
	_mesh(_visual, "SphereMesh", Vector3(-0.37, 0.76, -0.03), skin, Vector3(0.07, 0.07, 0.07))
	_mesh(_visual, "SphereMesh", Vector3(0.37, 0.76, -0.03), skin, Vector3(0.07, 0.07, 0.07))

	_mesh(_visual, "CylinderMesh", Vector3(0.0, 1.42, 0.0), skin, Vector3(0.075, 0.09, 0.18))
	_mesh(_visual, "SphereMesh", Vector3(0.0, 1.57, 0.0), skin, Vector3(0.17, 0.17, 0.16))
	_mesh(_visual, "BoxMesh", Vector3(0.0, 1.54, -0.17), skin, Vector3(0.05, 0.06, 0.06))
	# Eyes are simple dark slits, but they make the face.
	_mesh(_visual, "BoxMesh", Vector3(-0.06, 1.6, -0.15), dark, Vector3(0.025, 0.025, 0.015))
	_mesh(_visual, "BoxMesh", Vector3(0.06, 1.6, -0.15), dark, Vector3(0.025, 0.025, 0.015))
	if has_beard:
		_mesh(_visual, "CylinderMesh", Vector3(0.0, 1.44, -0.1), hair, Vector3(0.11, 0.035, 0.28))
		_mesh(_visual, "BoxMesh", Vector3(0.0, 1.5, -0.17), _material(Color(0.8, 0.76, 0.68), 1.0), Vector3(0.14, 0.06, 0.04))

	match hat_style:
		"hood":
			_mesh(_visual, "SphereMesh", Vector3(0.0, 1.62, 0.03), robe, Vector3(0.2, 0.16, 0.2))
			_mesh(_visual, "CylinderMesh", Vector3(0.0, 1.35, 0.14), robe, Vector3(0.23, 0.19, 0.36))
		"kerchief":
			_mesh(_visual, "SphereMesh", Vector3(0.0, 1.68, 0.02), accent, Vector3(0.18, 0.1, 0.18))
			_mesh(_visual, "BoxMesh", Vector3(0.0, 1.52, 0.17), accent, Vector3(0.2, 0.18, 0.04))
		"cap":
			_mesh(_visual, "CylinderMesh", Vector3(0.0, 1.7, 0.02), accent, Vector3(0.18, 0.19, 0.12))
			_mesh(_visual, "BoxMesh", Vector3(0.0, 1.66, -0.16), accent, Vector3(0.26, 0.03, 0.16))
		"bald":
			_mesh(_visual, "SphereMesh", Vector3(0.0, 1.68, 0.05), skin, Vector3(0.1, 0.06, 0.12))
		_:
			_mesh(_visual, "SphereMesh", Vector3(0.0, 1.64, 0.01), hair, Vector3(0.18, 0.12, 0.18))

	# Hair at the sides under the hat.
	_mesh(_visual, "SphereMesh", Vector3(-0.13, 1.52, 0.05), hair, Vector3(0.06, 0.1, 0.08))
	_mesh(_visual, "SphereMesh", Vector3(0.13, 1.52, 0.05), hair, Vector3(0.06, 0.1, 0.08))

	_build_role_prop(glow)

	if carries_lantern:
		var lantern := Node3D.new()
		lantern.position = Vector3(0.42, 0.86, -0.06)
		_visual.add_child(lantern)
		_mesh(lantern, "BoxMesh", Vector3(0.0, -0.1, 0.0), trim, Vector3(0.13, 0.16, 0.13))
		var bulb := _mesh(lantern, "SphereMesh", Vector3(0.0, -0.1, 0.0), glow, Vector3(0.06, 0.06, 0.06))
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lantern_light = OmniLight3D.new()
		_lantern_light.light_color = Color(1.0, 0.72, 0.36)
		_lantern_light.light_energy = 0.8
		_lantern_light.omni_range = 4.0
		_lantern_light.position = Vector3(0.0, -0.1, 0.0)
		lantern.add_child(_lantern_light)

func _build_role_prop(glow: StandardMaterial3D) -> void:
	match role:
		"elder":
			# A tall walking staff, crystal-topped.
			var staff := _mesh(_visual, "CylinderMesh", Vector3(0.46, 1.02, -0.04), _material(Color(0.3, 0.2, 0.1), 0.9), Vector3(0.024, 0.032, 1.9))
			staff.rotation.z = -0.06
			var crystal := _mesh(_visual, "SphereMesh", Vector3(0.5, 2.02, -0.06), glow, Vector3(0.08, 0.1, 0.08))
			crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"smith":
			# Hammer resting across the shoulder.
			var shaft := _mesh(_visual, "CylinderMesh", Vector3(0.36, 1.16, 0.04), _material(Color(0.32, 0.21, 0.11), 0.9), Vector3(0.028, 0.028, 0.86))
			shaft.rotation.z = -0.7
			var head := _mesh(_visual, "BoxMesh", Vector3(0.12, 1.48, 0.04), _material(Color(0.3, 0.3, 0.32), 0.45, 0.7), Vector3(0.3, 0.14, 0.16))
			head.rotation.z = -0.7
		"merchant":
			# A shallow basket of wares balanced on the hip.
			var basket := _mesh(_visual, "CylinderMesh", Vector3(-0.36, 0.82, -0.04), _material(Color(0.55, 0.4, 0.2), 0.95), Vector3(0.18, 0.14, 0.2))
			basket.rotation.z = 0.1
			for i in 3:
				var apple := _mesh(_visual, "SphereMesh", Vector3(-0.42 + 0.05 * float(i), 0.94, -0.08 + 0.04 * float(i % 2)), _material(Color(0.62, 0.2, 0.12), 0.8), Vector3(0.045, 0.045, 0.045))
				apple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"hunter":
			# Long spear planted beside the gate.
			var spear := _mesh(_visual, "CylinderMesh", Vector3(-0.5, 1.02, -0.04), _material(Color(0.34, 0.24, 0.13), 0.9), Vector3(0.022, 0.028, 2.1))
			spear.rotation.z = 0.05
			var tip := _mesh(_visual, "PrismMesh", Vector3(-0.45, 2.12, -0.04), _material(Color(0.72, 0.74, 0.78), 0.35, 0.8), Vector3(0.06, 0.18, 0.06))
			tip.rotation.z = -0.05
		"villager":
			# A woven basket or bundle of herbs.
			_mesh(_visual, "CylinderMesh", Vector3(0.38, 0.82, -0.06), _material(Color(0.56, 0.42, 0.22), 0.95), Vector3(0.16, 0.13, 0.22))
			for i in 3:
				_mesh(_visual, "CylinderMesh", Vector3(0.3 + 0.08 * float(i), 0.95, -0.08), _material(Color(0.3, 0.46, 0.22), 0.9), Vector3(0.02, 0.015, 0.3)).rotation.z = -0.3 + 0.2 * float(i)
		_:
			_mesh(_visual, "CylinderMesh", Vector3(0.44, 1.0, -0.05), _material(Color(0.32, 0.21, 0.11), 0.9), Vector3(0.02, 0.026, 1.7))

func _build_labels() -> void:
	_name_label = Label3D.new()
	_name_label.text = display_name.to_upper()
	_name_label.font_size = 40
	_name_label.pixel_size = 0.003
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.outline_size = 14
	_name_label.outline_modulate = Color(0.05, 0.035, 0.02, 1.0)
	_name_label.modulate = Color(0.92, 0.86, 0.7, 1.0)
	_name_label.position = Vector3(0.0, 2.02, 0.0)
	add_child(_name_label)

	_marker = Label3D.new()
	_marker.font_size = 96
	_marker.pixel_size = 0.0038
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.outline_size = 26
	_marker.outline_modulate = Color(0.06, 0.04, 0.02, 1.0)
	_marker.modulate = Color(1.0, 0.86, 0.42, 1.0)
	_marker.position = Vector3(0.0, 2.42, 0.0)
	_marker.visible = false
	add_child(_marker)

func _process(delta: float) -> void:
	_time += delta
	if _visual != null:
		_visual.position.y = sin(_time * 1.2) * 0.012
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var distance := global_position.distance_to(player.global_position)
		if _name_label != null:
			_name_label.visible = distance < 10.0
		if distance < 7.0 and _visual != null:
			var wanted := player.global_position - global_position
			var yaw := atan2(-wanted.x, -wanted.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, 1.0 - exp(-2.4 * delta))
	if _marker != null and _marker.visible:
		_marker.position.y = 2.42 + sin(_time * 3.0) * 0.06
	if _lantern_light != null:
		_lantern_light.light_energy = 0.8 + sin(_time * 9.0) * 0.09 + sin(_time * 14.0 + 1.2) * 0.04

func get_interaction_prompt() -> String:
	return "[ E ]     Speak with %s" % display_name

func can_interact() -> bool:
	return true

func interact(_player: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_npc_dialogue"):
		hud.call("show_npc_dialogue", npc_id)

func set_quest_marker(marker: String) -> void:
	_marker_state = marker
	if _marker == null:
		return
	_marker.visible = not marker.is_empty()
	_marker.text = marker
	match marker:
		"!":
			_marker.modulate = Color(1.0, 0.86, 0.42, 1.0)
		"?":
			_marker.modulate = Color(0.7, 0.86, 0.62, 1.0)
		"$":
			_marker.modulate = Color(0.96, 0.78, 0.36, 1.0)
		_:
			_marker.modulate = Color(0.92, 0.86, 0.7, 1.0)

func get_quest_marker() -> String:
	return _marker_state

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

func _mesh(parent: Node3D, mesh_type: String, position: Vector3, material: StandardMaterial3D, size: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	match mesh_type:
		"CylinderMesh":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x
			cylinder.bottom_radius = size.y
			cylinder.height = size.z
			cylinder.radial_segments = 9
			cylinder.rings = 2
			mesh = cylinder
		"BoxMesh":
			var box := BoxMesh.new()
			box.size = size
			mesh = box
		"PrismMesh":
			var prism := PrismMesh.new()
			prism.size = size
			mesh = prism
		_:
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.y * 2.0
			sphere.radial_segments = 10
			sphere.rings = 6
			mesh = sphere
	mesh.material = material
	node.mesh = mesh
	node.position = position
	parent.add_child(node)
	return node
