extends SceneTree

## Headless self-check for the dungeon generator:
##   godot --headless -s res://scripts/dungeon/debug_check.gd
## Asserts that every layout is a connected tree with a deepest boss room,
## one treasure room, and the right number of combat rooms for the depth.

const Layout := preload("res://scripts/dungeon/layout_generator.gd")

func _initialize() -> void:
	var checked := 0
	var failures := 0
	for depth in range(1, 21):
		for attempt in range(6):
			var seed_value := depth * 10007 + attempt * 3517
			checked += 1
			var problems := Layout.validate(Layout.generate(depth, seed_value))
			if not problems.is_empty():
				failures += 1
				for problem in problems:
					printerr("depth=%d seed=%d  %s" % [depth, seed_value, problem])
	if failures == 0:
		print("dungeon layout check: %d layouts OK" % checked)
	quit(1 if failures > 0 else 0)
