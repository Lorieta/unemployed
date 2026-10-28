extends Control

## Title screen. A dark parchment-and-gold landing: begin the journey, adjust
## preferences, or leave. Begin swaps to the world scene; the in-game ESC menu
## handles everything from there.

const WORLD_SCENE := "res://scenes/world/verdant_reach.tscn"
const MENU_SETTINGS := preload("res://scenes/main/menu_settings.gd")

const PARCHMENT := Color(0.92, 0.87, 0.76, 1.0)
const MUTED := Color(0.63, 0.58, 0.48, 1.0)
const GOLD := Color(0.84, 0.7, 0.4, 1.0)
const GOLD_BRIGHT := Color(0.97, 0.86, 0.58, 1.0)
const OUTLINE := Color(0.03, 0.024, 0.018, 0.95)

var _settings: MenuSettingsPanel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_title()
	_build_buttons()
	_settings = MENU_SETTINGS.new() as MenuSettingsPanel
	add_child(_settings)

func _build_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.024, 0.019, 0.014, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# A faint horizon glow keeps the black from reading as a void.
	var glow := ColorRect.new()
	glow.color = Color(0.16, 0.12, 0.06, 0.35)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_top = 240.0
	glow.color = Color(0.055, 0.042, 0.026, 1.0)
	add_child(glow)

	var frame_rule := ColorRect.new()
	frame_rule.color = Color(0.84, 0.7, 0.4, 0.32)
	frame_rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_rule.offset_top = 168.0
	frame_rule.offset_bottom = -168.0
	frame_rule.offset_left = 120.0
	frame_rule.offset_right = -120.0
	add_child(frame_rule)

func _build_title() -> void:
	var title := Label.new()
	title.text = "UNEMPLOYED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 140.0
	title.offset_bottom = 230.0
	title.offset_left = -400.0
	title.offset_right = 400.0
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", PARCHMENT)
	title.add_theme_color_override("font_outline_color", OUTLINE)
	title.add_theme_constant_override("outline_size", 10)
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "A WAYFARER WITHOUT A POST"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_top = 226.0
	subtitle.offset_bottom = 250.0
	subtitle.offset_left = -400.0
	subtitle.offset_right = 400.0
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", GOLD)
	subtitle.add_theme_color_override("font_outline_color", OUTLINE)
	subtitle.add_theme_constant_override("outline_size", 3)
	add_child(subtitle)

func _build_buttons() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_left = -170.0
	column.offset_top = -40.0
	column.offset_right = 170.0
	column.offset_bottom = 160.0
	add_child(column)

	var begin := _make_button("Begin the Journey")
	begin.add_theme_font_size_override("font_size", 15)
	begin.pressed.connect(_on_begin_pressed)
	column.add_child(begin)

	var settings := _make_button("Settings")
	settings.pressed.connect(_on_settings_pressed)
	column.add_child(settings)

	var quit := _make_button("Quit Game")
	quit.pressed.connect(_on_quit_pressed)
	column.add_child(quit)

	var footer := Label.new()
	footer.text = "WASD to move  ·  Mouse to aim  ·  ESC to pause"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_top = -64.0
	footer.offset_bottom = -40.0
	footer.offset_left = -400.0
	footer.offset_right = 400.0
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", MUTED)
	footer.add_theme_color_override("font_outline_color", OUTLINE)
	footer.add_theme_constant_override("outline_size", 2)
	add_child(footer)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340.0, 44.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.07, 0.056, 0.04, 0.95), Color(0.48, 0.39, 0.24, 1.0)))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.13, 0.105, 0.07, 0.98), GOLD))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.035, 0.028, 0.02, 0.98), GOLD))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.anti_aliasing = true
	return box

func _on_begin_pressed() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_settings_pressed() -> void:
	_settings.open()

func _on_quit_pressed() -> void:
	get_tree().quit()
