extends CanvasLayer
## Kütüphane: 4 sütun (Askeri, Sivil, Ticaret, Bilim) x 5 seviye + "Çağ atla" düğmesi. L tuşu veya Şehir sekmesiyle açılır.

signal research(col_id: String)
signal age_up

const UnitsData = preload("res://scripts/units_data.gd")

var _panel: PanelContainer
var _cells := {}      # "col:row" -> Button
var _next_btns := {}  # col id -> Button (sütunun sıradaki araştırması)
var _age_btn: Button
var _age_info: Label
var _age_bar: ProgressBar


func _ready() -> void:
	layer = 8
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color("0f1630")
	st.border_color = Color("8fc0ff")
	st.set_border_width_all(2)
	st.set_corner_radius_all(16)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", st)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.offset_left = 10
	_panel.offset_right = -10
	_panel.offset_top = 70
	_panel.offset_bottom = -100
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = "Kütüphane"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffe08a"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Kapat"
	close.custom_minimum_size = Vector2(96, 44)
	close.pressed.connect(func(): visible = false)
	head.add_child(close)

	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	for col in UnitsData.LIB_COLS:
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 5)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cv)
		var h := Label.new()
		h.text = col["title"]
		h.add_theme_font_size_override("font_size", 15)
		h.add_theme_color_override("font_color", col["color"])
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(h)
		var d := Label.new()
		d.text = col["desc"]
		d.add_theme_font_size_override("font_size", 10)
		d.add_theme_color_override("font_color", Color("a8b3d0"))
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(d)
		for r in range(UnitsData.LIB_ROWS):
			var b := Button.new()
			b.custom_minimum_size = Vector2(0, 52)
			b.size_flags_vertical = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 11)
			var cid: String = col["id"]
			b.pressed.connect(func(): research.emit(cid))
			cv.add_child(b)
			_cells["%s:%d" % [cid, r]] = b

	_age_info = Label.new()
	_age_info.add_theme_font_size_override("font_size", 13)
	_age_info.add_theme_color_override("font_color", Color("c9d3f0"))
	_age_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_age_info)
	_age_bar = ProgressBar.new()
	_age_bar.custom_minimum_size = Vector2(0, 14)
	_age_bar.max_value = 1.0
	_age_bar.show_percentage = false
	v.add_child(_age_bar)
	_age_btn = Button.new()
	_age_btn.custom_minimum_size = Vector2(0, 58)
	_age_btn.add_theme_font_size_override("font_size", 16)
	_age_btn.pressed.connect(func(): age_up.emit())
	v.add_child(_age_btn)


## state: {"levels": {id: int}, "next": {id: {"cost": String, "can": bool}}, "age": {"text": String, "can": bool, "btn": String},
##         "progress": float (-1 = yok)}
func refresh(state: Dictionary) -> void:
	var levels: Dictionary = state["levels"]
	for col in UnitsData.LIB_COLS:
		var cid: String = col["id"]
		var lv: int = levels[cid]
		for r in range(UnitsData.LIB_ROWS):
			var b: Button = _cells["%s:%d" % [cid, r]]
			if r < lv:
				b.text = "Seviye %d\n✓" % (r + 1)
				b.disabled = true
				b.modulate = col["color"].lerp(Color.WHITE, 0.2)
			elif r == lv:
				var info: Dictionary = state["next"][cid]
				b.text = "Seviye %d\n%s" % [r + 1, info["cost"]]
				b.disabled = not info["can"]
				b.modulate = Color.WHITE
			else:
				b.text = "Seviye %d\nkilitli" % (r + 1)
				b.disabled = true
				b.modulate = Color(1, 1, 1, 0.45)
	var age: Dictionary = state["age"]
	_age_info.text = age["text"]
	_age_btn.text = age["btn"]
	_age_btn.disabled = not age["can"]
	var p: float = state["progress"]
	_age_bar.visible = p >= 0.0
	_age_bar.value = maxf(p, 0.0)
