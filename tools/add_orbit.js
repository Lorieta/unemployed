const fs = require('fs');
let c = fs.readFileSync('scenes/hud/hud.gd', 'utf8');

// Find the _process function and add orbit camera logic after _update_boss_bar()
const target = `_update_boss_bar()\n\n	var vitals_changed := false`;
const replacement = `_update_boss_bar()\n\n	if _orbit_camera:\n\tvar viewport := get_viewport()\n\tvar mouse := viewport.get_mouse_position()\n\tvar center := viewport.get_visible_rect().size * 0.5\n\toffset := mouse - center\n\tviewport.set_mouse_position(center)\n\tget_viewport().set_input_as_handled()\n\tvar camera := viewport.get_camera_3d()\n\tif camera:\n\t\tvar player_pos := _player.global_position\n\t\tvar to_center := player_pos - camera.global_position\n\t\tvar yaw := offset.x * 0.01\n\t\tcamera.global_transform.basis = camera.global_transform.basis.rotated(Vector3.UP, yaw)\n\n	var vitals_changed := false`;

if (c.includes(target)) {
  c = c.replace(target, replacement);
  fs.writeFileSync('scenes/hud/hud.gd', c);
  console.log('Orbit logic added successfully');
} else {
  console.log('Target not found, trying alternative...');
  // Try to find _process and add after _update_boss_bar
  let idx = c.indexOf('func _process');
  if (idx >= 0) {
    console.log('_process found at index', idx);
    // Show context
    console.log(c.substring(idx, idx + 200).includes('_update_boss_bar') ? 'Contains _update_boss_bar' : 'Does not contain _update_boss_bar');
  }
}