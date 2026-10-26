extends Node3D

## Dresses the chibi rig in one of five weapon outfits at runtime.
##
## The rig in `tiny_human.tscn` deliberately keeps its animation pivots simple.
## This script decorates those pivots with layered cloth, leather, steel, fur and
## hair, but groups every garment by weapon so switching from the longsword to
## the bow, staff, dagger or fox relic changes the whole silhouette. Shared
## pieces (face, cape, base body) are recoloured from a per-weapon palette, and
## the kitsune gets a live, swaying tail. None of the walk / run / attack pivots
## are touched: every decoration hangs off a node that already animates.

const WEAPON_ORDER := ["sword", "bow", "staff", "dagger", "kitsune"]

## Per-outfit colours for the shared body, cape and cloth pieces.
const PALETTES := {
	"sword": {
		"tunic": Color(0.12, 0.21, 0.42, 1.0),
		"tunic_light": Color(0.19, 0.31, 0.56, 1.0),
		"tunic_dark": Color(0.064, 0.115, 0.26, 1.0),
		"cape": Color(0.46, 0.09, 0.09, 1.0),
		"cape_dark": Color(0.27, 0.05, 0.05, 1.0),
		"pants": Color(0.20, 0.19, 0.17, 1.0),
		"leather": Color(0.33, 0.20, 0.10, 1.0),
		"leather_dark": Color(0.17, 0.10, 0.052, 1.0),
		"boot": Color(0.16, 0.11, 0.07, 1.0),
		"steel": Color(0.66, 0.69, 0.74, 1.0),
		"brass": Color(0.87, 0.68, 0.28, 1.0),
		"hair": Color(0.30, 0.155, 0.065, 1.0),
		"hair_light": Color(0.43, 0.245, 0.10, 1.0),
		"cream": Color(0.92, 0.88, 0.78, 1.0),
		"accent": Color(0.92, 0.74, 0.32, 1.0),
		"cloth": Color(0.17, 0.29, 0.50, 1.0),
		"fur": Color(0.86, 0.84, 0.79, 1.0),
	},
	"bow": {
		"tunic": Color(0.17, 0.28, 0.16, 1.0),
		"tunic_light": Color(0.26, 0.38, 0.22, 1.0),
		"tunic_dark": Color(0.086, 0.16, 0.086, 1.0),
		"cape": Color(0.30, 0.34, 0.17, 1.0),
		"cape_dark": Color(0.16, 0.20, 0.09, 1.0),
		"pants": Color(0.24, 0.21, 0.16, 1.0),
		"leather": Color(0.40, 0.26, 0.13, 1.0),
		"leather_dark": Color(0.21, 0.13, 0.07, 1.0),
		"boot": Color(0.20, 0.14, 0.08, 1.0),
		"steel": Color(0.55, 0.56, 0.52, 1.0),
		"brass": Color(0.72, 0.55, 0.24, 1.0),
		"hair": Color(0.38, 0.22, 0.09, 1.0),
		"hair_light": Color(0.52, 0.32, 0.13, 1.0),
		"cream": Color(0.87, 0.83, 0.69, 1.0),
		"accent": Color(0.66, 0.79, 0.43, 1.0),
		"cloth": Color(0.28, 0.36, 0.20, 1.0),
		"fur": Color(0.56, 0.43, 0.27, 1.0),
	},
	"staff": {
		"tunic": Color(0.11, 0.14, 0.36, 1.0),
		"tunic_light": Color(0.19, 0.24, 0.55, 1.0),
		"tunic_dark": Color(0.052, 0.07, 0.20, 1.0),
		"cape": Color(0.16, 0.18, 0.48, 1.0),
		"cape_dark": Color(0.08, 0.09, 0.28, 1.0),
		"pants": Color(0.12, 0.12, 0.22, 1.0),
		"leather": Color(0.26, 0.21, 0.34, 1.0),
		"leather_dark": Color(0.13, 0.10, 0.19, 1.0),
		"boot": Color(0.12, 0.10, 0.18, 1.0),
		"steel": Color(0.66, 0.68, 0.78, 1.0),
		"brass": Color(0.86, 0.70, 0.34, 1.0),
		"hair": Color(0.70, 0.71, 0.76, 1.0),
		"hair_light": Color(0.86, 0.87, 0.92, 1.0),
		"cream": Color(0.90, 0.90, 0.84, 1.0),
		"accent": Color(0.64, 0.86, 0.98, 1.0),
		"cloth": Color(0.20, 0.24, 0.56, 1.0),
		"fur": Color(0.85, 0.85, 0.90, 1.0),
	},
	"dagger": {
		"tunic": Color(0.16, 0.15, 0.17, 1.0),
		"tunic_light": Color(0.24, 0.23, 0.26, 1.0),
		"tunic_dark": Color(0.08, 0.075, 0.09, 1.0),
		"cape": Color(0.25, 0.11, 0.17, 1.0),
		"cape_dark": Color(0.13, 0.05, 0.09, 1.0),
		"pants": Color(0.13, 0.12, 0.14, 1.0),
		"leather": Color(0.28, 0.19, 0.14, 1.0),
		"leather_dark": Color(0.14, 0.09, 0.07, 1.0),
		"boot": Color(0.11, 0.09, 0.08, 1.0),
		"steel": Color(0.58, 0.60, 0.66, 1.0),
		"brass": Color(0.62, 0.50, 0.26, 1.0),
		"hair": Color(0.14, 0.10, 0.08, 1.0),
		"hair_light": Color(0.24, 0.17, 0.12, 1.0),
		"cream": Color(0.80, 0.77, 0.70, 1.0),
		"accent": Color(0.75, 0.30, 0.34, 1.0),
		"cloth": Color(0.20, 0.11, 0.16, 1.0),
		"fur": Color(0.35, 0.30, 0.28, 1.0),
	},
	"kitsune": {
		"tunic": Color(0.90, 0.86, 0.78, 1.0),
		"tunic_light": Color(0.97, 0.94, 0.88, 1.0),
		"tunic_dark": Color(0.78, 0.70, 0.58, 1.0),
		"cape": Color(0.72, 0.20, 0.14, 1.0),
		"cape_dark": Color(0.45, 0.10, 0.08, 1.0),
		"pants": Color(0.85, 0.80, 0.70, 1.0),
		"leather": Color(0.45, 0.18, 0.12, 1.0),
		"leather_dark": Color(0.26, 0.10, 0.07, 1.0),
		"boot": Color(0.30, 0.14, 0.10, 1.0),
		"steel": Color(0.85, 0.83, 0.72, 1.0),
		"brass": Color(0.95, 0.76, 0.35, 1.0),
		"hair": Color(0.46, 0.24, 0.10, 1.0),
		"hair_light": Color(0.62, 0.36, 0.15, 1.0),
		"cream": Color(0.96, 0.93, 0.86, 1.0),
		"accent": Color(0.96, 0.72, 0.34, 1.0),
		"cloth": Color(0.90, 0.86, 0.78, 1.0),
		"fur": Color(0.94, 0.90, 0.82, 1.0),
	},
}

