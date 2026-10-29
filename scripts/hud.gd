extends CanvasLayer
## Arayüz.
## Üst: kaynak kutuları (toplam, net gelir/ticaret sınırı), nüfus, çağ düğmesi (dokununca geliştirici paneli), boşta işçi ikonu, mini harita.
## Alt: 5 sekme (Şehir, İnşa, Ordu, Keşif, Uluslar) ve her sekmenin bağlamsal paneli; yapı seçilince üretim/yükseltme paneli.
## Eylemler tek bir `action(id)` sinyaliyle main.gd'ye gider.

signal action(id: String)
signal minimap_pressed(world: Vector2)

const UnitsData = preload("res://scripts/units_data.gd")
const Minimap = preload("res://scripts/minimap.gd")

const BG := Color("141c3c")
const BORDER := Color("2a3560")
const BG_ACTIVE := Color("234a8a")
const BORDER_ACTIVE := Color("8fc0ff")
const RES_COLORS := {
	"food": Color("7bd36b"), "wood": Color("c9a06a"), "gold": Color("f0c64a"),
	"silver": Color("dfe6ee"), "oil": Color("9aa3b8"),
}
const RED := Color("ff6b6b")

const TAB_ORDER := ["Şehir", "İnşa", "Ordu", "Keşif", "Uluslar"]
const STANCES := [["Saldırgan", "stance:aggressive"], ["Savunma", "stance:defend"], ["Sabit", "stance:hold"]]
const FORMATIONS := [["Çizgi", "form:line"], ["Sütun", "form:column"], ["Kare", "form:square"], ["Dağınık", "form:box"]]

var minimap: Control
var _chips := {}
var _pop_label: Label
var _era_btn: Button
var _idle_btn: Button
var _hint: Label
var _toast: Label
var _debug: Label
var _toast_tween: Tween
var _box: Panel
var _flash: ColorRect
var _context: VBoxContainer
var _panels := {}
var _tab_buttons := {}
var _open_tab := ""
var _build_row: HBoxContainer
var _mode_btn: Button
var _stance_btns := {}
var _form_btns := {}
var _nations_label: Label
var _struct_panel: PanelContainer
var _struct_box: VBoxContainer
var _struct_sig := ""
var _s_title: Label
var _s_stats: Label
var _s_up: Button
var _s_queue_btns: Array = []
var _dev_panel: PanelContainer
var _dev_era_buttons: Array = []
var _idle_t := 0.0
var _idle_n := 0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_top(root)
	_build_labels(root)
	_build_minimap(root)
	_build_dev_panel(root)
	_build_bottom(root)

	_box = Panel.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.24, 0.55, 1.0, 0.18)
	bs.border_color = BORDER_ACTIVE
	bs.set_border_width_all(2)
	_box.add_theme_stylebox_override("panel", bs)
	_box.visible = false
	root.add_child(_box)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)


func _process(delta: float) -> void:
	_idle_t += delta
	if _idle_btn != null and _idle_n > 0:
		var a := 0.55 + 0.45 * absf(sin(_idle_t * 4.0))
		_idle_btn.modulate = Color(1, 1, 1, a)
	elif _idle_btn != null:
		_idle_btn.modulate = Color(1, 1, 1, 0.45)


# ---------------------------------------------------------------- yerleşim

func _build_top(root: Control) -> void:
	var row1 := HBoxContainer.new()
	row1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row1.add_theme_constant_override("separation", 4)
	root.add_child(row1)
	_anchor_top(row1, 8.0, 50.0)
	for key in UnitsData.RES_KEYS:
		var chip := _chip(UnitsData.RES_TITLES[key], RES_COLORS[key])
		_chips[key] = chip
		row1.add_child(chip)
	(_chips["oil"] as Control).visible = false

	var row2 := HBoxContainer.new()
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row2.add_theme_constant_override("separation", 4)
	root.add_child(row2)
	_anchor_top(row2, 54.0, 90.0)

	var pop := PanelContainer.new()
	pop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pop.add_theme_stylebox_override("panel", _style(BG, BORDER, 10, 3))
	_pop_label = Label.new()
	_pop_label.add_theme_font_size_override("font_size", 14)
	_pop_label.add_theme_color_override("font_color", Color("e8ecfa"))
	_pop_label.text = "Nüfus 0/10"
	pop.add_child(_pop_label)
	row2.add_child(pop)

	_era_btn = Button.new()
	_era_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_era_btn.add_theme_font_size_override("font_size", 12)
	_era_btn.add_theme_color_override("font_color", Color("ffe08a"))
	_era_btn.add_theme_stylebox_override("normal", _style(BG, Color("8a7a3a"), 10, 3))
	_era_btn.add_theme_stylebox_override("hover", _style(BG_ACTIVE, BORDER_ACTIVE, 10, 3))
	_era_btn.add_theme_stylebox_override("pressed", _style(BG_ACTIVE, BORDER_ACTIVE, 10, 3))
	_era_btn.pressed.connect(func(): _dev_panel.visible = not _dev_panel.visible)
	row2.add_child(_era_btn)
	set_era("I", "Kılıç ve Ok")

	_idle_btn = Button.new()
	_idle_btn.text = "!"
	_idle_btn.custom_minimum_size = Vector2(40, 0)
	_idle_btn.add_theme_font_size_override("font_size", 18)
	_idle_btn.add_theme_color_override("font_color", Color("ffe08a"))
	_idle_btn.add_theme_stylebox_override("normal", _style(Color("3a2f10"), Color("ffe08a"), 20, 2))
	_idle_btn.add_theme_stylebox_override("hover", _style(Color("4a3d14"), Color("ffe08a"), 20, 2))
	_idle_btn.add_theme_stylebox_override("pressed", _style(Color("4a3d14"), Color("ffe08a"), 20, 2))
	_idle_btn.pressed.connect(func(): action.emit("idle_worker"))
	row2.add_child(_idle_btn)


