class_name DungeonLayoutBuilder
extends RefCounted

## Pure-data floor layout: turns a depth number plus a seed into room records
## without touching nodes, physics or scenes, so it can be smoke-tested
## headlessly (scripts/dungeon/debug_check.gd). Room records are Dictionaries:
## { index, cell (Vector2i), parent (int, -1 for the entrance), children
## (Array[int]), type, size (Vector2 world W x D), distance }.

const CELL := 16.0
const DOOR_WIDTH := 3.2
const MIN_ROOM := 10.0
const MAX_ROOM := 14.6
const MAX_COMBAT_ROOMS := 8

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

static func combat_room_count(depth: int) -> int:
	return clampi(2 + depth / 2, 2, MAX_COMBAT_ROOMS)

static func generate(depth: int, base_seed: int) -> Dictionary:
	var layout := {}
	for attempt in range(8):
		layout = _generate_once(depth, base_seed, attempt)
		if validate(layout).is_empty():
			return layout
	push_warning("DungeonLayoutBuilder: falling back after 8 attempts (depth %d)" % depth)
	return _generate_once(depth, base_seed, 99)

static func _generate_once(depth: int, base_seed: int, attempt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["dungeon", depth, base_seed, attempt])
	var combat_count := combat_room_count(depth)
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var cell_index := {Vector2i.ZERO: 0}
	var parents: Array[int] = [-1]
	var guard := 0
	while cells.size() < combat_count + 3 and guard < 4000:
		guard += 1
		var origin_index := rng.randi_range(0, cells.size() - 1)
		var dir := DIRS[rng.randi_range(0, DIRS.size() - 1)]
		var candidate: Vector2i = cells[origin_index] + dir
		if cell_index.has(candidate):
			continue
		var neighbours := 0
		for probe in DIRS:
			if cell_index.has(candidate + probe):
				neighbours += 1
		if neighbours != 1:
			continue
		cell_index[candidate] = cells.size()
		cells.append(candidate)
		parents.append(origin_index)

	var rooms: Array = []
	for i in cells.size():
		rooms.append({
			"index": i,
			"cell": cells[i],
			"parent": parents[i],
			"children": [],
			"type": "combat",
			"size": Vector2.ZERO,
			"distance": 0,
		})
	for i in range(1, rooms.size()):
		rooms[parents[i]]["children"].append(i)
	for i in range(1, rooms.size()):
		rooms[i]["distance"] = int(rooms[parents[i]]["distance"]) + 1
	rooms[0]["type"] = "entrance"

	var boss_index := -1
	for i in range(1, rooms.size()):
		if boss_index < 0 or int(rooms[i]["distance"]) > int(rooms[boss_index]["distance"]):
			boss_index = i
	rooms[boss_index]["type"] = "boss"

	var treasure_candidates: Array[int] = []
	for i in range(1, rooms.size()):
		if i == boss_index or not rooms[i]["children"].is_empty():
			continue
		treasure_candidates.append(i)
	if treasure_candidates.is_empty():
		for i in range(1, rooms.size()):
			if i != boss_index:
				treasure_candidates.append(i)
	var treasure_index := treasure_candidates[rng.randi_range(0, treasure_candidates.size() - 1)]
	rooms[treasure_index]["type"] = "treasure"

	for i in rooms.size():
		rooms[i]["size"] = _size_for_type(rooms[i]["type"], rng)

	return {
		"depth": depth,
		"base_seed": base_seed,
		"rooms": rooms,
		"entrance": 0,
		"boss": boss_index,
		"treasure": treasure_index,
	}

static func _size_for_type(type: String, rng: RandomNumberGenerator) -> Vector2:
	match type:
		"boss":
			return Vector2(rng.randf_range(13.0, MAX_ROOM), rng.randf_range(13.0, MAX_ROOM))
		"entrance":
			return Vector2(rng.randf_range(12.0, 14.0), rng.randf_range(12.0, 14.0))
		"treasure":
			return Vector2(rng.randf_range(10.0, 12.5), rng.randf_range(10.0, 12.5))
		_:
			return Vector2(rng.randf_range(MIN_ROOM, MAX_ROOM), rng.randf_range(MIN_ROOM, MAX_ROOM))

static func validate(layout: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var rooms: Array = layout.get("rooms", [])
	if rooms.is_empty():
		problems.append("layout has no rooms")
		return problems
	if rooms[0].get("type") != "entrance":
		problems.append("room 0 is not the entrance")
	var occupied := {}
	var boss_count := 0
	var treasure_count := 0
	var combat_count := 0
	var deepest := 0
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var cell: Vector2i = room["cell"]
		if occupied.has(cell):
			problems.append("duplicate cell %s" % cell)
		occupied[cell] = true
		match room["type"]:
			"boss":
				boss_count += 1
			"treasure":
				treasure_count += 1
			"combat":
				combat_count += 1
		if int(room["distance"]) > int(rooms[deepest]["distance"]):
			deepest = i
	if int(layout.get("boss", -1)) != deepest:
		problems.append("boss room is not the deepest room")
	if boss_count != 1:
		problems.append("expected exactly 1 boss room, found %d" % boss_count)
	if treasure_count != 1:
		problems.append("expected exactly 1 treasure room, found %d" % treasure_count)
	if combat_count != combat_room_count(int(layout.get("depth", 1))):
		problems.append("combat room count %d does not match depth" % combat_count)
	var boss_index := int(layout.get("boss", -1))
	for i in range(1, rooms.size()):
		var room: Dictionary = rooms[i]
		var parent := int(room["parent"])
		if parent < 0 or parent >= rooms.size():
			problems.append("room %d has no valid parent" % i)
			continue
		var delta: Vector2i = room["cell"] - rooms[parent]["cell"]
		if absi(delta.x) + absi(delta.y) != 1:
			problems.append("room %d parent cell is not adjacent" % i)
		if not rooms[parent]["children"].has(i):
			problems.append("room %d parent does not list it as a child" % i)
		if int(room["distance"]) != int(rooms[parent]["distance"]) + 1:
			problems.append("room %d distance disagrees with its parent" % i)
	if boss_index < 0 or boss_index >= rooms.size():
		problems.append("boss index out of range")
	elif not rooms[boss_index]["children"].is_empty():
		problems.append("boss room has children")
	for i in rooms.size():
		if rooms[i]["children"].is_empty() and int(rooms[i]["parent"]) < 0:
			problems.append("room %d is unreachable" % i)
	return problems

static func edge_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]

static func room_world_center(room: Dictionary) -> Vector3:
	var cell: Vector2i = room["cell"]
	return Vector3(float(cell.x) * CELL, 0.0, float(cell.y) * CELL)

static func door_dirs_for(rooms: Array, index: int) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	var room: Dictionary = rooms[index]
	var parent := int(room["parent"])
	if parent >= 0:
		dirs.append(_dir_between(room["cell"], rooms[parent]["cell"]))
	for child in room["children"]:
		dirs.append(_dir_between(room["cell"], rooms[child]["cell"]))
	return dirs

static func _dir_between(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	return Vector2i(signi(to_cell.x - from_cell.x), signi(to_cell.y - from_cell.y))
