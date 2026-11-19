class_name DungeonLayoutBuilder
extends RefCounted

## Pure-data floor layout: turns a depth number plus a seed into room records
## without touching nodes, physics or scenes, so it can be smoke-tested
## headlessly (scripts/dungeon/debug_check.gd). Room records are Dictionaries:
## { index, cell (Vector2i), parent (int, -1 for the entrance), children
## (Array[int]), type, size (Vector2 world W x D), distance }.
##
## Every depth also gets a floor *style*: a warren, a long gauntlet, a
## crossroads, or ringed halls. The style changes the growth rules, corridor
## spacing and room sizes, so two depths never read as the same floor. Every
## fifth depth is the Collapsing Vault: a linear escape stage where a wall of
## ruin chases the hero toward the warden's door.

const CELL := 18.0
const DOOR_WIDTH := 3.2
const MIN_ROOM := 9.5
const MAX_ROOM := 14.4
const MAX_COMBAT_ROOMS := 8
const ESCAPE_EVERY := 5

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## name is shown in the depth banner; cell is the world distance between room
## centres; room_min/room_max bound the side length of a combat hall.
const STYLES := {
	"warren": {
		"name": "Twisting Warrens",
		"cell": 18.0,
		"room_min": 10.0,
		"room_max": 14.4,
	},
	"gauntlet": {
		"name": "Long Gauntlet",
		"cell": 17.0,
		"room_min": 9.5,
		"room_max": 12.4,
	},
	"crossroads": {
		"name": "Crossroads",
		"cell": 19.0,
		"room_min": 10.5,
		"room_max": 14.0,
	},
	"ring": {
		"name": "Ringed Halls",
		"cell": 18.5,
		"room_min": 9.8,
		"room_max": 13.2,
	},
	"collapse": {
		"name": "The Collapsing Vault",
		"cell": 16.5,
		"room_min": 9.5,
		"room_max": 12.0,
	},
}

static func combat_room_count(depth: int) -> int:
	return clampi(2 + depth / 2, 2, MAX_COMBAT_ROOMS)

## The escape stage runs a little leaner so the collapsing wall stays a real
## threat instead of a long slog.
static func combat_expected(depth: int, style: String) -> int:
	var base := combat_room_count(depth)
	if style == "collapse":
		return maxi(2, base - 1)
	return base

## Which floor shape this depth wears. The four normal styles rotate with the
## depth, so consecutive stages always feel different, while the seeded offset
## keeps separate runs from lining up. Every fifth depth is the escape stage.
static func style_for_depth(depth: int, base_seed: int) -> String:
	if depth > 0 and depth % ESCAPE_EVERY == 0:
		return "collapse"
	var keys: Array[String] = ["warren", "gauntlet", "crossroads", "ring"]
	var offset := absi(base_seed) % keys.size()
	return keys[(depth - 1 + offset) % keys.size()]

## Loop corridors that turn the pure tree of rooms into a maze: extra passages
## between rooms that already sit side by side but were not connected. The
## shape decides how maze-like the floor is; ringed halls are the most tangled.
static func extra_edge_count(depth: int, style: String) -> int:
	var count := 1
	match style:
		"collapse":
			count = 0
		"gauntlet":
			count = 1
		"warren":
			count = clampi(1 + (depth - 1) / 3, 1, 3)
		"crossroads":
			count = clampi(2 + (depth - 1) / 3, 2, 5)
		"ring":
			count = clampi(3 + (depth - 1) / 2, 3, 7)
	return count

static func generate(depth: int, base_seed: int) -> Dictionary:
	var layout := {}
	for attempt in range(10):
		layout = _generate_once(depth, base_seed, attempt)
		if validate(layout).is_empty():
			return layout
	push_warning("DungeonLayoutBuilder: falling back after 10 attempts (depth %d)" % depth)
	return _generate_once(depth, base_seed, 99)

