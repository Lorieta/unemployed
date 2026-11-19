extends Node

## Throwaway continue smoke test (bootstrapper): fabricates a mid-game save —
## level 3 knight, two whetstones, learned talents, a carried satchel and a lit
## shrine — then loads the world scene so the checker can verify everything is
## restored.

const CHECKER := preload("res://tests/continue_smoke_checker.gd")

func _ready() -> void:
	SaveManager.start_new_game("knight", "Ser Aldric")
	SaveManager.save_progress({
		"level": 3,
		"xp": 400.0,
		"gold": 320,
		"health": 120.0,
		"mana": 60.0,
		"skills": {"1": "whirlwind_slash", "2": "windstep"},
		"items": {"health": 3, "mana": 2},
		"purchases": {"bran": {"whetstone": 2}},
		"story_stage": 3,
		"shrine_lit": true,
	})
	SaveManager.active_data = SaveManager.continue_game()
	var checker := Node.new()
	checker.set_script(CHECKER)
	get_tree().root.add_child.call_deferred(checker)
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/verdant_reach.tscn")
