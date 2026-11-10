class_name OverlayPanel
extends Control

## Shared parchment-and-gold overlay used by the journal, map, settings and
## dialogue. Builds its own frame, dim layer, heading and scrollable content so
## every screen in the demo feels like part of the same crafted set.

signal closed
signal opened

const ORNATE := preload("res://scenes/hud/ornate_panel.gd")

const PARCHMENT := Color(0.92, 0.87, 0.76, 1.0)
const MUTED := Color(0.63, 0.58, 0.48, 1.0)
const GOLD := Color(0.84, 0.7, 0.4, 1.0)
const GOLD_BRIGHT := Color(0.97, 0.86, 0.58, 1.0)
const OUTLINE := Color(0.03, 0.024, 0.018, 0.95)

@export var title := ""
@export var subtitle := ""
@export var panel_size := Vector2(840.0, 570.0)

var content_box: VBoxContainer
var _panel: Control
var _title_label: Label
var _subtitle_label: Label
var _tween: Tween

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_build_content()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.008, 0.006, 0.004, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	_panel = Control.new()
	_panel.set_script(ORNATE)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -panel_size.x * 0.5
	_panel.offset_top = -panel_size.y * 0.5
	_panel.offset_right = panel_size.x * 0.5
	_panel.offset_bottom = panel_size.y * 0.5
	_panel.set("fill_color", Color(0.05, 0.041, 0.03, 0.975))
	_panel.set("border_color", Color(0.8, 0.65, 0.35, 1.0))
	_panel.set("top_gem", true)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	_title_label = _make_label(title, Vector2(36.0, 16.0), Vector2(panel_size.x - 120.0, 34.0), 24, PARCHMENT)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_constant_override("outline_size", 5)
	_panel.add_child(_title_label)

	_subtitle_label = _make_label(subtitle, Vector2(36.0, 46.0), Vector2(panel_size.x - 72.0, 18.0), 9, MUTED)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_subtitle_label)

	var divider := ColorRect.new()
	divider.color = Color(0.84, 0.7, 0.4, 0.32)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.position = Vector2(36.0, 74.0)
	divider.size = Vector2(panel_size.x - 72.0, 1.0)
	_panel.add_child(divider)

	var close := Button.new()
	close.text = "×"
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -46.0
	close.offset_top = 12.0
	close.offset_right = -14.0
	close.offset_bottom = 40.0
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", GOLD)
	close.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	close.add_theme_stylebox_override("normal", _make_style(Color(0.05, 0.04, 0.03, 0.9), Color(0.44, 0.36, 0.22, 0.95)))
	close.add_theme_stylebox_override("hover", _make_style(Color(0.12, 0.1, 0.065, 0.96), GOLD))
	close.add_theme_stylebox_override("pressed", _make_style(Color(0.03, 0.024, 0.018, 0.98), GOLD))
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(close_panel)
	_panel.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(36.0, 92.0)
	scroll.size = Vector2(panel_size.x - 72.0, panel_size.y - 132.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(scroll)

	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 9)
	scroll.add_child(content_box)

	var footer := _make_label("Press ESC or × to close", Vector2(36.0, panel_size.y - 34.0), Vector2(panel_size.x - 72.0, 18.0), 9, Color(0.5, 0.46, 0.38, 1.0))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(footer)

func _build_content() -> void:
	pass

func _make_label(text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	return label

func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.anti_aliasing = true
	return box

func add_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	content_box.add_child(label)
	return label

func add_paragraph(text: String, color := PARCHMENT, font_size := 13) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 2)
	content_box.add_child(label)
	return label

func add_rule() -> void:
	var rule := ColorRect.new()
	rule.color = Color(0.84, 0.7, 0.4, 0.22)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_box.add_child(rule)

func add_spacer(height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_box.add_child(spacer)

func add_row(left_text: String, right_text: String, right_color := GOLD_BRIGHT) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := Label.new()
	left.text = left_text
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_font_size_override("font_size", 12)
	left.add_theme_color_override("font_color", PARCHMENT)
	left.add_theme_color_override("font_outline_color", OUTLINE)
	left.add_theme_constant_override("outline_size", 2)
	row.add_child(left)
	var right := Label.new()
	right.text = right_text
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_theme_font_size_override("font_size", 12)
	right.add_theme_color_override("font_color", right_color)
	right.add_theme_color_override("font_outline_color", OUTLINE)
	right.add_theme_constant_override("outline_size", 2)
	row.add_child(right)
	content_box.add_child(row)
	return row

func add_action_button(text: String, callback: Callable) -> Button:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 36.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.07, 0.056, 0.04, 0.95), Color(0.48, 0.39, 0.24, 1.0)))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.13, 0.105, 0.07, 0.98), GOLD))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.035, 0.028, 0.02, 0.98), GOLD))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(callback)
	row.add_child(button)
	content_box.add_child(row)
	return button

func clear_content() -> void:
	for child in content_box.get_children():
		child.queue_free()

func set_header(new_title: String, new_subtitle: String) -> void:
	title = new_title
	subtitle = new_subtitle
	if _title_label != null:
		_title_label.text = new_title
	if _subtitle_label != null:
		_subtitle_label.text = new_subtitle

func open() -> void:
	if visible:
		return
	_kill_tween()
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	opened.emit()

func close_panel() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.11)
	_tween.tween_callback(func() -> void:
		visible = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		closed.emit()
	)

func toggle_panel() -> void:
	if visible:
		close_panel()
	else:
		open()

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_panel()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_panel()
		get_viewport().set_input_as_handled()
