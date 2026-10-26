class_name InventoryPanel
extends Control

## The satchel window: a classic paper-doll equipment column, a grid of carried
## items, and a live armory. The armory is the only place weapons are equipped;
## clicking a weapon here draws the same blade the journal and combat use.

signal closed
signal weapon_selected(weapon_id: String)
signal offhand_selected(offhand_id: String)
signal item_used(item_id: String)

const QUICK_SLOT := preload("res://scenes/hud/quick_slot.tscn")
const OFFHAND_LIBRARY := preload("res://scenes/player/offhands/offhand_library.gd")

const ICON_SWORD := preload("res://assets/ui/icons/sword.svg")
const ICON_SHIELD := preload("res://assets/ui/icons/shield.svg")
const ICON_HELM := preload("res://assets/ui/icons/helm.svg")
const ICON_ARMOR := preload("res://assets/ui/icons/armor.svg")
const ICON_GLOVES := preload("res://assets/ui/icons/gloves.svg")
const ICON_BOOTS := preload("res://assets/ui/icons/boots.svg")
const ICON_POTION_RED := preload("res://assets/ui/icons/potion_red.svg")
const ICON_POTION_BLUE := preload("res://assets/ui/icons/potion_blue.svg")
const ICON_HERB := preload("res://assets/ui/icons/herb.svg")
const ICON_SCROLL := preload("res://assets/ui/icons/scroll.svg")
const ICON_TORCH := preload("res://assets/ui/icons/torch.svg")
const ICON_GEM := preload("res://assets/ui/icons/gem.svg")
const ICON_KEY := preload("res://assets/ui/icons/key.svg")
const ICON_MAP := preload("res://assets/ui/icons/map.svg")
const ICON_COIN := preload("res://assets/ui/icons/coin.svg")
const ICON_RING := preload("res://assets/ui/icons/ring.svg")

const COLOR_PARCHMENT := Color(0.92, 0.87, 0.76, 1.0)
const COLOR_MUTED := Color(0.63, 0.58, 0.48, 1.0)
const COLOR_GOLD := Color(0.84, 0.7, 0.4, 1.0)
const COLOR_GOLD_BRIGHT := Color(0.97, 0.86, 0.58, 1.0)

const GRID_SLOTS := 20
const EQUIPMENT_START_Y := 0.0
const EQUIPMENT_ROW_HEIGHT := 62.0
const ARMORY_START_Y := 0.0
const ARMORY_ROW_HEIGHT := 58.0
const DEFAULT_ITEM_HINT := "Click a carried item to use it.  Hover to read its description."

## Definitions for item ids that shops can add to the satchel. Existing stacks are
## simply topped up; a brand-new entry is added to the first free grid slot.
const ITEM_DEFINITIONS := {
	"health": {"icon": ICON_POTION_RED, "name": "Crimson Draught", "description": "Restores 45 health. Bitter, but it works."},
	"mana": {"icon": ICON_POTION_BLUE, "name": "Azure Draught", "description": "Restores 40 mana. Tastes of cold rain."},
	"moonpetal": {"icon": ICON_HERB, "name": "Moonpetal", "description": "A pale herb that opens only at dusk."},
	"waybread": {"icon": ICON_HERB, "name": "Waybread", "description": "Hearth-baked and honeyed. Restores 25 health on the road."},
	"return": {"icon": ICON_SCROLL, "name": "Scroll of Return", "description": "Read the runes to return to the old well."},
	"torch": {"icon": ICON_TORCH, "name": "Pitch Torch", "description": "Click to kindle or smother a warm travelling light."},
}

var _equipment := [
	{"icon": ICON_SWORD, "name": "Wayfarer's Blade", "type": "MAIN HAND"},
	{"icon": ICON_SHIELD, "name": "Oaken Buckler", "type": "OFF HAND"},
	{"icon": ICON_HELM, "name": "Leather Hood", "type": "HEAD"},
	{"icon": ICON_ARMOR, "name": "Ranger's Coat", "type": "BODY"},
	{"icon": ICON_GLOVES, "name": "Worn Gloves", "type": "HANDS"},
	{"icon": ICON_BOOTS, "name": "Trailboots", "type": "FEET"},
]

