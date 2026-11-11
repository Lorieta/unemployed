extends CharacterBody3D

## One script, four silhouettes. Mosslings, briar wolves and foxfire wisps prowl
## the Thorned Field; the Briar Warden is the named elite that wakes when the
## shrine is lit. Every variant shares the same aggro, strike, health-bar, loot
## and respawn code, so the field behaves consistently even though it looks
## varied.

signal defeated(monster: Node)

const HP_BAR_SHADER := preload("res://scenes/world/monster_hp_bar.gdshader")

## Swing timelines, in seconds, per attack type. Every attack runs one of these
## clocks, and pose + damage + effects all key off the same progress.
const ATTACK_TIMELINES := {
	"claw": 0.5,
	"sweep": 0.72,
	"slam": 0.95,
	"volley": 1.05,
	"pounce": 0.75,
	"bolt": 0.7,
}

@export var variant := "mossling"
@export var display_name := "Mossling"
@export var max_health := 70.0
@export var damage := 9.0
@export var move_speed := 2.4
@export var aggro_range := 13.0
## Once chasing, the monster gives up when the hero slips this far away.
@export var deaggro_range := 21.0
## And it never drags itself this far from its home turf, whatever happens.
@export var leash_range := 25.0
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
var _chasing := false
var _swing := 0.0
var _attack_cooldown := 0.0
var _attack_type := "claw"
var _attack_total := 0.5
var _attack_flags := {}
var _special_cooldown := 0.0
var _pounce_target := Vector3.ZERO
var _walk_phase := 0.0
var _legs: Array[Node3D] = []
var _arm_pivots: Array[Node3D] = []
var _head: Node3D
var _tail: Node3D
var _orb_meshes: Array[MeshInstance3D] = []
var _spawn_position := Vector3.ZERO
var _spawn_rotation := 0.0
var _player: Node3D
var _visual: Node3D
var _flash := 0.0
var _flash_materials: Array[StandardMaterial3D] = []
var _bar_root: Node3D
var _bar_material: ShaderMaterial
var _bar_ratio := 1.0
var _bar_ghost := 1.0
var _last_hit_time := -10.0
var _hp_label: Label3D
var _name_label: Label3D
var _collision: CollisionShape3D
var _wisp := false
var _height := 1.2
var _radius := 0.42
var _slow_time := 0.0
var _slow_factor := 1.0
var _distract_time := 0.0
var _distract_point := Vector3.ZERO
var _poison_time := 0.0
var _poison_dps := 0.0
var _poison_tick := 0.0
var _poison_source := Vector3.ZERO

