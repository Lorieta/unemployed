extends CharacterBody3D

## One script, four silhouettes. Mosslings, briar wolves and foxfire wisps prowl
## the Thorned Field; the Briar Warden is the named elite that wakes when the
## shrine is lit. Every variant shares the same aggro, strike, health-bar, loot
## and respawn code, so the field behaves consistently even though it looks
## varied.

signal defeated(monster: Node)

@export var variant := "mossling"
@export var display_name := "Mossling"
@export var max_health := 70.0
@export var damage := 9.0
@export var move_speed := 2.4
@export var aggro_range := 13.0
@export var attack_range := 1.9
@export var attack_interval := 1.9
@export var xp_reward := 40.0
@export var gold_reward := 6
@export var boss := false
@export var dormant := false
@export var respawn_delay := 15.0

var health := 70.0

var _dead := false
var _time := 0.0
var _swing := 0.0
var _attack_cooldown := 0.0
var _hit_pending := false
var _spawn_position := Vector3.ZERO
var _spawn_rotation := 0.0
var _player: Node3D
var _visual: Node3D
var _flash := 0.0
var _flash_materials: Array[StandardMaterial3D] = []
var _bar_root: Node3D
var _bar_fill: MeshInstance3D
var _bar_fill_material: StandardMaterial3D
var _name_label: Label3D
var _collision: CollisionShape3D
var _wisp := false
var _height := 1.2
var _radius := 0.42

func _ready() -> void:
	add_to_group("enemy")
	if boss:
		add_to_group("enemy_boss")
	_spawn_position = global_position
	_spawn_rotation = rotation.y
	health = max_health
	_wisp = variant == "wisp"
	_collision = get_node_or_null("CollisionShape3D") as CollisionShape3D
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_build_visual()
	_build_body()
	_build_health_bar()
	_update_health_bar()
	_play_idle_pop()

# ---------------------------------------------------------------------------
# Appearance
# ---------------------------------------------------------------------------

func _build_visual() -> void:
	match variant:
		"briar_wolf":
			_build_wolf()
		"wisp":
			_build_wisp()
		"briar_warden":
			_build_warden()
		_:
			_build_mossling()

func _build_mossling() -> void:
	_height = 1.15
	_radius = 0.45
	var body := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 0.52, 0.0), Color(0.27, 0.38, 0.19), Vector3(0.4, 0.34, 0.4))
	body.scale = Vector3(1.0, 0.82, 0.92)
	var hump := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 0.78, 0.12), Color(0.33, 0.46, 0.23), Vector3(0.28, 0.2, 0.26))
	hump.scale = Vector3(1.0, 0.7, 0.9)
	_add_mesh(_visual, "SphereMesh", Vector3(0.0, 0.9, -0.22), Color(0.5, 0.55, 0.32), Vector3(0.22, 0.19, 0.21))
	_add_glow_eye(Vector3(-0.09, 0.94, -0.4), Color(0.76, 1.0, 0.42))
	_add_glow_eye(Vector3(0.09, 0.94, -0.4), Color(0.76, 1.0, 0.42))
	for side in [-1, 1]:
		var arm := _add_mesh(_visual, "CylinderMesh", Vector3(0.36 * side, 0.48, 0.0), Color(0.24, 0.33, 0.18), Vector3(0.09, 0.09, 0.5))
		arm.rotation.z = 0.5 * side
		var foot := _add_mesh(_visual, "SphereMesh", Vector3(0.18 * side, 0.1, -0.02), Color(0.2, 0.26, 0.15), Vector3(0.17, 0.08, 0.22))
		foot.scale = Vector3(1.0, 0.6, 1.2)
	# A crown of little mossy stones and shelf fungus.
	for i in 4:
		var angle := float(i) * TAU / 4.0 + 0.4
		_add_mesh(_visual, "SphereMesh", Vector3(cos(angle) * 0.22, 0.88 + 0.06 * float(i % 2), sin(angle) * 0.19), Color(0.5, 0.56, 0.26), Vector3(0.09, 0.04, 0.09))
	var light := OmniLight3D.new()
	light.light_color = Color(0.62, 0.92, 0.42)
	light.light_energy = 0.28
	light.omni_range = 2.2
	light.position = Vector3(0.0, 0.85, -0.3)
	_visual.add_child(light)

