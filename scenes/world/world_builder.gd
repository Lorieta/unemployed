extends Node3D

## Builds Hearthmere and the Thorned Field out of simple primitives. The town
## sits in the +Z half of the map with the gate at z = -30, and the field runs
## away toward -Z. Everything here is generated at load so the scene file stays
## readable and the town can be re-dressed by changing a few numbers.

const TREE := preload("res://scenes/demo/low_poly_tree.tscn")

const TOWN_CENTER := Vector3(0.0, 0.0, 4.0)
const GATE_Z := -30.0
const SHRINE_POSITION := Vector3(-6.0, 0.0, -74.0)

var _materials := {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 20261026
	_build_ground_details()
	_build_plaza()
	_build_buildings()
	_build_market()
	_build_smithy()
	_build_gate()
	_build_town_dressing()
	_build_field()
	_build_boundaries()

# ---------------------------------------------------------------------------
# Ground and roads
# ---------------------------------------------------------------------------

func _build_ground_details() -> void:
	var root := _group("Roads")
	var dirt := _mat(Color(0.34, 0.3, 0.22), 1.0)
	var dirt_light := _mat(Color(0.4, 0.35, 0.25), 1.0)
	var cobble := _mat(Color(0.38, 0.38, 0.35), 0.98)
	var cobble_dark := _mat(Color(0.32, 0.32, 0.3), 1.0)

	# The road from the spawn point through the plaza and on to the gate.
	_mesh(root, "box", Vector3(0.0, 0.02, 5.0), Vector3(5.0, 0.05, 34.0), dirt)
	_mesh(root, "box", Vector3(0.0, 0.025, -21.0), Vector3(4.2, 0.05, 22.0), dirt_light)
	_mesh(root, "box", Vector3(-1.5, 0.03, -47.0), Vector3(3.6, 0.05, 30.0), dirt)
	_mesh(root, "box", Vector3(-4.6, 0.03, -66.0), Vector3(3.2, 0.05, 26.0), dirt_light)
	_mesh(root, "box", Vector3(-4.0, 0.03, -86.0), Vector3(3.4, 0.05, 18.0), dirt)

	# Plaza cobbles, layered so the edge reads as worn stone.
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.05, 0.0), Vector3(8.6, 9.4, 0.1), cobble_dark)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.08, 0.0), Vector3(7.9, 8.6, 0.1), cobble)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.11, 0.0), Vector3(6.9, 7.4, 0.1), cobble_dark)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.14, 0.0), Vector3(5.8, 6.3, 0.1), cobble)

	# Mossy field clearings.
	for spot in [
		Vector3(-6.0, 0.03, -74.0),
		Vector3(4.0, 0.03, -44.0),
		Vector3(-16.0, 0.03, -56.0),
		Vector3(14.0, 0.03, -64.0),
		Vector3(-2.0, 0.03, -96.0),
	]:
		var radius := _rng.randf_range(5.5, 8.0)
		_mesh(root, "cylinder", spot, Vector3(radius, radius + 0.8, 0.05), _mat(Color(0.22, 0.27, 0.19), 1.0))

	# Grass tufts around the verges.
	for i in 140:
		var x := _rng.randf_range(-28.0, 28.0)
		var z := _rng.randf_range(-108.0, 34.0)
		if absf(x) < 4.0 and z > -90.0:
			continue
		if Vector2(x - SHRINE_POSITION.x, z - SHRINE_POSITION.z).length() < 7.0:
			continue
		_tuft(root, Vector3(x, 0.0, z), _rng.randf_range(0.7, 1.5))

func _tuft(parent: Node3D, position: Vector3, size: float) -> void:
	var color := Color(0.27, 0.36, 0.2) if _rng.randf() > 0.4 else Color(0.34, 0.41, 0.23)
	var material := _mat(color, 1.0)
	for i in 3:
		var blade := _mesh(parent, "prism", position + Vector3(_rng.randf_range(-0.16, 0.16), 0.18 * size, _rng.randf_range(-0.16, 0.16)), Vector3(0.06, 0.36 * size, 0.05), material)
		blade.rotation.y = _rng.randf() * TAU
		blade.rotation.z = _rng.randf_range(-0.16, 0.16)

# ---------------------------------------------------------------------------
# Hearthmere
# ---------------------------------------------------------------------------