static func _generate_once(depth: int, base_seed: int, attempt: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["dungeon", depth, base_seed, attempt])
	var style := style_for_depth(depth, base_seed)
	var config: Dictionary = STYLES.get(style, STYLES["warren"])
	var cell_size := float(config["cell"])
	var combat_count := combat_expected(depth, style)
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var cell_index := {Vector2i.ZERO: 0}
	var parents: Array[int] = [-1]
	var distances: Array[int] = [0]
	var guard := 0
	while cells.size() < combat_count + 3 and guard < 6000:
		guard += 1
		var origin_index := _pick_origin(style, cells, parents, distances, rng)
		var dir := _pick_direction(style, origin_index, cells, cell_index, parents, rng)
		if dir == Vector2i.ZERO:
			continue
		var candidate: Vector2i = cells[origin_index] + dir
		if cell_index.has(candidate):
			continue
		cell_index[candidate] = cells.size()
		cells.append(candidate)
		parents.append(origin_index)
		distances.append(int(distances[origin_index]) + 1)

	var rooms: Array = []
	for i in cells.size():
		rooms.append({
			"index": i,
			"cell": cells[i],
			"parent": parents[i],
			"children": [],
			"type": "combat",
			"size": Vector2.ZERO,
			"distance": distances[i],
		})
	for i in range(1, rooms.size()):
		rooms[parents[i]]["children"].append(i)
	rooms[0]["type"] = "entrance"

	var boss_index := -1
	for i in range(1, rooms.size()):
		if boss_index < 0 or int(rooms[i]["distance"]) > int(rooms[boss_index]["distance"]):
			boss_index = i
	rooms[boss_index]["type"] = "boss"

	# The Collapsing Vault replaces its combat halls with trap chambers: the
	# hero clears each one by crossing to the far doorway, not by fighting.
	if style == "collapse":
		for i in range(1, rooms.size()):
			if String(rooms[i]["type"]) == "combat":
				rooms[i]["type"] = "trap"

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

	# Loop corridors: connect a few adjacent-but-unlinked room pairs so the
	# floor reads as a maze rather than a straight gauntlet. The pairs keep the
	# tree structure intact (parents and children unchanged), they only add
	# extra doorways recorded separately. Enumerate the pairs instead of
	# randomly probing so a floor with possible loops always gets them.
	var adjacent_pairs: Array = []
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var delta: Vector2i = rooms[j]["cell"] - rooms[i]["cell"]
			if absi(delta.x) + absi(delta.y) != 1:
				continue
			# Never duplicate a tree doorway as a "loop" — the gate map is keyed
			# by room pair, so a duplicate would replace the real gate.
			if int(rooms[j]["parent"]) == i or int(rooms[i]["parent"]) == j:
				continue
			adjacent_pairs.append([i, j])
	for i in range(adjacent_pairs.size() - 1, 0, -1):
		var swap_with := rng.randi_range(0, i)
		var swap = adjacent_pairs[i]
		adjacent_pairs[i] = adjacent_pairs[swap_with]
		adjacent_pairs[swap_with] = swap
	var extra_edges: Array = []
	var extra_target := extra_edge_count(depth, style)
	var boss_loops := 0
	for pair in adjacent_pairs:
		if extra_edges.size() >= extra_target:
			break
		var a_index := int(pair[0])
		var b_index := int(pair[1])
		# At most one loop corridor into the boss lair, so its front door
		# stays meaningful.
		if a_index == boss_index or b_index == boss_index:
			if boss_loops > 0:
				continue
			boss_loops += 1
		extra_edges.append([mini(a_index, b_index), maxi(a_index, b_index)])

	for i in rooms.size():
		rooms[i]["size"] = _size_for_type(rooms[i]["type"], style, rng)

	return {
		"depth": depth,
		"base_seed": base_seed,
		"rooms": rooms,
		"entrance": 0,
		"boss": boss_index,
		"treasure": treasure_index,
		"extra_edges": extra_edges,
		"style": style,
		"style_name": str(config["name"]),
		"archetype": "escape" if style == "collapse" else "branch",
		"cell_size": cell_size,
		"escape": style == "collapse",
		"combat_expected": combat_count,
	}