func _ready() -> void:
	add_to_group("enemy")
	if boss:
		add_to_group("enemy_boss")
		# The named elite fights to the edge of its clearing, not the whole map.
		deaggro_range = maxf(deaggro_range, 34.0)
		leash_range = maxf(leash_range, 40.0)
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
		# Shoulders: pivots so the arms can wind up and slam for the claw.
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.36 * side, 0.62, 0.0)
		shoulder.set_meta("side", side)
		shoulder.set_meta("rest_x", 0.0)
		shoulder.set_meta("rest_z", 0.5 * side)
		shoulder.set_meta("phase", PI if side < 0 else 0.0)
		_visual.add_child(shoulder)
		_arm_pivots.append(shoulder)
		_add_mesh(shoulder, "CylinderMesh", Vector3(0.0, -0.14, 0.0), Color(0.24, 0.33, 0.18), Vector3(0.09, 0.09, 0.5))
		# Hips: pivots so the feet take little steps in the walk cycle.
		var hip := Node3D.new()
		hip.position = Vector3(0.18 * side, 0.28, -0.02)
		hip.set_meta("phase", PI if side > 0 else 0.0)
		hip.set_meta("rest", 0.0)
		_visual.add_child(hip)
		_legs.append(hip)
		var foot := _add_mesh(hip, "SphereMesh", Vector3(0.0, -0.18, 0.0), Color(0.2, 0.26, 0.15), Vector3(0.17, 0.08, 0.22))
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
	# Head on a pivot so bites and idle glances can animate.
	_head = Node3D.new()
	_head.position = Vector3(0.0, 0.98, -0.62)
	_visual.add_child(_head)
	var head := _add_mesh(_head, "SphereMesh", Vector3(0.0, -0.06, -0.3), Color(0.3, 0.24, 0.17), Vector3(0.24, 0.2, 0.24))
	head.scale = Vector3(0.95, 1.0, 1.15)
	_add_mesh(_head, "SphereMesh", Vector3(0.0, -0.14, -0.56), Color(0.18, 0.14, 0.1), Vector3(0.12, 0.09, 0.12))
	_add_glow_eye(Vector3(-0.09, 0.0, -0.44), Color(1.0, 0.62, 0.22), _head)
	_add_glow_eye(Vector3(0.09, 0.0, -0.44), Color(1.0, 0.62, 0.22), _head)
	for side in [-1, 1]:
		var ear := _add_mesh(_head, "PrismMesh", Vector3(0.13 * side, 0.18, -0.26), Color(0.24, 0.19, 0.14), Vector3(0.13, 0.22, 0.09))
		ear.rotation.y = 0.15 * side
		# Four legs on hip pivots, phased for a diagonal trot.
		for front in [-1, 1]:
			for s2 in [-1, 1]:
				var hip := Node3D.new()
				hip.position = Vector3(0.22 * s2, 0.7, 0.32 * front)
				hip.set_meta("phase", 0.0 if float(front) * float(s2) > 0.0 else PI)
				hip.set_meta("rest", 0.08 * float(front))
				_visual.add_child(hip)
				_legs.append(hip)
				_add_mesh(hip, "CylinderMesh", Vector3(0.0, -0.32, 0.0), Color(0.2, 0.16, 0.12), Vector3(0.075, 0.09, 0.62))
		# Briar spikes running down the spine.
		for i in 5:
			var spike := _add_mesh(_visual, "PrismMesh", Vector3(0.0, 1.05 - float(i) * 0.04, -0.38 + float(i) * 0.22), Color(0.36, 0.44, 0.22), Vector3(0.1, 0.24 + 0.04 * float(i % 2), 0.08))
			spike.rotation.z = 0.1 * float(side)
	# Tail on its own pivot so it can wag.
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 1.06, 0.46)
	_visual.add_child(_tail)
	var tail := _add_mesh(_tail, "CylinderMesh", Vector3(0.0, -0.16, 0.32), Color(0.22, 0.18, 0.13), Vector3(0.07, 0.02, 0.72))
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
	# Core and halo are tracked so the bolt charge can pulse them.
	_orb_meshes.append(orb)
	_orb_meshes.append(halo)
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
		# Shoulders: pivots so the Warden can sweep and slam its arms.
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.58 * side, 2.0, 0.0)
		shoulder.set_meta("side", side)
		shoulder.set_meta("rest_x", 0.12)
		shoulder.set_meta("rest_z", 0.16 * side)
		_visual.add_child(shoulder)
		_arm_pivots.append(shoulder)
		_add_mesh(shoulder, "CylinderMesh", Vector3(0.1 * side, -0.5, 0.0), Color(0.22, 0.17, 0.11), Vector3(0.13, 0.1, 1.35))
		var claw := _add_mesh(shoulder, "PrismMesh", Vector3(0.18 * side, -1.12, -0.1), Color(0.42, 0.48, 0.24), Vector3(0.16, 0.4, 0.16))
		claw.rotation.z = 3.05 * side
		for i in 4:
			var thorn := _add_mesh(_visual, "PrismMesh", Vector3(0.36 * side, 1.05 + float(i) * 0.4, 0.15 * float(i % 2)), Color(0.4, 0.46, 0.23), Vector3(0.1, 0.34, 0.1))
			thorn.rotation.z = -0.5 * side
		# Feet on hip pivots, alternating phase for the heavy stomp.
		var hip := Node3D.new()
		hip.position = Vector3(0.28 * side, 0.6, -0.06)
		hip.set_meta("phase", 0.0 if side < 0 else PI)
		hip.set_meta("rest", 0.0)
		_visual.add_child(hip)
		_legs.append(hip)
		var foot := _add_mesh(hip, "CylinderMesh", Vector3(0.0, -0.44, 0.0), Color(0.18, 0.14, 0.09), Vector3(0.23, 0.28, 0.4))
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

