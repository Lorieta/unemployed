extends StaticBody3D

## A dungeon buff rune: a carved ring of standing stones around a glowing
## sigil disc. Stands in the "interactable" group so the hero can walk up and
## press E; the surge applies a timed buff to the hero and the rune goes
## dormant with a dying ember glow. One shot per visit — each rebuilt floor
## raises its runes fresh.

const KINDS := {
	"power": {
		"title": "Rune of Power",
		"prompt": "Channel the Rune of Power",
		"amount": 6.0,
		"duration": 20.0,
		"color": Color(1.0, 0.5, 0.2),
		"desc": "+6 arm strength for 20s",
	},
	"haste": {
		"title": "Rune of Haste",
		"prompt": "Channel the Rune of Haste",
		"amount": 0.3,
		"duration": 22.0,
		"color": Color(0.4, 1.0, 0.6),
		"desc": "+30% stride for 22s",
	},
	"ward": {
		"title": "Rune of Warding",
		"prompt": "Channel the Rune of Warding",
		"amount": 0.18,
		"duration": 24.0,
		"color": Color(0.45, 0.7, 1.0),
		"desc": "-18% damage taken for 24s",
	},
	"mend": {
		"title": "Rune of Mending",
		"prompt": "Channel the Rune of Mending",
		"amount": 4.5,
		"duration": 12.0,
		"color": Color(1.0, 0.6, 0.75),
		"desc": "wounds close slowly for 12s",
	},
}

@export var kind := "power"

var used := false
var _time := 0.0
var _pulse_materials: Array[StandardMaterial3D] = []
var _sigil: MeshInstance3D
var _light: OmniLight3D

func _ready() -> void:
	add_to_group("interactable")
	if not KINDS.has(kind):
		kind = "power"
	_build()

func can_interact() -> bool:
	return not used

func get_interaction_prompt() -> String:
	if used:
		return "The rune is spent.  Its light sleeps."
	return "[ E ]     %s   (%s)" % [str(KINDS[kind]["prompt"]), str(KINDS[kind]["desc"])]

func interact(player: Node) -> void:
	if used:
		return
	used = true
	if player != null and player.has_method("apply_buff"):
		player.call("apply_buff", kind, float(KINDS[kind]["amount"]), float(KINDS[kind]["duration"]))
	_dim()
	# A brief surge of light as the rune spends itself.
	var flash := OmniLight3D.new()
	flash.light_color = KINDS[kind]["color"]
	flash.light_energy = 3.0
	flash.omni_range = 7.0
	flash.position = Vector3(0.0, 1.4, 0.0)
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "light_energy", 0.0, 0.9)
	tween.tween_callback(flash.queue_free)

func _process(delta: float) -> void:
	_time += delta
	if used:
		return
	var pulse := 1.35 + sin(_time * 2.6) * 0.4
	for material in _pulse_materials:
		material.emission_energy_multiplier = pulse
	if _light != null:
		_light.light_energy = 1.1 + sin(_time * 2.6) * 0.25

func _build() -> void:
	var color: Color = KINDS[kind]["color"]
	var stone := _stone(Color(0.26, 0.25, 0.24), 0.92)
	var stone_dark := _stone(Color(0.18, 0.175, 0.165), 1.0)
	# Sunken plinth base.
	_disc(Vector3(0.0, 0.06, 0.0), 2.3, 0.12, stone_dark)
	_disc(Vector3(0.0, 0.1, 0.0), 1.7, 0.1, stone)
	# The sigil disc: two crossed glowing bars in a ring.
	_disc(Vector3(0.0, 0.18, 0.0), 1.15, 0.06, _glow(color * 0.5, 0.8))
	_sigil = _disc(Vector3(0.0, 0.24, 0.0), 0.85, 0.05, _glow(color, 1.35))
	_sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		var angle := float(i) * TAU / 4.0 + 0.785
		var bar := _box(Vector3(cos(angle) * 0.55, 0.3, sin(angle) * 0.55), Vector3(0.85, 0.04, 0.16), _glow(color, 1.2))
		bar.rotation.y = -angle
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Standing stones around the ring, each carved with a glowing band.
	for i in 5:
		var angle := float(i) * TAU / 5.0
		var lean := 0.06 * sin(float(i) * 1.7)
		var stone_node := _prism(Vector3(cos(angle) * 1.95, 0.85, sin(angle) * 1.95), Vector3(0.5, 1.7, 0.36), stone)
		stone_node.rotation.y = -angle
		stone_node.rotation.z = lean
		var band := _box(Vector3(cos(angle) * 1.95, 0.85, sin(angle) * 1.95) + Vector3(0.0, 0.15, 0.0), Vector3(0.44, 0.1, 0.3), _glow(color, 1.1))
		band.rotation.y = -angle
		band.rotation.z = lean
	# A few stray chips at the base.
	for i in 5:
		var angle := randf() * TAU
		var chip := _prism(Vector3(cos(angle) * randf_range(1.1, 2.6), 0.08, sin(angle) * randf_range(1.1, 2.6)), Vector3(0.22, 0.16, 0.2), stone_dark)
		chip.rotation.y = randf() * TAU
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 1.1
	_light.omni_range = 5.0
	_light.position = Vector3(0.0, 1.1, 0.0)
	add_child(_light)

func _dim() -> void:
	for material in _pulse_materials:
		material.emission_energy_multiplier = 0.25
	if _light != null:
		var tween := create_tween()
		tween.tween_property(_light, "light_energy", 0.12, 0.8)
	if _sigil != null:
		_sigil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _stone(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	_pulse_materials.append(material)
	return material

func _disc(position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 2
	mesh.material = material
	node.mesh = mesh
	node.position = position
	add_child(node)
	return node

func _box(position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	node.position = position
	add_child(node)
	return node

func _prism(position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	node.position = position
	add_child(node)
	return node
