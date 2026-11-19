extends SceneTree

## Headless regression for a continued journey:
##   godot --headless -s res://scripts/dungeon/debug_persistence.gd
## Builds a saved run whose Rowan/shrine milestone is already complete, boots
## Verdant Reach against SaveManager, and checks that the shrine's lit visuals
## come back, the entrance reports itself open and E enters the Under-Reach
## without re-lighting anything.

const WorldScene := preload("res://scenes/world/verdant_reach.tscn")
const SAVE_MANAGER := preload("res://scripts/save/save_manager.gd")

var _failures := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var save := root.get_node_or_null("SaveManager")
	if save == null:
		save = Node.new()
		save.name = "SaveManager"
		save.set_script(SAVE_MANAGER)
		root.add_child(save)
	save.set("active_data", {
		"character_id": "knight",
		"character_name": "Aldric",
		"level": 5,
		"xp": 1200.0,
		"health": 120.0,
		"mana": 60.0,
		"gold": 300,
		"weapon": "sword",
		"offhand": "shield",
		"quest_stage": 3,
		"dummies_hit": 3,
		"story_stage": 4,
		"beasts_culled": 8,
		"side_stage": 0,
		"wolves_culled": 0,
		"shrine_lit": true,
		"boss_defeated": false,
		"skills": {},
		"items": {},
		"purchases": {"mira": {}, "bran": {}},
	})

	var world := WorldScene.instantiate()
	root.add_child(world)
	current_scene = world
	await _wait_frames(30)

	var shrine := get_first_node_in_group("shrine")
	var hud := get_first_node_in_group("hud")
	_check("shrine restored lit from the saved run", shrine != null and bool(shrine.call("is_lit")))
	_check("HUD reports the dungeon unlocked", hud != null and bool(hud.call("is_dungeon_unlocked")))
	var warden_wakes := true
	for boss in get_nodes_in_group("enemy_boss"):
		if str(boss.get("variant")) == "briar_warden" and bool(boss.get("dormant")):
			warden_wakes = false
	_check("a lit saved shrine wakes the Briar Warden", warden_wakes)
	var inventory = hud.get("_inventory") if hud != null else null
	_check(
		"an explicitly empty saved satchel clears the demo kit",
		inventory != null and (inventory.call("get_save_items") as Dictionary).is_empty()
	)

	var entrance := get_first_node_in_group("dungeon_entrance")
	var prompt := str(entrance.call("get_interaction_prompt")) if entrance != null else ""
	_check("entrance prompt offers the descent", prompt.contains("Descend"))

	var manager := get_first_node_in_group("dungeon_manager")
	if entrance != null:
		entrance.call("interact", null)
	await _wait_frames(10)
	_check("interact enters the Under-Reach", manager != null and bool(manager.call("is_inside_dungeon")))

	if _failures == 0:
		print("dungeon persistence check: OK")
	else:
		printerr("dungeon persistence check: %d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)

func _check(label: String, passes: bool) -> void:
	if passes:
		print("  ok    %s" % label)
		return
	_failures += 1
	printerr("  FAIL  %s" % label)

func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame
