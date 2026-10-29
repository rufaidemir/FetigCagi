extends RefCounted
## Düşük poligonlu, kodla üretilen yer tutucu modeller (kale, kule, asker, tank, gemi, tarla).
## Gerçek 3B modeller (glb) hazır olunca bu dosya, onları yükleyen fabrikaya dönüşür.

const STONE := Color("b8b2a4")
const DARK := Color("2b2f3a")
const SKIN := Color("f2d2b0")


static func _mat(color: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func _add(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _add(parent, bm, color, pos, rot_deg)


static func _cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, color: Color, segs: int = 12, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	return _add(parent, cm, color, pos, rot_deg)


# ---------------------------------------------------------------- çağa ve mimariye göre yapılar
# Çağ katmanı (tier): 0 ahşap/saman, 1 taş, 2 sanayi (beton, düz çatı), 3+ modern (cam ve çelik).
# Mimari (style): "west" kiremit/koni çatı, "east" pagoda, "mideast" kubbe, "meso" basamaklı piramit.

static func tier_of(era: int) -> int:
	return clampi(era, 0, 3)


static func _wall_color(tier: int) -> Color:
	match tier:
		0: return Color("8a6a42")
		1: return STONE
		2: return Color("9aa3ad")
	return Color("86b4d6")


## Çatı: mimari stiline göre; sanayi ve sonrası düz çatı.
static func _roof(parent: Node3D, style: String, tier: int, color: Color, pos: Vector3, r: float) -> void:
	if tier >= 2:
		_box(parent, Vector3(r * 2.1, 0.5, r * 2.1), pos + Vector3(0, 0.25, 0), Color("6b7280"))
		_cyl(parent, 0.25, 0.25, 1.6, pos + Vector3(r * 0.5, 1.0, r * 0.4), DARK, 6)
		return
	var roof_col := Color("c9a95a") if tier == 0 else color
	match style:
		"east":
			_cyl(parent, 0.0, r * 1.3, 1.1, pos + Vector3(0, 1.9, 0), roof_col)
			_cyl(parent, r * 1.1, r * 1.9, 0.3, pos + Vector3(0, 1.1, 0), roof_col.darkened(0.15))
			_cyl(parent, r * 0.9, r * 1.5, 0.3, pos + Vector3(0, 0.5, 0), roof_col.darkened(0.25))
		"mideast":
			var sm := SphereMesh.new()
			sm.radius = r * 1.3
			sm.height = r * 2.0
			sm.is_hemisphere = true
			_add(parent, sm, roof_col, pos + Vector3(0, 0.3, 0))
			_cyl(parent, 0.05, 0.05, 1.2, pos + Vector3(0, r * 1.3 + 0.9, 0), Color("e0b04a"), 6)
		"meso":
			for i in range(3):
				var s := r * (2.3 - i * 0.7)
				_box(parent, Vector3(s, 0.7, s), pos + Vector3(0, 0.35 + i * 0.7, 0), roof_col.darkened(0.08 * i))
		_:
			_cyl(parent, 0.0, r * 1.45, 2.0, pos + Vector3(0, 1.0, 0), roof_col)


static func castle(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := Node3D.new()
	n.name = "Castle"
	var tier := tier_of(era)
	var wall := _wall_color(tier)
	_box(n, Vector3(11.5, 1.5, 11.5), Vector3(0, -0.2, 0), wall.darkened(0.25))
	var wh := 3.0 if tier < 3 else 5.0
	for z in [-4.5, 4.5]:
		_box(n, Vector3(10, wh, 1), Vector3(0, wh * 0.5, z), wall)
	for x in [-4.5, 4.5]:
		_box(n, Vector3(1, wh, 10), Vector3(x, wh * 0.5, 0), wall)
	var th := 5.5 if tier < 3 else 8.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			if tier >= 3:
				_box(n, Vector3(2.4, th, 2.4), Vector3(sx * 4.5, th * 0.5, sz * 4.5), wall)
			else:
				_cyl(n, 1.3, 1.4, th, Vector3(sx * 4.5, th * 0.5, sz * 4.5), wall)
			_roof(n, style, tier, team, Vector3(sx * 4.5, th, sz * 4.5), 1.3)
	var kh := 7.0 if tier < 3 else 12.0
	_box(n, Vector3(4, kh, 4), Vector3(0, kh * 0.5, 0), wall.lightened(0.08))
	_roof(n, style, tier, team, Vector3(0, kh, 0), 2.0)
	var top := kh + (2.6 if tier < 2 else 0.8)
	_cyl(n, 0.07, 0.07, 2.6, Vector3(0, top + 1.3, 0), DARK, 6)
	_box(n, Vector3(1.3, 0.7, 0.06), Vector3(0.7, top + 2.0, 0), team)
	if tier >= 2:
		_cyl(n, 0.5, 0.6, 5.0, Vector3(-3.0, kh + 2.5, 2.0), Color("5a6270"), 8)  # baca
	_box(n, Vector3(1.8, 2.2, 0.25), Vector3(0, 1.1, 4.55), DARK)
	return n


static func tower(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := Node3D.new()
	n.name = "Tower"
	var tier := tier_of(era)
	var wall := _wall_color(tier)
	var h := 6.0 if tier < 3 else 9.0
	if tier >= 3:
		_box(n, Vector3(2.4, h, 2.4), Vector3(0, h * 0.5, 0), wall)
	else:
		_cyl(n, 1.0, 1.25, h, Vector3(0, h * 0.5, 0), wall)
	_cyl(n, 1.5, 1.5, 0.7, Vector3(0, h + 0.3, 0), wall.lightened(0.05))
	_roof(n, style, tier, team, Vector3(0, h + 0.65, 0), 1.2)
	_box(n, Vector3(0.25, 0.9, 0.2), Vector3(0, 4.0, 1.12), DARK)
	return n


static func house(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := Node3D.new()
	n.name = "House"
	var tier := tier_of(era)
	_box(n, Vector3(4.2, 2.6 if tier < 3 else 5.0, 3.6), Vector3(0, (1.3 if tier < 3 else 2.5), 0), _wall_color(tier))
	_roof(n, style, tier, team, Vector3(0, 2.6 if tier < 3 else 5.0, 0), 1.7)
	_box(n, Vector3(0.9, 1.4, 0.2), Vector3(0, 0.7, 1.85), DARK)
	return n


static func _hall(team: Color, era: int, style: String, label_col: Color, w: float, d: float) -> Node3D:
	var n := Node3D.new()
	var tier := tier_of(era)
	var h := 3.2 if tier < 3 else 6.0
	_box(n, Vector3(w, h, d), Vector3(0, h * 0.5, 0), _wall_color(tier))
	_roof(n, style, tier, team, Vector3(0, h, 0), minf(w, d) * 0.45)
	_box(n, Vector3(w * 0.3, 2.0, 0.2), Vector3(0, 1.0, d * 0.5 + 0.05), DARK)
	_box(n, Vector3(w * 0.5, 0.5, 0.15), Vector3(0, h - 0.5, d * 0.5 + 0.1), label_col)
	return n


static func barracks(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := _hall(team, era, style, team, 8.0, 5.0)
	n.name = "Barracks"
	return n


static func stable(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := _hall(team, era, style, Color("8a5a3a"), 9.0, 5.0)
	n.name = "Stable"
	_box(n, Vector3(2.5, 1.0, 0.3), Vector3(-2.5, 0.5, 3.0), Color("6b4a2b"))
	return n


static func siege_factory(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := _hall(team, era, style, Color("2b2f3a"), 9.0, 6.0)
	n.name = "SiegeFactory"
	_cyl(n, 0.3, 0.3, 4.5, Vector3(3.5, 4.0, 0), DARK, 8, Vector3(0, 0, 55))
	return n


static func dock(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := _hall(team, era, style, Color("3a6aa0"), 6.0, 5.0)
	n.name = "Dock"
	_box(n, Vector3(2.0, 0.3, 9.0), Vector3(0, 0.2, 7.0), Color("7a5a38"))
	for z in [4.0, 7.0, 10.0]:
		_cyl(n, 0.2, 0.2, 1.4, Vector3(1.1, 0.3, z), Color("5a3d24"), 6)
		_cyl(n, 0.2, 0.2, 1.4, Vector3(-1.1, 0.3, z), Color("5a3d24"), 6)
	return n


static func lookout(team: Color, era: int = 1, style: String = "west") -> Node3D:
	var n := Node3D.new()
	n.name = "Lookout"
	var wood := Color("7a5a38") if tier_of(era) < 2 else Color("6b7280")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_cyl(n, 0.18, 0.28, 9.0, Vector3(sx * 0.9, 4.5, sz * 0.9), wood, 6, Vector3(-sz * 4, 0, sx * 4))
	_box(n, Vector3(2.8, 0.3, 2.8), Vector3(0, 9.0, 0), wood)
	_box(n, Vector3(2.4, 1.0, 2.4), Vector3(0, 9.8, 0), wood.lightened(0.1))
	_box(n, Vector3(0.9, 0.5, 0.05), Vector3(0, 10.8, 0), team)
	return n


## Birimlerin çağ görünümü: tahta parçalar çelikleşir, metal parçalar parlar.
static func apply_era(node: Node3D, era: int) -> void:
	for c in node.get_children():
		if c is Node3D:
			apply_era(c as Node3D, era)
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var m := mi.material_override as StandardMaterial3D
			if m == null:
				continue
			if mi.has_meta("metal"):
				var base: Color = mi.get_meta("metal_base", m.albedo_color)
				mi.set_meta("metal_base", base)
				m.albedo_color = base.lerp(Color("dfe6ef"), clampf(0.25 * float(era), 0.0, 0.8))
				m.metallic = clampf(0.25 * float(era), 0.0, 0.8)
				m.roughness = 0.5
			elif mi.has_meta("wood"):
				var wb: Color = mi.get_meta("wood_base", m.albedo_color)
				mi.set_meta("wood_base", wb)
				m.albedo_color = wb if era < 1 else wb.lerp(Color("b9c2cf"), clampf(0.5 * float(era), 0.0, 0.9))
				m.metallic = 0.0 if era < 1 else 0.6


static func soldier(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Soldier"
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 1.0
	_add(n, cap, team, Vector3(0, 0.5, 0))
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	_add(n, head, SKIN, Vector3(0, 1.15, 0))
	var helmet := SphereMesh.new()
	helmet.radius = 0.23
	helmet.height = 0.23
	helmet.is_hemisphere = true
	_add(n, helmet, Color("5a6272"), Vector3(0, 1.22, 0))
	_box(n, Vector3(0.08, 0.5, 0.4), Vector3(-0.32, 0.55, 0), Color("e8ecfa"))
	_cyl(n, 0.02, 0.02, 1.6, Vector3(0.3, 0.8, 0), Color("c9ced8"), 6)
	n.scale = Vector3.ONE * 1.6
	return n


# ---------------------------------------------------------------- bitki örgüleri (MultiMesh için tek mesh)

## Birden çok ilkel şekli, vertex renkleriyle tek ArrayMesh'te birleştirir.
## Parça: {"mesh": Mesh, "xf": Transform3D, "color": Color, "sway": float (rüzgâr ağırlığı, alfa kanalı)}.
static func merged(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in parts:
		var m: Mesh = p["mesh"]
		var xf: Transform3D = p["xf"]
		var c: Color = p["color"]
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base := verts.size()
		for i in range(v.size()):
			verts.append(xf * v[i])
			norms.append((xf.basis * n[i]).normalized())
			cols.append(Color(c.r, c.g, c.b, float(p["sway"])))
		for i in ind:
			idx.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func _cyl_mesh(r_top: float, r_bot: float, h: float, segs: int) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return cm


static func _sph_mesh(r: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	return sm


## Çam: gövde + üst üste dört koni.
static func pine_mesh() -> ArrayMesh:
	var parts: Array = []
	parts.append({"mesh": _cyl_mesh(0.22, 0.32, 1.8, 6), "xf": Transform3D(Basis(), Vector3(0, 0.9, 0)),
		"color": Color("5a3d24"), "sway": 0.0})
	for i in range(4):
		var r := 2.0 - i * 0.38
		var c := Color("1d5a33").lerp(Color("3a8a4c"), float(i) / 3.0)
		parts.append({"mesh": _cyl_mesh(0.0, r, 2.4, 8), "xf": Transform3D(Basis(), Vector3(0, 2.3 + i * 1.1, 0)),
			"color": c, "sway": 0.25 + 0.2 * i})
	return merged(parts)


## Geniş yapraklı ağaç: gövde + üç küre taç.
static func broad_mesh() -> ArrayMesh:
	var parts: Array = []
	parts.append({"mesh": _cyl_mesh(0.25, 0.38, 2.4, 6), "xf": Transform3D(Basis(), Vector3(0, 1.2, 0)),
		"color": Color("6b4a2b"), "sway": 0.0})
	parts.append({"mesh": _sph_mesh(1.7), "xf": Transform3D(Basis(), Vector3(0, 3.7, 0)),
		"color": Color("3f8a3a"), "sway": 0.5})
	parts.append({"mesh": _sph_mesh(1.25), "xf": Transform3D(Basis(), Vector3(1.1, 3.2, 0.5)),
		"color": Color("4d9a42"), "sway": 0.6})
	parts.append({"mesh": _sph_mesh(1.2), "xf": Transform3D(Basis(), Vector3(-1.0, 3.4, -0.6)),
		"color": Color("377a35"), "sway": 0.6})
	return merged(parts)


## Çimen tutamı: üç ince üçgen yaprak (60° arayla), tabanı koyu ucu açık.
static func grass_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	# Zeminle uyumlu, kısa ve dolgun yapraklar (koyu sivri çizgiler yerine yumuşak bir tutam)
	for b in range(5):
		var basis := Basis(Vector3.UP, deg_to_rad(36.0 * b))
		var h := 0.38 + 0.08 * float(b % 3)
		verts.append(basis * Vector3(-0.13, 0.0, 0.0))
		verts.append(basis * Vector3(0.13, 0.0, 0.0))
		verts.append(basis * Vector3(0.06, h, 0.06))
		for i in range(3):
			norms.append(Vector3.UP)
		cols.append(Color(0.34, 0.56, 0.26, 0.0))
		cols.append(Color(0.34, 0.56, 0.26, 0.0))
		cols.append(Color(0.58, 0.80, 0.36, 1.0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out


static func spearman(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Spearman"
	for x in [-0.12, 0.12]:
		_cyl(n, 0.08, 0.09, 0.5, Vector3(x, 0.25, 0), DARK, 6)
	var cap := CapsuleMesh.new()
	cap.radius = 0.27
	cap.height = 0.9
	_add(n, cap, team, Vector3(0, 0.78, 0))
	_box(n, Vector3(0.58, 0.1, 0.4), Vector3(0, 0.62, 0), Color("5b3a1e"))
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	_add(n, head, SKIN, Vector3(0, 1.4, 0))
	var helmet := SphereMesh.new()
	helmet.radius = 0.23
	helmet.height = 0.23
	helmet.is_hemisphere = true
	_add(n, helmet, Color("9aa3b2"), Vector3(0, 1.45, 0)).set_meta("metal", true)
	_box(n, Vector3(0.06, 0.22, 0.3), Vector3(0, 1.7, 0), team.lightened(0.15))
	# Yuvarlak kalkan (sol), mızrak (sağ)
	_cyl(n, 0.36, 0.36, 0.07, Vector3(-0.36, 0.85, 0.05), team.darkened(0.1), 14, Vector3(0, 0, 90))
	var boss := SphereMesh.new()
	boss.radius = 0.1
	boss.height = 0.2
	_add(n, boss, Color("e8ecfa"), Vector3(-0.42, 0.85, 0.05)).set_meta("metal", true)
	_cyl(n, 0.025, 0.025, 2.1, Vector3(0.34, 1.05, 0.1), Color("7a4f2a"), 6, Vector3(0, 0, -6)).set_meta("wood", true)
	_cyl(n, 0.0, 0.07, 0.3, Vector3(0.18, 2.17, 0.1), Color("dfe6ee"), 6, Vector3(0, 0, -6)).set_meta("metal", true)
	n.scale = Vector3.ONE * 1.25
	return n


static func archer(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Archer"
	for x in [-0.12, 0.12]:
		_cyl(n, 0.08, 0.09, 0.5, Vector3(x, 0.25, 0), DARK, 6)
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 0.9
	_add(n, cap, Color("5b7a3a"), Vector3(0, 0.78, 0))
	_box(n, Vector3(0.52, 0.7, 0.06), Vector3(0, 0.85, -0.22), team.darkened(0.25))
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	_add(n, head, SKIN, Vector3(0, 1.4, 0))
	var hood := SphereMesh.new()
	hood.radius = 0.24
	hood.height = 0.24
	hood.is_hemisphere = true
	_add(n, hood, team.darkened(0.15), Vector3(0, 1.44, -0.02))
	# Yay: sap ve iki kol, kiriş
	_box(n, Vector3(0.05, 0.4, 0.05), Vector3(-0.4, 0.95, 0.3), Color("7a4f2a")).set_meta("wood", true)
	_box(n, Vector3(0.05, 0.5, 0.05), Vector3(-0.4, 1.27, 0.22), Color("7a4f2a"), Vector3(25, 0, 0)).set_meta("wood", true)
	_box(n, Vector3(0.05, 0.5, 0.05), Vector3(-0.4, 0.63, 0.22), Color("7a4f2a"), Vector3(-25, 0, 0)).set_meta("wood", true)
	_box(n, Vector3(0.012, 1.2, 0.012), Vector3(-0.4, 0.95, 0.1), Color("e8ecfa"))
	# Ok kılıfı
	_cyl(n, 0.1, 0.1, 0.6, Vector3(0.15, 0.95, -0.3), Color("7a4f2a"), 8, Vector3(15, 0, 0))
	_box(n, Vector3(0.05, 0.2, 0.05), Vector3(0.12, 1.32, -0.36), Color("dfe6ee"))
	n.scale = Vector3.ONE * 1.25
	return n


static func musketeer(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Musketeer"
	for x in [-0.12, 0.12]:
		_cyl(n, 0.08, 0.09, 0.5, Vector3(x, 0.25, 0), Color("e8ecfa"), 6)
	var cap := CapsuleMesh.new()
	cap.radius = 0.27
	cap.height = 0.9
	_add(n, cap, team, Vector3(0, 0.78, 0))
	_box(n, Vector3(0.1, 0.8, 0.06), Vector3(0.0, 0.8, 0.26), Color("e8ecfa"), Vector3(0, 0, 25))
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	_add(n, head, SKIN, Vector3(0, 1.4, 0))
	_cyl(n, 0.28, 0.3, 0.12, Vector3(0, 1.58, 0), DARK, 10)
	_box(n, Vector3(0.05, 0.25, 0.05), Vector3(0.2, 1.72, 0), team.lightened(0.3))
	_cyl(n, 0.03, 0.03, 1.5, Vector3(0.3, 1.0, 0.45), Color("3a2a1a"), 6, Vector3(80, 0, 0))
	n.scale = Vector3.ONE * 1.25
	return n


static func rifleman(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Rifleman"
	var olive := Color("5f6b3a")
	for x in [-0.12, 0.12]:
		_cyl(n, 0.08, 0.09, 0.5, Vector3(x, 0.25, 0), DARK, 6)
	var cap := CapsuleMesh.new()
	cap.radius = 0.27
	cap.height = 0.9
	_add(n, cap, olive, Vector3(0, 0.78, 0))
	_box(n, Vector3(0.5, 0.5, 0.2), Vector3(0, 0.85, -0.3), team.darkened(0.2))
	var head := SphereMesh.new()
	head.radius = 0.19
	head.height = 0.38
	_add(n, head, SKIN, Vector3(0, 1.4, 0))
	var helmet := SphereMesh.new()
	helmet.radius = 0.24
	helmet.height = 0.24
	helmet.is_hemisphere = true
	_add(n, helmet, olive.darkened(0.2), Vector3(0, 1.45, 0))
	_cyl(n, 0.03, 0.03, 1.7, Vector3(0.28, 1.0, 0.5), DARK, 6, Vector3(80, 0, 0))
	n.scale = Vector3.ONE * 1.25
	return n


static func cavalry(team: Color) -> Node3D:
	var n := scout(team)
	n.name = "Cavalry"
	_cyl(n, 0.03, 0.03, 2.8, Vector3(0.45, 1.9, 0.3), Color("7a4f2a"), 6, Vector3(70, 0, 0))
	_cyl(n, 0.0, 0.07, 0.3, Vector3(0.45, 2.15, 1.55), Color("dfe6ee"), 6, Vector3(70, 0, 0))
	return n


static func cannon(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Cannon"
	var wood := Color("6b4a2b")
	for x in [-0.7, 0.7]:
		_cyl(n, 0.6, 0.6, 0.2, Vector3(x, 0.6, 0), wood, 12, Vector3(0, 0, 90))
	_box(n, Vector3(1.0, 0.3, 2.4), Vector3(0, 0.75, -0.4), wood)
	_cyl(n, 0.28, 0.38, 2.4, Vector3(0, 1.1, 0.4), Color("2b2f3a"), 10, Vector3(90, 0, 0))
	_box(n, Vector3(0.9, 0.12, 0.5), Vector3(0, 1.45, -0.2), team)
	n.scale = Vector3.ONE * 1.3
	return n


static func galleon(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Galleon"
	var wood := Color("6b4a2b")
	_box(n, Vector3(2.8, 1.3, 8.5), Vector3(0, 0.5, 0), wood)
	var prow := _cyl(n, 0.0, 1.4, 2.4, Vector3(0, 0.5, 5.4), wood, 12, Vector3(90, 0, 0))
	prow.scale = Vector3(1, 1, 0.5)
	_box(n, Vector3(2.9, 0.2, 8.6), Vector3(0, 1.2, 0), team)
	_box(n, Vector3(2.4, 1.6, 2.2), Vector3(0, 1.9, -3.2), wood.darkened(0.2))
	for z in [-1.2, 1.8]:
		_cyl(n, 0.12, 0.16, 8.0, Vector3(0, 5.0, z), Color("3a2a1a"), 6)
		_box(n, Vector3(0.1, 4.2, 3.0), Vector3(0, 5.2, z + 0.1), Color("f2efe6"))
	_box(n, Vector3(0.06, 0.7, 1.1), Vector3(0.0, 9.2, 1.8), team)
	for s in [-1.4, 1.4]:
		_cyl(n, 0.12, 0.12, 0.9, Vector3(s, 1.2, 0.5), DARK, 6, Vector3(0, 0, 90))
	n.scale = Vector3.ONE * 1.2
	return n


static func lumber_camp() -> Node3D:
	var n := Node3D.new()
	n.name = "LumberCamp"
	_box(n, Vector3(3.4, 2.2, 3.0), Vector3(0, 1.1, 0), Color("8a6a42"))
	_cyl(n, 0.0, 3.0, 1.6, Vector3(0, 3.0, 0), Color("6b3f24"), 4, Vector3(0, 45, 0))
	for i in range(3):
		_cyl(n, 0.35, 0.35, 3.0, Vector3(3.2, 0.4 + i * 0.5, -0.6 + i * 0.1), Color("7a4f2a"), 8, Vector3(0, 0, 90))
	_cyl(n, 0.4, 0.45, 0.8, Vector3(-3.0, 0.4, 1.4), Color("7a4f2a"), 8)
	_box(n, Vector3(0.12, 1.2, 0.12), Vector3(-3.0, 1.4, 1.4), Color("5a3d24"), Vector3(0, 0, 20))
	return n


static func mine(ore: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Mine"
	_cyl(n, 1.2, 4.2, 3.2, Vector3(0, 1.6, 0), Color("7d838d"), 8)
	_cyl(n, 0.0, 2.4, 1.6, Vector3(-1.2, 3.8, 0.6), Color("8c929c"), 7)
	_box(n, Vector3(1.6, 1.8, 0.4), Vector3(0, 0.9, 3.2), DARK)
	_box(n, Vector3(0.2, 2.0, 0.2), Vector3(-0.95, 1.0, 3.5), Color("6b4a2b"))
	_box(n, Vector3(0.2, 2.0, 0.2), Vector3(0.95, 1.0, 3.5), Color("6b4a2b"))
	_box(n, Vector3(2.2, 0.2, 0.3), Vector3(0, 2.05, 3.5), Color("6b4a2b"))
	for p in [Vector3(2.4, 0.5, 2.0), Vector3(-2.2, 0.5, 2.4), Vector3(0.6, 0.45, 3.9)]:
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 0.8
		_add(n, sm, ore, p)
	return n


static func derrick() -> Node3D:
	var n := Node3D.new()
	n.name = "OilDerrick"
	var steel := Color("5a6270")
	_cyl(n, 0.3, 1.5, 9.0, Vector3(0, 4.5, 0), steel, 4, Vector3(0, 45, 0))
	for y in [2.0, 4.5, 7.0]:
		_box(n, Vector3(2.0 - y * 0.15, 0.16, 2.0 - y * 0.15), Vector3(0, y, 0), steel.darkened(0.2), Vector3(0, 45, 0))
	_box(n, Vector3(3.0, 1.4, 1.6), Vector3(3.2, 1.2, 0), Color("c9a227"))
	_box(n, Vector3(3.4, 0.25, 0.3), Vector3(3.2, 2.4, 0), DARK, Vector3(0, 0, 14))
	_cyl(n, 3.0, 3.0, 0.08, Vector3(0, 0.05, 0), Color("14110d"), 14)
	return n


static func worker(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Worker"
	var cap := CapsuleMesh.new()
	cap.radius = 0.27
	cap.height = 1.0
	_add(n, cap, Color("c9a15a"), Vector3(0, 0.5, 0))
	_box(n, Vector3(0.56, 0.18, 0.4), Vector3(0, 0.55, 0), team)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	_add(n, head, SKIN, Vector3(0, 1.15, 0))
	var hat := SphereMesh.new()
	hat.radius = 0.26
	hat.height = 0.26
	hat.is_hemisphere = true
	_add(n, hat, Color("f0c64a"), Vector3(0, 1.22, 0))
	_cyl(n, 0.03, 0.03, 1.2, Vector3(0.32, 0.7, 0.1), Color("7a4f2a"), 6, Vector3(0, 0, 20))
	_box(n, Vector3(0.4, 0.08, 0.08), Vector3(0.52, 1.28, 0.1), Color("9aa3b2"))
	n.scale = Vector3.ONE * 1.6
	return n


static func tank(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Tank"
	for x in [-0.8, 0.8]:
		_box(n, Vector3(0.5, 0.5, 3.0), Vector3(x, 0.25, 0), DARK)
	_box(n, Vector3(1.5, 0.5, 2.8), Vector3(0, 0.65, 0), team)
	_box(n, Vector3(1.1, 0.45, 1.2), Vector3(0, 1.1, -0.1), team.lightened(0.1))
	_cyl(n, 0.09, 0.09, 1.9, Vector3(0, 1.15, 1.35), DARK, 8, Vector3(90, 0, 0))
	n.scale = Vector3.ONE * 1.4
	return n


static func ship(team: Color) -> Node3D:
	var n := Node3D.new()
	n.name = "Ship"
	var hull := Color("7f8a9b")
	_box(n, Vector3(2.4, 1.0, 8.0), Vector3(0, 0.4, 0), hull)
	var prow := _cyl(n, 0.0, 1.2, 2.2, Vector3(0, 0.4, 5.1), hull, 12, Vector3(90, 0, 0))
	prow.scale = Vector3(1, 1, 0.42)
	_box(n, Vector3(2.45, 0.18, 8.05), Vector3(0, 0.95, 0), team)
	_box(n, Vector3(1.6, 1.1, 2.2), Vector3(0, 1.55, -0.6), Color("d9dde6"))
	_box(n, Vector3(1.2, 0.8, 1.2), Vector3(0, 2.5, -0.6), Color("c4cad6"))
	_cyl(n, 0.3, 0.3, 1.1, Vector3(0, 3.2, -1.7), DARK, 10)
	_cyl(n, 0.5, 0.5, 0.3, Vector3(0, 1.1, 2.4), DARK, 12)
	_cyl(n, 0.08, 0.08, 1.4, Vector3(0, 1.25, 3.2), DARK, 8, Vector3(90, 0, 0))
	n.scale = Vector3.ONE * 1.3
	return n


static func scout(team: Color) -> Node3D:
	# Atlı izci: at gövdesi, boyun, baş, dört bacak ve binici.
	var n := Node3D.new()
	n.name = "Scout"
	var horse := Color("8a5a3a")
	_box(n, Vector3(0.55, 0.55, 1.5), Vector3(0, 0.95, 0), horse)
	_box(n, Vector3(0.28, 0.6, 0.3), Vector3(0, 1.35, 0.85), horse, Vector3(25, 0, 0))
	_box(n, Vector3(0.25, 0.25, 0.5), Vector3(0, 1.55, 1.15), horse.darkened(0.15))
	for x in [-0.18, 0.18]:
		for z in [-0.6, 0.6]:
			_cyl(n, 0.07, 0.07, 0.7, Vector3(x, 0.35, z), horse.darkened(0.3), 6)
	_box(n, Vector3(0.58, 0.12, 0.6), Vector3(0, 1.3, -0.1), team)
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 0.8
	_add(n, cap, team, Vector3(0, 1.75, -0.1))
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	_add(n, head, SKIN, Vector3(0, 2.28, -0.1))
	n.scale = Vector3.ONE * 1.6
	return n


static func farm() -> Node3D:
	var n := Node3D.new()
	n.name = "Farm"
	_box(n, Vector3(7, 0.2, 5.5), Vector3(0, 0.1, 0), Color("7fc25a"))
	for i in range(4):
		_box(n, Vector3(7, 0.22, 0.6), Vector3(0, 0.12, -2.0 + i * 1.3), Color("5fa63f"))
	return n
