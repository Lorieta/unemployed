class_name PauseMenu
extends OverlayPanel

## The ESC pause overlay. The scene tree pauses while this panel is visible, so
## it runs with PROCESS_MODE_ALWAYS to keep its fade tween and ESC handling
## alive. The HUD owns this panel: it pauses/unpauses around `closed`.

signal settings_requested
signal quit_to_title_requested
signal quit_game_requested

func _ready() -> void:
	title = "PAUSED"
	subtitle = "THE WAY RESTS A MOMENT"
	panel_size = Vector2(460.0, 400.0)
	process_mode = Node.PROCESS_MODE_ALWAYS
	super._ready()

func _build_content() -> void:
	add_paragraph("The world holds its breath. Resume the journey, adjust your preferences, or leave for the title screen.", MUTED, 12)
	add_rule()
	add_spacer(4.0)
	add_action_button("Resume", close_panel)
	add_action_button("Settings", func() -> void: settings_requested.emit())
	add_rule()
	add_action_button("Quit to Title", func() -> void: quit_to_title_requested.emit())
	add_action_button("Quit Game", func() -> void: quit_game_requested.emit())
