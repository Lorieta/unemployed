class_name SkillListPanel
extends OverlayPanel

## The gilded skill library. Talents are filed into five weapon-school folders,
## so the five assignable slots can be filled without turning the action bar into
## a flat list. Right-clicking a slot opens this panel already pointed at that
## slot; the Skills button (or K) opens it in browse mode.

signal skill_chosen(skill_id: String, slot_index: int)
signal clear_requested(slot_index: int)

const SKILL_LIBRARY := preload("res://scenes/hud/skill_library.gd")

const CARD_BG := Color(0.075, 0.061, 0.044, 0.94)
const CARD_BG_HOVER := Color(0.13, 0.105, 0.07, 0.96)
const CARD_BORDER := Color(0.46, 0.37, 0.22, 0.95)
const SLOT_COUNT_HINT := 5

var _assign_slot := -1
var _assigned: Array = []
var _school_id := "sword"
var _tabs: HBoxContainer
var _body: VBoxContainer
var _sections := {}
var _tab_buttons := {}
var _status_labels := {}
var _clear_button: Button

func _ready() -> void:
	title = "SKILL LIBRARY"
	subtitle = "FIVE SCHOOLS OF THE ROAD"
	panel_size = Vector2(900.0, 640.0)
	super._ready()
	_select_school("sword")