## Where the next room grows from. A gauntlet keeps pushing off its deepest
## room, a crossroads favours the junction and the first two rings, a warren
## wanders, and ringed halls spread evenly.
static func _pick_origin(style: String, cells: Array[Vector2i], parents: Array[int], distances: Array[int], rng: RandomNumberGenerator) -> int:
	match style:
		"gauntlet", "collapse":
			if rng.randf() < 0.8:
				var deepest := 0
				for i in cells.size():
					if int(distances[i]) > int(distances[deepest]):
						deepest = i
				return deepest
		"crossroads":
			if rng.randf() < 0.45:
				return 0
			if rng.randf() < 0.4:
				var shallow: Array[int] = []
				for i in cells.size():
					if int(distances[i]) <= 2:
						shallow.append(i)
				if not shallow.is_empty():
					return shallow[rng.randi_range(0, shallow.size() - 1)]
		_:
			if cells.size() > 2 and rng.randf() < 0.5:
				var a := rng.randi_range(0, cells.size() - 1)
				var b := rng.randi_range(0, cells.size() - 1)
				return a if int(distances[a]) >= int(distances[b]) else b
	return rng.randi_range(0, cells.size() - 1)

static func _pick_direction(style: String, origin: int, cells: Array[Vector2i], cell_index: Dictionary, parents: Array[int], rng: RandomNumberGenerator) -> Vector2i:
	var valid: Array[Vector2i] = []
	var folded: Array[Vector2i] = []
	# A cell brushing two halls is what makes a shortcut corridor possible.
	# Collapse floors stay strictly linear; the other styles fold back on
	# themselves so the extra-edge pass can weave real loops.
	var max_neighbours := 1 if style == "collapse" else 2
	for dir in DIRS:
		var candidate: Vector2i = cells[origin] + dir
		if cell_index.has(candidate):
			continue
		var neighbours := 0
		for probe in DIRS:
			if cell_index.has(candidate + probe):
				neighbours += 1
		if neighbours < 1 or neighbours > max_neighbours:
			continue
		valid.append(dir)
		if neighbours == 2:
			folded.append(dir)
	if valid.is_empty():
		return Vector2i.ZERO
	if style == "ring" and not folded.is_empty():
		return folded[rng.randi_range(0, folded.size() - 1)]
	var forward := Vector2i.ZERO
	var parent := int(parents[origin])
	if parent >= 0:
		forward = cells[origin] - cells[parent]
	if style == "gauntlet" or style == "collapse":
		if forward != Vector2i.ZERO and valid.has(forward) and rng.randf() < 0.75:
			return forward
	elif style == "crossroads" and forward != Vector2i.ZERO and rng.randf() < 0.65:
		var turns: Array[Vector2i] = []
		for dir in valid:
			if dir != forward:
				turns.append(dir)
		if not turns.is_empty():
			return turns[rng.randi_range(0, turns.size() - 1)]
	return valid[rng.randi_range(0, valid.size() - 1)]

static func _size_for_type(type: String, style: String, rng: RandomNumberGenerator) -> Vector2:
	var config: Dictionary = STYLES.get(style, STYLES["warren"])
	match type:
		"boss":
			return Vector2(rng.randf_range(13.0, MAX_ROOM), rng.randf_range(13.0, MAX_ROOM))
		"entrance":
			return Vector2(rng.randf_range(11.0, 13.5), rng.randf_range(11.0, 13.5))
		"treasure":
			return Vector2(rng.randf_range(9.5, 12.0), rng.randf_range(9.5, 12.0))
		_:
			var low := float(config["room_min"])
			var high := float(config["room_max"])
			return Vector2(rng.randf_range(low, high), rng.randf_range(low, high))

