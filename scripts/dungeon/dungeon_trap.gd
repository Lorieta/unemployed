extends Node3D

## Dungeon traps: hazards that telegraph, then punish. Three types share one
## script — spike plates that erupt underfoot, flame vents that jet on a clock,
## and dart holes that fire across a corridor. Every trap damages the hero
## through the HUD's incoming-damage funnel and can be triggered repeatedly,
## but never faster than its cooldown. Spawned by the dungeon manager in
## corridors and combat rooms.

const SPIKE_DAMAGE := 14.0
const FLAME_DAMAGE := 11.0
const DART_DAMAGE := 9.0
const CRUSHER_DAMAGE := 22.0
const BEAM_DAMAGE := 16.0
const SWEEPER_DAMAGE := 13.0

@export var trap_type := "spike"
## Deeper floors hit harder without needing a whole new trap table.
@export var damage_scale := 1.0

var _armed := true
var _timer := 0.0
var _period := 0.0
var _telegraph := false
var _triggered := false
var _parts := {}
var _glow_materials: Array[StandardMaterial3D] = []
var _moving: Array[Node3D] = []
var _player_in_zone := false
var _sweep_angle := 0.0
var _sweep_cooldown := 0.0
var _beam_active := false
var _beam_cooldown := 0.0

func _ready() -> void:
	_timer = randf_range(0.4, 1.6)
	match trap_type:
		"spike":
			_build_spike()
			_period = 2.4
		"flame":
			_build_flame()
			_period = 3.2
		"darts":
			_build_darts()
			_period = 2.8
		"crusher":
			_build_crusher()
			_period = 3.0
		"beam":
			_build_beam()
			_period = 2.6
		"sweeper":
			_build_sweeper()
			_period = 3.0
		_:
			trap_type = "spike"
			_build_spike()
			_period = 2.4

func _build_spike() -> void:
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color(0.2, 0.19, 0.18)
	plate_material.roughness = 0.85
	var plate := _box(Vector3(0.0, 0.03, 0.0), Vector3(2.2, 0.07, 2.2), plate_material)
	plate.name = "Plate"
	# Tell-tale rivets ring the plate so sharp eyes can spot it.
	for i in 8:
		var angle := float(i) * TAU / 8.0
		_box(Vector3(cos(angle) * 0.95, 0.08, sin(angle) * 0.95), Vector3(0.1, 0.06, 0.1), _metal())
	var grate_material := StandardMaterial3D.new()
	grate_material.albedo_color = Color(0.1, 0.09, 0.09)
	grate_material.roughness = 0.7
	for i in 4:
		_box(Vector3(-0.6 + 0.4 * float(i), 0.075, 0.0), Vector3(0.08, 0.02, 2.0), grate_material)
	# The spike cluster stays hidden inside the plate until it fires.
	var spikes := Node3D.new()
	spikes.name = "Spikes"
	spikes.position = Vector3(0.0, -0.4, 0.0)
	add_child(spikes)
	_parts["spikes"] = spikes
	for i in 9:
		var angle := float(i) * TAU / 9.0
		var ring := 0.7 if i % 2 == 0 else 0.35
		var spike_material := _glow(Color(0.75, 0.78, 0.82), 0.0)
		var spike := _prism(Vector3(cos(angle) * ring, 0.0, sin(angle) * ring), Vector3(0.16, 0.9, 0.16), spike_material, spikes)
		_moving.append(spike)
	var zone := _zone(Vector3(2.3, 1.4, 2.3))
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _build_flame() -> void:
	# A scorched floor grate with a stone collar that reads as a vent.
	var collar_material := StandardMaterial3D.new()
	collar_material.albedo_color = Color(0.24, 0.22, 0.2)
	collar_material.roughness = 0.9
	_cylinder(Vector3(0.0, 0.06, 0.0), 1.05, 0.12, collar_material)
	var grate_material := StandardMaterial3D.new()
	grate_material.albedo_color = Color(0.09, 0.08, 0.08)
	_cylinder(Vector3(0.0, 0.13, 0.0), 0.75, 0.04, grate_material)
	# Scorch marks around the vent.
	for i in 5:
		var angle := randf() * TAU
		var mark_material := StandardMaterial3D.new()
		mark_material.albedo_color = Color(0.12, 0.1, 0.09)
		mark_material.roughness = 1.0
		var mark := _prism(Vector3(cos(angle) * randf_range(1.2, 1.9), 0.02, sin(angle) * randf_range(1.2, 1.9)), Vector3(0.4, 0.02, 0.9), mark_material)
		mark.rotation.y = angle
	# The jet: an emissive column that scales from nothing.
	var jet := _cylinder(Vector3(0.0, 0.9, 0.0), 0.5, 2.0, _glow(Color(1.0, 0.45, 0.12), 2.2))
	jet.name = "Jet"
	jet.scale = Vector3(0.01, 0.01, 0.01)
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parts["jet"] = jet
	var ember_material := _glow(Color(1.0, 0.6, 0.2), 1.6)
	for i in 4:
		var angle := float(i) * TAU / 4.0
		_box(Vector3(cos(angle) * 0.55, 0.16, sin(angle) * 0.55), Vector3(0.14, 0.06, 0.14), ember_material)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.18)
	light.light_energy = 0.0
	light.omni_range = 5.0
	light.position = Vector3(0.0, 1.2, 0.0)
	add_child(light)
	_parts["light"] = light
	var zone := _zone(Vector3(1.6, 2.6, 1.6))
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _build_darts() -> void:
	# A wall-mounted pair of dart holes with an iron frame, firing along -Z of
	# this node, so the manager yaw-rotates the trap to aim down its corridor.
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.22, 0.2, 0.18)
	frame_material.roughness = 0.9
	_box(Vector3(0.0, 0.9, 0.0), Vector3(1.6, 1.8, 0.5), frame_material)
	var hole_material := StandardMaterial3D.new()
	hole_material.albedo_color = Color(0.05, 0.05, 0.05)
	for side in [-1, 1]:
		_box(Vector3(0.45 * float(side), 1.1, 0.2), Vector3(0.34, 0.34, 0.3), hole_material)
	_box(Vector3(0.0, 1.85, 0.0), Vector3(1.7, 0.14, 0.55), _metal())
	# Cracked floor scarring down the firing lane.
	for i in 5:
		var lane_material := StandardMaterial3D.new()
		lane_material.albedo_color = Color(0.15, 0.14, 0.13)
		lane_material.roughness = 1.0
		_box(Vector3(randf_range(-0.3, 0.3), 0.02, -1.4 - 1.1 * float(i)), Vector3(0.3, 0.02, randf_range(0.4, 0.8)), lane_material)
	# The travelling dart is spawned on fire; the template is hidden here.
	var dart := _box(Vector3(0.0, 1.1, 0.0), Vector3(0.09, 0.09, 0.7), _glow(Color(0.9, 0.85, 0.7), 0.9))
	dart.name = "Dart"
	dart.visible = false
	_parts["dart"] = dart
	var zone := Area3D.new()
	zone.position = Vector3(0.0, 1.1, -3.6)
	var zone_shape := BoxShape3D.new()
	zone_shape.size = Vector3(2.6, 1.8, 6.4)
	var zone_collision := CollisionShape3D.new()
	zone_collision.shape = zone_shape
	zone.add_child(zone_collision)
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)

