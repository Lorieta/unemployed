extends Node

## The persistent half of the boot smoke test: waits for the world scene, then
## checks class application, locks, level-up, and the save write-back.

func _ready() -> void:
	_run_checks()

func _run_checks() -> void:
	await get_tree().create_timer(1.2).timeout
	var failures := 0
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud == null:
		print("BOOT FAIL: no hud")
		get_tree().quit(1)
		return

	if str(hud._character_id) != "arcanist":
		failures += 1; print("FAIL character_id: ", hud._character_id)
	if str(hud._character_name) != "Mereth":
		failures += 1; print("FAIL character_name: ", hud._character_name)
	if str(hud._allowed_school) != "staff":
		failures += 1; print("FAIL allowed_school: ", hud._allowed_school)
	if absf(float(hud._max_health) - 160.0) > 0.01 or absf(float(hud._max_mana) - 120.0) > 0.01:
		failures += 1; print("FAIL level-1 caps: ", hud._max_health, " ", hud._max_mana)
	if str(hud._player.get("equipped_weapon")) != "staff":
		failures += 1; print("FAIL equipped weapon: ", hud._player.get("equipped_weapon"))
	if str(hud._inventory.get_equipped()) != "staff":
		failures += 1; print("FAIL armory equip: ", hud._inventory.get_equipped())

	# Class lock: the knight's sword must not answer to the Arcanist.
	hud._on_inventory_weapon_selected("sword")
	if str(hud._player.get("equipped_weapon")) != "staff":
		failures += 1; print("FAIL weapon lock not enforced")
	else:
		print("ok: weapon lock holds")

	# School lock: a sword talent must be refused.
	hud._on_skill_chosen("vanguard_arc", 0)
	if str(hud._slot_data[0].get("skill", "")) != "":
		failures += 1; print("FAIL school lock not enforced")
	else:
		print("ok: school lock holds")
	# A staff talent should assign.
	hud._on_skill_chosen("fireball", 0)
	if str(hud._slot_data[0].get("skill", "")) != "fireball":
		failures += 1; print("FAIL staff talent assign")
	else:
		print("ok: staff talent assigned")

	# Level up: 700 XP clears the 650 first level.
	hud._add_xp(700.0)
	if int(hud._level) != 2:
		failures += 1; print("FAIL level up: ", hud._level)
	elif absf(float(hud._max_health) - 174.0) > 0.01 or absf(float(hud._max_mana) - 129.0) > 0.01:
		failures += 1; print("FAIL level-2 caps: ", hud._max_health, " ", hud._max_mana)
	elif absf(float(hud._health) - 174.0) > 0.01:
		failures += 1; print("FAIL level-up full heal: ", hud._health)
	else:
		print("ok: level up works (2, 174 HP, 129 mana)")

	# The run must have written back with the new level.
	var data: Dictionary = SaveManager.read_save_file()
	if int(data.get("level", 0)) != 2:
		failures += 1; print("FAIL saved level: ", data.get("level"))
	else:
		print("ok: save holds level 2")
	if str(data.get("weapon", "")) != "staff":
		failures += 1; print("FAIL saved weapon: ", data.get("weapon"))
	var saved_skills: Dictionary = data.get("skills", {})
	if str(saved_skills.get("1", "")) != "fireball":
		failures += 1; print("FAIL saved skill: ", saved_skills)

	SaveManager.clear_save()
	if failures == 0:
		print("BOOT SMOKE OK — all boot checks passed")
		get_tree().quit(0)
	else:
		print("BOOT SMOKE FAILED — %d failures" % failures)
		get_tree().quit(1)
