extends Control
## Mini harita: arazi, sis, birlikler, ulusal sınırlar ve kamera çerçevesi. Dokununca kamera oraya gider.

signal pressed_at(world: Vector2)

const WORLD := 1024.0
const RES := 64

var _tex: ImageTexture
var _img: Image
var _base: PackedColorArray = PackedColorArray()
var markers: Array = []   # [{"p": Vector2, "c": Color, "r": float}]
var rings: Array = []     # [{"p": Vector2, "r": float, "c": Color}]
var view: Rect2 = Rect2()


func setup(gen) -> void:
	_img = Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	_base.resize(RES * RES)
	var cell := WORLD / float(RES)
	for j in range(RES):
		for i in range(RES):
			var x := (float(i) + 0.5) * cell
			var z := (float(j) + 0.5) * cell
			var h: float = gen.height_at(x, z)
			var c := Color("1e4f7a")
			if h >= 0.0:
				var b: int = gen.biome_at(x, z, h)
				match b:
					1: c = Color("d9c98c")
					2: c = Color("5f9650")
					3: c = Color("2f6b3f")
					4: c = Color("cfae62")
					5: c = Color("8b929b")
					6: c = Color("eef3f7")
					_: c = Color("5f9650")
			elif h > -0.06:
				c = Color("3b8fb5")
			_base[j * RES + i] = c
	refresh(PackedByteArray(), 256)


## fog_bytes: keşif sisi hücreleri (0 bilinmeyen, 128 keşfedilmiş, 255 görünür), fog_size: hücre sayısı (bir kenar).
func refresh(fog_bytes: PackedByteArray, fog_size: int) -> void:
	for j in range(RES):
		for i in range(RES):
			var c: Color = _base[j * RES + i]
			var f := 255
			if fog_bytes.size() == fog_size * fog_size:
				f = fog_bytes[int(j * fog_size / RES) * fog_size + int(i * fog_size / RES)]
			if f == 0:
				c = Color(0.02, 0.03, 0.06)
			elif f == 128:
				c = Color(c.r * 0.45, c.g * 0.45, c.b * 0.45)
			_img.set_pixel(i, j, c)
	_tex.update(_img)
	queue_redraw()


func _to_local_pos(w: Vector2) -> Vector2:
	return w / WORLD * size


func _draw() -> void:
	if _tex == null:
		return
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	for r in rings:
		var c: Color = r["c"]
		draw_arc(_to_local_pos(r["p"]), float(r["r"]) / WORLD * size.x, 0.0, TAU, 40, c, 1.5)
	for m in markers:
		draw_circle(_to_local_pos(m["p"]), float(m["r"]), m["c"])
	if view.size.x > 0.0:
		var a := _to_local_pos(view.position)
		var b := _to_local_pos(view.size)
		draw_rect(Rect2(a, b), Color(1, 1, 1, 0.9), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color("8fa3d6"), false, 2.0)


func _gui_input(ev: InputEvent) -> void:
	var p := Vector2.ZERO
	var hit := false
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		p = ev.position
		hit = true
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		p = ev.position
		hit = true
	elif ev is InputEventScreenTouch and ev.pressed:
		p = ev.position
		hit = true
	elif ev is InputEventScreenDrag:
		p = ev.position
		hit = true
	if hit:
		pressed_at.emit((p / size) * WORLD)
		accept_event()
