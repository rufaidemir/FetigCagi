extends RefCounted
## Keşif sisi. Dünya 4x4 karoluk hücrelere bölünür (256x256 hücre).
## Hücre durumu: 0 bilinmeyen, 128 keşfedilmiş, 255 şu an görünür.

const WORLD_TILES := 1024
const CELL := 4
const SIZE := 256  # WORLD_TILES / CELL

var data := PackedByteArray()
var image: Image
var texture: ImageTexture
var explored_count := 0

var _visible := PackedInt32Array()


func _init() -> void:
	data.resize(SIZE * SIZE)
	data.fill(0)
	image = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, data)
	texture = ImageTexture.create_from_image(image)


## observers: [{"pos": Vector3, "radius": float}, ...]
func update(observers: Array) -> void:
	for idx in _visible:
		data[idx] = 128
	_visible.clear()

	for o in observers:
		var p: Vector3 = o["pos"]
		var rc := int(ceil(float(o["radius"]) / CELL))
		var cx := int(p.x / CELL)
		var cz := int(p.z / CELL)
		for dz in range(-rc, rc + 1):
			var z := cz + dz
			if z < 0 or z >= SIZE:
				continue
			for dx in range(-rc, rc + 1):
				var x := cx + dx
				if x < 0 or x >= SIZE:
					continue
				if dx * dx + dz * dz > rc * rc:
					continue
				var idx := z * SIZE + x
				if data[idx] != 255:
					if data[idx] == 0:
						explored_count += 1
					data[idx] = 255
					_visible.append(idx)

	image.set_data(SIZE, SIZE, false, Image.FORMAT_L8, data)
	texture.update(image)


func state_at(p: Vector3) -> int:
	var x := clampi(int(p.x / CELL), 0, SIZE - 1)
	var z := clampi(int(p.z / CELL), 0, SIZE - 1)
	return data[z * SIZE + x]


func explored_percent() -> float:
	return 100.0 * float(explored_count) / float(SIZE * SIZE)
