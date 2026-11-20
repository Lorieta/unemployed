class_name GearLibrary
extends RefCounted

## Class-bound relics of the Hollow Crown. Each hero can find one weapon and four
## armour pieces; every piece is a permanent upgrade rather than a temporary
## consumable. Chests roll "gear_<slot>" tokens which the HUD resolves to the
## current hero's next missing relic, so a cache is always useful to the class
## that opened it.

const ICON_SWORD := preload("res://assets/ui/icons/sword.svg")
const ICON_BOW := preload("res://assets/ui/icons/bow.svg")
const ICON_STAFF := preload("res://assets/ui/icons/staff.svg")
const ICON_DAGGER := preload("res://assets/ui/icons/dagger.svg")
const ICON_KITSUNE := preload("res://assets/ui/icons/kitsune.svg")
const ICON_HELM := preload("res://assets/ui/icons/helm.svg")
const ICON_ARMOR := preload("res://assets/ui/icons/armor.svg")
const ICON_GLOVES := preload("res://assets/ui/icons/gloves.svg")
const ICON_BOOTS := preload("res://assets/ui/icons/boots.svg")

const SLOT_ORDER := ["weapon", "head", "body", "hands", "feet"]
const SLOT_LABELS := {
	"weapon": "MAIN HAND",
	"head": "HEAD",
	"body": "BODY",
	"hands": "HANDS",
	"feet": "FEET",
}
const CLASS_SCHOOLS := {
	"knight": "sword",
	"ranger": "bow",
	"arcanist": "staff",
	"shadow": "dagger",
	"spiritcaller": "kitsune",
}
const WEAPON_ICONS := {
	"sword": ICON_SWORD,
	"bow": ICON_BOW,
	"staff": ICON_STAFF,
	"dagger": ICON_DAGGER,
	"kitsune": ICON_KITSUNE,
}
const SLOT_ICONS := {
	"head": ICON_HELM,
	"body": ICON_ARMOR,
	"hands": ICON_GLOVES,
	"feet": ICON_BOOTS,
}

