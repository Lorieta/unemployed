extends Node3D

## Runs a generated dungeon depth: builds the floor from layout data, spawns
## scaled monsters, locks rooms behind clear conditions, and unlocks the
## descend stairwell once the warden falls. Level progression only — the whole
## run resets when the hero falls, a new depth is built after each descent,
## and ascent stairwells let the hero climb back up a floor or out to the
## surface when embedded in the world. In that mode nothing is built until
## `enter_dungeon()` is called from the surface entrance interactable.

const MONSTER_SCENE := preload("res://scenes/world/monster.tscn")
const Layout := preload("res://scripts/dungeon/layout_generator.gd")
const Builder := preload("res://scripts/dungeon/room_builder.gd")
const Stairs := preload("res://scripts/dungeon/dungeon_stairs.gd")
const Trap := preload("res://scripts/dungeon/dungeon_trap.gd")
const Rune := preload("res://scripts/dungeon/dungeon_rune.gd")

const VARIANT_BASES := {
	"mossling": {
		"display": "Mossling",
		"health": 60.0,
		"damage": 8.0,
		"speed": 2.6,
		"attack_range": 1.8,
		"attack_interval": 1.7,
		"aggro": 11.0,
		"xp": 30.0,
		"gold": 5,
	},
	"briar_wolf": {
		"display": "Briar Wolf",
		"health": 95.0,
		"damage": 12.0,
		"speed": 3.5,
		"attack_range": 2.0,
		"attack_interval": 1.4,
		"aggro": 13.0,
		"xp": 50.0,
		"gold": 9,
	},
	"wisp": {
		"display": "Foxfire Wisp",
		"health": 55.0,
		"damage": 11.0,
		"speed": 2.2,
		"attack_range": 6.2,
		"attack_interval": 2.3,
		"aggro": 14.0,
		"xp": 45.0,
		"gold": 7,
	},
	"ember_hound": {
		"display": "Ember Hound",
		"health": 130.0,
		"damage": 14.0,
		"speed": 4.3,
		"attack_range": 2.2,
		"attack_interval": 1.4,
		"aggro": 14.0,
		"xp": 75.0,
		"gold": 11,
	},
	"cinder_imp": {
		"display": "Cinder Imp",
		"health": 95.0,
		"damage": 15.0,
		"speed": 2.0,
		"attack_range": 7.5,
		"attack_interval": 2.2,
		"aggro": 15.0,
		"xp": 80.0,
		"gold": 12,
	},
	"barrow_wight": {
		"display": "Barrow Wight",
		"health": 190.0,
		"damage": 17.0,
		"speed": 3.0,
		"attack_range": 2.5,
		"attack_interval": 1.9,
		"aggro": 14.0,
		"xp": 100.0,
		"gold": 15,
	},
	"grave_knight": {
		"display": "Grave Knight",
		"health": 260.0,
		"damage": 20.0,
		"speed": 3.1,
		"attack_range": 2.8,
		"attack_interval": 1.6,
		"aggro": 16.0,
		"xp": 140.0,
		"gold": 22,
	},
	"ash_revenant": {
		"display": "Ash Revenant",
		"health": 225.0,
		"damage": 22.0,
		"speed": 2.6,
		"attack_range": 6.4,
		"attack_interval": 2.0,
		"aggro": 17.0,
		"xp": 165.0,
		"gold": 26,
	},
}
## The deeper crypts are ruled by the dead of the barrows: the Briar Warden
## keeps the shallow halls, and from the third depth down a Barrow King sits on
## the dais with his nova and his volley.
const BOSS_BASES := {
	"briar_warden": {
		"display": "Briar Warden",
		"health": 260.0,
		"damage": 14.0,
		"speed": 2.7,
		"attack_range": 2.7,
		"attack_interval": 1.9,
		"aggro": 24.0,
		"xp": 320.0,
		"gold": 140,
	},
	"barrow_king": {
		"display": "Barrow King",
		"health": 430.0,
		"damage": 19.0,
		"speed": 2.8,
		"attack_range": 3.2,
		"attack_interval": 2.1,
		"aggro": 24.0,
		"xp": 520.0,
		"gold": 230,
	},
	"frost_wraith": {
		"display": "Frost Wraith",
		"health": 560.0,
		"damage": 23.0,
		"speed": 3.2,
		"attack_range": 2.9,
		"attack_interval": 1.8,
		"aggro": 26.0,
		"xp": 720.0,
		"gold": 320,
	},
	"ember_tyrant": {
		"display": "Ember Tyrant",
		"health": 700.0,
		"damage": 26.0,
		"speed": 3.0,
		"attack_range": 3.5,
		"attack_interval": 1.9,
		"aggro": 26.0,
		"xp": 950.0,
		"gold": 440,
	},
}

