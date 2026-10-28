extends CanvasLayer

## Classic adventure HUD: portrait and vitals, a hand-framed minimap, a tracked
## quest, five assignable skill slots, five item slots, XP, coin, and a working
## satchel/journal/map/skills/settings set. Weapons live only in the satchel
## armory; the skill bar holds learned talents from `SkillLibrary`, every slot
## starts empty, and talents are assigned in the gilded school-folder library.
##
## The HUD also owns the story: Hearthmere's townsfolk, the Thorned Field's
## quest counters, Mira and Bran's counters, the zone banner, the Briar Warden's
## bar, and the hero's death and recovery. World objects report events through
## small, forgiving hooks (`on_monster_killed`, `on_shrine_interact`,
## `apply_incoming_damage`) so their scenes stay independent of this layer.

const QUICK_SLOT := preload("res://scenes/hud/quick_slot.tscn")
const JOURNAL_PANEL := preload("res://scenes/hud/journal_panel.gd")
const MAP_PANEL := preload("res://scenes/hud/map_panel.gd")
const SETTINGS_PANEL := preload("res://scenes/hud/settings_panel.gd")
const PAUSE_MENU := preload("res://scenes/hud/pause_menu.gd")
const DIALOGUE_PANEL := preload("res://scenes/hud/dialogue_panel.gd")
const SKILL_LIBRARY := preload("res://scenes/hud/skill_library.gd")
const SKILL_LIST_PANEL := preload("res://scenes/hud/skill_list_panel.gd")
const SHOP_PANEL := preload("res://scenes/hud/shop_panel.gd")
const OFFHAND_LIBRARY := preload("res://scenes/player/offhands/offhand_library.gd")

const ICON_POTION_RED := preload("res://assets/ui/icons/potion_red.svg")
const ICON_POTION_BLUE := preload("res://assets/ui/icons/potion_blue.svg")
const ICON_TORCH := preload("res://assets/ui/icons/torch.svg")
const ICON_SCROLL := preload("res://assets/ui/icons/scroll.svg")
const ICON_GEM := preload("res://assets/ui/icons/gem.svg")
const ICON_BAG := preload("res://assets/ui/icons/bag.svg")
const ICON_BOOK := preload("res://assets/ui/icons/book.svg")
const ICON_MAP := preload("res://assets/ui/icons/map.svg")
const ICON_GEAR := preload("res://assets/ui/icons/gear.svg")

const SLOT_COUNT := 5
const ITEM_SLOT_COUNT := 5


const MAX_HEALTH := 160.0
const MAX_MANA := 120.0
const MAX_XP := 18000.0
const QUEST_REWARD := 120

const STORY_BEASTS_REQUIRED := 8
const STORY_SIDE_WOLVES_REQUIRED := 4
const STORY_REWARD_A_GOLD := 180
const STORY_REWARD_A_XP := 700.0
const STORY_REWARD_B_GOLD := 320
const STORY_REWARD_B_XP := 1400.0
const SIDE_REWARD_GOLD := 90
const SIDE_REWARD_XP := 320.0
const DEATH_GOLD_LOSS := 40

const QUICK_ITEM_IDS := ["health", "mana", "torch", "return", "moonpetal"]

const ZONE_INFO := {
	"town": {"title": "HEARTHMERE", "subtitle": "A LANTERN TOWN IN THE VERDANT REACH"},
	"field": {"title": "THE THORNED FIELD", "subtitle": "BEYOND HEARTHMERE'S GATE"},
	"shrine": {"title": "THE WAYSHRINE", "subtitle": "A QUIET CLEARING IN THE BRIARS"},
	"warden": {"title": "THE WARDEN'S CLEARING", "subtitle": "OLD STONE AND LIVING THORNS"},
}

## Everything the two shopkeepers carry. `whetstone` and `rivet` are permanent
## upgrades fitted by Bran rather than satchel items; every other id is fed to
## the inventory through `add_item`.
const SHOP_STOCK := {
	"mira": {
		"title": "MIRA'S WARES",
		"subtitle": "HEARTHMERE MARKET",
		"description": "Mira keeps the market stall with the red awning. Dried herbs hang from the beams, and the good draughts are kept under the counter where the light cannot sour them.",
		"stock": [
			{"id": "health", "name": "Crimson Draught", "description": "Restores 45 health. Bitter, but it works.", "price": 30, "max": 8},
			{"id": "mana", "name": "Azure Draught", "description": "Restores 40 mana. Tastes of cold rain.", "price": 34, "max": 6},
			{"id": "waybread", "name": "Waybread", "description": "Hearth-baked and honeyed. Restores 25 health on the road.", "price": 18, "max": 6},
			{"id": "moonpetal", "name": "Moonpetal", "description": "A pale herb that opens only at dusk.", "price": 22, "max": 5},
		],
	},
	"bran": {
		"title": "BRAN'S FORGE",
		"subtitle": "HEARTHMERE SMITHY",
		"description": "The forge shed is open to the road. Bran sets down his hammer, wipes his hands on his apron, and looks over your steel with the flat eye of a man who has straightened worse.",
		"stock": [
			{"id": "whetstone", "name": "Forge Whetstone", "description": "Bran hones your weapon: +2 permanent attack power. Limit 4.", "price": 120, "max": 4},
			{"id": "rivet", "name": "Shield Rivet", "description": "A brass rivet set into your guard: +3% permanent damage reduction. Limit 3.", "price": 90, "max": 3},
			{"id": "health", "name": "Crimson Draught", "description": "A forge-hand's pick-me-up. Restores 45 health.", "price": 32, "max": 5},
			{"id": "waybread", "name": "Waybread", "description": "A hard traveler's loaf from the smithy table. Restores 25 health.", "price": 20, "max": 4},
		],
	},
}

const COLOR_PARCHMENT := Color(0.92, 0.87, 0.76, 1.0)
const COLOR_MUTED := Color(0.63, 0.58, 0.48, 1.0)
const COLOR_GOLD := Color(0.84, 0.7, 0.4, 1.0)
const COLOR_GOLD_BRIGHT := Color(0.97, 0.86, 0.58, 1.0)
const COLOR_DONE := Color(0.58, 0.67, 0.5, 1.0)
const COLOR_PENDING := Color(0.48, 0.44, 0.36, 1.0)
const COLOR_OUTLINE := Color(0.035, 0.028, 0.02, 0.95)

@onready var _health_bar: StatBar = $Root/PlayerPanel/HealthBar
@onready var _mana_bar: StatBar = $Root/PlayerPanel/ManaBar
@onready var _health_value: Label = $Root/PlayerPanel/HealthValue
@onready var _mana_value: Label = $Root/PlayerPanel/ManaValue
@onready var _skill_row: HBoxContainer = $Root/Quickbar/SkillRow
@onready var _item_row: HBoxContainer = $Root/Quickbar/ItemRow
@onready var _weapon_label: Label = $Root/Quickbar/WeaponLabel
@onready var _xp_bar: StatBar = $Root/Quickbar/XPBar
@onready var _xp_value: Label = $Root/Quickbar/XPLabel
@onready var _buttons: HBoxContainer = $Root/Buttons
@onready var _inventory: InventoryPanel = $Root/Inventory
@onready var _toast: Label = $Root/Toast
@onready var _prompt: Control = $Root/InteractionPrompt
@onready var _prompt_text: Label = $Root/InteractionPrompt/PromptText
@onready var _hint_panel: Control = $Root/HintPanel
@onready var _vignette: ColorRect = $Root/Vignette
@onready var _objective1: Label = $Root/QuestPanel/Objective1
@onready var _objective2: Label = $Root/QuestPanel/Objective2
@onready var _objective3: Label = $Root/QuestPanel/Objective3
@onready var _reward_label: Label = $Root/QuestPanel/Reward
@onready var _quest_title: Label = $Root/QuestPanel/QuestTitle
@onready var _quest_chapter: Label = $Root/QuestPanel/QuestChapter
@onready var _zone_banner: Control = $Root/ZoneBanner
@onready var _zone_title: Label = $Root/ZoneBanner/ZoneTitle
@onready var _zone_sub: Label = $Root/ZoneBanner/ZoneSub
@onready var _boss_bar: Control = $Root/BossBar
@onready var _boss_name: Label = $Root/BossBar/BossName
@onready var _boss_fill: StatBar = $Root/BossBar/BossFill
@onready var _reticle: Control = $Root/AimReticle

