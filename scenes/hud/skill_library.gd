class_name SkillLibrary
extends RefCounted

## The learned talents, grouped into the five weapon schools of the road.
##
## The HUD's five assignable slots read from this catalogue, and the character
## reads the same entries for cast duration, pose, damage and projectile timing.
## Skills are deliberately *not* weapons: every weapon is still equipped only
## through the satchel armory. A talent may sit in one slot at a time.

const ICON_DASH := preload("res://assets/ui/icons/boots.svg")
const ICON_GUARD := preload("res://assets/ui/icons/shield.svg")
const ICON_HEAL := preload("res://assets/ui/icons/herb.svg")
const ICON_FOCUS := preload("res://assets/ui/icons/gem.svg")
const ICON_RECALL := preload("res://assets/ui/icons/scroll.svg")
const ICON_SLASH := preload("res://assets/ui/icons/armor.svg")
const ICON_HELM := preload("res://assets/ui/icons/helm.svg")

const SCHOOL_ORDER := ["sword", "bow", "staff", "dagger", "kitsune"]

const SCHOOLS := {
	"sword": {
		"name": "Sword",
		"subtitle": "STEEL AND STEP",
		"icon": WeaponLibrary.ICON_SWORD,
		"color": Color(0.86, 0.77, 0.56, 1.0),
		"description": "Knightly pressure: close the distance, set the shoulder, and finish with a committed arc.",
	},
	"bow": {
		"name": "Bow",
		"subtitle": "BREATH AND DISTANCE",
		"icon": WeaponLibrary.ICON_BOW,
		"color": Color(0.62, 0.79, 0.51, 1.0),
		"description": "Hunter's patience: steady the aim, loose a true arrow, or darken the sky with a volley.",
	},
	"staff": {
		"name": "Staff",
		"subtitle": "SPIRIT AND STONE",
		"icon": WeaponLibrary.ICON_STAFF,
		"color": Color(0.68, 0.76, 0.94, 1.0),
		"description": "Wizardry of the old well: mend what is broken, ward the circle, and ring the ground like a bell.",
	},
	"dagger": {
		"name": "Dagger",
		"subtitle": "SHADOW AND FLURRY",
		"icon": WeaponLibrary.ICON_DAGGER,
		"color": Color(0.83, 0.53, 0.51, 1.0),
		"description": "Rogue's arithmetic: arrive unseen, spend the opening, and leave before the answer comes.",
	},
	"kitsune": {
		"name": "Kitsune",
		"subtitle": "FOXFIRE AND RETURN",
		"icon": WeaponLibrary.ICON_KITSUNE,
		"color": Color(0.95, 0.72, 0.44, 1.0),
		"description": "Spirit-relic grace: send foxfire hunting, borrow a little warmth, and slip back to the well.",
	},
}

