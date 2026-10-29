extends Node3D
## Dikey dilim: 1024x1024 dünya, eğik kamera, keşif sisi, çağlar, birlikler, savaş ve can çubukları.

const WorldGen = preload("res://scripts/world_gen.gd")
const Models = preload("res://scripts/models.gd")
const RtsCamera = preload("res://scripts/rts_camera.gd")
const Hud = preload("res://scripts/hud.gd")
const Fog = preload("res://scripts/fog.gd")
const UnitsData = preload("res://scripts/units_data.gd")
const Fx = preload("res://scripts/fx.gd")
const UiMenu = preload("res://scripts/ui_menu.gd")
const UiLibrary = preload("res://scripts/ui_library.gd")

const BORDER_BASE := 85.0       # oyuncu ulusal sınır yarıçapı (karo); Sivil teknolojiyle büyür
const ENEMY_BORDER := 50.0
const NUKE_RADIUS := 60.0

const CHUNK_TILES := 64
const WORLD_CHUNKS := 16  # 1024 / 64
const BUILD_BUDGET_USEC := 7000
const FOG_INTERVAL := 0.2
const PICK_RADIUS_PX := 55.0
const PICK_RADIUS_STRUCT_PX := 95.0
const MARKER_LIFE := 1.4
const LINE_LIFE := 1.6

const MAX_LEVEL := 5
# Yükseltme temel bedeli (1. seviyeden 2.'ye). Her seviyede 1,7 katına çıkar.
const UPGRADE_BASE := {
	"castle": {"food": 80.0, "wood": 100.0, "gold": 120.0, "silver": 5.0},
	"tower": {"food": 40.0, "wood": 50.0, "gold": 70.0, "silver": 0.0},
}
const GATHER_RANGE := 6.0   # işçi bu mesafeden yakınsa toplar
const NODE_PICK_PX := 85.0

const COL_MOVE := Color(0.07, 0.14, 0.36)
const COL_ATTACK := Color(0.50, 0.05, 0.12)


## İnşaat alanı: işçiler gelip çalıştıkça ilerler, bitince gerçek yapıya dönüşür.
class Site:
	var kind := ""
	var node: Node3D
	var progress := 0.0
	var btime := 10.0
	var label: Label3D
	var pos := Vector3.ZERO
	var yaw := 0.0


## Kaynak toplama noktası (tarla, odun kampı, altın/gümüş madeni, petrol kulesi).
class RNode:
	var kind := ""        # food, wood, gold, silver, oil
	var title := ""
	var node: Node3D
	var slots := 5
	var workers := 0
	var rate := 0.2       # işçi başına saniyede toplanan miktar
	var min_era := 0      # bu çağdan önce görünmez ve kullanılamaz
	var label: Label3D


## Savaşabilen / seçilebilen her varlık (birlik veya yapı). Nesne referansıyla karşılaştırılır.
class Ent:
	var node: Node3D
	var kind := ""
	var team := "player"
	var nation := ""
	var alive := true
	var structure := false
	# Saldırı
	var atk_range := 0.0
	var dmg := 0.0
	var cd := 1.0
	var cd_t := 0.0
	var proj := ""
	var attack: Ent = null      # komutla verilen saldırı hedefi
	var body_r := 0.0           # yapının gövde yarıçapı (menzil hesabına eklenir)
	var hit_h := 1.2
	var fire_h := 1.8
	var level := 1                # yapı seviyesi (para ile yükseltilir)
	var naval := false            # sadece suda hareket eder
	var range_ring: MeshInstance3D  # seçilince gösterilen menzil halkası
	var ring_range := -1.0
	var job: RNode = null         # işçinin atandığı kaynak noktası
	var job_angle := 0.0
	var build_site: Site = null   # işçinin çalıştığı inşaat alanı
	var queue: Array = []         # üretim kuyruğu: [{"kind", "total", "left"}]
	var rally = null              # toplanma noktası (Vector3) veya null
	var stance := "defend"        # aggressive / defend / hold
	var home = null               # savunma modunda geri dönülen nokta
	var fire: CPUParticles3D      # hasarlı yapıdaki yangın
	var fire_level := 0
	# Animasyon
	var base_scale := Vector3.ONE
	var tween: Tween
	var threat_ring: MeshInstance3D   # saldırı hedefi işareti (kırmızı, nabız atar)
	# Can çubuğu
	var hp := 1.0
	var max_hp := 1.0
	var bar_mesh: MeshInstance3D
	var bar_off := 3.0
	var bar_last := -1.0
	# Oyuncu birlikleri
	var speed := 0.0
	var sight := 0.0
	var selected := false
	var goal = null             # Vector3 hareket hedefi veya null
	var ring: MeshInstance3D


var gen = WorldGen.new()
var fog = Fog.new()
var cam: Camera3D
var hud: CanvasLayer
var chunks := {}  # Vector2i -> {"node": MeshInstance3D, "step": int}

var _terrain_mat: ShaderMaterial
var _detail_tex: ImageTexture
var _detail_normal: ImageTexture
var _home := Vector2(-1000, -1000)   # oyuncu kalesinin konumu (ağaç temizliği için)
var _veg_trees: ShaderMaterial
var _veg_grass: ShaderMaterial
var _pine_mesh: ArrayMesh
var _broad_mesh: ArrayMesh
var _grass_mesh: ArrayMesh
var _water: MeshInstance3D
var _env: Environment

# Oyun durumu
var _era := 0
# Kaynaklar: yalnızca işçilerin kaynak noktalarında topladığı kadar artar.
var _res := {"food": 250.0, "wood": 150.0, "gold": 180.0, "silver": 20.0, "oil": 0.0}
var _res_ui_t := 0.0
var _nodes: Array = []      # kaynak noktaları (RNode)
var _dock := Vector2(-1, -1)  # gemilerin doğduğu kıyı noktası
var _workers_trained := 0     # işçi maliyeti her işçide %12 artar
var _world_root: Node3D
var _all: Array = []        # çubuğu olan tüm varlıklar
var _units: Array = []      # oyuncunun hareketli birlikleri
var _pstructs: Array = []   # oyuncu yapıları
var _eunits: Array = []     # rakip birlikleri
var _estructs: Array = []   # rakip yapıları
var _nations: Array = []    # [{"name","structures","units","pos","found"}]
var _projectiles: Array = []
var _fx_count := 0
var _threat_t := 0.0
var _markers: Array = []
var _lines: Array = []
var _path_mesh: ImmediateMesh
var _bar_mat: ShaderMaterial
var _bars_root: Node3D
var _fog_timer := 0.0
var _rng := RandomNumberGenerator.new()

# Yeni sistemler
var fx
var menu
var lib
var _started := false
var _cfg := {}
var _peace_left := 0.0
var _style := "west"            # oyuncunun mimari stili
var _formation := "box"
var _build_kind := ""           # inşaat yerleştirme modu
var _rally_mode := false
var _sites: Array = []
var _lib_levels := {"mil": 0, "civ": 0, "com": 0, "sci": 0}
var _age_progress := -1.0
var _border_mesh: ImmediateMesh
var _border_t := 0.0
var _mm_t := 0.0
var _fire_t := 0.0
var _idle_cursor := 0
var _nomad := false
var _starve_warned := 0.0
var _cfg_override := {}

# Girdi
var _select_mode := false
var _tap_candidate := false
var _press_pos := Vector2.ZERO
var _press_ms := 0
var _box_active := false
var _last_tap_unit: Ent = null
var _last_tap_ms := 0
var _sel_struct: Ent = null   # seçili oyuncu yapısı (kule/kale)
var _selcastle_arg := false

# Test yardımcıları (komut satırı: godot --path . -- --shot=x.png --zoom=110 --army --era=3 --move=60,-30 --atk)
var _shot_path := ""
var _shot_ms := 4000  # ekran görüntüsü için oyun başladıktan sonra beklenecek süre
var _army_arg := false
var _move_arg = null
var _atk_arg := false
var _taptest := false
var _taptest_done := false
var _tab_arg := ""


func _ready() -> void:
	var auto_start := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
			auto_start = true
		elif a == "--menu":
			auto_start = false
		elif a == "--army":
			_army_arg = true
			auto_start = true
		elif a == "--atk":
			_atk_arg = true
			auto_start = true
		elif a == "--taptest":
			_taptest = true
			auto_start = true
		elif a == "--nomenu":
			auto_start = true
		elif a.begins_with("--tab="):
			_tab_arg = a.substr(6)
		elif a == "--selcastle":
			_selcastle_arg = true
		elif a.begins_with("--wait="):
			_shot_ms = int(float(a.substr(7)) * 1000.0)
		elif a.begins_with("--era="):
			_era = clampi(int(a.substr(6)) - 1, 0, UnitsData.ERAS.size() - 1)
			auto_start = true
		elif a.begins_with("--move="):
			var p := a.substr(7).split(",")
			_move_arg = Vector2(float(p[0]), float(p[1]))
		elif a.begins_with("--map="):
			_cfg_override["map"] = a.substr(6)
		elif a == "--nomad":
			_cfg_override["nomad"] = true
		elif a.begins_with("--peace="):
			_cfg_override["peace"] = float(a.substr(8))
		elif a.begins_with("--style="):
			_cfg_override["style"] = a.substr(8)
	# --menu bayrağı verilmişse (menü ekran görüntüsü için) otomatik başlatma kapalı kalır
	if "--menu" in OS.get_cmdline_user_args():
		auto_start = false

	_rng.seed = 7
	_setup_environment()
	_setup_materials()
	cam = RtsCamera.new()
	add_child(cam)
	cam.current = true
	_setup_water()
	_setup_paths()
	_setup_bars()

	hud = Hud.new()
	add_child(hud)
	hud.action.connect(_on_action)
	hud.minimap_pressed.connect(_on_minimap)
	lib = UiLibrary.new()
	add_child(lib)
	lib.research.connect(_on_research)
	lib.age_up.connect(_on_age_up)
	fx = Fx.new(self, cam)

	menu = UiMenu.new()
	add_child(menu)
	menu.start.connect(_start_game)
	if auto_start:
		menu.visible = false
		_start_game(menu.default_cfg())


## Menüden (veya test bayraklarıyla) oyunu başlatır: dünya, kamera, yapılar, kurallar.
func _start_game(cfg: Dictionary) -> void:
	_cfg = cfg.duplicate()
	for k in _cfg_override:
		_cfg[k] = _cfg_override[k]
	gen = WorldGen.new(20241029, String(_cfg["map"]))
	_style = String(_cfg["style"])
	_nomad = bool(_cfg["nomad"])
	_peace_left = float(_cfg["peace"])
	Engine.time_scale = float(_cfg["speed"])
	cam.scroll_mul = float(_cfg["scroll"])
	_setup_borders()

	var spawn: Vector2 = gen.find_spawn()
	_home = spawn
	cam.target = Vector3(spawn.x, 0.0, spawn.y)
	cam.zoom = 70.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zoom="):
			cam.zoom = float(a.substr(7))
		elif a.begins_with("--look="):  # test: kamerayı doğan noktaya göre kaydır
			var lp := a.substr(7).split(",")
			cam.target += Vector3(float(lp[0]), 0.0, float(lp[1]))
	cam._apply()

	_place_world(spawn)
	hud.minimap.setup(gen)
	_apply_era(_era, false)
	_update_fog()
	hud.set_stance("stance:defend")
	hud.set_formation("form:" + _formation)
	_started = true
	if _tab_arg != "":
		hud.open_tab(_tab_arg)
	if _selcastle_arg and not _pstructs.is_empty():
		_select_struct(_pstructs[0])

	if _move_arg != null:
		_select_all(true)
		_order_move(Vector3(spawn.x + _move_arg.x, 0.0, spawn.y + _move_arg.y))
	if _atk_arg:
		_select_all(true)
		if not _estructs.is_empty():
			_order_attack(_estructs[0])
	_refresh_hint()
	if "--lib" in OS.get_cmdline_user_args():
		_on_action("library")
	if _nomad:
		hud.show_toast("Göçebe: bir işçiyle Kale inşa et")


