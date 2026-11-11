extends Control

## Title screen. A dark parchment-and-gold landing that offers Continue (the
## previous save, if one exists) and New Journey: pick one of the five wayfarer
## characters, name them, and set out. Begin swaps to the world scene; the
## in-game ESC menu handles everything from there.

const WORLD_SCENE := "res://scenes/world/verdant_reach.tscn"
const MENU_SETTINGS := preload("res://scenes/main/menu_settings.gd")

const PARCHMENT := Color(0.92, 0.87, 0.76, 1.0)
const MUTED := Color(0.63, 0.58, 0.48, 1.0)
const GOLD := Color(0.84, 0.7, 0.4, 1.0)
const GOLD_BRIGHT := Color(0.97, 0.86, 0.58, 1.0)
const OUTLINE := Color(0.03, 0.024, 0.018, 0.95)
const CARD_FILL := Color(0.07, 0.056, 0.04, 0.95)
const CARD_FILL_HOVER := Color(0.13, 0.105, 0.07, 0.98)

var _settings: MenuSettingsPanel
var _content: Control
var _selected_character := "knight"
var _name_edit: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_title()
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_settings = MENU_SETTINGS.new() as MenuSettingsPanel
	add_child(_settings)
	_show_landing()


func _build_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.024, 0.019, 0.014, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# A faint horizon glow keeps the black from reading as a void.
	var glow := ColorRect.new()
	glow.color = Color(0.055, 0.042, 0.026, 1.0)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.offset_top = 240.0
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
	title.offset_top = 60.0
	title.offset_bottom = 150.0
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
	subtitle.offset_top = 146.0
	subtitle.offset_bottom = 170.0
	subtitle.offset_left = -400.0
	subtitle.offset_right = 400.0
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", GOLD)
	subtitle.add_theme_color_override("font_outline_color", OUTLINE)
	subtitle.add_theme_constant_override("outline_size", 3)
	add_child(subtitle)


func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()


