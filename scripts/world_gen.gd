extends RefCounted
## Tohumdan deterministik dünya üretimi (1024x1024 karo).
## Dünya kayıt edilmez, parça (chunk) parça mesh olarak üretilir.

const WORLD_TILES := 1024
const CHUNK_TILES := 64
const HEIGHT_SCALE := 30.0
const SEABED_SCALE := 8.0

const SEA := 0
const BEACH := 1
const GRASS := 2
const FOREST := 3
const DESERT := 4
const ROCK := 5
const SNOW := 6

var _height := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _palette: Array = []
var sea_bias := 0.0       # negatif: daha çok deniz (takımadalar)
var mountain_mul := 1.0   # dağ sırtlarının şiddeti
var scorched: Array = []  # nükleer yanık bölgeler: [{"p": Vector2, "r": float}] (bitki çıkmaz)


## profile: "continents" (varsayılan), "archipelago" (çok ada), "mountains" (dağlık).
func _init(p_seed: int = 20241029, profile: String = "continents") -> void:
	match profile:
		"archipelago":
			sea_bias = -0.14
		"mountains":
			sea_bias = 0.03
			mountain_mul = 2.4
	_height.seed = p_seed
	_height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height.frequency = 0.0032
	_height.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height.fractal_octaves = 5

	_ridge.seed = p_seed + 1
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.006
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 3

	_moist.seed = p_seed + 2
	_moist.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moist.frequency = 0.004
	_moist.fractal_octaves = 3

	_detail.seed = p_seed + 3
	_detail.frequency = 0.08

	_palette = [
		Color.html("2d6f8e"),  # SEA (deniz tabanı)
		Color.html("e2d49a"),  # BEACH
		Color.html("5f9650"),  # GRASS
		Color.html("2f6b3f"),  # FOREST
		Color.html("cfae62"),  # DESERT
		Color.html("8b929b"),  # ROCK
		Color.html("eef3f7"),  # SNOW
	]


## -1..1 arası yükseklik. 0 altı deniz.
func height_at(x: float, z: float) -> float:
	var n := _height.get_noise_2d(x, z)
	var r := _ridge.get_noise_2d(x, z)
	var cx := x / WORLD_TILES * 2.0 - 1.0
	var cz := z / WORLD_TILES * 2.0 - 1.0
	var d := maxf(absf(cx), absf(cz))
	var edge := smoothstep(0.78, 1.0, d)
	var mountain := maxf(r, 0.0) * 0.25 * mountain_mul * clampf(n + 0.4, 0.0, 1.0)
	return n * 0.85 + 0.12 + sea_bias + mountain - edge * 1.4


func is_scorched(x: float, z: float) -> bool:
	for s in scorched:
		if Vector2(x - s["p"].x, z - s["p"].y).length() < float(s["r"]):
			return true
	return false


func surface_y(x: float, z: float) -> float:
	var h := height_at(x, z)
	if h < 0.0:
		return h * SEABED_SCALE
	return h * HEIGHT_SCALE


func biome_at(x: float, z: float, h: float) -> int:
	if h < 0.0:
		return SEA
	if h < 0.035:
		return BEACH
	var temp := z / WORLD_TILES  # kuzey (z=0) soğuk, güney sıcak
	var m := _moist.get_noise_2d(x, z)
	if h > 0.55 or temp < 0.08:
		return SNOW
	if h > 0.38:
		return ROCK
	if m < -0.2 and temp > 0.45:
		return DESERT
	if m > 0.15:
		return FOREST
	return GRASS


func _color_for(biome: int, d: float) -> Color:
	var c: Color = _palette[biome]
	var f := 1.0 + d * 0.08
	return Color(c.r * f, c.g * f, c.b * f)


## Bir parçanın mesh'i. step: örnekleme aralığı (1 = ayrıntılı, 8 = uzak LOD).
func build_chunk(cx: int, cz: int, step: int) -> ArrayMesh:
	var n := int(CHUNK_TILES / float(step)) + 1
	var ox := cx * CHUNK_TILES
	var oz := cz * CHUNK_TILES

	# Bir halka fazladan örnekleyip normalleri komşu parçalarla uyumlu hesaplıyoruz (dikiş yok).
	var m2 := n + 2
	var ys := PackedFloat32Array()
	ys.resize(m2 * m2)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for j in range(-1, n + 1):
		for i in range(-1, n + 1):
			var wx := float(ox + i * step)
			var wz := float(oz + j * step)
			var h := height_at(wx, wz)
			var y := h * SEABED_SCALE if h < 0.0 else h * HEIGHT_SCALE
			ys[(j + 1) * m2 + (i + 1)] = y
			if i >= 0 and i < n and j >= 0 and j < n:
				verts.append(Vector3(wx, y, wz))
				cols.append(_color_for(biome_at(wx, wz, h), _detail.get_noise_2d(wx, wz)))

	var normals := PackedVector3Array()
	for j in range(n):
		for i in range(n):
			var yl := ys[(j + 1) * m2 + i]
			var yr := ys[(j + 1) * m2 + i + 2]
			var yu := ys[j * m2 + i + 1]
			var yd := ys[(j + 2) * m2 + i + 1]
			normals.append(Vector3(yl - yr, 2.0 * float(step), yu - yd).normalized())

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(verts.size()):
		st.set_color(cols[k])
		st.set_normal(normals[k])
		st.add_vertex(verts[k])
	for j in range(n - 1):
		for i in range(n - 1):
			var a := j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)

	# Etek (skirt): farklı LOD'lar arasındaki çatlakları gizler.
	var edge: Array = []
	for i in range(n):
		edge.append(i)
	for j in range(1, n):
		edge.append(j * n + (n - 1))
	for i in range(n - 2, -1, -1):
		edge.append((n - 1) * n + i)
	for j in range(n - 2, 0, -1):
		edge.append(j * n)
	var base := verts.size()
	var skirt := 4.0 * float(step)
	for k in range(edge.size()):
		var v: Vector3 = verts[edge[k]]
		st.set_color(cols[edge[k]])
		st.set_normal(normals[edge[k]])
		st.add_vertex(Vector3(v.x, v.y - skirt, v.z))
	var m := edge.size()
	for k in range(m):
		var k2 := (k + 1) % m
		st.add_index(edge[k])
		st.add_index(edge[k2])
		st.add_index(base + k)
		st.add_index(edge[k2])
		st.add_index(base + k2)
		st.add_index(base + k)

	return st.commit()