func _build_wolf() -> void:
	_height = 1.25
	_radius = 0.5
	var body := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 0.76, 0.1), Color(0.22, 0.18, 0.13), Vector3(0.3, 0.2, 0.3))
	body.scale = Vector3(1.0, 0.9, 2.1)
	var chest := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 0.8, -0.45), Color(0.26, 0.21, 0.15), Vector3(0.3, 0.28, 0.3))
	chest.scale = Vector3(1.0, 1.0, 1.15)
	var head := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 0.92, -0.92), Color(0.3, 0.24, 0.17), Vector3(0.24, 0.2, 0.24))
	head.scale = Vector3(0.95, 1.0, 1.15)
	_add_mesh(_visual, "SphereMesh", Vector3(0.0, 0.84, -1.18), Color(0.18, 0.14, 0.1), Vector3(0.12, 0.09, 0.12))
	_add_glow_eye(Vector3(-0.09, 0.98, -1.06), Color(1.0, 0.62, 0.22))
	_add_glow_eye(Vector3(0.09, 0.98, -1.06), Color(1.0, 0.62, 0.22))
	for side in [-1, 1]:
		var ear := _add_mesh(_visual, "PrismMesh", Vector3(0.13 * side, 1.16, -0.88), Color(0.24, 0.19, 0.14), Vector3(0.13, 0.22, 0.09))
		ear.rotation.y = 0.15 * side
		for front in [-1, 1]:
			for s2 in [-1, 1]:
				var leg := _add_mesh(_visual, "CylinderMesh", Vector3(0.22 * s2, 0.38, 0.32 * front), Color(0.2, 0.16, 0.12), Vector3(0.075, 0.09, 0.62))
				leg.rotation.x = 0.08 * float(front)
		# Briar spikes running down the spine.
		for i in 5:
			var spike := _add_mesh(_visual, "PrismMesh", Vector3(0.0, 1.05 - float(i) * 0.04, -0.38 + float(i) * 0.22), Color(0.36, 0.44, 0.22), Vector3(0.1, 0.24 + 0.04 * float(i % 2), 0.08))
			spike.rotation.z = 0.1 * float(side)
	var tail := _add_mesh(_visual, "CylinderMesh", Vector3(0.0, 0.9, 0.78), Color(0.22, 0.18, 0.13), Vector3(0.07, 0.02, 0.72))
	tail.rotation.x = -1.1
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.24)
	light.light_energy = 0.3
	light.omni_range = 2.0
	light.position = Vector3(0.0, 1.0, -1.0)
	_visual.add_child(light)

func _build_wisp() -> void:
	_height = 1.7
	_radius = 0.4
	var orb := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 1.25, 0.0), Color(0.52, 1.0, 0.8), Vector3(0.3, 0.3, 0.3), true)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 1.25, 0.0), Color(0.35, 0.9, 0.7), Vector3(0.52, 0.52, 0.52), true)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:
		var angle := float(i) * TAU / 5.0
		var tendril := _add_mesh(_visual, "CylinderMesh", Vector3(cos(angle) * 0.16, 0.92, sin(angle) * 0.16), Color(0.42, 1.0, 0.78), Vector3(0.035, 0.005, 0.5), true)
		tendril.rotation.z = cos(angle) * 0.5
		tendril.rotation.x = sin(angle) * 0.5
	for i in 3:
		var mote := _add_mesh(_visual, "SphereMesh", Vector3(cos(float(i) * 2.1) * 0.5, 1.3 + sin(float(i) * 1.7) * 0.25, sin(float(i) * 2.1) * 0.5), Color(0.65, 1.0, 0.85), Vector3(0.06, 0.06, 0.06), true)
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 1.0, 0.72)
	light.light_energy = 1.2
	light.omni_range = 3.4
	light.position = Vector3(0.0, 1.25, 0.0)
	_visual.add_child(light)

