extends StaticBody3D

## A cave mouth in the western rocks of the Thorned Field that leads down into
## the Under-Reach. The hill seals itself with living briars until the wayshrine
## is lit, then the thorns withdraw and the dark tunnel opens. The actual floor
## building is delegated to the dungeon manager node found in the
## "dungeon_manager" group; this node only sells the entry.

@export var entrance_name := "the Under-Reach"

## The cave mouth and its apron are wider than a doorway: let the hero interact
## from the approach stones instead of only from the dark itself.
const INTERACTION_RADIUS := 5.4

var _lit_fx := false
var _fx_initialized := false
var _glow_materials: Array[StandardMaterial3D] = []
var _flames: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _motes: Array[Dictionary] = []
var _seal_root: Node3D
var _seal_collision: CollisionShape3D
var _inner_light: OmniLight3D
var _time := 0.0
var _check_timer := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("dungeon_entrance")
	_build()
	_ignite(_dungeon_unlocked())

func can_interact() -> bool:
	var manager := _find_manager()
	if manager == null or bool(manager.call("is_inside_dungeon")):
		return false
	# Stay targetable even while the briars seal the mouth so the cave can
	# explain why it will not open instead of silently doing nothing.
	return true

func get_interaction_range() -> float:
	return INTERACTION_RADIUS

func get_interaction_prompt() -> String:
	if not _dungeon_unlocked():
		return "[ E ]     The cave is sealed by briars - light the wayshrine"
	return "[ E ]     Descend into %s" % entrance_name

func interact(_player: Node) -> void:
	var manager := _find_manager()
	if manager == null or bool(manager.call("is_inside_dungeon")):
		return
	if not _dungeon_unlocked():
		_toast("The cave mouth is bound in briars.  Light the wayshrine to open the way down.")
		return
	manager.call("enter_dungeon")

func _toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text, 2.6)

func _process(delta: float) -> void:
	_time += delta
	_check_timer -= delta
	if _check_timer <= 0.0:
		_check_timer = 0.5
		_ignite(_dungeon_unlocked())
	for i in _flames.size():
		_flames[i].scale = Vector3(0.85, 1.05 + sin(_time * 5.0 + float(i) * 1.9) * 0.18, 0.85)
	for i in _lights.size():
		_lights[i].light_energy = 0.9 + sin(_time * 2.7 + float(i) * 1.3) * 0.18
	if _inner_light != null:
		var base := 1.45 if _lit_fx else 0.28
		_inner_light.light_energy = base + sin(_time * 1.8) * 0.12
	for mote in _motes:
		var node: Node3D = mote["node"]
		var base_pos: Vector3 = mote["base"]
		var phase: float = mote["phase"]
		var speed: float = mote["speed"]
		node.position = base_pos + Vector3(
			sin(_time * speed + phase) * 0.38,
			sin(_time * speed * 1.7 + phase * 2.1) * 0.24,
			cos(_time * speed * 0.8 + phase) * 0.30
		)

