extends StaticBody3D

## A straw practice dummy that takes hits, wobbles, shows floating damage and
## resets itself a moment after being knocked over.

signal struck(amount: float)

@export var display_name := "PRACTICE DUMMY"
@export var max_health := 140.0
@export var reset_delay := 2.4

@onready var _pivot: Node3D = $Pivot
@onready var _name_label: Label3D = $NameLabel

var health := 140.0
var _rest_rotation := Vector3.ZERO
var _busy := false
var _flash_overlay := StandardMaterial3D.new()
var _time := 0.0

func _ready() -> void:
	add_to_group("training_dummy")
	health = max_health
	_rest_rotation = _pivot.rotation
	_flash_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_overlay.albedo_color = Color(1.0, 0.92, 0.72, 0.0)
	_flash_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_apply_overlay()
	_name_label.text = display_name

func _process(delta: float) -> void:
	_time += delta
	if not _busy:
		_pivot.rotation.z = _rest_rotation.z + sin(_time * 1.4) * 0.006

func can_interact() -> bool:
	return false

func take_damage(amount: float, hit_position := Vector3.ZERO) -> void:
	health = maxf(0.0, health - amount)
	_spawn_number(amount, hit_position)
	_flash()
	_wobble()
	struck.emit(amount)
	if health <= 0.0 and not _busy:
		_knock_down()

func _apply_overlay() -> void:
	for child in _pivot.get_children():
		if child is MeshInstance3D and child.name != "Shadow":
			(child as MeshInstance3D).material_overlay = _flash_overlay

func _flash() -> void:
	_flash_overlay.albedo_color.a = 0.5
	var tween := create_tween()
	tween.tween_property(_flash_overlay, "albedo_color:a", 0.0, 0.18)

func _wobble() -> void:
	if _busy:
		return
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:z", _rest_rotation.z + 0.13, 0.07)
	tween.tween_property(_pivot, "rotation:z", _rest_rotation.z - 0.09, 0.1)
	tween.tween_property(_pivot, "rotation:z", _rest_rotation.z + 0.04, 0.09)
	tween.tween_property(_pivot, "rotation:z", _rest_rotation.z, 0.1)

func _knock_down() -> void:
	_busy = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_pivot, "rotation:z", _rest_rotation.z + 1.45, 0.35).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_pivot, "position:y", -0.12, 0.35)
	await get_tree().create_timer(reset_delay).timeout
	if not is_inside_tree():
		return
	health = max_health
	var reset := create_tween()
	reset.set_parallel(true)
	reset.tween_property(_pivot, "rotation:z", _rest_rotation.z, 0.35).set_trans(Tween.TRANS_BACK)
	reset.tween_property(_pivot, "position:y", 0.0, 0.35)
	reset.chain().tween_callback(func() -> void:
		_busy = false
		_spawn_number(max_health, global_position + Vector3(0.0, 1.8, 0.0), "RESTORED")
	)

func _spawn_number(amount: float, hit_position: Vector3, prefix := "") -> void:
	var label := Label3D.new()
	label.text = ("%s%d" % [prefix, roundi(amount)]) if prefix.is_empty() else ("%s" % prefix)
	label.font_size = 64
	label.pixel_size = 0.0045
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 22
	label.outline_modulate = Color(0.05, 0.035, 0.02, 1.0)
	label.modulate = Color(1.0, 0.86, 0.5, 1.0)
	label.render_priority = 2
	get_tree().current_scene.add_child(label)
	if hit_position.length_squared() < 0.001:
		hit_position = global_position + Vector3(0.0, 1.45, 0.0)
	label.global_position = hit_position + Vector3(randf_range(-0.18, 0.18), 0.35, randf_range(-0.18, 0.18))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 0.75, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.18)
	tween.chain().tween_callback(label.queue_free)