## Bir parçanın bitki örtüsü: çam, geniş yapraklı ağaç ve (istenirse) çimen tutamı dönüşümleri.
## Aynı parça her zaman aynı bitkileri verir (tohum + parça koordinatı).
func vegetation(cx: int, cz: int, with_grass: bool) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = (cx * 73856093) ^ (cz * 19349663) ^ int(_height.seed)
	var ox := float(cx * CHUNK_TILES)
	var oz := float(cz * CHUNK_TILES)
	var pines: Array = []
	var broads: Array = []
	var tufts: Array = []

	var step := 3.0
	var n := int(CHUNK_TILES / step)
	for j in range(n):
		for i in range(n):
			var x := ox + (float(i) + rng.randf()) * step
			var z := oz + (float(j) + rng.randf()) * step
			var h := height_at(x, z)
			if h < 0.05 or is_scorched(x, z):
				continue
			var b := biome_at(x, z, h)
			var p := 0.0
			if b == FOREST:
				p = 0.8
			elif b == GRASS:
				p = 0.06
			elif b == SNOW and h < 0.6:
				p = 0.12
			if p <= 0.0 or rng.randf() > p:
				continue
			if absf(height_at(x + 2.0, z) - h) * HEIGHT_SCALE > 3.2:
				continue  # dik yamaçta ağaç yok
			var s := rng.randf_range(0.55, 1.0)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
			var xf := Transform3D(basis, Vector3(x, h * HEIGHT_SCALE - 0.15, z))
			if z / WORLD_TILES < 0.34 or b == SNOW:
				pines.append(xf)
			else:
				broads.append(xf)

	if with_grass:
		var gstep := 1.7
		var gn := int(CHUNK_TILES / gstep)
		for j in range(gn):
			for i in range(gn):
				var x := ox + (float(i) + rng.randf()) * gstep
				var z := oz + (float(j) + rng.randf()) * gstep
				var h := height_at(x, z)
				if h < 0.045 or is_scorched(x, z):
					continue
				var b := biome_at(x, z, h)
				var p := 0.0
				if b == GRASS:
					p = 0.5
				elif b == FOREST:
					p = 0.25
				# Lekeli dağılım: gürültünün yüksek olduğu yerlerde yoğun, diğerlerinde seyrek
				if _detail.get_noise_2d(x * 0.5, z * 0.5) < 0.05:
					p *= 0.12
				if p <= 0.0 or rng.randf() > p:
					continue
				var s := rng.randf_range(0.7, 1.2)
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
				tufts.append(Transform3D(basis, Vector3(x, h * HEIGHT_SCALE, z)))

	return {"pines": pines, "broads": broads, "tufts": tufts}


## Düz, kara bir başlangıç noktası arar (dünya ortasından dışa doğru).
func find_spawn() -> Vector2:
	var center := Vector2(WORLD_TILES * 0.5, WORLD_TILES * 0.5)
	for r in range(0, 480, 10):
		var count := maxi(1, int(r / 6.0))
		for i in range(count):
			var a := TAU * float(i) / float(count)
			var p := center + Vector2(cos(a), sin(a)) * float(r)
			if _good_spawn(p):
				return p
	return center


func _good_spawn(p: Vector2) -> bool:
	var h := height_at(p.x, p.y)
	if h < 0.06 or h > 0.30:
		return false
	for o in [Vector2(14, 0), Vector2(-14, 0), Vector2(0, 14), Vector2(0, -14)]:
		var ho := height_at(p.x + o.x, p.y + o.y)
		if absf(ho - h) > 0.05:
			return false
	return true


## p yakınında düz, kara bir nokta arar.
func find_land_near(p: Vector2) -> Vector2:
	for r in range(0, 260, 8):
		var count := maxi(1, int(r / 6.0))
		for i in range(count):
			var a := TAU * float(i) / float(count)
			var q := p + Vector2(cos(a), sin(a)) * float(r)
			if q.x < 40.0 or q.y < 40.0 or q.x > WORLD_TILES - 40.0 or q.y > WORLD_TILES - 40.0:
				continue
			if _good_spawn(q):
				return q
	return p


## p yakınında derin su arar; bulamazsa Vector2(-1, -1) döner.
func find_water_near(p: Vector2) -> Vector2:
	for r in range(20, 320, 10):
		for i in range(24):
			var a := TAU * float(i) / 24.0
			var q := p + Vector2(cos(a), sin(a)) * float(r)
			if q.x < 0.0 or q.y < 0.0 or q.x > WORLD_TILES or q.y > WORLD_TILES:
				continue
			if height_at(q.x, q.y) < -0.14:
				return q
	return Vector2(-1, -1)