var _items := [
	{"id": "health", "icon": ICON_POTION_RED, "name": "Crimson Draught", "stack": 4, "description": "Restores 45 health. Bitter, but it works."},
	{"id": "mana", "icon": ICON_POTION_BLUE, "name": "Azure Draught", "stack": 2, "description": "Restores 40 mana. Tastes of cold rain."},
	{"id": "moonpetal", "icon": ICON_HERB, "name": "Moonpetal", "stack": 5, "description": "A pale herb that opens only at dusk."},
	{"id": "return", "icon": ICON_SCROLL, "name": "Scroll of Return", "stack": 1, "description": "Read the runes to return to the old well."},
	{"id": "torch", "icon": ICON_TORCH, "name": "Pitch Torch", "stack": 1, "description": "Click to kindle or smother a warm travelling light."},
	{"id": "soulstone", "icon": ICON_GEM, "name": "Verdant Soulstone", "stack": 1, "description": "A shard of the Reach's old magic. It hums faintly."},
	{"id": "key", "icon": ICON_KEY, "name": "Old Well Key", "stack": 1, "description": "A cold iron key. Opens nothing you have found yet."},
	{"id": "map", "icon": ICON_MAP, "name": "Valley Map", "stack": 1, "description": "Unfolds the chart of the Verdant Reach."},
	{"id": "ring", "icon": ICON_RING, "name": "Band of the Wanderer", "stack": 1, "description": "A plain ring, warm to the touch."},
	{"id": "gold", "icon": ICON_COIN, "name": "Gold Coins", "stack": 86, "description": "Eighty-six coins in a worn leather purse."},
	{"id": "shield", "icon": ICON_SHIELD, "name": "Travel Shield", "stack": 1, "description": "Oaken, scarred, and steady. It has seen worse roads."},
]

var _tween: Tween
var _equipped := "sword"
var _equipped_offhand := "shield"
var _armory_tab := "weapons"
var _weapon_slots := {}
var _offhand_slots := {}
var _item_slots: Array[QuickSlot] = []
var _main_hand_slot: QuickSlot
var _main_hand_name: Label
var _main_hand_type: Label
var _off_hand_slot: QuickSlot
var _off_hand_name: Label
var _off_hand_type: Label
var _weapon_detail_name: Label
var _weapon_detail_style: Label
var _weapon_detail_stats: Label
var _weapon_detail_desc: Label
var _item_hint: Label

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Dim.gui_input.connect(_on_dim_gui_input)
	$Panel/CloseButton.pressed.connect(close)
	_style_close_button()
	_weapon_detail_name = $Panel/WeaponDetailName
	_weapon_detail_style = $Panel/WeaponDetailStyle
	_weapon_detail_stats = $Panel/WeaponDetailStats
	_weapon_detail_desc = $Panel/WeaponDetailDesc
	_item_hint = $Panel/ItemHint
	$Panel/WeaponTab.pressed.connect(_set_tab.bind("weapons"))
	$Panel/OffhandTab.pressed.connect(_set_tab.bind("offhand"))
	_build_equipment()
	_build_items()
	_build_armory()
	_build_offhands()
	$Panel/ItemCount.text = "%d / %d" % [_items.size(), GRID_SLOTS]
	$Panel/GoldValue.text = "1,284"
	_item_hint.text = DEFAULT_ITEM_HINT
	set_equipped("sword")
	set_equipped_offhand("shield")
	_set_tab("weapons")

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	_kill_tween()
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)

func close() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(func() -> void:
		visible = false
		modulate = Color(1.0, 1.0, 1.0, 1.0)
		closed.emit()
	)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()

func _style_close_button() -> void:
	var button: Button = $Panel/CloseButton
	button.text = "×"
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", COLOR_GOLD)
	button.add_theme_color_override("font_hover_color", COLOR_GOLD_BRIGHT)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.05, 0.04, 0.03, 0.9), Color(0.44, 0.36, 0.22, 0.95)))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.12, 0.1, 0.065, 0.96), COLOR_GOLD))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.03, 0.024, 0.018, 0.98), COLOR_GOLD))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.anti_aliasing = true
	return box

