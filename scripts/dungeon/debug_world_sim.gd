extends SceneTree

## Headless integration simulation for the dungeon inside the surface world:
##   godot --headless -s res://scripts/dungeon/debug_world_sim.gd
## Boots Verdant Reach, checks the sealed entrance by the wayshrine, descends
## when the shrine is lit, clears floors, descends and ascends between depths,
## then climbs back out to the saved surface spot with lighting restored.

const WorldScene := preload("res://scenes/world/verdant_reach.tscn")
const Layout := preload("res://scripts/dungeon/layout_generator.gd")

var _manager: Node3D
var _failures := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var world := WorldScene.instantiate()
	root.add_child(world)
	current_scene = world
	await _wait_frames(30)

	_manager = get_first_node_in_group("dungeon_manager") as Node3D
	_check("manager node registered", _manager != null)
	if _manager == null:
		quit(1)
		return
	_check("depth is 0 before entry", int(_manager.depth) == 0)
	_check("dungeon inactive before entry", not bool(_manager.call("is_inside_dungeon")))

	var entrance := get_first_node_in_group("dungeon_entrance") as Node
	_check("entrance exists", entrance != null)
	if entrance == null:
		quit(1)
		return
	_check("entrance locked while shrine sleeps", not entrance.call("can_interact"))

	var shrine := get_first_node_in_group("shrine") as Node
	_check("wayshrine present", shrine != null)
	shrine.call("light_up")
	await _wait_frames(10)
	_check("entrance opens once the shrine is lit", entrance.call("can_interact"))

	var player := get_first_node_in_group("player") as Node3D
	_check("hero present", player != null)
	var surface_spot := player.global_position

	entrance.call("interact", player)
	await _wait_frames(40)
	_check("dungeon active after entry", bool(_manager.call("is_inside_dungeon")))
	_check("manager started depth 1", int(_manager.depth) == 1)
	_check("hero dropped below the world", player.global_position.y < -100.0)
	_check("dungeon monsters spawned", _room_monsters().size() > 0)
	var dungeon_env: Environment = _environment().environment
	_check("world lighting dimmed", dungeon_env != null and dungeon_env.background_color.v < 0.2)
	_check("sun doused", absf(_sun().light_energy - 0.04) < 0.001)

	var combat_total: int = _manager._combat_total
	_check("combat rooms exist", combat_total >= 2)

	var first_combat := _fresh_combat_room()
	await _teleport_and_settle(_room_center(first_combat) + Vector3(0.0, 0.6, 0.0))
	await _wait_frames(10)
	_check(
		"hall door seals on entry",
		bool(_manager._gates[_edge_key(int(_manager._rooms[first_combat]["parent"]), first_combat)]["collision"].disabled) == false
	)

	_kill_every_room()
	await _wait_frames(20)
	_check("all halls subdued", int(_manager._cleared_combat) >= combat_total)
	_check("warden falls without stepping in", bool(_manager._boss_dead))

	for boss in _boss_monster_nodes():
		if is_instance_valid(boss) and not bool(boss.call("is_defeated")):
			boss.call("take_damage", 99999.0, boss.global_position)
	await _wait_frames(20)
	_check("warden defeated", bool(_manager._boss_dead))
	_check("descend stairs spawned", _manager._stairs != null)

	if _manager._stairs != null:
		await _teleport_and_settle(_manager._stairs.global_position + Vector3(0.0, 0.4, 0.0))
		await _wait_frames(5)
		_manager._stairs.emit_signal("used")
		await _wait_frames(40)
	_check("descended to depth 2", int(_manager.depth) == 2)

	_ascend_stairs_node()
	await _wait_frames(40)
	_check("climbed back to depth 1", int(_manager.depth) == 1)
	var restored_cleared := 0
	for key in _manager._rooms:
		if String(_manager._rooms[key]["state"]) == "cleared" and String(_manager._rooms[key]["type"]) == "combat":
			restored_cleared += 1
	_check("cleared halls stay cleared after climb", restored_cleared >= combat_total)
	_check("warden stays defeated after climb", bool(_manager._boss_dead))
	_check("descend stairs return on the upper floor", _manager._stairs != null)
	var stair_local: Vector3 = _manager._built["stair_spot"]
	var hero_local: Vector3 = player.global_position - Vector3(0.0, float(_manager.vertical_offset), 0.0)
	_check(
		"hero waits by the stair used to descend",
		hero_local.distance_to(stair_local) < 1.5
	)

	_ascend_stairs_node()
	await _wait_frames(40)
	_check("dungeon inactive after climbing out", not bool(_manager.call("is_inside_dungeon")))
	_check(
		"hero returns to the surface spot",
		player.global_position.distance_to(surface_spot) < 2.0
	)
	var restored_env: Environment = _environment().environment
	_check("world lighting restored", restored_env != null and restored_env.background_color.v > 0.3)
	_check("sun relit", _sun().light_energy > 0.3)

	entrance.call("interact", player)
	await _wait_frames(40)
	_check("re-entry starts a fresh run", bool(_manager.call("is_inside_dungeon")) and int(_manager.depth) == 1)
	_check("fresh monsters return", _room_monsters().size() > 0)

	if _failures == 0:
		print("dungeon world simulation: OK")
		quit(0)
	else:
		printerr("dungeon world simulation: %d failures" % _failures)
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

func _environment() -> WorldEnvironment:
	for node in current_scene.find_children("*", "WorldEnvironment", true, false):
		return node as WorldEnvironment
	return null

func _sun() -> DirectionalLight3D:
	for node in current_scene.find_children("*", "DirectionalLight3D", true, false):
		return node as DirectionalLight3D
	return null

func _room_monsters() -> Array:
	var found := []
	for key in _manager._rooms:
		for monster in _manager._rooms[key]["monster_nodes"]:
			if is_instance_valid(monster):
				found.append(monster)
	return found

func _boss_monster_nodes() -> Array:
	var boss_index := int(_manager._layout["boss"])
	var room: Dictionary = _manager._rooms.get(boss_index, {})
	return room.get("monster_nodes", [])

func _fresh_combat_room() -> int:
	for key in _manager._rooms:
		if String(_manager._rooms[key]["type"]) == "combat" and String(_manager._rooms[key]["state"]) == "fresh":
			return int(key)
	return -1

func _room_center(index: int) -> Vector3:
	var record: Dictionary = _manager._built["rooms"][index]
	return (record["node"] as Node3D).global_position

func _edge_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]

func _teleport_and_settle(spot: Vector3) -> void:
	var player := get_first_node_in_group("player") as Node3D
	if player == null:
		_check("player present", false)
		return
	player.global_position = spot

func _kill_every_room() -> void:
	for key in _manager._rooms:
		for monster in _manager._rooms[key]["monster_nodes"]:
			if is_instance_valid(monster) and not bool(monster.call("is_defeated")):
				monster.call("take_damage", 99999.0, monster.global_position)

func _ascend_stairs_node() -> void:
	for stairs in get_nodes_in_group("dungeon_stairs"):
		if not is_instance_valid(stairs):
			continue
		if bool(stairs.get("ascent")):
			stairs.emit_signal("used")
			return
	_check("ascend stairs present", false)