## The landing view: Continue (only when a save exists), New Journey,
## Settings, and Quit, stacked in the center column.
func _show_landing() -> void:
	_clear_content()
	_selected_character = "knight"

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.offset_left = -170.0
	column.offset_top = -40.0
	column.offset_right = 170.0
	column.offset_bottom = 160.0
	_content.add_child(column)

	var has_save := SaveManager.has_save_file()
	if has_save:
		var summary := SaveManager.read_save_summary()
		var continue_button := _make_button("Continue")
		continue_button.add_theme_font_size_override("font_size", 15)
		continue_button.pressed.connect(_on_continue_pressed)
		column.add_child(continue_button)

		var summary_text := "%s  ·  %s\nLEVEL %d" % [
			str(summary.get("character_name", "—")).to_upper(),
			str(summary.get("title", "")),
			int(summary.get("level", 1)),
		]
		var summary_label := _make_label(summary_text, 10, MUTED)
		summary_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		summary_label.custom_minimum_size = Vector2(0.0, 34.0)
		column.add_child(summary_label)

	var begin := _make_button("New Journey")
	begin.add_theme_font_size_override("font_size", 15)
	begin.pressed.connect(_on_new_journey_pressed)
	column.add_child(begin)

	var settings := _make_button("Settings")
	settings.pressed.connect(_on_settings_pressed)
	column.add_child(settings)

	var quit := _make_button("Quit Game")
	quit.pressed.connect(_on_quit_pressed)
	column.add_child(quit)

	var footer := _make_label("WASD to move  ·  Mouse to aim  ·  ESC to pause", 10, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	footer.offset_top = -64.0
	footer.offset_bottom = -40.0
	footer.offset_left = -400.0
	footer.offset_right = 400.0
	_content.add_child(footer)


## The New Journey view: five character cards (each locked to one weapon and
## one school), a name field pre-filled with the chosen hero's default name,
## and Begin / Back.
func _show_character_select() -> void:
	_clear_content()

	var heading := _make_label("CHOOSE YOUR WAYFARER", 16, PARCHMENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.set_anchors_preset(Control.PRESET_CENTER_TOP)
	heading.offset_top = 200.0
	heading.offset_bottom = 230.0
	heading.offset_left = -400.0
	heading.offset_right = 400.0
	_content.add_child(heading)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	cards_row.set_anchors_preset(Control.PRESET_CENTER)
	cards_row.offset_left = -516.0
	cards_row.offset_top = -120.0
	cards_row.offset_right = 516.0
	cards_row.offset_bottom = 190.0
	_content.add_child(cards_row)

	for character_id in CharacterLibrary.ORDER:
		cards_row.add_child(_make_character_card(character_id))

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.set_anchors_preset(Control.PRESET_CENTER)
	name_row.offset_left = -260.0
	name_row.offset_top = 220.0
	name_row.offset_right = 260.0
	name_row.offset_bottom = 270.0
	_content.add_child(name_row)

	var name_label := _make_label("NAME", 11, GOLD)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(56.0, 36.0)
	name_row.add_child(name_label)

	_name_edit = LineEdit.new()
	_name_edit.text = str(CharacterLibrary.get_character(_selected_character).get("name", "Aldric"))
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(240.0, 36.0)
	_name_edit.caret_blink = true
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.focus_mode = Control.FOCUS_ALL
	_name_edit.add_theme_font_size_override("font_size", 13)
	_name_edit.add_theme_color_override("font_color", PARCHMENT)
	_name_edit.add_theme_color_override("font_outline_color", OUTLINE)
	_name_edit.add_theme_constant_override("outline_size", 3)
	_name_edit.add_theme_stylebox_override("normal", _make_style(Color(0.035, 0.028, 0.02, 0.95), Color(0.48, 0.39, 0.24, 1.0)))
	_name_edit.add_theme_stylebox_override("focus", _make_style(Color(0.07, 0.056, 0.04, 0.95), GOLD))
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_begin_new_game_pressed())
	name_row.add_child(_name_edit)

	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.set_anchors_preset(Control.PRESET_CENTER)
	button_row.offset_left = -260.0
	button_row.offset_top = 290.0
	button_row.offset_right = 260.0
	button_row.offset_bottom = 340.0
	_content.add_child(button_row)

	var back := _make_button("Back")
	back.custom_minimum_size = Vector2(150.0, 44.0)
	back.pressed.connect(_show_landing)
	button_row.add_child(back)

	var begin := _make_button("Begin the Journey")
	begin.custom_minimum_size = Vector2(240.0, 44.0)
	begin.add_theme_font_size_override("font_size", 15)
	begin.pressed.connect(_on_begin_new_game_pressed)
	button_row.add_child(begin)


func _make_character_card(character_id: String) -> Button:
	var info: Dictionary = CharacterLibrary.get_character(character_id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(198.0, 320.0)
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("normal", _make_style(CARD_FILL, Color(0.48, 0.39, 0.24, 1.0)))
	card.add_theme_stylebox_override("hover", _make_style(CARD_FILL_HOVER, GOLD))
	card.add_theme_stylebox_override("pressed", _make_style(CARD_FILL_HOVER, GOLD_BRIGHT))
	card.set_meta("character_id", character_id)
	card.pressed.connect(func() -> void: _select_character(character_id))
	_apply_card_selection(card, character_id == _selected_character)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10.0
	box.offset_right = -10.0
	box.offset_top = 12.0
	box.offset_bottom = -10.0
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var icon := TextureRect.new()
	icon.texture = info.get("icon")
	icon.custom_minimum_size = Vector2(0.0, 44.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var title_label := _make_label(str(info.get("name", "")), 15, PARCHMENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	var role_label := _make_label(str(info.get("title", "")), 10, GOLD)
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(role_label)

	var rule := ColorRect.new()
	rule.color = Color(0.84, 0.7, 0.4, 0.25)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)

	var forte := _make_label(str(info.get("forte", "")), 8, GOLD_BRIGHT)
	forte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(forte)

	var blurb := _make_label(str(info.get("blurb", "")), 9, MUTED)
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(blurb)

	var weapon_label := _make_label("WEAPON · %s" % str(info.get("weapon", "")).to_upper(), 9, GOLD)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(weapon_label)

	return card


func _select_character(character_id: String) -> void:
	_selected_character = character_id
	if _name_edit != null and is_instance_valid(_name_edit):
		_name_edit.text = str(CharacterLibrary.get_character(character_id).get("name", "Aldric"))
	# Re-tint the cards so the chosen one reads as selected.
	for card in _content.get_children():
		_retint_cards(card)


func _retint_cards(node: Node) -> void:
	for child in node.get_children():
		if child is Button and child.has_meta("character_id"):
			_apply_card_selection(child, str(child.get_meta("character_id")) == _selected_character)
		_retint_cards(child)


func _apply_card_selection(card: Button, selected: bool) -> void:
	if selected:
		card.add_theme_stylebox_override("normal", _make_style(CARD_FILL_HOVER, GOLD_BRIGHT))
	else:
		card.add_theme_stylebox_override("normal", _make_style(CARD_FILL, Color(0.48, 0.39, 0.24, 1.0)))


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


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.anti_aliasing = true
	return box


func _on_continue_pressed() -> void:
	var data := SaveManager.continue_game()
	if data.is_empty():
		# The file vanished or could not be read; fall back to a fresh start.
		_on_new_journey_pressed()
		return
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_new_journey_pressed() -> void:
	_show_character_select()


func _on_begin_new_game_pressed() -> void:
	var chosen_name := ""
	if _name_edit != null and is_instance_valid(_name_edit):
		chosen_name = _name_edit.text
	SaveManager.start_new_game(_selected_character, chosen_name)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_settings_pressed() -> void:
	_settings.open()


func _on_quit_pressed() -> void:
	get_tree().quit()