func _build_warden() -> void:
	_height = 2.55
	_radius = 0.72
	var body := _add_mesh(_visual, "CylinderMesh", Vector3(0.0, 1.35, 0.0), Color(0.19, 0.14, 0.1), Vector3(0.56, 0.38, 1.6))
	body.scale = Vector3(1.0, 1.0, 0.86)
	var chest := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 1.9, -0.04), Color(0.25, 0.2, 0.13), Vector3(0.5, 0.44, 0.42))
	chest.scale = Vector3(1.0, 0.95, 0.8)
	var head := _add_mesh(_visual, "SphereMesh", Vector3(0.0, 2.42, -0.1), Color(0.3, 0.26, 0.16), Vector3(0.3, 0.3, 0.28))
	_add_mesh(_visual, "PrismMesh", Vector3(0.0, 2.28, -0.35), Color(0.34, 0.3, 0.18), Vector3(0.24, 0.3, 0.22))
	_add_glow_eye(Vector3(-0.13, 2.47, -0.36), Color(1.0, 0.42, 0.2))
	_add_glow_eye(Vector3(0.13, 2.47, -0.36), Color(1.0, 0.42, 0.2))
	# Antlers and a crown of briars.
	for side in [-1, 1]:
		var antler := _add_mesh(_visual, "CylinderMesh", Vector3(0.3 * side, 2.72, -0.02), Color(0.3, 0.26, 0.16), Vector3(0.045, 0.02, 0.86))
		antler.rotation.z = 0.55 * side
		var tine := _add_mesh(_visual, "CylinderMesh", Vector3(0.5 * side, 3.0, -0.02), Color(0.3, 0.26, 0.16), Vector3(0.03, 0.015, 0.42))
		tine.rotation.z = 1.05 * side
		var arm := _add_mesh(_visual, "CylinderMesh", Vector3(0.72 * side, 1.55, 0.0), Color(0.22, 0.17, 0.11), Vector3(0.13, 0.1, 1.35))
		arm.rotation.z = 0.16 * side
		var claw := _add_mesh(_visual, "PrismMesh", Vector3(0.78 * side, 0.92, -0.1), Color(0.42, 0.48, 0.24), Vector3(0.16, 0.4, 0.16))
		claw.rotation.z = 3.05 * side
		for i in 4:
			var thorn := _add_mesh(_visual, "PrismMesh", Vector3(0.36 * side, 1.05 + float(i) * 0.4, 0.15 * float(i % 2)), Color(0.4, 0.46, 0.23), Vector3(0.1, 0.34, 0.1))
			thorn.rotation.z = -0.5 * side
		var foot := _add_mesh(_visual, "CylinderMesh", Vector3(0.28 * side, 0.16, -0.06), Color(0.18, 0.14, 0.09), Vector3(0.23, 0.28, 0.4))
		foot.scale = Vector3(1.0, 0.7, 1.1)
	# A ragged cloak of leaves.
	for i in 7:
		var angle := float(i) * TAU / 7.0
		var leaf := _add_mesh(_visual, "PrismMesh", Vector3(cos(angle) * 0.34, 1.5 + sin(float(i) * 1.3) * 0.25, sin(angle) * 0.3), Color(0.28, 0.36, 0.2), Vector3(0.22, 0.5, 0.1))
		leaf.rotation.y = angle
		leaf.rotation.x = 0.2
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.2)
	light.light_energy = 0.7
	light.omni_range = 4.0
	light.position = Vector3(0.0, 2.1, -0.4)
	_visual.add_child(light)