const SCALE_PER_DEPTH := 0.26
const TREASURE_HEAL := 40.0
const DESCENT_HEAL := 25.0
const SPAWN_MARGIN := 2.0
const GATE_SLIDE_TIME := 0.9
const TRAP_SCALE_PER_DEPTH := 0.1

@export var deterministic_seed := 0
@export var auto_start := true
@export var embedded_in_world := false
@export var vertical_offset := 0.0

var depth := 0
var _base_seed := 0
var _archetype := "branch"
var _layout: Dictionary
var _built: Dictionary
var _chunks: Node3D
var _gates: Dictionary
var _rooms: Dictionary
var _cleared_combat := 0
var _combat_total := 0
var _boss_dead := false
var _boss_gate_opened := false
var _boss_display := ""
var _stairs: StaticBody3D
var _player: Node3D
var _spawn_rng := RandomNumberGenerator.new()
var _dungeon_active := false
var _transitioning := false
var _surface_return := Vector3.INF
var _floor_state := {}
var _hero_local := Vector3.INF
var _light_backup := []
var _dungeon_environment: Environment

func _ready() -> void:
	add_to_group("dungeon_manager")
	_base_seed = deterministic_seed if deterministic_seed > 0 else randi()
	if auto_start:
		_start_floor(1)

func enter_dungeon() -> void:
	if _transitioning or _dungeon_active:
		return
	_player = _find_player()
	if _player == null:
		return
	_dungeon_active = true
	_surface_return = _player.global_position
	# A fresh descent into the crypt rolls a brand-new run seed, so leaving and
	# coming back never replays the same floors. Saved floors in _floor_state
	# keep this run's seed until the hero climbs out.
	if _floor_state.is_empty():
		_base_seed = deterministic_seed if deterministic_seed > 0 else randi()
	if "allow_fall_rescue" in _player:
		_player.set("allow_fall_rescue", false)
	_set_dungeon_lighting(true)
	_start_floor(1)

func exit_dungeon() -> void:
	if _transitioning or not _dungeon_active:
		return
	_transitioning = true
	_dungeon_active = false
	if _player != null and is_instance_valid(_player) and _surface_return.x != INF:
		_player.global_position = _surface_return
	if _player != null and is_instance_valid(_player) and "allow_fall_rescue" in _player:
		_player.set("allow_fall_rescue", true)
	_surface_return = Vector3.INF
	_set_dungeon_lighting(false)
	depth = 0
	_reset_floor_state()
	_floor_state = {}
	await _rebuild_chunks()
	_transitioning = false
	_toast("You climb back into the Reach.")

func is_inside_dungeon() -> bool:
	return _dungeon_active

func _start_floor(next_depth: int) -> void:
	depth = next_depth
	_transitioning = true
	_reset_floor_state()
	_hero_local = Vector3.INF
	await _rebuild_chunks()
	_layout = Layout.generate(depth, _base_seed)
	_archetype = String(_layout.get("archetype", "branch"))
	_built = Builder.build(_chunks, _layout, _base_seed)
	_gates = _built["gates"]
	_rig_rooms()
	_apply_initial_gates()
	_restore_floor()
	_spawn_ascent()
	_place_hero()
	_spawn_monsters()
	_spawn_traps()
	_spawn_runes()
	if _archetype == "escape":
		_toast("Trap Gauntlet  —  Depth %d" % depth)
		_toast("No foes here. Dodge the snares and cross every chamber to escape.")
	else:
		_toast("%s  —  Depth %d" % [str(_built.get("biome_name", "Dungeon")), depth])
		_toast("Clear every hall to open the warden's door.")
	_transitioning = false

func _reset_floor_state() -> void:
	_rooms = {}
	_gates = {}
	_built = {}
	_layout = {}
	_stairs = null
	_cleared_combat = 0
	_combat_total = 0
	_boss_dead = false
	_boss_gate_opened = false
	_boss_display = ""

func _rebuild_chunks() -> void:
	if _chunks != null and is_instance_valid(_chunks):
		var old := _chunks
		_chunks = null
		old.queue_free()
		await get_tree().process_frame
	_chunks = Node3D.new()
	_chunks.name = "Chunks_Floor_%d" % depth
	add_child(_chunks)
	_chunks.position = Vector3(0.0, vertical_offset, 0.0)

