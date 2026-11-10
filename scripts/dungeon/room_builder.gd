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
	},
	{
		"name": "Ember Halls",
		"floor": Color(0.2, 0.14, 0.12),
		"wall": Color(0.26, 0.19, 0.16),
		"pillar": Color(0.3, 0.22, 0.18),
		"accent": Color(0.52, 0.2, 0.12),
		"torch": Color(1.0, 0.5, 0.18),
		"metal": Color(0.28, 0.23, 0.2),
	},
	{
		"name": "Frost Vaults",
		"floor": Color(0.14, 0.17, 0.2),
		"wall": Color(0.19, 0.23, 0.27),
		"pillar": Color(0.23, 0.28, 0.32),
		"accent": Color(0.35, 0.5, 0.62),
		"torch": Color(0.55, 0.8, 1.0),
		"metal": Color(0.22, 0.26, 0.3),
	},
]

static var _materials := {}

static func biome_for_depth(depth: int) -> Dictionary:
	return BIOMES[(depth - 1) % BIOMES.size()]

static func build(root: Node3D, layout: Dictionary, base_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rooms", int(layout["depth"]), base_seed])
	var rooms: Array = layout["rooms"]
	var biome := biome_for_depth(int(layout["depth"]))
	var door_dirs: Array = []
	for i in rooms.size():
		door_dirs.append(Layout.door_dirs_for(rooms, i))
	var result := {
		"rooms": [],
		"gates": {},
		"stair_spot": Vector3.ZERO,
		"biome_name": biome["name"],
	}
	for i in rooms.size():
		result["rooms"].append(_build_room(root, rooms, i, door_dirs[i], biome, rng, result))
	for i in rooms.size():
		var parent := int(rooms[i]["parent"])
		if parent < 0:
			continue
		result["gates"][Layout.edge_key(parent, i)] = _build_edge(root, rooms, parent, i, biome)
	return result

static func _build_room(root: Node3D, rooms: Array, index: int, doors: Array[Vector2i], biome: Dictionary, rng: RandomNumberGenerator, result: Dictionary) -> Dictionary:
	var room: Dictionary = rooms[index]
	var center := Layout.room_world_center(room)
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

	var brazier_count := 4 if room["type"] == "boss" else rng.randi_range(2, 3)
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
	var rubble_count := rng.randi_range(3, 6)
	for i in rubble_count:
		var spot := _random_inner_point(half, door_points, record["blocked_points"], 3.0, rng, 12)
		if spot == Vector3.ZERO:
			continue
		_build_rock(node, spot, rock_material, rng)

	match room["type"]:
		"entrance":
			for k in 8:
				var angle := float(k) * TAU / 8.0
				var stone := _add_mesh_prism(node, Vector3(cos(angle) * 2.4, 0.24, sin(angle) * 2.4), _mat(biome["accent"], 0.85))
				stone.rotation.y = -angle
		"treasure":
			_build_treasure(node, biome)
		"boss":
			_build_boss_dais(node, biome)
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
	return record

static func _build_rock(parent: Node3D, local_spot: Vector3, material: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var scale_value := rng.randf_range(0.5, 1.2)
	var node := Node3D.new()
	parent.add_child(node)
	var rock := _add_mesh_sphere(node, Vector3(0.0, 0.0, 0.0), material)
	rock.scale = Vector3(scale_value, scale_value * 0.6, scale_value * rng.randf_range(0.8, 1.2))
	rock.position = Vector3(0.0, scale_value * 0.35, 0.0)
	rock.rotation.y = rng.randf() * TAU
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
	mesh.height = 0.5
	mesh.radial_segments = 14
	mesh.rings = 2
	mesh.material = stone
	dais.mesh = mesh
	dais.position = Vector3(0.0, 0.25, 0.0)
	node.add_child(dais)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.1
	shape.height = 0.5
	collision.shape = shape
	collision.position = dais.position
	var dais_body := StaticBody3D.new()
	dais_body.name = "Dais"
	node.add_child(dais_body)
	dais_body.add_child(collision)
	var light := OmniLight3D.new()
	light.light_color = biome["torch"]
	light.light_energy = 0.7
	light.omni_range = 9.0
	light.position = Vector3(0.0, 3.6, 0.0)
	node.add_child(light)

static func _build_edge(root: Node3D, rooms: Array, a_index: int, b_index: int, biome: Dictionary) -> Dictionary:
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
	var center_a := Layout.room_world_center(a)
	var center_b := Layout.room_world_center(b)
	var face_a := center_a + dir3 * (a_along + WALL_THICKNESS)
	var face_b := center_b - dir3 * (b_along + WALL_THICKNESS)
	var length := Layout.CELL - (a_along + b_along) - WALL_THICKNESS * 2.0 + 0.8
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

	var key := Layout.edge_key(a_index, b_index)
	var gate := Node3D.new()
	gate.name = "Gate_%s" % key.replace("|", "_")
	gate.position = (center_a + center_b) * 0.5
	root.add_child(gate)
	var jamb_body := StaticBody3D.new()
	jamb_body.name = "Jambs"
	gate.add_child(jamb_body)
	for side in [-1, 1]:
		var jamb_offset := perp3 * float(side) * 1.75 + Vector3(0.0, 1.9, 0.0)
		var jamb := _add_mesh_cylinder(jamb_body, jamb_offset, 0.28, 3.8, _mat(Color(0.3, 0.28, 0.26), 0.6, 0.4))
		var jamb_shape := CylinderShape3D.new()
		jamb_shape.radius = 0.28
		jamb_shape.height = 3.8
		var jamb_collision := CollisionShape3D.new()
		jamb_collision.shape = jamb_shape
		jamb_collision.position = jamb_offset
		jamb_body.add_child(jamb_collision)
	_add_mesh_box(gate, Vector3(0.0, 3.5, 0.0), _edge_box_size(0.4, 0.5, Layout.DOOR_WIDTH + 1.2, axis_x), _mat(Color(0.26, 0.24, 0.22), 0.7, 0.3))

	var slab := StaticBody3D.new()
	slab.name = "Slab"
	gate.add_child(slab)
	var slab_size := _edge_box_size(0.35, 3.2, Layout.DOOR_WIDTH, axis_x)
	var slab_mesh := MeshInstance3D.new()
	var slab_box := BoxMesh.new()
	slab_box.size = slab_size
	slab_box.material = _mat(Color(0.34, 0.3, 0.26), 0.4, 0.7)
	slab_mesh.mesh = slab_box
	slab_mesh.position = Vector3(0.0, 1.6, 0.0)
	slab.add_child(slab_mesh)
	var slab_collision := CollisionShape3D.new()
	var slab_shape := BoxShape3D.new()
	slab_shape.size = slab_size
	slab_collision.shape = slab_shape
	slab_collision.position = Vector3(0.0, 1.6, 0.0)
	slab.add_child(slab_collision)

	return {
		"key": key,
		"slab": slab,
		"collision": slab_collision,
		"closed_y": 1.6,
		"open_y": -1.9,
	}

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
		if not clear:
			continue
		for point in blocked_points:
			if spot.distance_to(point) < 1.9:
				clear = false
				break
		if clear:
			return spot
	return Vector3.ZERO

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

static func _add_mesh_prism(parent: Node3D, position: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.4, 0.5, 0.4)
	prism.material = material
	node.mesh = prism
	node.position = position
	parent.add_child(node)
	return node
