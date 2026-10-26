extends RefCounted

## Catalogue of the five off-hand choices carried on the left arm.
##
## The satchel armory and the hero read the same entries, so a shield selected
## in the inventory is the exact shield that appears on the rig. Each entry
## carries the little combat bonus it contributes, which the HUD applies when
## the player takes a hit and the hero applies when a blow lands.

const ICON_SHIELD := preload("res://assets/ui/icons/shield.svg")
const ICON_GLOVES := preload("res://assets/ui/icons/gloves.svg")
const ICON_BOOK := preload("res://assets/ui/icons/book.svg")
const ICON_RING := preload("res://assets/ui/icons/ring.svg")
const ICON_TORCH := preload("res://assets/ui/icons/torch.svg")

const ORDER := ["shield", "gauntlet", "tome", "charm", "lantern"]

const OFFHANDS := {
	"shield": {
		"name": "Warden's Shield",
		"class": "KITE SHIELD",
		"icon": ICON_SHIELD,
		"tagline": "Stand your ground",
		"description": "An oaken shield banded in old brass. It turns aside a third of every blow while raised, and still blunts what gets past.",
		"effect": "Blunts 12% of all damage, and 55% while guarding.",
		"bonus": {"damage_reduction": 0.12, "guard_reduction": 0.55},
	},
	"gauntlet": {
		"name": "Emberweave Gauntlet",
		"class": "WAR GLOVE",
		"icon": ICON_GLOVES,
		"tagline": "Every punch a forge",
		"description": "Scale and ember-thread wrapped around the left hand. The plates heat when the arm swings, lending weight to a close blow.",
		"effect": "Melee strikes deal 18% more damage.",
		"bonus": {"melee": 1.18},
	},
	"tome": {
		"name": "Tome of the Verdant",
		"class": "GRIMOIRE",
		"icon": ICON_BOOK,
		"tagline": "Words that bite",
		"description": "A living grimoire bound in moss-green leather. Its pages turn on their own, and the runes drift free when the wielder casts.",
		"effect": "Spells and missiles deal 15% more damage.",
		"bonus": {"spell": 1.15, "mana_regen": 1.25},
	},
	"charm": {
		"name": "Wayfarer's Charm",
		"class": "ROAD CHARM",
		"icon": ICON_RING,
		"tagline": "Fortune favours the footsore",
		"description": "A little brass sun on a leather cord. It was a gift, once. It still seems to nudge luck a coin's width toward its bearer.",
		"effect": "Enemies yield 25% more gold and 15% more experience.",
		"bonus": {"gold": 1.25, "xp": 1.15},
	},
	"lantern": {
		"name": "Foxfire Lantern",
		"class": "SPIRIT LAMP",
		"icon": ICON_TORCH,
		"tagline": "A light that follows",
		"description": "A cage of black iron around a wisp of green foxfire. It needs no oil, and it never quite goes out.",
		"effect": "Sheds a warm spirit-light and steadies the nerves (+8% guard).",
		"bonus": {"light": true, "guard_reduction": 0.08},
	},
}

static func has(offhand_id: String) -> bool:
	return OFFHANDS.has(offhand_id)

static func get_offhand(offhand_id: String) -> Dictionary:
	return OFFHANDS.get(offhand_id, {})

static func name_of(offhand_id: String) -> String:
	return str(OFFHANDS.get(offhand_id, {}).get("name", "Bare Hand"))
