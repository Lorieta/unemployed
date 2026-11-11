extends Node

## The persistent half of the continue smoke test: verifies that the HUD
## restored the fabricated mid-game save.

func _ready() -> void:
	_run_checks()

func _run_checks() -> void:
	await get_tree().create_timer(1.2).timeout
	var failures := 0
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		print("CONT FAIL: no hud")
		get_tree().quit(1)
		return

	if str(hud._character_id) != "knight" or str(hud._character_name) != "Ser Aldric":
		failures += 1; print("FAIL identity: ", hud._character_id, " / ", hud._character_name)
	if int(hud._level) != 3:
		failures += 1; print("FAIL level: ", hud._level)
	if absf(float(hud._max_health) - 188.0) > 0.01 or absf(float(hud._max_mana) - 138.0) > 0.01:
		failures += 1; print("FAIL level-3 caps: ", hud._max_health, " ", hud._max_mana)
	# Saved health, plus a little passive regen while the scene settles.
	if float(hud._health) < 120.0 or float(hud._health) > 122.0:
		failures += 1; print("FAIL saved health: ", hud._health)
	if int(hud._gold) != 320:
		failures += 1; print("FAIL gold: ", hud._gold)
	if str(hud._player.get("equipped_weapon")) != "sword":
		failures += 1; print("FAIL weapon: ", hud._player.get("equipped_weapon"))
	if str(hud._slot_data[0].get("skill", "")) != "whirlwind_slash" or str(hud._slot_data[1].get("skill", "")) != "windstep":
		failures += 1; print("FAIL skills: ", hud._slot_data[0].get("skill"), " ", hud._slot_data[1].get("skill"))
	if hud._inventory.get_item_count("health") != 3 or hud._inventory.get_item_count("mana") != 2:
		failures += 1; print("FAIL items: ", hud._inventory.get_item_count("health"), " ", hud._inventory.get_item_count("mana"))
	# Level growth (2 levels) + two whetstones: 2.5*2 + 2.0*2 = 9.0 power.
	if absf(float(hud._player.call("weapon_power_bonus")) - 9.0) > 0.01:
		failures += 1; print("FAIL weapon power bonus: ", hud._player.call("weapon_power_bonus"))
	# Two levels of hide (0.005*2) + two rivets-worth is none, so 0.01.
	if absf(float(hud._player.call("mitigation_bonus")) - 0.01) > 0.001:
		failures += 1; print("FAIL mitigation bonus: ", hud._player.call("mitigation_bonus"))
	if int(hud._story_stage) != 3:
		failures += 1; print("FAIL story stage: ", hud._story_stage)

	# The lit shrine must have woken the Warden on load.
	var woke := true
	for boss in get_tree().get_nodes_in_group("enemy_boss"):
		if bool(boss.get("dormant")):
			woke = false
	if not woke:
		failures += 1; print("FAIL boss not awakened after continue")
	else:
		print("ok: Warden awake after continue")

	SaveManager.clear_save()
	if failures == 0:
		print("CONT SMOKE OK — all continue checks passed")
		get_tree().quit(0)
	else:
		print("CONT SMOKE FAILED — %d failures" % failures)
		get_tree().quit(1)
