class_name JournalPanel
extends OverlayPanel

## The journal: the Briar Watch story, the Wayfarer's tutorial errand, Tomas's
## hunt, notes on Hearthmere and the Thorned Field, a field guide to every
## weapon and off-hand, and the five skill schools. It reads the same
## WeaponLibrary, OffhandLibrary and SkillLibrary data as combat and the HUD, so
## the notes never drift from the world, and makes clear that weapons are
## equipped from the satchel armory while the five skill slots hold assignable
## talents.

const SKILL_LIBRARY := preload("res://scenes/hud/skill_library.gd")
const OFFHAND_LIBRARY := preload("res://scenes/player/offhands/offhand_library.gd")

const STORY_BEASTS_REQUIRED := 8
const STORY_SIDE_WOLVES_REQUIRED := 4

var _story_label: Label
var _tutorial_label: Label
var _side_label: Label
var _equipped_label: Label
var _note_label: Label

func _ready() -> void:
	title = "JOURNAL"
	subtitle = "THE TALE SO FAR"
	panel_size = Vector2(880.0, 620.0)
	super._ready()
	refresh(0, 0, "sword")

func _build_content() -> void:
	add_heading("THE BRIAR WATCH")
	_story_label = add_paragraph("Elder Rowan waits in the hall at the head of Hearthmere square. The Briar Watch has not been taken up in a generation.", PARCHMENT, 14)
	add_spacer(4.0)

	add_heading("THE WAYFARER'S ERRAND")
	_tutorial_label = add_paragraph("Speak with the Wayfarer by the old well.", MUTED, 12)

	add_heading("TOMAS'S HUNT")
	_side_label = add_paragraph("Tomas holds the south gate. He has work for a hunter.", MUTED, 12)

	add_row("EQUIPPED", "", GOLD)
	_equipped_label = add_paragraph("", GOLD_BRIGHT, 12)
	add_spacer(4.0)
	add_rule()

	add_heading("HEARTHMERE")
	add_paragraph("A lantern town at the north end of the Reach, built around a fountain plaza and held by an old gate. Elder Rowan keeps the hall, Mira keeps the market stall with the red awning, Bran keeps the forge, and Tomas keeps the gate. Follow the south road under the ruined arch and you are in the Thorned Field.", PARCHMENT, 13)
	add_rule()

	add_heading("THE THORNED FIELD")
	add_paragraph("Mosslings drift through the grass, briar wolves hunt in packs, and foxfire wisps carry their own cold light. The wayshrine stands southwest among leaning stones, and the Briar Warden sleeps in the far clearing until the shrine is lit. Beasts return to their ground after a time; the Warden does not.", PARCHMENT, 13)
	add_rule()

	add_heading("THE WAYFARER")
	add_paragraph("A quiet figure in a weathered green cloak, waiting where the road bends toward the old well. The lantern at their staff is always lit, even at noon. They have a way of asking questions that sound like answers.", PARCHMENT, 13)
	add_rule()

	add_heading("WEAPONS OF THE ROAD")
	add_paragraph("Every weapon is drawn from the satchel armory, never from the skill bar. Changing steel changes the whole silhouette: the hero dresses for the trade, then carries a different whole-body idle, walk, run and attack.", MUTED, 12)
	var outfits := {
		"sword": "Knight's blue tabard, plate cuirass, faulds and winged helm",
		"bow": "Hunter's green hood, crossed harness, quiver and wrapped boots",
		"staff": "Wizard's indigo robe, silver beard and tall pointed hat",
		"dagger": "Rogue's charcoal hood, face wrap, harness and belt knives",
		"kitsune": "White kimono, vermilion haori, fox ears and a living tail",
	}
	for weapon_id in WeaponLibrary.ORDER:
		var data: Dictionary = WeaponLibrary.WEAPONS[weapon_id]
		add_row("%s  ·  %s" % [data["name"], data["class"]], "%d DMG" % int(data["damage"]))
		add_paragraph("Outfit: %s." % str(outfits.get(weapon_id, "Traveling clothes")), MUTED, 11)
		add_paragraph("Signature: %s. %s" % [data["skill"], data["description"]], MUTED, 11)
	add_rule()

	add_heading("OFF-HAND ARTS")
	add_paragraph("Five off-hands are carried on the free left arm, chosen on the OFF-HAND page of the satchel armory. The bow and the kitsune need both hands and stow the off-hand while drawn.", MUTED, 12)
	for offhand_id in OFFHAND_LIBRARY.ORDER:
		var offhand: Dictionary = OFFHAND_LIBRARY.OFFHANDS[offhand_id]
		add_row("%s  ·  %s" % [offhand["name"], offhand["class"]], str(offhand["tagline"]).to_upper())
		add_paragraph(str(offhand["effect"]), MUTED, 11)
	add_rule()

	add_heading("THE FIVE SCHOOLS")
	add_paragraph("The five skill slots are filled from the gilded SKILL LIBRARY, filed into five weapon-school folders. A talent may sit in only one slot at a time; assigning it elsewhere moves it rather than copying it.", MUTED, 12)
	for school_id in SKILL_LIBRARY.SCHOOL_ORDER:
		var school: Dictionary = SKILL_LIBRARY.SCHOOLS[school_id]
		var talents := ""
		for skill_id in SKILL_LIBRARY.skills_in_school(school_id):
			if not talents.is_empty():
				talents += "  ·  "
			talents += str(SKILL_LIBRARY.SKILLS[skill_id]["name"])
		add_row("%s  ·  %s" % [school["name"], school["subtitle"]], "3 TALENTS")
		add_paragraph("%s  —  %s" % [talents, school["description"]], MUTED, 11)
	add_rule()

	add_heading("TRAVELER'S NOTES")
	add_paragraph("WASD / ARROWS  walk     SHIFT  run     LEFT CLICK or SPACE  attack with the equipped weapon     E  interact", MUTED, 11)
	add_paragraph("MOUSE  aim: a gilded cursor follows the pointer across the whole screen, a dotted line shows the hero's aim, and the hero turns to match it while standing still.", MUTED, 11)
	add_paragraph("1 - 5  cast the assigned talents     RIGHT-CLICK a skill slot or press K for the SKILL LIBRARY     6 - 0  item slots", MUTED, 11)
	add_paragraph("I  satchel and armory     J  journal     M  map     ESC closes any page     Hearthmere's shops open from Mira and Bran's dialogue.", MUTED, 11)
	add_paragraph("The five skill slots begin empty. Open the satchel (I) and click a weapon in the armory to equip it; the outfit changes with the weapon. Off-hands live on the second armory page.", MUTED, 11)
	_note_label = add_paragraph("", MUTED, 11)