func _add_glow_eye(position: Vector3, color: Color, parent: Node3D = null) -> void:
	var eye := _add_mesh(parent if parent != null else _visual, "SphereMesh", position, color, Vector3(0.06, 0.06, 0.055), true)
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
	_bar_root.position = Vector3(0.0, _height + 0.45, 0.0)
	add_child(_bar_root)

	# A single shader-drawn pill replaces the old pair of scaled quads: the
	# billboard keeps its true size while the fill moves through shader
	# uniforms, so the bar never stretches or snaps as the camera moves.
	_bar_material = ShaderMaterial.new()
	_bar_material.shader = HP_BAR_SHADER
	_bar_material.render_priority = 3
	_bar_material.set_shader_parameter("ratio", 1.0)
	_bar_material.set_shader_parameter("ghost", 1.0)
	if boss:
		# The named elite wears a hot ember rim instead of gold.
		_bar_material.set_shader_parameter("rim_color", Color(1.0, 0.62, 0.3, 0.95))

	var bar := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.55, 0.2) if boss else Vector2(1.3, 0.15)
	mesh.material = _bar_material
	bar.mesh = mesh
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_root.add_child(bar)

	# A small live tally riding the bar, e.g. "48 / 70".
	_hp_label = Label3D.new()
	_hp_label.font_size = 40 if boss else 32
	_hp_label.pixel_size = 0.0026
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.outline_size = 12
	_hp_label.outline_modulate = Color(0.04, 0.03, 0.02, 1.0)
	_hp_label.modulate = Color(1.0, 0.95, 0.85, 0.92)
	_hp_label.render_priority = 4
	_bar_root.add_child(_hp_label)

	_name_label = Label3D.new()
	_name_label.text = display_name.to_upper()
	_name_label.font_size = 56 if boss else 44
	_name_label.pixel_size = 0.0032
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.outline_size = 16
	_name_label.outline_modulate = Color(0.05, 0.035, 0.02, 1.0)
	_name_label.modulate = Color(1.0, 0.72, 0.52, 1.0) if boss else Color(0.94, 0.86, 0.68, 1.0)
	_name_label.position = Vector3(0.0, 0.19, 0.0)
	_bar_root.add_child(_name_label)
	_update_health_bar()

func _update_health_bar() -> void:
	_bar_ratio = clampf(health / maxf(max_health, 0.001), 0.0, 1.0)
	if _bar_ghost < _bar_ratio:
		# Heals snap the ghost forward to the truth immediately.
		_bar_ghost = _bar_ratio
	if _bar_material != null:
		_bar_material.set_shader_parameter("ratio", _bar_ratio)
		_bar_material.set_shader_parameter("ghost", _bar_ghost)
	if _hp_label != null:
		var text := "%d/%d" % [roundi(health), roundi(max_health)]
		if text != _hp_label.text:
			_hp_label.text = text

## The pale wound trail lingers where the last hits landed, then bleeds down
## toward the true fill after half a second — the same trick the HUD bars use.
func _update_bar_ghost(delta: float) -> void:
	if _bar_ghost <= _bar_ratio or _time - _last_hit_time < 0.5:
		return
	_bar_ghost = maxf(_bar_ratio, _bar_ghost - delta * 0.85)
	if _bar_material != null:
		_bar_material.set_shader_parameter("ghost", _bar_ghost)

# ---------------------------------------------------------------------------
# Behaviour
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _dead:
		return
	_update_status(delta)
	if _dead:
		return
	_update_bar_ghost(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_update_bar_visibility()

	if _distract_time > 0.0:
		_update_distracted(delta)
		return

	if dormant or _player == null:
		_idle(delta)
		return

	var offset := _player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var speed := move_speed * _slow_multiplier()

	# Aggro behaves like a proper RPG encounter: the monster notices the hero
	# up close, gives up when they slip beyond its attention span, and never
	# drags itself past the leash around its home turf. No more conga lines
	# trailing the player across the whole Reach.
	if not _chasing:
		if distance <= aggro_range:
			_chasing = true
	elif distance > deaggro_range \
			or global_position.distance_to(_spawn_position) > leash_range:
		_chasing = false

	# A wolf mid-pounce flies on its own clock: crouch, launch, land.
	if _attack_type == "pounce" and _swing > 0.0:
		_update_pounce_motion(delta)
		_update_swing(delta)
		_animate(delta, distance)
		return

	if _chasing and distance > 0.01:
		var to_player := offset / distance
		if distance > attack_range * 0.78:
			var desired := to_player * speed
			velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-7.0 * delta))
			velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-7.0 * delta))
		else:
			velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-10.0 * delta))
			velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-10.0 * delta))
		if distance <= _attack_trigger_range() and _attack_cooldown <= 0.0 and _swing <= 0.0:
			_begin_attack()
		var wanted_yaw := atan2(-to_player.x, -to_player.z)
		rotation.y = lerp_angle(rotation.y, wanted_yaw, 1.0 - exp(-6.0 * delta))
	else:
		# Off the chase, it drifts home — knitting any wounds back together on
		# the way, the way resting monsters do between fights.
		health = minf(max_health, health + max_health * 0.08 * delta)
		_update_health_bar()
		var home := _spawn_position - global_position
		home.y = 0.0
		if home.length() > 1.2:
			var desired := home.normalized() * speed * 0.45
			velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-3.0 * delta))
			velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-3.0 * delta))
		else:
			velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-4.0 * delta))
			velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-4.0 * delta))
		if home.length() > 2.0:
			rotation.y = lerp_angle(rotation.y, atan2(-home.x, -home.z), 1.0 - exp(-2.0 * delta))

	# Attacks root the beast in place — the pounce drives its own motion.
	if _swing > 0.0 and _attack_type != "pounce":
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-12.0 * delta))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-12.0 * delta))

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