const CAPE_SCALES := {
	"sword": Vector3(1.0, 1.0, 1.0),
	"bow": Vector3(0.94, 0.92, 1.0),
	"staff": Vector3(1.14, 1.22, 1.0),
	"dagger": Vector3(0.90, 0.84, 1.0),
	"kitsune": Vector3(1.06, 1.12, 1.0),
}

var _mats := {}
var _mat := {}
var _groups := {}

var _body: Node3D
var _upper: Node3D
var _head: Node3D
var _left_shoulder: Node3D
var _right_shoulder: Node3D
var _left_elbow: Node3D
var _right_elbow: Node3D
var _left_knee: Node3D
var _right_knee: Node3D
var _left_foot: Node3D
var _right_foot: Node3D

var _cape_root: Node3D
var _cape_nodes: Array = []
var _hair_main: Array[MeshInstance3D] = []
var _hair_light: Array[MeshInstance3D] = []

var _tail_root: Node3D
var _tail_segments: Array[Node3D] = []
var _tail_time := 0.0

var _current_outfit := ""

func _ready() -> void:
	_build_materials()
	_body = get_parent().get_node_or_null("Visual/Body") as Node3D
	if _body == null:
		return
	_upper = _body.get_node_or_null("UpperBody") as Node3D
	if _upper == null:
		return
	_head = _upper.get_node_or_null("HeadPivot") as Node3D
	_left_shoulder = _upper.get_node_or_null("LeftShoulder") as Node3D
	_right_shoulder = _upper.get_node_or_null("RightShoulder") as Node3D
	_left_elbow = _upper.get_node_or_null("LeftShoulder/Elbow") as Node3D
	_right_elbow = _upper.get_node_or_null("RightShoulder/Elbow") as Node3D
	_left_knee = _body.get_node_or_null("LeftHip/Knee") as Node3D
	_right_knee = _body.get_node_or_null("RightHip/Knee") as Node3D
	_left_foot = _body.get_node_or_null("LeftHip/Knee/Foot") as Node3D
	_right_foot = _body.get_node_or_null("RightHip/Knee/Foot") as Node3D

	_mat = _mats["sword"]
	_build_common_head()
	_build_cape()
	for weapon_id in WEAPON_ORDER:
		_mat = _mats[weapon_id]
		_build_outfit(weapon_id)
	_mat = _mats["kitsune"]
	_build_tail()

	var parent := get_parent()
	var equipped := str(parent.get("equipped_weapon")) if parent != null else "sword"
	_apply_outfit(equipped)
	if parent != null and parent.has_signal("weapon_changed"):
		parent.weapon_changed.connect(_on_weapon_changed)

func _on_weapon_changed(weapon_id: String) -> void:
	_apply_outfit(weapon_id)

func _build_materials() -> void:
	for weapon_id in WEAPON_ORDER:
		var palette: Dictionary = PALETTES[weapon_id]
		var mats := {}
		mats["skin"] = _material(Color(0.93, 0.71, 0.56), 0.78)
		mats["eye_white"] = _material(Color(0.98, 0.96, 0.90), 0.42)
		mats["iris"] = _material(Color(0.17, 0.52, 0.40), 0.26, 0.0, Color(0.06, 0.32, 0.20), 0.25)
		mats["pupil"] = _material(Color(0.035, 0.03, 0.026), 0.5)
		mats["mouth"] = _material(Color(0.52, 0.20, 0.18), 0.7)
		for key in [
			"tunic", "tunic_light", "tunic_dark", "cape", "cape_dark", "pants",
			"leather", "leather_dark", "boot", "steel", "brass", "hair",
			"hair_light", "cream", "accent", "cloth", "fur",
		]:
			var color: Color = palette[key]
			var roughness := 0.9
			var metallic := 0.0
			if key == "steel":
				roughness = 0.32
				metallic = 0.82
			elif key == "brass" or key == "accent":
				roughness = 0.36
				metallic = 0.82
			elif key == "fur":
				roughness = 1.0
			mats[key] = _material(color, roughness, metallic)
		_mats[weapon_id] = mats
	_mat = _mats["sword"]