func _build() -> void:
	var rock := _material(Color(0.28, 0.27, 0.24), 0.98)
	var rock_dark := _material(Color(0.17, 0.165, 0.15), 1.0)
	var rock_light := _material(Color(0.36, 0.34, 0.29), 0.96)
	var moss := _material(Color(0.24, 0.31, 0.18), 1.0)
	var wood := _material(Color(0.29, 0.2, 0.11), 0.95)
	var iron := _material(Color(0.19, 0.18, 0.17), 0.5, 0.65)
	var torch := _material(Color(1.0, 0.68, 0.28), 0.3, 0.0, 1.9)
	var glow := _material(Color(0.62, 0.86, 0.55), 0.4, 0.0, 1.4)

	# The apron: worn flagstones and gravel leading out of the mouth.
	_mesh("cylinder", Vector3(0.0, 0.02, 2.3), Vector3(2.5, 2.8, 0.08), rock_dark)
	_mesh("cylinder", Vector3(0.0, 0.04, 2.2), Vector3(2.0, 2.3, 0.07), rock)
	for i in 4:
		var step_z := 2.8 + float(i) * 1.15
		var step := _mesh("cylinder", Vector3(sin(float(i) * 1.7) * 0.5, 0.035, step_z), Vector3(1.1, 1.25, 0.07), rock_light if i % 2 == 0 else rock)
		step.rotation.y = float(i) * 0.9
	for i in 7:
		var angle := float(i) * TAU / 7.0 + 0.3
		var pebble := _mesh("sphere", Vector3(cos(angle) * (3.1 + float(i % 3) * 0.45), 0.12, 1.1 + sin(angle) * 1.7), Vector3(0.28, 0.2, 0.24), rock_dark)
		pebble.rotation.y = angle
		pebble.scale = Vector3(1.0, 0.65, 0.9)

	# The hill: broad shoulders either side and a heavy brow over the opening.
	var boulders := [
		[Vector3(-3.35, 1.1, -0.5), Vector3(1.45, 1.7, 1.25)],
		[Vector3(3.35, 1.1, -0.5), Vector3(1.45, 1.7, 1.25)],
		[Vector3(-4.55, 1.4, -2.1), Vector3(2.0, 2.3, 2.1)],
		[Vector3(4.55, 1.4, -2.1), Vector3(2.0, 2.3, 2.1)],
		[Vector3(-2.65, 2.75, -1.25), Vector3(1.8, 1.7, 1.6)],
		[Vector3(2.65, 2.75, -1.25), Vector3(1.8, 1.7, 1.6)],
		[Vector3(0.0, 3.35, -1.0), Vector3(3.2, 1.5, 2.0)],
		[Vector3(-1.1, 2.05, -2.4), Vector3(1.6, 1.5, 1.4)],
		[Vector3(1.1, 2.05, -2.4), Vector3(1.6, 1.5, 1.4)],
		[Vector3(-4.2, 0.45, 0.65), Vector3(1.0, 1.0, 0.9)],
		[Vector3(4.2, 0.45, 0.65), Vector3(1.0, 1.0, 0.9)],
		[Vector3(-1.9, 0.25, 0.9), Vector3(0.65, 0.55, 0.6)],
		[Vector3(1.9, 0.25, 0.9), Vector3(0.65, 0.55, 0.6)],
	]
	for i in boulders.size():
		var spot: Vector3 = boulders[i][0]
		var shape: Vector3 = boulders[i][1]
		var boulder := _mesh("sphere", spot, Vector3(1.0, 1.0, 1.0), rock if i % 3 != 1 else rock_light)
		boulder.scale = shape
		boulder.rotation.y = float(i) * 1.31
		boulder.rotation.z = sin(float(i) * 2.1) * 0.08
	# A few jagged crown stones and mossy caps.
	for i in 7:
		var angle := float(i) * TAU / 7.0 + 0.4
		var crown_spot := Vector3(cos(angle) * 3.6, 3.35 + sin(float(i) * 1.9) * 0.45, -1.7 + sin(angle) * 1.1)
		var crown := _mesh("prism", crown_spot, Vector3(0.75, 1.25, 0.65), rock_dark)
		crown.rotation.y = -angle
		crown.rotation.z = cos(angle) * 0.24
	for i in 5:
		var angle := float(i) * TAU / 5.0 + 0.8
		var cap := _mesh("sphere", Vector3(cos(angle) * 4.0, 2.5 + sin(float(i) * 2.3) * 0.7, -2.0 + sin(angle) * 1.4), Vector3(0.8, 0.35, 0.65), moss)
		cap.rotation.y = angle

	# The dark mouth itself: a recessed tunnel with descending steps and a
	# faint glow far back, so the way down reads without exposing the void.
	var void_material := StandardMaterial3D.new()
	void_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	void_material.albedo_color = Color(0.008, 0.01, 0.012)
	var void_back := _mesh("box", Vector3(0.0, 1.65, -2.55), Vector3(3.5, 3.3, 0.25), void_material)
	void_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tunnel_floor := _mesh("box", Vector3(0.0, 0.015, -1.25), Vector3(3.2, 0.05, 2.6), rock_dark)
	tunnel_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 3:
		var sink := 0.02 - float(i) * 0.105
		var step := _mesh("box", Vector3(0.0, sink, -0.35 - float(i) * 0.52), Vector3(2.7 - float(i) * 0.34, 0.16, 0.42), rock_dark)
		step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var far_glow := _mesh("sphere", Vector3(0.0, 0.85, -2.38), Vector3(0.18, 0.18, 0.18), glow)
	far_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Threshold rocks and roots framing the opening.
	for side in [-1, 1]:
		var lip := _mesh("prism", Vector3(float(side) * 2.15, 0.55, 0.35), Vector3(0.75, 1.2, 0.65), rock_light)
		lip.rotation.y = -0.42 * float(side)
		lip.rotation.z = 0.16 * float(side)
		var root := _mesh("cylinder", Vector3(float(side) * 1.85, 0.5, 0.75), Vector3(0.08, 0.12, 1.5), wood)
		root.rotation.z = 0.55 * float(side)
		root.rotation.x = 0.3

	# Two torches on the approach, deliberately outside the sealed mouth.
	for side in [-1, 1]:
		_torch(Vector3(float(side) * 2.85, 0.0, 0.7), wood, iron, torch)

	# The briar seal: living thorns woven across the entrance until the shrine
	# wakes. They retract into the ground when the way opens.
	_seal_root = Node3D.new()
	_seal_root.name = "BriarSeal"
	add_child(_seal_root)
	for i in 9:
		var span := 3.35 - absf(float(i) - 4.0) * 0.16
		var y := 0.35 + float(i % 5) * 0.48
		var branch := _mesh("cylinder", Vector3(0.0, y, -0.05 - float(i % 2) * 0.15), Vector3(0.055, 0.08, span), wood, _seal_root)
		branch.rotation.z = PI * 0.5 + sin(float(i) * 1.7) * 0.18
		branch.rotation.x = sin(float(i) * 2.3) * 0.12
		var thorn := _mesh("prism", Vector3(cos(float(i) * 2.1) * 1.25, y + 0.12, 0.0), Vector3(0.2, 0.55, 0.16), glow, _seal_root)
		thorn.rotation.z = cos(float(i) * 1.9) * 0.75
		thorn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var seal_light := OmniLight3D.new()
	seal_light.light_color = Color(0.52, 0.78, 0.46)
	seal_light.light_energy = 0.45
	seal_light.omni_range = 4.0
	seal_light.position = Vector3(0.0, 1.35, 0.3)
	_seal_root.add_child(seal_light)

	# Weathered signpost on the approach.
	var sign_pivot := Node3D.new()
	sign_pivot.position = Vector3(3.75, 0.0, 4.15)
	sign_pivot.rotation.y = -0.5
	add_child(sign_pivot)
	_mesh("cylinder", Vector3(0.0, 0.8, 0.0), Vector3(0.055, 0.07, 1.6), wood, sign_pivot)
	var board := _mesh("box", Vector3(0.0, 1.55, 0.0), Vector3(1.25, 0.32, 0.06), wood, sign_pivot)
	board.rotation.z = 0.03
	var sign_text := Label3D.new()
	sign_text.text = "THE UNDER-REACH"
	sign_text.font_size = 30
	sign_text.pixel_size = 0.0036
	sign_text.outline_size = 10
	sign_text.outline_modulate = Color(0.05, 0.04, 0.03, 1.0)
	sign_text.modulate = Color(0.78, 0.72, 0.54, 1.0)
	sign_text.position = Vector3(0.0, 1.56, 0.045)
	sign_pivot.add_child(sign_text)

	# Collision: the hill shoulders, the brow and the back of the shallow
	# tunnel all block movement; only the mouth itself is walkable.
	_collider(Vector3(-4.1, 2.0, -1.7), Vector3(3.3, 4.6, 4.6), 0.18)
	_collider(Vector3(4.1, 2.0, -1.7), Vector3(3.3, 4.6, 4.6), -0.18)
	_collider(Vector3(0.0, 3.85, -1.4), Vector3(6.4, 1.7, 3.2), 0.0)
	_collider(Vector3(0.0, 1.5, -2.65), Vector3(3.4, 3.2, 0.5), 0.0)
	_seal_collision = _collider(Vector3(0.0, 1.15, 0.05), Vector3(3.0, 2.5, 0.35), 0.0)

	# Warm inner light that only fully wakes once the shrine is lit.
	_inner_light = OmniLight3D.new()
	_inner_light.light_color = Color(1.0, 0.72, 0.36)
	_inner_light.light_energy = 0.28
	_inner_light.omni_range = 8.0
	_inner_light.position = Vector3(0.0, 1.7, -0.7)
	add_child(_inner_light)

	# Motes drifting around the mouth, so the cave feels alive even in daylight.
	for i in 8:
		var mote_glow := _material(Color(0.92, 0.84, 0.58), 0.4, 0.0, 1.5)
		var mote := _mesh("sphere", Vector3(0.0, 1.4, 1.0), Vector3(0.055, 0.055, 0.055), mote_glow)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := float(i) * TAU / 8.0
		_motes.append({
			"node": mote,
			"base": Vector3(cos(angle) * 1.8, 1.25 + sin(float(i) * 2.2) * 0.55, 1.0 + sin(angle) * 1.1),
			"phase": float(i) * 0.85,
			"speed": 0.55 + float(i % 3) * 0.18,
		})