const SETS := {
	"knight": {
		"weapon": {
			"id": "crown_crownsunder",
			"name": "Crownsunder",
			"description": "A blackened longsword with a seam of crown-gold down the fuller. It bites through obsidian as if through old snow.",
			"bonus": {"power": 15.0, "mitigation": 0.015, "health": 20.0},
		},
		"head": {
			"id": "crown_helm_knight",
			"name": "Crownward Helm",
			"description": "A knight's helm reforged with a circlet of broken crown-spikes. The visor never fogs.",
			"bonus": {"power": 3.0, "mitigation": 0.03, "health": 18.0},
		},
		"body": {
			"id": "crown_plate",
			"name": "Sovereign Plate",
			"description": "Ember-lit plate from the Sovereign's own guard. Heavy, warm, and difficult to argue with.",
			"bonus": {"power": 4.0, "mitigation": 0.05, "health": 36.0},
		},
		"hands": {
			"id": "crown_gauntlets",
			"name": "Emberfist Gauntlets",
			"description": "Knuckles of fused ash and iron. Every blow leaves a faint line of fire behind.",
			"bonus": {"power": 6.0, "mitigation": 0.015, "health": 10.0},
		},
		"feet": {
			"id": "crown_greaves",
			"name": "Ashen Greaves",
			"description": "Greaves that drink the heat of the road. The Hollow Crown's cinders cannot slow them.",
			"bonus": {"power": 2.0, "mitigation": 0.02, "health": 14.0},
		},
	},
	"ranger": {
		"weapon": {
			"id": "crown_longbow",
			"name": "Hollow Longbow",
			"description": "A bow cut from a black-glass rib, strung with a thread of ember-silk. Its arrows sing.",
			"bonus": {"power": 17.0, "mitigation": 0.005, "health": 12.0, "mana": 6.0},
		},
		"head": {
			"id": "crown_hood",
			"name": "Whisper Hood",
			"description": "A stalker's hood lined with ash-fox fur. It swallows the sound of your passing.",
			"bonus": {"power": 4.0, "mitigation": 0.02, "health": 14.0, "mana": 8.0},
		},
		"body": {
			"id": "crown_scale",
			"name": "Ashscale Jerkin",
			"description": "Overlapping scales of heat-cracked basalt. Light enough to draw from and tough enough to matter.",
			"bonus": {"power": 5.0, "mitigation": 0.035, "health": 28.0, "mana": 8.0},
		},
		"hands": {
			"id": "crown_grips",
			"name": "Stalker's Grips",
			"description": "Gloves with black-glass knuckles. The draw comes faster; the release comes cleaner.",
			"bonus": {"power": 6.0, "mitigation": 0.01, "health": 10.0},
		},
		"feet": {
			"id": "crown_treads",
			"name": "Cinder Treads",
			"description": "Soft boots with soles of cooled lava. They leave no print in the ash.",
			"bonus": {"power": 3.0, "mitigation": 0.015, "health": 12.0, "mana": 4.0},
		},
	},
	"arcanist": {
		"weapon": {
			"id": "crown_starstaff",
			"name": "Ashen Starstaff",
			"description": "A staff crowned with a cinder star that never cools. It remembers every spell cast through it.",
			"bonus": {"power": 16.0, "mitigation": 0.005, "health": 10.0, "mana": 22.0},
		},
		"head": {
			"id": "crown_circlet",
			"name": "Hollow Circlet",
			"description": "A thin ring of black glass and gold. Thoughts arrive more quickly beneath it.",
			"bonus": {"power": 3.0, "mitigation": 0.015, "health": 12.0, "mana": 14.0},
		},
		"body": {
			"id": "crown_robes",
			"name": "Sovereign Robes",
			"description": "Layered robes stitched with ember-thread. The hem never quite touches the ground.",
			"bonus": {"power": 4.0, "mitigation": 0.03, "health": 24.0, "mana": 20.0},
		},
		"hands": {
			"id": "crown_wraps",
			"name": "Emberweave Wraps",
			"description": "Thin wraps that channel heat without burning. Every gesture leaves a spark in the air.",
			"bonus": {"power": 5.0, "mitigation": 0.01, "health": 8.0, "mana": 10.0},
		},
		"feet": {
			"id": "crown_slippers",
			"name": "Ashstep Slippers",
			"description": "Slippers that hover a finger's width above the ash. Walking feels like a rumour.",
			"bonus": {"power": 2.0, "mitigation": 0.015, "health": 10.0, "mana": 8.0},
		},
	},
	"shadow": {
		"weapon": {
			"id": "crown_fang",
			"name": "Obsidian Fang",
			"description": "A dagger ground from a single stalker's blade. It is always cold, even in the cinder wind.",
			"bonus": {"power": 18.0, "mitigation": 0.005, "health": 12.0},
		},
		"head": {
			"id": "crown_cowl",
			"name": "Nightglass Cowl",
			"description": "A cowl of woven shadow and black glass. Eyes slide off it and forget what they saw.",
			"bonus": {"power": 4.0, "mitigation": 0.02, "health": 14.0, "mana": 6.0},
		},
		"body": {
			"id": "crown_leathers",
			"name": "Crownshadow Leathers",
			"description": "Supple leather reinforced with obsidian scales. It moves without a sound.",
			"bonus": {"power": 5.0, "mitigation": 0.04, "health": 30.0},
		},
		"hands": {
			"id": "crown_claws",
			"name": "Glassclaw Wraps",
			"description": "Wraps tipped with blades of black glass. They find the seam in any guard.",
			"bonus": {"power": 7.0, "mitigation": 0.01, "health": 8.0},
		},
		"feet": {
			"id": "crown_steps",
			"name": "Silent Steps",
			"description": "Boots whose soles are cut from the Hollow Crown's quietest stone.",
			"bonus": {"power": 3.0, "mitigation": 0.02, "health": 10.0},
		},
	},
	"spiritcaller": {
		"weapon": {
			"id": "crown_kitsune",
			"name": "Sovereign Foxfire",
			"description": "A kitsune relic wreathed in pale crown-fire. The fox within it has stopped pretending to sleep.",
			"bonus": {"power": 15.0, "mitigation": 0.005, "health": 14.0, "mana": 16.0},
		},
		"head": {
			"id": "crown_mask",
			"name": "Hollow Mask",
			"description": "A fox mask of ash-wood and gold. Behind it, the spirit world is a little closer.",
			"bonus": {"power": 3.0, "mitigation": 0.015, "health": 14.0, "mana": 12.0},
		},
		"body": {
			"id": "crown_mantle",
			"name": "Ashen Mantle",
			"description": "A mantle of cinder-feathers that stirs without wind. The dead bow their heads to it.",
			"bonus": {"power": 4.0, "mitigation": 0.03, "health": 28.0, "mana": 18.0},
		},
		"hands": {
			"id": "crown_talismans",
			"name": "Cinder Talismans",
			"description": "A fistful of burning paper charms. They curl and re-form around your fingers.",
			"bonus": {"power": 5.0, "mitigation": 0.01, "health": 10.0, "mana": 12.0},
		},
		"feet": {
			"id": "crown_sandals",
			"name": "Ashroad Sandals",
			"description": "Simple sandals that leave brief, glowing fox prints on the ash.",
			"bonus": {"power": 2.0, "mitigation": 0.015, "health": 12.0, "mana": 8.0},
		},
	},
}

static func set_for_class(class_id: String) -> Dictionary:
	return SETS.get(class_id, SETS["knight"])

