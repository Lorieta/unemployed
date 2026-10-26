class_name MapPanel
extends OverlayPanel

## A large, live chart of the Verdant Reach. It shares the main world with the
## minimap, so it shows the actual town, gate road, Thorned Field, wayshrine and
## the Warden's far clearing rather than a painted approximation.

const MINIMAP_OVERLAY := preload("res://scenes/hud/minimap_overlay.gd")

var _camera: Camera3D
var _player: Node3D
var _coord_label: Label
var _zone_label: Label
var _viewport: SubViewport

func _ready() -> void:
	title = "HEARTHMERE & THE THORNED FIELD"
	subtitle = "CHARTED LANDS  ·  DAY 3, DUSK"
	panel_size = Vector2(900.0, 650.0)
	super._ready()

func _build_content() -> void:
	add_paragraph("The town of Hearthmere and the road south through the Thorned Field, charted by lamplight. The gate road runs from the plaza past the last lamp and under the ruined arch.", MUTED, 12)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0.0, 360.0)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_child(holder)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(container)

	_viewport = SubViewport.new()
	_viewport.handle_input_locally = false
	_viewport.size = Vector2i(820, 360)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	container.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 56.0
	_camera.near = 0.1
	_camera.far = 160.0
	_camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_camera.current = true
	_viewport.add_child(_camera)

	var overlay := Control.new()
	overlay.set_script(MINIMAP_OVERLAY)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(overlay)

	add_rule()
	add_heading("FIELD NOTES")
	add_paragraph("Hearthmere's plaza holds the fountain, Mira's market stall and Bran's forge; Elder Rowan keeps the hall at its head. South of the gate, briar wolves and mosslings work the field, and the wayshrine stands among leaning stones southwest of the road. The Briar Warden sleeps in the far clearing until the shrine is lit.", PARCHMENT, 12)
	var row := add_row("POSITION", "", GOLD)
	_coord_label = row.get_child(1) as Label
	var zone_row := add_row("ZONE", "HEARTHMERE", GOLD)
	_zone_label = zone_row.get_child(1) as Label
	add_row("HEARTHMERE", "PLAZA  ·  MARKET  ·  FORGE  ·  HALL", GOLD_BRIGHT)
	add_row("THE SOUTH GATE", "TOMAS KEEPS THE WATCH", GOLD_BRIGHT)
	add_row("THE THORNED FIELD", "MOSSLINGS  ·  BRIAR WOLVES  ·  WISPS", GOLD_BRIGHT)
	add_row("THE WAYSHRINE", "SOUTHWEST OF THE ROAD", GOLD_BRIGHT)
	add_row("THE WARDEN'S CLEARING", "FAR SOUTH  ·  SEALED UNTIL THE SHRINE WAKES", GOLD_BRIGHT)

	_player = get_tree().get_first_node_in_group("player") as Node3D
	if _viewport != null and get_viewport() != null:
		_viewport.world_3d = get_viewport().world_3d
	_update_camera()

func _process(_delta: float) -> void:
	if _camera == null:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_update_camera()

func _update_camera() -> void:
	if _camera == null:
		return
	if _player != null:
		_camera.global_position = Vector3(_player.global_position.x, 40.0, _player.global_position.z)
		if _coord_label != null:
			_coord_label.text = "%d, %d" % [roundi(_player.global_position.x), roundi(_player.global_position.z)]
		if _zone_label != null:
			_zone_label.text = _zone_name(_player.global_position)
	else:
		_camera.global_position = Vector3(0.0, 40.0, 0.0)

func _zone_name(position: Vector3) -> String:
	if position.z < -86.0:
		return "THE WARDEN'S CLEARING"
	if position.distance_to(Vector3(-6.0, 0.0, -74.0)) < 14.0:
		return "THE WAYSHRINE"
	if position.z < -31.0:
		return "THE THORNED FIELD"
	return "HEARTHMERE"

func open() -> void:
	super.open()
	_update_camera()
