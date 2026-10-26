extends StaticBody3D

## The Wayfarer waits by the old well. Interacting hands the conversation to the
## HUD, which owns the quest state and the dialogue overlay.

@onready var _visual: Node3D = $Visual
@onready var _head: Node3D = $Visual/Head
@onready var _lantern: Node3D = $Visual/Lantern
@onready var _light: OmniLight3D = $Visual/Lantern/Light

var _time := 0.0
var _rest_head := Vector3.ZERO

func _ready() -> void:
	add_to_group("interactable")
	_rest_head = _head.rotation

func _process(delta: float) -> void:
	_time += delta
	_visual.position.y = sin(_time * 1.1) * 0.012
	_visual.rotation.z = sin(_time * 0.7) * 0.008
	_head.rotation.z = _rest_head.z + sin(_time * 0.9 + 1.2) * 0.025
	_lantern.rotation.z = sin(_time * 0.8) * 0.05
	_light.light_energy = 1.15 + sin(_time * 8.0) * 0.1 + sin(_time * 13.0) * 0.05

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var wanted := player.global_position - global_position
		if Vector2(wanted.x, wanted.z).length_squared() < 36.0:
			var yaw := atan2(-wanted.x, -wanted.z)
			_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, 1.0 - exp(-3.0 * delta))

func get_interaction_prompt() -> String:
	return "[ E ]     Speak with the Wayfarer"

func can_interact() -> bool:
	return true

func interact(_player: Node) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_wayfarer_dialogue"):
		hud.show_wayfarer_dialogue()