static func gear_for_slot(class_id: String, slot: String) -> Dictionary:
	return set_for_class(class_id).get(slot, {})

static func item_by_id(item_id: String) -> Dictionary:
	for class_id in SETS:
		var set: Dictionary = SETS[class_id]
		for slot in SLOT_ORDER:
			var data: Dictionary = set.get(slot, {})
			if str(data.get("id", "")) == item_id:
				var result := data.duplicate(true)
				result["class"] = class_id
				result["slot"] = slot
				result["icon"] = _icon_for(class_id, slot)
				result["type"] = SLOT_LABELS.get(slot, "RELIC")
				return result
	return {}

static func _icon_for(class_id: String, slot: String) -> Texture2D:
	if slot == "weapon":
		return WEAPON_ICONS.get(str(CLASS_SCHOOLS.get(class_id, "sword")), ICON_SWORD)
	return SLOT_ICONS.get(slot, ICON_ARMOR)

static func item_definitions() -> Dictionary:
	var definitions := {}
	for class_id in SETS:
		for slot in SLOT_ORDER:
			var data := relic_for(class_id, slot)
			if data.is_empty():
				continue
			definitions[str(data["id"])] = {
				"icon": data["icon"],
				"name": data["name"],
				"description": "%s\n\n%s  ·  %s\nClick to bind this relic and gain its permanent stats." % [
					data["description"], SLOT_LABELS.get(slot, "RELIC"), _stat_line(data),
				],
				"gear": true,
				"class": class_id,
				"slot": slot,
			}
	return definitions

static func relic_for(class_id: String, slot: String) -> Dictionary:
	var data: Dictionary = gear_for_slot(class_id, slot)
	if data.is_empty():
		return {}
	var result := data.duplicate(true)
	result["class"] = class_id
	result["slot"] = slot
	result["icon"] = _icon_for(class_id, slot)
	result["type"] = SLOT_LABELS.get(slot, "RELIC")
	return result

static func is_gear(item_id: String) -> bool:
	return not item_by_id(item_id).is_empty()

static func class_of(item_id: String) -> String:
	return str(item_by_id(item_id).get("class", ""))

static func slot_of(item_id: String) -> String:
	return str(item_by_id(item_id).get("slot", ""))

static func school_of(item_id: String) -> String:
	return str(CLASS_SCHOOLS.get(class_of(item_id), "sword"))

static func _stat_line(data: Dictionary) -> String:
	var bonus: Dictionary = data.get("bonus", {})
	var parts: Array[String] = []
	var power := float(bonus.get("power", 0.0))
	if power > 0.0:
		parts.append("+%d POWER" % roundi(power))
	var mitigation := float(bonus.get("mitigation", 0.0))
	if mitigation > 0.0:
		parts.append("+%d%% WARD" % roundi(mitigation * 100.0))
	var health := float(bonus.get("health", 0.0))
	if health > 0.0:
		parts.append("+%d HEALTH" % roundi(health))
	var mana := float(bonus.get("mana", 0.0))
	if mana > 0.0:
		parts.append("+%d MANA" % roundi(mana))
	return "  ·  ".join(parts)

static func stat_line(item_id: String) -> String:
	var data := item_by_id(item_id)
	return _stat_line(data) if not data.is_empty() else ""

static func total_bonus(owned: Array) -> Dictionary:
	var total := {"power": 0.0, "mitigation": 0.0, "health": 0.0, "mana": 0.0}
	for item_id in owned:
		var data := item_by_id(str(item_id))
		if data.is_empty():
			continue
		var bonus: Dictionary = data.get("bonus", {})
		total["power"] = float(total["power"]) + float(bonus.get("power", 0.0))
		total["mitigation"] = float(total["mitigation"]) + float(bonus.get("mitigation", 0.0))
		total["health"] = float(total["health"]) + float(bonus.get("health", 0.0))
		total["mana"] = float(total["mana"]) + float(bonus.get("mana", 0.0))
	return total

static func next_upgrade(class_id: String, owned: Array, slot := "") -> String:
	var worn := {}
	for item_id in owned:
		var data := item_by_id(str(item_id))
		if not data.is_empty():
			worn[str(data["slot"])] = true
	var slots: Array = [slot] if not slot.is_empty() else SLOT_ORDER
	for candidate in slots:
		if worn.has(str(candidate)):
			continue
		var data := gear_for_slot(class_id, str(candidate))
		if not data.is_empty():
			return str(data["id"])
	return ""

static func equipped_item(class_id: String, owned: Array, slot: String) -> String:
	for item_id in owned:
		var data := item_by_id(str(item_id))
		if not data.is_empty() and str(data.get("class", "")) == class_id and str(data.get("slot", "")) == slot:
			return str(item_id)
	return ""
