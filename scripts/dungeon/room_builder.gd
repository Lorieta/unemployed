class_name DungeonRoomBuilder
extends RefCounted

## Turns layout data into dungeon geometry: floors, walls with door gaps,
## corridors, porter gates, braziers, pillars, rubble, treasure chests and the
## boss dais. Everything is built from primitives at runtime in the style of
## world_builder.gd, with proper StaticBody3D colliders so rooms are fully
## enclosed except at door holes.

const Layout := preload("res://scripts/dungeon/layout_generator.gd")

const WALL_HEIGHT := 4.6
const WALL_THICKNESS := 0.6
const DOOR_TOP := 3.0

const BIOMES: Array[Dictionary] = [
	{
		"name": "Moss Crypt",
		"floor": Color(0.16, 0.2, 0.15),
		"wall": Color(0.22, 0.25, 0.2),
		"pillar": Color(0.27, 0.31, 0.24),
		"accent": Color(0.3, 0.44, 0.24),
		"torch": Color(1.0, 0.72, 0.3),
		"metal": Color(0.24, 0.26, 0.24),
		"crack": Color(0.12, 0.14, 0.1),
		"weft": Color(0.2, 0.32, 0.17),
		"weft_glow": 0.0,
		"puddle": Color(0.1, 0.13, 0.11),
		"bone": Color(0.62, 0.6, 0.52),
		"wood": Color(0.32, 0.23, 0.13),
	},
	{
		"name": "Ember Halls",
		"floor": Color(0.2, 0.14, 0.12),
		"wall": Color(0.26, 0.19, 0.16),
		"pillar": Color(0.3, 0.22, 0.18),
		"accent": Color(0.52, 0.2, 0.12),
		"torch": Color(1.0, 0.5, 0.18),
		"metal": Color(0.28, 0.23, 0.2),
		"crack": Color(0.1, 0.07, 0.06),
		"weft": Color(0.85, 0.3, 0.08),
		"weft_glow": 1.1,
		"puddle": Color(0.14, 0.08, 0.06),
		"bone": Color(0.6, 0.52, 0.44),
		"wood": Color(0.26, 0.17, 0.1),
	},
	{
		"name": "Frost Vaults",
		"floor": Color(0.14, 0.17, 0.2),
		"wall": Color(0.19, 0.23, 0.27),
		"pillar": Color(0.23, 0.28, 0.32),
		"accent": Color(0.35, 0.5, 0.62),
		"torch": Color(0.55, 0.8, 1.0),
		"metal": Color(0.22, 0.26, 0.3),
		"crack": Color(0.1, 0.13, 0.16),
		"weft": Color(0.6, 0.8, 0.95),
		"weft_glow": 0.7,
		"puddle": Color(0.12, 0.16, 0.2),
		"bone": Color(0.68, 0.68, 0.64),
		"wood": Color(0.28, 0.22, 0.16),
	},
]

static var _materials := {}

static func biome_for_depth(depth: int) -> Dictionary:
	return BIOMES[(depth - 1) % BIOMES.size()]