func _build_plaza() -> void:
	var root := _group("Plaza")
	# Well-side lanterns, benches, and a notice board.
	for offset in [
		Vector3(-7.4, 0.0, 8.4),
		Vector3(8.6, 0.0, 8.2),
		Vector3(-8.2, 0.0, -1.6),
		Vector3(9.0, 0.0, -2.4),
	]:
		_make_lamp(root, offset)
	_make_bench(root, Vector3(-4.2, 0.0, 1.2), 0.4)
	_make_bench(root, Vector3(4.4, 0.0, 6.6), -0.5)
	_make_notice_board(root, Vector3(-6.8, 0.0, 4.2), 0.3)
	_barrel(root, Vector3(-9.8, 0.0, 6.2), 0.5)
	_barrel(root, Vector3(-10.6, 0.0, 5.5), 0.35)
	_crate(root, Vector3(9.6, 0.0, 6.0), 0.9, 0.2)
	_crate(root, Vector3(9.0, 0.0, 6.7), 0.7, -0.4)
	_hay(root, Vector3(-11.2, 0.0, 1.0), 1.0)

	# A low fountain basin in the middle of the square.
	var stone := _mat(Color(0.36, 0.36, 0.33), 0.98)
	var stone_dark := _mat(Color(0.28, 0.29, 0.27), 1.0)
	var water := _mat(Color(0.24, 0.46, 0.44), 0.25, 0.0)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.18, 0.0), Vector3(2.25, 2.4, 0.34), stone_dark)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.34, 0.0), Vector3(1.9, 2.05, 0.1), stone)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.39, 0.0), Vector3(1.55, 1.7, 0.06), water)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 0.78, 0.0), Vector3(0.24, 0.34, 1.0), stone)
	_mesh(root, "cylinder", TOWN_CENTER + Vector3(0.0, 1.28, 0.0), Vector3(0.7, 0.5, 0.16), stone_dark)
	_mesh(root, "sphere", TOWN_CENTER + Vector3(0.0, 1.5, 0.0), Vector3(0.22, 0.22, 0.22), water)

	# Bunting strung between the market and the hall.
	var cloth_colors := [Color(0.62, 0.2, 0.16), Color(0.78, 0.6, 0.22), Color(0.24, 0.42, 0.33)]
	for i in 9:
		var x := -8.0 + float(i) * 2.0
		var y := 4.1 + sin(float(i) * 0.6) * 0.18
		var flag := _mesh(root, "prism", Vector3(x, y, -26.2), Vector3(0.28, 0.5, 0.03), _mat(cloth_colors[i % cloth_colors.size()], 0.9))
		flag.rotation.z = PI
		flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_buildings() -> void:
	var root := _group("Buildings")
	# Elder's hall at the head of the square.
	_make_house(root, Vector3(0.0, 0.0, -18.0), Vector3(10.0, 4.2, 7.0), Color(0.42, 0.36, 0.26), Color(0.3, 0.17, 0.1), 0.0, "THE ELDER'S HALL", Color(0.7, 0.56, 0.28))
	# Cottages around the green.
	_make_house(root, Vector3(-17.0, 0.0, 10.0), Vector3(6.4, 3.2, 5.4), Color(0.46, 0.4, 0.3), Color(0.32, 0.2, 0.12), PI * 0.35, "", Color(0.55, 0.42, 0.22))
	_make_house(root, Vector3(16.5, 0.0, 15.0), Vector3(6.8, 3.4, 5.6), Color(0.4, 0.36, 0.28), Color(0.27, 0.18, 0.11), -PI * 0.32, "", Color(0.58, 0.44, 0.24))
	_make_house(root, Vector3(-18.0, 0.0, -6.0), Vector3(7.0, 3.8, 5.8), Color(0.44, 0.38, 0.29), Color(0.3, 0.19, 0.1), PI * 0.5, "", Color(0.62, 0.48, 0.26))
	_make_house(root, Vector3(17.0, 0.0, -6.0), Vector3(6.4, 3.4, 5.2), Color(0.4, 0.35, 0.27), Color(0.28, 0.18, 0.11), -PI * 0.5, "", Color(0.55, 0.44, 0.24))
	# Houses along the approach, making the road feel lived in.
	_make_house(root, Vector3(-14.0, 0.0, 24.0), Vector3(6.0, 3.0, 5.0), Color(0.45, 0.4, 0.31), Color(0.32, 0.2, 0.12), PI * 0.2, "", Color(0.6, 0.48, 0.26))
	_make_house(root, Vector3(14.5, 0.0, 27.0), Vector3(6.2, 3.2, 5.0), Color(0.41, 0.37, 0.29), Color(0.29, 0.18, 0.11), -PI * 0.25, "", Color(0.57, 0.44, 0.24))

func _build_market() -> void:
	var root := _group("Market")
	var stall := _make_stall(root, Vector3(10.4, 0.0, 1.6), -PI * 0.5, Color(0.44, 0.2, 0.16), "MIRA'S WARES")
	var produce := _mat(Color(0.62, 0.22, 0.13), 0.9)
	for i in 5:
		_mesh(stall, "sphere", Vector3(-1.2 + 0.25 * float(i), 1.0, 0.5 - 0.18 * float(i % 2)), Vector3(0.1, 0.1, 0.1), produce)
	_make_stall(root, Vector3(-10.4, 0.0, 4.2), PI * 0.5, Color(0.24, 0.38, 0.31), "TRAVEL GOODS")
	# Crates and sacks behind the stalls.
	for offset in [Vector3(11.8, 0.0, 3.2), Vector3(12.4, 0.0, 2.5), Vector3(-12.0, 0.0, 5.6)]:
		_crate(root, offset, _rng.randf_range(0.6, 0.95), _rng.randf_range(0.0, 0.4))
	_barrel(root, Vector3(12.4, 0.0, 0.2), 0.42)
	_barrel(root, Vector3(11.8, 0.0, -0.6), 0.34)

