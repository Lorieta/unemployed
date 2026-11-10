class_name WeaponLibrary
extends RefCounted

## Shared catalogue of the demo's weapons. The HUD, inventory, character and
## journal all read from this one place so the skill bar, satchel and combat
## animations never drift apart.

const ICON_SWORD := preload("res://assets/ui/icons/sword.svg")
const ICON_BOW := preload("res://assets/ui/icons/bow.svg")
const ICON_STAFF := preload("res://assets/ui/icons/staff.svg")
const ICON_DAGGER := preload("res://assets/ui/icons/dagger.svg")
const ICON_KITSUNE := preload("res://assets/ui/icons/kitsune.svg")

const ORDER := ["sword", "bow", "staff", "dagger", "kitsune"]

const WEAPONS := {
	"sword": {
		"name": "Wayfarer's Blade",
		"class": "LONGSWORD",
		"skill": "Vanguard Arc",
		"skill_verb": "Sweep",
		"icon": ICON_SWORD,
		"damage": 34.0,
		"cooldown": 0.78,
		"anim_duration": 0.64,
		"range": 2.9,
		"style": "Broad, committed arcs",
		"description": "A balanced arming sword. Heavy diagonal sweeps with a step into the cut.",
		"trail_color": Color(0.96, 0.87, 0.6, 0.75),
	},
	"bow": {
		"name": "Hunting Bow",
		"class": "LONGBOW",
		"skill": "Trueshot",
		"skill_verb": "Loose",
		"icon": ICON_BOW,
		"damage": 30.0,
		"cooldown": 1.1,
		"anim_duration": 0.95,
		"range": 16.0,
		"style": "Draw, hold, release",
		"description": "A yew bow. Raise, draw to the cheek, hold a breath, then loose a swift arrow.",
		"trail_color": Color(0.9, 0.8, 0.55, 0.0),
	},
	"staff": {
		"name": "Spiritwood Staff",
		"class": "QUARTERSTAFF",
		"skill": "Spirit Slam",
		"skill_verb": "Cast",
		"icon": ICON_STAFF,
		"damage": 26.0,
		"cooldown": 1.3,
		"anim_duration": 1.05,
		"range": 3.0,
		"style": "Overhead cast and slam",
		"description": "A living staff crowned with a pale crystal. Raised overhead, then driven down in a ringing shockwave.",
		"trail_color": Color(0.55, 0.95, 0.88, 0.55),
	},
	"dagger": {
		"name": "Thistle Dagger",
		"class": "DAGGER",
		"skill": "Thistle Flurry",
		"skill_verb": "Flurry",
		"icon": ICON_DAGGER,
		"damage": 16.0,
		"cooldown": 0.66,
		"anim_duration": 0.5,
		"range": 2.2,
		"style": "Quick double thrust",
		"description": "A short, wicked blade. Two snapping thrusts with a low lunge between them.",
		"trail_color": Color(0.95, 0.95, 1.0, 0.6),
	},
	"kitsune": {
		"name": "Kitsune Ember",
		"class": "SPIRIT RELIC",
		"skill": "Foxfire",
		"skill_verb": "Beckon",
		"icon": ICON_KITSUNE,
		"damage": 12.0,
		"cooldown": 1.2,
		"anim_duration": 0.9,
		"range": 12.0,
		"style": "Floating spirit, darting wisps",
		"description": "A fox-spirit flame that hovers above the palm. The caster sweeps a hand and three embers dart after a foe.",
		"trail_color": Color(0.6, 0.98, 0.9, 0.6),
	},
}