func _build_labels(root: Control) -> void:
	_hint = _label(root, 14, Color("e8ecfa"), 5)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place_top(_hint, 96.0, 132.0)
	_hint.offset_right = -134.0

	_debug = _label(root, 11, Color("c9d3f0"), 4)
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place_top(_debug, 134.0, 150.0)
	_debug.offset_right = -134.0

	_toast = _label(root, 22, Color("ffe08a"), 7)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	_place_top(_toast, 232.0, 270.0)


func _build_minimap(root: Control) -> void:
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(118, 118)
	root.add_child(minimap)
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = -128.0
	minimap.offset_right = -10.0
	minimap.offset_top = 96.0
	minimap.offset_bottom = 214.0
	minimap.pressed_at.connect(func(w: Vector2): minimap_pressed.emit(w))


func _build_dev_panel(root: Control) -> void:
	_dev_panel = PanelContainer.new()
	_dev_panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.07, 0.16, 0.97), Color("a478ff"), 14, 10))
	_dev_panel.visible = false
	root.add_child(_dev_panel)
	_anchor_top(_dev_panel, 222.0, 222.0)
	_dev_panel.offset_left = 12.0
	_dev_panel.offset_right = -12.0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_dev_panel.add_child(col)
	var title := Label.new()
	title.text = "Geliştirici modu"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color("d7c2ff"))
	col.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for i in range(UnitsData.ERAS.size()):
		var b := _button("Çağ %s" % UnitsData.ERAS[i]["roman"], 44, 13)
		var idx := i
		b.pressed.connect(func(): action.emit("era:%d" % idx))
		row.add_child(b)
		_dev_era_buttons.append(b)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	col.add_child(row2)
	for it in [["+1000 kaynak", "dev_res"], ["Tüm binalar", "dev_buildings"], ["Nükleer test", "dev_nuke"]]:
		var b := _button(it[0], 42, 12)
		var id: String = it[1]
		b.pressed.connect(func(): action.emit(id))
		row2.add_child(b)


func _build_bottom(root: Control) -> void:
	_context = VBoxContainer.new()
	_context.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_context)
	_context.anchor_left = 0.0
	_context.anchor_right = 1.0
	_context.anchor_top = 1.0
	_context.anchor_bottom = 1.0
	_context.offset_left = 10.0
	_context.offset_right = -10.0
	_context.offset_top = -86.0
	_context.offset_bottom = -86.0
	_context.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_context.add_theme_constant_override("separation", 6)

	# Yapı paneli (üretim kuyruğu, yükseltme): en üstte
	_struct_panel = PanelContainer.new()
	_struct_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.11, 0.24, 0.97), BORDER_ACTIVE, 14, 8))
	_struct_panel.visible = false
	_context.add_child(_struct_panel)
	_struct_box = VBoxContainer.new()
	_struct_box.add_theme_constant_override("separation", 6)
	_struct_panel.add_child(_struct_box)

	for tab in TAB_ORDER:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.11, 0.24, 0.96), BORDER, 14, 8))
		panel.visible = false
		_context.add_child(panel)
		_panels[tab] = panel
		match tab:
			"Şehir":
				panel.add_child(_row([["Kaleye\ngit", "home"], ["Kütüphane\n(L)", "library"]]))
			"İnşa":
				_build_row = HBoxContainer.new()
				_build_row.add_theme_constant_override("separation", 5)
				panel.add_child(_build_row)
			"Ordu":
				var v := VBoxContainer.new()
				v.add_theme_constant_override("separation", 5)
				panel.add_child(v)
				var r1 := _row([["Hepsini seç", "select_all"], ["Kutu seç", "box_mode"], ["Dur", "stop"]])
				_mode_btn = r1.get_child(1)
				v.add_child(r1)
				var r2 := _row(STANCES)
				for i in range(STANCES.size()):
					_stance_btns[STANCES[i][1]] = r2.get_child(i)
				v.add_child(r2)
				var r3 := _row(FORMATIONS)
				for i in range(FORMATIONS.size()):
					_form_btns[FORMATIONS[i][1]] = r3.get_child(i)
				v.add_child(r3)
			"Keşif":
				panel.add_child(_row([["İzciyi seç", "scout"], ["İzciye git", "scout_focus"]]))
			"Uluslar":
				_nations_label = Label.new()
				_nations_label.text = "Henüz ulus keşfedilmedi.\nİzciyi gönder."
				_nations_label.add_theme_font_size_override("font_size", 15)
				_nations_label.add_theme_color_override("font_color", Color("e8ecfa"))
				panel.add_child(_nations_label)

	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 10.0
	bar.offset_right = -10.0
	bar.offset_top = -78.0
	bar.offset_bottom = -12.0
	for tab in TAB_ORDER:
		var tb := _button(tab, 62, 15)
		tb.pressed.connect(func(): _toggle_tab(tab))
		bar.add_child(tb)
		_tab_buttons[tab] = tb


