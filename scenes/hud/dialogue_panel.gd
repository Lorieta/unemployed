class_name DialoguePanel
extends OverlayPanel

## Conversation window. The HUD fills in the speaker, body and choices; the
## panel simply presents them in the same gilded frame as the other pages.

signal choice_selected(choice_id: String)

func _ready() -> void:
	title = "CONVERSATION"
	subtitle = ""
	panel_size = Vector2(720.0, 460.0)
	super._ready()

func present(speaker: String, body: String, choices: Array) -> void:
	clear_content()
	set_header("CONVERSATION", speaker.to_upper())
	add_heading(speaker)
	add_paragraph(body, PARCHMENT, 14)
	add_spacer(6.0)
	add_rule()
	for choice in choices:
		var data: Dictionary = choice
		add_action_button(str(data["label"]), _on_choice.bind(str(data["id"])))
	open()

func _on_choice(choice_id: String) -> void:
	choice_selected.emit(choice_id)
