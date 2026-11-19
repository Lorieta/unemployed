extends SceneTree

const MONSTER := preload("res://scenes/world/monster.tscn")

var _failures := 0

func _initialize() -> void:
	_run()

func _run() -> void:
	var boss := MONSTER.instantiate()
	boss.boss = true
	boss.boss_respawns = true
	boss.boss_respawn_delay = 0.2
	boss.max_health = 50.0
	root.add_child(boss)
	await process_frame
	boss.call("mark_defeated")
	_check("boss is down immediately", bool(boss.call("is_defeated")))
	_check("boss is hidden while down", not boss.visible)
	await create_timer(0.55).timeout
	_check("boss returns after its delay", not bool(boss.call("is_defeated")))
	_check("boss is visible after returning", boss.visible)
	_check("boss health is restored", float(boss.get("health")) == 50.0)
	if _failures == 0:
		print("boss respawn check: OK")
	else:
		printerr("boss respawn check: %d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)

func _check(label: String, passes: bool) -> void:
	if passes:
		print("  ok    %s" % label)
		return
	_failures += 1
	printerr("  FAIL  %s" % label)