func _rig_rooms() -> void:
	var rooms: Array = _layout["rooms"]
	for i in rooms.size():
		var record: Dictionary = _built["rooms"][i]
		_rooms[i] = {
			"type": record["type"],
			"state": "fresh",
			"monsters_left": 0,
			"blessed": false,
			"monster_nodes": [],
			"parent": int(rooms[i]["parent"]),
			"children": rooms[i]["children"],
		}
		if record["type"] == "combat" or record["type"] == "trap":
			_combat_total += 1
		var zone: Area3D = record["zone"]
		zone.body_entered.connect(_on_zone_entered.bind(i))
		var exit_zone = record.get("exit_zone")
		if exit_zone is Area3D:
			(exit_zone as Area3D).body_entered.connect(_on_trap_exit.bind(i))

## A corridor starts shut when the room it leaves is an uncleared combat or trap
## chamber, or when it leads into the boss room, so every deeper hall must be
## earned. Trap chambers open onto their approach and seal only once the hero
## steps inside, so a gauntlet can always be entered. Loop corridors (the maze
## shortcuts) start shut and open once either side falls. The entrance keeps an
## open way out and treasure rooms stay reachable from halls that are done.
func _apply_initial_gates() -> void:
	var rooms: Array = _layout["rooms"]
	for key in _gates:
		var parts: PackedStringArray = String(key).split("|")
		var a := int(parts[0])
		var b := int(parts[1])
		var shut: bool
		var child := b if int(rooms[b]["parent"]) == a else -1
		if child < 0:
			child = a if int(rooms[a]["parent"]) == b else -1
		if child >= 0:
			var parent := b if child == a else a
			var parent_kind := String(rooms[parent]["type"])
			var child_kind := String(rooms[child]["type"])
			# The approach to a trap chamber stays open; the edge that *leaves*
			# an uncleared trap is barred until its far-side exit is crossed.
			shut = parent_kind == "combat" or parent_kind == "trap" or child_kind == "boss"
		else:
			shut = _room_is_gated(rooms[a]) or _room_is_gated(rooms[b])
		_place_gate(key, shut)

func _room_is_gated(room: Dictionary) -> bool:
	var kind := String(room["type"])
	return kind == "combat" or kind == "trap" or kind == "boss"

func _gate_touches(key: String, index: int) -> bool:
	var parts := key.split("|")
	return int(parts[0]) == index or int(parts[1]) == index

func _gate_other(key: String, index: int) -> int:
	var parts := key.split("|")
	var a := int(parts[0])
	var b := int(parts[1])
	return b if a == index else a

func _place_gate(key: String, shut: bool) -> void:
	var gate: Dictionary = _gates.get(key, {})
	if gate.is_empty():
		return
	if shut:
		gate["collision"].disabled = false
		gate["slab"].position.y = float(gate["closed_y"])
	else:
		gate["collision"].disabled = true
		gate["slab"].position.y = float(gate["open_y"])
	_tint_gate(gate, shut)

## The rune plate above each door burns red while the way is barred and cools
## to a green gleam once the hall behind it is subdued.
func _tint_gate(gate: Dictionary, locked: bool) -> void:
	if not gate.has("lock_mats"):
		return
	var color := Color(1.0, 0.32, 0.2) if locked else Color(0.55, 1.0, 0.7)
	var energy := 1.15 if locked else 0.8
	for material in gate["lock_mats"]:
		material.emission = color
		material.emission_energy_multiplier = energy

func _restore_floor() -> void:
	var saved: Dictionary = _floor_state.get(depth, {})
	if saved.is_empty():
		return
	var cleared: Array = saved.get("cleared", [])
	for index in cleared:
		var room: Dictionary = _rooms.get(index, {})
		if room.is_empty():
			continue
		room["state"] = "cleared"
		_open_room_gates(int(index))
	_cleared_combat = _count_cleared()
	for index in saved.get("blessed", []):
		var room: Dictionary = _rooms.get(index, {})
		if not room.is_empty():
			room["blessed"] = true
	# Re-evaluate the exit gate now that the saved room states are in place: a
	# floor saved with every hall cleared but a living warden must still open
	# its gate on the way back up. On an escape floor this also restores the
	# exit stair once every trap chamber is behind the hero.
	_open_boss_gate()
	if bool(saved.get("boss_dead", false)):
		_boss_dead = true
		var boss_index := int(_layout["boss"])
		if _rooms.has(boss_index):
			_rooms[boss_index]["state"] = "cleared"
		_spawn_stairs()

func _spawn_ascent() -> void:
	if _chunks == null:
		return
	var entrance := int(_layout["entrance"])
	var center: Vector3 = _built["rooms"][entrance]["center"]
	var stairs := Stairs.new()
	stairs.name = "AscendStairs"
	stairs.ascent = true
	_chunks.add_child(stairs)
	stairs.position = center + Vector3(0.0, 0.55, 0.0)
	stairs.used.connect(_on_stairs_used.bind(stairs))
	stairs.unlock()

