extends SceneTree

## Headless regression for dungeon loot chests and the satchel:
##   godot --headless -s res://scripts/dungeon/debug_chest.gd
## Enters the Under-Reach, opens the treasure room's Grand Cache, checks that
## gold and items actually arrive once, then descends and climbs back to verify
## the opened cache is restored instead of handing out a second haul.

const WorldScene := preload("res://scenes/world/verdant_reach.tscn")

var _failures := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var world := WorldScene.instantiate()
	root.add_child(world)
	current_scene = world
	await _wait_frames(30)

	var manager := get_first_node_in_group("dungeon_manager") as Node3D
	var player := get_first_node_in_group("player") as Node3D
	var hud := get_first_node_in_group("hud")
	var shrine := get_first_node_in_group("shrine")
	var entrance := get_first_node_in_group("dungeon_entrance")
	_check("world systems present", manager != null and player != null and hud != null and shrine != null and entrance != null)
	if manager == null or player == null or hud == null or shrine == null or entrance == null:
		_finish()
		return

	shrine.call("light_up")
	await _wait_frames(10)
	entrance.call("interact", player)
	await _wait_frames(40)
	_check("dungeon active", bool(manager.call("is_inside_dungeon")))

	var layout: Dictionary = manager.get("_layout")
	var built: Dictionary = manager.get("_built")
	var rooms: Array = built["rooms"]
	var layout_rooms: Array = layout["rooms"]
	var chest_index := -1
	for i in layout_rooms.size():
		if str(layout_rooms[i]["type"]) != "treasure":
			continue
		var record: Dictionary = rooms[i]
		if record.has("chest"):
			chest_index = i
			break
	_check("treasure room holds a Grand Cache", chest_index >= 0)
	if chest_index < 0:
		_finish()
		return

	var chest: Node = rooms[chest_index]["chest"]
	_check("cache is an interactable", chest != null and chest.has_method("interact") and bool(chest.call("can_interact")))
	var inventory = hud.get("_inventory")
	var gold_before := int(hud.get("_gold"))
	var items_before := _item_total(inventory)
	chest.call("interact", player)
	await _wait_seconds(1.0)

	var gold_after := int(hud.get("_gold"))
	var items_after := _item_total(inventory)
	_check("cache marks itself open", bool(chest.get("is_open")))
	_check("cache cannot be reopened", not bool(chest.call("can_interact")))
	_check("cache awards gold", gold_after > gold_before)
	_check("cache awards at least one item", items_after > items_before)

	var gold_settled := int(hud.get("_gold"))
	chest.call("interact", player)
	await _wait_seconds(0.4)
	_check("a second interact does not double the loot", int(hud.get("_gold")) == gold_settled)

	manager.call("_snapshot_floor")
	manager.call("_descend")
	await _wait_seconds(1.2)
	_check("descended to depth 2", int(manager.get("depth")) == 2)
	manager.call("_ascend_floor")
	await _wait_seconds(1.2)
	_check("climbed back to depth 1", int(manager.get("depth")) == 1)

	var rebuilt: Dictionary = manager.get("_built")
	var rebuilt_rooms: Array = rebuilt["rooms"]
	var restored: Node = null
	if chest_index < rebuilt_rooms.size():
		var record: Dictionary = rebuilt_rooms[chest_index]
		restored = record.get("chest")
	_check(
		"opened cache stays open on revisit",
		restored != null and is_instance_valid(restored) and bool(restored.get("is_open"))
	)

	_finish()

func _item_total(inventory) -> int:
	if inventory == null:
		return 0
	var stacks: Dictionary = inventory.call("get_save_items")
	var total := 0
	for value in stacks.values():
		total += int(value)
	return total

func _check(label: String, passes: bool) -> void:
	if passes:
		print("  ok    %s" % label)
		return
	_failures += 1
	printerr("  FAIL  %s" % label)

func _finish() -> void:
	if _failures == 0:
		print("dungeon chest check: OK")
	else:
		printerr("dungeon chest check: %d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)

func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame

func _wait_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
