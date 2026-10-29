extends CanvasLayer
## Ana menü: Fetih senaryosu (yakında), Hızlı oyun (harita, kurallar, mimari), Ayarlar (hız, kaydırma).
## "Başla"ya basınca seçilen yapılandırma `start` sinyaliyle yollanır.

signal start(cfg: Dictionary)

const BG := Color("0b1126")
const BTN := Color("141c3c")
const BORDER := Color("2a3560")
const ACTIVE := Color("234a8a")

const OPTIONS := {
	"map": ["Kıtalar", "Takımadalar", "Dağlık"],
	"rules": ["Normal", "Göçebe"],
	"peace": ["Yok", "5 dk", "15 dk"],
	"style": ["Batı", "Doğu", "Orta Doğu", "Mezoamerika"],
	"speed": ["1×", "1,5×", "2×"],
	"scroll": ["Yavaş", "Normal", "Hızlı"],
}
const TITLES := {"map": "Harita tipi", "rules": "Oyun kuralı", "peace": "Barış süresi",
	"style": "Mimari", "speed": "Oyun hızı", "scroll": "Kaydırma hızı"}

var cfg := {"map": 0, "rules": 0, "peace": 0, "style": 0, "speed": 0, "scroll": 1}
var _views := {}
var _opt_buttons := {}


func _ready() -> void:
	layer = 20
	var root := ColorRect.new()
	root.color = BG
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_views["main"] = _make_main(root)
	_views["quick"] = _make_options(root, ["map", "rules", "peace", "style"], "Hızlı oyun", true)
	_views["settings"] = _make_options(root, ["speed", "scroll"], "Ayarlar", false)
	_show("main")


func _show(v: String) -> void:
	for k in _views:
		(_views[k] as Control).visible = (k == v)


func _col(root: Control) -> VBoxContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 28)
	m.add_theme_constant_override("margin_right", 28)
	m.add_theme_constant_override("margin_top", 70)
	m.add_theme_constant_override("margin_bottom", 40)
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.add_child(v)
	m.set_meta("col", v)
	return v


func _btn(text: String, h: float, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, h)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", size)
	_style(b, false)
	return b


func _style(b: Button, active: bool) -> void:
	for st in ["normal", "hover", "pressed"]:
		var s := StyleBoxFlat.new()
		s.bg_color = ACTIVE if active else BTN
		s.border_color = Color("8fc0ff") if active else BORDER
		s.set_border_width_all(1)
		s.set_corner_radius_all(14)
		s.content_margin_left = 12
		s.content_margin_right = 12
		b.add_theme_stylebox_override(st, s)
	b.add_theme_stylebox_override("disabled", b.get_theme_stylebox("normal"))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_main(root: Control) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var v := _col(holder)
	v.add_child(_label("FETİH ÇAĞI", 44, Color("ffe08a")))
	v.add_child(_label("Keşfet · kur · fethet · çağ atla", 15, Color("a8b3d0")))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	v.add_child(gap)
	var campaign := _btn("Fetih senaryosu (yakında)", 64, 18)
	campaign.disabled = true
	campaign.modulate = Color(1, 1, 1, 0.5)
	v.add_child(campaign)
	var quick := _btn("Hızlı oyun", 64, 20)
	quick.pressed.connect(func(): _show("quick"))
	v.add_child(quick)
	var settings := _btn("Ayarlar", 64, 20)
	settings.pressed.connect(func(): _show("settings"))
	v.add_child(settings)
	return holder


func _make_options(root: Control, keys: Array, title: String, with_start: bool) -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.visible = false
	root.add_child(holder)
	var v := _col(holder)
	v.add_child(_label(title, 32, Color("ffe08a")))
	for key in keys:
		v.add_child(_label(TITLES[key], 14, Color("a8b3d0")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var arr: Array = []
		for i in range(OPTIONS[key].size()):
			var b := _btn(OPTIONS[key][i], 52, 14)
			var k: String = key
			var idx := i
			b.pressed.connect(func(): _pick(k, idx))
			row.add_child(b)
			arr.append(b)
		_opt_buttons[key] = arr
		_pick(key, cfg[key])
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(grow)
	if with_start:
		var go := _btn("Başla", 68, 22)
		go.pressed.connect(func():
			visible = false
			start.emit(_cfg_out()))
		v.add_child(go)
	var back := _btn("Geri", 52, 15)
	back.pressed.connect(func(): _show("main"))
	v.add_child(back)
	return holder


func _pick(key: String, idx: int) -> void:
	cfg[key] = idx
	var arr: Array = _opt_buttons[key]
	for i in range(arr.size()):
		_style(arr[i], i == idx)


## Menüdeki seçimleri oyunun anlayacağı değerlere çevirir.
func _cfg_out() -> Dictionary:
	return {
		"map": ["continents", "archipelago", "mountains"][cfg["map"]],
		"nomad": cfg["rules"] == 1,
		"peace": [0.0, 300.0, 900.0][cfg["peace"]],
		"style": ["west", "east", "mideast", "meso"][cfg["style"]],
		"speed": [1.0, 1.5, 2.0][cfg["speed"]],
		"scroll": [0.6, 1.0, 1.6][cfg["scroll"]],
	}


## Menüsüz (test) başlatma için varsayılan yapılandırma.
func default_cfg() -> Dictionary:
	return _cfg_out()