func _spawn_monsters() -> void:
	_spawn_rng.seed = hash(["spawn", _base_seed, depth])
	var rooms: Array = _layout["rooms"]
	var boss_index := int(_layout["boss"])
	var scale := _difficulty_scale()
	for i in rooms.size():
		var kind: String = rooms[i]["type"]
		if kind == "combat":
			var room: Dictionary = _rooms[i]
			if String(room["state"]) == "cleared":
				continue
			var count := clampi(2 + _spawn_rng.randi_range(0, 1) + depth - 1, 2, 5)
			for n in count:
				_spawn_at_room(i, _pick_variant(), scale)
		elif kind == "boss":
			# Escape stages are monster-free trap gauntlets; the exit stair
			# rises from the clear condition instead of a boss corpse.
			if _archetype == "escape" or _boss_dead:
				continue
			_spawn_boss(boss_index, scale)

func _difficulty_scale() -> float:
	return 1.0 + SCALE_PER_DEPTH * float(depth - 1)

## Enemy tiers roll forward with depth: the weak crypt-folk disappear from the
## pool instead of following the hero forever, and the dead take their place.
func _pick_variant() -> String:
	var pool: Array[String]
	if depth <= 1:
		pool = ["mossling", "briar_wolf"]
	elif depth <= 3:
		pool = ["briar_wolf", "wisp", "ember_hound"]
	elif depth <= 5:
		pool = ["ember_hound", "cinder_imp", "barrow_wight"]
	elif depth <= 8:
		pool = ["cinder_imp", "barrow_wight", "grave_knight"]
	else:
		pool = ["barrow_wight", "grave_knight", "ash_revenant"]
	return pool[_spawn_rng.randi_range(0, pool.size() - 1)]

## The crypt's ruler changes with depth: living thorns, then the barrow dead,
## then the wraiths and tyrants that rule the deepest vaults.
func _boss_variant() -> String:
	if depth >= 9:
		return "ember_tyrant"
	if depth >= 6:
		return "frost_wraith"
	if depth >= 3:
		return "barrow_king"
	return "briar_warden"

func _spawn_boss(boss_index: int, scale: float) -> void:
	var record: Dictionary = _built["rooms"][boss_index]
	var variant := _boss_variant()
	_boss_display = str(BOSS_BASES[variant]["display"])
	var monster: CharacterBody3D = MONSTER_SCENE.instantiate()
	_configure_monster(monster, variant, BOSS_BASES[variant], scale, true)
	monster.position = _local_boss_position(record)
	record["node"].add_child(monster)
	_rooms[boss_index]["monsters_left"] = 1
	_rooms[boss_index]["monster_nodes"].append(monster)
	monster.defeated.connect(_on_monster_defeated.bind(boss_index))
	monster.tree_exited.connect(_on_monster_gone.bind(monster, boss_index))

## ---------------------------------------------------------------------------
## Traps: hazards seeded through the corridors and the uncleared combat halls.
## The deeper the floor, the more of them the crypt arms against intruders.
## ---------------------------------------------------------------------------

func _spawn_traps() -> void:
	var escape := _archetype == "escape"
	var trap_count := clampi(6 + depth, 6, 14) if escape else clampi(2 + depth / 2, 2, 6)
	var spots: Array[Dictionary] = []
	# Corridor midpoints make natural kill lanes. The gate stores the corridor
	# midpoint in floor space; the trap is nudged down the lane afterward so it
	# never spawns inside the gatehouse posts or under the portcullis.
	for key in _gates:
		var gate: Dictionary = _gates[key]
		spots.append({
			"position": Vector3(gate.get("mid", Vector3.ZERO)),
			"in_room": false,
			"axis_x": bool(gate.get("axis_x", true)),
		})
	# Combat halls hide traps among their clutter; escape halls are all trap.
	var rooms: Array = _layout["rooms"]
	for i in rooms.size():
		var kind := String(rooms[i]["type"])
		if kind == "combat" or kind == "trap":
			spots.append({"index": i, "in_room": true})
	# Chambers have room for the big rigs; corridors only get compact floor
	# hazards so their wide beams, sweepers and crusher guides never clip the
	# gatehouse or the lane walls.
	var chamber_types: Array[String] = ["spike", "flame", "darts", "crusher", "beam", "sweeper"]
	if not escape:
		chamber_types = ["spike", "flame", "darts", "crusher"]
	var corridor_types: Array[String] = ["spike", "flame"]
	var damage_scale := 1.0 + TRAP_SCALE_PER_DEPTH * float(depth - 1)
	var placed := 0
	var guard := 0
	while placed < trap_count and guard < 80:
		guard += 1
		var choice: Dictionary = spots[_spawn_rng.randi_range(0, spots.size() - 1)]
		var trap := Trap.new()
		var in_room := bool(choice["in_room"])
		var pool := chamber_types if in_room else corridor_types
		trap.trap_type = pool[_spawn_rng.randi_range(0, pool.size() - 1)]
		trap.damage_scale = damage_scale
		if in_room:
			var record: Dictionary = _built["rooms"][int(choice["index"])]
			var local_spot := _trap_room_spot(record)
			if local_spot == Vector3.INF:
				continue
			trap.position = local_spot
			(record["node"] as Node3D).add_child(trap)
		else:
			# Step the hazard down the lane so it clears the gatehouse footings
			# and the raised portcullis, picking a side at random.
			var along := Vector3.RIGHT if bool(choice.get("axis_x", true)) else Vector3.BACK
			var side := -1.0 if _spawn_rng.randf() < 0.5 else 1.0
			var corridor_mid: Vector3 = choice["position"]
			trap.position = corridor_mid + along * (2.7 * side) + Vector3(0.0, 0.05, 0.0)
			_chunks.add_child(trap)
		placed += 1

