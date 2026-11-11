extends Node

## SaveManager (autoload). Owns the single JSON save file at
## `user://savegame.json` and the state of the run that is currently being
## played. The main menu calls `start_new_game` / `continue_game` before
## switching to the world scene; the HUD pushes progress into `save_progress`
## at meaningful moments (quests, level-ups, purchases, death, quitting) and
## re-applies `active_data` when the scene starts.
##
## The file is deliberately plain data — every value is a String, Number, bool
## or Dictionary — so it survives a JSON round trip untouched.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

## State for the run currently loaded in memory. Empty until the player starts
## or continues a journey; a debug run straight from the editor leaves it empty
## and the HUD falls back to its defaults.
var active_data: Dictionary = {}


func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Returns a summary for the main menu's Continue button, or an empty
## Dictionary when no readable save exists.
func read_save_summary() -> Dictionary:
	var data := read_save_file()
	if data.is_empty():
		return {}
	var char_info: Dictionary = CharacterLibrary.get_character(str(data.get("character_id", "knight")))
	return {
		"character_id": str(data.get("character_id", "knight")),
		"character_name": str(data.get("character_name", char_info.get("name", "Aldric"))),
		"title": str(char_info.get("title", "THE KNIGHT")),
		"level": int(data.get("level", 1)),
		"gold": int(data.get("gold", 0)),
	}


func read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func write_save_file() -> bool:
	if active_data.is_empty():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open %s for writing." % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(active_data, "\t"))
	file.close()
	return true


func clear_save() -> void:
	active_data = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Builds a fresh run for the chosen character and stores it as the active run.
## Called by the main menu before switching to the world scene.
func start_new_game(character_id: String, character_name: String) -> Dictionary:
	active_data = _default_run(character_id, character_name)
	write_save_file()
	return active_data


## Loads the save file into `active_data` and returns it. Empty when the file
## is missing or corrupt, so callers can fall back to a fresh run.
func continue_game() -> Dictionary:
	var data := read_save_file()
	if data.is_empty():
		return {}
	active_data = data
	return active_data


## Merges a patch of progress into the active run and writes the file. Called
## by the HUD; unknown keys are simply added so the save format can grow.
func save_progress(patch: Dictionary) -> bool:
	if active_data.is_empty():
		active_data = _default_run("knight", "Aldric")
	_merge_into(active_data, patch)
	return write_save_file()


func active_exists() -> bool:
	return not active_data.is_empty()


func _default_run(character_id: String, character_name: String) -> Dictionary:
	var char_info: Dictionary = CharacterLibrary.get_character(character_id)
	var clean_name := character_name.strip_edges()
	if clean_name.is_empty():
		clean_name = str(char_info.get("name", "Aldric"))
	return {
		"version": SAVE_VERSION,
		"character_id": character_id,
		"character_name": clean_name,
		"weapon": str(char_info.get("weapon", "sword")),
		"offhand": "",
		"level": 1,
		"xp": 0.0,
		"health": -1.0,
		"mana": -1.0,
		"gold": 60,
		"skills": {"1": "", "2": "", "3": "", "4": "", "5": ""},
		"items": {},
		"quest_stage": 0,
		"dummies_hit": 0,
		"story_stage": 0,
		"beasts_culled": 0,
		"side_stage": 0,
		"wolves_culled": 0,
		"shrine_lit": false,
		"boss_defeated": false,
		"purchases": {"mira": {}, "bran": {}},
	}


## Recursive dictionary merge: nested dictionaries combine key-by-key so a
## patch can update a single skill slot without erasing the rest.
func _merge_into(target: Dictionary, patch: Dictionary) -> void:
	for key in patch.keys():
		var value: Variant = patch[key]
		if typeof(value) == TYPE_DICTIONARY and typeof(target.get(key)) == TYPE_DICTIONARY:
			_merge_into(target[key], value)
		else:
			target[key] = value