## An illusion clone pulls nearby enemies off the hero for a few seconds. The
## monster chases the decoy and swings at it, but cannot damage the real player
## while distracted.
func _update_distracted(delta: float) -> void:
	var offset := _distract_point - global_position
	offset.y = 0.0
	var distance := offset.length()
	var speed := move_speed * _slow_multiplier()
	if distance > 1.45:
		var desired := (offset / maxf(distance, 0.01)) * speed
		velocity.x = lerpf(velocity.x, desired.x, 1.0 - exp(-7.0 * delta))
		velocity.z = lerpf(velocity.z, desired.z, 1.0 - exp(-7.0 * delta))
		rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), 1.0 - exp(-6.0 * delta))
	else:
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-10.0 * delta))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-10.0 * delta))
		if _swing <= 0.0 and _attack_cooldown <= 0.0:
			_attack_type = "claw"
			_attack_total = float(ATTACK_TIMELINES["claw"])
			_attack_flags.clear()
			_swing = _attack_total
			_attack_cooldown = attack_interval
	if not _wisp:
		velocity.y = -20.0
	else:
		velocity.y = 0.0
	move_and_slide()
	if _wisp:
		global_position.y = _spawn_position.y
	_update_swing(delta)
	_animate(delta, distance)

func _update_status(delta: float) -> void:
	_special_cooldown = maxf(0.0, _special_cooldown - delta)
	if _slow_time > 0.0:
		_slow_time = maxf(0.0, _slow_time - delta)
		if _slow_time <= 0.0:
			_slow_factor = 1.0
	if _distract_time > 0.0:
		_distract_time = maxf(0.0, _distract_time - delta)
	if _poison_time > 0.0:
		_poison_time = maxf(0.0, _poison_time - delta)
		_poison_tick -= delta
		if _poison_tick <= 0.0:
			_poison_tick = 1.0
			take_damage(_poison_dps, _poison_source)

func _slow_multiplier() -> float:
	return _slow_factor if _slow_time > 0.0 else 1.0

func _begin_attack() -> void:
	var type := _choose_attack()
	_attack_type = type
	_attack_total = float(ATTACK_TIMELINES.get(type, 0.5))
	_attack_flags.clear()
	_swing = _attack_total
	_attack_cooldown = attack_interval
	if type == "pounce":
		_special_cooldown = 4.0
		var target_ok := _player != null and is_instance_valid(_player)
		_pounce_target = _player.global_position if target_ok else global_position
	elif type == "slam" or type == "volley":
		_special_cooldown = 4.5

## Pick the attack this swing will perform. Wisps always lob bolts; the Warden
## alternates its named specials (ground slam, thorn volley) on a cooldown and
## sweeps otherwise; wolves pounce from a hop's distance and claw up close.
func _choose_attack() -> String:
	var distance := 999.0
	if _player != null and is_instance_valid(_player):
		distance = global_position.distance_to(_player.global_position)
	if _wisp:
		return "bolt"
	if boss:
		if _special_cooldown <= 0.0:
			return "slam" if distance <= 4.2 else "volley"
		return "sweep"
	if variant == "briar_wolf" and _special_cooldown <= 0.0 and distance > attack_range * 1.05:
		return "pounce"
	return "claw"

## How close the hero must be before this monster starts a swing. Specials
## reach further than the basic strike so the boss can open from range.
func _attack_trigger_range() -> float:
	if boss and _special_cooldown <= 0.0:
		return maxf(attack_range, 6.0)
	if variant == "briar_wolf" and _special_cooldown <= 0.0:
		return attack_range + 2.4
	return attack_range