func _build_smithy() -> void:
	var root := _group("Smithy")
	var stone := _mat(Color(0.3, 0.29, 0.27), 0.98)
	var wood := _mat(Color(0.25, 0.16, 0.09), 0.95)
	var roof := _mat(Color(0.2, 0.22, 0.2), 0.9)
	var ember := _mat(Color(1.0, 0.48, 0.16), 0.4, 0.0, 2.2)
	# Open-sided forge shed.
	var origin := Vector3(-11.4, 0.0, -8.4)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_mesh(root, "cylinder", origin + Vector3(2.2 * float(sx), 1.5, 1.8 * float(sz)), Vector3(0.11, 0.14, 3.0), wood)
	_mesh(root, "box", origin + Vector3(0.0, 3.05, 0.0), Vector3(5.2, 0.16, 4.4), roof)
	_mesh(root, "prism", origin + Vector3(0.0, 3.55, 0.0), Vector3(5.6, 0.9, 4.8), _mat(Color(0.16, 0.18, 0.17), 0.9))
	_mesh(root, "box", origin + Vector3(0.0, 0.35, 0.0), Vector3(4.6, 0.7, 3.4), stone)
	# Forge, hood and chimney.
	var forge := Vector3(origin.x - 1.1, 0.0, origin.z - 0.9)
	_mesh(root, "box", forge + Vector3(0.0, 0.7, 0.0), Vector3(1.8, 1.2, 1.4), stone)
	_mesh(root, "box", forge + Vector3(0.0, 1.35, 0.0), Vector3(1.0, 0.16, 0.9), ember)
	_mesh(root, "box", forge + Vector3(0.0, 2.15, 0.0), Vector3(1.3, 1.3, 0.9), stone)
	_mesh(root, "cylinder", forge + Vector3(0.0, 3.1, 0.0), Vector3(0.36, 0.44, 1.5), stone)
	var forge_light := OmniLight3D.new()
	forge_light.light_color = Color(1.0, 0.52, 0.2)
	forge_light.light_energy = 1.3
	forge_light.omni_range = 5.0
	forge_light.position = forge + Vector3(0.0, 1.1, 0.0)
	root.add_child(forge_light)
	# Anvil and weapon rack.
	_mesh(root, "box", origin + Vector3(1.6, 0.58, 1.0), Vector3(0.9, 0.2, 0.4), _mat(Color(0.2, 0.21, 0.23), 0.4, 0.75))
	_mesh(root, "box", origin + Vector3(1.6, 0.3, 1.0), Vector3(0.36, 0.56, 0.3), wood)
	_mesh(root, "box", origin + Vector3(1.7, 0.18, 0.5), Vector3(0.7, 0.36, 0.24), wood)
	for i in 3:
		var blade := _mesh(root, "box", origin + Vector3(0.6 + 0.45 * float(i), 1.5, 1.9), Vector3(0.06, 1.0, 0.14), _mat(Color(0.68, 0.7, 0.74), 0.35, 0.7))
		blade.rotation.z = 0.18 - 0.12 * float(i)
	_sign(root, "BRAN'S FORGE", origin + Vector3(0.0, 2.7, 2.25), 0.0, 58)

func _build_gate() -> void:
	var root := _group("Gate")
	var stone := _mat(Color(0.42, 0.41, 0.37), 0.98)
	var stone_dark := _mat(Color(0.32, 0.32, 0.29), 1.0)
	var wood := _mat(Color(0.28, 0.18, 0.1), 0.95)
	var metal := _mat(Color(0.24, 0.24, 0.25), 0.45, 0.7)
	for side in [-1, 1]:
		var tower := Vector3(6.2 * float(side), 0.0, GATE_Z)
		_mesh(root, "box", tower + Vector3(0.0, 2.4, 0.0), Vector3(3.2, 4.8, 3.2), stone)
		_mesh(root, "box", tower + Vector3(0.0, 0.3, 0.0), Vector3(3.6, 0.6, 3.6), stone_dark)
		for i in 3:
			_mesh(root, "box", tower + Vector3(-1.0 + 1.0 * float(i), 5.0, 1.25), Vector3(0.6, 0.5, 0.5), stone_dark)
			_mesh(root, "box", tower + Vector3(-1.0 + 1.0 * float(i), 5.0, -1.25), Vector3(0.6, 0.5, 0.5), stone_dark)
		var banner_color := Color(0.48, 0.16, 0.12) if side < 0 else Color(0.22, 0.36, 0.28)
		_mesh(root, "box", tower + Vector3(0.0, 2.5, 1.68), Vector3(0.7, 2.1, 0.08), _mat(banner_color, 0.9))
		_mesh(root, "box", tower + Vector3(0.0, 3.55, 1.7), Vector3(1.0, 0.12, 0.1), metal)
		_mesh(root, "cylinder", tower + Vector3(0.0, 4.4, 2.0), Vector3(0.08, 0.1, 1.4), wood)
		var flame := _mesh(root, "sphere", tower + Vector3(0.0, 5.2, 2.0), Vector3(0.16, 0.24, 0.16), _mat(Color(1.0, 0.62, 0.22), 0.3, 0.0, 2.0))
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.24)
		light.light_energy = 1.0
		light.omni_range = 6.0
		light.position = tower + Vector3(0.0, 5.2, 2.0)
		root.add_child(light)
		# Stone wing walls out to the edge of the map.
		_make_wall(root, Vector3(19.0 * float(side), 1.3, GATE_Z), Vector3(25.0, 2.6, 0.9), stone_dark, true)
	# Lintel and sign.
	_mesh(root, "box", Vector3(0.0, 5.0, GATE_Z), Vector3(9.6, 0.5, 0.7), stone_dark)
	_mesh(root, "box", Vector3(0.0, 5.45, GATE_Z), Vector3(5.2, 0.9, 0.24), wood)
	_sign(root, "HEARTHMERE", Vector3(0.0, 5.47, GATE_Z + 0.18), 0.0, 72)
	# Iron braziers flanking the opening.
	for side in [-1, 1]:
		var brazier := Vector3(4.6 * float(side), 0.0, GATE_Z + 1.6)
		_mesh(root, "cylinder", brazier + Vector3(0.0, 0.55, 0.0), Vector3(0.12, 0.16, 1.1), metal)
		_mesh(root, "cylinder", brazier + Vector3(0.0, 1.18, 0.0), Vector3(0.34, 0.22, 0.24), metal)
		var coal := _mesh(root, "sphere", brazier + Vector3(0.0, 1.3, 0.0), Vector3(0.18, 0.1, 0.18), _mat(Color(1.0, 0.5, 0.18), 0.4, 0.0, 2.2))
		coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.58, 0.22)
		light.light_energy = 1.1
		light.omni_range = 5.5
		light.position = brazier + Vector3(0.0, 1.5, 0.0)
		root.add_child(light)