func _build_content() -> void:
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 5)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_child(_tabs)

	for school_id in SKILL_LIBRARY.SCHOOL_ORDER:
		var data: Dictionary = SKILL_LIBRARY.SCHOOLS[school_id]
		var tab := Button.new()
		tab.text = str(data["name"]).to_upper()
		tab.custom_minimum_size = Vector2(0.0, 34.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.focus_mode = Control.FOCUS_NONE
		tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tab.add_theme_font_size_override("font_size", 11)
		tab.pressed.connect(_select_school.bind(school_id))
		_tabs.add_child(tab)
		_tab_buttons[school_id] = tab

	_clear_button = Button.new()
	_clear_button.text = "CLEAR THIS SLOT"
	_clear_button.custom_minimum_size = Vector2(0.0, 30.0)
	_clear_button.focus_mode = Control.FOCUS_NONE
	_clear_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_clear_button.add_theme_font_size_override("font_size", 10)
	_clear_button.add_theme_color_override("font_color", PARCHMENT)
	_clear_button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	_clear_button.add_theme_stylebox_override("normal", _make_style(CARD_BG, CARD_BORDER))
	_clear_button.add_theme_stylebox_override("hover", _make_style(CARD_BG_HOVER, GOLD))
	_clear_button.add_theme_stylebox_override("pressed", _make_style(Color(0.035, 0.028, 0.02, 0.98), GOLD))
	_clear_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_clear_button.pressed.connect(_on_clear_pressed)
	_clear_button.visible = false
	content_box.add_child(_clear_button)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	content_box.add_child(_body)

	for school_id in SKILL_LIBRARY.SCHOOL_ORDER:
		var section := VBoxContainer.new()
		section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		section.add_theme_constant_override("separation", 7)
		_body.add_child(section)
		_sections[school_id] = section
		_build_section(section, school_id)

func _build_section(section: VBoxContainer, school_id: String) -> void:
	var data: Dictionary = SKILL_LIBRARY.SCHOOLS[school_id]
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	section.add_child(header)

	var title_label := Label.new()
	title_label.text = "%s SCHOOL" % str(data["name"]).to_upper()
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", data["color"])
	title_label.add_theme_color_override("font_outline_color", OUTLINE)
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	var subtitle := Label.new()
	subtitle.text = str(data["subtitle"])
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(subtitle)

	var description := Label.new()
	description.text = str(data["description"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", MUTED)
	description.add_theme_color_override("font_outline_color", OUTLINE)
	description.add_theme_constant_override("outline_size", 2)
	section.add_child(description)

	for skill_id in SKILL_LIBRARY.skills_in_school(school_id):
		_build_card(section, skill_id)

func _build_card(section: VBoxContainer, skill_id: String) -> void:
	var data: Dictionary = SKILL_LIBRARY.SKILLS[skill_id]
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_style(CARD_BG, CARD_BORDER))
	section.add_child(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var icon := TextureRect.new()
	icon.texture = data["icon"]
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(0.96, 0.9, 0.74, 1.0)
	row.add_child(icon)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 1)
	row.add_child(column)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	column.add_child(heading)

	var name_label := Label.new()
	name_label.text = str(data["name"])
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", PARCHMENT)
	name_label.add_theme_color_override("font_outline_color", OUTLINE)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)

	var tag := Label.new()
	tag.text = str(data["tag"])
	tag.add_theme_font_size_override("font_size", 9)
	var school_color: Color = SKILL_LIBRARY.SCHOOLS[str(data["school"])]["color"]
	tag.add_theme_color_override("font_color", school_color)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(tag)

	var description := Label.new()
	description.text = str(data["description"])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("font_size", 11)
	description.add_theme_color_override("font_color", MUTED)
	column.add_child(description)

	var meta := Label.new()
	meta.text = _meta_text(data)
	meta.add_theme_font_size_override("font_size", 9)
	meta.add_theme_color_override("font_color", Color(0.78, 0.68, 0.48, 1.0))
	column.add_child(meta)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", MUTED)
	column.add_child(status)
	_status_labels[skill_id] = status

	var action := Button.new()
	action.text = "ASSIGN"
	action.custom_minimum_size = Vector2(98.0, 34.0)
	action.focus_mode = Control.FOCUS_NONE
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action.add_theme_font_size_override("font_size", 10)
	action.add_theme_color_override("font_color", PARCHMENT)
	action.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	action.add_theme_stylebox_override("normal", _make_style(Color(0.055, 0.045, 0.032, 0.96), CARD_BORDER))
	action.add_theme_stylebox_override("hover", _make_style(CARD_BG_HOVER, GOLD))
	action.add_theme_stylebox_override("pressed", _make_style(Color(0.035, 0.028, 0.02, 0.98), GOLD))
	action.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	action.pressed.connect(_choose_skill.bind(skill_id))
	row.add_child(action)

func _meta_text(data: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("%.0f MANA" % float(data.get("mana", 0.0)))
	parts.append("%.1f s RECOVERY" % float(data.get("cooldown", 0.0)))
	match str(data.get("effect", "")):
		"strike":
			var hits := int(data.get("hits", 1))
			parts.append("%d x %.0f DAMAGE" % [hits, float(data.get("damage", 0.0))])
		"shockwave":
			parts.append("%.0f DAMAGE IN %.1f m" % [float(data.get("damage", 0.0)), float(data.get("radius", 0.0))])
		"projectile", "wisps":
			parts.append("%.0f DAMAGE" % float(data.get("damage", 0.0)))
		"volley":
			parts.append("%d ARROWS" % int(data.get("count", 1)))
		"heal":
			parts.append("+%.0f HEALTH" % float(data.get("amount", 0.0)))
		"mana":
			parts.append("+%.0f MANA" % float(data.get("amount", 0.0)))
		"dash":
			parts.append("DASH")
		"guard":
			parts.append("GUARD")
		"recall":
			parts.append("RETURN")
	return "   ·   ".join(parts)

func _select_school(school_id: String) -> void:
	if not SKILL_LIBRARY.SCHOOLS.has(school_id):
		return
	_school_id = school_id
	for id in _sections:
		(_sections[id] as Control).visible = str(id) == school_id
	for id in _tab_buttons:
		var button := _tab_buttons[id] as Button
		var selected: bool = str(id) == school_id
		var color: Color = SKILL_LIBRARY.SCHOOLS[id]["color"]
		button.add_theme_color_override("font_color", GOLD_BRIGHT if selected else MUTED)
		button.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
		button.add_theme_stylebox_override(
			"normal",
			_make_style(
				Color(0.12, 0.095, 0.06, 0.98) if selected else Color(0.05, 0.041, 0.03, 0.92),
				color if selected else CARD_BORDER
			)
		)
		button.add_theme_stylebox_override("hover", _make_style(CARD_BG_HOVER, GOLD))
		button.add_theme_stylebox_override("pressed", _make_style(Color(0.035, 0.028, 0.02, 0.98), GOLD))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func open_browser(school_hint := "") -> void:
	_assign_slot = -1
	set_header("SKILL LIBRARY", "FIVE SCHOOLS OF THE ROAD")
	_clear_button.visible = false
	if SKILL_LIBRARY.SCHOOLS.has(school_hint):
		_select_school(school_hint)
	_refresh_cards()
	open()

func open_for_slot(slot_index: int, school_hint := "") -> void:
	_assign_slot = slot_index
	var slot_name := "SLOT %d" % (slot_index + 1) if slot_index >= 0 else "A FREE SLOT"
	set_header("SKILL LIBRARY", "CHOOSING A TALENT FOR %s" % slot_name)
	_clear_button.visible = slot_index >= 0 and slot_index < SLOT_COUNT_HINT
	_clear_button.text = "CLEAR SLOT %d" % (slot_index + 1) if slot_index >= 0 else "CLEAR THIS SLOT"
	if SKILL_LIBRARY.SCHOOLS.has(school_hint):
		_select_school(school_hint)
	_refresh_cards()
	open()

func set_assigned(assigned: Array) -> void:
	_assigned = assigned.duplicate()
	_refresh_cards()

func _refresh_cards() -> void:
	for skill_id in _status_labels:
		var label := _status_labels[skill_id] as Label
		var slot := _assigned.find(skill_id)
		if slot >= 0:
			label.text = "ASSIGNED TO SLOT %d" % (slot + 1)
			label.add_theme_color_override("font_color", GOLD_BRIGHT)
		else:
			label.text = "UNASSIGNED"
			label.add_theme_color_override("font_color", MUTED)

func _choose_skill(skill_id: String) -> void:
	var slot := _assign_slot
	if slot < 0:
		slot = _first_free_slot()
	if slot < 0:
		slot = 0
	skill_chosen.emit(skill_id, slot)

func _first_free_slot() -> int:
	for i in SLOT_COUNT_HINT:
		if i >= _assigned.size() or str(_assigned[i]).is_empty():
			return i
	return -1

func _on_clear_pressed() -> void:
	if _assign_slot >= 0:
		clear_requested.emit(_assign_slot)