func _process(delta: float) -> void:
	if _shot_path != "" and Time.get_ticks_msec() >= _shot_ms:
		print("RES son ", _res)
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()
	if not _started:
		return

	if _taptest and not _taptest_done and Time.get_ticks_msec() > 2500:
		_taptest_done = true
		_run_systest()

	if _peace_left > 0.0:
		_peace_left = maxf(0.0, _peace_left - delta)
	_gather(delta)
	_process_queues(delta)
	_update_sites(delta)
	_update_age(delta)
	_res_ui_t += delta
	if _res_ui_t >= 0.5:
		_res_ui_t = 0.0
		_refresh_economy_ui()
		_refresh_struct_panel()
		if lib.visible:
			lib.refresh(_lib_state())

	_water.position = Vector3(cam.target.x, 0.0, cam.target.z)
	_env.fog_density = 0.35 / (cam.zoom * 2.0 + 150.0)
	_move_units(delta)
	_fire_phase(_units + _pstructs, _eunits + _estructs, delta, true)
	_fire_phase(_eunits + _estructs, _units + _pstructs, delta, false)
	_update_projectiles(delta)
	_update_threat_rings(delta)
	_update_markers(delta)
	_update_lines(delta)
	_update_bars()
	_update_chunks()

	_border_t += delta
	if _border_t >= 0.1:
		_border_t = 0.0
		_update_borders()
	_mm_t += delta
	if _mm_t >= 0.25:
		_mm_t = 0.0
		_update_minimap()
	_fire_t += delta
	if _fire_t >= 0.5:
		_fire_t = 0.0
		_update_fires()

	_fog_timer += delta
	if _fog_timer >= FOG_INTERVAL:
		_fog_timer = 0.0
		_update_fog()

	var peace_txt := ""
	if _peace_left > 0.0:
		peace_txt = " · barış %d:%02d" % [int(_peace_left) / 60, int(_peace_left) % 60]
	hud.set_debug("FPS %d · parça %d · yakınlık %d · keşif %%%.1f%s" % [
		Engine.get_frames_per_second(), chunks.size(), int(cam.zoom), fog.explored_percent(), peace_txt])


## Sistem testi (--taptest): kuyruk, inşaat, nüfus, kütüphane, çağ atlama, savaş modları, nükleer. Sonuçları konsola yazar.
func _run_systest() -> void:
	_on_action("dev_res")
	print("SYS nüfus ", _pop_used(), "/", _pop_cap(), " yapı=", _pstructs.size())
	# 1) Üretim kuyruğu
	var bar: Ent = null
	for s: Ent in _pstructs:
		if s.kind == "barracks":
			bar = s
	var before := _units.size()
	if bar != null:
		_select_struct(bar)
		_enqueue(bar, "spearman")
		_enqueue(bar, "archer")
		print("SYS kuyruk=", bar.queue.size())
		_process_queues(30.0)
		_process_queues(30.0)
	print("SYS üretim birlik ", before, " -> ", _units.size())
	# 2) İnşaat: ev
	var caps := _pop_cap()
	_clear_struct_selection()
	_select_only_kind("worker")
	_build_kind = "house"
	var spot := Vector3(_home.x + 30.0, 0.0, _home.y + 45.0)
	_place_build(spot)
	print("SYS inşaat alanı=", _sites.size())
	for u: Ent in _units:
		if u.build_site != null:
			u.node.position = Vector3(spot.x, u.node.position.y, spot.z)
	_update_sites(40.0)
	print("SYS ev bitti: yapı=", _pstructs.size(), " nüfus sınırı ", caps, " -> ", _pop_cap())
	# 3) Kütüphane + çağ atlama
	_on_research("mil")
	_on_research("com")
	print("SYS kütüphane ", _lib_levels, " nüfus sınırı=", _pop_cap(), " ticaret sınırı=", int(_com_cap()))
	var era0 := _era
	_on_age_up()
	_update_age(UnitsData.AGE_TIME + 1.0)
	print("SYS çağ ", era0, " -> ", _era)
	# 4) Savaş modları ve diziliş
	_select_all(true)
	_on_action("stance:aggressive")
	_on_action("form:line")
	var stance_ok := true
	for u: Ent in _units:
		if u.selected and u.stance != "aggressive":
			stance_ok = false
	print("SYS duruş ok=", stance_ok, " diziliş=", _formation)
	# 5) Nükleer
	var foes := _estructs.size() + _eunits.size()
	_nuke(_nations[0]["pos"])
	print("SYS nükleer: rakip varlık ", foes, " -> ", _estructs.size() + _eunits.size(), " yanık bölge=", gen.scorched.size())


# ---------------------------------------------------------------- kurulum

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4a86c8")
	sky_mat.sky_horizon_color = Color("b9d4ea")
	sky_mat.ground_horizon_color = Color("b9d4ea")
	sky_mat.ground_bottom_color = Color("7fa6c4")
	var sky := Sky.new()
	sky.sky_material = sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.45
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 0.9
	_env.fog_enabled = true
	_env.fog_light_color = Color("a9c4dc")
	_env.fog_density = 0.0008

	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260.0
	add_child(sun)


func _setup_materials() -> void:
	# Tekrarlayan gürültü dokusu ve ondan türetilen normal haritası (arazi detayı, su dalgaları)
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = 0.03
	nz.fractal_octaves = 4
	var img: Image = nz.get_seamless_image(512, 512, false, false, 0.1, true)
	_detail_tex = ImageTexture.create_from_image(img)
	var nimg: Image = img.duplicate()
	nimg.bump_map_to_normal_map(5.0)
	_detail_normal = ImageTexture.create_from_image(nimg)

	_terrain_mat = ShaderMaterial.new()
	_terrain_mat.shader = load("res://shaders/terrain.gdshader")
	_terrain_mat.set_shader_parameter("fog_tex", fog.texture)
	_terrain_mat.set_shader_parameter("detail_tex", _detail_tex)
	_terrain_mat.set_shader_parameter("detail_normal", _detail_normal)

	var vs: Shader = load("res://shaders/vegetation.gdshader")
	_veg_trees = ShaderMaterial.new()
	_veg_trees.shader = vs
	_veg_trees.set_shader_parameter("fog_tex", fog.texture)
	_veg_trees.set_shader_parameter("sway", 0.35)
	_veg_grass = ShaderMaterial.new()
	_veg_grass.shader = vs
	_veg_grass.set_shader_parameter("fog_tex", fog.texture)
	_veg_grass.set_shader_parameter("sway", 1.0)
	_pine_mesh = Models.pine_mesh()
	_broad_mesh = Models.broad_mesh()
	_grass_mesh = Models.grass_mesh()


func _setup_water() -> void:
	_water = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	_water.mesh = plane
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("fog_tex", fog.texture)
	m.set_shader_parameter("wave_normal", _detail_normal)
	_water.material_override = m
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


# ---------------------------------------------------------------- arazi parçaları

func _step_for_ring(ring: int) -> int:
	if ring <= 2:
		return 1
	if ring <= 5:
		return 4
	return 8


func _update_chunks() -> void:
	var radius := clampi(int(cam.zoom / 110.0) + 3, 3, 9)
	var center := Vector2i(
		floori(cam.target.x / CHUNK_TILES),
		floori(cam.target.z / CHUNK_TILES))

	var wanted: Array = []
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var k := center + Vector2i(dx, dz)
			if k.x < 0 or k.y < 0 or k.x >= WORLD_CHUNKS or k.y >= WORLD_CHUNKS:
				continue
			wanted.append([maxi(absi(dx), absi(dz)), k])
	wanted.sort_custom(func(a, b): return a[0] < b[0])

	var keep := {}
	var t0 := Time.get_ticks_usec()
	for w in wanted:
		var k: Vector2i = w[1]
		keep[k] = true
		var step := _step_for_ring(w[0])
		var level := _veg_level_for_ring(w[0])
		var rec = chunks.get(k)
		if rec != null and rec["step"] == step:
			if rec["veg"] != level and Time.get_ticks_usec() - t0 <= BUILD_BUDGET_USEC:
				_set_vegetation(k, level)
			continue
		if Time.get_ticks_usec() - t0 > BUILD_BUDGET_USEC:
			continue
		_build_chunk(k, step, level)

	for k in chunks.keys():
		if not keep.has(k):
			chunks[k]["node"].queue_free()
			chunks.erase(k)


## Bitki örtüsü düzeyi: 2 = ağaç + çimen (çok yakın), 1 = sadece ağaç, 0 = yok.
func _veg_level_for_ring(ring: int) -> int:
	if ring <= 1:
		return 2
	if ring <= 3:
		return 1
	return 0


func _build_chunk(k: Vector2i, step: int, level: int) -> void:
	var mesh: ArrayMesh = gen.build_chunk(k.x, k.y, step)
	var rec = chunks.get(k)
	var mi: MeshInstance3D
	if rec != null:
		mi = rec["node"]
	else:
		mi = MeshInstance3D.new()
		mi.material_override = _terrain_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		chunks[k] = {"node": mi, "step": step, "veg": -1, "vnodes": []}
	mi.mesh = mesh
	chunks[k]["step"] = step
	_set_vegetation(k, level)


func _set_vegetation(k: Vector2i, level: int) -> void:
	var rec: Dictionary = chunks[k]
	for n in rec["vnodes"]:
		(n as Node).queue_free()
	rec["vnodes"] = []
	rec["veg"] = level
	if level <= 0:
		return
	var v: Dictionary = gen.vegetation(k.x, k.y, level >= 2)
	var host: Node3D = rec["node"]
	_add_multimesh(host, rec, _pine_mesh, _clear_home(v["pines"], 44.0), _veg_trees, level >= 2)
	_add_multimesh(host, rec, _broad_mesh, _clear_home(v["broads"], 44.0), _veg_trees, level >= 2)
	_add_multimesh(host, rec, _grass_mesh, v["tufts"], _veg_grass, false)


## Kalenin etrafındaki ağaçları temizler (yerleşim alanı).
func _clear_home(xfs: Array, radius: float) -> Array:
	var out: Array = []
	for xf: Transform3D in xfs:
		if Vector2(xf.origin.x - _home.x, xf.origin.z - _home.y).length() > radius:
			out.append(xf)
	return out