func _build_town_dressing() -> void:
	var root := _group("TownDressing")
	# Trees ringing the town.
	for spot in [
		Vector3(-24.0, 0.0, 18.0), Vector3(-21.0, 0.0, 30.0), Vector3(-17.0, 0.0, -14.0),
		Vector3(22.0, 0.0, 22.0), Vector3(25.0, 0.0, 8.0), Vector3(19.0, 0.0, -16.0),
		Vector3(-24.0, 0.0, -22.0), Vector3(24.0, 0.0, -25.0), Vector3(-9.0, 0.0, 31.0),
		Vector3(8.0, 0.0, 32.0), Vector3(-27.0, 0.0, 2.0), Vector3(27.0, 0.0, 3.0),
	]:
		_make_tree(root, spot, _rng.randf_range(0.85, 1.25))
	# Fences along the fields beside the road.
	for side in [-1, 1]:
		for i in 8:
			var z := 27.0 - float(i) * 5.2
			_make_fence(root, Vector3(7.4 * float(side), 0.0, z), PI * 0.5)
	# A cart by the market.
	var cart := Vector3(13.2, 0.0, 8.6)
	_mesh(root, "box", cart + Vector3(0.0, 0.72, 0.0), Vector3(2.4, 0.18, 1.4), _mat(Color(0.3, 0.2, 0.11), 0.95))
	for sx in [-1, 1]:
		var wheel := _mesh(root, "cylinder", cart + Vector3(0.85 * float(sx), 0.42, 0.8), Vector3(0.42, 0.42, 0.12), _mat(Color(0.22, 0.15, 0.08), 0.95))
		wheel.rotation.x = PI * 0.5
	_mesh(root, "box", cart + Vector3(-1.1, 0.95, 0.0), Vector3(0.16, 0.6, 1.2), _mat(Color(0.26, 0.17, 0.09), 0.95))

# ---------------------------------------------------------------------------
# Thorned Field
# ---------------------------------------------------------------------------

