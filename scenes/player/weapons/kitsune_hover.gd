extends Node3D

## A small floating fox-spirit flame. Bobs and spins gently on its own so the
## relic feels alive even when it is simply resting above the caster's palm.

@export var hover_height := 0.035
@export var hover_speed := 2.1
@export var spin_speed := 1.15

## The character drives these two values so the spirit can trail behind a run,
## lunge forward on a cast, and spin faster while it is being channeled.
var energy := 1.0
var motion_offset := Vector3.ZERO

var _base_position := Vector3.ZERO
var _time := 0.0

@onready var _ring_a: Node3D = get_node_or_null("RingA")
@onready var _ring_b: Node3D = get_node_or_null("RingB")
@onready var _tails: Node3D = get_node_or_null("Tails")
@onready var _core: Node3D = get_node_or_null("Core")

func _ready() -> void:
	_base_position = position
	_time = randf() * TAU

func _process(delta: float) -> void:
	_time += delta
	var pulse := maxf(energy, 0.15)
	position = _base_position + motion_offset + Vector3(
		sin(_time * hover_speed * 0.53) * hover_height * 0.45,
		sin(_time * hover_speed) * hover_height * pulse,
		cos(_time * hover_speed * 0.67) * hover_height * 0.4
	)
	if _core != null:
		_core.rotation.y += spin_speed * pulse * delta
		_core.rotation.x = sin(_time * 1.3) * 0.12
	if _ring_a != null:
		_ring_a.rotation.y += spin_speed * 0.8 * pulse * delta
		_ring_a.rotation.z = 0.4 + sin(_time * 0.9) * 0.18
	if _ring_b != null:
		_ring_b.rotation.x += spin_speed * 0.55 * pulse * delta
		_ring_b.rotation.z = -0.7 + cos(_time * 1.1) * 0.2
	if _tails != null:
		_tails.rotation.y = sin(_time * 1.6) * 0.16
		_tails.rotation.z = sin(_time * 1.2 + 0.7) * 0.08

func set_motion_offset(offset: Vector3) -> void:
	motion_offset = offset

func set_energy(value: float) -> void:
	energy = maxf(0.0, value)
