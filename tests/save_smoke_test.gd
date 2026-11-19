extends SceneTree

## Throwaway smoke test: SaveManager round trip + level curve math.

func _initialize() -> void:
	var failures := 0
	var manager = load("res://scripts/save/save_manager.gd").new()

	# New game defaults.
	var run: Dictionary = manager.start_new_game("ranger", "   ")
	if run["character_name"] != "Sylva":
		failures += 1; print("FAIL default name: ", run["character_name"])
	if run["weapon"] != "bow":
		failures += 1; print("FAIL default weapon: ", run["weapon"])
	if int(run["level"]) != 1 or float(run["xp"]) != 0.0:
		failures += 1; print("FAIL default level/xp")

	# Progress patch merges nested dicts without clobbering.
	manager.save_progress({
		"level": 4,
		"xp": 320.5,
		"gold": 210,
		"skills": {"1": "trueshot", "2": "multishot"},
		"purchases": {"bran": {"whetstone": 2}},
		"story_stage": 3,
		"shrine_lit": true,
	})
	manager.save_progress({"skills": {"3": "rain_of_arrows"}})

	# A fresh reader sees the merged state.
	var reader = load("res://scripts/save/save_manager.gd").new()
	var loaded: Dictionary = reader.continue_game()
	if int(loaded.get("level", 0)) != 4:
		failures += 1; print("FAIL level round trip: ", loaded.get("level"))
	if float(loaded.get("xp", 0.0)) != 320.5:
		failures += 1; print("FAIL xp round trip: ", loaded.get("xp"))
	var skills: Dictionary = loaded.get("skills", {})
	if str(skills.get("1", "")) != "trueshot" or str(skills.get("3", "")) != "rain_of_arrows":
		failures += 1; print("FAIL skill merge: ", skills)
	var bran: Dictionary = (loaded.get("purchases", {}) as Dictionary).get("bran", {})
	if int(bran.get("whetstone", 0)) != 2:
		failures += 1; print("FAIL purchases merge: ", bran)
	if not bool(loaded.get("shrine_lit", false)):
		failures += 1; print("FAIL shrine flag round trip")

	# Summary for the Continue button.
	var summary: Dictionary = reader.read_save_summary()
	if str(summary.get("character_name", "")) != "Sylva" or int(summary.get("level", 0)) != 4:
		failures += 1; print("FAIL summary: ", summary)

	# Clear leaves nothing behind.
	reader.clear_save()
	if reader.has_save_file():
		failures += 1; print("FAIL clear_save left a file")

	# Level curve: level 1 -> 650, level 2 -> 1150, level 5 -> 2650.
	var hud = load("res://scenes/hud/hud.gd").new()
	for pair in [[1, 650.0], [2, 1150.0], [5, 2650.0]]:
		var need: float = hud.xp_needed_for_level(pair[0])
		if absf(need - pair[1]) > 0.01:
			failures += 1; print("FAIL xp curve level ", pair[0], ": ", need)

	if failures == 0:
		print("SMOKE OK — all save checks passed")
	else:
		print("SMOKE FAILED — %d failures" % failures)
	quit(1 if failures > 0 else 0)
