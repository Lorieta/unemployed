extends SceneTree

## Headless end-to-end simulation for the dungeon:
##   godot --headless -s res://scripts/dungeon/debug_sim.gd
## Boots the dungeon scene, walks the player into combat rooms, clears them by
## force, kills the warden, and descends — asserting gate, reward and floor
## state transitions along the way.

const DungeonScene := preload("res://scenes/dungeon/dungeon.tscn")

var _manager: Node3D
var _failures := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var dungeon := DungeonScene.instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	await _wait_frames(30)
	_manager = root.get_node_or_null("Dungeon")
	_check("manager present", _manager != null)
	if _manager == null:
		quit(1)
		return
	_check("depth 1 started", int(_manager.depth) == 1)
	_check("layout valid", not _manager._layout.is_empty())
	var enemies: Array = get_nodes_in_group("enemy")
	_check("monsters spawned", enemies.size() > 0)
	_check("boss present", get_nodes_in_group("enemy_boss").size() == 1)
	var combat_total: int = _manager._combat_total
	_check("combat rooms exist", combat_total >= 2)
	_check_initial_gates()

	var first_combat := _first_combat_room()
	_check("combat room found", first_combat >= 0)
	await _teleport_and_settle(_room_center(first_combat) + Vector3(0.0, 0.6, 0.0))
	await _wait_frames(10)
	var approach_key := _edge_key(int(_manager._rooms[first_combat]["parent"]), first_combat)
	_check(
		"seal on enter closed the hall door",
		bool(_manager._gates[approach_key]["collision"].disabled) == false
	)

	_kill_room(first_combat)
	await _wait_frames(20)
	var first_room_state: String = String(_manager._rooms[first_combat]["state"])
	_check("first combat room cleared", first_room_state == "cleared")
	_check(
		"cleared hall reopens its doors",
		bool(_manager._gates[approach_key]["collision"].disabled) == true
	)
	_check("other halls still sealed", int(_manager._cleared_combat) == 1)
	var boss_key := _children_of_boss_key()
	_check(
		"boss door still shut while halls stand",
		bool(_manager._gates[boss_key]["collision"].disabled) == false
	)

	_kill_all_regular()
	await _wait_frames(20)
	_check("every hall subdued", int(_manager._cleared_combat) == combat_total)
	_check(
		"boss door opens once all halls fall",
		bool(_manager._gates[boss_key]["collision"].disabled) == true
	)

	for monster in get_nodes_in_group("enemy_boss"):
		if not bool(monster.call("is_defeated")):
			monster.call("take_damage", 99999.0, monster.global_position)
	await _wait_frames(20)
	_check("boss defeated", bool(_manager._boss_dead))
	_check("descend stairs spawned", _manager._stairs != null)

	if _manager._stairs != null:
		_manager._stairs.emit_signal("used")
		await _wait_frames(30)
		_check("descended to depth 2", int(_manager.depth) == 2)
		_check("new floor has monsters", get_nodes_in_group("enemy").size() > 0)

	if _failures == 0:
		print("dungeon simulation: OK")
		quit(0)
	else:
		printerr("dungeon simulation: %d failures" % _failures)
		quit(1)

func _check(label: String, passes: bool) -> void:
	if passes:
		print("  ok    %s" % label)
		return
	_failures += 1
	printerr("  FAIL  %s" % label)

func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame

func _first_combat_room() -> int:
	for i in _manager._rooms:
		if String(_manager._rooms[i]["type"]) == "combat":
			return int(i)
	return -1

func _room_center(index: int) -> Vector3:
	return Vector3(_manager._built["rooms"][index]["center"])

func _boss_center() -> Vector3:
	return Vector3(_manager._built["rooms"][int(_manager._layout["boss"])]["center"])

func _edge_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]

func _children_of_boss_key() -> String:
	var boss_index := int(_manager._layout["boss"])
	return _edge_key(int(_manager._rooms[boss_index]["parent"]), boss_index)

func _teleport_and_settle(spot: Vector3) -> void:
	var player := get_first_node_in_group("player") as Node3D
	if player == null:
		_check("player present", false)
		return
	player.global_position = spot

func _kill_room(room_index: int) -> void:
	for monster in _manager._rooms[room_index]["monster_nodes"]:
		if is_instance_valid(monster) and not bool(monster.call("is_defeated")):
			monster.call("take_damage", 99999.0, monster.global_position)

func _kill_all_regular() -> void:
	for monster in get_nodes_in_group("enemy"):
		if monster.is_in_group("enemy_boss") or bool(monster.call("is_defeated")):
			continue
		monster.call("take_damage", 99999.0, monster.global_position)

func _check_initial_gates() -> void:
	var rooms: Array = _manager._layout["rooms"]
	for i in rooms.size():
		var parent := int(rooms[i]["parent"])
		if parent < 0:
			continue
		var key := _edge_key(parent, i)
		var gate: Dictionary = _manager._gates.get(key, {})
		if gate.is_empty():
			_check("gate exists for edge %s" % key, false)
			continue
		var collider: CollisionShape3D = gate["collision"]
		var should_shut := String(rooms[parent]["type"]) == "combat" or String(rooms[i]["type"]) == "boss"
		var is_shut := not bool(collider.disabled)
		_check(
			"initial gate %s (%s)" % [key, "shut" if should_shut else "open"],
			is_shut == should_shut
		)