static func build(root: Node3D, layout: Dictionary, base_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rooms", int(layout["depth"]), base_seed])
	var rooms: Array = layout["rooms"]
	var extra_edges: Array = layout.get("extra_edges", [])
	var biome := biome_for_depth(int(layout["depth"]))
	var archetype := String(layout.get("archetype", "branch"))
	var escape := archetype == "escape"
	var cell_size := float(layout.get("cell_size", Layout.CELL))
	var door_dirs: Array = []
	for i in rooms.size():
		door_dirs.append(Layout.door_dirs_for(rooms, i, extra_edges))
	var result := {
		"rooms": [],
		"gates": {},
		"stair_spot": Vector3.ZERO,
		"biome_name": biome["name"],
		"style_name": str(layout.get("style_name", "Dungeon")),
		"archetype": archetype,
	}
	for i in rooms.size():
		result["rooms"].append(_build_room(root, rooms, i, door_dirs[i], biome, rng, result, escape, cell_size))
	for i in rooms.size():
		var parent := int(rooms[i]["parent"])
		if parent < 0:
			continue
		result["gates"][Layout.edge_key(parent, i)] = _build_edge(root, rooms, parent, i, biome, rng, cell_size)
	for edge in extra_edges:
		var a := int(edge[0])
		var b := int(edge[1])
		result["gates"][Layout.edge_key(a, b)] = _build_edge(root, rooms, a, b, biome, rng, cell_size)
	return result

static func _build_room(root: Node3D, rooms: Array, index: int, doors: Array[Vector2i], biome: Dictionary, rng: RandomNumberGenerator, result: Dictionary, escape := false, cell_size := Layout.CELL) -> Dictionary:
	var room: Dictionary = rooms[index]
	var center := Layout.room_world_center(room, cell_size)
	var node := Node3D.new()
	node.name = "Room_%d" % index
	node.position = center
	root.add_child(node)

	var size: Vector2 = room["size"]
	var half := size * 0.5
	var door_points: Array[Vector3] = []
	for dir in doors:
		if dir.x != 0:
			door_points.append(Vector3(float(dir.x) * (half.x + 0.2), 0.0, 0.0))
		else:
			door_points.append(Vector3(0.0, 0.0, float(dir.y) * (half.y + 0.2)))

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	node.add_child(floor_body)
	_add_solid_box(floor_body, Vector3(0.0, -0.15, 0.0), Vector3(size.x + 1.2, 0.3, size.y + 1.2), _mat(biome["floor"], 0.95))

	var record := {
		"index": index,
		"type": room["type"],
		"node": node,
		"center": center,
		"doors": doors,
		"door_points": door_points,
		"blocked_points": [] as Array[Vector3],
		"half": half,
	}
	record["blocked_points"].append_array(door_points)

	var walls := StaticBody3D.new()
	walls.name = "Walls"
	node.add_child(walls)
	var wall_material := _mat(biome["wall"], 0.92)
	var wall_length_x := size.x + 1.2
	var wall_length_z := size.y + 1.2
	for dir in Layout.DIRS:
		var axis_x := dir.x != 0
		var plane_offset := (half.x if axis_x else half.y) + WALL_THICKNESS * 0.5
		var wall_length := wall_length_z if axis_x else wall_length_x
		var wall_center := Vector3(
			float(dir.x) * plane_offset,
			WALL_HEIGHT * 0.5,
			float(dir.y) * plane_offset
		)
		var wall_size := Vector3(WALL_THICKNESS, WALL_HEIGHT, wall_length) if axis_x else Vector3(wall_length, WALL_HEIGHT, WALL_THICKNESS)
		if not doors.has(dir):
			_add_solid_box(walls, wall_center, wall_size, wall_material)
			continue
		var seg_length := wall_length * 0.5 - Layout.DOOR_WIDTH * 0.5
		var seg_size := Vector3(WALL_THICKNESS, WALL_HEIGHT, seg_length) if axis_x else Vector3(seg_length, WALL_HEIGHT, WALL_THICKNESS)
		var perp_axis := Vector3(0.0, 0.0, 1.0) if axis_x else Vector3(1.0, 0.0, 0.0)
		for side in [-1, 1]:
			_add_solid_box(walls, wall_center + perp_axis * (Layout.DOOR_WIDTH * 0.5 + seg_length * 0.5) * float(side), seg_size, wall_material)
		_add_solid_box(
			walls,
			Vector3(wall_center.x, DOOR_TOP + (WALL_HEIGHT - DOOR_TOP) * 0.5, wall_center.z),
			Vector3(WALL_THICKNESS, WALL_HEIGHT - DOOR_TOP, Layout.DOOR_WIDTH) if axis_x else Vector3(Layout.DOOR_WIDTH, WALL_HEIGHT - DOOR_TOP, WALL_THICKNESS),
			wall_material
		)

	# Every opening gets a framed threshold and a pair of guttering sconces so
	# the way onward is legible from across a dark hall.
	for dir in doors:
		_build_doorway(node, dir, half, biome)

	var pillar_material := _mat(biome["pillar"], 0.9)
	for sign_x in [-1, 1]:
		for sign_z in [-1, 1]:
			var pillar_center := Vector3(sign_x * (half.x - 1.4), (WALL_HEIGHT - 0.3) * 0.5, sign_z * (half.y - 1.4))
			var pillar := _add_mesh_cylinder(walls, pillar_center, 0.5, WALL_HEIGHT - 0.3, pillar_material)
			pillar.rotation.y = rng.randf() * TAU
			var pillar_shape := CylinderShape3D.new()
			pillar_shape.radius = 0.5
			pillar_shape.height = WALL_HEIGHT - 0.3
			var pillar_collision := CollisionShape3D.new()
			pillar_collision.shape = pillar_shape
			pillar_collision.position = pillar_center
			walls.add_child(pillar_collision)
			record["blocked_points"].append(Vector3(pillar_center.x, 0.0, pillar_center.z))

	var brazier_count := 2 if escape else (4 if room["type"] == "boss" else rng.randi_range(2, 3))
	for i in brazier_count:
		var dir: Vector2i = Layout.DIRS[rng.randi_range(0, Layout.DIRS.size() - 1)]
		var along := rng.randf_range(-1.0, 1.0)
		if doors.has(dir) and absf(along) < 0.45:
			continue
		var offset := Vector3.ZERO
		if dir.x != 0:
			offset = Vector3(dir.x * (half.x - 1.15), 0.0, along * (half.y - 2.2))
		else:
			offset = Vector3(along * (half.x - 2.2), 0.0, dir.y * (half.y - 1.15))
		_build_brazier(node, offset, biome)

	var rock_material := _mat(Color(biome["pillar"]).darkened(0.12), 1.0)
	var rubble_count := 0 if escape else rng.randi_range(1, 3)
	for i in rubble_count:
		var spot := _random_inner_point(half, door_points, record["blocked_points"], 3.4, rng, 12)
		if spot == Vector3.ZERO:
			continue
		_build_rock(node, spot, rock_material, rng)

	# A restrained dressing layer: enough character to read as a place, sparse
	# enough that every doorway and gate lane stays legible and walkable.
	_dress_room(node, record, half, door_points, doors, biome, rng, escape)

	# Lit floor studs point toward the way deeper in. Trap chambers already
	# carry their own warning chevrons, so they are left alone.
	var deeper_dir := Vector2i.ZERO
	if not room["children"].is_empty():
		var child: Dictionary = rooms[int(room["children"][0])]
		var step: Vector2i = child["cell"] - room["cell"]
		deeper_dir = Vector2i(signi(step.x), signi(step.y))
	elif int(room["parent"]) >= 0:
		var parent_room: Dictionary = rooms[int(room["parent"])]
		var step: Vector2i = room["cell"] - parent_room["cell"]
		deeper_dir = Vector2i(signi(step.x), signi(step.y))
	if room["type"] != "trap":
		_dress_route_marker(node, deeper_dir, half, biome)

	match room["type"]:
		"entrance":
			for k in 4:
				var angle := float(k) * TAU / 4.0
				var stone := _add_mesh_prism(node, Vector3(cos(angle) * 2.4, 0.24, sin(angle) * 2.4), _mat(biome["accent"], 0.85))
				stone.rotation.y = -angle
			_build_entrance_gate(node, biome)
		"treasure":
			_build_treasure(node, biome)
			if not escape:
				_build_treasure_dressing(node, half, biome, rng, doors)
		"trap":
			_build_trap_room_dressing(node, half, biome, rng)
		"boss":
			if escape:
				_build_exit_chamber(node, biome)
			else:
				_build_boss_dais(node, biome)
				var boss_parent := int(room["parent"])
				var exit_dir := Vector2i.ZERO
				if boss_parent >= 0:
					var outward: Vector2i = room["cell"] - rooms[boss_parent]["cell"]
					exit_dir = Vector2i(signi(outward.x), signi(outward.y))
				_build_boss_tomb(node, half, biome, rng, doors, exit_dir)
			var away := Vector3(0.0, 0.0, 1.0)
			var parent := int(room["parent"])
			if parent >= 0:
				var boss_dir: Vector2i = room["cell"] - rooms[parent]["cell"]
				away = Vector3(float(boss_dir.x), 0.0, float(boss_dir.y)).normalized() * -1.0
			var stair_reach := half.x if absf(away.x) > 0.5 else half.y
			result["stair_spot"] = center + away * (stair_reach - 4.2) + Vector3(0.0, 0.55, 0.0)

	var zone := Area3D.new()
	zone.name = "Zone"
	zone.position = Vector3(0.0, 1.6, 0.0)
	node.add_child(zone)
	var zone_shape := BoxShape3D.new()
	zone_shape.size = Vector3(size.x - 3.0, 3.4, size.y - 3.0)
	var zone_collision := CollisionShape3D.new()
	zone_collision.shape = zone_shape
	zone.add_child(zone_collision)
	record["zone"] = zone

	# Escape-stage trap chambers use a far-side trigger instead of enemies:
	# cross the room to the next doorway to prove you survived the gauntlet.
	if room["type"] == "trap":
		var trigger_dir := Vector2i.ZERO
		if not room["children"].is_empty():
			trigger_dir = rooms[int(room["children"][0])]["cell"] - room["cell"]
		elif int(room["parent"]) >= 0:
			# A dead-end trap chamber proves itself at the far wall instead.
			var inward: Vector2i = room["cell"] - rooms[int(room["parent"])]["cell"]
			trigger_dir = Vector2i(signi(inward.x), signi(inward.y))
		if trigger_dir != Vector2i.ZERO:
			var trigger := Area3D.new()
			trigger.name = "TrapExit"
			var along_x := trigger_dir.x != 0
			trigger.position = Vector3(
				float(trigger_dir.x) * (half.x - 1.7),
				1.4,
				float(trigger_dir.y) * (half.y - 1.7)
			)
			var trigger_shape := BoxShape3D.new()
			trigger_shape.size = Vector3(2.0, 3.0, 3.2) if along_x else Vector3(3.2, 3.0, 2.0)
			var trigger_collision := CollisionShape3D.new()
			trigger_collision.shape = trigger_shape
			trigger.add_child(trigger_collision)
			node.add_child(trigger)
			record["exit_zone"] = trigger
	return record

## ---------------------------------------------------------------------------
## Room dressing: the details that turn a box of walls into a crypt. Each biome
## favors its own stains — moss creeps, ember cracks glow, frost sheens — and
## every room gets bones, webs, chains and cast-off clutter to litter the floor.
## ---------------------------------------------------------------------------

static func _dress_room(node: Node3D, record: Dictionary, half: Vector2, door_points: Array[Vector3], doors: Array[Vector2i], biome: Dictionary, rng: RandomNumberGenerator, escape := false) -> void:
	# Wall stains and cracks: a few thin dark panels, kept off the doorways.
	var crack_material := _mat(biome["crack"], 1.0)
	var stain_material := _mat(Color(biome["crack"]).darkened(0.15), 1.0)
	for i in (1 if escape else 3):
		var dir: Vector2i = Layout.DIRS[rng.randi_range(0, 3)]
		var along := rng.randf_range(-1.0, 1.0)
		if doors.has(dir) and absf(along) < 0.55:
			continue
		var offset: Vector3
		var size: Vector3
		if dir.x != 0:
			offset = Vector3(dir.x * (half.x - 0.02), rng.randf_range(0.4, 2.6), along * (half.y - 1.6))
			size = Vector3(0.05, rng.randf_range(0.7, 1.9), rng.randf_range(0.16, 0.34))
		else:
			offset = Vector3(along * (half.x - 1.6), rng.randf_range(0.4, 2.6), dir.y * (half.y - 0.02))
			size = Vector3(rng.randf_range(0.16, 0.34), rng.randf_range(0.7, 1.9), 0.05)
		_add_mesh_box(node, offset, size, crack_material if rng.randf() < 0.6 else stain_material)

	# Biome wefts hugging the wall base — moss, ember fissures or frost.
	var weft_material := _mat(biome["weft"], 0.9, 0.0, float(biome["weft_glow"]))
	for i in (1 if escape else 2):
		var dir: Vector2i = Layout.DIRS[rng.randi_range(0, 3)]
		var along := rng.randf_range(-0.8, 0.8)
		if doors.has(dir) and absf(along) < 0.55:
			continue
		var offset: Vector3
		var size: Vector3
		if dir.x != 0:
			offset = Vector3(dir.x * (half.x - rng.randf_range(0.3, 0.9)), 0.04, along * (half.y - 1.4))
			size = Vector3(rng.randf_range(0.5, 1.1), 0.03, rng.randf_range(0.8, 1.8))
		else:
			offset = Vector3(along * (half.x - 1.4), 0.04, dir.y * (half.y - rng.randf_range(0.3, 0.9)))
			size = Vector3(rng.randf_range(0.8, 1.8), 0.03, rng.randf_range(0.5, 1.1))
		var weft := _add_mesh_box(node, offset, size, weft_material)
		weft.rotation.y = rng.randf_range(-0.4, 0.4)

	# One small bone pile at most, and never in a walking lane.
	var bone_material := _mat(biome["bone"], 0.95)
	for i in (0 if escape else rng.randi_range(0, 1)):
		var spot := _random_inner_point(half, door_points, record["blocked_points"], 3.2, rng, 10)
		if spot == Vector3.ZERO:
			continue
		_build_bone_pile(node, spot, bone_material, rng)
		record["blocked_points"].append(Vector3(spot.x, 0.0, spot.z))

	# Chains high on the walls, out of the way of movement.
	var chain_material := _mat(Color(0.16, 0.16, 0.17), 0.4, 0.8)
	for i in (0 if escape else rng.randi_range(0, 2)):
		var dir: Vector2i = Layout.DIRS[rng.randi_range(0, 3)]
		var along := rng.randf_range(-0.85, 0.85)
		if doors.has(dir) and absf(along) < 0.55:
			continue
		var anchor: Vector3
		if dir.x != 0:
			anchor = Vector3(dir.x * (half.x - 0.15), WALL_HEIGHT - 0.15, along * (half.y - 1.4))
		else:
			anchor = Vector3(along * (half.x - 1.4), WALL_HEIGHT - 0.15, dir.y * (half.y - 0.15))
		_build_chain(node, anchor, chain_material, rng)

	# A single cobweb tucked in a corner.
	var web_material := StandardMaterial3D.new()
	web_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web_material.albedo_color = Color(0.85, 0.85, 0.85, 0.14)
	web_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	web_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in (0 if escape else 1):
		var corner_sign_x := -1.0 if rng.randf() < 0.5 else 1.0
		var corner_sign_z := -1.0 if rng.randf() < 0.5 else 1.0
		var web_offset := Vector3(corner_sign_x * (half.x - 1.5), WALL_HEIGHT - 0.7, corner_sign_z * (half.y - 1.5))
		var web := _add_mesh_box(node, web_offset, Vector3(1.4, 0.02, 1.4), web_material)
		web.rotation.y = 0.785
		var web_side := _add_mesh_box(node, web_offset + Vector3(corner_sign_x * 0.55, 0.0, corner_sign_z * -0.55), Vector3(0.02, 1.2, 1.1), web_material)
		web_side.rotation.y = 0.785

	# One glossy puddle at most, flat on the floor and harmless.
	var puddle_material := StandardMaterial3D.new()
	puddle_material.albedo_color = biome["puddle"]
	puddle_material.roughness = 0.08
	puddle_material.metallic = 0.3
	for i in (0 if escape else rng.randi_range(0, 1)):
		var spot := _random_inner_point(half, door_points, record["blocked_points"], 3.0, rng, 8)
		if spot == Vector3.ZERO:
			continue
		var pool := _add_mesh_cylinder(node, spot + Vector3(0.0, 0.035, 0.0), rng.randf_range(0.5, 0.95), 0.02, puddle_material)
		pool.scale.x = rng.randf_range(1.0, 1.6)

	# Crates and barrels only against walls away from any door lane.
	var clutter_material := _mat(biome["wood"], 0.95)
	var band_material := _mat(Color(0.2, 0.16, 0.12), 0.5, 0.5)
	for i in (0 if escape else rng.randi_range(0, 2)):
		var dir: Vector2i = Layout.DIRS[rng.randi_range(0, 3)]
		var along := rng.randf_range(-0.75, 0.75)
		if doors.has(dir) and absf(along) < 0.6:
			continue
		var spot: Vector3
		if dir.x != 0:
			spot = Vector3(dir.x * (half.x - 1.05), 0.0, along * (half.y - 2.0))
		else:
			spot = Vector3(along * (half.x - 2.0), 0.0, dir.y * (half.y - 1.05))
		if _in_door_lane(door_points, spot, 2.4):
			continue
		if rng.randf() < 0.5:
			_build_crate(node, spot, clutter_material, band_material, rng)
		else:
			_build_barrel(node, spot, clutter_material, band_material, rng)
		record["blocked_points"].append(Vector3(spot.x, 0.0, spot.z))

	# A toppled pillar stump, if there is room well clear of every doorway.
	var stump_material := _mat(biome["pillar"], 0.92)
	for i in (0 if escape else rng.randi_range(0, 1)):
		var spot := _random_inner_point(half, door_points, record["blocked_points"], 3.4, rng, 10)
		if spot == Vector3.ZERO:
			continue
		_build_pillar_stump(node, spot, stump_material, rng)
		record["blocked_points"].append(Vector3(spot.x, 0.0, spot.z))

	# Votive candles and a small wall shrine: signs that someone once tended
	# these halls. They sit high on the stone, clear of every walking lane.
	for i in (0 if escape else rng.randi_range(1, 2)):
		var candle_dir: Vector2i = Layout.DIRS[rng.randi_range(0, 3)]
		var candle_along := rng.randf_range(-0.72, 0.72)
		if doors.has(candle_dir) and absf(candle_along) < 0.62:
			continue
		_build_wall_candles(node, candle_dir, candle_along, half, biome, rng)

	if not escape and String(record["type"]) != "trap" and rng.randf() < 0.7:
		_build_wall_shrine(node, half, doors, biome, rng)

	# A sarcophagus or a huddle of burial urns gives combat halls a reason to
	# exist. Both are placed far from door lanes and recorded so monster, rune,
	# trap and stair placement keeps its distance.
	if not escape and String(record["type"]) == "combat":
		if rng.randf() < 0.55:
			var crypt_spot := _random_inner_point(half, door_points, record["blocked_points"], 4.2, rng, 14)
			if crypt_spot != Vector3.ZERO:
				var crypt_yaw := 0.0 if rng.randf() < 0.5 else PI * 0.5
				_build_sarcophagus(node, crypt_spot, crypt_yaw, biome, rng)
				record["blocked_points"].append(Vector3(crypt_spot.x, 0.0, crypt_spot.z))
		else:
			var urn_spot := _random_inner_point(half, door_points, record["blocked_points"], 3.2, rng, 10)
			if urn_spot != Vector3.ZERO:
				_build_urn_cluster(node, urn_spot, biome, rng)
				record["blocked_points"].append(Vector3(urn_spot.x, 0.0, urn_spot.z))

static func _build_doorway(node: Node3D, dir: Vector2i, half: Vector2, biome: Dictionary) -> void:
	var axis_x := dir.x != 0
	var along := half.x if axis_x else half.y
	var stone := _mat(biome["pillar"], 0.92)
	var stone_dark := _mat(Color(biome["pillar"]).darkened(0.16), 1.0)
	var seam_material := _mat(biome["accent"], 0.55, 0.0, 0.55)
	var metal := _mat(biome["metal"], 0.5, 0.65)
	var torch := _mat(biome["torch"], 0.3, 0.0, 2.1)
	var inward := Vector3(-dir.x, 0.0, -dir.y)
	var perp := Vector3(0.0, 0.0, 1.0) if axis_x else Vector3(1.0, 0.0, 0.0)
	var face := Vector3(dir.x * (along - 0.3), 0.0, dir.y * (along - 0.3))

	# Worn threshold slab and a warm seam across it.
	var slab_size := Vector3(1.0, 0.07, Layout.DOOR_WIDTH + 0.8) if axis_x else Vector3(Layout.DOOR_WIDTH + 0.8, 0.07, 1.0)
	_add_mesh_box(node, face + Vector3(0.0, 0.035, 0.0), slab_size, stone_dark)
	var seam_size := Vector3(0.1, 0.045, Layout.DOOR_WIDTH - 0.4) if axis_x else Vector3(Layout.DOOR_WIDTH - 0.4, 0.045, 0.1)
	_add_mesh_box(node, face + Vector3(0.0, 0.075, 0.0), seam_size, seam_material)

	for side in [-1, 1]:
		var offset := perp * (Layout.DOOR_WIDTH * 0.5 + 0.44) * float(side)
		# Carved jamb band framing the opening.
		var band_size := Vector3(0.2, DOOR_TOP, 0.18) if axis_x else Vector3(0.18, DOOR_TOP, 0.2)
		_add_mesh_box(node, face + offset + Vector3(0.0, DOOR_TOP * 0.5, 0.0), band_size, stone)
		var cap_size := Vector3(0.36, 0.22, 0.34) if axis_x else Vector3(0.34, 0.22, 0.36)
		_add_mesh_box(node, face + offset + Vector3(0.0, DOOR_TOP + 0.11, 0.0), cap_size, stone_dark)
		# Iron bracket and votive flame, high enough to clear the hero.
		var wall_spot := face + offset
		var bracket_size := Vector3(0.28, 0.08, 0.08) if axis_x else Vector3(0.08, 0.08, 0.28)
		_add_mesh_box(node, wall_spot + inward * 0.14 + Vector3(0.0, 2.5, 0.0), bracket_size, metal)
		var cup := _add_mesh_cylinder(node, wall_spot + inward * 0.3 + Vector3(0.0, 2.52, 0.0), 0.09, 0.14, metal)
		cup.rotation.x = PI * 0.5
		var flame := _add_mesh_sphere(node, wall_spot + inward * 0.34 + Vector3(0.0, 2.7, 0.0), torch)
		flame.scale = Vector3(0.55, 0.9, 0.55)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# A glowing keystone glyph above the opening.
	var glyph := _add_mesh_box(node, face + inward * 0.02 + Vector3(0.0, DOOR_TOP + 0.28, 0.0), Vector3(0.5, 0.16, 0.06) if axis_x else Vector3(0.06, 0.16, 0.5), seam_material)
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A short run of lit floor studs leading toward the deeper doorway. Purely a
## decal layer: no colliders, no light cost, and it fades before the doorway.
static func _dress_route_marker(node: Node3D, dir: Vector2i, half: Vector2, biome: Dictionary) -> void:
	if dir == Vector2i.ZERO:
		return
	var glow := _mat(biome["accent"], 0.5, 0.0, 0.85)
	var dim := _mat(Color(biome["accent"]).darkened(0.18), 0.6, 0.0, 0.45)
	var dir3 := Vector3(float(dir.x), 0.0, float(dir.y)).normalized()
	var reach := half.x if dir.x != 0 else half.y
	for i in 3:
		var distance := reach - 2.25 - 0.8 * float(i)
		if distance < 1.4:
			continue
		var plate := _add_mesh_box(node, dir3 * distance + Vector3(0.0, 0.045, 0.0), Vector3(0.34, 0.025, 0.34), glow if i == 0 else dim)
		plate.rotation.y = atan2(dir3.x, dir3.z)
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i == 0:
			var core := _add_mesh_box(node, dir3 * distance + Vector3(0.0, 0.06, 0.0), Vector3(0.12, 0.02, 0.12), _mat(Color(0.95, 0.8, 0.45), 0.4, 0.0, 1.2))
			core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A shelf of votive candles against one wall. Candles are emissive only so a
## room full of them never turns into a room full of omni lights.
static func _build_wall_candles(node: Node3D, dir: Vector2i, along: float, half: Vector2, biome: Dictionary, rng: RandomNumberGenerator) -> void:
	var axis_x := dir.x != 0
	var perp := Vector3(0.0, 0.0, 1.0) if axis_x else Vector3(1.0, 0.0, 0.0)
	var extent := (half.y if axis_x else half.x) - 1.6
	var wall := Vector3(dir.x * (half.x - 0.1), 0.0, dir.y * (half.y - 0.1)) + perp * along * extent
	var inward := Vector3(-dir.x, 0.0, -dir.y) * 0.18
	var shelf_size := Vector3(0.3, 0.07, 0.72) if axis_x else Vector3(0.72, 0.07, 0.3)
	_add_mesh_box(node, wall + inward + Vector3(0.0, 1.92, 0.0), shelf_size, _mat(Color(0.2, 0.19, 0.17), 0.95))
	var wax := _mat(Color(0.86, 0.81, 0.68), 0.85)
	var flame_material := _mat(biome["torch"], 0.3, 0.0, 2.1)
	for i in 3:
		var offset := perp * (-0.22 + 0.22 * float(i)) + inward
		var height := rng.randf_range(0.18, 0.34)
		_add_mesh_cylinder(node, wall + offset + Vector3(0.0, 1.96 + height * 0.5, 0.0), 0.035, height, wax)
		var flame := _add_mesh_sphere(node, wall + offset + Vector3(0.0, 1.98 + height, 0.0), flame_material)
		flame.scale = Vector3(0.45, 0.85, 0.45)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drip := _add_mesh_box(node, wall + inward + Vector3(0.0, 1.9, 0.0), Vector3(0.18, 0.03, 0.3) if axis_x else Vector3(0.3, 0.03, 0.18), wax)
	drip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A carved wall niche with a votive bowl. Picks a wall with no doorway so it
## never sits behind a gate or in a walking lane.
static func _build_wall_shrine(node: Node3D, half: Vector2, doors: Array[Vector2i], biome: Dictionary, rng: RandomNumberGenerator) -> void:
	var sides: Array[Vector2i] = []
	for dir in Layout.DIRS:
		if not doors.has(dir):
			sides.append(dir)
	if sides.is_empty():
		return
	var dir: Vector2i = sides[rng.randi_range(0, sides.size() - 1)]
	var axis_x := dir.x != 0
	var perp := Vector3(0.0, 0.0, 1.0) if axis_x else Vector3(1.0, 0.0, 0.0)
	var extent := (half.y if axis_x else half.x) - 1.8
	var along := rng.randf_range(-0.5, 0.5) * extent
	var wall := Vector3(dir.x * (half.x - 0.08), 0.0, dir.y * (half.y - 0.08)) + perp * along
	var inward := Vector3(-dir.x, 0.0, -dir.y) * 0.16
	var stone := _mat(biome["pillar"], 0.92)
	var stone_dark := _mat(Color(biome["pillar"]).darkened(0.2), 1.0)
	var accent := _mat(biome["accent"], 0.55, 0.0, 0.7)
	# Recessed relief panel.
	_add_mesh_box(node, wall + inward + Vector3(0.0, 2.15, 0.0), Vector3(0.1, 0.9, 1.0) if axis_x else Vector3(1.0, 0.9, 0.1), stone_dark)
	_add_mesh_box(node, wall + inward * 1.35 + Vector3(0.0, 2.15, 0.0), Vector3(0.06, 0.62, 0.68) if axis_x else Vector3(0.68, 0.62, 0.06), accent)
	# Shelf and votive bowl.
	_add_mesh_box(node, wall + inward + Vector3(0.0, 1.5, 0.0), Vector3(0.34, 0.08, 1.15) if axis_x else Vector3(1.15, 0.08, 0.34), stone)
	var bowl := _add_mesh_cylinder(node, wall + inward * 1.3 + Vector3(0.0, 1.64, 0.0), 0.2, 0.1, accent)
	bowl.scale = Vector3(1.0, 1.0, 1.0)
	var flame_material := _mat(biome["torch"], 0.3, 0.0, 2.0)
	for side in [-1, 1]:
		var candle := wall + inward * 1.2 + perp * 0.38 * float(side) + Vector3(0.0, 1.62, 0.0)
		_add_mesh_cylinder(node, candle, 0.035, 0.22, _mat(Color(0.86, 0.81, 0.68), 0.85))
		var flame := _add_mesh_sphere(node, candle + Vector3(0.0, 0.17, 0.0), flame_material)
		flame.scale = Vector3(0.45, 0.8, 0.45)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A stone coffin with a carved lid and a single guttering candle at its head.
## Collidable, and recorded in blocked_points by the caller.
static func _build_sarcophagus(node: Node3D, spot: Vector3, yaw: float, biome: Dictionary, rng: RandomNumberGenerator) -> void:
	var stone := _mat(biome["pillar"], 0.9)
	var stone_dark := _mat(Color(biome["pillar"]).darkened(0.18), 1.0)
	var trim := _mat(biome["accent"], 0.55, 0.0, 0.4)
	var body := StaticBody3D.new()
	node.add_child(body)
	body.position = spot
	body.rotation.y = yaw + rng.randf_range(-0.08, 0.08)
	_add_solid_box(body, Vector3(0.0, 0.42, 0.0), Vector3(1.18, 0.84, 2.15), stone)
	var lid := _add_mesh_box(body, Vector3(0.0, 0.92, 0.0), Vector3(1.3, 0.18, 2.28), stone_dark)
	lid.rotation.z = rng.randf_range(-0.04, 0.04)
	_add_mesh_box(body, Vector3(0.0, 0.84, 0.0), Vector3(1.32, 0.05, 0.16), trim)
	# A worn effigy on the lid.
	_add_mesh_box(body, Vector3(0.0, 1.02, -0.25), Vector3(0.34, 0.08, 1.4), stone)
	_add_mesh_sphere(body, Vector3(0.0, 1.1, 0.62), stone).scale = Vector3(0.36, 0.24, 0.34)
	# Candle at the head end.
	var head := body.position + body.basis * Vector3(0.0, 0.0, 1.16)
	_add_mesh_cylinder(node, head + Vector3(0.0, 1.08, 0.0), 0.05, 0.24, _mat(Color(0.86, 0.81, 0.68), 0.85))
	var flame := _add_mesh_sphere(node, head + Vector3(0.0, 1.27, 0.0), _mat(biome["torch"], 0.3, 0.0, 2.0))
	flame.scale = Vector3(0.5, 0.9, 0.5)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## A huddle of burial urns on a low plinth. Collidable; recorded by the caller.
static func _build_urn_cluster(node: Node3D, spot: Vector3, biome: Dictionary, rng: RandomNumberGenerator) -> void:
	var stone := _mat(biome["pillar"], 0.94)
	var clay := _mat(Color(0.4, 0.3, 0.2), 0.95)
	var clay_dark := _mat(Color(0.3, 0.22, 0.15), 1.0)
	var body := StaticBody3D.new()
	node.add_child(body)
	body.position = spot
	body.rotation.y = rng.randf() * TAU
	_add_mesh_box(body, Vector3(0.0, 0.08, 0.0), Vector3(1.5, 0.16, 1.3), stone)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 1.0, 1.3)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.5, 0.0)
	body.add_child(collision)
	for i in 3:
		var angle := float(i) * TAU / 3.0 + rng.randf_range(-0.2, 0.2)
		var offset := Vector3(cos(angle) * 0.32, 0.0, sin(angle) * 0.32)
		var height := rng.randf_range(0.5, 0.8)
		var urn := _add_mesh_cylinder(body, Vector3(offset.x, 0.16 + height * 0.5, offset.z), 0.19, height, clay if i != 1 else clay_dark)
		urn.scale = Vector3(1.0, 1.0, 0.86)
		_add_mesh_cylinder(body, Vector3(offset.x, 0.16 + height + 0.05, offset.z), 0.1, 0.12, clay_dark)
		if i == 0:
			var lip := _add_mesh_cylinder(body, Vector3(offset.x, 0.16 + height + 0.12, offset.z), 0.13, 0.05, clay_dark)
			lip.scale = Vector3(1.0, 1.0, 0.86)

