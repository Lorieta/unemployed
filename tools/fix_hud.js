const fs = require('fs');
let c = fs.readFileSync('scenes/hud/hud.gd', 'utf8');
let old = `func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if not _input_blocked():
				_attack_with_equipped()
				get_viewport().set_input_as_handled()
			return

	if not (event is InputEventKey):
		return`;

let new = `func _unhandled_input(event: InputEvent) -> void:
	 if event is InputEventMouseButton:
	  var mouse_event := event as InputEventMouseButton
	  if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
	   if not _input_blocked():
		_attack_with_equipped()
		get_viewport().set_input_as_handled()
	  return
   if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
    if mouse_event.pressed and not _input_blocked():
     _orbit_camera = true
     get_viewport().set_input_as_handled()
     return
    if not mouse_event.pressed:
     _orbit_camera = false
     get_viewport().set_input_as_handled()
     return
  return

	 if not (event is InputEventKey):
	  return`;

if (c.includes(old)) {
  c = c.replace(old, new);
  fs.writeFileSync('scenes/hud/hud.gd', c);
  console.log('Replacement succeeded');
} else {
  console.log('Old string not found');
  let idx = c.indexOf('func _unhandled_input');
  console.log('Found at index:', idx);
  console.log('Context:', c.substring(idx, idx+250));
}