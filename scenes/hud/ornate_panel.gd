@tool
class_name OrnatePanel
extends Control

## A reusable dark panel with a gilded double border and corner studs. Used for
## every framed element of the HUD so the interface reads as one crafted set.

@export var fill_color := Color(0.055, 0.045, 0.033, 0.88)
@export var border_color := Color(0.78, 0.63, 0.34, 0.95)
@export var inner_line_color := Color(0.78, 0.63, 0.34, 0.28)
@export var border_width := 2
@export var corner_radius := 5
@export var inner_margin := 5.0
@export var corner_ornaments := true
@export var top_gem := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 6.0 or size.y < 6.0:
		return

	var frame := StyleBoxFlat.new()
	frame.bg_color = fill_color
	frame.border_color = border_color
	frame.set_border_width_all(border_width)
	frame.set_corner_radius_all(corner_radius)
	frame.anti_aliasing = true
	draw_style_box(frame, Rect2(Vector2.ZERO, size))

	var inset := float(border_width) + inner_margin
	var inner_size := size - Vector2(inset * 2.0, inset * 2.0)
	if inner_size.x > 4.0 and inner_size.y > 4.0:
		var inner_rect := Rect2(Vector2(inset, inset), inner_size)
		draw_rect(inner_rect, inner_line_color, false, 1.0)
		draw_line(
			Vector2(inset + 4.0, inset + 1.0),
			Vector2(size.x - inset - 4.0, inset + 1.0),
			Color(1.0, 0.95, 0.82, 0.07),
			1.0
		)

		if corner_ornaments:
			var stud := border_color
			_draw_diamond(Vector2(inset, inset), 3.0, stud)
			_draw_diamond(Vector2(size.x - inset, inset), 3.0, stud)
			_draw_diamond(Vector2(inset, size.y - inset), 3.0, stud)
			_draw_diamond(Vector2(size.x - inset, size.y - inset), 3.0, stud)

	if top_gem:
		var center := Vector2(size.x * 0.5, 0.0)
		draw_line(center + Vector2(-34.0, 0.0), center + Vector2(-8.0, 0.0), border_color, 1.0)
		draw_line(center + Vector2(8.0, 0.0), center + Vector2(34.0, 0.0), border_color, 1.0)
		_draw_diamond(center, 4.0, Color(0.93, 0.8, 0.5, 1.0))

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -radius),
		center + Vector2(radius, 0.0),
		center + Vector2(0.0, radius),
		center + Vector2(-radius, 0.0),
	])
	draw_colored_polygon(points, color)