func _update_swing(delta: float) -> void:
	if _swing <= 0.0:
		return
	_swing = maxf(0.0, _swing - delta)
	var p := 1.0 - _swing / maxf(_attack_total, 0.001)
	match _attack_type:
		"claw":
			if p >= 0.52 and _a_once("hit"):
				var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
				_spawn_dust_puff(global_position + forward * 1.1, Color(0.62, 0.55, 0.4, 0.6))
				if _player_in_reach(attack_range + 0.6):
					_strike_player(damage)
		"sweep":
			if p >= 0.55 and _a_once("hit"):
				_spawn_arc_fx(Color(1.0, 0.55, 0.25, 0.9), 2.9, 0.32, 200.0, _height * 0.75)
				if _player_in_reach(attack_range + 1.0):
					_strike_player(damage)
		"slam":
			if p >= 0.2 and _a_once("telegraph"):
				# A faint ring marks the impact zone while the arms rise.
				_shock_ring(_slam_spot(), 3.6, Color(1.0, 0.4, 0.18, 0.3))
			if p >= 0.58 and _a_once("hit"):
				_slam_impact()
		"volley":
			if p >= 0.45 and _a_once("cast"):
				_thorn_volley()
		"bolt":
			if p >= 0.55 and _a_once("cast"):
				_cast_bolt()
		"pounce":
			if p >= 0.62 and _a_once("pounce_land"):
				_pounce_impact()
	if _swing <= 0.0 and not _dead:
		# The swing is over: fold every posed limb back to rest.
		_visual.scale = Vector3.ONE
		_visual.rotation.x = 0.0
		_visual.rotation.z = 0.0
		_visual.position.z = 0.0
		_visual.position.y = 0.0
		for arm in _arm_pivots:
			arm.rotation = Vector3(float(arm.get_meta("rest_x", 0.0)), 0.0, float(arm.get_meta("rest_z", 0.0)))
		for leg in _legs:
			leg.rotation.x = float(leg.get_meta("rest", 0.0))
		if _head != null:
			_head.rotation = Vector3.ZERO
		if _tail != null:
			_tail.rotation.y = 0.0
		for orb in _orb_meshes:
			orb.scale = Vector3.ONE

## One-shot gate for key frames inside an attack timeline.
func _a_once(key: String) -> bool:
	if _attack_flags.has(key):
		return false
	_attack_flags[key] = true
	return true

func _player_in_reach(reach: float) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var offset := _player.global_position - global_position
	offset.y = 0.0
	return offset.length() <= reach

## All player damage funnels through here so the illusion decoy keeps the real
## hero safe while it holds aggro.
func _strike_player(raw: float) -> void:
	if _distract_time > 0.0:
		return
	_hit_player(raw)

func _hit_player(raw: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("apply_incoming_damage"):
		hud.call("apply_incoming_damage", raw, global_position)

## The Warden slams the ground a pace in front of itself.
func _slam_spot() -> Vector3:
	var forward := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	return global_position + forward * 1.6

func _slam_impact() -> void:
	var spot := _slam_spot()
	_shock_ring(spot, 3.6, Color(1.0, 0.45, 0.2, 0.9))
	_spawn_dust_burst(3.0)
	if _player_in_reach(3.2):
		_strike_player(damage * 1.25)

func _pounce_impact() -> void:
	var spot := global_position
	_shock_ring(spot, 2.1, Color(0.82, 0.62, 0.36, 0.85))
	for i in 6:
		var angle := randf() * TAU
		var spot2 := spot + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.4, 1.1)
		spot2.y = 0.18
		_spawn_dust_puff(spot2, Color(0.7, 0.6, 0.44, 0.8))
	if _player_in_reach(1.9):
		_strike_player(damage * 1.2)

## A flat expanding ring on the ground — the reusable Shockwave prop.
func _shock_ring(spot: Vector3, radius: float, color: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var wave := Shockwave.new()
	wave.setup(color, radius, 0.55)
	parent.add_child(wave)
	wave.global_position = spot + Vector3(0.0, 0.12, 0.0)

## Five emissive segments sweeping across an arc, then collapsing away.
func _spawn_arc_fx(color: Color, radius: float, duration: float, energy: float, height: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var pivot := Node3D.new()
	parent.add_child(pivot)
	pivot.global_position = global_position + Vector3(0.0, height, 0.0)
	pivot.rotation.y = rotation.y - 1.1
	for i in 5:
		var angle := float(i) * 0.26
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.62, 0.07, 0.1)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy * 0.01
		box.material = material
		seg.mesh = box
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seg.position = Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)
		seg.rotation.y = angle
		pivot.add_child(seg)
	var tween := pivot.create_tween()
	tween.set_parallel(true)
	tween.tween_property(pivot, "rotation:y", pivot.rotation.y + 2.2, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(pivot, "scale", Vector3(0.9, 0.05, 0.9), duration)
	tween.chain().tween_callback(pivot.queue_free)

func _spawn_dust_puff(spot: Vector3, color: Color) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.26
	mesh.height = 0.36
	mesh.radial_segments = 7
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material = material
	puff.mesh = mesh
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(puff)
	puff.global_position = spot
	puff.scale = Vector3(0.6, 0.5, 0.6)
	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "scale", Vector3(1.9, 1.3, 1.9), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "global_position", spot + Vector3(randf_range(-0.3, 0.3), 0.55, randf_range(-0.3, 0.3)), 0.5)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(puff.queue_free)

