class_name QuickSlot
extends Control

## One gilded action slot. Handles its own frame, icon, hotkey, stack count and
## radial cooldown sweep so the skill bar and satchel can reuse the same widget.
## Skill slots are assignable: an empty slot shows a faint plus, and right-click
## asks the HUD to open its skill picker.

signal activated
signal assign_requested

const GOLD := Color(0.84, 0.7, 0.4, 1.0)
const PARCHMENT := Color(0.93, 0.88, 0.76, 1.0)
const OUTLINE := Color(0.035, 0.028, 0.02, 0.95)

@export var icon_texture: Texture2D
@export var item_name := ""
@export var hotkey := ""
@export var stack := 0
@export var selected := false
## Skill slots accept right-click assignment; inventory slots leave this false.
@export var assignable := false

var cooldown_remaining := 0.0
var cooldown_duration := 1.0

var _hotkey_label: Label
var _stack_label: Label
var _cooldown_label: Label
var _hovered := false

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	tooltip_text = _tooltip()
	resized.connect(queue_redraw)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_hotkey_label = _make_label(hotkey, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_hotkey_label.offset_left = 4.0
	_hotkey_label.offset_top = 4.0
	_hotkey_label.offset_right = -4.0
	_hotkey_label.offset_bottom = -2.0
	_hotkey_label.add_theme_font_size_override("font_size", 10)
	_hotkey_label.add_theme_color_override("font_color", GOLD)
	add_child(_hotkey_label)

	_stack_label = _make_label("", HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM)
	_stack_label.offset_left = 5.0
	_stack_label.offset_top = 4.0
	_stack_label.offset_right = -4.0
	_stack_label.offset_bottom = -2.0
	_stack_label.add_theme_font_size_override("font_size", 11)
	_stack_label.add_theme_color_override("font_color", PARCHMENT)
	add_child(_stack_label)

	_cooldown_label = _make_label("", HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_cooldown_label.add_theme_font_size_override("font_size", 13)
	_cooldown_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.76, 1.0))
	_cooldown_label.visible = false
	add_child(_cooldown_label)

	_update_stack_label()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if cooldown_remaining <= 0.0:
		return
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	if cooldown_remaining <= 0.0:
		_cooldown_label.visible = false
		set_process(false)
	else:
		_cooldown_label.text = "%.1f" % cooldown_remaining if cooldown_remaining < 10.0 else str(ceili(cooldown_remaining))
	queue_redraw()

func _make_label(text: String, h_align: HorizontalAlignment, v_align: VerticalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = h_align
	label.vertical_alignment = v_align
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 4)
	return label

func start_cooldown(seconds: float) -> void:
	if seconds <= 0.0:
		return
	cooldown_duration = seconds
	cooldown_remaining = seconds
	_cooldown_label.visible = true
	_cooldown_label.text = "%.1f" % seconds
	set_process(true)
	queue_redraw()

func set_selected(state: bool) -> void:
	if selected == state:
		return
	selected = state
	queue_redraw()

func set_stack(count: int) -> void:
	stack = count
	_update_stack_label()

func set_item(texture: Texture2D, display_name: String, count := 0) -> void:
	icon_texture = texture
	item_name = display_name
	stack = count
	tooltip_text = _tooltip()
	_update_stack_label()
	queue_redraw()

func clear_item() -> void:
	set_item(null, "", 0)

func is_empty() -> bool:
	return icon_texture == null and item_name.is_empty()

func _tooltip() -> String:
	if is_empty():
		return "Empty skill slot.  Right-click to open the skill library, or press K."
	return item_name

func _update_stack_label() -> void:
	if _stack_label == null:
		return
	_stack_label.text = str(stack) if stack > 1 else ""

func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()

func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and assignable:
		assign_requested.emit()
		accept_event()

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.05, 0.04, 0.03, 0.96)
	frame.border_color = Color(0.93, 0.79, 0.48, 1.0) if selected else (
		Color(0.66, 0.54, 0.31, 0.95) if _hovered else Color(0.42, 0.34, 0.21, 0.95)
	)
	frame.set_border_width_all(2 if selected else 1)
	frame.set_corner_radius_all(4)
	frame.anti_aliasing = true
	draw_style_box(frame, Rect2(Vector2.ZERO, size))

	var inner := Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
	var recess := StyleBoxFlat.new()
	recess.bg_color = Color(0.022, 0.018, 0.014, 0.92)
	recess.border_color = Color(0.27, 0.22, 0.14, 0.8)
	recess.set_border_width_all(1)
	recess.set_corner_radius_all(2)
	recess.anti_aliasing = true
	draw_style_box(recess, inner)

	var icon_rect := inner.grow(-3.0)
	if icon_texture != null:
		draw_texture_rect(icon_texture, icon_rect, false)
	else:
		var center := inner.get_center()
		if is_empty() and assignable:
			# A faint, waiting socket rather than a broken icon.
			var arm := minf(inner.size.x, inner.size.y) * 0.16
			var glow := Color(0.70, 0.58, 0.34, 0.40 if _hovered else 0.26)
			draw_line(center - Vector2(arm, 0.0), center + Vector2(arm, 0.0), glow, 1.5)
			draw_line(center - Vector2(0.0, arm), center + Vector2(0.0, arm), glow, 1.5)
		else:
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(0.0, -4.0),
					center + Vector2(4.0, 0.0),
					center + Vector2(0.0, 4.0),
					center + Vector2(-4.0, 0.0),
				]),
				Color(0.7, 0.58, 0.34, 0.16)
			)

	if selected:
		draw_rect(Rect2(Vector2(1.0, 1.0), size - Vector2(2.0, 2.0)), Color(0.96, 0.84, 0.52, 0.35), false, 1.0)

	if cooldown_remaining > 0.0 and cooldown_duration > 0.0:
		_draw_cooldown(inner)

func _draw_cooldown(inner: Rect2) -> void:
	var center := inner.get_center()
	var radius := minf(inner.size.x, inner.size.y) * 0.5
	var fraction := clampf(cooldown_remaining / cooldown_duration, 0.0, 1.0)
	var segments := 36
	var points := PackedVector2Array([center])
	for i in range(segments + 1):
		var angle := -PI * 0.5 + TAU * fraction * (float(i) / float(segments))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0.02, 0.016, 0.012, 0.64))
	_cooldown_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