## `pose` selects the whole-body casting animation in `tiny_human.gd`.
## `effect` tells the character and HUD what the talent actually does.
const SKILLS := {
	# --- Sword -----------------------------------------------------------
	"windstep": {
		"school": "sword",
		"name": "Windstep",
		"tag": "MOBILITY",
		"icon": ICON_DASH,
		"mana": 10.0,
		"cooldown": 4.0,
		"duration": 0.42,
		"pose": "dash",
		"effect": "dash",
		"toast": "Windstep carries you forward.",
		"description": "A low, wind-backed dash toward the aim mark. The cape snaps and the boots barely touch the road.",
	},
	"bulwark": {
		"school": "sword",
		"name": "Bulwark",
		"tag": "GUARD",
		"icon": ICON_GUARD,
		"mana": 8.0,
		"cooldown": 8.0,
		"duration": 0.62,
		"pose": "guard",
		"effect": "guard",
		"toast": "Bulwark. You set your shoulder behind the guard.",
		"description": "Set the shoulder and shrug off the next blows. A knight's answer to a bad angle.",
	},
	"vanguard_arc": {
		"school": "sword",
		"name": "Vanguard Arc",
		"tag": "STRIKE",
		"icon": WeaponLibrary.ICON_SWORD,
		"mana": 18.0,
		"cooldown": 9.0,
		"duration": 0.78,
		"pose": "slash",
		"effect": "strike",
		"damage": 58.0,
		"reach": 3.2,
		"hit_time": 0.42,
		"min_dot": 0.05,
		"toast": "Vanguard Arc cuts a wide, final line.",
		"description": "A full-bodied diagonal cut with a step behind it. Heavy enough to end a duel.",
	},

	# --- Bow -------------------------------------------------------------
	"trueshot": {
		"school": "bow",
		"name": "Trueshot",
		"tag": "SHOT",
		"icon": WeaponLibrary.ICON_BOW,
		"mana": 14.0,
		"cooldown": 7.0,
		"duration": 0.86,
		"pose": "shot",
		"effect": "projectile",
		"damage": 48.0,
		"release_time": 0.62,
		"toast": "Trueshot flies straight and true.",
		"description": "Draw past the cheek, hold the breath, and put one arrow exactly where the box is looking.",
	},
	"steady_aim": {
		"school": "bow",
		"name": "Steady Aim",
		"tag": "FOCUS",
		"icon": ICON_FOCUS,
		"mana": 0.0,
		"cooldown": 10.0,
		"duration": 0.92,
		"pose": "focus",
		"effect": "mana",
		"amount": 35.0,
		"toast": "Steady Aim returns 35 mana.",
		"description": "Centre the breath, still the hands, and recover 35 mana. A hunter's quiet between shots.",
	},
	"rain_of_arrows": {
		"school": "bow",
		"name": "Rain of Arrows",
		"tag": "VOLLEY",
		"icon": WeaponLibrary.ICON_BOW,
		"mana": 26.0,
		"cooldown": 13.0,
		"duration": 1.22,
		"pose": "volley",
		"effect": "volley",
		"damage": 22.0,
		"count": 5,
		"first_shot": 0.54,
		"shot_gap": 0.075,
		"spread": 0.14,
		"toast": "Rain of Arrows darkens the air.",
		"description": "Five quick shafts in a fan. Not subtle, but the ground ahead becomes a bad place to stand.",
	},

	# --- Staff -----------------------------------------------------------
	"spirit_slam": {
		"school": "staff",
		"name": "Spirit Slam",
		"tag": "SLAM",
		"icon": WeaponLibrary.ICON_STAFF,
		"mana": 20.0,
		"cooldown": 10.0,
		"duration": 1.0,
		"pose": "slam",
		"effect": "shockwave",
		"damage": 48.0,
		"reach": 3.2,
		"radius": 3.7,
		"hit_time": 0.62,
		"toast": "Spirit Slam rings the ground like a bell.",
		"description": "Raise the crystal overhead, then drive it down. A pale shockwave rolls out around the staff.",
	},
	"mend": {
		"school": "staff",
		"name": "Mend",
		"tag": "RESTORE",
		"icon": ICON_HEAL,
		"mana": 22.0,
		"cooldown": 12.0,
		"duration": 0.86,
		"pose": "mend",
		"effect": "heal",
		"amount": 45.0,
		"toast": "Mend closes your wounds.  +45 health.",
		"description": "A quiet word over the crystal closes wounds and restores 45 health.",
	},
	"aegis": {
		"school": "staff",
		"name": "Aegis",
		"tag": "WARD",
		"icon": ICON_GUARD,
		"mana": 12.0,
		"cooldown": 14.0,
		"duration": 0.70,
		"pose": "guard",
		"effect": "guard",
		"toast": "Aegis settles over you like a second skin.",
		"description": "Draw a ward around the shoulders. The next blows break on the circle instead of on you.",
	},

	# --- Dagger ----------------------------------------------------------
	"shadowstep": {
		"school": "dagger",
		"name": "Shadowstep",
		"tag": "MOBILITY",
		"icon": ICON_DASH,
		"mana": 9.0,
		"cooldown": 4.5,
		"duration": 0.34,
		"pose": "dash",
		"effect": "dash",
		"toast": "Shadowstep takes you out of the line.",
		"description": "A short, low dart toward the aim mark. Fast enough to make the first strike the last word.",
	},
	"thistle_flurry": {
		"school": "dagger",
		"name": "Thistle Flurry",
		"tag": "FLURRY",
		"icon": WeaponLibrary.ICON_DAGGER,
		"mana": 16.0,
		"cooldown": 8.0,
		"duration": 0.72,
		"pose": "flurry",
		"effect": "strike",
		"damage": 18.0,
		"reach": 2.5,
		"hit_time": 0.20,
		"hit_gap": 0.18,
		"hits": 3,
		"min_dot": 0.0,
		"toast": "Thistle Flurry: three quick, wicked lines.",
		"description": "Three snapping thrusts with a low lunge between them. Small blade, no wasted motion.",
	},
	"smoke_veil": {
		"school": "dagger",
		"name": "Smoke Veil",
		"tag": "EVADE",
		"icon": ICON_GUARD,
		"mana": 11.0,
		"cooldown": 11.0,
		"duration": 0.60,
		"pose": "guard",
		"effect": "guard",
		"toast": "Smoke Veil. You become a difficult shape to hit.",
		"description": "Turn the shoulder into a smear of shadow and let the blow find nothing worth hitting.",
	},

	# --- Kitsune ---------------------------------------------------------
	"foxfire": {
		"school": "kitsune",
		"name": "Foxfire",
		"tag": "SPIRIT",
		"icon": WeaponLibrary.ICON_KITSUNE,
		"mana": 20.0,
		"cooldown": 9.0,
		"duration": 0.92,
		"pose": "spirit",
		"effect": "wisps",
		"damage": 18.0,
		"count": 3,
		"release_time": 0.32,
		"toast": "Foxfire hunts on its own.",
		"description": "Beckon the hovering flame and send three embers after the nearest foe. They curve; they do not miss.",
	},
	"spirit_mend": {
		"school": "kitsune",
		"name": "Spirit Mend",
		"tag": "RESTORE",
		"icon": ICON_HEAL,
		"mana": 20.0,
		"cooldown": 12.0,
		"duration": 0.86,
		"pose": "mend",
		"effect": "heal",
		"amount": 40.0,
		"toast": "Spirit Mend borrows a little warmth.  +40 health.",
		"description": "The fox-spirit shares its warmth. Wounds close, and the tail curls a little tighter.",
	},
	"fox_recall": {
		"school": "kitsune",
		"name": "Fox Recall",
		"tag": "RETURN",
		"icon": ICON_RECALL,
		"mana": 16.0,
		"cooldown": 16.0,
		"duration": 0.90,
		"pose": "recall",
		"effect": "recall",
		"toast": "Fox Recall flares. You stand beside the old well again.",
		"description": "Speak the fox-rune and step back to the old well, leaving only a thread of pale fire.",
	},
}

## Stable ordering for the library and for any generated skill lists.
const ORDER := [
	"windstep", "bulwark", "vanguard_arc",
	"trueshot", "steady_aim", "rain_of_arrows",
	"spirit_slam", "mend", "aegis",
	"shadowstep", "thistle_flurry", "smoke_veil",
	"foxfire", "spirit_mend", "fox_recall",
]

static func school(school_id: String) -> Dictionary:
	return SCHOOLS.get(school_id, {})

static func skill(skill_id: String) -> Dictionary:
	return SKILLS.get(skill_id, {})

static func skills_in_school(school_id: String) -> Array[String]:
	var result: Array[String] = []
	for skill_id in ORDER:
		if str(SKILLS[skill_id]["school"]) == school_id:
			result.append(skill_id)
	return result

static func school_of(skill_id: String) -> String:
	return str(SKILLS.get(skill_id, {}).get("school", ""))

static func skill_name(skill_id: String) -> String:
	return str(SKILLS.get(skill_id, {}).get("name", skill_id))

static func is_valid_skill(skill_id: String) -> bool:
	return SKILLS.has(skill_id)