func _build_equipment() -> void:
	var parent: Control = $Panel/EquipmentRows
	for i in _equipment.size():
		var entry: Dictionary = _equipment[i]
		var y := EQUIPMENT_START_Y + float(i) * EQUIPMENT_ROW_HEIGHT

		var slot := QUICK_SLOT.instantiate() as QuickSlot
		slot.icon_texture = entry["icon"]
		slot.item_name = entry["name"]
		slot.position = Vector2(0.0, y)
		slot.size = Vector2(56.0, 56.0)
		parent.add_child(slot)
		slot.tooltip_text = "%s\n%s" % [entry["name"], entry["type"]]

		var name_label := _make_label(str(entry["name"]), Vector2(66.0, y + 4.0), Vector2(254.0, 22.0), 12, COLOR_PARCHMENT)
		parent.add_child(name_label)
		var type_label := _make_label(str(entry["type"]), Vector2(66.0, y + 26.0), Vector2(254.0, 18.0), 9, COLOR_GOLD)
		parent.add_child(type_label)

		if i == 0:
			_main_hand_slot = slot
			_main_hand_name = name_label
			_main_hand_type = type_label
		elif i == 1:
			_off_hand_slot = slot
			_off_hand_name = name_label
			_off_hand_type = type_label

func _build_items() -> void:
	var grid: GridContainer = $Panel/ItemGrid
	for i in GRID_SLOTS:
		var slot := QUICK_SLOT.instantiate() as QuickSlot
		if i < _items.size():
			var entry: Dictionary = _items[i]
			slot.icon_texture = entry["icon"]
			slot.item_name = entry["name"]
			slot.stack = int(entry["stack"])
			var description := str(entry.get("description", ""))
			slot.activated.connect(_on_item_slot.bind(str(entry.get("id", "")), description))
			slot.mouse_entered.connect(_on_item_hover.bind(description))
			var suffix := ""
			if int(entry["stack"]) > 1:
				suffix = "  ×%d" % int(entry["stack"])
			slot.tooltip_text = "%s%s" % [entry["name"], suffix]
			_item_slots.append(slot)
		grid.add_child(slot)

func _build_armory() -> void:
	var parent: Control = $Panel/ArmoryRows
	for i in WeaponLibrary.ORDER.size():
		var weapon_id: String = WeaponLibrary.ORDER[i]
		var data: Dictionary = WeaponLibrary.WEAPONS[weapon_id]
		var y := ARMORY_START_Y + float(i) * ARMORY_ROW_HEIGHT

		var slot := QUICK_SLOT.instantiate() as QuickSlot
		slot.icon_texture = data["icon"]
		slot.item_name = "%s  ·  %s" % [data["class"], data["name"]]
		slot.position = Vector2(0.0, y)
		slot.size = Vector2(52.0, 52.0)
		slot.tooltip_text = "%s\n%s  ·  %s\n%d damage  ·  click to equip" % [data["name"], data["class"], data["skill"], int(data["damage"])]
		slot.activated.connect(_on_weapon_slot.bind(weapon_id))
		parent.add_child(slot)
		_weapon_slots[weapon_id] = slot

		parent.add_child(_make_label(str(data["name"]), Vector2(66.0, y + 4.0), Vector2(166.0, 22.0), 12, COLOR_PARCHMENT))
		parent.add_child(_make_label(str(data["class"]), Vector2(66.0, y + 25.0), Vector2(166.0, 18.0), 9, COLOR_GOLD))

