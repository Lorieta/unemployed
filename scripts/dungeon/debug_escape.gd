extends SceneTree

## Headless checks for the varied-floor systems:
##   godot --headless -s res://scripts/dungeon/debug_escape.gd
## Verifies that floor styles rotate, the periodic Collapsing Vault is a
## monster-free trap gauntlet, its exit gate/stair obey the full-clear rule,
## and a restored floor reopens the exit once every room was cleared.

const DungeonScene := preload("res://scenes/dungeon/dungeon.tscn")
const Layout := preload("res://scripts/dungeon/layout_generator.gd")

var _manager: Node3D
var _player: Node3D
var _failures := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	_check_layout_variety()
	var dungeon := DungeonScene.instantiate()
	root.add_child(dungeon)
	current_scene = dungeon
	await _wait_frames(30)
	_manager = root.get_node_or_null("Dungeon") as Node3D
	_player = get_first_node_in_group("player") as Node3D
	if _manager == null or _player == null:
		_check("harness present", false)
		_finish()
		return

	# Keep placement deterministic so the trap-type assertions don't flake.
	_manager._base_seed = 4242
	var escape_depth := Layout.ESCAPE_EVERY
	await _manager._start_floor(escape_depth)
	_check("periodic depth is a collapse floor", String(_manager._layout.get("style", "")) == "collapse")
	_check("collapse floor reports an escape archetype", String(_manager._archetype) == "escape")
	_check("collapse floor is marked as escape", bool(_manager._layout.get("escape", false)))
	var rooms: Array = _manager._layout["rooms"]
	var trap_rooms := 0
	for i in rooms.size():
		if String(rooms[i]["type"]) == "trap":
			trap_rooms += 1
			_check("trap room %d has an exit trigger" % i, _manager._built["rooms"][i].get("exit_zone") != null)
	_check("trap rooms generated", trap_rooms >= 3)
	_check("every trap room is a clear condition", int(_manager._combat_total) == trap_rooms)
	_check("escape stage has no monsters", get_nodes_in_group("enemy").is_empty())
	_check("escape stage has no boss monster", get_nodes_in_group("enemy_boss").is_empty())

	var trap_nodes := 0
	var new_types := 0
	var corridor_traps := 0
	var corridor_problems := 0
	for node in dungeon.find_children("*", "Node3D", true, false):
		if "trap_type" in node:
			trap_nodes += 1
			var kind := String(node.get("trap_type"))
			if kind in ["crusher", "beam", "sweeper"]:
				new_types += 1
			# Corridor traps hang directly off the floor chunks; chamber traps
			# are parented to their room. Compact floor hazards only, and never
			# parked inside a gatehouse.
			if node.get_parent() == _manager._chunks:
				corridor_traps += 1
				if not kind in ["spike", "flame"]:
					corridor_problems += 1
				for key in _manager._gates:
					var gate_mid: Vector3 = _manager._gates[key].get("mid", Vector3.ZERO)
					if node.position.distance_to(gate_mid) < 2.0:
						corridor_problems += 1
	_check("escape stage is trapped", trap_nodes >= 6)
	_check("advanced traps armed", new_types > 0)
	_check(
		"corridor traps are compact and clear of gatehouses",
		corridor_traps > 0 and corridor_problems == 0
	)

	var boss_index := int(_manager._layout["boss"])
	var boss_key := _edge_key(int(_manager._rooms[boss_index]["parent"]), boss_index)
	await _wait_frames(2)
	_check("exit gate shut before the gauntlet", not bool(_manager._gates[boss_key]["collision"].disabled))
	for i in rooms.size():
		if String(rooms[i]["type"]) == "trap":
			_manager._on_trap_exit(_player, i)
	await _wait_frames(10)
	_check("all trap rooms cleared", int(_manager._cleared_combat) == trap_rooms)
	_check("exit gate opens on full clear", bool(_manager._gates[boss_key]["collision"].disabled))
	_check("exit stair rises without a boss", _manager._stairs != null)

	# A cleared escape floor must keep its stair when climbed back into.
	_manager._snapshot_floor()
	await _manager._start_floor(escape_depth)
	await _wait_frames(2)
	_check("escape exit returns after restore", _manager._stairs != null)
	_check("restored escape gate stays open", bool(_manager._gates[boss_key]["collision"].disabled))

	# Normal floors use the same full-clear test for the boss door.
	await _manager._start_floor(1)
	var restore_rooms: Array = _manager._layout["rooms"]
	for i in restore_rooms.size():
		if String(restore_rooms[i]["type"]) == "combat":
			_manager._clear_combat_room(i)
	_manager._snapshot_floor()
	var restore_boss := int(_manager._layout["boss"])
	var restore_key := _edge_key(int(_manager._rooms[restore_boss]["parent"]), restore_boss)
	_check("boss gate shut before restoring", not bool(_manager._gates[restore_key]["collision"].disabled))
	await _manager._start_floor(1)
	await _wait_frames(2)
	_check("boss gate reopens after restore", bool(_manager._gates[restore_key]["collision"].disabled))
	_check("living boss still waits", not bool(_manager._boss_dead))

	_check_high_floor_mobs()
	_finish()

func _check_high_floor_mobs() -> void:
	_manager._spawn_rng.seed = 4242
	_manager.depth = 7
	var mid_mobs := {}
	for i in 60:
		mid_mobs[_manager._pick_variant()] = true
	_check("deep halls roll Grave Knights", mid_mobs.has("grave_knight"))
	_manager._spawn_rng.seed = 4242
	_manager.depth = 11
	var deep_mobs := {}
	for i in 60:
		deep_mobs[_manager._pick_variant()] = true
	_check("deepest halls roll Ash Revenants", deep_mobs.has("ash_revenant"))
	_manager.depth = 6
	_check("mid boss becomes Frost Wraith", _manager._boss_variant() == "frost_wraith")
	_manager.depth = 9
	_check("deep boss becomes Ember Tyrant", _manager._boss_variant() == "ember_tyrant")

func _check_layout_variety() -> void:
	var styles := {}
	var consecutive_repeats := 0
	var last_style := ""
	var loops := 0
	for depth in range(1, 21):
		var layout := Layout.generate(depth, 4242)
		var style := String(layout.get("style", ""))
		styles[style] = true
		if style == last_style:
			consecutive_repeats += 1
		last_style = style
		loops += int(layout.get("extra_edges", []).size())
		if depth % Layout.ESCAPE_EVERY == 0:
			_check("depth %d is the escape style" % depth, style == "collapse")
		else:
			_check("depth %d is not an escape style" % depth, style != "collapse")
	for expected in ["warren", "gauntlet", "crossroads", "ring", "collapse"]:
		_check("floor style %s appears" % expected, styles.has(expected))
	_check("consecutive floors never share a style", consecutive_repeats == 0)
	_check("maze loop corridors are generated", loops > 0)

func _edge_key(a: int, b: int) -> String:
	return "%d|%d" % [mini(a, b), maxi(a, b)]

func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame

func _check(label: String, passes: bool) -> void:
	if passes:
		print("  ok    %s" % label)
		return
	_failures += 1
	printerr("  FAIL  %s" % label)

func _finish() -> void:
	if _failures == 0:
		print("dungeon variety/escape check: OK")
		quit(0)
	else:
		printerr("dungeon variety/escape check: %d failures" % _failures)
		quit(1)