func _add_mesh(parent: Node3D, mesh_type: String, position: Vector3, color: Color, size: Vector3, emissive := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	match mesh_type:
		"CylinderMesh":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x
			cylinder.bottom_radius = size.y
			cylinder.height = size.z
			cylinder.radial_segments = 7
			cylinder.rings = 2
			mesh = cylinder
		"PrismMesh":
			var prism := PrismMesh.new()
			prism.size = size
			mesh = prism
		_:
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.y * 2.0
			sphere.radial_segments = 8
			sphere.rings = 5
			mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_materials.append(material)
	mesh.material = material
	node.mesh = mesh
	node.position = position
	parent.add_child(node)
	return node

func _add_glow_eye(position: Vector3, color: Color) -> void:
	var eye := _add_mesh(_visual, "SphereMesh", position, color, Vector3(0.06, 0.06, 0.055), true)
	eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_body() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = _radius
	shape.height = maxf(_height, _radius * 2.0 + 0.1)
	if _collision != null:
		_collision.shape = shape
		_collision.position = Vector3(0.0, _height * 0.5, 0.0)

func _build_health_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.name = "HealthBar"
	_bar_root.position = Vector3(0.0, _height + 0.42, 0.0)
	add_child(_bar_root)

	var back_material := StandardMaterial3D.new()
	back_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back_material.albedo_color = Color(0.05, 0.04, 0.03, 0.85)
	back_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	back_material.no_depth_test = true
	back_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var back := MeshInstance3D.new()
	var back_mesh := QuadMesh.new()
	back_mesh.size = Vector2(1.32, 0.15)
	back_mesh.material = back_material
	back.mesh = back_mesh
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(back)

	_bar_fill_material = StandardMaterial3D.new()
	_bar_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bar_fill_material.albedo_color = Color(0.66, 0.18, 0.14, 1.0)
	_bar_fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_bar_fill_material.no_depth_test = true
	var fill := MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(1.24, 0.08)
	fill_mesh.material = _bar_fill_material
	fill.mesh = fill_mesh
	fill.position = Vector3(0.0, 0.0, 0.001)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(fill)
	_bar_fill = fill

	_name_label = Label3D.new()
	_name_label.text = display_name.to_upper()
	_name_label.font_size = 44 if not boss else 56
	_name_label.pixel_size = 0.0032
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.outline_size = 16
	_name_label.outline_modulate = Color(0.05, 0.035, 0.02, 1.0)
	_name_label.modulate = Color(0.94, 0.86, 0.68, 1.0) if not boss else Color(1.0, 0.72, 0.52, 1.0)
	_name_label.position = Vector3(0.0, 0.24, 0.0)
	_bar_root.add_child(_name_label)

func _update_health_bar() -> void:
	if _bar_fill == null:
		return
	var ratio := clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
	_bar_fill.scale = Vector3(maxf(ratio, 0.001), 1.0, 1.0)
	_bar_fill.position.x = -0.62 + 0.62 * ratio
	if _bar_fill_material != null:
		if ratio > 0.6:
			_bar_fill_material.albedo_color = Color(0.58, 0.72, 0.32, 1.0)
		elif ratio > 0.3:
			_bar_fill_material.albedo_color = Color(0.82, 0.62, 0.22, 1.0)
		else:
			_bar_fill_material.albedo_color = Color(0.72, 0.2, 0.14, 1.0)

# ---------------------------------------------------------------------------
# Behaviour
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _dead:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_update_bar_visibility()

	if dormant or _player == null:
		_idle(delta)
		return

	var offset := _player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance <= aggro_range and distance > 0.01:
		var to_player := offset / distance
		if distance > attack_range * 0.78:
			var desired := to_player * move_speed
			velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-7.0 * delta))
			velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-7.0 * delta))
		else:
			velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-10.0 * delta))
			velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-10.0 * delta))
		if distance <= attack_range and _attack_cooldown <= 0.0:
			_begin_attack()
		var wanted_yaw := atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, wanted_yaw, 1.0 - exp(-6.0 * delta))
	else:
		var home := _spawn_position - global_position
		home.y = 0.0
		if home.length() > 1.2:
			var desired := home.normalized() * move_speed * 0.45
			velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-3.0 * delta))
			velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-3.0 * delta))
		else:
			velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-4.0 * delta))
			velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-4.0 * delta))
		if home.length() > 2.0:
			rotation.y = lerp_angle(rotation.y, atan2(-home.x, -home.z), 1.0 - exp(-2.0 * delta))

	if not _wisp:
		velocity.y = -20.0
	else:
		velocity.y = 0.0
	move_and_slide()
	if _wisp:
		global_position.y = _spawn_position.y

	_update_swing(delta)
	_animate(delta, distance)