func _build_field() -> void:
	var root := _group("ThornedField")
	var bark := _mat(Color(0.2, 0.15, 0.1), 1.0)
	var bark_light := _mat(Color(0.28, 0.21, 0.13), 1.0)
	var thorn := _mat(Color(0.28, 0.34, 0.18), 0.98)
	var stone := _mat(Color(0.3, 0.31, 0.29), 1.0)
	var moss := _mat(Color(0.23, 0.3, 0.18), 1.0)

	# Ruined arch marking the edge of the field.
	var arch := Vector3(0.0, 0.0, -35.0)
	for side in [-1, 1]:
		var pillar := _mesh(root, "box", arch + Vector3(4.0 * float(side), 1.8, 0.0), Vector3(0.9, 3.6, 0.9), stone)
		pillar.rotation.z = 0.07 * float(side)
		_mesh(root, "box", arch + Vector3(4.0 * float(side), 3.75, 0.0), Vector3(1.3, 0.3, 1.2), moss)
	_mesh(root, "box", arch + Vector3(0.0, 3.4, 0.0), Vector3(8.2, 0.7, 0.8), stone).rotation.z = 0.04
	_mesh(root, "prism", arch + Vector3(1.6, 3.9, 0.0), Vector3(1.0, 0.8, 0.6), stone).rotation.z = -0.2

	# Standing stones and dead trees.
	for spot in [
		Vector3(-18.0, 0.0, -40.0), Vector3(20.0, 0.0, -38.0), Vector3(-24.0, 0.0, -58.0),
		Vector3(23.0, 0.0, -55.0), Vector3(-20.0, 0.0, -82.0), Vector3(19.0, 0.0, -84.0),
		Vector3(-24.0, 0.0, -96.0), Vector3(24.0, 0.0, -100.0),
	]:
		_dead_tree(root, spot, _rng.randf_range(0.9, 1.4), bark, bark_light, thorn)
	for i in 26:
		var x := _rng.randf_range(-27.0, 27.0)
		var z := _rng.randf_range(-106.0, -34.0)
		if _near_field_path(x, z):
			continue
		_bramble(root, Vector3(x, 0.0, z), _rng.randf_range(0.7, 1.5), bark, thorn, moss)
	for i in 18:
		var x := _rng.randf_range(-27.0, 27.0)
		var z := _rng.randf_range(-106.0, -34.0)
		if _near_field_path(x, z):
			continue
		_rock(root, Vector3(x, 0.0, z), _rng.randf_range(0.5, 1.6), stone)
	for i in 10:
		var x := _rng.randf_range(-27.0, 27.0)
		var z := _rng.randf_range(-106.0, -36.0)
		if _near_field_path(x, z):
			continue
		_tuft(root, Vector3(x, 0.0, z), _rng.randf_range(0.8, 1.6))

	# The shrine clearing: a ring of leaning stones.
	for i in 7:
		var angle := float(i) * TAU / 7.0
		var spot := SHRINE_POSITION + Vector3(cos(angle) * 6.2, 0.0, sin(angle) * 6.2)
		var monolith := _mesh(root, "prism", spot + Vector3(0.0, 1.15, 0.0), Vector3(0.5, 2.3, 0.4), stone)
		monolith.rotation.y = -angle
		monolith.rotation.z = cos(angle) * 0.12
		_mesh(root, "sphere", spot + Vector3(0.0, 2.35, 0.0), Vector3(0.16, 0.16, 0.16), moss)

	# The Warden's clearing, ringed with huge thorns.
	var arena := Vector3(0.0, 0.0, -96.0)
	for i in 10:
		var angle := float(i) * TAU / 10.0
		var spot := arena + Vector3(cos(angle) * 9.5, 0.0, sin(angle) * 9.5)
		var spike := _mesh(root, "prism", spot + Vector3(0.0, 1.6, 0.0), Vector3(0.55, 3.2, 0.5), thorn)
		spike.rotation.y = -angle
		spike.rotation.z = cos(angle) * 0.25
		spike.rotation.x = sin(angle) * 0.25
	_mesh(root, "cylinder", arena + Vector3(0.0, 0.03, 0.0), Vector3(9.0, 10.0, 0.06), _mat(Color(0.2, 0.16, 0.12), 1.0))
	for i in 12:
		var angle := float(i) * TAU / 12.0 + 0.3
		_mesh(root, "sphere", arena + Vector3(cos(angle) * 8.2, 0.9, sin(angle) * 8.2), Vector3(0.3, 0.4, 0.3), _mat(Color(0.36, 0.42, 0.22), 0.95))

	# A broken wagon swallowed by briars, a little storytelling.
	var wreck := Vector3(-14.0, 0.0, -62.0)
	_mesh(root, "box", wreck + Vector3(0.0, 0.65, 0.0), Vector3(2.4, 0.16, 1.4), bark).rotation.z = 0.18
	_mesh(root, "cylinder", wreck + Vector3(0.7, 0.45, 0.7), Vector3(0.4, 0.4, 0.1), bark_light).rotation.x = PI * 0.5
	_bramble(root, wreck + Vector3(1.2, 0.0, -0.6), 1.2, bark, thorn, moss)

func _near_field_path(x: float, z: float) -> bool:
	if z > -88.0 and absf(x - (z + 30.0) * 0.136) < 4.8:
		return true
	if Vector2(x - SHRINE_POSITION.x, z - SHRINE_POSITION.z).length() < 8.5:
		return true
	if Vector2(x, z + 96.0).length() < 11.0:
		return true
	return false

func _dead_tree(parent: Node3D, position: Vector3, scale: float, bark: StandardMaterial3D, bark_light: StandardMaterial3D, thorn: StandardMaterial3D) -> void:
	var trunk := _mesh(parent, "cylinder", position + Vector3(0.0, 1.3 * scale, 0.0), Vector3(0.12 * scale, 0.26 * scale, 2.6 * scale), bark)
	trunk.rotation.z = _rng.randf_range(-0.1, 0.1)
	for i in 4:
		var angle := float(i) * TAU / 4.0 + _rng.randf_range(-0.4, 0.4)
		var height := (1.2 + 0.35 * float(i)) * scale
		var branch := _mesh(parent, "cylinder", position + Vector3(cos(angle) * 0.55 * scale, height, sin(angle) * 0.55 * scale), Vector3(0.04 * scale, 0.08 * scale, 1.4 * scale), bark_light)
		branch.rotation.z = 0.9 * cos(angle)
		branch.rotation.x = -0.9 * sin(angle)
		var twig := _mesh(parent, "prism", position + Vector3(cos(angle) * 1.1 * scale, height + 0.35 * scale, sin(angle) * 1.1 * scale), Vector3(0.16 * scale, 0.5 * scale, 0.12 * scale), thorn)
		twig.rotation.z = 0.7 * cos(angle)