func _spawn_dust_burst(radius: float) -> void:
	for i in 10:
		var angle := randf() * TAU
		var spot := global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius * randf_range(0.35, 1.0)
		spot.y = 0.18
		_spawn_dust_puff(spot, Color(0.7, 0.58, 0.4, 0.7))

## The Warden hurls three thorn bolts in a loose fan — staggered, so a rolling
## hero can slip between them.
func _thorn_volley() -> void:
	_spawn_thorn_bolt(0.0, -0.55)
	_spawn_thorn_bolt(0.22, 0.0)
	_spawn_thorn_bolt(0.44, 0.55)

## One green thorn, launched after a delay, drilling toward a locked aim point.
## Dodgeable: it only bites if the hero is still near that point on arrival.
func _spawn_thorn_bolt(delay: float, fan: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var parent := get_parent()
	if parent == null:
		return
	var right := Vector3(cos(rotation.y), 0.0, -sin(rotation.y))
	var goal := _player.global_position + right * (fan * 2.2) + Vector3(0.0, 0.9, 0.0)
	var start := global_position + Vector3(0.0, _height * 0.72, 0.0)
	var thorn := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.14, 0.42, 0.14)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.55, 0.85, 0.3, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.45, 0.85, 0.28, 1.0)
	material.emission_energy_multiplier = 1.6
	mesh.material = material
	thorn.mesh = mesh
	thorn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(thorn)
	thorn.global_position = start
	thorn.look_at(goal, Vector3.UP)
	thorn.rotate_x(-PI * 0.5)
	thorn.visible = false
	var flight := clampf(start.distance_to(goal) / 14.0, 0.35, 0.9)
	var tween := thorn.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: thorn.visible = true)
	tween.tween_property(thorn, "global_position", goal, flight)
	tween.parallel().tween_property(thorn, "rotation:y", thorn.rotation.y + TAU * 2.0, flight)
	tween.tween_callback(func() -> void:
		if is_instance_valid(thorn):
			_spawn_dust_puff(thorn.global_position, Color(0.55, 0.8, 0.35, 0.8))
			thorn.queue_free()
		if _player != null and is_instance_valid(_player):
			var chest := _player.global_position + Vector3(0.0, 0.95, 0.0)
			if chest.distance_to(goal) < 1.25:
				_strike_player(damage * 0.6)
	)

## The pounce owns the wolf's motion for its whole timeline: a crouch in place,
## a flat dash toward the locked target with dust kicking up behind, then a
## heavy landing handled by the swing timeline.
func _update_pounce_motion(delta: float) -> void:
	var p := 1.0 - _swing / maxf(_attack_total, 0.001)
	if not _wisp:
		velocity.y = -20.0
	else:
		velocity.y = 0.0
	if p < 0.3:
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-14.0 * delta))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-14.0 * delta))
	elif p < 0.62:
		var dir := _pounce_target - global_position
		dir.y = 0.0
		var step := 9.0 * delta
		if dir.length() > step:
			dir = dir.normalized() * step
		velocity.x = dir.x / delta
		velocity.z = dir.z / delta
		if _a_once("dust_%d" % roundi(p * 20.0)):
			_spawn_dust_puff(global_position + Vector3(0.0, 0.15, 0.0), Color(0.68, 0.58, 0.42, 0.65))
	else:
		velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-9.0 * delta))
		velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-9.0 * delta))
	move_and_slide()
	if _wisp:
		global_position.y = _spawn_position.y

func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)

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
	if _swing > 0.0:
		# While attacking, the swing timeline poses the whole body.
		_apply_attack_pose(1.0 - _swing / maxf(_attack_total, 0.001))
	else:
		# The walk clock only turns while the beast actually moves.
		_walk_phase += delta * (6.0 + 3.0 * gait) * gait
		_pose_walk(gait)
		var breathe := sin(_time * 2.0) * 0.02
		_visual.position.y = breathe * (1.0 - gait) + (sin(_time * 8.0) * 0.015 * gait if not _wisp else 0.0)
		if _wisp:
			_visual.position.y = sin(_time * 1.7) * 0.12
			_visual.rotation.y += delta * 0.6
			_visual.rotation.z = sin(_time * 1.1) * 0.08
		else:
			_visual.rotation.z = sin(_time * 7.0) * 0.035 * gait
			_visual.rotation.x = breathe * 0.2
			_visual.position.z = 0.0
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

