extends StaticBody3D

## A dungeon loot chest. Treasure rooms hold a Grand Cache; cleared combat halls
## sometimes hide a smaller Old Cache. The chest shakes, throws its lid, and
## spills light and coins before handing its haul to the HUD. Opened state is
## restored by the dungeon manager when the hero climbs back to a saved floor.

signal opened(chest: Node)

const COMMON_POOL := [
	{"id": "health", "min": 1, "max": 2},
	{"id": "mana", "min": 1, "max": 2},
	{"id": "waybread", "min": 1, "max": 2},
	{"id": "moonpetal", "min": 1, "max": 2},
	{"id": "torch", "min": 1, "max": 1},
	{"id": "smoke_bomb", "min": 1, "max": 1},
]

const TREASURE_POOL := [
	{"id": "health_greater", "min": 1, "max": 2},
	{"id": "mana_greater", "min": 1, "max": 2},
	{"id": "elixir", "min": 1, "max": 1},
	{"id": "ember_tonic", "min": 1, "max": 2},
	{"id": "frost_salve", "min": 1, "max": 2},
	{"id": "smoke_bomb", "min": 1, "max": 2},
	{"id": "soulstone", "min": 1, "max": 1},
	{"id": "health", "min": 2, "max": 3},
	{"id": "mana", "min": 2, "max": 3},
	{"id": "waybread", "min": 2, "max": 3},
	{"id": "key", "min": 1, "max": 1},
	{"id": "ring", "min": 1, "max": 1},
]

@export var loot_quality := "treasure"
@export var chest_label := "Grand Cache"
var depth := 1
var room_index := 0
var loot_seed := 0
var is_open := false

var _opening := false
var _pending_open := false
var _root: Node3D
var _lid: Node3D
var _glow: StandardMaterial3D
var _light: OmniLight3D
var _time := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("dungeon_chest")
	_build()
	if _pending_open:
		_apply_open_pose()

func can_interact() -> bool:
	return not is_open and not _opening

func get_interaction_range() -> float:
	return 2.8

func get_interaction_prompt() -> String:
	return "[ E ]     Open the %s" % chest_label

func interact(_player: Node) -> void:
	if is_open or _opening:
		return
	is_open = true
	_opening = true
	var loot := _roll_loot()
	_play_open_animation(loot)

func mark_opened() -> void:
	_pending_open = true
	if _root == null:
		return
	_apply_open_pose()

func _apply_open_pose() -> void:
	_pending_open = false
	is_open = true
	_opening = false
	if _lid != null:
		_lid.rotation.x = -1.98
	if _light != null:
		_light.light_energy = 0.16
	if _glow != null:
		_glow.emission_energy_multiplier = 0.22

func _process(delta: float) -> void:
	_time += delta
	if _light != null and not is_open:
		_light.light_energy = 0.72 + sin(_time * 2.2) * 0.12
	if _glow != null and not is_open:
		_glow.emission_energy_multiplier = 1.1 + sin(_time * 2.8) * 0.25

func _build() -> void:
	var wood := _material(Color(0.38, 0.25, 0.12), 0.9)
	var wood_dark := _material(Color(0.25, 0.16, 0.08), 0.95)
	var iron := _material(Color(0.2, 0.19, 0.18), 0.45, 0.7)
	var gold := _material(Color(0.82, 0.63, 0.26), 0.35, 0.85)
	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_color = Color(1.0, 0.78, 0.35)
	_glow.emission_enabled = true
	_glow.emission = Color(1.0, 0.7, 0.28)
	_glow.emission_energy_multiplier = 1.2

	_root = Node3D.new()
	_root.name = "Chest"
	add_child(_root)

	# Body, feet and iron bands.
	_add_box(_root, Vector3(0.0, 0.31, 0.0), Vector3(1.18, 0.58, 0.74), wood)
	_add_box(_root, Vector3(0.0, 0.05, 0.0), Vector3(1.26, 0.1, 0.82), wood_dark)
	for side in [-1, 1]:
		_add_box(_root, Vector3(float(side) * 0.40, 0.34, 0.0), Vector3(0.075, 0.62, 0.79), iron)
		_add_box(_root, Vector3(float(side) * 0.47, 0.06, 0.27), Vector3(0.14, 0.16, 0.14), iron)
	# Front plate and keyhole.
	_add_box(_root, Vector3(0.0, 0.37, 0.385), Vector3(0.32, 0.28, 0.045), gold)
	_add_box(_root, Vector3(0.0, 0.37, 0.412), Vector3(0.10, 0.15, 0.025), iron)
	_add_box(_root, Vector3(0.0, 0.41, 0.427), Vector3(0.055, 0.055, 0.02), _glow)

	# Lid hinged at the back edge.
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0.0, 0.62, -0.37)
	_root.add_child(_lid)
	_add_box(_lid, Vector3(0.0, 0.08, 0.37), Vector3(1.25, 0.20, 0.79), wood)
	_add_box(_lid, Vector3(0.0, 0.19, 0.37), Vector3(1.16, 0.06, 0.70), wood_dark)
	for side in [-1, 1]:
		_add_box(_lid, Vector3(float(side) * 0.40, 0.16, 0.37), Vector3(0.075, 0.08, 0.82), iron)
		_add_box(_lid, Vector3(float(side) * 0.48, 0.12, 0.0), Vector3(0.12, 0.13, 0.12), iron)
		_add_box(_root, Vector3(float(side) * 0.48, 0.52, -0.36), Vector3(0.11, 0.12, 0.11), gold)

	# A small name-plate above the lock, and a warm cache light.
	var title := Label3D.new()
	title.text = chest_label.to_upper()
	title.font_size = 30
	title.pixel_size = 0.0032
	title.outline_size = 10
	title.outline_modulate = Color(0.04, 0.03, 0.02, 1.0)
	title.modulate = Color(0.88, 0.77, 0.48, 0.92)
	title.position = Vector3(0.0, 1.02, 0.1)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_root.add_child(title)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.76, 0.36)
	_light.light_energy = 0.72
	_light.omni_range = 4.2
	_light.position = Vector3(0.0, 0.95, 0.05)
	add_child(_light)

	# Solid enough to feel like a real cache, short enough to step around.
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 1.05, 0.92)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.52, 0.0)
	add_child(collision)