static func _build_bone_pile(parent: Node3D, spot: Vector3, material: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.position = spot
	pivot.rotation.y = rng.randf() * TAU
	for i in rng.randi_range(3, 5):
		var angle := rng.randf() * TAU
		var reach := rng.randf_range(0.1, 0.55)
		var long_bone := _add_mesh_box(pivot, Vector3(cos(angle) * reach, 0.07, sin(angle) * reach), Vector3(0.07, 0.07, rng.randf_range(0.5, 0.95)), material)
		long_bone.rotation.y = rng.randf() * TAU
		long_bone.rotation.z = rng.randf_range(-0.3, 0.3)
	for i in rng.randi_range(1, 2):
		var angle := rng.randf() * TAU
		var skull := _add_mesh_sphere(pivot, Vector3(cos(angle) * 0.35, 0.14, sin(angle) * 0.35), material)
		skull.scale = Vector3(0.75, 0.6, 0.85)
		var jaw := _add_mesh_box(pivot, Vector3(cos(angle) * 0.35, 0.05, sin(angle) * 0.35 + 0.12), Vector3(0.16, 0.05, 0.14), material)
		jaw.rotation.y = angle
	var rib_material := _mat(Color(material.albedo_color).darkened(0.12), 0.95)
	for i in 3:
		var rib := _add_mesh_box(pivot, Vector3(rng.randf_range(-0.2, 0.2), 0.05, -0.25 + 0.12 * float(i)), Vector3(0.4, 0.04, 0.05), rib_material)
		rib.rotation.z = 0.12

static func _build_chain(parent: Node3D, anchor: Vector3, material: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var link_count := rng.randi_range(3, 5)
	for i in link_count:
		var link := _add_mesh_cylinder(parent, anchor + Vector3(rng.randf_range(-0.03, 0.03), -0.3 - 0.32 * float(i), rng.randf_range(-0.03, 0.03)), 0.05, 0.24, material)
		link.rotation.z = 1.57
		link.rotation.y = 0.785 if i % 2 == 0 else 0.0
	if rng.randf() < 0.5:
		var hook := _add_mesh_sphere(parent, anchor + Vector3(0.0, -0.3 - 0.32 * float(link_count), 0.0), material)
		hook.scale = Vector3(0.5, 0.4, 0.5)

static func _build_crate(parent: Node3D, spot: Vector3, wood: StandardMaterial3D, band: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = spot
	body.rotation.y = rng.randf() * TAU
	var size := Vector3(0.9, 0.8, 0.9) if rng.randf() < 0.7 else Vector3(0.7, 0.6, 0.7)
	_add_solid_box(body, Vector3(0.0, size.y * 0.5, 0.0), size, wood)
	for side in [-1, 1]:
		_add_mesh_box(body, Vector3(0.0, size.y * 0.5, size.z * 0.5 * float(side)), Vector3(size.x + 0.04, 0.09, 0.03), band)
		_add_mesh_box(body, Vector3(size.x * 0.5 * float(side), size.y * 0.5, 0.0), Vector3(0.03, 0.09, size.z + 0.04), band)

static func _build_barrel(parent: Node3D, spot: Vector3, wood: StandardMaterial3D, band: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = spot
	body.rotation.y = rng.randf() * TAU
	var barrel := _add_mesh_cylinder(body, Vector3(0.0, 0.45, 0.0), 0.32, 0.9, wood)
	barrel.rotation.z = 0.0
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.32
	shape.height = 0.9
	collision.shape = shape
	collision.position = Vector3(0.0, 0.45, 0.0)
	body.add_child(collision)
	for i in 2:
		_add_mesh_cylinder(body, Vector3(0.0, 0.24 + 0.42 * float(i), 0.0), 0.335, 0.08, band)
	if rng.randf() < 0.4:
		# One barrel has given up and lies spilling on its side.
		var fallen := _add_mesh_cylinder(parent, spot + Vector3(rng.randf_range(0.5, 0.9), 0.3, rng.randf_range(-0.2, 0.2)), 0.28, 0.8, wood)
		fallen.rotation.x = 1.57
		fallen.rotation.y = rng.randf() * TAU

static func _build_pillar_stump(parent: Node3D, spot: Vector3, material: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = spot
	body.rotation.y = rng.randf() * TAU
	var stump := _add_mesh_cylinder(body, Vector3(0.0, 0.35, 0.0), 0.42, 0.7, material)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 0.7
	collision.shape = shape
	collision.position = Vector3(0.0, 0.35, 0.0)
	body.add_child(collision)
	# Broken shards around the stump where the pillar fell.
	var shard_material := _mat(Color(material.albedo_color).darkened(0.1), 1.0)
	for i in rng.randi_range(2, 4):
		var angle := rng.randf() * TAU
		var shard := _add_mesh_prism(body, Vector3(cos(angle) * 0.75, 0.14, sin(angle) * 0.75), shard_material)
		shard.rotation.y = rng.randf() * TAU
		shard.rotation.z = rng.randf_range(-0.5, 0.5)

## ---------------------------------------------------------------------------
## Corridor dressing: sconces to light the passage, cracks and scuffs along the
## floor, and the odd fallen stone — so the hallways feel walked and worn.
## ---------------------------------------------------------------------------

static func _dress_corridor(corridor: Node3D, mid: Vector3, length: float, axis_x: bool, biome: Dictionary, rng: RandomNumberGenerator) -> void:
	# Wall sconces halfway down each side, lighting the walk between rooms.
	var sconce_material := _mat(biome["metal"], 0.5, 0.6)
	var flame_material := _mat(biome["torch"], 0.3, 0.0, 2.0)
	var perp3 := Vector3(0.0, 0.0, 1.0) if axis_x else Vector3(1.0, 0.0, 0.0)
	for side in [-1, 1]:
		var along := mid + (Vector3(1.0, 0.0, 0.0) if axis_x else Vector3(0.0, 0.0, 1.0)) * rng.randf_range(-length * 0.2, length * 0.2)
		var wall_face := along + perp3 * float(side) * 1.58
		_add_mesh_cylinder(corridor, wall_face + Vector3(0.0, 2.0, 0.0), 0.06, 0.3, sconce_material)
		var cup := _add_mesh_cylinder(corridor, wall_face + Vector3(-perp3.x * 0.14 * float(side), 2.18, -perp3.z * 0.14 * float(side)), 0.12, 0.16, sconce_material)
		cup.rotation.z = 1.1 * float(side) if axis_x else 0.0
		cup.rotation.x = 0.0 if axis_x else 1.1 * float(side)
		var flame := _add_mesh_sphere(corridor, wall_face + Vector3(-perp3.x * 0.2 * float(side), 2.36, -perp3.z * 0.2 * float(side)), flame_material)
		flame.scale = Vector3(0.7, 1.1, 0.7)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = biome["torch"]
		light.light_energy = 0.75
		light.omni_range = 5.0
		light.position = wall_face + Vector3(-perp3.x * 0.5 * float(side), 2.4, -perp3.z * 0.5 * float(side))
		corridor.add_child(light)

	# A worn guide ring in the middle of the passage, and a warm seam at the
	# far end so the next opening reads from a distance.
	var accent := _mat(biome["accent"], 0.55, 0.0, 0.35)
	var guide := _add_mesh_cylinder(corridor, mid + Vector3(0.0, 0.02, 0.0), 0.62, 0.02, accent)
	guide.scale = Vector3(1.0, 1.0, 0.7) if axis_x else Vector3(0.7, 1.0, 1.0)
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Floor cracks and scuff marks down the passage.
	var crack_material := _mat(biome["crack"], 1.0)
	for i in 2:
		var along := rng.randf_range(-length * 0.45, length * 0.45)
		var offset: Vector3
		var crack: MeshInstance3D
		if axis_x:
			offset = mid + Vector3(along, 0.035, rng.randf_range(-1.3, 1.3))
			crack = _add_mesh_box(corridor, offset, Vector3(rng.randf_range(0.3, 0.7), 0.02, 0.1), crack_material)
		else:
			offset = mid + Vector3(rng.randf_range(-1.3, 1.3), 0.035, along)
			crack = _add_mesh_box(corridor, offset, Vector3(0.1, 0.02, rng.randf_range(0.3, 0.7)), crack_material)
		crack.rotation.y = rng.randf_range(-0.3, 0.3)

	# A single fallen stone, hugging the wall and never in the gate lane.
	# Corridor rubble is decorative only — no collider can snag the hero.
	var rubble_material := _mat(Color(biome["pillar"]).darkened(0.12), 1.0)
	for i in 1:
		var along := rng.randf_range(-length * 0.4, length * 0.4)
		if absf(along) < 2.2:
			continue
		var edge := 1.0 if rng.randf() < 0.5 else -1.0
		var spot: Vector3
		if axis_x:
			spot = mid + Vector3(along, 0.0, edge * 1.35)
		else:
			spot = mid + Vector3(edge * 1.35, 0.0, along)
		_build_rock(corridor, spot, rubble_material, rng, false)

static func _build_rock(parent: Node3D, local_spot: Vector3, material: StandardMaterial3D, rng: RandomNumberGenerator, collidable := true) -> void:
	var scale_value := rng.randf_range(0.5, 1.0)
	var node := Node3D.new()
	parent.add_child(node)
	var rock := _add_mesh_sphere(node, Vector3(0.0, 0.0, 0.0), material)
	rock.scale = Vector3(scale_value, scale_value * 0.6, scale_value * rng.randf_range(0.8, 1.2))
	rock.position = Vector3(0.0, scale_value * 0.35, 0.0)
	rock.rotation.y = rng.randf() * TAU
	if collidable:
		var body := StaticBody3D.new()
		node.add_child(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(scale_value * 0.9, scale_value * 0.6, scale_value * 0.9)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = rock.position
		body.add_child(collision)
	node.position = local_spot

static func _build_brazier(parent: Node3D, offset: Vector3, biome: Dictionary) -> void:
	var metal := _mat(biome["metal"], 0.5, 0.6)
	_add_mesh_cylinder(parent, offset + Vector3(0.0, 0.4, 0.0), 0.3, 0.8, metal)
	var flame := _add_mesh_sphere(parent, offset + Vector3(0.0, 0.92, 0.0), _mat(biome["torch"], 0.3, 0.0, 1.8))
	flame.scale = Vector3(0.9, 1.2, 0.9)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = biome["torch"]
	light.light_energy = 1.15
	light.omni_range = 7.0
	light.position = offset + Vector3(0.0, 1.7, 0.0)
	parent.add_child(light)

static func _build_treasure(node: Node3D, biome: Dictionary) -> void:
	var wood := _mat(Color(0.4, 0.28, 0.14), 0.9)
	var trim := _mat(biome["accent"], 0.4, 0.7)
	_add_solid_box(node, Vector3(0.0, 0.3, 0.3), Vector3(1.1, 0.6, 0.7), wood)
	_add_solid_box(node, Vector3(0.0, 0.68, 0.3), Vector3(1.2, 0.2, 0.8), trim)
	for i in 5:
		var coin := _add_mesh_sphere(node, Vector3(-0.3 + 0.15 * float(i), 0.16, -0.45), _mat(Color(0.9, 0.72, 0.3), 0.35, 0.9))
		coin.scale = Vector3(0.48, 0.2, 0.48)
	# A pair of candle stands flanking the chest make the cache read at a
	# distance, even before the player's own torch reaches it.
	var flame_material := _mat(biome["torch"], 0.3, 0.0, 2.0)
	for side in [-1, 1]:
		var stand := Vector3(1.35 * float(side), 0.0, 0.35)
		_add_mesh_cylinder(node, stand + Vector3(0.0, 0.55, 0.0), 0.05, 1.1, _mat(Color(0.22, 0.21, 0.19), 0.5, 0.6))
		_add_mesh_cylinder(node, stand + Vector3(0.0, 1.14, 0.0), 0.16, 0.06, _mat(biome["metal"], 0.5, 0.65))
		var flame := _add_mesh_sphere(node, stand + Vector3(0.0, 1.32, 0.0), flame_material)
		flame.scale = Vector3(0.55, 0.9, 0.55)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.4)
	light.light_energy = 0.9
	light.omni_range = 4.5
	light.position = Vector3(0.0, 1.2, 0.0)
	node.add_child(light)

static func _build_boss_dais(node: Node3D, biome: Dictionary) -> void:
	var stone := _mat(Color(biome["pillar"]).darkened(0.1), 0.9)
	var dais := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 3.0
	mesh.bottom_radius = 3.3
	mesh.height = 0.16
	mesh.radial_segments = 14
	mesh.rings = 2
	mesh.material = stone
	dais.mesh = mesh
	dais.position = Vector3(0.0, 0.08, 0.0)
	# Deliberately no collider: the dais is a floor inlay, not a wall the hero
	# has to fight. Gates, stairs and the warden all stay easy to reach.
	node.add_child(dais)
	# Four votive clusters on the diagonals ring the dais without touching the
	# approach lanes or the boss's own foot.
	var trim := _mat(biome["accent"], 0.55, 0.0, 0.6)
	var flame_material := _mat(biome["torch"], 0.3, 0.0, 2.1)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var spot := Vector3(2.55 * float(sx), 0.0, 2.55 * float(sz))
			_add_mesh_cylinder(node, spot + Vector3(0.0, 0.34, 0.0), 0.1, 0.68, _mat(Color(0.22, 0.21, 0.19), 0.5, 0.6))
			_add_mesh_cylinder(node, spot + Vector3(0.0, 0.7, 0.0), 0.18, 0.06, trim)
			var flame := _add_mesh_sphere(node, spot + Vector3(0.0, 0.9, 0.0), flame_material)
			flame.scale = Vector3(0.6, 1.0, 0.6)
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = biome["torch"]
	light.light_energy = 0.7
	light.omni_range = 9.0
	light.position = Vector3(0.0, 3.6, 0.0)
	node.add_child(light)

## The entrance room reads as a threshold: a carved arch framing the way in,
## torches on both posts, and a worn welcome-mat mosaic underfoot.
static func _build_entrance_gate(node: Node3D, biome: Dictionary) -> void:
	var stone := _mat(biome["pillar"], 0.92)
	var stone_dark := _mat(Color(biome["pillar"]).darkened(0.15), 1.0)
	var torch := _mat(biome["torch"], 0.3, 0.0, 1.8)
	for side in [-1, 1]:
		var post := _add_mesh_box(node, Vector3(2.3 * float(side), 1.6, 0.0), Vector3(0.7, 3.2, 0.7), stone)
		post.rotation.z = 0.02 * float(side)
		_add_mesh_box(node, Vector3(2.3 * float(side), 3.35, 0.0), Vector3(1.0, 0.3, 1.0), stone_dark)
		_add_mesh_cylinder(node, Vector3(2.3 * float(side), 1.05, 0.45), 0.08, 0.5, _mat(biome["metal"], 0.5, 0.6))
		var flame := _add_mesh_sphere(node, Vector3(2.3 * float(side), 1.45, 0.45), torch)
		flame.scale = Vector3(0.8, 1.2, 0.8)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = biome["torch"]
		light.light_energy = 0.85
		light.omni_range = 4.5
		light.position = Vector3(2.3 * float(side), 1.9, 0.5)
		node.add_child(light)
	var lintel := _add_mesh_box(node, Vector3(0.0, 3.55, 0.0), Vector3(5.6, 0.5, 0.7), stone)
	lintel.rotation.z = 0.02
	_add_mesh_prism(node, Vector3(0.0, 4.0, 0.0), stone_dark, Vector3(1.1, 0.7, 0.7))
	# A carved name-board so the threshold reads as a threshold, not a wall.
	var board := _add_mesh_box(node, Vector3(0.0, 3.58, 0.38), Vector3(3.2, 0.42, 0.08), stone_dark)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var title := Label3D.new()
	title.text = "THE UNDER-REACH"
	title.font_size = 44
	title.pixel_size = 0.0042
	title.outline_size = 14
	title.outline_modulate = Color(0.05, 0.04, 0.03, 1.0)
	title.modulate = Color(0.82, 0.74, 0.52, 1.0)
	title.position = Vector3(0.0, 3.58, 0.44)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.add_child(title)
	# Freestanding braziers flanking the arch light the approach.
	for side in [-1, 1]:
		var spot := Vector3(3.5 * float(side), 0.0, 0.5)
		_add_mesh_cylinder(node, spot + Vector3(0.0, 0.5, 0.0), 0.1, 1.0, _mat(biome["metal"], 0.5, 0.65))
		_add_mesh_cylinder(node, spot + Vector3(0.0, 1.04, 0.0), 0.28, 0.18, _mat(biome["metal"], 0.5, 0.65))
		var bowl_flame := _add_mesh_sphere(node, spot + Vector3(0.0, 1.22, 0.0), torch)
		bowl_flame.scale = Vector3(0.9, 1.3, 0.9)
		bowl_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A worn mosaic ring on the floor at the threshold.
	var mosaic := _add_mesh_cylinder(node, Vector3(0.0, 0.045, 0.0), 1.9, 0.03, _mat(biome["accent"], 0.9))
	mosaic.scale.y = 1.0
	for i in 4:
		var angle := float(i) * TAU / 4.0
		var rune_plate := _add_mesh_box(node, Vector3(cos(angle) * 1.2, 0.07, sin(angle) * 1.2), Vector3(0.5, 0.03, 0.16), _mat(biome["accent"], 0.85))
		rune_plate.rotation.y = -angle

## Treasure rooms read as somebody's cache: a woven rug, stuffed sacks, and
## stacked reserve crates arranged around the chest.
static func _build_treasure_dressing(node: Node3D, half: Vector2, biome: Dictionary, rng: RandomNumberGenerator, doors: Array[Vector2i] = []) -> void:
	# A rug under the chest.
	var rug := _add_mesh_box(node, Vector3(0.0, 0.05, 0.1), Vector3(2.6, 0.03, 1.9), _mat(biome["accent"], 1.0))
	rug.rotation.y = 0.06
	var rug_border := _add_mesh_box(node, Vector3(0.0, 0.075, 0.1), Vector3(2.9, 0.012, 2.2), _mat(Color(0.5, 0.42, 0.3), 1.0))
	rug_border.rotation.y = 0.06
	var door_points: Array[Vector3] = []
	for dir in doors:
		if dir.x != 0:
			door_points.append(Vector3(float(dir.x) * (half.x + 0.2), 0.0, 0.0))
		else:
			door_points.append(Vector3(0.0, 0.0, float(dir.y) * (half.y + 0.2)))
	# Sacks of coin and grain slumped against the walls, clear of the doors.
	var sack_material := _mat(Color(0.5, 0.42, 0.3), 1.0)
	var sack_tie := _mat(Color(0.32, 0.25, 0.16), 1.0)
	for i in rng.randi_range(2, 3):
		var angle := float(i) * TAU / 3.0 + 0.5
		var spot := Vector3(cos(angle) * (half.x - 1.3), 0.0, sin(angle) * (half.y - 1.3))
		if _in_door_lane(door_points, spot, 2.6):
			continue
		var sack := _add_mesh_sphere(node, spot + Vector3(0.0, 0.34, 0.0), sack_material)
		sack.scale = Vector3(1.05, 1.35, 0.95)
		var neck := _add_mesh_cylinder(node, spot + Vector3(0.0, 0.82, 0.0), 0.14, 0.22, sack_tie)
		neck.rotation.z = rng.randf_range(-0.3, 0.3)
		# A few spilled coins by each sack.
		for j in 3:
			var coin := _add_mesh_sphere(node, spot + Vector3(rng.randf_range(-0.6, 0.6), 0.05, rng.randf_range(-0.6, 0.6)), _mat(Color(0.9, 0.72, 0.3), 0.35, 0.9))
			coin.scale = Vector3(0.4, 0.15, 0.4)
	# Reserve crates stacked in the corner farthest from every doorway.
	var wood := _mat(biome["wood"], 0.95)
	var corner := Vector3.ZERO
	var best_clearance := -1.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var probe := Vector3(sx * (half.x - 1.2), 0.0, sz * (half.y - 1.2))
			var clearance := 999.0
			for point in door_points:
				clearance = minf(clearance, probe.distance_to(point))
			if clearance > best_clearance:
				best_clearance = clearance
				corner = probe
	if best_clearance < 3.0:
		return
	_build_crate(node, corner, wood, _mat(Color(0.2, 0.16, 0.12), 0.5, 0.5), rng)
	var stacked := Node3D.new()
	stacked.position = corner + Vector3(0.05, 0.85, 0.05)
	node.add_child(stacked)
	_build_crate(stacked, Vector3.ZERO, wood, _mat(Color(0.2, 0.16, 0.12), 0.5, 0.5), rng)
	stacked.rotation.y += rng.randf_range(-0.3, 0.3)

## The boss tomb: a stone sarcophagus on a side wall, hostile banners on the
## flanking walls, and grave slabs lit by the boss's own fire. The tomb is kept
## off the doorways and off the stair wall so the fight, the gate and the
## descend stair all stay reachable.
static func _build_boss_tomb(node: Node3D, half: Vector2, biome: Dictionary, rng: RandomNumberGenerator, doors: Array[Vector2i] = [], exit_dir := Vector2i.ZERO) -> void:
	var stone := _mat(biome["pillar"], 0.9)
	var stone_dark := _mat(Color(biome["pillar"]).darkened(0.18), 1.0)
	var trim := _mat(biome["accent"], 0.5, 0.6)
	var door_points: Array[Vector3] = []
	for dir in doors:
		if dir.x != 0:
			door_points.append(Vector3(float(dir.x) * (half.x + 0.2), 0.0, 0.0))
		else:
			door_points.append(Vector3(0.0, 0.0, float(dir.y) * (half.y + 0.2)))
	# Pick a wall for the sarcophagus: no doorway, and not the wall where the
	# descend stair rises.
	var sides: Array[Vector2i] = []
	for dir in Layout.DIRS:
		if doors.has(dir) or dir == exit_dir:
			continue
		sides.append(dir)
	if sides.is_empty():
		for dir in Layout.DIRS:
			if not doors.has(dir):
				sides.append(dir)
	if sides.is_empty():
		sides.append(Vector2i(1, 0))
	var tomb_dir: Vector2i = sides[rng.randi_range(0, sides.size() - 1)]
	var spot := Vector3(float(tomb_dir.x) * (half.x - 2.1), 0.0, float(tomb_dir.y) * (half.y - 2.1))
	var tomb := Node3D.new()
	tomb.name = "Sarcophagus"
	tomb.position = spot
	tomb.rotation.y = 0.0 if tomb_dir.y != 0 else PI * 0.5
	node.add_child(tomb)
	_add_solid_box(tomb, Vector3(0.0, 0.45, 0.0), Vector3(1.5, 0.9, 2.6), stone)
	var lid := _add_mesh_box(tomb, Vector3(0.35, 1.05, 0.1), Vector3(1.6, 0.22, 2.7), stone_dark)
	lid.rotation.z = -0.16
	_add_mesh_box(tomb, Vector3(0.0, 0.95, 0.0), Vector3(1.58, 0.06, 0.2), trim)
	_add_mesh_prism(tomb, Vector3(0.0, 1.2, -0.5), trim, Vector3(0.3, 0.3, 0.3))
	# Banners on the two walls flanking the tomb.
	var banner_x := tomb_dir.y != 0
	for side in [-1, 1]:
		var banner_spot := Vector3(float(side) * (half.x - 0.35), 2.6, 0.0) if banner_x else Vector3(0.0, 2.6, float(side) * (half.y - 0.35))
		var banner_size := Vector3(0.08, 2.8, 1.2) if banner_x else Vector3(1.2, 2.8, 0.08)
		_add_mesh_box(node, banner_spot, banner_size, _mat(Color(biome["accent"]).darkened(0.1), 0.95))
		var rail_size := Vector3(0.12, 0.14, 1.4) if banner_x else Vector3(1.4, 0.14, 0.12)
		_add_mesh_box(node, banner_spot + Vector3(0.0, 1.3, 0.0), rail_size, trim)
		var tail_spot := banner_spot + Vector3(0.0, -1.55, 0.0)
		var tail := _add_mesh_prism(node, tail_spot, _mat(Color(biome["accent"]).darkened(0.1), 0.95), Vector3(1.1, 0.5, 0.08) if banner_x else Vector3(0.08, 0.5, 1.1))
		tail.rotation.x = PI
	# Two grave slabs, each with a guttering soul-light, never in a door lane.
	for i in 2:
		var angle := float(i) * PI + 0.785
		var slab_spot := Vector3(cos(angle) * (half.x - 2.0), 0.0, sin(angle) * (half.y - 2.0))
		if _in_door_lane(door_points, slab_spot, 2.8):
			continue
		var slab := _add_mesh_box(node, slab_spot + Vector3(0.0, 0.14, 0.0), Vector3(1.1, 0.28, 0.7), stone_dark)
		slab.rotation.y = -angle
		var soul := _add_mesh_sphere(node, slab_spot + Vector3(0.0, 0.5, 0.0), _mat(biome["torch"], 0.3, 0.0, 1.5))
		soul.scale = Vector3(0.5, 0.8, 0.5)
		soul.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = biome["torch"]
		light.light_energy = 0.55
		light.omni_range = 3.5
		light.position = slab_spot + Vector3(0.0, 0.9, 0.0)
		node.add_child(light)

static func _build_edge(root: Node3D, rooms: Array, a_index: int, b_index: int, biome: Dictionary, rng: RandomNumberGenerator, cell_size := Layout.CELL) -> Dictionary:
	var a: Dictionary = rooms[a_index]
	var b: Dictionary = rooms[b_index]
	var dir: Vector2i = a["cell"] - b["cell"]
	dir = -dir
	var axis_x := dir.x != 0
	var dir3 := Vector3(float(dir.x), 0.0, float(dir.y))
	var perp3 := Vector3(-dir3.z, 0.0, dir3.x)
	var a_half: Vector2 = a["size"] * 0.5
	var b_half: Vector2 = b["size"] * 0.5
	var a_along := a_half.x if axis_x else a_half.y
	var b_along := b_half.x if axis_x else b_half.y
	var center_a := Layout.room_world_center(a, cell_size)
	var center_b := Layout.room_world_center(b, cell_size)
	var face_a := center_a + dir3 * (a_along + WALL_THICKNESS)
	var face_b := center_b - dir3 * (b_along + WALL_THICKNESS)
	var length := cell_size - (a_along + b_along) - WALL_THICKNESS * 2.0 + 0.8
	var mid := (face_a + face_b) * 0.5
	var wall_material := _mat(biome["wall"], 0.92)

	var corridor := Node3D.new()
	corridor.name = "Corridor_%d_%d" % [a_index, b_index]
	root.add_child(corridor)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	corridor.add_child(floor_body)
	_add_solid_box(floor_body, mid + Vector3(0.0, -0.17, 0.0), _edge_box_size(length, 0.3, 3.6, axis_x), _mat(Color(0.14, 0.16, 0.14), 0.95))
	var side_body := StaticBody3D.new()
	side_body.name = "SideWalls"
	corridor.add_child(side_body)
	for side in [-1, 1]:
		_add_solid_box(
			side_body,
			mid + perp3 * float(side) * 1.75 + Vector3(0.0, WALL_HEIGHT * 0.5, 0.0),
			_edge_box_size(length, WALL_HEIGHT, 0.3, axis_x),
			wall_material
		)
	_dress_corridor(corridor, mid, length, axis_x, biome, rng)

	var key := Layout.edge_key(a_index, b_index)
	var gate := Node3D.new()
	gate.name = "Gate_%s" % key.replace("|", "_")
	gate.position = (center_a + center_b) * 0.5
	# One construction fits both orientations: the gatehouse is built with the
	# doorway spanning local Z, so a quarter turn squares it up against a
	# corridor that runs along the world's Z instead.
	gate.rotation.y = 0.0 if axis_x else PI * 0.5
	root.add_child(gate)
	# Fresh lock-plate materials per gate so the manager can tint each door's
	# rune independently — the cached _mat pool would retint every gate at once.
	var lock_mats: Array[StandardMaterial3D] = []
	_build_gatehouse(gate, biome, lock_mats)

	var slab := StaticBody3D.new()
	slab.name = "Portcullis"
	gate.add_child(slab)
	slab.position = Vector3(0.0, 1.6, 0.0)
	var collision := _build_portcullis(slab, biome)

	return {
		"key": key,
		"slab": slab,
		"collision": collision,
		"lock_mats": lock_mats,
		"closed_y": 1.6,
		"open_y": 4.35,
		"mid": mid,
		"axis_x": axis_x,
	}

## A proper gatehouse framing each doorway: stone posts with plinths, caps and
## crenellations, a slotted header bound by a keystone, torch brackets, a winch
## drum with its rope, and a rune-lock plate on both approach faces that the
## manager tints red while the way is barred and green once it opens.
static func _build_gatehouse(gate: Node3D, biome: Dictionary, lock_mats: Array[StandardMaterial3D]) -> void:
	var stone := _mat(biome["pillar"], 0.92)
	var stone_dark := _mat(Color(biome["pillar"]).darkened(0.18), 1.0)
	var iron := _mat(Color(0.2, 0.2, 0.21), 0.45, 0.75)
	var flame := _mat(biome["torch"], 0.3, 0.0, 1.9)
	# Posts flanking the opening — the doorway spans local Z.
	for side in [-1, 1]:
		var z := 2.05 * float(side)
		var post := _add_mesh_box(gate, Vector3(0.0, 2.3, z), Vector3(1.5, 4.6, 0.9), stone)
		post.rotation.x = 0.015 * float(side)
		_add_mesh_box(gate, Vector3(0.0, 0.25, z), Vector3(1.7, 0.5, 1.1), stone_dark)
		_add_mesh_box(gate, Vector3(0.0, 4.7, z), Vector3(1.7, 0.35, 1.1), stone_dark)
		for k in 2:
			_add_mesh_box(gate, Vector3(-0.4 + 0.8 * float(k), 5.05, z), Vector3(0.45, 0.45, 0.95), stone)
		# Torch bracket on the inner face of each post.
		var arm := _add_mesh_cylinder(gate, Vector3(0.55, 2.6, z - 0.35 * float(side)), 0.05, 0.4, iron)
		arm.rotation.x = 1.35
		var tongue := _add_mesh_sphere(gate, Vector3(0.55, 2.88, z - 0.6 * float(side)), flame)
		tongue.scale = Vector3(0.8, 1.3, 0.8)
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Slotted header above the opening: two stone faces with the portcullis
	# riding in the slot between them.
	for face in [-1, 1]:
		var x := 0.42 * float(face)
		_add_mesh_box(gate, Vector3(x, 3.75, 0.0), Vector3(0.35, 1.15, 5.0), stone)
		var keystone := _add_mesh_prism(gate, Vector3(x + 0.2 * float(face), 4.45, 0.0), stone_dark, Vector3(0.42, 0.5, 0.8))
		keystone.rotation.x = PI * 0.5 * float(face)
	# Corbels carrying the header ends out over the posts.
	for side in [-1, 1]:
		_add_mesh_prism(gate, Vector3(0.0, 3.0, 2.32 * float(side)), stone_dark, Vector3(1.3, 0.55, 0.55))
	# Crenellations crowning the header.
	for k in 5:
		_add_mesh_box(gate, Vector3(0.0, 4.5, -2.0 + 1.0 * float(k)), Vector3(1.3, 0.4, 0.42), stone_dark)
	# The rune-lock plate, mounted on both approach faces of the header. Its
	# glow material is fresh per gate and handed to the manager for tinting.
	var plate_glow := StandardMaterial3D.new()
	plate_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plate_glow.albedo_color = Color(1.0, 0.32, 0.2)
	plate_glow.emission_enabled = true
	plate_glow.emission = Color(1.0, 0.32, 0.2)
	plate_glow.emission_energy_multiplier = 1.15
	lock_mats.append(plate_glow)
	for face in [-1, 1]:
		var x := 0.62 * float(face)
		_add_mesh_box(gate, Vector3(x, 3.75, 0.0), Vector3(0.06, 0.95, 1.15), iron)
		var plate := _add_mesh_box(gate, Vector3(x + 0.035 * float(face), 3.75, 0.0), Vector3(0.03, 0.72, 0.88), plate_glow)
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for dz in [-1, 1]:
			for dy in [-1, 1]:
				var rivet := _add_mesh_sphere(gate, Vector3(x + 0.06 * float(face), 3.75 + 0.3 * float(dy), 0.38 * float(dz)), iron)
				rivet.scale = Vector3.ONE * 0.05
	# The winch that would raise the gate, with its rope running down to it.
	var drum := _add_mesh_cylinder(gate, Vector3(0.0, 5.0, 2.05), 0.2, 0.66, iron)
	drum.rotation.x = 1.5708
	var crank := _add_mesh_cylinder(gate, Vector3(0.5, 5.0, 2.05), 0.04, 0.7, iron)
	crank.rotation.z = 1.5708
	_add_mesh_sphere(gate, Vector3(0.85, 5.0, 2.05), iron).scale = Vector3.ONE * 0.09
	for k in 4:
		_add_mesh_cylinder(gate, Vector3(0.55, 4.6 - 0.3 * float(k), 1.55), 0.03, 0.32, iron)
	# A warm wash under the header and a lit threshold band: the gatehouse is
	# always the brightest thing in a corridor, so a barred way is never missed.
	var gate_light := OmniLight3D.new()
	gate_light.light_color = biome["torch"]
	gate_light.light_energy = 0.6
	gate_light.omni_range = 6.0
	gate_light.position = Vector3(0.0, 3.1, 0.0)
	gate.add_child(gate_light)
	var threshold := _add_mesh_box(
		gate,
		Vector3(0.0, 0.035, 0.0),
		Vector3(2.2, 0.05, Layout.DOOR_WIDTH - 0.3),
		_mat(biome["accent"], 0.55, 0.0, 0.4)
	)
	threshold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The portcullis itself: a grid of iron bars with two braces and spiked feet,
## hung on the moving slab so the manager can tween it up out of the way. The
## collision box sits centered on the slab origin, so a closed gate bars the
## whole doorway instead of just its top half.
static func _build_portcullis(slab: StaticBody3D, _biome: Dictionary) -> CollisionShape3D:
	var iron := _mat(Color(0.23, 0.22, 0.22), 0.5, 0.7)
	var iron_dark := _mat(Color(0.15, 0.14, 0.14), 0.55, 0.6)
	var bar_count := 9
	for i in bar_count:
		var z := -1.5 + 3.0 * float(i) / float(bar_count - 1)
		_add_mesh_cylinder(slab, Vector3(0.0, 0.0, z), 0.055, 3.0, iron)
		# Downward spikes on the walking edge — the business end of the gate.
		var spike := _add_mesh_prism(slab, Vector3(0.0, -1.56, z), iron_dark, Vector3(0.13, 0.24, 0.13))
		spike.rotation.x = PI
	for y in [-0.72, 0.72]:
		_add_mesh_box(slab, Vector3(0.0, float(y), 0.0), Vector3(0.14, 0.18, 3.15), iron_dark)
	# Hanging rings where the winch rope would attach.
	_add_mesh_cylinder(slab, Vector3(0.0, 1.62, 0.0), 0.05, 0.24, iron_dark).rotation.z = 1.5708
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 3.0, 3.2)
	collision.shape = shape
	collision.position = Vector3.ZERO
	slab.add_child(collision)
	return collision

static func _edge_box_size(along: float, height: float, cross: float, axis_x: bool) -> Vector3:
	return Vector3(along, height, cross) if axis_x else Vector3(cross, height, along)

static func _random_inner_point(half: Vector2, door_points: Array[Vector3], blocked_points: Array[Vector3], door_clearance: float, rng: RandomNumberGenerator, tries: int) -> Vector3:
	for i in tries:
		var spot := Vector3(rng.randf_range(-half.x + 2.0, half.x - 2.0), 0.0, rng.randf_range(-half.y + 2.0, half.y - 2.0))
		var clear := true
		for point in door_points:
			if spot.distance_to(point) < door_clearance:
				clear = false
				break
		if not clear or _in_door_lane(door_points, spot, 2.2):
			continue
		for point in blocked_points:
			if spot.distance_to(point) < 1.9:
				clear = false
				break
		if clear:
			return spot
	return Vector3.ZERO

## True when a spot sits in the straight walking lane in front of a doorway.
## Used for every collidable prop so gates and doors are never walled off.
static func _in_door_lane(door_points: Array[Vector3], spot: Vector3, half_width: float) -> bool:
	for door in door_points:
		if absf(door.x) > 0.01:
			if signf(spot.x) == signf(door.x) and absf(spot.z) < half_width:
				return true
		elif signf(spot.z) == signf(door.z) and absf(spot.x) < half_width:
			return true
	return false

## Trap chambers read as purpose-built arenas: warning chevrons on the floor,
## runic pillars on the walls and a bright threshold marking the far doorway.
static func _build_trap_room_dressing(node: Node3D, half: Vector2, biome: Dictionary, rng: RandomNumberGenerator) -> void:
	var warning := _mat(Color(biome["accent"]), 0.6, 0.0, 0.7)
	var dark := _mat(Color(biome["crack"]), 1.0)
	# A clean grid of hazard chevrons down the middle of the lane.
	for i in 5:
		var z := -half.y + 1.6 + float(i) * (half.y * 2.0 - 3.2) / 4.0
		var left := _add_mesh_box(node, Vector3(-0.9, 0.04, z), Vector3(0.7, 0.03, 0.16), warning)
		left.rotation.y = 0.7
		var right := _add_mesh_box(node, Vector3(0.9, 0.04, z), Vector3(0.7, 0.03, 0.16), warning)
		right.rotation.y = -0.7
		_add_mesh_box(node, Vector3(0.0, 0.035, z), Vector3(3.2, 0.02, 0.07), dark)
	# Standing marker stones at the corners, with a low warning glow.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var spot := Vector3(sx * (half.x - 1.1), 0.0, sz * (half.y - 1.1))
			_add_mesh_prism(node, spot + Vector3(0.0, 0.55, 0.0), _mat(biome["pillar"], 0.9), Vector3(0.4, 1.1, 0.4))
			_add_mesh_box(node, spot + Vector3(0.0, 0.9, 0.0), Vector3(0.42, 0.1, 0.42), warning)
			var light := OmniLight3D.new()
			light.light_color = biome["torch"]
			light.light_energy = 0.35
			light.omni_range = 3.0
			light.position = spot + Vector3(0.0, 1.1, 0.0)
			node.add_child(light)

## Escape floors end at an open gate rather than a tomb: a lit arch, a clean
## floor and a ring that marks where the descend stair will rise.
static func _build_exit_chamber(node: Node3D, biome: Dictionary) -> void:
	var stone := _mat(biome["pillar"], 0.92)
	var glow := _mat(biome["accent"], 0.4, 0.0, 1.4)
	for side in [-1, 1]:
		_add_mesh_box(node, Vector3(2.4 * float(side), 1.7, 0.0), Vector3(0.6, 3.4, 0.6), stone)
		_add_mesh_box(node, Vector3(2.4 * float(side), 3.55, 0.0), Vector3(0.9, 0.3, 0.9), glow)
	_add_mesh_box(node, Vector3(0.0, 3.6, 0.0), Vector3(5.6, 0.4, 0.6), stone)
	# A bright lintel legend so the ascent never reads as another dead end.
	var title := Label3D.new()
	title.text = "WAY OUT"
	title.font_size = 52
	title.pixel_size = 0.0044
	title.outline_size = 15
	title.outline_modulate = Color(0.04, 0.05, 0.04, 1.0)
	title.modulate = Color(0.7, 1.0, 0.76, 1.0)
	title.position = Vector3(0.0, 3.6, 0.36)
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.add_child(title)
	# Standing lamps on both posts, plus a clean ring underfoot.
	var flame_material := _mat(biome["torch"], 0.3, 0.0, 2.0)
	for side in [-1, 1]:
		var lamp := Vector3(2.4 * float(side), 0.0, 0.42)
		_add_mesh_cylinder(node, lamp + Vector3(0.0, 0.5, 0.0), 0.06, 1.0, _mat(biome["metal"], 0.5, 0.65))
		var flame := _add_mesh_sphere(node, lamp + Vector3(0.0, 1.1, 0.0), flame_material)
		flame.scale = Vector3(0.6, 1.0, 0.6)
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := _add_mesh_cylinder(node, Vector3(0.0, 0.05, 0.0), 2.6, 0.04, glow)
	ring.scale.y = 1.0
	for i in 3:
		var chevron := _add_mesh_box(node, Vector3(0.0, 0.075, -1.4 + 0.7 * float(i)), Vector3(0.5, 0.02, 0.12), glow)
		chevron.rotation.y = 0.0
		chevron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = biome["accent"]
	light.light_energy = 1.1
	light.omni_range = 8.0
	light.position = Vector3(0.0, 2.6, 0.0)
	node.add_child(light)

static func _mat(color: Color, roughness: float, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material

static func _add_solid_box(body: Node, position: Vector3, size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = position
	body.add_child(mesh_instance)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = position
	body.add_child(collision)

static func _add_mesh_box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	node.mesh = box
	node.position = position
	parent.add_child(node)
	return node

static func _add_mesh_cylinder(parent: Node3D, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 10
	cylinder.rings = 2
	cylinder.material = material
	node.mesh = cylinder
	node.position = position
	parent.add_child(node)
	return node

static func _add_mesh_sphere(parent: Node3D, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = material
	node.mesh = sphere
	node.position = position
	parent.add_child(node)
	return node

static func _add_mesh_prism(parent: Node3D, position: Vector3, material: Material, size := Vector3(0.4, 0.5, 0.4)) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = size
	prism.material = material
	node.mesh = prism
	node.position = position
	parent.add_child(node)
	return node