func _bramble(parent: Node3D, position: Vector3, scale: float, bark: StandardMaterial3D, thorn: StandardMaterial3D, moss: StandardMaterial3D) -> void:
	for i in 4:
		var angle := float(i) * TAU / 4.0 + _rng.randf_range(-0.5, 0.5)
		var stem := _mesh(parent, "cylinder", position + Vector3(cos(angle) * 0.3 * scale, 0.35 * scale, sin(angle) * 0.3 * scale), Vector3(0.05 * scale, 0.08 * scale, 0.9 * scale), bark)
		stem.rotation.z = cos(angle) * 0.55
		stem.rotation.x = sin(angle) * 0.55
		var spike := _mesh(parent, "prism", position + Vector3(cos(angle) * 0.65 * scale, 0.7 * scale, sin(angle) * 0.65 * scale), Vector3(0.16 * scale, 0.4 * scale, 0.12 * scale), thorn)
		spike.rotation.z = cos(angle) * 0.6
		spike.rotation.x = 0.3 * sin(angle)
	var clump := _mesh(parent, "sphere", position + Vector3(0.0, 0.32 * scale, 0.0), Vector3(0.4 * scale, 0.3 * scale, 0.4 * scale), moss)
	clump.scale = Vector3(1.2, 0.7, 1.1)

func _rock(parent: Node3D, position: Vector3, scale: float, material: StandardMaterial3D) -> void:
	var rock := _mesh(parent, "sphere", position + Vector3(0.0, 0.35 * scale, 0.0), Vector3(0.65 * scale, 0.45 * scale, 0.55 * scale), material)
	rock.rotation.y = _rng.randf() * TAU
	rock.scale = Vector3(1.0, 0.7, 0.9)

# ---------------------------------------------------------------------------
# Boundaries
# ---------------------------------------------------------------------------

func _build_boundaries() -> void:
	var root := _group("Boundaries")
	var hidden := _mat(Color(0.2, 0.2, 0.2), 1.0)
	_make_wall(root, Vector3(-31.0, 2.5, -35.0), Vector3(1.0, 5.0, 150.0), hidden, false)
	_make_wall(root, Vector3(31.0, 2.5, -35.0), Vector3(1.0, 5.0, 150.0), hidden, false)
	_make_wall(root, Vector3(0.0, 2.5, 41.0), Vector3(62.0, 5.0, 1.0), hidden, false)
	_make_wall(root, Vector3(0.0, 2.5, -111.0), Vector3(62.0, 5.0, 1.0), hidden, false)

# ---------------------------------------------------------------------------
# Shared props
# ---------------------------------------------------------------------------

func _make_house(parent: Node3D, position: Vector3, size: Vector3, wall_color: Color, roof_color: Color, yaw: float, label_text: String, trim_color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = position
	pivot.rotation.y = yaw
	parent.add_child(pivot)

	var stone := _mat(Color(0.35, 0.34, 0.31), 0.98)
	var wood := _mat(Color(0.24, 0.16, 0.09), 0.95)
	var wall_mat := _mat(wall_color, 0.96)
	var roof_mat := _mat(roof_color, 0.92)
	var trim := _mat(trim_color, 0.7, 0.1)
	var glow := _mat(Color(1.0, 0.74, 0.36), 0.4, 0.0, 1.5)

	_mesh(pivot, "box", Vector3(0.0, 0.15, 0.0), Vector3(size.x + 0.6, 0.3, size.z + 0.6), stone)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	pivot.add_child(body)
	_mesh(body, "box", Vector3(0.0, size.y * 0.5 + 0.1, 0.0), size, wall_mat)
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, size.y * 0.5 + 0.1, 0.0)
	body.add_child(collision)

	var roof_height := maxf(1.1, size.x * 0.26)
	_mesh(pivot, "prism", Vector3(0.0, size.y + 0.1 + roof_height * 0.5, 0.0), Vector3(size.x + 1.2, roof_height, size.z + 1.2), roof_mat)
	_mesh(pivot, "box", Vector3(0.0, size.y + 0.12 + roof_height, 0.0), Vector3(size.x + 0.5, 0.12, 0.22), roof_mat)
	# Door, frame and steps face local +Z.
	_mesh(pivot, "box", Vector3(0.0, 1.05, size.z * 0.5 + 0.05), Vector3(1.15, 2.1, 0.16), wood)
	_mesh(pivot, "box", Vector3(0.0, 2.18, size.z * 0.5 + 0.04), Vector3(1.55, 0.18, 0.22), trim)
	_mesh(pivot, "box", Vector3(0.0, 0.15, size.z * 0.5 + 0.6), Vector3(1.8, 0.3, 0.9), stone)
	for sx in [-1, 1]:
		_mesh(pivot, "box", Vector3(0.62 * float(sx), 1.05, size.z * 0.5 + 0.06), Vector3(0.12, 2.1, 0.12), trim)
	# Windows to either side of the door.
	for sx in [-1, 1]:
		_mesh(pivot, "box", Vector3(size.x * 0.28 * float(sx), size.y * 0.62, size.z * 0.5 + 0.06), Vector3(0.95, 0.9, 0.1), glow)
		_mesh(pivot, "box", Vector3(size.x * 0.28 * float(sx), size.y * 0.62, size.z * 0.5 + 0.12), Vector3(1.05, 0.08, 0.08), wood)
		_mesh(pivot, "box", Vector3(size.x * 0.28 * float(sx), size.y * 0.62, size.z * 0.5 + 0.12), Vector3(0.08, 1.0, 0.08), wood)
	# Corner timbers.
	for sx in [-1, 1]:
		_mesh(pivot, "box", Vector3(size.x * 0.47 * float(sx), size.y * 0.5 + 0.1, size.z * 0.5 + 0.03), Vector3(0.16, size.y, 0.12), trim)
	_mesh(pivot, "box", Vector3(0.0, size.y * 0.94, size.z * 0.5 + 0.03), Vector3(size.x, 0.16, 0.12), trim)
	# Chimney and its smoke-stained cap.
	var chimney_x := size.x * 0.28
	_mesh(pivot, "box", Vector3(chimney_x, size.y + roof_height * 0.95, -0.4), Vector3(0.62, 1.4, 0.62), stone)
	_mesh(pivot, "box", Vector3(chimney_x, size.y + roof_height * 1.65, -0.4), Vector3(0.74, 0.16, 0.74), wood)
	if not label_text.is_empty():
		_sign(pivot, label_text, Vector3(0.0, minf(size.y + 0.4, 3.0), size.z * 0.5 + 0.22), 0.0, 58)
	return pivot