func _zone(size: Vector3) -> Area3D:
	var zone := Area3D.new()
	var zone_shape := BoxShape3D.new()
	zone_shape.size = size
	var zone_collision := CollisionShape3D.new()
	zone_collision.shape = zone_shape
	zone.add_child(zone_collision)
	add_child(zone)
	return zone

func _on_body_entered(body: Node3D) -> void:
	if body != null and body.is_in_group("player"):
		_player_in_zone = true

func _on_body_exited(body: Node3D) -> void:
	if body != null and body.is_in_group("player"):
		_player_in_zone = false
		_telegraph = false

func _process(delta: float) -> void:
	_timer -= delta
	_sweep_cooldown = maxf(0.0, _sweep_cooldown - delta)
	_beam_cooldown = maxf(0.0, _beam_cooldown - delta)
	match trap_type:
		"spike":
			_update_spike(delta)
		"flame":
			_update_flame(delta)
		"darts":
			_update_darts(delta)
		"crusher":
			_update_crusher(delta)
		"beam":
			_update_beam(delta)
		"sweeper":
			_update_sweeper(delta)

## Spike plates trigger the moment the hero steps on them: a warning shudder,
## then the spikes erupt. They snap back after a beat and rearm.
func _update_spike(_delta: float) -> void:
	var spikes: Node3D = _parts.get("spikes")
	if _triggered:
		return
	if _player_in_zone and _timer <= 0.0:
		_triggered = true
		_shake_plate()
		var target_y := 0.85
		for spike in _moving:
			spike.position.y = target_y
			_flash_glow(1.4)
		_strike(SPIKE_DAMAGE)
		get_tree().create_timer(0.55).timeout.connect(func () -> void:
			if is_instance_valid(spikes):
				for spike in _moving:
					if is_instance_valid(spike):
						spike.position.y = 0.0
				_flash_glow(0.0)
			_triggered = false
			_timer = _period
		)
	elif _player_in_zone and not _telegraph:
		_telegraph = true
		_flash_glow(0.5)

