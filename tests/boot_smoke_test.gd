extends Node

## Throwaway boot smoke test (bootstrapper): starts a new game as the Arcanist
## and swaps to the world scene. The checker node lives directly under root so
## the scene change cannot free it mid-check.

const CHECKER := preload("res://tests/boot_smoke_checker.gd")

func _ready() -> void:
	SaveManager.start_new_game("arcanist", "Mereth")
	var checker := Node.new()
	checker.set_script(CHECKER)
	get_tree().root.add_child.call_deferred(checker)
	get_tree().change_scene_to_file.call_deferred("res://scenes/world/verdant_reach.tscn")