func _trap_room_spot(record: Dictionary) -> Vector3:
	var half: Vector2 = record["half"]
	for i in 12:
		var spot := Vector3(
			_spawn_rng.randf_range(-half.x + 2.2, half.x - 2.2),
			0.0,
			_spawn_rng.randf_range(-half.y + 2.2, half.y - 2.2)
		)
		if not _point_clear(record, spot):
			continue
		return spot
	return Vector3.INF

## ---------------------------------------------------------------------------
## Buff runes: at least one ring on every floor — the treasure room always
## keeps one, and a second is hidden in a random combat hall.
## ---------------------------------------------------------------------------

func _spawn_runes() -> void:
	var kinds: Array[String] = ["power", "haste", "ward", "mend"]
	_place_rune(int(_layout["treasure"]), kinds[_spawn_rng.randi_range(0, kinds.size() - 1)])
	# A second rune deeper in, in a room the hero has to fight through.
	var rooms: Array = _layout["rooms"]
	var candidates: Array[int] = []
	for i in rooms.size():
		var kind := String(rooms[i]["type"])
		# Escape floors have no combat halls, so their second rune hides in a
		# trap chamber instead.
		if kind == "combat" or kind == "trap":
			candidates.append(i)
	if not candidates.is_empty():
		_place_rune(candidates[_spawn_rng.randi_range(0, candidates.size() - 1)], kinds[_spawn_rng.randi_range(0, kinds.size() - 1)])

func _place_rune(room_index: int, kind: String) -> void:
	var record: Dictionary = _built["rooms"][room_index]
	var rune := Rune.new()
	rune.kind = kind
	var local_spot := _trap_room_spot(record)
	if local_spot == Vector3.INF:
		local_spot = Vector3(0.0, 0.05, 0.0)
	rune.position = local_spot + Vector3(0.0, 0.05, 0.0)
	(record["node"] as Node3D).add_child(rune)

func _spawn_at_room(room_index: int, variant: String, scale: float) -> void:
	var record: Dictionary = _built["rooms"][room_index]
	var base: Dictionary = VARIANT_BASES[variant]
	var monster: CharacterBody3D = MONSTER_SCENE.instantiate()
	_configure_monster(monster, variant, base, scale, false)
	monster.position = _local_spawn_position(record, _spawn_rng)
	record["node"].add_child(monster)
	_rooms[room_index]["monsters_left"] += 1
	_rooms[room_index]["monster_nodes"].append(monster)
	monster.defeated.connect(_on_monster_defeated.bind(room_index))
	monster.tree_exited.connect(_on_monster_gone.bind(monster, room_index))

func _configure_monster(monster: CharacterBody3D, variant: String, base: Dictionary, scale: float, boss: bool) -> void:
	monster.variant = variant
	monster.display_name = str(base["display"])
	monster.max_health = float(base["health"]) * scale
	monster.health = monster.max_health
	monster.damage = float(base["damage"]) * scale
	monster.move_speed = float(base["speed"])
	monster.attack_range = float(base["attack_range"])
	monster.attack_interval = float(base["attack_interval"])
	monster.aggro_range = float(base["aggro"])
	monster.xp_reward = float(base["xp"]) * scale
	monster.gold_reward = int(round(float(base["gold"]) * scale))
	monster.respawn_delay = 3600.0
	if boss:
		monster.boss = true
		monster.dormant = true