func _idle(delta: float) -> void:
	velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-4.0 * delta))
	velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-4.0 * delta))
	if not _wisp:
		velocity.y = -20.0
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_swing(delta)
	_animate(delta, 999.0)

func _begin_attack() -> void:
	_attack_cooldown = attack_interval
	_swing = 0.44
	_hit_pending = true

func _update_swing(delta: float) -> void:
	if _swing <= 0.0:
		return
	_swing = maxf(0.0, _swing - delta)
	if _hit_pending and _swing <= 0.24:
		_hit_pending = false
		_deliver_attack()

func _deliver_attack() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var offset := _player.global_position - global_position
	offset.y = 0.0
	if _wisp:
		_cast_bolt()
		return
	if offset.length() > attack_range + 0.8:
		return
	_hit_player(damage)

func _hit_player(raw: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("apply_incoming_damage"):
		hud.call("apply_incoming_damage", raw, global_position)

## The wisp's bolt is a travelling mote rather than a hitscan: it can be dodged,
## and it still cracks against the ground if the player slips away.
func _cast_bolt() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var mote := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	mesh.radial_segments = 8
	mesh.rings = 5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.5, 1.0, 0.78, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.4, 1.0, 0.7, 1.0)
	material.emission_energy_multiplier = 2.6
	mesh.material = material
	mote.mesh = mesh
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(0.5, 1.0, 0.8)
	light.light_energy = 1.1
	light.omni_range = 2.6
	mote.add_child(light)
	var parent := get_parent()
	if parent == null:
		return
	parent.add_child(mote)
	var start := global_position + Vector3(0.0, 1.25, 0.0)
	var goal := _player.global_position + Vector3(0.0, 0.95, 0.0)
	mote.global_position = start
	var tween := mote.create_tween()
	tween.tween_property(mote, "global_position", goal, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		if mote == null or not is_instance_valid(mote):
			return
		if _player != null and is_instance_valid(_player):
			var chest := _player.global_position + Vector3(0.0, 0.95, 0.0)
			if chest.distance_to(goal) < 1.25:
				_hit_player(damage)
		mote.queue_free()
	)

func _animate(delta: float, distance: float) -> void:
	if _visual == null:
		return
	var gait := clampf(Vector2(velocity.x, velocity.z).length() / maxf(move_speed, 0.01), 0.0, 1.0)
	var breathe := sin(_time * 2.0) * 0.02
	var lunge := 0.0
	if _swing > 0.0:
		var t := 1.0 - _swing / 0.44
		lunge = sin(t * PI) * 0.28
	_visual.position.y = breathe * (1.0 - gait) + (sin(_time * 8.0) * 0.015 * gait if not _wisp else 0.0)
	if _wisp:
		_visual.position.y = sin(_time * 1.7) * 0.12
		_visual.rotation.y += delta * 0.6
		_visual.rotation.z = sin(_time * 1.1) * 0.08
	else:
		_visual.rotation.z = sin(_time * 7.0) * 0.035 * gait
		_visual.rotation.x = -lunge * 0.35 + breathe * 0.2
		_visual.position.z = -lunge * 0.22
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.5)
		for material in _flash_materials:
			material.emission_enabled = _flash > 0.01
			material.emission = Color(1.0, 0.92, 0.7)
			material.emission_energy_multiplier = _flash * 1.4
	var near := distance < 20.0
	if _name_label != null:
		_name_label.visible = boss or near
	if _bar_root != null and not boss:
		_bar_root.visible = health < max_health or near