static func validate(layout: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var rooms: Array = layout.get("rooms", [])
	if rooms.is_empty():
		problems.append("layout has no rooms")
		return problems
	if rooms[0].get("type") != "entrance":
		problems.append("room 0 is not the entrance")
	var style := String(layout.get("style", ""))
	if not STYLES.has(style):
		problems.append("unknown floor style '%s'" % style)
	var cell_size := float(layout.get("cell_size", CELL))
	if cell_size < 12.0:
		problems.append("cell size is too small: %.1f" % cell_size)
	var occupied := {}
	var boss_count := 0
	var treasure_count := 0
	var combat_count := 0
	var trap_count := 0
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
			"trap":
				trap_count += 1
		if int(room["distance"]) > int(rooms[deepest]["distance"]):
			deepest = i
	if int(layout.get("boss", -1)) != deepest:
		problems.append("boss room is not the deepest room")
	if boss_count != 1:
		problems.append("expected exactly 1 boss room, found %d" % boss_count)
	if treasure_count != 1:
		problems.append("expected exactly 1 treasure room, found %d" % treasure_count)
	var expected := int(layout.get("combat_expected", combat_room_count(int(layout.get("depth", 1)))))
	var clearable := combat_count if style != "collapse" else trap_count
	if clearable != expected:
		problems.append("clearable room count %d does not match expected %d" % [clearable, expected])
	if style == "collapse" and combat_count > 0:
		problems.append("escape floor should not contain combat halls")
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
		# Leave room for a walkable corridor between two halls.
		var axis_x := delta.x != 0
		var a_size: Vector2 = rooms[parent]["size"]
		var b_size: Vector2 = room["size"]
		var a_along := (a_size.x if axis_x else a_size.y) * 0.5
		var b_along := (b_size.x if axis_x else b_size.y) * 0.5
		if cell_size - a_along - b_along < 2.4:
			problems.append("rooms %d and %d leave no corridor" % [parent, i])
	if boss_index < 0 or boss_index >= rooms.size():
		problems.append("boss index out of range")
	elif not rooms[boss_index]["children"].is_empty():
		problems.append("boss room has children")
	for i in rooms.size():
		if rooms[i]["children"].is_empty() and int(rooms[i]["parent"]) < 0:
			problems.append("room %d is unreachable" % i)
	var extra: Array = layout.get("extra_edges", [])
	var seen_loops := {}
	for edge in extra:
		var a := int(edge[0])
		var b := int(edge[1])
		if a < 0 or a >= rooms.size() or b < 0 or b >= rooms.size() or a == b:
			problems.append("loop edge %d|%d out of range" % [a, b])
			continue
		var loop_key := edge_key(a, b)
		if seen_loops.has(loop_key):
			problems.append("duplicate loop edge %s" % loop_key)
		seen_loops[loop_key] = true
		if int(rooms[a]["parent"]) == b or int(rooms[b]["parent"]) == a:
			problems.append("loop edge %s duplicates a tree doorway" % loop_key)
		var delta: Vector2i = rooms[b]["cell"] - rooms[a]["cell"]
		if absi(delta.x) + absi(delta.y) != 1:
			problems.append("loop edge %s is not adjacent" % loop_key)
	if bool(layout.get("escape", false)) != (style == "collapse"):
		problems.append("escape flag disagrees with floor style")
	return problems

static func edge_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]

static func room_world_center(room: Dictionary, cell_size := CELL) -> Vector3:
	var cell: Vector2i = room["cell"]
	return Vector3(float(cell.x) * cell_size, 0.0, float(cell.y) * cell_size)

static func door_dirs_for(rooms: Array, index: int, extra_edges: Array = []) -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	var room: Dictionary = rooms[index]
	var parent := int(room["parent"])
	if parent >= 0:
		dirs.append(_dir_between(room["cell"], rooms[parent]["cell"]))
	for child in room["children"]:
		dirs.append(_dir_between(room["cell"], rooms[child]["cell"]))
	for edge in extra_edges:
		var a := int(edge[0])
		var b := int(edge[1])
		if index == a:
			dirs.append(_dir_between(room["cell"], rooms[b]["cell"]))
		elif index == b:
			dirs.append(_dir_between(room["cell"], rooms[a]["cell"]))
	return dirs

static func _dir_between(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	return Vector2i(signi(to_cell.x - from_cell.x), signi(to_cell.y - from_cell.y))