var _health := 122.0
var _mana := 82.0
var _xp := 12480.0
var _gold := 1284
var _level := 7

var _slots: Array[QuickSlot] = []
var _skill_slots: Array[QuickSlot] = []
var _selected_slot := -1
var _slot_data: Array[Dictionary] = []
var _toast_timer := 0.0

var _player: Node
var _announced_weapon := "sword"
var _current_prompt := ""
var _aim_point := Vector3.ZERO
var _has_aim := false

var _journal: JournalPanel
var _map: MapPanel
var _settings: SettingsPanel
var _pause: PauseMenu
var _dialogue: DialoguePanel
var _skill_list: Node
var _overlays: Array[OverlayPanel] = []

var _quest_stage := 0
var _dummies_hit := 0

var _story_stage := 0
var _beasts_culled := 0
var _side_stage := 0
var _wolves_culled := 0
var _shrine_lit := false
var _boss_defeated := false
var _boss: Node = null
var _dead := false
var _orbit_camera := false

var _shop: OverlayPanel
var _purchases := {"mira": {}, "bran": {}}
var _zone_id := ""
var _zone_timer := 0.0
var _falling := false

func _ready() -> void:
	_build_slot_data()
	_build_quickbar()
	_build_buttons()
	_build_overlays()
	_resolve_player()
	_refresh_vitals()
	_refresh_progress()
	_refresh_quest()
	_update_weapon_label("sword")
	_toast.modulate.a = 0.0
	_prompt.visible = false
	_inventory.closed.connect(_on_inventory_closed)
	_inventory.weapon_selected.connect(_on_inventory_weapon_selected)
	_inventory.offhand_selected.connect(_on_inventory_offhand_selected)
	if _inventory.has_signal("item_used"):
		_inventory.item_used.connect(_on_inventory_item_used)
	_skill_list.set_assigned(_assigned_skills())
	_sync_item_stacks()
	_refresh_quest_markers()
	_boss_bar.visible = false
	_zone_banner.modulate.a = 0.0

func _build_slot_data() -> void:
	_slot_data.clear()
	# The five skill slots begin empty. Right-click assigns a learned talent.
	for i in SLOT_COUNT:
		_slot_data.append({
			"kind": "skill_slot",
			"skill": "",
			"icon": null,
			"name": "",
			"key": str(i + 1),
			"cooldown": 0.0,
			"stack": 0,
		})
	_slot_data.append({"icon": ICON_POTION_RED, "name": "Crimson Draught", "key": "6", "kind": "health", "cooldown": 1.0, "stack": 4})
	_slot_data.append({"icon": ICON_POTION_BLUE, "name": "Azure Draught", "key": "7", "kind": "mana", "cooldown": 1.0, "stack": 2})
	_slot_data.append({"icon": ICON_TORCH, "name": "Pitch Torch", "key": "8", "kind": "light", "cooldown": 0.0, "stack": 1})
	_slot_data.append({"icon": ICON_SCROLL, "name": "Scroll of Return", "key": "9", "kind": "return", "cooldown": 3.0, "stack": 1})
	_slot_data.append({"icon": ICON_GEM, "name": "Moonpetal", "key": "0", "kind": "inspect", "cooldown": 0.0, "stack": 1})

func _build_quickbar() -> void:
	for i in _slot_data.size():
		var data: Dictionary = _slot_data[i]
		var slot := QUICK_SLOT.instantiate() as QuickSlot
		var is_skill := str(data["kind"]) == "skill_slot"
		slot.assignable = is_skill
		slot.icon_texture = data.get("icon", null)
		slot.item_name = str(data.get("name", ""))
		slot.hotkey = str(data["key"])
		slot.stack = int(data.get("stack", 0))
		var row := _skill_row if is_skill else _item_row
		row.add_child(slot)
		slot.activated.connect(_on_slot_activated.bind(i))
		if is_skill:
			slot.assign_requested.connect(_on_slot_assign_requested.bind(i))
			_skill_slots.append(slot)
		_slots.append(slot)


func _build_buttons() -> void:
	var definitions := [
		[ICON_BAG, "Satchel  (I)", _toggle_inventory],
		[ICON_BOOK, "Journal", _show_journal],
		[ICON_GEM, "Skills  (K)", _show_skills],
		[ICON_MAP, "Map", _show_map],
		[ICON_GEAR, "Settings", _show_settings],
	]
	for definition in definitions:
		var button := _make_icon_button(definition[0], definition[1])
		button.pressed.connect(definition[2])
		_buttons.add_child(button)

func _build_overlays() -> void:
	_journal = JOURNAL_PANEL.new() as JournalPanel
	_map = MAP_PANEL.new() as MapPanel
	_settings = SETTINGS_PANEL.new() as SettingsPanel
	_pause = PAUSE_MENU.new() as PauseMenu
	_dialogue = DIALOGUE_PANEL.new() as DialoguePanel
	_skill_list = SKILL_LIST_PANEL.new()
	_shop = SHOP_PANEL.new() as OverlayPanel
	_overlays = [_journal, _map, _settings, _dialogue, _shop]
	_overlays.append(_skill_list as OverlayPanel)
	_overlays.append(_pause)
	for panel in _overlays:
		$Root.add_child(panel)
		panel.closed.connect(_on_overlay_closed)
	_shop.connect("purchase_requested", _on_shop_purchase)
	_settings.hints_toggled.connect(_on_hints_toggled)
	_settings.vignette_toggled.connect(_on_vignette_toggled)
	_settings.restart_requested.connect(_on_restart_requested)
	_pause.closed.connect(_on_pause_closed)
	_pause.settings_requested.connect(_on_pause_settings)
	_pause.quit_to_title_requested.connect(_on_quit_to_title)
	_pause.quit_game_requested.connect(_on_quit_game)
	_dialogue.choice_selected.connect(_on_dialogue_choice)
	_skill_list.connect("skill_chosen", _on_skill_chosen)
	_skill_list.connect("clear_requested", _on_skill_clear_requested)

func _resolve_player() -> void:
	_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return
	_player.weapon_changed.connect(_on_weapon_changed)
	_player.offhand_changed.connect(_on_offhand_changed)
	_player.attack_started.connect(_on_attack_started)
	_player.enemy_hit.connect(_on_enemy_hit)
	_player.interaction_changed.connect(_on_interaction_changed)
	var equipped := str(_player.get("equipped_weapon"))
	_announced_weapon = equipped
	_update_weapon_label(equipped)
	_inventory.set_equipped_offhand(str(_player.get("equipped_offhand")))
	_player.call("set_aim_facing", true)

func _make_icon_button(icon: Texture2D, tooltip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(44.0, 44.0)
	button.icon = icon
	button.expand_icon = true
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _make_style(Color(0.06, 0.05, 0.035, 0.92), Color(0.46, 0.38, 0.23, 0.95)))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.11, 0.09, 0.06, 0.96), COLOR_GOLD))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.035, 0.028, 0.02, 0.98), Color(0.6, 0.48, 0.27, 1.0)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("icon_normal_color", Color(0.84, 0.74, 0.54, 1.0))
	button.add_theme_color_override("icon_hover_color", COLOR_GOLD_BRIGHT)
	button.add_theme_color_override("icon_pressed_color", COLOR_GOLD)
	return button