func _make_stall(parent: Node3D, position: Vector3, yaw: float, cloth_color: Color, label_text: String) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = position
	pivot.rotation.y = yaw
	parent.add_child(pivot)
	var wood := _mat(Color(0.33, 0.22, 0.12), 0.95)
	var cloth := _mat(cloth_color, 0.92)
	var cloth_light := _mat(cloth_color.lightened(0.16), 0.92)
	var trim := _mat(Color(0.66, 0.52, 0.27), 0.7)

	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_mesh(pivot, "cylinder", Vector3(1.55 * float(sx), 1.3, 0.9 * float(sz)), Vector3(0.07, 0.09, 2.6), wood)
	# Counter with a collision body so the stall feels solid.
	var counter := StaticBody3D.new()
	counter.collision_layer = 1
	counter.collision_mask = 1
	pivot.add_child(counter)
	_mesh(counter, "box", Vector3(0.0, 0.62, 0.55), Vector3(3.2, 1.05, 1.5), wood)
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 1.05, 1.5)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 0.62, 0.55)
	counter.add_child(collision)
	_mesh(pivot, "box", Vector3(0.0, 1.18, 0.55), Vector3(3.4, 0.1, 1.7), cloth_light)
	# Striped awning.
	_mesh(pivot, "box", Vector3(0.0, 2.48, 0.0), Vector3(3.9, 0.09, 2.5), cloth)
	var trim_strip := _mesh(pivot, "box", Vector3(0.0, 2.4, -1.2), Vector3(3.9, 0.3, 0.08), trim)
	trim_strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 4:
		_mesh(pivot, "box", Vector3(-1.45 + 0.97 * float(i), 2.4, 1.24), Vector3(0.12, 0.3, 0.06), cloth_light)
	for i in 3:
		_mesh(pivot, "box", Vector3(-0.7 + 0.7 * float(i), 2.1, 1.18), Vector3(0.5, 0.5, 0.05), cloth_light)
	_sign(pivot, label_text, Vector3(0.0, 2.95, 0.05), 0.0, 50)
	return pivot

func _make_lamp(parent: Node3D, position: Vector3) -> void:
	var wood := _mat(Color(0.24, 0.17, 0.1), 0.95)
	var iron := _mat(Color(0.2, 0.2, 0.2), 0.5, 0.6)
	var glow := _mat(Color(1.0, 0.72, 0.36), 0.35, 0.0, 1.8)
	_mesh(parent, "cylinder", position + Vector3(0.0, 1.55, 0.0), Vector3(0.07, 0.1, 3.1), wood)
	_mesh(parent, "box", position + Vector3(0.0, 3.08, 0.0), Vector3(0.9, 0.1, 0.1), iron)
	var lantern := _mesh(parent, "box", position + Vector3(0.38, 2.86, 0.0), Vector3(0.28, 0.38, 0.28), glow)
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh(parent, "prism", position + Vector3(0.38, 3.12, 0.0), Vector3(0.36, 0.22, 0.36), iron)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.36)
	light.light_energy = 0.85
	light.omni_range = 6.0
	light.position = position + Vector3(0.38, 2.8, 0.0)
	parent.add_child(light)
	_mesh(parent, "cylinder", position + Vector3(0.0, 0.08, 0.0), Vector3(0.3, 0.36, 0.16), iron)

