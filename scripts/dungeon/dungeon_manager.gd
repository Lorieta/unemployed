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
}
const BOSS_BASE := {
	"variant": "briar_warden",
	"display": "Briar Warden",
	"health": 260.0,
	"damage": 14.0,
	"speed": 2.7,
	"attack_range": 2.7,
	"attack_interval": 1.9,
	"aggro": 24.0,
	"xp": 320.0,
	"gold": 140,
}

const SCALE_PER_DEPTH := 0.18
const TREASURE_HEAL := 40.0
const DESCENT_HEAL := 25.0
const SPAWN_MARGIN := 2.0
const GATE_SLIDE_TIME := 0.9

@export var deterministic_seed := 0
@export var auto_start := true
@export var embedded_in_world := false
@export var vertical_offset := 0.0

var depth := 0
var _base_seed := 0
var _layout: Dictionary
var _built: Dictionary
var _chunks: Node3D
var _gates: Dictionary
var _rooms: Dictionary
var _cleared_combat := 0
var _combat_total := 0
var _boss_dead := false
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
	_built = Builder.build(_chunks, _layout, _base_seed)
	_gates = _built["gates"]
	_rig_rooms()
	_apply_initial_gates()
	_restore_floor()
	_spawn_ascent()
	_place_hero()
	_spawn_monsters()
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
		if record["type"] == "combat":
			_combat_total += 1
		var zone: Area3D = record["zone"]
		zone.body_entered.connect(_on_zone_entered.bind(i))

## A corridor starts shut when the room it leaves is an uncleared combat room or
## when it leads into the boss room, so every deeper hall must be earned. The
## entrance keeps an open way out and treasure rooms stay reachable from halls
## that are already done.
func _apply_initial_gates() -> void:
	var rooms: Array = _layout["rooms"]
	for i in rooms.size():
		var parent := int(rooms[i]["parent"])
		if parent < 0:
			continue
		var shut := String(rooms[parent]["type"]) == "combat" or String(rooms[i]["type"]) == "boss"
		_place_gate(Layout.edge_key(parent, i), shut)

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

func _restore_floor() -> void:
	var saved: Dictionary = _floor_state.get(depth, {})
	if saved.is_empty():
		return
	var cleared: Array = saved["cleared"]
	_cleared_combat = cleared.size()
	for index in cleared:
		var room: Dictionary = _rooms.get(index, {})
		if room.is_empty():
			continue
		room["state"] = "cleared"
		_open_room_gates(int(index))
	for index in saved["blessed"]:
		var room: Dictionary = _rooms.get(index, {})
		if not room.is_empty():
			room["blessed"] = true
	if bool(saved["boss_dead"]):
		_boss_dead = true
		var boss_index := int(_layout["boss"])
		_rooms[boss_index]["state"] = "cleared"
		_open_boss_gate()
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
			if _boss_dead:
				continue
			_spawn_boss(boss_index, scale)

func _difficulty_scale() -> float:
	return 1.0 + SCALE_PER_DEPTH * float(depth - 1)

func _pick_variant() -> String:
	var pool: Array = ["mossling"]
	if depth >= 2:
		pool.append("briar_wolf")
	if depth >= 3:
		pool.append("wisp")
	return pool[_spawn_rng.randi_range(0, pool.size() - 1)]

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

func _spawn_boss(boss_index: int, scale: float) -> void:
	var record: Dictionary = _built["rooms"][boss_index]
	var monster: CharacterBody3D = MONSTER_SCENE.instantiate()
	_configure_monster(monster, "briar_warden", BOSS_BASE, scale, true)
	monster.position = _local_boss_position(record)
	record["node"].add_child(monster)
	_rooms[boss_index]["monsters_left"] = 1
	_rooms[boss_index]["monster_nodes"].append(monster)
	monster.defeated.connect(_on_monster_defeated.bind(boss_index))

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
			if room["state"] == "fresh":
				room["state"] = "sealed"
				_seal_room(room_index)
		"treasure":
			if not room["blessed"]:
				room["blessed"] = true
				_heal_player(TREASURE_HEAL)
		"boss":
			_awaken_boss(room_index)

func _seal_room(room_index: int) -> void:
	var parent: int = _rooms[room_index]["parent"]
	if parent >= 0:
		_set_gate(Layout.edge_key(parent, room_index), false)

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
			room["state"] = "cleared"
			_cleared_combat += 1
			_open_room_gates(room_index)
			_toast("The hall falls quiet.  The gates open.")
			if _cleared_combat >= _combat_total:
				_open_boss_gate()
		"boss":
			_boss_dead = true
			room["state"] = "cleared"
			_spawn_stairs()
			_toast("The Warden falls.  A stair descends to the next depth.")

func _open_room_gates(room_index: int) -> void:
	var parent: int = _rooms[room_index]["parent"]
	if parent >= 0:
		_set_gate(Layout.edge_key(parent, room_index), true)
	var boss_index := int(_layout["boss"])
	for child in _rooms[room_index]["children"]:
		if child == boss_index:
			continue
		_set_gate(Layout.edge_key(room_index, child), true)

func _open_boss_gate() -> void:
	var boss_index := int(_layout["boss"])
	var parent: int = _rooms[boss_index]["parent"]
	if parent >= 0:
		_set_gate(Layout.edge_key(parent, boss_index), true)
		_toast("Every hall is subdued.  The warden's door stands open.")

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
		if String(room["type"]) == "combat" and String(room["state"]) == "cleared":
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