func _make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.anti_aliasing = true
	return box

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if not _input_blocked():
				_attack_with_equipped()
				get_viewport().set_input_as_handled()
			if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				if mouse_event.pressed and not _input_blocked():
					_orbit_camera = true
					get_viewport().set_input_as_handled()
				return
				if not mouse_event.pressed:
					_orbit_camera = false
					get_viewport().set_input_as_handled()
				return
			return
		return

	if not (event is InputEventKey):
		return

	if event.is_action_pressed("ui_cancel"):
		if not _any_overlay_open():
			_toggle_pause()
			get_viewport().set_input_as_handled()
		return

func _toggle_pause() -> void:
	if _pause.visible:
		_pause.close_panel()
		return
	if _input_blocked():
		return
	_open_overlay(_pause)
	get_tree().paused = true

## The pause panel closes itself on ESC or the close button while the tree is
## paused (it runs with PROCESS_MODE_ALWAYS), so unpausing lives on `closed`.
func _on_pause_closed() -> void:
	get_tree().paused = false

func _on_pause_settings() -> void:
	# Unpause first: the settings panel and HUD freeze while the tree pauses.
	get_tree().paused = false
	_show_settings()

func _on_quit_to_title() -> void:
	# The paused state survives scene changes, so release it explicitly.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _on_quit_game() -> void:
	get_tree().quit()

