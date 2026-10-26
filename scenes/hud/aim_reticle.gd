extends Control

## The game's own mouse pointer. A gilded ring follows the OS pointer across the
## whole screen, a dashed line runs from the hero to the point being aimed at,
## and the system cursor is hidden so the pointer belongs to the adventure rather
## than the desktop. The reticle never eats clicks: it is pure HUD furniture.

const GOLD := Color(0.97, 0.86, 0.58, 0.96)
const GOLD_DIM := Color(0.84, 0.7, 0.4, 0.48)
const OUTLINE := Color(0.035, 0.028, 0.02, 0.82)

@export var accent := GOLD
@export var draw_ring := true
@export var line_reach := 16.0

var _pulse := 0.0
var _aim_enabled := true
var _cursor := Vector2.ZERO
var _hovering := false
var _player: Node3D
var _camera: Camera3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 200
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	set_process(true)
	queue_redraw()

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func set_aim_visible(active: bool) -> void:
	_aim_enabled = active

## Kept so older callers keep working; the cursor itself is always drawn now.
func set_active(active: bool) -> void:
	set_aim_visible(active)

func is_active() -> bool:
	return _aim_enabled

func _process(delta: float) -> void:
	_pulse += delta
	_cursor = get_viewport().get_mouse_position()
	_resolve_world()
	var hovered := get_viewport().gui_get_hovered_control()
	_hovering = hovered != null and hovered != self
	queue_redraw()

func _resolve_world() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_camera = get_viewport().get_camera_3d()

func _draw() -> void:
	if not _cursor.x > 0.0 and not _cursor.y > 0.0:
		_cursor = get_viewport().get_mouse_position()
	if _aim_enabled:
		_draw_aim_line()
	_draw_cursor()

## Dotted line from the hero's chest to the pointer. The dots fade toward the
## hero so the line reads as direction rather than a hard tether.
func _draw_aim_line() -> void:
	if _player == null or _camera == null or not is_instance_valid(_player):
		return
	if _camera.is_position_behind(_player.global_position + Vector3(0.0, 1.0, 0.0)):
		return
	var origin := _camera.unproject_position(_player.global_position + Vector3(0.0, 1.0, 0.0))
	var to := _cursor
	var span := origin.distance_to(to)
	if span < 34.0:
		return
	var direction := (to - origin) / span
	var start := origin + direction * 26.0
	var end := to - direction * (line_reach + 6.0)
	var length := start.distance_to(end)
	if length < 8.0:
		return
	var step := 9.0
	var travelled := 0.0
	while travelled < length:
		var from_point := start + direction * travelled
		var dash := minf(4.5, length - travelled)
		var t := travelled / length
		var fade := clampf(t * 2.4, 0.12, 1.0) * (1.0 - clampf((t - 0.86) / 0.14, 0.0, 1.0))
		var dot_alpha := 0.52 * fade
		draw_line(from_point, from_point + direction * dash, Color(accent.r, accent.g, accent.b, dot_alpha), 1.8, true)
		travelled += step

func _draw_cursor() -> void:
	var center := _cursor
	var breathe := 1.0 + sin(_pulse * 2.8) * 0.06
	var radius := (9.5 if not _hovering else 12.0) * breathe
	var glow := 0.24 + sin(_pulse * 3.2) * 0.06
	if _hovering:
		glow = 0.5

	# Soft halo so the pointer stays legible over dark grass and bright stone.
	draw_circle(center, radius + 4.0, Color(accent.r, accent.g, accent.b, 0.07 + glow * 0.10))
	draw_circle(center, radius + 1.5, Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.20))

	if draw_ring:
		draw_arc(center, radius, 0.0, TAU, 32, Color(accent.r, accent.g, accent.b, 0.78), 1.6, true)
		draw_arc(center, radius + 2.4, 0.0, TAU, 32, Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.24), 1.0, true)

	# Four cardinal ticks, like the reticle of an old adventure game.
	for i in 4:
		var angle := float(i) * PI * 0.5
		var dir := Vector2(cos(angle), sin(angle))
		var inner := center + dir * (radius + 2.0)
		var outer := center + dir * (radius + 6.5)
		draw_line(inner, outer, OUTLINE, 3.4, true)
		draw_line(inner, outer, accent, 1.7, true)

	# The precise aim dot.
	var dot := 2.4 if not _hovering else 3.0
	draw_circle(center, dot + 1.2, Color(OUTLINE.r, OUTLINE.g, OUTLINE.b, 0.7))
	draw_circle(center, dot, accent)
	if _hovering:
		draw_arc(center, radius + 8.0, -PI * 0.85, -PI * 0.15, 12, Color(accent.r, accent.g, accent.b, 0.45), 1.4, true)