func _local_spawn_position(record: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var half: Vector2 = record["half"]
	for i in 16:
		var spot := Vector3(
			rng.randf_range(-half.x + SPAWN_MARGIN, half.x - SPAWN_MARGIN),
			0.05,
			rng.randf_range(-half.y + SPAWN_MARGIN, half.y - SPAWN_MARGIN)
		)
		if not _point_clear(record, spot):
			continue
		return spot
	return Vector3(0.0, 0.05, 0.0)

func _local_boss_position(record: Dictionary) -> Vector3:
	var boss_index := int(_layout["boss"])
	var parent_index: int = _rooms[boss_index]["parent"]
	var rooms: Array = _layout["rooms"]
	var away := Vector3(0.0, 0.0, 1.0)
	if parent_index >= 0:
		var dir: Vector2i = rooms[boss_index]["cell"] - rooms[parent_index]["cell"]
		away = Vector3(float(dir.x), 0.0, float(dir.y)).normalized() * -1.0
	var half: Vector2 = record["half"]
	var reach := half.x if absf(away.x) > 0.5 else half.y
	return away * (reach - 3.4) + Vector3(0.0, 0.55, 0.0)

func _point_clear(record: Dictionary, spot: Vector3) -> bool:
	for point in record["blocked_points"]:
		if spot.distance_to(point) < 2.4:
			return false
	if record["index"] == int(_layout["entrance"]) and _hero_local.x != INF:
		if spot.distance_to(_hero_local) < 2.4:
			return false
	return true

func _place_hero() -> void:
	_player = _find_player()
	if _player == null:
		return
	var entrance_index := int(_layout["entrance"])
	var record: Dictionary = _built["rooms"][entrance_index]
	var local_spot: Vector3
	var saved: Dictionary = _floor_state.get(depth, {})
	if not saved.is_empty():
		local_spot = saved["return_local"]
		_hero_local = Vector3.INF
		_player.global_position = Vector3(0.0, vertical_offset, 0.0) + local_spot
	else:
		local_spot = _fresh_hero_spot(record)
		_hero_local = Vector3(local_spot.x, 0.0, local_spot.z)
		_player.global_position = (record["node"] as Node3D).global_position + local_spot
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		camera.global_position = _player.global_position + Vector3(0.0, 9.0, 7.5)

func _fresh_hero_spot(record: Dictionary) -> Vector3:
	var doors: Array = record["doors"]
	if doors.is_empty():
		return Vector3(0.0, 0.6, 0.0)
	var dir: Vector2i = doors[0]
	var half: Vector2 = record["half"]
	var reach := half.x if dir.x != 0 else half.y
	return Vector3(float(dir.x) * (reach - 3.0), 0.6, float(dir.y) * (reach - 3.0))

func _find_player() -> Node3D:
	var found := get_tree().get_first_node_in_group("player") as Node3D
	if found != null:
		return found
	if has_node("Player"):
		return get_node("Player") as Node3D
	return null

func _set_dungeon_lighting(on: bool) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if on:
		if _dungeon_environment == null:
			_dungeon_environment = Environment.new()
			_dungeon_environment.background_mode = Environment.BG_COLOR
			_dungeon_environment.background_color = Color(0.01, 0.012, 0.02)
			_dungeon_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			_dungeon_environment.ambient_light_color = Color(0.12, 0.13, 0.18)
			_dungeon_environment.ambient_light_energy = 0.35
			_dungeon_environment.fog_enabled = true
			_dungeon_environment.fog_light_color = Color(0.05, 0.055, 0.08)
			_dungeon_environment.fog_density = 0.012
		_light_backup.clear()
		for node in scene.find_children("*", "WorldEnvironment", true, false):
			var holder := node as WorldEnvironment
			_light_backup.append({"node": holder, "environment": holder.environment})
			holder.environment = _dungeon_environment
		for node in scene.find_children("*", "DirectionalLight3D", true, false):
			var light := node as DirectionalLight3D
			_light_backup.append({"node": light, "energy": light.light_energy})
			light.light_energy = 0.04
	else:
		for item in _light_backup:
			var node: Node = item["node"]
			if not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			if node is WorldEnvironment:
				(node as WorldEnvironment).environment = item["environment"]
			elif node is DirectionalLight3D:
				(node as DirectionalLight3D).light_energy = item["energy"]
		_light_backup.clear()

func _on_zone_entered(body: Node3D, room_index: int) -> void:
	if body == null or not body.is_in_group("player"):
		return
	var room: Dictionary = _rooms.get(room_index, {})
	if room.is_empty():
		return
	match room["type"]:
		"combat":
			if _room_has_active_enemies(room_index):
				# Bar the doors only while the hall still stands against
				# the hero — an emptied hall must never seal behind them.
				if room["state"] == "fresh":
					room["state"] = "sealed"
				_seal_room(room_index)
			else:
				_clear_combat_room(room_index)
		"trap":
			# A trap chamber has no enemies: surviving means reaching its far
			# side. Seal the way back so the gauntlet can't be bypassed.
			if String(room["state"]) == "fresh":
				room["state"] = "sealed"
				_seal_room(room_index)
		"treasure":
			if not room["blessed"]:
				room["blessed"] = true
				_heal_player(TREASURE_HEAL)
		"boss":
			_awaken_boss(room_index)

func _on_trap_exit(body: Node3D, room_index: int) -> void:
	if body == null or not body.is_in_group("player"):
		return
	var room: Dictionary = _rooms.get(room_index, {})
	if room.is_empty() or String(room["type"]) != "trap":
		return
	if String(room["state"]) == "cleared":
		return
	_clear_combat_room(room_index)

func _seal_room(room_index: int) -> void:
	# Close every gate touching this room — tree edges and maze loop edges
	# alike — so a waking hall can't be kited through its shortcuts.
	for key in _gates:
		if _gate_touches(key, room_index):
			_set_gate(key, false)

## True while any spawned monster of this hall is still alive. Defeated
## monsters linger as fading corpses for a moment, so check health rather
## than node validity alone.
func _room_has_active_enemies(room_index: int) -> bool:
	var room: Dictionary = _rooms.get(room_index, {})
	if room.is_empty():
		return false
	for monster in room["monster_nodes"]:
		if is_instance_valid(monster) and float(monster.health) > 0.0:
			return true
	return false

## A combat hall counts as fallen once nothing in it is left standing. The
## defeat signal and every other path that empties a hall funnel through
## here, so the gates always reopen whatever the kill order looked like.
func _clear_combat_room(room_index: int) -> void:
	var room: Dictionary = _rooms.get(room_index, {})
	var kind := String(room.get("type", ""))
	if room.is_empty() or (kind != "combat" and kind != "trap"):
		return
	if String(room["state"]) != "cleared":
		room["state"] = "cleared"
		_toast("The gauntlet is behind you.  The way ahead grinds open." if kind == "trap" else "The hall falls quiet.  The gates open.")
	# Recount from room state rather than trusting an incremental tally: a
	# restored floor, a stray free or a double clear can never desync the gate.
	_cleared_combat = _count_cleared()
	_open_room_gates(room_index)
	_open_boss_gate()

## Safety net: a monster node leaving the tree without a defeat signal (an
## odd cleanup path, a fall, a freed floor) must not leave its hall sealed
## forever. Skips floor transitions, where everything frees at once.
func _on_monster_gone(monster: Node, room_index: int) -> void:
	if _transitioning or not is_inside_tree():
		return
	var room: Dictionary = _rooms.get(room_index, {})
	if room.is_empty() or not room["monster_nodes"].has(monster):
		return
	if String(room["state"]) == "sealed" and not _room_has_active_enemies(room_index):
		_clear_combat_room(room_index)

func _awaken_boss(room_index: int) -> void:
	var room: Dictionary = _rooms.get(room_index, {})
	if room.is_empty() or _boss_dead:
		return
	for monster in room["monster_nodes"]:
		if is_instance_valid(monster) and monster.has_method("awaken"):
			monster.awaken()

func _on_monster_defeated(_monster: Node, room_index: int) -> void:
	var room: Dictionary = _rooms.get(room_index, {})
	if room.is_empty():
		return
	room["monsters_left"] = maxi(0, int(room["monsters_left"]) - 1)
	if int(room["monsters_left"]) > 0:
		return
	match room["type"]:
		"combat":
			_clear_combat_room(room_index)
		"boss":
			_boss_dead = true
			room["state"] = "cleared"
			_spawn_stairs()
			var boss_name := _boss_display if _boss_display != "" else str(BOSS_BASES[_boss_variant()]["display"])
			_toast("%s falls.  A stair descends to the next depth." % boss_name)

func _open_room_gates(room_index: int) -> void:
	var parent: int = _rooms[room_index]["parent"]
	# A cleared hall or trap chamber opens every way it touches, including the
	# way the hero came in. The seal on entry supplies the gauntlet's pressure;
	# leaving a cleared chamber one-way could strand the hero when another side
	# chamber still bars the boss door.
	if parent >= 0:
		_set_gate(Layout.edge_key(parent, room_index), true)
	var boss_index := int(_layout["boss"])
	for child in _rooms[room_index]["children"]:
		if child == boss_index:
			continue
		_set_gate(Layout.edge_key(room_index, child), true)
	# Maze loop corridors: open every shortcut touching the cleared hall,
	# except one that would sneak into the boss lair early.
	for key in _gates:
		if not _gate_touches(key, room_index):
			continue
		var other := _gate_other(key, room_index)
		if other == boss_index:
			continue
		_set_gate(key, true)

## How many clearable halls (combat or trap) are done, counted straight from
## room state so a restore or a stray free can never desync the tally.
func _count_cleared() -> int:
	var count := 0
	for key in _rooms:
		var room: Dictionary = _rooms[key]
		var kind := String(room["type"])
		if (kind == "combat" or kind == "trap") and String(room["state"]) == "cleared":
			count += 1
	return count

## True only when every combat hall and trap chamber on this depth is cleared.
## The boss door and the escape stair both key off this one test.
func _all_halls_cleared() -> bool:
	var required := 0
	for key in _rooms:
		var room: Dictionary = _rooms[key]
		var kind := String(room["type"])
		if kind != "combat" and kind != "trap":
			continue
		required += 1
		if String(room["state"]) != "cleared":
			return false
	return required > 0

## The single source of truth for the floor's exit gate: it opens exactly when
## every clearable room on this depth is done. Called on each clear and again
## when a saved floor is restored, so climbing back up can't relock it.
func _open_boss_gate() -> void:
	if _boss_gate_opened or not _all_halls_cleared():
		return
	_boss_gate_opened = true
	var boss_index := int(_layout["boss"])
	for key in _gates:
		if _gate_touches(key, boss_index):
			_set_gate(key, true)
	if _archetype == "escape":
		_complete_escape_floor()
	else:
		_toast("Every hall is subdued.  The warden's door stands open.")

## The Collapsing Vault has no warden: crossing every trap chamber is the clear
## condition, and the exit stair rises from the far chamber once it is done.
func _complete_escape_floor() -> void:
	_boss_dead = true
	var boss_index := int(_layout["boss"])
	if _rooms.has(boss_index):
		_rooms[boss_index]["state"] = "cleared"
	_spawn_stairs()
	_toast("Every gauntlet is behind you.  The exit stair rises.")

func _set_gate(key: String, opened: bool) -> void:
	var gate: Dictionary = _gates.get(key, {})
	if gate.is_empty():
		return
	var slab: StaticBody3D = gate["slab"]
	if slab.has_meta("y_tween"):
		var previous: Tween = slab.get_meta("y_tween")
		if previous.is_valid():
			previous.kill()
	var collider: CollisionShape3D = gate["collision"]
	collider.set_deferred("disabled", opened)
	var target_y: float = float(gate["open_y"]) if opened else float(gate["closed_y"])
	var tween := slab.create_tween()
	slab.set_meta("y_tween", tween)
	tween.tween_property(slab, "position:y", target_y, GATE_SLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tint_gate(gate, not opened)

func _spawn_stairs() -> void:
	if _stairs != null or _chunks == null:
		return
	var stairs := Stairs.new()
	stairs.name = "DescendStairs"
	_stairs = stairs
	_chunks.add_child(_stairs)
	_stairs.position = _built["stair_spot"]
	_stairs.used.connect(_on_stairs_used.bind(_stairs))
	_stairs.unlock()

func _on_stairs_used(stairs_node: Node) -> void:
	var ascend := false
	if stairs_node != null and "ascent" in stairs_node:
		ascend = bool(stairs_node.get("ascent"))
	if ascend:
		if depth <= 1:
			exit_dungeon()
		else:
			_ascend_floor()
	else:
		_descend()

func _descend() -> void:
	if _transitioning:
		return
	_snapshot_floor()
	var next := depth + 1
	if not _floor_state.has(next):
		_heal_player(DESCENT_HEAL)
	_start_floor(next)

func _ascend_floor() -> void:
	if _transitioning:
		return
	var target := depth - 1
	if target < 1:
		exit_dungeon()
		return
	if _floor_state.get(target, {}).is_empty():
		exit_dungeon()
		return
	_start_floor(target)

func _snapshot_floor() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var cleared: Array = []
	var blessed: Array = []
	for key in _rooms:
		var room: Dictionary = _rooms[key]
		var kind := String(room["type"])
		if (kind == "combat" or kind == "trap") and String(room["state"]) == "cleared":
			cleared.append(int(key))
		if bool(room["blessed"]):
			blessed.append(int(key))
	var return_local: Vector3 = Vector3.ZERO
	if is_instance_valid(_player):
		return_local = _player.global_position - Vector3(0.0, vertical_offset, 0.0)
	_floor_state[depth] = {
		"cleared": cleared,
		"blessed": blessed,
		"boss_dead": _boss_dead,
		"return_local": return_local,
	}

func _heal_player(amount: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("_heal"):
		hud.call("_heal", amount)

func _toast(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", text)