func _torch(offset: Vector3, wood: StandardMaterial3D, iron: StandardMaterial3D, flame_material: StandardMaterial3D) -> void:
	_mesh("cylinder", offset + Vector3(0.0, 0.65, 0.0), Vector3(0.075, 0.1, 1.3), wood)
	_mesh("cylinder", offset + Vector3(0.0, 1.33, 0.0), Vector3(0.18, 0.13, 0.2), iron)
	var flame := _mesh("sphere", offset + Vector3(0.0, 1.55, 0.0), Vector3(0.18, 0.22, 0.18), flame_material)
	_flames.append(flame)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 0.9
	light.omni_range = 6.0
	light.position = offset + Vector3(0.0, 1.7, 0.0)
	add_child(light)
	_lights.append(light)

func _ignite(on: bool) -> void:
	var first := not _fx_initialized
	if not first and on == _lit_fx:
		return
	_fx_initialized = true
	_lit_fx = on
	for material in _glow_materials:
		material.emission_energy_multiplier = 2.2 if on else 0.45
	for light in _lights:
		if first:
			light.light_energy = 0.9 if on else 0.55
		else:
			var tween := create_tween()
			tween.tween_property(light, "light_energy", 0.9 if on else 0.55, 0.8)
	if _inner_light != null and not first:
		var tween := create_tween()
		tween.tween_property(_inner_light, "light_energy", 1.45 if on else 0.28, 1.0)
	if _seal_collision != null:
		_seal_collision.set_deferred("disabled", on)
	if _seal_root != null:
		var target_scale := Vector3(1.0, 0.02, 1.0) if on else Vector3.ONE
		var target_y := -0.45 if on else 0.0
		if first:
			_seal_root.scale = target_scale
			_seal_root.position.y = target_y
		else:
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(_seal_root, "scale", target_scale, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property(_seal_root, "position:y", target_y, 0.8)

func _shrine_lit() -> bool:
	var shrine := get_tree().get_first_node_in_group("shrine")
	if shrine == null or not shrine.has_method("is_lit"):
		return false
	return bool(shrine.call("is_lit"))

## The cave answers to the Rowan/shrine milestone, not only the live shrine
## node: a save that already completed the quest keeps the way down open even
## when the shrine scene has just reloaded dark.
func _dungeon_unlocked() -> bool:
	if _shrine_lit():
		return true
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("is_dungeon_unlocked"):
		if bool(hud.call("is_dungeon_unlocked")):
			return true
	# Last resort for harnesses or scenes without a HUD: read the persisted run
	# directly. The autoload only exists when the project boots normally.
	var manager := get_node_or_null("/root/SaveManager")
	if manager != null:
		var data: Variant = manager.get("active_data")
		if typeof(data) == TYPE_DICTIONARY:
			var saved: Dictionary = data
			if bool(saved.get("shrine_lit", false)) \
					or int(saved.get("story_stage", 0)) >= 4 \
					or bool(saved.get("boss_defeated", false)):
				return true
	return false

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

func _collider(position: Vector3, size: Vector3, rotation_y := 0.0) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = position
	collision.rotation.y = rotation_y
	add_child(collision)
	return collision

func _mesh(shape: String, position: Vector3, size: Vector3, material: StandardMaterial3D, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var host: Node3D = parent if parent != null else self
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
	host.add_child(node)
	return node
