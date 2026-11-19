class_name CharacterLibrary
extends RefCounted

## The five heroes of the Reach. Each character is bound to one weapon and one
## school of talents, so a playthrough is a class: the Knight always carries the
## longsword and studies the Sword school, the Ranger always carries the bow,
## and so on. The main menu reads this catalogue to build the character cards,
## and the HUD uses it to lock the armory and the skill library to the path.

const ICON_SWORD := preload("res://assets/ui/icons/sword.svg")
const ICON_BOW := preload("res://assets/ui/icons/bow.svg")
const ICON_STAFF := preload("res://assets/ui/icons/staff.svg")
const ICON_DAGGER := preload("res://assets/ui/icons/dagger.svg")
const ICON_KITSUNE := preload("res://assets/ui/icons/kitsune.svg")

const ORDER := ["knight", "ranger", "arcanist", "shadow", "spiritcaller"]

const CHARACTERS := {
	"knight": {
		"name": "Aldric",
		"title": "THE KNIGHT",
		"weapon": "sword",
		"school": "sword",
		"icon": ICON_SWORD,
		"color": Color(0.86, 0.77, 0.56, 1.0),
		"blurb": "A sworn blade who walked away from the banner. Planted, weighty, and hard to move. The longsword answers only to a steady shoulder.",
		"forte": "STEEL  ·  GUARD  ·  HEAVY CUTS",
	},
	"ranger": {
		"name": "Sylva",
		"title": "THE RANGER",
		"weapon": "bow",
		"school": "bow",
		"icon": ICON_BOW,
		"color": Color(0.62, 0.79, 0.51, 1.0),
		"blurb": "The Reach raised her and the road taught her the rest. Quiet steps, a long eye, and an arrow for everything that stirs in the briars.",
		"forte": "DISTANCE  ·  VOLLEYS  ·  PRECISION",
	},
	"arcanist": {
		"name": "Mereth",
		"title": "THE ARCANIST",
		"weapon": "staff",
		"school": "staff",
		"icon": ICON_STAFF,
		"color": Color(0.68, 0.76, 0.94, 1.0),
		"blurb": "A scholar of the old well who learned that the water remembers. Fire, frost and storm answer the crystal, for a price in mana.",
		"forte": "SPELLS  ·  WARDS  ·  MENDING",
	},
	"shadow": {
		"name": "Vex",
		"title": "THE SHADOW",
		"weapon": "dagger",
		"school": "dagger",
		"icon": ICON_DAGGER,
		"color": Color(0.83, 0.53, 0.51, 1.0),
		"blurb": "Nobody hires a shadow and nobody catches one. Close the gap, spend the opening, and be gone before the answer comes.",
		"forte": "SPEED  ·  FLURRIES  ·  POISONS",
	},
	"spiritcaller": {
		"name": "Kira",
		"title": "THE SPIRITCALLER",
		"weapon": "kitsune",
		"school": "kitsune",
		"icon": ICON_KITSUNE,
		"color": Color(0.95, 0.72, 0.44, 1.0),
		"blurb": "The fox-spirit chose her, or she chose it; neither will say. Foxfire hunts on its own, and the road always leads back to the well.",
		"forte": "FOXFIRE  ·  SPIRITS  ·  TRICKS",
	},
}

static func get_character(character_id: String) -> Dictionary:
	return CHARACTERS.get(character_id, CHARACTERS["knight"])

static func weapon_of(character_id: String) -> String:
	return str(get_character(character_id).get("weapon", "sword"))
