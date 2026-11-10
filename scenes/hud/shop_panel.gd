extends OverlayPanel

## The counter at Mira's stall or Bran's forge. Stock, prices and limits are
## supplied by the HUD, which also owns the purse and the satchel, so a purchase
## updates the inventory, the quickbar and the gold display in one place.

signal purchase_requested(shop_id: String, item_id: String)

var _shop_id := ""
var _shop_title := ""
var _shop_subtitle := ""
var _shop_description := ""
var _stock: Array = []
var _gold := 0
var _purchases := {}
var _note := ""

func _ready() -> void:
	title = "MARKET"
	subtitle = "HEARTHMERE"
	panel_size = Vector2(820.0, 660.0)
	super._ready()

func _build_content() -> void:
	add_paragraph("The market smells of woodsmoke, wet wool and new bread. A bell above the door knocks softly in the wind.", MUTED, 12)

func present(shop_id: String, shop_title: String, shop_subtitle: String, description: String, stock: Array, gold: int, purchases: Dictionary, note := "") -> void:
	_shop_id = shop_id
	_shop_title = shop_title
	_shop_subtitle = shop_subtitle
	_shop_description = description
	_stock = stock
	_gold = gold
	_purchases = purchases.duplicate()
	_note = note
	_rebuild()
	open()

func _rebuild() -> void:
	if content_box == null:
		return
	clear_content()
	set_header(_shop_title, _shop_subtitle)
	add_paragraph(_shop_description, MUTED, 12)
	add_spacer(2.0)
	add_row("YOUR PURSE", "%s GOLD" % _format_number(_gold), GOLD_BRIGHT)
	add_rule()
	add_heading("WARES")

	for entry in _stock:
		var item_id := str(entry.get("id", ""))
		var price := int(entry.get("price", 0))
		var limit := int(entry.get("max", 0))
		var bought := int(_purchases.get(item_id, 0))
		var exhausted := limit > 0 and bought >= limit
		var right := "%s GOLD" % _format_number(price)
		if limit > 0:
			right += "   ·   %d / %d" % [bought, limit]
		add_row(str(entry.get("name", item_id)), right, MUTED if exhausted else GOLD_BRIGHT)
		add_paragraph(str(entry.get("description", "")), MUTED, 11)
		var label := "Sold out"
		if not exhausted:
			if price > _gold:
				label = "Not enough gold  ·  %d" % price
			else:
				label = "Buy for %d gold" % price
		var button := add_action_button(label, _on_buy.bind(item_id))
		button.disabled = exhausted or price > _gold
		add_spacer(2.0)

	if not _note.is_empty():
		add_rule()
		add_paragraph(_note, GOLD, 11)
	add_spacer(4.0)
	add_action_button("Leave the counter", close_panel)

func _on_buy(item_id: String) -> void:
	if _shop_id.is_empty() or item_id.is_empty():
		return
	purchase_requested.emit(_shop_id, item_id)

func _format_number(number: int) -> String:
	var digits := str(number)
	var result := ""
	while digits.length() > 3:
		result = "," + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result