func _update_bar_visibility() -> void:
	if _bar_root == null:
		return
	if boss:
		_bar_root.visible = not _dead and not dormant
	elif _player != null and is_instance_valid(_player):
		var distance := global_position.distance_to(_player.global_position)
		_bar_root.visible = not _dead and (distance < 20.0 or health < max_health)
	if _name_label != null and boss:
		_name_label.visible = not dormant

func _play_idle_pop() -> void:
	_visual.scale = Vector3(0.85, 1.15, 0.85)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK)

# ---------------------------------------------------------------------------
# Damage, death and loot
# ---------------------------------------------------------------------------

func take_damage(amount: float, hit_position := Vector3.ZERO) -> void:
	if _dead:
		return
	if dormant:
		awaken()
	health = maxf(0.0, health - amount)
	_flash = 1.0
	_spawn_number(amount, hit_position)
	_update_health_bar()
	if health <= 0.0:
		_die()

func awaken() -> void:
	if not dormant:
		return
	dormant = false
	_play_idle_pop()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "%s stirs. The briars pull taut." % display_name)

func is_defeated() -> bool:
	return _dead

func _die() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	if _collision != null:
		_collision.set_deferred("disabled", true)
	_bar_root.visible = false
	defeated.emit(self)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("on_monster_killed"):
		hud.call("on_monster_killed", self, variant, boss, xp_reward, gold_reward)
	_spawn_burst()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", Vector3(0.2, 0.05, 0.2), 0.7).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_visual, "rotation:x", 1.2, 0.7)
	tween.tween_property(_visual, "position:y", -0.4, 0.7)
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	visible = false
	if boss:
		return
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	_respawn()

func _respawn() -> void:
	global_position = _spawn_position
	rotation.y = _spawn_rotation
	health = max_health
	_dead = false
	visible = true
	_visual.scale = Vector3.ONE
	_visual.rotation = Vector3.ZERO
	_visual.position = Vector3.ZERO
	if _collision != null:
		_collision.set_deferred("disabled", false)
	_bar_root.visible = true
	_update_health_bar()
	set_physics_process(true)
	_play_idle_pop()

func _spawn_number(amount: float, hit_position: Vector3) -> void:
	var label := Label3D.new()
	label.text = "%d" % roundi(amount)
	label.font_size = 64
	label.pixel_size = 0.0045
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 22
	label.outline_modulate = Color(0.05, 0.035, 0.02, 1.0)
	label.modulate = Color(1.0, 0.82, 0.42, 1.0)
	label.render_priority = 2
	get_tree().current_scene.add_child(label)
	if hit_position.length_squared() < 0.001:
		hit_position = global_position + Vector3(0.0, _height * 0.8, 0.0)
	label.global_position = hit_position + Vector3(randf_range(-0.18, 0.18), 0.4, randf_range(-0.18, 0.18))
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 0.8, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.chain().tween_callback(label.queue_free)

func _spawn_burst() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var color := Color(0.72, 0.9, 0.46, 1.0) if variant == "mossling" else Color(0.94, 0.72, 0.32, 1.0)
	if variant == "wisp":
		color = Color(0.5, 1.0, 0.78, 1.0)
	elif variant == "briar_warden":
		color = Color(1.0, 0.5, 0.24, 1.0)
	for i in 9:
		var mote := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.055
		mesh.height = 0.11
		mesh.radial_segments = 5
		mesh.rings = 3
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.6
		mesh.material = material
		mote.mesh = mesh
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mote)
		mote.global_position = global_position + Vector3(0.0, _height * 0.55, 0.0)
		var angle := randf() * TAU
		var spread := Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.5, 1.5)
		var tween := mote.create_tween()
		tween.set_parallel(true)
		tween.tween_property(mote, "global_position", mote.global_position + spread + Vector3(0.0, randf_range(0.6, 1.4), 0.0), 0.55)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.55)
		tween.chain().tween_callback(mote.queue_free)