## Procedural gait: legs stride on their phase offsets, arms counter-swing,
## the tail wags and the head bobs — all scaled by how fast the beast moves.
func _pose_walk(gait: float) -> void:
	var amp := 0.55 * gait
	for leg in _legs:
		var phase := float(leg.get_meta("phase", 0.0))
		var rest := float(leg.get_meta("rest", 0.0))
		leg.rotation.x = rest + sin(_walk_phase + phase) * amp
	for arm in _arm_pivots:
		var arm_phase := float(arm.get_meta("phase", 0.0))
		arm.rotation.x = float(arm.get_meta("rest_x", 0.0)) + sin(_walk_phase + arm_phase) * amp * 0.7
		arm.rotation.z = float(arm.get_meta("rest_z", 0.0)) + sin(_walk_phase + arm_phase) * 0.08 * gait
	if _head != null:
		_head.rotation.x = sin(_walk_phase * 2.0) * 0.045 * gait
		_head.rotation.y = sin(_walk_phase) * 0.05 * gait
	if _tail != null:
		_tail.rotation.y = sin(_walk_phase * 1.3 + 0.4) * (0.2 + 0.3 * gait)

## Pose the body for the current attack. Damage and effects are handled by the
## swing timeline; this only moves limbs so the strike reads on screen.
func _apply_attack_pose(p: float) -> void:
	match _attack_type:
		"claw":
			_pose_claw(p)
		"sweep":
			_pose_sweep(p)
		"slam":
			_pose_slam(p)
		"volley":
			_pose_volley(p)
		"bolt":
			_pose_bolt(p)
		"pounce":
			_pose_pounce(p)

## Wind the arms up, then drive them down with a lunge. Wolves have no arms, so
## their claw reads as a head-snap lunge instead.
func _pose_claw(p: float) -> void:
	var windup := _ease_out(clampf(p / 0.52, 0.0, 1.0))
	var strike := _ease_out(clampf((p - 0.52) / 0.48, 0.0, 1.0))
	var angle := -1.3 * windup + 2.2 * strike
	for arm in _arm_pivots:
		arm.rotation.x = float(arm.get_meta("rest_x", 0.0)) + angle
		arm.rotation.z = float(arm.get_meta("rest_z", 0.0))
	_visual.position.z = -0.2 * strike
	_visual.rotation.x = -0.12 * windup + 0.3 * strike
	if _head != null:
		_head.rotation.x = -0.3 * windup + 0.55 * strike
	if _tail != null:
		_tail.rotation.y = sin(p * PI) * 0.5

## The Warden's wide single-arm sweep, pulling back before carving across.
func _pose_sweep(p: float) -> void:
	var windup := _ease_out(clampf(p / 0.4, 0.0, 1.0))
	var strike := _ease_out(clampf((p - 0.4) / 0.6, 0.0, 1.0))
	for arm in _arm_pivots:
		var side := float(arm.get_meta("side", 1.0))
		arm.rotation.z = float(arm.get_meta("rest_z", 0.0))
		if side > 0.0:
			arm.rotation.x = -0.7 * windup
			arm.rotation.y = lerpf(-1.4, 1.5, strike)
		else:
			arm.rotation.x = float(arm.get_meta("rest_x", 0.0)) + 0.1
			arm.rotation.y = 0.0
	_visual.rotation.x = 0.1 * windup - 0.12 * strike

## Both arms haul up overhead, hang a beat, then crash down with the body.
func _pose_slam(p: float) -> void:
	var raise := _ease_out(clampf(p / 0.5, 0.0, 1.0))
	var drop := _ease_out(clampf((p - 0.5) / 0.14, 0.0, 1.0))
	var angle := lerpf(0.0, -2.1, raise)
	angle = lerpf(angle, 0.8, drop)
	for arm in _arm_pivots:
		arm.rotation.x = float(arm.get_meta("rest_x", 0.0)) + angle
		arm.rotation.y = 0.0
		arm.rotation.z = float(arm.get_meta("rest_z", 0.0))
	_visual.rotation.x = 0.22 * raise - 0.32 * drop
	_visual.position.z = -0.35 * drop
	_visual.position.y = -0.12 * drop