## The second page of the armory. Off-hands live on the left arm, so every hero
## can carry one of these from the first minute of the game.
func _build_offhands() -> void:
	var parent: Control = $Panel/OffhandRows
	for i in OFFHAND_LIBRARY.ORDER.size():
		var offhand_id: String = OFFHAND_LIBRARY.ORDER[i]
		var data: Dictionary = OFFHAND_LIBRARY.OFFHANDS[offhand_id]
		var y := ARMORY_START_Y + float(i) * ARMORY_ROW_HEIGHT

		var slot := QUICK_SLOT.instantiate() as QuickSlot
		slot.icon_texture = data["icon"]
		slot.item_name = "%s  ·  %s" % [data["class"], data["name"]]
		slot.position = Vector2(0.0, y)
		slot.size = Vector2(52.0, 52.0)
		slot.tooltip_text = "%s\n%s  ·  %s\n%s\nClick to carry." % [data["name"], data["class"], data["tagline"], data["effect"]]
		slot.activated.connect(_on_offhand_slot.bind(offhand_id))
		parent.add_child(slot)
		_offhand_slots[offhand_id] = slot

		parent.add_child(_make_label(str(data["name"]), Vector2(66.0, y + 4.0), Vector2(166.0, 22.0), 12, COLOR_PARCHMENT))
		parent.add_child(_make_label(str(data["class"]), Vector2(66.0, y + 25.0), Vector2(166.0, 18.0), 9, COLOR_GOLD))

func _set_tab(tab: String) -> void:
	_armory_tab = tab
	var weapons := tab == "weapons"
	$Panel/ArmoryRows.visible = weapons
	$Panel/OffhandRows.visible = not weapons
	_style_tab($Panel/WeaponTab, weapons)
	_style_tab($Panel/OffhandTab, not weapons)
	if weapons:
		_update_weapon_detail(_equipped)
	else:
		_update_offhand_detail(_equipped_offhand)

func set_armory_tab(tab: String) -> void:
	if tab == "offhand" or tab == "weapons":
		_set_tab(tab)

func _style_tab(button: Button, active: bool) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 9)
	button.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT if active else COLOR_MUTED)
	button.add_theme_color_override("font_hover_color", COLOR_GOLD_BRIGHT)
	button.add_theme_stylebox_override("normal", _make_style(
		Color(0.13, 0.105, 0.065, 0.95) if active else Color(0.05, 0.04, 0.03, 0.8),
		COLOR_GOLD if active else Color(0.36, 0.3, 0.19, 0.9)
	))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.15, 0.12, 0.075, 0.96), COLOR_GOLD))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.04, 0.032, 0.022, 0.98), COLOR_GOLD))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func set_equipped(weapon_id: String) -> void:
	if not WeaponLibrary.WEAPONS.has(weapon_id):
		return
	_equipped = weapon_id
	for id in _weapon_slots:
		(_weapon_slots[id] as QuickSlot).set_selected(str(id) == weapon_id)
	_update_main_hand(weapon_id)
	if _armory_tab == "weapons":
		_update_weapon_detail(weapon_id)

func set_equipped_offhand(offhand_id: String) -> void:
	if not OFFHAND_LIBRARY.has(offhand_id):
		return
	_equipped_offhand = offhand_id
	for id in _offhand_slots:
		(_offhand_slots[id] as QuickSlot).set_selected(str(id) == offhand_id)
	_update_off_hand(offhand_id)
	if _armory_tab == "offhand":
		_update_offhand_detail(offhand_id)

func get_equipped() -> String:
	return _equipped

func get_equipped_offhand() -> String:
	return _equipped_offhand

func consume_item(item_id: String) -> bool:
	for i in _items.size():
		var entry: Dictionary = _items[i]
		if str(entry.get("id", "")) != item_id:
			continue
		var count := int(entry["stack"])
		if count <= 0:
			return false
		entry["stack"] = count - 1
		if i < _item_slots.size():
			_item_slots[i].set_stack(count - 1)
			var suffix := ""
			if count - 1 > 1:
				suffix = "  ×%d" % (count - 1)
			_item_slots[i].tooltip_text = "%s%s" % [str(entry["name"]), suffix]
		return true
	return false

## Shop purchases land here: top up an existing stack, or add the definition to
## the first free grid slot and rebuild the grid.
func add_item(item_id: String, amount := 1) -> bool:
	if amount <= 0:
		return false
	for i in _items.size():
		var entry: Dictionary = _items[i]
		if str(entry.get("id", "")) != item_id:
			continue
		var total := int(entry["stack"]) + amount
		entry["stack"] = total
		if i < _item_slots.size():
			_item_slots[i].set_stack(total)
			_item_slots[i].tooltip_text = "%s  ×%d" % [str(entry["name"]), total]
		return true
	if _items.size() >= GRID_SLOTS:
		return false
	if not ITEM_DEFINITIONS.has(item_id):
		return false
	var definition: Dictionary = ITEM_DEFINITIONS[item_id]
	_items.append({
		"id": item_id,
		"icon": definition["icon"],
		"name": definition["name"],
		"stack": amount,
		"description": definition["description"],
	})
	_rebuild_items()
	refresh_counts()
	return true

