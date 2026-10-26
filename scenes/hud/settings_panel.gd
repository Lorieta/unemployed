class_name SettingsPanel
extends OverlayPanel

## A small, working settings page: fullscreen, master volume, the vignette and
## the control-hint card. Every switch takes effect immediately.

signal hints_toggled(enabled: bool)
signal vignette_toggled(enabled: bool)
signal restart_requested

var _hints_check: CheckButton
var _vignette_check: CheckButton
var _volume_slider: HSlider
var _volume_value: Label

func _ready() -> void:
	title = "SETTINGS"
	subtitle = "THE WAYFARER'S PREFERENCES"
	panel_size = Vector2(760.0, 560.0)
	super._ready()

func _build_content() -> void:
	add_heading("DISPLAY")
	_make_check_row("Fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, _on_fullscreen_toggled)
	_vignette_check = _make_check_row("Cinematic vignette", true, _on_vignette_toggled)
	add_rule()

	add_heading("AUDIO")
	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 16)
	volume_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var volume_label := Label.new()
	volume_label.text = "Master volume"
	volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_label.add_theme_font_size_override("font_size", 13)
	volume_label.add_theme_color_override("font_color", PARCHMENT)
	volume_label.add_theme_color_override("font_outline_color", OUTLINE)
	volume_label.add_theme_constant_override("outline_size", 2)
	volume_row.add_child(volume_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 100.0
	_volume_slider.step = 1.0
	_volume_slider.custom_minimum_size = Vector2(250.0, 24.0)
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.value = clampf(db_to_linear(AudioServer.get_bus_volume_db(0)) * 100.0, 0.0, 100.0)
	_volume_slider.value_changed.connect(_on_volume_changed)
	volume_row.add_child(_volume_slider)

	_volume_value = Label.new()
	_volume_value.custom_minimum_size = Vector2(52.0, 24.0)
	_volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_volume_value.text = "%d%%" % roundi(_volume_slider.value)
	_volume_value.add_theme_font_size_override("font_size", 12)
	_volume_value.add_theme_color_override("font_color", GOLD_BRIGHT)
	_volume_value.add_theme_color_override("font_outline_color", OUTLINE)
	_volume_value.add_theme_constant_override("outline_size", 2)
	volume_row.add_child(_volume_value)
	content_box.add_child(volume_row)
	add_rule()

	add_heading("INTERFACE")
	_hints_check = _make_check_row("Show control hints", true, _on_hints_toggled)
	add_paragraph("The hint card sits above the coin purse and lists every control in the demo.", MUTED, 11)
	add_rule()

	add_heading("THE DEMO")
	add_paragraph("This is a small hand-built adventure slice. All five weapons are live, every dummy can be struck, and the Wayfarer has an errand for you.", PARCHMENT, 12)
	add_action_button("Restart the demo", _on_restart)
	add_paragraph("Restarting returns Aldric to the road beside the old well.", MUTED, 11)

func set_hints_enabled(enabled: bool) -> void:
	if _hints_check != null:
		_hints_check.set_pressed_no_signal(enabled)

func set_vignette_enabled(enabled: bool) -> void:
	if _vignette_check != null:
		_vignette_check.set_pressed_no_signal(enabled)

func _make_check_row(text: String, pressed: bool, callback: Callable) -> CheckButton:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", PARCHMENT)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 2)
	row.add_child(label)

	var check := CheckButton.new()
	check.button_pressed = pressed
	check.focus_mode = Control.FOCUS_NONE
	check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	check.add_theme_color_override("font_color", PARCHMENT)
	check.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	check.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
	check.toggled.connect(callback)
	row.add_child(check)
	content_box.add_child(row)
	return check

func _on_fullscreen_toggled(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vignette_toggled(enabled: bool) -> void:
	vignette_toggled.emit(enabled)

func _on_hints_toggled(enabled: bool) -> void:
	hints_toggled.emit(enabled)

func _on_volume_changed(value: float) -> void:
	var linear := clampf(value / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(0, linear <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.001)))
	_volume_value.text = "%d%%" % roundi(value)

func _on_restart() -> void:
	restart_requested.emit()