func _row(items: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	for b in items:
		var btn := _button(b[0], 56, 13)
		var id: String = b[1]
		btn.pressed.connect(func(): action.emit(id))
		row.add_child(btn)
	return row


# ---------------------------------------------------------------- sekmeler

func open_tab(tab: String) -> void:
	if _open_tab != tab:
		_toggle_tab(tab)


func _toggle_tab(tab: String) -> void:
	_open_tab = "" if _open_tab == tab else tab
	for t in TAB_ORDER:
		(_panels[t] as Control).visible = (t == _open_tab)
		_style_button(_tab_buttons[t], t == _open_tab)


func _style_button(b: Button, active: bool) -> void:
	var bg := BG_ACTIVE if active else BG
	var br := BORDER_ACTIVE if active else BORDER
	b.add_theme_stylebox_override("normal", _style(bg, br, 12, 6))
	b.add_theme_stylebox_override("hover", _style(Color("1b2650") if not active else BG_ACTIVE, BORDER_ACTIVE, 12, 6))
	b.add_theme_stylebox_override("pressed", _style(Color("1b2650"), BORDER_ACTIVE, 12, 6))


# ---------------------------------------------------------------- dışarıdan çağrılar

## İnşa sekmesi: items [[etiket, "build:tür"], ...]
func set_build_items(items: Array) -> void:
	for c in _build_row.get_children():
		c.queue_free()
	for it in items:
		var btn := _button(it[0], 60, 11)
		var id: String = it[1]
		btn.pressed.connect(func(): action.emit(id))
		_build_row.add_child(btn)


## Seçili yapı paneli. info: title, stats, up_text, up_enabled, up_visible, train [[etiket,id]], queue [string], rally (bool)
func show_struct(info: Dictionary) -> void:
	var train: Array = info.get("train", [])
	var queue: Array = info.get("queue", [])
	var sig := "%s|%d|%d|%s" % [info["title"], train.size(), queue.size(), str(info.get("rally", false))]
	for t in train:
		sig += "|" + str(t[1])
	if sig != _struct_sig:
		_struct_sig = sig
		_rebuild_struct(info, train, queue)
	_s_title.text = info["title"]
	_s_stats.text = info["stats"]
	_s_up.visible = bool(info.get("up_visible", false))
	_s_up.text = info.get("up_text", "Yükselt")
	_s_up.disabled = not bool(info.get("up_enabled", false))
	for i in range(mini(_s_queue_btns.size(), queue.size())):
		(_s_queue_btns[i] as Button).text = queue[i]
	_struct_panel.visible = true


func _rebuild_struct(info: Dictionary, train: Array, queue: Array) -> void:
	for c in _struct_box.get_children():
		c.queue_free()
	_s_queue_btns = []
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_struct_box.add_child(top)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	top.add_child(col)
	_s_title = Label.new()
	_s_title.add_theme_font_size_override("font_size", 17)
	_s_title.add_theme_color_override("font_color", Color("ffe08a"))
	col.add_child(_s_title)
	_s_stats = Label.new()
	_s_stats.add_theme_font_size_override("font_size", 12)
	_s_stats.add_theme_color_override("font_color", Color("c9d3f0"))
	col.add_child(_s_stats)
	_s_up = _button("Yükselt", 52, 13)
	_s_up.size_flags_horizontal = Control.SIZE_SHRINK_END
	_s_up.custom_minimum_size = Vector2(150, 52)
	_s_up.add_theme_stylebox_override("disabled", _style(Color(0.1, 0.12, 0.2), Color(0.2, 0.22, 0.3), 12, 6))
	_s_up.pressed.connect(func(): action.emit("upgrade"))
	top.add_child(_s_up)
	if not train.is_empty():
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 5)
		_struct_box.add_child(r)
		for t in train:
			var b := _button(t[0], 54, 12)
			var id: String = t[1]
			b.pressed.connect(func(): action.emit(id))
			r.add_child(b)
	if not queue.is_empty():
		var q := HBoxContainer.new()
		q.add_theme_constant_override("separation", 4)
		_struct_box.add_child(q)
		for i in range(queue.size()):
			var b := _button(queue[i], 40, 11)
			var idx := i
			b.pressed.connect(func(): action.emit("qc:%d" % idx))
			q.add_child(b)
			_s_queue_btns.append(b)
	if bool(info.get("rally", false)):
		var rb := _button("Toplanma noktası belirle", 40, 12)
		rb.pressed.connect(func(): action.emit("rally"))
		_struct_box.add_child(rb)