func get_item_count(item_id: String) -> int:
	for entry in _items:
		if str(entry.get("id", "")) == item_id:
			return int(entry["stack"])
	return 0

func set_gold(value: int) -> void:
	$Panel/GoldValue.text = _format_number(value)

func refresh_counts() -> void:
	$Panel/ItemCount.text = "%d / %d" % [_items.size(), GRID_SLOTS]

func _rebuild_items() -> void:
	var grid: GridContainer = $Panel/ItemGrid
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	_item_slots.clear()
	_build_items()

func _format_number(number: int) -> String:
	var digits := str(number)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result

func _on_weapon_slot(weapon_id: String) -> void:
	_update_weapon_detail(weapon_id)
	_weapon_slots[weapon_id].set_selected(true)
	weapon_selected.emit(weapon_id)

func _on_offhand_slot(offhand_id: String) -> void:
	_update_offhand_detail(offhand_id)
	_offhand_slots[offhand_id].set_selected(true)
	offhand_selected.emit(offhand_id)

func _on_item_slot(item_id: String, description: String) -> void:
	if not description.is_empty():
		_item_hint.text = description
	if item_id.is_empty():
		return
	item_used.emit(item_id)

func _on_item_hover(description: String) -> void:
	if not description.is_empty():
		_item_hint.text = description

func _update_main_hand(weapon_id: String) -> void:
	var data: Dictionary = WeaponLibrary.WEAPONS.get(weapon_id, {})
	if data.is_empty() or _main_hand_slot == null:
		return
	_main_hand_slot.set_item(data["icon"], data["name"], 0)
	_main_hand_slot.tooltip_text = "%s\nMAIN HAND  ·  %s" % [data["name"], data["class"]]
	_main_hand_name.text = str(data["name"])
	_main_hand_type.text = "MAIN HAND  ·  %s" % str(data["class"])

func _update_weapon_detail(weapon_id: String) -> void:
	var data: Dictionary = WeaponLibrary.WEAPONS.get(weapon_id, {})
	if data.is_empty() or _weapon_detail_name == null:
		return
	_weapon_detail_name.text = str(data["name"])
	_weapon_detail_style.text = "%s  ·  SIGNATURE: %s" % [str(data["class"]), str(data["skill"]).to_upper()]
	_weapon_detail_stats.text = "%d DAMAGE   ·   %.2fs RECOVERY" % [int(data["damage"]), float(data["cooldown"])]
	_weapon_detail_desc.text = "%s\n\nClick this weapon in the armory to equip it." % str(data["description"])

func _update_off_hand(offhand_id: String) -> void:
	var data: Dictionary = OFFHAND_LIBRARY.get_offhand(offhand_id)
	if data.is_empty() or _off_hand_slot == null:
		return
	_off_hand_slot.set_item(data["icon"], data["name"], 0)
	_off_hand_slot.tooltip_text = "%s\nOFF HAND  ·  %s\n%s" % [data["name"], data["class"], data["tagline"]]
	_off_hand_name.text = str(data["name"])
	_off_hand_type.text = "OFF HAND  ·  %s" % str(data["class"])

func _update_offhand_detail(offhand_id: String) -> void:
	var data: Dictionary = OFFHAND_LIBRARY.get_offhand(offhand_id)
	if data.is_empty() or _weapon_detail_name == null:
		return
	_weapon_detail_name.text = str(data["name"])
	_weapon_detail_style.text = "%s  ·  %s" % [str(data["class"]), str(data["tagline"]).to_upper()]
	_weapon_detail_stats.text = str(data["effect"])
	_weapon_detail_desc.text = "%s\n\nThe bow and the kitsune need both hands, so the off-hand is stowed while either is drawn." % str(data["description"])

func _make_label(text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = label_size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.024, 0.018, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	return label