## One arm hurls the thorn bolts; the body leans into the throw.
func _pose_volley(p: float) -> void:
	var raise := _ease_out(clampf(p / 0.45, 0.0, 1.0))
	var release := _ease_out(clampf((p - 0.45) / 0.25, 0.0, 1.0))
	for arm in _arm_pivots:
		var side := float(arm.get_meta("side", 1.0))
		arm.rotation.y = 0.0
		arm.rotation.z = float(arm.get_meta("rest_z", 0.0))
		if side > 0.0:
			arm.rotation.x = float(arm.get_meta("rest_x", 0.0)) - 2.3 * raise + 1.6 * release
		else:
			arm.rotation.x = float(arm.get_meta("rest_x", 0.0))
	_visual.rotation.x = 0.14 * raise - 0.2 * release

## The wisp swells and shivers as the bolt charges in its core.
func _pose_bolt(p: float) -> void:
	var charge := _ease_out(clampf(p / 0.55, 0.0, 1.0))
	if _orb_meshes.size() > 0:
		_orb_meshes[0].scale = Vector3.ONE * (1.0 + 0.18 * charge)
	if _orb_meshes.size() > 1:
		var pulse := 1.0 + 0.3 * charge + 0.1 * sin(_time * 22.0) * charge
		_orb_meshes[1].scale = Vector3.ONE * pulse
	_visual.scale = Vector3.ONE * (1.0 + 0.07 * charge)

## Crouch, stretch into the dash, then squash on the landing.
func _pose_pounce(p: float) -> void:
	if p < 0.3:
		var t := p / 0.3
		_visual.scale = Vector3(1.0 + 0.22 * t, 1.0 - 0.26 * t, 1.0 + 0.22 * t)
	elif p < 0.62:
		var t := (p - 0.3) / 0.32
		_visual.scale = Vector3(1.0 - 0.18 * t, 1.0 + 0.28 * t, 1.0 - 0.18 * t)
		for leg in _legs:
			var rest := float(leg.get_meta("rest", 0.0))
			leg.rotation.x = rest - 0.4 if rest < 0.0 else rest + 0.4
	else:
		var t := clampf((p - 0.62) / 0.38, 0.0, 1.0)
		var squash := sin(t * PI)
		_visual.scale = Vector3(1.0 + 0.16 * squash, 1.0 - 0.2 * squash, 1.0 + 0.16 * squash)

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
	# Pain pulls aggro, however the hit arrived — a well-placed arrow from
	# beyond arm's reach still earns the monster's full attention.
	_chasing = true
	_last_hit_time = _time
	health = maxf(0.0, health - amount)
	_flash = 1.0
	_spawn_number(amount, hit_position)
	_update_health_bar()
	if health <= 0.0:
		_die()

## Ice Lance calls this. A stronger slow wins, and a fresh hit extends the
## duration without stacking the multiplier lower and lower.
func apply_slow(factor: float, duration: float) -> void:
	if _dead:
		return
	_slow_factor = minf(_slow_factor, clampf(factor, 0.05, 1.0))
	_slow_time = maxf(_slow_time, duration)

## Poison Blade calls this. Damage is dealt in one-second ticks so the target
## keeps losing health after the blade has already left.
func apply_poison(damage_per_second: float, duration: float, source := Vector3.ZERO) -> void:
	if _dead or damage_per_second <= 0.0 or duration <= 0.0:
		return
	_poison_dps = maxf(_poison_dps, damage_per_second)
	_poison_time = maxf(_poison_time, duration)
	_poison_source = source if source != Vector3.ZERO else global_position
	_poison_tick = minf(_poison_tick, 0.35)
	if _poison_tick <= 0.0:
		_poison_tick = 0.35

## Illusion Clone calls this to pull aggro onto the decoy.
func distract(point: Vector3, duration: float) -> void:
	if _dead:
		return
	_distract_time = maxf(_distract_time, duration)
	_distract_point = point
	_attack_cooldown = maxf(_attack_cooldown, 0.25)

func awaken() -> void:
	if not dormant:
		return
	dormant = false
	_chasing = true
	_play_idle_pop()
	# The Warden announces itself: a white-hot flash and a ground ring.
	_flash = 1.0
	_shock_ring(global_position, 4.2, Color(1.0, 0.5, 0.25, 0.8))
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.call("show_toast", "%s stirs. The briars pull taut." % display_name)

## Save system: a Warden already felled in the saved run loads resting. It
## goes straight to its death state without paying out loot a second time.
func mark_defeated() -> void:
	if _dead:
		return
	_dead = true
	dormant = false
	set_physics_process(false)
	velocity = Vector3.ZERO
	if _collision != null:
		_collision.set_deferred("disabled", true)
	if _bar_root != null:
		_bar_root.visible = false
	visible = false

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
	_chasing = false
	_swing = 0.0
	_attack_type = "claw"
	_attack_flags.clear()
	_special_cooldown = 0.0
	_bar_ghost = 1.0
	_last_hit_time = -10.0
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