func _add_multimesh(host: Node3D, rec: Dictionary, mesh: Mesh, xfs: Array, mat: Material, shadows: bool) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in range(xfs.size()):
		mm.set_instance_transform(i, xfs[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(mi)
	(rec["vnodes"] as Array).append(mi)


# ---------------------------------------------------------------- can çubukları

func _setup_bars() -> void:
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = load("res://shaders/health_bar.gdshader")
	_bar_mat.render_priority = 10
	_bars_root = Node3D.new()
	_bars_root.name = "CanCubuklari"
	add_child(_bars_root)


func _attach_bar(e: Ent, size_mul: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 0.34)
	mi.mesh = q
	mi.material_override = _bar_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 20.0
	mi.set_instance_shader_parameter("size_mul", size_mul)
	_bars_root.add_child(mi)
	e.bar_mesh = mi
	_all.append(e)


func _bar_color(team: String, r: float) -> Color:
	if team != "player":
		return Color("ff4d6a")
	if r > 0.6:
		return Color("4ade80")
	if r > 0.3:
		return Color("fbbf24")
	return Color("f97316")


func _update_bars() -> void:
	_bar_mat.set_shader_parameter("bar_scale", clampf(0.5 + cam.zoom * 0.004, 0.7, 2.0))
	var bars_on: bool = cam.zoom < 420.0
	for e: Ent in _all:
		var m := e.bar_mesh
		m.visible = bars_on and e.node.is_visible_in_tree()
		if not m.visible:
			continue
		m.global_position = e.node.global_position + Vector3(0.0, e.bar_off, 0.0)
		var r := clampf(e.hp / e.max_hp, 0.0, 1.0)
		if r != e.bar_last:
			e.bar_last = r
			m.set_instance_shader_parameter("ratio", r)
			m.set_instance_shader_parameter("fill_color", _bar_color(e.team, r))


# ---------------------------------------------------------------- varlıklar

func _put(parent: Node3D, node: Node3D, x: float, z: float, yaw_deg: float = 0.0) -> Node3D:
	node.position = Vector3(x, gen.surface_y(x, z), z)
	node.rotation_degrees.y = yaw_deg
	parent.add_child(node)
	return node


func _make_ent(node: Node3D, kind: String, team: String, frac: float, nation: String) -> Ent:
	var s: Dictionary = UnitsData.KINDS[kind]
	var e := Ent.new()
	e.node = node
	e.base_scale = node.scale
	e.kind = kind
	e.team = team
	e.nation = nation
	e.structure = s.has("body_r")
	e.body_r = float(s.get("body_r", 0.0))
	e.atk_range = float(s["range"])
	e.dmg = float(s["dmg"])
	e.cd = float(s["cd"])
	e.cd_t = _rng.randf() * e.cd
	e.proj = String(s["proj"])
	e.max_hp = float(s["hp"])
	e.hp = e.max_hp * frac
	e.sight = float(s["sight"])
	e.speed = float(s["speed"])
	e.naval = bool(s.get("naval", false))
	e.bar_off = float(s["bar_off"])
	e.hit_h = 4.0 if e.structure else (2.5 if e.naval else 1.2)
	e.fire_h = 8.0 if e.structure else (3.0 if e.naval else 1.8)
	_attach_bar(e, float(s["bar_size"]))
	return e


func _add_unit(node: Node3D, kind: String) -> Ent:
	var e := _make_ent(node, kind, "player", 1.0, "")
	var s: Dictionary = UnitsData.KINDS[kind]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffe08a")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = float(s["ring"])
	torus.outer_radius = float(s["ring"]) + 0.22
	ring.mesh = torus
	ring.material_override = mat
	ring.position = Vector3(0, 0.15, 0)
	ring.visible = false
	node.add_child(ring)
	e.ring = ring
	e.home = node.position
	_units.append(e)
	Models.apply_era(node, _era)
	return e


func _add_struct(node: Node3D, kind: String, team: String, frac: float, nation: String) -> Ent:
	var e := _make_ent(node, kind, team, frac, nation)
	if team == "player":
		_pstructs.append(e)
	else:
		_estructs.append(e)
	return e


func _add_enemy(node: Node3D, kind: String, frac: float, nation: String) -> Ent:
	var e := _make_ent(node, kind, "enemy", frac, nation)
	_eunits.append(e)
	return e


func _place_world(spawn: Vector2) -> void:
	var root := Node3D.new()
	root.name = "World"
	add_child(root)
	_world_root = root
	var blue := Color("3d8bff")

	if not _nomad:
		_add_struct(_put(root, _struct_model("castle", blue, _era, _style), spawn.x, spawn.y), "castle", "player", 1.0, "")
		for o in [Vector2(-16, -16), Vector2(16, -16), Vector2(-16, 16), Vector2(16, 16)]:
			_add_struct(_put(root, _struct_model("tower", blue, _era, _style), spawn.x + o.x, spawn.y + o.y), "tower", "player", 1.0, "")
		# Hazır kışla (hemen asker üretebilmek için)
		_add_struct(_put(root, _struct_model("barracks", blue, _era, _style), spawn.x + 30, spawn.y + 22, 180.0), "barracks", "player", 1.0, "")
	# Kaynak noktaları: işçiler seçilip bunlara dokunulunca çalışmaya başlar. Petrol Çağ III'ten itibaren açılır.
	_add_node(root, "food", "Tarla", Models.farm(), spawn + Vector2(-46, 6), 0.30, 0)
	_add_node(root, "food", "Tarla", Models.farm(), spawn + Vector2(-46, 18), 0.30, 0)
	_add_node(root, "wood", "Odun kampı", Models.lumber_camp(), spawn + Vector2(58, 30), 0.28, 0)
	_add_node(root, "gold", "Altın madeni", Models.mine(Color("f0c64a")), spawn + Vector2(-66, -42), 0.20, 0)
	_add_node(root, "silver", "Gümüş madeni", Models.mine(Color("dfe6ee")), spawn + Vector2(-40, -64), 0.08, 0)
	_add_node(root, "oil", "Petrol kulesi", Models.derrick(), spawn + Vector2(66, -48), 0.10, UnitsData.OIL_ERA)

	# Başlangıç: 2 işçi + 1 izci (Göçebe kuralında 3 işçi). Askerler kışlada üretilir (test için --army).
	if _nomad:
		for i in range(3):
			_add_unit(_put(root, Models.worker(blue), spawn.x - 6 + i * 4.0, spawn.y + 6, 180.0), "worker")
	else:
		for i in range(2):
			_add_unit(_put(root, Models.worker(blue), spawn.x - 6 + i * 4.0, spawn.y + 22, 180.0), "worker")
		_add_unit(_put(root, Models.scout(blue), spawn.x + 6, spawn.y + 30), "scout")
	if _army_arg:
		for i in range(5):
			_add_unit(_put(root, Models.spearman(blue), spawn.x - 8 + i * 2.4, spawn.y + 27, 180.0), "spearman")
		for i in range(4):
			_add_unit(_put(root, Models.archer(blue), spawn.x - 7 + i * 2.4, spawn.y + 31, 180.0), "archer")
		if _era >= 2:
			for i in range(3):
				_add_unit(_put(root, Models.tank(blue), spawn.x + 28, spawn.y - 6 + i * 7, 90.0), "tank")

	_add_nation(root, "Kızıl", Color("ff4d6a"), spawn + Vector2(70, -30), "west")
	_add_nation(root, "Zümrüt", Color("35c98a"), gen.find_land_near(spawn + Vector2(260, -140)), "east")
	_add_nation(root, "Mor", Color("a478ff"), gen.find_land_near(spawn + Vector2(-200, 220)), "mideast")
	_add_nation(root, "Turkuaz", Color("2fc4d6"), gen.find_land_near(spawn + Vector2(130, 330)), "meso")

	# Gemiler Çağ II'den itibaren üretilir; doğdukları kıyı noktası:
	_dock = gen.find_water_near(spawn)


## Kaynak noktası ekler. pos arazi üzerinde kara değilse en yakın düz kara bulunur.
func _add_node(root: Node3D, kind: String, title: String, model: Node3D, pos: Vector2, rate: float, min_era: int) -> void:
	var p := pos
	if gen.height_at(p.x, p.y) < 0.06:
		p = gen.find_land_near(pos)
	var n := RNode.new()
	n.kind = kind
	n.title = title
	n.rate = rate
	n.min_era = min_era
	n.node = _put(root, model, p.x, p.y)
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 48
	l.pixel_size = 0.012
	l.outline_size = 12
	l.modulate = Color("ffffff")
	l.outline_modulate = Color(0.05, 0.05, 0.1, 1.0)
	l.position = Vector3(0, 7.0, 0)
	n.node.add_child(l)
	n.label = l
	_nodes.append(n)
	_update_node_label(n)


func _update_node_label(n: RNode) -> void:
	n.label.text = "%s %d/%d" % [n.title, n.workers, n.slots]


## Yapı modeli: çağ katmanı (ahşap/taş/sanayi/modern) ve mimari stile (Batı, Doğu, Orta Doğu, Mezoamerika) göre.
func _struct_model(kind: String, color: Color, era: int, style: String) -> Node3D:
	match kind:
		"castle": return Models.castle(color, era, style)
		"tower": return Models.tower(color, era, style)
		"house": return Models.house(color, era, style)
		"barracks": return Models.barracks(color, era, style)
		"stable": return Models.stable(color, era, style)
		"siege": return Models.siege_factory(color, era, style)
		"dock": return Models.dock(color, era, style)
		"lookout": return Models.lookout(color, era, style)
	return Models.house(color, era, style)


func _add_nation(root: Node3D, nation_name: String, color: Color, p: Vector2, style: String) -> void:
	var structures := Node3D.new()
	structures.name = nation_name + "_yapilar"
	root.add_child(structures)
	var units := Node3D.new()
	units.name = nation_name + "_birlikler"
	root.add_child(units)

	# Rakip canları, can çubuğunu göstermek için kısmen hasarlı başlıyor.
	_add_struct(_put(structures, _struct_model("castle", color, 1, style), p.x, p.y, -90.0), "castle", "enemy", _rng.randf_range(0.7, 1.0), nation_name)
	for dz in [-12, 12]:
		_add_struct(_put(structures, _struct_model("tower", color, 1, style), p.x - 14, p.y + dz), "tower", "enemy", _rng.randf_range(0.5, 1.0), nation_name)
	for i in range(3):
		_add_enemy(_put(units, Models.spearman(color), p.x - 22, p.y - 5 + i * 2.4, -90.0), "spearman", _rng.randf_range(0.5, 1.0), nation_name)
	for i in range(3):
		_add_enemy(_put(units, Models.archer(color), p.x - 26, p.y - 4 + i * 2.4, -90.0), "archer", _rng.randf_range(0.5, 1.0), nation_name)

	structures.visible = false
	units.visible = false
	_nations.append({"name": nation_name, "structures": structures,
		"units": units, "pos": Vector3(p.x, 0.0, p.y), "found": false})


# ---------------------------------------------------------------- sis ve keşif

func _update_fog() -> void:
	var obs: Array = []
	for e: Ent in _pstructs:
		obs.append({"pos": e.node.global_position, "radius": e.sight})
	for e: Ent in _units:
		obs.append({"pos": e.node.global_position, "radius": e.sight})
	fog.update(obs)

	for nat in _nations:
		var st := fog.state_at(nat["pos"])
		(nat["structures"] as Node3D).visible = st >= 128
		for u in (nat["units"] as Node3D).get_children():
			(u as Node3D).visible = fog.state_at((u as Node3D).global_position) == 255
		if st >= 128 and not nat["found"]:
			nat["found"] = true
			hud.show_toast("Yeni ulus keşfedildi: %s" % nat["name"])
			var names: PackedStringArray = []
			for n in _nations:
				if n["found"]:
					names.append(String(n["name"]))
			hud.set_nations_text("Keşfedilen uluslar: " + ", ".join(names))


# ---------------------------------------------------------------- seçim

func _selected_count() -> int:
	var n := 0
	for u: Ent in _units:
		if u.selected:
			n += 1
	return n


func _set_selected(u: Ent, on: bool) -> void:
	if on and _sel_struct != null:
		_clear_struct_selection()
	var was := u.selected
	u.selected = on
	u.ring.visible = on
	_set_range_ring(u, on)
	if on and not was:
		# Seçim animasyonu: halka büyüyerek belirir
		u.ring.scale = Vector3.ONE * 0.3
		var tw := create_tween()
		tw.tween_property(u.ring, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _select_all(on: bool) -> void:
	for u: Ent in _units:
		_set_selected(u, on)
	_refresh_hint()


func _select_only_kind(kind: String) -> void:
	for u: Ent in _units:
		_set_selected(u, u.kind == kind)
	_refresh_hint()


func _refresh_hint() -> void:
	var n := _selected_count()
	var txt := ""
	if n == 0:
		txt = "Bir birliğe dokun ya da Ordu sekmesinden seç"
	else:
		txt = "%d birlik seçili: yere dokun = git, düşmana dokun = saldır" % n
	if _select_mode:
		txt += "  [kutu seçim açık]"
	hud.set_hint(txt)


func _select_in_rect(rect: Rect2) -> void:
	for u: Ent in _units:
		var inside := false
		if not cam.is_position_behind(u.node.global_position):
			inside = rect.has_point(cam.unproject_position(u.node.global_position + Vector3(0, 1.0, 0)))
		_set_selected(u, inside)
	_refresh_hint()


# ---------------------------------------------------------------- yapı seçimi ve yükseltme

func _select_struct(e: Ent) -> void:
	if _sel_struct == e:
		_clear_struct_selection()
		return
	_select_all(false)
	_clear_struct_selection()
	_sel_struct = e
	if e.ring == null:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("ffe08a")
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		var inner := e.body_r + 1.6
		t.inner_radius = inner
		t.outer_radius = inner + 0.4
		ring.mesh = t
		ring.material_override = mat
		ring.position = Vector3(0, 0.2, 0)
		e.node.add_child(ring)
		e.ring = ring
	e.ring.visible = true
	e.ring.scale = Vector3.ONE * 0.4
	var tw := create_tween()
	tw.tween_property(e.ring, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_range_ring(e, true)
	_refresh_upgrade_panel()


func _clear_struct_selection() -> void:
	if _sel_struct != null and _sel_struct.ring != null:
		_sel_struct.ring.visible = false
	if _sel_struct != null:
		_set_range_ring(_sel_struct, false)
	_sel_struct = null
	_rally_mode = false
	hud.hide_struct()


## Seçilen birlik/yapının saldırı menzilini yerde ince bir halka olarak gösterir.
func _set_range_ring(e: Ent, on: bool) -> void:
	if e.atk_range <= 0.0 or not is_instance_valid(e.node):
		return
	if not on:
		if e.range_ring != null:
			e.range_ring.visible = false
		return
	var r := e.atk_range + e.body_r
	if e.range_ring == null or absf(e.ring_range - r) > 0.01:
		if e.range_ring != null:
			e.range_ring.queue_free()
		var sc := maxf(e.node.scale.x, 0.01)
		var w := 0.12 + r * 0.004
		var t := TorusMesh.new()
		t.inner_radius = (r - w) / sc
		t.outer_radius = (r + w) / sc
		t.rings = 48
		t.ring_segments = 4
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		m.albedo_color = Color(0.55, 0.82, 1.0, 0.7)
		var ring := MeshInstance3D.new()
		ring.mesh = t
		ring.material_override = m
		ring.position = Vector3(0, 0.6, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.node.add_child(ring)
		e.range_ring = ring
		e.ring_range = r
	e.range_ring.visible = true


func _struct_title(e: Ent) -> String:
	return String((UnitsData.KINDS[e.kind] as Dictionary).get("title", e.kind))


func _upgrade_cost(e: Ent) -> Dictionary:
	var b: Dictionary = UPGRADE_BASE[e.kind]
	var f := pow(1.7, float(e.level - 1))
	var out := {}
	for k in b:
		out[k] = roundf(float(b[k]) * f)
	return out


func _can_afford(c: Dictionary) -> bool:
	for k in c:
		if _res[k] < float(c[k]):
			return false
	return true


func _spend(c: Dictionary) -> void:
	for k in c:
		_res[k] -= float(c[k])


## "50Y 20O 30A" gibi kısa maliyet metni (Y yiyecek, O odun, A altın, G gümüş, P petrol).
func _cost_text(c: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in UnitsData.RES_KEYS:
		if c.has(k) and float(c[k]) > 0.0:
			parts.append("%d%s" % [int(c[k]), UnitsData.RES_SHORT[k]])
	return " ".join(parts)


## Seçili yapı paneli: bilgi, yükseltme (kule/kale), üretim düğmeleri, kuyruk ve toplanma noktası.
func _refresh_struct_panel() -> void:
	var e := _sel_struct
	if e == null or not e.alive:
		hud.hide_struct()
		return
	var s: Dictionary = UnitsData.KINDS[e.kind]
	var stats := "Can %d/%d" % [int(e.hp), int(e.max_hp)]
	if e.dmg > 0.0:
		stats += " · Hasar %.0f · Menzil %.0f" % [e.dmg, e.atk_range]
	if s.has("pop"):
		stats += " · +%d nüfus" % int(s["pop"])
	var info := {"title": "%s · Seviye %d" % [_struct_title(e), e.level], "stats": stats}
	if UPGRADE_BASE.has(e.kind):
		info["up_visible"] = true
		if e.level >= MAX_LEVEL:
			info["up_text"] = "En üst\nseviye"
			info["up_enabled"] = false
		else:
			var c := _upgrade_cost(e)
			info["up_text"] = "Yükselt\n" + _cost_text(c)
			info["up_enabled"] = _can_afford(c)
	if s.has("trains"):
		var train: Array = []
		for kind in s["trains"]:
			if kind in UnitsData.TRAIN[_era]:
				var ks: Dictionary = UnitsData.KINDS[kind]
				train.append(["%s\n%s" % [ks["title"], _cost_text(_unit_cost(kind))], "q:" + kind])
		info["train"] = train
		var q: Array = []
		for item in e.queue:
			var pct := 100.0 * (1.0 - float(item["left"]) / float(item["total"]))
			q.append("%s %d%%" % [UnitsData.KINDS[item["kind"]]["title"], int(pct)])
		info["queue"] = q
		info["rally"] = true
	hud.show_struct(info)


func _refresh_upgrade_panel() -> void:
	_refresh_struct_panel()


## Seçili yapıyı yükseltir: can +%30, hasar +%25, menzil +%6, görüş +%5, boyut +%5.
func _do_upgrade() -> void:
	var e := _sel_struct
	if e == null or not e.alive or not UPGRADE_BASE.has(e.kind):
		return
	if e.level >= MAX_LEVEL:
		hud.show_toast("%s zaten en üst seviyede" % _struct_title(e))
		return
	var c := _upgrade_cost(e)
	if not _can_afford(c):
		hud.show_toast("Yetersiz kaynak")
		return
	_spend(c)
	e.level += 1
	var inc := e.max_hp * 0.3
	e.max_hp += inc
	e.hp += inc
	e.dmg *= 1.25
	e.atk_range *= 1.06
	e.sight *= 1.05
	e.base_scale *= 1.05
	if e.tween != null:
		e.tween.kill()
	e.tween = create_tween()
	e.tween.tween_property(e.node, "scale", e.base_scale * 1.2, 0.12)
	e.tween.tween_property(e.node, "scale", e.base_scale, 0.2)
	e.ring_range = -1.0
	_set_range_ring(e, true)  # menzil büyüdü, halkayı yenile
	_spawn_burst(e.node.global_position + Vector3(0, e.hit_h + 2.0, 0), "player")
	hud.show_toast("%s seviye %d oldu" % [_struct_title(e), e.level])
	_refresh_upgrade_panel()


# ---------------------------------------------------------------- emirler

func _order_move(hit: Vector3) -> void:
	var sel: Array = []
	for u: Ent in _units:
		if u.selected:
			sel.append(u)
	if sel.is_empty():
		return
	var offs := _formation_offsets(sel.size())
	for i in range(sel.size()):
		var u: Ent = sel[i]
		_release_job(u)
		_cancel_build(u)
		u.attack = null
		u.goal = Vector3(hit.x + offs[i].x, 0.0, hit.z + offs[i].z)
		u.home = u.goal
		_add_line(u.node.position, u.goal, COL_MOVE)
	_spawn_marker(hit, COL_MOVE)


## Diziliş: line (çizgi), column (sütun), square (kare savunma düzeni), box (dağınık ızgara).
func _formation_offsets(n: int) -> Array:
	var out: Array = []
	match _formation:
		"line":
			for i in range(n):
				out.append(Vector3((float(i) - (n - 1) * 0.5) * 3.2, 0.0, 0.0))
		"column":
			for i in range(n):
				out.append(Vector3(0.0, 0.0, (float(i) - (n - 1) * 0.5) * 3.2))
		"square":
			var h := maxf(3.5, float(n) * 0.9)
			for i in range(n):
				var t := float(i) / float(maxi(n, 1)) * 4.0
				var side := int(t)
				var f := t - float(side)
				match side:
					0: out.append(Vector3(-h + f * 2.0 * h, 0.0, -h))
					1: out.append(Vector3(h, 0.0, -h + f * 2.0 * h))
					2: out.append(Vector3(h - f * 2.0 * h, 0.0, h))
					_: out.append(Vector3(-h, 0.0, h - f * 2.0 * h))
		_:
			var cols := int(ceil(sqrt(float(n))))
			var rows := int(ceil(float(n) / float(cols)))
			for i in range(n):
				out.append(Vector3((float(i % cols) - (cols - 1) * 0.5) * 3.5, 0.0, (float(i / cols) - (rows - 1) * 0.5) * 3.5))
	return out


func _order_attack(target: Ent) -> void:
	if _peace_left > 0.0:
		hud.show_toast("Barış süresi: %d:%02d" % [int(_peace_left) / 60, int(_peace_left) % 60])
		return
	var any := false
	for u: Ent in _units:
		if u.selected and u.dmg > 0.0:
			u.attack = target
			u.goal = null
			any = true
			_add_line(u.node.position, target.node.global_position, COL_ATTACK)
	if any:
		_spawn_marker(target.node.global_position, COL_ATTACK)
	else:
		hud.show_toast("Seçili birlikler saldıramaz")


func _stop_selected() -> void:
	for u: Ent in _units:
		if u.selected:
			_release_job(u)
			_cancel_build(u)
			u.goal = null
			u.attack = null
			u.home = u.node.position
	_refresh_hint()


# ---------------------------------------------------------------- hareket

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Arazi etkisi: ormanda ağır birlikler yavaşlar, sığ suda herkes yavaşlar.
func _speed_factor(u: Ent) -> float:
	if u.naval:
		return 1.0
	var p := u.node.position
	var h := gen.height_at(p.x, p.z)
	var f := 1.0
	if h < 0.012:
		f = 0.5  # sığlık/çamur
	var cls: String = UnitsData.CLS.get(u.kind, "")
	if (cls == "heavy_cav" or cls == "siege") and gen.biome_at(p.x, p.z, h) == WorldGen.FOREST:
		f *= 0.35  # tank/ağır süvari/top ormanda neredeyse geçemez
	return f


func _move_units(delta: float) -> void:
	var blocked := false
	var blocked_naval := false
	var cliff := false
	for u: Ent in _units:
		var goal = u.goal
		_auto_stance(u)
		if u.attack != null:
			if not u.attack.alive:
				u.attack = null
			else:
				var tp := u.attack.node.global_position
				var reach := u.atk_range * 0.85 + u.attack.body_r
				goal = tp if _flat_dist(u.node.global_position, tp) > reach else null
		if goal == null:
			continue
		var node := u.node
		var to: Vector3 = (goal as Vector3) - node.position
		to.y = 0.0
		var dist := to.length()
		if dist < 0.8:
			if u.attack == null:
				u.goal = null
				if u.home == null:
					u.home = node.position
			continue
		var dir := to / dist
		var step := minf(u.speed * _speed_factor(u) * delta, dist)
		var nx := node.position.x + dir.x * step
		var nz := node.position.z + dir.z * step
		var h := gen.height_at(nx, nz)
		# Kara birlikleri derin suya, gemiler karaya giremez (sığlıkta yürünür)
		if (u.naval and h > -0.04) or (not u.naval and h < -0.03):
			u.goal = null
			u.attack = null
			blocked = true
			blocked_naval = u.naval
			continue
		# Uçurum: çok dik yamaçlar geçit vermez
		if not u.naval and step > 0.001:
			var slope := absf(gen.surface_y(nx, nz) - node.position.y) / step
			if slope > 2.6:
				u.goal = null
				u.attack = null
				cliff = true
				continue
		var ny := 0.1 if u.naval else gen.surface_y(nx, nz)
		node.position = Vector3(nx, ny, nz)
		node.rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z))
	if blocked:
		hud.show_toast("Gemiler karaya giremez" if blocked_naval else "Birlikler derin suya giremez")
	elif cliff:
		hud.show_toast("Geçit yok: uçurum")


## Duruş: Saldırgan görüş alanındakini kovalar, Savunma bölgesini korur, Sabit yerinden kıpırdamaz.
func _auto_stance(u: Ent) -> void:
	if u.dmg <= 0.0 or u.goal != null or u.attack != null or u.stance == "hold" or _peace_left > 0.0:
		return
	var pos := u.node.global_position
	if u.home == null:
		u.home = pos
	var foes := _eunits + _estructs
	if u.stance == "aggressive":
		var f := _nearest_target(pos, u.sight * 1.4, foes, true, false)
		if f != null:
			u.attack = f
	else:
		var hp: Vector3 = u.home
		var f := _nearest_target(hp, 22.0, foes, true, false)
		if f != null:
			u.attack = f
		elif _flat_dist(pos, hp) > 4.0:
			u.goal = hp  # görev bitti, yerine dön


# ---------------------------------------------------------------- savaş

## Menzildeki en yakın hedef. ambush: piyade ormandaysa 10 karodan uzaktan görülemez (pusu).
func _nearest_target(apos: Vector3, rng: float, defenders: Array, need_visible: bool, ambush: bool = true) -> Ent:
	var best: Ent = null
	var best_d := INF
	for d: Ent in defenders:
		if not d.alive:
			continue
		if need_visible and not d.node.is_visible_in_tree():
			continue
		var dist := _flat_dist(apos, d.node.global_position) - d.body_r
		if dist > rng or dist >= best_d:
			continue
		if ambush and dist > 10.0 and _hidden_in_forest(d):
			continue
		best_d = dist
		best = d
	return best


func _hidden_in_forest(d: Ent) -> bool:
	var cls: String = UnitsData.CLS.get(d.kind, "")
	if cls != "heavy_inf" and cls != "light_inf":
		return false
	var p := d.node.global_position
	return gen.biome_at(p.x, p.z, gen.height_at(p.x, p.z)) == WorldGen.FOREST


## Yüksek zemin: yukarıdaki menzilli birim daha uzağa ve daha sert vurur.
func _height_bonus(a: Ent, tgt: Ent) -> float:
	return a.node.global_position.y - tgt.node.global_position.y


func _fire_phase(attackers: Array, defenders: Array, delta: float, is_player: bool) -> void:
	if _peace_left > 0.0:
		return  # barış süresinde kimse ateş etmez
	for a: Ent in attackers.duplicate():
		if not a.alive or a.dmg <= 0.0:
			continue
		a.cd_t = maxf(0.0, a.cd_t - delta)
		var apos := a.node.global_position
		var tgt: Ent = a.attack
		if tgt != null and not tgt.alive:
			a.attack = null
			tgt = null
		if tgt != null:
			var dd := _flat_dist(apos, tgt.node.global_position) - tgt.body_r
			var rng_eff := a.atk_range
			if a.proj != "":
				rng_eff *= 1.0 + clampf(_height_bonus(a, tgt) * 0.012, -0.1, 0.25)
			if dd > rng_eff:
				continue  # önce yaklaşmalı
		else:
			var reach := a.atk_range
			if a.proj != "":
				reach *= 1.1  # tepeden bakınca bonus için biraz geniş tara
			tgt = _nearest_target(apos, reach, defenders, is_player, not is_player)
			if tgt == null:
				continue
			if a.proj != "":
				var dd2 := _flat_dist(apos, tgt.node.global_position) - tgt.body_r
				if dd2 > a.atk_range * (1.0 + clampf(_height_bonus(a, tgt) * 0.012, -0.1, 0.25)):
					continue
		if a.cd_t > 0.0:
			continue
		a.cd_t = a.cd
		if not a.structure:
			var d := tgt.node.global_position - apos
			a.node.rotation_degrees.y = rad_to_deg(atan2(d.x, d.z))
			_attack_anim(a)
		_launch(a, tgt)


func _launch(a: Ent, tgt: Ent) -> void:
	# Taş-kâğıt-makas: saldıran sınıfın hedef sınıfa çarpanı (bkz. units_data.gd MULT)
	var dmg := a.dmg * UnitsData.multiplier(a.kind, tgt.kind)
	if a.proj != "":
		dmg *= 1.0 + clampf(_height_bonus(a, tgt) * 0.02, -0.15, 0.3)  # yüksek zemin bonusu
	if a.proj == "":
		_hit(tgt, dmg)  # yakın dövüş
		return
	var from := a.node.global_position + Vector3(0.0, a.fire_h, 0.0)
	var to := tgt.node.global_position + Vector3(0.0, tgt.hit_h, 0.0)
	var node := MeshInstance3D.new()
	var speed := 38.0
	var arc := 0.14
	if a.proj == "bullet" or a.proj == "shell":
		fx.muzzle(from, to - from, a.proj == "shell")  # namlu alevi ve barut dumanı
	if a.proj == "arrow":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.09, 0.09, 1.5)
		node.mesh = bm
		node.material_override = _flat_mat(Color("e8d9a8"))
	elif a.proj == "bullet":
		var bl := SphereMesh.new()
		bl.radius = 0.12
		bl.height = 0.24
		node.mesh = bl
		node.material_override = _flat_mat(Color("ffd36b"))
		speed = 95.0
		arc = 0.02
	else:
		var sm := SphereMesh.new()
		sm.radius = 0.3
		sm.height = 0.6
		node.mesh = sm
		node.material_override = _flat_mat(Color("2b2f3a"))
		speed = 70.0
		arc = 0.05
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	node.global_position = from
	var dist := from.distance_to(to)
	if a.proj == "shell":
		fx.attach_trail(node)
	_projectiles.append({"node": node, "from": from, "to": to, "ent": tgt, "dmg": dmg, "proj": a.proj,
		"t": 0.0, "dur": maxf(0.15, dist / speed), "arc": dist * arc})


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	return m


func _update_projectiles(delta: float) -> void:
	for p in _projectiles.duplicate():
		var ent: Ent = p["ent"]
		p["t"] += delta
		if ent.alive:
			p["to"] = ent.node.global_position + Vector3(0.0, ent.hit_h, 0.0)
		var k := clampf(float(p["t"]) / float(p["dur"]), 0.0, 1.0)
		var from: Vector3 = p["from"]
		var to: Vector3 = p["to"]
		var pos := from.lerp(to, k) + Vector3(0.0, float(p["arc"]) * sin(k * PI), 0.0)
		var node: Node3D = p["node"]
		var prev := node.global_position
		node.global_position = pos
		if pos.distance_to(prev) > 0.02:
			node.look_at(pos + (pos - prev), Vector3.UP)
		if k >= 1.0:
			var pk: String = p["proj"]
			if pk == "shell" or pk == "bullet":
				fx.impact(to, pk)  # çarpma tozu / toprak fırlaması
			if ent.alive:
				_hit(ent, float(p["dmg"]))
			node.queue_free()
			_projectiles.erase(p)


func _hit(ent: Ent, amount: float) -> void:
	if not ent.alive:
		return
	ent.hp = maxf(0.0, ent.hp - amount)
	_hit_fx(ent, amount)
	if ent.hp <= 0.0:
		_kill(ent)


## Saldıran birliğin hareketi: yakın dövüşte öne eğilir, menzilli atışta geriye sekmesi.
func _attack_anim(a: Ent) -> void:
	var lean := 24.0 if a.proj == "" else -10.0
	var tw := create_tween()
	tw.tween_property(a.node, "rotation_degrees:x", lean, 0.08)
	tw.tween_property(a.node, "rotation_degrees:x", 0.0, 0.16)


## Vuruş geri bildirimi: kısa büyüme, uçan hasar yazısı ve kıvılcım.
func _hit_fx(ent: Ent, amount: float) -> void:
	if ent.tween != null:
		ent.tween.kill()
		ent.node.scale = ent.base_scale
	ent.tween = create_tween()
	ent.tween.tween_property(ent.node, "scale", ent.base_scale * 1.14, 0.05)
	ent.tween.tween_property(ent.node, "scale", ent.base_scale, 0.12)
	if cam.zoom > 320.0 or _fx_count > 30:
		return
	var pos := ent.node.global_position
	_spawn_damage_text(pos + Vector3(0, ent.bar_off, 0), amount, ent.team)
	_spawn_burst(pos + Vector3(0, ent.hit_h, 0), ent.team)


func _spawn_damage_text(pos: Vector3, amount: float, team: String) -> void:
	var l := Label3D.new()
	l.text = "-%d" % int(round(amount))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.004 + cam.zoom * 0.00006
	l.font_size = 64
	l.outline_size = 14
	l.modulate = Color("ffd7a0") if team == "player" else Color("ffffff")
	l.outline_modulate = Color(0.05, 0.05, 0.1, 1.0)
	l.shaded = false
	add_child(l)
	l.global_position = pos
	_fx_count += 1
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 3.5, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(func():
		_fx_count -= 1
		l.queue_free())


func _spawn_burst(pos: Vector3, team: String) -> void:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _flat_mat(Color("ff6b6b") if team != "player" else Color("ffb454"))
	p.mesh = sm
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 9
	p.lifetime = 0.45
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -16.0, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.global_position = pos
	p.emitting = true
	_fx_count += 1
	get_tree().create_timer(0.8).timeout.connect(func():
		_fx_count -= 1
		p.queue_free())


func _kill(ent: Ent) -> void:
	ent.alive = false
	if _sel_struct == ent:
		_clear_struct_selection()
	_release_job(ent)
	_units.erase(ent)
	_pstructs.erase(ent)
	_eunits.erase(ent)
	_estructs.erase(ent)
	_all.erase(ent)
	for u: Ent in _units:
		if u.attack == ent:
			u.attack = null
	if ent.bar_mesh:
		ent.bar_mesh.queue_free()
	# Ölüm animasyonu: birlik yere yıkılıp küçülür, yapı çöker.
	if ent.tween != null:
		ent.tween.kill()
	if ent.ring:
		ent.ring.visible = false
	if ent.threat_ring:
		ent.threat_ring.visible = false
	var node := ent.node
	if ent.fire != null:
		ent.fire.queue_free()
		ent.fire = null
	var tw := create_tween()
	if ent.structure:
		tw.tween_property(node, "scale", Vector3(ent.base_scale.x, 0.04, ent.base_scale.z), 1.0)
		_spawn_burst(node.global_position + Vector3(0, 3, 0), "enemy")
		fx.rubble(node.global_position, maxf(ent.body_r, 2.0), node.global_position.y)  # kalıntılar bir süre durur
	else:
		tw.tween_property(node, "rotation_degrees:z", 85.0, 0.22)
		tw.tween_property(node, "scale", Vector3.ZERO, 0.35)
		fx.puff(node.global_position + Vector3(0, 0.5, 0), Color(0.5, 0.45, 0.38), 5, 0.8, 0.3, 2.0)
	tw.tween_callback(node.queue_free)
	if ent.structure and ent.kind == "castle":
		hud.show_toast("%s kalesi yıkıldı!" % ent.nation if ent.nation != "" else "Kaleniz yıkıldı!")


## Test: H tuşu seçili birliklere azami canlarının %25'i kadar hasar verir.
func _damage_selected() -> void:
	for u: Ent in _units.duplicate():
		if u.selected:
			_hit(u, u.max_hp * 0.25)
	_refresh_hint()


# ---------------------------------------------------------------- saldırı hedefi işareti

## Oyuncu birliklerinin saldırdığı rakibin altında kırmızı, nabız atan bir halka gösterir.
func _update_threat_rings(delta: float) -> void:
	_threat_t += delta
	for e: Ent in _eunits + _estructs:
		var attacked := false
		for u: Ent in _units:
			if u.attack == e:
				attacked = true
				break
		if attacked and e.threat_ring == null:
			var ring := MeshInstance3D.new()
			var t := TorusMesh.new()
			var inner := (maxf(e.body_r, 1.0) + 1.0) / maxf(e.base_scale.x, 0.01)
			t.inner_radius = inner
			t.outer_radius = inner + 0.35 / maxf(e.base_scale.x, 0.01)
			ring.mesh = t
			ring.material_override = _flat_mat(Color(0.8, 0.1, 0.2))
			ring.position = Vector3(0, 0.25, 0)
			e.node.add_child(ring)
			e.threat_ring = ring
		if e.threat_ring != null:
			e.threat_ring.visible = attacked
			if attacked:
				e.threat_ring.scale = Vector3.ONE * (1.0 + 0.1 * sin(_threat_t * 8.0))


# ---------------------------------------------------------------- emir göstergeleri (bir kez oynar)

func _setup_paths() -> void:
	_path_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _path_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _add_line(a: Vector3, b: Vector3, col: Color) -> void:
	_lines.append({"a": a, "b": b, "col": col, "t": 0.0})


func _update_lines(delta: float) -> void:
	if _lines.is_empty():
		if _path_mesh.get_surface_count() > 0:
			_path_mesh.clear_surfaces()
		return
	_path_mesh.clear_surfaces()
	var width := maxf(0.12, cam.zoom * 0.0011)
	var step := maxf(1.6, width * 9.0)
	var began := false
	for i in range(_lines.size() - 1, -1, -1):
		var l: Dictionary = _lines[i]
		l["t"] += delta
		if float(l["t"]) > LINE_LIFE:
			_lines.remove_at(i)
			continue
		var alpha := clampf((LINE_LIFE - float(l["t"])) / 0.5, 0.0, 1.0) * 0.95
		var col: Color = l["col"]
		col.a = alpha
		var a: Vector3 = l["a"]
		var b: Vector3 = l["b"]
		var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var length := flat.length()
		if length < 1.0:
			continue
		if not began:
			_path_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			began = true
		var dir := flat / length
		var side := Vector3(-dir.z, 0.0, dir.x) * (width * 0.5)
		var d := 0.0
		var on := true
		while d < length:
			var d2 := minf(d + step, length)
			if on:
				var p0 := a + dir * d
				var p1 := a + dir * d2
				p0.y = maxf(gen.surface_y(p0.x, p0.z), 0.0) + 0.6
				p1.y = maxf(gen.surface_y(p1.x, p1.z), 0.0) + 0.6
				_ribbon(p0, p1, side, col)
			d = d2
			on = not on
		var e := Vector3(b.x, maxf(gen.surface_y(b.x, b.z), 0.0) + 0.7, b.z)
		var s := width * 1.8
		_ribbon(e - Vector3(0, 0, s), e + Vector3(0, 0, s), Vector3(s, 0, 0), col)
	if began:
		_path_mesh.surface_end()


func _ribbon(p0: Vector3, p1: Vector3, side: Vector3, col: Color) -> void:
	_path_mesh.surface_set_color(col)
	_path_mesh.surface_add_vertex(p0 - side)
	_path_mesh.surface_add_vertex(p0 + side)
	_path_mesh.surface_add_vertex(p1 + side)
	_path_mesh.surface_add_vertex(p0 - side)
	_path_mesh.surface_add_vertex(p1 + side)
	_path_mesh.surface_add_vertex(p1 - side)


func _alpha_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	return m


func _spawn_marker(hit: Vector3, col: Color) -> void:
	var root := Node3D.new()
	root.position = Vector3(hit.x, maxf(gen.surface_y(hit.x, hit.z), 0.0) + 0.3, hit.z)
	add_child(root)

	var ma := _alpha_mat(col)
	var ring_a := MeshInstance3D.new()
	var ta := TorusMesh.new()
	ta.inner_radius = 1.2
	ta.outer_radius = 1.45
	ring_a.mesh = ta
	ring_a.material_override = ma
	root.add_child(ring_a)

	var mb := _alpha_mat(col)
	var ring_b := MeshInstance3D.new()
	var tb := TorusMesh.new()
	tb.inner_radius = 1.2
	tb.outer_radius = 1.4
	ring_b.mesh = tb
	ring_b.material_override = mb
	root.add_child(ring_b)

	var mc := _alpha_mat(col)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.6
	cone.height = 1.4
	arrow.mesh = cone
	arrow.rotation_degrees.x = 180.0
	arrow.material_override = mc
	root.add_child(arrow)

	_markers.append({"node": root, "ring_a": ring_a, "ring_b": ring_b, "arrow": arrow,
		"ma": ma, "mb": mb, "mc": mc, "col": col, "t": 0.0})


func _update_markers(delta: float) -> void:
	for i in range(_markers.size() - 1, -1, -1):
		var m: Dictionary = _markers[i]
		m["t"] += delta
		var t: float = m["t"]
		if t > MARKER_LIFE:
			(m["node"] as Node3D).queue_free()
			_markers.remove_at(i)
			continue
		var fade := clampf((MARKER_LIFE - t) / 0.4, 0.0, 1.0)
		var col: Color = m["col"]
		(m["ring_a"] as Node3D).scale = Vector3.ONE * (0.5 + 0.5 * minf(t / 0.25, 1.0))
		(m["ma"] as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.95 * fade)
		var f := clampf(t / 1.0, 0.0, 1.0)  # dışa yayılan halka yalnızca bir kez
		(m["ring_b"] as Node3D).scale = Vector3.ONE * (1.0 + f * 1.8)
		(m["mb"] as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.8 * (1.0 - f))
		(m["arrow"] as Node3D).position.y = 3.0 + 0.6 * absf(sin(minf(t, 0.9) * 3.5))
		(m["mc"] as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.95 * fade)


# ---------------------------------------------------------------- üretim

func _model_for(kind: String, color: Color) -> Node3D:
	match kind:
		"worker": return Models.worker(color)
		"scout": return Models.scout(color)
		"spearman": return Models.spearman(color)
		"archer": return Models.archer(color)
		"musketeer": return Models.musketeer(color)
		"cavalry": return Models.cavalry(color)
		"cannon": return Models.cannon(color)
		"rifleman": return Models.rifleman(color)
		"tank": return Models.tank(color)
		"galleon": return Models.galleon(color)
		"destroyer": return Models.ship(color)
	return Models.spearman(color)


## Birimin güncel bedeli. İşçi her yeni işçide %12 pahalanır.
func _unit_cost(kind: String) -> Dictionary:
	var c: Dictionary = (UnitsData.KINDS[kind] as Dictionary).get("cost", {}).duplicate()
	if kind == "worker":
		var f := pow(1.12, float(_workers_trained))
		for k in c:
			c[k] = roundf(float(c[k]) * f)
	return c


# ---------------------------------------------------------------- üretim kuyruğu ve toplanma noktası

func _pop_cap() -> int:
	var cap := 0
	for s: Ent in _pstructs:
		cap += int((UnitsData.KINDS[s.kind] as Dictionary).get("pop", 0))
	if cap == 0:
		cap = 5  # yapısız (Göçebe) başlangıç
	return cap + 10 * int(_lib_levels["mil"])


func _queued_count() -> int:
	var n := 0
	for s: Ent in _pstructs:
		n += s.queue.size()
	return n


func _pop_used() -> int:
	return _units.size() + _queued_count()


## Birimi yapının kuyruğuna ekler: bedel hemen ödenir, süre dolunca birim çıkar.
func _enqueue(b: Ent, kind: String) -> void:
	var s: Dictionary = UnitsData.KINDS[kind]
	var bd: Dictionary = UnitsData.KINDS[b.kind]
	if not (kind in bd.get("trains", [])) or not (kind in UnitsData.TRAIN[_era]):
		hud.show_toast("%s bu çağda üretilemez" % s["title"])
		return
	if b.queue.size() >= 5:
		hud.show_toast("Kuyruk dolu")
		return
	if _pop_used() >= _pop_cap():
		hud.show_toast("Nüfus sınırı: ev yap veya Askeri teknoloji araştır")
		return
	if bool(s.get("naval", false)) and gen.find_water_near(Vector2(b.node.position.x, b.node.position.z)).x < 0.0:
		hud.show_toast("Limanın yakınında su yok")
		return
	var c := _unit_cost(kind)
	if not _can_afford(c):
		hud.show_toast("Yetersiz kaynak")
		return
	_spend(c)
	var t := float(UnitsData.TTIME.get(kind, 8.0))
	b.queue.append({"kind": kind, "total": t, "left": t, "cost": c})
	_refresh_struct_panel()


func _cancel_queue(b: Ent, idx: int) -> void:
	if idx < 0 or idx >= b.queue.size():
		return
	var item: Dictionary = b.queue[idx]
	for k in item["cost"]:
		_res[k] += float(item["cost"][k])  # iade
	b.queue.remove_at(idx)
	hud.show_toast("Üretim iptal edildi, bedel iade")
	_refresh_struct_panel()


func _process_queues(delta: float) -> void:
	for b: Ent in _pstructs:
		if b.queue.is_empty():
			continue
		var item: Dictionary = b.queue[0]
		item["left"] = float(item["left"]) - delta
		if float(item["left"]) <= 0.0:
			b.queue.remove_at(0)
			_spawn_trained(b, String(item["kind"]))
			_refresh_struct_panel()


func _spawn_trained(b: Ent, kind: String) -> void:
	var s: Dictionary = UnitsData.KINDS[kind]
	var blue := Color("3d8bff")
	var model := _model_for(kind, blue)
	var bp := b.node.position
	var e: Ent
	if bool(s.get("naval", false)):
		var w := gen.find_water_near(Vector2(bp.x, bp.z))
		var d := (w if w.x >= 0.0 else Vector2(bp.x + 20.0, bp.z)) + Vector2(_rng.randf_range(-4.0, 4.0), _rng.randf_range(-4.0, 4.0))
		model.position = Vector3(d.x, 0.1, d.y)
		_world_root.add_child(model)
		e = _add_unit(model, kind)
	else:
		var x := bp.x + _rng.randf_range(-5.0, 5.0)
		var z := bp.z + b.body_r + 4.0 + _rng.randf_range(0.0, 3.0)
		e = _add_unit(_put(_world_root, model, x, z, 180.0), kind)
	Models.apply_era(model, _era)
	if kind == "worker":
		_workers_trained += 1
	if b.rally != null:
		var r: Vector3 = b.rally
		e.goal = Vector3(r.x + _rng.randf_range(-3.0, 3.0), 0.0, r.z + _rng.randf_range(-3.0, 3.0))
	hud.show_toast("%s hazır" % s["title"])


# ---------------------------------------------------------------- inşaat

func _refresh_build_buttons() -> void:
	var items: Array = []
	for kind in UnitsData.BUILD_LIST:
		var s: Dictionary = UnitsData.KINDS[kind]
		if int(s["era"]) > _era:
			continue
		items.append(["%s\n%s" % [s["title"], _cost_text(s["cost"])], "build:" + kind])
	hud.set_build_items(items)


func _cancel_build(u: Ent) -> void:
	u.build_site = null


## Yer tutma: yer uygun mu, bedel yeterli mi, işçi var mı; inşaat alanı açılır.
func _place_build(hit: Vector3) -> void:
	var kind := _build_kind
	_build_kind = ""
	if kind == "":
		return
	var s: Dictionary = UnitsData.KINDS[kind]
	var c: Dictionary = s["cost"]
	if gen.height_at(hit.x, hit.z) < 0.06:
		hud.show_toast("Buraya inşa edilemez (su ya da kıyı)")
		return
	if kind == "dock" and gen.find_water_near(Vector2(hit.x, hit.z)).x < 0.0:
		hud.show_toast("Liman kıyıya yakın olmalı")
		return
	if kind == "dock":
		var w := gen.find_water_near(Vector2(hit.x, hit.z))
		if Vector2(hit.x - w.x, hit.z - w.y).length() > 40.0:
			hud.show_toast("Liman kıyıya yakın olmalı")
			return
	for st: Ent in _pstructs + _estructs:
		var need := float((UnitsData.KINDS[st.kind] as Dictionary).get("body_r", 3.0)) + float(s.get("body_r", 3.0)) + 2.0
		if _flat_dist(hit, st.node.global_position) < need:
			hud.show_toast("Yer dolu: başka bir yere dokun")
			return
	if not _can_afford(c):
		hud.show_toast("Yetersiz kaynak")
		return
	# İşçi bul: seçili işçiler, yoksa boştaki, yoksa herhangi bir işçi
	var builders: Array = []
	for u: Ent in _units:
		if u.kind == "worker" and u.selected:
			builders.append(u)
	if builders.is_empty():
		var best: Ent = null
		var bd := INF
		for u: Ent in _units:
			if u.kind != "worker":
				continue
			var d := _flat_dist(u.node.global_position, hit)
			var idle := u.job == null and u.goal == null and u.build_site == null
			if idle:
				d -= 1000.0
			if d < bd:
				bd = d
				best = u
		if best != null:
			builders.append(best)
	if builders.is_empty():
		hud.show_toast("İnşaat için işçi lazım")
		return
	_spend(c)
	var site := Site.new()
	site.kind = kind
	site.btime = float(s["btime"])
	site.pos = Vector3(hit.x, gen.surface_y(hit.x, hit.z), hit.z)
	var model := _struct_model(kind, Color("3d8bff"), _era, _style)
	model.position = site.pos
	model.scale = Vector3(1, 0.2, 1)
	_world_root.add_child(model)
	site.node = model
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 48
	l.pixel_size = 0.012
	l.outline_size = 12
	l.position = Vector3(0, 10.0, 0)
	model.add_child(l)
	site.label = l
	_sites.append(site)
	for u: Ent in builders:
		_release_job(u)
		u.attack = null
		u.build_site = site
		u.goal = Vector3(site.pos.x + _rng.randf_range(-3.0, 3.0), 0.0, site.pos.z + 4.0 + _rng.randf_range(0.0, 3.0))
	_spawn_marker(site.pos, COL_MOVE)
	hud.show_toast("%s inşaatı başladı" % s["title"])


func _update_sites(delta: float) -> void:
	for i in range(_sites.size() - 1, -1, -1):
		var site: Site = _sites[i]
		var present := 0
		for u: Ent in _units:
			if u.build_site == site and _flat_dist(u.node.global_position, site.pos) <= 9.0:
				present += 1
				u.node.rotation_degrees.x = sin(Time.get_ticks_msec() * 0.012) * 12.0
		if present > 0:
			site.progress += delta / site.btime * pow(float(present), 0.7)
		var p := clampf(site.progress, 0.0, 1.0)
		site.node.scale = Vector3(1, 0.2 + 0.8 * p, 1)
		site.label.text = "İnşaat %%%d" % int(p * 100.0)
		if p >= 1.0:
			_finish_site(site)
			_sites.remove_at(i)


func _finish_site(site: Site) -> void:
	for u: Ent in _units:
		if u.build_site == site:
			u.build_site = null
			u.node.rotation_degrees.x = 0.0
	site.node.queue_free()
	var model := _struct_model(site.kind, Color("3d8bff"), _era, _style)
	model.position = site.pos
	_world_root.add_child(model)
	var e := _add_struct(model, site.kind, "player", 1.0, "")
	if site.kind == "castle" and _home.x < -500.0:
		_home = Vector2(site.pos.x, site.pos.z)
	hud.show_toast("%s tamamlandı" % String(UnitsData.KINDS[site.kind]["title"]))
	if _sel_struct == null:
		pass
	_refresh_economy_ui()


# ---------------------------------------------------------------- çağ, çağ atlama, yapı evrimi

## Çağı değiştirir: üretim/inşa listeleri, petrol, yapı modelleri ve birim görünümleri çağa göre yenilenir.
func _apply_era(idx: int, announce: bool = true) -> void:
	var changed := idx != _era
	_era = clampi(idx, 0, UnitsData.ERAS.size() - 1)
	var e: Dictionary = UnitsData.ERAS[_era]
	hud.set_era(e["roman"], e["name"])
	hud.set_dev_era(_era)
	hud.show_resource("oil", _era >= UnitsData.OIL_ERA)
	for n: RNode in _nodes:
		var open := _era >= n.min_era
		n.node.visible = open
		if not open:
			for u: Ent in _units:
				if u.job == n:
					_release_job(u)
	_refresh_build_buttons()
	for u: Ent in _units:
		Models.apply_era(u.node, _era)
	if changed:
		_swap_structure_models()
	_refresh_struct_panel()
	_refresh_economy_ui()
	if announce:
		hud.show_toast("Çağ %s: %s" % [e["roman"], e["name"]])


## Çağ atlayınca oyuncu yapıları anında yeni çağın görünümüne (ahşap → taş → sanayi → modern) dönüşür.
func _swap_structure_models() -> void:
	for s: Ent in _pstructs:
		var old := s.node
		var parent := old.get_parent()
		var nm := _struct_model(s.kind, Color("3d8bff"), _era, _style)
		nm.position = old.position
		nm.rotation = old.rotation
		nm.scale = s.base_scale
		parent.add_child(nm)
		var had_sel := s.ring != null and s.ring.visible
		s.node = nm
		s.ring = null
		s.range_ring = null
		s.threat_ring = null
		if s.fire != null:
			s.fire = null
		s.fire_level = 0
		old.queue_free()
		fx.puff(nm.global_position + Vector3(0, 3, 0), Color(0.8, 0.8, 0.8), 14, 1.4, 1.2, 4.0)
		if had_sel and _sel_struct == s:
			_sel_struct = null
			_select_struct(s)
	for site: Site in _sites:
		pass


func _unit_research_discount() -> float:
	return maxf(0.5, 1.0 - 0.1 * float(_lib_levels["sci"]))


func _scaled(c: Dictionary, f: float) -> Dictionary:
	var out := {}
	for k in c:
		out[k] = roundf(float(c[k]) * f)
	return out


func _lib_cost(row: int) -> Dictionary:
	return _scaled(UnitsData.LIB_COST[row], _unit_research_discount())


func _age_ok() -> bool:
	if _era >= UnitsData.ERAS.size() - 1:
		return false
	var n := 0
	for k in _lib_levels:
		if int(_lib_levels[k]) >= _era + 1:
			n += 1
	return n >= 2


func _age_cost() -> Dictionary:
	return _scaled(UnitsData.AGE_COST[_era], _unit_research_discount())


func _lib_state() -> Dictionary:
	var next := {}
	for col in UnitsData.LIB_COLS:
		var cid: String = col["id"]
		var lv: int = _lib_levels[cid]
		if lv < UnitsData.LIB_ROWS:
			var c := _lib_cost(lv)
			next[cid] = {"cost": _cost_text(c), "can": _can_afford(c)}
		else:
			next[cid] = {"cost": "", "can": false}
	var age := {}
	if _era >= UnitsData.ERAS.size() - 1:
		age = {"text": "En son çağdasın.", "can": false, "btn": "Çağ atla"}
	else:
		var nxt: Dictionary = UnitsData.ERAS[_era + 1]
		var c := _age_cost()
		var ok := _age_ok()
		var req := "En az iki sütunu Seviye %d yap." % (_era + 1)
		age = {"text": "Sonraki çağ: %s. %s\nBedel: %s" % [nxt["name"], req, _cost_text(c)],
			"can": ok and _can_afford(c) and _age_progress < 0.0, "btn": "Çağ atla: %s" % nxt["name"]}
	return {"levels": _lib_levels, "next": next, "age": age, "progress": _age_progress}


func _on_research(col_id: String) -> void:
	var lv: int = _lib_levels[col_id]
	if lv >= UnitsData.LIB_ROWS:
		return
	var c := _lib_cost(lv)
	if not _can_afford(c):
		hud.show_toast("Yetersiz kaynak")
		return
	_spend(c)
	_lib_levels[col_id] = lv + 1
	hud.show_toast("Araştırıldı: Seviye %d" % (lv + 1))
	lib.refresh(_lib_state())
	_refresh_economy_ui()


func _on_age_up() -> void:
	if _age_progress >= 0.0 or not _age_ok():
		hud.show_toast("Çağ atlamak için gereken araştırma tamamlanmadı")
		return
	var c := _age_cost()
	if not _can_afford(c):
		hud.show_toast("Yetersiz kaynak")
		return
	_spend(c)
	_age_progress = 0.0
	lib.visible = false
	hud.show_toast("Çağ atlanıyor...")


func _update_age(delta: float) -> void:
	if _age_progress < 0.0:
		return
	_age_progress += delta / UnitsData.AGE_TIME
	var e: Dictionary = UnitsData.ERAS[_era]
	hud.set_era(e["roman"], e["name"], minf(_age_progress, 1.0))
	if _age_progress >= 1.0:
		_age_progress = -1.0
		_apply_era(_era + 1)


# ---------------------------------------------------------------- kaynak toplama (işçi görevleri) ve ekonomi

func _com_cap() -> float:
	return float(UnitsData.COM_CAP[_era]) * (1.0 + 0.25 * float(_lib_levels["com"]))


## Düşman sınırı bir kaynak noktasını yutmuşsa orada üretim durur.
func _node_blocked(n: RNode) -> bool:
	for s: Ent in _estructs:
		if s.kind == "castle" and _flat_dist(n.node.global_position, s.node.global_position) < ENEMY_BORDER:
			return true
	return false


## Atanan işçilerin brüt dakikalık geliri (kaynak başına, ticaret sınırından önce).
func _income_raw() -> Dictionary:
	var out := {}
	for k in UnitsData.RES_KEYS:
		out[k] = 0.0
	for n: RNode in _nodes:
		if _era >= n.min_era and not _node_blocked(n):
			out[n.kind] += float(n.workers) * n.rate * 60.0
	return out


## Ticaret sınırına göre kırpılmış gelir.
func _income_per_min() -> Dictionary:
	var raw := _income_raw()
	var cap := _com_cap()
	for k in raw:
		raw[k] = minf(float(raw[k]), cap)
	return raw


## Askerlerin bakımı (dakikada yiyecek). İşçiler bakım istemez.
func _upkeep_per_min() -> float:
	var n := 0
	for u: Ent in _units:
		if u.kind != "worker":
			n += 1
	return 1.2 * float(n)


## Görevi olan işçiler kaynak noktasına yürür ve yakına varınca toplar. Ticaret sınırı ve bakım uygulanır.
func _gather(delta: float) -> void:
	var raw := _income_raw()
	var cap := _com_cap()
	for u: Ent in _units:
		if u.job == null:
			continue
		var n: RNode = u.job
		if _node_blocked(n):
			continue
		var d := _flat_dist(u.node.global_position, n.node.global_position)
		if d <= GATHER_RANGE:
			var scale := 1.0
			if float(raw[n.kind]) > cap:
				scale = cap / float(raw[n.kind])
			_res[n.kind] += n.rate * delta * scale
			u.node.rotation_degrees.x = sin(Time.get_ticks_msec() * 0.011 + u.job_angle) * 14.0  # kazma/orak sallama
		else:
			u.node.rotation_degrees.x = 0.0
			if u.goal == null and u.attack == null:
				var np := n.node.global_position
				u.goal = Vector3(np.x + cos(u.job_angle) * 4.5, 0.0, np.z + sin(u.job_angle) * 4.5)
	var up := _upkeep_per_min() / 60.0 * delta
	if up > 0.0:
		if float(_res["food"]) <= up:
			_starve_warned += delta
			if _starve_warned > 20.0:
				_starve_warned = 0.0
				hud.show_toast("Yiyecek bitti! Askerlerin bakımı ödenemiyor")
		_res["food"] = maxf(0.0, float(_res["food"]) - up)


## Üst panel: kaynaklar (net gelir ve ticaret sınırı), nüfus, boşta işçi.
func _refresh_economy_ui() -> void:
	var rates := _income_per_min()
	var up := _upkeep_per_min()
	var cap := int(_com_cap())
	for k in UnitsData.RES_KEYS:
		var net := int(rates[k])
		if k == "food":
			net = int(rates[k] - up)
		hud.set_resource(k, int(_res[k]), net, cap)
	hud.set_pop(_pop_used(), _pop_cap())
	hud.set_idle(_idle_workers().size())
	_refresh_build_buttons_if_needed()


var _build_sig := ""

func _refresh_build_buttons_if_needed() -> void:
	var sig := str(_era)
	if sig != _build_sig:
		_build_sig = sig
		_refresh_build_buttons()


func _idle_workers() -> Array:
	var out: Array = []
	for u: Ent in _units:
		if u.kind == "worker" and u.job == null and u.goal == null and u.attack == null and u.build_site == null:
			out.append(u)
	return out


func _on_idle_worker() -> void:
	var list := _idle_workers()
	if list.is_empty():
		hud.show_toast("Boşta işçi yok")
		return
	_idle_cursor = (_idle_cursor + 1) % list.size()
	var u: Ent = list[_idle_cursor]
	_select_all(false)
	_set_selected(u, true)
	_focus(u.node.position)
	_refresh_hint()


# ---------------------------------------------------------------- mini harita ve ulusal sınırlar

func _setup_borders() -> void:
	if _border_mesh != null:
		return
	_border_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _border_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _player_border_radius() -> float:
	return BORDER_BASE * (1.0 + 0.12 * float(_lib_levels["civ"]))


## Sınır halkaları: oyuncunun (mavi) ve keşfedilmiş rakiplerin (kırmızı). Dalga gibi kıpırdar, Sivil teknolojiyle genişler.
func _border_rings() -> Array:
	var rings: Array = []
	for s: Ent in _pstructs:
		if s.kind == "castle":
			rings.append({"p": Vector2(s.node.position.x, s.node.position.z), "r": _player_border_radius(), "c": Color(0.35, 0.6, 1.0)})
	for nat in _nations:
		if not nat["found"]:
			continue
		for s: Ent in _estructs:
			if s.kind == "castle" and s.nation == nat["name"]:
				rings.append({"p": Vector2(s.node.position.x, s.node.position.z), "r": ENEMY_BORDER, "c": Color(1.0, 0.35, 0.4)})
	return rings


func _update_borders() -> void:
	_border_mesh.clear_surfaces()
	var rings := _border_rings()
	if rings.is_empty():
		return
	var width := maxf(0.5, cam.zoom * 0.004)
	var t := Time.get_ticks_msec() * 0.0015
	_border_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEG := 120
	for ring in rings:
		var c: Color = ring["c"]
		c.a = 0.75
		var center: Vector2 = ring["p"]
		var prev := Vector3.ZERO
		var first := Vector3.ZERO
		for i in range(SEG + 1):
			var a := TAU * float(i) / float(SEG)
			var r := float(ring["r"]) + sin(a * 7.0 + t) * 1.6 + sin(a * 3.0 - t * 1.3) * 1.2  # dalga gibi bükülme
			var x := center.x + cos(a) * r
			var z := center.y + sin(a) * r
			var p := Vector3(x, maxf(gen.surface_y(x, z), 0.0) + 0.7, z)
			if i > 0 and i % 2 == 1:  # kesikli çizgi
				var d := (p - prev)
				var side := Vector3(-d.z, 0.0, d.x).normalized() * (width * 0.5)
				_border_mesh.surface_set_color(c)
				_border_mesh.surface_add_vertex(prev - side)
				_border_mesh.surface_add_vertex(prev + side)
				_border_mesh.surface_add_vertex(p + side)
				_border_mesh.surface_add_vertex(prev - side)
				_border_mesh.surface_add_vertex(p + side)
				_border_mesh.surface_add_vertex(p - side)
			prev = p
			if i == 0:
				first = p
	_border_mesh.surface_end()


func _update_minimap() -> void:
	var mm = hud.minimap
	var marks: Array = []
	for s: Ent in _pstructs:
		marks.append({"p": Vector2(s.node.position.x, s.node.position.z), "c": Color("5aa0ff"), "r": 3.0})
	for u: Ent in _units:
		marks.append({"p": Vector2(u.node.position.x, u.node.position.z), "c": Color("a8d0ff"), "r": 1.6})
	for s: Ent in _estructs:
		if s.node.is_visible_in_tree():
			marks.append({"p": Vector2(s.node.position.x, s.node.position.z), "c": Color("ff5a6a"), "r": 3.0})
	for u: Ent in _eunits:
		if u.node.is_visible_in_tree():
			marks.append({"p": Vector2(u.node.position.x, u.node.position.z), "c": Color("ff8a95"), "r": 1.6})
	mm.markers = marks
	mm.rings = _border_rings()
	var zoom_v: float = cam.zoom
	var w: float = zoom_v * 0.95
	var h: float = zoom_v * 1.5
	mm.view = Rect2(cam.target.x - w * 0.5, cam.target.z - h * 0.5, w, h)
	mm.refresh(fog.data, fog.SIZE)


func _on_minimap(w: Vector2) -> void:
	_focus(Vector3(w.x, 0.0, w.y))


# ---------------------------------------------------------------- yangın, nükleer

## Hasarlı yapılarda yangın: can %55'in altında hafif, %25'in altında şiddetli.
func _update_fires() -> void:
	for s: Ent in _pstructs + _estructs:
		if not s.alive or not s.node.is_visible_in_tree():
			continue
		var r := s.hp / s.max_hp
		var lv := 0 if r >= 0.55 else (1 if r >= 0.25 else 2)
		if lv != s.fire_level:
			if s.fire != null:
				s.fire.queue_free()
				s.fire = null
			s.fire_level = lv
			if lv > 0:
				s.fire = fx.fire(s.node, lv, s.hit_h + 1.0)


## Nükleer patlama: kör edici beyazlık, mantar bulutu, alandaki her şey yok olur, zemin yanar, ağaçlar kaybolur.
func _nuke(pos: Vector3) -> void:
	hud.flash()
	fx.nuke(pos, NUKE_RADIUS, gen.surface_y(pos.x, pos.z))
	var victims: Array = []
	for e: Ent in _units + _pstructs + _eunits + _estructs:
		if _flat_dist(e.node.global_position, pos) <= NUKE_RADIUS:
			victims.append(e)
	for e: Ent in victims:
		_hit(e, 999999.0)
	gen.scorched.append({"p": Vector2(pos.x, pos.z), "r": NUKE_RADIUS})
	for k in chunks.keys():
		var c: Vector2i = k
		var ctr := Vector2((c.x + 0.5) * CHUNK_TILES, (c.y + 0.5) * CHUNK_TILES)
		if ctr.distance_to(Vector2(pos.x, pos.z)) < NUKE_RADIUS + CHUNK_TILES:
			_set_vegetation(k, int(chunks[k]["veg"]))
	hud.show_toast("Nükleer patlama!")


func _release_job(u: Ent) -> void:
	if u.job == null:
		return
	u.job.workers = maxi(0, u.job.workers - 1)
	_update_node_label(u.job)
	u.job = null
	if is_instance_valid(u.node):
		u.node.rotation_degrees.x = 0.0


## Seçili işçileri kaynak noktasına atar (boş yer kadarı).
func _assign_jobs(n: RNode) -> void:
	var workers: Array = []
	for u: Ent in _units:
		if u.selected and u.kind == "worker":
			workers.append(u)
	if workers.is_empty():
		hud.show_toast("Önce işçi seç")
		return
	var left := 0
	for u: Ent in workers:
		if u.job == n:
			continue
		if n.workers >= n.slots:
			left += 1
			continue
		_release_job(u)
		u.attack = null
		u.goal = null
		u.job = n
		u.job_angle = float(n.workers) * 1.26
		n.workers += 1
	_update_node_label(n)
	_spawn_marker(n.node.global_position, COL_MOVE)
	if left > 0:
		hud.show_toast("%s dolu, %d işçi atanamadı" % [n.title, left])
	else:
		hud.show_toast("%d işçi %s'na gidiyor" % [workers.size(), n.title])


func _pick_node(screen: Vector2) -> RNode:
	var best: RNode = null
	var best_d := NODE_PICK_PX
	for n: RNode in _nodes:
		if not n.node.visible or cam.is_position_behind(n.node.global_position):
			continue
		var d := screen.distance_to(cam.unproject_position(n.node.global_position + Vector3(0, 2.0, 0)))
		if d < best_d:
			best_d = d
			best = n
	return best


# ---------------------------------------------------------------- gezinme çubuğu

## Arayüzden gelen eylemler (hud.gd'deki TABS tablosundaki kimlikler).
func _on_action(id: String) -> void:
	# Yerleştirme / toplanma noktası modları başka bir eylemle iptal olur
	if not id.begins_with("build:") and id != "rally":
		_build_kind = ""
		_rally_mode = false
	if id.begins_with("q:"):
		if _sel_struct != null:
			_enqueue(_sel_struct, id.substr(2))
		return
	if id.begins_with("qc:"):
		if _sel_struct != null:
			_cancel_queue(_sel_struct, int(id.substr(3)))
		return
	if id.begins_with("build:"):
		var kind := id.substr(6)
		_build_kind = "" if _build_kind == kind else kind
		if _build_kind != "":
			hud.set_hint("%s: inşa edilecek yere dokun" % String(UnitsData.KINDS[kind]["title"]))
		else:
			_refresh_hint()
		return
	if id.begins_with("era:"):
		_apply_era(int(id.substr(4)))
		return
	if id.begins_with("stance:"):
		var st := id.substr(7)
		for u: Ent in _units:
			if u.selected:
				u.stance = st
		hud.set_stance(id)
		hud.show_toast("Duruş: %s" % {"aggressive": "Saldırgan", "defend": "Savunma", "hold": "Sabit"}[st])
		return
	if id.begins_with("form:"):
		_formation = id.substr(5)
		hud.set_formation(id)
		return
	match id:
		"rally":
			if _sel_struct != null:
				_rally_mode = true
				hud.set_hint("Toplanma noktası için yere dokun")
		"library":
			lib.refresh(_lib_state())
			lib.visible = not lib.visible
		"idle_worker":
			_on_idle_worker()
		"dev_res":
			for k in UnitsData.RES_KEYS:
				_res[k] += 1000.0
			hud.show_toast("+1000 kaynak (geliştirici)")
			_refresh_economy_ui()
		"dev_buildings":
			_dev_all_buildings()
		"dev_nuke":
			var target := Vector3(cam.target.x, 0.0, cam.target.z)
			if not _nations.is_empty():
				target = _nations[0]["pos"]
				_focus(target)
			_nuke(target)
		"upgrade":
			_do_upgrade()
		"home":
			if not _pstructs.is_empty():
				_focus((_pstructs[0] as Ent).node.position)
			else:
				_focus(Vector3(_home.x, 0.0, _home.y))
		"select_all":
			_select_all(_selected_count() != _units.size())
		"box_mode":
			_select_mode = not _select_mode
			cam.pan_enabled = not _select_mode
			hud.set_select_mode(_select_mode)
			hud.show_toast("Kutu seçim açık: sürükleyerek çiz" if _select_mode else "Kaydırma modu")
			_refresh_hint()
		"stop":
			_stop_selected()
		"scout":
			_select_only_kind("scout")
		"scout_focus":
			_select_only_kind("scout")
			for u: Ent in _units:
				if u.kind == "scout":
					_focus(u.node.position)


func _focus(p: Vector3) -> void:
	cam.target = Vector3(p.x, 0.0, p.z)
	cam._apply()


## Test/geliştirici: tüm yapı türlerini kalenin etrafında anında kurar.
func _dev_all_buildings() -> void:
	var have := {}
	for s: Ent in _pstructs:
		have[s.kind] = true
	var i := 0
	for kind in ["barracks", "stable", "siege", "dock", "house", "lookout"]:
		if have.has(kind):
			continue
		var a := float(i) * 0.9 + 0.4
		var p := Vector2(_home.x + cos(a) * 42.0, _home.y + sin(a) * 42.0)
		if kind == "dock":
			var w := gen.find_water_near(_home)
			if w.x >= 0.0:
				p = w + (Vector2(_home.x, _home.y) - w).normalized() * 12.0
		var model := _struct_model(kind, Color("3d8bff"), _era, _style)
		_add_struct(_put(_world_root, model, p.x, p.y), kind, "player", 1.0, "")
		i += 1
	hud.show_toast("Tüm yapılar kuruldu (geliştirici)")
	_refresh_economy_ui()


# ---------------------------------------------------------------- dokunma

func _box_mode() -> bool:
	return _select_mode or Input.is_key_pressed(KEY_SHIFT)


func _unhandled_input(event: InputEvent) -> void:
	if not _started:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		_on_action("library")
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_damage_selected()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press(event.pressed, event.position)
	elif event is InputEventScreenTouch:
		if event.index == 0:
			_handle_press(event.pressed, event.position)
		elif event.pressed:
			_tap_candidate = false
			_cancel_box()
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_handle_move(event.position)
	elif event is InputEventScreenDrag and event.index == 0:
		_handle_move(event.position)


func _cancel_box() -> void:
	_box_active = false
	hud.hide_box()


func _handle_move(pos: Vector2) -> void:
	if not _tap_candidate or not _box_mode():
		return
	if not _box_active and pos.distance_to(_press_pos) > 14.0:
		_box_active = true
	if _box_active:
		hud.show_box(Rect2(_press_pos, Vector2.ZERO).expand(pos))


func _handle_press(pressed: bool, pos: Vector2) -> void:
	if pressed:
		_tap_candidate = true
		_press_pos = pos
		_press_ms = Time.get_ticks_msec()
		return
	if _box_active:
		var rect := Rect2(_press_pos, Vector2.ZERO).expand(pos)
		_cancel_box()
		_tap_candidate = false
		_select_in_rect(rect)
		return
	if _tap_candidate:
		_tap_candidate = false
		if pos.distance_to(_press_pos) < 14.0 and Time.get_ticks_msec() - _press_ms < 450:
			_on_tap(pos)


func _pick(list: Array, screen: Vector2, max_px: float, height: float) -> Ent:
	var best: Ent = null
	var best_d := max_px
	for e: Ent in list:
		if not e.node.is_visible_in_tree():
			continue
		if cam.is_position_behind(e.node.global_position):
			continue
		var d := screen.distance_to(cam.unproject_position(e.node.global_position + Vector3(0, height, 0)))
		if d < best_d:
			best_d = d
			best = e
	return best


func _on_tap(screen: Vector2) -> void:
	# 0) Yerleştirme modları: inşaat yeri veya toplanma noktası
	if _build_kind != "":
		var bh := _ground_hit(screen)
		if bh != Vector3.INF:
			_place_build(bh)
			_refresh_hint()
		return
	if _rally_mode and _sel_struct != null:
		var rh := _ground_hit(screen)
		if rh != Vector3.INF:
			_sel_struct.rally = rh
			_rally_mode = false
			_spawn_marker(rh, COL_MOVE)
			hud.show_toast("Toplanma noktası belirlendi")
			_refresh_hint()
		return
	# 1) Kendi birliğine dokunuldu mu?
	var mine := _pick(_units, screen, PICK_RADIUS_PX, 1.2)
	if mine != null:
		var now := Time.get_ticks_msec()
		if mine == _last_tap_unit and now - _last_tap_ms < 400:
			for u: Ent in _units:
				_set_selected(u, u.kind == mine.kind)
			_last_tap_unit = null
		else:
			_set_selected(mine, not mine.selected)
			_last_tap_unit = mine
			_last_tap_ms = now
		_refresh_hint()
		return
	# 2) Kendi yapına (kule/kale) mı? Seçer; yükseltme paneli açılır.
	var mine_struct := _pick(_pstructs, screen, PICK_RADIUS_STRUCT_PX, 4.0)
	if mine_struct != null:
		_select_struct(mine_struct)
		return
	# 3) Kaynak noktasına mı? Seçili işçiler çalışmaya gider.
	var rn := _pick_node(screen)
	if rn != null and _selected_count() > 0:
		_assign_jobs(rn)
		return
	# 4) Rakibe dokunuldu mu? Seçili birlik varsa saldır.
	if _selected_count() > 0:
		var foe := _pick(_eunits, screen, PICK_RADIUS_PX, 1.2)
		if foe == null:
			foe = _pick(_estructs, screen, PICK_RADIUS_STRUCT_PX, 4.0)
		if foe != null:
			_order_attack(foe)
			return
		# 5) Yere dokunuldu: hareket
		var hit := _ground_hit(screen)
		if hit != Vector3.INF:
			_order_move(hit)
	elif _sel_struct != null:
		_clear_struct_selection()  # boşluğa dokunmak yapı seçimini kaldırır


## Ekran noktasından araziye ışın yürütür.
func _ground_hit(screen: Vector2) -> Vector3:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var step := maxf(1.0, cam.zoom * 0.02)
	var t := 0.0
	while t < 4000.0:
		var p := o + d * t
		if p.y <= gen.surface_y(p.x, p.z):
			return Vector3(p.x, 0.0, p.z)
		t += step
	return Vector3.INF