func hide_struct() -> void:
	_struct_panel.visible = false
	_struct_sig = ""


func set_stance(id: String) -> void:
	for k in _stance_btns:
		_style_button(_stance_btns[k], k == id)


func set_formation(id: String) -> void:
	for k in _form_btns:
		_style_button(_form_btns[k], k == id)


func set_debug(text: String) -> void:
	_debug.text = text


func set_hint(text: String) -> void:
	_hint.text = text


func set_nations_text(text: String) -> void:
	_nations_label.text = text


func set_select_mode(on: bool) -> void:
	if _mode_btn:
		_style_button(_mode_btn, on)


func show_box(rect: Rect2) -> void:
	_box.position = rect.position
	_box.size = rect.size
	_box.visible = true


func hide_box() -> void:
	_box.visible = false


## Kaynak kutusu: toplam, net dakikalık gelir ve ticaret sınırı. net < 0 ise kırmızı.
func set_resource(key: String, value: int, net: int = 0, cap: int = 0) -> void:
	if not _chips.has(key):
		return
	var v := (_chips[key] as PanelContainer).get_child(0) as VBoxContainer
	var row := v.get_child(1) as HBoxContainer
	(row.get_child(0) as Label).text = str(value)
	var rate := row.get_child(1) as Label
	if cap > 0:
		rate.text = "%s%d/%d" % ["+" if net >= 0 else "", net, cap]
	else:
		rate.text = ""
	rate.add_theme_color_override("font_color", RED if net < 0 else RES_COLORS[key])


func show_resource(key: String, on: bool) -> void:
	if _chips.has(key):
		(_chips[key] as Control).visible = on


func set_pop(used: int, cap: int) -> void:
	_pop_label.text = "Nüfus %d/%d" % [used, cap]
	_pop_label.add_theme_color_override("font_color", RED if used >= cap else Color("e8ecfa"))


func set_idle(n: int) -> void:
	_idle_n = n
	_idle_btn.text = "!" if n == 0 else str(n)


## progress >= 0 ise çağ atlama ilerlemesi gösterilir.
func set_era(roman: String, era_name: String, progress: float = -1.0) -> void:
	if progress >= 0.0:
		_era_btn.text = "ÇAĞ ATLANIYOR\n%%%d" % int(progress * 100.0)
	else:
		_era_btn.text = "ÇAĞ %s · %s" % [roman, era_name]


func set_dev_era(idx: int) -> void:
	for i in range(_dev_era_buttons.size()):
		_style_button(_dev_era_buttons[i], i == idx)


## Ekranı bir an beyazla kaplar (nükleer patlama).
func flash() -> void:
	_flash.color = Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(_flash, "color:a", 0.0, 1.8)


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.7)


# ---------------------------------------------------------------- yardımcılar

func _anchor_top(c: Control, top: float, bottom: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = 8.0
	c.offset_right = -8.0
	c.offset_top = top
	c.offset_bottom = bottom


func _label(root: Control, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("0b1126"))
	l.add_theme_constant_override("outline_size", outline)
	root.add_child(l)
	return l


func _place_top(c: Control, top: float, bottom: float) -> void:
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 0.0
	c.anchor_bottom = 0.0
	c.offset_left = 10.0
	c.offset_right = -10.0
	c.offset_top = top
	c.offset_bottom = bottom


func _style(bg: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


func _button(label: String, min_h: float, font_size: int) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, min_h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", font_size)
	_style_button(b, false)
	return b


func _chip(title: String, accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _style(BG, BORDER, 8, 2))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	p.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 10)
	t.add_theme_color_override("font_color", Color("a8b3d0"))
	v.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	v.add_child(row)
	var val := Label.new()
	val.text = "0"
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", accent)
	row.add_child(val)
	var r := Label.new()
	r.add_theme_font_size_override("font_size", 9)
	r.add_theme_color_override("font_color", accent)
	r.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(r)
	return p
