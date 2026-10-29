extends RefCounted
## Görsel efektler: namlu alevi ve barut dumanı, mermi izi, çarpma tozu, yangın, enkaz, nükleer patlama.
## Tüm efektler `host` altına eklenir ve kendi kendini siler. Çok yoğun savaşta sayı sınırlanır.

const MAX_FX := 48

var host: Node3D
var cam: Camera3D
var count := 0


func _init(p_host: Node3D, p_cam: Camera3D) -> void:
	host = p_host
	cam = p_cam


func _unshaded(c: Color, alpha: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.vertex_color_use_as_albedo = true
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func busy() -> bool:
	return count >= MAX_FX or cam.zoom > 360.0


func _later(sec: float, cb: Callable) -> void:
	host.get_tree().create_timer(sec).timeout.connect(cb)


## Yukarı yükselen, sönen parçacık bulutu (duman, toz, kıvılcım).
func puff(pos: Vector3, color: Color, amount: int, life: float, size: float, speed: float, gravity_y: float = 0.6, spread: float = 45.0) -> void:
	if busy():
		return
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _unshaded(Color.WHITE, true)
	p.mesh = sm
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity_y, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.85))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(p)
	p.global_position = pos
	p.emitting = true
	count += 1
	_later(life + 0.3, func():
		count -= 1
		p.queue_free())


## Namlu alevi (kısa parlak küre) ve barut dumanı.
func muzzle(pos: Vector3, dir: Vector3, big: bool) -> void:
	if busy():
		return
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5 if big else 0.28
	sm.height = sm.radius * 2.0
	flash.mesh = sm
	flash.material_override = _unshaded(Color(1.0, 0.85, 0.4, 1.0), true)
	host.add_child(flash)
	flash.global_position = pos + dir.normalized() * 1.2
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 2.2, 0.09)
	tw.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.09)
	tw.chain().tween_callback(flash.queue_free)
	puff(pos + dir.normalized() * 1.0, Color(0.85, 0.85, 0.85), 8 if big else 4, 1.4, 0.55 if big else 0.32, 2.0)


## Çarpma: toz ve kıvılcım. kind: "shell" büyük toz, diğerleri küçük.
func impact(pos: Vector3, kind: String) -> void:
	if kind == "shell":
		puff(pos, Color(0.45, 0.36, 0.26), 12, 0.9, 0.5, 6.0, -8.0, 80.0)
		puff(pos, Color(0.35, 0.35, 0.35), 6, 1.5, 0.8, 2.0, 0.8, 30.0)
	else:
		puff(pos, Color(0.55, 0.5, 0.42), 4, 0.5, 0.2, 3.0, -6.0, 70.0)


## Mermiye bağlanan iz (sürekli küçük duman).
func attach_trail(node: Node3D) -> void:
	if busy():
		return
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _unshaded(Color.WHITE, true)
	p.mesh = sm
	p.amount = 14
	p.lifetime = 0.7
	p.gravity = Vector3(0, 0.3, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.4
	p.local_coords = false
	var g := Gradient.new()
	g.set_color(0, Color(0.8, 0.8, 0.8, 0.7))
	g.set_color(1, Color(0.8, 0.8, 0.8, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(p)
	p.emitting = true


## Binaya bağlanan sürekli yangın (alev + duman). level 1 hafif, 2 şiddetli.
func fire(node: Node3D, level: int, height: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _unshaded(Color.WHITE, true)
	p.mesh = sm
	p.amount = 10 * level
	p.lifetime = 1.0
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 1.0, 0)
	p.scale_amount_min = 0.5 * level
	p.scale_amount_max = 1.0 * level
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.65, 0.15, 0.9))
	g.set_color(1, Color(0.2, 0.2, 0.2, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, height, 0)
	node.add_child(p)
	p.emitting = true
	return p


## Yıkılan yapının enkazı: gri taş parçaları, bir süre durup söner.
func rubble(pos: Vector3, radius: float, ground_y: float) -> void:
	var rng := RandomNumberGenerator.new()
	var root := Node3D.new()
	host.add_child(root)
	root.global_position = Vector3(pos.x, ground_y, pos.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.32, 0.30)
	mat.roughness = 1.0
	for i in range(7):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.8, 2.4), rng.randf_range(0.4, 1.4), rng.randf_range(0.8, 2.4))
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3(rng.randf_range(-radius, radius) * 0.7, bm.size.y * 0.4, rng.randf_range(-radius, radius) * 0.7)
		mi.rotation_degrees = Vector3(rng.randf_range(-12, 12), rng.randf_range(0, 180), rng.randf_range(-12, 12))
		root.add_child(mi)
	puff(root.global_position + Vector3(0, 1, 0), Color(0.3, 0.3, 0.3), 10, 3.0, 1.0, 2.5)
	_later(40.0, func():
		var tw := host.create_tween()
		tw.tween_property(root, "scale", Vector3(1, 0.01, 1), 2.0)
		tw.tween_callback(root.queue_free))


## Nükleer patlama: kör edici top, mantar bulutu, yanık zemin (Decal) ve şok dalgası. Kaldırılması gereken bitkiler için main bilgilendirilir.
func nuke(pos: Vector3, radius: float, ground_y: float) -> void:
	var root := Node3D.new()
	host.add_child(root)
	root.global_position = Vector3(pos.x, ground_y, pos.z)

	var fire_m := _unshaded(Color(1.0, 0.7, 0.25, 0.95), true)
	var stem := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.0
	cyl.bottom_radius = 7.0
	cyl.height = 1.0
	stem.mesh = cyl
	stem.material_override = fire_m
	root.add_child(stem)
	var cap := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	cap.mesh = sph
	cap.material_override = fire_m
	root.add_child(cap)

	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(stem, "scale", Vector3(1.0, 46.0, 1.0), 3.2)
	tw.tween_property(stem, "position:y", 23.0, 3.2)
	tw.tween_property(cap, "scale", Vector3.ONE * 20.0, 3.6)
	tw.tween_property(cap, "position:y", 52.0, 3.6)
	tw.tween_property(fire_m, "albedo_color", Color(0.22, 0.2, 0.2, 0.0), 11.0).set_delay(2.0)
	tw.chain().tween_callback(root.queue_free)

	puff(root.global_position + Vector3(0, 4, 0), Color(1.0, 0.6, 0.2), 30, 3.0, 2.0, 18.0, -2.0, 90.0)
	puff(root.global_position + Vector3(0, 10, 0), Color(0.25, 0.22, 0.2), 30, 8.0, 3.5, 7.0, 1.5, 60.0)

	# Şok dalgası halkası
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	ring.mesh = t
	var rm := _unshaded(Color(1.0, 0.95, 0.8, 0.8), true)
	ring.material_override = rm
	root.add_child(ring)
	ring.position.y = 1.0
	var tr := host.create_tween()
	tr.set_parallel(true)
	tr.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 1.4)
	tr.tween_property(rm, "albedo_color:a", 0.0, 1.4)

	# Kalıcı yanık zemin (Decal)
	var g := Gradient.new()
	g.set_color(0, Color(0.02, 0.02, 0.02, 0.95))
	g.set_color(1, Color(0.02, 0.02, 0.02, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	var d := Decal.new()
	d.texture_albedo = tex
	d.size = Vector3(radius * 2.0, 80.0, radius * 2.0)
	d.cull_mask = 1
	host.add_child(d)
	d.global_position = Vector3(pos.x, ground_y, pos.z)