func _play_open_animation(loot: Dictionary) -> void:
	# A short rattle before the lid gives way.
	var shake := create_tween()
	shake.tween_property(_root, "position", Vector3(0.045, 0.0, 0.0), 0.055)
	shake.tween_property(_root, "position", Vector3(-0.045, 0.0, 0.0), 0.055)
	shake.tween_property(_root, "position", Vector3(0.03, 0.0, 0.0), 0.05)
	shake.tween_property(_root, "position", Vector3.ZERO, 0.06)

	var lid_tween := create_tween()
	lid_tween.tween_property(_lid, "rotation:x", -1.98, 0.58).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if _light != null:
		var flare := create_tween()
		flare.tween_property(_light, "light_energy", 3.6, 0.16)
		flare.tween_property(_light, "light_energy", 0.9, 0.85)
	if _glow != null:
		_glow.emission_energy_multiplier = 3.2

	_spawn_reward_fx()
	var grant := create_tween()
	grant.tween_interval(0.32)
	grant.tween_callback(_grant_loot.bind(loot))
	var finish := create_tween()
	finish.tween_interval(0.9)
	finish.tween_callback(func() -> void:
		_opening = false
	)

func _spawn_reward_fx() -> void:
	var palette: Array[Color] = [
		Color(1.0, 0.78, 0.32),
		Color(0.64, 0.88, 0.56),
		Color(0.58, 0.76, 1.0),
	]
	for i in 10:
		var color: Color = palette[i % palette.size()]
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.2
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.055 if i % 3 != 0 else 0.085
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere.material = material
		orb.mesh = sphere
		orb.position = Vector3(randf_range(-0.22, 0.22), 0.7, 0.1)
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(orb)
		var target := Vector3(randf_range(-1.15, 1.15), randf_range(1.45, 2.35), randf_range(-0.55, 0.75))
		var tween := orb.create_tween()
		tween.set_parallel(true)
		tween.tween_property(orb, "position", target, 0.62).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(orb, "scale", Vector3.ZERO, 0.62).set_delay(0.18)
		tween.chain().tween_callback(orb.queue_free)

	# A rising ring of rune light above the cache.
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.82, 0.44)
	ring_material.emission_enabled = true
	ring_material.emission = Color(1.0, 0.74, 0.3)
	ring_material.emission_energy_multiplier = 1.8
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.34
	torus.outer_radius = 0.45
	torus.rings = 16
	torus.ring_segments = 24
	torus.material = ring_material
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.84, 0.05)
	ring.rotation.x = PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "position:y", 1.8, 0.9)
	ring_tween.tween_property(ring, "scale", Vector3(1.9, 1.9, 1.9), 0.9)
	ring_tween.tween_property(ring, "rotation:y", TAU, 0.9)
	ring_tween.chain().tween_callback(ring.queue_free)

func _grant_loot(loot: Dictionary) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("grant_dungeon_loot"):
		hud.call("grant_dungeon_loot", loot.get("items", []), int(loot.get("gold", 0)), chest_label)
	opened.emit(self)

func _roll_loot() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = loot_seed if loot_seed != 0 else hash([room_index, depth, chest_label])
	var pool: Array = COMMON_POOL if loot_quality == "common" else TREASURE_POOL
	var items: Array = []
	var used := {}
	var picks := 2 if loot_quality == "common" else 3
	var guard := 0
	while items.size() < picks and guard < 40:
		guard += 1
		var entry: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var item_id := str(entry["id"])
		if used.has(item_id):
			continue
		used[item_id] = true
		var amount := rng.randi_range(int(entry.get("min", 1)), int(entry.get("max", 1)))
		items.append({"id": item_id, "amount": amount})
	var depth_bonus := maxi(0, depth - 1)
	var gold: int
	if loot_quality == "common":
		gold = rng.randi_range(16, 34) + depth_bonus * 4
	else:
		gold = rng.randi_range(62, 104) + depth_bonus * 14
	return {"items": items, "gold": gold}

func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_box(parent: Node3D, position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	node.mesh = box
	node.position = position
	parent.add_child(node)
	return node