func _material(color: Color, roughness := 0.9, metallic := 0.0, emission := Color(0, 0, 0, 0), energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission.a > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	return material

func _paint(parent: Node3D, path: String, material: StandardMaterial3D, visible := true) -> MeshInstance3D:
	var node := parent.get_node_or_null(path) as MeshInstance3D
	if node != null:
		node.material_override = material
		node.visible = visible
	return node

func _box(parent: Node3D, size: Vector3, position: Vector3, material: StandardMaterial3D, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation = rotation
	parent.add_child(node)
	return node

func _sphere(parent: Node3D, radius: float, position: Vector3, material: StandardMaterial3D, scale := Vector3.ONE, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.scale = scale
	node.rotation = rotation
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, radius: float, height: float, position: Vector3, material: StandardMaterial3D, rotation := Vector3.ZERO, top_radius := -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation = rotation
	parent.add_child(node)
	return node

func _capsule(parent: Node3D, radius: float, height: float, position: Vector3, material: StandardMaterial3D, rotation := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 4
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation = rotation
	parent.add_child(node)
	return node

## One visibility group per outfit per animated pivot.
func _group(parent: Node3D, weapon_id: String) -> Node3D:
	var node := Node3D.new()
	node.name = "Outfit_%s" % weapon_id
	node.visible = false
	parent.add_child(node)
	if not _groups.has(weapon_id):
		_groups[weapon_id] = []
	_groups[weapon_id].append(node)
	return node

func _hair_box(size: Vector3, position: Vector3, rotation := Vector3.ZERO, light := false) -> MeshInstance3D:
	var node := _box(_head, size, position, _mat["hair_light"] if light else _mat["hair"], rotation)
	if light:
		_hair_light.append(node)
	else:
		_hair_main.append(node)
	return node

func _hair_sphere(radius: float, position: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var node := _sphere(_head, radius, position, _mat["hair"], scale)
	_hair_main.append(node)
	return node

func _cape_part(parent: Node3D, size: Vector3, position: Vector3, key: String, rotation := Vector3.ZERO) -> MeshInstance3D:
	var node := _box(parent, size, position, _mat[key], rotation)
	_cape_nodes.append({"node": node, "key": key})
	return node

func _cape_sphere(parent: Node3D, radius: float, position: Vector3, scale: Vector3, key: String) -> MeshInstance3D:
	var node := _sphere(parent, radius, position, _mat[key], scale)
	_cape_nodes.append({"node": node, "key": key})
	return node

func _apply_outfit(weapon_id: String) -> void:
	if not _mats.has(weapon_id):
		weapon_id = "sword"
	_current_outfit = weapon_id
	_mat = _mats[weapon_id]
	for id in _groups:
		var shown: bool = str(id) == weapon_id
		for node in _groups[id]:
			(node as Node3D).visible = shown
	_recolour_base(weapon_id)
	_recolour_cape()
	if _cape_root != null:
		_cape_root.scale = CAPE_SCALES.get(weapon_id, Vector3.ONE)
	if _tail_root != null:
		_tail_root.visible = weapon_id == "kitsune"

func _recolour_base(weapon_id: String) -> void:
	var mats: Dictionary = _mats[weapon_id]
	_paint(_upper, "Torso", mats["tunic"])
	_paint(_body, "Pelvis", mats["pants"])
	_paint(_body, "Belt", mats["leather"])
	_paint(_body, "Buckle", mats["brass"])
	_paint(_body, "Satchel", mats["leather"])
	_paint(_body, "SatchelFlap", mats["leather_dark"])
	_paint(_body, "LeftHip/UpperLeg", mats["pants"])
	_paint(_body, "LeftHip/Knee/LowerLeg", mats["pants"])
	_paint(_body, "RightHip/UpperLeg", mats["pants"])
	_paint(_body, "RightHip/Knee/LowerLeg", mats["pants"])
	_paint(_body, "LeftHip/Knee/Foot/FootMesh", mats["boot"])
	_paint(_body, "RightHip/Knee/Foot/FootMesh", mats["boot"])
	if _head != null:
		_paint(_head, "Head", mats["skin"])
		_paint(_head, "Nose", mats["skin"])
		_paint(_head, "Hair", mats["hair"])
		# The block eyes in the rig are replaced by the expressive eyes above.
		_paint(_head, "EyeLeft", mats["pupil"], false)
		_paint(_head, "EyeRight", mats["pupil"], false)
	for side in ["Left", "Right"]:
		_paint(_upper, "%sShoulder/ShoulderJoint" % side, mats["skin"])
		_paint(_upper, "%sShoulder/UpperArm" % side, mats["skin"])
		_paint(_upper, "%sShoulder/Elbow/LowerArm" % side, mats["skin"])
		_paint(_upper, "%sShoulder/Elbow/Hand" % side, mats["skin"])
	for node in _hair_main:
		node.material_override = mats["hair"]
	for node in _hair_light:
		node.material_override = mats["hair_light"]

func _recolour_cape() -> void:
	for part in _cape_nodes:
		var node := part["node"] as MeshInstance3D
		var key := str(part["key"])
		if _mat.has(key):
			node.material_override = _mat[key]

# ---------------------------------------------------------------------------
# Shared face and hair
# ---------------------------------------------------------------------------

func _build_common_head() -> void:
	if _head == null:
		return
	_sphere(_head, 0.058, Vector3(-0.188, 0.150, 0.010), _mat["skin"], Vector3(0.52, 1.0, 0.78), Vector3(0.0, 0.0, 0.18))
	_sphere(_head, 0.058, Vector3(0.188, 0.150, 0.010), _mat["skin"], Vector3(0.52, 1.0, 0.78), Vector3(0.0, 0.0, -0.18))

	for side in [-1.0, 1.0]:
		var x: float = 0.073 * side
		_sphere(_head, 0.048, Vector3(x, 0.178, -0.177), _mat["eye_white"], Vector3(1.0, 1.18, 0.42))
		_sphere(_head, 0.026, Vector3(x, 0.176, -0.195), _mat["iris"], Vector3(1.0, 1.12, 0.36))
		_sphere(_head, 0.014, Vector3(x, 0.174, -0.204), _mat["pupil"], Vector3(1.0, 1.15, 0.30))
		_sphere(_head, 0.008, Vector3(x - 0.008, 0.190, -0.211), _mat["eye_white"], Vector3(1.0, 1.0, 0.30))
		_hair_box(Vector3(0.068, 0.018, 0.016), Vector3(x, 0.252, -0.178), Vector3(0.0, 0.0, -0.16 * side))
		_sphere(_head, 0.024, Vector3(x * 1.55, 0.108, -0.166), _mat["mouth"], Vector3(1.0, 0.55, 0.25))

	_box(_head, Vector3(0.044, 0.010, 0.012), Vector3(0.0, 0.074, -0.180), _mat["mouth"])
	_box(_head, Vector3(0.030, 0.006, 0.010), Vector3(0.0, 0.061, -0.177), _mat["mouth"])

	# Layered hair: swept fringe, side locks, a back mass and a short tail.
	_hair_box(Vector3(0.100, 0.105, 0.060), Vector3(0.0, 0.287, -0.158), Vector3(-0.16, 0.0, 0.0), true)
	_hair_box(Vector3(0.092, 0.130, 0.055), Vector3(-0.093, 0.271, -0.153), Vector3(-0.10, 0.10, 0.28))
	_hair_box(Vector3(0.092, 0.142, 0.055), Vector3(0.094, 0.267, -0.150), Vector3(-0.10, -0.10, -0.30))
	_hair_box(Vector3(0.060, 0.170, 0.050), Vector3(-0.158, 0.215, -0.112), Vector3(0.0, 0.20, 0.34))
	_hair_box(Vector3(0.060, 0.178, 0.050), Vector3(0.160, 0.212, -0.108), Vector3(0.0, -0.20, -0.36), true)
	_hair_box(Vector3(0.045, 0.120, 0.045), Vector3(-0.170, 0.145, -0.060), Vector3(0.0, 0.0, 0.08))
	_hair_box(Vector3(0.045, 0.115, 0.045), Vector3(0.170, 0.148, -0.058), Vector3(0.0, 0.0, -0.08), true)
	_hair_sphere(0.170, Vector3(0.0, 0.180, 0.092), Vector3(1.10, 0.92, 0.78))
	_hair_box(Vector3(0.130, 0.090, 0.050), Vector3(0.0, 0.292, 0.075), Vector3(-0.12, 0.0, 0.0), true)
	_hair_box(Vector3(0.072, 0.168, 0.070), Vector3(0.045, 0.095, 0.175), Vector3(-0.32, 0.0, -0.16))

# ---------------------------------------------------------------------------
# Cape (shared geometry, recoloured per outfit)
# ---------------------------------------------------------------------------

func _build_cape() -> void:
	if _upper == null:
		return
	_cape_root = Node3D.new()
	_cape_root.name = "CapeRoot"
	_cape_root.position = Vector3(0.0, 0.425, 0.105)
	_upper.add_child(_cape_root)

	_cape_sphere(_upper, 0.042, Vector3(0.0, 0.438, 0.092), Vector3(1.35, 0.85, 0.65), "brass")
	_cape_sphere(_upper, 0.024, Vector3(-0.070, 0.448, 0.086), Vector3(1.0, 1.0, 0.55), "brass")
	_cape_sphere(_upper, 0.024, Vector3(0.070, 0.448, 0.086), Vector3(1.0, 1.0, 0.55), "brass")
	_cape_part(_upper, Vector3(0.090, 0.022, 0.030), Vector3(-0.125, 0.438, 0.075), "leather_dark", Vector3(0.0, 0.0, 0.25))
	_cape_part(_upper, Vector3(0.090, 0.022, 0.030), Vector3(0.125, 0.438, 0.075), "leather_dark", Vector3(0.0, 0.0, -0.25))

	var upper_pivot := Node3D.new()
	upper_pivot.name = "CapeUpper"
	upper_pivot.rotation = Vector3(-0.10, 0.0, 0.0)
	_cape_root.add_child(upper_pivot)
	_cape_part(upper_pivot, Vector3(0.300, 0.205, 0.018), Vector3(0.0, -0.100, 0.0), "cape")

	var mid_pivot := Node3D.new()
	mid_pivot.name = "CapeMid"
	mid_pivot.position = Vector3(0.0, -0.198, 0.0)
	mid_pivot.rotation = Vector3(-0.055, 0.0, 0.0)
	upper_pivot.add_child(mid_pivot)
	_cape_part(mid_pivot, Vector3(0.340, 0.205, 0.018), Vector3(0.0, -0.100, 0.0), "cape")
	_cape_part(mid_pivot, Vector3(0.025, 0.200, 0.022), Vector3(-0.173, -0.100, 0.0), "cape_dark")
	_cape_part(mid_pivot, Vector3(0.025, 0.200, 0.022), Vector3(0.173, -0.100, 0.0), "cape_dark")

	var lower_pivot := Node3D.new()
	lower_pivot.name = "CapeLower"
	lower_pivot.position = Vector3(0.0, -0.198, 0.0)
	lower_pivot.rotation = Vector3(-0.035, 0.0, 0.0)
	mid_pivot.add_child(lower_pivot)
	_cape_part(lower_pivot, Vector3(0.382, 0.205, 0.018), Vector3(0.0, -0.100, 0.0), "cape")
	_cape_part(lower_pivot, Vector3(0.386, 0.024, 0.022), Vector3(0.0, -0.196, 0.0), "brass")
	_cape_part(lower_pivot, Vector3(0.030, 0.190, 0.024), Vector3(-0.193, -0.098, 0.0), "cape_dark")
	_cape_part(lower_pivot, Vector3(0.030, 0.190, 0.024), Vector3(0.193, -0.098, 0.0), "cape_dark")

# ---------------------------------------------------------------------------
# Outfits
# ---------------------------------------------------------------------------

func _build_outfit(weapon_id: String) -> void:
	match weapon_id:
		"sword":
			_build_knight()
		"bow":
			_build_hunter()
		"staff":
			_build_wizard()
		"dagger":
			_build_rogue()
		"kitsune":
			_build_kitsune()

## Knight: blue tabard, full steel cuirass, faulds, winged helm and plate boots.
func _build_knight() -> void:
	var chest := _group(_upper, "sword")
	var hips := _group(_body, "sword")

	_cylinder(chest, 0.070, 0.10, Vector3(0.0, 0.435, 0.0), _mat["skin"])
	_sphere(chest, 0.112, Vector3(0.0, 0.418, 0.0), _mat["steel"], Vector3(1.18, 0.52, 1.05))
	_sphere(chest, 0.198, Vector3(0.0, 0.278, -0.012), _mat["steel"], Vector3(1.0, 1.02, 0.94))
	_box(chest, Vector3(0.026, 0.300, 0.026), Vector3(0.0, 0.278, -0.182), _mat["brass"])
	_box(chest, Vector3(0.270, 0.024, 0.026), Vector3(0.0, 0.385, -0.166), _mat["brass"])
	_box(chest, Vector3(0.150, 0.400, 0.018), Vector3(0.0, 0.180, -0.198), _mat["tunic"])
	_box(chest, Vector3(0.044, 0.400, 0.020), Vector3(-0.055, 0.180, -0.202), _mat["brass"])
	_box(chest, Vector3(0.044, 0.400, 0.020), Vector3(0.055, 0.180, -0.202), _mat["brass"])
	_box(chest, Vector3(0.150, 0.360, 0.018), Vector3(0.0, 0.180, 0.188), _mat["tunic_dark"])

	for i in 3:
		var step := float(i)
		var width := 0.270 - 0.020 * step
		var y := -0.020 - 0.055 * step
		var z := 0.100 + 0.006 * step
		_box(hips, Vector3(width, 0.070, 0.020), Vector3(0.0, y, -z), _mat["steel"], Vector3(0.18, 0.0, 0.0))
		_box(hips, Vector3(width, 0.070, 0.020), Vector3(0.0, y, z), _mat["steel"], Vector3(-0.18, 0.0, 0.0))
	_box(hips, Vector3(0.300, 0.045, 0.210), Vector3(0.0, 0.055, 0.0), _mat["leather"])
	_box(hips, Vector3(0.060, 0.060, 0.022), Vector3(0.0, 0.055, -0.112), _mat["brass"])
	_box(hips, Vector3(0.085, 0.105, 0.060), Vector3(-0.165, -0.020, -0.070), _mat["leather"], Vector3(0.0, 0.28, 0.0))
	_box(hips, Vector3(0.070, 0.082, 0.052), Vector3(0.168, -0.018, 0.060), _mat["leather_dark"], Vector3(0.0, -0.30, 0.0))
	_box(hips, Vector3(0.045, 0.360, 0.028), Vector3(-0.165, 0.045, 0.155), _mat["leather_dark"], Vector3(0.20, 0.0, 0.34))
	_box(hips, Vector3(0.058, 0.030, 0.038), Vector3(-0.165, 0.215, 0.155), _mat["brass"], Vector3(0.20, 0.0, 0.34))

	if _head != null:
		var helm := _group(_head, "sword")
		_sphere(helm, 0.208, Vector3(0.0, 0.285, 0.012), _mat["steel"], Vector3(1.02, 0.72, 1.02))
		_box(helm, Vector3(0.034, 0.130, 0.030), Vector3(0.0, 0.232, -0.196), _mat["steel"])
		_box(helm, Vector3(0.360, 0.028, 0.340), Vector3(0.0, 0.328, 0.010), _mat["brass"])
		_box(helm, Vector3(0.100, 0.200, 0.060), Vector3(0.0, 0.380, 0.190), _mat["cape"], Vector3(-0.35, 0.0, 0.0))
		_sphere(helm, 0.026, Vector3(0.0, 0.336, -0.196), _mat["accent"], Vector3(1.0, 1.0, 0.6))

	for shoulder in [_left_shoulder, _right_shoulder]:
		if shoulder == null:
			continue
		var arm := _group(shoulder, "sword")
		_sphere(arm, 0.112, Vector3(0.0, 0.012, 0.0), _mat["steel"], Vector3(1.10, 0.62, 1.05))
		_sphere(arm, 0.028, Vector3(0.0, 0.062, -0.020), _mat["brass"], Vector3(1.0, 0.7, 1.0))
		_cylinder(arm, 0.069, 0.145, Vector3(0.0, -0.085, 0.0), _mat["tunic"], Vector3.ZERO, 0.062)
		_cylinder(arm, 0.072, 0.026, Vector3(0.0, -0.020, 0.0), _mat["steel"], Vector3.ZERO, 0.076)

	for elbow in [_left_elbow, _right_elbow]:
		if elbow == null:
			continue
		var arm := _group(elbow, "sword")
		_cylinder(arm, 0.063, 0.130, Vector3(0.0, -0.112, 0.0), _mat["steel"], Vector3.ZERO, 0.058)
		_cylinder(arm, 0.068, 0.020, Vector3(0.0, -0.052, 0.0), _mat["brass"])
		_cylinder(arm, 0.066, 0.018, Vector3(0.0, -0.174, 0.0), _mat["brass"])
		_box(arm, Vector3(0.045, 0.100, 0.014), Vector3(0.0, -0.112, -0.061), _mat["steel"])

	for knee in [_left_knee, _right_knee]:
		if knee == null:
			continue
		var leg := _group(knee, "sword")
		_sphere(leg, 0.072, Vector3(0.0, 0.0, -0.052), _mat["steel"], Vector3(1.0, 0.82, 0.48))
		_sphere(leg, 0.024, Vector3(0.0, 0.0, -0.090), _mat["brass"], Vector3(1.0, 1.0, 0.45))
		_cylinder(leg, 0.077, 0.200, Vector3(0.0, -0.155, 0.0), _mat["steel"], Vector3.ZERO, 0.070)
		_box(leg, Vector3(0.085, 0.140, 0.020), Vector3(0.0, -0.160, -0.074), _mat["brass"])

	for foot in [_left_foot, _right_foot]:
		if foot == null:
			continue
		var boot := _group(foot, "sword")
		_box(boot, Vector3(0.140, 0.020, 0.230), Vector3(0.0, -0.046, -0.036), _mat["leather_dark"])
		_sphere(boot, 0.070, Vector3(0.0, -0.028, -0.112), _mat["steel"], Vector3(1.0, 0.58, 0.92))
		_box(boot, Vector3(0.122, 0.015, 0.030), Vector3(0.0, 0.006, -0.052), _mat["brass"])

## Hunter: green hood and cloak, crossed leather harness, quiver and wrapped boots.
func _build_hunter() -> void:
	var chest := _group(_upper, "bow")
	var hips := _group(_body, "bow")

	_cylinder(chest, 0.067, 0.085, Vector3(0.0, 0.435, 0.0), _mat["skin"])
	_cylinder(chest, 0.090, 0.040, Vector3(0.0, 0.452, 0.0), _mat["cream"])
	_box(chest, Vector3(0.055, 0.440, 0.016), Vector3(0.0, 0.255, -0.182), _mat["leather"], Vector3(0.0, 0.0, 0.62))
	_box(chest, Vector3(0.055, 0.420, 0.016), Vector3(0.0, 0.255, -0.182), _mat["leather_dark"], Vector3(0.0, 0.0, -0.62))
	_box(chest, Vector3(0.070, 0.060, 0.022), Vector3(0.0, 0.250, -0.196), _mat["brass"])
	_box(chest, Vector3(0.240, 0.140, 0.018), Vector3(0.0, 0.120, -0.196), _mat["tunic"])

	if _head != null:
		var hood := _group(_head, "bow")
		_sphere(hood, 0.218, Vector3(0.0, 0.205, 0.055), _mat["cloth"], Vector3(1.04, 1.08, 0.92))
		_box(hood, Vector3(0.300, 0.050, 0.060), Vector3(0.0, 0.340, -0.150), _mat["cloth"], Vector3(0.35, 0.0, 0.0))
		_box(hood, Vector3(0.100, 0.220, 0.020), Vector3(-0.160, 0.200, -0.155), _mat["cloth"], Vector3(0.0, 0.0, 0.10))
		_box(hood, Vector3(0.100, 0.220, 0.020), Vector3(0.160, 0.200, -0.155), _mat["cloth"], Vector3(0.0, 0.0, -0.10))
		_box(hood, Vector3(0.030, 0.280, 0.050), Vector3(0.200, 0.320, 0.060), _mat["accent"], Vector3(-0.25, 0.20, 0.35))
		_box(hood, Vector3(0.022, 0.050, 0.020), Vector3(0.200, 0.450, 0.060), _mat["accent"], Vector3(-0.25, 0.20, 0.35))

	# Quiver and three arrows on the back.
	_cylinder(hips, 0.055, 0.340, Vector3(0.165, 0.170, 0.155), _mat["leather"], Vector3(0.26, 0.0, 0.30))
	for i in 3:
		var offset := -0.030 + 0.030 * float(i)
		_cylinder(hips, 0.008, 0.260, Vector3(0.145 + offset, 0.355, 0.190 + offset), _mat["cream"], Vector3(0.26, 0.0, 0.30))
		_box(hips, Vector3(0.030, 0.050, 0.010), Vector3(0.145 + offset, 0.455, 0.190 + offset), _mat["accent"], Vector3(0.26, 0.0, 0.30))

	_box(hips, Vector3(0.300, 0.045, 0.210), Vector3(0.0, 0.055, 0.0), _mat["leather_dark"])
	_box(hips, Vector3(0.058, 0.058, 0.020), Vector3(0.0, 0.055, -0.112), _mat["brass"])
	_box(hips, Vector3(0.085, 0.100, 0.060), Vector3(-0.160, -0.020, -0.070), _mat["leather"], Vector3(0.0, 0.28, 0.0))
	_box(hips, Vector3(0.075, 0.095, 0.055), Vector3(0.165, -0.018, 0.060), _mat["leather"], Vector3(0.0, -0.30, 0.0))
	_box(hips, Vector3(0.040, 0.160, 0.025), Vector3(-0.175, -0.040, 0.100), _mat["steel"], Vector3(0.1, 0.0, 0.25))
	_box(hips, Vector3(0.025, 0.060, 0.020), Vector3(-0.175, 0.050, 0.100), _mat["brass"], Vector3(0.1, 0.0, 0.25))

	for shoulder in [_left_shoulder, _right_shoulder]:
		if shoulder == null:
			continue
		var arm := _group(shoulder, "bow")
		_sphere(arm, 0.082, Vector3(0.0, 0.0, 0.0), _mat["tunic_dark"], Vector3(1.05, 0.92, 1.05))
		_cylinder(arm, 0.069, 0.145, Vector3(0.0, -0.085, 0.0), _mat["tunic"], Vector3.ZERO, 0.073)
		_cylinder(arm, 0.073, 0.026, Vector3(0.0, -0.020, 0.0), _mat["leather"], Vector3.ZERO, 0.076)

	for elbow in [_left_elbow, _right_elbow]:
		if elbow == null:
			continue
		var arm := _group(elbow, "bow")
		_cylinder(arm, 0.063, 0.128, Vector3(0.0, -0.112, 0.0), _mat["leather"], Vector3.ZERO, 0.057)
		_cylinder(arm, 0.067, 0.018, Vector3(0.0, -0.052, 0.0), _mat["leather_dark"])
		_cylinder(arm, 0.066, 0.016, Vector3(0.0, -0.174, 0.0), _mat["leather_dark"])
		_box(arm, Vector3(0.045, 0.100, 0.014), Vector3(0.0, -0.112, -0.061), _mat["leather_dark"])

	for knee in [_left_knee, _right_knee]:
		if knee == null:
			continue
		var leg := _group(knee, "bow")
		_cylinder(leg, 0.074, 0.180, Vector3(0.0, -0.150, 0.0), _mat["leather_dark"], Vector3.ZERO, 0.068)
		_box(leg, Vector3(0.132, 0.030, 0.190), Vector3(0.0, -0.100, 0.0), _mat["leather"], Vector3(0.0, 0.0, 0.0))
		_sphere(leg, 0.070, Vector3(0.0, 0.0, -0.052), _mat["leather"], Vector3(1.0, 0.78, 0.52))

	for foot in [_left_foot, _right_foot]:
		if foot == null:
			continue
		var boot := _group(foot, "bow")
		_box(boot, Vector3(0.136, 0.020, 0.228), Vector3(0.0, -0.046, -0.036), _mat["leather_dark"])
		_sphere(boot, 0.068, Vector3(0.0, -0.028, -0.112), _mat["boot"], Vector3(1.0, 0.58, 0.92))
		_box(boot, Vector3(0.140, 0.016, 0.040), Vector3(0.0, 0.006, -0.052), _mat["leather"])

## Wizard: indigo robe, long sleeves, silver beard, and a tall pointed hat.
func _build_wizard() -> void:
	var chest := _group(_upper, "staff")
	var hips := _group(_body, "staff")

	_cylinder(chest, 0.069, 0.090, Vector3(0.0, 0.435, 0.0), _mat["skin"])
	_sphere(chest, 0.196, Vector3(0.0, 0.265, -0.008), _mat["tunic"], Vector3(1.0, 1.0, 0.95))
	_box(chest, Vector3(0.050, 0.200, 0.018), Vector3(-0.060, 0.360, -0.183), _mat["cream"], Vector3(0.0, 0.0, 0.50))
	_box(chest, Vector3(0.050, 0.200, 0.018), Vector3(0.060, 0.360, -0.183), _mat["cream"], Vector3(0.0, 0.0, -0.50))
	for i in 3:
		var y := 0.120 + 0.070 * float(i)
		_sphere(chest, 0.016, Vector3(-0.120 + 0.030 * float(i), y, -0.178), _mat["accent"], Vector3(1.0, 1.0, 0.5))
		_sphere(chest, 0.012, Vector3(0.135 - 0.028 * float(i), y + 0.030, -0.178), _mat["brass"], Vector3(1.0, 1.0, 0.5))

	_cylinder(hips, 0.290, 0.600, Vector3(0.0, -0.270, 0.0), _mat["tunic_dark"], Vector3.ZERO, 0.155)
	_cylinder(hips, 0.300, 0.038, Vector3(0.0, -0.010, 0.0), _mat["brass"], Vector3.ZERO, 0.160)
	_box(hips, Vector3(0.055, 0.520, 0.020), Vector3(0.0, -0.265, -0.238), _mat["accent"], Vector3(0.12, 0.0, 0.0))
	_box(hips, Vector3(0.230, 0.040, 0.060), Vector3(0.0, 0.055, -0.100), _mat["leather"])
	_box(hips, Vector3(0.065, 0.070, 0.030), Vector3(0.0, 0.040, -0.132), _mat["brass"])
	_box(hips, Vector3(0.075, 0.100, 0.055), Vector3(-0.170, -0.020, -0.050), _mat["leather"], Vector3(0.0, 0.28, 0.0))

	if _head != null:
		var hat := _group(_head, "staff")
		_cylinder(hat, 0.315, 0.028, Vector3(0.0, 0.345, 0.0), _mat["tunic"], Vector3.ZERO, 0.315)
		_cylinder(hat, 0.140, 0.460, Vector3(0.0, 0.565, 0.015), _mat["tunic"], Vector3.ZERO, 0.012)
		_cylinder(hat, 0.148, 0.048, Vector3(0.0, 0.368, 0.010), _mat["brass"], Vector3.ZERO, 0.144)
		_sphere(hat, 0.026, Vector3(0.0, 0.372, -0.146), _mat["accent"], Vector3(1.0, 1.0, 0.5))
		_sphere(hat, 0.094, Vector3(0.0, 0.030, -0.150), _mat["hair_light"], Vector3(0.92, 1.40, 0.55))
		_box(hat, Vector3(0.130, 0.028, 0.030), Vector3(0.0, 0.100, -0.192), _mat["hair_light"])
		_box(hat, Vector3(0.030, 0.090, 0.030), Vector3(-0.098, 0.060, -0.176), _mat["hair_light"], Vector3(0.0, 0.0, 0.18))
		_box(hat, Vector3(0.030, 0.090, 0.030), Vector3(0.098, 0.060, -0.176), _mat["hair_light"], Vector3(0.0, 0.0, -0.18))

	for shoulder in [_left_shoulder, _right_shoulder]:
		if shoulder == null:
			continue
		var arm := _group(shoulder, "staff")
		_sphere(arm, 0.084, Vector3(0.0, 0.0, 0.0), _mat["tunic"], Vector3(1.05, 0.92, 1.05))
		_cylinder(arm, 0.072, 0.145, Vector3(0.0, -0.085, 0.0), _mat["tunic"], Vector3.ZERO, 0.080)

	for elbow in [_left_elbow, _right_elbow]:
		if elbow == null:
			continue
		var arm := _group(elbow, "staff")
		_cylinder(arm, 0.105, 0.200, Vector3(0.0, -0.112, 0.0), _mat["tunic"], Vector3.ZERO, 0.056)
		_cylinder(arm, 0.100, 0.024, Vector3(0.0, -0.208, 0.0), _mat["brass"], Vector3.ZERO, 0.092)
		_box(arm, Vector3(0.045, 0.090, 0.014), Vector3(0.0, -0.120, -0.100), _mat["accent"])

	for knee in [_left_knee, _right_knee]:
		if knee == null:
			continue
		var leg := _group(knee, "staff")
		_cylinder(leg, 0.072, 0.170, Vector3(0.0, -0.155, 0.0), _mat["boot"], Vector3.ZERO, 0.064)
		_box(leg, Vector3(0.030, 0.060, 0.030), Vector3(0.0, -0.020, -0.060), _mat["brass"])

	for foot in [_left_foot, _right_foot]:
		if foot == null:
			continue
		var boot := _group(foot, "staff")
		_box(boot, Vector3(0.132, 0.020, 0.224), Vector3(0.0, -0.046, -0.036), _mat["leather_dark"])
		_sphere(boot, 0.066, Vector3(0.0, -0.028, -0.110), _mat["boot"], Vector3(1.0, 0.58, 0.92))
		_box(boot, Vector3(0.120, 0.014, 0.030), Vector3(0.0, 0.006, -0.052), _mat["brass"])

## Rogue: charcoal hood and face wrap, crossed harness, belt knives and soft boots.
func _build_rogue() -> void:
	var chest := _group(_upper, "dagger")
	var hips := _group(_body, "dagger")

	_cylinder(chest, 0.072, 0.090, Vector3(0.0, 0.435, 0.0), _mat["cloth"])
	_sphere(chest, 0.150, Vector3(0.0, 0.420, 0.000), _mat["cloth"], Vector3(1.25, 0.55, 1.15))
	_box(chest, Vector3(0.050, 0.400, 0.016), Vector3(0.0, 0.260, -0.186), _mat["leather"], Vector3(0.0, 0.0, 0.66))
	_box(chest, Vector3(0.050, 0.400, 0.016), Vector3(0.0, 0.260, -0.186), _mat["leather_dark"], Vector3(0.0, 0.0, -0.66))
	_box(chest, Vector3(0.060, 0.070, 0.022), Vector3(0.0, 0.250, -0.198), _mat["steel"])
	_box(chest, Vector3(0.220, 0.120, 0.016), Vector3(0.0, 0.120, -0.194), _mat["tunic_dark"])

	if _head != null:
		var hood := _group(_head, "dagger")
		_sphere(hood, 0.216, Vector3(0.0, 0.215, 0.050), _mat["cloth"], Vector3(1.04, 1.06, 0.94))
		_box(hood, Vector3(0.240, 0.120, 0.050), Vector3(0.0, 0.105, -0.184), _mat["cloth"], Vector3(0.10, 0.0, 0.0))
		_box(hood, Vector3(0.160, 0.220, 0.100), Vector3(0.0, 0.320, 0.150), _mat["cloth"], Vector3(-0.40, 0.0, 0.0))
		_box(hood, Vector3(0.300, 0.050, 0.050), Vector3(0.0, 0.300, -0.150), _mat["leather_dark"], Vector3(0.25, 0.0, 0.0))
		_box(hood, Vector3(0.022, 0.070, 0.020), Vector3(0.0, 0.160, -0.205), _mat["accent"])

	_box(hips, Vector3(0.300, 0.045, 0.210), Vector3(0.0, 0.055, 0.0), _mat["leather_dark"])
	_box(hips, Vector3(0.060, 0.060, 0.020), Vector3(0.0, 0.055, -0.112), _mat["steel"])
	_box(hips, Vector3(0.080, 0.100, 0.055), Vector3(-0.165, -0.020, -0.070), _mat["leather"], Vector3(0.0, 0.28, 0.0))
	_box(hips, Vector3(0.080, 0.100, 0.055), Vector3(0.165, -0.020, -0.070), _mat["leather"], Vector3(0.0, -0.28, 0.0))
	_box(hips, Vector3(0.040, 0.180, 0.025), Vector3(-0.178, -0.030, 0.105), _mat["leather_dark"], Vector3(0.15, 0.0, 0.22))
	_box(hips, Vector3(0.040, 0.160, 0.025), Vector3(0.178, -0.040, 0.100), _mat["leather_dark"], Vector3(0.15, 0.0, -0.22))
	_box(hips, Vector3(0.038, 0.060, 0.020), Vector3(-0.178, 0.040, 0.105), _mat["brass"], Vector3(0.15, 0.0, 0.22))
	_box(hips, Vector3(0.038, 0.060, 0.020), Vector3(0.178, 0.030, 0.100), _mat["brass"], Vector3(0.15, 0.0, -0.22))

	for shoulder in [_left_shoulder, _right_shoulder]:
		if shoulder == null:
			continue
		var arm := _group(shoulder, "dagger")
		_sphere(arm, 0.086, Vector3(0.0, 0.0, 0.0), _mat["tunic_dark"], Vector3(1.10, 0.78, 1.05))
		_cylinder(arm, 0.066, 0.140, Vector3(0.0, -0.085, 0.0), _mat["tunic"], Vector3.ZERO, 0.060)
		_box(arm, Vector3(0.120, 0.020, 0.120), Vector3(0.0, 0.045, 0.0), _mat["leather"], Vector3(0.0, 0.0, 0.10))

	for elbow in [_left_elbow, _right_elbow]:
		if elbow == null:
			continue
		var arm := _group(elbow, "dagger")
		_cylinder(arm, 0.061, 0.126, Vector3(0.0, -0.112, 0.0), _mat["cloth"], Vector3.ZERO, 0.056)
		for i in 3:
			_cylinder(arm, 0.064, 0.012, Vector3(0.0, -0.070 - 0.035 * float(i), 0.0), _mat["leather_dark"])
		_box(arm, Vector3(0.042, 0.080, 0.012), Vector3(0.0, -0.125, -0.060), _mat["leather"])

	for knee in [_left_knee, _right_knee]:
		if knee == null:
			continue
		var leg := _group(knee, "dagger")
		_cylinder(leg, 0.072, 0.170, Vector3(0.0, -0.155, 0.0), _mat["leather_dark"], Vector3.ZERO, 0.065)
		_sphere(leg, 0.068, Vector3(0.0, 0.0, -0.050), _mat["leather"], Vector3(1.0, 0.72, 0.50))
		_box(leg, Vector3(0.120, 0.022, 0.160), Vector3(0.0, -0.100, 0.0), _mat["leather"], Vector3(0.10, 0.0, 0.0))

	for foot in [_left_foot, _right_foot]:
		if foot == null:
			continue
		var boot := _group(foot, "dagger")
		_box(boot, Vector3(0.132, 0.020, 0.222), Vector3(0.0, -0.046, -0.036), _mat["leather_dark"])
		_sphere(boot, 0.064, Vector3(0.0, -0.030, -0.108), _mat["boot"], Vector3(1.0, 0.56, 0.90))
		_box(boot, Vector3(0.128, 0.014, 0.032), Vector3(0.0, 0.006, -0.052), _mat["leather"])

## Kitsune: white kimono, vermilion haori and obi, fox ears and a living tail.
func _build_kitsune() -> void:
	var chest := _group(_upper, "kitsune")
	var hips := _group(_body, "kitsune")

	_cylinder(chest, 0.069, 0.088, Vector3(0.0, 0.435, 0.0), _mat["skin"])
	_sphere(chest, 0.194, Vector3(0.0, 0.267, -0.008), _mat["tunic"], Vector3(1.0, 1.0, 0.95))
	_box(chest, Vector3(0.060, 0.240, 0.020), Vector3(-0.070, 0.345, -0.180), _mat["cape"], Vector3(0.0, 0.0, 0.55))
	_box(chest, Vector3(0.060, 0.240, 0.020), Vector3(0.070, 0.345, -0.180), _mat["cape"], Vector3(0.0, 0.0, -0.55))
	_box(chest, Vector3(0.022, 0.240, 0.024), Vector3(0.0, 0.340, -0.186), _mat["brass"], Vector3(0.0, 0.0, 0.0))
	_box(chest, Vector3(0.200, 0.080, 0.018), Vector3(0.0, 0.140, -0.190), _mat["tunic_light"])

	_box(hips, Vector3(0.310, 0.100, 0.220), Vector3(0.0, 0.040, 0.0), _mat["cape"])
	_box(hips, Vector3(0.330, 0.030, 0.230), Vector3(0.0, 0.098, 0.0), _mat["brass"])
	_box(hips, Vector3(0.090, 0.055, 0.030), Vector3(0.0, 0.045, -0.126), _mat["brass"])
	_cylinder(hips, 0.245, 0.340, Vector3(0.0, -0.160, 0.0), _mat["tunic_dark"], Vector3.ZERO, 0.150)
	_box(hips, Vector3(0.045, 0.300, 0.020), Vector3(-0.080, -0.155, -0.214), _mat["cape"], Vector3(0.10, 0.0, 0.06))
	_box(hips, Vector3(0.045, 0.300, 0.020), Vector3(0.080, -0.155, -0.214), _mat["cape"], Vector3(0.10, 0.0, -0.06))

	# Gold fox charm at the hip.
	_sphere(hips, 0.058, Vector3(0.175, -0.020, -0.095), _mat["cream"], Vector3(0.90, 1.10, 0.36))
	_box(hips, Vector3(0.018, 0.014, 0.012), Vector3(0.160, -0.002, -0.128), _mat["cape"])
	_box(hips, Vector3(0.018, 0.014, 0.012), Vector3(0.190, -0.002, -0.128), _mat["cape"])
	_box(hips, Vector3(0.014, 0.030, 0.012), Vector3(0.175, -0.050, -0.128), _mat["cape"], Vector3(0.0, 0.0, 0.78))

	if _head != null:
		var fox := _group(_head, "kitsune")
		_cylinder(fox, 0.066, 0.200, Vector3(-0.110, 0.400, 0.010), _mat["fur"], Vector3(0.0, 0.0, 0.18), 0.008)
		_cylinder(fox, 0.066, 0.200, Vector3(0.110, 0.400, 0.010), _mat["fur"], Vector3(0.0, 0.0, -0.18), 0.008)
		_cylinder(fox, 0.035, 0.130, Vector3(-0.108, 0.382, -0.022), _mat["cape"], Vector3(0.0, 0.0, 0.18), 0.006)
		_cylinder(fox, 0.035, 0.130, Vector3(0.108, 0.382, -0.022), _mat["cape"], Vector3(0.0, 0.0, -0.18), 0.006)
		_box(fox, Vector3(0.100, 0.040, 0.080), Vector3(-0.100, 0.310, 0.010), _mat["fur"], Vector3(0.0, 0.0, 0.14))
		_box(fox, Vector3(0.100, 0.040, 0.080), Vector3(0.100, 0.310, 0.010), _mat["fur"], Vector3(0.0, 0.0, -0.14))
		_box(fox, Vector3(0.060, 0.022, 0.020), Vector3(0.0, 0.340, -0.196), _mat["brass"])

	for shoulder in [_left_shoulder, _right_shoulder]:
		if shoulder == null:
			continue
		var arm := _group(shoulder, "kitsune")
		_sphere(arm, 0.084, Vector3(0.0, 0.0, 0.0), _mat["tunic"], Vector3(1.08, 0.90, 1.05))
		_cylinder(arm, 0.073, 0.145, Vector3(0.0, -0.085, 0.0), _mat["tunic"], Vector3.ZERO, 0.078)
		_cylinder(arm, 0.078, 0.026, Vector3(0.0, -0.020, 0.0), _mat["cape"], Vector3.ZERO, 0.080)

	for elbow in [_left_elbow, _right_elbow]:
		if elbow == null:
			continue
		var arm := _group(elbow, "kitsune")
		_cylinder(arm, 0.102, 0.190, Vector3(0.0, -0.112, 0.0), _mat["tunic"], Vector3.ZERO, 0.058)
		_cylinder(arm, 0.096, 0.026, Vector3(0.0, -0.199, 0.0), _mat["cape"], Vector3.ZERO, 0.090)
		_box(arm, Vector3(0.040, 0.080, 0.014), Vector3(0.0, -0.120, -0.098), _mat["brass"])

	for knee in [_left_knee, _right_knee]:
		if knee == null:
			continue
		var leg := _group(knee, "kitsune")
		_cylinder(leg, 0.070, 0.160, Vector3(0.0, -0.155, 0.0), _mat["tunic_dark"], Vector3.ZERO, 0.062)
		_box(leg, Vector3(0.040, 0.020, 0.030), Vector3(0.0, -0.020, -0.062), _mat["cape"])

	for foot in [_left_foot, _right_foot]:
		if foot == null:
			continue
		var boot := _group(foot, "kitsune")
		_box(boot, Vector3(0.130, 0.020, 0.220), Vector3(0.0, -0.046, -0.036), _mat["leather_dark"])
		_sphere(boot, 0.064, Vector3(0.0, -0.030, -0.108), _mat["boot"], Vector3(1.0, 0.56, 0.90))
		_box(boot, Vector3(0.126, 0.014, 0.030), Vector3(0.0, 0.006, -0.052), _mat["brass"])

# ---------------------------------------------------------------------------
# Kitsune tail
# ---------------------------------------------------------------------------

func _build_tail() -> void:
	if _body == null:
		return
	_tail_root = Node3D.new()
	_tail_root.name = "KitsuneTail"
	_tail_root.position = Vector3(0.165, -0.060, 0.135)
	_tail_root.rotation = Vector3(0.0, -0.32, 0.0)
	_body.add_child(_tail_root)

	var parent := _tail_root
	var radii := [0.090, 0.108, 0.100, 0.082, 0.060, 0.038]
	for i in radii.size():
		var pivot := Node3D.new()
		pivot.name = "TailSegment%d" % i
		if i > 0:
			pivot.position = Vector3(0.0, 0.0, 0.145)
			pivot.rotation = Vector3(-0.08, 0.0, 0.0)
		parent.add_child(pivot)
		var fur := _sphere(pivot, float(radii[i]), Vector3(0.0, 0.0, 0.072), _mat["fur"], Vector3(0.88, 0.88, 1.30))
		if i >= 3:
			_sphere(pivot, float(radii[i]) * 0.74, Vector3(0.0, 0.012, 0.126), _mat["cream"], Vector3(0.82, 0.82, 1.15))
		_tail_segments.append(pivot)
		parent = pivot

func _process(delta: float) -> void:
	if _tail_root == null or not _tail_root.visible:
		return
	_tail_time += delta
	var speed := 0.0
	var parent := get_parent()
	if parent != null:
		var velocity = parent.get("velocity")
		if velocity is Vector3:
			speed = Vector2(velocity.x, velocity.z).length()
	var energy := 1.0 + minf(speed * 0.14, 0.9)
	for i in _tail_segments.size():
		var segment := _tail_segments[i]
		var phase := _tail_time * (1.7 + 0.24 * float(i)) - 0.48 * float(i)
		# The root segment lifts the whole brush up and back; later segments only
		# add a gentle curl, so the tail reads as one arc rather than a whip.
		var base_x := -0.55 if i == 0 else -0.10
		segment.rotation.x = base_x + sin(phase * 1.15) * 0.10 * energy
		segment.rotation.y = sin(phase) * 0.20 * energy
		segment.rotation.z = cos(phase * 0.9) * 0.16 * energy