func _activate_slot(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var slot := _slots[index]
	var data: Dictionary = _slot_data[index]
	_select_slot(index)

	if str(data["kind"]) == "skill_slot":
		var skill_id := str(data.get("skill", ""))
		if skill_id.is_empty():
			show_toast("That skill slot is empty.  Open the skill library (K) to assign one.")
			return
		if slot.cooldown_remaining > 0.0:
			show_toast("%s is still recovering." % SKILL_LIBRARY.skill_name(skill_id))
			return
		if not _cast_skill(skill_id):
			return
		slot.start_cooldown(float(data["cooldown"]))
		return

	if slot.cooldown_remaining > 0.0:
		show_toast("That is still recovering.")
		return

	match str(data["kind"]):
		"health":
			if _health >= MAX_HEALTH - 0.5:
				show_toast("Your health is already full.")
				return
			if slot.stack <= 0 or not _inventory.consume_item("health"):
				show_toast("No crimson draughts remain.  Mira sells more.")
				return
			_health = minf(MAX_HEALTH, _health + 45.0)
			_refresh_vitals()
			_sync_item_stacks()
			show_toast("The crimson draught restores 45 health.")
		"mana":
			if _mana >= MAX_MANA - 0.5:
				show_toast("Your mana is already full.")
				return
			if slot.stack <= 0 or not _inventory.consume_item("mana"):
				show_toast("No azure draughts remain.  Mira sells more.")
				return
			_mana = minf(MAX_MANA, _mana + 40.0)
			_refresh_vitals()
			_sync_item_stacks()
			show_toast("The azure draught restores 40 mana.")
		"light":
			if _player != null:
				var on := bool(_player.call("is_torch_on"))
				_player.call("set_torch", not on)
				if on:
					show_toast("You smother the torch.  The dusk returns.")
				else:
					show_toast("The pitch torch catches with a warm crackle.")
		"return":
			if _player != null:
				_player.call("return_to_spawn")
			show_toast("The scroll's runes flare.  You stand beside the old well again.")
		"inspect":
			show_toast("Moonpetal.  A pale herb that opens only at dusk.")

	var cooldown := float(data["cooldown"])
	if cooldown > 0.0:
		slot.start_cooldown(cooldown)

func _cast_skill(skill_id: String) -> bool:
	if _player == null:
		return false
	var skill: Dictionary = SKILL_LIBRARY.SKILLS.get(skill_id, {})
	if skill.is_empty():
		return false
	var skill_name := str(skill["name"])
	var mana_cost := float(skill.get("mana", 0.0))
	if mana_cost > 0.0 and _mana < mana_cost:
		show_toast("Not enough mana for %s.  (%.0f needed)" % [skill_name, mana_cost])
		return false
	if not bool(_player.call("perform_skill", skill_id)):
		show_toast("You are in the middle of something else.")
		return false
	if mana_cost > 0.0:
		_mana = maxf(0.0, _mana - mana_cost)
		_refresh_vitals()
	# The library describes what a talent does; the HUD only applies the parts it
	# owns (vitals and travel). Damage, projectiles and poses belong to the hero.
	match str(skill.get("effect", "")):
		"heal":
			_health = minf(MAX_HEALTH, _health + float(skill.get("amount", 0.0)))
			_refresh_vitals()
		"mana":
			_mana = minf(MAX_MANA, _mana + float(skill.get("amount", 0.0)))
			_refresh_vitals()
		"recall":
			_player.call("return_to_spawn")
	show_toast(str(skill.get("toast", "%s is cast." % skill_name)))
	return true

func _show_skills() -> void:
	if _skill_list == null:
		return
	if _inventory.visible:
		_inventory.close()
	_skill_list.set_assigned(_assigned_skills())
	_skill_list.open_browser(_school_hint())
	_open_overlay(_skill_list as OverlayPanel)

func _school_hint() -> String:
	if _player == null:
		return "sword"
	var weapon := str(_player.get("equipped_weapon"))
	return weapon if SKILL_LIBRARY.SCHOOLS.has(weapon) else "sword"

func _assigned_skills() -> Array:
	var result := []
	for i in SLOT_COUNT:
		result.append(str(_slot_data[i].get("skill", "")))
	return result

func _on_slot_assign_requested(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or _skill_list == null:
		return
	if _inventory.visible:
		_inventory.close()
	_skill_list.set_assigned(_assigned_skills())
	_skill_list.open_for_slot(index, _school_hint())
	_open_overlay(_skill_list as OverlayPanel)

func _on_skill_chosen(skill_id: String, slot_index: int) -> void:
	if not SKILL_LIBRARY.is_valid_skill(skill_id):
		return
	_assign_skill(slot_index, skill_id)
	_skill_list.set_assigned(_assigned_skills())

func _on_skill_clear_requested(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	if str(_slot_data[slot_index].get("skill", "")).is_empty():
		return
	_set_slot_skill(slot_index, "")
	_skill_list.set_assigned(_assigned_skills())
	show_toast("Cleared skill slot %d." % (slot_index + 1))

func _assign_skill(slot_index: int, skill_id: String) -> void:
	var existing := _skill_slot_of(skill_id)
	if existing == slot_index:
		return
	var previous := str(_slot_data[slot_index].get("skill", ""))
	if existing >= 0:
		# Swap rather than duplicate: a talent can only sit in one slot.
		_set_slot_skill(existing, previous)
	_set_slot_skill(slot_index, skill_id)
	show_toast("%s assigned to slot %d.  Right-click a slot to change it." % [SKILL_LIBRARY.skill_name(skill_id), slot_index + 1])

func _set_slot_skill(slot_index: int, skill_id: String) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	var data: Dictionary = _slot_data[slot_index]
	var slot := _skill_slots[slot_index]
	if SKILL_LIBRARY.SKILLS.has(skill_id):
		var skill: Dictionary = SKILL_LIBRARY.SKILLS[skill_id]
		var school: Dictionary = SKILL_LIBRARY.school(str(skill.get("school", "")))
		data["skill"] = skill_id
		data["icon"] = skill["icon"]
		data["name"] = str(skill["name"])
		data["cooldown"] = float(skill["cooldown"])
		slot.set_item(skill["icon"], str(skill["name"]), 0)
		slot.tooltip_text = "%s  ·  %s\n%s\nRight-click to reassign." % [
			str(school.get("name", "")).to_upper(),
			str(skill["name"]),
			str(skill["description"]),
		]
	else:
		data["skill"] = ""
		data["icon"] = null
		data["name"] = ""
		data["cooldown"] = 0.0
		slot.clear_item()

func _skill_slot_of(skill_id: String) -> int:
	for i in SLOT_COUNT:
		if str(_slot_data[i].get("skill", "")) == skill_id:
			return i
	return -1

func _attack_with_equipped() -> void:
	if _player == null:
		return
	if not bool(_player.call("attack")):
		show_toast("You are still recovering.  Give it a breath.")

func _on_slot_activated(index: int) -> void:
	_activate_slot(index)

func _select_slot(index: int) -> void:
	_selected_slot = index
	for i in _slots.size():
		_slots[i].set_selected(i == index)

func _on_weapon_changed(weapon_id: String) -> void:
	_announced_weapon = weapon_id
	_update_weapon_label(weapon_id)
	_refresh_journal()
	_inventory.set_equipped(weapon_id)
	if _player != null:
		_inventory.set_equipped_offhand(str(_player.get("equipped_offhand")))
	var data: Dictionary = WeaponLibrary.WEAPONS.get(weapon_id, {})
	if not data.is_empty():
		show_toast("Equipped %s.  Open the satchel to choose another." % str(data["name"]))

func _on_offhand_changed(offhand_id: String) -> void:
	_inventory.set_equipped_offhand(offhand_id)
	_refresh_journal()
	var data: Dictionary = OFFHAND_LIBRARY.get_offhand(offhand_id)
	if not data.is_empty():
		show_toast("Off-hand: %s.  %s" % [str(data["name"]), str(data["effect"])])
	if _player != null and str(_player.get("equipped_weapon")) in ["bow", "kitsune"]:
		show_toast("%s is stowed: this weapon needs both hands." % str(data.get("name", "The off-hand")))

func _on_attack_started(weapon_id: String) -> void:
	_update_weapon_label(weapon_id)

func _update_weapon_label(weapon_id: String) -> void:
	var data: Dictionary = WeaponLibrary.WEAPONS.get(weapon_id, {})
	if data.is_empty():
		_weapon_label.text = ""
		return
	_weapon_label.text = "%s  ·  %s" % [str(data["class"]).to_upper(), str(data["name"]).to_upper()]

func _on_enemy_hit(target: Node, amount: float) -> void:
	if target != null and target.is_in_group("training_dummy") and _quest_stage == 1:
		_dummies_hit += 1
		_xp = minf(MAX_XP, _xp + amount * 3.0)
		_refresh_progress()
		if _dummies_hit >= 3:
			_quest_stage = 2
			show_toast("Three clean strikes.  The Wayfarer is waiting by the well.")
		_refresh_quest()
	else:
		_xp = minf(MAX_XP, _xp + amount * 3.0)
		_refresh_progress()
	_refresh_journal()

func _on_interaction_changed(prompt: String) -> void:
	_current_prompt = prompt
	_prompt_text.text = prompt
	_update_prompt_visibility()

func _interact() -> void:
	if _player == null:
		return
	if not bool(_player.call("interact")):
		show_toast("There is nothing within reach.")

func _damage(amount: float) -> void:
	_health = maxf(1.0, _health - amount)
	_refresh_vitals()
	show_toast("You take %d damage.  (H / J to test)" % int(amount))

func _heal(amount: float) -> void:
	_health = minf(MAX_HEALTH, _health + amount)
	_refresh_vitals()
	show_toast("You recover %d health." % int(amount))

func _toggle_inventory() -> void:
	if _inventory.visible:
		_inventory.close()
		return
	_hide_overlays_immediately()
	_inventory.open()
	_inventory.set_equipped(str(_player.get("equipped_weapon")) if _player != null else "sword")
	_inventory.set_equipped_offhand(str(_player.get("equipped_offhand")) if _player != null else "shield")
	_sync_world_lock()
	_prompt.visible = false

func _on_inventory_closed() -> void:
	_sync_world_lock()

func _on_inventory_weapon_selected(weapon_id: String) -> void:
	if _player == null:
		return
	_player.call("equip_weapon", weapon_id)
	_inventory.set_equipped(weapon_id)

func _on_inventory_offhand_selected(offhand_id: String) -> void:
	if _player == null:
		return
	_player.call("equip_offhand", offhand_id)
	_inventory.set_equipped_offhand(offhand_id)

func _on_inventory_item_used(item_id: String) -> void:
	match item_id:
		"health":
			if _health >= MAX_HEALTH - 0.5:
				show_toast("Your health is already full.")
				return
			if _inventory.get_item_count(item_id) <= 0:
				show_toast("No crimson draughts remain.  Mira sells more.")
				return
			_health = minf(MAX_HEALTH, _health + 45.0)
			_refresh_vitals()
			_inventory.consume_item(item_id)
			_sync_item_stacks()
			show_toast("The crimson draught restores 45 health.")
		"mana":
			if _mana >= MAX_MANA - 0.5:
				show_toast("Your mana is already full.")
				return
			if _inventory.get_item_count(item_id) <= 0:
				show_toast("No azure draughts remain.  Mira sells more.")
				return
			_mana = minf(MAX_MANA, _mana + 40.0)
			_refresh_vitals()
			_inventory.consume_item(item_id)
			_sync_item_stacks()
			show_toast("The azure draught restores 40 mana.")
		"waybread":
			if _health >= MAX_HEALTH - 0.5:
				show_toast("Your health is already full.")
				return
			if _inventory.get_item_count(item_id) <= 0:
				show_toast("The waybread is gone.")
				return
			_health = minf(MAX_HEALTH, _health + 25.0)
			_refresh_vitals()
			_inventory.consume_item(item_id)
			_sync_item_stacks()
			show_toast("The waybread restores 25 health.")
		"torch":
			if _player != null:
				var on := bool(_player.call("is_torch_on"))
				_player.call("set_torch", not on)
				show_toast("You smother the torch.  The dusk returns." if on else "The pitch torch catches with a warm crackle.")
		"return":
			if _player != null:
				_player.call("return_to_spawn")
			show_toast("The scroll's runes flare.  You stand beside the old well again.")
		"map":
			_inventory.close()
			_show_map()
		"moonpetal":
			show_toast("Moonpetal.  A pale herb that opens only at dusk.")
		"soulstone":
			show_toast("The soulstone hums.  Somewhere, the Reach answers.")
		"key":
			show_toast("A cold iron key.  No lock in the grove fits it.")
		"ring":
			show_toast("The band is warm, as though someone just slipped it off.")
		"gold":
			show_toast("Eighty-six coins.  A wayfarer's honest wage.")
		"shield":
			show_toast("You raise the oaken buckler.  It has seen worse roads.")
		_:
			show_toast("You turn the keepsake over in your hand.")
	_sync_item_stacks()

func _show_journal() -> void:
	if _journal.visible:
		_journal.close_panel()
		return
	_refresh_journal()
	_open_overlay(_journal)

func _refresh_journal() -> void:
	var weapon := str(_player.get("equipped_weapon")) if _player != null else "sword"
	var offhand := str(_player.get("equipped_offhand")) if _player != null else "shield"
	_journal.refresh(_quest_stage, _dummies_hit, weapon, offhand, _story_snapshot())

func _story_snapshot() -> Dictionary:
	return {
		"story": _story_stage,
		"beasts": _beasts_culled,
		"side": _side_stage,
		"wolves": _wolves_culled,
		"shrine": _shrine_lit,
		"boss": _boss_defeated,
	}

func _show_map() -> void:
	if _map.visible:
		_map.close_panel()
		return
	_open_overlay(_map)

func _show_settings() -> void:
	_settings.set_hints_enabled(_hint_panel.visible)
	_settings.set_vignette_enabled(_vignette.visible)
	_open_overlay(_settings)

func _open_overlay(panel: OverlayPanel) -> void:
	if _inventory.visible:
		_inventory.close()
	for other in _overlays:
		if other != panel and other.visible:
			other.close_panel()
	panel.open()
	_sync_world_lock()
	_prompt.visible = false

func _close_overlays() -> void:
	for panel in _overlays:
		if panel.visible:
			panel.close_panel()

func _hide_overlays_immediately() -> void:
	for panel in _overlays:
		panel.visible = false
		panel.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_overlay_closed() -> void:
	_sync_world_lock()

func _any_overlay_open() -> bool:
	for panel in _overlays:
		if panel.visible:
			return true
	return false

func _input_blocked() -> bool:
	return _any_overlay_open() or _inventory.visible

func _sync_world_lock() -> void:
	var blocked := _input_blocked()
	if _player != null:
		_player.call("set_movement_locked", blocked)
		if blocked:
			_player.call("set_aim_facing", false)
	_update_prompt_visibility()

## The pointer is a true screen-space cursor. The HUD casts a camera ray through
## it onto the ground plane, clamps the hit to the hero's reach and hands that
## world point to the player, so aiming is always exactly where the pointer sits
## while WASD movement stays free. Overlays hide the aim line but never the
## cursor itself.
func _update_aim() -> void:
	if _player == null:
		return
	var viewport := get_viewport()
	var mouse := viewport.get_mouse_position()
	var blocked := _input_blocked()
	if _reticle != null:
		_reticle.call("set_aim_visible", not blocked)
	_player.call("set_aim_facing", not blocked)
	if blocked:
		return
	var camera := viewport.get_camera_3d()
	if camera == null:
		return
	var player_position: Vector3 = _player.global_position
	var screen_center := viewport.get_visible_rect().size * 0.5
	var offset := mouse - screen_center
	var aim: Vector3
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_normal := camera.project_ray_normal(mouse)
	var hit: Variant = Plane(Vector3.UP, player_position.y).intersects_ray(ray_origin, ray_normal)
	if hit != null:
		aim = hit as Vector3
	else:
		# The pointer is above the horizon: fall back to the camera's ground
		# basis so the hero still turns sensibly instead of snapping.
		if offset.length() < 6.0:
			return
		var camera_basis := camera.global_transform.basis
		var right := camera_basis.x
		right.y = 0.0
		var forward := -camera_basis.z
		forward.y = 0.0
		if right.length_squared() < 0.001 or forward.length_squared() < 0.001:
			return
		var direction := (right.normalized() * offset.x - forward.normalized() * offset.y).normalized()
		aim = player_position + direction * 8.0
	var flat := Vector3(aim.x - player_position.x, 0.0, aim.z - player_position.z)
	if flat.length() > 18.0:
		flat = flat.normalized() * 18.0
	elif flat.length() < 0.35:
		flat = -_player.global_transform.basis.z
		flat.y = 0.0
		flat = flat.normalized() * 3.0
	_aim_point = player_position + flat
	_aim_point.y = player_position.y
	_has_aim = true
	_player.call("set_aim_point", _aim_point)

func _update_prompt_visibility() -> void:
	_prompt.visible = not _input_blocked() and not _current_prompt.is_empty()

func show_wayfarer_dialogue() -> void:
	if _dialogue == null:
		return
	var body := ""
	var choices: Array = []
	match _quest_stage:
		0:
			body = "You have the look of someone between roads, friend. The straw men by the well won't mind a few honest blows. Strike three of them cleanly and I'll pay you a wayfarer's wage."
			choices = [
				{"id": "accept", "label": "I'll take the errand"},
				{"id": "close", "label": "Another time"},
			]
		1:
			body = "Three clean strikes, friend. The dummies don't bite, and the Reach has been quiet all evening. I'll be here when you're done."
			choices = [{"id": "close", "label": "I'll see it done"}]
		2:
			body = "Ah, there you are. The straw men are still standing, which is more than I can say for my purse. A promise is a promise."
			choices = [
				{"id": "reward", "label": "Take the purse"},
				{"id": "close", "label": "Not yet"},
			]
		_:
			body = "The well is deep and the road is long, but you've earned a warm fire and a full purse. Go well, Aldric. The Reach will remember you."
			choices = [{"id": "close", "label": "Go well"}]
	_open_dialogue("The Wayfarer", body, choices)

func show_well_dialogue() -> void:
	_open_dialogue(
		"The Old Well",
		"The water is black and very still. Your lantern light sinks a little way, then is swallowed. Far below, a bucket knocks softly against stone. The rope is frayed, and the air smells of rain.",
		[{"id": "close", "label": "Step back from the well"}]
	)

func show_npc_dialogue(npc_id: String) -> void:
	match npc_id:
		"elder_rowan":
			_show_elder_dialogue()
		"mira":
			_show_mira_dialogue()
		"bran":
			_show_bran_dialogue()
		"tomas":
			_show_tomas_dialogue()
		"nell":
			_open_dialogue(
				"Nell",
				"Elder Rowan keeps the hall at the head of the square. If you mean to go through the south gate, hear him first. The briars have been closer this season than I like.",
				[{"id": "close", "label": "Thank you, Nell"}]
			)
		"garrick":
			_open_dialogue(
				"Old Garrick",
				"The gate road runs south, past the last lamp and under the ruined arch. Mosslings in the grass, wolves in the briars, and lights that move when the wind does not. Keep your shield arm loose.",
				[{"id": "close", "label": "I'll mind the road"}]
			)
		"wren":
			_open_dialogue(
				"Wren",
				"The wayshrine used to burn green every dusk. My grandmother said it held the briars back. Now it is cold, and the Warden walks in the far clearing. If Rowan asks you to light it, do not go alone in the dark.",
				[{"id": "close", "label": "I'll remember"}]
			)
		_:
			_open_dialogue(
				"Townsfolk",
				"Good evening, traveler. Hearthmere has a warm fire and a long road, and you look like you have met both.",
				[{"id": "close", "label": "Good evening"}]
			)

func _show_elder_dialogue() -> void:
	match _story_stage:
		0:
			_open_dialogue(
				"Elder Rowan",
				"You have the look of someone between roads, friend. Hearthmere has a gate that no longer keeps the dark out. Mosslings and briar wolves press the Thorned Field, and the old wayshrine has gone cold. Will you take up the watch?",
				[
					{"id": "story_accept", "label": "I'll take up the watch"},
					{"id": "close", "label": "Another time"},
				]
			)
		1:
			_open_dialogue(
				"Elder Rowan",
				"Eight beasts, friend. Not a hunt for sport, but a thinning of the field. Drive them back from the gate road and return to me. The town will sleep easier for it.",
				[{"id": "close", "label": "I'll see it done"}]
			)
		2:
			_open_dialogue(
				"Elder Rowan",
				"You have done what the gate guard could not. Take this purse, and hear the rest. The briars will not truly retreat until the wayshrine burns again.",
				[
					{"id": "story_claim", "label": "Take the first payment"},
					{"id": "close", "label": "Not yet"},
				]
			)
		3:
			_open_dialogue(
				"Elder Rowan",
				"The wayshrine lies southwest of the field, ringed by leaning stones. Carry a light and touch the crystal. When it wakes, the Warden will know, and it will come for you. Be ready.",
				[{"id": "close", "label": "I'll light it"}]
			)
		4:
			_open_dialogue(
				"Elder Rowan",
				"The shrine burns, and the briars are pulling back. But the Briar Warden has woken in the far clearing. End it, and Hearthmere will owe you a debt we cannot quickly repay.",
				[{"id": "close", "label": "I'll end it"}]
			)
		5:
			_open_dialogue(
				"Elder Rowan",
				"The Warden is fallen. I did not think to see the field quiet again. Stand still a moment, friend. Hearthmere has more than coin to give you.",
				[
					{"id": "story_final", "label": "Accept the elder's gift"},
					{"id": "close", "label": "Later"},
				]
			)
		_:
			_open_dialogue(
				"Elder Rowan",
				"The gate stands open and the road is quiet. You have done Hearthmere a great service, Aldric. Warm your hands at any fire in this town, and know that the Reach remembers.",
				[{"id": "close", "label": "Go well, Elder"}]
			)

func _show_mira_dialogue() -> void:
	var extra := " The roads have been unkind to travelers, so I keep the good draughts under the counter."
	if _story_stage >= 3 and not _shrine_lit:
		extra = " If you are going to the shrine, take a light and a spare draught. The briars do not bargain."
	elif _shrine_lit:
		extra = " The green light on the horizon is a fine sight. I have been selling more lantern oil than I know what to do with."
	_open_dialogue(
		"Mira",
		"Potions, waybread and moonpetal, all honest and most of it fresh. Coin first, questions after." + extra,
		[
			{"id": "shop_mira", "label": "Browse Mira's wares"},
			{"id": "close", "label": "Just passing through"},
		]
	)

func _show_bran_dialogue() -> void:
	var extra := " I can hone an edge or set a rivet in that shield of yours. Permanent work, not market polish."
	if _story_stage >= 3 and not _shrine_lit:
		extra = " If you mean to wake the shrine, have your steel seen to first. The Warden does not care how brave you are."
	elif _shrine_lit:
		extra = " That green light means the field is stirring. Good. A forge likes a little work."
	_open_dialogue(
		"Bran",
		"The forge is hot and the anvil is free. What needs mending?" + extra,
		[
			{"id": "shop_bran", "label": "Browse Bran's forge"},
			{"id": "close", "label": "Nothing today"},
		]
	)

func _show_tomas_dialogue() -> void:
	match _side_stage:
		0:
			_open_dialogue(
				"Tomas",
				"The briar wolves have been at my traps again. Four of them, maybe more, working the field beyond the gate. I would go myself, but someone has to hold this gate. Thin them out and I'll make it worth your while.",
				[
					{"id": "tomas_accept", "label": "I'll hunt the wolves"},
					{"id": "close", "label": "Not now"},
				]
			)
		1:
			_open_dialogue(
				"Tomas",
				"Four briar wolves. The pack runs the field and the ruined arch. They are quick, but they turn wide after a lunge. Use that.",
				[{"id": "close", "label": "I'll find them"}]
			)
		2:
			_open_dialogue(
				"Tomas",
				"That is the last of them. The traps will hold now. Here, take this. A hunter pays what a hunter promises.",
				[
					{"id": "tomas_claim", "label": "Take the hunter's purse"},
					{"id": "close", "label": "Later"},
				]
			)
		_:
			_open_dialogue(
				"Tomas",
				"The field is quieter for your work, friend. If the briars send more, I know who to call.",
				[{"id": "close", "label": "Good hunting, Tomas"}]
			)

func _open_dialogue(speaker: String, body: String, choices: Array) -> void:
	if _dialogue == null:
		return
	if _inventory.visible:
		_inventory.close()
	for other in _overlays:
		if other != _dialogue and other.visible:
			other.close_panel()
	_dialogue.present(speaker, body, choices)
	_sync_world_lock()
	_prompt.visible = false

func _on_dialogue_choice(choice_id: String) -> void:
	match choice_id:
		"accept":
			if _quest_stage == 0:
				_quest_stage = 1
				_dummies_hit = 0
				_refresh_quest()
				show_toast("Errand accepted.  Strike the practice dummies three times.")
			_dialogue.present(
				"The Wayfarer",
				"Three clean strikes, friend. The dummies don't bite. I'll be here when you're done.",
				[{"id": "close", "label": "I'll see it done"}]
			)
		"reward":
			if _quest_stage == 2:
				_quest_stage = 3
				_gold += QUEST_REWARD
				_xp = minf(MAX_XP, _xp + 500.0)
				_refresh_progress()
				_refresh_quest()
				show_toast("The Wayfarer pays you %d gold.  The errand is complete." % QUEST_REWARD)
			_dialogue.close_panel()
		"story_accept":
			if _story_stage == 0:
				_story_stage = 1
				_beasts_culled = 0
				_refresh_quest()
				show_toast("The Briar Watch begins.  Cull %d beasts in the Thorned Field." % STORY_BEASTS_REQUIRED)
			_dialogue.present(
				"Elder Rowan",
				"Eight beasts, friend. Drive them back from the gate road and return to me. The town will sleep easier for it.",
				[{"id": "close", "label": "I'll see it done"}]
			)
		"story_claim":
			if _story_stage == 2:
				_story_stage = 3
				_gold += STORY_REWARD_A_GOLD
				_xp = minf(MAX_XP, _xp + STORY_REWARD_A_XP)
				_refresh_progress()
				_refresh_quest()
				show_toast("Elder Rowan pays you %d gold and %s experience." % [STORY_REWARD_A_GOLD, _format_number(STORY_REWARD_A_XP)])
			_dialogue.present(
				"Elder Rowan",
				"The wayshrine lies southwest of the field, ringed by leaning stones. Carry a light and touch the crystal. When it wakes, the Warden will know, and it will come for you. Be ready.",
				[{"id": "close", "label": "I'll light it"}]
			)
		"story_final":
			if _story_stage == 5:
				_story_stage = 6
				_gold += STORY_REWARD_B_GOLD
				_xp = minf(MAX_XP, _xp + STORY_REWARD_B_XP)
				_refresh_progress()
				_refresh_quest()
				show_toast("Hearthmere pays its debt: %d gold and %s experience." % [STORY_REWARD_B_GOLD, _format_number(STORY_REWARD_B_XP)])
			_dialogue.present(
				"Elder Rowan",
				"The gate stands open and the road is quiet. You have done Hearthmere a great service, Aldric. Warm your hands at any fire in this town, and know that the Reach remembers.",
				[{"id": "close", "label": "Go well, Elder"}]
			)
		"tomas_accept":
			if _side_stage == 0:
				_side_stage = 1
				_wolves_culled = 0
				_refresh_quest()
				show_toast("Tomas's Hunt begins.  Kill %d briar wolves in the Thorned Field." % STORY_SIDE_WOLVES_REQUIRED)
			_dialogue.present(
				"Tomas",
				"Four briar wolves. The pack runs the field and the ruined arch. They are quick, but they turn wide after a lunge. Use that.",
				[{"id": "close", "label": "I'll find them"}]
			)
		"tomas_claim":
			if _side_stage == 2:
				_side_stage = 3
				_gold += SIDE_REWARD_GOLD
				_xp = minf(MAX_XP, _xp + SIDE_REWARD_XP)
				_refresh_progress()
				_refresh_quest()
				show_toast("Tomas pays you %d gold and %s experience." % [SIDE_REWARD_GOLD, _format_number(SIDE_REWARD_XP)])
			_dialogue.close_panel()
		"shop_mira":
			_open_shop("mira")
		"shop_bran":
			_open_shop("bran")
		_:
			_dialogue.close_panel()

func _on_hints_toggled(enabled: bool) -> void:
	_hint_panel.visible = enabled

func _on_vignette_toggled(enabled: bool) -> void:
	_vignette.visible = enabled

func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

# ---------------------------------------------------------------------------
# Shops
# ---------------------------------------------------------------------------

func _open_shop(shop_id: String) -> void:
	if _shop == null:
		return
	var data: Dictionary = SHOP_STOCK.get(shop_id, {})
	if data.is_empty():
		return
	_shop.call(
		"present",
		shop_id,
		str(data["title"]),
		str(data["subtitle"]),
		str(data["description"]),
		data["stock"],
		_gold,
		_purchases.get(shop_id, {}),
		_shop_note(shop_id)
	)
	_open_overlay(_shop)

func _shop_note(shop_id: String) -> String:
	if shop_id == "bran":
		var bran_ledger: Dictionary = _purchases["bran"]
		var whetstones := int(bran_ledger.get("whetstone", 0))
		var rivets := int(bran_ledger.get("rivet", 0))
		return "Bran's work so far:  %d whetstones (+%d power)  ·  %d rivets (+%d%% guard)." % [
			whetstones, whetstones * 2, rivets, rivets * 3,
		]
	var ledger: Dictionary = _purchases.get(shop_id, {})
	var bought := 0
	for value in ledger.values():
		bought += int(value)
	return "Mira's ledger:  %d purchases this evening." % bought

func _on_shop_purchase(shop_id: String, item_id: String) -> void:
	var data: Dictionary = SHOP_STOCK.get(shop_id, {})
	if data.is_empty():
		return
	var entry := {}
	for candidate in data["stock"]:
		if str(candidate.get("id", "")) == item_id:
			entry = candidate
			break
	if entry.is_empty():
		return
	var ledger: Dictionary = _purchases.get(shop_id, {})
	var bought := int(ledger.get(item_id, 0))
	var limit := int(entry.get("max", 0))
	if limit > 0 and bought >= limit:
		show_toast("That is all they will part with tonight.")
		return
	var price := int(entry.get("price", 0))
	if price > _gold:
		show_toast("Not enough gold.  (%d needed)" % price)
		return
	var bought_name := str(entry.get("name", item_id))
	match item_id:
		"whetstone":
			if _player == null:
				return
			_player.call("upgrade_weapon_power", 2.0)
		"rivet":
			if _player == null:
				return
			_player.call("upgrade_mitigation", 0.03)
		_:
			if not _inventory.add_item(item_id):
				show_toast("Your satchel has no room for that.")
				return
	_gold -= price
	ledger[item_id] = bought + 1
	_purchases[shop_id] = ledger
	_refresh_progress()
	_sync_item_stacks()
	_open_shop(shop_id)
	if item_id == "whetstone":
		show_toast("Bran hones your weapon.  +2 attack power.")
	elif item_id == "rivet":
		show_toast("Bran sets a rivet in your guard.  +3% damage reduction.")
	else:
		show_toast("You buy %s for %d gold." % [bought_name, price])

# ---------------------------------------------------------------------------
# Story events from the world
# ---------------------------------------------------------------------------

func on_monster_killed(monster: Node, variant: String, is_boss: bool, xp_reward: float, gold_reward: int) -> void:
	var xp_gain := xp_reward
	var gold_gain := gold_reward
	if _player != null:
		xp_gain *= float(_player.call("xp_multiplier"))
		gold_gain = roundi(float(gold_gain) * float(_player.call("gold_multiplier")))
	_xp = minf(MAX_XP, _xp + xp_gain)
	_gold += gold_gain
	var notes: Array[String] = []

	if _story_stage == 1 and (variant == "mossling" or variant == "briar_wolf"):
		_beasts_culled += 1
		if _beasts_culled >= STORY_BEASTS_REQUIRED:
			_story_stage = 2
			notes.append("The field is thinner.  Return to Elder Rowan.")
	if _side_stage == 1 and variant == "briar_wolf":
		_wolves_culled += 1
		if _wolves_culled >= STORY_SIDE_WOLVES_REQUIRED:
			_side_stage = 2
			notes.append("Tomas's wolves are done.  Return to him at the gate.")
	if is_boss:
		_boss_defeated = true
		if _story_stage == 4:
			_story_stage = 5
			notes.append("The Briar Warden falls.  Return to Elder Rowan.")
		elif _story_stage < 4:
			notes.append("The Briar Warden is fallen, but the wayshrine is still cold.")

	_refresh_progress()
	_refresh_quest()

	if not notes.is_empty():
		var summary := ""
		for note in notes:
			if not summary.is_empty():
				summary += "  "
			summary += str(note)
		show_toast(summary, 3.4)
	else:
		var fallen := str(monster.get("display_name")) if monster != null else "The beast"
		show_toast("%s falls.  +%d XP  ·  +%d gold." % [fallen, roundi(xp_gain), gold_gain], 2.2)

func on_shrine_interact(shrine: Node) -> void:
	if shrine == null:
		return
	var already_lit := _shrine_lit
	if shrine.has_method("is_lit"):
		already_lit = already_lit or bool(shrine.call("is_lit"))
	if already_lit:
		show_toast("The wayshrine burns steadily.  The briars keep their distance.")
		return
	if _story_stage < 3:
		show_toast("The shrine is cold and dark.  Elder Rowan may know how to wake it.")
		return
	if shrine.has_method("light_up"):
		shrine.call("light_up")
	_shrine_lit = true
	if _story_stage == 3:
		_story_stage = 4
		if _boss_defeated:
			_story_stage = 5
		for boss in get_tree().get_nodes_in_group("enemy_boss"):
			if boss.has_method("awaken"):
				boss.call("awaken")
		if _boss_defeated:
			show_toast("The shrine wakes.  The Warden is already fallen; return to Elder Rowan.", 3.4)
		else:
			show_toast("The shrine wakes in green fire.  Something vast stirs in the far clearing.", 3.4)
	else:
		show_toast("The wayshrine wakes.  Green light spills across the briars.", 3.0)
	_refresh_quest()

# ---------------------------------------------------------------------------
# Damage, death and recovery
# ---------------------------------------------------------------------------

func apply_incoming_damage(raw: float, _source_position := Vector3.ZERO) -> void:
	if _dead or _falling or _input_blocked():
		return
	var dealt := raw
	if _player != null and _player.has_method("mitigate_damage"):
		dealt = float(_player.call("mitigate_damage", raw))
	_health = maxf(0.0, _health - dealt)
	_refresh_vitals()
	if _health <= 0.0:
		_fall()
	else:
		show_toast("A blow lands for %d damage." % roundi(dealt), 1.4)

func _fall() -> void:
	if _falling:
		return
	_falling = true
	_dead = true
	_health = 0.0
	_refresh_vitals()
	if _player != null:
		_player.call("set_movement_locked", true)
		_player.call("set_aim_facing", false)
	show_toast("Your strength fails.  The Reach grows dark...", 2.4)
	await get_tree().create_timer(1.9).timeout
	if not is_inside_tree():
		return
	var lost := mini(_gold, DEATH_GOLD_LOSS)
	_gold -= lost
	_health = MAX_HEALTH * 0.6
	_mana = MAX_MANA * 0.5
	_dead = false
	_falling = false
	if _player != null:
		_player.call("return_to_spawn")
		_player.call("set_movement_locked", _input_blocked())
	_refresh_vitals()
	_refresh_progress()
	var message := "You wake at the edge of Hearthmere."
	if lost > 0:
		message += "  You lost %d gold on the road." % lost
	show_toast(message, 3.2)

# ---------------------------------------------------------------------------
# HUD bookkeeping
# ---------------------------------------------------------------------------

func _sync_item_stacks() -> void:
	if _inventory == null or _slots.size() < 10:
		return
	for i in QUICK_ITEM_IDS.size():
		var slot_index := 5 + i
		var count := _inventory.get_item_count(str(QUICK_ITEM_IDS[i]))
		_slot_data[slot_index]["stack"] = count
		_slots[slot_index].set_stack(count)

func _update_zone(delta: float) -> void:
	if _player == null:
		return
	var position: Vector3 = _player.global_position
	var id := "town"
	if position.z < -86.0:
		id = "warden"
	elif position.distance_to(Vector3(-6.0, 0.0, -74.0)) < 14.0:
		id = "shrine"
	elif position.z < -31.0:
		id = "field"
	if id != _zone_id:
		_zone_id = id
		var info: Dictionary = ZONE_INFO.get(id, {})
		_zone_title.text = str(info.get("title", "THE VERDANT REACH"))
		_zone_sub.text = str(info.get("subtitle", ""))
		_zone_banner.modulate.a = 1.0
		_zone_timer = 4.0
	if _zone_timer > 0.0:
		_zone_timer = maxf(0.0, _zone_timer - delta)
		if _zone_timer < 1.0:
			_zone_banner.modulate.a = clampf(_zone_timer, 0.0, 1.0)

func _update_boss_bar() -> void:
	if _boss != null and (not is_instance_valid(_boss) or bool(_boss.get("dormant")) or bool(_boss.call("is_defeated"))):
		_boss = null
	if _boss == null:
		for candidate in get_tree().get_nodes_in_group("enemy_boss"):
			if not is_instance_valid(candidate):
				continue
			if bool(candidate.get("dormant")):
				continue
			if candidate.has_method("is_defeated") and bool(candidate.call("is_defeated")):
				continue
			_boss = candidate
			break
	var show := _boss != null and not _dead
	_boss_bar.visible = show
	if not show:
		return
	_boss_name.text = str(_boss.get("display_name")).to_upper()
	_boss_fill.set_values(float(_boss.get("health")), float(_boss.get("max_health")))


func _refresh_quest() -> void:
	_quest_title.text = "THE BRIAR WATCH"
	_quest_chapter.text = "CHAPTER II  ·  THE THORNED FIELD"

	var first := ""
	var second := ""
	var third := ""
	var reward := ""
	var first_state := "pending"
	var second_state := "pending"
	var third_state := "pending"

	match _story_stage:
		0:
			first = "·  Seek Elder Rowan in Hearthmere square"
			second = "·  Ask the townsfolk what stirs beyond the gate"
			first_state = "active"
			reward = "REWARD      %d GOLD  ·  %s XP" % [STORY_REWARD_A_GOLD, _format_number(STORY_REWARD_A_XP)]
		1:
			first = "·  Cull the beasts in the Thorned Field    %d / %d" % [mini(_beasts_culled, STORY_BEASTS_REQUIRED), STORY_BEASTS_REQUIRED]
			second = "·  Follow the south road through the gate"
			first_state = "active"
			reward = "REWARD      %d GOLD  ·  %s XP" % [STORY_REWARD_A_GOLD, _format_number(STORY_REWARD_A_XP)]
		2:
			first = "✓  The beasts are thinned"
			second = "·  Return to Elder Rowan for the first payment"
			first_state = "done"
			second_state = "active"
			reward = "REWARD READY      %d GOLD  ·  %s XP" % [STORY_REWARD_A_GOLD, _format_number(STORY_REWARD_A_XP)]
		3:
			first = "✓  Elder Rowan's blessing received"
			second = "·  Light the wayshrine in the Thorned Field"
			first_state = "done"
			second_state = "active"
			reward = "REWARD      %d GOLD  ·  %s XP  ·  THE WARDEN" % [STORY_REWARD_B_GOLD, _format_number(STORY_REWARD_B_XP)]
		4:
			first = "✓  The wayshrine burns"
			second = "·  Defeat the Briar Warden in the far clearing"
			first_state = "done"
			second_state = "active"
			reward = "REWARD      %d GOLD  ·  %s XP" % [STORY_REWARD_B_GOLD, _format_number(STORY_REWARD_B_XP)]
		5:
			first = "✓  The Briar Warden is fallen"
			second = "·  Return to Elder Rowan in Hearthmere"
			first_state = "done"
			second_state = "active"
			reward = "REWARD READY      %d GOLD  ·  %s XP" % [STORY_REWARD_B_GOLD, _format_number(STORY_REWARD_B_XP)]
		_:
			first = "✓  The Briar Watch is broken"
			second = "·  Hearthmere is quiet.  The road is yours again."
			first_state = "done"
			second_state = "done"
			reward = "COMPLETE      ·      BOTH REWARDS RECEIVED"

	match _side_stage:
		0:
			third = "·  Tomas has work for a hunter by the gate"
			third_state = "pending"
		1:
			third = "·  Tomas's Hunt: briar wolves    %d / %d" % [mini(_wolves_culled, STORY_SIDE_WOLVES_REQUIRED), STORY_SIDE_WOLVES_REQUIRED]
			third_state = "active"
		2:
			third = "·  Return to Tomas at the south gate"
			third_state = "active"
		_:
			third = "✓  Tomas's Hunt is complete"
			third_state = "done"

	_set_objective(_objective1, first, first_state)
	_set_objective(_objective2, second, second_state)
	_set_objective(_objective3, third, third_state)

	if _story_stage >= 6:
		_reward_label.add_theme_color_override("font_color", COLOR_DONE)
	elif _story_stage == 2 or _story_stage == 5:
		_reward_label.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	else:
		_reward_label.add_theme_color_override("font_color", COLOR_MUTED)
	_reward_label.text = reward

	_refresh_quest_markers()
	_refresh_journal()

func _set_objective(label: Label, text: String, state: String) -> void:
	if label == null:
		return
	label.text = text
	var color := COLOR_PENDING
	match state:
		"done":
			color = COLOR_DONE
		"active":
			color = COLOR_GOLD
		_:
			color = COLOR_PENDING
	label.add_theme_color_override("font_color", color)

func _refresh_quest_markers() -> void:
	for npc in get_tree().get_nodes_in_group("npc"):
		if not npc.has_method("set_quest_marker"):
			continue
		var marker := ""
		match str(npc.get("npc_id")):
			"elder_rowan":
				if _story_stage == 0:
					marker = "!"
				elif _story_stage == 2 or _story_stage == 5:
					marker = "?"
			"tomas":
				if _side_stage == 0:
					marker = "!"
				elif _side_stage == 2:
					marker = "?"
			"mira", "bran":
				marker = "$"
		npc.call("set_quest_marker", marker)

func show_toast(text: String, duration := 2.6) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_timer = duration

func _process(delta: float) -> void:
	_update_aim()
	_update_zone(delta)
	_update_boss_bar()

	var vitals_changed := false
	if _health < MAX_HEALTH:
		_health = minf(MAX_HEALTH, _health + 0.8 * delta)
		vitals_changed = true
	if _mana < MAX_MANA:
		_mana = minf(MAX_MANA, _mana + 2.4 * delta)
		vitals_changed = true
	if vitals_changed:
		_refresh_vitals()

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.55:
			_toast.modulate.a = clampf(_toast_timer / 0.55, 0.0, 1.0)

func _refresh_vitals() -> void:
	_health_bar.set_values(_health, MAX_HEALTH)
	_mana_bar.set_values(_mana, MAX_MANA)
	_health_value.text = "%d / %d" % [roundi(_health), int(MAX_HEALTH)]
	_mana_value.text = "%d / %d" % [roundi(_mana), int(MAX_MANA)]

func _refresh_progress() -> void:
	_xp_bar.set_values(_xp, MAX_XP)
	_xp_value.text = "%s / %s XP" % [_format_number(_xp), _format_number(MAX_XP)]
	$Root/Quickbar/LevelLabel.text = "LEVEL %d" % _level
	$Root/PlayerPanel/Level.text = "LEVEL %d" % _level
	$Root/GoldPanel/GoldValue.text = _format_number(_gold)
	$Root/Inventory/Panel/GoldValue.text = _format_number(_gold)
	_inventory.set_gold(_gold)

func _format_number(number: float) -> String:
	var digits := str(int(number))
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result
