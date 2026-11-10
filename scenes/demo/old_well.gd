extends StaticBody3D

## The old well by the Wayfarer's camp. Looking into it is a small piece of
## flavour that proves interaction works away from the quest-giver.

@onready var _water: MeshInstance3D = $Water
var _time := 0.0

func _ready() -> void:
	add_to_group("interactable")

func _process(delta: float) -> void:
	_time += delta
	_water.position.y = 0.55 + sin(_time * 1.2) * 0.008

func get_interaction_prompt() -> String:
	return "[ E ]     Look into the old well"

func can_interact() -> bool:
	return true

func interact(_player: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_well_dialogue"):
		hud.show_well_dialogue()