func refresh(stage: int, hits: int, equipped: String, offhand := "", story := {}) -> void:
	if _story_label == null:
		return
	_story_label.text = _story_text(story)
	_tutorial_label.text = _tutorial_text(stage, hits)
	_side_label.text = _side_text(story)
	var data: Dictionary = WeaponLibrary.WEAPONS.get(equipped, {})
	if not data.is_empty():
		var text := "%s  ·  %s  ·  %d damage" % [data["name"], data["class"], int(data["damage"])]
		var off_data: Dictionary = OFFHAND_LIBRARY.get_offhand(offhand)
		if not off_data.is_empty():
			text += "\nOff-hand: %s  ·  %s" % [off_data["name"], off_data["effect"]]
		_equipped_label.text = text

func _story_text(story: Dictionary) -> String:
	var beasts := mini(int(story.get("beasts", 0)), STORY_BEASTS_REQUIRED)
	match int(story.get("story", 0)):
		0:
			return "Speak with Elder Rowan in the hall at the head of Hearthmere square. The Briar Watch has not been taken up in a generation."
		1:
			return "Cull the beasts pressing the gate road.   %d / %d beasts felled in the Thorned Field." % [beasts, STORY_BEASTS_REQUIRED]
		2:
			return "The field is thinner. Return to Elder Rowan in Hearthmere for the first payment."
		3:
			return "The elder's blessing is received. Carry a light to the wayshrine southwest of the field and wake its crystal."
		4:
			return "The shrine burns green. The Briar Warden has woken in the far clearing — end it before it reaches the gate."
		5:
			return "The Briar Warden is fallen. Return to Elder Rowan in Hearthmere and accept the town's thanks."
		_:
			return "The Briar Watch is broken. Hearthmere is quiet, the gate stands open, and the road is yours again."

func _tutorial_text(stage: int, hits: int) -> String:
	match stage:
		0:
			return "Speak with the Wayfarer by the old well."
		1:
			return "Prove your arm: strike the practice dummies.   %d / 3" % mini(hits, 3)
		2:
			return "Return to the Wayfarer and claim your wage."
		_:
			return "The Wayfarer's errand is complete. The old well keeps its quiet."

func _side_text(story: Dictionary) -> String:
	var wolves := mini(int(story.get("wolves", 0)), STORY_SIDE_WOLVES_REQUIRED)
	match int(story.get("side", 0)):
		0:
			return "Tomas holds the south gate. He has work for a hunter, if you ask."
		1:
			return "Kill four briar wolves in the Thorned Field.   %d / %d" % [wolves, STORY_SIDE_WOLVES_REQUIRED]
		2:
			return "The pack is thinned. Return to Tomas at the south gate for the hunter's purse."
		_:
			return "Tomas's Hunt is complete. The traps will hold."
