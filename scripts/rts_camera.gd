extends Camera3D
## Sabit eğik (2.5B) strateji kamerası: sürükle = kaydır, tekerlek / sıkıştır = yakınlaş.

const WORLD := 1024.0

@export var min_zoom := 25.0
@export var max_zoom := 900.0
@export var pitch_deg := 52.0

var zoom := 90.0
var target := Vector3(512, 0, 512)
var pan_enabled := true  # çoklu seçim modunda kapanır (sürükleme kutu çizer)
var scroll_mul := 1.0    # ayarlardaki kaydırma hızı çarpanı

var _touches := {}
var _pinch_last := 0.0


func _ready() -> void:
	fov = 40.0
	near = 1.0
	far = 4000.0
	_apply()


func _apply() -> void:
	zoom = clampf(zoom, min_zoom, max_zoom)
	target.x = clampf(target.x, 0.0, WORLD)
	target.z = clampf(target.z, 0.0, WORLD)
	var pitch := deg_to_rad(pitch_deg)
	position = target + Vector3(0.0, sin(pitch), cos(pitch)) * zoom
	rotation = Vector3(-pitch, 0.0, 0.0)


func _pan(rel: Vector2) -> void:
	if not pan_enabled or Input.is_key_pressed(KEY_SHIFT):
		return  # Shift + sürükle (masaüstü) de kutu seçimidir
	var k := zoom * 0.0012 * scroll_mul
	var kz := k / sin(deg_to_rad(pitch_deg))
	target.x -= rel.x * k
	target.z -= rel.y * kz
	_apply()


func _zoom_by(factor: float) -> void:
	zoom *= factor
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(0.88)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.14)
	elif event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE):
			_pan(event.relative)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_last = 0.0
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_pan(event.relative)
		elif _touches.size() == 2:
			var p: Array = _touches.values()
			var d: float = (p[0] as Vector2).distance_to(p[1] as Vector2)
			if _pinch_last > 0.0 and d > 1.0:
				_zoom_by(_pinch_last / d)
			_pinch_last = d