func _make_bench(parent: Node3D, position: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	pivot.rotation.y = yaw
	parent.add_child(pivot)
	var wood := _mat(Color(0.34, 0.22, 0.12), 0.95)
	for sx in [-1, 1]:
		_mesh(pivot, "box", Vector3(0.65 * float(sx), 0.25, 0.0), Vector3(0.16, 0.5, 0.5), wood)
	_mesh(pivot, "box", Vector3(0.0, 0.55, 0.0), Vector3(1.7, 0.12, 0.55), wood)
	_mesh(pivot, "box", Vector3(0.0, 0.92, 0.22), Vector3(1.7, 0.5, 0.1), wood)

func _make_notice_board(parent: Node3D, position: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	pivot.rotation.y = yaw
	parent.add_child(pivot)
	var wood := _mat(Color(0.28, 0.18, 0.1), 0.95)
	var paper := _mat(Color(0.85, 0.8, 0.66), 0.95)
	for sx in [-1, 1]:
		_mesh(pivot, "cylinder", Vector3(0.75 * float(sx), 1.25, 0.0), Vector3(0.07, 0.09, 2.5), wood)
	_mesh(pivot, "box", Vector3(0.0, 1.6, 0.0), Vector3(1.9, 1.2, 0.12), wood)
	for i in 3:
		_mesh(pivot, "box", Vector3(-0.5 + 0.5 * float(i), 1.72, 0.08), Vector3(0.36, 0.5, 0.02), paper)

func _make_fence(parent: Node3D, position: Vector3, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	pivot.rotation.y = yaw
	parent.add_child(pivot)
	var wood := _mat(Color(0.33, 0.23, 0.12), 0.98)
	_mesh(pivot, "box", Vector3(-3.0, 0.55, 0.0), Vector3(0.14, 1.1, 0.14), wood)
	_mesh(pivot, "box", Vector3(3.0, 0.55, 0.0), Vector3(0.14, 1.1, 0.14), wood)
	_mesh(pivot, "box", Vector3(0.0, 0.85, 0.0), Vector3(6.0, 0.1, 0.08), wood)
	_mesh(pivot, "box", Vector3(0.0, 0.5, 0.0), Vector3(6.0, 0.1, 0.08), wood)

func _make_wall(parent: Node3D, center: Vector3, size: Vector3, material: StandardMaterial3D, visible_mesh: bool) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	parent.add_child(body)
	if visible_mesh:
		_mesh(body, "box", center, size, material)
		# A mossy cap makes the town wall read as old stone.
		_mesh(body, "box", center + Vector3(0.0, size.y * 0.5 + 0.08, 0.0), Vector3(size.x, 0.16, size.z + 0.2), _mat(Color(0.27, 0.33, 0.2), 1.0))
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = center
	body.add_child(collision)

func _make_tree(parent: Node3D, position: Vector3, scale: float) -> void:
	var tree := TREE.instantiate() as Node3D
	tree.position = position
	tree.rotation.y = _rng.randf() * TAU
	tree.scale = Vector3(scale, scale * _rng.randf_range(0.92, 1.12), scale)
	parent.add_child(tree)

func _barrel(parent: Node3D, position: Vector3, scale: float) -> void:
	var wood := _mat(Color(0.35, 0.23, 0.12), 0.95)
	var hoop := _mat(Color(0.3, 0.31, 0.32), 0.5, 0.5)
	var barrel := _mesh(parent, "cylinder", position + Vector3(0.0, 0.5 * scale, 0.0), Vector3(0.32 * scale, 0.28 * scale, 1.0 * scale), wood)
	barrel.scale = Vector3(1.0, 1.0, 0.92)
	for y in [0.2, 0.5, 0.8]:
		var ring := _mesh(parent, "cylinder", position + Vector3(0.0, y * scale, 0.0), Vector3(0.325 * scale, 0.325 * scale, 0.06), hoop)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _crate(parent: Node3D, position: Vector3, scale: float, yaw: float) -> void:
	var wood := _mat(Color(0.42, 0.3, 0.16), 0.95)
	var trim := _mat(Color(0.28, 0.19, 0.1), 0.98)
	var crate := _mesh(parent, "box", position + Vector3(0.0, 0.32 * scale, 0.0), Vector3(0.64 * scale, 0.64 * scale, 0.64 * scale), wood)
	crate.rotation.y = yaw
	_mesh(parent, "box", position + Vector3(0.0, 0.65 * scale, 0.0), Vector3(0.68 * scale, 0.05, 0.68 * scale), trim).rotation.y = yaw

func _hay(parent: Node3D, position: Vector3, scale: float) -> void:
	var straw := _mat(Color(0.7, 0.58, 0.3), 1.0)
	var bale := _mesh(parent, "cylinder", position + Vector3(0.0, 0.3 * scale, 0.0), Vector3(0.55 * scale, 0.55 * scale, 0.8 * scale), straw)
	bale.rotation.z = PI * 0.5
	bale.rotation.y = _rng.randf() * TAU
	_mesh(parent, "box", position + Vector3(0.0, 0.62 * scale, 0.0), Vector3(0.4, 0.04, 1.4 * scale), straw).rotation.y = bale.rotation.y

func _sign(parent: Node3D, text: String, position: Vector3, yaw: float, font_size := 58) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0042
	label.outline_size = 18
	label.outline_modulate = Color(0.06, 0.04, 0.02, 1.0)
	label.modulate = Color(0.92, 0.82, 0.58, 1.0)
	label.position = position
	label.rotation.y = yaw
	label.no_depth_test = false
	parent.add_child(label)
	return label

func _group(group_name: String) -> Node3D:
	var node := Node3D.new()
	node.name = group_name
	add_child(node)
	return node

func _mesh(parent: Node3D, shape: String, position: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh: PrimitiveMesh
	match shape:
		"box":
			var box := BoxMesh.new()
			box.size = size
			mesh = box
		"cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = size.x
			cylinder.bottom_radius = size.y
			cylinder.height = size.z
			cylinder.radial_segments = 10
			cylinder.rings = 2
			mesh = cylinder
		"prism":
			var prism := PrismMesh.new()
			prism.size = size
			mesh = prism
		_:
			var sphere := SphereMesh.new()
			sphere.radius = size.x
			sphere.height = size.y * 2.0
			sphere.radial_segments = 10
			sphere.rings = 5
			mesh = sphere
	mesh.material = material
	node.mesh = mesh
	node.position = position
	parent.add_child(node)
	return node

func _mat(color: Color, roughness: float, metallic := 0.0, emission := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), roughness, metallic, emission]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = material
	return material
