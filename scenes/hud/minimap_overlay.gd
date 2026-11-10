extends Control

## Thin compass furniture drawn on top of the minimap texture.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return
	var gold := Color(0.9, 0.78, 0.5, 0.9)
	var dark := Color(0.03, 0.024, 0.018, 0.85)
	var center := size * 0.5

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.84, 0.7, 0.4, 0.45), false, 1.0)
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, 5.0), gold, 1.0)
	draw_line(Vector2(center.x, size.y), Vector2(center.x, size.y - 5.0), gold, 1.0)
	draw_line(Vector2(0.0, center.y), Vector2(5.0, center.y), gold, 1.0)
	draw_line(Vector2(size.x, center.y), Vector2(size.x - 5.0, center.y), gold, 1.0)

	draw_circle(center, 8.5, Color(0.02, 0.016, 0.012, 0.5))
	var arrow := PackedVector2Array([
		center + Vector2(0.0, -7.0),
		center + Vector2(5.0, 5.5),
		center + Vector2(0.0, 2.0),
		center + Vector2(-5.0, 5.5),
	])
	draw_colored_polygon(arrow, Color(0.97, 0.86, 0.58, 1.0))
	var outline := PackedVector2Array([
		arrow[0], arrow[1], arrow[2], arrow[3], arrow[0],
	])
	draw_polyline(outline, dark, 1.0, true)