func _update_flame(delta: float) -> void:
	if _timer <= 0.0:
		_timer = _period
		_fire_flame()
	elif not _telegraph and _timer < 0.8:
		_telegraph = true
		# Warning glow: the vent vents heat before it erupts.
		_flash_glow(0.6)
		var light: OmniLight3D = _parts.get("light")
		if light != null:
			light.light_energy = 0.4

func _fire_flame() -> void:
	_telegraph = false
	_flash_glow(2.2)
	var jet: MeshInstance3D = _parts.get("jet")
	if jet != null:
		var tween := jet.create_tween()
		tween.tween_property(jet, "scale", Vector3(1.0, 1.0, 1.0), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(jet, "scale", Vector3(0.01, 0.01, 0.01), 0.5).set_delay(0.35)
	var light: OmniLight3D = _parts.get("light")
	if light != null:
		var light_tween := light.create_tween()
		light_tween.tween_property(light, "light_energy", 2.2, 0.12)
		light_tween.tween_property(light, "light_energy", 0.0, 0.6)
	if _player_in_zone:
		_strike(FLAME_DAMAGE)

## Dart holes fire on a clock whether or not anyone stands in the lane; the
## hero is only hurt if the dart actually reaches them mid-flight.
func _update_darts(delta: float) -> void:
	if _timer > 0.0:
		return
	_timer = _period
	var dart: MeshInstance3D = _parts.get("dart")
	if dart == null:
		return
	dart.visible = true
	dart.position = Vector3(0.0, 1.1, -0.4)
	_flash_glow(1.2)
	var tween := dart.create_tween()
	tween.tween_property(dart, "position:z", -7.4, 0.38)
	tween.tween_callback(func () -> void:
		dart.visible = false
		_flash_glow(0.0)
	)
	# The dart's flight is checked once it would pass the hero.
	var flight_timer := get_tree().create_timer(0.22)
	flight_timer.timeout.connect(func () -> void:
		if _player_in_zone:
			_strike(DART_DAMAGE)
	)

## A ceiling block the size of a doorway: a lit rune plate shudders, then a
## slab of stone drops like a hammer and retracts. The heaviest corridor snare.
func _build_crusher() -> void:
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color(0.24, 0.22, 0.2)
	plate_material.roughness = 0.9
	var plate := _box(Vector3(0.0, 0.04, 0.0), Vector3(2.6, 0.08, 2.6), plate_material)
	plate.name = "Plate"
	var rune_material := _glow(Color(1.0, 0.35, 0.18), 0.35)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var rune := _box(Vector3(sx * 0.95, 0.1, sz * 0.95), Vector3(0.35, 0.04, 0.08), rune_material)
			rune.rotation.y = 0.785
	var guide_material := _metal()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cylinder(Vector3(sx * 1.3, 1.55, sz * 1.3), 0.09, 3.0, guide_material)
	var block_material := StandardMaterial3D.new()
	block_material.albedo_color = Color(0.28, 0.27, 0.26)
	block_material.roughness = 0.82
	var block := _box(Vector3(0.0, 3.0, 0.0), Vector3(2.2, 0.7, 2.2), block_material)
	block.name = "Block"
	_parts["block"] = block
	for dz in [-1, 1]:
		_box(Vector3(0.0, 3.0, 1.12 * float(dz)), Vector3(2.3, 0.1, 0.05), rune_material)
	var zone := _zone(Vector3(2.7, 3.3, 2.7))
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _update_crusher(_delta: float) -> void:
	var block: MeshInstance3D = _parts.get("block")
	if block == null:
		return
	if _timer <= 0.0:
		_timer = _period
		_telegraph = false
		_flash_glow(2.0)
		var tween := block.create_tween()
		tween.tween_property(block, "position:y", 0.55, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(block, "position:y", 3.0, 0.5).set_delay(0.32)
		if _player_in_zone:
			_strike(CRUSHER_DAMAGE)
	elif not _telegraph and _timer < 0.75:
		_telegraph = true
		_flash_glow(0.7)

## Twin emitter pylons throw a hot beam across the lane on a clock. A low hum
## of light telegraphs the shot; standing in the lane when it fires hurts.
func _build_beam() -> void:
	var emitter_material := _metal()
	var lens_material := _glow(Color(0.3, 0.9, 1.0), 0.4)
	for side in [-1, 1]:
		var x := 1.9 * float(side)
		_box(Vector3(x, 1.1, 0.0), Vector3(0.5, 2.2, 0.5), emitter_material)
		_box(Vector3(x, 0.06, 0.0), Vector3(0.8, 0.08, 0.8), emitter_material)
		var lens := _cylinder(Vector3(x, 1.25, -0.28 * float(side)), 0.16, 0.12, lens_material)
		lens.rotation.x = PI * 0.5
	var beam := _box(Vector3(0.0, 1.1, 0.0), Vector3(3.8, 0.12, 0.12), _glow(Color(0.4, 0.95, 1.0), 2.4))
	beam.name = "Beam"
	beam.scale = Vector3(1.0, 0.08, 0.08)
	beam.visible = false
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_parts["beam"] = beam
	var zone := _zone(Vector3(4.0, 2.4, 1.4))
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _update_beam(_delta: float) -> void:
	var beam: MeshInstance3D = _parts.get("beam")
	if beam == null:
		return
	if _timer <= 0.0:
		_timer = _period
		_telegraph = false
		beam.visible = true
		beam.scale = Vector3(1.0, 0.08, 0.08)
		_flash_glow(2.4)
		_beam_active = true
		var tween := beam.create_tween()
		tween.tween_property(beam, "scale:y", 1.0, 0.08)
		get_tree().create_timer(0.42).timeout.connect(func () -> void:
			if not is_instance_valid(beam):
				return
			beam.visible = false
			beam.scale = Vector3(1.0, 0.08, 0.08)
			_beam_active = false
			_flash_glow(0.2)
		)
	elif not _telegraph and _timer < 0.7:
		_telegraph = true
		_flash_glow(0.6)
	if _beam_active and _player_in_zone and _beam_cooldown <= 0.0:
		_beam_cooldown = 0.85
		_strike(BEAM_DAMAGE)

## A rotating blade on a central post, sweeping the whole chamber. It never
## stops, so the only answer is to time the crossing or keep moving.
func _build_sweeper() -> void:
	var metal := _metal()
	var glow := _glow(Color(1.0, 0.3, 0.2), 0.8)
	_cylinder(Vector3(0.0, 0.05, 0.0), 2.5, 0.05, _glow(Color(0.9, 0.25, 0.18), 0.35))
	_cylinder(Vector3(0.0, 0.95, 0.0), 0.22, 1.9, metal)
	var arm := Node3D.new()
	arm.name = "SweepArm"
	arm.position = Vector3(0.0, 1.05, 0.0)
	add_child(arm)
	_parts["arm"] = arm
	_prism(Vector3(1.5, 0.0, 0.0), Vector3(2.9, 0.14, 0.3), glow, arm)
	for i in 4:
		var z := -0.72 + 0.48 * float(i)
		var tooth := _prism(Vector3(2.85, 0.0, z), Vector3(0.18, 0.42, 0.18), glow, arm)
		tooth.rotation.x = PI
	var zone := _zone(Vector3(5.2, 2.2, 5.2))
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)

func _update_sweeper(delta: float) -> void:
	var arm: Node3D = _parts.get("arm")
	if arm == null:
		return
	_sweep_angle += delta * 2.3
	arm.rotation.y = _sweep_angle
	if _player_in_zone and _sweep_cooldown <= 0.0:
		_sweep_cooldown = 0.9
		_flash_glow(1.6)
		get_tree().create_timer(0.2).timeout.connect(func () -> void: _flash_glow(0.8))
		_strike(SWEEPER_DAMAGE)

func _shake_plate() -> void:
	var plate := get_node_or_null("Plate") as MeshInstance3D
	if plate == null:
		return
	var tween := plate.create_tween()
	tween.tween_property(plate, "position:y", 0.06, 0.07)
	tween.tween_property(plate, "position:y", 0.03, 0.07)
	tween.tween_property(plate, "position:y", 0.05, 0.07)

func _flash_glow(energy: float) -> void:
	for material in _glow_materials:
		material.emission_energy_multiplier = energy

## All trap damage funnels through the HUD so armor and guards still count.
func _strike(raw: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("apply_incoming_damage"):
		hud.call("apply_incoming_damage", raw * damage_scale)

func _box(position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	node.position = position
	add_child(node)
	return node

func _prism(position: Vector3, size: Vector3, material: StandardMaterial3D, parent: Node = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = size
	mesh.material = material
	node.mesh = mesh
	node.position = position
	if parent != null:
		parent.add_child(node)
	else:
		add_child(node)
	return node

func _cylinder(position: Vector3, radius: float, height: float, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 2
	mesh.material = material
	node.mesh = mesh
	node.position = position
	add_child(node)
	return node

func _metal() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.28, 0.26)
	material.roughness = 0.45
	material.metallic = 0.7
	return material

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
	_glow_materials.append(material)
	return material
