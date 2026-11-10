@tool
class_name StatBar
extends Control

## Slim, recessed stat bar with a gold rim, a trailing "wound" ghost, and
## engraved tick marks. Values are animated so damage and healing read clearly.

@export var value := 100.0
@export var max_value := 100.0
@export var fill_color := Color(0.66, 0.16, 0.13, 1.0)
@export var ghost_color := Color(0.94, 0.84, 0.58, 0.55)
@export var rim_color := Color(0.72, 0.57, 0.31, 0.95)
@export var show_ticks := true
@export var show_gloss := true
@export var show_ghost := true

var _display := 1.0
var _ghost := 1.0
var _ghost_hold := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_display = _target_ratio()
	_ghost = _display
	queue_redraw()

func _process(delta: float) -> void:
	var target := _target_ratio()
	if Engine.is_editor_hint():
		_display = target
		_ghost = target
		queue_redraw()
		return

	if not is_equal_approx(_display, target):
		_display = lerpf(_display, target, 1.0 - exp(-9.0 * delta))
		if absf(_display - target) < 0.0015:
			_display = target
		queue_redraw()

	if _ghost_hold > 0.0:
		_ghost_hold -= delta
	elif _ghost > _display:
		_ghost = lerpf(_ghost, _display, 1.0 - exp(-4.0 * delta))
		if _ghost - _display < 0.002:
			_ghost = _display
		queue_redraw()

	if _ghost < _display:
		_ghost = _display

func set_values(current: float, maximum: float) -> void:
	var previous := _target_ratio()
	value = current
	max_value = maxf(maximum, 0.0001)
	var target := _target_ratio()
	if target < previous:
		_ghost = maxf(_ghost, previous)
		_ghost_hold = 0.45
	queue_redraw()

func _target_ratio() -> float:
	return clampf(value / maxf(max_value, 0.0001), 0.0, 1.0)

func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.025, 0.02, 0.015, 0.94)
	frame.border_color = rim_color
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(3)
	frame.anti_aliasing = true
	draw_style_box(frame, Rect2(Vector2.ZERO, size))

	var inner := Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	draw_rect(inner, Color(0.016, 0.013, 0.01, 0.95))

	var fill_width := inner.size.x * _display
	if show_ghost and _ghost > _display:
		var ghost_rect := Rect2(inner.position, Vector2(inner.size.x * _ghost, inner.size.y))
		draw_rect(ghost_rect, ghost_color)

	if fill_width > 0.5:
		var fill_rect := Rect2(inner.position, Vector2(fill_width, inner.size.y))
		_draw_gradient_fill(fill_rect)
		if show_gloss:
			draw_rect(
				Rect2(fill_rect.position, Vector2(fill_rect.size.x, fill_rect.size.y * 0.42)),
				Color(1.0, 1.0, 1.0, 0.1)
			)
		var edge := Color(fill_color.r, fill_color.g, fill_color.b, 0.95).lightened(0.35)
		draw_line(
			Vector2(fill_rect.end.x - 0.5, fill_rect.position.y + 1.0),
			Vector2(fill_rect.end.x - 0.5, fill_rect.end.y - 1.0),
			edge,
			1.2
		)

	if show_ticks:
		for i in range(1, 5):
			var x := inner.position.x + inner.size.x * (float(i) * 0.2)
			draw_line(
				Vector2(x, inner.position.y + 1.0),
				Vector2(x, inner.end.y - 1.0),
				Color(0.03, 0.025, 0.02, 0.3),
				1.0
			)

func _draw_gradient_fill(area: Rect2) -> void:
	var top := fill_color.lightened(0.24)
	var bottom := fill_color.darkened(0.2)
	var points := PackedVector2Array([
		area.position,
		Vector2(area.end.x, area.position.y),
		area.end,
		Vector2(area.position.x, area.end.y),
	])
	var colors := PackedColorArray([top, top, bottom, bottom])
	draw_polygon(points, colors)
